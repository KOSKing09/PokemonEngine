// Only THIS player halts while THEY are in dialog
if (dialog2p_is_open(pid)) exit;
if (bag_is_open(pid) || pause_is_open(pid) || party_is_open(pid) || battle_is_open(pid)) exit;
// advance one tile at a time; Run (B/O) speeds up tween
grid_step(id, pid);

// feed anim with your grid state
var moving = (grid.state == "move");
player_anim_update_basic(id, moving, grid.dir);