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
                    if (is_real(_mv) && is_real(_move) && _mv == _move) continue;
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
            case 203: // Endure shares the same diminishing success gate
            case 852: // Silk Trap shares Protect timing
            case 908: // Burning Bulwark shares Protect timing
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
                    var _fail_name = __battle_dialog_actor_name(_user, "The user");
                    var _fail_move = "Protect";
                    try { _fail_move = __battle_move_name_impl(_move); } catch (e_fn) {}
                    dialog_queue(_fail_name + "'s " + string(_fail_move) + " failed!");
                    try { variable_struct_set(_user, "sys_protect_streak", 0); } catch (e_rstreak) {}
                    try { variable_struct_set(_user, "sys_protected", false); } catch (e_pf) {}
                    try { variable_struct_set(_user, "_protected", false); } catch (e_pf2) {}
                    try { variable_struct_set(_user, "sys_enduring", false); } catch (e_endf1) {}
                    try { variable_struct_set(_user, "_enduring", false); } catch (e_endf2) {}
                    try { variable_struct_set(_user, "sys_protected_turn", undefined); } catch (e_pf3) {}
                    try { variable_struct_set(_user, "sys_protected_source_move", undefined); } catch (e_pf4) {}
                    try { variable_struct_set(_user, "sys_endure_turn", undefined); } catch (e_endf3) {}
                    return false;
                }

                try { variable_struct_set(_user, "sys_protect_streak", _consecutive); } catch (e_sp) {}
                if (_move == 203){
                    try { variable_struct_set(_user, "sys_enduring", true); } catch (e_end1) {}
                    try { variable_struct_set(_user, "_enduring", true); } catch (e_end2) {}
                    try { variable_struct_set(_user, "sys_endure_turn", _turn_now); } catch (e_end3) {}
                } else {
                    try { variable_struct_set(_user, "sys_protected", true); } catch (e_p1) {}
                    try { variable_struct_set(_user, "_protected", true); } catch (e_p2) {}
                    try { variable_struct_set(_user, "_protected_announce_shown", false); } catch (e_p3) {}
                    try { variable_struct_set(_user, "sys_protected_turn", _turn_now); } catch (e_p4) {}
                    try { variable_struct_set(_user, "sys_protected_source_move", _move); } catch (e_p5) {}
                }
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
    _needle = string_replace_all(_needle, "_", "-");
    _needle = string_replace_all(_needle, " ", "-");

    var _ability = undefined;
    if (variable_struct_exists(_ent, "ability")) _ability = variable_struct_get(_ent, "ability");

    if (is_undefined(_ability) && variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
        var _mon = variable_struct_get(_ent, "mon");
        if (variable_struct_exists(_mon, "ability")) _ability = variable_struct_get(_mon, "ability");
    }

    if (is_string(_ability)){
        var _ability_key = string_lower(string(_ability));
        _ability_key = string_replace_all(_ability_key, "_", "-");
        _ability_key = string_replace_all(_ability_key, " ", "-");
        if (_ability_key == _needle) return true;
    } else if (is_real(_ability)){
        try {
            if (!is_undefined(scr_ability_name_by_id)){
                var _ab_name = scr_ability_name_by_id(_ability);
                if (is_string(_ab_name)){
                    var _ab_key = string_lower(string(_ab_name));
                    _ab_key = string_replace_all(_ab_key, "_", "-");
                    _ab_key = string_replace_all(_ab_key, " ", "-");
                    if (_ab_key == _needle) return true;
                }
            }
        } catch (e_lookup) {}

        var _const_key = "ABILITY_" + string_upper(string_replace_all(_needle, "-", "_"));
        try {
            if (variable_global_exists(_const_key)){
                var _const_val = variable_global_get(_const_key);
                if (is_real(_const_val) && floor(_const_val) == floor(_ability)) return true;
            }
        } catch (e_const) {}
    }

    return false;
}

function __battle_actor_ability_name_lc(_ent){
    if (!is_struct(_ent)) return "";
    var _ability = undefined;
    try {
        if (variable_struct_exists(_ent, "ability")) _ability = variable_struct_get(_ent, "ability");
        else if (variable_struct_exists(_ent, "ability_id")) _ability = variable_struct_get(_ent, "ability_id");
        if (is_undefined(_ability) && variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
            var _mon = variable_struct_get(_ent, "mon");
            if (variable_struct_exists(_mon, "ability")) _ability = variable_struct_get(_mon, "ability");
            else if (variable_struct_exists(_mon, "ability_id")) _ability = variable_struct_get(_mon, "ability_id");
        }
        if (is_string(_ability)){
            var _ab_string = string_lower(string(_ability));
            _ab_string = string_replace_all(_ab_string, "_", "-");
            _ab_string = string_replace_all(_ab_string, " ", "-");
            return _ab_string;
        }
        if (is_real(_ability) && !is_undefined(scr_ability_name_by_id)){
            var _name = scr_ability_name_by_id(_ability);
            if (is_string(_name)) return string_lower(string_replace_all(string(_name), " ", "-"));
        }
    } catch (e_ability_name) {}
    return "";
}

function __battle_actor_has_any_ability(_ent, _names){
    if (!is_struct(_ent) || !is_array(_names)) return false;
    var _ab = __battle_actor_ability_name_lc(_ent);
    if (string_length(_ab) <= 0) return false;
    for (var _i = 0; _i < array_length(_names); ++_i){
        var _needle = string_lower(string_replace_all(string(_names[_i]), " ", "-"));
        if (_ab == _needle) return true;
    }
    return false;
}

function __battle_actor_ability_id(_ent){
    if (!is_struct(_ent)) return undefined;
    var _ability = undefined;
    try {
        if (variable_struct_exists(_ent, "ability_id")) _ability = variable_struct_get(_ent, "ability_id");
        else if (variable_struct_exists(_ent, "ability")) _ability = variable_struct_get(_ent, "ability");
        if (is_undefined(_ability) && variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
            var _mon = variable_struct_get(_ent, "mon");
            if (variable_struct_exists(_mon, "ability_id")) _ability = variable_struct_get(_mon, "ability_id");
            else if (variable_struct_exists(_mon, "ability")) _ability = variable_struct_get(_mon, "ability");
        }
        if (is_real(_ability)) return floor(_ability);
        if (is_string(_ability) && variable_global_exists("_abilities") && is_array(global._abilities)){
            var _key = string_lower(string(_ability));
            _key = string_replace_all(_key, "_", "-");
            _key = string_replace_all(_key, " ", "-");
            for (var _ai = 1; _ai < array_length(global._abilities); ++_ai){
                var _ab = global._abilities[_ai];
                if (!is_struct(_ab)) continue;
                if (variable_struct_exists(_ab, "identifier")){
                    var _ident_key = string_lower(string(variable_struct_get(_ab, "identifier")));
                    _ident_key = string_replace_all(_ident_key, "_", "-");
                    _ident_key = string_replace_all(_ident_key, " ", "-");
                    if (_ident_key == _key) return _ai;
                }
                if (variable_global_exists("_ability_effects") && is_array(global._ability_effects) && _ai < array_length(global._ability_effects)){
                    var _eff_name = global._ability_effects[_ai];
                    if (is_struct(_eff_name) && variable_struct_exists(_eff_name, "name")){
                        var _name_key = string_lower(string(variable_struct_get(_eff_name, "name")));
                        _name_key = string_replace_all(_name_key, "_", "-");
                        _name_key = string_replace_all(_name_key, " ", "-");
                        if (_name_key == _key) return _ai;
                    }
                }
            }
        }
    } catch (e_ability_id) {}
    return undefined;
}

function __battle_actor_ability_effect(_ent){
    var _aid = __battle_actor_ability_id(_ent);
    if (!is_real(_aid)) return undefined;
    try {
        if (variable_global_exists("_ability_effects") && is_array(global._ability_effects) && _aid >= 0 && _aid < array_length(global._ability_effects)){
            var _eff = global._ability_effects[_aid];
            if (is_struct(_eff)) return _eff;
        }
    } catch (e_eff) {}
    return undefined;
}

function __battle_ability_effect_has_type(_eff, _field, _type_name){
    if (!is_struct(_eff) || !is_string(_field) || !variable_struct_exists(_eff, _field)) return false;
    var _arr = variable_struct_get(_eff, _field);
    if (!is_array(_arr)) return false;
    var _key = string_lower(string(_type_name));
    for (var _i = 0; _i < array_length(_arr); ++_i){
        var _item = _arr[_i];
        if (is_string(_item) && string_lower(string(_item)) == _key) return true;
        if (is_struct(_item) && variable_struct_exists(_item, "type") && string_lower(string(variable_struct_get(_item, "type"))) == _key) return true;
    }
    return false;
}

function __battle_ability_effect_status_immune(_ent, _status_name){
    var _eff = __battle_actor_ability_effect(_ent);
    var _key = string_lower(string(_status_name));
    var _actions = __battle_actor_ability_actions(_ent, "status_apply");
    for (var _ai = 0; _ai < array_length(_actions); ++_ai){
        var _act = _actions[_ai];
        var _kind = (is_struct(_act) && variable_struct_exists(_act, "kind")) ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
        if (_kind != "block_status") continue;
        var _data = __battle_ability_action_data(_act);
        if (variable_struct_exists(_data, "status") && string_lower(string(variable_struct_get(_data, "status"))) == _key){
            try { __battle_queue_ability_action_dialog(_ent, _act, undefined, { status:_key }); } catch (e_status_ability_dialog) {}
            return true;
        }
    }
    if (!is_struct(_eff) || !variable_struct_exists(_eff, "status_immunities")) return false;
    var _arr = variable_struct_get(_eff, "status_immunities");
    if (!is_array(_arr)) return false;
    for (var _i = 0; _i < array_length(_arr); ++_i){
        if (string_lower(string(_arr[_i])) == _key) return true;
    }
    return false;
}

function __battle_actor_ability_has_group(_ent, _group_id){
    var _eff = __battle_actor_ability_effect(_ent);
    if (!is_struct(_eff) || !variable_struct_exists(_eff, "groups")) return false;
    var _groups = variable_struct_get(_eff, "groups");
    if (!is_array(_groups)) return false;
    var _needle = string_lower(string(_group_id));
    for (var _i = 0; _i < array_length(_groups); ++_i){
        if (string_lower(string(_groups[_i])) == _needle) return true;
    }
    return false;
}

function __battle_actor_ability_actions(_ent, _hook){
    var _out = [];
    var _eff = __battle_actor_ability_effect(_ent);
    if (!is_struct(_eff) || !variable_struct_exists(_eff, "actions")) return _out;
    var _actions = variable_struct_get(_eff, "actions");
    if (!is_array(_actions)) return _out;
    var _hook_key = string_lower(string(_hook));
    for (var _i = 0; _i < array_length(_actions); ++_i){
        var _action = _actions[_i];
        if (!is_struct(_action) || !variable_struct_exists(_action, "hook")) continue;
        if (string_lower(string(variable_struct_get(_action, "hook"))) == _hook_key) array_push(_out, _action);
    }
    return _out;
}

function __battle_ability_action_data(_action){
    if (is_struct(_action) && variable_struct_exists(_action, "data") && is_struct(variable_struct_get(_action, "data"))) return variable_struct_get(_action, "data");
    return {};
}

function __battle_item_action_data(_action){
    if (is_struct(_action) && variable_struct_exists(_action, "data") && is_struct(variable_struct_get(_action, "data"))) return variable_struct_get(_action, "data");
    return {};
}

function __battle_held_item_label(_actor){
    var _iid = -1;
    try {
        if (!is_undefined(item_runtime_actor_held_item_id)) _iid = item_runtime_actor_held_item_id(_actor);
        else if (is_struct(_actor) && variable_struct_exists(_actor, "held_item_id") && is_real(variable_struct_get(_actor, "held_item_id"))) _iid = floor(variable_struct_get(_actor, "held_item_id"));
    } catch (e_item_label_id) { _iid = -1; }
    if (_iid > 0 && variable_global_exists("_items") && is_array(global._items) && _iid < array_length(global._items)){
        var _it = global._items[_iid];
        if (is_struct(_it)){
            var _nm = "";
            if (variable_struct_exists(_it, "name")) _nm = string(variable_struct_get(_it, "name"));
            else if (variable_struct_exists(_it, "identifier")) _nm = string(variable_struct_get(_it, "identifier"));
            if (string_length(_nm) > 0) return __battle_ability_battle_label(string_replace_all(_nm, "-", " "));
        }
    }
    return "held item";
}

function __battle_actor_has_type_name_runtime(_actor, _type_name){
    var _tid = __battle_type_id_by_name_safe(_type_name);
    if (!is_real(_tid) || _tid <= 0) return false;
    var _types = __battle_actor_type_ids(_actor);
    for (var _i = 0; _i < array_length(_types); ++_i){
        if (is_real(_types[_i]) && floor(_types[_i]) == floor(_tid)) return true;
    }
    return false;
}

function __battle_ability_actor_name(_actor, _fallback){
    if (is_struct(_actor)){
        try {
            if (variable_struct_exists(_actor, "name") && string_length(string(variable_struct_get(_actor, "name"))) > 0) return string(variable_struct_get(_actor, "name"));
            if (variable_struct_exists(_actor, "nickname") && string_length(string(variable_struct_get(_actor, "nickname"))) > 0) return string(variable_struct_get(_actor, "nickname"));
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
                var _mon = variable_struct_get(_actor, "mon");
                if (variable_struct_exists(_mon, "name") && string_length(string(variable_struct_get(_mon, "name"))) > 0) return string(variable_struct_get(_mon, "name"));
                if (variable_struct_exists(_mon, "nickname") && string_length(string(variable_struct_get(_mon, "nickname"))) > 0) return string(variable_struct_get(_mon, "nickname"));
            }
        } catch (e_ability_actor_name) {}
    }
    return string(_fallback);
}

function __battle_ability_label(_actor){
    var _eff = __battle_actor_ability_effect(_actor);
    if (is_struct(_eff) && variable_struct_exists(_eff, "name") && string_length(string(variable_struct_get(_eff, "name"))) > 0) return string(variable_struct_get(_eff, "name"));
    var _ab = __battle_actor_ability_name_lc(_actor);
    _ab = string_replace_all(_ab, "-", " ");
    if (string_length(_ab) <= 0) _ab = "ability";
    return _ab;
}

function __battle_ability_pretty_stat(_stat){
    var _s = string_lower(string(_stat));
    switch (_s){
        case "atk": return "Attack";
        case "def": return "Defense";
        case "spa": return "Sp. Atk";
        case "spd": return "Sp. Def";
        case "spe": return "Speed";
        case "accuracy": return "accuracy";
        case "evasion": return "evasiveness";
    }
    return string(_stat);
}

function __battle_ability_battle_label(_text){
    return string_upper(string(_text));
}

function __battle_ability_pretty_weather(_weather){
    var _w = string_lower(string(_weather));
    switch (_w){
        case "rain": return "It started to rain";
        case "sun": return "The sunlight got bright";
        case "sandstorm": return "A sandstorm brewed";
        case "hail": return "It started to hail";
        case "snow": return "It started to snow";
    }
    return "The weather changed";
}

function __battle_ability_pretty_status(_status){
    var _s = string_lower(string(_status));
    switch (_s){
        case "poison": return "poison";
        case "toxic": return "bad poison";
        case "burn": return "a burn";
        case "paralysis": case "paralyze": return "paralysis";
        case "sleep": return "sleep";
        case "freeze": return "freezing";
        case "confusion": return "confusion";
    }
    return string(_status);
}

function __battle_queue_ability_dialog(_actor, _text){
    if (!is_string(_text) || string_length(_text) <= 0) return false;
    try { dialog_queue(_text); return true; } catch (e_ability_dialog) {}
    return false;
}

function __battle_queue_ability_header(_actor){
    return __battle_queue_ability_dialog(_actor, __battle_ability_actor_name(_actor, "The Pokemon") + "'s " + __battle_ability_battle_label(__battle_ability_label(_actor)) + "!");
}

