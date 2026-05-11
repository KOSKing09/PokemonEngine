function __battle_command_actor_indexes(_pid){
    var _B = __battle_ensure_slot(_pid);
    var _out = [];
    var _format = (is_struct(_B) && variable_struct_exists(_B, "battle_format")) ? string(variable_struct_get(_B, "battle_format")) : "single";
    var _versus = (is_struct(_B) && variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true);
    if (_versus && is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor")) && variable_struct_exists(_B, "actor_owner_pid") && is_array(variable_struct_get(_B, "actor_owner_pid"))){
        var _owners = variable_struct_get(_B, "actor_owner_pid");
        for (var _vi = 0; _vi < array_length(variable_struct_get(_B, "actor")); ++_vi){
            if (!__battle_actor_index_alive(_pid, _vi)) continue;
            if (_vi >= array_length(_owners)) continue;
            var _owner_pid = _owners[_vi];
            if (is_real(_owner_pid) && floor(_owner_pid) == floor(_pid)) array_push(_out, _vi);
        }
        return _out;
    }
    if (_format != "double"){
        if (__battle_actor_index_alive(_pid, 0)) array_push(_out, 0);
        return _out;
    }
    for (var _i = 0; _i <= 1; ++_i){
        if (!__battle_actor_index_alive(_pid, _i)) continue;
        var _owner = __battle_actor_control_pid(_pid, _i);
        if (!is_real(_owner) || _owner == _pid) array_push(_out, _i);
    }
    return _out;
}

function __battle_find_player_turn_action(_B, _actorIndex){
    if (!is_struct(_B) || !is_real(_actorIndex)) return undefined;
    var _queued = (variable_struct_exists(_B, "_player_turn_actions") && is_array(variable_struct_get(_B, "_player_turn_actions"))) ? variable_struct_get(_B, "_player_turn_actions") : [];
    for (var _i = 0; _i < array_length(_queued); ++_i){
        var _act = _queued[_i];
        if (is_struct(_act) && variable_struct_exists(_act, "actor_index") && is_real(variable_struct_get(_act, "actor_index")) && floor(variable_struct_get(_act, "actor_index")) == floor(_actorIndex)) return _act;
    }
    return undefined;
}

function __battle_remove_player_turn_action(_B, _actorIndex){
    if (!is_struct(_B) || !is_real(_actorIndex)) return;
    var _queued = (variable_struct_exists(_B, "_player_turn_actions") && is_array(variable_struct_get(_B, "_player_turn_actions"))) ? variable_struct_get(_B, "_player_turn_actions") : [];
    var _next = [];
    for (var _i = 0; _i < array_length(_queued); ++_i){
        var _act = _queued[_i];
        if (!is_struct(_act)) continue;
        if (variable_struct_exists(_act, "actor_index") && is_real(variable_struct_get(_act, "actor_index")) && floor(variable_struct_get(_act, "actor_index")) == floor(_actorIndex)) continue;
        array_push(_next, _act);
    }
    variable_struct_set(_B, "_player_turn_actions", _next);
}

function __battle_store_player_turn_action(_B, _action){
    if (!is_struct(_B) || !is_struct(_action) || !variable_struct_exists(_action, "actor_index")) return;
    var _actorIndex = variable_struct_get(_action, "actor_index");
    __battle_remove_player_turn_action(_B, _actorIndex);
    var _queued = (variable_struct_exists(_B, "_player_turn_actions") && is_array(variable_struct_get(_B, "_player_turn_actions"))) ? variable_struct_get(_B, "_player_turn_actions") : [];
    array_push(_queued, _action);
    variable_struct_set(_B, "_player_turn_actions", _queued);
}

function __battle_player_action_locked(_action){
    return is_struct(_action) && variable_struct_exists(_action, "lock_action") && variable_struct_get(_action, "lock_action") == true;
}

function __battle_next_command_actor_index(_pid, _afterActorIndex){
    var _B = __battle_ensure_slot(_pid);
    var _actors = __battle_command_actor_indexes(_pid);
    for (var _i = 0; _i < array_length(_actors); ++_i){
        var _idx = _actors[_i];
        if (_idx <= _afterActorIndex) continue;
        if (!is_struct(__battle_find_player_turn_action(_B, _idx))) return _idx;
    }
    return -1;
}

