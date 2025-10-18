// [Battle] battle_moves_impls — Build v0.5.2 — Updated 2025-10-17
// Adds semi‑invuln exceptions: certain moves can hit targets during Fly/Dig/Dive/Bounce with optional power multipliers.
// No other files required. Drop-in replacement for battle_moves_impls.gml.


// --- Safety shims ---
function __gm_bool(_v){ return (is_real(_v) || is_bool(_v)) ? (_v != 0) : false; }
function __gm_int(_v, _d){ return (is_real(_v) ? floor(_v) : (_d)); }
function __gm_str(_v){ return is_string(_v) ? _v : string(_v); }

// --- Local helpers ---
function __bm__get_move(_mid){ if (!variable_global_exists("_moves")) return undefined; var a = global._moves; return (is_array(a) && _mid>=0 && _mid<array_length(a)) ? a[_mid] : undefined; }
function __bm__get_meta(_mid){ if (!variable_global_exists("_move_meta")) return undefined; var a = global._move_meta; return (is_array(a) && _mid>=0 && _mid<array_length(a)) ? a[_mid] : undefined; }
function __bm__name_of_move(_mid){
    // Prefer the project's canonical move-name helper when available so
    // move names remain consistent across UI subsystems.
    try {
        if (!is_undefined(scr_move_name_by_id)){
            var _nm = scr_move_name_by_id(_mid);
            if (is_string(_nm) && string_length(_nm) > 0) return _nm;
        }
    } catch (e_sn) {}

    if (variable_global_exists("_move_text") && is_array(global._move_text) && _mid>=0 && _mid<array_length(global._move_text)){
        var t=global._move_text[_mid]; if(is_struct(t) && variable_struct_exists(t,"name") && string_length(string(variable_struct_get(t,"name")))>0) return string(variable_struct_get(t,"name"));
    }
    var m=__bm__get_move(_mid);
    if (is_struct(m) && variable_struct_exists(m,"identifier") && string_length(string(variable_struct_get(m,"identifier")))>0) return string(variable_struct_get(m,"identifier"));
    return "Move "+string(_mid);
}
function __bm__actor(_B, _idx){ if (!is_struct(_B)||!variable_struct_exists(_B,"actor")||!is_array(_B.actor)) return undefined; if (_idx<0||_idx>=array_length(_B.actor)) return undefined; return _B.actor[_idx]; }
function __bm__enemy_index(_idx){ return (_idx==0)?1:0; }