function __battle_queue_ability_action_dialog(_actor, _action, _target, _context){
    if (!is_struct(_action)) return false;
    var _kind = variable_struct_exists(_action, "kind") ? string_lower(string(variable_struct_get(_action, "kind"))) : "";
    var _data = __battle_ability_action_data(_action);
    var _actor_name = __battle_ability_actor_name(_actor, "The Pokemon");
    var _target_name = __battle_ability_actor_name(_target, "the target");
    var _ability = __battle_ability_battle_label(__battle_ability_label(_actor));
    var _msg = "";

    if (variable_struct_exists(_data, "dialog") && string_length(string(variable_struct_get(_data, "dialog"))) > 0){
        _msg = string(variable_struct_get(_data, "dialog"));
        _msg = string_replace_all(_msg, "{actor}", _actor_name);
        _msg = string_replace_all(_msg, "{target}", _target_name);
        _msg = string_replace_all(_msg, "{ability}", _ability);
    } else {
        switch (_kind){
            case "set_weather":
                var _weather = variable_struct_exists(_data, "weather") ? variable_struct_get(_data, "weather") : "";
                __battle_queue_ability_header(_actor);
                _msg = __battle_ability_pretty_weather(_weather) + "!";
                break;
            case "stage_opponents":
                var _stat = variable_struct_exists(_data, "stat") ? variable_struct_get(_data, "stat") : "stat";
                var _delta = variable_struct_exists(_data, "delta") ? variable_struct_get(_data, "delta") : -1;
                _msg = _actor_name + "'s " + _ability + " ";
                _msg += (_delta < 0) ? "cut " : "raised ";
                _msg += _target_name + "'s " + __battle_ability_battle_label(__battle_ability_pretty_stat(_stat)) + "!";
                break;
            case "absorb_heal":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " regained health!";
                break;
            case "block_stage_boost":
                var _bst = variable_struct_exists(_data, "stat") ? variable_struct_get(_data, "stat") : "";
                __battle_queue_ability_header(_actor);
                _msg = "The attack was drawn in";
                if (string_length(string(_bst)) > 0) _msg += "! " + _actor_name + "'s " + __battle_ability_battle_label(__battle_ability_pretty_stat(_bst)) + " rose";
                _msg += "!";
                break;
            case "flash_fire":
                __battle_queue_ability_header(_actor);
                _msg = "Fire's power was raised!";
                break;
            case "block_type":
                __battle_queue_ability_header(_actor);
                _msg = "It avoided the attack!";
                break;
            case "low_hp_type_multiplier":
                __battle_queue_ability_header(_actor);
                _msg = "The move's power was raised!";
                break;
            case "type_multiplier":
                __battle_queue_ability_header(_actor);
                _msg = "The damage was reduced!";
                break;
            case "super_effective_multiplier":
                __battle_queue_ability_header(_actor);
                _msg = "It weakened the attack!";
                break;
            case "not_very_effective_multiplier":
                __battle_queue_ability_header(_actor);
                _msg = "The move's power was raised!";
                break;
            case "block_non_super_effective":
                __battle_queue_ability_header(_actor);
                _msg = "It protected " + _actor_name + "!";
                break;
            case "stab_multiplier":
                __battle_queue_ability_header(_actor);
                _msg = "The move's power was raised!";
                break;
            case "attack_multiplier":
            case "attack_when_status_multiplier":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + "'s ATTACK was boosted!";
                break;
            case "defense_multiplier":
            case "defense_when_status_multiplier":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + "'s DEFENSE was boosted!";
                break;
            case "weather_speed_multiplier":
            case "speed_when_status_multiplier":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + "'s SPEED rose!";
                break;
            case "status_priority_bonus":
            case "type_priority_bonus":
            case "healing_priority_bonus":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " moved quicker!";
                break;
            case "self_stage_change":
                var _boost_stat = variable_struct_exists(_data, "stat") ? variable_struct_get(_data, "stat") : "stat";
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + "'s " + __battle_ability_battle_label(__battle_ability_pretty_stat(_boost_stat)) + " rose!";
                break;
            case "set_stage":
                var _set_stat = variable_struct_exists(_data, "stat") ? variable_struct_get(_data, "stat") : "stat";
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + "'s " + __battle_ability_battle_label(__battle_ability_pretty_stat(_set_stat)) + " maxed out!";
                break;
            case "damage_attacker_fraction":
                __battle_queue_ability_header(_actor);
                _msg = _target_name + " was hurt!";
                break;
            case "status_attacker_chance":
                var _contact_status = variable_struct_exists(_data, "status") ? variable_struct_get(_data, "status") : "status";
                __battle_queue_ability_header(_actor);
                _msg = _target_name + " was afflicted with " + __battle_ability_pretty_status(_contact_status) + "!";
                break;
            case "volatile_attacker_chance":
                __battle_queue_ability_header(_actor);
                _msg = _target_name + " was affected!";
                break;
            case "replace_attacker_ability":
                __battle_queue_ability_header(_actor);
                _msg = _target_name + "'s Ability became " + _ability + "!";
                break;
            case "block_crit":
                __battle_queue_ability_header(_actor);
                _msg = "A critical hit was prevented!";
                break;
            case "survive_full_hp_ko":
                _msg = _actor_name + " hung on using its " + _ability + "!";
                break;
            case "block_sound":
                __battle_queue_ability_header(_actor);
                _msg = "The sound-based move was blocked!";
                break;
            case "no_guard":
                __battle_queue_ability_header(_actor);
                _msg = "The attack can't miss!";
                break;
            case "block_status":
                var _status = variable_struct_exists(_data, "status") ? variable_struct_get(_data, "status") : "";
                __battle_queue_ability_header(_actor);
                _msg = __battle_ability_pretty_status(_status) + " was prevented!";
                break;
            case "block_stat_lowering":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + "'s stats weren't lowered!";
                break;
            case "berry_effect_multiplier":
                __battle_queue_ability_header(_actor);
                _msg = "The Berry's effect was boosted!";
                break;
            case "block_opponent_berries":
                __battle_queue_ability_header(_actor);
                _msg = _target_name + " is too nervous to eat Berries!";
                break;
            case "heal_fraction_if_berry":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " restored HP!";
                break;
            case "restore_consumed_berry_chance":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " harvested one Berry!";
                break;
            case "reuse_berry_next_turn":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " ate the Berry again!";
                break;
            case "block_item_removal":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " held on to its item!";
                break;
            case "moving_last_multiplier":
            case "target_switched_in_multiplier":
                __battle_queue_ability_header(_actor);
                _msg = "The move's power was raised!";
                break;
            case "conditional_reaction":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + "'s Ability activated!";
                break;
            case "force_switch_below_hp_fraction":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " went back!";
                break;
            case "boost_by_opponent_defenses":
            case "conditional_stage_event":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + "'s stats rose!";
                break;
            case "crit_stage_bonus":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " is getting pumped!";
                break;
            case "always_crit_on_poisoned_target":
                __battle_queue_ability_header(_actor);
                _msg = "It aimed for a weak spot!";
                break;
            case "second_parental_hit":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " attacked again!";
                break;
            case "bypass_target_barriers":
                __battle_queue_ability_header(_actor);
                _msg = "It slipped through the barrier!";
                break;
            case "copy_status_to_source":
                __battle_queue_ability_header(_actor);
                _msg = _target_name + " received the same status!";
                break;
            case "skip_every_other_turn":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " is loafing around!";
                break;
            case "force_max_hits":
                __battle_queue_ability_header(_actor);
                _msg = "It will hit the maximum number of times!";
                break;
            case "block_first_hit":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " protected itself!";
                break;
            case "damage_attacker_equal_last_damage":
                __battle_queue_ability_header(_actor);
                _msg = _target_name + " was hurt!";
                break;
            case "explode_on_faint":
                __battle_queue_ability_header(_actor);
                _msg = _actor_name + " exploded!";
                break;
            case "convert_move_type":
                __battle_queue_ability_header(_actor);
                _msg = "The move's type changed!";
                break;
            default:
                _msg = _actor_name + "'s " + _ability + "!";
                break;
        }
    }
    return __battle_queue_ability_dialog(_actor, _msg);
}

function __battle_type_id_by_name_safe(_name){
    var _key = string_lower(string(_name));
    try {
        if (variable_global_exists("TYPE_ID_BY_NAME")){
            var _map = variable_global_get("TYPE_ID_BY_NAME");
            if (ds_exists(_map, ds_type_map) && ds_map_exists(_map, _key)) return ds_map_find_value(_map, _key);
        }
    } catch (e_type_map) {}
    switch (_key){
        case "normal": return 1;
        case "fighting": return 2;
        case "flying": return 3;
        case "poison": return 4;
        case "ground": return 5;
        case "rock": return 6;
        case "bug": return 7;
        case "ghost": return 8;
        case "steel": return 9;
        case "fire": return 10;
        case "water": return 11;
        case "grass": return 12;
        case "electric": return 13;
        case "psychic": return 14;
        case "ice": return 15;
        case "dragon": return 16;
        case "dark": return 17;
        case "fairy": return 18;
    }
    return -1;
}

function __battle_move_type_safe(_move_id, _A){
    try {
        if (!is_undefined(scr_move_type_id_by_id) && is_real(_move_id)) return scr_move_type_id_by_id(_move_id, _A);
    } catch (e_move_type) {}
    return -1;
}

function __battle_type_name_by_id_safe(_type_id){
    switch (floor(_type_id)){
        case 1: return "normal";
        case 2: return "fighting";
        case 3: return "flying";
        case 4: return "poison";
        case 5: return "ground";
        case 6: return "rock";
        case 7: return "bug";
        case 8: return "ghost";
        case 9: return "steel";
        case 10: return "fire";
        case 11: return "water";
        case 12: return "grass";
        case 13: return "electric";
        case 14: return "psychic";
        case 15: return "ice";
        case 16: return "dragon";
        case 17: return "dark";
        case 18: return "fairy";
    }
    return "";
}

function __battle_move_damage_class_safe(_move_id){
    try {
        if (!is_undefined(scr_move_damage_class_by_id) && is_real(_move_id)) return scr_move_damage_class_by_id(_move_id);
    } catch (e_dc) {}
    try {
        if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
            var _mm = __battle_get_move_meta(_move_id);
            if (is_struct(_mm) && variable_struct_exists(_mm, "damage_class_id")) return variable_struct_get(_mm, "damage_class_id");
        }
    } catch (e_dc_meta) {}
    return undefined;
}

function __battle_actor_type_ids(_actor){
    var _out = [];
    function __push_type_once(_arr, _tid){
        if (!is_real(_tid) || _tid <= 0) return _arr;
        var _id = floor(_tid);
        for (var _i = 0; _i < array_length(_arr); ++_i){
            if (is_real(_arr[_i]) && floor(_arr[_i]) == _id) return _arr;
        }
        array_push(_arr, _id);
        return _arr;
    }
    if (!is_struct(_actor)) return _out;
    try {
        if (variable_struct_exists(_actor, "types") && is_array(variable_struct_get(_actor, "types"))){
            var _types = variable_struct_get(_actor, "types");
            for (var _ti = 0; _ti < array_length(_types); ++_ti) _out = __push_type_once(_out, _types[_ti]);
        }
        if (variable_struct_exists(_actor, "type1")) _out = __push_type_once(_out, variable_struct_get(_actor, "type1"));
        if (variable_struct_exists(_actor, "type2")) _out = __push_type_once(_out, variable_struct_get(_actor, "type2"));
        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
            var _mon = variable_struct_get(_actor, "mon");
            if (variable_struct_exists(_mon, "types") && is_array(variable_struct_get(_mon, "types"))){
                var _mtypes = variable_struct_get(_mon, "types");
                for (var _mi = 0; _mi < array_length(_mtypes); ++_mi) _out = __push_type_once(_out, _mtypes[_mi]);
            }
            if (variable_struct_exists(_mon, "type1")) _out = __push_type_once(_out, variable_struct_get(_mon, "type1"));
            if (variable_struct_exists(_mon, "type2")) _out = __push_type_once(_out, variable_struct_get(_mon, "type2"));
            var _sid = -1;
            if (variable_struct_exists(_mon, "species_id") && is_real(variable_struct_get(_mon, "species_id"))) _sid = variable_struct_get(_mon, "species_id");
            else if (variable_struct_exists(_mon, "id") && is_real(variable_struct_get(_mon, "id"))) _sid = variable_struct_get(_mon, "id");
            if (_sid >= 0 && variable_global_exists("_species_types") && is_array(global._species_types) && _sid < array_length(global._species_types)){
                var _stypes = global._species_types[_sid];
                if (is_array(_stypes)) for (var _si = 0; _si < array_length(_stypes); ++_si) _out = __push_type_once(_out, _stypes[_si]);
            }
        }
    } catch (e_actor_types) {}
    return _out;
}

function __battle_type_matchup_multiplier(_attack_type, _defense_type){
    if (!is_real(_attack_type) || !is_real(_defense_type)) return 1.0;
    var _atk = floor(_attack_type);
    var _def = floor(_defense_type);
    try {
        if (variable_global_exists("BATTLE_TYPE_EFFICACY")){
            var _map = variable_global_get("BATTLE_TYPE_EFFICACY");
            if (ds_exists(_map, ds_type_map)){
                var _key = string(_atk) + ":" + string(_def);
                if (ds_map_exists(_map, _key)){
                    var _mv = ds_map_find_value(_map, _key);
                    if (is_real(_mv)) return _mv;
                }
            }
        }
    } catch (e_type_map_lookup) {}
    try {
        if (variable_global_exists("_type_efficacy") && is_array(global._type_efficacy)){
            for (var _i = 0; _i < array_length(global._type_efficacy); ++_i){
                var _row = global._type_efficacy[_i];
                if (!is_struct(_row)) continue;
                if (variable_struct_exists(_row, "attack_type") && variable_struct_exists(_row, "target_type")){
                    if (floor(variable_struct_get(_row, "attack_type")) == _atk && floor(variable_struct_get(_row, "target_type")) == _def){
                        if (variable_struct_exists(_row, "mult") && is_real(variable_struct_get(_row, "mult"))) return variable_struct_get(_row, "mult");
                        if (variable_struct_exists(_row, "factor") && is_real(variable_struct_get(_row, "factor"))) return variable_struct_get(_row, "factor") / 100.0;
                    }
                }
            }
        }
    } catch (e_type_array_lookup) {}
    return 1.0;
}

function __battle_move_type_effectiveness_multiplier(_A, _D, _move_id){
    var _mv_type = __battle_move_type_safe(_move_id, _A);
    if (!is_real(_mv_type) || _mv_type <= 0) return 1.0;
    var _def_types = __battle_actor_type_ids(_D);
    var _mult = 1.0;
    var _miracle_eye_psychic = false;
    try {
        _miracle_eye_psychic = (_mv_type == __battle_type_id_by_name_safe("psychic")) && is_struct(_D) && variable_struct_exists(_D, "_miracle_eye_active") && variable_struct_get(_D, "_miracle_eye_active") == true;
    } catch (e_miracle_eff) { _miracle_eye_psychic = false; }
    var _attacker_type_bypass_actions = [];
    try { _attacker_type_bypass_actions = __battle_actor_ability_actions(_A, "type_effectiveness"); } catch (e_bypass_actions) { _attacker_type_bypass_actions = []; }
    for (var _i = 0; _i < array_length(_def_types); ++_i){
        var _def_type = _def_types[_i];
        var _m = __battle_type_matchup_multiplier(_mv_type, _def_type);
        if (_miracle_eye_psychic && _def_type == __battle_type_id_by_name_safe("dark") && _m <= 0) _m = 1.0;
        if (_m <= 0){
            for (var _bai = 0; _bai < array_length(_attacker_type_bypass_actions); ++_bai){
                var _bact = _attacker_type_bypass_actions[_bai];
                if (!is_struct(_bact)) continue;
                var _bkind = variable_struct_exists(_bact, "kind") ? string_lower(string(variable_struct_get(_bact, "kind"))) : "";
                if (_bkind != "bypass_ghost_immunity") continue;
                var _bdata = __battle_ability_action_data(_bact);
                var _target_type_name = variable_struct_exists(_bdata, "target_type") ? string_lower(string(variable_struct_get(_bdata, "target_type"))) : "";
                if (_target_type_name != "ghost" || _def_type != __battle_type_id_by_name_safe("ghost")) continue;
                var _attack_types = variable_struct_exists(_bdata, "attacking_types") ? variable_struct_get(_bdata, "attacking_types") : [];
                if (!is_array(_attack_types)) _attack_types = [string(_attack_types)];
                for (var _ati = 0; _ati < array_length(_attack_types); ++_ati){
                    if (_mv_type == __battle_type_id_by_name_safe(_attack_types[_ati])){
                        _m = 1.0;
                        break;
                    }
                }
            }
        }
        _mult *= _m;
    }
    return _mult;
}

function __battle_move_stab_multiplier(_A, _move_id){
    var _mv_type = __battle_move_type_safe(_move_id, _A);
    if (!is_real(_mv_type) || _mv_type <= 0) return 1.0;
    var _types = __battle_actor_type_ids(_A);
    var _has_stab = false;
    for (var _i = 0; _i < array_length(_types); ++_i){
        if (is_real(_types[_i]) && floor(_types[_i]) == floor(_mv_type)){ _has_stab = true; break; }
    }
    if (!_has_stab) return 1.0;
    var _stab = 1.5;
    var _actions = __battle_actor_ability_actions(_A, "stab");
    for (var _ai = 0; _ai < array_length(_actions); ++_ai){
        var _act = _actions[_ai];
        var _kind = (is_struct(_act) && variable_struct_exists(_act, "kind")) ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
        if (_kind != "stab_multiplier") continue;
        var _data = __battle_ability_action_data(_act);
        if (variable_struct_exists(_data, "mult") && is_real(variable_struct_get(_data, "mult"))) _stab = variable_struct_get(_data, "mult");
    }
    return _stab;
}

function __battle_ability_type_effectiveness_multiplier(_A, _D, _move_id, _type_mult){
    var _out = is_real(_type_mult) ? _type_mult : 1.0;
    try {
        var _def_actions = __battle_actor_ability_actions(_D, "type_effectiveness");
        for (var _di = 0; _di < array_length(_def_actions); ++_di){
            var _dact = _def_actions[_di];
            var _dkind = (is_struct(_dact) && variable_struct_exists(_dact, "kind")) ? string_lower(string(variable_struct_get(_dact, "kind"))) : "";
            var _ddata = __battle_ability_action_data(_dact);
            if (_dkind == "super_effective_multiplier" && _out > 1.0){
                var _dm = variable_struct_exists(_ddata, "mult") ? variable_struct_get(_ddata, "mult") : 0.75;
                _out *= _dm;
                try { __battle_queue_ability_action_dialog(_D, _dact, _A, { move_id:_move_id, type_mult:_type_mult }); } catch (e_filter_dialog) {}
            } else if (_dkind == "block_non_super_effective" && _out <= 1.0){
                _out = 0;
                try { __battle_queue_ability_action_dialog(_D, _dact, _A, { move_id:_move_id, type_mult:_type_mult }); } catch (e_wg_dialog) {}
            }
        }
        var _atk_actions = __battle_actor_ability_actions(_A, "type_effectiveness");
        for (var _ai = 0; _ai < array_length(_atk_actions); ++_ai){
            var _aact = _atk_actions[_ai];
            var _akind = (is_struct(_aact) && variable_struct_exists(_aact, "kind")) ? string_lower(string(variable_struct_get(_aact, "kind"))) : "";
            var _adata = __battle_ability_action_data(_aact);
            if (_akind == "not_very_effective_multiplier" && _out > 0 && _out < 1.0){
                var _am = variable_struct_exists(_adata, "mult") ? variable_struct_get(_adata, "mult") : 2;
                _out *= _am;
                try { __battle_queue_ability_action_dialog(_A, _aact, _D, { move_id:_move_id, type_mult:_type_mult }); } catch (e_tinted_dialog) {}
            }
        }
    } catch (e_ability_type_effectiveness) {}
    return _out;
}

function __battle_actor_has_major_status(_actor){
    if (!is_struct(_actor) || is_undefined(status_system_has_status)) return false;
    var _statuses = ["burn", "poison", "toxic", "paralysis", "paralyze", "sleep", "freeze"];
    for (var _i = 0; _i < array_length(_statuses); ++_i){
        try {
            if (status_system_has_status(_actor, _statuses[_i])) return true;
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon")) && status_system_has_status(variable_struct_get(_actor, "mon"), _statuses[_i])) return true;
        } catch (e_status_check) {}
    }
    return false;
}

