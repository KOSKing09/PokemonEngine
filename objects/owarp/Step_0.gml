if (!is_undefined(transition_is_blocking) && transition_is_blocking()) exit;

var _target_room = _room;
if (is_string(_target_room)){
    try { _target_room = asset_get_index(_target_room); } catch (e_warp_room_name) { _target_room = noone; }
}
if (_target_room == -1) _target_room = noone;
if (_target_room == noone && return_to_rogue != true) exit;

var _left = bbox_left + 1;
var _right = bbox_right - 1;
var _top = bbox_top + 1;
var _bottom = bbox_bottom - 1;
var _opts = { transition_style: trans_style };
var _warp_sound_res = warp_sound;
if (is_undefined(_warp_sound_res) || _warp_sound_res == -1 || _warp_sound_res == noone){
    switch (string_lower(string(warp_kind))){
        case "door": _warp_sound_res = snd_Warp_Door; break;
        case "ladder": _warp_sound_res = snd_Warp_Ladder; break;
        default: _warp_sound_res = snd_Warp_Exit; break;
    }
}

for (var _pid = 0; _pid < 2; ++_pid){
    var _pl = player_by_pid(_pid);
    if (_pl == noone) continue;
    if (_pid == 1 && !multiplayer_player_joined(1)) continue;

    var _moving_into_warp = controls_down(_pid, "MoveUp") || controls_down(_pid, "MoveRight") || controls_down(_pid, "MoveDown") || controls_down(_pid, "MoveLeft");
    if (!_moving_into_warp) continue;

    var _pl_left = variable_instance_get(_pl, "bbox_left");
    var _pl_top = variable_instance_get(_pl, "bbox_top");
    var _pl_right = variable_instance_get(_pl, "bbox_right");
    var _pl_bottom = variable_instance_get(_pl, "bbox_bottom");
    if (_pl_right < _left || _pl_left > _right || _pl_bottom < _top || _pl_top > _bottom) continue;

    if (return_to_rogue == true && !is_undefined(rogue_world_return_from_interior)){
        if (!is_undefined(sfx_play_safe)) sfx_play_safe(_warp_sound_res, 1);
        if (rogue_world_return_from_interior()) exit;
    }
    if (_target_room == noone) continue;

    if (remember_rogue_return == true && room == rm_world && _target_room != rm_world && !is_undefined(rogue_world_store_interior_return)){
        var _return_x = (is_real(rogue_return_x) && rogue_return_x >= 0) ? rogue_return_x : (variable_instance_get(_pl, "x") + real(rogue_return_offset_x));
        var _return_y = (is_real(rogue_return_y) && rogue_return_y >= 0) ? rogue_return_y : (variable_instance_get(_pl, "y") + real(rogue_return_offset_y));
        rogue_world_store_interior_return(_return_x, _return_y, variable_instance_exists(_pl, "facing_dir") ? variable_instance_get(_pl, "facing_dir") : 2);
    }

    if (_target_room == rm_rogue_building && is_string(rogue_room_file) && string_length(rogue_room_file) > 0 && !is_undefined(rogue_room_enter)){
        if (!is_undefined(sfx_play_safe)) sfx_play_safe(_warp_sound_res, 1);
        if (is_real(_x) && is_real(_y) && _x >= 0 && _y >= 0){
            if (rogue_room_enter(rogue_room_file, _x, _y)) exit;
        } else {
            if (rogue_room_enter(rogue_room_file)) exit;
        }
    }

    if (world_warp_to(_target_room, _x, _y, _opts)){
        if (!is_undefined(sfx_play_safe)) sfx_play_safe(_warp_sound_res, 1);
        exit;
    }
}