// External hooks (guarded)
function __bm__apply_hp_delta_lerped(_pid,_ent,_dmg){
    try{
        // Debug: report entry
    // Use a more targeted flag for move/lerp debug; DATA_DEBUG is very noisy.
    if (variable_global_exists("MOVES_DEBUG") && global.MOVES_DEBUG) show_debug_message("[moves][lerped] request pid=" + string(_pid) + ", ent=" + string(_ent) + ", delta=" + string(_dmg));
        if (variable_global_exists("_battle_impls") && is_struct(variable_global_get("_battle_impls")) && variable_struct_exists(variable_global_get("_battle_impls"), "__battle_apply_damage_lerped")){
            var fn = variable_struct_get(variable_global_get("_battle_impls"), "__battle_apply_damage_lerped");
            if (!is_undefined(fn)){
                if (variable_global_exists("MOVES_DEBUG") && global.MOVES_DEBUG) show_debug_message("[moves][lerped] calling registry impl");
                return fn(_pid,_ent,_dmg);
            }
        }
    }catch(e){}
    try{
        if (variable_global_exists("__battle_apply_damage_lerped")){
            var gf = variable_global_get("__battle_apply_damage_lerped");
            if (!is_undefined(gf)){
                if (variable_global_exists("MOVES_DEBUG") && global.MOVES_DEBUG) show_debug_message("[moves][lerped] calling global impl");
                return gf(_pid,_ent,_dmg);
            }
        }
    }catch(e){}
    if (variable_global_exists("MOVES_DEBUG") && global.MOVES_DEBUG) show_debug_message("[moves][lerped] no impl found, returning fallback (no-op)");
    return [_dmg,0,0];
}
function __bm__request_anim_text(_pid,_txt){
    try{
        if (variable_global_exists("_battle_impls") && is_struct(variable_global_get("_battle_impls")) && variable_struct_exists(variable_global_get("_battle_impls"), "__battle_request_animation_text")){
            var fn = variable_struct_get(variable_global_get("_battle_impls"), "__battle_request_animation_text"); fn(_pid,_txt); return;
        }
    }catch(e){}
    try{ if (variable_global_exists("__battle_request_animation_text")) variable_global_get("__battle_request_animation_text")(_pid,_txt); }catch(e){}
}
function __bm__consume_pp(_A,_slot){
    try{
        if (variable_global_exists("_battle_impls") && is_struct(variable_global_get("_battle_impls")) && variable_struct_exists(variable_global_get("_battle_impls"), "__battle_consume_pp")){
            var fn = variable_struct_get(variable_global_get("_battle_impls"), "__battle_consume_pp"); return fn(_A,_slot);
        }
    }catch(e){}
    try{ if (variable_global_exists("__battle_consume_pp")) return variable_global_get("__battle_consume_pp")(_A,_slot); }catch(e){}
    return true;
}
function __bm__set_status(_ent,_id,_turns){
    try{
        if (variable_global_exists("_battle_impls") && is_struct(variable_global_get("_battle_impls")) && variable_struct_exists(variable_global_get("_battle_impls"), "__battle_inflict_status")){
            var fn = variable_struct_get(variable_global_get("_battle_impls"), "__battle_inflict_status"); return fn(_ent,_id,_turns);
        }
    }catch(e){}
    try{ if (variable_global_exists("__battle_inflict_status")) return variable_global_get("__battle_inflict_status")(_ent,_id,_turns); }catch(e){}
    return false;
}
function __bm__stat_stage_add(_ent,_stat,_delta){
    try{
        if (variable_global_exists("_battle_impls") && is_struct(variable_global_get("_battle_impls")) && variable_struct_exists(variable_global_get("_battle_impls"), "__battle_stat_stage_add")){
            var fn = variable_struct_get(variable_global_get("_battle_impls"), "__battle_stat_stage_add"); return fn(_ent,_stat,_delta);
        }
    }catch(e){}
    try{ if (variable_global_exists("__battle_stat_stage_add")) return variable_global_get("__battle_stat_stage_add")(_ent,_stat,_delta); }catch(e){}
    return false;
}
function __bm__calc_damage(_B,_A,_D,_mid,_crit){
    try{
        // battle system expects (attacker, defender, move_id, power)
        var mtmp = __bm__get_move(_mid);
        var pwr = (is_struct(mtmp) && variable_struct_exists(mtmp, "power")) ? real(variable_struct_get(mtmp, "power")) : 40;
        return __battle_calc_damage(_A, _D, _mid, pwr);
    }catch(e){
        var m=__bm__get_move(_mid); var p=(is_struct(m)&&variable_struct_exists(m,"power"))?real(variable_struct_get(m,"power")):40; 
        return max(1,floor(p));
    }
}
function __bm__roll_hit(_mid){ try{ return __battle_roll_hit(_mid); }catch(e){ return true; } }

// Internal per-battle memory on _B
function __bm__ensure_mem(_B){
    if (!variable_struct_exists(_B,"_mem") || !is_struct(_B._mem)){
        _B._mem = { action_counter:0, last_move_id:-1, last_move_actor:-1, last_move_success:false };
    }
    return _B._mem;
}