function __battle_apply_ability_heal_or_block(_pid, _target_index, _A, _D, _move_id){
    if (!is_struct(_D) || !is_real(_move_id)) return false;
    var _mv_type = __battle_move_type_safe(_move_id, _A);
    var _type_name = __battle_type_name_by_id_safe(_mv_type);
    var _block = false;
    var _heal = 0;
    var _boost_flash = false;
    var _eff = __battle_actor_ability_effect(_D);
    var _ability_dialog_action = undefined;
    if (string_length(_type_name) > 0 && is_struct(_eff)){
        var _def_type_actions = __battle_actor_ability_actions(_D, "on_defend_type");
        for (var _dai = 0; _dai < array_length(_def_type_actions); ++_dai){
            var _act = _def_type_actions[_dai];
            var _act_kind = (is_struct(_act) && variable_struct_exists(_act, "kind")) ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
            var _data = __battle_ability_action_data(_act);
            var _act_type = (variable_struct_exists(_data, "type")) ? string_lower(string(variable_struct_get(_data, "type"))) : "";
            if (_act_type != _type_name) continue;
            switch (_act_kind){
                case "absorb_heal":
                    _block = true;
                    _ability_dialog_action = _act;
                    var _afrac = variable_struct_exists(_data, "fraction") ? variable_struct_get(_data, "fraction") : 0.25;
                    _heal = max(_heal, max(1, floor(__battle_hp_max(_D) * _afrac)));
                    break;
                case "block_stage_boost":
                    _block = true;
                    _ability_dialog_action = _act;
                    break;
                case "flash_fire":
                    _block = true;
                    _boost_flash = true;
                    _ability_dialog_action = _act;
                    break;
                case "block_type":
                    _block = true;
                    _ability_dialog_action = _act;
                    break;
            }
        }
        if (!_block && __battle_ability_effect_has_type(_eff, "blocked_types", _type_name)){
            _block = true;
        }
        if (_block && _type_name == "ground" && __battle_actor_has_any_ability(_D, ["levitate"])){
            var _gravity_active_csv = false;
            try {
                var _gravity_turns_csv = __battle_field_get_status_or(_pid, "gravity", 0);
                _gravity_active_csv = (is_real(_gravity_turns_csv) && _gravity_turns_csv > 0);
            } catch (e_gravity_levitate_csv) { _gravity_active_csv = false; }
            if (_gravity_active_csv) _block = false;
        }
        if (_block && _heal <= 0 && variable_struct_exists(_eff, "absorb_heal_types") && is_array(variable_struct_get(_eff, "absorb_heal_types"))){
            var _heals = variable_struct_get(_eff, "absorb_heal_types");
            for (var _hi = 0; _hi < array_length(_heals); ++_hi){
                var _h = _heals[_hi];
                if (is_struct(_h) && variable_struct_exists(_h, "type") && string_lower(string(variable_struct_get(_h, "type"))) == _type_name){
                    var _frac = variable_struct_exists(_h, "fraction") ? variable_struct_get(_h, "fraction") : 0.25;
                    _heal = max(1, floor(__battle_hp_max(_D) * _frac));
                    break;
                }
            }
        }
        if (_block && variable_struct_exists(_eff, "flash_fire") && variable_struct_get(_eff, "flash_fire") == true) _boost_flash = true;
    }

    if (!_block){
        if (_mv_type == __battle_type_id_by_name_safe("water") && __battle_actor_has_any_ability(_D, ["water-absorb", "storm-drain", "dry-skin"])){
            _block = true;
            _heal = max(1, floor(__battle_hp_max(_D) / 4));
        } else if (_mv_type == __battle_type_id_by_name_safe("electric") && __battle_actor_has_any_ability(_D, ["volt-absorb", "lightning-rod", "motor-drive"])){
            _block = true;
            if (__battle_actor_has_any_ability(_D, ["volt-absorb"])) _heal = max(1, floor(__battle_hp_max(_D) / 4));
        } else if (_mv_type == __battle_type_id_by_name_safe("fire") && __battle_actor_has_any_ability(_D, ["flash-fire"])){
            _block = true;
            _boost_flash = true;
        } else if (_mv_type == __battle_type_id_by_name_safe("grass") && __battle_actor_has_any_ability(_D, ["sap-sipper"])){
            _block = true;
        } else if (_mv_type == __battle_type_id_by_name_safe("ground") && __battle_actor_has_any_ability(_D, ["earth-eater"])){
            _block = true;
            _heal = max(1, floor(__battle_hp_max(_D) / 4));
        } else if (_mv_type == __battle_type_id_by_name_safe("fire") && __battle_actor_has_any_ability(_D, ["well-baked-body"])){
            _block = true;
        } else if (_mv_type == __battle_type_id_by_name_safe("flying") && __battle_actor_has_any_ability(_D, ["wind-rider"])){
            _block = true;
        } else if (_mv_type == __battle_type_id_by_name_safe("ground") && __battle_actor_has_any_ability(_D, ["levitate"])){
            var _gravity_active = false;
            try {
                var _gravity_turns = __battle_field_get_status_or(_pid, "gravity", 0);
                _gravity_active = (is_real(_gravity_turns) && _gravity_turns > 0);
            } catch (e_gravity_levitate) { _gravity_active = false; }
            if (!_gravity_active) _block = true;
        }
    }

    if (!_block) return false;

    var _before = __battle_hp_now(_D);
    if (_heal > 0){
        __battle_set_hp_now(_D, min(__battle_hp_max(_D), _before + _heal));
        __battle_clear_fainted_if_healed(_D);
        try { __battle_request_animation_safe(_pid, { type: "heal", target_index: _target_index, amount: _heal }); } catch (e_heal_anim) {}
    }
    if (_boost_flash) variable_struct_set(_D, "_flash_fire_active", true);
    try {
        var _did_generic_stage = false;
        var _def_type_actions_stage = __battle_actor_ability_actions(_D, "on_defend_type");
        for (var _sai = 0; _sai < array_length(_def_type_actions_stage); ++_sai){
            var _sact = _def_type_actions_stage[_sai];
            var _skind = (is_struct(_sact) && variable_struct_exists(_sact, "kind")) ? string_lower(string(variable_struct_get(_sact, "kind"))) : "";
            if (_skind != "block_stage_boost") continue;
            var _sdata = __battle_ability_action_data(_sact);
            var _stype = variable_struct_exists(_sdata, "type") ? string_lower(string(variable_struct_get(_sdata, "type"))) : "";
            if (_stype != _type_name) continue;
            var _sstat = variable_struct_exists(_sdata, "stat") ? variable_struct_get(_sdata, "stat") : "spa";
            var _sdelta = variable_struct_exists(_sdata, "delta") ? variable_struct_get(_sdata, "delta") : 1;
            __battle_ability_change_stage(_D, _sstat, _sdelta);
            _did_generic_stage = true;
        }
        if (!_did_generic_stage && is_struct(_eff) && variable_struct_exists(_eff, "block_stage_boosts") && is_array(variable_struct_get(_eff, "block_stage_boosts"))){
            var _boosts = variable_struct_get(_eff, "block_stage_boosts");
            for (var _bi = 0; _bi < array_length(_boosts); ++_bi){
                var _b = _boosts[_bi];
                if (is_struct(_b) && variable_struct_exists(_b, "type") && string_lower(string(variable_struct_get(_b, "type"))) == _type_name){
                    __battle_ability_change_stage(_D, variable_struct_get(_b, "stat"), variable_struct_get(_b, "delta"));
                }
            }
        } else {
            if (_mv_type == __battle_type_id_by_name_safe("electric") && __battle_actor_has_any_ability(_D, ["motor-drive"])) __battle_ability_change_stage(_D, "spe", 1);
            if (_mv_type == __battle_type_id_by_name_safe("electric") && __battle_actor_has_any_ability(_D, ["lightning-rod"])) __battle_ability_change_stage(_D, "spa", 1);
            if (_mv_type == __battle_type_id_by_name_safe("water") && __battle_actor_has_any_ability(_D, ["storm-drain"])) __battle_ability_change_stage(_D, "spa", 1);
            if (_mv_type == __battle_type_id_by_name_safe("grass") && __battle_actor_has_any_ability(_D, ["sap-sipper"])) __battle_ability_change_stage(_D, "atk", 1);
            if (_mv_type == __battle_type_id_by_name_safe("fire") && __battle_actor_has_any_ability(_D, ["well-baked-body"])) __battle_ability_change_stage(_D, "def", 2);
            if (_mv_type == __battle_type_id_by_name_safe("fire") && __battle_actor_has_any_ability(_D, ["thermal-exchange"])) __battle_ability_change_stage(_D, "atk", 1);
            if (_mv_type == __battle_type_id_by_name_safe("flying") && __battle_actor_has_any_ability(_D, ["wind-rider"])) __battle_ability_change_stage(_D, "atk", 1);
            if (_mv_type == __battle_type_id_by_name_safe("electric") && __battle_actor_has_any_ability(_D, ["electromorphosis", "wind-power"])) variable_struct_set(_D, "_ability_charge_next_electric", true);
        }
    } catch (e_absorb_stage) {}

    try {
        if (is_struct(_ability_dialog_action)) __battle_queue_ability_action_dialog(_D, _ability_dialog_action, _A, { move_id:_move_id, type:_type_name });
        else {
            var _name = variable_struct_exists(_D, "name") ? string(variable_struct_get(_D, "name")) : "The target";
            var _ab = __battle_actor_ability_name_lc(_D);
            _ab = string_replace_all(_ab, "-", " ");
            if (string_length(_ab) <= 0) _ab = "ability";
            dialog_queue(_name + "'s " + _ab + " activated!");
        }
    } catch (e_msg) {}
    return true;
}

function __battle_ability_damage_multiplier(_A, _D, _move_id){
    var _mult = 1.0;
    var _type = __battle_move_type_safe(_move_id, _A);
    var _type_name = __battle_type_name_by_id_safe(_type);
    try {
        if (__battle_hp_now(_A) * 3 <= __battle_hp_max(_A)){
            var _atk_eff = __battle_actor_ability_effect(_A);
            var _did_low_hp_action = false;
            var _deal_actions = __battle_actor_ability_actions(_A, "damage_dealt");
            for (var _dmi = 0; _dmi < array_length(_deal_actions); ++_dmi){
                var _dmact = _deal_actions[_dmi];
                var _dmkind = (is_struct(_dmact) && variable_struct_exists(_dmact, "kind")) ? string_lower(string(variable_struct_get(_dmact, "kind"))) : "";
                if (_dmkind != "low_hp_type_multiplier") continue;
                var _dmdata = __battle_ability_action_data(_dmact);
                if (!variable_struct_exists(_dmdata, "type") || string_lower(string(variable_struct_get(_dmdata, "type"))) != _type_name) continue;
                var _dmmult = variable_struct_exists(_dmdata, "mult") ? variable_struct_get(_dmdata, "mult") : 1.5;
                _mult *= _dmmult;
                _did_low_hp_action = true;
                try { __battle_queue_ability_action_dialog(_A, _dmact, _D, { move_id:_move_id, type:_type_name }); } catch (e_low_hp_dialog) {}
            }
            if (!_did_low_hp_action){
                if (is_struct(_atk_eff) && variable_struct_exists(_atk_eff, "low_hp_type") && string_length(string(variable_struct_get(_atk_eff, "low_hp_type"))) > 0 && string_lower(string(variable_struct_get(_atk_eff, "low_hp_type"))) == _type_name){
                    var _lh_mult = variable_struct_exists(_atk_eff, "low_hp_multiplier") ? variable_struct_get(_atk_eff, "low_hp_multiplier") : 1.5;
                    _mult *= _lh_mult;
                    try { __battle_queue_ability_dialog(_A, __battle_ability_actor_name(_A, "The Pokemon") + "'s " + __battle_ability_battle_label(__battle_ability_label(_A)) + "!"); } catch (e_low_hp_legacy_dialog) {}
                } else {
                    if (_type == __battle_type_id_by_name_safe("grass") && __battle_actor_has_any_ability(_A, ["overgrow"])) _mult *= 1.5;
                    if (_type == __battle_type_id_by_name_safe("fire") && __battle_actor_has_any_ability(_A, ["blaze"])) _mult *= 1.5;
                    if (_type == __battle_type_id_by_name_safe("water") && __battle_actor_has_any_ability(_A, ["torrent"])) _mult *= 1.5;
                    if (_type == __battle_type_id_by_name_safe("bug") && __battle_actor_has_any_ability(_A, ["swarm"])) _mult *= 1.5;
                }
            }
        }
        if (_type == __battle_type_id_by_name_safe("fire") && is_struct(_A) && variable_struct_exists(_A, "_flash_fire_active") && variable_struct_get(_A, "_flash_fire_active") == true) _mult *= 1.5;
        if (_type == __battle_type_id_by_name_safe("electric") && is_struct(_A) && variable_struct_exists(_A, "_ability_charge_next_electric") && variable_struct_get(_A, "_ability_charge_next_electric") == true){
            _mult *= 2;
            try { variable_struct_set(_A, "_ability_charge_next_electric", false); } catch (e_charge_clear) {}
        }
        try {
            var _pid_aura = (!is_undefined(__status_find_battle_pid)) ? __status_find_battle_pid(_A) : undefined;
            if (is_real(_pid_aura)){
                var _Baura = __battle_ensure_slot(_pid_aura);
                if (is_struct(_Baura) && variable_struct_exists(_Baura, "actor") && is_array(variable_struct_get(_Baura, "actor"))){
                    var _aura_actors = variable_struct_get(_Baura, "actor");
                    var _aidx_aura = -1;
                    var _didx_aura = -1;
                    for (var _axi = 0; _axi < array_length(_aura_actors); ++_axi){
                        if (_aura_actors[_axi] == _A) _aidx_aura = _axi;
                        if (_aura_actors[_axi] == _D) _didx_aura = _axi;
                    }
                    var _aside_aura = (_aidx_aura >= 0 && !is_undefined(__battle_actor_side)) ? __battle_actor_side(_aidx_aura) : -1;
                    var _dside_aura = (_didx_aura >= 0 && !is_undefined(__battle_actor_side)) ? __battle_actor_side(_didx_aura) : -2;
                    var _dc_aura = __battle_move_damage_class_safe(_move_id);
                    var _has_aura_break = false;
                    var _has_dark_aura = false;
                    var _has_fairy_aura = false;
                    for (var _aui = 0; _aui < array_length(_aura_actors); ++_aui){
                        var _support = _aura_actors[_aui];
                        if (!is_struct(_support) || __battle_hp_now(_support) <= 0) continue;
                        var _sside = (!is_undefined(__battle_actor_side)) ? __battle_actor_side(_aui) : -99;
                        if (__battle_actor_has_any_ability(_support, ["aura-break"])) _has_aura_break = true;
                        if (__battle_actor_has_any_ability(_support, ["dark-aura"])) _has_dark_aura = true;
                        if (__battle_actor_has_any_ability(_support, ["fairy-aura"])) _has_fairy_aura = true;
                        if (_sside == _aside_aura && _support != _A){
                            if (_dc_aura == 3 && __battle_actor_has_any_ability(_support, ["battery"])) _mult *= 1.3;
                            if (__battle_actor_has_any_ability(_support, ["power-spot"])) _mult *= 1.3;
                        }
                        if (_sside == _dside_aura && _support != _D){
                            if (__battle_actor_has_any_ability(_support, ["friend-guard"])) _mult *= 0.75;
                        }
                        if (_support != _A && _support != _D){
                            if (_dc_aura == 2 && _sside == _aside_aura && __battle_actor_has_any_ability(_support, ["sword-of-ruin"])) _mult *= 1.3333;
                            if (_dc_aura == 3 && _sside == _aside_aura && __battle_actor_has_any_ability(_support, ["beads-of-ruin"])) _mult *= 1.3333;
                            if (_dc_aura == 2 && _sside == _dside_aura && __battle_actor_has_any_ability(_support, ["tablets-of-ruin"])) _mult *= 0.75;
                            if (_dc_aura == 3 && _sside == _dside_aura && __battle_actor_has_any_ability(_support, ["vessel-of-ruin"])) _mult *= 0.75;
                        }
                    }
                    if ((_type_name == "dark" && _has_dark_aura) || (_type_name == "fairy" && _has_fairy_aura)){
                        _mult *= _has_aura_break ? 0.75 : 1.3333;
                    }
                }
            }
        } catch (e_ally_aura_mult) {}
        try {
            var _all_deal_actions = __battle_actor_ability_actions(_A, "damage_dealt");
            var _move_type_actions = __battle_actor_ability_actions(_A, "move_type_check");
            var _move_ident_boost = __battle_ability_move_identifier_safe(_move_id);
            var _move_power_boost = __battle_ability_move_power_safe(_move_id);
            var _weather_id_boost = __battle_ability_current_weather_id(_A);
            try {
                if (array_length(_move_type_actions) > 0){
                    var _ab_convert = __battle_actor_ability_name_lc(_A);
                    var _normal_id_convert = __battle_type_id_by_name_safe("normal");
                    var _base_type_convert = -1;
                    if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){
                        var _base_move_convert = global._moves[_move_id];
                        if (is_struct(_base_move_convert) && variable_struct_exists(_base_move_convert, "type_id") && is_real(variable_struct_get(_base_move_convert, "type_id"))) _base_type_convert = variable_struct_get(_base_move_convert, "type_id");
                    }
                    var _converted_boost = false;
                    if (_ab_convert == "normalize") _converted_boost = true;
                    else if ((_ab_convert == "refrigerate" || _ab_convert == "pixilate" || _ab_convert == "aerilate" || _ab_convert == "galvanize") && _base_type_convert == _normal_id_convert) _converted_boost = true;
                    else if (_ab_convert == "liquid-voice" && __battle_ability_move_is_sound(_move_id)) _converted_boost = true;
                    if (_converted_boost){
                        _mult *= 1.2;
                        try { __battle_queue_ability_action_dialog(_A, _move_type_actions[0], _D, { move_id:_move_id }); } catch (e_convert_dialog) {}
                    }
                }
            } catch (e_type_convert_boost) {}
            for (var _gdi = 0; _gdi < array_length(_all_deal_actions); ++_gdi){
                var _gact = _all_deal_actions[_gdi];
                if (!is_struct(_gact)) continue;
                var _gkind = variable_struct_exists(_gact, "kind") ? string_lower(string(variable_struct_get(_gact, "kind"))) : "";
                var _gdata = __battle_ability_action_data(_gact);
                var _gm = (variable_struct_exists(_gdata, "mult") && is_real(variable_struct_get(_gdata, "mult"))) ? variable_struct_get(_gdata, "mult") : 1;
                var _apply_gm = false;
                switch (_gkind){
                    case "contact_multiplier":
                        _apply_gm = (!is_undefined(__battle_move_is_contactish) && __battle_move_is_contactish(_move_id));
                        break;
                    case "low_power_multiplier":
                        var _maxp = (variable_struct_exists(_gdata, "max_power") && is_real(variable_struct_get(_gdata, "max_power"))) ? variable_struct_get(_gdata, "max_power") : 60;
                        _apply_gm = (_move_power_boost > 0 && _move_power_boost <= _maxp);
                        break;
                    case "flag_multiplier":
                        _apply_gm = __battle_ability_move_has_keyword(_move_id, variable_struct_exists(_gdata, "flag") ? variable_struct_get(_gdata, "flag") : "");
                        break;
                    case "recoil_move_multiplier":
                        _apply_gm = (string_pos("recoil", _move_ident_boost) > 0 || _move_ident_boost == "take-down" || _move_ident_boost == "double-edge" || _move_ident_boost == "submission" || _move_ident_boost == "brave-bird" || _move_ident_boost == "flare-blitz" || _move_ident_boost == "wild-charge" || _move_ident_boost == "head-smash" || _move_ident_boost == "wood-hammer");
                        break;
                    case "secondary_effect_multiplier":
                        _apply_gm = __battle_ability_move_has_secondary_effect(_move_id);
                        if (_apply_gm) try { variable_struct_set(_A, "_suppress_secondary_effects_once", true); } catch (e_sheer_tag) {}
                        break;
                    case "sound_move_multiplier":
                        _apply_gm = __battle_ability_move_is_sound(_move_id);
                        break;
                    case "type_multiplier":
                    case "aura_type_modifier":
                        var _want_type = variable_struct_exists(_gdata, "type") ? string_lower(string(variable_struct_get(_gdata, "type"))) : "";
                        var _ab_type_boost = __battle_actor_ability_name_lc(_A);
                        if (_gkind == "aura_type_modifier" && (_ab_type_boost == "dark-aura" || _ab_type_boost == "fairy-aura" || _ab_type_boost == "aura-break")){
                            _apply_gm = false;
                            break;
                        }
                        if (string_length(_want_type) <= 0){
                            if (_ab_type_boost == "steelworker" || _ab_type_boost == "steely-spirit") _want_type = "steel";
                            else if (_ab_type_boost == "rocky-payload") _want_type = "rock";
                            else if (_ab_type_boost == "transistor") _want_type = "electric";
                            else if (_ab_type_boost == "dragons-maw") _want_type = "dragon";
                        }
                        if (string_length(_want_type) > 0 && (!is_real(_gm) || _gm == 1)) _gm = 1.5;
                        _apply_gm = (string_length(_want_type) > 0 && _want_type == _type_name);
                        break;
                    case "weather_type_multiplier":
                        var _wtypes = variable_struct_exists(_gdata, "types") ? variable_struct_get(_gdata, "types") : (variable_struct_exists(_gdata, "type") ? variable_struct_get(_gdata, "type") : []);
                        var _wweathers = variable_struct_exists(_gdata, "weather") ? variable_struct_get(_gdata, "weather") : [];
                        _apply_gm = (string_length(_weather_id_boost) > 0 && __battle_ability_list_contains(_wweathers, _weather_id_boost) && __battle_ability_list_contains(_wtypes, _type_name));
                        break;
                    case "critical_multiplier_bonus":
                        var _crit_now = false;
                        try { var _Bcrit_now = __battle_ensure_slot(0); _crit_now = is_struct(_Bcrit_now) && variable_struct_exists(_Bcrit_now, "_last_crit") && variable_struct_get(_Bcrit_now, "_last_crit") == true; } catch (e_crit_bonus_read) {}
                        _apply_gm = _crit_now;
                        break;
                    case "gender_match_multiplier":
                        var _asex = __battle_ability_actor_sex(_A);
                        var _dsex = __battle_ability_actor_sex(_D);
                        if (string_length(_asex) > 0 && string_length(_dsex) > 0 && _asex != "unknown" && _dsex != "unknown"){
                            if (_asex == _dsex) _gm = (variable_struct_exists(_gdata, "same_sex_mult") && is_real(variable_struct_get(_gdata, "same_sex_mult"))) ? variable_struct_get(_gdata, "same_sex_mult") : 1.25;
                            else _gm = (variable_struct_exists(_gdata, "different_sex_mult") && is_real(variable_struct_get(_gdata, "different_sex_mult"))) ? variable_struct_get(_gdata, "different_sex_mult") : 0.75;
                            _apply_gm = true;
                        }
                        break;
                    case "moving_last_multiplier":
                        try { _apply_gm = variable_struct_exists(_A, "_will_move_last_this_turn") && variable_struct_get(_A, "_will_move_last_this_turn") == true; } catch (e_last_mult) { _apply_gm = false; }
                        break;
                    case "target_switched_in_multiplier":
                        try {
                            var _pid_stake = (!is_undefined(__status_find_battle_pid)) ? __status_find_battle_pid(_D) : undefined;
                            var _turn_stake = -9999;
                            if (is_real(_pid_stake)){
                                var _Bstake = __battle_ensure_slot(_pid_stake);
                                if (is_struct(_Bstake) && variable_struct_exists(_Bstake, "turn_i") && is_real(variable_struct_get(_Bstake, "turn_i"))) _turn_stake = floor(variable_struct_get(_Bstake, "turn_i"));
                            }
                            var _switched_turn = (variable_struct_exists(_D, "_switched_in_turn") && is_real(variable_struct_get(_D, "_switched_in_turn"))) ? floor(variable_struct_get(_D, "_switched_in_turn")) : -9998;
                            _apply_gm = (_switched_turn == _turn_stake);
                        } catch (e_stake_mult) { _apply_gm = false; }
                        break;
                }
                if (_apply_gm && is_real(_gm) && _gm != 1){
                    _mult *= _gm;
                    try { __battle_queue_ability_action_dialog(_A, _gact, _D, { move_id:_move_id, type:_type_name }); } catch (e_gdeal_dialog) {}
                }
            }
        } catch (e_generic_dealt_mult) {}
        var _def_eff = __battle_actor_ability_effect(_D);
        var _used_table_mult = false;
        var _taken_actions = __battle_actor_ability_actions(_D, "damage_taken");
        for (var _tai = 0; _tai < array_length(_taken_actions); ++_tai){
            var _tact = _taken_actions[_tai];
            var _tkind = (is_struct(_tact) && variable_struct_exists(_tact, "kind")) ? string_lower(string(variable_struct_get(_tact, "kind"))) : "";
            var _tdata = __battle_ability_action_data(_tact);
            var _tmult = variable_struct_exists(_tdata, "mult") ? variable_struct_get(_tdata, "mult") : 1;
            var _apply_tm = false;
            if (_tkind == "type_multiplier"){
                _apply_tm = (variable_struct_exists(_tdata, "type") && string_lower(string(variable_struct_get(_tdata, "type"))) == _type_name);
            } else if (_tkind == "sound_move_multiplier"){
                _apply_tm = __battle_ability_move_is_sound(_move_id);
            } else if (_tkind == "conditional_damage_or_boost"){
                var _abid = __battle_actor_ability_name_lc(_D);
                if ((_abid == "multiscale" || _abid == "shadow-shield") && __battle_hp_now(_D) >= __battle_hp_max(_D)){ _tmult = 0.5; _apply_tm = true; }
                if (_abid == "fluffy"){
                    if (!is_undefined(__battle_move_is_contactish) && __battle_move_is_contactish(_move_id)){ _tmult = 0.5; _apply_tm = true; }
                    if (_type_name == "fire"){ _tmult = 2; _apply_tm = true; }
                }
                if (_abid == "ice-scales"){
                    var _dc_taken = __battle_move_damage_class_safe(_move_id);
                    if (is_real(_dc_taken) && floor(_dc_taken) == 3){ _tmult = 0.5; _apply_tm = true; }
                }
            }
            if (_apply_tm){
                _mult *= _tmult;
                _used_table_mult = true;
                try { __battle_queue_ability_action_dialog(_D, _tact, _A, { move_id:_move_id, type:_type_name }); } catch (e_taken_dialog) {}
            }
        }
        if (!_used_table_mult && is_struct(_def_eff) && variable_struct_exists(_def_eff, "damage_taken_multipliers") && is_array(variable_struct_get(_def_eff, "damage_taken_multipliers"))){
            var _taken = variable_struct_get(_def_eff, "damage_taken_multipliers");
            for (var _ti = 0; _ti < array_length(_taken); ++_ti){
                var _rec = _taken[_ti];
                if (is_struct(_rec) && variable_struct_exists(_rec, "type") && string_lower(string(variable_struct_get(_rec, "type"))) == _type_name){
                    var _tm = variable_struct_exists(_rec, "mult") ? variable_struct_get(_rec, "mult") : 1;
                    _mult *= _tm;
                    _used_table_mult = true;
                }
            }
        }
        if (!_used_table_mult && (_type == __battle_type_id_by_name_safe("fire") || _type == __battle_type_id_by_name_safe("ice")) && __battle_actor_has_any_ability(_D, ["thick-fat"])) _mult *= 0.5;
    } catch (e_ability_mult) {}
    try {
        if (!is_undefined(item_runtime_actor_held_actions)){
            var _item_taken_actions = item_runtime_actor_held_actions(_D, "damage_taken");
            for (var _itai = 0; _itai < array_length(_item_taken_actions); ++_itai){
                var _itact = _item_taken_actions[_itai];
                if (!is_struct(_itact)) continue;
                var _itkind = variable_struct_exists(_itact, "kind") ? string_lower(string(variable_struct_get(_itact, "kind"))) : "";
                var _itdata = __battle_item_action_data(_itact);
                var _want_taken_type = variable_struct_exists(_itdata, "type") ? string_lower(string(variable_struct_get(_itdata, "type"))) : "";
                if (string_length(_want_taken_type) <= 0 || _want_taken_type != _type_name) continue;
                var _needs_super = (_itkind == "resist_super_effective_type");
                if (_needs_super && _mult <= 1) continue;
                if (!is_undefined(__battle_ability_item_blocked_by_opponent) && __battle_ability_item_blocked_by_opponent(_D, item_runtime_actor_held_item_id(_D))) continue;
                var _taken_mult = (variable_struct_exists(_itdata, "multiplier") && is_real(variable_struct_get(_itdata, "multiplier"))) ? real(variable_struct_get(_itdata, "multiplier")) : 0.5;
                _mult *= _taken_mult;
                try { dialog_queue(__battle_ability_actor_name(_D, "The Pokemon") + "'s " + __battle_held_item_label(_D) + " weakened the attack!"); } catch (e_resist_berry_dialog) {}
                try {
                    var _consumed_taken_item = __battle_item_consume_held(_D);
                    if (_consumed_taken_item > 0 && !is_undefined(__battle_apply_after_item_consumed_ability)) __battle_apply_after_item_consumed_ability(_D, _consumed_taken_item);
                } catch (e_resist_berry_consume) {}
                break;
            }
        }
    } catch (e_item_taken_mult) {}
    try {
        if (!is_undefined(item_runtime_actor_held_actions)){
            var _item_deal_actions = item_runtime_actor_held_actions(_A, "damage_dealt");
            var _dc_item = __battle_move_damage_class_safe(_move_id);
            for (var _idi = 0; _idi < array_length(_item_deal_actions); ++_idi){
                var _iact = _item_deal_actions[_idi];
                if (!is_struct(_iact)) continue;
                var _ikind = variable_struct_exists(_iact, "kind") ? string_lower(string(variable_struct_get(_iact, "kind"))) : "";
                var _idata = __battle_item_action_data(_iact);
                var _im = 1;
                if (variable_struct_exists(_idata, "multiplier") && is_real(variable_struct_get(_idata, "multiplier"))) _im = variable_struct_get(_idata, "multiplier");
                else if (variable_struct_exists(_idata, "mult") && is_real(variable_struct_get(_idata, "mult"))) _im = variable_struct_get(_idata, "mult");
                var _apply_item_mult = false;
                switch (_ikind){
                    case "multiplier":
                        _apply_item_mult = true;
                        break;
                    case "type_multiplier":
                    case "type_or_category_multiplier":
                        var _want_item_type = variable_struct_exists(_idata, "type") ? string_lower(string(variable_struct_get(_idata, "type"))) : "";
                        if (_want_item_type == "physical") _apply_item_mult = (is_real(_dc_item) && floor(_dc_item) == 2);
                        else if (_want_item_type == "special") _apply_item_mult = (is_real(_dc_item) && floor(_dc_item) == 3);
                        else _apply_item_mult = (string_length(_want_item_type) > 0 && _want_item_type == _type_name);
                        break;
                    case "prose_multiplier_pending":
                        _apply_item_mult = false;
                        break;
                }
                if (_apply_item_mult && is_real(_im) && _im != 1){
                    _mult *= _im;
                    try {
                        var _iname = __battle_held_item_label(_A);
                        var _aname = __battle_ability_actor_name(_A, "The Pokemon");
                        dialog_queue(_aname + "'s " + _iname + " boosted the move!");
                    } catch (e_item_boost_dialog) {}
                }
            }
        }
    } catch (e_item_dealt_mult) {}
    return _mult;
}

