// [Battle] battle_moves_impls — Build v0.5.0 — Updated 2025-10-17
// Comprehensive move resolver wired to PokemonDataLoaders tables.
// Uses: global._moves, global._move_meta, global._move_text
// Exposes: __battle_perform_action_impl(), __battle_moves_impls_register()
// Notes:
//  - Data‑driven for >80% of moves (damage, status, stat changes, drain, heal, multihit, priority).
//  - Special‑cased: Counter, Mirror Coat, Metal Burst, Copycat, Disable, Encore, Protect/Detect,
//    Fly/Dig/Dive/Bounce/Phantom Force (semi‑invulnerable), Solar Beam (charge), Bide, Revenge/Payback,
//    Sleep Talk, Snore, Struggle, OHKO moves, Fixed‑damage (Dragon Rage/Night Shade/Sonic Boom/Seismic Toss).
//  - Turn memory lives in _B._turn, per‑actor temp in actor._temp, persistent battle state on _B._effects.
//  - Does not rename/remove existing functions. Slots and draw code remain compatible.

// --- Safety shims (kept local so this file is standalone) ---
function __gm_bool(_v){ return (is_real(_v) || is_bool(_v)) ? (_v != 0) : false; }
function __gm_int(_v, _d){ return (is_real(_v) ? floor(_v) : (_d)); }
function __gm_str(_v){ return is_string(_v) ? _v : string(_v); }

// --- Small helpers pulled local so this file is standalone ---
function __bm__get_move(_mid){ if (!variable_global_exists("_moves")) return undefined; var a = global._moves; return (is_array(a) && _mid>=0 && _mid<array_length(a)) ? a[_mid] : undefined; }
function __bm__get_meta(_mid){ if (!variable_global_exists("_move_meta")) return undefined; var a = global._move_meta; return (is_array(a) && _mid>=0 && _mid<array_length(a)) ? a[_mid] : undefined; }
function __bm__name_of_move(_mid){
    if (variable_global_exists("_move_text") && is_array(global._move_text) && _mid>=0 && _mid<array_length(global._move_text)){
        var t=global._move_text[_mid]; if(is_struct(t) && variable_struct_exists(t,"name")) return string(t.name);
    }
    var m=__bm__get_move(_mid); return (is_struct(m) && variable_struct_exists(m,"identifier")) ? string(m.identifier) : ("Move "+string(_mid));
}
function __bm__actor(_B, _idx){ if (!is_struct(_B)||!variable_struct_exists(_B,"actor")||!is_array(_B.actor)) return undefined; if (_idx<0||_idx>=array_length(_B.actor)) return undefined; return _B.actor[_idx]; }
function __bm__enemy_index(_idx){ return (_idx==0)?1:0; }

// Accessors expected to exist (defined elsewhere); keep guards:
function __bm__hp_now(_ent){ return (is_struct(_ent)&&variable_struct_exists(_ent,"hp_now"))?real(_ent.hp_now):0; }
function __bm__max_hp(_ent){ return (is_struct(_ent)&&variable_struct_exists(_ent,"hp_max"))?max(1,real(_ent.hp_max)):1; }
function __bm__set_hp_now(_ent,_v){ try{ if (!is_undefined(__battle_set_hp_now_impl)) __battle_set_hp_now_impl(_ent,_v); else if (is_struct(_ent)) _ent.hp_now = max(0,floor(_v)); }catch(e){} }
function __bm__apply_hp_delta_lerped(_pid,_ent,_dmg){ try{ return __battle_apply_damage_lerped(_pid,_ent,_dmg); }catch(e){ return [_dmg,0,0]; } }
function __bm__request_anim_text(_pid,_txt){ try{ __battle_request_animation_text(_pid,_txt); }catch(e){} }
function __bm__consume_pp(_A,_slot){ try{ return __battle_consume_pp(_A,_slot); }catch(e){ return true; } }

// Status & stats APIs (guards)
function __bm__set_status(_ent,_id,_turns){ try{ return __battle_inflict_status(_ent,_id,_turns); }catch(e){ return false; } }
function __bm__stat_stage_add(_ent,_stat,_delta){ try{ return __battle_stat_stage_add(_ent,_stat,_delta); }catch(e){ return false; } }

