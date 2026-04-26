// [Battle] battle_impls — Build v0.2.0 — Updated 2025-10-18

// Extracted battle helper implementations to modularize large battle_system.gml
// These functions are internal impls; the public API in battle_system.gml
// continues to expose the original function names and delegates to these.

// --- Backward-compatible fallback shims ---
// Provide small, safe fallbacks for commonly-referenced globals that some
// move/battle code expects to exist. These prefer existing impls when
// available and otherwise provide a no-op or debug-friendly behavior.
try {
    if (is_undefined(dialog_queue)){
        function dialog_queue(_txt){
            // Status effects enqueue dialog via _pending_status_msgs; this fallback only routes text when the battle dispatcher is unavailable.
            // Prefer the new dialog dispatcher if available
            try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(0, _txt); else show_debug_message(_txt); } catch (e) { try { show_debug_message(_txt); } catch (e2) {} }
        }
    }
} catch (e_sh) {}

try {
    if (is_undefined(move_get_name)){
        function move_get_name(_id){
            try { if (!is_undefined(scr_move_name_by_id)) return scr_move_name_by_id(_id); } catch (e) {}
            try { return __battle_move_name_impl(_id); } catch (e2) { return "MOVE " + string(_id); }
        }
    }
} catch (e_mgn) {}

try {
    if (is_undefined(move_get_power)){
        function move_get_power(_id){
            try { if (!is_undefined(scr_move_power_by_id)) return scr_move_power_by_id(_id); } catch (e) {}
            try { return __battle_move_power_impl(_id, undefined, undefined); } catch (e2) { return 0; }
        }
    }
} catch (e_mgp) {}

try {
    if (is_undefined(move_get_flags)){
        function move_get_flags(_id){
            // Try to read flags from move meta if available, otherwise fall back to 0
            try {
                if (!is_undefined(__battle_get_move_meta)){
                    var _mm = __battle_get_move_meta(_id);
                    if (is_struct(_mm) && variable_struct_exists(_mm, "flags")) return variable_struct_get(_mm, "flags");
                }
            } catch (e) {}
            try { if (variable_global_exists("_move_flags") && is_array(global._move_flags) && is_real(_id) && _id >= 0 && _id < array_length(global._move_flags)) return global._move_flags[_id]; } catch (e2) {}
            return 0;
        }
    }
} catch (e_mgf) {}

// Minimal flag constants used by a few helpers. Only define if missing so
// we don't overwrite project-specific values.
try { if (!variable_global_exists("MOVE_FLAG_DISABLE")) variable_global_set("MOVE_FLAG_DISABLE", 1); } catch (e) {}
try { if (!variable_global_exists("MOVE_FLAG_DRAIN")) variable_global_set("MOVE_FLAG_DRAIN", 2); } catch (e) {}

// Safe no-op stubs for optional functions referenced by battle code.
try {
    if (is_undefined("__battle_clear_disable") || is_undefined(__battle_clear_disable))
    function __battle_clear_disable(_actor){
        if (!is_struct(_actor)) return;
        try { variable_struct_set(_actor, "sys_disabledMove", undefined); } catch (e_cl1) {}
        try { variable_struct_set(_actor, "sys_disabledTurns", 0); } catch (e_cl2) {}
        try { variable_struct_set(_actor, "sys_disabledExpiresTurn", undefined); } catch (e_cl3) {}
        try { variable_struct_set(_actor, "sys_disabledSource", undefined); } catch (e_cl4) {}
        try { variable_struct_set(_actor, "sys_disabledAppliedTurn", undefined); } catch (e_cl5) {}
        try { variable_struct_set(_actor, "sys_disabledActive", false); } catch (e_cl6) {}
        try { variable_struct_set(_actor, "sys_disabled_notified_clear", true); } catch (e_cl7) {}
    }
} catch (e_cd) {}

try {
    if (is_undefined("__battle_apply_disable") || is_undefined(__battle_apply_disable))
    function __battle_apply_disable(_pid, _user, _target, _move){
        if (!is_struct(_target)) return false;

        // If the target already has an active Disable effect, fail to extend it.
        try {
            if (variable_struct_exists(_target, "sys_disabledActive") && variable_struct_get(_target, "sys_disabledActive") == true) {
                return false;
            }
        } catch (e_chk_active) {}

        // Locate the most recent move the target executed; Disable fails without a reference.
        var _last_move = undefined;
        try {
            if (variable_struct_exists(_target, "_last_moves") && is_array(variable_struct_get(_target, "_last_moves"))){
                var _hist = variable_struct_get(_target, "_last_moves");
                for (var _di = array_length(_hist) - 1; _di >= 0; --_di){
                    var _rec = _hist[_di];
                    if (!is_struct(_rec) || !variable_struct_exists(_rec, "move")) continue;
                    var _mv = variable_struct_get(_rec, "move");
                    if (is_real(_mv)){ _last_move = _mv; break; }
                }
            }
        } catch (e_hist) { _last_move = undefined; }
        if (!is_real(_last_move)) return false;

        // Determine the active battle turn so we can set an expiry.
        var _turn_now = 0;
        try {
            var _Bslot = __battle_ensure_slot(_pid);
            if (is_struct(_Bslot) && variable_struct_exists(_Bslot, "turn_i")){
                _turn_now = max(0, floor(variable_struct_get(_Bslot, "turn_i")));
            }
        } catch (e_turn) { _turn_now = 0; }

        // Duration in Gen3: 4-7 turns inclusive. Ensure minimum duration of 4 turns.
        var _duration = irandom_range(4, 7);
        if (_duration < 4) _duration = 4;
        var _expire_turn = _turn_now + _duration;

        // Clear any stale disable data before applying a fresh one.
        __battle_clear_disable(_target);

        try { variable_struct_set(_target, "sys_disabledMove", _last_move); } catch (e_dm1) {}
        try { variable_struct_set(_target, "sys_disabledTurns", _duration); } catch (e_dm2) {}
        try { variable_struct_set(_target, "sys_disabledExpiresTurn", _expire_turn); } catch (e_dm3) {}
        try { variable_struct_set(_target, "sys_disabledSource", _move); } catch (e_dm4) {}
        try { variable_struct_set(_target, "sys_disabledAppliedTurn", _turn_now); } catch (e_dm5) {}
        try { variable_struct_set(_target, "sys_disabledActive", true); } catch (e_dm6) {}
        try { variable_struct_set(_target, "sys_disabled_notified_clear", false); } catch (e_dm7) {}
        return true;
    }
} catch (e) {}

try {
    if (is_undefined("__battle_apply_status_move") || is_undefined(__battle_apply_status_move))
    function __battle_apply_status_move(_pid, _user, _target, _move){
        if (!is_real(_move)) return false;

        // Resolve current turn counter for streak/expiry tracking.
        var _turn_now = 0;
        try {
            var _Bslot = __battle_ensure_slot(_pid);
            if (is_struct(_Bslot) && variable_struct_exists(_Bslot, "turn_i")){
                _turn_now = max(0, floor(variable_struct_get(_Bslot, "turn_i")));
            }
        } catch (e_turn) { _turn_now = 0; }

        switch (_move){
            case 182: // Protect
            case 197: // Detect shares Protect rules
                if (!is_struct(_user)) return false;

                var _last_turn = (variable_struct_exists(_user, "sys_protect_last_turn") ? variable_struct_get(_user, "sys_protect_last_turn") : -999);
                var _streak_prev = (variable_struct_exists(_user, "sys_protect_streak") ? max(0, real(variable_struct_get(_user, "sys_protect_streak"))) : 0);
                var _consecutive = 1;
                if (is_real(_last_turn) && _turn_now - _last_turn <= 1 && _streak_prev > 0){
                    _consecutive = max(1, _streak_prev + 1);
                }

                // Base success 100%, subsequent consecutive uses succeed at 1/3, 1/9, ...
                var _success = true;
                if (_consecutive > 1){
                    var _chance = power(1.0/3.0, _consecutive - 1);
                    if (random(1) >= _chance) _success = false;
                }

                try { variable_struct_set(_user, "sys_protect_last_turn", _turn_now); } catch (e_lp) {}

                if (!_success){
                    var _fail_name = (variable_struct_exists(_user, "name") ? string(variable_struct_get(_user, "name")) : "The user");
                    var _fail_move = "Protect";
                    try { _fail_move = __battle_move_name_impl(_move); } catch (e_fn) {}
                    dialog_queue(_fail_name + "'s " + string(_fail_move) + " failed!");
                    try { variable_struct_set(_user, "sys_protect_streak", 0); } catch (e_rstreak) {}
                    try { variable_struct_set(_user, "sys_protected", false); } catch (e_pf) {}
                    try { variable_struct_set(_user, "_protected", false); } catch (e_pf2) {}
                    try { variable_struct_set(_user, "sys_protected_turn", undefined); } catch (e_pf3) {}
                    try { variable_struct_set(_user, "sys_protected_source_move", undefined); } catch (e_pf4) {}
                    return false;
                }

                try { variable_struct_set(_user, "sys_protect_streak", _consecutive); } catch (e_sp) {}
                try { variable_struct_set(_user, "sys_protected", true); } catch (e_p1) {}
                try { variable_struct_set(_user, "_protected", true); } catch (e_p2) {}
                try { variable_struct_set(_user, "_protected_announce_shown", false); } catch (e_p3) {}
                try { variable_struct_set(_user, "sys_protected_turn", _turn_now); } catch (e_p4) {}
                try { variable_struct_set(_user, "sys_protected_source_move", _move); } catch (e_p5) {}
                return true;

            default:
                break;
        }

        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            show_debug_message("[battle][status_move] no handler for move=" + string(_move));
        }
        return false;
    }
} catch (e) {}
try { if (is_undefined("scr_move_meta_ailment_to_name") || is_undefined(scr_move_meta_ailment_to_name)) function scr_move_meta_ailment_to_name(_id) { return undefined; } } catch (e) {}