function __battle_ability_change_stage(_actor, _stat, _delta){
    if (!is_struct(_actor) || !is_string(_stat) || !is_real(_delta)) return false;
    var _final_delta = _delta;
    try {
        var _stage_actions = __battle_actor_ability_actions(_actor, "stage_change");
        for (var _sai = 0; _sai < array_length(_stage_actions); ++_sai){
            var _sact = _stage_actions[_sai];
            if (!is_struct(_sact)) continue;
            var _skind = variable_struct_exists(_sact, "kind") ? string_lower(string(variable_struct_get(_sact, "kind"))) : "";
            var _sdata = __battle_ability_action_data(_sact);
            if (_skind == "block_stat_lowering" && _final_delta < 0){
                var _stats = variable_struct_exists(_sdata, "stats") ? variable_struct_get(_sdata, "stats") : "all";
                var _blocked = false;
                if (is_array(_stats)){
                    for (var _bi = 0; _bi < array_length(_stats); ++_bi){
                        if (string_lower(string(_stats[_bi])) == string_lower(_stat)){ _blocked = true; break; }
                    }
                } else {
                    var _stat_key = string_lower(string(_stats));
                    _blocked = (_stat_key == "all" || _stat_key == string_lower(_stat));
                }
                if (_blocked){
                    try { __battle_queue_ability_action_dialog(_actor, _sact, _actor, { stat:_stat, delta:_delta }); } catch (e_block_stage_dialog) {}
                    return false;
                }
            } else if (_skind == "invert_stage_delta"){
                _final_delta = -_final_delta;
            } else if (_skind == "stage_delta_multiplier"){
                var _stage_mult = (variable_struct_exists(_sdata, "mult") && is_real(variable_struct_get(_sdata, "mult"))) ? variable_struct_get(_sdata, "mult") : 1;
                _final_delta *= _stage_mult;
            }
        }
    } catch (e_stage_ability_mod) {}
    var _stages = {};
    try {
        if (variable_struct_exists(_actor, "_stages") && is_struct(variable_struct_get(_actor, "_stages"))) _stages = variable_struct_get(_actor, "_stages");
    } catch (e_stage_read) { _stages = {}; }
    var _cur = 0;
    try { if (variable_struct_exists(_stages, _stat) && is_real(variable_struct_get(_stages, _stat))) _cur = variable_struct_get(_stages, _stat); } catch (e_cur) {}
    var _next = clamp(floor(_cur + _final_delta), -6, 6);
    if (_next == _cur) return false;
    variable_struct_set(_stages, _stat, _next);
    variable_struct_set(_actor, "_stages", _stages);
    try {
        if (_final_delta < 0){
            var _react_actions = __battle_actor_ability_actions(_actor, "after_stat_lowered");
            for (var _rai = 0; _rai < array_length(_react_actions); ++_rai){
                var _ract = _react_actions[_rai];
                if (!is_struct(_ract)) continue;
                var _rkind = variable_struct_exists(_ract, "kind") ? string_lower(string(variable_struct_get(_ract, "kind"))) : "";
                if (_rkind != "self_stage_change") continue;
                var _rdata = __battle_ability_action_data(_ract);
                var _rstat = variable_struct_exists(_rdata, "stat") ? string(variable_struct_get(_rdata, "stat")) : "atk";
                var _rdelta = variable_struct_exists(_rdata, "delta") ? variable_struct_get(_rdata, "delta") : 1;
                __battle_ability_change_stage(_actor, _rstat, _rdelta);
                try { __battle_queue_ability_action_dialog(_actor, _ract, _actor, { stat:_rstat, delta:_rdelta }); } catch (e_stat_lowered_dialog) {}
            }
        }
    } catch (e_after_stat_lowered) {}
    return true;
}

function __battle_ability_move_identifier_safe(_move_id){
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){
            var _mv = global._moves[_move_id];
            if (is_struct(_mv) && variable_struct_exists(_mv, "identifier")) return string_lower(string(variable_struct_get(_mv, "identifier")));
        }
    } catch (e_ident) {}
    return "";
}

function __battle_ability_move_power_safe(_move_id){
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){
            var _mv = global._moves[_move_id];
            if (is_struct(_mv)){
                if (variable_struct_exists(_mv, "power") && is_real(variable_struct_get(_mv, "power"))) return variable_struct_get(_mv, "power");
                if (variable_struct_exists(_mv, "base_power") && is_real(variable_struct_get(_mv, "base_power"))) return variable_struct_get(_mv, "base_power");
            }
        }
    } catch (e_power) {}
    try {
        if (!is_undefined(__battle_move_behavior_full)){
            var _beh = __battle_move_behavior_full(_move_id);
            if (is_struct(_beh) && variable_struct_exists(_beh, "power") && is_real(variable_struct_get(_beh, "power"))) return variable_struct_get(_beh, "power");
        }
    } catch (e_beh_power) {}
    return 0;
}

function __battle_ability_move_has_keyword(_move_id, _keyword){
    var _ident = __battle_ability_move_identifier_safe(_move_id);
    var _key = string_lower(string(_keyword));
    if (string_length(_ident) <= 0 || string_length(_key) <= 0) return false;
    if (string_pos(_key, _ident) > 0 || string_pos(_ident, _key) > 0) return true;
    if (_key == "punch" && (string_pos("punch", _ident) > 0 || _ident == "comet-punch" || _ident == "dizzy-punch")) return true;
    if (_key == "bite" && (string_pos("bite", _ident) > 0 || string_pos("fang", _ident) > 0 || _ident == "jaw-lock")) return true;
    if (_key == "pulse" && string_pos("pulse", _ident) > 0) return true;
    if (_key == "slicing" && (string_pos("slash", _ident) > 0 || string_pos("cut", _ident) > 0 || _ident == "leaf-blade" || _ident == "x-scissor")) return true;
    return false;
}

function __battle_ability_move_is_sound(_move_id){
    var _ident = __battle_ability_move_identifier_safe(_move_id);
    if (string_length(_ident) <= 0) return false;
    return (string_pos("sound", _ident) > 0 || string_pos("voice", _ident) > 0 || string_pos("song", _ident) > 0 || string_pos("echo", _ident) > 0 || string_pos("noise", _ident) > 0 || string_pos("snore", _ident) > 0 || _ident == "boomburst" || _ident == "hyper-voice" || _ident == "bug-buzz" || _ident == "uproar" || _ident == "growl" || _ident == "roar" || _ident == "sing");
}

function __battle_ability_move_has_secondary_effect(_move_id){
    try {
        if (!is_undefined(__battle_get_move_meta)){
            var _mm = __battle_get_move_meta(_move_id);
            if (is_struct(_mm)){
                if (variable_struct_exists(_mm, "ailment_chance") && real(variable_struct_get(_mm, "ailment_chance")) > 0) return true;
                if (variable_struct_exists(_mm, "stat_chance") && real(variable_struct_get(_mm, "stat_chance")) > 0) return true;
                if (variable_struct_exists(_mm, "flinch_chance") && real(variable_struct_get(_mm, "flinch_chance")) > 0) return true;
                if (variable_struct_exists(_mm, "effect_chance") && real(variable_struct_get(_mm, "effect_chance")) > 0) return true;
            }
        }
    } catch (e_secondary_meta) {}
    return false;
}

function __battle_ability_current_weather_id(_actor){
    try {
        var _pid = (!is_undefined(__status_find_battle_pid)) ? __status_find_battle_pid(_actor) : undefined;
        if (!is_real(_pid)) return "";
        var _w = __battle_get_weather(_pid);
        if (!__battle_weather_is_active(_w)) return "";
        if (!is_undefined(__battle_weather_suppressed_by_ability) && __battle_weather_suppressed_by_ability(_pid)) return "";
        return __battle_weather_get_normalized_id(_w);
    } catch (e_weather_id) {}
    return "";
}

function __battle_ability_list_contains(_list, _value){
    var _want = string_lower(string(_value));
    if (!is_array(_list)) _list = [string(_list)];
    for (var _i = 0; _i < array_length(_list); ++_i){
        if (string_lower(string(_list[_i])) == _want) return true;
    }
    return false;
}

function __battle_ability_actor_sex(_actor){
    if (!is_struct(_actor)) return "";
    var _fields = ["sex", "gender"];
    for (var _i = 0; _i < array_length(_fields); ++_i){
        var _f = _fields[_i];
        try {
            if (variable_struct_exists(_actor, _f)){
                var _v = string_lower(string(variable_struct_get(_actor, _f)));
                if (string_length(_v) > 0) return _v;
            }
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
                var _m = variable_struct_get(_actor, "mon");
                if (variable_struct_exists(_m, _f)){
                    var _mv = string_lower(string(variable_struct_get(_m, _f)));
                    if (string_length(_mv) > 0) return _mv;
                }
            }
        } catch (e_sex) {}
    }
    return "";
}

function __battle_ability_secondary_effect_chance(_A, _D, _chance){
    var _out = clamp(floor(is_real(_chance) ? _chance : 0), 0, 100);
    try {
        if (is_struct(_A) && variable_struct_exists(_A, "_suppress_secondary_effects_once") && variable_struct_get(_A, "_suppress_secondary_effects_once") == true) return 0;
    } catch (e_suppress_once) {}
    try {
        var _def_actions = __battle_actor_ability_actions(_D, "secondary_effect_check");
        for (var _di = 0; _di < array_length(_def_actions); ++_di){
            var _dact = _def_actions[_di];
            if (!is_struct(_dact)) continue;
            var _dkind = variable_struct_exists(_dact, "kind") ? string_lower(string(variable_struct_get(_dact, "kind"))) : "";
            if (_dkind == "block_secondary_effects"){
                try { __battle_queue_ability_action_dialog(_D, _dact, _A, {}); } catch (e_block_secondary_dialog) {}
                return 0;
            }
        }
        var _atk_actions = __battle_actor_ability_actions(_A, "secondary_effect_check");
        for (var _ai = 0; _ai < array_length(_atk_actions); ++_ai){
            var _act = _atk_actions[_ai];
            if (!is_struct(_act)) continue;
            var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
            if (_kind != "secondary_chance_multiplier") continue;
            var _data = __battle_ability_action_data(_act);
            var _mult = (variable_struct_exists(_data, "mult") && is_real(variable_struct_get(_data, "mult"))) ? variable_struct_get(_data, "mult") : 1;
            _out = clamp(floor(_out * _mult), 0, 100);
        }
    } catch (e_secondary_chance) {}
    return _out;
}