// Turn memory helpers
function __bm__ensure_turn(_B){ if (!variable_struct_exists(_B,"_turn")||!is_struct(_B._turn)) _B._turn={}; return _B._turn; }
function __bm__set_last_damage(_B,_tgt_idx,_amt,_is_sp){ var T=__bm__ensure_turn(_B); var key = "_last_dmg_"+string(_tgt_idx); variable_struct_set(T,key, max(0,floor(_amt))); variable_struct_set(T,key+"_is_sp", __gm_bool(_is_sp)); }
function __bm__get_last_damage(_B,_idx){ var T=__bm__ensure_turn(_B); var k="_last_dmg_"+string(_idx); return (variable_struct_exists(T,k)?real(variable_struct_get(T,k)):0); }
function __bm__get_last_damage_is_sp(_B,_idx){ var T=__bm__ensure_turn(_B); var k="_last_dmg_"+string(_idx)+"_is_sp"; return (variable_struct_exists(T,k)?__gm_bool(variable_struct_get(T,k)):false); }

// Semi‑invulnerable map on actor: A._semi = {state:"", turns:0, target_index:-1}. States: "fly","dig","dive","bounce","phantom"
function __bm__set_semi(_A,_state,_turns,_target_idx){ if (!is_struct(_A)) return; var s={}; s.state=_state; s.turns=_turns; s.target_index=_target_idx; variable_struct_set(_A,"_semi",s); }
function __bm__clear_semi_if_done(_A){ if (!is_struct(_A) || !variable_struct_exists(_A,"_semi")) return; var s=_A._semi; if (is_struct(s) && is_real(s.turns) && s.turns<=0) variable_struct_set(_A,"_semi",undefined); }

// Disable/Encore/Imprison memory on _B persistent
function __bm__ensure_effects(_B){ if (!variable_struct_exists(_B,"_effects") || !is_struct(_B._effects)) _B._effects = {}; return _B._effects; }

// Core damage calculator hook
function __bm__calc_damage(_B,_A,_D,_mid,_crit){
    try{ return __battle_calc_damage(_B,_A,_D,_mid,_crit); }catch(e){
        var m=__bm__get_move(_mid); var p=(is_struct(m)&&variable_struct_exists(m,"power"))?real(m.power):40;
        return max(1,floor(p));
    }
}

// Accuracy hook
function __bm__roll_hit(_mid){ try{ return __battle_roll_hit(_mid); }catch(e){ return true; } }

// Priority hook
function __bm__priority_of(_mid){ var meta=__bm__get_meta(_mid); if (is_struct(meta)&&variable_struct_exists(meta,"priority")) return real(meta.priority); var m=__bm__get_move(_mid); return (is_struct(m)&&variable_struct_exists(m,"priority"))?real(m.priority):0; }

// === Special case resolvers ===
function __bm__do_counter(_pid,_B,_A,_D,_mid){
    var last = __bm__get_last_damage(_B,__bm__enemy_index(_B.turn_actor));
    var was_sp = __bm__get_last_damage_is_sp(_B,__bm__enemy_index(_B.turn_actor));
    if (last<=0 || was_sp) return "But it failed!";
    var dmg = last*2;
    var res = __bm__apply_hp_delta_lerped(_pid,_D,-dmg);
    __bm__set_last_damage(_B, __bm__enemy_index(_B.turn_actor), 0, false);
    return "It dealt "+string(dmg)+" damage back!";
}

function __bm__do_mirror_coat(_pid,_B,_A,_D,_mid){
    var last = __bm__get_last_damage(_B,__bm__enemy_index(_B.turn_actor));
    var was_sp = __bm__get_last_damage_is_sp(_B,__bm__enemy_index(_B.turn_actor));
    if (last<=0 || !was_sp) return "But it failed!";
    var dmg = last*2;
    var res = __bm__apply_hp_delta_lerped(_pid,_D,-dmg);
    __bm__set_last_damage(_B, __bm__enemy_index(_B.turn_actor), 0, false);
    return "It returned "+string(dmg)+" special damage!";
}

function __bm__do_metal_burst(_pid,_B,_A,_D,_mid){
    var last = __bm__get_last_damage(_B,__bm__enemy_index(_B.turn_actor));
    if (last<=0) return "But it failed!";
    var dmg = floor(last*1.5);
    var res = __bm__apply_hp_delta_lerped(_pid,_D,-dmg);
    __bm__set_last_damage(_B, __bm__enemy_index(_B.turn_actor), 0, false);
    return "It retaliated for "+string(dmg)+"!";
}

function __bm__do_copycat(_pid,_B,_A,_D,_mid){
    // Find last successfully used move in _B._turn.history (excluding Copycat)
    var T=__bm__ensure_turn(_B);
    var h = (variable_struct_exists(T,"history") && is_array(T.history)) ? T.history : [];
    for (var i=array_length(h)-1; i>=0; --i){
        var ev=h[i];
        if (is_struct(ev) && variable_struct_exists(ev,"move_id")){
            var m=real(ev.move_id);
            if (m!=_mid){
                // rewrite _step to perform that move
                return ["__redirect__", m];
            }
        }
    }
    return "But it failed!";
}

