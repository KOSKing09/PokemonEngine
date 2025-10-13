// P1 view
var p0 = player_by_pid(0);
if (p0 != noone) {
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[draw73][debug] calling dialog2p_draw_world pid=0");
    dialog2p_draw_world(0, view_camera[0]);
}

// P2 view (only if you actually use a second camera / splitscreen)
var p1 = player_by_pid(1);
    if (p1 != noone && cam_is_valid_index(1)) {
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[draw73][debug] calling dialog2p_draw_world pid=1");
        dialog2p_draw_world(1, view_camera[1]);
    }