/// ===== Accuracy & targeting helpers =====
function __battle_actor_index_of(_ent){
    if (!is_struct(_ent)) return undefined;
    try {
        if (variable_struct_exists(_ent, "actor_index") && is_real(variable_struct_get(_ent, "actor_index"))){
            return floor(variable_struct_get(_ent, "actor_index"));
        }
    } catch (e_idx) {}
    try {
        if (variable_struct_exists(_ent, "slot") && is_real(variable_struct_get(_ent, "slot"))){
            return floor(variable_struct_get(_ent, "slot"));
        }
    } catch (e_slot) {}
    try {
        if (variable_struct_exists(_ent, "index") && is_real(variable_struct_get(_ent, "index"))){
            return floor(variable_struct_get(_ent, "index"));
        }
    } catch (e_index) {}
    return undefined;
}

function __battle_struct_matches_actor(_candidate, _target){
    if (_candidate == _target) return true;
    if (!is_struct(_candidate) || !is_struct(_target)) return false;

    var _idx_candidate = __battle_actor_index_of(_candidate);
    var _idx_target    = __battle_actor_index_of(_target);
    if (is_real(_idx_candidate) && is_real(_idx_target) && _idx_candidate == _idx_target) return true;

    try {
        if (variable_struct_exists(_candidate, "mon") && variable_struct_exists(_target, "mon")){
            var _cand_mon = variable_struct_get(_candidate, "mon");
            var _tgt_mon  = variable_struct_get(_target, "mon");
            if (is_struct(_cand_mon) && _cand_mon == _tgt_mon) return true;
        }
    } catch (e_monmatch) {}

    return false;
}

function __battle_entity_field_matches_target(_ent, _target, _field){
    if (!is_struct(_ent) || !is_string(_field)) return false;
    if (!variable_struct_exists(_ent, _field)) return false;

    var _val = variable_struct_get(_ent, _field);
    if (is_struct(_val)){
        if (__battle_struct_matches_actor(_val, _target)) return true;
        try {
            if (variable_struct_exists(_val, "target") && __battle_struct_matches_actor(variable_struct_get(_val, "target"), _target)) return true;
        } catch (e_val_target) {}
        try {
            if (variable_struct_exists(_val, "target_actor") && __battle_struct_matches_actor(variable_struct_get(_val, "target_actor"), _target)) return true;
        } catch (e_val_actor) {}
        try {
            if (variable_struct_exists(_val, "entity") && __battle_struct_matches_actor(variable_struct_get(_val, "entity"), _target)) return true;
        } catch (e_val_entity) {}
    }

    if (is_array(_val)){
        for (var _ai = 0; _ai < array_length(_val); ++_ai){
            var _item = _val[_ai];
            if (is_struct(_item) && __battle_struct_matches_actor(_item, _target)) return true;
            if (is_real(_item)){
                var _idx_target = __battle_actor_index_of(_target);
                if (is_real(_idx_target) && floor(_item) == _idx_target) return true;
            }
        }
    }

    if (is_real(_val)){
        var _idx_target_num = __battle_actor_index_of(_target);
        if (is_real(_idx_target_num) && floor(_val) == _idx_target_num) return true;
    }

    if (is_string(_val)){
        var _idx_tgt = __battle_actor_index_of(_target);
        if (is_real(_idx_tgt)){
            var _val_lc = string_lower(string(_val));
            if (_idx_tgt == 0 && (_val_lc == "player" || _val_lc == "ally")) return true;
            if (_idx_tgt == 1 && (_val_lc == "enemy" || _val_lc == "foe" || _val_lc == "opponent")) return true;
        }
    }

    return false;
}

function __battle_actor_has_ability_named(_ent, _name_lc){
    if (!is_struct(_ent) || !is_string(_name_lc) || string_length(_name_lc) <= 0) return false;
    var _needle = string_lower(string(_name_lc));

    var _ability = undefined;
    if (variable_struct_exists(_ent, "ability")) _ability = variable_struct_get(_ent, "ability");

    if (is_undefined(_ability) && variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
        var _mon = variable_struct_get(_ent, "mon");
        if (variable_struct_exists(_mon, "ability")) _ability = variable_struct_get(_mon, "ability");
    }

    if (is_string(_ability)){
        if (string_lower(string(_ability)) == _needle) return true;
    } else if (is_real(_ability)){
        try {
            if (!is_undefined(scr_ability_name_by_id)){
                var _ab_name = scr_ability_name_by_id(_ability);
                if (is_string(_ab_name) && string_lower(string(_ab_name)) == _needle) return true;
            }
        } catch (e_lookup) {}

        var _const_key = "ABILITY_" + string_upper(string_replace_all(_needle, " ", "_"));
        try {
            if (variable_global_exists(_const_key)){
                var _const_val = variable_global_get(_const_key);
                if (is_real(_const_val) && floor(_const_val) == floor(_ability)) return true;
            }
        } catch (e_const) {}
    }

    return false;
}

function __battle_has_no_guard_effect(_ent){
    return __battle_actor_has_ability_named(_ent, "no guard");
}

function __battle_attack_has_lock_on(_attacker, _defender){
    if (!is_struct(_attacker) || !is_struct(_defender)) return false;

    var _fields_attacker = ["_lock_on_target", "_lock_on_target_ref", "_lock_on_target_struct", "sys_lock_on_target", "_lock_on_target_actor", "_mind_reader_target", "sys_mind_reader_target"];
    for (var _fi = 0; _fi < array_length(_fields_attacker); ++_fi){
        if (__battle_entity_field_matches_target(_attacker, _defender, _fields_attacker[_fi])) return true;
    }

    var _fields_index = ["_lock_on_target_index", "sys_lock_on_target_index", "_mind_reader_target_index", "sys_mind_reader_target_index"];
    for (var _fj = 0; _fj < array_length(_fields_index); ++_fj){
        if (__battle_entity_field_matches_target(_attacker, _defender, _fields_index[_fj])) return true;
    }

    var _reverse_fields = ["_lock_on_source", "sys_lock_on_source", "_mind_reader_source", "sys_mind_reader_source"];
    for (var _rk = 0; _rk < array_length(_reverse_fields); ++_rk){
        if (__battle_entity_field_matches_target(_defender, _attacker, _reverse_fields[_rk])) return true;
    }

    return false;
}

function __battle_attack_has_mind_reader(_attacker, _defender){
    return __battle_attack_has_lock_on(_attacker, _defender);
}

function __battle_has_perfect_target_lock(_attacker, _defender){
    if (__battle_has_no_guard_effect(_attacker) || __battle_has_no_guard_effect(_defender)) return true;
    if (__battle_attack_has_lock_on(_attacker, _defender)) return true;
    if (__battle_attack_has_mind_reader(_attacker, _defender)) return true;
    return false;
}

function __battle_should_ignore_accuracy(_attacker, _defender, _move_id){
    return __battle_has_perfect_target_lock(_attacker, _defender);
}