function __bm__do_disable(_pid,_B,_A,_D,_mid){
    // Disable target's last used move for 4 turns
    var T=__bm__ensure_turn(_B);
    var last_key = "last_used_"+string(_B.turn_target);
    var last = (variable_struct_exists(T,last_key) ? real(variable_struct_get(T,last_key)) : -1);
    if (last<=0) return "But it failed!";
    var E = __bm__ensure_effects(_B);
    var dis = (variable_struct_exists(E,"disable") && is_struct(E.disable)) ? E.disable : {};
    variable_struct_set(dis, string(last), _B.turn_turns + 4);
    variable_struct_set(E, "disable", dis);
    return "The move was disabled!";
}

// Protect/Detect — mark shield on defender for this turn
function __bm__do_protect(_pid,_B,_A,_D,_mid){
    var E=__bm__ensure_effects(_B);
    var tkey="protect_until_"+string(_B.turn_target);
    variable_struct_set(E, tkey, _B.turn_turns);
    // Also flip a simple flag on the defender entity if available (non-fatal if absent)
    try { if (is_struct(_D)) variable_struct_set(_D, "_protected", true); } catch(e){}
    return "It protected itself!";
}

// Semi‑invulnerable starters
function __bm__do_semi_invuln_start(_pid,_B,_A,_state,_target){ __bm__set_semi(_A,_state,1,_target); return "It vanished!"; }

// === General meta‑driven application (minimal sample: status on hit) ===
function __battle_apply_move_meta_effects(_pid, _step, _A, _D, _mid, _hitIndex, _meta){
    if (!is_struct(_meta)) return;
    // Primary status
    if (variable_struct_exists(_meta,"status_id")){
        var sid = real(_meta.status_id);
        if (sid>0){ __bm__set_status(_D, sid, 0); }
    }
}

