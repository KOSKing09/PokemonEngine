/// @file scr_interact.gml
/// Requires your player to expose grid position and facing vector.
function interact_try(_player) {
    if (is_undefined(_player)) return false;
    var tx = _player.grid_x + _player.face_x;
    var ty = _player.grid_y + _player.face_y;
    // Ask for NPC at tile
    if (function_exists(npc_find_at_tile)) {
        var n = npc_find_at_tile(tx,ty);
        if (!is_undefined(n) && is_instance(n)) {
            if (variable_instance_exists(n, "on_interact") && is_method(n.on_interact)) { n.direction_face(-_player.face_x, -_player.face_y); n.on_interact(_player); return true; }
        }
    }
    // Ask events for tile (optional extension)
    return false;
}