function __battle_should_ignore_invuln_state(_attacker, _defender, _move_id){
    return __battle_has_perfect_target_lock(_attacker, _defender);
}


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

    // If this is a physical move and the attacker is burned, halve its attack
    try {
        var _dc = undefined;
        if (!is_undefined(scr_move_damage_class_by_id) && is_real(_move_id)){
            _dc = scr_move_damage_class_by_id(_move_id);
        } else if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
            var __mm_try = __battle_get_move_meta(_move_id);
            if (is_struct(__mm_try) && variable_struct_exists(__mm_try, "damage_class_id")) _dc = variable_struct_get(__mm_try, "damage_class_id");
        }
        // damage class 2 == physical in most datasets
        if (is_real(_dc) && floor(_dc) == 2){
            if (!is_undefined(status_system_has_status) && status_system_has_status(_A, "burn")){
                Atk = floor(Atk / 2);
            }
        }
    } catch (e_burn) {}

    // base formula (Pokémon-like, simplified)
    var base = floor( (((2*L/5 + 2) * _power * Atk) / max(1,Def)) / 50 ) + 2;

    // variance 0.85..1.00
    var variance = 0.85 + random(0.15);
    var dmg = floor(base * variance);

    // crit ~ 1/24
    // crit: base chance ~1/24; allow per-move override via move_meta.crit_rate
    var crit = false;
    try {
        var crit_rate_level = 0;
        // Prefer move meta accessor if present
        if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
            try {
                var _mm = __battle_get_move_meta(_move_id);
                if (is_struct(_mm) && variable_struct_exists(_mm, "crit_rate") && is_real(variable_struct_get(_mm, "crit_rate"))) crit_rate_level = variable_struct_get(_mm, "crit_rate");
            } catch (e_mm) { crit_rate_level = 0; }
        } else if (variable_global_exists("_move_meta") && is_array(global._move_meta) && is_struct(global._move_meta[_move_id])){
            try { var _mm2 = global._move_meta[_move_id]; if (variable_struct_exists(_mm2, "crit_rate") && is_real(variable_struct_get(_mm2, "crit_rate"))) crit_rate_level = variable_struct_get(_mm2, "crit_rate"); } catch (e_m2) { crit_rate_level = 0; }
        }
        // Map crit_rate_level to a sampling denominator (conservative mapping)
        var denom = 24;
        if (is_real(crit_rate_level)){
            if (crit_rate_level <= 0) denom = 24;
            else if (crit_rate_level == 1) denom = 8; // higher crit chance
            else denom = 2; // very high crit chance for larger values
        }
        crit = (irandom(max(1, denom) - 1) == 0);
    } catch (e_crit) { crit = (irandom(23) == 0); }
    var critMul = crit ? 1.5 : 1.0;
    dmg = floor(dmg * critMul);

    // Weather-based damage adjustments
    try {
        var _pid_weather = 0;
        var _found_pid = false;
        if (variable_global_exists("sys_battles") && is_array(global.sys_battles)){
            for (var __pi = 0; __pi < array_length(global.sys_battles); ++__pi){
                var _slotw = global.sys_battles[__pi];
                if (!is_struct(_slotw)) continue;
                if (!variable_struct_exists(_slotw, "actor") || !is_array(variable_struct_get(_slotw, "actor"))) continue;
                var __acts_w = variable_struct_get(_slotw, "actor");
                for (var __pj = 0; __pj < array_length(__acts_w); ++__pj){
                    if (is_struct(__acts_w[__pj]) && __acts_w[__pj] == _A){ _pid_weather = __pi; _found_pid = true; break; }
                }
                if (_found_pid) break;
            }
        }
        var _wrec = undefined;
        if (_found_pid && variable_global_exists("sys_battles") && is_array(global.sys_battles) && _pid_weather >= 0 && _pid_weather < array_length(global.sys_battles)){
            var _slot_weather = global.sys_battles[_pid_weather];
            if (is_struct(_slot_weather)){
                if (variable_struct_exists(_slot_weather, "_field") && is_struct(variable_struct_get(_slot_weather, "_field"))){
                    var _field_weather = variable_struct_get(_slot_weather, "_field");
                    if (variable_struct_exists(_field_weather, "weather")) _wrec = variable_struct_get(_field_weather, "weather");
                } else if (variable_struct_exists(_slot_weather, "_weather")){
                    _wrec = variable_struct_get(_slot_weather, "_weather");
                }
            }
        }
        var _normalize_weather_id = function(_wid_raw){
            var raw = string_lower(string(_wid_raw));
            switch (raw){
                case "sun": case "sunny": case "sunny-day": case "sunlight": return "sun";
                case "harsh-sun": case "harsh sunlight": case "harsh-sunlight": return "harsh-sun";
                case "rain": case "rain-dance": return "rain";
                case "sandstorm": case "sand storm": return "sandstorm";
                case "hail": case "hailstorm": return "hail";
                case "snow": case "snowscape": return "snow";
                case "fog": return "fog";
                default: return raw;
            }
        };
        var _type_id_lookup = function(_name){
            var key = string_lower(string(_name));
            if (variable_global_exists("TYPE_ID_BY_NAME")){
                var _map = variable_global_get("TYPE_ID_BY_NAME");
                if (ds_exists(_map, ds_type_map)){
                    var val = ds_map_find_value(_map, key);
                    if (is_real(val)) return floor(val);
                }
            }
            switch (key){
                case "fire": return 10;
                case "water": return 11;
            }
            return -1;
        };
        var _weather_active = function(_state){
            if (!is_struct(_state)) return false;
            if (variable_struct_exists(_state, "active")){
                if (variable_struct_get(_state, "active") != true) return false;
            }
            var wid_chk = _normalize_weather_id(variable_struct_exists(_state, "id") ? variable_struct_get(_state, "id") : "");
            if (string_length(wid_chk) <= 0) return false;
            if (variable_struct_exists(_state, "turns_remaining") && is_real(variable_struct_get(_state, "turns_remaining"))){
                var _rem_chk = variable_struct_get(_state, "turns_remaining");
                var _inf_chk = (variable_struct_exists(_state, "infinite") && variable_struct_get(_state, "infinite") == true);
                if (_rem_chk == 0 && !_inf_chk) return false;
            }
            return true;
        };
        if (_weather_active(_wrec)){
            var _wid_norm = _normalize_weather_id(variable_struct_exists(_wrec, "id") ? variable_struct_get(_wrec, "id") : "");
            var _mv_type = -1;
            if (!is_undefined(scr_move_type_id_by_id) && is_real(_move_id)) _mv_type = scr_move_type_id_by_id(_move_id);
            var _fire_id = _type_id_lookup("fire");
            var _water_id = _type_id_lookup("water");
            if (_wid_norm == "sun" || _wid_norm == "harsh-sun"){
                if (_mv_type == _fire_id) dmg = floor(dmg * 1.5);
                else if (_mv_type == _water_id) dmg = floor(max(0, dmg * 0.5));
            } else if (_wid_norm == "rain"){
                if (_mv_type == _fire_id) dmg = floor(max(0, dmg * 0.5));
                else if (_mv_type == _water_id) dmg = floor(dmg * 1.5);
            }
        }
    } catch (e_weather_dmg) {}

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
    var newhp = max(0, cur_hp - max(0, round(_dmg * (is_real(_mult) ? _mult : 1))));
    __battle_set_hp_now(T, newhp);
    // If this damage caused a faint, mark the entity and inner mon as fainted
    // and schedule a pending party open on the battle slot so the UI can prompt
    // the player to choose a replacement after dialog closes.
    try {
        if (cur_hp > 0 && newhp <= 0){
            var _dbg_trainer = false;
            try {
                if (variable_global_exists("DATA_DEBUG_TRAINER")) _dbg_trainer = (global.DATA_DEBUG_TRAINER == true);
                else if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) _dbg_trainer = true;
            } catch (e_dbgflag_dmg) { _dbg_trainer = false; }
            if (_dbg_trainer){
                try {
                    var _fname_dbg = "<unknown>";
                    if (is_struct(T) && variable_struct_exists(T, "name")) _fname_dbg = string(variable_struct_get(T, "name"));
                    else if (is_struct(T) && variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon")) && variable_struct_exists(variable_struct_get(T, "mon"), "name")) _fname_dbg = string(variable_struct_get(variable_struct_get(T, "mon"), "name"));
                    show_debug_message("[battle][trainer][faint] marking actor fainted=" + _fname_dbg + ", hp_before=" + string(cur_hp) + ", hp_after=" + string(newhp));
                } catch (e_dbg_faint_actor) {}
            }
            if (is_struct(T)) variable_struct_set(T, "_fainted", true);
            if (is_struct(T) && variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon"))){
                var __mi_f = variable_struct_get(T, "mon");
                if (_dbg_trainer){
                    try { show_debug_message("[battle][trainer][faint] inner mon struct tagged"); } catch (e_dbg_faint_mon) {}
                }
                variable_struct_set(__mi_f, "_fainted", true);
            }
            // Sync trainer party entry (when present) so follow-up alive checks see the fainted state.
            try {
                var _B_sync = __battle_ensure_slot(_pid);
                if (is_struct(_B_sync) && variable_struct_exists(_B_sync, "_trainer_party")){
                    var _party_sync = variable_struct_get(_B_sync, "_trainer_party");
                    if (is_array(_party_sync)){
                        for (var __tsi = 0; __tsi < array_length(_party_sync); ++__tsi){
                            var __tmon = _party_sync[__tsi];
                            if (!is_struct(__tmon)) continue;
                            if (__tmon == T || (variable_struct_exists(T, "mon") && __tmon == variable_struct_get(T, "mon"))){
                                __battle_set_hp_now(__tmon, newhp);
                                try { variable_struct_set(__tmon, "_fainted", true); } catch (e_sync_flag) {}
                                break;
                            }
                        }
                    }
                }
            } catch (e_sync_party) {}
            // Schedule pending party open on the battle slot so it's handled in battle_system
            // Only schedule a forced party open when the fainted actor is the player's active Pokémon
            // (actor index 0). This prevents the party UI from opening when an enemy faints.
            try {
                var _B_sch = __battle_ensure_slot(_pid);
                if (is_struct(_B_sch)){
                    // Only open party UI for player's side (target_index == 0)
                    if (is_real(_target_index) && _target_index == 0){
                        variable_struct_set(_B_sch, "_pending_open_party", true);
                        try {
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_impls] scheduled _pending_open_party for pid=" + string(_pid));
                        } catch (e_dbg_po) {}
                    }
                    // Ensure the faint dialog has at least one frame to render before
                    // the party UI may open: set a short delay marker the battle
                    // update loop will honor.
                    // Give the faint dialog a slightly longer window to render before
                    // the party UI opens. Increase from 120ms to 300ms to reduce
                    // chances the party menu occludes the faint message on slow
                    // machines or when multiple UI updates occur in the same frame.
                    try { variable_struct_set(_B_sch, "_pending_open_party_delay_until", current_time + 300);
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_impls] set _pending_open_party_delay_until=" + string(current_time + 300) + " pid=" + string(_pid));
                    } catch (e_pd) {}
                    // Queue faint text to show last; do not open immediately.
                        try {
                            var _fnt_name = "(Unknown)";
                            if (variable_struct_exists(T, "name")) _fnt_name = variable_struct_get(T, "name");
                            else if (variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon")) && variable_struct_exists(variable_struct_get(T, "mon"), "name")) _fnt_name = variable_struct_get(variable_struct_get(T, "mon"), "name");
                            // Queue as a faint-gated dialog so it shows after other pending messages
                            if (!is_undefined(__battle_try_enqueue_faint_dialog)) __battle_try_enqueue_faint_dialog(_pid, _B_sch, string(_fnt_name) + " fainted!", string(_fnt_name) + " fainted!");
                        } catch (e_sd_local) {}
                    // Do NOT set _faint_pending here; allow other messages to show before faint.
                    // Store a reference to the fainted actor's inner mon (preferred) so selection
                    // mapping can resolve correctly even after the party is reordered.
                    var _refm = T;
                    if (variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon"))) _refm = variable_struct_get(T, "mon");
                    variable_struct_set(_B_sch, "_pending_open_party_next_mon_ref", _refm);
                    try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){ var _nmref = "<unknown>"; try { if (is_struct(_refm) && variable_struct_exists(_refm, "name")) _nmref = string(variable_struct_get(_refm, "name")); } catch(e_){} show_debug_message("[battle_impls] _pending_open_party_next_mon_ref set for pid=" + string(_pid) + ", ref_preview=" + _nmref); } } catch(e_dbgref) {}
                    // Preserve current UI menu/selection so we can restore it after forced swap
                    try {
                        if (variable_struct_exists(_B_sch, "sys_ui") && is_struct(variable_struct_get(_B_sch, "sys_ui"))){
                            var _su = variable_struct_get(_B_sch, "sys_ui");
                            // Save menu and selection coordinates
                            if (variable_struct_exists(_su, "menu")) variable_struct_set(_B_sch, "_pending_open_party_prev_menu", variable_struct_get(_su, "menu"));
                            if (variable_struct_exists(_su, "selX")) variable_struct_set(_B_sch, "_pending_open_party_prev_selX", variable_struct_get(_su, "selX"));
                            if (variable_struct_exists(_su, "selY")) variable_struct_set(_B_sch, "_pending_open_party_prev_selY", variable_struct_get(_su, "selY"));
                        }
                    } catch (e_saveui) {}
                    // Also clear any deferred turn resume so we don't accidentally continue
                    // the turn while the party selection is pending.
                    variable_struct_set(_B_sch, "_defer_turn_until_no_dialog", false);
                }
            } catch (e_sch) {}
        }
    } catch (e_pf){}
    // Trigger visual lerp and hit SFX for this applied damage
    try {
        if (is_real(cur_hp) && is_real(newhp) && cur_hp != newhp){
            // Use provided multiplier when available, otherwise default to 1.0
            var use_mult = (is_real(_mult) ? _mult : 1.0);
            try { __battle_trigger_hit_effect(_pid, T, cur_hp, newhp, use_mult); } catch (e_th) { /* removed noisy sound debug */ }
        }
    } catch (e_any) { /* removed noisy sound debug */ }
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

