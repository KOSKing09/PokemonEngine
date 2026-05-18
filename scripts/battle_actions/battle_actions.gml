function __battle_dialog_actor_name(_actor, _fallback){
    var _fb = is_string(_fallback) ? _fallback : "The Pokemon";
    if (!is_struct(_actor)) return _fb;

    if (!is_undefined(__battle_actor_display_name)){
        var _resolved = __battle_actor_display_name(_actor);
        if (is_string(_resolved) && string_length(string_trim(_resolved)) > 0 && string(_resolved) != "???") return string_trim(_resolved);
    }

    var _mon_ref = undefined;
    if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) _mon_ref = variable_struct_get(_actor, "mon");
    else if (variable_struct_exists(_actor, "pokemon") && is_struct(variable_struct_get(_actor, "pokemon"))) _mon_ref = variable_struct_get(_actor, "pokemon");
    else if (variable_struct_exists(_actor, "original_mon") && is_struct(variable_struct_get(_actor, "original_mon"))) _mon_ref = variable_struct_get(_actor, "original_mon");
    else if (variable_struct_exists(_actor, "source_mon") && is_struct(variable_struct_get(_actor, "source_mon"))) _mon_ref = variable_struct_get(_actor, "source_mon");
    else if (variable_struct_exists(_actor, "wild_mon") && is_struct(variable_struct_get(_actor, "wild_mon"))) _mon_ref = variable_struct_get(_actor, "wild_mon");
    else _mon_ref = _actor;

    if (is_struct(_mon_ref)){
        if (variable_struct_exists(_mon_ref, "nickname")){
            var _nick = variable_struct_get(_mon_ref, "nickname");
            if (is_string(_nick) && string_length(string_trim(_nick)) > 0) return string_trim(_nick);
        }

        if (!is_undefined(mon_display_name)){
            var _display = mon_display_name(_mon_ref);
            if (is_string(_display) && string_length(string_trim(_display)) > 0 && string(_display) != "???") return string_trim(_display);
        }

        if (variable_struct_exists(_mon_ref, "name")){
            var _mon_name = variable_struct_get(_mon_ref, "name");
            if (is_string(_mon_name) && string_length(string_trim(_mon_name)) > 0 && string(_mon_name) != "???") return string_trim(_mon_name);
        }
    }

    if (variable_struct_exists(_actor, "nickname")){
        var _actor_nick = variable_struct_get(_actor, "nickname");
        if (is_string(_actor_nick) && string_length(string_trim(_actor_nick)) > 0) return string_trim(_actor_nick);
    }

    if (variable_struct_exists(_actor, "name")){
        var _actor_name = variable_struct_get(_actor, "name");
        if (is_string(_actor_name) && string_length(string_trim(_actor_name)) > 0 && string(_actor_name) != "???") return string_trim(_actor_name);
    }

    return _fb;
}

function __battle_item_consume_held(_actor){
    if (!is_struct(_actor)) return -1;
    var _iid = -1;
    try {
        if (variable_struct_exists(_actor, "held_item_id") && is_real(variable_struct_get(_actor, "held_item_id"))) _iid = floor(variable_struct_get(_actor, "held_item_id"));
        if (_iid > 0){
            variable_struct_set(_actor, "_consumed_item", _iid);
            variable_struct_set(_actor, "_item_lost", true);
            variable_struct_set(_actor, "item_lost", true);
            variable_struct_set(_actor, "held_item_id", -1);
            variable_struct_set(_actor, "held_item_real_name", "");
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
                var _mon = variable_struct_get(_actor, "mon");
                variable_struct_set(_mon, "_consumed_item", _iid);
                variable_struct_set(_mon, "_item_lost", true);
                variable_struct_set(_mon, "item_lost", true);
                variable_struct_set(_mon, "held_item_id", -1);
                variable_struct_set(_mon, "held_item_real_name", "");
            }
        }
    } catch (e_consume_held_item) {}
    return _iid;
}

function __battle_held_berry_can_use(_actor, _item_id){
    if (!is_struct(_actor) || !is_real(_item_id) || _item_id <= 0) return false;
    try {
        if (!is_undefined(__battle_ability_item_is_berry) && !__battle_ability_item_is_berry(_item_id)) return false;
        if (!is_undefined(__battle_ability_item_blocked_by_opponent) && __battle_ability_item_blocked_by_opponent(_actor, _item_id)) return false;
    } catch (e_berry_can_use) {}
    return true;
}

function __battle_actor_has_any_status_for_item(_actor, _statuses){
    if (!is_struct(_actor) || is_undefined(status_system_has_status)) return false;
    if (!is_array(_statuses)) _statuses = [_statuses];
    for (var _si = 0; _si < array_length(_statuses); ++_si){
        var _sid = string(_statuses[_si]);
        try { if (status_system_has_status(_actor, _sid)) return true; } catch (e_status_actor) {}
        try {
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon")) && status_system_has_status(variable_struct_get(_actor, "mon"), _sid)) return true;
        } catch (e_status_mon) {}
    }
    return false;
}

function __battle_clear_any_status_for_item(_actor, _statuses){
    if (!is_struct(_actor) || is_undefined(status_system_clear_status)) return false;
    if (!is_array(_statuses)) _statuses = [_statuses];
    var _did = false;
    for (var _si = 0; _si < array_length(_statuses); ++_si){
        var _sid = string(_statuses[_si]);
        try { if (status_system_clear_status(_actor, _sid)) _did = true; } catch (e_clear_actor) {}
        try {
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon")) && status_system_clear_status(variable_struct_get(_actor, "mon"), _sid)) _did = true;
        } catch (e_clear_mon) {}
    }
    if (_did){
        try { if (variable_struct_exists(_actor, "status")) variable_struct_set(_actor, "status", 0); } catch (e_legacy_status) {}
        try { if (variable_struct_exists(_actor, "status_id")) variable_struct_set(_actor, "status_id", 0); } catch (e_legacy_status_id) {}
    }
    return _did;
}

function __battle_consume_held_berry_and_mark(_actor, _item_label){
    var _iid = __battle_item_consume_held(_actor);
    if (_iid > 0 && !is_undefined(__battle_apply_after_item_consumed_ability)){
        try { __battle_apply_after_item_consumed_ability(_actor, _iid); } catch (e_after_berry_ability) {}
    }
    return _iid;
}

function __battle_try_auto_use_held_berry(_pid, _actor_index, _actor, _attacker, _move_id, _damage_class, _type_mult, _timing){
    if (!is_struct(_actor) || is_undefined(item_runtime_actor_held_item_id) || is_undefined(item_runtime_actor_held_actions)) return false;
    var _item_id = item_runtime_actor_held_item_id(_actor);
    if (!__battle_held_berry_can_use(_actor, _item_id)) return false;
    var _actions = item_runtime_actor_held_actions(_actor, "held_auto_use");
    var _did = false;
    var _hp_now = __battle_hp_now(_actor);
    var _hp_max = max(1, __battle_hp_max(_actor));
    var _item_label = (!is_undefined(__battle_held_item_label)) ? __battle_held_item_label(_actor) : "Berry";
    var _name = __battle_dialog_actor_name(_actor, "The Pokemon");

    for (var _ai = 0; _ai < array_length(_actions); ++_ai){
        if (_did) break;
        var _act = _actions[_ai];
        if (!is_struct(_act)) continue;
        var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
        var _data = (variable_struct_exists(_act, "data") && is_struct(variable_struct_get(_act, "data"))) ? variable_struct_get(_act, "data") : {};
        var _threshold = (variable_struct_exists(_data, "hp_fraction") && is_real(variable_struct_get(_data, "hp_fraction"))) ? real(variable_struct_get(_data, "hp_fraction")) : 0;
        var _meets_hp = (_threshold <= 0 || (_hp_now > 0 && _hp_now <= floor(_hp_max * _threshold)));

        if (_kind == "cure_status"){
            var _statuses = variable_struct_exists(_data, "status") ? variable_struct_get(_data, "status") : [];
            if (!__battle_actor_has_any_status_for_item(_actor, _statuses)) continue;
            if (__battle_clear_any_status_for_item(_actor, _statuses)){
                __battle_consume_held_berry_and_mark(_actor, _item_label);
                try { dialog_queue(_name + " cured its status using its " + _item_label + "!"); } catch (e_berry_status_dialog) {}
                _did = true;
            }
        } else if (_kind == "hp_threshold_heal_flat" || _kind == "hp_threshold_heal_fraction"){
            if (!_meets_hp || _hp_now >= _hp_max) continue;
            var _heal = 0;
            if (_kind == "hp_threshold_heal_flat"){
                _heal = (variable_struct_exists(_data, "amount") && is_real(variable_struct_get(_data, "amount"))) ? floor(variable_struct_get(_data, "amount")) : 10;
            } else {
                var _num = (variable_struct_exists(_data, "numerator") && is_real(variable_struct_get(_data, "numerator"))) ? real(variable_struct_get(_data, "numerator")) : 1;
                var _den = (variable_struct_exists(_data, "denominator") && is_real(variable_struct_get(_data, "denominator"))) ? max(1, real(variable_struct_get(_data, "denominator"))) : 4;
                _heal = max(1, floor(_hp_max * _num / _den));
            }
            if (!is_undefined(__battle_ability_item_effect_multiplier)) _heal = max(1, floor(_heal * __battle_ability_item_effect_multiplier(_actor, _item_id)));
            var _after = min(_hp_max, _hp_now + _heal);
            if (_after > _hp_now){
                __battle_set_hp_now(_actor, _after);
                try { __battle_clear_fainted_if_healed(_actor); } catch (e_berry_heal_clear) {}
                try { __battle_request_animation_safe(_pid, { type:"heal", actor:_actor, target_index:_actor_index, amount:(_after - _hp_now) }); } catch (e_berry_heal_anim) {}
                __battle_consume_held_berry_and_mark(_actor, _item_label);
                try { dialog_queue(_name + " restored HP using its " + _item_label + "!"); } catch (e_berry_heal_dialog) {}
                _did = true;
            }
        } else if (_kind == "hp_threshold_stage"){
            if (!_meets_hp) continue;
            var _stat = variable_struct_exists(_data, "stat") ? string(variable_struct_get(_data, "stat")) : "";
            var _delta = (variable_struct_exists(_data, "delta") && is_real(variable_struct_get(_data, "delta"))) ? floor(variable_struct_get(_data, "delta")) : 1;
            var _stage_ok = (!is_undefined(__battle_ability_change_stage) && __battle_ability_change_stage(_actor, _stat, _delta));
            if (_stage_ok){
                __battle_consume_held_berry_and_mark(_actor, _item_label);
                try { dialog_queue(_name + "'s " + string_upper(_stat) + " rose using its " + _item_label + "!"); } catch (e_berry_stage_dialog) {}
                _did = true;
            }
        } else if (_kind == "hp_threshold_random_stage"){
            if (!_meets_hp) continue;
            var _stats = ["atk","def","spa","spd","spe"];
            var _picked = _stats[irandom(array_length(_stats) - 1)];
            var _rdelta = (variable_struct_exists(_data, "delta") && is_real(variable_struct_get(_data, "delta"))) ? floor(variable_struct_get(_data, "delta")) : 2;
            if (!is_undefined(__battle_ability_change_stage) && __battle_ability_change_stage(_actor, _picked, _rdelta)){
                __battle_consume_held_berry_and_mark(_actor, _item_label);
                try { dialog_queue(_name + "'s stats rose using its " + _item_label + "!"); } catch (e_berry_random_dialog) {}
                _did = true;
            }
        } else if (_kind == "hp_threshold_crit"){
            if (!_meets_hp) continue;
            var _crit_add = (variable_struct_exists(_data, "stages") && is_real(variable_struct_get(_data, "stages"))) ? floor(variable_struct_get(_data, "stages")) : 2;
            var _crit_prev = (variable_struct_exists(_actor, "_focus_energy_level") && is_real(variable_struct_get(_actor, "_focus_energy_level"))) ? floor(variable_struct_get(_actor, "_focus_energy_level")) : 0;
            variable_struct_set(_actor, "_focus_energy_level", clamp(_crit_prev + _crit_add, 0, 3));
            __battle_consume_held_berry_and_mark(_actor, _item_label);
            try { dialog_queue(_name + " is getting pumped using its " + _item_label + "!"); } catch (e_berry_crit_dialog) {}
            _did = true;
        } else if (_kind == "after_super_effective_heal"){
            if (!is_real(_type_mult) || _type_mult <= 1 || _hp_now <= 0 || _hp_now >= _hp_max) continue;
            var _enum = (variable_struct_exists(_data, "numerator") && is_real(variable_struct_get(_data, "numerator"))) ? real(variable_struct_get(_data, "numerator")) : 1;
            var _eden = (variable_struct_exists(_data, "denominator") && is_real(variable_struct_get(_data, "denominator"))) ? max(1, real(variable_struct_get(_data, "denominator"))) : 4;
            var _eheal = max(1, floor(_hp_max * _enum / _eden));
            if (!is_undefined(__battle_ability_item_effect_multiplier)) _eheal = max(1, floor(_eheal * __battle_ability_item_effect_multiplier(_actor, _item_id)));
            var _eafter = min(_hp_max, _hp_now + _eheal);
            if (_eafter > _hp_now){
                __battle_set_hp_now(_actor, _eafter);
                try { __battle_request_animation_safe(_pid, { type:"heal", actor:_actor, target_index:_actor_index, amount:(_eafter - _hp_now) }); } catch (e_enigma_anim) {}
                __battle_consume_held_berry_and_mark(_actor, _item_label);
                try { dialog_queue(_name + " restored HP using its " + _item_label + "!"); } catch (e_enigma_dialog) {}
                _did = true;
            }
        } else if (_kind == "hp_threshold_next_accuracy"){
            if (!_meets_hp) continue;
            var _acc_mult = (variable_struct_exists(_data, "multiplier") && is_real(variable_struct_get(_data, "multiplier"))) ? real(variable_struct_get(_data, "multiplier")) : 1.2;
            variable_struct_set(_actor, "_held_next_accuracy_multiplier", _acc_mult);
            __battle_consume_held_berry_and_mark(_actor, _item_label);
            try { dialog_queue(_name + " became more focused using its " + _item_label + "!"); } catch (e_micle_dialog) {}
            _did = true;
        } else if (_kind == "hp_threshold_next_priority"){
            if (!_meets_hp) continue;
            variable_struct_set(_actor, "_held_next_priority", true);
            __battle_consume_held_berry_and_mark(_actor, _item_label);
            try { dialog_queue(_name + " is ready to move first using its " + _item_label + "!"); } catch (e_custap_dialog) {}
            _did = true;
        }
    }
    return _did;
}

