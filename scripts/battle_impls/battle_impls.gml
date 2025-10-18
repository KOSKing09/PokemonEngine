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