function __battle_ability_item_name_by_id(_item_id){
    if (!is_real(_item_id) || _item_id <= 0) return "";
    try {
        if (variable_global_exists("_items") && is_array(global._items) && _item_id < array_length(global._items)){
            var _it = global._items[floor(_item_id)];
            if (is_struct(_it)){
                if (variable_struct_exists(_it, "identifier")) return string_lower(string(variable_struct_get(_it, "identifier")));
                if (variable_struct_exists(_it, "name")) return string_lower(string(variable_struct_get(_it, "name")));
            }
        }
    } catch (e_item_name) {}
    return "";
}

function __battle_ability_item_is_berry(_item_id){
    var _nm = __battle_ability_item_name_by_id(_item_id);
    return (string_length(_nm) > 0 && string_pos("berry", _nm) > 0);
}

function __battle_ability_item_effect_multiplier(_actor, _item_id){
    var _mult = 1.0;
    if (!is_struct(_actor) || !__battle_ability_item_is_berry(_item_id)) return _mult;
    try {
        var _actions = __battle_actor_ability_actions(_actor, "item_check");
        for (var _ai = 0; _ai < array_length(_actions); ++_ai){
            var _act = _actions[_ai];
            if (!is_struct(_act)) continue;
            var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
            if (_kind != "berry_effect_multiplier") continue;
            var _data = __battle_ability_action_data(_act);
            var _m = (variable_struct_exists(_data, "mult") && is_real(variable_struct_get(_data, "mult"))) ? variable_struct_get(_data, "mult") : 1;
            _mult *= _m;
            try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_ripen_dialog) {}
        }
    } catch (e_item_mult) {}
    return _mult;
}

function __battle_ability_item_blocked_by_opponent(_actor, _item_id){
    if (!is_struct(_actor) || !__battle_ability_item_is_berry(_item_id)) return false;
    try {
        var _pid = (!is_undefined(__status_find_battle_pid)) ? __status_find_battle_pid(_actor) : undefined;
        if (!is_real(_pid)) return false;
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return false;
        var _actors = variable_struct_get(_B, "actor");
        var _actor_idx = -1;
        for (var _i = 0; _i < array_length(_actors); ++_i){
            if (is_struct(_actors[_i]) && (_actors[_i] == _actor || (variable_struct_exists(_actors[_i], "mon") && variable_struct_get(_actors[_i], "mon") == _actor))){ _actor_idx = _i; break; }
        }
        var _actor_side = (is_real(_actor_idx) && _actor_idx >= 0 && !is_undefined(__battle_actor_side)) ? __battle_actor_side(_actor_idx) : 0;
        for (var _oi = 0; _oi < array_length(_actors); ++_oi){
            var _opp = _actors[_oi];
            if (!is_struct(_opp) || __battle_hp_now(_opp) <= 0) continue;
            if (!is_undefined(__battle_actor_side) && __battle_actor_side(_oi) == _actor_side) continue;
            var _actions = __battle_actor_ability_actions(_opp, "item_check");
            for (var _ai = 0; _ai < array_length(_actions); ++_ai){
                var _act = _actions[_ai];
                if (!is_struct(_act)) continue;
                var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
                if (_kind == "block_opponent_berries"){
                    try { __battle_queue_ability_action_dialog(_opp, _act, _actor, {}); } catch (e_unnerve_dialog) {}
                    return true;
                }
            }
        }
    } catch (e_item_block) {}
    return false;
}

function __battle_apply_after_item_consumed_ability(_actor, _item_id){
    if (!is_struct(_actor) || !__battle_ability_item_is_berry(_item_id)) return false;
    var _did = false;
    try {
        variable_struct_set(_actor, "_last_consumed_berry_id", floor(_item_id));
        variable_struct_set(_actor, "_consumed_item", floor(_item_id));
        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
            var _mon = variable_struct_get(_actor, "mon");
            variable_struct_set(_mon, "_last_consumed_berry_id", floor(_item_id));
            variable_struct_set(_mon, "_consumed_item", floor(_item_id));
        }
    } catch (e_consumed_mark) {}
    try {
        var _actions = __battle_actor_ability_actions(_actor, "after_item_consumed");
        for (var _ai = 0; _ai < array_length(_actions); ++_ai){
            var _act = _actions[_ai];
            if (!is_struct(_act)) continue;
            var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
            var _data = __battle_ability_action_data(_act);
            if (_kind == "heal_fraction_if_berry"){
                var _frac = (variable_struct_exists(_data, "fraction") && is_real(variable_struct_get(_data, "fraction"))) ? variable_struct_get(_data, "fraction") : 0.333333;
                var _before = __battle_hp_now(_actor);
                var _maxhp = max(1, __battle_hp_max(_actor));
                if (_before > 0 && _before < _maxhp){
                    var _after = min(_maxhp, _before + max(1, floor(_maxhp * _frac)));
                    __battle_set_hp_now(_actor, _after);
                    try { __battle_request_animation_safe(0, { type:"heal", actor:_actor, amount:(_after - _before) }); } catch (e_cp_anim) {}
                    try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_cp_dialog) {}
                    _did = true;
                }
            } else if (_kind == "reuse_berry_next_turn"){
                var _is_ability_reuse = false;
                try { _is_ability_reuse = variable_struct_exists(_actor, "_reusing_berry_from_ability") && variable_struct_get(_actor, "_reusing_berry_from_ability") == true; } catch (e_reuse_guard) { _is_ability_reuse = false; }
                if (!_is_ability_reuse){
                    variable_struct_set(_actor, "_reuse_berry_next_turn_id", floor(_item_id));
                    _did = true;
                }
            }
        }
    } catch (e_after_item) {}
    return _did;
}

function __battle_ability_blocks_item_removal(_holder, _source){
    if (!is_struct(_holder)) return false;
    try {
        var _actions = __battle_actor_ability_actions(_holder, "item_check");
        for (var _ai = 0; _ai < array_length(_actions); ++_ai){
            var _act = _actions[_ai];
            if (!is_struct(_act)) continue;
            var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
            if (_kind == "block_item_removal"){
                try { __battle_queue_ability_action_dialog(_holder, _act, _source, {}); } catch (e_sticky_dialog) {}
                return true;
            }
        }
    } catch (e_item_remove_block) {}
    return false;
}

function __battle_ability_move_target_blocked(_A, _D, _move_id){
    if (!is_struct(_D)) return false;
    var _ident = __battle_ability_move_identifier_safe(_move_id);
    try {
        var _actions = __battle_actor_ability_actions(_D, "move_target_filter");
        for (var _ai = 0; _ai < array_length(_actions); ++_ai){
            var _act = _actions[_ai];
            if (!is_struct(_act)) continue;
            var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
            var _blocked = false;
            switch (_kind){
                case "block_sound":
                    _blocked = __battle_ability_move_is_sound(_move_id);
                    break;
                case "block_ball_bomb":
                    _blocked = (string_pos("ball", _ident) > 0 || string_pos("bomb", _ident) > 0 || string_pos("bullet", _ident) > 0 || _ident == "aura-sphere" || _ident == "focus-blast" || _ident == "seed-bomb");
                    break;
                case "block_powder":
                    _blocked = (string_pos("powder", _ident) > 0 || _ident == "spore" || _ident == "cotton-spore" || _ident == "stun-spore" || _ident == "sleep-powder" || _ident == "poison-powder" || _ident == "rage-powder");
                    break;
                case "block_explosion_moves":
                    _blocked = (_ident == "explosion" || _ident == "self-destruct" || _ident == "mind-blown" || _ident == "misty-explosion");
                    break;
                case "reflect_or_block_status_move":
                    var _dc = 0;
                    try { if (!is_undefined(scr_move_damage_class_by_id)) _dc = scr_move_damage_class_by_id(_move_id); } catch (e_filter_dc) { _dc = 0; }
                    _blocked = (is_real(_dc) && floor(_dc) == 1);
                    break;
            }
            if (_blocked){
                try { __battle_queue_ability_action_dialog(_D, _act, _A, { move_id:_move_id }); } catch (e_target_block_dialog) {}
                return true;
            }
        }
        var _field_actions = [];
        try { _field_actions = __battle_actor_ability_actions(_A, "move_target_filter"); } catch (e_attack_filter) { _field_actions = []; }
        for (var _fi = 0; _fi < array_length(_field_actions); ++_fi){
            var _fact = _field_actions[_fi];
            if (!is_struct(_fact)) continue;
            var _fkind = variable_struct_exists(_fact, "kind") ? string_lower(string(variable_struct_get(_fact, "kind"))) : "";
            if (_fkind == "block_explosion_moves" && (_ident == "explosion" || _ident == "self-destruct" || _ident == "mind-blown" || _ident == "misty-explosion")){
                try { __battle_queue_ability_action_dialog(_A, _fact, _D, { move_id:_move_id }); } catch (e_damp_user_dialog) {}
                return true;
            }
        }
    } catch (e_target_filter) {}
    return false;
}

function __battle_apply_entry_abilities(_pid, _actor_index){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return false;
    var _actors = variable_struct_get(_B, "actor");
    if (!is_real(_actor_index) || _actor_index < 0 || _actor_index >= array_length(_actors)) return false;
    var _actor = _actors[_actor_index];
    if (!is_struct(_actor)) return false;
    var _ability = __battle_actor_ability_name_lc(_actor);
    if (string_length(_ability) <= 0) return false;
    var _eff = __battle_actor_ability_effect(_actor);

    var _actor_name = variable_struct_exists(_actor, "name") ? string(variable_struct_get(_actor, "name")) : "The Pokemon";

    try {
        var _entry_actions_weather = __battle_actor_ability_actions(_actor, "on_entry");
        var _did_weather_action = false;
        for (var _wai = 0; _wai < array_length(_entry_actions_weather); ++_wai){
            var _wact = _entry_actions_weather[_wai];
            var _wkind = (is_struct(_wact) && variable_struct_exists(_wact, "kind")) ? string_lower(string(variable_struct_get(_wact, "kind"))) : "";
            if (_wkind != "set_weather" && _wkind != "set_special_weather" && _wkind != "set_terrain") continue;
            var _wdata = __battle_ability_action_data(_wact);
            if (_wkind == "set_terrain"){
                var _terrain = variable_struct_exists(_wdata, "terrain") ? string_lower(string(variable_struct_get(_wdata, "terrain"))) : "";
                if (string_length(_terrain) <= 0){
                    if (_ability == "electric-surge" || _ability == "hadron-engine") _terrain = "electric";
                    else if (_ability == "psychic-surge") _terrain = "psychic";
                    else if (_ability == "misty-surge") _terrain = "misty";
                    else if (_ability == "grassy-surge" || _ability == "seed-sower") _terrain = "grassy";
                }
                if (string_length(_terrain) > 0 && !is_undefined(__battle_field_set_terrain)){
                    var _tdur = variable_struct_exists(_wdata, "duration") ? variable_struct_get(_wdata, "duration") : 5;
                    __battle_field_set_terrain(_pid, _terrain, { source:_actor, turns:_tdur });
                    __battle_queue_ability_action_dialog(_actor, _wact, undefined, { terrain:_terrain });
                    _did_weather_action = true;
                }
                continue;
            }
            var _weather_to_set = variable_struct_exists(_wdata, "weather") ? string(variable_struct_get(_wdata, "weather")) : "";
            if (string_length(_weather_to_set) <= 0 && _wkind == "set_special_weather"){
                if (_ability == "primordial-sea") _weather_to_set = "rain";
                else if (_ability == "desolate-land" || _ability == "orichalcum-pulse") _weather_to_set = "harsh-sun";
                else if (_ability == "delta-stream") _weather_to_set = "strong-winds";
            }
            if (string_length(_weather_to_set) <= 0) continue;
            var _wdur = variable_struct_exists(_wdata, "duration") ? variable_struct_get(_wdata, "duration") : 5;
            var _winf = (_wkind == "set_special_weather");
            __battle_set_weather(_pid, _weather_to_set, { source: _actor, duration: _wdur, infinite:_winf });
            __battle_queue_ability_action_dialog(_actor, _wact, undefined, { weather:_weather_to_set });
            _did_weather_action = true;
        }
        if (!_did_weather_action){
            if (is_struct(_eff) && variable_struct_exists(_eff, "entry_weather") && string_length(string(variable_struct_get(_eff, "entry_weather"))) > 0){
                __battle_set_weather(_pid, string(variable_struct_get(_eff, "entry_weather")), { source: _actor, duration: 5 });
                __battle_queue_ability_dialog(_actor, _actor_name + "'s " + __battle_ability_battle_label(__battle_ability_label(_actor)) + "!");
                __battle_queue_ability_dialog(_actor, __battle_ability_pretty_weather(variable_struct_get(_eff, "entry_weather")) + "!");
            } else if (_ability == "drizzle") __battle_set_weather(_pid, "rain", { source: _actor, duration: 5 });
            else if (_ability == "drought") __battle_set_weather(_pid, "sun", { source: _actor, duration: 5 });
            else if (_ability == "sand-stream") __battle_set_weather(_pid, "sandstorm", { source: _actor, duration: 5 });
            else if (_ability == "snow-warning") __battle_set_weather(_pid, "hail", { source: _actor, duration: 5 });
        }
    } catch (e_weather_entry) {}

    var _entry_stage = [];
    if (is_struct(_eff) && variable_struct_exists(_eff, "entry_stage_opponents") && is_array(variable_struct_get(_eff, "entry_stage_opponents"))) _entry_stage = variable_struct_get(_eff, "entry_stage_opponents");
    var _entry_actions_stage = __battle_actor_ability_actions(_actor, "on_entry");
    for (var _eai = 0; _eai < array_length(_entry_actions_stage); ++_eai){
        var _eact = _entry_actions_stage[_eai];
        var _ekind = (is_struct(_eact) && variable_struct_exists(_eact, "kind")) ? string_lower(string(variable_struct_get(_eact, "kind"))) : "";
        if (_ekind == "stage_opponents") array_push(_entry_stage, __battle_ability_action_data(_eact));
    }
    if (_ability == "intimidate" || array_length(_entry_stage) > 0){
        if (array_length(_entry_stage) <= 0) _entry_stage = [{ stat:"atk", delta:-1, blockers:["clear-body", "white-smoke", "hyper-cutter", "full-metal-body"] }];
        var _side = (!is_undefined(__battle_actor_side) ? __battle_actor_side(_actor_index) : ((_actor_index <= 1) ? 0 : 1));
        for (var _i = 0; _i < array_length(_actors); ++_i){
            if (_i == _actor_index) continue;
            var _target = _actors[_i];
            if (!is_struct(_target) || __battle_hp_now(_target) <= 0) continue;
            var _target_side = (!is_undefined(__battle_actor_side) ? __battle_actor_side(_i) : ((_i <= 1) ? 0 : 1));
            if (_target_side == _side) continue;
            for (var _si = 0; _si < array_length(_entry_stage); ++_si){
                var _stage_rec = _entry_stage[_si];
                if (!is_struct(_stage_rec)) continue;
                var _stat = variable_struct_exists(_stage_rec, "stat") ? variable_struct_get(_stage_rec, "stat") : "atk";
                var _delta = variable_struct_exists(_stage_rec, "delta") ? variable_struct_get(_stage_rec, "delta") : -1;
                var _blockers = variable_struct_exists(_stage_rec, "blockers") ? variable_struct_get(_stage_rec, "blockers") : ["clear-body", "white-smoke", "hyper-cutter", "full-metal-body"];
                var _blocked_stage = false;
                if (is_array(_blockers) && __battle_actor_has_any_ability(_target, _blockers)) _blocked_stage = true;
                try { if (!_blocked_stage && __battle_actor_ability_has_group(_target, "intimidate_immunity")) _blocked_stage = true; } catch (e_intimidate_group_block) {}
                if (_blocked_stage){
                    try { __battle_queue_ability_action_dialog(_target, { hook:"stage_change", kind:"block_stat_lowering", data:{ stats:"all" } }, _actor, {}); } catch (e_stage_block_dialog) {}
                    continue;
                }
                if (__battle_ability_change_stage(_target, _stat, _delta)){
                    try {
                        var _stage_action = { hook:"on_entry", kind:"stage_opponents", data:_stage_rec };
                        __battle_queue_ability_action_dialog(_actor, _stage_action, _target, { stat:_stat, delta:_delta });
                    } catch (e_intim_msg) {}
                }
            }
        }
    }

    try {
        var _entry_info_actions = __battle_actor_ability_actions(_actor, "on_entry");
        for (var _iai = 0; _iai < array_length(_entry_info_actions); ++_iai){
            var _iact = _entry_info_actions[_iai];
            if (!is_struct(_iact)) continue;
            var _ikind = variable_struct_exists(_iact, "kind") ? string_lower(string(variable_struct_get(_iact, "kind"))) : "";
            if (_ikind == "reveal_target_item" || _ikind == "reveal_highest_power_move" || _ikind == "warn_super_effective_or_ohko_move"){
                __battle_queue_ability_action_dialog(_actor, _iact, undefined, {});
            } else if (_ikind == "clear_screens"){
                for (var _side_clear = 0; _side_clear < 2; ++_side_clear){
                    try { __battle_field_clear_barrier(_pid, _side_clear, "reflect"); } catch (e_clear_reflect) {}
                    try { __battle_field_clear_barrier(_pid, _side_clear, "light_screen"); } catch (e_clear_ls) {}
                    try { __battle_field_clear_barrier(_pid, _side_clear, "aurora_veil"); } catch (e_clear_av) {}
                }
                __battle_queue_ability_action_dialog(_actor, _iact, undefined, {});
            } else if (_ikind == "boost_by_opponent_defenses"){
                var _entry_side = (!is_undefined(__battle_actor_side) ? __battle_actor_side(_actor_index) : ((_actor_index <= 1) ? 0 : 1));
                var _def_total = 0;
                var _spdef_total = 0;
                var _def_count = 0;
                for (var _di = 0; _di < array_length(_actors); ++_di){
                    if (_di == _actor_index) continue;
                    var _opp_def = _actors[_di];
                    if (!is_struct(_opp_def) || __battle_hp_now(_opp_def) <= 0) continue;
                    var _opp_side = (!is_undefined(__battle_actor_side) ? __battle_actor_side(_di) : ((_di <= 1) ? 0 : 1));
                    if (_opp_side == _entry_side) continue;
                    _def_total += __battle_stat_get(_opp_def, "def");
                    _spdef_total += __battle_stat_get(_opp_def, "spdef");
                    _def_count += 1;
                }
                if (_def_count > 0){
                    var _boost_stat = (_def_total < _spdef_total) ? "atk" : "spa";
                    var _boost_delta = 1;
                    var _idata = __battle_ability_action_data(_iact);
                    if (_boost_stat == "atk" && variable_struct_exists(_idata, "physical_stat")) _boost_stat = string(variable_struct_get(_idata, "physical_stat"));
                    if (_boost_stat == "spa" && variable_struct_exists(_idata, "special_stat")) _boost_stat = string(variable_struct_get(_idata, "special_stat"));
                    if (variable_struct_exists(_idata, "delta") && is_real(variable_struct_get(_idata, "delta"))) _boost_delta = variable_struct_get(_idata, "delta");
                    if (__battle_ability_change_stage(_actor, _boost_stat, _boost_delta)){
                        __battle_queue_ability_action_dialog(_actor, _iact, undefined, {});
                    }
                }
            }
        }
    } catch (e_entry_info_actions) {}

    try {
        var _stage_event_actions = __battle_actor_ability_actions(_actor, "stage_event_check");
        for (var _sei = 0; _sei < array_length(_stage_event_actions); ++_sei){
            var _seact = _stage_event_actions[_sei];
            if (!is_struct(_seact)) continue;
            var _sekind = variable_struct_exists(_seact, "kind") ? string_lower(string(variable_struct_get(_seact, "kind"))) : "";
            if (_sekind != "conditional_stage_event") continue;
            var _stage_event_did = false;
            if (_ability == "intrepid-sword") _stage_event_did = __battle_ability_change_stage(_actor, "atk", 1);
            else if (_ability == "dauntless-shield") _stage_event_did = __battle_ability_change_stage(_actor, "def", 1);
            if (_stage_event_did) __battle_queue_ability_action_dialog(_actor, _seact, undefined, {});
        }
    } catch (e_entry_stage_event) {}

    return true;
}