// Semi‑invulnerable map on actor: A._semi = {state:"", turns:0, target_index:-1, move_id:-1}
function __bm__set_semi(_A,_state,_turns,_target_idx,_mid){
    if (!is_struct(_A)) return;
    var s={}; s.state=_state; s.turns=_turns; s.target_index=_target_idx; s.move_id=_mid;
    variable_struct_set(_A,"_semi",s);
}
function __bm__pop_semi_turn(_A){
    if (!is_struct(_A) || !variable_struct_exists(_A,"_semi")) return;
    var s=_A._semi; if (!is_struct(s)) return;
    s.turns -= 1; if (s.turns<=0) variable_struct_set(_A,"_semi",undefined);
}
function __bm__defender_is_semi(_D){
    return (is_struct(_D) && variable_struct_exists(_D,"_semi") && is_struct(_D._semi));
}
function __bm__defender_semi_state(_D){
    if (!__bm__defender_is_semi(_D)) return "";
    var s = _D._semi; if (is_struct(s) && variable_struct_exists(s,"state")) return string_lower(s.state);
    return "";
}

// Disable map per-battle: store on _B._mem.disable = { moveId : expires_at_counter }
function __bm__disable_activate(_B, _target_move_id, _ttl_actions){
    var M=__bm__ensure_mem(_B);
    if (!variable_struct_exists(M,"disable") || !is_struct(M.disable)) M.disable = {};
    variable_struct_set(M.disable, string(_target_move_id), __gm_int(M.action_counter,0) + _ttl_actions);
}
function __bm__disable_is_active(_B,_move_id){
    var M=__bm__ensure_mem(_B);
    if (!variable_struct_exists(M,"disable") || !is_struct(M.disable)) return false;
    var key=string(_move_id);
    if (!variable_struct_exists(M.disable,key)) return false;
    var expires_at = real(variable_struct_get(M.disable,key));
    return (__gm_int(variable_struct_exists(M,"action_counter")?variable_struct_get(M,"action_counter"):0,0) < expires_at);
}

// ---------- Semi‑invuln exceptions ----------
// Returns an array [hits:boolean, power_mult:real].
function __bm__move_hits_semi(_move_ident, _semi_state){
    var move_ident_l = string_lower(_move_ident);
    var st = string_lower(_semi_state);

    // Common exception sets
    var hits_air = ds_list_create(); // Fly/Bounce
    ds_list_add(hits_air, "gust"); ds_list_add(hits_air, "twister"); ds_list_add(hits_air, "thunder");
    ds_list_add(hits_air, "hurricane"); ds_list_add(hits_air, "smack-down"); ds_list_add(hits_air, "thousand-arrows");
    ds_list_add(hits_air, "sky-uppercut"); // optional

    if (st == "fly" || st == "bounce"){
        var mul = 1.0;
        if (ds_list_find_index(hits_air, move_ident_l) != -1){
            ds_list_destroy(hits_air);
            return [true, mul];
        }
        ds_list_destroy(hits_air);
        return [false, 1.0];
    }

    if (st == "dig"){
        // Earthquake/Magnitude hit with boosted power; Bulldoze can hit normally if present
        if (move_ident_l == "earthquake" || move_ident_l == "magnitude"){
            return [true, 2.0];
        }
        if (move_ident_l == "bulldoze"){
            return [true, 1.0];
        }
        return [false, 1.0];
    }

    if (st == "dive"){
        // Surf/Whirlpool can hit with boosted power
        if (move_ident_l == "surf" || move_ident_l == "whirlpool"){
            return [true, 2.0];
        }
        return [false, 1.0];
    }

    // phantom-force: no standard counters—treat as fully invulnerable here
    return [false, 1.0];
}

