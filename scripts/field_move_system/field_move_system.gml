function field_move_normalize(_move){
    var _m = string_lower(string_trim(string(_move)));
    _m = string_replace_all(_m, "-", " ");
    _m = string_replace_all(_m, "_", " ");
    return _m;
}

function field_move_display_name(_move){
    var _m = field_move_normalize(_move);
    if (_m == "rock smash") return "Rock Smash";
    if (_m == "fly") return "Fly";
    if (_m == "cut") return "Cut";
    if (_m == "surf") return "Surf";
    if (_m == "strength") return "Strength";
    return string_upper(string_copy(_m, 1, 1)) + string_delete(_m, 1, 1);
}

function field_move_party_has_move(_pid, _move){
    var _want = field_move_normalize(_move);
    if (string_length(_want) <= 0) return false;
    if (is_undefined(party_model_get_mons)) return false;

    var _mons = party_model_get_mons(max(0, floor(_pid)));
    if (!is_array(_mons)) return false;

    for (var _i = 0; _i < array_length(_mons); ++_i){
        var _mon = _mons[_i];
        if (!is_struct(_mon)) continue;
        var _moves = [];
        if (variable_struct_exists(_mon, "moves") && is_array(variable_struct_get(_mon, "moves"))) _moves = variable_struct_get(_mon, "moves");
        else if (variable_struct_exists(_mon, "move_ids") && is_array(variable_struct_get(_mon, "move_ids"))) _moves = variable_struct_get(_mon, "move_ids");
        for (var _m = 0; _m < array_length(_moves); ++_m){
            var _mid = _moves[_m];
            if (!is_real(_mid) || _mid <= 0) continue;
            var _name = "";
            if (!is_undefined(scr_move_name_by_id)){
                try { _name = scr_move_name_by_id(_mid); } catch (e_move_name) { _name = ""; }
            }
            if (field_move_normalize(_name) == _want) return true;
        }
    }
    return false;
}

function field_move_player_can_use(_pid, _move){
    if (variable_global_exists("FIELD_MOVES_IGNORE_REQUIREMENTS") && global.FIELD_MOVES_IGNORE_REQUIREMENTS == true) return true;
    return field_move_party_has_move(_pid, _move);
}

function field_move_prop_setup(_inst, _move, _kind){
    if (!instance_exists(_inst)) return false;
    variable_instance_set(_inst, "field_move_required", field_move_normalize(_move));
    variable_instance_set(_inst, "field_move_kind", string_lower(string(_kind)));
    variable_instance_set(_inst, "trainer_enabled", false);
    variable_instance_set(_inst, "wander_enabled", false);
    variable_instance_set(_inst, "interact_radius", 24);
    variable_instance_set(_inst, "world_solid", true);
    return true;
}

function field_move_prop_interact(_inst, _pid){
    if (!instance_exists(_inst)) return false;
    var _move = variable_instance_exists(_inst, "field_move_required") ? field_move_normalize(variable_instance_get(_inst, "field_move_required")) : "";
    if (string_length(_move) <= 0) return false;

    var _move_name = field_move_display_name(_move);
    if (!field_move_player_can_use(_pid, _move)){
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "A Pokemon that knows " + _move_name + " can use this.");
        return true;
    }

    var _kind = variable_instance_exists(_inst, "field_move_kind") ? string_lower(string(variable_instance_get(_inst, "field_move_kind"))) : _move;
    if (_kind == "rock" || _kind == "rock smash" || _move == "rock smash"){
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Your Pokemon used Rock Smash!");
        instance_destroy(_inst);
        return true;
    }

    if (_kind == "fly" || _move == "fly"){
        if (variable_instance_exists(_inst, "field_move_target_room")){
            var _target = variable_instance_get(_inst, "field_move_target_room");
            if (is_real(_target) && room_exists(_target)){
                if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Your Pokemon used Fly!");
                room_goto(_target);
                return true;
            }
        }
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Your Pokemon used Fly!");
        return true;
    }

    if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Your Pokemon used " + _move_name + "!");
    return true;
}
