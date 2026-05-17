if (!is_undefined(transition_is_blocking) && transition_is_blocking()) exit;

var _left = bbox_left + 1;
var _right = bbox_right - 1;
var _top = bbox_top + 1;
var _bottom = bbox_bottom - 1;

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

    var _pl_left = variable_instance_get(_pl, "bbox_left");
    var _pl_top = variable_instance_get(_pl, "bbox_top");
    var _pl_right = variable_instance_get(_pl, "bbox_right");
    var _pl_bottom = variable_instance_get(_pl, "bbox_bottom");
    if (_pl_right < _left || _pl_left > _right || _pl_bottom < _top || _pl_top > _bottom) continue;

    if (!is_undefined(sfx_play_safe)) sfx_play_safe(_warp_sound_res, 1);
    if (rogue_return_warp == true){
        if (!is_undefined(rogue_world_return_to_previous)) rogue_world_return_to_previous();
        exit;
    }
    if (!is_undefined(rogue_world_set_return)){
        var _return_x = variable_instance_get(_pl, "x");
        var _return_y = variable_instance_get(_pl, "y") + 16;
        rogue_world_set_return(room, _return_x, _return_y, variable_instance_exists(_pl, "facing_dir") ? variable_instance_get(_pl, "facing_dir") : 2, rogue_return_edge);
    }
    if (!is_undefined(rogue_world_prepare_enter)) rogue_world_prepare_enter(rogue_seed, rogue_chunk_x, rogue_chunk_y, rogue_spawn_x, rogue_spawn_y, variable_instance_exists(_pl, "facing_dir") ? variable_instance_get(_pl, "facing_dir") : 2, rogue_return_edge);
    world_warp_to(rm_world, rogue_spawn_x, rogue_spawn_y, {
        transition_style: rogue_transition_style,
        show_route: true,
        facing: 2
    });
    exit;
}