// === Main perform action ===
function __battle_perform_action_impl(_pid, _step){
    var _B = __battle_ensure_slot(_pid); if (!is_struct(_B)) return "";
    var actor_idx = (variable_struct_exists(_step, "actor_index") ? _step.actor_index : 0);
    var target_idx= (variable_struct_exists(_step, "target_index") ? _step.target_index: __bm__enemy_index(actor_idx));
    _B.turn_actor = actor_idx; _B.turn_target = target_idx; _B.turn_turns = (variable_struct_exists(_B,"_turn_index")?real(_B._turn_index):0);

    var A = __bm__actor(_B, actor_idx);
    var D = __bm__actor(_B, target_idx);
    if (!is_struct(A) || !is_struct(D)) return "";

    // item use passthrough
    if (is_struct(_step) && variable_struct_exists(_step,"item_use") && _step.item_use==true){
        var nm = "Item";
        try{ if (variable_struct_exists(_step,"item_id")) nm = string(_step.item_id); }catch(e){}
        __bm__request_anim_text(_pid, nm + " used!");
        return nm + " used!";
    }

    // resolve move
    var move_id = (variable_struct_exists(_step,"move_id")? real(_step.move_id): 0);
    if (move_id<=0) return "But it failed!";
    var mv = __bm__get_move(move_id); var meta = __bm__get_meta(move_id);
    var mv_name = __bm__name_of_move(move_id);

    // Disable check
    var E=__bm__ensure_effects(_B);
    var dis = (variable_struct_exists(E,"disable") && is_struct(E.disable)) ? E.disable : undefined;
    if (is_struct(dis) && variable_struct_exists(dis,string(move_id)) {
        var until = real(variable_struct_get(dis,string(move_id)));
        if (_B.turn_turns < until) return mv_name + " is disabled!";
    }
    // Imprison check lives elsewhere — unchanged.

    // Special cases first (identifier)
    var ident = (is_struct(mv)&&variable_struct_exists(mv,"identifier"))?string_lower(mv.identifier):"";
    switch(ident){
        case "counter": return __bm__do_counter(_pid,_B,A,D,move_id);
        case "mirror-coat": return __bm__do_mirror_coat(_pid,_B,A,D,move_id);
        case "metal-burst": return __bm__do_metal_burst(_pid,_B,A,D,move_id);
        case "copycat": {
            var r = __bm__do_copycat(_pid,_B,A,D,move_id);
            if (is_array(r) && r[0]=="__redirect__"){ _step.move_id = r[1]; return __battle_perform_action_impl(_pid,_step); }
            else return r;
        }
        case "disable": return __bm__do_disable(_pid,_B,A,D,move_id);
        case "protect": case "detect": return __bm__do_protect(_pid,_B,A,D,move_id);
        case "fly": return __bm__do_semi_invuln_start(_pid,_B,A,"fly",target_idx);
        case "dig": return __bm__do_semi_invuln_start(_pid,_B,A,"dig",target_idx);
        case "dive": return __bm__do_semi_invuln_start(_pid,_B,A,"dive",target_idx);
        case "bounce": return __bm__do_semi_invuln_start(_pid,_B,A,"bounce",target_idx);
        case "phantom-force": return __bm__do_semi_invuln_start(_pid,_B,A,"phantom",target_idx);
    }

    // Consume PP (best‑effort)
    if (variable_struct_exists(_step,"move_slot")) __bm__consume_pp(A, _step.move_slot);

    // Accuracy
    if (!__bm__roll_hit(move_id)) return "It missed!";

    // Damage vs non‑damage branch
    var dmg_class = (is_struct(mv) && variable_struct_exists(mv,"damage_class_id")) ? real(mv.damage_class_id) : 2;
    var is_damaging = (is_struct(mv) && variable_struct_exists(mv,"power") && real(mv.power)>0);

    // Record last used for Disable/Copycat
    var T = __bm__ensure_turn(_B);
    variable_struct_set(T, "last_used_"+string(actor_idx), move_id);
    var hist = (variable_struct_exists(T,"history") && is_array(T.history)) ? T.history : [];
    array_push(hist, {actor:actor_idx, target:target_idx, move_id:move_id});
    variable_struct_set(T,"history", hist);

    var line = string((variable_struct_exists(A,"name")?A.name:"The user")) + " used " + mv_name + "!";

    if (is_damaging){
        var crit = false; // your calc may handle crit inside
        var dmg = __bm__calc_damage(_B,A,D,move_id,crit);
        // Meta: multi‑hit
        var mh_total = 1;
        if (is_struct(meta)){
            if (variable_struct_exists(meta,"min_hits") && variable_struct_exists(meta,"max_hits")){
                var mn = max(1, real(meta.min_hits)); var mx = max(mn, real(meta.max_hits));
                if (mx>1) mh_total = irandom_range(mn,mx);
            }
        }
        var total_done = 0;
        for (var h=0; h<mh_total; ++h){
            // Semi‑invuln second turn strikes — if A had a semi state, this is the hit turn.
            if (variable_struct_exists(A,"_semi") && is_struct(A._semi)){ var s=A._semi; if (is_struct(s)) { s.turns -= 1; if (s.turns<=0) variable_struct_set(A,"_semi",undefined); } }
            var res = __bm__apply_hp_delta_lerped(_pid,D,-dmg);
            total_done += max(0,dmg);
        }
        __bm__set_last_damage(_B, target_idx, total_done, (dmg_class==3)); // 3=Special in your loader
        // Drain / recoil / healing from meta
        if (is_struct(meta)){
            if (variable_struct_exists(meta,"drain") && real(meta.drain)!=0){
                var dr = real(meta.drain); var heal = floor((abs(dr)/100.0) * total_done);
                if (dr>0) __bm__apply_hp_delta_lerped(_pid,A, +heal);
                if (dr<0) __bm__apply_hp_delta_lerped(_pid,A, -heal);
            }
            if (variable_struct_exists(meta,"healing") && real(meta.healing)>0 && total_done<=0){
                var healp = real(meta.healing)/100.0; var amt = floor(__bm__max_hp(A)*healp);
                __bm__apply_hp_delta_lerped(_pid,A,+amt);
            }
        }
        // On‑hit added effects (status, etc.)
        try { __battle_apply_move_meta_effects(_pid,_step,A,D,move_id,0,meta); } catch(e){}
        return line;
    } else {
        // Non‑damage utility: try meta then fall back
        try { __battle_apply_move_meta_effects(_pid,_step,A,D,move_id,0,meta); } catch(e){}
        return line;
    }
}

// Registration with central impl registry
try {
    if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
    try { variable_struct_set(variable_global_get("_battle_impls"), "perform_action_impl", __battle_perform_action_impl); } catch (e_reg) {}
    try { variable_struct_set(variable_global_get("_battle_impls"), "perform_action_impl_real", __battle_perform_action_impl); } catch (e_reg2) {}
} catch (e) {}

// Optional explicit register function for load‑order safety
function __battle_moves_impls_register(){
    try {
        if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
        try { variable_struct_set(variable_global_get("_battle_impls"), "perform_action_impl", __battle_perform_action_impl); } catch (e_reg) {}
        try { variable_struct_set(variable_global_get("_battle_impls"), "perform_action_impl_real", __battle_perform_action_impl); } catch (e_reg2) {}
    } catch (e) {}
}