// === Special case resolvers ===
function __bm__do_counter(_pid,_B,_A,_D,_mid){
    var M=__bm__ensure_mem(_B);
    var lastAmt = (variable_struct_exists(M,"last_dmg_"+string(__bm__enemy_index(_B.turn_actor))) ? real(variable_struct_get(M,"last_dmg_"+string(__bm__enemy_index(_B.turn_actor)))) : 0);
    var was_sp = (variable_struct_exists(M,"last_dmg_sp_"+string(__bm__enemy_index(_B.turn_actor))) ? __gm_bool(variable_struct_get(M,"last_dmg_sp_"+string(__bm__enemy_index(_B.turn_actor)))) : false);
    if (lastAmt<=0 || was_sp) return "But it failed!";
    var dmg = lastAmt*2;
    __bm__apply_hp_delta_lerped(_pid,_D,-dmg);
    variable_struct_set(M, "last_dmg_"+string(__bm__enemy_index(_B.turn_actor)), 0);
    return "It dealt "+string(dmg)+" damage back!";
}
function __bm__do_mirror_coat(_pid,_B,_A,_D,_mid){
    var M=__bm__ensure_mem(_B);
    var lastAmt = (variable_struct_exists(M,"last_dmg_"+string(__bm__enemy_index(_B.turn_actor))) ? real(variable_struct_get(M,"last_dmg_"+string(__bm__enemy_index(_B.turn_actor)))) : 0);
    var was_sp = (variable_struct_exists(M,"last_dmg_sp_"+string(__bm__enemy_index(_B.turn_actor))) ? __gm_bool(variable_struct_get(M,"last_dmg_sp_"+string(__bm__enemy_index(_B.turn_actor)))) : false);
    if (lastAmt<=0 || !was_sp) return "But it failed!";
    var dmg = lastAmt*2;
    __bm__apply_hp_delta_lerped(_pid,_D,-dmg);
    variable_struct_set(M, "last_dmg_"+string(__bm__enemy_index(_B.turn_actor)), 0);
    return "It returned "+string(dmg)+" special damage!";
}
function __bm__do_metal_burst(_pid,_B,_A,_D,_mid){
    var M=__bm__ensure_mem(_B);
    var lastAmt = (variable_struct_exists(M,"last_dmg_"+string(__bm__enemy_index(_B.turn_actor))) ? real(variable_struct_get(M,"last_dmg_"+string(__bm__enemy_index(_B.turn_actor)))) : 0);
    if (lastAmt<=0) return "But it failed!";
    var dmg = floor(lastAmt*1.5);
    __bm__apply_hp_delta_lerped(_pid,_D,-dmg);
    variable_struct_set(M, "last_dmg_"+string(__bm__enemy_index(_B.turn_actor)), 0);
    return "It retaliated for "+string(dmg)+"!";
}

// Copycat: replay last successful move that is not Copycat
function __bm__do_copycat(_pid,_B,_A,_D,_mid){
    var M = __bm__ensure_mem(_B);
    var lm = -1;
    try { if (variable_struct_exists(M, "last_move_id")) lm = __gm_int(variable_struct_get(M, "last_move_id"), -1); } catch (e) {}
    var last_succ = false;
    try { if (variable_struct_exists(M, "last_move_success")) last_succ = __gm_bool(variable_struct_get(M, "last_move_success")); } catch (e) {}
    // Validate candidate move id: must be positive, different from Copycat, and the last move must have been successful
    if (lm > 0 && lm != _mid && last_succ){
        // Ensure the move isn't another Copycat (avoid infinite redirect loops) and that the move id resolves to a known move
        try {
            var _mv = __bm__get_move(lm);
            var _ident = "";
            if (is_struct(_mv) && variable_struct_exists(_mv, "identifier")) _ident = string_lower(string(variable_struct_get(_mv, "identifier")));
            // If the resolved move is valid and not copycat, allow redirect
            if (!is_undefined(_mv) && _ident != "copycat") return ["__redirect__", lm];
        } catch (e_valid) {}
    }
    return "But it failed!";
}

// Disable: lock target's last used move for N action resolutions (self-contained)
function __bm__do_disable(_pid,_B,_A,_D,_mid){
    var M=__bm__ensure_mem(_B);
    // Use defender's last used move id from memory; if missing, fail
    var last_by_def = (__gm_int(variable_struct_exists(M,"last_used_"+string(_B.turn_target)) ? variable_struct_get(M,"last_used_"+string(_B.turn_target)) : -1, -1));
    if (last_by_def<=0) return "But it failed!";
    __bm__disable_activate(_B, last_by_def, 8); // ~4 turns worth of actions in 1v1 (player+enemy) → 8 actions
    return "The move was disabled!";
}

