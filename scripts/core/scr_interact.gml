/// @file scr_interact.gml
function interact_try(_player) {
    if (is_undefined(_player)) return false;

    var tile_x = _player.grid_x + _player.face_x;
    var tile_y = _player.grid_y + _player.face_y;

    var npc_find_idx = asset_get_index("npc_find_at_tile");
    if (npc_find_idx != -1) {
        var npc_inst = script_execute(npc_find_idx, tile_x, tile_y);
        if (npc_inst != noone && is_instance(npc_inst)) {
            if (variable_instance_exists(npc_inst, "direction_face")) npc_inst.direction_face(-_player.face_x, -_player.face_y);
            if (variable_instance_exists(npc_inst, "on_interact") && is_method(npc_inst.on_interact)) {
                npc_inst.on_interact(_player);
                return true;
            }
        }
    }
    return false;
}