function __battle_find_pid_by_slot_impl(_B){
    if (variable_global_exists("sys_battles") && is_array(global.sys_battles)){
        for (var _i = 0; _i < array_length(global.sys_battles); _i++){
            if (global.sys_battles[_i] == _B) return _i;
        }
    }
    return 0;
}

function __battle_prepare_caught_mon_impl(_pid, _caught){
    if (!is_struct(_caught)) return _caught;

    var growth_id = undefined;
    if (variable_struct_exists(_caught, "growth_id") && is_real(variable_struct_get(_caught, "growth_id"))) growth_id = variable_struct_get(_caught, "growth_id");
    else if (variable_struct_exists(_caught, "growth") && is_real(variable_struct_get(_caught, "growth"))) growth_id = variable_struct_get(_caught, "growth");
    else if (variable_struct_exists(_caught, "growth_rate_id") && is_real(variable_struct_get(_caught, "growth_rate_id"))) growth_id = variable_struct_get(_caught, "growth_rate_id");

    var lvl = 1;
    if (variable_struct_exists(_caught, "level") && is_real(variable_struct_get(_caught, "level"))) lvl = floor(variable_struct_get(_caught, "level"));
    else if (variable_struct_exists(_caught, "lvl") && is_real(variable_struct_get(_caught, "lvl"))) lvl = floor(variable_struct_get(_caught, "lvl"));

    if (!is_undefined(scr_get_exp_for_level) && is_real(growth_id)){
        var cur_exp = scr_get_exp_for_level(growth_id, lvl);
        if (is_real(cur_exp) && cur_exp >= 0) variable_struct_set(_caught, "exp", cur_exp);
        var next_exp = scr_get_exp_for_level(growth_id, min(100, lvl + 1));
        if (is_real(next_exp) && next_exp > 0) variable_struct_set(_caught, "exp_next", next_exp);
    }
    if (!variable_struct_exists(_caught, "exp")) variable_struct_set(_caught, "exp", 0);
    if (!variable_struct_exists(_caught, "exp_next")) variable_struct_set(_caught, "exp_next", max(20, lvl * lvl * 2));
    if (!variable_struct_exists(_caught, "pokeball_item_id") || !is_real(variable_struct_get(_caught, "pokeball_item_id")) || variable_struct_get(_caught, "pokeball_item_id") <= 0){
        variable_struct_set(_caught, "pokeball_item_id", 4);
    }
    return _caught;
}