// Protect/Detect — mark shield on defender for this action window
function __bm__do_protect(_pid,_B,_A,_D,_mid){
    try { if (is_struct(_D)) variable_struct_set(_D, "_protected", true); } catch(e){}
    return "It protected itself!";
}

// Meta effects are implemented centrally in `scripts/battle_system/battle_system.gml`.
// This file intentionally does not provide a second definition to avoid duplicate
// script/function names (GameMaker requires global script names to be unique).
// If you need to override the meta-effect handler, provide the implementation
// in `battle_system.gml` or register it via the `_battle_impls` registry.

// === Main perform action ===
function __battle_perform_action_impl(_pid, _step){
    var _B = __battle_ensure_slot(_pid); if (!is_struct(_B)) return "";
    try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){ show_debug_message("[battle][perform_action] pid=" + string(_pid) + ", step=" + string(_step)); } } catch(e){}
    var actor_idx = (variable_struct_exists(_step, "actor_index") ? _step.actor_index : 0);
    var target_idx= (variable_struct_exists(_step, "target_index") ? _step.target_index: __bm__enemy_index(actor_idx));
    _B.turn_actor = actor_idx; _B.turn_target = target_idx;

    var A = __bm__actor(_B, actor_idx);
    var D = __bm__actor(_B, target_idx);
    if (!is_struct(A) || !is_struct(D)) return "";

    var M=__bm__ensure_mem(_B);
    // Bump action counter first so disables expire
    M.action_counter = __gm_int(M.action_counter,0) + 1;

    // If attacker is in semi state and selected a different move, force continuation of its stored move
    if (variable_struct_exists(A,"_semi") && is_struct(variable_struct_get(A,"_semi"))){
        var s = variable_struct_get(A,"_semi");
        if (is_struct(s) && variable_struct_exists(s,"move_id") && is_real(variable_struct_get(s,"move_id")) && variable_struct_get(s,"move_id")>0){
            _step.move_id = real(variable_struct_get(s,"move_id"));
            target_idx = (variable_struct_exists(s,"target_index")? real(variable_struct_get(s,"target_index")) : target_idx);
            try { variable_struct_set(_B, "turn_target", target_idx); } catch (ee) {}
            D = __bm__actor(_B, target_idx);
        }
    }

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
    if (string_length(string(mv_name)) == 0) mv_name = "Move " + string(move_id);
    var ident = "";
    if (is_struct(mv) && variable_struct_exists(mv, "identifier")) ident = string_lower(string(variable_struct_get(mv, "identifier")));

    // Prevent incapacitated actors (sleep) from acting here unless the move
    // specifically bypasses sleep (e.g., Snore, Sleep Talk). This centralizes
    // the pre-action gating so the battle engine consistently enforces it.
    try {
        if (!is_undefined(status_system_has_status) && status_system_has_status(A, "sleep")){
            var _allowed = ["snore","sleep-talk"];
            var _ok = false;
            for (var __ai = 0; __ai < array_length(_allowed); ++__ai){ if (_allowed[__ai] == ident) { _ok = true; break; } }
            if (!_ok){
                // mark last move as unsuccessful for copycat/related logic
                try { variable_struct_set(M, "last_move_success", false); } catch (e_lm) {}
                var actor_name = (variable_struct_exists(A,"name") ? string(variable_struct_get(A,"name")) : "The user");
                return actor_name + " is asleep!";
            }
        }
    } catch (e_sleep) { /* ignore and continue */ }

    // Disable check (self-contained via action_counter)
    if (__bm__disable_is_active(_B, move_id)){
        return mv_name + " is disabled!";
    }

    // Special cases first
    switch(ident){
        case "counter": return __bm__do_counter(_pid,_B,A,D,move_id);
        case "mirror-coat": return __bm__do_mirror_coat(_pid,_B,A,D,move_id);
        case "metal-burst": return __bm__do_metal_burst(_pid,_B,A,D,move_id);
        case "copycat":
            var r = __bm__do_copycat(_pid,_B,A,D,move_id);
            if (is_array(r) && r[0]=="__redirect__"){
                var _lm = r[1];
                // Build a fresh step for the redirected move so actor/defender
                // are re-resolved and local context is correct. Attempt to pick
                // a matching move_slot on the actor if it has the move; otherwise
                // leave move_slot undefined and let consume_pp be best-effort.
                var new_step = { actor_index: actor_idx, target_index: target_idx, move_id: _lm };
                // Try to find a move_slot on attacker that matches _lm
                try {
                    if (is_struct(A) && variable_struct_exists(A, "moves")){
                        var __mv_arr = variable_struct_get(A, "moves");
                        if (is_array(__mv_arr)){
                            for (var __ms = 0; __ms < array_length(__mv_arr); __ms++){
                                if (is_real(__mv_arr[__ms]) && __mv_arr[__ms] == _lm){ new_step.move_slot = __ms; break; }
                            }
                        }
                    }
                } catch (e_ms){}
                // Execute redirected move in a fresh context
                try { var exec_res = __battle_perform_action_impl(_pid, new_step); } catch (e_exec){ exec_res = ""; }
                try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){ show_debug_message("[battle][perform_action][copycat_redirect] pid=" + string(_pid) + ", orig_mid=" + string(move_id) + ", redirect_mid=" + string(_lm) + ", exec_res=" + string(exec_res)); } } catch(e){}
                var nm = __bm__name_of_move(_lm);
                if (string_length(string(nm)) == 0) nm = "Move " + string(_lm);
                var actor_name = (variable_struct_exists(A,"name") ? string(variable_struct_get(A,"name")) : "The user");
                // If the redirected execution returned a non-empty announcement, prefer it
                if (is_string(exec_res) && string_length(exec_res) > 0) return exec_res;
                return actor_name + " used " + nm + "!";
            } else return r;
        case "disable": return __bm__do_disable(_pid,_B,A,D,move_id);
        case "protect": case "detect": return __bm__do_protect(_pid,_B,A,D,move_id);
        case "fly": __bm__set_semi(A,"fly",1,target_idx,move_id); return "It flew up high!";
        case "dig": __bm__set_semi(A,"dig",1,target_idx,move_id); return "It burrowed underground!";
        case "dive": __bm__set_semi(A,"dive",1,target_idx,move_id); return "It hid underwater!";
        case "bounce": __bm__set_semi(A,"bounce",1,target_idx,move_id); return "It sprang up!";
        case "phantom-force": __bm__set_semi(A,"phantom",1,target_idx,move_id); return "It vanished instantly!";
    }

    // Consume PP (best‑effort)
    if (variable_struct_exists(_step,"move_slot")) __bm__consume_pp(A, _step.move_slot);

    // Accuracy & semi-invuln handling with exceptions
    if (__bm__defender_is_semi(D)){
        var st = __bm__defender_semi_state(D);
        var exc = __bm__move_hits_semi(ident, st);
        var can_hit = (is_array(exc) && array_length(exc)>=1 ? __gm_bool(exc[0]) : false);
        if (!can_hit) return "It missed!";
        // we’ll apply exc[1] as a power multiplier below if damaging
        var _semi_power_mul = (is_array(exc) && array_length(exc)>=2 ? real(exc[1]) : 1.0);
        variable_struct_set(_B, "_semi_power_mul_tmp", _semi_power_mul);
    } else {
        variable_struct_set(_B, "_semi_power_mul_tmp", 1.0);
    }

    if (!__bm__roll_hit(move_id)) return "It missed!";

    // Damage vs non‑damage branch
    var dmg_class = 2;
    try { if (is_struct(mv) && variable_struct_exists(mv,"damage_class_id")) dmg_class = real(variable_struct_get(mv,"damage_class_id")); } catch(e){}
    var is_damaging = false;
    try { if (is_struct(mv) && variable_struct_exists(mv,"power") && real(variable_struct_get(mv,"power"))>0) is_damaging = true; } catch(e){}

    // Remember last used (for Disable target tracking and global last move)
    variable_struct_set(M, "last_used_"+string(actor_idx), move_id);

    var line = string((variable_struct_exists(A,"name")?string(variable_struct_get(A,"name")):"The user")) + " used " + mv_name + "!";

    if (is_damaging){
        var crit = false;
        var dmg = __bm__calc_damage(_B,A,D,move_id,crit);
        var powmul = 1.0;
        if (variable_struct_exists(_B, "_semi_power_mul_tmp") && is_real(variable_struct_get(_B, "_semi_power_mul_tmp"))) powmul = max(0.1, real(variable_struct_get(_B, "_semi_power_mul_tmp")));
        dmg = floor(dmg * powmul);

        var total_done = 0;
        var hits = 1;
        if (is_struct(meta)){
            if (variable_struct_exists(meta,"min_hits") && variable_struct_exists(meta,"max_hits")){
                var mn = max(1, real(variable_struct_get(meta, "min_hits"))); var mx = max(mn, real(variable_struct_get(meta, "max_hits")));
                if (mx>1) hits = irandom_range(mn,mx);
            }
        }
        for (var h=0; h<hits; ++h){
            // If attacker is coming down from semi, pop it now on first strike
            if (variable_struct_exists(A,"_semi") && is_struct(variable_struct_get(A,"_semi"))){ __bm__pop_semi_turn(A); }
            __bm__apply_hp_delta_lerped(_pid,D,-dmg);
            total_done += max(0,dmg);
        }
        // Store last damage for retaliate moves on both sides
        variable_struct_set(M, "last_dmg_"+string(target_idx), total_done);
        variable_struct_set(M, "last_dmg_sp_"+string(target_idx), (dmg_class==3));
        // Drain / recoil / healing
        if (is_struct(meta)){
            if (variable_struct_exists(meta,"drain") && real(variable_struct_get(meta, "drain"))!=0){
                var dr = real(variable_struct_get(meta, "drain")); var heal = floor((abs(dr)/100.0) * total_done);
                if (dr>0) __bm__apply_hp_delta_lerped(_pid,A, +heal);
                if (dr<0) __bm__apply_hp_delta_lerped(_pid,A, -heal);
            }
            if (variable_struct_exists(meta,"healing") && real(variable_struct_get(meta, "healing"))>0 && total_done<=0){
                var healp = real(variable_struct_get(meta, "healing"))/100.0; var amt = floor((is_struct(A)&&variable_struct_exists(A,"hp_max")?real(variable_struct_get(A,"hp_max")):0)*healp);
                __bm__apply_hp_delta_lerped(_pid,A,+amt);
            }
        }
        // Minimal meta status application
        try { __battle_apply_move_meta_effects(_pid,_step,A,D,move_id,0,meta); } catch(e){}
        // Mark last successful move for Copycat
        M.last_move_id = move_id; M.last_move_actor = actor_idx; M.last_move_success = true;
        return line;
    } else {
        // Utility effects via meta
        try { __battle_apply_move_meta_effects(_pid,_step,A,D,move_id,0,meta); } catch(e){}
        M.last_move_id = move_id; M.last_move_actor = actor_idx; M.last_move_success = true;
        return line;
    }
}

