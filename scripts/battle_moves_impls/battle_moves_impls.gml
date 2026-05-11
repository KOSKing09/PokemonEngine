// [Battle] battle_moves_impls — Build v0.2.0 — Updated 2025-10-18

// Primary move resolver implementation.
// Handles move execution, including meta move reroutes, status gates, and delegates to
// battle_impl helpers for damage/effect application.

function __battle_perform_action_impl(_pid, _step){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return "";
    var actor_idx = (variable_struct_exists(_step, "actor_index") ? variable_struct_get(_step, "actor_index") : 0);
    var target_idx = (variable_struct_exists(_step, "target_index") ? variable_struct_get(_step, "target_index") : 1);
    var A = undefined; var D = undefined;
    try {
        if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
            var __acts = variable_struct_get(_B, "actor");
            if (is_real(actor_idx) && actor_idx >= 0 && actor_idx < array_length(__acts)) A = __acts[actor_idx];
            if (is_real(target_idx) && target_idx >= 0 && target_idx < array_length(__acts)) D = __acts[target_idx];
        }
    } catch (e_a) { A = undefined; D = undefined; }

    if (is_struct(_step) && variable_struct_exists(_step, "switch_to")){
        var _switch_idx = variable_struct_get(_step, "switch_to");
        var _switch_msg = "But it failed!";
        try {
            if (!is_undefined(__battle_trainer_perform_switch_action)){
                _switch_msg = __battle_trainer_perform_switch_action(_pid, _switch_idx, _step);
            } else if (!is_undefined(battle_switch_to)){
                var _ok_switch = battle_switch_to(_pid, _switch_idx, { forced: true, actor_index: actor_idx, consume_turn: false, auto_apply: true });
                _switch_msg = (_ok_switch ? "The opponent sent out a Pokémon!" : "But it failed!");
            }
        } catch (e_switch) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][debug] switch action failed: " + string(e_switch));
        }
        return _switch_msg;
    }

    // Local helper to centralize the 'used' vs 'ohko miss' return message.
    // Also stamps the actor with last_move_dialog id/ts so other paths can de-dup their own messages.
    // Accept explicit parameters to avoid closure/scope issues with the static analyser.
    function __battle_impl_return_used(_pid_in, _A_in, _mv_name_in, _mid_in){
        var _actor_name = "The user";
        try {
            if (is_struct(_A_in) && variable_struct_exists(_A_in, "name")) _actor_name = string(variable_struct_get(_A_in, "name"));
            if (is_struct(_A_in) && variable_struct_exists(_A_in, "actor_index") && is_real(variable_struct_get(_A_in, "actor_index"))){
                var _actor_idx_name = floor(variable_struct_get(_A_in, "actor_index"));
                if (!is_undefined(__battle_actor_side) && __battle_actor_side(_actor_idx_name) == 1){
                    if (string_copy(_actor_name, 1, 4) != "Foe ") _actor_name = "Foe " + _actor_name;
                }
            }
        } catch (e_actor_name) {}
        try {
            var _Bslot_rr = __battle_ensure_slot(_pid_in);
            if (is_struct(_Bslot_rr) && variable_struct_exists(_Bslot_rr, "_last_ohko_miss") && variable_struct_get(_Bslot_rr, "_last_ohko_miss") == true){
                // Log consumption explicitly so it stands out in noisy logs
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[OHKO] performer consuming _last_ohko_miss for pid=" + string(_pid_in) + " move=" + string(_mv_name_in));
                try { variable_struct_set(_Bslot_rr, "_last_ohko_miss", undefined); } catch (e_clr) {}
                return _actor_name + "'s attack missed!";
            }
        } catch (e_ru) {}
        // Best-effort: stamp last_move_dialog fields so inner enqueuers can skip duplicates
        try {
            if (is_struct(_A_in)){
                if (is_real(_mid_in)){
                    variable_struct_set(_A_in, "_last_move_dialog_id", _mid_in);
                    variable_struct_set(_A_in, "_last_move_dialog_ts", current_time);
                }
            }
        } catch (e_stamp) {}
        return _actor_name + " used " + string(_mv_name_in) + "!";
    }

    function __battle_consume_damage_miss(_pid_in){
        var _missed = false;
        try {
            var _Bslot_miss = __battle_ensure_slot(_pid_in);
            if (is_struct(_Bslot_miss) && variable_struct_exists(_Bslot_miss, "_last_damage_move_missed")){
                _missed = (variable_struct_get(_Bslot_miss, "_last_damage_move_missed") == true);
                variable_struct_set(_Bslot_miss, "_last_damage_move_missed", false);
            }
        } catch (e_consume_miss) { _missed = false; }
        return _missed;
    }

    function __battle_record_move_usage(_pid_in, _user_in, _target_in, _move_in, _skip_target_record){
        if (!is_real(_move_in)) return;
        try { global.lastMoveUsed_ID = _move_in; } catch (e_gl) {}
        var _suppress_target = false;
        if (is_struct(_user_in)){
            try {
                if (variable_struct_exists(_user_in, "_suppress_last_move_record") && variable_struct_get(_user_in, "_suppress_last_move_record") == true){
                    _suppress_target = true;
                }
            } catch (e_sup) {}
            try { variable_struct_set(_user_in, "sys_last_move_used", _move_in); } catch (e_lm1) {}
            try { variable_struct_set(_user_in, "sys_last_move_used_ts", current_time); } catch (e_lm2) {}
            var _user_hist = [];
            try {
                if (variable_struct_exists(_user_in, "_last_moves_used") && is_array(variable_struct_get(_user_in, "_last_moves_used"))){
                    _user_hist = variable_struct_get(_user_in, "_last_moves_used");
                }
            } catch (e_hist) {}
            var _t_idx = undefined;
            if (is_struct(_target_in)){
                if (variable_struct_exists(_target_in, "actor_index")) _t_idx = variable_struct_get(_target_in, "actor_index");
                else if (variable_struct_exists(_target_in, "slot")) _t_idx = variable_struct_get(_target_in, "slot");
            }
            array_push(_user_hist, { move: _move_in, target: _target_in, target_index: _t_idx, ts: current_time });
            if (array_length(_user_hist) > 8){
                var _trim_hist = [];
                var _start_hist = array_length(_user_hist) - 8;
                for (var _hi = _start_hist; _hi < array_length(_user_hist); ++_hi){ array_push(_trim_hist, _user_hist[_hi]); }
                _user_hist = _trim_hist;
            }
            try { variable_struct_set(_user_in, "_last_moves_used", _user_hist); } catch (e_setHist) {}
        }
        if (is_bool(_skip_target_record) && _skip_target_record) _suppress_target = true;
        if (_suppress_target) return;
        if (is_struct(_target_in)){
            var _target_hist = [];
            try {
                if (variable_struct_exists(_target_in, "_last_moves") && is_array(variable_struct_get(_target_in, "_last_moves"))){
                    _target_hist = variable_struct_get(_target_in, "_last_moves");
                }
            } catch (e_tHist) {}
            array_push(_target_hist, { move: _move_in, src: _user_in, ts: current_time });
            if (array_length(_target_hist) > 8){
                var _trim_target = [];
                var _start_target = array_length(_target_hist) - 8;
                for (var _ti = _start_target; _ti < array_length(_target_hist); ++_ti){ array_push(_trim_target, _target_hist[_ti]); }
                _target_hist = _trim_target;
            }
            try { variable_struct_set(_target_in, "_last_moves", _target_hist); } catch (e_setTarget) {}
        }
    }

    function __battle_no_pp_msg(_actor){
        var _name = "The user";
        try {
            if (is_struct(_actor) && variable_struct_exists(_actor, "name")){
                _name = string(variable_struct_get(_actor, "name"));
            }
        } catch (e_np) {}
        return string(_name) + " has no PP left!";
    }

    function __battle_apply_called_move(_pid_in, _caller_in, _target_in, _source_move_in, _called_move_in){
        if (!is_struct(_caller_in) || !is_real(_called_move_in)) return;
        try {
            variable_struct_set(_caller_in, "_called_move_source_id", _source_move_in);
            variable_struct_set(_caller_in, "_called_move_active", true);
            variable_struct_set(_caller_in, "_suppress_called_move_dialog", true);
        } catch (e_ctx_set) {}
        try { __battle_apply_move(_pid_in, _caller_in, _target_in, _called_move_in); } catch (e_ctx_apply) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][called-move] apply failed: " + string(e_ctx_apply)); }
        try { variable_struct_set(_caller_in, "_called_move_source_id", undefined); } catch (e_ctx_clear1) {}
        try { variable_struct_set(_caller_in, "_called_move_active", false); } catch (e_ctx_clear2) {}
        try { variable_struct_set(_caller_in, "_suppress_called_move_dialog", false); } catch (e_ctx_clear3) {}
    }
    function __battle_get_held_item_snapshot(_actor){
        if (!is_struct(_actor)) return { id: -1, name: "" };
        var _iid = (variable_struct_exists(_actor, "held_item_id") && is_real(variable_struct_get(_actor, "held_item_id"))) ? floor(variable_struct_get(_actor, "held_item_id")) : -1;
        var _nm = (variable_struct_exists(_actor, "held_item_real_name") ? string(variable_struct_get(_actor, "held_item_real_name")) : "");
        if (string_length(_nm) <= 0 && is_real(_iid) && _iid > 0 && variable_global_exists("_items") && is_array(global._items) && _iid < array_length(global._items)){
            var _it_snap = global._items[_iid];
            if (is_struct(_it_snap) && variable_struct_exists(_it_snap, "identifier")) _nm = string(variable_struct_get(_it_snap, "identifier"));
        }
        return { id: _iid, name: _nm };
    }

    function __battle_set_held_item_snapshot(_actor, _item_id, _item_name){
        if (!is_struct(_actor)) return;
        var _iid = (is_real(_item_id) ? floor(_item_id) : -1);
        var _nm = (is_string(_item_name) ? string(_item_name) : "");
        variable_struct_set(_actor, "held_item_id", _iid);
        variable_struct_set(_actor, "held_item_real_name", (_iid > 0 ? _nm : ""));
        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
            var _item_mon = variable_struct_get(_actor, "mon");
            variable_struct_set(_item_mon, "held_item_id", _iid);
            variable_struct_set(_item_mon, "held_item_real_name", (_iid > 0 ? _nm : ""));
        }
    }

    function __battle_item_snapshot_is_berry(_item_snap){
        if (!is_struct(_item_snap)) return false;
        var _berry_name = (variable_struct_exists(_item_snap, "name") ? string_lower(string(variable_struct_get(_item_snap, "name"))) : "");
        if (string_length(_berry_name) > 0 && string_pos("berry", _berry_name) > 0) return true;
        var _berry_id = (variable_struct_exists(_item_snap, "id") && is_real(variable_struct_get(_item_snap, "id"))) ? floor(variable_struct_get(_item_snap, "id")) : -1;
        if (_berry_id > 0 && variable_global_exists("_items") && is_array(global._items) && _berry_id < array_length(global._items)){
            var _berry_item = global._items[_berry_id];
            if (is_struct(_berry_item)){
                if (variable_struct_exists(_berry_item, "identifier") && string_pos("berry", string_lower(string(variable_struct_get(_berry_item, "identifier")))) > 0) return true;
                if (variable_struct_exists(_berry_item, "name") && string_pos("berry", string_lower(string(variable_struct_get(_berry_item, "name")))) > 0) return true;
            }
        }
        return false;
    }

    function __battle_consume_borrowed_berry(_berry_item_id, _user_actor){
        if (!is_real(_berry_item_id) || _berry_item_id <= 0 || !is_struct(_user_actor) || is_undefined(scr_apply_item_effects)) return { applied: false, messages: [] };
        var _berry_res = scr_apply_item_effects(_berry_item_id, undefined, _user_actor);
        if (!is_struct(_berry_res)) return { applied: false, messages: [] };
        if (!variable_struct_exists(_berry_res, "messages") || !is_array(variable_struct_get(_berry_res, "messages"))) variable_struct_set(_berry_res, "messages", []);
        return _berry_res;
    }

    function __battle_type_id_from_name(_type_name){
        var _type_l = string_lower(string(_type_name));
        try {
            if (variable_global_exists("TYPE_ID_BY_NAME")){
                var _type_map = variable_global_get("TYPE_ID_BY_NAME");
                if (ds_exists(_type_map, ds_type_map) && ds_map_exists(_type_map, _type_l)) return ds_map_find_value(_type_map, _type_l);
            }
        } catch (e_type_lookup) {}
        switch (_type_l){
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
        }
        return -1;
    }

    function __battle_get_natural_gift_profile(_actor){
        if (!is_struct(_actor)) return undefined;
        var _snap = undefined;
        try {
            if (variable_struct_exists(_actor, "_pending_natural_gift") && is_struct(variable_struct_get(_actor, "_pending_natural_gift"))) _snap = variable_struct_get(_actor, "_pending_natural_gift");
        } catch (e_ng_pending) { _snap = undefined; }
        if (!is_struct(_snap)) _snap = __battle_get_held_item_snapshot(_actor);
        if (!__battle_item_snapshot_is_berry(_snap)) return undefined;
        var _berry_name = (variable_struct_exists(_snap, "name") ? string_lower(string(variable_struct_get(_snap, "name"))) : "");
        if (string_length(_berry_name) <= 0 && variable_struct_exists(_snap, "id") && is_real(variable_struct_get(_snap, "id")) && variable_global_exists("_items") && is_array(global._items)){
            var _berry_id = floor(variable_struct_get(_snap, "id"));
            if (_berry_id > 0 && _berry_id < array_length(global._items)){
                var _berry_item = global._items[_berry_id];
                if (is_struct(_berry_item) && variable_struct_exists(_berry_item, "identifier")) _berry_name = string_lower(string(variable_struct_get(_berry_item, "identifier")));
            }
        }
        if (string_length(_berry_name) <= 0) return undefined;
        var _type_name = "";
        var _power = 0;
        switch (_berry_name){
            case "cheri-berry":
            case "occa-berry": _type_name = "fire"; _power = 80; break;
            case "bluk-berry": _type_name = "fire"; _power = 90; break;
            case "watmel-berry": _type_name = "fire"; _power = 100; break;
            case "chesto-berry":
            case "passho-berry": _type_name = "water"; _power = 80; break;
            case "nanab-berry": _type_name = "water"; _power = 90; break;
            case "durin-berry": _type_name = "water"; _power = 100; break;
            case "pecha-berry":
            case "wacan-berry": _type_name = "electric"; _power = 80; break;
            case "wepear-berry": _type_name = "electric"; _power = 90; break;
            case "belue-berry": _type_name = "electric"; _power = 100; break;
            case "rawst-berry":
            case "rindo-berry": _type_name = "grass"; _power = 80; break;
            case "pinap-berry": _type_name = "grass"; _power = 90; break;
            case "liechi-berry": _type_name = "grass"; _power = 100; break;
            case "aspear-berry":
            case "yache-berry": _type_name = "ice"; _power = 80; break;
            case "pomeg-berry": _type_name = "ice"; _power = 90; break;
            case "ganlon-berry": _type_name = "ice"; _power = 100; break;
            case "leppa-berry":
            case "chople-berry": _type_name = "fighting"; _power = 80; break;
            case "kelpsy-berry": _type_name = "fighting"; _power = 90; break;
            case "salac-berry": _type_name = "fighting"; _power = 100; break;
            case "oran-berry":
            case "kebia-berry": _type_name = "poison"; _power = 80; break;
            case "qualot-berry": _type_name = "poison"; _power = 90; break;
            case "petaya-berry": _type_name = "poison"; _power = 100; break;
            case "persim-berry":
            case "shuca-berry": _type_name = "ground"; _power = 80; break;
            case "hondew-berry": _type_name = "ground"; _power = 90; break;
            case "apicot-berry": _type_name = "ground"; _power = 100; break;
            case "lum-berry":
            case "coba-berry": _type_name = "flying"; _power = 80; break;
            case "grepa-berry": _type_name = "flying"; _power = 90; break;
            case "lansat-berry": _type_name = "flying"; _power = 100; break;
            case "sitrus-berry":
            case "payapa-berry": _type_name = "psychic"; _power = 80; break;
            case "tamato-berry": _type_name = "psychic"; _power = 90; break;
            case "starf-berry": _type_name = "psychic"; _power = 100; break;
            case "figy-berry":
            case "tanga-berry": _type_name = "bug"; _power = 80; break;
            case "cornn-berry": _type_name = "bug"; _power = 90; break;
            case "enigma-berry": _type_name = "bug"; _power = 100; break;
            case "wiki-berry":
            case "charti-berry": _type_name = "rock"; _power = 80; break;
            case "magost-berry": _type_name = "rock"; _power = 90; break;
            case "micle-berry": _type_name = "rock"; _power = 100; break;
            case "mago-berry":
            case "kasib-berry": _type_name = "ghost"; _power = 80; break;
            case "rabuta-berry": _type_name = "ghost"; _power = 90; break;
            case "custap-berry": _type_name = "ghost"; _power = 100; break;
            case "aguav-berry":
            case "haban-berry": _type_name = "dragon"; _power = 80; break;
            case "nomel-berry": _type_name = "dragon"; _power = 90; break;
            case "jaboca-berry": _type_name = "dragon"; _power = 100; break;
            case "iapapa-berry":
            case "colbur-berry": _type_name = "dark"; _power = 80; break;
            case "spelon-berry": _type_name = "dark"; _power = 90; break;
            case "rowap-berry": _type_name = "dark"; _power = 100; break;
            case "razz-berry":
            case "babiri-berry": _type_name = "steel"; _power = 80; break;
            case "pamtre-berry": _type_name = "steel"; _power = 90; break;
            case "chilan-berry": _type_name = "normal"; _power = 80; break;
        }
        if (string_length(_type_name) <= 0 || _power <= 0) return undefined;
        return { item_id: (variable_struct_exists(_snap, "id") ? variable_struct_get(_snap, "id") : -1), item_name: _berry_name, type_name: _type_name, type_id: __battle_type_id_from_name(_type_name), power: _power };
    }

    function __battle_set_ability_value(_actor, _ability_value, _ability_id_value){
        if (!is_struct(_actor)) return;
        variable_struct_set(_actor, "ability", _ability_value);
        if (is_real(_ability_id_value)) variable_struct_set(_actor, "ability_id", floor(_ability_id_value));
        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
            var _ability_mon = variable_struct_get(_actor, "mon");
            variable_struct_set(_ability_mon, "ability", _ability_value);
            if (is_real(_ability_id_value)) variable_struct_set(_ability_mon, "ability_id", floor(_ability_id_value));
        }
    }

    function __battle_try_apply_status_with_chance(_target, _status_id, _base_chance, _source){
        if (!is_struct(_target) || is_undefined(status_system_apply_status)) return false;
        var _chance = (is_real(_base_chance) ? clamp(floor(_base_chance), 0, 100) : 100);
        try {
            if (!is_undefined(__status_dev_override_chance)) _chance = __status_dev_override_chance(_status_id, _chance);
        } catch (e_status_override) {}
        if (_chance <= 0) return false;
        if (_chance < 100){
            var _roll = irandom(99);
            if (_roll >= _chance) return false;
        }
        try {
            return status_system_apply_status(_target, _status_id, { source: _source });
        } catch (e_status_apply) { return false; }
    }

    function __battle_magic_coat_can_reflect(_mid, _ident, _actor_idx, _target_idx){
        if (!is_real(_mid)) return false;
        var _is_status_move = false;
        try {
            if (!is_undefined(scr_move_damage_class_by_id) && is_real(_mid)) _is_status_move = (scr_move_damage_class_by_id(_mid) == 1);
        } catch (e_magic_dc) { _is_status_move = false; }
        if (!_is_status_move) return false;
        if (is_real(_actor_idx) && is_real(_target_idx) && floor(_actor_idx) == floor(_target_idx)) return false;
        var _ident_l = string_lower(string(_ident));
        return (_ident_l != "memento" && _ident_l != "magic-coat" && _ident_l != "snatch" && _ident_l != "teeter-dance" && _ident_l != "defog");
    }

    function __battle_snatch_can_steal(_mid, _ident, _actor_idx, _target_idx){
        if (!is_real(_mid)) return false;
        var _is_status_move = false;
        try {
            if (!is_undefined(scr_move_damage_class_by_id) && is_real(_mid)) _is_status_move = (scr_move_damage_class_by_id(_mid) == 1);
        } catch (e_snatch_dc) { _is_status_move = false; }
        if (!_is_status_move) return false;
        if (!(is_real(_actor_idx) && is_real(_target_idx) && floor(_actor_idx) == floor(_target_idx))) return false;
        var _ident_l = string_lower(string(_ident));
        var _deny = ["protect", "detect", "endure", "magic-coat", "snatch", "follow-me", "helping-hand", "splash", "teleport", "taunt", "torment", "embargo", "heal-block", "imprison", "assist", "metronome", "sleep-talk", "copycat", "mimic", "mirror-move", "sketch", "roar", "whirlwind"];
        for (var _sdi = 0; _sdi < array_length(_deny); ++_sdi){
            if (_deny[_sdi] == _ident_l) return false;
        }
        return true;
    }

    function __battle_terrain_power_family(_pid_in){
        var _terr_id = (!is_undefined(__battle_get_terrain_id) ? string_lower(string(__battle_get_terrain_id(_pid_in))) : "");
        switch (_terr_id){
            case "electric":
                return { nature_move_id: 85, secret_status: "paralysis" };
            case "grassy":
                return { nature_move_id: 412, secret_status: "sleep" };
            case "misty":
                return { nature_move_id: 585, secret_status: "confusion" };
            case "psychic":
                return { nature_move_id: 94, secret_status: "confusion" };
            default:
                return { nature_move_id: 161, secret_status: "confusion" };
        }
    }

    function __battle_roost_restore_actor(_actor){
        if (!is_struct(_actor) || !variable_struct_exists(_actor, "_roost_restore")) return;
        var _restore = variable_struct_get(_actor, "_roost_restore");
        if (!is_struct(_restore)) {
            variable_struct_set(_actor, "_roost_restore", undefined);
            return;
        }
        var _type1 = (variable_struct_exists(_restore, "type1") && is_real(variable_struct_get(_restore, "type1"))) ? variable_struct_get(_restore, "type1") : -1;
        var _type2 = (variable_struct_exists(_restore, "type2") && is_real(variable_struct_get(_restore, "type2"))) ? variable_struct_get(_restore, "type2") : -1;
        var _types = [];
        if (variable_struct_exists(_restore, "types") && is_array(variable_struct_get(_restore, "types"))) _types = variable_struct_get(_restore, "types");
        variable_struct_set(_actor, "type1", _type1);
        variable_struct_set(_actor, "type2", _type2);
        variable_struct_set(_actor, "types", _types);
        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
            var _restore_mon = variable_struct_get(_actor, "mon");
            variable_struct_set(_restore_mon, "type1", _type1);
            variable_struct_set(_restore_mon, "type2", _type2);
            variable_struct_set(_restore_mon, "types", _types);
        }
        variable_struct_set(_actor, "_roost_restore", undefined);
        variable_struct_set(_actor, "_roost_turn", undefined);
        variable_struct_set(_actor, "_roost_active", false);
    }

    function __battle_roost_apply_self(_actor, _turn_now_local){
        if (!is_struct(_actor)) return false;
        var _flying_id = undefined;
        var _normal_id = 0;
        try {
            if (variable_global_exists("TYPE_ID_BY_NAME")){
                var _type_map = variable_global_get("TYPE_ID_BY_NAME");
                if (ds_exists(_type_map, ds_type_map)){
                    _flying_id = ds_map_find_value(_type_map, "flying");
                    _normal_id = ds_map_find_value(_type_map, "normal");
                }
            }
        } catch (e_roost_type_map) { _flying_id = undefined; _normal_id = 0; }
        if (!is_real(_flying_id)) return false;

        var _type1 = (variable_struct_exists(_actor, "type1") && is_real(variable_struct_get(_actor, "type1"))) ? variable_struct_get(_actor, "type1") : -1;
        var _type2 = (variable_struct_exists(_actor, "type2") && is_real(variable_struct_get(_actor, "type2"))) ? variable_struct_get(_actor, "type2") : -1;
        var _types_src = [];
        if (variable_struct_exists(_actor, "types") && is_array(variable_struct_get(_actor, "types"))) _types_src = variable_struct_get(_actor, "types");

        var _has_flying = false;
        if (_type1 == _flying_id || _type2 == _flying_id) _has_flying = true;
        if (!_has_flying){
            for (var _rti = 0; _rti < array_length(_types_src); ++_rti){
                if (is_real(_types_src[_rti]) && _types_src[_rti] == _flying_id){ _has_flying = true; break; }
            }
        }

        if (variable_struct_exists(_actor, "_roost_restore") && is_struct(variable_struct_get(_actor, "_roost_restore"))){
            __battle_roost_restore_actor(_actor);
            _type1 = (variable_struct_exists(_actor, "type1") && is_real(variable_struct_get(_actor, "type1"))) ? variable_struct_get(_actor, "type1") : -1;
            _type2 = (variable_struct_exists(_actor, "type2") && is_real(variable_struct_get(_actor, "type2"))) ? variable_struct_get(_actor, "type2") : -1;
            _types_src = (variable_struct_exists(_actor, "types") && is_array(variable_struct_get(_actor, "types"))) ? variable_struct_get(_actor, "types") : [];
        }

        if (!_has_flying) return false;

        var _types_new = [];
        for (var _rj = 0; _rj < array_length(_types_src); ++_rj){
            var _tid = _types_src[_rj];
            if (is_real(_tid) && _tid != _flying_id) array_push(_types_new, _tid);
        }
        if (array_length(_types_new) <= 0){
            if (_type1 != _flying_id && is_real(_type1) && _type1 >= 0) array_push(_types_new, _type1);
            if (_type2 != _flying_id && is_real(_type2) && _type2 >= 0) array_push(_types_new, _type2);
        }
        if (array_length(_types_new) <= 0) array_push(_types_new, _normal_id);

        variable_struct_set(_actor, "_roost_restore", {
            type1: _type1,
            type2: _type2,
            types: _types_src
        });
        variable_struct_set(_actor, "_roost_turn", _turn_now_local);
        variable_struct_set(_actor, "_roost_active", true);
        variable_struct_set(_actor, "type1", _types_new[0]);
        variable_struct_set(_actor, "type2", (array_length(_types_new) > 1) ? _types_new[1] : -1);
        variable_struct_set(_actor, "types", _types_new);
        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
            var _roost_mon = variable_struct_get(_actor, "mon");
            variable_struct_set(_roost_mon, "type1", _types_new[0]);
            variable_struct_set(_roost_mon, "type2", (array_length(_types_new) > 1) ? _types_new[1] : -1);
            variable_struct_set(_roost_mon, "types", _types_new);
        }
        return true;
    }

    // item use shortcut (keeps prior behavior simple)
    if (is_struct(_step) && variable_struct_exists(_step, "item_use") && _step.item_use == true){
        var item_id = (variable_struct_exists(_step, "item_id") ? variable_struct_get(_step, "item_id") : undefined);
        var ball_mult = (variable_struct_exists(_step, "ball_mult") ? variable_struct_get(_step, "ball_mult") : undefined);
        var target_index = (variable_struct_exists(_step, "target_index") ? variable_struct_get(_step, "target_index") : undefined);
        var action_pid = _pid;
        if (variable_struct_exists(_step, "actor_index") && is_real(variable_struct_get(_step, "actor_index")) && !is_undefined(__battle_actor_owner_pid)){
            var _owner_pid = __battle_actor_owner_pid(_pid, variable_struct_get(_step, "actor_index"));
            if (is_real(_owner_pid) && _owner_pid >= 0) action_pid = floor(_owner_pid);
        }
        if (is_real(action_pid) && is_real(item_id) && item_id > 0 && !is_undefined(bag_inventory_remove_item)){
            bag_inventory_remove_item(action_pid, item_id, 1);
            if (!is_undefined(bags_seed_from_items)) bags_seed_from_items(action_pid);
        }

        var started_catch = false;
        if (!is_undefined(__battle_try_catch)) started_catch = __battle_try_catch(action_pid, ball_mult, item_id, target_index, action_pid);
        if (started_catch) return "";

        var disp = "item";
        if (!is_undefined(variable_global_exists) && variable_global_exists("_items") && is_array(global._items) && is_real(item_id) && item_id >= 0 && item_id < array_length(global._items)){
            var it = global._items[item_id]; if (is_struct(it) && variable_struct_exists(it, "name")) disp = string(variable_struct_get(it, "name"));
        }
        return "But nothing happened with " + string(disp) + ".";
    }

    var move_slot = (variable_struct_exists(_step, "slot") ? variable_struct_get(_step, "slot") : undefined);
    var move_id   = (variable_struct_exists(_step, "move_id") ? variable_struct_get(_step, "move_id") : undefined);
    try {
        if (is_struct(A) && is_real(move_slot)) variable_struct_set(A, "_last_selected_move_slot", move_slot);
    } catch (e_move_slot_stamp) {}

    // Status gate: prevent acting when frozen/asleep/etc. before consuming PP or applying meta moves.
    if (is_struct(A) && !is_undefined(__battle_check_can_act) && !(is_real(move_id) && (move_id == 173 || move_id == 214))){
        var _can_act = true;
        try { _can_act = __battle_check_can_act(A, move_id); } catch (e_can_act) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][gate] exception while checking actability: " + string(e_can_act));
            _can_act = true;
        }
        if (!_can_act){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                var _act_name = "actor";
                try { _act_name = string(__status_mon_display_name(A)); } catch (e_nm_gate) {}
                show_debug_message("[battle][status][gate] prevented action for " + _act_name + " (move_id=" + string(move_id) + ")");
            }
            return ""; // Message already queued by status system (freeze/sleep/etc.)
        }
    }

    var _is_protect_like = (is_real(move_id) && (move_id == 182 || move_id == 197));
    var _is_endure_like = (is_real(move_id) && move_id == 203);
    var _is_guard_like = (_is_protect_like || _is_endure_like);
    var _turn_now = 0;
    try {
        var _slot_turn = __battle_ensure_slot(_pid);
        if (is_struct(_slot_turn) && variable_struct_exists(_slot_turn, "turn_i")){
            _turn_now = max(0, floor(variable_struct_get(_slot_turn, "turn_i")));
        }
    } catch (e_turnp) { _turn_now = 0; }

    var _moveEntry = undefined;
    var _moveIdent = "";
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && is_real(move_id) && move_id >= 0 && move_id < array_length(global._moves)){
            _moveEntry = global._moves[move_id];
            if (is_struct(_moveEntry) && variable_struct_exists(_moveEntry, "identifier")){
                _moveIdent = string_lower(string(variable_struct_get(_moveEntry, "identifier")));
            }
        }
    } catch (e_moveIdent) { _moveEntry = undefined; _moveIdent = ""; }
    var _effect_id = undefined;
    try {
        if (is_struct(_moveEntry) && variable_struct_exists(_moveEntry, "effect_id") && is_real(variable_struct_get(_moveEntry, "effect_id"))) _effect_id = floor(variable_struct_get(_moveEntry, "effect_id"));
        if (!is_real(_effect_id) && !is_undefined(__battle_get_move_meta) && is_real(move_id)){
            var _eid_mm = __battle_get_move_meta(move_id);
            if (is_struct(_eid_mm) && variable_struct_exists(_eid_mm, "effect_id") && is_real(variable_struct_get(_eid_mm, "effect_id"))) _effect_id = floor(variable_struct_get(_eid_mm, "effect_id"));
        }
    } catch (e_effect_id) { _effect_id = undefined; }

    var _gravity_turns_active = 0;
    try { _gravity_turns_active = __battle_field_get_status_or(_pid, "gravity", 0); } catch (e_gravity_active) { _gravity_turns_active = 0; }

    try {
        if (is_real(_gravity_turns_active) && _gravity_turns_active > 0){
            var _gravity_deny = ["fly", "bounce", "jump-kick", "high-jump-kick", "splash", "telekinesis", "magnet-rise", "sky-drop"];
            for (var _gdi = 0; _gdi < array_length(_gravity_deny); ++_gdi){
                if (_moveIdent == _gravity_deny[_gdi]){
                    dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " can't use that move because of Gravity!");
                    return "";
                }
            }
        }
    } catch (e_gravity_gate) {}

    try {
        var _B_roost = __battle_ensure_slot(_pid);
        if (is_struct(_B_roost) && variable_struct_exists(_B_roost, "actor") && is_array(variable_struct_get(_B_roost, "actor"))){
            var _roost_actors = variable_struct_get(_B_roost, "actor");
            for (var _rai = 0; _rai < array_length(_roost_actors); ++_rai){
                var _roost_actor = _roost_actors[_rai];
                if (!is_struct(_roost_actor) || !variable_struct_exists(_roost_actor, "_roost_turn")) continue;
                var _roost_turn = variable_struct_get(_roost_actor, "_roost_turn");
                if (is_real(_roost_turn) && _turn_now > _roost_turn) __battle_roost_restore_actor(_roost_actor);
            }
        }
    } catch (e_roost_expire) {}

    if (is_struct(A) && is_real(move_id) && !is_undefined(status_system_has_status)){
        try {
            if (status_system_has_status(A, "heal-block")){
                var _hb_blocks_move = (move_id == 156);
                if (!_hb_blocks_move && !is_undefined(__battle_get_move_meta)){
                    var _hb_mm = __battle_get_move_meta(move_id);
                    if (is_struct(_hb_mm)){
                        if (variable_struct_exists(_hb_mm, "healing") && is_real(variable_struct_get(_hb_mm, "healing")) && real(variable_struct_get(_hb_mm, "healing")) > 0) _hb_blocks_move = true;
                        if (!_hb_blocks_move && variable_struct_exists(_hb_mm, "drain") && is_real(variable_struct_get(_hb_mm, "drain")) && real(variable_struct_get(_hb_mm, "drain")) > 0) _hb_blocks_move = true;
                    }
                }
                if (_hb_blocks_move){
                    var _hb_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The Pokémon");
                    dialog_queue(_hb_name + " is prevented from using healing moves!");
                    return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
                }
            }
        } catch (e_heal_block_gate) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][heal-block] gate failed: " + string(e_heal_block_gate));
        }
    }

    try {
        if (is_struct(D) && variable_struct_exists(D, "_magic_coat_turn") && variable_struct_get(D, "_magic_coat_turn") == _turn_now && __battle_magic_coat_can_reflect(move_id, _moveIdent, actor_idx, target_idx)){
            var _coat_name = (variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target");
            variable_struct_set(D, "_magic_coat_turn", undefined);
            variable_struct_set(D, "_magic_coat_active", false);
            D = A;
            target_idx = actor_idx;
            dialog_queue(_coat_name + " bounced the move back!");
        }
    } catch (e_magic_redirect) {}

    try {
        if (__battle_snatch_can_steal(move_id, _moveIdent, actor_idx, target_idx)){
            var _B_snatch = __battle_ensure_slot(_pid);
            if (is_struct(_B_snatch) && variable_struct_exists(_B_snatch, "actor") && is_array(variable_struct_get(_B_snatch, "actor"))){
                var _snatch_acts = variable_struct_get(_B_snatch, "actor");
                for (var _sai = 0; _sai < array_length(_snatch_acts); ++_sai){
                    var _snatcher = _snatch_acts[_sai];
                    if (!is_struct(_snatcher) || _snatcher == A) continue;
                    if (!variable_struct_exists(_snatcher, "_snatch_turn") || variable_struct_get(_snatcher, "_snatch_turn") != _turn_now) continue;
                    variable_struct_set(_snatcher, "_snatch_turn", undefined);
                    variable_struct_set(_snatcher, "_snatch_active", false);
                    A = _snatcher;
                    D = _snatcher;
                    actor_idx = _sai;
                    target_idx = _sai;
                    dialog_queue((variable_struct_exists(_snatcher, "name") ? string(variable_struct_get(_snatcher, "name")) : "The Pokémon") + " snatched the move!");
                    break;
                }
            }
        }
    } catch (e_snatch_redirect) {}

    try {
        if (is_struct(A) && variable_struct_exists(A, "_recharge_turn") && variable_struct_get(A, "_recharge_turn") == true){
            variable_struct_set(A, "_recharge_turn", false);
            variable_struct_set(A, "_recharge_move", undefined);
            dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " must recharge!");
            return "";
        }
    } catch (e_recharge_gate) {}

    if (is_struct(A) && is_real(move_id) && !is_undefined(status_system_has_status)){
        try {
            if (status_system_has_status(A, "torment")){
                var _last_torment_move = undefined;
                if (variable_struct_exists(A, "sys_last_move_used")) _last_torment_move = variable_struct_get(A, "sys_last_move_used");
                if (!is_real(_last_torment_move) && variable_struct_exists(A, "_last_move_dialog_id")) _last_torment_move = variable_struct_get(A, "_last_move_dialog_id");
                if (!is_real(_last_torment_move) && variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                    var _Amon = variable_struct_get(A, "mon");
                    if (variable_struct_exists(_Amon, "sys_last_move_used")) _last_torment_move = variable_struct_get(_Amon, "sys_last_move_used");
                    if (!is_real(_last_torment_move) && variable_struct_exists(_Amon, "_last_move_dialog_id")) _last_torment_move = variable_struct_get(_Amon, "_last_move_dialog_id");
                }
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][torment] last_move=" + string(_last_torment_move) + ", attempted=" + string(move_id));
                if (is_real(_last_torment_move) && _last_torment_move == move_id){
                    var _torment_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The Pokémon");
                    var _torment_move_name = _moveIdent;
                    if (string_length(_torment_move_name) <= 0) _torment_move_name = "that move";
                    else _torment_move_name = string_replace_all(_torment_move_name, "-", " ");
                    dialog_queue(_torment_name + " can't use " + _torment_move_name + " again due to Torment!");
                    return "";
                }
            }
        } catch (e_torment_gate) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][torment] gate failed: " + string(e_torment_gate));
        }
    }

    if (is_struct(A) && is_real(move_id) && !is_undefined(status_system_has_status)){
        try {
            var _taunt = (variable_struct_exists(A, "_taunt_state") ? variable_struct_get(A, "_taunt_state") : undefined);
            if (is_struct(_taunt) && variable_struct_exists(_taunt, "remaining") && is_real(variable_struct_get(_taunt, "remaining")) && variable_struct_get(_taunt, "remaining") > 0){
                var _is_status_move = false;
                if (!is_undefined(scr_move_damage_class_by_id) && is_real(move_id)) _is_status_move = (scr_move_damage_class_by_id(move_id) == 1);
                if (!_is_status_move){
                    var _taunt_power = 0;
                    try { _taunt_power = scr_move_power_by_id(move_id); } catch (e_taunt_power) { _taunt_power = 0; }
                    if (is_real(_taunt_power) && _taunt_power <= 0) _is_status_move = true;
                }
                if (_is_status_move && _effect_id != 176){
                    dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The Pokémon") + " can't use status moves after the taunt!");
                    return "";
                }
            }
        } catch (e_taunt_gate) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][taunt] gate failed: " + string(e_taunt_gate));
        }
    }

    if (is_struct(A)){
        if (!_is_guard_like){
            try { variable_struct_set(A, "sys_protect_streak", 0); } catch (e_rstreakA) {}
        }
        try {
            var _prot_turn = (variable_struct_exists(A, "sys_protected_turn") ? variable_struct_get(A, "sys_protected_turn") : undefined);
            if (is_real(_prot_turn) && _turn_now > _prot_turn){
                variable_struct_set(A, "sys_protected", false);
                variable_struct_set(A, "_protected", false);
                variable_struct_set(A, "sys_protected_turn", undefined);
            }
        } catch (e_prot_clearA) {}
        try {
            var _endure_turn = (variable_struct_exists(A, "sys_endure_turn") ? variable_struct_get(A, "sys_endure_turn") : undefined);
            if (is_real(_endure_turn) && _turn_now > _endure_turn){
                variable_struct_set(A, "sys_enduring", false);
                variable_struct_set(A, "_enduring", false);
                variable_struct_set(A, "sys_endure_turn", undefined);
            }
        } catch (e_endure_clearA) {}
        try {
            var _magic_turn = (variable_struct_exists(A, "_magic_coat_turn") ? variable_struct_get(A, "_magic_coat_turn") : undefined);
            if (is_real(_magic_turn) && _turn_now > _magic_turn){
                variable_struct_set(A, "_magic_coat_turn", undefined);
                variable_struct_set(A, "_magic_coat_active", false);
            }
        } catch (e_magic_clearA) {}
        try {
            if (variable_struct_exists(A, "_grudge_active") && variable_struct_get(A, "_grudge_active") == true){
                variable_struct_set(A, "_grudge_active", false);
            }
        } catch (e_grudge_clearA) {}
        try {
            var _snatch_turn = (variable_struct_exists(A, "_snatch_turn") ? variable_struct_get(A, "_snatch_turn") : undefined);
            if (is_real(_snatch_turn) && _turn_now > _snatch_turn){
                variable_struct_set(A, "_snatch_turn", undefined);
                variable_struct_set(A, "_snatch_active", false);
            }
        } catch (e_snatch_clearA) {}

        var _disableExpireA = undefined;
        var _disableActiveA = false;
        var _disableNotifiedA = false;
        try { if (variable_struct_exists(A, "sys_disabledExpiresTurn")) _disableExpireA = variable_struct_get(A, "sys_disabledExpiresTurn"); } catch (e_expA) {}
        try { if (variable_struct_exists(A, "sys_disabledActive")) _disableActiveA = (variable_struct_get(A, "sys_disabledActive") == true); } catch (e_actA) { _disableActiveA = false; }
        try { if (variable_struct_exists(A, "sys_disabled_notified_clear")) _disableNotifiedA = (variable_struct_get(A, "sys_disabled_notified_clear") == true); } catch (e_notA) { _disableNotifiedA = false; }
        if (is_real(_disableExpireA) && _disableActiveA){
            if (_turn_now >= _disableExpireA){
                if (!_disableNotifiedA){
                    var _aname_clear = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The Pokémon");
                    dialog_queue(_aname_clear + " is no longer disabled!");
                }
                __battle_clear_disable(A);
            } else {
                var _remainingA = max(0, _disableExpireA - _turn_now);
                try { variable_struct_set(A, "sys_disabledTurns", _remainingA); } catch (e_remA) {}
                try { variable_struct_set(A, "sys_disabled_notified_clear", false); } catch (e_notResetA) {}
            }
        } else if (!_disableActiveA){
            __battle_clear_disable(A);
        }
    }

    // Sky Drop hold: actors being carried cannot act until the carrier releases them.
    try {
        if (is_struct(A) && variable_struct_exists(A, "_sky_drop_held") && variable_struct_get(A, "_sky_drop_held") == true){
            var _still_held = false;
            try {
                if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                    var _acts_sd = variable_struct_get(_B, "actor");
                    for (var _sdi = 0; _sdi < array_length(_acts_sd); ++_sdi){
                        var _carrier = _acts_sd[_sdi];
                        if (!is_struct(_carrier) || _carrier == A) continue;
                        if (!variable_struct_exists(_carrier, "_charging_move")) continue;
                        var _car_info = variable_struct_get(_carrier, "_charging_move");
                        if (!is_struct(_car_info)) continue;
                        if (!variable_struct_exists(_car_info, "sky_drop") || variable_struct_get(_car_info, "sky_drop") != true) continue;
                        var _tref_sd = undefined;
                        if (variable_struct_exists(_car_info, "target_actor")) _tref_sd = variable_struct_get(_car_info, "target_actor");
                        if (is_struct(_tref_sd) && _tref_sd == A){ _still_held = true; break; }
                        if (!is_struct(_tref_sd) && variable_struct_exists(_car_info, "target_index") && variable_struct_exists(A, "actor_index")){
                            var _ti_sd = variable_struct_get(_car_info, "target_index");
                            var _ai_sd = variable_struct_get(A, "actor_index");
                            if (is_real(_ti_sd) && is_real(_ai_sd) && _ti_sd == _ai_sd){ _still_held = true; break; }
                        }
                    }
                }
            } catch (e_sdchk) { _still_held = false; }
            if (!_still_held){
                try { variable_struct_set(A, "_sky_drop_held", undefined); } catch (e_sdclr1) {}
                try { if (variable_struct_exists(A, "_semi_invuln")) variable_struct_set(A, "_semi_invuln", undefined); } catch (e_sdclr2) {}
            } else {
                var _held_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The target");
                dialog_queue(_held_name + " is trapped in the air!");
                return "";
            }
        }
    } catch (e_sdh) {}

    // Helper: simple identifier-based ignore list used by metronome/assist/etc.
    function __is_meta_move_ignored(_mid){
        try {
            if (!is_real(_mid)) return true;
            if (!variable_global_exists("_moves") || !is_array(global._moves)) return true;
            var mv = global._moves[_mid];
            if (!is_struct(mv)) return true;
            var ident = "";
            if (variable_struct_exists(mv, "identifier")) ident = string(variable_struct_get(mv, "identifier"));
            ident = string_lower(ident);
            var ignore_ids = ["assist","metronome","sleep-talk","copycat","mimic","mirror-move","mirror-coat","sketch","me-first","protect","snatch","switcheroo","trick","struggle","encore","follow-me","quick-guard","feint","focus-punch","counter","covet","destiny-bond","detect","endure","chatter","helping-hand","thief","wide-guard","roar","whirlwind","uproar"];
            for (var ii=0; ii<array_length(ignore_ids); ++ii) if (string_lower(ignore_ids[ii]) == ident) return true;
            return false;
        } catch (e_i) { return true; }
    }

    // === META MOVES IMPLEMENTATION ===
    try {
    // METRONOME (118): select a random non-meta move from the global move list
        if (is_real(move_id) && move_id == 118){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var candidates = [];
            if (variable_global_exists("_moves") && is_array(global._moves)){
                for (var mi=0; mi<array_length(global._moves); ++mi){
                    if (!is_struct(global._moves[mi])) continue;
                    // Skip invalid entries and our ignore list
                    if (__is_meta_move_ignored(mi)) continue;
                    // Skip moves the user already knows (Metronome must pick a move the user doesn't already have)
                    try {
                        if (is_struct(A) && variable_struct_exists(A, "moves") && is_array(variable_struct_get(A, "moves"))){
                            var _am = variable_struct_get(A, "moves");
                            var _known = false;
                            for (var _ki = 0; _ki < array_length(_am); ++_ki){ if (is_real(_am[_ki]) && _am[_ki] == mi) { _known = true; break; } }
                            if (_known) continue;
                        }
                    } catch (e_k) { /* defensive: ignore and continue */ }
                    // Skip moves with no identifier/name
                    var ok = true;
                    try { if (!variable_struct_exists(global._moves[mi], "identifier")) ok = false; } catch (e_ok) { ok = false; }
                    if (!ok) continue;
                    array_push(candidates, mi);
                }
            }
        if (array_length(candidates) == 0) return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " failed to use Metronome!";
            var pick = candidates[irandom(array_length(candidates)-1)];
            // Announce and replay the picked move
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_sup) {}
            try { __battle_request_animation_safe(A, { type: "metronome" }); } catch (e_ma) {}
            __battle_apply_called_move(_pid, A, D, move_id, pick);
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_sup2) {}
            return "";
        }

        // ASSIST (274): pick a random move known by an ally (other actors in the same slot)
    if (is_real(move_id) && move_id == 274){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var _Bslot = __battle_ensure_slot(_pid);
            var ally_moves = [];
            try {
                if (is_struct(_Bslot) && variable_struct_exists(_Bslot, "actor") && is_array(variable_struct_get(_Bslot, "actor"))){
                    var acts = variable_struct_get(_Bslot, "actor");
                    for (var ai=0; ai<array_length(acts); ++ai){
                        var act = acts[ai];
                        if (!is_struct(act)) continue;
                        if (act == A) continue; // skip self
                        if (is_real(variable_struct_get(act, "hp_now")) && variable_struct_get(act, "hp_now") <= 0) continue; // fainted
                        if (!variable_struct_exists(act, "moves") || !is_array(variable_struct_get(act, "moves"))) continue;
                        var mlist = variable_struct_get(act, "moves");
                        for (var mi2=0; mi2<array_length(mlist); ++mi2){ var mv = mlist[mi2]; if (is_real(mv) && !__is_meta_move_ignored(mv)) array_push(ally_moves, mv); }
                    }
                }
            } catch (e_as) { ally_moves = []; }
            if (array_length(ally_moves) == 0) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            var pick2 = ally_moves[irandom(array_length(ally_moves)-1)];
        try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_sup3) {}
            __battle_apply_called_move(_pid, A, D, move_id, pick2);
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_sup4) {}
            return "";
        }

        // MIMIC (102): copy the last move used by the target (if valid)
    if (is_real(move_id) && move_id == 102){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var cand = undefined;
            try {
                if (is_struct(D) && variable_struct_exists(D, "_last_moves") && is_array(variable_struct_get(D, "_last_moves"))){
                    var lr = variable_struct_get(D, "_last_moves");
                    for (var ii=array_length(lr)-1; ii>=0; --ii){ var rec = lr[ii]; if (!is_struct(rec) || !variable_struct_exists(rec, "move")) continue; var mv = rec.move; if (!is_real(mv)) continue; if (__is_meta_move_ignored(mv)) continue; cand = mv; break; }
                }
            } catch (e_mi) { cand = undefined; }
            if (!is_real(cand)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_su) {}
            __battle_apply_called_move(_pid, A, D, move_id, cand);
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_su2) {}
            return "";
        }

        // MIRROR-MOVE (119): use the last move that targeted this user (if available)
    if (is_real(move_id) && move_id == 119){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var cand2 = undefined;
            try {
                if (is_struct(A) && variable_struct_exists(A, "_last_moves") && is_array(variable_struct_get(A, "_last_moves"))){
                    var lr2 = variable_struct_get(A, "_last_moves");
                    for (var jj=array_length(lr2)-1; jj>=0; --jj){ var rec2 = lr2[jj]; if (!is_struct(rec2) || !variable_struct_exists(rec2, "move")) continue; var mv2 = rec2.move; if (!is_real(mv2)) continue; if (__is_meta_move_ignored(mv2)) continue; cand2 = mv2; break; }
                }
            } catch (e_mm2) { cand2 = undefined; }
            if (!is_real(cand2)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_su3) {}
            __battle_apply_called_move(_pid, A, D, move_id, cand2);
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_su4) {}
            return "";
        }

        // SKETCH (166): permanently replace the user's selected move slot with the target's last used move
        if (is_real(move_id) && move_id == 166){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            if (!is_struct(A) || !is_real(move_slot)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            var sketch_cand = undefined;
            try {
                if (is_struct(D) && variable_struct_exists(D, "_last_moves") && is_array(variable_struct_get(D, "_last_moves"))){
                    var lr3 = variable_struct_get(D, "_last_moves");
                    for (var kk=array_length(lr3)-1; kk>=0; --kk){ var rec3 = lr3[kk]; if (!is_struct(rec3) || !variable_struct_exists(rec3, "move")) continue; var mv3 = rec3.move; if (!is_real(mv3)) continue; if (__is_meta_move_ignored(mv3)) continue; sketch_cand = mv3; break; }
                }
            } catch (e_sk) { sketch_cand = undefined; }
            if (!is_real(sketch_cand)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            // Replace the move in the user's moves array at slot
            try {
                if (!variable_struct_exists(A, "moves") || !is_array(variable_struct_get(A, "moves"))) variable_struct_set(A, "moves", []);
                var _alist = variable_struct_get(A, "moves");
                if (is_real(move_slot) && move_slot >= 0){
                    // Expand if necessary
                    while (array_length(_alist) <= move_slot) array_push(_alist, -1);
                    _alist[move_slot] = sketch_cand;
                    variable_struct_set(A, "moves", _alist);
                    try { __battle_request_animation_safe(A, { type: "sketch" }); } catch (e_sa) {}
                    return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " sketched " + __battle_move_name(sketch_cand) + "!";
                }
            } catch (e_rep) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sketch] failed: " + string(e_rep)); }
            return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
        }

        // TRANSFORM (144): make the user copy the target's form/stats/moves roughly
        if (is_real(move_id) && move_id == 144){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            try {
                if (!is_struct(A) || !is_struct(D)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
                // Shallow copy of D.mon into A._transformed_mon so the renderer/logic can use it
                var srcmon = (variable_struct_exists(D, "mon") ? variable_struct_get(D, "mon") : undefined);
                if (is_struct(srcmon)){
                        // store original mon for revert if needed and assign transform mon reference
                        try { variable_struct_set(A, "_original_mon", (variable_struct_exists(A, "mon") ? variable_struct_get(A, "mon") : undefined)); } catch (e_om) {}
                        try { variable_struct_set(A, "mon", srcmon); } catch (e_setm) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][transform] warning: failed to set reference mon: " + string(e_setm)); }
                    variable_struct_set(A, "_transformed", true);
                    try { __battle_request_animation_safe(A, { type: "transform" }); } catch (e_tf) {}
                    return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " transformed into " + string(variable_struct_exists(D, "name") ? variable_struct_get(D, "name") : "the target") + "!";
                }
            } catch (e_t) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][transform] failed: " + string(e_t)); }
            return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
        }

        // ME-FIRST (382): attempt to use the target's move immediately when it is a damaging move
        if (is_real(move_id) && move_id == 382){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var mf = undefined;
            try {
                // Prefer to inspect target's _last_moves for their most recent chosen move
                if (is_struct(D) && variable_struct_exists(D, "_last_moves") && is_array(variable_struct_get(D, "_last_moves"))){
                    var lr4 = variable_struct_get(D, "_last_moves");
                    for (var zz=array_length(lr4)-1; zz>=0; --zz){ var r4 = lr4[zz]; if (!is_struct(r4) || !variable_struct_exists(r4, "move")) continue; var mv4 = r4.move; if (!is_real(mv4)) continue; if (__is_meta_move_ignored(mv4)) continue; mf = mv4; break; }
                }
            } catch (e_mf) { mf = undefined; }
            if (!is_real(mf)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_su5) {}
            __battle_apply_called_move(_pid, A, D, move_id, mf);
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_su6) {}
            return __battle_impl_return_used(_pid, A, __battle_move_name(mf), mf);
        }

        // COPYCAT (383): reuse the most recent move used in battle when available
        if (is_real(move_id) && move_id == 383){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var _copied = __battle_find_copycat_candidate(_pid, A);
            if (is_real(_copied) && _copied == move_id) _copied = undefined;
            if (!is_real(_copied)){
                dialog_queue(string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " failed to Copycat!");
                return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            }
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_surp) {}
            __battle_apply_called_move(_pid, A, D, move_id, _copied);
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_surp2) {}
            return "";
        }

        // SUBSTITUTE (164): spend 1/4 max HP to create a decoy that absorbs direct move damage
        if (is_real(move_id) && move_id == 164){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            __battle_record_move_usage(_pid, A, D, move_id, false);
            var _sub_used_msg = __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            if (!is_struct(A)) return _sub_used_msg;
            var _sub_hp_now = max(0, __battle_hp_now(A));
            var _sub_hp_max = max(1, __battle_hp_max(A));
            var _sub_cost = max(1, floor(_sub_hp_max / 4));
            var _already_sub = false;
            try { if (!is_undefined(status_system_has_status)) _already_sub = status_system_has_status(A, "substitute"); } catch (e_sub_has) { _already_sub = false; }
            if (_already_sub || _sub_hp_now <= _sub_cost){
                dialog_queue("But it failed!");
                return _sub_used_msg;
            }
            __battle_set_hp_now(A, _sub_hp_now - _sub_cost);
            var _sub_ok = false;
            try {
                if (!is_undefined(status_system_apply_status)) _sub_ok = status_system_apply_status(A, "substitute", { source: A });
                if (_sub_ok && !is_undefined(status_system_get)){
                    var _sub_inst = status_system_get(A, "substitute");
                    if (is_struct(_sub_inst)){
                        variable_struct_set(_sub_inst, "hp", _sub_cost);
                        variable_struct_set(_sub_inst, "hp_max", _sub_cost);
                    }
                }
            } catch (e_sub_apply) { _sub_ok = false; }
            if (_sub_ok){
                try { __battle_request_animation_safe(A, { type: "substitute" }); } catch (e_sub_anim) {}
                var _sub_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user");
                dialog_queue(_sub_name + " made a substitute!");
            } else {
                __battle_set_hp_now(A, _sub_hp_now);
                dialog_queue("But it failed!");
            }
            return _sub_used_msg;
        }

        // HEAL BELL / AROMATHERAPY (effect 103): clear major status and confusion on the user's side party
        if (is_real(move_id) && (move_id == 215 || move_id == 312)){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            __battle_record_move_usage(_pid, A, D, move_id, false);
            var _heal_party_used_msg = __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            var _clear_ids = ["sleep", "freeze", "burn", "poison", "toxic", "paralysis", "paralyze", "confusion"];
            var _side_idx = 0;
            try {
                if (is_struct(A) && variable_struct_exists(A, "actor_index") && is_real(variable_struct_get(A, "actor_index"))) _side_idx = __battle_field_side_index_for_actor(variable_struct_get(A, "actor_index"));
            } catch (e_hpside) { _side_idx = 0; }
            var _cleared_any = false;
            var _clear_statuses_on_mon = function(_mon_ref){
                var _did_any = false;
                if (!is_struct(_mon_ref) || is_undefined(status_system_clear_status)) return false;
                for (var _ci = 0; _ci < array_length(_clear_ids); ++_ci){
                    try {
                        if (status_system_clear_status(_mon_ref, _clear_ids[_ci])) _did_any = true;
                    } catch (e_hclear) {}
                }
                return _did_any;
            };
            try {
                var _Bslot_hp = __battle_ensure_slot(_pid);
                if (is_struct(_Bslot_hp) && variable_struct_exists(_Bslot_hp, "actor") && is_array(variable_struct_get(_Bslot_hp, "actor"))){
                    var _acts_hp = variable_struct_get(_Bslot_hp, "actor");
                    for (var _ai_hp = 0; _ai_hp < array_length(_acts_hp); ++_ai_hp){
                        var _act_hp = _acts_hp[_ai_hp];
                        if (!is_struct(_act_hp)) continue;
                        var _act_side = __battle_field_side_index_for_actor(_ai_hp);
                        if (_act_side != _side_idx) continue;
                        if (_clear_statuses_on_mon(_act_hp)) _cleared_any = true;
                    }
                }
            } catch (e_hacts) {}
            try {
                if (_side_idx == 0){
                    var _party_mons = party_model_get_mons(_pid);
                    if (is_array(_party_mons)){
                        for (var _pm = 0; _pm < array_length(_party_mons); ++_pm){
                            if (_clear_statuses_on_mon(_party_mons[_pm])) _cleared_any = true;
                        }
                    }
                } else {
                    var _Bslot_enemy = __battle_ensure_slot(_pid);
                    if (is_struct(_Bslot_enemy) && variable_struct_exists(_Bslot_enemy, "_trainer_party") && is_array(variable_struct_get(_Bslot_enemy, "_trainer_party"))){
                        var _tparty = variable_struct_get(_Bslot_enemy, "_trainer_party");
                        for (var _tp = 0; _tp < array_length(_tparty); ++_tp){
                            if (_clear_statuses_on_mon(_tparty[_tp])) _cleared_any = true;
                        }
                    }
                }
            } catch (e_hparty) {}
            try {
                if (move_id == 215) dialog_queue("A bell chimed!");
                else dialog_queue("A soothing aroma wafted through the area!");
                if (_cleared_any) dialog_queue("The party's status was healed!");
            } catch (e_hmsg) {}
            return _heal_party_used_msg;
        }

        if (is_real(move_id) && move_id == 287){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            __battle_record_move_usage(_pid, A, D, move_id, false);
            var _refresh_used_msg = __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            var _refresh_cleared = false;
            var _refresh_ids = ["sleep", "freeze", "burn", "poison", "toxic", "paralysis", "paralyze"];
            if (is_struct(A) && !is_undefined(status_system_clear_status)){
                for (var _rf = 0; _rf < array_length(_refresh_ids); ++_rf){
                    try { if (status_system_clear_status(A, _refresh_ids[_rf])) _refresh_cleared = true; } catch (e_refresh_clear) {}
                }
                try {
                    if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                        var _refresh_mon = variable_struct_get(A, "mon");
                        for (var _rfm = 0; _rfm < array_length(_refresh_ids); ++_rfm){
                            try { if (status_system_clear_status(_refresh_mon, _refresh_ids[_rfm])) _refresh_cleared = true; } catch (e_refresh_clear_mon) {}
                        }
                    }
                } catch (e_refresh_mon_outer) {}
            }
            if (_refresh_cleared){
                dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " refreshed itself!");
            } else {
                dialog_queue("But it failed!");
            }
            return _refresh_used_msg;
        }
    } catch (e_metaAll) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta_moves] handler error: " + string(e_metaAll)); }

    // Debug: log selection immediately so we can trace Horn Drill choices
    try {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            // Debug-only: log to console rather than opening a player dialog
            try { show_debug_message("[battle_select][debug] pid=" + string(_pid) + ", slot=" + string(move_slot) + ", mv_selected=" + string(move_id) + ", actor.moves[slot]=" + string((is_struct(A) && is_array(variable_struct_get(A, "moves")) && is_real(move_slot) && move_slot >=0 && move_slot < array_length(variable_struct_get(A, "moves")) ? variable_struct_get(A, "moves")[move_slot] : "?")) ); } catch (e_sd) {}
        }
    } catch (e_dbgsel) {}

    // Record per-target last-move for Copycat's reference. Some move impls
    // bypass __battle_apply_move; we therefore record here centrally so
    // Copycat can find moves regardless of which low-level path was used.
    try {
        var _suppress = false;
        try { if (is_struct(A) && variable_struct_exists(A, "_suppress_last_move_record") && variable_struct_get(A, "_suppress_last_move_record") == true) _suppress = true; } catch (e_sp) { _suppress = false; }
        // Only record when we have an attacker and defender, move_id is real,
        // it's not a Copycat meta-move, and suppression isn't active.
        if (!_suppress && is_struct(A) && is_struct(D) && is_real(move_id)){
            var skip_rec = false;
            try { if (is_array(global._moves) && is_struct(global._moves[move_id]) && variable_struct_exists(global._moves[move_id], "identifier") && string_lower(variable_struct_get(global._moves[move_id], "identifier")) == "copycat") skip_rec = true; } catch (e_sr) { skip_rec = false; }
            if (!skip_rec){
                try {
                    if (!variable_struct_exists(D, "_last_moves") || !is_array(variable_struct_get(D, "_last_moves"))) variable_struct_set(D, "_last_moves", []);
                    var _arr = variable_struct_get(D, "_last_moves");
                    array_push(_arr, { move: move_id, src: A, ts: current_time });
                    if (array_length(_arr) > 8){ var _start = array_length(_arr) - 8; var _new = []; for (var _k=_start; _k < array_length(_arr); ++_k) array_push(_new, _arr[_k]); _arr = _new; }
                    variable_struct_set(D, "_last_moves", _arr);
                    // Keep the global scalar in sync for the simple Copycat implementation
                    try { global.lastMoveUsed_ID = move_id; } catch (e_g) {}
                    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][record_last_move][impl] target=" + string(variable_struct_exists(D, "name") ? variable_struct_get(D, "name") : "?") + " move=" + string(move_id) + " src=" + string(variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "?") + " ts=" + string(current_time) + " (global.lastMoveUsed_ID set)");
                } catch (e_r) { if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][record_last_move][impl] failed: " + string(e_r)); }
            }
        }
    } catch (e_allrec) { if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][record_last_move][impl] outer error: " + string(e_allrec)); }

    // minimal status check to avoid crashes during refactor
    try {
        if (!is_undefined(status_system_has_status) && is_struct(A) && status_system_has_status(A, "sleep") && !(is_real(move_id) && (move_id == 173 || move_id == 214))){
            // Request blocked animation, but do NOT enqueue another dialog because
            // status_system_apply_status already queues the canonical 'fell asleep!'
            __battle_request_animation_safe(A, { type: "status_blocked", status: "sleep" });
            return "";
        }
    } catch (e) { }

    // flinch: if the actor was flinched by a previous hit, they lose their turn
    try {
        if (is_struct(A) && variable_struct_exists(A, "_flinched") && variable_struct_get(A, "_flinched") == true){
            // Debug: report pre-clear state
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                try {
                    var _an = (variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"<no-name>");
                    var _has_wrap = variable_struct_exists(A, "_flinched") && variable_struct_get(A, "_flinched") == true;
                    var _inner_has = false;
                    if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                        var _inner_m = variable_struct_get(A, "mon");
                        _inner_has = (variable_struct_exists(_inner_m, "_flinched") && variable_struct_get(_inner_m, "_flinched") == true);
                    }
                    show_debug_message("[battle][flinch][exec] pre-clear actor='"+string(_an)+"' wrapper_flag="+string(_has_wrap)+" inner_flag="+string(_inner_has));
                } catch (e_dbgp) {}
            }
            // clear the flag and show a flinch animation/dialog
            try { variable_struct_set(A, "_flinched", undefined); } catch (e_fclr) {}
            // also clear inner mon flag if present
            try {
                if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                    var _inner_m2 = variable_struct_get(A, "mon");
                    try { variable_struct_set(_inner_m2, "_flinched", undefined); } catch (e_ic) {}
                }
            } catch (e_in2) {}
            try { __battle_request_animation_safe(A, { type: "flinch" }); } catch (e_fa) {}
            try { dialog2p_show_now(_pid, string(variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user") + " flinched!"); } catch (e_fd) {}
            // Debug: report post-clear state
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                try {
                    var _an2 = (variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"<no-name>");
                    var _has_wrap2 = (variable_struct_exists(A, "_flinched") && variable_struct_get(A, "_flinched") == true);
                    var _inner_has2 = false;
                    if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                        var _inner_m3 = variable_struct_get(A, "mon");
                        _inner_has2 = (variable_struct_exists(_inner_m3, "_flinched") && variable_struct_get(_inner_m3, "_flinched") == true);
                    }
                    show_debug_message("[battle][flinch][exec] post-clear actor='"+string(_an2)+"' wrapper_flag="+string(_has_wrap2)+" inner_flag="+string(_inner_has2));
                } catch (e_dbg2) {}
            }
            return "";
        }
    } catch (e_fl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][flinch] check failed: " + string(e_fl)); }

    // Prevent the actor from selecting a move that is currently disabled.
    var _disabledMoveA = undefined;
    try { if (is_struct(A) && variable_struct_exists(A, "sys_disabledMove")) _disabledMoveA = variable_struct_get(A, "sys_disabledMove"); } catch (e_dmA) { _disabledMoveA = undefined; }
    if (is_real(_disabledMoveA) && is_real(move_id) && _disabledMoveA == move_id){
        var _aname_disable_block = (is_struct(A) && variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user");
        dialog_queue(_aname_disable_block + " is disabled and can't use that move!");
        return "";
    }

    // check for Imprison on the target slot: if target slot has an _imprisoned map/list and it contains this move, fail
    try {
        var _slot_check = __battle_ensure_slot(_pid);
        if (is_struct(_slot_check) && variable_struct_exists(_slot_check, "_imprisoned")){
            var _imap = variable_struct_get(_slot_check, "_imprisoned");
            var imprisoned = false;
            // check string-keyed map at _map
            if (is_struct(_imap) && variable_struct_exists(_imap, "_map") && is_struct(variable_struct_get(_imap, "_map"))){
                var _smap = variable_struct_get(_imap, "_map");
                if (variable_struct_exists(_smap, string(move_id))) imprisoned = true;
            }
            // check numeric list at _list
            if (!imprisoned && is_struct(_imap) && variable_struct_exists(_imap, "_list") && is_array(variable_struct_get(_imap, "_list"))){
                var _slist = variable_struct_get(_imap, "_list");
                for (var _li = 0; _li < array_length(_slist); _li++){ if (is_real(_slist[_li]) && _slist[_li] == move_id){ imprisoned = true; break; } }
            }
            if (imprisoned){ try { __battle_request_animation_safe(A, { type: "blocked", reason: "imprison" }); } catch (e_blk2) {} return ""; }
        }
    } catch (e_ic) { }

    if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);

    var mv_name = (is_undefined(move_id) ? "the move" : __battle_move_name(move_id));
    if (is_real(move_id) && move_id == 100){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _teleport_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _teleport_slot = __battle_ensure_slot(_pid);
        var _teleport_mode = "wild";
        try {
            if (is_struct(_teleport_slot) && variable_struct_exists(_teleport_slot, "_battle_mode")){
                _teleport_mode = string_lower(string(variable_struct_get(_teleport_slot, "_battle_mode")));
            }
        } catch (e_tp_mode) { _teleport_mode = "wild"; }
        if (_teleport_mode != "trainer"){
            try { variable_struct_set(_teleport_slot, "result", "escaped"); } catch (e_tp_result) {}
            try { variable_struct_set(_teleport_slot, "_pending_close", true); } catch (e_tp_close) {}
            dialog_queue("Got away safely!");
        } else {
            dialog_queue("But it failed!");
        }
        return _teleport_used_msg;
    }
    if (is_real(move_id) && (move_id == 248 || move_id == 353)){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _future_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _future_power = 0;
        var _future_damage = 0;
        try { _future_power = __battle_move_power(move_id, A, D); } catch (e_fs_power) { _future_power = 0; }
        try { _future_damage = __battle_calc_damage(A, D, move_id, max(1, _future_power)); } catch (e_fs_damage) { _future_damage = 0; }
        if (!is_real(_future_damage) || _future_damage <= 0) _future_damage = max(1, _future_power);
        var _queued_future = false;
        try {
            if (!is_undefined(__battle_queue_delayed_hit)){
                _queued_future = __battle_queue_delayed_hit(_pid, {
                    move_id: move_id,
                    actor_index: actor_idx,
                    source_side: actor_idx,
                    target_index: target_idx,
                    turns_remaining: 3,
                    damage: max(1, floor(_future_damage))
                });
            }
        } catch (e_fs_queue) { _queued_future = false; }
        if (_queued_future) dialog_queue((move_id == 248) ? "Future Sight was set!" : "Doom Desire was set!");
        else dialog_queue("But it failed!");
        return _future_used_msg;
    }
    if (is_real(move_id) && (move_id == 18 || move_id == 46)){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _phase_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _phase_slot = __battle_ensure_slot(_pid);
        var _phase_mode = "wild";
        try {
            if (is_struct(_phase_slot) && variable_struct_exists(_phase_slot, "_battle_mode")) _phase_mode = string_lower(string(variable_struct_get(_phase_slot, "_battle_mode")));
        } catch (e_phase_mode) { _phase_mode = "wild"; }
        if (_phase_mode != "trainer"){
            try { variable_struct_set(_phase_slot, "result", "escaped"); } catch (e_phase_result) {}
            try { variable_struct_set(_phase_slot, "_pending_close", true); } catch (e_phase_close) {}
            dialog_queue("Got away safely!");
        } else if (actor_idx == 0 && is_struct(_phase_slot) && !is_undefined(__battle_trainer_next_alive_index) && !is_undefined(__battle_trainer_perform_switch_action)){
            var _phase_next = -1;
            try { _phase_next = __battle_trainer_next_alive_index(_phase_slot, (variable_struct_exists(_phase_slot, "_trainer_party_active_idx") ? variable_struct_get(_phase_slot, "_trainer_party_active_idx") : -1)); } catch (e_phase_next) { _phase_next = -1; }
            if (is_real(_phase_next) && _phase_next >= 0){
                try { __battle_trainer_perform_switch_action(_pid, _phase_next, { move_id: move_id, forced: true }); } catch (e_phase_sw) { dialog_queue("But it failed!"); }
            } else {
                dialog_queue("But it failed!");
            }
        } else {
            dialog_queue("But it failed!");
        }
        return _phase_used_msg;
    }
    if (is_real(move_id) && move_id == 150){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _splash_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        dialog_queue("But nothing happened!");
        return _splash_used_msg;
    }
    if (is_real(move_id) && move_id == 117){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _bide_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _bide_state = (is_struct(A) && variable_struct_exists(A, "_bide_state")) ? variable_struct_get(A, "_bide_state") : undefined;
        if (is_struct(_bide_state) && variable_struct_exists(_bide_state, "remaining") && is_real(variable_struct_get(_bide_state, "remaining"))){
            var _bide_remaining = max(0, floor(variable_struct_get(_bide_state, "remaining")) - 1);
            variable_struct_set(_bide_state, "remaining", _bide_remaining);
            if (_bide_remaining <= 0){
                var _bide_damage = (variable_struct_exists(_bide_state, "damage") && is_real(variable_struct_get(_bide_state, "damage"))) ? floor(variable_struct_get(_bide_state, "damage")) : 0;
                variable_struct_set(A, "_bide_state", undefined);
                if (_bide_damage > 0 && is_struct(D)){
                    __battle_apply_damage(_pid, target_idx, max(1, _bide_damage * 2), 1.0);
                    dialog_queue((is_struct(A) && variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " unleashed energy!");
                } else {
                    dialog_queue("But it failed!");
                }
            } else {
                variable_struct_set(A, "_bide_state", _bide_state);
                dialog_queue((is_struct(A) && variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " is biding its time!");
            }
        } else {
            variable_struct_set(A, "_bide_state", { remaining: 2, damage: 0 });
            dialog_queue((is_struct(A) && variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " began storing energy!");
        }
        return _bide_used_msg;
    }
    if (is_real(move_id) && move_id == 220){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _pain_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (is_struct(A) && is_struct(D)){
            var _pain_avg = floor((max(0, __battle_hp_now(A)) + max(0, __battle_hp_now(D))) / 2);
            __battle_set_hp_now(A, min(__battle_hp_max(A), _pain_avg));
            __battle_set_hp_now(D, min(__battle_hp_max(D), _pain_avg));
            dialog_queue("The battlers shared their pain!");
        } else {
            dialog_queue("But it failed!");
        }
        return _pain_used_msg;
    }
    if (is_real(move_id) && move_id == 273){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _wish_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _wish_side = 0;
        try {
            if (is_struct(A) && variable_struct_exists(A, "actor_index") && is_real(variable_struct_get(A, "actor_index"))) _wish_side = __battle_field_side_index_for_actor(variable_struct_get(A, "actor_index"));
        } catch (e_wish_side) { _wish_side = 0; }
        var _wish_slot = __battle_ensure_slot(_pid);
        if (is_struct(_wish_slot) && !variable_struct_exists(_wish_slot, "_pending_wishes")) variable_struct_set(_wish_slot, "_pending_wishes", []);
        var _wish_pending = (is_struct(_wish_slot) && variable_struct_exists(_wish_slot, "_pending_wishes") && is_array(variable_struct_get(_wish_slot, "_pending_wishes"))) ? variable_struct_get(_wish_slot, "_pending_wishes") : [];
        var _wish_heal = max(1, floor(__battle_hp_max(A) * 0.5));
        array_push(_wish_pending, { side: _wish_side, remaining: 2, amount: _wish_heal, source_name: (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") });
        if (is_struct(_wish_slot)) variable_struct_set(_wish_slot, "_pending_wishes", _wish_pending);
        dialog_queue("A wish was made!");
        return _wish_used_msg;
    }
    if (is_real(move_id) && move_id == 361){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _healing_wish_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _healing_wish_side = 0;
        try {
            if (is_struct(A) && variable_struct_exists(A, "actor_index") && is_real(variable_struct_get(A, "actor_index"))) _healing_wish_side = __battle_field_side_index_for_actor(variable_struct_get(A, "actor_index"));
        } catch (e_hw_side) { _healing_wish_side = 0; }
        var _healing_slot = __battle_ensure_slot(_pid);
        if (is_struct(_healing_slot) && !variable_struct_exists(_healing_slot, "_pending_healing_wishes")) variable_struct_set(_healing_slot, "_pending_healing_wishes", []);
        var _healing_pending = (is_struct(_healing_slot) && variable_struct_exists(_healing_slot, "_pending_healing_wishes") && is_array(variable_struct_get(_healing_slot, "_pending_healing_wishes"))) ? variable_struct_get(_healing_slot, "_pending_healing_wishes") : [];
        array_push(_healing_pending, { side: _healing_wish_side, source_name: (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") });
        if (is_struct(_healing_slot)) variable_struct_set(_healing_slot, "_pending_healing_wishes", _healing_pending);
        dialog_queue("A healing wish was made!");
        var _self_ko_hp_hw = __battle_hp_now(A);
        if (is_real(_self_ko_hp_hw) && _self_ko_hp_hw > 0){
            try { __battle_apply_damage(_pid, actor_idx, _self_ko_hp_hw, 1.0); } catch (e_hw_ko) { __battle_set_hp_now(A, 0); }
        }
        return _healing_wish_used_msg;
    }
    if (is_real(move_id) && move_id == 271){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _trick_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (!is_struct(A) || !is_struct(D)){
            dialog_queue("But it failed!");
            return _trick_used_msg;
        }
        var _a_item = __battle_get_held_item_snapshot(A);
        var _d_item = __battle_get_held_item_snapshot(D);
        if ((!is_real(_a_item.id) || _a_item.id <= 0) && (!is_real(_d_item.id) || _d_item.id <= 0)){
            dialog_queue("But it failed!");
            return _trick_used_msg;
        }
        __battle_set_held_item_snapshot(A, _d_item.id, _d_item.name);
        __battle_set_held_item_snapshot(D, _a_item.id, _a_item.name);
        dialog_queue("The battlers switched items!");
        return _trick_used_msg;
    }
    if (is_real(move_id) && move_id == 272){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _role_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (!is_struct(A) || !is_struct(D) || !variable_struct_exists(D, "ability")){
            dialog_queue("But it failed!");
            return _role_used_msg;
        }
        var _role_ability = variable_struct_get(D, "ability");
        var _role_ability_id = (variable_struct_exists(D, "ability_id") && is_real(variable_struct_get(D, "ability_id"))) ? variable_struct_get(D, "ability_id") : undefined;
        __battle_set_ability_value(A, _role_ability, _role_ability_id);
        dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " copied the target's Ability!");
        return _role_used_msg;
    }
    if (is_real(move_id) && move_id == 227){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _encore_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _encore_move = undefined;
        try {
            if (is_struct(D) && variable_struct_exists(D, "sys_last_move_used") && is_real(variable_struct_get(D, "sys_last_move_used"))) _encore_move = variable_struct_get(D, "sys_last_move_used");
            if (!is_real(_encore_move) && is_struct(D) && variable_struct_exists(D, "_last_moves_used") && is_array(variable_struct_get(D, "_last_moves_used"))){
                var _enc_hist = variable_struct_get(D, "_last_moves_used");
                for (var _ei = array_length(_enc_hist) - 1; _ei >= 0; --_ei){
                    var _erec = _enc_hist[_ei];
                    if (is_struct(_erec) && variable_struct_exists(_erec, "move") && is_real(variable_struct_get(_erec, "move"))){ _encore_move = variable_struct_get(_erec, "move"); break; }
                }
            }
        } catch (e_enc_find) { _encore_move = undefined; }
        if (is_real(_encore_move) && _encore_move >= 0 && _encore_move != move_id){
            variable_struct_set(D, "_encore_state", { move_id: _encore_move, remaining: irandom_range(2, 6) });
            dialog_queue((is_struct(D) && variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target") + " received an encore!");
        } else {
            dialog_queue("But it failed!");
        }
        return _encore_used_msg;
    }
    if (is_real(move_id) && move_id == 160){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _conversion_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _candidate_types = [];
        try {
            if (is_struct(A) && variable_struct_exists(A, "moves") && is_array(variable_struct_get(A, "moves"))){
                var _conv_moves = variable_struct_get(A, "moves");
                for (var _ci = 0; _ci < array_length(_conv_moves); ++_ci){
                    var _cmove = _conv_moves[_ci];
                    if (!is_real(_cmove) || _cmove < 0 || _cmove == move_id) continue;
                    var _ctype = scr_move_type_id_by_id(_cmove);
                    if (is_real(_ctype) && _ctype >= 0) array_push(_candidate_types, _ctype);
                }
            }
        } catch (e_conv_scan) {}
        if (array_length(_candidate_types) <= 0){
            dialog_queue("But it failed!");
        } else {
            var _new_type = _candidate_types[irandom(array_length(_candidate_types) - 1)];
            variable_struct_set(A, "types", [_new_type]);
            variable_struct_set(A, "type1", _new_type);
            variable_struct_set(A, "type2", -1);
            try {
                if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                    var _conv_mon = variable_struct_get(A, "mon");
                    variable_struct_set(_conv_mon, "types", [_new_type]);
                    variable_struct_set(_conv_mon, "type1", _new_type);
                    variable_struct_set(_conv_mon, "type2", -1);
                }
            } catch (e_conv_inner) {}
            dialog_queue((is_struct(A) && variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " transformed its type!");
        }
        return _conversion_used_msg;
    }
    if (is_real(move_id) && move_id == 176){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _conv2_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _last_type = -1;
        try {
            var _last_move = undefined;
            if (is_struct(A) && variable_struct_exists(A, "_last_moves") && is_array(variable_struct_get(A, "_last_moves"))){
                var _conv2_hist = variable_struct_get(A, "_last_moves");
                for (var _c2i = array_length(_conv2_hist) - 1; _c2i >= 0; --_c2i){
                    var _c2rec = _conv2_hist[_c2i];
                    if (is_struct(_c2rec) && variable_struct_exists(_c2rec, "move") && is_real(variable_struct_get(_c2rec, "move"))){ _last_move = variable_struct_get(_c2rec, "move"); break; }
                }
            }
            if (!is_real(_last_move) && is_struct(A) && variable_struct_exists(A, "_last_received_from_move") && is_real(variable_struct_get(A, "_last_received_from_move"))) _last_move = variable_struct_get(A, "_last_received_from_move");
            if (is_real(_last_move)) _last_type = scr_move_type_id_by_id(_last_move);
        } catch (e_conv2_last) { _last_type = -1; }
        var _conv2_candidates = [];
        try {
            if (is_real(_last_type) && _last_type >= 0 && variable_global_exists("BATTLE_TYPE_EFFICACY")){
                var _eff_map = variable_global_get("BATTLE_TYPE_EFFICACY");
                for (var _type_id = 1; _type_id <= 18; ++_type_id){
                    var _key = string(_last_type) + ":" + string(_type_id);
                    if (ds_map_exists(_eff_map, _key)){
                        var _mul = ds_map_find_value(_eff_map, _key);
                        if (is_real(_mul) && _mul < 1) array_push(_conv2_candidates, _type_id);
                    }
                }
            }
        } catch (e_conv2_scan) { _conv2_candidates = []; }
        if (array_length(_conv2_candidates) <= 0){
            switch (_last_type){
                case 10: _conv2_candidates = [10, 11, 16]; break; // fire
                case 11: _conv2_candidates = [11, 12, 16]; break; // water
                case 12: _conv2_candidates = [10, 12, 3, 7, 16]; break; // grass
                case 13: _conv2_candidates = [12, 13, 16]; break; // electric
                case 14: _conv2_candidates = [14, 9]; break; // psychic
                case 15: _conv2_candidates = [10, 11, 15, 9]; break; // ice
                case 16: _conv2_candidates = [17]; break; // dragon
                default: _conv2_candidates = [11, 12, 16]; break;
            }
        }
        if (array_length(_conv2_candidates) <= 0){
            dialog_queue("But it failed!");
        } else {
            var _conv2_type = _conv2_candidates[irandom(array_length(_conv2_candidates) - 1)];
            variable_struct_set(A, "types", [_conv2_type]);
            variable_struct_set(A, "type1", _conv2_type);
            variable_struct_set(A, "type2", -1);
            try {
                if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                    var _conv2_mon = variable_struct_get(A, "mon");
                    variable_struct_set(_conv2_mon, "types", [_conv2_type]);
                    variable_struct_set(_conv2_mon, "type1", _conv2_type);
                    variable_struct_set(_conv2_mon, "type2", -1);
                }
            } catch (e_conv2_inner) {}
            dialog_queue((is_struct(A) && variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " transformed its type!");
        }
        return _conv2_used_msg;
    }
    if (is_real(move_id) && move_id == 187){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _belly_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _belly_hp = __battle_hp_now(A);
        var _belly_max = max(1, __battle_hp_max(A));
        var _belly_cost = max(1, floor(_belly_max / 2));
        var _belly_stage = 0;
        try {
            if (is_struct(A) && variable_struct_exists(A, "_stages") && is_struct(variable_struct_get(A, "_stages"))){
                var _belly_stages_read = variable_struct_get(A, "_stages");
                if (variable_struct_exists(_belly_stages_read, "atk") && is_real(variable_struct_get(_belly_stages_read, "atk"))) _belly_stage = variable_struct_get(_belly_stages_read, "atk");
            }
        } catch (e_belly_read) { _belly_stage = 0; }
        if (_belly_hp <= _belly_cost || _belly_stage >= 6){
            dialog_queue("But it failed!");
            return _belly_used_msg;
        }
        if (!variable_struct_exists(A, "_stages") || !is_struct(variable_struct_get(A, "_stages"))) variable_struct_set(A, "_stages", {});
        var _belly_stages = variable_struct_get(A, "_stages");
        variable_struct_set(_belly_stages, "atk", 6);
        variable_struct_set(A, "_stages", _belly_stages);
        __battle_set_hp_now(A, max(1, _belly_hp - _belly_cost));
        try { __battle_request_animation_safe(A, { type: "stat_change", stat: "atk", change: 6 }); } catch (e_belly_anim) {}
        var _belly_name = (is_struct(A) && variable_struct_exists(A, "name")) ? string(variable_struct_get(A, "name")) : "The user";
        dialog_queue(_belly_name + " cut its HP and maximized its Attack!");
        return _belly_used_msg;
    }
    if (is_real(move_id) && move_id == 244){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _psych_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (is_struct(A) && is_struct(D)){
            var _copied_stages = {};
            try {
                if (variable_struct_exists(D, "_stages") && is_struct(variable_struct_get(D, "_stages"))){
                    _copied_stages = __battle_clone_stage_struct(variable_struct_get(D, "_stages"));
                }
            } catch (e_psych_clone) { _copied_stages = {}; }
            variable_struct_set(A, "_stages", _copied_stages);
            try { __battle_request_animation_safe(A, { type: "stat_change", stat: "all", change: 0 }); } catch (e_psych_anim) {}
            var _psych_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user");
            dialog_queue(_psych_name + " copied the target's stat changes!");
        } else {
            dialog_queue("But it failed!");
        }
        return _psych_used_msg;
    }
    if (is_real(move_id) && move_id == 357){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _miracle_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (!is_struct(D)){
            dialog_queue("But it failed!");
            return _miracle_used_msg;
        }
        if (variable_struct_exists(D, "_miracle_eye_active") && variable_struct_get(D, "_miracle_eye_active") == true){
            dialog_queue("But it failed!");
            return _miracle_used_msg;
        }
        try {
            if (variable_struct_exists(D, "_stages") && is_struct(variable_struct_get(D, "_stages"))){
                var _miracle_stages = variable_struct_get(D, "_stages");
                if (variable_struct_exists(_miracle_stages, "evasion") && is_real(variable_struct_get(_miracle_stages, "evasion")) && variable_struct_get(_miracle_stages, "evasion") != 0){
                    variable_struct_set(_miracle_stages, "evasion", 0);
                    variable_struct_set(D, "_stages", _miracle_stages);
                }
            }
        } catch (e_miracle_stage) {}
        variable_struct_set(D, "_miracle_eye_active", true);
        if (variable_struct_exists(D, "mon") && is_struct(variable_struct_get(D, "mon"))) variable_struct_set(variable_struct_get(D, "mon"), "_miracle_eye_active", true);
        dialog_queue((variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target") + " was identified!");
        return _miracle_used_msg;
    }
    if (is_real(move_id) && move_id == 281){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _yawn_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _yawn_ok = false;
        try {
            if (is_struct(D) && !is_undefined(status_system_apply_status)) _yawn_ok = status_system_apply_status(D, "yawn", { duration: 2, source: A });
        } catch (e_yawn_apply) { _yawn_ok = false; }
        if (_yawn_ok) dialog_queue((is_struct(D) && variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target") + " grew drowsy!");
        else dialog_queue("But it failed!");
        return _yawn_used_msg;
    }
    if (is_real(move_id) && move_id == 278){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _recycle_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _held_now = __battle_get_held_item_snapshot(A);
        var _restore_id = (is_struct(A) && variable_struct_exists(A, "_last_lost_item_id") && is_real(variable_struct_get(A, "_last_lost_item_id"))) ? floor(variable_struct_get(A, "_last_lost_item_id")) : -1;
        var _restore_name = (is_struct(A) && variable_struct_exists(A, "_last_lost_item_name") ? string(variable_struct_get(A, "_last_lost_item_name")) : "");
        if (_held_now.id > 0 || _restore_id <= 0){
            dialog_queue("But it failed!");
            return _recycle_used_msg;
        }
        __battle_set_held_item_snapshot(A, _restore_id, _restore_name);
        variable_struct_set(A, "_last_lost_item_id", -1);
        variable_struct_set(A, "_last_lost_item_name", "");
        dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " recovered its item!");
        return _recycle_used_msg;
    }
    if (is_real(move_id) && move_id == 285){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _skill_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (!is_struct(A) || !is_struct(D) || !variable_struct_exists(A, "ability") || !variable_struct_exists(D, "ability")){
            dialog_queue("But it failed!");
            return _skill_used_msg;
        }
        var _a_ability = variable_struct_get(A, "ability");
        var _a_ability_id = (variable_struct_exists(A, "ability_id") && is_real(variable_struct_get(A, "ability_id"))) ? variable_struct_get(A, "ability_id") : undefined;
        var _d_ability = variable_struct_get(D, "ability");
        var _d_ability_id = (variable_struct_exists(D, "ability_id") && is_real(variable_struct_get(D, "ability_id"))) ? variable_struct_get(D, "ability_id") : undefined;
        __battle_set_ability_value(A, _d_ability, _d_ability_id);
        __battle_set_ability_value(D, _a_ability, _a_ability_id);
        dialog_queue("The battlers swapped Abilities!");
        return _skill_used_msg;
    }
    if (is_real(move_id) && move_id == 288){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _grudge_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (is_struct(A)) variable_struct_set(A, "_grudge_active", true);
        dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " is bearing a grudge!");
        return _grudge_used_msg;
    }
    if (is_real(move_id) && move_id == 298){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _teeter_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _teeter_applied = false;
        try {
            if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                var _teeter_actors = variable_struct_get(_B, "actor");
                for (var _tdi = 0; _tdi < array_length(_teeter_actors); ++_tdi){
                    var _td_actor = _teeter_actors[_tdi];
                    if (!is_struct(_td_actor) || _td_actor == A) continue;
                    var _td_hp = __battle_hp_now(_td_actor);
                    if (is_real(_td_hp) && _td_hp <= 0) continue;
                    if (__battle_try_apply_status_with_chance(_td_actor, "confusion", 100, A)) _teeter_applied = true;
                }
            }
        } catch (e_teeter_apply) { _teeter_applied = false; }
        if (_teeter_applied) dialog_queue("All nearby battlers became confused!");
        else dialog_queue("But it failed!");
        return _teeter_used_msg;
    }
    if (is_real(move_id) && move_id == 226){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _bp_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _bp_slot = __battle_ensure_slot(_pid);
        var _bp_stages = {};
        try {
            if (is_struct(A) && variable_struct_exists(A, "_stages") && is_struct(variable_struct_get(A, "_stages"))) _bp_stages = __battle_clone_stage_struct(variable_struct_get(A, "_stages"));
        } catch (e_bp_clone) { _bp_stages = {}; }
        if (is_struct(_bp_slot)) variable_struct_set(_bp_slot, "_baton_pass_pending", { actor_index: actor_idx, stages: _bp_stages });

        if (actor_idx == 0){
            var _P_bp = (is_undefined(party_ensure) ? undefined : party_ensure(_pid));
            var _can_pass = false;
            if (is_struct(_P_bp) && variable_struct_exists(_P_bp, "mons") && is_array(variable_struct_get(_P_bp, "mons"))){
                var _bp_mons = variable_struct_get(_P_bp, "mons");
                var _self_mon = (is_struct(A) && variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) ? variable_struct_get(A, "mon") : A;
                for (var _bp_i = 0; _bp_i < array_length(_bp_mons); ++_bp_i){
                    var _bp_mon = _bp_mons[_bp_i];
                    if (!is_struct(_bp_mon) || _bp_mon == _self_mon) continue;
                    var _bp_hp = __battle_hp_now(_bp_mon);
                    if (is_real(_bp_hp) && _bp_hp > 0){ _can_pass = true; break; }
                }
            }
            if (!_can_pass){
                dialog_queue("But it failed!");
                try { if (is_struct(_bp_slot)) variable_struct_set(_bp_slot, "_baton_pass_pending", undefined); } catch (e_bp_fail_clear) {}
                return _bp_used_msg;
            }
            if (!is_undefined(party_open) && is_struct(_P_bp)){
                party_open(_pid);
                try { if (!is_undefined(party_set_swap_mode_impl)) party_set_swap_mode_impl(_pid, true, false); } catch (e_bp_swap) {}
                try { variable_struct_set(_P_bp, "_battle_baton_pass_mode", true); } catch (e_bp_mode) {}
                try { variable_struct_set(_P_bp, "lock", 0); } catch (e_bp_lock) {}
            } else {
                dialog_queue("But it failed!");
                try { if (is_struct(_bp_slot)) variable_struct_set(_bp_slot, "_baton_pass_pending", undefined); } catch (e_bp_clear2) {}
            }
            return _bp_used_msg;
        }

        if (actor_idx == 1){
            var _next_bp = -1;
            try { _next_bp = __battle_trainer_next_alive_index(_bp_slot, (variable_struct_exists(_bp_slot, "_trainer_party_active_idx") ? variable_struct_get(_bp_slot, "_trainer_party_active_idx") : -1)); } catch (e_bp_next) { _next_bp = -1; }
            if (is_real(_next_bp) && _next_bp >= 0 && !is_undefined(__battle_trainer_perform_switch_action)){
                try { __battle_trainer_perform_switch_action(_pid, _next_bp, { move_id: move_id, baton_pass: true }); } catch (e_bp_enemy) { dialog_queue("But it failed!"); }
            } else {
                dialog_queue("But it failed!");
                try { if (is_struct(_bp_slot)) variable_struct_set(_bp_slot, "_baton_pass_pending", undefined); } catch (e_bp_clear3) {}
            }
            return _bp_used_msg;
        }
    }

    var mv_power = 0;
    try { mv_power = __battle_move_power(move_id, A, D); } catch (e) { mv_power = 0; }
    if (is_real(_effect_id) && _effect_id == 159){
        var _active_turns = 0;
        try { if (variable_struct_exists(A, "active_turns") && is_real(variable_struct_get(A, "active_turns"))) _active_turns = floor(variable_struct_get(A, "active_turns")); } catch (e_fake_turns) { _active_turns = 0; }
        if (_active_turns > 0){
            __battle_record_move_usage(_pid, A, D, move_id, false);
            var _fake_out_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
            dialog_queue("But it failed!");
            return _fake_out_used_msg;
        }
    }
    if (is_real(move_id) && move_id == 173){
        var _snore_asleep = false;
        try {
            _snore_asleep = !is_undefined(status_system_has_status) && status_system_has_status(A, "sleep");
            if (!_snore_asleep && is_struct(A) && variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) _snore_asleep = status_system_has_status(variable_struct_get(A, "mon"), "sleep");
        } catch (e_snore_sleep) { _snore_asleep = false; }
        if (!_snore_asleep){
            __battle_record_move_usage(_pid, A, D, move_id, false);
            var _snore_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
            dialog_queue("But it failed!");
            return _snore_used_msg;
        }
    }
    if (is_real(move_id) && move_id == 214){
        var _sleep_talk_asleep = false;
        try {
            _sleep_talk_asleep = !is_undefined(status_system_has_status) && status_system_has_status(A, "sleep");
            if (!_sleep_talk_asleep && is_struct(A) && variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) _sleep_talk_asleep = status_system_has_status(variable_struct_get(A, "mon"), "sleep");
        } catch (e_sleep_talk_sleep) { _sleep_talk_asleep = false; }
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _sleep_talk_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (!_sleep_talk_asleep){
            dialog_queue("But it failed!");
            return _sleep_talk_used_msg;
        }
        var _sleep_talk_choices = [];
        try {
            if (is_struct(A) && variable_struct_exists(A, "moves") && is_array(variable_struct_get(A, "moves"))){
                var _sleep_talk_moves = variable_struct_get(A, "moves");
                for (var _st_i = 0; _st_i < array_length(_sleep_talk_moves); ++_st_i){
                    var _st_mid = _sleep_talk_moves[_st_i];
                    if (!is_real(_st_mid) || _st_mid < 0 || _st_mid == 214) continue;
                    if (__is_meta_move_ignored(_st_mid)) continue;
                    array_push(_sleep_talk_choices, _st_mid);
                }
            }
        } catch (e_sleep_talk_choices) { _sleep_talk_choices = []; }
        if (array_length(_sleep_talk_choices) <= 0){
            dialog_queue("But it failed!");
            return _sleep_talk_used_msg;
        }
        var _sleep_talk_pick = _sleep_talk_choices[irandom(array_length(_sleep_talk_choices) - 1)];
        try { variable_struct_set(A, "_sleep_talk_bypass", true); } catch (e_st_bypass1) {}
        try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_st_sup1) {}
        try {
            var _sleep_talk_power = __battle_move_power(_sleep_talk_pick, A, D);
            if (is_real(_sleep_talk_power) && _sleep_talk_power > 0){
                var _sleep_talk_res = __battle_apply_move_damage(_pid, target_idx, A, D, _sleep_talk_pick, _sleep_talk_power);
                var _sleep_talk_dmg = (is_array(_sleep_talk_res) ? _sleep_talk_res[0] : 0);
                if (!__battle_consume_damage_miss(_pid)){
                    try { __battle_apply_move_meta_effects(_pid, { move_id: _sleep_talk_pick }, A, D, _sleep_talk_pick, _sleep_talk_dmg, __battle_get_move_meta(_sleep_talk_pick)); } catch (e_st_meta) {}
                }
            } else {
                __battle_apply_called_move(_pid, A, D, move_id, _sleep_talk_pick);
            }
        } catch (e_sleep_talk_apply) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sleep-talk] apply failed: " + string(e_sleep_talk_apply)); }
        try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_st_sup2) {}
        try { variable_struct_set(A, "_sleep_talk_bypass", false); } catch (e_st_bypass2) {}
        return _sleep_talk_used_msg;
    }
    if (is_real(move_id) && move_id == 138){
        var _dream_target_asleep = false;
        try {
            _dream_target_asleep = !is_undefined(status_system_has_status) && status_system_has_status(D, "sleep");
            if (!_dream_target_asleep && is_struct(D) && variable_struct_exists(D, "mon") && is_struct(variable_struct_get(D, "mon"))) _dream_target_asleep = status_system_has_status(variable_struct_get(D, "mon"), "sleep");
        } catch (e_dream_sleep) { _dream_target_asleep = false; }
        if (!_dream_target_asleep){
            __battle_record_move_usage(_pid, A, D, move_id, false);
            var _dream_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
            dialog_queue("But it failed!");
            return _dream_used_msg;
        }
    }
    try {
        if (is_real(move_id) && move_id == 228 && is_struct(_step) && variable_struct_exists(_step, "pursuit_switching") && variable_struct_get(_step, "pursuit_switching") == true){
            mv_power = max(1, floor(mv_power * 2));
        }
    } catch (e_pursuit_power) {}

    if (_is_guard_like){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _status_handled = false;
        try { _status_handled = (__battle_apply_status_move(_pid, A, D, move_id) == true); } catch (e_status_apply) { _status_handled = false; }
        try {
            if (!is_undefined(__battle_get_move_meta)){
                var _status_meta = __battle_get_move_meta(move_id);
                if (is_struct(_status_meta)) __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, 0, _status_meta);
            }
        } catch (e_status_meta_apply) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][impl] meta(status-early) error: " + string(e_status_meta_apply));
        }
        return __battle_impl_return_used(_pid, A, mv_name, move_id);
    }

    var _is_disable_move = (is_real(move_id) && move_id == 50) || (_moveIdent == "disable");
    if (is_real(move_id) && move_id == 266){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _follow_me_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _follow_me_ok = false;
        try {
            var _B_follow = __battle_ensure_slot(_pid);
            if (is_struct(_B_follow) && variable_struct_exists(_B_follow, "actor") && is_array(variable_struct_get(_B_follow, "actor"))){
                var _follow_side = (variable_struct_exists(A, "actor_index") && is_real(variable_struct_get(A, "actor_index"))) ? __battle_field_side_index_for_actor(variable_struct_get(A, "actor_index")) : 0;
                var _follow_acts = variable_struct_get(_B_follow, "actor");
                for (var _fai = 0; _fai < array_length(_follow_acts); ++_fai){
                    var _fally = _follow_acts[_fai];
                    if (!is_struct(_fally) || _fally == A) continue;
                    if (__battle_field_side_index_for_actor(_fai) != _follow_side) continue;
                    variable_struct_set(A, "_follow_me_turn", _turn_now);
                    variable_struct_set(A, "_follow_me_active", true);
                    _follow_me_ok = true;
                    break;
                }
            }
        } catch (e_follow_me) { _follow_me_ok = false; }
        if (!_follow_me_ok) dialog_queue("But it failed!");
        return _follow_me_used_msg;
    }
    if (is_real(move_id) && move_id == 270){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _help_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _help_ok = false;
        try {
            var _B_help = __battle_ensure_slot(_pid);
            if (is_struct(_B_help) && variable_struct_exists(_B_help, "actor") && is_array(variable_struct_get(_B_help, "actor"))){
                var _help_side = (variable_struct_exists(A, "actor_index") && is_real(variable_struct_get(A, "actor_index"))) ? __battle_field_side_index_for_actor(variable_struct_get(A, "actor_index")) : 0;
                var _help_acts = variable_struct_get(_B_help, "actor");
                for (var _hai = 0; _hai < array_length(_help_acts); ++_hai){
                    var _hally = _help_acts[_hai];
                    if (!is_struct(_hally) || _hally == A) continue;
                    if (__battle_field_side_index_for_actor(_hai) != _help_side) continue;
                    variable_struct_set(_hally, "_helping_hand_turn", _turn_now);
                    variable_struct_set(_hally, "_helping_hand_bonus", 1.5);
                    _help_ok = true;
                    break;
                }
            }
        } catch (e_helping_hand) { _help_ok = false; }
        if (!_help_ok) dialog_queue("But it failed!");
        return _help_used_msg;
    }
    if (is_real(move_id) && move_id == 267){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _nature_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _nature_pick = 161;
        try {
            var _terrain_family = __battle_terrain_power_family(_pid);
            if (is_struct(_terrain_family) && variable_struct_exists(_terrain_family, "nature_move_id") && is_real(variable_struct_get(_terrain_family, "nature_move_id"))) _nature_pick = variable_struct_get(_terrain_family, "nature_move_id");
            var _nature_power = __battle_move_power(_nature_pick, A, D);
            if (is_real(_nature_power) && _nature_power > 0){
                var _nature_res = __battle_apply_move_damage(_pid, target_idx, A, D, _nature_pick, _nature_power);
                var _nature_dmg = (is_array(_nature_res) ? _nature_res[0] : 0);
                if (!__battle_consume_damage_miss(_pid)){
                    try { __battle_apply_move_meta_effects(_pid, { move_id: _nature_pick }, A, D, _nature_pick, _nature_dmg, __battle_get_move_meta(_nature_pick)); } catch (e_nature_meta) {}
                }
            } else {
                try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_nature_sup1) {}
                __battle_apply_called_move(_pid, A, D, move_id, _nature_pick);
                try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_nature_sup2) {}
            }
        } catch (e_nature_power) { dialog_queue("But it failed!"); }
        return _nature_used_msg;
    }
    if (is_real(move_id) && move_id == 277){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _magic_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        try {
            variable_struct_set(A, "_magic_coat_turn", _turn_now);
            variable_struct_set(A, "_magic_coat_active", true);
        } catch (e_magic_set) {
            dialog_queue("But it failed!");
            return _magic_used_msg;
        }
        return _magic_used_msg;
    }
    if (is_real(move_id) && move_id == 289){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _snatch_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        try {
            variable_struct_set(A, "_snatch_turn", _turn_now);
            variable_struct_set(A, "_snatch_active", true);
        } catch (e_snatch_set) {
            dialog_queue("But it failed!");
            return _snatch_used_msg;
        }
        return _snatch_used_msg;
    }
    if (_is_disable_move){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _disable_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _disabled_success = __battle_apply_disable(_pid, A, D, move_id);
        if (_disabled_success){
            var _tname_disable = (is_struct(D) && variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target");
            dialog_queue(_tname_disable + " was disabled!");
        } else {
            dialog_queue("But it failed!");
        }
        return _disable_used_msg;
    }

    if (is_real(move_id) && move_id == 116){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _focus_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _focus_applied = false;
        try {
            if (is_struct(A)){
                var _focus_level = (variable_struct_exists(A, "_focus_energy_level") && is_real(variable_struct_get(A, "_focus_energy_level"))) ? floor(variable_struct_get(A, "_focus_energy_level")) : 0;
                if (_focus_level <= 0){
                    variable_struct_set(A, "_focus_energy_level", 1);
                    _focus_applied = true;
                }
            }
        } catch (e_focus_set) { _focus_applied = false; }
        if (_focus_applied){
            try { __battle_request_animation_safe(A, { type: "focus_energy" }); } catch (e_focus_anim) {}
            var _focus_name = (is_struct(A) && variable_struct_exists(A, "name")) ? string(variable_struct_get(A, "name")) : "The user";
            dialog_queue(_focus_name + " is getting pumped!");
        } else {
            dialog_queue("But it failed!");
        }
        return _focus_used_msg;
    }

    if (is_real(move_id) && move_id == 156){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _rest_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (!is_struct(A)) return _rest_used_msg;
        var _rest_hp_now = __battle_hp_now(A);
        var _rest_hp_max = max(1, __battle_hp_max(A));
        var _rest_needs_heal = (_rest_hp_now < _rest_hp_max);
        var _rest_has_major = false;
        try {
            if (!is_undefined(status_system_has_status)){
                var _rest_major = ["poison", "toxic", "burn", "freeze", "paralysis", "paralyze"];
                for (var _rs = 0; _rs < array_length(_rest_major); ++_rs){
                    if (status_system_has_status(A, _rest_major[_rs])){ _rest_has_major = true; break; }
                }
            }
        } catch (e_rest_check) { _rest_has_major = false; }
        if (!_rest_needs_heal && !_rest_has_major){
            dialog_queue("But it failed!");
            return _rest_used_msg;
        }
        try {
            if (!is_undefined(status_system_clear_status)){
                var _rest_clear = ["poison", "toxic", "burn", "freeze", "paralysis", "paralyze"];
                for (var _rc = 0; _rc < array_length(_rest_clear); ++_rc){
                    status_system_clear_status(A, _rest_clear[_rc]);
                }
            }
        } catch (e_rest_clear) {}
        var _rest_sleep_ok = false;
        try {
            if (!is_undefined(status_system_apply_status)) _rest_sleep_ok = status_system_apply_status(A, "sleep", { duration: 2, source: A });
        } catch (e_rest_sleep) { _rest_sleep_ok = false; }
        if (!_rest_sleep_ok){
            dialog_queue("But it failed!");
            return _rest_used_msg;
        }
        var _rest_heal = max(0, _rest_hp_max - _rest_hp_now);
        if (_rest_heal > 0){
            try { __battle_set_hp_now(A, _rest_hp_max); } catch (e_rest_hp) {}
            try { __battle_clear_fainted_if_healed(A); } catch (e_rest_faint) {}
            try {
                variable_struct_set(A, "_hp_lerp_from", _rest_hp_now);
                variable_struct_set(A, "_hp_lerp_to", _rest_hp_max);
                variable_struct_set(A, "_hp_lerp_start_ms", current_time);
                variable_struct_set(A, "_hp_lerp_dur", 400);
                variable_struct_set(A, "_hp_lerp_active", true);
                if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                    var _rest_mon = variable_struct_get(A, "mon");
                    variable_struct_set(_rest_mon, "_hp_lerp_from", _rest_hp_now);
                    variable_struct_set(_rest_mon, "_hp_lerp_to", _rest_hp_max);
                    variable_struct_set(_rest_mon, "_hp_lerp_start_ms", variable_struct_get(A, "_hp_lerp_start_ms"));
                    variable_struct_set(_rest_mon, "_hp_lerp_dur", variable_struct_get(A, "_hp_lerp_dur"));
                    variable_struct_set(_rest_mon, "_hp_lerp_active", true);
                }
            } catch (e_rest_lerp) {}
            try { __battle_request_animation_safe(A, { type: "heal", amount: _rest_heal }); } catch (e_rest_anim) {}
        }
        var _rest_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user");
        dialog_queue(_rest_name + " went to sleep and restored its health!");
        return _rest_used_msg;
    }

    // Generic two-turn move handling (charge then strike). This handles common
    // Gen3 two-turn moves like Razor Wind, SolarBeam, Skull Bash, Sky Attack,

    if (is_real(move_id) && move_id == 355){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _roost_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (!is_struct(A)) return _roost_used_msg;
        var _roost_hp_now = __battle_hp_now(A);
        var _roost_hp_max = max(1, __battle_hp_max(A));
        if (_roost_hp_now >= _roost_hp_max){
            dialog_queue("But it failed!");
            return _roost_used_msg;
        }
        var _roost_heal = max(1, floor(_roost_hp_max * 0.5));
        var _roost_hp_to = min(_roost_hp_max, _roost_hp_now + _roost_heal);
        try { __battle_set_hp_now(A, _roost_hp_to); } catch (e_roost_hp) {}
        try { __battle_clear_fainted_if_healed(A); } catch (e_roost_faint) {}
        try {
            variable_struct_set(A, "_hp_lerp_from", _roost_hp_now);
            variable_struct_set(A, "_hp_lerp_to", _roost_hp_to);
            variable_struct_set(A, "_hp_lerp_start_ms", current_time);
            variable_struct_set(A, "_hp_lerp_dur", 400);
            variable_struct_set(A, "_hp_lerp_active", true);
            if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                var _roost_lerp_mon = variable_struct_get(A, "mon");
                variable_struct_set(_roost_lerp_mon, "_hp_lerp_from", _roost_hp_now);
                variable_struct_set(_roost_lerp_mon, "_hp_lerp_to", _roost_hp_to);
                variable_struct_set(_roost_lerp_mon, "_hp_lerp_start_ms", variable_struct_get(A, "_hp_lerp_start_ms"));
                variable_struct_set(_roost_lerp_mon, "_hp_lerp_dur", variable_struct_get(A, "_hp_lerp_dur"));
                variable_struct_set(_roost_lerp_mon, "_hp_lerp_active", true);
            }
        } catch (e_roost_lerp) {}
        var _roost_grounded = false;
        try { _roost_grounded = __battle_roost_apply_self(A, _turn_now); } catch (e_roost_apply) { _roost_grounded = false; }
        if (_roost_grounded) dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " landed and became grounded!");
        return _roost_used_msg;
    }
    if (is_real(move_id) && move_id == 356){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _gravity_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (is_real(_gravity_turns_active) && _gravity_turns_active > 0){
            dialog_queue("But it failed!");
            return _gravity_used_msg;
        }
        try {
            __battle_field_set_status(_pid, "gravity", 5);
            var _gravity_actors = (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))) ? variable_struct_get(_B, "actor") : [];
            for (var _gai = 0; _gai < array_length(_gravity_actors); ++_gai){
                var _gactor = _gravity_actors[_gai];
                if (!is_struct(_gactor)) continue;
                if (variable_struct_exists(_gactor, "_semi_invuln")) variable_struct_set(_gactor, "_semi_invuln", undefined);
                if (variable_struct_exists(_gactor, "_sky_drop_held")) variable_struct_set(_gactor, "_sky_drop_held", undefined);
                if (variable_struct_exists(_gactor, "_charging_move") && is_struct(variable_struct_get(_gactor, "_charging_move"))){
                    var _charge_state = variable_struct_get(_gactor, "_charging_move");
                    if (is_struct(_charge_state) && variable_struct_exists(_charge_state, "move_id")){
                        var _charge_move_id = variable_struct_get(_charge_state, "move_id");
                        if (_charge_move_id == 19 || _charge_move_id == 340 || _charge_move_id == 507) variable_struct_set(_gactor, "_charging_move", undefined);
                    }
                }
            }
            dialog_queue("Gravity intensified!");
        } catch (e_gravity_apply) { dialog_queue("But it failed!"); }
        return _gravity_used_msg;
    }
    // Fly, Dig, Dive, Bounce, etc. First use sets a charging flag on the actor
    // (_charging_move) and returns; the second use with the same move_id clears
    // the flag and proceeds to actually perform the attack.
    try {
        if (is_real(move_id) && is_struct(A)){
            var two_ids = [13,19,76,91,130,143,291,340,467,507,566,669]; // razor-wind, fly, solar-beam, dig, skull-bash, sky-attack, dive, bounce, shadow-force, sky-drop, phantom-force, solar-blade
            var is_two = false;
            for (var _ti=0; _ti<array_length(two_ids); ++_ti) if (two_ids[_ti] == move_id) { is_two = true; break; }
            if (is_two && (move_id == 76 || move_id == 669)){
                try {
                    var _solar_weather = __battle_get_weather(_pid);
                    if (__battle_weather_is_active(_solar_weather)){
                        var _solar_wid = __battle_weather_get_normalized_id(_solar_weather);
                        if (_solar_wid == "sun" || _solar_wid == "harsh-sun") is_two = false;
                    }
                } catch (e_solar_weather) {}
            }
            // Special-case: Thrash / Rollout-like behavior using shared locked-move state.
            if (is_real(move_id) && (move_id == 37 || move_id == 80 || move_id == 200)){
                var _locked = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
                // If not previously locked, initialize lock state (2..3 turns inclusive)
                if (!is_struct(_locked) || !variable_struct_exists(_locked, "move_id") || variable_struct_get(_locked, "move_id") != move_id){
                    var dur = irandom_range(2,3);
                    variable_struct_set(A, "_locked_move", { move_id: move_id, remaining: dur, apply_confuse_on_end: true, force_reuse: true });
                }
            }
            if (is_real(move_id) && move_id == 205){
                var _locked_roll = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
                if (!is_struct(_locked_roll) || !variable_struct_exists(_locked_roll, "move_id") || variable_struct_get(_locked_roll, "move_id") != 205){
                    variable_struct_set(A, "_locked_move", { move_id: 205, remaining: 5, apply_confuse_on_end: false, force_reuse: true });
                    if (!variable_struct_exists(A, "_rollout_mul") || !is_real(variable_struct_get(A, "_rollout_mul"))) variable_struct_set(A, "_rollout_mul", 1);
                }
            }
            if (is_real(_effect_id) && _effect_id == 160){
                var _uproar_lock = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
                if (!is_struct(_uproar_lock) || !variable_struct_exists(_uproar_lock, "move_id") || variable_struct_get(_uproar_lock, "move_id") != move_id){
                    variable_struct_set(A, "_locked_move", { move_id: move_id, remaining: irandom_range(2, 5), apply_confuse_on_end: false, force_reuse: true, wake_field_sleepers: true });
                }
                try {
                    if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor")) && !is_undefined(status_system_has_status) && !is_undefined(status_system_clear_status)){
                        var _uproar_targets = variable_struct_get(_B, "actor");
                        for (var _uproar_idx = 0; _uproar_idx < array_length(_uproar_targets); ++_uproar_idx){
                            var _uproar_target = _uproar_targets[_uproar_idx];
                            if (!is_struct(_uproar_target)) continue;
                            if (status_system_has_status(_uproar_target, "sleep")) status_system_clear_status(_uproar_target, "sleep");
                        }
                    }
                    variable_struct_set(_B, "_uproar_active", true);
                } catch (e_uproar_start) {}
            }
            if (is_two){
                var charging = (variable_struct_exists(A, "_charging_move") ? variable_struct_get(A, "_charging_move") : undefined);
                // If actor is already charging this same move, consume the charge and continue
                if (is_struct(charging) && variable_struct_exists(charging, "move_id") && variable_struct_get(charging, "move_id") == move_id){
                    var _charge_info = charging;
                    // Use stored target_index from the charging record (defensive: override current target_idx)
                    try {
                        var _stored_tidx = (variable_struct_exists(charging, "target_index") ? variable_struct_get(charging, "target_index") : undefined);
                        if (is_real(_stored_tidx)){
                            target_idx = _stored_tidx;
                            // Recompute D from the actor array so subsequent code targets the correct defender
                            try {
                                if (is_array(__acts) && is_real(target_idx) && target_idx >= 0 && target_idx < array_length(__acts)){
                                    D = __acts[target_idx];
                                }
                            } catch (e_recomp) {}
                        }
                    } catch (e_st) {}

                    // Clear charging state and proceed with normal attack
                    variable_struct_set(A, "_charging_move", undefined);
                    // Clear semi-invulnerable phase now that the strike resolves
                    try { if (variable_struct_exists(A, "_semi_invuln")) variable_struct_set(A, "_semi_invuln", undefined); } catch (e_clrsi) {}
                    // Release any sky drop-held target so it can act again
                    try {
                        if (is_struct(_charge_info) && variable_struct_exists(_charge_info, "sky_drop") && variable_struct_get(_charge_info, "sky_drop") == true){
                            var _release_tgt = undefined;
                            if (variable_struct_exists(_charge_info, "target_actor") && is_struct(variable_struct_get(_charge_info, "target_actor"))){
                                _release_tgt = variable_struct_get(_charge_info, "target_actor");
                            } else if (variable_struct_exists(_charge_info, "target_index") && is_array(__acts)){
                                var _release_idx = variable_struct_get(_charge_info, "target_index");
                                if (is_real(_release_idx) && _release_idx >= 0 && _release_idx < array_length(__acts)){
                                    _release_tgt = __acts[_release_idx];
                                }
                            }
                            if (!is_struct(_release_tgt) && is_struct(D)) _release_tgt = D;
                            if (is_struct(_release_tgt)){
                                try { if (variable_struct_exists(_release_tgt, "_semi_invuln")) variable_struct_set(_release_tgt, "_semi_invuln", undefined); } catch (e_rel1) {}
                                try { if (variable_struct_exists(_release_tgt, "_sky_drop_held")) variable_struct_set(_release_tgt, "_sky_drop_held", undefined); } catch (e_rel2) {}
                            }
                        }
                    } catch (e_release) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] failed to release sky-drop target: " + string(e_release)); }
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] " + string(variable_struct_get(A, "name")) + " completes charge for move=" + string(move_id) + ", stored_target=" + string(_stored_tidx) + ", resolved_target_idx=" + string(target_idx));
                } else {
                    // Start charging: store move and intended target index so the second
                    // turn can reference it. PP already consumed earlier.
                        var _charge_rec = { move_id: move_id, target_index: target_idx };
                        if (move_id == 507){
                            try { variable_struct_set(_charge_rec, "sky_drop", true); } catch (e_sdflag) {}
                        }
                        if (is_struct(D)){
                            try { variable_struct_set(_charge_rec, "target_actor", D); } catch (e_tar) {}
                        }
                        variable_struct_set(A, "_charging_move", _charge_rec);
                        if (move_id == 130){
                            try {
                                if (!variable_struct_exists(A, "_stages") || !is_struct(variable_struct_get(A, "_stages"))) variable_struct_set(A, "_stages", {});
                                var _skull_stages = variable_struct_get(A, "_stages");
                                var _skull_prev = (variable_struct_exists(_skull_stages, "def") && is_real(variable_struct_get(_skull_stages, "def"))) ? variable_struct_get(_skull_stages, "def") : 0;
                                variable_struct_set(_skull_stages, "def", clamp(_skull_prev + 1, -6, 6));
                                variable_struct_set(A, "_stages", _skull_stages);
                                dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + "'s Defense rose!");
                            } catch (e_skull_def) {}
                        }
                        // If this is a semi-invulnerable two-turn move (fly/dig/dive/bounce/sky-attack),
                        // mark the actor so other move handlers can apply the special rules.
                        try {
                            var _phase = undefined;
                            if (move_id == 19) _phase = "fly";           // Fly
                            else if (move_id == 91) _phase = "dig";      // Dig
                            else if (move_id == 291) _phase = "dive";    // Dive
                            else if (move_id == 340) _phase = "bounce";  // Bounce
                            else if (move_id == 143) _phase = "fly";     // Sky Attack behaves like fly for interactions
                            else if (move_id == 467 || move_id == 566) _phase = "vanish"; // Shadow/Phantom Force vanish
                            else if (move_id == 507) _phase = "skydrop"; // Sky Drop lifts target
                            if (!is_undefined(_phase)){
                                variable_struct_set(A, "_semi_invuln", _phase);
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] set _semi_invuln=" + string(_phase) + " for " + string(variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "?"));
                                if (_phase == "skydrop" && is_struct(D)){
                                    try {
                                        variable_struct_set(D, "_semi_invuln", "skydrop");
                                        variable_struct_set(D, "_sky_drop_held", true);
                                    } catch (e_sdt) {}
                                }
                            }
                        } catch (e_si) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] failed to set _semi_invuln: " + string(e_si)); }
                    // Request a charge animation if available and return the 'used' dialog
                    try { __battle_request_animation_safe(A, { type: "charge", move_id: move_id }); } catch (e_ch) {}
                    return __battle_impl_return_used(_pid, A, mv_name);
                }
            }
        }
    } catch (e_two){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] handler error: " + string(e_two)); }

    if (is_real(_effect_id) && _effect_id == 171 && is_struct(A)){
        var _focus_punch_interrupted = false;
        try {
            _focus_punch_interrupted = variable_struct_exists(A, "_was_hit_this_turn") && variable_struct_get(A, "_was_hit_this_turn") == true && variable_struct_exists(A, "_last_received_damage") && is_real(variable_struct_get(A, "_last_received_damage")) && variable_struct_get(A, "_last_received_damage") > 0;
        } catch (e_focus_gate) { _focus_punch_interrupted = false; }
        if (_focus_punch_interrupted){
            __battle_record_move_usage(_pid, A, D, move_id, false);
            var _focus_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
            dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " lost focus and couldn't move!");
            return _focus_used_msg;
        }
    }

    if (is_real(_effect_id) && _effect_id == 176){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _taunt_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (is_struct(D)){
            variable_struct_set(D, "_taunt_state", { remaining: 2, source_move: move_id, source_actor_index: actor_idx });
            dialog_queue((variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target") + " fell for the taunt!");
        } else {
            dialog_queue("But it failed!");
        }
        return _taunt_used_msg;
    }

    if (is_real(move_id) && move_id == 283){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _endeavor_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (is_struct(A) && is_struct(D)){
            var _endeavor_user_hp = max(0, __battle_hp_now(A));
            var _endeavor_target_hp = max(0, __battle_hp_now(D));
            if (_endeavor_target_hp > _endeavor_user_hp){
                var _endeavor_delta = _endeavor_target_hp - _endeavor_user_hp;
                __battle_apply_damage(_pid, target_idx, _endeavor_delta, 1.0);
            } else {
                dialog_queue("But it failed!");
            }
        } else {
            dialog_queue("But it failed!");
        }
        return _endeavor_used_msg;
    }

    if (is_real(move_id) && move_id == 300){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _mud_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _mud_ok = false;
        try {
            __battle_field_set_status(_pid, "mud_sport", 5);
            _mud_ok = true;
        } catch (e_mud_set) { _mud_ok = false; }
        if (_mud_ok) dialog_queue("Electricity's power was weakened!");
        else dialog_queue("But it failed!");
        return _mud_used_msg;
    }
    if (is_real(move_id) && move_id == 346){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _water_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _water_ok = false;
        try {
            __battle_field_set_status(_pid, "water_sport", 5);
            _water_ok = true;
        } catch (e_water_set) { _water_ok = false; }
        if (_water_ok) dialog_queue("Fire's power was weakened!");
        else dialog_queue("But it failed!");
        return _water_used_msg;
    }
    if (is_real(move_id) && move_id == 293){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _camo_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _camo_type = 1;
        try {
            var _terr_id = (!is_undefined(__battle_get_terrain_id) ? string_lower(string(__battle_get_terrain_id(_pid))) : "");
            switch (_terr_id){
                case "grassy": _camo_type = 12; break;
                case "electric": _camo_type = 13; break;
                case "psychic": _camo_type = 14; break;
                case "misty": _camo_type = 18; break;
                default: _camo_type = 1; break;
            }
            variable_struct_set(A, "types", [_camo_type]);
            variable_struct_set(A, "type1", _camo_type);
            variable_struct_set(A, "type2", -1);
            if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                var _camo_mon = variable_struct_get(A, "mon");
                variable_struct_set(_camo_mon, "types", [_camo_type]);
                variable_struct_set(_camo_mon, "type1", _camo_type);
                variable_struct_set(_camo_mon, "type2", -1);
            }
            dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " transformed its type!");
        } catch (e_camo_apply) { dialog_queue("But it failed!"); }
        return _camo_used_msg;
    }
    if (is_real(move_id) && move_id == 366){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _tailwind_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _tailwind_side = 0;
        try {
            if (is_struct(A) && variable_struct_exists(A, "actor_index") && is_real(variable_struct_get(A, "actor_index"))) _tailwind_side = __battle_field_side_index_for_actor(variable_struct_get(A, "actor_index"));
            __battle_field_set_side_status(_pid, _tailwind_side, "tailwind", 4);
            dialog_queue("A tailwind began blowing behind the team!");
        } catch (e_tailwind_apply) { dialog_queue("But it failed!"); }
        return _tailwind_used_msg;
    }
    if (is_real(move_id) && move_id == 367){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _acu_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _acu_stats = ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"];
        var _acu_choices = [];
        if (!variable_struct_exists(A, "_stages") || !is_struct(variable_struct_get(A, "_stages"))) variable_struct_set(A, "_stages", {});
        var _acu_stage_map = variable_struct_get(A, "_stages");
        for (var _asi = 0; _asi < array_length(_acu_stats); ++_asi){
            var _akey = _acu_stats[_asi];
            var _aval = (variable_struct_exists(_acu_stage_map, _akey) && is_real(variable_struct_get(_acu_stage_map, _akey))) ? variable_struct_get(_acu_stage_map, _akey) : 0;
            if (_aval < 6) array_push(_acu_choices, _akey);
        }
        if (array_length(_acu_choices) <= 0){
            dialog_queue("But it failed!");
            return _acu_used_msg;
        }
        var _acu_pick = _acu_choices[irandom(array_length(_acu_choices) - 1)];
        var _acu_cur = (variable_struct_exists(_acu_stage_map, _acu_pick) && is_real(variable_struct_get(_acu_stage_map, _acu_pick))) ? variable_struct_get(_acu_stage_map, _acu_pick) : 0;
        variable_struct_set(_acu_stage_map, _acu_pick, min(6, _acu_cur + 2));
        variable_struct_set(A, "_stages", _acu_stage_map);
        try { __battle_request_animation_safe(A, { type: "stat_change", stat: _acu_pick, change: 2 }); } catch (e_acu_anim) {}
        dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + " sharply boosted " + string_upper(_acu_pick) + "!");
        return _acu_used_msg;
    }

    // Locked-move enforcement: Thrash and Rollout both force repeated use while active.
    try {
        if (is_struct(A) && is_real(move_id) && move_id != 37 && move_id != 80 && move_id != 200 && move_id != 205){
            var _lm = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
            if (is_struct(_lm) && variable_struct_exists(_lm, "force_reuse") && variable_struct_get(_lm, "force_reuse") == true && variable_struct_exists(_lm, "move_id") && is_real(variable_struct_get(_lm, "move_id")) && is_real(variable_struct_get(_lm, "remaining")) && variable_struct_get(_lm, "remaining") > 0){
                var _locked_move_id = variable_struct_get(_lm, "move_id");
                move_id = _locked_move_id;
                mv_name = __battle_move_name(move_id);
                mv_power = __battle_move_power(move_id, A, D);
            }
        }
    } catch (e_tl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][thrash] enforcement error: " + string(e_tl)); }

    // Fury Cutter resets when the user executes any other move, including status moves.
    try {
        if (is_struct(A) && is_real(move_id) && move_id != 210 && variable_struct_exists(A, "_fury_cutter_mul")){
            variable_struct_set(A, "_fury_cutter_mul", 1);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][fury] non-fury move reset: set _fury_cutter_mul=1");
        }
    } catch (e_fc_reset) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][fury] non-fury reset failed: " + string(e_fc_reset)); }

    // Counter / Mirror Coat / Metal Burst: reflect last-received damage if appropriate
    try {
        if (is_real(move_id) && is_struct(A)){
            // Counter: physical counter (reflects double physical damage received)
            if (move_id == 68){
                var lastd = (variable_struct_exists(A, "_last_received_damage") ? variable_struct_get(A, "_last_received_damage") : 0);
                var lastclass = (variable_struct_exists(A, "_last_received_move_damage_class") ? variable_struct_get(A, "_last_received_move_damage_class") : undefined);
                // In Gen3, Counter only responds to physical moves; we check damage class == 2 (physical) when available
                if (is_real(lastd) && lastd > 0 && (is_undefined(lastclass) || lastclass == 2)){
                    var reflect = lastd * 2;
                    // Apply reflected damage to the original attacker if we can determine actor index
                    var atk_idx = (variable_struct_exists(A, "_last_received_from_actor_index") ? variable_struct_get(A, "_last_received_from_actor_index") : undefined);
                    var _Bslot2 = __battle_ensure_slot(_pid);
                    if (is_real(atk_idx) && is_struct(_Bslot2)){
                        __battle_apply_damage(_pid, atk_idx, reflect, 1.0);
                        try { __battle_request_animation_safe(A, { type: "counter", amount: reflect }); } catch (e_ca) {}
                        return __battle_impl_return_used(_pid, A, mv_name);
                    }
                }
                // If nothing to reflect, play a blocked/miss animation
                try { __battle_request_animation_safe(A, { type: "blocked", reason: "counter_none" }); } catch (e_bn) {}
                return __battle_impl_return_used(_pid, A, mv_name, move_id);
            }

            // Mirror Coat: reflects special moves (damage class 3) back at double damage
            if (move_id == 243){
                var lastd2 = (variable_struct_exists(A, "_last_received_damage") ? variable_struct_get(A, "_last_received_damage") : 0);
                var lastclass2 = (variable_struct_exists(A, "_last_received_move_damage_class") ? variable_struct_get(A, "_last_received_move_damage_class") : undefined);
                if (is_real(lastd2) && lastd2 > 0 && (is_undefined(lastclass2) || lastclass2 == 3)){
                    var reflect2 = lastd2 * 2;
                    var atk_idx2 = (variable_struct_exists(A, "_last_received_from_actor_index") ? variable_struct_get(A, "_last_received_from_actor_index") : undefined);
                    var _Bslot3 = __battle_ensure_slot(_pid);
                    if (is_real(atk_idx2) && is_struct(_Bslot3)){
                        __battle_apply_damage(_pid, atk_idx2, reflect2, 1.0);
                        try { __battle_request_animation_safe(A, { type: "mirror_coat", amount: reflect2 }); } catch (e_mc) {}
                        return __battle_impl_return_used(_pid, A, mv_name);
                    }
                }
                try { __battle_request_animation_safe(A, { type: "blocked", reason: "mirror_none" }); } catch (e_bn2) {}
                return __battle_impl_return_used(_pid, A, mv_name, move_id);
            }

            // Metal Burst (id 368): reflect 1.5x last received damage (phys or spec in Gen4+; in Gen3 returns 1.5x both?)
            if (move_id == 368){
                var lastd3 = (variable_struct_exists(A, "_last_received_damage") ? variable_struct_get(A, "_last_received_damage") : 0);
                if (is_real(lastd3) && lastd3 > 0){
                    var reflect3 = floor(lastd3 * 1.5);
                    var atk_idx3 = (variable_struct_exists(A, "_last_received_from_actor_index") ? variable_struct_get(A, "_last_received_from_actor_index") : undefined);
                    var _Bslot4 = __battle_ensure_slot(_pid);
                    if (is_real(atk_idx3) && is_struct(_Bslot4)){
                        __battle_apply_damage(_pid, atk_idx3, reflect3, 1.0);
                        try { __battle_request_animation_safe(A, { type: "metal_burst", amount: reflect3 }); } catch (e_mb) {}
                        return __battle_impl_return_used(_pid, A, mv_name);
                    }
                }
                try { __battle_request_animation_safe(A, { type: "blocked", reason: "metal_none" }); } catch (e_mb2) {}
                return __battle_impl_return_used(_pid, A, mv_name);
            }
        }
    } catch (e_cm) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][counter] handler error: " + string(e_cm)); }

    // Allow moves with power > 0 OR explicit OHKO moves (e.g. Horn Drill) to proceed
    // to the damage application path. Some OHKO moves have no power value but
    // must still run the OHKO semantic branch in __battle_apply_move_damage.
    if (is_struct(D)){
        // Detect multi-hit moves via move meta (min_hits/max_hits). If multi-hit,
        // apply first hit now and schedule remaining hits in _pending_multi_hit so
        // the engine can show per-hit dialogs between hits (Emerald style).
        var mm_local = undefined;
        try { mm_local = __battle_get_move_meta(move_id); } catch (e_mm) { mm_local = undefined; }
        // Detect OHKO-type moves (explicit meta or classic Horn Drill id=32)
        var is_ohko_move = false;
        try {
            if (is_struct(mm_local) && variable_struct_exists(mm_local, "ohko") && variable_struct_get(mm_local, "ohko") == true) is_ohko_move = true;
            if (!is_ohko_move && is_real(move_id) && move_id == 32) is_ohko_move = true;
        } catch (e_o) { is_ohko_move = is_ohko_move; }
        var total_hits = 1;
        try {
            if (is_struct(mm_local)){
                var mh_min = (variable_struct_exists(mm_local, "min_hits") ? floor(variable_struct_get(mm_local, "min_hits")) : -1);
                var mh_max = (variable_struct_exists(mm_local, "max_hits") ? floor(variable_struct_get(mm_local, "max_hits")) : -1);
                if (is_real(mh_min) && mh_min > 0 && is_real(mh_max) && mh_max > 0){
                    if (mh_max > mh_min) total_hits = irandom_range(mh_min, mh_max);
                    else total_hits = mh_min;
                } else if (is_real(mh_min) && mh_min > 0) total_hits = mh_min;
                else if (is_real(mh_max) && mh_max > 0) total_hits = mh_max;
            }
        } catch (e_h) { total_hits = 1; }

        var _natural_gift_profile = undefined;
        try {
            if (is_real(_effect_id) && _effect_id == 223){
                var _natural_gift_enabled = true;
                if (!is_undefined(__battle_meta_held_items_enabled)) _natural_gift_enabled = (__battle_meta_held_items_enabled(A) != false);
                _natural_gift_profile = __battle_get_natural_gift_profile(A);
                if (!_natural_gift_enabled || !is_struct(_natural_gift_profile)){
                    dialog_queue("But it failed!");
                    return __battle_impl_return_used(_pid, A, mv_name, move_id);
                }
            }
        } catch (e_natural_gift_gate) { _natural_gift_profile = undefined; }

        // Apply first hit now (only if move has power, is OHKO, or uses a custom damage semantic like Present)
        if ((is_real(mv_power) && mv_power > 0) || is_ohko_move || (is_real(move_id) && move_id == 217)){
    var _target_had_paralysis = false;
    try {
        if (is_real(_effect_id) && _effect_id == 172 && !is_undefined(status_system_has_status)){
            _target_had_paralysis = status_system_has_status(D, "paralysis") || status_system_has_status(D, "paralyze");
            if (!_target_had_paralysis && variable_struct_exists(D, "mon") && is_struct(variable_struct_get(D, "mon"))) _target_had_paralysis = status_system_has_status(variable_struct_get(D, "mon"), "paralysis") || status_system_has_status(variable_struct_get(D, "mon"), "paralyze");
        }
    } catch (e_smelling_pre) { _target_had_paralysis = false; }
    // If this is a locked repeated move, mark that the actor executed it this turn.
    try {
        if (is_struct(A) && variable_struct_exists(A, "_locked_move")){
            var _exec_lock = variable_struct_get(A, "_locked_move");
            if (is_struct(_exec_lock) && variable_struct_exists(_exec_lock, "force_reuse") && variable_struct_get(_exec_lock, "force_reuse") == true && variable_struct_exists(_exec_lock, "move_id") && variable_struct_get(_exec_lock, "move_id") == move_id) variable_struct_set(A, "_locked_move_executed", true);
        }
    } catch (e_lf) {}
    try {
        if (is_real(_effect_id) && _effect_id == 223 && is_struct(_natural_gift_profile) && is_struct(A)){
            variable_struct_set(A, "_pending_natural_gift", _natural_gift_profile);
            __battle_set_held_item_snapshot(A, -1, "");
        }
    } catch (e_natural_gift_consume) {}
    var resf = __battle_apply_move_damage(_pid, target_idx, A, D, move_id, mv_power);
        var _semi_blocked = false;
        try {
            var _Bsemi_chk = __battle_ensure_slot(_pid);
            if (is_struct(_Bsemi_chk) && variable_struct_exists(_Bsemi_chk, "__semi_guard_blocked") && variable_struct_get(_Bsemi_chk, "__semi_guard_blocked") == true){
                _semi_blocked = true;
                variable_struct_set(_Bsemi_chk, "__semi_guard_blocked", false);
            }
        } catch (e_sflag) { _semi_blocked = false; }
        if (_semi_blocked){
            try { if (is_struct(A) && variable_struct_exists(A, "_pending_natural_gift")) variable_struct_set(A, "_pending_natural_gift", undefined); } catch (e_natural_gift_clear_block) {}
            return "";
        }
        var dmgh = (is_array(resf) ? resf[0] : 0);
        var _damage_move_missed = __battle_consume_damage_miss(_pid);
        if (!_damage_move_missed){
            try { __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, dmgh, mm_local); } catch (e_meta) {}
        }
        try {
            if (is_real(move_id) && move_id == 280 && is_real(dmgh) && dmgh > 0){
                var _brick_side_hit = __battle_field_side_index_for_actor(target_idx);
                var _brick_broke = false;
                var _reflect_turns_hit = __battle_field_get_barrier_or(_pid, _brick_side_hit, "reflect", 0);
                if (is_real(_reflect_turns_hit) && _reflect_turns_hit > 0){ __battle_field_clear_barrier(_pid, _brick_side_hit, "reflect"); _brick_broke = true; }
                var _screen_turns_hit = __battle_field_get_barrier_or(_pid, _brick_side_hit, "light_screen", 0);
                if (is_real(_screen_turns_hit) && _screen_turns_hit > 0){ __battle_field_clear_barrier(_pid, _brick_side_hit, "light_screen"); _brick_broke = true; }
                if (_brick_broke) dialog_queue("The protective barriers were shattered!");
            }
            if (is_real(move_id) && move_id == 282 && is_real(dmgh) && dmgh > 0 && is_struct(D)){
                var _knock_item = __battle_get_held_item_snapshot(D);
                if (is_real(_knock_item.id) && _knock_item.id > 0){
                    variable_struct_set(D, "_last_lost_item_id", _knock_item.id);
                    variable_struct_set(D, "_last_lost_item_name", _knock_item.name);
                    __battle_set_held_item_snapshot(D, -1, "");
                    dialog_queue((variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target") + " lost its held item!");
                }
            }
            if (is_real(_effect_id) && _effect_id == 225 && is_real(dmgh) && dmgh > 0 && is_struct(A) && is_struct(D)){
                var _pluck_item = __battle_get_held_item_snapshot(D);
                if (__battle_item_snapshot_is_berry(_pluck_item)){
                    __battle_set_held_item_snapshot(D, -1, "");
                    var _pluck_user_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user");
                    var _pluck_target_name = (variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target");
                    var _pluck_can_use = true;
                    try {
                        if (!is_undefined(__battle_meta_held_items_enabled)) _pluck_can_use = (__battle_meta_held_items_enabled(A) != false);
                    } catch (e_pluck_embargo) { _pluck_can_use = true; }
                    if (_pluck_can_use){
                        var _pluck_res = __battle_consume_borrowed_berry(_pluck_item.id, A);
                        dialog_queue(_pluck_user_name + " ate " + _pluck_target_name + "'s Berry!");
                        if (is_struct(_pluck_res) && variable_struct_exists(_pluck_res, "messages") && is_array(variable_struct_get(_pluck_res, "messages"))){
                            var _pluck_msgs = variable_struct_get(_pluck_res, "messages");
                            for (var _pmi = 0; _pmi < array_length(_pluck_msgs); ++_pmi){
                                var _pluck_msg = _pluck_msgs[_pmi];
                                if (is_string(_pluck_msg) && string_length(_pluck_msg) > 0) dialog_queue(_pluck_msg);
                            }
                        }
                    } else {
                        dialog_queue(_pluck_user_name + " destroyed " + _pluck_target_name + "'s Berry, but couldn't use it!");
                    }
                }
            }
            if (is_real(_effect_id) && _effect_id == 201 && is_real(dmgh) && dmgh > 0 && is_struct(D)){
                if (__battle_try_apply_status_with_chance(D, "burn", 10, A)){
                    dialog_queue((variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target") + " was burned!");
                }
            }
            if (is_real(_effect_id) && _effect_id == 203 && is_real(dmgh) && dmgh > 0 && is_struct(D)){
                if (__battle_try_apply_status_with_chance(D, "toxic", 50, A)){
                    dialog_queue((variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target") + " was badly poisoned!");
                }
            }
            if (is_real(_effect_id) && _effect_id == 198 && is_real(dmgh) && dmgh > 0 && is_struct(D)){
                var _secret_status = "confusion";
                try {
                    var _secret_family = __battle_terrain_power_family(_pid);
                    if (is_struct(_secret_family) && variable_struct_exists(_secret_family, "secret_status")) _secret_status = string(variable_struct_get(_secret_family, "secret_status"));
                } catch (e_secret_family) { _secret_status = "confusion"; }
                if (__battle_try_apply_status_with_chance(D, _secret_status, 30, A)){
                    var _secret_target_name = (variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target");
                    switch (string_lower(_secret_status)){
                        case "sleep": dialog_queue(_secret_target_name + " grew drowsy!"); break;
                        case "paralysis":
                        case "paralyze": dialog_queue(_secret_target_name + " was paralyzed!"); break;
                        case "confusion": dialog_queue(_secret_target_name + " became confused!"); break;
                    }
                }
            }
            if (is_real(_effect_id) && _effect_id == 210 && is_real(dmgh) && dmgh > 0 && is_struct(D)){
                if (__battle_try_apply_status_with_chance(D, "poison", 10, A)){
                    dialog_queue((variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target") + " was poisoned!");
                }
            }
            if (is_real(_effect_id) && _effect_id == 218 && is_real(dmgh) && dmgh > 0 && is_struct(D) && !is_undefined(status_system_clear_status)){
                var _wake_had_sleep = false;
                try {
                    _wake_had_sleep = status_system_has_status(D, "sleep");
                    if (!_wake_had_sleep && variable_struct_exists(D, "mon") && is_struct(variable_struct_get(D, "mon"))) _wake_had_sleep = status_system_has_status(variable_struct_get(D, "mon"), "sleep");
                } catch (e_wake_hit_chk) { _wake_had_sleep = false; }
                if (_wake_had_sleep){
                    status_system_clear_status(D, "sleep");
                    if (variable_struct_exists(D, "mon") && is_struct(variable_struct_get(D, "mon"))) status_system_clear_status(variable_struct_get(D, "mon"), "sleep");
                    dialog_queue((variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target") + " woke up!");
                }
            }
            if (is_real(_effect_id) && _effect_id == 229 && is_real(dmgh) && dmgh > 0 && is_struct(A)){
                var _switch_slot = __battle_ensure_slot(_pid);
                if (actor_idx == 0){
                    var _P_ut = (is_undefined(party_ensure) ? undefined : party_ensure(_pid));
                    var _can_ut = false;
                    if (is_struct(_P_ut) && variable_struct_exists(_P_ut, "mons") && is_array(variable_struct_get(_P_ut, "mons"))){
                        var _ut_mons = variable_struct_get(_P_ut, "mons");
                        var _self_ut_mon = (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) ? variable_struct_get(A, "mon") : A;
                        for (var _ut_i = 0; _ut_i < array_length(_ut_mons); ++_ut_i){
                            var _ut_mon = _ut_mons[_ut_i];
                            if (!is_struct(_ut_mon) || _ut_mon == _self_ut_mon) continue;
                            var _ut_hp = __battle_hp_now(_ut_mon);
                            if (is_real(_ut_hp) && _ut_hp > 0){ _can_ut = true; break; }
                        }
                    }
                    if (_can_ut && !is_undefined(party_open) && is_struct(_P_ut)){
                        party_open(_pid);
                        try { if (!is_undefined(party_set_swap_mode_impl)) party_set_swap_mode_impl(_pid, true, false); } catch (e_ut_swap) {}
                        try { variable_struct_set(_P_ut, "lock", 0); } catch (e_ut_lock) {}
                    }
                } else {
                    var _next_ut = -1;
                    try { _next_ut = __battle_trainer_next_alive_index(_switch_slot, (variable_struct_exists(_switch_slot, "_trainer_party_active_idx") ? variable_struct_get(_switch_slot, "_trainer_party_active_idx") : -1)); } catch (e_ut_next) { _next_ut = -1; }
                    if (is_real(_next_ut) && _next_ut >= 0 && !is_undefined(__battle_trainer_perform_switch_action)){
                        try { __battle_trainer_perform_switch_action(_pid, _next_ut, { move_id: move_id, forced: false }); } catch (e_ut_enemy) {}
                    }
                }
            }
        } catch (e_brick_hit) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][brick-break] post-hit failed: " + string(e_brick_hit)); }
        try {
            if (is_real(_effect_id) && _effect_id == 172 && _target_had_paralysis && is_real(dmgh) && dmgh > 0 && !is_undefined(status_system_clear_status)){
                status_system_clear_status(D, "paralysis");
                status_system_clear_status(D, "paralyze");
                if (variable_struct_exists(D, "mon") && is_struct(variable_struct_get(D, "mon"))){
                    var _clear_mon = variable_struct_get(D, "mon");
                    status_system_clear_status(_clear_mon, "paralysis");
                    status_system_clear_status(_clear_mon, "paralyze");
                }
            }
        } catch (e_smelling_post) {}
        try {
            if (is_real(move_id) && move_id == 6 && is_real(dmgh) && dmgh > 0){
                var _payday_level = (is_struct(A) && variable_struct_exists(A, "level") && is_real(variable_struct_get(A, "level"))) ? floor(variable_struct_get(A, "level")) : 1;
                var _payday_amount = max(1, _payday_level * 5);
                var _payday_slot = __battle_ensure_slot(_pid);
                if (is_struct(_payday_slot)){
                    var _payday_cur = (variable_struct_exists(_payday_slot, "_pay_day_money") && is_real(variable_struct_get(_payday_slot, "_pay_day_money"))) ? floor(variable_struct_get(_payday_slot, "_pay_day_money")) : 0;
                    variable_struct_set(_payday_slot, "_pay_day_money", _payday_cur + _payday_amount);
                    dialog_queue("Coins were scattered everywhere!");
                }
            }
        } catch (e_payday) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pay-day] failed: " + string(e_payday)); }
        try {
            if (is_real(dmgh) && dmgh > 0 && is_struct(A)){
                var _recharge_eid = undefined;
                if (variable_global_exists("_moves") && is_array(global._moves) && is_real(move_id) && move_id >= 0 && move_id < array_length(global._moves)){
                    var _recharge_move = global._moves[move_id];
                    if (is_struct(_recharge_move) && variable_struct_exists(_recharge_move, "effect_id") && is_real(variable_struct_get(_recharge_move, "effect_id"))) _recharge_eid = floor(variable_struct_get(_recharge_move, "effect_id"));
                }
                if (is_real(_recharge_eid) && _recharge_eid == 81){
                    variable_struct_set(A, "_recharge_turn", true);
                    variable_struct_set(A, "_recharge_move", move_id);
                }
            }
        } catch (e_recharge_set) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][recharge] set failed: " + string(e_recharge_set)); }

        // Hazard removal moves: Rapid Spin (229) clears hazards on user's side;
        // Defog (432) clears hazards on the target's side. Implement here
        // to ensure flags set by meta handlers are removed immediately when used.
        try {
            if (is_real(move_id) && (move_id == 229 || move_id == 432)){
                var _Bslot_rrr = __battle_ensure_slot(_pid);
                if (is_struct(_Bslot_rrr)){
                    if (move_id == 229){
                        // Rapid Spin: clear hazards on user's side (slot-side of the user)
                        try {
                            variable_struct_set(_Bslot_rrr, "_side_spikes", 0);
                            variable_struct_set(_Bslot_rrr, "_side_toxic_spikes", 0);
                            variable_struct_set(_Bslot_rrr, "_side_stealth_rock", 0);
                            variable_struct_set(_Bslot_rrr, "_side_sticky_web", false);
                            // Request a clear-hazards animation and dialog
                            try { __battle_request_animation_safe(_pid, { type: "clear_hazards", actor: A, target: D }); } catch (e_anim) {}
                            try { var nmC = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(nmC) + " removed entry hazards!", false); } catch (e_msgc) {}
                        } catch (e_clr) {}
                    } else if (move_id == 432){
                        // Defog: clears hazards on the target's side. Attempt to determine
                        // which side the target occupies. If D is undefined, clear both.
                        try {
                            variable_struct_set(_Bslot_rrr, "_side_spikes", 0);
                            variable_struct_set(_Bslot_rrr, "_side_toxic_spikes", 0);
                            variable_struct_set(_Bslot_rrr, "_side_stealth_rock", 0);
                            variable_struct_set(_Bslot_rrr, "_side_sticky_web", false);
                            // Request a clear-hazards animation and dialog
                            try { __battle_request_animation_safe(_pid, { type: "clear_hazards", actor: A, target: D }); } catch (e_anim2) {}
                            try { var nmD = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(nmD) + " cleared the field!", false); } catch (e_msgd) {}
                        } catch (e_defc) {}
                    }
                    // Mark that a meta-effect change occurred so UI updates can run
                    try { variable_struct_set(_Bslot_rrr, "_meta_effect_applied", true); } catch (e_me) {}
                }
            }
        } catch (e_hclr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] hazard-clear failed: " + string(e_hclr)); }

        // Special-case: Jump Kick / High Jump Kick — if the move missed (dmgh == 0),
        // apply miss recoil equal to 50% of the attacker's max HP.
        try {
            if (is_real(move_id) && (move_id == 26 || move_id == 136) && is_struct(A)){
                if (!is_real(dmgh) || dmgh <= 0){
                    // attacker actor index discovery
                    var atk_idx = undefined;
                    try { if (variable_struct_exists(A, "actor_index")) atk_idx = variable_struct_get(A, "actor_index"); } catch (e_ai) {}
                    try { if (!is_real(atk_idx) && variable_struct_exists(A, "slot")) atk_idx = variable_struct_get(A, "slot"); } catch (e_ai2) {}
                    try {
                        if (!is_real(atk_idx)){
                            var _Bt = __battle_ensure_slot(_pid);
                            if (is_struct(_Bt) && variable_struct_exists(_Bt, "actor") && is_array(variable_struct_get(_Bt, "actor"))){ var __acts_t = variable_struct_get(_Bt, "actor"); for (var _ii=0; _ii<array_length(__acts_t); ++_ii) if (is_struct(__acts_t[_ii]) && __acts_t[_ii] == A){ atk_idx = _ii; break; } }
                        }
                    } catch (e_ad) {}
                    var ahpmax = (variable_struct_exists(A, "hp_max") ? variable_struct_get(A, "hp_max") : (variable_struct_exists(A, "maxhp") ? variable_struct_get(A, "maxhp") : (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon")) && variable_struct_exists(variable_struct_get(A, "mon"), "hp_max") ? variable_struct_get(variable_struct_get(A, "mon"), "hp_max") : 1)));
                    ahpmax = max(1, floor(real(ahpmax)));
                    var recoil = max(1, floor(ahpmax * 0.5));
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][jump-kick] miss recoil for " + string(variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"?") + ", move_id=" + string(move_id) + ", amt=" + string(recoil));
                    try { if (is_real(atk_idx)) __battle_apply_damage(_pid, atk_idx, recoil, 1.0); else __battle_set_hp_now(A, max(0, __battle_hp_now(A) - recoil)); } catch (e_rk) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][jump-kick] recoil failed: " + string(e_rk)); }
                }
            }
        } catch (e_jk) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][jump-kick] handler error: " + string(e_jk)); }

        // Fury Cutter: if this move hit successfully, increment a per-attacker multiplier so
        // subsequent uses in the same battle become stronger. If the move missed, reset multiplier.
        try {
            if (is_real(move_id) && move_id == 210 && is_struct(A)){
                // A hit considered successful when dmgh > 0
                if (is_real(dmgh) && dmgh > 0){
                    var cur = (variable_struct_exists(A, "_fury_cutter_mul") && is_real(variable_struct_get(A, "_fury_cutter_mul"))) ? variable_struct_get(A, "_fury_cutter_mul") : 1;
                    // Double multiplier each successful hit, but cap to a reasonable value (e.g., 16x)
                    var nextm = min(cur * 2, 16);
                    variable_struct_set(A, "_fury_cutter_mul", nextm);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][fury] hit: set _fury_cutter_mul=" + string(nextm));
                } else {
                    // Miss or zero damage resets multiplier
                    variable_struct_set(A, "_fury_cutter_mul", 1);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][fury] miss/reset: set _fury_cutter_mul=1");
                }
            } else if (is_struct(A)){
                // Using any other move resets the Fury Cutter multiplier
                if (variable_struct_exists(A, "_fury_cutter_mul")) variable_struct_set(A, "_fury_cutter_mul", 1);
            }
        } catch (e_fc2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][fury] multiplier update failed: " + string(e_fc2)); }

        // Rollout: each successful hit doubles the next hit's power while the lock remains active.
        try {
            if (is_real(move_id) && move_id == 205 && is_struct(A)){
                if (is_real(dmgh) && dmgh > 0){
                    var cur_roll = (variable_struct_exists(A, "_rollout_mul") && is_real(variable_struct_get(A, "_rollout_mul"))) ? variable_struct_get(A, "_rollout_mul") : 1;
                    var next_roll = min(cur_roll * 2, 16);
                    variable_struct_set(A, "_rollout_mul", next_roll);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][rollout] hit: set _rollout_mul=" + string(next_roll));
                } else {
                    variable_struct_set(A, "_rollout_mul", 1);
                    try { if (variable_struct_exists(A, "_locked_move")) variable_struct_set(A, "_locked_move", undefined); } catch (e_roll_clear) {}
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][rollout] miss/reset: cleared lock and reset _rollout_mul=1");
                }
            } else if (is_struct(A)){
                var _roll_lock = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
                var _roll_active = (is_struct(_roll_lock) && variable_struct_exists(_roll_lock, "move_id") && variable_struct_get(_roll_lock, "move_id") == 205 && is_real(variable_struct_get(_roll_lock, "remaining")) && variable_struct_get(_roll_lock, "remaining") > 0);
                if (!_roll_active && variable_struct_exists(A, "_rollout_mul")) variable_struct_set(A, "_rollout_mul", 1);
            }
        } catch (e_roll) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][rollout] multiplier update failed: " + string(e_roll)); }

        // If multiple hits, schedule the rest into the battle slot for per-hit processing
        if (!_damage_move_missed && is_real(total_hits) && total_hits > 1){
            try {
                var _pm = { move_id: move_id, actor_index: actor_idx, target_index: target_idx, mv_power: mv_power, remaining: max(0, total_hits - 1), total_hits: total_hits };
                var _B = __battle_ensure_slot(_pid);
                if (is_struct(_B)) variable_struct_set(_B, "_pending_multi_hit", _pm);
            } catch (e_sched) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][multihit] scheduling failed: " + string(e_sched)); }
        }

        // If the slot recorded an OHKO miss, present a miss message instead of generic 'used' text
        try {
            var _Bslot_rr = __battle_ensure_slot(_pid);
            if (is_struct(_Bslot_rr) && variable_struct_exists(_Bslot_rr, "_last_ohko_miss") && variable_struct_get(_Bslot_rr, "_last_ohko_miss") == true){
                // clear the marker and return a clearer miss message
                try { variable_struct_set(_Bslot_rr, "_last_ohko_miss", undefined); } catch (e_clr) {}
                return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + "'s attack missed!";
            }
        } catch (e_rr) {}
        if (_damage_move_missed){
            return string((variable_struct_exists(A,"name") ? variable_struct_get(A,"name") : "The user")) + "'s attack missed!";
        }
        }

        // For non-damaging/status moves (mv_power <= 0), ensure meta effects run here
        // before returning the generic 'used' dialog (e.g., terrains, weather, setup moves).
        if (!(is_real(mv_power) && mv_power > 0)){
            try {
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                    show_debug_message("[battle][impl] applying meta (status) for move_id=" + string(move_id));
                }
                __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, 0, __battle_get_move_meta(move_id));
            } catch (e_meta_nd) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][impl] meta(status) error: " + string(e_meta_nd)); }
        }

        try {
            if (is_real(move_id) && (move_id == 120 || move_id == 153) && is_struct(A)){
                var _self_ko_hp = __battle_hp_now(A);
                if (is_real(_self_ko_hp) && _self_ko_hp > 0){
                    try { __battle_apply_damage(_pid, actor_idx, _self_ko_hp, 1.0); } catch (e_sdmg) { __battle_set_hp_now(A, 0); }
                }
            }
        } catch (e_self_ko) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][self-ko] handler error: " + string(e_self_ko)); }

        try { if (is_struct(A) && variable_struct_exists(A, "_pending_natural_gift")) variable_struct_set(A, "_pending_natural_gift", undefined); } catch (e_natural_gift_clear_end) {}

        return __battle_impl_return_used(_pid, A, mv_name, move_id);
    }
}

// Ensure this impl is discoverable via the central registry
try {
    if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
    try { variable_struct_set(variable_global_get("_battle_impls"), "__battle_perform_action_impl", __battle_perform_action_impl); } catch (e_reg) {}
} catch (e) {}

// Expose a small registration function to handle load-order: callers can invoke
// this to ensure the perform_action impl is present in the central registry.
function __battle_moves_impls_register(){
    try {
        if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
        try { variable_struct_set(variable_global_get("_battle_impls"), "__battle_perform_action_impl", __battle_perform_action_impl); } catch (e_reg) {}
        // Also register the 'real' key the proxy checks for
        try { variable_struct_set(variable_global_get("_battle_impls"), "__battle_perform_action_impl_real", __battle_perform_action_impl); } catch (e_reg2) {}
    } catch (e) {}
}
