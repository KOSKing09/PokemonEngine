// Extracted battle helper implementations to modularize large battle_system.gml
// These functions are internal impls; the public API in battle_system.gml
// continues to expose the original function names and delegates to these.

function __battle_set_hp_now_impl(_ent, _val){
    var v = (is_real(_val) ? max(0, floor(_val)) : 0);
    try {
        if (is_struct(_ent)){
            if (variable_struct_exists(_ent, "hp_now")) variable_struct_set(_ent, "hp_now", v);
            if (variable_struct_exists(_ent, "hp")) variable_struct_set(_ent, "hp", v);
            // Also mirror to inner mon if present
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
                var mi = variable_struct_get(_ent, "mon");
                if (variable_struct_exists(mi, "hp_now")) variable_struct_set(mi, "hp_now", v);
                if (variable_struct_exists(mi, "hp")) variable_struct_set(mi, "hp", v);
            }
        }
    } catch (e_set){}
}

function __battle_is_fainted_impl(_ent){
    return (__battle_hp_now(_ent) <= 0);
}

function __battle_clear_fainted_if_healed_impl(_ent){
    try {
        if (__battle_hp_now(_ent) > 0){
            if (is_struct(_ent) && variable_struct_exists(_ent, "_fainted")) variable_struct_set(_ent, "_fainted", false);
            if (is_struct(_ent) && variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
                var mi2 = variable_struct_get(_ent, "mon");
                if (variable_struct_exists(mi2, "_fainted")) variable_struct_set(mi2, "_fainted", false);
            }
        }
    } catch (e_clear){}
}

function __battle_calc_damage_impl(_A, _D, _move_id, _power){
    var L = (is_real(_A.level) ? _A.level : 5);
    var Atk = __battle_stat_get(_A, "atk");
    var Def = __battle_stat_get(_D, "def");

    // base formula (Pokémon-like, simplified)
    var base = floor( (((2*L/5 + 2) * _power * Atk) / max(1,Def)) / 50 ) + 2;

    // variance 0.85..1.00
    var variance = 0.85 + random(0.15);
    var dmg = floor(base * variance);

    // crit ~ 1/24
    var crit = (irandom(23) == 0);
    var critMul = crit ? 1.5 : 1.0;
    dmg = floor(dmg * critMul);

    // mark crit for message
    var _B = __battle_ensure_slot(0); // any slot; we only read flag in same pid flow
    try { if (is_struct(_B)) variable_struct_set(_B, "_last_crit", crit); } catch (e) {}

    // clamp
    dmg = max(0, dmg);
    return dmg;
}

function __battle_apply_damage_impl(_pid, _target_index, _dmg, _mult){
    var _B = __battle_ensure_slot(_pid);
    var T = undefined;
    try {
        if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
            var _actors_arr = variable_struct_get(_B, "actor");
            if (is_real(_target_index) && _target_index >= 0 && _target_index < array_length(_actors_arr)) T = _actors_arr[_target_index];
        }
    } catch (e_gett) { T = undefined; }
    if (!is_struct(T)) return;
    // If the target has an active Protect-like flag, consume it and skip damage.
    try {
        if (variable_struct_exists(T, "_protected") && variable_struct_get(T, "_protected") == true){
            // Request protected animation for the defender
            __battle_request_animation_safe(_pid, { type: "protected", target_index: _target_index });
            // Mark announce shown and consume protection so it doesn't persist
            variable_struct_set(T, "_protected_announce_shown", true);
            variable_struct_set(T, "_protected", false);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
                try {
                    var _tname_dbg2 = "unknown";
                    if (variable_struct_exists(T, "name")) _tname_dbg2 = variable_struct_get(T, "name");
                    else if (variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon")) && variable_struct_exists(variable_struct_get(T, "mon"), "name")) _tname_dbg2 = variable_struct_get(variable_struct_get(T, "mon"), "name");
                    show_debug_message("[battle][protect][consumed_impl] pid=" + string(_pid) + " target_index=" + string(_target_index) + " name=" + string(_tname_dbg2) + " dmg=" + string(_dmg));
                } catch (e_dbg3) { show_debug_message("[battle][protect][consumed_impl] target_index=" + string(_target_index) + " dmg=" + string(_dmg)); }
            }
            return;
        }
    } catch (e_prot){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][protect] guard error: " + string(e_prot)); }

    var cur_hp = __battle_hp_now(T);
    var newhp = max(0, cur_hp - max(0, _dmg));
    __battle_set_hp_now(T, newhp);
    // Trigger visual lerp and hit SFX for this applied damage
    try {
        if (is_real(cur_hp) && is_real(newhp) && cur_hp != newhp){
            // Use provided multiplier when available, otherwise default to 1.0
            var use_mult = (is_real(_mult) ? _mult : 1.0);
            try { __battle_trigger_hit_effect(_pid, T, cur_hp, newhp, use_mult); } catch (e_th) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] trigger call failed: " + string(e_th)); }
        }
    } catch (e_any) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] apply_damage trigger error: " + string(e_any)); }
    // Clear faint flag if healed above 0
    __battle_clear_fainted_if_healed(T);
}