// Registration with central impl registry
try {
    if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
    try { variable_struct_set(variable_global_get("_battle_impls"), "perform_action_impl", __battle_perform_action_impl); } catch (e_reg) {}
    try { variable_struct_set(variable_global_get("_battle_impls"), "perform_action_impl_real", __battle_perform_action_impl); } catch (e_reg2) {}
} catch (e) {}
// Ensure lerped damage shim is visible in the registry in case of load-order differences
try {
    if (variable_global_exists("__battle_apply_damage_lerped") && !is_undefined(variable_global_get("__battle_apply_damage_lerped"))){
        try {
            var _regtmp = variable_global_get("_battle_impls");
            if (!variable_struct_exists(_regtmp, "__battle_apply_damage_lerped")) variable_struct_set(_regtmp, "__battle_apply_damage_lerped", variable_global_get("__battle_apply_damage_lerped"));
        } catch (e_r2) {}
    }
} catch (e_reg3) {}

// Optional explicit register function for load‑order safety
function __battle_moves_impls_register(){
    try {
        if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
        try { variable_struct_set(variable_global_get("_battle_impls"), "perform_action_impl", __battle_perform_action_impl); } catch (e_reg) {}
        try { variable_struct_set(variable_global_get("_battle_impls"), "perform_action_impl_real", __battle_perform_action_impl); } catch (e_reg2) {}
    } catch (e) {}
}