function __battle_try_held_after_damage_taken_items(_pid, _actor_index, _actor, _attacker, _attacker_index, _move_id, _damage_class, _actual_delta){
    if (!is_struct(_actor) || !is_struct(_attacker) || _actual_delta <= 0 || is_undefined(item_runtime_actor_held_item_id) || is_undefined(item_runtime_actor_held_actions)) return false;
    var _item_id = item_runtime_actor_held_item_id(_actor);
    if (!__battle_held_berry_can_use(_actor, _item_id)) return false;
    var _actions = item_runtime_actor_held_actions(_actor, "after_damage_taken");
    var _did = false;
    for (var _ai = 0; _ai < array_length(_actions); ++_ai){
        var _act = _actions[_ai];
        if (!is_struct(_act)) continue;
        var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
        if (_kind != "retaliate_damage_class_fraction") continue;
        var _data = (variable_struct_exists(_act, "data") && is_struct(variable_struct_get(_act, "data"))) ? variable_struct_get(_act, "data") : {};
        var _want_dc = (variable_struct_exists(_data, "damage_class") && is_real(variable_struct_get(_data, "damage_class"))) ? floor(variable_struct_get(_data, "damage_class")) : -1;
        if (!is_real(_damage_class) || floor(_damage_class) != _want_dc) continue;
        var _num = (variable_struct_exists(_data, "numerator") && is_real(variable_struct_get(_data, "numerator"))) ? real(variable_struct_get(_data, "numerator")) : 1;
        var _den = (variable_struct_exists(_data, "denominator") && is_real(variable_struct_get(_data, "denominator"))) ? max(1, real(variable_struct_get(_data, "denominator"))) : 8;
        var _dmg = max(1, floor(max(1, __battle_hp_max(_attacker)) * _num / _den));
        var _label = (!is_undefined(__battle_held_item_label)) ? __battle_held_item_label(_actor) : "Berry";
        __battle_consume_held_berry_and_mark(_actor, _label);
        try { dialog_queue(__battle_dialog_actor_name(_attacker, "The attacker") + " was hurt by " + __battle_dialog_actor_name(_actor, "the target") + "'s " + _label + "!"); } catch (e_retaliate_dialog) {}
        if (is_real(_attacker_index) && _attacker_index >= 0) __battle_apply_damage(_pid, _attacker_index, _dmg, 1.0);
        else __battle_set_hp_now(_attacker, max(0, __battle_hp_now(_attacker) - _dmg));
        _did = true;
        break;
    }
    return _did;
}

// Battle action helpers (extracted from battle_system.gml)

function __battle_consume_pp(_A, _move_slot){
    if (!is_struct(_A)) return false;
    try {
        if (variable_struct_exists(_A, "_called_move_active") && variable_struct_get(_A, "_called_move_active") == true) return true;
    } catch (e_called_pp) {}
    if (!is_array(_A.pps)) return false;
    if (!is_real(_move_slot) || _move_slot < 0 || _move_slot >= array_length(_A.pps)) return false;
    var cur = _A.pps[_move_slot];
    if (!is_real(cur) || cur <= 0) return false;
    var _cost = 1;
    try {
        var _pid_pp = __battle_guess_pid_for_entities(_A, undefined);
        if (is_real(_pid_pp)){
            var _Bpp = __battle_ensure_slot(_pid_pp);
            if (is_struct(_Bpp) && variable_struct_exists(_Bpp, "actor") && is_array(variable_struct_get(_Bpp, "actor"))){
                var _actors_pp = variable_struct_get(_Bpp, "actor");
                var _aidx_pp = __battle_action_actor_index(_pid_pp, _A);
                var _aside_pp = (is_real(_aidx_pp) && !is_undefined(__battle_actor_side)) ? __battle_actor_side(_aidx_pp) : 0;
                for (var _pi = 0; _pi < array_length(_actors_pp); ++_pi){
                    var _opp_pp = _actors_pp[_pi];
                    if (!is_struct(_opp_pp) || __battle_hp_now(_opp_pp) <= 0) continue;
                    if (!is_undefined(__battle_actor_side) && __battle_actor_side(_pi) == _aside_pp) continue;
                    var _pp_actions = __battle_actor_ability_actions(_opp_pp, "pp_consume");
                    for (var _pai = 0; _pai < array_length(_pp_actions); ++_pai){
                        var _pact = _pp_actions[_pai];
                        if (!is_struct(_pact)) continue;
                        var _pkind = variable_struct_exists(_pact, "kind") ? string_lower(string(variable_struct_get(_pact, "kind"))) : "";
                        if (_pkind != "extra_pp_cost_against_self") continue;
                        var _pdata = (variable_struct_exists(_pact, "data") && is_struct(variable_struct_get(_pact, "data"))) ? variable_struct_get(_pact, "data") : {};
                        var _extra = (variable_struct_exists(_pdata, "extra") && is_real(variable_struct_get(_pdata, "extra"))) ? variable_struct_get(_pdata, "extra") : 1;
                        _cost += max(0, floor(_extra));
                        try { __battle_queue_ability_action_dialog(_opp_pp, _pact, _A, {}); } catch (e_pressure_dialog) {}
                    }
                }
            }
        }
    } catch (e_pressure_pp) {}
    _A.pps[_move_slot] = max(0, cur - _cost);
    return true;
}

function __battle_roll_hit(_move_id, _A, _D){
    // If attacker and defender are provided, use the new stage-aware check
    try {
        if (!is_undefined(_A) && !is_undefined(_D) && !is_undefined(__battle_can_hit_target)){
            return __battle_can_hit_target(_A, _D, _move_id);
        }
    } catch (e) { /* fall back to simple check */ }
    var acc = __battle_move_accuracy(_move_id);
    return (irandom(99) < clamp(floor(acc), 0, 100));
}

/// Best-effort helper: locate the battle slot for either participant when _pid is missing.
function __battle_guess_pid_for_entities(_A, _D){
    var candidates = [];
    if (is_struct(_A)) array_push(candidates, _A);
    if (is_struct(_D) && _D != _A) array_push(candidates, _D);

    if (array_length(candidates) == 0) return undefined;

    try {
        if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) return undefined;
        for (var _pid_iter = 0; _pid_iter < array_length(global.sys_battles); ++_pid_iter){
            var _slot = global.sys_battles[_pid_iter];
            if (!is_struct(_slot) || !variable_struct_exists(_slot, "actor")) continue;
            var _actors = variable_struct_get(_slot, "actor");
            if (!is_array(_actors)) continue;
            for (var _ai = 0; _ai < array_length(_actors); ++_ai){
                var _act = _actors[_ai];
                if (!is_struct(_act)) continue;
                for (var _ci = 0; _ci < array_length(candidates); ++_ci){
                    var _cand = candidates[_ci];
                    if (_act == _cand) return _pid_iter;
                    if (variable_struct_exists(_act, "mon") && variable_struct_get(_act, "mon") == _cand) return _pid_iter;
                }
            }
        }
    } catch (e_gp){ /* ignore and fall back */ }

    return undefined;
}

function __battle_action_actor_index(_pid, _actor){
    try {
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return undefined;
        var _actors = variable_struct_get(_B, "actor");
        for (var _i = 0; _i < array_length(_actors); ++_i){
            if (is_struct(_actors[_i]) && _actors[_i] == _actor) return _i;
        }
    } catch (e_idx) {}
    return undefined;
}

function __battle_action_move_identifier_safe(_move_id){
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){
            var _mv = global._moves[_move_id];
            if (is_struct(_mv) && variable_struct_exists(_mv, "identifier")) return string_lower(string(variable_struct_get(_mv, "identifier")));
        }
    } catch (e_ident) {}
    return "";
}

function __battle_move_is_contactish(_move_id){
    var _ident = __battle_action_move_identifier_safe(_move_id);
    if (string_length(_ident) <= 0) return false;
    switch (_ident){
        case "earthquake": case "bulldoze": case "magnitude": case "rock-slide": case "stone-edge":
        case "smack-down": case "razor-leaf": case "magical-leaf": case "bullet-seed":
        case "water-gun": case "bubble": case "bubble-beam": case "hydro-pump": case "surf":
        case "ember": case "flamethrower": case "fire-blast": case "ice-beam": case "blizzard":
        case "thunderbolt": case "thunder": case "gust": case "air-slash": case "razor-wind":
        case "confusion": case "psybeam": case "psychic": case "shadow-ball": case "sludge-bomb":
            return false;
    }
    try {
        if (!is_undefined(scr_move_damage_class_by_id) && scr_move_damage_class_by_id(_move_id) != 2) return false;
    } catch (e_dc_contact) {}
    return true;
}

function __battle_ability_pick_best_boost_stat(_actor){
    var _best_stat = "atk";
    var _best_val = -1;
    var _stats = ["atk", "def", "spa", "spdef", "spe"];
    for (var _i = 0; _i < array_length(_stats); ++_i){
        var _st = _stats[_i];
        var _val = 0;
        try { _val = __battle_stat_get(_actor, _st); } catch (e_best_stat) { _val = 0; }
        if (is_real(_val) && _val > _best_val){
            _best_val = _val;
            _best_stat = _st;
        }
    }
    return _best_stat;
}

function __battle_ability_stage_set(_actor, _stat, _stage){
    if (!is_struct(_actor)) return false;
    var _key = "stage_" + string_lower(string(_stat));
    try {
        variable_struct_set(_actor, _key, clamp(floor(_stage), -6, 6));
        return true;
    } catch (e_stage_set) {}
    return false;
}

function __battle_ability_apply_self_stage_action(_actor, _action){
    if (!is_struct(_actor) || !is_struct(_action)) return false;
    var _data = (variable_struct_exists(_action, "data") && is_struct(variable_struct_get(_action, "data"))) ? variable_struct_get(_action, "data") : {};
    var _kind = variable_struct_exists(_action, "kind") ? string_lower(string(variable_struct_get(_action, "kind"))) : "";
    if (_kind == "self_best_stat_stage_change"){
        var _best = __battle_ability_pick_best_boost_stat(_actor);
        var _delta_best = (variable_struct_exists(_data, "delta") && is_real(variable_struct_get(_data, "delta"))) ? variable_struct_get(_data, "delta") : 1;
        if (!is_undefined(__battle_ability_change_stage) && __battle_ability_change_stage(_actor, _best, _delta_best)){
            try { __battle_queue_ability_action_dialog(_actor, { hook:"after_faint_caused", kind:"self_stage_change", data:{ stat:_best, delta:_delta_best } }, _actor, {}); } catch (e_best_dialog) {}
            return true;
        }
        return false;
    }
    if (_kind == "set_stage"){
        var _set_stat = variable_struct_exists(_data, "stat") ? variable_struct_get(_data, "stat") : "atk";
        var _stage = variable_struct_exists(_data, "stage") ? variable_struct_get(_data, "stage") : 6;
        if (__battle_ability_stage_set(_actor, _set_stat, _stage)){
            try { __battle_queue_ability_action_dialog(_actor, _action, _actor, {}); } catch (e_set_dialog) {}
            return true;
        }
        return false;
    }
    var _stat = variable_struct_exists(_data, "stat") ? variable_struct_get(_data, "stat") : "atk";
    var _delta = variable_struct_exists(_data, "delta") ? variable_struct_get(_data, "delta") : 1;
    if (!is_undefined(__battle_ability_change_stage) && __battle_ability_change_stage(_actor, _stat, _delta)){
        try { __battle_queue_ability_action_dialog(_actor, _action, _actor, {}); } catch (e_stage_dialog) {}
        return true;
    }
    return false;
}

function __battle_ability_apply_stage_changes(_actor, _changes){
    if (!is_struct(_actor) || !is_array(_changes)) return false;
    var _did = false;
    for (var _ci = 0; _ci < array_length(_changes); ++_ci){
        var _ch = _changes[_ci];
        if (!is_struct(_ch)) continue;
        var _cstat = variable_struct_exists(_ch, "stat") ? variable_struct_get(_ch, "stat") : "";
        var _cdelta = variable_struct_exists(_ch, "delta") ? variable_struct_get(_ch, "delta") : 0;
        if (is_string(_cstat) && string_length(_cstat) > 0 && is_real(_cdelta) && !is_undefined(__battle_ability_change_stage)){
            if (__battle_ability_change_stage(_actor, _cstat, _cdelta)) _did = true;
        }
    }
    return _did;
}