function __battle_move_name_impl(_code){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_name_by_id)) return scr_move_name_by_id(_code);
        return "MOVE " + string(_code);
    }
    return "--";
}

function __battle_move_power_impl(_code, _A, _D){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_power_by_id)){
            var p = scr_move_power_by_id(_code);
            if (is_real(p) && p > 0) return max(0, real(p));
            var vp = __battle_variable_move_power(_code, _A, _D);
            if (is_real(vp) && vp > 0) return vp;
            return 0;
        }
    }
    return 0;
}

function __battle_entity_weight_impl(_ent){
    try {
        if (!is_undefined(_ent) && is_struct(_ent)){
            if (variable_struct_exists(_ent, "weight") && is_real(variable_struct_get(_ent, "weight"))){
                var raww = real(variable_struct_get(_ent, "weight"));
                return __battle_weight_to_kg_impl(raww);
            }
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
                var mi = variable_struct_get(_ent, "mon");
                if (variable_struct_exists(mi, "weight") && is_real(variable_struct_get(mi, "weight"))) return __battle_weight_to_kg_impl(real(variable_struct_get(mi, "weight")));
                if (variable_struct_exists(mi, "species_id") && is_real(variable_struct_get(mi, "species_id"))){
                    var sid = variable_struct_get(mi, "species_id");
                    if (variable_global_exists("_pokemon") && is_array(global._pokemon) && sid >= 0 && sid < array_length(global._pokemon)){
                        var sp = global._pokemon[sid];
                        if (is_struct(sp) && variable_struct_exists(sp, "weight") && is_real(variable_struct_get(sp, "weight"))) return __battle_weight_to_kg_impl(real(variable_struct_get(sp, "weight")));
                    }
                }
            }
        }
    } catch (e_wt){ }
    return 0;
}

function __battle_weight_to_kg_impl(_raw){
    if (!is_real(_raw)) return 0;
    var r = real(_raw);
    if (r <= 0) return 0;
    return r / 10.0;
}