function __battle_has_no_guard_effect(_ent){
    var _eff = __battle_actor_ability_effect(_ent);
    if (is_struct(_eff) && variable_struct_exists(_eff, "no_guard") && variable_struct_get(_eff, "no_guard") == true) return true;
    if (__battle_actor_ability_has_group(_ent, "accuracy_override")) return true;
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
    if (__battle_has_perfect_target_lock(_attacker, _defender)) return true;
    try {
        var _ignore_acc_eid = (!is_undefined(__battle_move_effect_id_safe) ? __battle_move_effect_id_safe(_move_id) : undefined);
        if (is_real(_ignore_acc_eid) && floor(_ignore_acc_eid) == 217) return true;
    } catch (e_miracle_acc) {}
    return false;
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
    var _dc_initial = __battle_move_damage_class_safe(_move_id);
    var _is_special = (is_real(_dc_initial) && floor(_dc_initial) == 3);
    var Atk = __battle_stat_get(_A, _is_special ? "spa" : "atk");
    var Def = __battle_stat_get(_D, _is_special ? "spdef" : "def");

    try {
        var _atk_eff_calc = __battle_actor_ability_effect(_A);
        var _def_eff_calc = __battle_actor_ability_effect(_D);
        var _did_attack_stat_action = false;
        var _did_attack_status_action = false;
        var _atk_stat_actions = __battle_actor_ability_actions(_A, "stat_calc");
        for (var _asai = 0; _asai < array_length(_atk_stat_actions); ++_asai){
            var _asact = _atk_stat_actions[_asai];
            var _askind = (is_struct(_asact) && variable_struct_exists(_asact, "kind")) ? string_lower(string(variable_struct_get(_asact, "kind"))) : "";
            var _asdata = __battle_ability_action_data(_asact);
            if (_askind == "attack_multiplier" && !_is_special){
                var _asmult = variable_struct_exists(_asdata, "mult") ? variable_struct_get(_asdata, "mult") : 1;
                Atk = floor(Atk * _asmult);
                _did_attack_stat_action = true;
            }
            if (_askind == "attack_multiplier_and_choice_lock" && !_is_special){
                var _choice_mult = variable_struct_exists(_asdata, "mult") ? variable_struct_get(_asdata, "mult") : 1.5;
                Atk = floor(Atk * _choice_mult);
                _did_attack_stat_action = true;
            }
            if (_askind == "early_turn_attack_speed_multiplier" && !_is_special){
                var _limit_turns = (variable_struct_exists(_asdata, "turns") && is_real(variable_struct_get(_asdata, "turns"))) ? variable_struct_get(_asdata, "turns") : 5;
                var _active_turns = (variable_struct_exists(_A, "active_turns") && is_real(variable_struct_get(_A, "active_turns"))) ? variable_struct_get(_A, "active_turns") : 0;
                if (_active_turns < _limit_turns){
                    var _early_atk_mult = variable_struct_exists(_asdata, "attack_mult") ? variable_struct_get(_asdata, "attack_mult") : 0.5;
                    Atk = floor(Atk * _early_atk_mult);
                }
            }
            if (_askind == "attack_when_status_multiplier" && !_is_special && __battle_actor_has_major_status(_A)){
                var _assmult = variable_struct_exists(_asdata, "mult") ? variable_struct_get(_asdata, "mult") : 1;
                Atk = floor(Atk * _assmult);
                _did_attack_status_action = true;
            }
            if (_askind == "special_attack_when_status_multiplier" && _is_special && __battle_actor_has_major_status(_A)){
                var _spasmult = variable_struct_exists(_asdata, "mult") ? variable_struct_get(_asdata, "mult") : 1;
                Atk = floor(Atk * _spasmult);
                _did_attack_status_action = true;
            }
            if (_askind == "ally_special_attack_support" && _is_special){
                var _plusminus_active = false;
                try {
                    if (__battle_actor_has_any_ability(_A, ["plus", "minus"])){
                        var _pid_pm = (!is_undefined(__status_find_battle_pid)) ? __status_find_battle_pid(_A) : undefined;
                        if (is_real(_pid_pm)){
                            var _Bpm = __battle_ensure_slot(_pid_pm);
                            if (is_struct(_Bpm) && variable_struct_exists(_Bpm, "actor") && is_array(variable_struct_get(_Bpm, "actor"))){
                                var _actors_pm = variable_struct_get(_Bpm, "actor");
                                var _aidx_pm = -1;
                                for (var _pmi = 0; _pmi < array_length(_actors_pm); ++_pmi){
                                    if (_actors_pm[_pmi] == _A){ _aidx_pm = _pmi; break; }
                                }
                                var _aside_pm = (_aidx_pm >= 0 && !is_undefined(__battle_actor_side)) ? __battle_actor_side(_aidx_pm) : -1;
                                for (var _pmj = 0; _pmj < array_length(_actors_pm); ++_pmj){
                                    var _ally_pm = _actors_pm[_pmj];
                                    if (!is_struct(_ally_pm) || _ally_pm == _A || __battle_hp_now(_ally_pm) <= 0) continue;
                                    var _alside_pm = (!is_undefined(__battle_actor_side)) ? __battle_actor_side(_pmj) : -2;
                                    if (_alside_pm == _aside_pm && __battle_actor_has_any_ability(_ally_pm, ["plus", "minus"])){
                                        _plusminus_active = true;
                                        break;
                                    }
                                }
                            }
                        }
                    }
                } catch (e_plusminus_stat) { _plusminus_active = false; }
                if (_plusminus_active){
                    var _pm_mult = variable_struct_exists(_asdata, "mult") ? variable_struct_get(_asdata, "mult") : 1.5;
                    Atk = floor(Atk * _pm_mult);
                }
            }
            if (_askind == "attack_spa_when_hp_below_multiplier"){
                var _hp_frac = (variable_struct_exists(_asdata, "hp_fraction") && is_real(variable_struct_get(_asdata, "hp_fraction"))) ? variable_struct_get(_asdata, "hp_fraction") : 0.5;
                var _hp_now_frac = __battle_hp_now(_A) / max(1, __battle_hp_max(_A));
                if (_hp_now_frac <= _hp_frac){
                    var _thresh_mult = variable_struct_exists(_asdata, "mult") ? variable_struct_get(_asdata, "mult") : 1;
                    Atk = floor(Atk * _thresh_mult);
                }
            }
            if (_askind == "weather_spa_multiplier" && _is_special){
                var _wspa_id = __battle_ability_current_weather_id(_A);
                var _wspa_list = variable_struct_exists(_asdata, "weather") ? variable_struct_get(_asdata, "weather") : [];
                if (string_length(_wspa_id) > 0 && __battle_ability_list_contains(_wspa_list, _wspa_id)){
                    var _wspa_mult = variable_struct_exists(_asdata, "mult") ? variable_struct_get(_asdata, "mult") : 1;
                    Atk = floor(Atk * _wspa_mult);
                }
            }
            if (_askind == "sun_party_attack_spdef_multiplier"){
                var _fg_weather = __battle_ability_current_weather_id(_A);
                var _fg_list = variable_struct_exists(_asdata, "weather") ? variable_struct_get(_asdata, "weather") : ["sun","harsh-sun"];
                if (string_length(_fg_weather) > 0 && __battle_ability_list_contains(_fg_list, _fg_weather)){
                    var _fg_mult = (!_is_special && variable_struct_exists(_asdata, "attack_mult")) ? variable_struct_get(_asdata, "attack_mult") : 1;
                    Atk = floor(Atk * _fg_mult);
                }
            }
        }
        if (!_did_attack_stat_action && !_is_special && is_struct(_atk_eff_calc) && variable_struct_exists(_atk_eff_calc, "attack_stat_multiplier")) Atk = floor(Atk * variable_struct_get(_atk_eff_calc, "attack_stat_multiplier"));
        else if (!_did_attack_stat_action && !_is_special && __battle_actor_has_any_ability(_A, ["huge-power", "pure-power"])) Atk *= 2;
        if (!_did_attack_status_action && !_is_special && is_struct(_atk_eff_calc) && variable_struct_exists(_atk_eff_calc, "attack_status_multiplier") && __battle_actor_has_major_status(_A)) Atk = floor(Atk * variable_struct_get(_atk_eff_calc, "attack_status_multiplier"));
        else if (!_did_attack_status_action && !_is_special && __battle_actor_has_any_ability(_A, ["guts"]) && __battle_actor_has_major_status(_A)) Atk = floor(Atk * 1.5);

        try {
            if (!is_undefined(item_runtime_actor_held_actions)){
                var _item_stat_actions = item_runtime_actor_held_actions(_A, "stat_calc");
                for (var _isai = 0; _isai < array_length(_item_stat_actions); ++_isai){
                    var _isact = _item_stat_actions[_isai];
                    if (!is_struct(_isact)) continue;
                    var _iskind = variable_struct_exists(_isact, "kind") ? string_lower(string(variable_struct_get(_isact, "kind"))) : "";
                    if (_iskind != "stat_multiplier") continue;
                    var _isdata = __battle_item_action_data(_isact);
                    var _istat = variable_struct_exists(_isdata, "stat") ? string_lower(string(variable_struct_get(_isdata, "stat"))) : "";
                    var _imult = (variable_struct_exists(_isdata, "multiplier") && is_real(variable_struct_get(_isdata, "multiplier"))) ? variable_struct_get(_isdata, "multiplier") : 1.5;
                    if ((!_is_special && _istat == "atk") || (_is_special && _istat == "spa")){
                        Atk = floor(Atk * _imult);
                    }
                }
            }
        } catch (e_item_stat_calc) {}

        var _did_defense_status_action = false;
        var _did_defense_stat_action = false;
        var _def_stat_actions = __battle_actor_ability_actions(_D, "stat_calc");
        for (var _dsai = 0; _dsai < array_length(_def_stat_actions); ++_dsai){
            var _dsact = _def_stat_actions[_dsai];
            var _dskind = (is_struct(_dsact) && variable_struct_exists(_dsact, "kind")) ? string_lower(string(variable_struct_get(_dsact, "kind"))) : "";
            var _dsdata = __battle_ability_action_data(_dsact);
            if (_dskind == "defense_multiplier" && !_is_special){
                var _dstatmult = variable_struct_exists(_dsdata, "mult") ? variable_struct_get(_dsdata, "mult") : 1;
                Def = floor(Def * _dstatmult);
                _did_defense_stat_action = true;
            }
            if (_dskind == "terrain_defense_multiplier" && !_is_special){
                var _terrain_id_def = "";
                try {
                    var _pid_def_terrain = (!is_undefined(__status_find_battle_pid)) ? __status_find_battle_pid(_D) : undefined;
                    if (is_real(_pid_def_terrain) && !is_undefined(__battle_field_get_terrain)){
                        var _terr_def = __battle_field_get_terrain(_pid_def_terrain);
                        if (is_struct(_terr_def) && variable_struct_exists(_terr_def, "id")) _terrain_id_def = string_lower(string(variable_struct_get(_terr_def, "id")));
                    }
                } catch (e_terrain_def_read) { _terrain_id_def = ""; }
                var _terrain_list_def = variable_struct_exists(_dsdata, "terrain") ? variable_struct_get(_dsdata, "terrain") : [];
                if (string_length(_terrain_id_def) > 0 && __battle_ability_list_contains(_terrain_list_def, _terrain_id_def)){
                    var _terrain_def_mult = variable_struct_exists(_dsdata, "mult") ? variable_struct_get(_dsdata, "mult") : 1.5;
                    Def = floor(Def * _terrain_def_mult);
                    _did_defense_stat_action = true;
                }
            }
            if (_dskind == "defense_when_status_multiplier" && !_is_special && __battle_actor_has_major_status(_D)){
                var _dsmult = variable_struct_exists(_dsdata, "mult") ? variable_struct_get(_dsdata, "mult") : 1;
                Def = floor(Def * _dsmult);
                _did_defense_status_action = true;
            }
            if (_dskind == "sun_party_attack_spdef_multiplier" && _is_special){
                var _fgd_weather = __battle_ability_current_weather_id(_D);
                var _fgd_list = variable_struct_exists(_dsdata, "weather") ? variable_struct_get(_dsdata, "weather") : ["sun","harsh-sun"];
                if (string_length(_fgd_weather) > 0 && __battle_ability_list_contains(_fgd_list, _fgd_weather)){
                    var _fgd_mult = variable_struct_exists(_dsdata, "spdef_mult") ? variable_struct_get(_dsdata, "spdef_mult") : 1;
                    Def = floor(Def * _fgd_mult);
                }
            }
        }
        if (!_did_defense_stat_action && !_is_special && is_struct(_def_eff_calc) && variable_struct_exists(_def_eff_calc, "defense_stat_multiplier")) Def = floor(Def * variable_struct_get(_def_eff_calc, "defense_stat_multiplier"));
        if (!_did_defense_status_action && !_is_special && is_struct(_def_eff_calc) && variable_struct_exists(_def_eff_calc, "defense_status_multiplier") && __battle_actor_has_major_status(_D)) Def = floor(Def * variable_struct_get(_def_eff_calc, "defense_status_multiplier"));
        else if (!_did_defense_status_action && !_is_special && __battle_actor_has_any_ability(_D, ["marvel-scale"]) && __battle_actor_has_major_status(_D)) Def = floor(Def * 1.5);
    } catch (e_stat_ability) {}

    // If this is a physical move and the attacker is burned, halve its attack
    try {
        var _dc = _dc_initial;
        // damage class 2 == physical in most datasets
        if (is_real(_dc) && floor(_dc) == 2){
            if (!__battle_actor_has_any_ability(_A, ["guts"]) && !is_undefined(status_system_has_status) && status_system_has_status(_A, "burn")){
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
        try {
            var _crit_eid_impl = undefined;
            if (!is_undefined(__battle_move_effect_id_safe)) _crit_eid_impl = __battle_move_effect_id_safe(_move_id);
            if (is_real(_crit_eid_impl) && _crit_eid_impl == 44) crit_rate_level += 1;
        } catch (e_high_crit_impl) {}
        try {
            var _crit_actions = __battle_actor_ability_actions(_A, "crit_calc");
            for (var _cai = 0; _cai < array_length(_crit_actions); ++_cai){
                var _cact = _crit_actions[_cai];
                if (!is_struct(_cact)) continue;
                var _ckind = variable_struct_exists(_cact, "kind") ? string_lower(string(variable_struct_get(_cact, "kind"))) : "";
                var _cdata = __battle_ability_action_data(_cact);
                if (_ckind == "crit_stage_bonus"){
                    var _cdelta = (variable_struct_exists(_cdata, "delta") && is_real(variable_struct_get(_cdata, "delta"))) ? variable_struct_get(_cdata, "delta") : 1;
                    crit_rate_level += _cdelta;
                } else if (_ckind == "always_crit_on_poisoned_target"){
                    var _poisoned_target = false;
                    try {
                        if (!is_undefined(status_system_has_status)){
                            _poisoned_target = status_system_has_status(_D, "poison") || status_system_has_status(_D, "toxic");
                        }
                    } catch (e_merciless_status) { _poisoned_target = false; }
                    if (_poisoned_target) crit_rate_level = max(crit_rate_level, 3);
                }
            }
        } catch (e_crit_ability_calc) {}
        try {
            var _focus_bonus = 0;
            if (is_struct(_A) && variable_struct_exists(_A, "_focus_energy_level") && is_real(variable_struct_get(_A, "_focus_energy_level"))) _focus_bonus = max(0, floor(variable_struct_get(_A, "_focus_energy_level")));
            else if (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))){
                var _focus_mon = variable_struct_get(_A, "mon");
                if (variable_struct_exists(_focus_mon, "_focus_energy_level") && is_real(variable_struct_get(_focus_mon, "_focus_energy_level"))) _focus_bonus = max(0, floor(variable_struct_get(_focus_mon, "_focus_energy_level")));
            }
            crit_rate_level += _focus_bonus;
        } catch (e_focus_crit) {}
        // Map crit_rate_level to a sampling denominator (conservative mapping)
        var denom = 24;
        if (is_real(crit_rate_level)){
            if (crit_rate_level <= 0) denom = 24;
            else if (crit_rate_level == 1) denom = 8; // higher crit chance
            else denom = 2; // very high crit chance for larger values
        }
        var _no_crit_move = false;
        try {
            if (is_real(_crit_eid_impl) && _crit_eid_impl == 149) _no_crit_move = true;
            if (is_real(_move_id) && (_move_id == 248 || _move_id == 353)) _no_crit_move = true;
        } catch (e_no_crit_impl) { _no_crit_move = false; }
        var _crit_blocked_by_ability = false;
        try {
            var _crit_eff = __battle_actor_ability_effect(_D);
            _crit_blocked_by_ability = (is_struct(_crit_eff) && variable_struct_exists(_crit_eff, "crit_immunity") && variable_struct_get(_crit_eff, "crit_immunity") == true);
            if (!_crit_blocked_by_ability) _crit_blocked_by_ability = __battle_actor_ability_has_group(_D, "crit_immunity");
        } catch (e_crit_eff) { _crit_blocked_by_ability = false; }
        if (_crit_blocked_by_ability || __battle_actor_has_any_ability(_D, ["battle-armor", "shell-armor"])){
            crit = false;
        } else if (_no_crit_move){
            crit = false;
        } else if (variable_global_exists("DEV_FORCE_CRIT_ROLL_100") && is_real(global.DEV_FORCE_CRIT_ROLL_100) && global.DEV_FORCE_CRIT_ROLL_100 >= 0){
            var _crit_chance_impl = 100 / max(1, denom);
            crit = (real(global.DEV_FORCE_CRIT_ROLL_100) < _crit_chance_impl);
        } else {
            crit = (irandom(max(1, denom) - 1) == 0);
        }
    } catch (e_crit) { crit = (irandom(23) == 0); }
    var critMul = crit ? 1.5 : 1.0;
    dmg = floor(dmg * critMul);

    try {
        var _stab_mult = __battle_move_stab_multiplier(_A, _move_id);
        if (is_real(_stab_mult) && _stab_mult != 1.0) dmg = floor(dmg * _stab_mult);
        var _type_mult_calc = __battle_move_type_effectiveness_multiplier(_A, _D, _move_id);
        _type_mult_calc = __battle_ability_type_effectiveness_multiplier(_A, _D, _move_id, _type_mult_calc);
        if (is_real(_type_mult_calc)) dmg = floor(dmg * _type_mult_calc);
        try {
            var _B_type_dbg = __battle_ensure_slot(0);
            if (is_struct(_B_type_dbg)) variable_struct_set(_B_type_dbg, "_last_type_effectiveness", _type_mult_calc);
        } catch (e_type_dbg_slot) {}
    } catch (e_type_damage_calc) {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][type] damage multiplier failed: " + string(e_type_damage_calc));
    }

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
        var _weather_suppressed = false;
        try { if (!is_undefined(__battle_weather_suppressed_by_ability)) _weather_suppressed = __battle_weather_suppressed_by_ability(0); } catch (e_weather_suppress_calc) { _weather_suppressed = false; }
        if (!_weather_suppressed && _weather_active(_wrec)){
            var _wid_norm = _normalize_weather_id(variable_struct_exists(_wrec, "id") ? variable_struct_get(_wrec, "id") : "");
            var _mv_type = -1;
            if (!is_undefined(scr_move_type_id_by_id) && is_real(_move_id)) _mv_type = scr_move_type_id_by_id(_move_id, _A);
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

    try {
        var _Bcrit_pre_ability = __battle_ensure_slot(0);
        if (is_struct(_Bcrit_pre_ability)) variable_struct_set(_Bcrit_pre_ability, "_last_crit", crit);
    } catch (e_pre_ability_crit) {}

    try {
        dmg = floor(dmg * __battle_ability_damage_multiplier(_A, _D, _move_id));
    } catch (e_ability_damage) {}

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

    function __battle_find_move_slot_by_id(_actor, _move_id){
        if (!is_struct(_actor) || !is_real(_move_id)) return -1;
        if (!variable_struct_exists(_actor, "moves") || !is_array(variable_struct_get(_actor, "moves"))) return -1;
        var _moves = variable_struct_get(_actor, "moves");
        for (var _msi = 0; _msi < array_length(_moves); ++_msi){
            if (_moves[_msi] == _move_id) return _msi;
        }
        return -1;
    }

    var cur_hp = __battle_hp_now(T);
    var newhp = max(0, cur_hp - max(0, round(_dmg * (is_real(_mult) ? _mult : 1))));
    try {
        if (is_real(cur_hp) && cur_hp > 0 && is_real(newhp) && newhp <= 0 && variable_struct_exists(T, "_enduring") && variable_struct_get(T, "_enduring") == true){
            newhp = 1;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                var _tname_endure_impl = variable_struct_exists(T, "name") ? string(variable_struct_get(T, "name")) : "target";
                show_debug_message("[battle][endure] " + _tname_endure_impl + " endured the hit at 1 HP");
            }
        }
    } catch (e_endure_impl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][endure] impl damage guard failed: " + string(e_endure_impl)); }
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
            try {
                var _grudge_active = (is_struct(T) && variable_struct_exists(T, "_grudge_active") && variable_struct_get(T, "_grudge_active") == true);
                if (_grudge_active && is_struct(_B) && variable_struct_exists(_B, "_pending_damage_source") && is_struct(variable_struct_get(_B, "_pending_damage_source"))){
                    var _grudge_src = variable_struct_get(_B, "_pending_damage_source");
                    var _grudge_attacker = (variable_struct_exists(_grudge_src, "attacker") ? variable_struct_get(_grudge_src, "attacker") : undefined);
                    var _grudge_move_id = (variable_struct_exists(_grudge_src, "move_id") ? variable_struct_get(_grudge_src, "move_id") : undefined);
                    var _grudge_slot = (variable_struct_exists(_grudge_src, "move_slot") ? variable_struct_get(_grudge_src, "move_slot") : undefined);
                    if (!is_real(_grudge_slot)) _grudge_slot = __battle_find_move_slot_by_id(_grudge_attacker, _grudge_move_id);
                    if (is_struct(_grudge_attacker) && is_real(_grudge_slot) && variable_struct_exists(_grudge_attacker, "pps") && is_array(variable_struct_get(_grudge_attacker, "pps")) && _grudge_slot >= 0 && _grudge_slot < array_length(variable_struct_get(_grudge_attacker, "pps"))){
                        var _grudge_pps = variable_struct_get(_grudge_attacker, "pps");
                        _grudge_pps[_grudge_slot] = 0;
                        variable_struct_set(_grudge_attacker, "pps", _grudge_pps);
                        dialog_queue(__battle_dialog_actor_name(_grudge_attacker, "The attacker") + "'s move lost all its PP due to Grudge!");
                    }
                }
            } catch (e_grudge_apply) {}
            try {
                if (is_struct(T) && variable_struct_exists(T, "_grudge_active")) variable_struct_set(T, "_grudge_active", false);
            } catch (e_grudge_clear_faint) {}
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
                    var _player_side_faint = (is_real(_target_index) && (__battle_actor_side(_target_index) == 0));
                    // Only open party UI for player's side faints.
                    if (_player_side_faint){
                        variable_struct_set(_B_sch, "_pending_open_party", true);
                        variable_struct_set(_B_sch, "_pending_open_party_fainted_actor_index", _target_index);
                        try {
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_impls] scheduled _pending_open_party for pid=" + string(_pid));
                        } catch (e_dbg_po) {}
                    }
                    // Queue faint text to show last; do not open immediately.
                        try {
                            var _fnt_name = "(Unknown)";
                            if (variable_struct_exists(T, "name")) _fnt_name = variable_struct_get(T, "name");
                            else if (variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon")) && variable_struct_exists(variable_struct_get(T, "mon"), "name")) _fnt_name = variable_struct_get(variable_struct_get(T, "mon"), "name");
                            // Queue as a faint-gated dialog so it shows after other pending messages
                            if (!is_undefined(__battle_try_enqueue_faint_dialog)) __battle_try_enqueue_faint_dialog(_pid, _B_sch, string(_fnt_name) + " fainted!", string(_fnt_name) + " fainted!");
                        } catch (e_sd_local) {}
                    if (_player_side_faint){
                        // Ensure the faint dialog has time to render before the party UI may open.
                        try { variable_struct_set(_B_sch, "_pending_open_party_delay_until", current_time + 300);
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_impls] set _pending_open_party_delay_until=" + string(current_time + 300) + " pid=" + string(_pid));
                        } catch (e_pd) {}
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
                                if (variable_struct_exists(_su, "menu")) variable_struct_set(_B_sch, "_pending_open_party_prev_menu", variable_struct_get(_su, "menu"));
                                if (variable_struct_exists(_su, "selX")) variable_struct_set(_B_sch, "_pending_open_party_prev_selX", variable_struct_get(_su, "selX"));
                                if (variable_struct_exists(_su, "selY")) variable_struct_set(_B_sch, "_pending_open_party_prev_selY", variable_struct_get(_su, "selY"));
                            }
                        } catch (e_saveui) {}
                        // Also clear any deferred turn resume so we don't accidentally continue
                        // the turn while the party selection is pending.
                        variable_struct_set(_B_sch, "_defer_turn_until_no_dialog", false);
                    }
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
            if (_code == 237){
                var _hp_power_impl = __battle_variable_move_power(_code, _A, _D);
                if (is_real(_hp_power_impl) && _hp_power_impl > 0) return _hp_power_impl;
            }
            if (_code == 358 || _code == 362){
                var _var_power_impl = __battle_variable_move_power(_code, _A, _D);
                if (is_real(_var_power_impl) && _var_power_impl > 0) return _var_power_impl;
            }
            if (_code == 360){
                var _gyro_aspeed = 0;
                var _gyro_dspeed = 0;
                try {
                    if (is_struct(_A) && variable_struct_exists(_A, "spe") && is_real(variable_struct_get(_A, "spe"))) _gyro_aspeed = variable_struct_get(_A, "spe");
                    else if (is_struct(_A) && variable_struct_exists(_A, "speed") && is_real(variable_struct_get(_A, "speed"))) _gyro_aspeed = variable_struct_get(_A, "speed");
                    if (is_struct(_D) && variable_struct_exists(_D, "spe") && is_real(variable_struct_get(_D, "spe"))) _gyro_dspeed = variable_struct_get(_D, "spe");
                    else if (is_struct(_D) && variable_struct_exists(_D, "speed") && is_real(variable_struct_get(_D, "speed"))) _gyro_dspeed = variable_struct_get(_D, "speed");
                } catch (e_gyro_power_impl) { _gyro_aspeed = 0; _gyro_dspeed = 0; }
                if (_gyro_aspeed > 0 && _gyro_dspeed > 0){
                    var _gyro_ratio = _gyro_dspeed / max(1, _gyro_aspeed);
                    return clamp(floor(25 * _gyro_ratio), 1, 150);
                }
            }
            if (_code == 363 && !is_undefined(__battle_get_natural_gift_profile)){
                var _gift_profile_impl = __battle_get_natural_gift_profile(_A);
                if (is_struct(_gift_profile_impl) && variable_struct_exists(_gift_profile_impl, "power") && is_real(variable_struct_get(_gift_profile_impl, "power"))) return variable_struct_get(_gift_profile_impl, "power");
            }
            var p = scr_move_power_by_id(_code);
            if (is_real(p) && p > 0){
                var _power = max(0, real(p));
                try {
                    if (!is_undefined(__battle_move_behavior_power_multiplier)){
                        _power *= __battle_move_behavior_power_multiplier(_code, _A, _D);
                    }
                } catch (e_power_mod) {}
                return _power;
            }
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
    var _store_pid = _pid;
    var _caught_target_idx = -1;
    if (variable_struct_exists(_B, "_catch_anim") && is_struct(variable_struct_get(_B, "_catch_anim"))){
        var _catch_state = variable_struct_get(_B, "_catch_anim");
        if (variable_struct_exists(_catch_state, "_finalized") && variable_struct_get(_catch_state, "_finalized") == true) return { ok:true, location:"already_finalized" };
        variable_struct_set(_catch_state, "_finalized", true);
        variable_struct_set(_B, "_catch_anim", _catch_state);
        if (variable_struct_exists(_catch_state, "target_actor_index") && is_real(variable_struct_get(_catch_state, "target_actor_index"))) _caught_target_idx = floor(variable_struct_get(_catch_state, "target_actor_index"));
        if (variable_struct_exists(_catch_state, "owner_pid") && is_real(variable_struct_get(_catch_state, "owner_pid"))) _store_pid = max(0, floor(variable_struct_get(_catch_state, "owner_pid")));
    }
    var _mon = __battle_prepare_caught_mon_impl(_store_pid, _caught);
    var _store = { ok:false, location:"none", mon:_mon };
    if (is_struct(_mon) && !is_undefined(party_model_store_caught_mon)) _store = party_model_store_caught_mon(_store_pid, _mon);
    try {
        if (is_struct(_mon) && !is_undefined(poke_index_mark_mon_caught)) poke_index_mark_mon_caught(_store_pid, _mon);
    } catch (e_poke_index_caught) {}

    var _caught_name = "Pokemon";
    if (is_struct(_mon) && !is_undefined(mon_display_name)){
        var _caught_display = mon_display_name(_mon);
        if (is_string(_caught_display) && string_length(string_trim(_caught_display)) > 0 && string(_caught_display) != "???") _caught_name = string_trim(_caught_display);
    }
    if (_caught_name == "Pokemon" && is_struct(_mon) && variable_struct_exists(_mon, "nickname") && string_length(string_trim(string(variable_struct_get(_mon, "nickname")))) > 0) _caught_name = string_trim(string(variable_struct_get(_mon, "nickname")));
    else if (_caught_name == "Pokemon" && is_struct(_mon) && variable_struct_exists(_mon, "name")) _caught_name = string(variable_struct_get(_mon, "name"));
    else if (_caught_name == "Pokemon" && is_array(_B.actor) && _caught_target_idx >= 0 && _caught_target_idx < array_length(_B.actor) && is_struct(_B.actor[_caught_target_idx]) && variable_struct_exists(_B.actor[_caught_target_idx], "name")) _caught_name = string(variable_struct_get(_B.actor[_caught_target_idx], "name"));
    else if (_caught_name == "Pokemon" && !is_undefined(__battle_enemy_lead_index) && is_array(_B.actor)){
        var _enemy_idx = __battle_enemy_lead_index(_pid);
        if (_enemy_idx >= 0 && _enemy_idx < array_length(_B.actor) && is_struct(_B.actor[_enemy_idx]) && variable_struct_exists(_B.actor[_enemy_idx], "name")) _caught_name = string(variable_struct_get(_B.actor[_enemy_idx], "name"));
    }

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
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_store_pid, _msg);
        else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_store_pid, _msg, _msg, "any");
    } catch (e_msg) {}
    try {
        if (is_struct(_store) && variable_struct_exists(_store, "ok") && _store.ok){
            var _nick_queue = (variable_struct_exists(_B, "_pending_caught_nicknames") && is_array(variable_struct_get(_B, "_pending_caught_nicknames"))) ? variable_struct_get(_B, "_pending_caught_nicknames") : [];
            array_push(_nick_queue, { pid:_store_pid, store:_store, species_name:_caught_name });
            variable_struct_set(_B, "_pending_caught_nicknames", _nick_queue);
        }
    } catch (e_vk_req) {}

    if (is_array(_B.actor) && _caught_target_idx >= 0 && _caught_target_idx < array_length(_B.actor)){
        _B.actor[_caught_target_idx] = undefined;
    }

    var _continue_same_turn_after_catch = false;
    var _moved_enemy_from_idx = -1;
    var _moved_enemy_to_idx = -1;
    try {
        if (is_array(_B.turn_queue) && is_real(_B.turn_i)){
            for (var _cq_i = max(0, floor(_B.turn_i)); _cq_i < array_length(_B.turn_queue); ++_cq_i){
                var _cq_step = _B.turn_queue[_cq_i];
                if (!is_struct(_cq_step)) continue;
                var _cq_actor_idx = (variable_struct_exists(_cq_step, "actor_index") && is_real(variable_struct_get(_cq_step, "actor_index"))) ? floor(variable_struct_get(_cq_step, "actor_index")) : -1;
                if (_cq_actor_idx == _caught_target_idx) continue;
                _continue_same_turn_after_catch = true;
                if (variable_struct_exists(_cq_step, "item_use") && variable_struct_get(_cq_step, "item_use") == true) break;
                if (_cq_actor_idx >= 0 && is_array(_B.actor) && _cq_actor_idx < array_length(_B.actor) && is_struct(_B.actor[_cq_actor_idx])){
                    break;
                }
            }
        }
    } catch (e_continue_catch_scan) { _continue_same_turn_after_catch = false; }

    // Keep the remaining wild in the primary enemy slot so existing single-target
    // battle flows continue to address the surviving opponent after a double catch.
    if (is_array(_B.actor) && variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double"){
        var _enemy_lead_idx = __battle_actor_index_for_side_slot(_pid, 1, 0);
        var _enemy_tail_idx = __battle_actor_index_for_side_slot(_pid, 1, 1);
        if (_enemy_lead_idx >= 0 && _enemy_tail_idx >= 0 && _enemy_lead_idx < array_length(_B.actor) && _enemy_tail_idx < array_length(_B.actor)){
            if (!is_struct(_B.actor[_enemy_lead_idx]) && is_struct(_B.actor[_enemy_tail_idx])){
                _B.actor[_enemy_lead_idx] = _B.actor[_enemy_tail_idx];
                _B.actor[_enemy_tail_idx] = undefined;
                _moved_enemy_from_idx = _enemy_tail_idx;
                _moved_enemy_to_idx = _enemy_lead_idx;
                try { __battle_set_actor_runtime_fields(_B.actor[_enemy_lead_idx], _enemy_lead_idx, -1, -1, -1); } catch (e_reindex_enemy) {}
            }
        }
    }

    if (_continue_same_turn_after_catch && _moved_enemy_from_idx >= 0 && _moved_enemy_to_idx >= 0){
        try {
            for (var _rq_i = max(0, floor(_B.turn_i)); _rq_i < array_length(_B.turn_queue); ++_rq_i){
                var _rq_step = _B.turn_queue[_rq_i];
                if (!is_struct(_rq_step)) continue;
                if (variable_struct_exists(_rq_step, "actor_index") && is_real(variable_struct_get(_rq_step, "actor_index")) && floor(variable_struct_get(_rq_step, "actor_index")) == _moved_enemy_from_idx){
                    variable_struct_set(_rq_step, "actor_index", _moved_enemy_to_idx);
                }
                if (variable_struct_exists(_rq_step, "target_index") && is_real(variable_struct_get(_rq_step, "target_index")) && floor(variable_struct_get(_rq_step, "target_index")) == _moved_enemy_from_idx){
                    variable_struct_set(_rq_step, "target_index", _moved_enemy_to_idx);
                }
                _B.turn_queue[_rq_i] = _rq_step;
            }
        } catch (e_retarget_remaining_catch) {}
    }

    var _enemy_side_alive = false;
    if (is_array(_B.actor)){
        for (var _ai = 0; _ai < array_length(_B.actor); ++_ai){
            if (!is_undefined(__battle_actor_side) && __battle_actor_side(_ai) != 1) continue;
            var _enemy_actor = _B.actor[_ai];
            if (!is_struct(_enemy_actor)) continue;
            var _enemy_hp = 0;
            if (!is_undefined(__battle_hp_now)) _enemy_hp = __battle_hp_now(_enemy_actor);
            else if (variable_struct_exists(_enemy_actor, "hp_now")) _enemy_hp = variable_struct_get(_enemy_actor, "hp_now");
            if (is_real(_enemy_hp) && _enemy_hp > 0){
                _enemy_side_alive = true;
                break;
            }
        }
    }

    if (_enemy_side_alive){
        _B.result = "ongoing";
        _B._pending_close = false;
        try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_po_continue) {}
        if (_continue_same_turn_after_catch){
            try { variable_struct_set(_B, "_action_active", true); } catch (e_act_continue_turn) {}
            _B.phase = "turn";
            if (variable_struct_exists(_B, "_catch_anim")) _B._catch_anim = undefined;
            return _store;
        }
        try { variable_struct_set(_B, "_action_active", false); } catch (e_act_continue) {}
        try { variable_struct_set(_B, "turn_action_player", undefined); } catch (e_tap_continue) {}
        try { variable_struct_set(_B, "turn_action_enemy", undefined); } catch (e_tae_continue) {}
        try { variable_struct_set(_B, "turn_queue", []); } catch (e_tq_continue) {}
        try { variable_struct_set(_B, "_player_turn_actions", []); } catch (e_pta_continue) {}
        try { variable_struct_set(_B, "_command_pending_action", undefined); } catch (e_cpa_continue) {}
        try { variable_struct_set(_B, "_target_pick_targets", undefined); } catch (e_tpt_continue) {}
        try { variable_struct_set(_B, "_target_pick_index", 0); } catch (e_tpi_continue) {}
        try { variable_struct_set(_B, "turn_i", 0); } catch (e_ti_continue) {}
        if (is_struct(_B.sys_ui)){
            try { variable_struct_set(_B.sys_ui, "menu", "root"); } catch (e_menu_continue) {}
            try { variable_struct_set(_B.sys_ui, "selX", 0); } catch (e_selx_continue) {}
            try { variable_struct_set(_B.sys_ui, "selY", 0); } catch (e_sely_continue) {}
        }
        try {
            if (!is_undefined(__battle_uses_split_command_ui) && __battle_uses_split_command_ui(_B) && variable_struct_exists(_B, "_versus_ui") && is_array(variable_struct_get(_B, "_versus_ui"))){
                var _ui_list_continue = variable_struct_get(_B, "_versus_ui");
                var _ppids_continue = (variable_struct_exists(_B, "player_pids") && is_array(variable_struct_get(_B, "player_pids"))) ? variable_struct_get(_B, "player_pids") : [0, 1];
                for (var _ui_i_continue = 0; _ui_i_continue < array_length(_ui_list_continue); ++_ui_i_continue){
                    var _ui_continue = _ui_list_continue[_ui_i_continue];
                    if (!is_struct(_ui_continue)) _ui_continue = { menu:"root", selX:0, selY:0, command_actor_index:0, command_pending_action:undefined, target_pick_targets:undefined, target_pick_index:0 };
                    var _ui_pid_continue = (_ui_i_continue < array_length(_ppids_continue) && is_real(_ppids_continue[_ui_i_continue])) ? floor(_ppids_continue[_ui_i_continue]) : _ui_i_continue;
                    var _next_actor_continue = (!is_undefined(__battle_next_command_actor_index)) ? __battle_next_command_actor_index(_ui_pid_continue, -1) : -1;
                    variable_struct_set(_ui_continue, "menu", "root");
                    variable_struct_set(_ui_continue, "selX", 0);
                    variable_struct_set(_ui_continue, "selY", 0);
                    variable_struct_set(_ui_continue, "command_pending_action", undefined);
                    variable_struct_set(_ui_continue, "target_pick_targets", undefined);
                    variable_struct_set(_ui_continue, "target_pick_index", 0);
                    variable_struct_set(_ui_continue, "command_actor_index", (_next_actor_continue >= 0) ? _next_actor_continue : 0);
                    _ui_list_continue[_ui_i_continue] = _ui_continue;
                }
                variable_struct_set(_B, "_versus_ui", _ui_list_continue);
            }
        } catch (e_split_ui_continue) {}
        _B.phase = "command";
        if (variable_struct_exists(_B, "_catch_anim")) _B._catch_anim = undefined;
        return _store;
    }

    _B.result = "caught";
    _B._pending_close = true;

    try {
        if (!is_undefined(__battle_play_defeated_music_once)) __battle_play_defeated_music_once(_B);
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

        function __battle_resolve_live_actor_index(_pid, _ent, _fallback_index){
            var _fallback = (is_real(_fallback_index) ? floor(_fallback_index) : undefined);
            var _B = __battle_ensure_slot(_pid);
            if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return _fallback;

            var _actors = variable_struct_get(_B, "actor");
            var _hint_idx = __battle_actor_index_of(_ent);
            if (is_real(_hint_idx) && _hint_idx >= 0 && _hint_idx < array_length(_actors)){
                var _hint_actor = _actors[_hint_idx];
                if (is_struct(_hint_actor)){
                    if (_hint_actor == _ent) return _hint_idx;
                    if (__battle_struct_matches_actor(_hint_actor, _ent) || __battle_struct_matches_actor(_ent, _hint_actor)) return _hint_idx;
                }
            }

            for (var _i = 0; _i < array_length(_actors); ++_i){
                var _actor = _actors[_i];
                if (!is_struct(_actor)) continue;
                if (_actor == _ent) return _i;
                if (__battle_struct_matches_actor(_actor, _ent) || __battle_struct_matches_actor(_ent, _actor)) return _i;
            }

            if (is_real(_hint_idx) && _hint_idx >= 0 && _hint_idx < array_length(_actors)) return _hint_idx;
            if (is_real(_fallback) && _fallback >= 0 && _fallback < array_length(_actors)) return _fallback;
            return undefined;
        }

        function __battle_resolve_effect_target_index(_pid, _A, _D, _fallback_target_index){
            var _fallback = (is_real(_fallback_target_index) ? floor(_fallback_target_index) : undefined);
            var _tgt_idx = __battle_resolve_live_actor_index(_pid, _D, _fallback);
            if (is_real(_tgt_idx)) return _tgt_idx;

            var _act_idx = __battle_resolve_live_actor_index(_pid, _A, undefined);
            if (is_real(_act_idx) && !is_undefined(__battle_get_default_target_index)) return __battle_get_default_target_index(_pid, _act_idx);

            return _fallback;
        }
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
        _move_id = floor(_move_id);
        if (_move_id <= 0) return true;
        if (!variable_global_exists("_moves") || !is_array(global._moves)) return true;
        if (_move_id >= array_length(global._moves)) return true;
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
        var _Bslot = __battle_ensure_slot(_pid);
        if (!is_struct(_Bslot) || !variable_struct_exists(_Bslot, "actor") || !is_array(variable_struct_get(_Bslot, "actor"))) return undefined;
        var acts = variable_struct_get(_Bslot, "actor");
        var best_move = undefined;
        var best_ts = -1;
        for (var ai = 0; ai < array_length(acts); ++ai){
            var act = acts[ai];
            if (!is_struct(act)) continue;
            var _hist = [];
            try {
                if (variable_struct_exists(act, "_last_moves_used") && is_array(variable_struct_get(act, "_last_moves_used"))){
                    _hist = variable_struct_get(act, "_last_moves_used");
                }
            } catch (e_h) { _hist = []; }
            for (var hi = array_length(_hist) - 1; hi >= 0; --hi){
                var rec = _hist[hi];
                if (!is_struct(rec) || !variable_struct_exists(rec, "move")) continue;
                var cand = variable_struct_get(rec, "move");
                if (!is_real(cand)) continue;
                if (__battle_move_copycat_is_ignored(cand)) continue;
                var ts = (variable_struct_exists(rec, "ts") ? variable_struct_get(rec, "ts") : hi);
                if (!is_real(ts)) ts = hi;
                if (ts >= best_ts){
                    best_ts = ts;
                    best_move = cand;
                }
                break;
            }
        }
        if (is_real(best_move)) return best_move;
        try {
            if (variable_global_exists("lastMoveUsed_ID") && is_real(global.lastMoveUsed_ID) && global.lastMoveUsed_ID > 0 && !__battle_move_copycat_is_ignored(global.lastMoveUsed_ID)){
                return global.lastMoveUsed_ID;
            }
        } catch (e_glob) {}
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
    if (!__battle_check_can_act(_user, _move)) return;

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
    var _called_move_active = false;
    var _suppress_called_dialog = false;
    try {
        if (is_struct(_user) && variable_struct_exists(_user, "_called_move_active") && variable_struct_get(_user, "_called_move_active") == true) _called_move_active = true;
        if (_called_move_active && is_struct(_user) && variable_struct_exists(_user, "_suppress_called_move_dialog") && variable_struct_get(_user, "_suppress_called_move_dialog") == true) _suppress_called_dialog = true;
    } catch (e_called_ctx) { _called_move_active = false; _suppress_called_dialog = false; }

    var _is_disable_move = (is_real(_move) && _move == 50) || (_moveIdent == "disable");
    var _is_protect_like = (is_real(_move) && (_move == 182 || _move == 197 || _move == 852 || _move == 908));

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
                    var _uname_clear = __battle_dialog_actor_name(_user, "The Pokémon");
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
        var _copiedMove = __battle_find_copycat_candidate(_pid, _user);
        if (is_real(_copiedMove) && _copiedMove == _move) _copiedMove = undefined;
        if (!is_real(_copiedMove)){
            dialog_queue(_user.name + " failed to Copycat!");
            return;
        }
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
        if (_should_enqueue_used && !_suppress_called_dialog) {
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
                array_push(_hist_user, { move: _move, target_index: _t_idx_record, ts: current_time });
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
                    var _src_idx_record = undefined;
                    var _src_name_record = "";
                    try {
                        if (is_struct(_user)){
                            if (variable_struct_exists(_user, "actor_index") && is_real(variable_struct_get(_user, "actor_index"))) _src_idx_record = floor(variable_struct_get(_user, "actor_index"));
                            if (variable_struct_exists(_user, "name")) _src_name_record = string(variable_struct_get(_user, "name"));
                        }
                    } catch (e_src_record_light) {}
                    array_push(_arr2, { move: _move, src_index: _src_idx_record, src_name: _src_name_record, ts: current_time });
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
            var _tname_disable = __battle_dialog_actor_name(_target, "The target");
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
            if (is_real(_move) && (_move == 364 || _move == 467 || _move == 566)){
                _t_protected = false;
                try { variable_struct_set(_target, "sys_protected", false); } catch (e_bp) {}
                try { variable_struct_set(_target, "_protected", false); } catch (e_bp2) {}
                try { variable_struct_set(_target, "sys_protected_turn", undefined); } catch (e_bp3) {}
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
            var _target_name_si = __battle_dialog_actor_name(_target, "The target");
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
                var _miss_name = __battle_dialog_actor_name(_user, "The attacker");
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
        if (!is_undefined(__battle_resolve_live_actor_index)) _tidx = __battle_resolve_live_actor_index(_pid, _target, undefined);
        else if (is_struct(_target) && variable_struct_exists(_target, "actor_index") && is_real(variable_struct_get(_target, "actor_index"))) _tidx = variable_struct_get(_target, "actor_index");
        else if (is_struct(_target) && variable_struct_exists(_target, "slot") && is_real(variable_struct_get(_target, "slot"))) _tidx = variable_struct_get(_target, "slot");
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
                    try { ach = __battle_ability_secondary_effect_chance(_user, _target, ach); } catch (e_ability_ail_chance) {}
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


function __battle_check_can_act(_user, _move_id){
    try {
        if (is_struct(_user) && variable_struct_exists(_user, "_sleep_talk_bypass") && variable_struct_get(_user, "_sleep_talk_bypass") == true){
            return true;
        }
    } catch (e_sleep_talk_bypass) {}
    try {
        if (is_struct(_user) && variable_struct_exists(_user, "_sleep_wake_dialog_pending") && variable_struct_get(_user, "_sleep_wake_dialog_pending") == true){
            variable_struct_set(_user, "_sleep_wake_dialog_pending", false);
            return true;
        }
    } catch (e_sleep_wake_resume) {}
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
                var _thaw_on_use = (is_real(_move_id) && (_move_id == 172 || _move_id == 221));
                if (_thaw_on_use){
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][freeze] thaw-on-use move=" + string(_move_id));
                    status_system_clear_status(_user, "freeze");
                    return true;
                }
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
                var _sleep_name = "The user";
                try {
                    _sleep_name = string(__status_mon_display_name(_user));
                } catch (e_sleep_name) {
                    if (variable_struct_exists(_user, "name")) _sleep_name = string(variable_struct_get(_user, "name"));
                }
                try {
                    var _pid_sleep = __battle_guess_pid_for_entities(_user, undefined);
                    if (is_real(_pid_sleep) && !is_undefined(__battle_slot_has_active_uproar) && __battle_slot_has_active_uproar(_pid_sleep)){
                        var _wake_uproar_msg = _sleep_name + " woke up in the uproar!";
                        var _wake_uproar_queued = false;
                        try { variable_struct_set(_user, "_suppress_sleep_wake_dialog_once", true); } catch (e_sleep_uproar_suppress) {}
                        status_system_clear_status(_user, "sleep");
                        try { _wake_uproar_queued = __status_request_dialog_for_mon(_user, _wake_uproar_msg, false); } catch (e_sleep_uproar_queue) { _wake_uproar_queued = false; }
                        if (!_wake_uproar_queued){
                            try {
                                if (!is_undefined(dialog_queue)){
                                    dialog_queue(_wake_uproar_msg);
                                    _wake_uproar_queued = true;
                                }
                            } catch (e_sleep_uproar_fallback) {}
                        }
                        if (_wake_uproar_queued){
                            try { variable_struct_set(_user, "_sleep_wake_dialog_pending", true); } catch (e_sleep_uproar_pending) {}
                            try {
                                var _B_sleep_uproar = __battle_ensure_slot(_pid_sleep);
                                if (is_struct(_B_sleep_uproar)) variable_struct_set(_B_sleep_uproar, "_hold_current_action_for_status_dialog", true);
                            } catch (e_sleep_uproar_hold) {}
                            return false;
                        }
                        return true;
                    }
                } catch (e_sleep_uproar) {}
                var inst_s = status_system_get(_user, "sleep");
                var turns = (is_struct(inst_s) && variable_struct_exists(inst_s, "turns") && is_real(variable_struct_get(inst_s, "turns"))) ? variable_struct_get(inst_s, "turns") : undefined;
                if (is_real(turns) && turns > 0){
                    // Decrement remaining turns; status_system.on_tick will handle dialog
                    if (is_struct(inst_s) && is_real(inst_s.turns)) inst_s.turns = max(0, inst_s.turns - 1);
                    return false;
                }
                // no turns left -> wake up
                var _wake_msg = _sleep_name + " woke up!";
                var _wake_queued = false;
                try { variable_struct_set(_user, "_suppress_sleep_wake_dialog_once", true); } catch (e_sleep_suppress) {}
                status_system_clear_status(_user, "sleep");
                try { _wake_queued = __status_request_dialog_for_mon(_user, _wake_msg, false); } catch (e_sleep_queue) { _wake_queued = false; }
                if (!_wake_queued){
                    try {
                        if (!is_undefined(dialog_queue)){
                            dialog_queue(_wake_msg);
                            _wake_queued = true;
                        }
                    } catch (e_sleep_fallback) {}
                }
                if (_wake_queued){
                    try { variable_struct_set(_user, "_sleep_wake_dialog_pending", true); } catch (e_sleep_pending) {}
                    try {
                        var _pid_sleep_wake = __battle_guess_pid_for_entities(_user, undefined);
                        var _B_sleep_wake = __battle_ensure_slot(_pid_sleep_wake);
                        if (is_struct(_B_sleep_wake)) variable_struct_set(_B_sleep_wake, "_hold_current_action_for_status_dialog", true);
                    } catch (e_sleep_hold) {}
                    return false;
                }
                return true;
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
            // Confusion: announce the state, then 50% chance to hurt self instead of acting.
            if (status_system_has_status(_user, "confusion")){
                var _cinst = undefined;
                try { _cinst = status_system_get(_user, "confusion"); } catch (e_ci) { _cinst = undefined; }
                var _conf_name = "The user";
                try { _conf_name = string(__status_mon_display_name(_user)); } catch (e_conf_name) {
                    if (variable_struct_exists(_user, "name")) _conf_name = string(variable_struct_get(_user, "name"));
                }
                var _actor_idx_conf = (variable_struct_exists(_user, "actor_index") && is_real(variable_struct_get(_user, "actor_index"))) ? floor(variable_struct_get(_user, "actor_index")) : 0;

                var _cturns = (is_struct(_cinst) && variable_struct_exists(_cinst, "turns") && is_real(variable_struct_get(_cinst, "turns"))) ? variable_struct_get(_cinst, "turns") : undefined;
                if (is_real(_cturns) && _cturns <= 0){
                    dialog_queue(_conf_name + " snapped out of confusion!");
                    status_system_clear_status(_user, "confusion");
                    try { variable_struct_set(_user, "_confusion_turn_pending_roll", false); } catch (e_conf_turn_reset) {}
                    return true;
                }

                var _pending_conf_roll = (variable_struct_exists(_user, "_confusion_turn_pending_roll") && variable_struct_get(_user, "_confusion_turn_pending_roll") == true);
                if (!_pending_conf_roll){
                    var _pid_conf_announce = __battle_guess_pid_for_entities(_user, _user);
                    var _shown_conf = false;
                    try {
                        __battle_request_animation_safe(_pid_conf_announce, {
                            type: "move",
                            user: _user,
                            target: _user,
                            target_index: _actor_idx_conf,
                            visual_kind: "confused_ducks",
                            sprite: spr_confused,
                            duration: 1900,
                            offset_y: -30,
                            orbit_count: 3,
                            orbit_radius_x: 22,
                            orbit_radius_y: 8,
                            spin_speed: 1.05,
                            tint: c_white
                        });
                    } catch (e_conf_turn_anim) {}
                    try {
                        if (is_real(_pid_conf_announce) && !is_undefined(dialog2p_show_now)){
                            dialog2p_show_now(_pid_conf_announce, { text: _conf_name + " is confused!" });
                            _shown_conf = true;
                        }
                    } catch (e_conf_now) { _shown_conf = false; }
                    if (!_shown_conf){
                        try { _shown_conf = __status_request_dialog_for_mon(_user, _conf_name + " is confused!", false); } catch (e_conf_msg) { _shown_conf = false; }
                    }
                    if (!_shown_conf){
                        try {
                            dialog_queue(_conf_name + " is confused!");
                            _shown_conf = true;
                        } catch (e_conf_queue) { _shown_conf = false; }
                    }
                    if (_shown_conf){
                        try { variable_struct_set(_user, "_confusion_turn_pending_roll", true); } catch (e_conf_pending) {}
                        try {
                            var _B_conf_announce = __battle_ensure_slot(_pid_conf_announce);
                            if (is_struct(_B_conf_announce)) variable_struct_set(_B_conf_announce, "_hold_current_action_for_status_dialog", true);
                        } catch (e_conf_hold) {}
                        return false;
                    }
                }

                try { variable_struct_set(_user, "_confusion_turn_pending_roll", false); } catch (e_conf_resume) {}
                if (is_struct(_cinst) && is_real(_cturns) && _cturns > 0) variable_struct_set(_cinst, "turns", max(0, _cturns - 1));

                if (irandom(1) == 0){
                    var _pid_conf = __battle_guess_pid_for_entities(_user, _user);
                    try { variable_struct_set(_user, "_allow_confusion_self_hit", true); } catch (e_conf_flag_set) {}
                    try { __battle_apply_move_damage(_pid_conf, _actor_idx_conf, _user, _user, -1, 40); } catch (e_conf_self) {}
                    try { variable_struct_set(_user, "_allow_confusion_self_hit", false); } catch (e_conf_flag_clear) {}
                    dialog_queue(_conf_name + " hurt itself in its confusion!");
                    try { __battle_request_animation_safe(_user, { type: "confusion_hit" }); } catch (e_conf_anim) {}
                    return false;
                }
                return true;
            }
            // Infatuation: 50% chance to be immobilized.
            if (status_system_has_status(_user, "infatuation")){
                var _iinst = undefined;
                try { _iinst = status_system_get(_user, "infatuation"); } catch (e_ii) { _iinst = undefined; }
                var _immobile_love = false;
                if (is_struct(_iinst) && variable_struct_exists(_iinst, "_force_skip_next_move") && variable_struct_get(_iinst, "_force_skip_next_move") == true){
                    _immobile_love = true;
                    try { variable_struct_set(_iinst, "_force_skip_next_move", false); } catch (e_ilclr) {}
                } else {
                    _immobile_love = (irandom(1) == 0);
                }
                if (_immobile_love){
                    dialog_queue((variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user") + " is in love and can't move!");
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

function vkbd__clear_input_latch(){
    if (!variable_global_exists("SYS_VKBD") || !is_struct(global.SYS_VKBD)) return;
    global.SYS_VKBD.sys_input_cooldown = 8;
    global.SYS_VKBD.sys_last_key = "";
    global.SYS_VKBD.sys_repeat_key = "";
    global.SYS_VKBD.sys_repeat_timer = 0;
}

function vkbd__can_accept_input(){
    if (!variable_global_exists("SYS_VKBD") || !is_struct(global.SYS_VKBD)) return true;
    if (!variable_struct_exists(global.SYS_VKBD, "sys_input_cooldown")) global.SYS_VKBD.sys_input_cooldown = 0;
    if (global.SYS_VKBD.sys_input_cooldown > 0){
        global.SYS_VKBD.sys_input_cooldown -= 1;
        return false;
    }
    return true;
}

function vkbd__append_char(_ch){
    if (!variable_global_exists("SYS_VKBD") || !is_struct(global.SYS_VKBD)) return false;
    if (!is_string(_ch) || string_length(_ch) <= 0) return false;

    if (!variable_struct_exists(global.SYS_VKBD, "text") || !is_string(global.SYS_VKBD.text)) global.SYS_VKBD.text = "";
    if (!variable_struct_exists(global.SYS_VKBD, "max_len") || !is_real(global.SYS_VKBD.max_len)) global.SYS_VKBD.max_len = 12;

    if (string_length(global.SYS_VKBD.text) >= global.SYS_VKBD.max_len) return false;

    // Allow the same key repeatedly. The old behavior blocked duplicate keys
    // because it treated same-key selection as held input instead of a new press.
    global.SYS_VKBD.text += _ch;
    global.SYS_VKBD.sys_last_key = _ch;
    return true;
}