function dev_moves_impl_report() {
    try {
        if (!variable_global_exists("_move_meta") || is_undefined(global._move_meta)) {
            show_debug_message("[dev_moves_impl_report] global._move_meta not present");
            return;
        }
        var mm = global._move_meta;
        var handlers = (variable_global_exists("_battle_impls") ? global._battle_impls : undefined);
        var missing = [];
        var total = 0;

        if (is_array(mm)) {
            total = array_length(mm);
            for (var i = 0; i < total; ++i) {
                var m = mm[i];
                if (!is_struct(m)) continue;
                var has_impl = variable_struct_exists(m, "impl");
                var handler_found = false;
                if (!has_impl && !is_undefined(handlers)) {
                    if (is_array(handlers)) handler_found = (i >= 0 && i < array_length(handlers) && !is_undefined(handlers[i]));
                    else if (is_struct(handlers)) handler_found = variable_struct_exists(handlers, string(i));
                }
                if (!has_impl && !handler_found) array_push(missing, i);
            }
        } else if (is_struct(mm)) {
            // Some GM runtimes don't expose `for (k in struct)` or `struct_keys`.
            // Do a numeric scan across likely numeric string keys (move ids).
            var _limit = 1000; // safety cap for dev-runner
            if (!is_undefined(handlers) && is_array(handlers)) _limit = max(_limit, array_length(handlers));
            for (var _i = 0; _i < _limit; _i++){
                var key = string(_i);
                if (!variable_struct_exists(mm, key)) continue;
                var m = mm[key];
                if (!is_struct(m)) continue;
                var idnum = real(string(key));
                total += 1;
                var has_impl = variable_struct_exists(m, "impl");
                var handler_found = false;
                if (!has_impl && !is_undefined(handlers)) {
                    if (is_struct(handlers) && variable_struct_exists(handlers, string(idnum))) handler_found = true;
                    if (is_array(handlers) && idnum >= 0 && idnum < array_length(handlers) && !is_undefined(handlers[idnum])) handler_found = true;
                }
                if (!has_impl && !handler_found) array_push(missing, idnum);
            }
        } else {
            show_debug_message("[dev_moves_impl_report] unknown _move_meta container type");
            return;
        }

        var sample = "";
        var limit = min(array_length(missing), 40);
        for (var s = 0; s < limit; s++){
            sample += string(missing[s]);
            if (s < limit - 1) sample += ",";
        }

        show_debug_message("[dev_moves_impl_report] total_meta_slots_approx=" + string(total) + " missing_impl_count=" + string(array_length(missing)));
        if (array_length(missing) > 0) show_debug_message("[dev_moves_impl_report] sample_missing_ids=" + sample);
        else show_debug_message("[dev_moves_impl_report] static check: every move meta has an 'impl' field or a handler entry (best-effort).");
    } catch (e) {
        show_debug_message("[dev_moves_impl_report] failed: " + string(e));
    }
}