function __battle_previous_command_actor_index(_pid, _beforeActorIndex){
    var _B = __battle_ensure_slot(_pid);
    var _actors = __battle_command_actor_indexes(_pid);
    for (var _i = array_length(_actors) - 1; _i >= 0; --_i){
        var _idx = _actors[_i];
        if (_idx >= _beforeActorIndex) continue;
        var _queued = __battle_find_player_turn_action(_B, _idx);
        if (is_struct(_queued) && !__battle_player_action_locked(_queued)) return _idx;
    }
    return -1;
}

function __battle_all_command_actions_ready(_pid){
    var _B = __battle_ensure_slot(_pid);
    var _actors = [];
    var _format = (is_struct(_B) && variable_struct_exists(_B, "battle_format")) ? string(variable_struct_get(_B, "battle_format")) : "single";
    var _versus = (is_struct(_B) && variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true);
    if (_versus && is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor")) && variable_struct_exists(_B, "actor_owner_pid") && is_array(variable_struct_get(_B, "actor_owner_pid"))){
        var _owners = variable_struct_get(_B, "actor_owner_pid");
        for (var _vi = 0; _vi < array_length(variable_struct_get(_B, "actor")); ++_vi){
            if (!__battle_actor_index_alive(_pid, _vi)) continue;
            if (_vi >= array_length(_owners)) continue;
            var _owner_pid = _owners[_vi];
            if (is_real(_owner_pid) && floor(_owner_pid) >= 0) array_push(_actors, _vi);
        }
    } else if (_format == "double"){
        for (var _ai = 0; _ai <= 1; ++_ai){
            if (__battle_actor_index_alive(_pid, _ai)) array_push(_actors, _ai);
        }
    } else {
        _actors = __battle_command_actor_indexes(_pid);
    }
    if (array_length(_actors) <= 0) return false;
    for (var _i = 0; _i < array_length(_actors); ++_i){
        if (!is_struct(__battle_find_player_turn_action(_B, _actors[_i]))) return false;
    }
    return true;
}

function __battle_move_target_mode(_move_id){
    var _target = "";
    var _target_id = undefined;
    try {
        if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
            var _mm = __battle_get_move_meta(_move_id);
            if (is_struct(_mm) && variable_struct_exists(_mm, "target")) _target = string(variable_struct_get(_mm, "target"));
            if (is_struct(_mm) && variable_struct_exists(_mm, "target_id") && is_real(variable_struct_get(_mm, "target_id"))) _target_id = floor(variable_struct_get(_mm, "target_id"));
        }
    } catch (e_target_meta) {}
    try {
        if ((string_length(_target) <= 0 || !is_real(_target_id)) && variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){
            var _mv = global._moves[_move_id];
            if (is_struct(_mv) && variable_struct_exists(_mv, "target")) _target = string(variable_struct_get(_mv, "target"));
            if (is_struct(_mv) && variable_struct_exists(_mv, "target_id") && is_real(variable_struct_get(_mv, "target_id"))) _target_id = floor(variable_struct_get(_mv, "target_id"));
        }
    } catch (e_target_moves) {}
    _target = string_lower(_target);
    if (string_pos("self", _target) > 0 || string_pos("user", _target) > 0 || string_pos("own", _target) > 0) return "self";
    if (string_pos("ally", _target) > 0 || string_pos("friend", _target) > 0) return "ally";
    if (is_real(_target_id)){
        if (_target_id == 7) return "self";
        if (_target_id == 3 || _target_id == 5 || _target_id == 13 || _target_id == 15) return "ally";
    }
    return "opponent";
}

function __battle_target_candidates(_pid, _actorIndex, _move_id){
    var _B = __battle_ensure_slot(_pid);
    var _out = [];
    var _mode = __battle_move_target_mode(_move_id);
    var _side = __battle_actor_side(_actorIndex);
    if (_mode == "self"){
        if (__battle_actor_index_alive(_pid, _actorIndex)) array_push(_out, floor(_actorIndex));
        return _out;
    }

    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return _out;
    var _actors = variable_struct_get(_B, "actor");
    for (var _i = 0; _i < array_length(_actors); ++_i){
        if (!__battle_actor_index_alive(_pid, _i)) continue;
        if (_mode == "ally"){
            if (__battle_actor_side(_i) != _side) continue;
        } else if (_i == floor(_actorIndex)) {
            continue;
        }
        array_push(_out, _i);
    }
    if (array_length(_out) <= 0){
        var _fallback = __battle_get_default_target_index(_pid, _actorIndex);
        if (__battle_actor_index_alive(_pid, _fallback)) array_push(_out, _fallback);
    }
    return _out;
}