function __battle_apply_ability_after_damage_reactions(_pid, _target_index, _A, _D, _move_id, _before_hp, _after_hp, _actual_delta){
    if (!is_struct(_A) || !is_struct(_D) || !is_real(_actual_delta) || _actual_delta <= 0) return;
    var _contact = __battle_move_is_contactish(_move_id);
    var _attacker_index = __battle_action_actor_index(_pid, _A);
    var _defender_fainted = (_after_hp <= 0);
    var _move_type_name = "";
    try {
        var _move_type_id = (!is_undefined(scr_move_type_id_by_id)) ? scr_move_type_id_by_id(_move_id, _A) : -1;
        if (!is_undefined(__battle_type_name_by_id_safe)) _move_type_name = string_lower(string(__battle_type_name_by_id_safe(_move_type_id)));
    } catch (e_type_react) { _move_type_name = ""; }
    var _was_crit = false;
    try {
        var _Bcrit = __battle_ensure_slot(_pid);
        _was_crit = is_struct(_Bcrit) && variable_struct_exists(_Bcrit, "_last_crit") && variable_struct_get(_Bcrit, "_last_crit") == true;
    } catch (e_crit_react) { _was_crit = false; }

    try {
        var _taken_damage_rules = __battle_actor_ability_actions(_D, "damage_taken");
        for (var _tdri = 0; _tdri < array_length(_taken_damage_rules); ++_tdri){
            var _tdr = _taken_damage_rules[_tdri];
            if (!is_struct(_tdr)) continue;
            var _tdr_kind = variable_struct_exists(_tdr, "kind") ? string_lower(string(variable_struct_get(_tdr, "kind"))) : "";
            if (_tdr_kind != "conditional_damage_or_boost") continue;
            var _ab_boost = (!is_undefined(__battle_actor_ability_name_lc)) ? __battle_actor_ability_name_lc(_D) : "";
            var _did_boost = false;
            if (_move_type_name == "fire" && _ab_boost == "thermal-exchange"){
                if (!is_undefined(__battle_ability_change_stage)) _did_boost = __battle_ability_change_stage(_D, "atk", 1);
            } else if (_move_type_name == "electric" && (_ab_boost == "electromorphosis" || _ab_boost == "wind-power")){
                variable_struct_set(_D, "_ability_charge_next_electric", true);
                _did_boost = true;
            }
            if (_did_boost) try { __battle_queue_ability_action_dialog(_D, _tdr, _A, {}); } catch (e_damage_rule_dialog) {}
        }
    } catch (e_damage_taken_rules) {}

    try {
        var _taken_actions = __battle_actor_ability_actions(_D, "after_damage_taken");
        for (var _ti = 0; _ti < array_length(_taken_actions); ++_ti){
            var _taken_act = _taken_actions[_ti];
            if (!is_struct(_taken_act)) continue;
            var _taken_kind = variable_struct_exists(_taken_act, "kind") ? string_lower(string(variable_struct_get(_taken_act, "kind"))) : "";
            var _taken_data = (variable_struct_exists(_taken_act, "data") && is_struct(variable_struct_get(_taken_act, "data"))) ? variable_struct_get(_taken_act, "data") : {};
            if (_taken_kind == "force_switch_below_hp_fraction"){
                var _hp_frac = (variable_struct_exists(_taken_data, "hp_fraction") && is_real(variable_struct_get(_taken_data, "hp_fraction"))) ? variable_struct_get(_taken_data, "hp_fraction") : 0.5;
                var _max_exit = max(1, __battle_hp_max(_D));
                var _crossed_exit = (_before_hp > floor(_max_exit * _hp_frac) && _after_hp > 0 && _after_hp <= floor(_max_exit * _hp_frac));
                var _exit_used = false;
                try { _exit_used = variable_struct_exists(_D, "_ability_forced_switch_used") && variable_struct_get(_D, "_ability_forced_switch_used") == true; } catch (e_exit_used) { _exit_used = false; }
                if (_crossed_exit && !_exit_used){
                    variable_struct_set(_D, "_ability_forced_switch_used", true);
                    var _did_exit = false;
                    try {
                        var _exit_side = (!is_undefined(__battle_actor_side) && is_real(_target_index)) ? __battle_actor_side(_target_index) : -1;
                        if (_exit_side == 0 && !is_undefined(__battle_pick_random_switchable_party_index) && !is_undefined(battle_switch_to)){
                            var _next_player_exit = __battle_pick_random_switchable_party_index(_pid, _target_index);
                            if (is_real(_next_player_exit) && _next_player_exit >= 0){
                                _did_exit = battle_switch_to(_pid, _next_player_exit, { forced:true, actor_index:_target_index, consume_turn:false, auto_apply:true });
                            }
                        } else if (_exit_side == 1 && !is_undefined(__battle_trainer_next_alive_index) && !is_undefined(__battle_trainer_perform_switch_action)){
                            var _Bexit = __battle_ensure_slot(_pid);
                            var _active_enemy_idx = (is_struct(_Bexit) && variable_struct_exists(_Bexit, "_trainer_party_active_idx")) ? variable_struct_get(_Bexit, "_trainer_party_active_idx") : -1;
                            var _next_enemy_exit = __battle_trainer_next_alive_index(_Bexit, _active_enemy_idx);
                            if (is_real(_next_enemy_exit) && _next_enemy_exit >= 0){
                                __battle_trainer_perform_switch_action(_pid, _next_enemy_exit, { forced:true, actor_index:_target_index, consume_turn:false });
                                _did_exit = true;
                            }
                        }
                    } catch (e_force_exit) { _did_exit = false; }
                    if (_did_exit) try { __battle_queue_ability_action_dialog(_D, _taken_act, _D, {}); } catch (e_exit_dialog) {}
                }
            } else if (_taken_kind == "conditional_reaction"){
                var _ab_react = (!is_undefined(__battle_actor_ability_name_lc)) ? __battle_actor_ability_name_lc(_D) : "";
                var _did_react = false;
                if (_ab_react == "berserk"){
                    var _max_berserk = max(1, __battle_hp_max(_D));
                    var _before_above = (_before_hp * 2 > _max_berserk);
                    var _after_below = (_after_hp > 0 && _after_hp * 2 <= _max_berserk);
                    if (_before_above && _after_below){
                        _did_react = (!is_undefined(__battle_ability_change_stage) && __battle_ability_change_stage(_D, "spa", 1));
                    }
                } else if (_ab_react == "anger-shell"){
                    var _max_shell = max(1, __battle_hp_max(_D));
                    var _before_shell = (_before_hp * 2 > _max_shell);
                    var _after_shell = (_after_hp > 0 && _after_hp * 2 <= _max_shell);
                    if (_before_shell && _after_shell){
                        _did_react = __battle_ability_apply_stage_changes(_D, [
                            { stat:"atk", delta:1 }, { stat:"spa", delta:1 }, { stat:"spe", delta:1 },
                            { stat:"def", delta:-1 }, { stat:"spd", delta:-1 }
                        ]);
                    }
                } else if (_ab_react == "cotton-down"){
                    var _Bcot = __battle_ensure_slot(_pid);
                    if (is_struct(_Bcot) && variable_struct_exists(_Bcot, "actor") && is_array(variable_struct_get(_Bcot, "actor"))){
                        var _cactors = variable_struct_get(_Bcot, "actor");
                        for (var _coi = 0; _coi < array_length(_cactors); ++_coi){
                            var _cot_t = _cactors[_coi];
                            if (!is_struct(_cot_t) || _cot_t == _D || __battle_hp_now(_cot_t) <= 0) continue;
                            if (!is_undefined(__battle_ability_change_stage) && __battle_ability_change_stage(_cot_t, "spe", -1)) _did_react = true;
                        }
                    }
                } else if (_ab_react == "sand-spit"){
                    if (!is_undefined(__battle_set_weather)){
                        __battle_set_weather(_pid, "sandstorm", { source:_D, duration:5 });
                        _did_react = true;
                    }
                } else if (_ab_react == "gooey" || _ab_react == "tangling-hair"){
                    if (_contact && !is_undefined(__battle_ability_change_stage)) _did_react = __battle_ability_change_stage(_A, "spe", -1);
                } else if (_ab_react == "perish-body"){
                    if (_contact && !is_undefined(status_system_apply_status)){
                        try { if (status_system_apply_status(_A, "perish-song", { source:_D })) _did_react = true; } catch (e_pb_a) {}
                        try { if (status_system_apply_status(_D, "perish-song", { source:_D })) _did_react = true; } catch (e_pb_d) {}
                    }
                } else if (_ab_react == "wandering-spirit"){
                    if (_contact){
                        var _a_ability = undefined;
                        try { if (variable_struct_exists(_A, "ability")) _a_ability = variable_struct_get(_A, "ability"); } catch (e_ws_a_read) {}
                        var _d_ability = undefined;
                        try { if (variable_struct_exists(_D, "ability")) _d_ability = variable_struct_get(_D, "ability"); } catch (e_ws_d_read) {}
                        if (!is_undefined(_a_ability) && !is_undefined(_d_ability)){
                            try { variable_struct_set(_A, "ability", _d_ability); } catch (e_ws_a_set) {}
                            try { variable_struct_set(_D, "ability", _a_ability); } catch (e_ws_d_set) {}
                            try { if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))) variable_struct_set(variable_struct_get(_A, "mon"), "ability", _d_ability); } catch (e_ws_am_set) {}
                            try { if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))) variable_struct_set(variable_struct_get(_D, "mon"), "ability", _a_ability); } catch (e_ws_dm_set) {}
                            _did_react = true;
                        }
                    }
                } else if (_ab_react == "lingering-aroma"){
                    if (_contact){
                        try { variable_struct_set(_A, "ability", "lingering-aroma"); } catch (e_la_a) {}
                        try { if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))) variable_struct_set(variable_struct_get(_A, "mon"), "ability", "lingering-aroma"); } catch (e_la_m) {}
                        _did_react = true;
                    }
                }
                if (_did_react) try { __battle_queue_ability_action_dialog(_D, _taken_act, _A, {}); } catch (e_cond_dialog) {}
            } else {
                __battle_ability_apply_self_stage_action(_D, _taken_act);
            }
        }
        var _physical = false;
        try { _physical = (!is_undefined(scr_move_damage_class_by_id) && scr_move_damage_class_by_id(_move_id) == 2); } catch (e_phys_react) { _physical = false; }
        if (_physical){
            var _phys_actions = __battle_actor_ability_actions(_D, "after_physical_damage_taken");
            for (var _pi = 0; _pi < array_length(_phys_actions); ++_pi){
                var _pact = _phys_actions[_pi];
                var _pdata = (is_struct(_pact) && variable_struct_exists(_pact, "data") && is_struct(variable_struct_get(_pact, "data"))) ? variable_struct_get(_pact, "data") : {};
                if (variable_struct_exists(_pdata, "changes") && is_array(variable_struct_get(_pdata, "changes"))){
                    var _changes = variable_struct_get(_pdata, "changes");
                    var _did_any = false;
                    for (var _ci = 0; _ci < array_length(_changes); ++_ci){
                        var _ch = _changes[_ci];
                        if (!is_struct(_ch)) continue;
                        var _cstat = variable_struct_exists(_ch, "stat") ? variable_struct_get(_ch, "stat") : "def";
                        var _cdelta = variable_struct_exists(_ch, "delta") ? variable_struct_get(_ch, "delta") : 0;
                        if (!is_undefined(__battle_ability_change_stage) && __battle_ability_change_stage(_D, _cstat, _cdelta)) _did_any = true;
                    }
                    if (_did_any) try { __battle_queue_ability_header(_D); } catch (e_weak_dialog) {}
                } else {
                    __battle_ability_apply_self_stage_action(_D, _pact);
                }
            }
        }
        if (string_length(_move_type_name) > 0){
            var _type_actions = __battle_actor_ability_actions(_D, "after_type_damage_taken");
            for (var _tai = 0; _tai < array_length(_type_actions); ++_tai){
                var _tact = _type_actions[_tai];
                var _tdata = (is_struct(_tact) && variable_struct_exists(_tact, "data") && is_struct(variable_struct_get(_tact, "data"))) ? variable_struct_get(_tact, "data") : {};
                var _types = variable_struct_exists(_tdata, "types") ? variable_struct_get(_tdata, "types") : [];
                if (!is_array(_types)) _types = [string(_types)];
                var _matches_type = false;
                for (var _tyi = 0; _tyi < array_length(_types); ++_tyi){
                    if (string_lower(string(_types[_tyi])) == _move_type_name){ _matches_type = true; break; }
                }
                if (_matches_type) __battle_ability_apply_self_stage_action(_D, _tact);
            }
        }
        if (_was_crit){
            var _crit_actions = __battle_actor_ability_actions(_D, "after_critical_damage_taken");
            for (var _cai = 0; _cai < array_length(_crit_actions); ++_cai) __battle_ability_apply_self_stage_action(_D, _crit_actions[_cai]);
        }
    } catch (e_taken_reactions) {}

    try {
        var _after_damage_actions = __battle_actor_ability_actions(_A, "after_damage");
        for (var _adi = 0; _adi < array_length(_after_damage_actions); ++_adi){
            var _adact = _after_damage_actions[_adi];
            if (!is_struct(_adact)) continue;
            var _adkind = variable_struct_exists(_adact, "kind") ? string_lower(string(variable_struct_get(_adact, "kind"))) : "";
            var _addata = (variable_struct_exists(_adact, "data") && is_struct(variable_struct_get(_adact, "data"))) ? variable_struct_get(_adact, "data") : {};
            if (_adkind == "flinch_bonus"){
                var _flinch_chance = (variable_struct_exists(_addata, "chance") && is_real(variable_struct_get(_addata, "chance"))) ? variable_struct_get(_addata, "chance") : 10;
                if (irandom(99) < _flinch_chance){
                    try { variable_struct_set(_D, "_flinched", true); } catch (e_flinch_d) {}
                    try { if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))) variable_struct_set(variable_struct_get(_D, "mon"), "_flinched", true); } catch (e_flinch_m) {}
                    try { __battle_queue_ability_action_dialog(_A, _adact, _D, {}); } catch (e_flinch_dialog) {}
                }
            } else if (_adkind == "second_parental_hit"){
                var _parental_used = false;
                try { _parental_used = variable_struct_exists(_A, "_parental_bond_second_hit_active") && variable_struct_get(_A, "_parental_bond_second_hit_active") == true; } catch (e_parental_read) { _parental_used = false; }
                if (!_parental_used && !_defender_fainted && is_real(_move_id) && _move_id >= 0 && is_real(_target_index)){
                    var _second_mult = (variable_struct_exists(_addata, "second_hit_mult") && is_real(variable_struct_get(_addata, "second_hit_mult"))) ? variable_struct_get(_addata, "second_hit_mult") : 0.25;
                    variable_struct_set(_A, "_parental_bond_second_hit_active", true);
                    var _second_dmg = max(1, floor(max(1, _actual_delta) * _second_mult));
                    try { __battle_queue_ability_action_dialog(_A, _adact, _D, {}); } catch (e_parental_dialog) {}
                    try { __battle_apply_damage(_pid, _target_index, _second_dmg, 1.0); } catch (e_parental_apply) {}
                    variable_struct_set(_A, "_parental_bond_second_hit_active", false);
                }
            }
        }
    } catch (e_after_damage_actions) {}

    if (_contact){
        try {
            var _contact_dealt_actions = __battle_actor_ability_actions(_A, "after_contact_dealt");
            for (var _cdi = 0; _cdi < array_length(_contact_dealt_actions); ++_cdi){
                var _cdact = _contact_dealt_actions[_cdi];
                if (!is_struct(_cdact)) continue;
                var _cdkind = variable_struct_exists(_cdact, "kind") ? string_lower(string(variable_struct_get(_cdact, "kind"))) : "";
                var _cddata = (variable_struct_exists(_cdact, "data") && is_struct(variable_struct_get(_cdact, "data"))) ? variable_struct_get(_cdact, "data") : {};
                if (_cdkind == "status_target_chance"){
                    var _cdchance = (variable_struct_exists(_cddata, "chance") && is_real(variable_struct_get(_cddata, "chance"))) ? variable_struct_get(_cddata, "chance") : 30;
                    if (irandom(99) < _cdchance && !is_undefined(status_system_apply_status)){
                        var _cdstatus = variable_struct_exists(_cddata, "status") ? string_lower(string(variable_struct_get(_cddata, "status"))) : "poison";
                        try {
                            if (status_system_apply_status(_D, _cdstatus, { source:_A })){
                                __battle_queue_ability_action_dialog(_A, _cdact, _D, {});
                            }
                        } catch (e_contact_dealt_status) {}
                    }
                }
            }
            var _contact_actions = __battle_actor_ability_actions(_D, "after_contact_taken");
            for (var _ai = 0; _ai < array_length(_contact_actions); ++_ai){
                var _act = _contact_actions[_ai];
                if (!is_struct(_act)) continue;
                var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
                var _data = (variable_struct_exists(_act, "data") && is_struct(variable_struct_get(_act, "data"))) ? variable_struct_get(_act, "data") : {};
                if (_kind == "damage_attacker_fraction" && is_real(_attacker_index)){
                    var _frac = (variable_struct_exists(_data, "fraction") && is_real(variable_struct_get(_data, "fraction"))) ? variable_struct_get(_data, "fraction") : 0.125;
                    var _rdmg = max(1, floor(__battle_hp_max(_A) * _frac));
                    try { __battle_queue_ability_action_dialog(_D, _act, _A, {}); } catch (e_contact_dmg_dialog) {}
                    __battle_apply_damage(_pid, _attacker_index, _rdmg, 1.0);
                } else if (_kind == "status_attacker_chance"){
                    var _chance = (variable_struct_exists(_data, "chance") && is_real(variable_struct_get(_data, "chance"))) ? variable_struct_get(_data, "chance") : 30;
                    if (irandom(99) < _chance && !is_undefined(status_system_apply_status)){
                        var _st = variable_struct_exists(_data, "status") ? string_lower(string(variable_struct_get(_data, "status"))) : "paralysis";
                        try {
                            if (status_system_apply_status(_A, _st, { source:_D })){
                                __battle_queue_ability_action_dialog(_D, _act, _A, {});
                            }
                        } catch (e_contact_status) {}
                    }
                } else if (_kind == "random_status_attacker_chance"){
                    var _rchance = (variable_struct_exists(_data, "chance") && is_real(variable_struct_get(_data, "chance"))) ? variable_struct_get(_data, "chance") : 30;
                    if (irandom(99) < _rchance && !is_undefined(status_system_apply_status)){
                        var _sts = variable_struct_exists(_data, "statuses") ? variable_struct_get(_data, "statuses") : ["poison","paralysis","sleep"];
                        if (!is_array(_sts)) _sts = [string(_sts)];
                        var _pick = string_lower(string(_sts[irandom(array_length(_sts) - 1)]));
                        try {
                            if (status_system_apply_status(_A, _pick, { source:_D })){
                                __battle_queue_ability_action_dialog(_D, { hook:"after_contact_taken", kind:"status_attacker_chance", data:{ status:_pick } }, _A, {});
                            }
                        } catch (e_random_status) {}
                    }
                } else if (_kind == "volatile_attacker_chance"){
                    var _vchance = (variable_struct_exists(_data, "chance") && is_real(variable_struct_get(_data, "chance"))) ? variable_struct_get(_data, "chance") : 30;
                    if (irandom(99) < _vchance && !is_undefined(status_system_apply_status)){
                        var _vol = variable_struct_exists(_data, "volatile") ? string_lower(string(variable_struct_get(_data, "volatile"))) : "infatuation";
                        try {
                            if (status_system_apply_status(_A, _vol, { source:_D })){
                                __battle_queue_ability_action_dialog(_D, _act, _A, {});
                            }
                        } catch (e_volatile_status) {}
                    }
                } else if (_kind == "replace_attacker_ability"){
                    var _new_ability = variable_struct_exists(_data, "ability") ? string(variable_struct_get(_data, "ability")) : "mummy";
                    try { variable_struct_set(_A, "ability", _new_ability); } catch (e_mummy_a) {}
                    try { if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))) variable_struct_set(variable_struct_get(_A, "mon"), "ability", _new_ability); } catch (e_mummy_m) {}
                    try { __battle_queue_ability_action_dialog(_D, _act, _A, {}); } catch (e_mummy_dialog) {}
                }
            }
            if (_defender_fainted && is_real(_attacker_index)){
                var _faint_contact_actions = __battle_actor_ability_actions(_D, "on_faint_from_contact");
                for (var _fi = 0; _fi < array_length(_faint_contact_actions); ++_fi){
                    var _fact = _faint_contact_actions[_fi];
                    if (!is_struct(_fact)) continue;
                    var _fkind = variable_struct_exists(_fact, "kind") ? string_lower(string(variable_struct_get(_fact, "kind"))) : "";
                    if (_fkind != "damage_attacker_fraction") continue;
                    var _fdata = (variable_struct_exists(_fact, "data") && is_struct(variable_struct_get(_fact, "data"))) ? variable_struct_get(_fact, "data") : {};
                    var _ffrac = (variable_struct_exists(_fdata, "fraction") && is_real(variable_struct_get(_fdata, "fraction"))) ? variable_struct_get(_fdata, "fraction") : 0.25;
                    var _fdmg = max(1, floor(__battle_hp_max(_A) * _ffrac));
                    try { __battle_queue_ability_action_dialog(_D, _fact, _A, {}); } catch (e_aftermath_dialog) {}
                    __battle_apply_damage(_pid, _attacker_index, _fdmg, 1.0);
                }
            }
        } catch (e_contact_reactions) {}
    }

    if (_defender_fainted){
        try {
            var _ko_actions = __battle_actor_ability_actions(_A, "after_faint_caused");
            for (var _ki = 0; _ki < array_length(_ko_actions); ++_ki) __battle_ability_apply_self_stage_action(_A, _ko_actions[_ki]);
            var _def_faint_actions = __battle_actor_ability_actions(_D, "on_faint");
            for (var _dfi = 0; _dfi < array_length(_def_faint_actions); ++_dfi){
                var _dfact = _def_faint_actions[_dfi];
                if (!is_struct(_dfact)) continue;
                var _dfkind = variable_struct_exists(_dfact, "kind") ? string_lower(string(variable_struct_get(_dfact, "kind"))) : "";
                if (_dfkind == "damage_attacker_equal_last_damage" && is_real(_attacker_index) && _actual_delta > 0){
                    try { __battle_queue_ability_action_dialog(_D, _dfact, _A, {}); } catch (e_innards_dialog) {}
                    __battle_apply_damage(_pid, _attacker_index, max(1, floor(_actual_delta)), 1.0);
                } else if (_dfkind == "explode_on_faint"){
                    var _Bboom = __battle_ensure_slot(_pid);
                    if (is_struct(_Bboom) && variable_struct_exists(_Bboom, "actor") && is_array(variable_struct_get(_Bboom, "actor"))){
                        var _boom_actors = variable_struct_get(_Bboom, "actor");
                        try { __battle_queue_ability_action_dialog(_D, _dfact, _A, {}); } catch (e_boom_dialog) {}
                        for (var _boi = 0; _boi < array_length(_boom_actors); ++_boi){
                            var _boom_t = _boom_actors[_boi];
                            if (!is_struct(_boom_t) || _boom_t == _D || __battle_hp_now(_boom_t) <= 0) continue;
                            var _boom_dmg = max(1, floor(__battle_hp_max(_boom_t) * 0.25));
                            __battle_apply_damage(_pid, _boi, _boom_dmg, 1.0);
                        }
                    }
                }
            }
            var _Bfaint = __battle_ensure_slot(_pid);
            if (is_struct(_Bfaint) && variable_struct_exists(_Bfaint, "actor") && is_array(variable_struct_get(_Bfaint, "actor"))){
                var _actors = variable_struct_get(_Bfaint, "actor");
                for (var _si = 0; _si < array_length(_actors); ++_si){
                    var _soul_actor = _actors[_si];
                    if (!is_struct(_soul_actor) || __battle_hp_now(_soul_actor) <= 0) continue;
                    var _any_faint_actions = __battle_actor_ability_actions(_soul_actor, "after_any_faint");
                    for (var _afi = 0; _afi < array_length(_any_faint_actions); ++_afi) __battle_ability_apply_self_stage_action(_soul_actor, _any_faint_actions[_afi]);
                }
            }
        } catch (e_ko_reactions) {}
    }
}