// Final catch handoff: normalize the caught mon, route it into party or PC
// storage, and show the resolved destination in dialog. The item sprite path
// stays item-id based here because the mon stores a canonical `pokeball_item_id`.
function __battle_finalize_catch_impl(_B, _caught){
    if (!is_struct(_B)) return { ok:false, location:"none" };

    var _pid = __battle_find_pid_by_slot_impl(_B);
    var _mon = __battle_prepare_caught_mon_impl(_pid, _caught);
    var _store = { ok:false, location:"none", mon:_mon };
    if (is_struct(_mon) && !is_undefined(party_model_store_caught_mon)) _store = party_model_store_caught_mon(_pid, _mon);

    var _caught_name = "Pokemon";
    if (is_struct(_mon) && variable_struct_exists(_mon, "name")) _caught_name = string(variable_struct_get(_mon, "name"));
    else if (is_struct(_mon) && variable_struct_exists(_mon, "nickname") && string_length(string(variable_struct_get(_mon, "nickname"))) > 0) _caught_name = string(variable_struct_get(_mon, "nickname"));
    else if (is_array(_B.actor) && array_length(_B.actor) > 1 && is_struct(_B.actor[1]) && variable_struct_exists(_B.actor[1], "name")) _caught_name = string(variable_struct_get(_B.actor[1], "name"));

    var _msg = "Gotcha!\nYou caught " + _caught_name + "!";
    if (is_struct(_store) && variable_struct_exists(_store, "ok") && _store.ok){
        if (variable_struct_exists(_store, "location") && string(variable_struct_get(_store, "location")) == "pc"){
            var _box_num = (variable_struct_exists(_store, "box_index") && is_real(variable_struct_get(_store, "box_index"))) ? floor(variable_struct_get(_store, "box_index")) + 1 : 1;
            _msg += "\n" + _caught_name + " was sent to Box " + string(_box_num) + ".";
        }
    } else {
        _msg += "\nStorage failed; the catch was not persisted.";
    }

    try {
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, _msg);
        else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, _msg, _msg, "any");
    } catch (e_msg) {}

    _B.result = "caught";
    _B._pending_close = true;

    try {
        var _stop_res = (variable_struct_exists(_B, "_battle_music") ? variable_struct_get(_B, "_battle_music") : undefined);
        var _bgm_handle = (variable_struct_exists(_B, "_bgm_handle") ? variable_struct_get(_B, "_bgm_handle") : undefined);
        if (!is_undefined(audio_stop_sound)) audio_stop_sound(_stop_res);
        else if (!is_undefined(_bgm_handle)) __battle_audio_stop_handle(_bgm_handle);
        else if (!is_undefined(audio_stop_all)) audio_stop_all();
    } catch (e_stop) {}
    try { variable_struct_set(_B, "_bgm_handle", undefined); } catch (e_bgm_clear) {}
    try {
        var _def_music = (variable_struct_exists(_B, "_battle_defeated_music") ? variable_struct_get(_B, "_battle_defeated_music") : undefined);
        if (!is_undefined(_def_music)){
            var _def_handle = __battle_sound_play_safe(_def_music);
            variable_struct_set(_B, "_defeated_handle", _def_handle);
        }
    } catch (e_defmusic) {}

    if (variable_struct_exists(_B, "_catch_anim") && is_struct(variable_struct_get(_B, "_catch_anim"))){
        var _A = variable_struct_get(_B, "_catch_anim");
        variable_struct_set(_A, "phase", "caught");
        variable_struct_set(_A, "phase_start", current_time);
        variable_struct_set(_A, "persistent", true);
        variable_struct_set(_B, "_catch_anim", _A);
    }
    return _store;
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
        try { variable_struct_set(_reg, "__battle_finalize_catch", __battle_finalize_catch_impl); } catch (e_reg) {}
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
    // Read global flag masks into locals to avoid bare global symbol references
    var FLAG_DISABLE = (variable_global_exists("MOVE_FLAG_DISABLE") ? variable_global_get("MOVE_FLAG_DISABLE") : 1);
    var FLAG_DRAIN = (variable_global_exists("MOVE_FLAG_DRAIN") ? variable_global_get("MOVE_FLAG_DRAIN") : 2);

    var _moveEntry = undefined;
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move) && _move >= 0 && _move < array_length(global._moves)){
            _moveEntry = global._moves[_move];
        }
    } catch (e_me) { _moveEntry = undefined; }
    var _moveIdent = "";
    try { if (is_struct(_moveEntry) && variable_struct_exists(_moveEntry, "identifier")) _moveIdent = string_lower(string(variable_struct_get(_moveEntry, "identifier"))); } catch (e_ident) { _moveIdent = ""; }

    var _is_disable_move = (is_real(_move) && _move == 50) || (_moveIdent == "disable");
    var _is_protect_like = (is_real(_move) && (_move == 182 || _move == 197));

    var _turn_now = 0;
    try {
        var _slot_turn = __battle_ensure_slot(_pid);
        if (is_struct(_slot_turn) && variable_struct_exists(_slot_turn, "turn_i")){
            _turn_now = max(0, floor(variable_struct_get(_slot_turn, "turn_i")));
        }
    } catch (e_turn_lookup) { _turn_now = 0; }

    // Clear expired Protect/Disable state on the acting user before processing their new move.
    if (is_struct(_user)){
        // Protect persistence only lasts through the turn it was applied.
        try {
            var _prot_turn = (variable_struct_exists(_user, "sys_protected_turn") ? variable_struct_get(_user, "sys_protected_turn") : undefined);
            if (is_real(_prot_turn) && _turn_now > _prot_turn){
                variable_struct_set(_user, "sys_protected", false);
                variable_struct_set(_user, "_protected", false);
            }
        } catch (e_clear_prot) {}

        if (!_is_protect_like){
            try { variable_struct_set(_user, "sys_protect_streak", 0); } catch (e_rstreak) {}
        }

        // Maintain Disable countdown/expiry on the acting user.
        var _disableExpire = undefined;
        var _disableActive = false;
        try { if (variable_struct_exists(_user, "sys_disabledExpiresTurn")) _disableExpire = variable_struct_get(_user, "sys_disabledExpiresTurn"); } catch (e_de) {}
        try { if (variable_struct_exists(_user, "sys_disabledActive")) _disableActive = (variable_struct_get(_user, "sys_disabledActive") == true); } catch (e_da) { _disableActive = false; }
        if (is_real(_disableExpire) && _disableActive){
            var _disableNotified = false;
            try { if (variable_struct_exists(_user, "sys_disabled_notified_clear")) _disableNotified = (variable_struct_get(_user, "sys_disabled_notified_clear") == true); } catch (e_notf) { _disableNotified = false; }
            if (_turn_now >= _disableExpire){
                if (!_disableNotified){
                    var _uname_clear = (variable_struct_exists(_user, "name") ? string(variable_struct_get(_user, "name")) : "The Pokémon");
                    dialog_queue(_uname_clear + " is no longer disabled!");
                }
                __battle_clear_disable(_user);
            } else {
                var _remaining = max(0, _disableExpire - _turn_now);
                try { variable_struct_set(_user, "sys_disabledTurns", _remaining); } catch (e_rem) {}
                try { variable_struct_set(_user, "sys_disabled_notified_clear", false); } catch (e_not_reset) {}
            }
        } else if (!is_real(_disableExpire) || !_disableActive){
            __battle_clear_disable(_user);
        }
    }

    if (_is_disable_move) _flags |= FLAG_DISABLE;

    // === DISABLED MOVE ===
    var _disabledMove = undefined;
    try { if (is_struct(_user) && variable_struct_exists(_user, "sys_disabledMove")) _disabledMove = variable_struct_get(_user, "sys_disabledMove"); } catch (e_dm) { _disabledMove = undefined; }
    if (is_real(_disabledMove) && _disabledMove == _move){
        var _uname = (is_struct(_user) && variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user");
        dialog_queue(_uname + " is disabled and can't use that move!");
        return;
    }

    

    // === COPYCAT: improved, per-target lookup (delegated to helper) ===
    var _isCopycatMove = false;
    try { if (is_struct(_moveEntry) && variable_struct_exists(_moveEntry, "identifier") && string_lower(variable_struct_get(_moveEntry, "identifier")) == "copycat") _isCopycatMove = true; } catch (e_ic) { _isCopycatMove = false; }
    if (_isCopycatMove){
        // Simple Copycat semantics: copy the global last move used in the battle when available
        var _copiedMove = undefined;
        try { if (variable_global_exists("lastMoveUsed_ID") && !is_undefined(global.lastMoveUsed_ID) && is_real(global.lastMoveUsed_ID) && global.lastMoveUsed_ID >= 0 && global.lastMoveUsed_ID != _move) _copiedMove = global.lastMoveUsed_ID; } catch (e_cp) { _copiedMove = undefined; }
        if (!is_real(_copiedMove)){
            dialog_queue(_user.name + " failed to Copycat!");
            return;
        }
        var _copiedName = (is_undefined(move_get_name) ? __battle_move_name_impl(_copiedMove) : move_get_name(_copiedMove));
        try { variable_struct_set(_user, "_suppress_last_move_record", true); } catch (e_s1) {}
        try { __battle_apply_move(_pid, _user, _target, _copiedMove); } catch (e_replay){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat] replay failed: " + string(e_replay)); }
        try { if (variable_struct_exists(_user, "_suppress_last_move_record")) variable_struct_set(_user, "_suppress_last_move_record", false); } catch (e_s2) {}
        return;
    }

    // === RECORD LAST MOVE USED ===
    if (!_isCopycatMove){
        global.lastMoveUsed_ID = _move;
        var _moveName = move_get_name(_move);
        // Prevent duplicate "used X!" dialogs when the same actor/move enqueues it
        // multiple times in quick succession (copycat/replay/multi-hit/faint ordering).
        var _should_enqueue_used = true;
        try {
            var _last_id = (variable_struct_exists(_user, "_last_move_dialog_id") ? variable_struct_get(_user, "_last_move_dialog_id") : undefined);
            var _last_ts = (variable_struct_exists(_user, "_last_move_dialog_ts") ? variable_struct_get(_user, "_last_move_dialog_ts") : -9999999);
            if (is_real(_last_id) && _last_id == _move && is_real(_last_ts) && abs(_last_ts - current_time) < 500) _should_enqueue_used = false;
        } catch (e_dup) { _should_enqueue_used = true; }
        if (_should_enqueue_used) {
            dialog_queue(_user.name + " used " + _moveName + "!");
            try { variable_struct_set(_user, "_last_move_dialog_id", _move); variable_struct_set(_user, "_last_move_dialog_ts", current_time); } catch (e_setd) {}
        }
        // Also record per-target history for Copycat's reference (unless suppressed)
        try {
            var _suppress = (variable_struct_exists(_user, "_suppress_last_move_record") && variable_struct_get(_user, "_suppress_last_move_record") == true);
        } catch (e_sup2){ var _suppress = false; }

        // Record per-user history so Encore/Disable/copy effects can inspect last actions.
        try {
            if (is_struct(_user) && is_real(_move)){
                variable_struct_set(_user, "sys_last_move_used", _move);
                variable_struct_set(_user, "sys_last_move_used_ts", current_time);
                var _hist_user = [];
                if (variable_struct_exists(_user, "_last_moves_used") && is_array(variable_struct_get(_user, "_last_moves_used"))){
                    _hist_user = variable_struct_get(_user, "_last_moves_used");
                }
                var _t_idx_record = undefined;
                if (is_struct(_target)){
                    if (variable_struct_exists(_target, "actor_index")) _t_idx_record = variable_struct_get(_target, "actor_index");
                    else if (variable_struct_exists(_target, "slot")) _t_idx_record = variable_struct_get(_target, "slot");
                }
                array_push(_hist_user, { move: _move, target: _target, target_index: _t_idx_record, ts: current_time });
                if (array_length(_hist_user) > 8){
                    var _start_used = array_length(_hist_user) - 8;
                    var _trim_used = [];
                    for (var _ui = _start_used; _ui < array_length(_hist_user); ++_ui){ array_push(_trim_used, _hist_user[_ui]); }
                    _hist_user = _trim_used;
                }
                variable_struct_set(_user, "_last_moves_used", _hist_user);
            }
        } catch (e_user_hist){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][record_last_move][user] error=" + string(e_user_hist)); }

        if (!(_suppress)){
            try {
                if (is_struct(_target)){
                    if (!variable_struct_exists(_target, "_last_moves") || !is_array(variable_struct_get(_target, "_last_moves"))) variable_struct_set(_target, "_last_moves", []);
                    var _arr2 = variable_struct_get(_target, "_last_moves");
                    array_push(_arr2, { move: _move, src: _user, ts: current_time });
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                        try { if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][record_last_move] target=" + string(variable_struct_exists(_target, "name") ? variable_struct_get(_target, "name") : "?") + " move=" + string(_move) + " src=" + string(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "?") + " ts=" + string(current_time)); } catch (e_dbg) {}
                    }
                    if (array_length(_arr2) > 8){ var _start2 = array_length(_arr2) - 8; var _new2 = []; for (var _ki2 = _start2; _ki2 < array_length(_arr2); ++_ki2) array_push(_new2, _arr2[_ki2]); _arr2 = _new2; }
                    variable_struct_set(_target, "_last_moves", _arr2);
                }
            } catch (e_rec2){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][record_last_move2] failed: " + string(e_rec2)); }
        }
    }

    if (_is_protect_like){
        __battle_apply_status_move(_pid, _user, _target, _move);
        return;
    }

    // === DISABLE FLAG ===
    if ((_flags & FLAG_DISABLE) != 0){
        var _disabled_ok = __battle_apply_disable(_pid, _user, _target, _move);
        if (_disabled_ok){
            var _tname_disable = (is_struct(_target) && variable_struct_exists(_target, "name") ? string(variable_struct_get(_target, "name")) : "The target");
            dialog_queue(_tname_disable + " was disabled!");
        } else {
            dialog_queue("But it failed!");
        }
        return;
    }

    // === PROTECTED FLAG ===
    var _t_protected = false;
    try { if (is_struct(_target) && variable_struct_exists(_target, "sys_protected") && variable_struct_get(_target, "sys_protected") == true) _t_protected = true; } catch (e_tp) { _t_protected = false; }
    if (_t_protected){
        try {
            if (is_real(_move) && (_move == 467 || _move == 566)){
                _t_protected = false;
                try { variable_struct_set(_target, "sys_protected", false); } catch (e_bp) {}
            }
        } catch (e_pf) {}
    }
    if (_t_protected){
        var _tname = (is_struct(_target) && variable_struct_exists(_target, "name") ? variable_struct_get(_target, "name") : "The target");
        var _mv_blocked_name = (is_struct(_moveEntry) && variable_struct_exists(_moveEntry, "name") ? string(variable_struct_get(_moveEntry, "name")) : move_get_name(_move));
        if (!is_string(_mv_blocked_name) || string_length(_mv_blocked_name) <= 0) _mv_blocked_name = "The move";
        dialog_queue(_mv_blocked_name + " had no effect!");
        try { variable_struct_set(_target, "sys_protected", false); } catch (e_cpflag) {}
        try { variable_struct_set(_target, "_protected", false); } catch (e_cpflag2) {}
        try { variable_struct_set(_target, "sys_protected_turn", undefined); } catch (e_cpflag3) {}
        return;
    }


    // === SEMI-INVULNERABLE CHECK ===
    try {
        if (is_struct(_target) && variable_struct_exists(_target, "_semi_invuln") && !is_undefined(variable_struct_get(_target, "_semi_invuln"))){
            var _phase = string_lower(string(variable_struct_get(_target, "_semi_invuln")));
            var _mname = "";
            try { _mname = string_lower(__battle_move_name(_move)); } catch (e_mn) { _mname = ""; }
            var _allow = false; var _mult = 1.0;
            var _state_msg = "";
            var _target_name_si = (is_struct(_target) && variable_struct_exists(_target, "name") ? string(variable_struct_get(_target, "name")) : "The target");
            if (_phase == "fly" || _phase == "bounce" || _phase == "skydrop"){
                if (string_pos("gust", _mname) > 0 || string_pos("twister", _mname) > 0) { _allow = true; _mult = 2.0; }
                _state_msg = _target_name_si + " is high in the sky!";
            } else if (_phase == "dig"){
                if (string_pos("earthquake", _mname) > 0 || string_pos("magnitude", _mname) > 0) { _allow = true; _mult = 2.0; }
                _state_msg = _target_name_si + " is underground!";
            } else if (_phase == "dive"){
                if (string_pos("surf", _mname) > 0 || string_pos("whirlpool", _mname) > 0) { _allow = true; _mult = 2.0; }
                _state_msg = _target_name_si + " is deep underwater!";
            } else if (_phase == "vanish"){
                _allow = false;
                _state_msg = _target_name_si + " vanished instantly!";
            }

            var _bypass_invuln = false;
            try {
                if (!is_undefined(__battle_should_ignore_invuln_state)){
                    _bypass_invuln = __battle_should_ignore_invuln_state(_user, _target, _move);
                }
            } catch (e_bypass) { _bypass_invuln = false; }
            if (_bypass_invuln){
                _allow = true;
                _state_msg = "";
                _mult = max(1.0, _mult);
            }

            if (!_allow){
                if (is_string(_state_msg) && string_length(_state_msg) > 0) dialog_queue(_state_msg);
                var _miss_name = (is_struct(_user) && variable_struct_exists(_user, "name") ? string(variable_struct_get(_user, "name")) : "The attacker");
                dialog_queue(_miss_name + "'s attack missed!");
                return;
            } else {
                var _semi_invuln_mult = _mult;
                try { variable_struct_set(_user, "__semi_mult_tmp", _semi_invuln_mult); } catch (e_sm) {}
            }
        }
    } catch (e_si) {}
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
    var _dmg = __battle_calc_damage(_user, _target, _move, move_get_power(_move));
    // Resolve target index robustly: prefer explicit actor_index, then 'slot',
    // then attempt to locate the target object in the battle slot actor array.
    var _tidx = undefined;
    try {
        if (is_struct(_target) && variable_struct_exists(_target, "actor_index") && is_real(variable_struct_get(_target, "actor_index"))) _tidx = variable_struct_get(_target, "actor_index");
        else if (is_struct(_target) && variable_struct_exists(_target, "slot") && is_real(variable_struct_get(_target, "slot"))) _tidx = variable_struct_get(_target, "slot");
        else {
            var _Btmp_try = __battle_ensure_slot(_pid);
            if (is_struct(_Btmp_try) && variable_struct_exists(_Btmp_try, "actor") && is_array(variable_struct_get(_Btmp_try, "actor")) && is_struct(_target)){
                var __actor_arr_try = variable_struct_get(_Btmp_try, "actor");
                for (var _ai_try = 0; _ai_try < array_length(__actor_arr_try); ++_ai_try){ if (is_struct(__actor_arr_try[_ai_try]) && __actor_arr_try[_ai_try] == _target){ _tidx = _ai_try; break; } }
            }
        }
    } catch (e_ti) { _tidx = undefined; }
    if (!is_real(_tidx)) _tidx = 0; // safe fallback
    var _semim = 1.0;
    try { if (variable_struct_exists(_user, "__semi_mult_tmp")) { _semim = max(1.0, real(variable_struct_get(_user, "__semi_mult_tmp"))); variable_struct_set(_user, "__semi_mult_tmp", undefined); } } catch (e_sm2) {}
    __battle_apply_damage(_pid, _tidx, _dmg, _semim);

    // === APPLY AILMENT / FLINCH / STAT EFFECTS FROM move_meta ===
    try {
        var _mm = undefined;
        if (!is_undefined(__battle_get_move_meta) && is_real(_move)){
            try { _mm = __battle_get_move_meta(_move); } catch (e_m) { _mm = undefined; }
        } else if (variable_global_exists("_move_meta") && is_array(global._move_meta) && _move >= 0 && _move < array_length(global._move_meta)){
            try { _mm = global._move_meta[_move]; } catch (e_gm2) { _mm = undefined; }
        }
        if (is_struct(_mm)){
            // Multi-hit visual feedback: if this move's effect_id indicates multi-hit (2 or 3),
            // play a small multihit overlay per hit and apply per-hit recoil nudges.
            try {
                var _effid_local = (variable_struct_exists(_mm, "effect_id") ? variable_struct_get(_mm, "effect_id") : undefined);
                if (is_real(_effid_local) && (_effid_local == 2 || _effid_local == 3)){
                    // Determine hits: prefer explicit min_hits/max_hits from move meta
                    var _min_hits = (variable_struct_exists(_mm, "min_hits") && is_real(variable_struct_get(_mm, "min_hits"))) ? floor(variable_struct_get(_mm, "min_hits")) : 1;
                    var _max_hits = (variable_struct_exists(_mm, "max_hits") && is_real(variable_struct_get(_mm, "max_hits"))) ? floor(variable_struct_get(_mm, "max_hits")) : _min_hits;
                    if (_max_hits < _min_hits) _max_hits = _min_hits;
                    var _hits_count = (_min_hits == _max_hits) ? _min_hits : irandom_range(_min_hits, _max_hits);
                    if (!is_real(_hits_count) || _hits_count < 1) _hits_count = 1;

                    // Choose frame mapping by move identifier (hardcoded mapping)
                    var _frame_map = 0;
                    try {
                        switch(string_lower(string(_moveIdent))){
                            case "cometpunch": case "armthrust": _frame_map = 0; break;
                            case "fury_swipes": case "furycutter": case "bite": _frame_map = 2; break;
                            case "double_kick": case "peck": _frame_map = 3; break;
                            case "karate_chop": case "cross_chop": _frame_map = 4; break;
                            default: _frame_map = 0; break;
                        }
                    } catch (e_fm) { _frame_map = 0; }

                    // Determine per-hit damage proportion if total damage is numeric
                    var _per_hit_dmg = 0;
                    if (is_real(_dmg) && _hits_count > 0) _per_hit_dmg = real(_dmg) / _hits_count;

                    // Resolve target max HP for proportion mapping
                    var _tgt_max_hp = 1;
                    try { if (variable_struct_exists(_target, "hp_max")) _tgt_max_hp = max(1, real(variable_struct_get(_target, "hp_max"))); else if (variable_struct_exists(_target, "mon") && is_struct(variable_struct_get(_target, "mon")) && variable_struct_exists(variable_struct_get(_target, "mon"), "hp_max")) _tgt_max_hp = max(1, real(variable_struct_get(variable_struct_get(_target, "mon"), "hp_max"))); } catch (e_thp) { _tgt_max_hp = 1; }

                    // Play overlays and apply nudges per hit
                    for (var _hi = 0; _hi < _hits_count; ++_hi){
                        // Small random offset for overlay placement
                        var _offx = irandom_range(-8, 8);
                        var _offy = irandom_range(-6, 6);
                        // Request the multihit overlay (short duration)
                        // Pass the sprite resource directly so the normalizer receives the intended sprite
                        try {
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                try {
                                    var _spr_ok = (is_undefined(spr_multihit) == false && sprite_exists(spr_multihit));
                                    show_debug_message("[battle][multi-hit][enqueue] pid=" + string(_pid) + ", target_index=" + string(_tidx) + ", frame=" + string(_frame_map) + ", off=(" + string(_offx) + "," + string(_offy) + ")" + ", spr_ok=" + string(_spr_ok));
                                } catch (e_dbgmh) {}
                            }
                            __battle_request_animation_safe(_pid, { type: "hit_effect", target_index: _tidx, actor: _user, target: _target, sprite: spr_multihit, scale: 1.0, frame: _frame_map, offset_x: _offx, offset_y: _offy, slide_mag: 6, duration: 140 });
                        } catch (e_reqmh) {}
                        // Camera shake/brief feedback between hits
                        try { if (!is_undefined(battle_cam_shake)) battle_cam_shake(_pid, 4, 120, 12, 0.92); } catch (e_cam) {}

                        // Compute per-hit nudge magnitude and set attacker/defender nudge fields (smaller per-hit)
                        try {
                            var _prop_hit = clamp((_tgt_max_hp > 0 ? (_per_hit_dmg / _tgt_max_hp) : 0), 0, 1);
                            var _nudge_mag_hit = lerp(2, 18, _prop_hit);
                            var _ndir_hit = 0;
                            var _act_idx_local2 = (variable_struct_exists(_user, "actor_index") ? variable_struct_get(_user, "actor_index") : undefined);
                            if (is_real(_act_idx_local2) && is_real(_tidx)) _ndir_hit = sign(_tidx - _act_idx_local2);
                            // Attacker nudge
                            try {
                                if (is_struct(_user)){
                                    variable_struct_set(_user, "_nudge_active", true);
                                    variable_struct_set(_user, "_nudge_start_ms", current_time);
                                    variable_struct_set(_user, "_nudge_dur", 240);
                                    variable_struct_set(_user, "_nudge_mag", _nudge_mag_hit);
                                    variable_struct_set(_user, "_nudge_dir", _ndir_hit);
                                }
                            } catch (e_an) {}
                            // Defender recoil (write both passed target and actor slot entry)
                            try {
                                var _d_nudge_m = max(1, _nudge_mag_hit * 0.75);
                                if (is_struct(_target)){
                                    variable_struct_set(_target, "_nudge_active", true);
                                    variable_struct_set(_target, "_nudge_start_ms", current_time);
                                    variable_struct_set(_target, "_nudge_dur", 200);
                                    variable_struct_set(_target, "_nudge_mag", _d_nudge_m);
                                    variable_struct_set(_target, "_nudge_dir", -_ndir_hit);
                                }
                                try {
                                    var _Btmp_mh = __battle_ensure_slot(_pid);
                                    if (is_struct(_Btmp_mh) && variable_struct_exists(_Btmp_mh, "actor") && is_array(variable_struct_get(_Btmp_mh, "actor"))){
                                        var _actors_mh = variable_struct_get(_Btmp_mh, "actor");
                                        if (is_real(_tidx) && _tidx >= 0 && _tidx < array_length(_actors_mh)){
                                            var _def_act_mh = _actors_mh[_tidx];
                                            if (is_struct(_def_act_mh)){
                                                variable_struct_set(_def_act_mh, "_nudge_active", true);
                                                variable_struct_set(_def_act_mh, "_nudge_start_ms", current_time);
                                                variable_struct_set(_def_act_mh, "_nudge_dur", 200);
                                                variable_struct_set(_def_act_mh, "_nudge_mag", _d_nudge_m);
                                                variable_struct_set(_def_act_mh, "_nudge_dir", -_ndir_hit);
                                            }
                                        }
                                    }
                                } catch (e_setslotmh) {}
                            } catch (e_dn) {}
                        } catch (e_hitloop) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][multi-hit] per-hit visual failed: " + string(e_hitloop)); }
                    }
                }
            } catch (e_mh_all) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][multi-hit] failed: " + string(e_mh_all)); }
            // Ailment application
            try {
                var ail_id = (variable_struct_exists(_mm, "meta_ailment_id") ? variable_struct_get(_mm, "meta_ailment_id") : undefined);
                var ach = (variable_struct_exists(_mm, "ailment_chance") && is_real(variable_struct_get(_mm, "ailment_chance"))) ? floor(variable_struct_get(_mm, "ailment_chance")) : 0;
                if (is_real(ail_id) && ail_id > 0 && !is_undefined(status_system_apply_status)){
                    // Attempt to resolve ailment name for clearer debug output
                    var sname_dbg = undefined;
                    try { if (!is_undefined(scr_move_meta_ailment_to_name)) sname_dbg = scr_move_meta_ailment_to_name(ail_id); } catch (e_sdbg) { sname_dbg = undefined; }
                    if (is_undefined(sname_dbg) && variable_global_exists("_move_meta_ailments") && is_array(global._move_meta_ailments) && ail_id < array_length(global._move_meta_ailments)){
                        try { var _amn_dbg = global._move_meta_ailments[ail_id]; if (is_struct(_amn_dbg) && variable_struct_exists(_amn_dbg, "name")) sname_dbg = variable_struct_get(_amn_dbg, "name"); } catch (e_amdbg) { sname_dbg = undefined; }
                    }
                    var __status_override_name = undefined;
                    if (!is_undefined(sname_dbg) && is_string(sname_dbg) && string_length(string(sname_dbg)) > 0) __status_override_name = string_lower(string(sname_dbg));
                    if (is_undefined(__status_override_name)){
                        switch (floor(ail_id)){
                            case 1: __status_override_name = "sleep"; break;
                            case 2: __status_override_name = "poison"; break;
                            case 3: __status_override_name = "burn"; break;
                            case 4: __status_override_name = "freeze"; break;
                            case 5: __status_override_name = "paralysis"; break;
                            case 6: __status_override_name = "confusion"; break;
                            case 8: __status_override_name = "trap"; break;
                        }
                    }
                    if (!is_undefined(__status_override_name) && !is_undefined(__status_dev_override_chance)){
                        ach = __status_dev_override_chance(__status_override_name, ach);
                    }
                    if (ach > 0){
                        // If Water Pledge double-effect is active for user's side, double the chance
                        try {
                            var _Bslot_local = __battle_ensure_slot(_pid);
                            if (is_struct(_Bslot_local) && variable_struct_exists(_Bslot_local, "_pledge_flags") && is_struct(variable_struct_get(_Bslot_local, "_pledge_flags"))){
                                var pf_local = variable_struct_get(_Bslot_local, "_pledge_flags");
                                var user_side = (variable_struct_exists(_user, "actor_index") && variable_struct_get(_user, "actor_index") == 0) ? 0 : 1;
                                var wk = "water_pledge_double_effect_side_" + string(user_side);
                                if (variable_struct_exists(pf_local, wk) && is_real(variable_struct_get(pf_local, wk)) && variable_struct_get(pf_local, wk) > 0){
                                    ach = min(100, floor(ach * 2));
                                }
                            }
                        } catch (e_pfd) {}
                        var roll = irandom(99);
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] ailment attempt for move=" + string(_move) + ", id=" + string(ail_id) + ", name=" + string(sname_dbg) + ", chance=" + string(ach) + ", roll=" + string(roll));
                        if (roll < ach){
                            // Map ailment id to status name if helper exists
                            var sname = undefined;
                            try { if (!is_undefined(scr_move_meta_ailment_to_name)) sname = scr_move_meta_ailment_to_name(ail_id); } catch (e_sm) { sname = undefined; }
                            // Fallback: try global._move_meta_ailments mapping
                            if (is_undefined(sname) && variable_global_exists("_move_meta_ailments") && is_array(global._move_meta_ailments) && ail_id < array_length(global._move_meta_ailments)){
                                try { var _amn = global._move_meta_ailments[ail_id]; if (is_struct(_amn) && variable_struct_exists(_amn, "name")) sname = variable_struct_get(_amn, "name"); } catch (e_am) { sname = undefined; }
                            }
                            if (!is_undefined(sname) && is_string(sname) && string_length(sname) > 0){
                                try { status_system_apply_status(_target, string_lower(sname), { source: _user }); } catch (e_ss) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status apply failed: " + string(e_ss)); }
                            } else {
                                // If we couldn't map name, attempt to apply common named statuses by id heuristics
                                try {
                                    // common ailment ids: 1=sleep,2=poison,3=burn,4=freeze,5=paralysis,6=confuse,8=trap
                                    var cand = undefined;
                                    if (is_real(ail_id)){
                                        switch(floor(ail_id)){
                                            case 1: cand = "sleep"; break;
                                            case 2: cand = "poison"; break;
                                            case 3: cand = "burn"; break;
                                            case 4: cand = "freeze"; break;
                                            case 5: cand = "paralyze"; break;
                                            case 6: cand = "confusion"; break;
                                        }
                                    }
                                    if (!is_undefined(cand)) try { status_system_apply_status(_target, cand, { source: _user }); } catch (e_ss2) {}
                                } catch (e_apply) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] ailment apply heuristics failed: " + string(e_apply)); }
                            }
                        }
                    }
                }
            } catch (e_a) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] ailment handler error: " + string(e_a)); }
        }
    } catch (e_any) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] post-dmg apply failed: " + string(e_any)); }

    // === DRAIN FLAG ===
    if (_flags & FLAG_DRAIN){
        var _heal = ceil(_dmg * 0.5);
        _user.hp = min(_user.hp + _heal, _user.hp_max);
        dialog_queue(_user.name + " absorbed health!");
    }

    _user.sys_lastMoveUsed = _move;
}