function __battle_target_candidate_select_index(_targets, _targetIndex){
    if (!is_array(_targets)) return 0;
    for (var _i = 0; _i < array_length(_targets); ++_i){
        if (_targets[_i] == _targetIndex) return _i;
    }
    return 0;
}

function __battle_sort_target_candidates(_pid, _actorIndex, _targets){
    if (!is_array(_targets)) return [];
    var _ordered = [];
    var _side = __battle_actor_side(_actorIndex);
    var _preferred = (_side == 0) ? [2, 3, 1, 0] : [0, 1, 3, 2];
    for (var _pi = 0; _pi < array_length(_preferred); ++_pi){
        var _want = _preferred[_pi];
        for (var _ti = 0; _ti < array_length(_targets); ++_ti){
            if (_targets[_ti] == _want){ array_push(_ordered, _want); break; }
        }
    }
    for (var _ri = 0; _ri < array_length(_targets); ++_ri){
        var _cand = _targets[_ri];
        var _seen = false;
        for (var _oi = 0; _oi < array_length(_ordered); ++_oi){
            if (_ordered[_oi] == _cand){ _seen = true; break; }
        }
        if (!_seen) array_push(_ordered, _cand);
    }
    return _ordered;
}

function __battle_target_pick_index(_B){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_target_pick_index") || !is_real(variable_struct_get(_B, "_target_pick_index"))) return 0;
    return max(0, floor(variable_struct_get(_B, "_target_pick_index")));
}

function __battle_side_has_alive_actor(_pid, _side){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_array(_B.actor)) return false;
    for (var _i = 0; _i < array_length(_B.actor); ++_i){
        if (__battle_actor_side(_i) != floor(_side)) continue;
        if (__battle_actor_index_alive(_pid, _i)) return true;
    }
    return false;
}

function __battle_commit_player_action(_pid, _action){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_struct(_action)) return false;
    var _versus = (variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true);

    __battle_store_player_turn_action(_B, _action);
    if (variable_struct_exists(_action, "actor_index") && variable_struct_get(_action, "actor_index") == 0) variable_struct_set(_B, "turn_action_player", _action);

    variable_struct_set(_B, "_command_pending_action", undefined);
    variable_struct_set(_B, "_target_pick_targets", undefined);
    variable_struct_set(_B, "_target_pick_index", 0);

    if (__battle_all_command_actions_ready(_pid)){
        if (!_versus) variable_struct_set(_B, "turn_action_enemy", __battle_enemy_choose_action(_pid));
        variable_struct_set(_B, "turn_queue", __battle_build_turn_actions(_pid));
        try { variable_struct_set(_B, "_player_turn_actions", []); } catch (e_clear_turn_queue_actions) {}
        try { variable_struct_set(_B, "_preserve_player_turn_actions_once", false); } catch (e_clear_turn_queue_preserve) {}
        variable_struct_set(_B, "turn_i", 0);
        variable_struct_set(_B, "phase", "turn");
        return true;
    }

    var _actor_index = (variable_struct_exists(_action, "actor_index") && is_real(variable_struct_get(_action, "actor_index"))) ? floor(variable_struct_get(_action, "actor_index")) : -1;
    var _next_actor = __battle_next_command_actor_index(_pid, _actor_index);
    if (_next_actor >= 0) variable_struct_set(_B, "_command_actor_index", _next_actor);
    var _sys_ui = (variable_struct_exists(_B, "sys_ui") ? variable_struct_get(_B, "sys_ui") : undefined);
    if (is_struct(_sys_ui)){
        variable_struct_set(_sys_ui, "menu", "root");
        variable_struct_set(_sys_ui, "selX", 0);
        variable_struct_set(_sys_ui, "selY", 0);
    }
    return false;
}

function __battle_resolve_live_target_index(_pid, _actorIndex, _targetIndex, _move_id){
    var _targets = __battle_target_candidates(_pid, _actorIndex, _move_id);
    if (is_array(_targets)){
        _targets = __battle_sort_target_candidates(_pid, _actorIndex, _targets);
        for (var _i = 0; _i < array_length(_targets); ++_i){
            if (_targets[_i] == _targetIndex) return _targetIndex;
        }
        var _mode = __battle_move_target_mode(_move_id);
        var _side = __battle_actor_side(_actorIndex);
        if (_mode == "opponent"){
            for (var _j = 0; _j < array_length(_targets); ++_j){
                if (__battle_actor_side(_targets[_j]) != _side) return _targets[_j];
            }
        }
        if (array_length(_targets) > 0) return _targets[0];
    }
    return __battle_get_default_target_index(_pid, _actorIndex);
}