// Applies damage and returns [dmg, beforeHP, afterHP]
function __battle_apply_move_damage(_pid, _target_index, _A, _D, _move_id, _mv_power){
    // Ensure we have a valid battle slot reference before performing slot-dependent work.
    var _pid_local = _pid;
    if (!is_real(_pid_local)) _pid_local = __battle_guess_pid_for_entities(_A, _D);
    if (!is_real(_pid_local)){
        if (variable_global_exists("sys_battles") && is_array(global.sys_battles) && array_length(global.sys_battles) > 0){
            _pid_local = 0;
        } else {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                show_debug_message("[guard][apply_move_damage] no battle slot resolved for move_id=" + string(_move_id));
            }
            return [0, __battle_hp_now(_D), __battle_hp_now(_D)];
        }
    }
    _pid = _pid_local;

    try {
        var _Bmiss_reset = __battle_ensure_slot(_pid);
        if (is_struct(_Bmiss_reset)) variable_struct_set(_Bmiss_reset, "_last_damage_move_missed", false);
    } catch (e_miss_reset) {}

    try {
        if (!is_undefined(__battle_ability_move_target_blocked) && __battle_ability_move_target_blocked(_A, _D, _move_id)){
            var _Bblocked = __battle_ensure_slot(_pid);
            if (is_struct(_Bblocked)) variable_struct_set(_Bblocked, "_last_damage_move_missed", true);
            return [0, __battle_hp_now(_D), __battle_hp_now(_D)];
        }
    } catch (e_ability_target_block) {}

    var _move_rec = undefined;
    var _eid = undefined;
    var _move_behavior = undefined;
    try {
        if (!is_undefined(__battle_move_behavior_full) && is_real(_move_id)){
            _move_behavior = __battle_move_behavior_full(_move_id);
            if (is_struct(_move_behavior) && variable_struct_exists(_move_behavior, "effect_id") && is_real(variable_struct_get(_move_behavior, "effect_id"))){
                _eid = floor(variable_struct_get(_move_behavior, "effect_id"));
            }
        }
    } catch (e_behavior_lookup) { _move_behavior = undefined; }
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){
            _move_rec = global._moves[_move_id];
        }
    } catch (e_move_rec_lookup) { _move_rec = undefined; }
    if (!is_real(_eid)){
        try {
            if (!is_undefined(__battle_move_effect_id_safe)) _eid = __battle_move_effect_id_safe(_move_id);
        } catch (e_eid) { _eid = _eid; }
    }

    var _is_dynamax_cannon = (is_struct(_move_behavior) && variable_struct_exists(_move_behavior, "damage_double_if_target_dynamax") && variable_struct_get(_move_behavior, "damage_double_if_target_dynamax") == true) || (is_real(_eid) && floor(_eid) == 421);
    var _is_snipe_shot = (is_struct(_move_behavior) && variable_struct_exists(_move_behavior, "bypass_target_guard") && variable_struct_get(_move_behavior, "bypass_target_guard") == true) || (is_real(_eid) && floor(_eid) == 422);
    var _snipe_bypassed_guard = false;
    if (_is_snipe_shot && is_struct(_D)){
        var guard_fields = ["_protected", "_quick_guard", "_wide_guard", "_mat_block"];
        for (var _gf = 0; _gf < array_length(guard_fields); ++_gf){
            var gkey = guard_fields[_gf];
            if (variable_struct_exists(_D, gkey) && variable_struct_get(_D, gkey) == true){
                try { variable_struct_set(_D, gkey, false); } catch (e_gf) {}
                _snipe_bypassed_guard = true;
            }
        }
    }

    // Semi-invulnerable guard: prevent damage unless the attacking move is one of the
    // explicit counters (e.g., Gust vs Fly, Earthquake vs Dig). When the counter move
    // connects, it should deal amplified damage just like the mainline games.
    var _semi_mult = 1.0;
    try {
        if (is_struct(_D) && variable_struct_exists(_D, "_semi_invuln") && !is_undefined(variable_struct_get(_D, "_semi_invuln"))){
            var _phase_raw = variable_struct_get(_D, "_semi_invuln");
            var _phase = string_lower(string(_phase_raw));
            var _move_name_lower = "";
            if (is_real(_move_id)){
                try {
                    if (!is_undefined(scr_move_name_by_id)) _move_name_lower = string_lower(string(scr_move_name_by_id(_move_id)));
                } catch (e_mn) { _move_name_lower = ""; }
                if (string_length(_move_name_lower) <= 0){
                    try {
                        if (variable_global_exists("_moves") && is_array(global._moves) && _move_id >= 0 && _move_id < array_length(global._moves)){
                            var _mref = global._moves[_move_id];
                            if (is_struct(_mref) && variable_struct_exists(_mref, "identifier")){
                                _move_name_lower = string_lower(string(variable_struct_get(_mref, "identifier")));
                            }
                        }
                    } catch (e_mid) { _move_name_lower = ""; }
                }
            }
            var _target_name = __battle_dialog_actor_name(_D, "The target");
            var _attacker_name = __battle_dialog_actor_name(_A, "The attacker");
            var _state_msg = "";
            var _allow_hit = false;

            if (_phase == "fly" || _phase == "bounce" || _phase == "skydrop"){
                if (string_pos("gust", _move_name_lower) > 0 || string_pos("twister", _move_name_lower) > 0 || string_pos("sky uppercut", _move_name_lower) > 0 || string_pos("sky-uppercut", _move_name_lower) > 0){
                    _allow_hit = true;
                    _semi_mult = 2.0;
                }
                _state_msg = _target_name + " is high in the sky!";
            } else if (_phase == "dig"){
                if (string_pos("earthquake", _move_name_lower) > 0 || string_pos("magnitude", _move_name_lower) > 0){
                    _allow_hit = true;
                    _semi_mult = 2.0;
                }
                _state_msg = _target_name + " is underground!";
            } else if (_phase == "dive"){
                if (string_pos("surf", _move_name_lower) > 0 || string_pos("whirlpool", _move_name_lower) > 0){
                    _allow_hit = true;
                    _semi_mult = 2.0;
                }
                _state_msg = _target_name + " is deep underwater!";
            } else if (_phase == "vanish"){
                _allow_hit = false;
                _state_msg = _target_name + " vanished instantly!";
            }

            if (!_allow_hit){
                if (string_length(_state_msg) > 0){
                    if (!is_undefined(dialog_queue)) dialog_queue(_state_msg);
                    else if (!is_undefined(dialog2p_show_now)) try { dialog2p_show_now(_pid, _state_msg); } catch (e_msg1) {}
                }
                var _miss_msg = _attacker_name + "'s attack missed!";
                if (!is_undefined(dialog_queue)) dialog_queue(_miss_msg);
                else if (!is_undefined(dialog2p_show_now)) try { dialog2p_show_now(_pid, _miss_msg); } catch (e_msg2) {}
                try {
                    var _Bsemi_flag = __battle_ensure_slot(_pid);
                    if (is_struct(_Bsemi_flag)){
                        variable_struct_set(_Bsemi_flag, "__semi_guard_blocked", true);
                        variable_struct_set(_Bsemi_flag, "_last_damage_move_missed", true);
                    }
                } catch (e_flag) {}
                var _hp_guard = __battle_hp_now(_D);
                return [0, _hp_guard, _hp_guard];
            }
        }
    } catch (e_semi_guard){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][semi] guard apply_damage failed: " + string(e_semi_guard)); }

    // Normal accuracy gate for moves that don't use custom accuracy semantics below.
    try {
        if (is_real(_move_id) && _move_id != 217){
            if (!__battle_can_hit_target(_A, _D, _move_id)){
                var _miss_name = __battle_dialog_actor_name(_A, "The attacker");
                dialog_queue(_miss_name + "'s attack missed!");
                try {
                    var _Bmiss_flag = __battle_ensure_slot(_pid);
                    if (is_struct(_Bmiss_flag)) variable_struct_set(_Bmiss_flag, "_last_damage_move_missed", true);
                } catch (e_miss_flag) {}
                var _hp_now_miss = __battle_hp_now(_D);
                return [0, _hp_now_miss, _hp_now_miss];
            }
        }
    } catch (e_acc_gate) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][accuracy] gate failed: " + string(e_acc_gate)); }

    try {
        if (!is_undefined(__battle_apply_ability_heal_or_block) && __battle_apply_ability_heal_or_block(_pid, _target_index, _A, _D, _move_id)){
            var _hp_ability_block = __battle_hp_now(_D);
            return [0, _hp_ability_block, _hp_ability_block];
        }
    } catch (e_ability_block) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ability] immunity gate failed: " + string(e_ability_block)); }

    // Present: after accuracy resolves, either heal the target or deal random damage.
    try {
        if (is_real(_move_id) && _move_id == 217){
            if (!__battle_can_hit_target(_A, _D, _move_id)){
                var _present_miss_name = __battle_dialog_actor_name(_A, "The attacker");
                dialog_queue(_present_miss_name + "'s attack missed!");
                try {
                    var _Bpresent_miss = __battle_ensure_slot(_pid);
                    if (is_struct(_Bpresent_miss)) variable_struct_set(_Bpresent_miss, "_last_damage_move_missed", true);
                } catch (e_present_miss_flag) {}
                var _hp_now_present_miss = __battle_hp_now(_D);
                return [0, _hp_now_present_miss, _hp_now_present_miss];
            }
            var _present_roll = irandom(3);
            if (_present_roll == 0){
                var _before_present = __battle_hp_now(_D);
                var _max_present = max(1, __battle_hp_max(_D));
                var _heal_present = max(1, floor(_max_present / 4));
                __battle_set_hp_now(_D, min(_max_present, _before_present + _heal_present));
                __battle_clear_fainted_if_healed(_D);
                try { __battle_request_animation_safe(_A, { type: "heal", actor: _A, target: _D, amount: _heal_present }); } catch (e_present_anim) {}
                dialog_queue(__battle_dialog_actor_name(_D, "The target") + " had its HP restored!");
                var _after_present = __battle_hp_now(_D);
                return [0, _before_present, _after_present];
            }
            switch (_present_roll){
                case 1: _mv_power = 40; break;
                case 2: _mv_power = 80; break;
                default: _mv_power = 120; break;
            }
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][present] damage roll=" + string(_present_roll) + " power=" + string(_mv_power));
        }
    } catch (e_present) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][present] handler failed: " + string(e_present)); }

    // Check for OHKO (one-hit KO) move meta first. This implements Sheer Cold / Fissure / Guillotine/Horn Drill style behavior.
    try {
        var oh = _move_behavior;
        if (!is_struct(oh) && !is_undefined(__battle_move_behavior_full) && is_real(_move_id)){
            try { oh = __battle_move_behavior_full(_move_id); } catch (e_gm) { oh = undefined; }
        }
        if (is_struct(oh) && variable_struct_exists(oh, "ohko") && variable_struct_get(oh, "ohko") == true){
            // OHKO move: accuracy is 30 + (user.level - target.level). If user.level < target.level the move fails.
            var ulevel = (is_struct(_A) && variable_struct_exists(_A, "level") && is_real(variable_struct_get(_A, "level"))) ? floor(variable_struct_get(_A, "level")) : 0;
            var tlevel = (is_struct(_D) && variable_struct_exists(_D, "level") && is_real(variable_struct_get(_D, "level"))) ? floor(variable_struct_get(_D, "level")) : 0;
            var acc_base = 30;
            var acc = acc_base + max(0, ulevel - tlevel);
            if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][ohko] attempt move_id=" + string(_move_id) + ", ulevel=" + string(ulevel) + ", tlevel=" + string(tlevel) + ", acc=" + string(acc));
            // If user is lower level, OHKO fails.
            var _Bslot_oh = __battle_ensure_slot(_pid);
            // If user level < target level, OHKO fails
            if (ulevel < tlevel){
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ohko] failed: user level < target level (" + string(ulevel) + " < " + string(tlevel) + ")");
                try { if (is_struct(_Bslot_oh)) variable_struct_set(_Bslot_oh, "_last_ohko_miss", true); } catch (e_ohf) {}
                // Visible single-line OHKO tag for noisy logs
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[OHKO] OHKO failed (level) pid=" + string(_pid) + " move=" + string(_move_id) + " attacker_lvl=" + string(ulevel) + " target_lvl=" + string(tlevel));
                return [0, __battle_hp_now(_D), __battle_hp_now(_D)];
            }
            // Roll against computed accuracy
            var roll = irandom(99);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ohko] acc=" + string(acc) + ", roll=" + string(roll));
            if (roll < clamp(floor(acc), 0, 100)){
                // Success: deal damage equal to target's max HP (attempt to read hp_max/maxhp)
                var target_max = 1;
                try { if (variable_struct_exists(_D, "hp_max")) target_max = variable_struct_get(_D, "hp_max"); else if (variable_struct_exists(_D, "maxhp")) target_max = variable_struct_get(_D, "maxhp"); else if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon")) && variable_struct_exists(variable_struct_get(_D, "mon"), "hp_max")) target_max = variable_struct_get(variable_struct_get(_D, "mon"), "hp_max"); } catch (e_mx) { target_max = 1; }
                target_max = max(1, floor(target_max));
                // Apply damage via canonical path so Protect/lerp/etc. run
                __battle_apply_damage(_pid, _target_index, target_max, 1.0);
                var after = __battle_hp_now(_D);
                return [target_max, max(0, __battle_hp_now(_D) + target_max - target_max), after];
            } else {
                // Miss
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ohko] missed (acc roll)");
                try { if (is_struct(_Bslot_oh)) variable_struct_set(_Bslot_oh, "_last_ohko_miss", true); } catch (e_ohm) {}
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[OHKO] OHKO missed (acc roll) pid=" + string(_pid) + " move=" + string(_move_id) + " roll=" + string(roll) + " need<" + string(acc));
                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][ohko] marked _last_ohko_miss due to acc roll for pid=" + string(_pid) + ", roll=" + string(roll) + ", needed<" + string(acc));
                return [0, __battle_hp_now(_D), __battle_hp_now(_D)];
            }
        }
    } catch (e_oh) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ohko] handler error: " + string(e_oh)); }

    // [central-behavior] Sleep-gated damaging moves such as Dream Eater.
    try {
        var _behavior_gate = _move_behavior;
        if (!is_struct(_behavior_gate) && !is_undefined(__battle_move_behavior_full)){
            _behavior_gate = __battle_move_behavior_full(_move_id);
        }
        if (is_struct(_behavior_gate)){
            var _req_status = (variable_struct_exists(_behavior_gate, "requires_target_status") ? string(variable_struct_get(_behavior_gate, "requires_target_status")) : "");
            var _fail_missing = (variable_struct_exists(_behavior_gate, "fail_if_target_status_missing") && variable_struct_get(_behavior_gate, "fail_if_target_status_missing") == true);
            if (_fail_missing && string_length(_req_status) > 0){
                var _has_req_status = false;
                try {
                    if (!is_undefined(__battle_move_behavior_actor_has_status)){
                        _has_req_status = __battle_move_behavior_actor_has_status(_D, _req_status);
                    }
                } catch (e_req_status_check) { _has_req_status = false; }
                if (!_has_req_status){
                    try { dialog_queue("But it failed!"); } catch (e_req_dialog) {}
                    var _hp_req_now = __battle_hp_now(_D);
                    return [0, _hp_req_now, _hp_req_now];
                }
            }
        }
    } catch (e_central_gate) {}

    var dmg = __battle_calc_damage(_A, _D, _move_id, _mv_power);
    try {
        if (is_struct(_A) && variable_struct_exists(_A, "_battle_z_power_move_id") && is_real(variable_struct_get(_A, "_battle_z_power_move_id")) && floor(variable_struct_get(_A, "_battle_z_power_move_id")) == floor(_move_id)){
            dmg = max(1, floor(dmg * 1.8));
            variable_struct_set(_A, "_battle_z_power_move_id", -1);
            try { dialog_queue(__battle_dialog_actor_name(_A, "The Pokemon") + " unleashed its full-force Z-Move!"); } catch (e_z_dialog) {}
        }
        if (is_struct(_A) && variable_struct_exists(_A, "_battle_dynamax") && variable_struct_get(_A, "_battle_dynamax") == true){
            dmg = max(1, floor(dmg * 1.5));
        }
    } catch (e_transform_damage) {}
    var before = __battle_hp_now(_D);
    // Temporary debug: print attacker/defender and indices to trace mis-targeting
    try {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            var aname_dbg = (is_struct(_A) && variable_struct_exists(_A, "name")) ? variable_struct_get(_A, "name") : (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && variable_struct_exists(variable_struct_get(_A, "mon"), "name") ? variable_struct_get(variable_struct_get(_A, "mon"), "name") : "<attacker?>");
            var dname_dbg = (is_struct(_D) && variable_struct_exists(_D, "name")) ? variable_struct_get(_D, "name") : (is_struct(_D) && variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon")) && variable_struct_exists(variable_struct_get(_D, "mon"), "name") ? variable_struct_get(variable_struct_get(_D, "mon"), "name") : "<defender?>");
            var a_idx_dbg = (is_struct(_A) && variable_struct_exists(_A, "actor_index") ? string(variable_struct_get(_A, "actor_index")) : (variable_struct_exists(_A, "slot") ? string(variable_struct_get(_A, "slot")) : "?"));
            var d_idx_dbg = (!is_undefined(__battle_actor_index_of) ? string(__battle_actor_index_of(_D)) : (is_struct(_D) && variable_struct_exists(_D, "actor_index") ? string(variable_struct_get(_D, "actor_index")) : (variable_struct_exists(_D, "slot") ? string(variable_struct_get(_D, "slot")) : "?")));
            show_debug_message("[dbg][apply_move_damage] pid=" + string(_pid) + ", target_idx_param=" + string(_target_index) + ", move=" + string(_move_id) + ", mv_power=" + string(_mv_power) + ", attacker=[" + string(aname_dbg) + ", idx=" + string(a_idx_dbg) + "], defender=[" + string(dname_dbg) + ", idx=" + string(d_idx_dbg) + "], computed_dmg=" + string(dmg) + ", defender_beforeHP=" + string(before));
        }
    } catch (e_dbgd) { }

    // Compute type-effectiveness multiplier (best-effort) so we can pick a hit sound
    var mult = 1.0;
    try {
        var atk_type = -1;
        if (!is_undefined(scr_move_type_id_by_id)) atk_type = scr_move_type_id_by_id(_move_id, _A);
        if (is_real(atk_type) && atk_type >= 0 && variable_global_exists("BATTLE_TYPE_EFFICACY")){
            var _tmp_bte = variable_global_get("BATTLE_TYPE_EFFICACY");
            var _miracle_eye_psychic = false;
            try {
                var _psy_id = 14;
                var _dark_id = 17;
                if (variable_global_exists("TYPE_ID_BY_NAME")){
                    var _miracle_type_map = variable_global_get("TYPE_ID_BY_NAME");
                    if (ds_exists(_miracle_type_map, ds_type_map)){
                        if (ds_map_exists(_miracle_type_map, "psychic")) _psy_id = ds_map_find_value(_miracle_type_map, "psychic");
                        if (ds_map_exists(_miracle_type_map, "dark")) _dark_id = ds_map_find_value(_miracle_type_map, "dark");
                    }
                }
                _miracle_eye_psychic = (atk_type == _psy_id) && is_struct(_D) && variable_struct_exists(_D, "_miracle_eye_active") && variable_struct_get(_D, "_miracle_eye_active") == true;
            } catch (e_miracle_type) { _miracle_eye_psychic = false; }
            var dt = [];
            // Collect defender type ids from wrapper or inner mon
            if (variable_struct_exists(_D, "types") && is_array(variable_struct_get(_D, "types"))) for (var _ti=0; _ti<array_length(variable_struct_get(_D, "types")); ++_ti) array_push(dt, variable_struct_get(_D, "types")[_ti]);
            if (variable_struct_exists(_D, "type1") && is_real(variable_struct_get(_D, "type1"))) array_push(dt, variable_struct_get(_D, "type1"));
            if (variable_struct_exists(_D, "type2") && is_real(variable_struct_get(_D, "type2"))) array_push(dt, variable_struct_get(_D, "type2"));
            if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))){
                var _mi = variable_struct_get(_D, "mon");
                if (variable_struct_exists(_mi, "types") && is_array(variable_struct_get(_mi, "types"))) for (var _ti2=0; _ti2<array_length(variable_struct_get(_mi, "types")); ++_ti2) array_push(dt, variable_struct_get(_mi, "types")[_ti2]);
                if (variable_struct_exists(_mi, "type1") && is_real(variable_struct_get(_mi, "type1"))) array_push(dt, variable_struct_get(_mi, "type1"));
                if (variable_struct_exists(_mi, "type2") && is_real(variable_struct_get(_mi, "type2"))) array_push(dt, variable_struct_get(_mi, "type2"));
                // species-level fallback via global._species_types
                if (variable_struct_exists(_mi, "species_id") && variable_global_exists("_species_types")){
                    var sid2 = variable_struct_get(_mi, "species_id");
                    if (is_real(sid2) && sid2 >= 0 && sid2 < array_length(global._species_types)){
                        var st2 = global._species_types[sid2]; if (is_array(st2)) for (var _zz=0; _zz<array_length(st2); ++_zz) array_push(dt, st2[_zz]);
                    }
                }
            }
            var prod = 1.0;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                show_debug_message("[battle][eff_debug] atk_type=" + string(atk_type) + ", defender_types=" + string(dt) + ", map_exists=" + string(!is_undefined(_tmp_bte)) );
            }
            for (var _k=0; _k<array_length(dt); ++_k){
                var def_t = dt[_k];
                if (!is_real(def_t)) continue;
                var key = string(atk_type) + ":" + string(def_t);
                if (ds_map_exists(_tmp_bte, key)){
                    var mval = ds_map_find_value(_tmp_bte, key);
                    if (is_real(mval)){
                        if (_miracle_eye_psychic){
                            var _dark_id_apply = 17;
                            try {
                                if (variable_global_exists("TYPE_ID_BY_NAME")){
                                    var _dark_map_apply = variable_global_get("TYPE_ID_BY_NAME");
                                    if (ds_exists(_dark_map_apply, ds_type_map) && ds_map_exists(_dark_map_apply, "dark")) _dark_id_apply = ds_map_find_value(_dark_map_apply, "dark");
                                }
                            } catch (e_dark_lookup_apply) { _dark_id_apply = 17; }
                            if (def_t == _dark_id_apply && mval <= 0) mval = 1.0;
                        }
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][eff_debug] found key=" + string(key) + ", mval=" + string(mval));
                        prod *= mval;
                    }
                } else {
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][eff_debug] missing key=" + string(key));
                }
            }
            mult = prod;
        }
    } catch (e_mult) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] type mult calc failed: " + string(e_mult)); }

    try {
        if (is_real(dmg) && dmg > 0 && !is_undefined(__battle_actor_has_any_ability) && __battle_actor_has_any_ability(_D, ["wonder-guard"]) && is_real(mult) && mult <= 1.0){
            var _wg_name = __battle_dialog_actor_name(_D, "The target");
            dialog_queue(_wg_name + "'s Wonder Guard protected it!");
            return [0, before, before];
        }
    } catch (e_wonder_guard) {}

    // Special-case move semantics that alter computed damage before application
    // [central-behavior] Phase 2 pre-special damage overrides.
    try {
        if (!is_undefined(__battle_move_behavior_fixed_damage)){
            var _central_fixed_damage = __battle_move_behavior_fixed_damage(_move_id, _A, _D);
            if (is_real(_central_fixed_damage)){
                dmg = max(0, floor(_central_fixed_damage));
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                    show_debug_message("[battle][central_behavior] fixed/level/half damage applied move=" + string(_move_id) + ", dmg=" + string(dmg));
                }
            }
        }
    } catch (e_central_fixed_damage) {}

    try {
        // Apply move-specific multipliers prior to special fixed-damage overrides
        if (_is_dynamax_cannon){
            var _target_is_dmax = false;
            try {
                if (!is_undefined(__battle_actor_is_dynamax)) _target_is_dmax = __battle_actor_is_dynamax(_D);
            } catch (e_dmx) { _target_is_dmax = false; }
            if (_target_is_dmax && is_real(dmg) && dmg > 0){
                dmg = max(0, round(dmg * 2));
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Dynamax Cannon 2x damage applied");
            }
        }

        if (is_undefined(__battle_move_behavior_fixed_damage)){
            // Legacy fallback for fixed-damage moves if the central resolver is unavailable.
            if (is_real(_move_id) && _move_id == 49){
                var sb_flat = 20;
                dmg = sb_flat;
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Sonic Boom applied flat dmg=" + string(dmg));
            }
            if (is_real(_move_id) && _move_id == 82){
                dmg = 40;
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Dragon Rage flat dmg=40");
            }
            if (is_real(_move_id) && (_move_id == 162 || _move_id == 717)){
                var curhp_sf = __battle_hp_now(_D);
                var sf_dmg = max(0, floor(curhp_sf / 2));
                dmg = sf_dmg;
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Super Fang computed dmg=" + string(dmg) + ", target_hp=" + string(curhp_sf));
            }
        }

        // Bide releases double the damage stored while the user was biding.
        if (is_real(_move_id) && _move_id == 117 && is_struct(_A)){
            var _bide_release = 0;
            try {
                if (variable_struct_exists(_A, "_bide_state") && is_struct(variable_struct_get(_A, "_bide_state"))){
                    var _bide_state_dmg = variable_struct_get(_A, "_bide_state");
                    if (variable_struct_exists(_bide_state_dmg, "damage") && is_real(variable_struct_get(_bide_state_dmg, "damage"))) _bide_release = floor(variable_struct_get(_bide_state_dmg, "damage")) * 2;
                }
            } catch (e_bide_dmg) { _bide_release = 0; }
            dmg = max(0, _bide_release);
        }

        if (is_undefined(__battle_move_behavior_fixed_damage)){
            // Legacy fallback for level-damage moves if the central resolver is unavailable.
            if (is_real(_move_id) && (_move_id == 69 || _move_id == 101)){
                try {
                    var atk_level_flat = (is_struct(_A) && variable_struct_exists(_A, "level") && is_real(variable_struct_get(_A, "level"))) ? floor(variable_struct_get(_A, "level")) : 1;
                    dmg = max(0, atk_level_flat);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] level-based move applied move="+string(_move_id)+", dmg="+string(dmg));
                } catch (e_lvl) { }
            }
        }

        // Psywave: random fixed damage from 50% to 150% of the user's level.
        if (is_real(_move_id) && _move_id == 149){
            try {
                var _psy_level = (is_struct(_A) && variable_struct_exists(_A, "level") && is_real(variable_struct_get(_A, "level"))) ? floor(variable_struct_get(_A, "level")) : 1;
                dmg = max(1, floor(_psy_level * irandom_range(50, 150) / 100));
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Psywave fixed dmg=" + string(dmg));
            } catch (e_psywave) { dmg = max(1, dmg); }
        }

        if (is_real(_move_id) && (_move_id == 76 || _move_id == 669) && is_real(dmg) && dmg > 0){
            try {
                var _solar_weather_dmg = __battle_get_weather(_pid);
                if (__battle_weather_is_active(_solar_weather_dmg)){
                    var _solar_wid_dmg = __battle_weather_get_normalized_id(_solar_weather_dmg);
                    if (_solar_wid_dmg == "rain" || _solar_wid_dmg == "hail" || _solar_wid_dmg == "snow" || _solar_wid_dmg == "sandstorm"){
                        dmg = max(1, floor(dmg * 0.5));
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] solar charge move halved by weather=" + string(_solar_wid_dmg));
                    }
                }
            } catch (e_solar_dmg) {}
        }

        if (is_real(_move_id) && (_move_id == 23 || _move_id == 537) && is_real(dmg) && dmg > 0 && is_struct(_D)){
            var _target_minimized = false;
            try {
                _target_minimized = (variable_struct_exists(_D, "_minimized") && variable_struct_get(_D, "_minimized") == true);
                if (!_target_minimized && variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))){
                    var _min_mon = variable_struct_get(_D, "mon");
                    _target_minimized = (variable_struct_exists(_min_mon, "_minimized") && variable_struct_get(_min_mon, "_minimized") == true);
                }
            } catch (e_min_check) { _target_minimized = false; }
            if (_target_minimized){
                dmg = max(1, floor(dmg * 2));
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Stomp-style minimize damage doubled");
            }
        }

        // False Swipe (id 206) must not reduce the target below 1 HP (can't OHKO)
        if (is_real(_move_id) && _move_id == 206 && is_real(dmg) && dmg > 0){
            var before_hp_fs = before;
            var intended_after_fs = max(0, before_hp_fs - dmg);
            if (intended_after_fs < 1){
                var new_dmg_fs = max(0, before_hp_fs - 1);
                if (new_dmg_fs != dmg){
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] False Swipe adjusted dmg from " + string(dmg) + " to " + string(new_dmg_fs) + " (before=" + string(before_hp_fs) + ")");
                    dmg = new_dmg_fs;
                }
            }
        }

        try {
            var _first_guard_actions = __battle_actor_ability_actions(_D, "before_damage_apply");
            for (var _fgi = 0; _fgi < array_length(_first_guard_actions); ++_fgi){
                var _fgact = _first_guard_actions[_fgi];
                if (!is_struct(_fgact)) continue;
                var _fgkind = variable_struct_exists(_fgact, "kind") ? string_lower(string(variable_struct_get(_fgact, "kind"))) : "";
                if (_fgkind != "block_first_hit") continue;
                var _fg_used = false;
                try { _fg_used = variable_struct_exists(_D, "_ability_first_hit_used") && variable_struct_get(_D, "_ability_first_hit_used") == true; } catch (e_fg_used) { _fg_used = false; }
                if (!_fg_used && is_real(dmg) && dmg > 0){
                    variable_struct_set(_D, "_ability_first_hit_used", true);
                    dmg = 0;
                    try { __battle_queue_ability_action_dialog(_D, _fgact, _A, {}); } catch (e_fg_dialog) {}
                    break;
                }
            }
        } catch (e_first_hit_guard) {}

        try {
            var _has_sturdy_ability = false;
            if (!is_undefined(__battle_actor_ability_effect)){
                var _sturdy_eff = __battle_actor_ability_effect(_D);
                _has_sturdy_ability = (is_struct(_sturdy_eff) && variable_struct_exists(_sturdy_eff, "sturdy") && variable_struct_get(_sturdy_eff, "sturdy") == true);
            }
            if (!_has_sturdy_ability && !is_undefined(__battle_actor_ability_has_group)) _has_sturdy_ability = __battle_actor_ability_has_group(_D, "survive_full_hp_ko");
            if (!_has_sturdy_ability && !is_undefined(__battle_actor_has_any_ability)) _has_sturdy_ability = __battle_actor_has_any_ability(_D, ["sturdy"]);
            if (is_real(dmg) && dmg > 0 && _has_sturdy_ability){
                var _sturdy_max = __battle_hp_max(_D);
                if (before >= _sturdy_max && before - dmg <= 0){
                    dmg = max(0, before - 1);
                    if (!is_undefined(__battle_queue_ability_action_dialog)){
                        __battle_queue_ability_action_dialog(_D, { hook:"before_damage_apply", kind:"survive_full_hp_ko", data:{ hp:1 } }, _A, {});
                    } else {
                        var _sturdy_name = __battle_dialog_actor_name(_D, "The target");
                        dialog_queue(_sturdy_name + " hung on using its STURDY!");
                    }
                }
            }
        } catch (e_sturdy) {}

        try {
            if (is_real(dmg) && dmg > 0 && before - dmg <= 0 && !is_undefined(item_runtime_actor_held_actions)){
                var _survive_item_actions = item_runtime_actor_held_actions(_D, "before_faint");
                for (var _sii = 0; _sii < array_length(_survive_item_actions); ++_sii){
                    var _siact = _survive_item_actions[_sii];
                    if (!is_struct(_siact)) continue;
                    var _sikind = variable_struct_exists(_siact, "kind") ? string_lower(string(variable_struct_get(_siact, "kind"))) : "";
                    var _sidata = (variable_struct_exists(_siact, "data") && is_struct(variable_struct_get(_siact, "data"))) ? variable_struct_get(_siact, "data") : {};
                    var _survive_hp = (variable_struct_exists(_sidata, "hp") && is_real(variable_struct_get(_sidata, "hp"))) ? max(1, floor(variable_struct_get(_sidata, "hp"))) : 1;
                    var _should_survive_item = false;
                    if (_sikind == "survive_full_hp_once"){
                        _should_survive_item = (before >= __battle_hp_max(_D));
                    } else if (_sikind == "chance_survive"){
                        var _chance_survive = (variable_struct_exists(_sidata, "chance") && is_real(variable_struct_get(_sidata, "chance"))) ? clamp(floor(variable_struct_get(_sidata, "chance")), 0, 100) : 10;
                        _should_survive_item = (irandom(99) < _chance_survive);
                    }
                    if (_should_survive_item){
                        var _item_label_survive = __battle_held_item_label(_D);
                        dmg = max(0, before - _survive_hp);
                        __battle_item_consume_held(_D);
                        try { dialog_queue(__battle_dialog_actor_name(_D, "The Pokemon") + " hung on using its " + _item_label_survive + "!"); } catch (e_survive_item_dialog) {}
                        break;
                    }
                }
            }
        } catch (e_item_before_faint) {}

        // Terrain effects: adjust damage or cancel based on battlefield terrain
        try {
            var terr = "";
            var _Bterr = __battle_ensure_slot(_pid);
            if (is_struct(_Bterr)){
                if (variable_struct_exists(_Bterr, "_field")){
                    var _fld = variable_struct_get(_Bterr, "_field");
                    if (is_struct(_fld) && variable_struct_exists(_fld, "terrain")){
                        var _terr_struct = variable_struct_get(_fld, "terrain");
                        if (is_struct(_terr_struct) && variable_struct_exists(_terr_struct, "id")) terr = string_lower(string(variable_struct_get(_terr_struct, "id")));
                    }
                } else if (variable_struct_exists(_Bterr, "_terrain")){
                    terr = string_lower(string(variable_struct_get(_Bterr, "_terrain")));
                }
            }
            if (string_length(terr) > 0){
                // Helper: grounded checks (reuse __actor_is_grounded if present)
                var A_grounded = true; var D_grounded = true;
                try { if (!is_undefined(__actor_is_grounded)) { A_grounded = __actor_is_grounded(_A); D_grounded = __actor_is_grounded(_D); } } catch (e_gr) {}
                // Move type id when available
                var mv_type = -1;
                try { if (!is_undefined(scr_move_type_id_by_id) && is_real(_move_id)) mv_type = scr_move_type_id_by_id(_move_id, _A); } catch (e_mt) { mv_type = -1; }
                // Psychic Terrain: block priority moves against grounded targets, and boost Psychic-type moves (grounded attacker)
                if (terr == "psychic"){
                    var priority_val = 0;
                    try {
                        if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
                            var _mm_pt = __battle_get_move_meta(_move_id);
                            if (is_struct(_mm_pt) && variable_struct_exists(_mm_pt, "priority") && is_real(variable_struct_get(_mm_pt, "priority"))) priority_val = variable_struct_get(_mm_pt, "priority");
                        }
                    } catch (e_pr) { priority_val = 0; }
                    if (is_real(priority_val) && priority_val > 0 && D_grounded){
                        // Cancel the move's damage application
                        try { var _dnm = (is_struct(_D) && variable_struct_exists(_D, "name") ? variable_struct_get(_D, "name") : "The target"); try { dialog2p_show_now(_pid, string(_dnm) + " was protected by the terrain!"); } catch (e_msg) { try { dialog2p_enqueue(_pid, string(_dnm) + " was protected by the terrain!"); } catch(e_){} } } catch (e_msg) {}
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                            var _an_dbg = (is_struct(_A) && variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "<att>");
                            show_debug_message("[battle][terrain] Psychic Terrain blocked priority move id=" + string(_move_id) + " from attacker=" + string(_an_dbg));
                        }
                        return [0, before, before];
                    }
                    // Boost Psychic-type moves by 1.3x for grounded users
                    var psy_id = -1;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")) { var _tmap_psy = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmap_psy, ds_type_map)) psy_id = ds_map_find_value(_tmap_psy, "psychic"); } } catch (e_tp) { psy_id = -1; }
                    if (is_real(psy_id) && mv_type == psy_id && A_grounded){
                        dmg = floor(dmg * 1.3);
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Psychic Terrain 1.3x boost applied to Psychic move id=" + string(_move_id));
                    }
                }
                // Electric Terrain: boost Electric-type moves used by grounded attacker (x1.3)
                if (terr == "electric" && is_real(mv_type)){
                    var ele_id = -1;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")){ var _tmap = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmap, ds_type_map)) ele_id = ds_map_find_value(_tmap, "electric"); } } catch (e_te) { ele_id = -1; }
                    if (is_real(ele_id) && mv_type == ele_id && A_grounded){ dmg = floor(dmg * 1.3); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Electric Terrain 1.3x boost applied to Electric move id=" + string(_move_id)); }
                }
                // Grassy Terrain: halve EQ/Bulldoze/Magnitude damage; boost Grass-type moves for grounded attackers
                if (terr == "grassy"){
                    // Identify EQ/Bulldoze/Magnitude by identifier or name
                    var iden = "";
                    try { if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){ var mv = global._moves[_move_id]; if (is_struct(mv) && variable_struct_exists(mv, "identifier")) iden = string_lower(string(variable_struct_get(mv, "identifier"))); } } catch (e_id) { iden = ""; }
                    if (string_length(iden) > 0){ if (string_pos("earthquake", iden) > 0 || string_pos("bulldoze", iden) > 0 || string_pos("magnitude", iden) > 0){ dmg = floor(dmg * 0.5); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Grassy Terrain halved ground-type quake-like move id=" + string(_move_id)); } }
                    // Boost Grass-type moves by 1.3x for grounded users
                    var grass_id = -1;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")){ var _tmap3 = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmap3, ds_type_map)) grass_id = ds_map_find_value(_tmap3, "grass"); } } catch (e_tg) { grass_id = -1; }
                    if (is_real(grass_id) && mv_type == grass_id && A_grounded){ dmg = floor(dmg * 1.3); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Grassy Terrain 1.3x boost applied to Grass move id=" + string(_move_id)); }
                }
                // Misty Terrain: halve Dragon-type move damage against grounded targets
                if (terr == "misty" && is_real(mv_type) && D_grounded){
                    var drag_id = -1;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")){ var _tmap2 = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmap2, ds_type_map)) drag_id = ds_map_find_value(_tmap2, "dragon"); } } catch (e_td) { drag_id = -1; }
                    if (is_real(drag_id) && mv_type == drag_id){ dmg = floor(dmg * 0.5); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Misty Terrain halved Dragon move id=" + string(_move_id)); }
                }
                var _mud_sport_turns = __battle_field_get_status_or(_pid, "mud_sport", 0);
                if (is_real(_mud_sport_turns) && _mud_sport_turns > 0 && is_real(mv_type)){
                    var ele_field_id = -1;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")){ var _tmap_mud = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmap_mud, ds_type_map)) ele_field_id = ds_map_find_value(_tmap_mud, "electric"); } } catch (e_tmud) { ele_field_id = -1; }
                    if (is_real(ele_field_id) && mv_type == ele_field_id){
                        dmg = max(1, floor(dmg * 0.5));
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][field] Mud Sport halved Electric move id=" + string(_move_id));
                    }
                }
                var _water_sport_turns = __battle_field_get_status_or(_pid, "water_sport", 0);
                if (is_real(_water_sport_turns) && _water_sport_turns > 0 && is_real(mv_type)){
                    var fire_field_id = 10;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")){ var _tmap_water = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmap_water, ds_type_map)) fire_field_id = ds_map_find_value(_tmap_water, "fire"); } } catch (e_twater) { fire_field_id = 10; }
                    if (is_real(fire_field_id) && mv_type == fire_field_id){
                        dmg = max(1, floor(dmg * 0.5));
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][field] Water Sport halved Fire move id=" + string(_move_id));
                    }
                }
            }
        } catch (e_terr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] damage adjust failed: " + string(e_terr)); }

        try {
            var _damage_class = undefined;
            if (!is_undefined(scr_move_damage_class_by_id) && is_real(_move_id)) _damage_class = scr_move_damage_class_by_id(_move_id);
            else if (is_struct(_move_rec) && variable_struct_exists(_move_rec, "damage_class_id") && is_real(variable_struct_get(_move_rec, "damage_class_id"))) _damage_class = variable_struct_get(_move_rec, "damage_class_id");
            if (is_real(_damage_class) && is_real(_target_index) && is_real(dmg) && dmg > 0){
                var _def_side = __battle_field_side_index_for_actor(_target_index);
                var _bypass_barriers = false;
                try {
                    var _barrier_actions = __battle_actor_ability_actions(_A, "damage_dealt");
                    for (var _bai = 0; _bai < array_length(_barrier_actions); ++_bai){
                        var _bact = _barrier_actions[_bai];
                        if (!is_struct(_bact)) continue;
                        var _bkind = variable_struct_exists(_bact, "kind") ? string_lower(string(variable_struct_get(_bact, "kind"))) : "";
                        if (_bkind == "bypass_target_barriers"){
                            _bypass_barriers = true;
                            try { __battle_queue_ability_action_dialog(_A, _bact, _D, {}); } catch (e_bypass_dialog) {}
                            break;
                        }
                    }
                } catch (e_bypass_barrier_read) { _bypass_barriers = false; }
                var _aurora_turns = __battle_field_get_barrier_or(_pid, _def_side, "aurora_veil", 0);
                if (!_bypass_barriers && is_real(_aurora_turns) && _aurora_turns > 0){
                    dmg = max(1, floor(dmg * 0.5));
                } else if (!_bypass_barriers && _damage_class == 2){
                    var _reflect_turns = __battle_field_get_barrier_or(_pid, _def_side, "reflect", 0);
                    if (is_real(_reflect_turns) && _reflect_turns > 0) dmg = max(1, floor(dmg * 0.5));
                } else if (!_bypass_barriers && _damage_class == 3){
                    var _screen_turns = __battle_field_get_barrier_or(_pid, _def_side, "light_screen", 0);
                    if (is_real(_screen_turns) && _screen_turns > 0) dmg = max(1, floor(dmg * 0.5));
                }
            }
        } catch (e_barrier_dmg) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][barrier] damage adjust failed: " + string(e_barrier_dmg)); }
    } catch (e_ms) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] handler error: " + string(e_ms)); }

    // Defensive guard: prevent accidental self-hits when target == attacker and move is not a self-targeting move
    try {
        var _att_idx_chk = undefined;
        if (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) _att_idx_chk = variable_struct_get(_A, "actor_index");
        else if (is_struct(_A) && variable_struct_exists(_A, "slot") && is_real(variable_struct_get(_A, "slot"))) _att_idx_chk = variable_struct_get(_A, "slot");
        var _is_self_target_allowed = false;
        // Try move meta first
        try {
            if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
                var _mm_local = __battle_get_move_meta(_move_id);
                if (is_struct(_mm_local) && variable_struct_exists(_mm_local, "target")){
                    var _tstr = string(variable_struct_get(_mm_local, "target"));
                    _tstr = string_lower(_tstr);
                    if (string_pos("self", _tstr) > 0 || string_pos("user", _tstr) > 0 || string_pos("own", _tstr) > 0 || string_pos("ally", _tstr) > 0) _is_self_target_allowed = true;
                }
            }
        } catch (e_mmeta) {}
        // Fallback: check global._moves entry if available
        try {
            if (!_is_self_target_allowed && variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){
                var _mEntry = global._moves[_move_id];
                if (is_struct(_mEntry) && variable_struct_exists(_mEntry, "target")){
                    var _t2 = string(variable_struct_get(_mEntry, "target")); _t2 = string_lower(_t2);
                    if (string_pos("self", _t2) > 0 || string_pos("user", _t2) > 0 || string_pos("own", _t2) > 0 || string_pos("ally", _t2) > 0) _is_self_target_allowed = true;
                }
            }
        } catch (e_mf) {}
        if (!_is_self_target_allowed && is_real(_move_id) && _move_id < 0){
            if (is_struct(_A) && variable_struct_exists(_A, "_allow_confusion_self_hit") && variable_struct_get(_A, "_allow_confusion_self_hit") == true){
                _is_self_target_allowed = true;
            }
        }
        if (is_real(_att_idx_chk) && is_real(_target_index) && _att_idx_chk == _target_index && !_is_self_target_allowed){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
                var _an = (is_struct(_A) && variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "<att?>");
                var _dn = (is_struct(_D) && variable_struct_exists(_D, "name") ? variable_struct_get(_D, "name") : "<def?>");
                show_debug_message("[guard][apply_move_damage] prevented accidental self-hit: pid=" + string(_pid) + ", move=" + string(_move_id) + ", attacker=" + string(_an) + ", idx=" + string(_att_idx_chk) + ", defender=" + string(_dn) + ", idx=" + string(_target_index) + ", meta_allows_self=" + string(_is_self_target_allowed));
            }
            return [0, before, before];
        }
    } catch (e_guard) { /* silently continue to apply damage if guard fails */ }

    // Apply any semi-invulnerable hit multiplier after all move-specific overrides.
    try {
            var _has_tmp_mult = false;
            try {
                if (is_struct(_A) && variable_struct_exists(_A, "__semi_mult_tmp") && !is_undefined(variable_struct_get(_A, "__semi_mult_tmp"))){
                    _has_tmp_mult = true;
                }
            } catch (e_chk) { _has_tmp_mult = false; }
            if (!_has_tmp_mult){
                if (is_real(_semi_mult) && _semi_mult > 1.0 && is_real(dmg) && dmg > 0){
                    dmg = round(dmg * _semi_mult);
                }
            }
    } catch (e_semimul) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][semi] multiplier apply failed: " + string(e_semimul)); }

    try {
        if (is_real(dmg) && dmg > 0 && !is_undefined(status_system_has_status) && !is_undefined(status_system_get) && status_system_has_status(_D, "substitute")){
            var _sub_inst_live = status_system_get(_D, "substitute");
            if (is_struct(_sub_inst_live)){
                var _sub_hp_live = (variable_struct_exists(_sub_inst_live, "hp") && is_real(variable_struct_get(_sub_inst_live, "hp"))) ? floor(variable_struct_get(_sub_inst_live, "hp")) : 0;
                var _incoming_sub = max(0, round(dmg * (is_real(mult) ? mult : 1)));
                if (_sub_hp_live > 0 && _incoming_sub > 0){
                    var _sub_left = max(0, _sub_hp_live - _incoming_sub);
                    variable_struct_set(_sub_inst_live, "hp", _sub_left);
                    if (variable_struct_exists(_sub_inst_live, "hp_max") && is_real(variable_struct_get(_sub_inst_live, "hp_max"))){
                        variable_struct_set(_sub_inst_live, "hp_max", max(variable_struct_get(_sub_inst_live, "hp_max"), _sub_hp_live));
                    }
                    try { __battle_request_animation_safe(_pid, { type: "substitute_hit", target_index: _target_index }); } catch (e_sub_anim) {}
                    if (_sub_left <= 0){
                        try { status_system_clear_status(_D, "substitute"); } catch (e_sub_clear) {}
                        try {
                            var _sub_name_break = __battle_dialog_actor_name(_D, "The substitute");
                            dialog_queue(_sub_name_break + "'s substitute faded!");
                        } catch (e_sub_msg_break) {}
                    }
                    return [0, before, before];
                }
            }
        }
    } catch (e_sub_block) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][substitute] damage intercept failed: " + string(e_sub_block)); }

    // Apply damage (this will update hp_now). Pass effectiveness multiplier so SFX choice can match.
    var _Bdamage_src = __battle_ensure_slot(_pid);
    try {
        if (is_struct(_Bdamage_src)){
            variable_struct_set(_Bdamage_src, "_pending_damage_source", {
                attacker: _A,
                move_id: _move_id,
                move_slot: (is_struct(_A) && variable_struct_exists(_A, "_last_selected_move_slot") ? variable_struct_get(_A, "_last_selected_move_slot") : undefined)
            });
        }
    } catch (e_damage_src_stamp) {}
    __battle_apply_damage(_pid, _target_index, dmg, mult);
    try {
        if (is_struct(_Bdamage_src)) variable_struct_set(_Bdamage_src, "_pending_damage_source", undefined);
    } catch (e_damage_src_clear) {}
    var after = __battle_hp_now(_D);

    if (_snipe_bypassed_guard && is_struct(_D)){
        try {
            var _msg_target = "The target";
            if (!is_undefined(__status_mon_display_name)) _msg_target = __status_mon_display_name(_D);
            else if (variable_struct_exists(_D, "name")) _msg_target = string(variable_struct_get(_D, "name"));
            if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_D, string(_msg_target) + " couldn't block the shot!", false);
        } catch (e_msg_guard) {}
    }

    // Play an impact sound. The type-effectiveness multiplier `mult` is best-effort
    // but has been unreliable; prefer an observed damage-based heuristic when
    // multiplier looks neutral. We compute the actual hp delta and a percent of
    // the target's max HP and use thresholds to choose the SFX.
    try {
        var actual_delta = max(0, before - after);
        try { __battle_apply_ability_after_damage_reactions(_pid, _target_index, _A, _D, _move_id, before, after, actual_delta); } catch (e_ability_after_damage_reactions) {}
        try {
            if (actual_delta > 0){
                var _atk_idx_for_item_taken = -1;
                if (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) _atk_idx_for_item_taken = floor(variable_struct_get(_A, "actor_index"));
                else if (is_struct(_A) && variable_struct_exists(_A, "slot") && is_real(variable_struct_get(_A, "slot"))) _atk_idx_for_item_taken = floor(variable_struct_get(_A, "slot"));
                var _dc_for_item_taken = undefined;
                try { if (!is_undefined(scr_move_damage_class_by_id) && is_real(_move_id)) _dc_for_item_taken = scr_move_damage_class_by_id(_move_id); } catch (e_dc_item_taken) {}
                if (!is_undefined(__battle_try_held_after_damage_taken_items)) __battle_try_held_after_damage_taken_items(_pid, _target_index, _D, _A, _atk_idx_for_item_taken, _move_id, _dc_for_item_taken, actual_delta);
                if (!is_undefined(__battle_try_auto_use_held_berry)) __battle_try_auto_use_held_berry(_pid, _target_index, _D, _A, _move_id, _dc_for_item_taken, mult, "after_damage");
            }
        } catch (e_item_after_damage_taken_runtime) {}
        try {
            if (actual_delta > 0 && !is_undefined(item_runtime_actor_held_actions)){
                var _after_item_actions = item_runtime_actor_held_actions(_A, "after_damage");
                var _attacker_index_item = undefined;
                if (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) _attacker_index_item = floor(variable_struct_get(_A, "actor_index"));
                for (var _aiai = 0; _aiai < array_length(_after_item_actions); ++_aiai){
                    var _aiact = _after_item_actions[_aiai];
                    if (!is_struct(_aiact)) continue;
                    var _aikind = variable_struct_exists(_aiact, "kind") ? string_lower(string(variable_struct_get(_aiact, "kind"))) : "";
                    var _aidata = (variable_struct_exists(_aiact, "data") && is_struct(variable_struct_get(_aiact, "data"))) ? variable_struct_get(_aiact, "data") : {};
                    if (_aikind == "heal_damage_fraction"){
                        var _num_h = (variable_struct_exists(_aidata, "numerator") && is_real(variable_struct_get(_aidata, "numerator"))) ? variable_struct_get(_aidata, "numerator") : 1;
                        var _den_h = (variable_struct_exists(_aidata, "denominator") && is_real(variable_struct_get(_aidata, "denominator"))) ? max(1, variable_struct_get(_aidata, "denominator")) : 8;
                        var _heal_h = max(1, floor(actual_delta * _num_h / _den_h));
                        var _before_h_item = __battle_hp_now(_A);
                        var _after_h_item = min(max(1, __battle_hp_max(_A)), _before_h_item + _heal_h);
                        if (_after_h_item > _before_h_item){
                            __battle_set_hp_now(_A, _after_h_item);
                            try { __battle_clear_fainted_if_healed(_A); } catch (e_item_heal_clear) {}
                            try { __battle_request_animation_safe(_pid, { type:"heal", actor:_A, amount:(_after_h_item - _before_h_item) }); } catch (e_item_heal_anim) {}
                            try { dialog_queue(__battle_ability_actor_name(_A, "The Pokemon") + " restored HP using its " + __battle_held_item_label(_A) + "!"); } catch (e_item_heal_dialog) {}
                        }
                    } else if (_aikind == "recoil_max_hp_fraction"){
                        var _num_r = (variable_struct_exists(_aidata, "numerator") && is_real(variable_struct_get(_aidata, "numerator"))) ? variable_struct_get(_aidata, "numerator") : 1;
                        var _den_r = (variable_struct_exists(_aidata, "denominator") && is_real(variable_struct_get(_aidata, "denominator"))) ? max(1, variable_struct_get(_aidata, "denominator")) : 10;
                        var _recoil_item = max(1, floor(max(1, __battle_hp_max(_A)) * _num_r / _den_r));
                        try { dialog_queue(__battle_ability_actor_name(_A, "The Pokemon") + " was hurt by its " + __battle_held_item_label(_A) + "!"); } catch (e_item_recoil_dialog) {}
                        if (is_real(_attacker_index_item)) __battle_apply_damage(_pid, _attacker_index_item, _recoil_item, 1.0);
                        else __battle_set_hp_now(_A, max(0, __battle_hp_now(_A) - _recoil_item));
                    }
                }
            }
        } catch (e_item_after_damage_reactions) {}
        // Record last-received damage on the defender so counter-moves can reference it
        try {
            if (is_struct(_D) && is_real(actual_delta) && actual_delta > 0){
                // store last received damage and move context
                variable_struct_set(_D, "_last_received_damage", actual_delta);
                variable_struct_set(_D, "_was_hit_this_turn", true);
                try { variable_struct_set(_D, "_last_received_from_move", _move_id); } catch (ee) {}
                try { variable_struct_set(_D, "_last_received_from_move_damage", actual_delta); } catch (ee_md) {}
                // store damage class (physical/special) if data-layer helper exists
                try { if (!is_undefined(scr_move_damage_class_by_id) && is_real(_move_id)) variable_struct_set(_D, "_last_received_move_damage_class", scr_move_damage_class_by_id(_move_id)); } catch (ee2) {}
                try {
                    if (variable_struct_exists(_D, "_bide_state") && is_struct(variable_struct_get(_D, "_bide_state"))){
                        var _bide_taken = variable_struct_get(_D, "_bide_state");
                        var _bide_accum = (variable_struct_exists(_bide_taken, "damage") && is_real(variable_struct_get(_bide_taken, "damage"))) ? floor(variable_struct_get(_bide_taken, "damage")) : 0;
                        variable_struct_set(_bide_taken, "damage", max(0, _bide_accum + actual_delta));
                        variable_struct_set(_D, "_bide_state", _bide_taken);
                    }
                } catch (ee_bide) {}
                // store attacker actor index when discoverable
                try {
                    var atk_idx = undefined;
                    var _Btmp = __battle_ensure_slot(_pid);
                    if (is_struct(_Btmp) && variable_struct_exists(_Btmp, "actor") && is_array(variable_struct_get(_Btmp, "actor"))){
                        var __acts_tmp = variable_struct_get(_Btmp, "actor");
                        for (var _ai_tmp = 0; _ai_tmp < array_length(__acts_tmp); ++_ai_tmp){ if (is_struct(__acts_tmp[_ai_tmp]) && __acts_tmp[_ai_tmp] == _A){ atk_idx = _ai_tmp; break; } }
                    }
                    if (is_real(atk_idx)) variable_struct_set(_D, "_last_received_from_actor_index", atk_idx);
                } catch (ee3) {}
            }
        } catch (e_lr){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] last-received record failed: " + string(e_lr)); }
        // Determine defender max HP
        var def_hp_max = 1;
        if (variable_struct_exists(_D, "hp_max")) def_hp_max = variable_struct_get(_D, "hp_max");
        else if (variable_struct_exists(_D, "maxhp")) def_hp_max = variable_struct_get(_D, "maxhp");
        else if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))){ var _m2 = variable_struct_get(_D, "mon"); if (variable_struct_exists(_m2, "hp_max")) def_hp_max = variable_struct_get(_m2, "hp_max"); }
        def_hp_max = max(1, def_hp_max);

        var pct = (def_hp_max > 0) ? (actual_delta / def_hp_max) : 0;
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][sound] move dmg play attempt mult=" + string(mult) + ", delta=" + string(actual_delta) + ", hp_max=" + string(def_hp_max) + ", pct=" + string(pct));

        // Heuristic thresholds (tunable):
        // - pct >= 0.25 => loud/super-effective
        // - pct <= 0.10 => quiet/not-very-effective
        // Otherwise neutral.
        var use_super = false; var use_notvery = false;
        if (pct >= 0.25) use_super = true;
        else if (pct <= 0.10 && actual_delta > 0) use_notvery = true;

        // Allow explicit multiplier to override/augment the heuristic when it is present
        if (is_real(mult) && mult > 1.0) use_super = true;
        if (is_real(mult) && mult < 1.0 && mult > 0.0) use_notvery = true;

        if (!is_undefined(audio_play_sound)){
            try {
                if (use_super) audio_play_sound(snd_SuperEffective, 1, false);
                else if (use_notvery) audio_play_sound(snd_NotVeryEffective, 1, false);
                else audio_play_sound(snd_Effective, 1, false);
                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][sound] move played via audio_play_sound (direct resource) chosen_super=" + string(use_super) + ", chosen_notvery=" + string(use_notvery));
            } catch (e_ap2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] audio_play_sound failed: " + string(e_ap2)); }
        } else {
            try {
                if (use_super) __battle_sound_play_safe(snd_SuperEffective);
                else if (use_notvery) __battle_sound_play_safe(snd_NotVeryEffective);
                else __battle_sound_play_safe(snd_Effective);
            } catch (e_spf3) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] fallback move play failed: " + string(e_spf3)); }
        }
    } catch (e_snd){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] play failed: " + string(e_snd)); }

    // Start a visual HP lerp on the defender so the UI animates from before->after
    try {
        if (is_struct(_D)){
            variable_struct_set(_D, "_hp_lerp_from", before);
            variable_struct_set(_D, "_hp_lerp_to", after);
            variable_struct_set(_D, "_hp_lerp_start_ms", current_time);
            variable_struct_set(_D, "_hp_lerp_dur", 400); // ms
            variable_struct_set(_D, "_hp_lerp_active", true);
            // mirror to inner mon if present
            if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))){ var _m = variable_struct_get(_D, "mon"); variable_struct_set(_m, "_hp_lerp_from", before); variable_struct_set(_m, "_hp_lerp_to", after); variable_struct_set(_m, "_hp_lerp_start_ms", current_time); variable_struct_set(_m, "_hp_lerp_dur", 400); variable_struct_set(_m, "_hp_lerp_active", true); }
        }
    } catch (e_lerp){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][lerp] start failed: " + string(e_lerp)); }

    return [dmg, before, after];
}