function __battle_check_can_act(_user){
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        var _dbg_name = "actor";
        var _dbg_has_freeze = "?";
        var _dbg_has_sleep = "?";
        var _dbg_has_para = "?";
        try {
            _dbg_name = string(__status_mon_display_name(_user));
        } catch (e_dbg_name) {}
        if (!is_undefined(status_system_has_status)){
            try { _dbg_has_freeze = string(status_system_has_status(_user, "freeze")); } catch (e_dbg_freeze) { _dbg_has_freeze = "err"; }
            try { _dbg_has_sleep = string(status_system_has_status(_user, "sleep")); } catch (e_dbg_sleep) { _dbg_has_sleep = "err"; }
            try {
                if (status_system_has_status(_user, "paralysis")) _dbg_has_para = "true";
                else if (status_system_has_status(_user, "paralyze")) _dbg_has_para = "true";
                else _dbg_has_para = "false";
            } catch (e_dbg_para) { _dbg_has_para = "err"; }
        }
        show_debug_message("[battle][status][check] actor=" + _dbg_name + " freeze=" + _dbg_has_freeze + " sleep=" + _dbg_has_sleep + " paralysis=" + _dbg_has_para);
    }
    // Use the centralized status system when available. Fall back to legacy
    // sys_status fields if the status system isn't present.
    try {
        if (!is_undefined(status_system_has_status) && !is_undefined(status_system_get)){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                try {
                    var _freeze_probe = status_system_has_status(_user, "freeze");
                    if (_freeze_probe){
                        show_debug_message("[battle][status][freeze] check=" + string(__status_mon_display_name(_user)) + " :: has_freeze=1");
                    }
                } catch (e_probe) {}
            }
            // Freeze handling: 75% chance to remain frozen each attempt; thaw on success
            if (status_system_has_status(_user, "freeze")){
                var _freeze_inst = undefined;
                try { _freeze_inst = status_system_get(_user, "freeze"); } catch (e_freeze_inst) { _freeze_inst = undefined; }
                var _freeze_name = "The Pokémon";
                try {
                    _freeze_name = string(__status_mon_display_name(_user));
                } catch (e_freeze_name) {
                    if (variable_struct_exists(_user, "name")) _freeze_name = string(variable_struct_get(_user, "name"));
                }
                var _freeze_msg = _freeze_name + " is still frozen!";
                var _skip_thaw_roll = false;
                if (is_struct(_freeze_inst) && variable_struct_exists(_freeze_inst, "_freeze_skip_thaw_roll") && variable_struct_get(_freeze_inst, "_freeze_skip_thaw_roll") == true){
                    _skip_thaw_roll = true;
                    try { variable_struct_set(_freeze_inst, "_freeze_skip_thaw_roll", false); } catch (e_clear_flag) {}
                }
                if (_skip_thaw_roll){
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][freeze] skip thaw roll for " + _freeze_name);
                    var _queued_skip = false;
                    try { _queued_skip = __status_request_dialog_for_mon(_user, _freeze_msg, false); } catch (e_freeze_skip) { _queued_skip = false; }
                    if (!_queued_skip){
                        try { if (!is_undefined(dialog_queue)) dialog_queue(_freeze_msg); } catch (e_fallback_skip) {}
                    }
                    return false;
                }
                var r2 = irandom(99);
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][freeze] thaw roll=" + string(r2) + " for " + _freeze_name);
                if (r2 < 75){
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][freeze] remains frozen");
                    var _queued = false;
                    try { _queued = __status_request_dialog_for_mon(_user, _freeze_msg, false); } catch (e_freeze_msg) { _queued = false; }
                    if (!_queued){
                        try { if (!is_undefined(dialog_queue)) dialog_queue(_freeze_msg); } catch (e_fallback) {}
                    }
                    return false;
                } else {
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][freeze] thawed -> clearing status");
                    status_system_clear_status(_user, "freeze");
                    return true;
                }
            }
            // Sleep handling: use turns on the status instance if available
            if (status_system_has_status(_user, "sleep")){
                var inst_s = status_system_get(_user, "sleep");
                var turns = (is_struct(inst_s) && variable_struct_exists(inst_s, "turns") && is_real(variable_struct_get(inst_s, "turns"))) ? variable_struct_get(inst_s, "turns") : undefined;
                if (is_real(turns) && turns > 0){
                    // Decrement remaining turns; status_system.on_tick will handle dialog
                    if (is_struct(inst_s) && is_real(inst_s.turns)) inst_s.turns = max(0, inst_s.turns - 1);
                    return false;
                }
                // no turns left -> wake up
                dialog_queue((variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user") + " woke up!"); status_system_clear_status(_user, "sleep"); return true;
            }
            // Paralysis: 25% chance to be immobilized
            if (status_system_has_status(_user, "paralysis") || status_system_has_status(_user, "paralyze")){
                // Prefer the canonical instance when available so callers can set per-instance flags
                var _pinst = undefined;
                try { if (status_system_has_status(_user, "paralysis")) _pinst = status_system_get(_user, "paralysis");
                      else if (status_system_has_status(_user, "paralyze")) _pinst = status_system_get(_user, "paralyze"); } catch (e_pi) { _pinst = undefined; }
                var _immobilized = (irandom(3) == 0); // 1/4 chance
                if (_immobilized){
                    // Suppress duplicate immobilize messages for the same actor in short windows
                    var _last_ts = (variable_struct_exists(_user, "_last_paralyze_msg_ts") ? variable_struct_get(_user, "_last_paralyze_msg_ts") : -9999999);
                    if (abs(current_time - _last_ts) >= 500){
                        dialog_queue((variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user") + " is paralyzed! It can't move!");
                        try { variable_struct_set(_user, "_last_paralyze_msg_ts", current_time); } catch (e_setp) {}
                    }
                    return false;
                }
                return true;
            }
        }
    } catch (e_status_fallback) {
        // fallback to legacy behavior if status_system calls fail
    }

    // Legacy fallback: read status fields from the actor struct to avoid runtime errors
    var _status = undefined; var _status_turns = 0;
    try {
        if (is_struct(_user) && variable_struct_exists(_user, "sys_status")) _status = variable_struct_get(_user, "sys_status");
        if (is_struct(_user) && variable_struct_exists(_user, "sys_status_turns")) _status_turns = variable_struct_get(_user, "sys_status_turns");
    } catch (e_st) { _status = undefined; _status_turns = 0; }

    switch (_status){
        case "freeze":
            if (irandom(3) < 3){
                try { dialog_queue(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user" + " is frozen solid!"); } catch (e) { dialog_queue("The user is frozen solid!"); }
                return false;
            } else {
                try { dialog_queue(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user" + " thawed out!"); } catch (e) { dialog_queue("The user thawed out!"); }
                try { if (is_struct(_user)) variable_struct_set(_user, "sys_status", undefined); } catch (e2) {}
                return true;
            }
        case "sleep":
            if (_status_turns > 0){
                try { dialog_queue(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user" + " is fast asleep..."); } catch (e) { dialog_queue("The user is fast asleep..."); }
                try { if (is_struct(_user)) variable_struct_set(_user, "sys_status_turns", max(0, _status_turns - 1)); } catch (e2) {}
                return false;
            } else {
                try { dialog_queue(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user" + " woke up!"); } catch (e) { dialog_queue("The user woke up!"); }
                try { if (is_struct(_user)) variable_struct_set(_user, "sys_status", undefined); } catch (e2) {}
                return true;
            }
        case "paralyze":
            if (irandom(3) == 0){
                try { dialog_queue(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user" + " is paralyzed! It can't move!"); } catch (e) { dialog_queue("The user is paralyzed! It can't move!"); }
                return false;
            }
            return true;
        default:
            return true;
    }
}