// Register impl functions into a global registry to allow battle_system.gml
// to call them without requiring duplicate script definitions.
function __battle_impls_register_all(){
    try {
        if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
        var _reg = variable_global_get("_battle_impls");
        // Populate known impl entries (add as needed)
        try { variable_struct_set(_reg, "__battle_set_hp_now_impl", __battle_set_hp_now_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_is_fainted_impl", __battle_is_fainted_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_clear_fainted_if_healed_impl", __battle_clear_fainted_if_healed_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_calc_damage_impl", __battle_calc_damage_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_apply_damage_impl", __battle_apply_damage_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_move_name_impl", __battle_move_name_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_move_power_impl", __battle_move_power_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_entity_weight_impl", __battle_entity_weight_impl); } catch (e_reg) {}
        // Optional finalize/catch hook (may be implemented elsewhere). Register a safe placeholder.
        try { variable_struct_set(_reg, "__battle_finalize_catch", undefined); } catch (e_reg) {}
        // Proxy for __battle_perform_action_impl: will call the real impl if/when it's registered
        try {
            variable_struct_set(_reg, "__battle_perform_action_impl", function(_pid,_step){
                try {
                    if (variable_global_exists("_battle_impls") && variable_struct_exists(variable_global_get("_battle_impls"), "__battle_perform_action_impl_real")){
                        var _r = variable_struct_get(variable_global_get("_battle_impls"), "__battle_perform_action_impl_real");
                        if (!is_undefined(_r)) return _r(_pid, _step);
                    }
                } catch (ee) {}
                try { if (!is_undefined(__battle_perform_action_impl)) return __battle_perform_action_impl(_pid, _step); } catch (e2) {}
                return undefined;
            });
        } catch (e_reg2) {}
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_impls][reg] failed: " + string(e)); }
}

// Run once to populate the registry eagerly when this script is first loaded
try { __battle_impls_register_all(); } catch (e_init) {}

function __bui_begin_impl(_pid,_rx,_ry,_rw,_rh){
    var _B = __battle_ensure_slot(_pid);
    var base_w = 240, base_h = 160;
    var sx = _rw / base_w;
    var sy = _rh / base_h;
    var s = min(sx, sy);
    var content_w = floor(base_w * s);
    var content_h = floor(base_h * s);
    var origin_x = _rx + floor((_rw - content_w) / 2);
    var origin_y = _ry + floor((_rh - content_h) / 2);
    try { if (is_struct(_B)) variable_struct_set(_B, "_ui", { rx: origin_x, ry: origin_y, rw: content_w, rh: content_h, base_w: base_w, base_h: base_h, s: s }); } catch (e_ui) {}
}

function __bui_end_impl(_pid){
    var _B = __battle_ensure_slot(_pid);
    try { if (is_struct(_B)) variable_struct_set(_B, "_ui", undefined); } catch (e_ui2) {}
}

// Helper: determine whether a given move id should be ignored by Copycat
function __battle_move_copycat_is_ignored(_move_id){
    try {
        if (!is_real(_move_id)) return true;
        if (!variable_global_exists("_moves") || !is_array(global._moves)) return true;
        if (!is_struct(global._moves[_move_id])) return true;
        var ident = "";
        try { if (variable_struct_exists(global._moves[_move_id], "identifier")) ident = string(variable_struct_get(global._moves[_move_id], "identifier")); } catch (e_i) {}
        ident = string_lower(string(ident));
        // Canonical identifiers that Copycat must skip (kept as identifiers so they're data-stable)
        var ignore_ids = ["assist","metronome","sleep-talk","copycat","mimic","mirror-move","mirror-coat","sketch","me-first","protect","snatch","switcheroo","trick","struggle","encore","follow-me","quick-guard","feint","focus-punch","counter","covet","destiny-bond","detect","endure","chatter","helping-hand","thief","wide-guard","quick-guard","roar","whirlwind","uproar"];
        for (var i=0; i<array_length(ignore_ids); ++i){ if (string_lower(ignore_ids[i]) == ident) return true; }
        // Additional heuristics: if move appears invalid or is flagged as non-damaging in simple metadata, optionally skip.
        // Prefer identifier-based filtering; avoid false-positives by default. If move power lookup exists and returns undefined, don't skip.
        return false;
    } catch (e_any){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat][is_ignored] err="+string(e_any)); return true; }
}

// Helper: find the move id candidate for Copycat for a given user (walks per-target history backwards)
function __battle_find_copycat_candidate(_pid, _user){
    try {
        if (!is_struct(_user)) return undefined;
        var _hist = [];
        try { if (variable_struct_exists(_user, "_last_moves") && is_array(variable_struct_get(_user, "_last_moves"))) _hist = variable_struct_get(_user, "_last_moves"); } catch (e_h) { _hist = []; }
        var _Bslot = __battle_ensure_slot(_pid);
        for (var hi = array_length(_hist)-1; hi >= 0; --hi){
            var rec = _hist[hi];
            if (!is_struct(rec) || !variable_struct_exists(rec, "move")) continue;
            var cand = variable_struct_get(rec, "move");
            if (!is_real(cand)) continue;
            // ignore based on identifier/meta
            if (__battle_move_copycat_is_ignored(cand)){
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat][preview] skipping move id="+string(cand)+" (ignored)");
                continue;
            }
            // ensure source still on-field — be robust to actor-wrapper recreation by matching _uid or inner .mon
            var src = (variable_struct_exists(rec, "src") ? variable_struct_get(rec, "src") : undefined);
            var src_ok = false;
            try {
                if (is_struct(src) && is_struct(_Bslot) && variable_struct_exists(_Bslot, "actor") && is_array(variable_struct_get(_Bslot, "actor"))){
                    var acts = variable_struct_get(_Bslot, "actor");
                    for (var ai=0; ai<array_length(acts); ++ai){
                        var act = acts[ai];
                        if (!is_struct(act)) continue;
                        var matched = false;
                        // Prefer UID matching when available
                        try {
                            if (variable_struct_exists(src, "_uid") && variable_struct_exists(act, "_uid") && is_real(variable_struct_get(src, "_uid")) && is_real(variable_struct_get(act, "_uid"))){
                                if (variable_struct_get(src, "_uid") == variable_struct_get(act, "_uid")) matched = true;
                            }
                        } catch (e_uidm) {}
                        // Fallback to direct struct equality
                        if (!matched && act == src) matched = true;
                        // Fallback to inner mon equality (sometimes stored src could be .mon)
                        if (!matched){
                            try {
                                if (variable_struct_exists(src, "mon") && variable_struct_exists(act, "mon") && variable_struct_get(src, "mon") == variable_struct_get(act, "mon")) matched = true;
                            } catch (e_mon) {}
                        }
                        if (matched){ try { if (__battle_hp_now(act) > 0) src_ok = true; else src_ok = false; } catch (e_chk) { src_ok = true; } break; }
                    }
                }
            } catch (e_s) { src_ok = false; }
            if (!src_ok){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat][preview] skipping move id="+string(cand)+" (source gone)"); continue; }
            return cand;
        }
    } catch (e_all){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat][find] error: " + string(e_all)); }
    return undefined;
}

// Debug helper: print the _last_moves history for an actor struct
function __battle_dbg_dump_last_moves(_actor){
    try {
        if (!is_struct(_actor)) { show_debug_message("[battle][dbg] actor not a struct"); return; }
        if (!variable_struct_exists(_actor, "_last_moves") || !is_array(variable_struct_get(_actor, "_last_moves"))){ show_debug_message("[battle][dbg] no _last_moves present"); return; }
        var arr = variable_struct_get(_actor, "_last_moves");
        show_debug_message("[battle][dbg] _last_moves len=" + string(array_length(arr)));
        for (var i=0;i<array_length(arr);++i){ var r=arr[i]; if (!is_struct(r)) continue; var mv=(variable_struct_exists(r,"move")?string(variable_struct_get(r,"move")):"?"); var src=(variable_struct_exists(r,"src") && variable_struct_exists(variable_struct_get(r,"src"),"name") ? variable_struct_get(variable_struct_get(r,"src"),"name") : "?"); var ts=(variable_struct_exists(r,"ts")?string(r.ts):"?"); show_debug_message("  ["+string(i)+"] move="+mv+" src="+src+" ts="+ts); }
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][dbg] dump failed: " + string(e)); }
}

function __bxu_impl(_pid,_xv){
    var _slot = __battle_ensure_slot(_pid);
    var _u = (is_struct(_slot) && variable_struct_exists(_slot, "_ui") ? variable_struct_get(_slot, "_ui") : undefined);
    if (is_undefined(_u)) return _xv;
    return floor(variable_struct_exists(_u, "rx") ? variable_struct_get(_u, "rx") + _xv * variable_struct_get(_u, "s") : _xv);
}

function __byu_impl(_pid,_yv){
    var _slot = __battle_ensure_slot(_pid);
    var _u = (is_struct(_slot) && variable_struct_exists(_slot, "_ui") ? variable_struct_get(_slot, "_ui") : undefined);
    if (is_undefined(_u)) return _yv;
    return floor(variable_struct_exists(_u, "ry") ? variable_struct_get(_u, "ry") + _yv * variable_struct_get(_u, "s") : _yv);
}

function __bwu_impl(_pid,_wv){
    var _slot = __battle_ensure_slot(_pid);
    var _u = (is_struct(_slot) && variable_struct_exists(_slot, "_ui") ? variable_struct_get(_slot, "_ui") : undefined);
    if (is_undefined(_u)) return _wv;
    return floor(_wv * (variable_struct_exists(_u, "s") ? variable_struct_get(_u, "s") : 1));
}

function __bhu_impl(_pid,_hv){
    var _slot = __battle_ensure_slot(_pid);
    var _u = (is_struct(_slot) && variable_struct_exists(_slot, "_ui") ? variable_struct_get(_slot, "_ui") : undefined);
    if (is_undefined(_u)) return _hv;
    return floor(_hv * (variable_struct_exists(_u, "s") ? variable_struct_get(_u, "s") : 1));
}


// [FORCE FIX] __battle_apply_move with full Copycat control
function __battle_apply_move(_pid, _user, _target, _move){
    if (!__battle_check_can_act(_user)) return;

    var _flags = move_get_flags(_move);

    // === DISABLED MOVE ===
    if (_user.sys_disabledMove == _move){
        dialog_queue(_user.name + " is disabled and can't use that move!");
        return;
    }

    

    // === COPYCAT: improved, per-target lookup (delegated to helper) ===
    if ((is_array(global._moves) && is_struct(global._moves[_move]) && variable_struct_exists(variable_struct_get(global._moves, _move) ? variable_struct_get(global._moves, _move) : global._moves[_move], "identifier") && (variable_struct_get(global._moves, _move).identifier == "copycat" || (is_struct(global._moves[_move]) && global._moves[_move].identifier == "copycat")))){
        // Simple Copycat semantics: copy the global last move used in the battle when available
        var _copiedMove = undefined;
        try { if (variable_global_exists("lastMoveUsed_ID") && !is_undefined(global.lastMoveUsed_ID) && is_real(global.lastMoveUsed_ID) && global.lastMoveUsed_ID >= 0 && global.lastMoveUsed_ID != _move) _copiedMove = global.lastMoveUsed_ID; } catch (e_cp) { _copiedMove = undefined; }
        if (!is_real(_copiedMove)){
            dialog_queue(_user.name + " failed to Copycat!");
            return;
        }
        var _copiedName = (is_undefined(move_get_name) ? __battle_move_name_impl(_copiedMove) : move_get_name(_copiedMove));
        dialog_queue(_user.name + " used " + _copiedName + "!");
        try { variable_struct_set(_user, "_suppress_last_move_record", true); } catch (e_s1) {}
        try { __battle_apply_move(_pid, _user, _target, _copiedMove); } catch (e_replay){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat] replay failed: " + string(e_replay)); }
        try { if (variable_struct_exists(_user, "_suppress_last_move_record")) variable_struct_set(_user, "_suppress_last_move_record", false); } catch (e_s2) {}
        return;
    }

    // === RECORD LAST MOVE USED ===
    if (!(is_array(global._moves) && is_struct(global._moves[_move]) && global._moves[_move].identifier == "copycat")){
        global.lastMoveUsed_ID = _move;
        var _moveName = move_get_name(_move);
        dialog_queue(_user.name + " used " + _moveName + "!");
        // Also record per-target history for Copycat's reference (unless suppressed)
        try {
            var _suppress = (variable_struct_exists(_user, "_suppress_last_move_record") && variable_struct_get(_user, "_suppress_last_move_record") == true);
        } catch (e_sup2){ var _suppress = false; }
        if (!(_suppress)){
            try {
                if (is_struct(_target)){
                    if (!variable_struct_exists(_target, "_last_moves") || !is_array(variable_struct_get(_target, "_last_moves"))) variable_struct_set(_target, "_last_moves", []);
                    var _arr2 = variable_struct_get(_target, "_last_moves");
                    array_push(_arr2, { move: _move, src: _user, ts: current_time });
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                        try { show_debug_message("[battle][record_last_move] target=" + string(variable_struct_exists(_target, "name") ? variable_struct_get(_target, "name") : "?") + " move=" + string(_move) + " src=" + string(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "?") + " ts=" + string(current_time)); } catch (e_dbg) {}
                    }
                    if (array_length(_arr2) > 8){ var _start2 = array_length(_arr2) - 8; var _new2 = []; for (var _ki2 = _start2; _ki2 < array_length(_arr2); ++_ki2) array_push(_new2, _arr2[_ki2]); _arr2 = _new2; }
                    variable_struct_set(_target, "_last_moves", _arr2);
                }
            } catch (e_rec2){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][record_last_move2] failed: " + string(e_rec2)); }
        }
    }

    // === DISABLE FLAG ===
    if (_flags & MOVE_FLAG_DISABLE){
        __battle_apply_disable(_target, _move);
        dialog_queue(_target.name + " was disabled!");
        return;
    }

    // === PROTECTED FLAG ===
    if (_target.sys_protected){
        dialog_queue(_target.name + " protected itself!");
        return;
    }

    // === ACCURACY CHECK ===
    if (!__battle_can_hit_target(_user, _target, _move)){
        dialog_queue(_user.name + "'s attack missed!");
        return;
    }

    // === STATUS MOVE ===
    var _power = move_get_power(_move);
    if (_power <= 0){
        __battle_apply_status_move(_pid, _user, _target, _move);
        return;
    }

    // === DAMAGE + ANIM ===
    __battle_request_animation_safe(_pid, { type: "move", user: _user, target: _target, move_id: _move });
    var _dmg = __battle_calc_damage_and_apply(_pid, _user, _target, _move);

    // === DRAIN FLAG ===
    if (_flags & MOVE_FLAG_DRAIN){
        var _heal = ceil(_dmg * 0.5);
        _user.hp = min(_user.hp + _heal, _user.hp_max);
        dialog_queue(_user.name + " absorbed health!");
    }

    _user.sys_lastMoveUsed = _move;
}


function __battle_check_can_act(_user){
    switch (_user.sys_status){
        case "freeze":
            if (irandom(3) < 3){
                dialog_queue(_user.name + " is frozen solid!");
                return false;
            } else {
                dialog_queue(_user.name + " thawed out!");
                _user.sys_status = undefined;
                return true;
            }
        case "sleep":
            if (_user.sys_status_turns > 0){
                dialog_queue(_user.name + " is fast asleep...");
                _user.sys_status_turns -= 1;
                return false;
            } else {
                dialog_queue(_user.name + " woke up!");
                _user.sys_status = undefined;
                return true;
            }
        case "paralyze":
            if (irandom(3) == 0){
                dialog_queue(_user.name + " is paralyzed! It can't move!");
                return false;
            }
            return true;
        default:
            return true;
    }
}
