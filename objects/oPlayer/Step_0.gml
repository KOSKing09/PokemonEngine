// Only THIS player halts while THEY are in dialog
if (dialog2p_is_open(pid)) exit;
var _battle_open = (!is_undefined(battle_is_open) && battle_is_open(pid));
var _vk_open = false;
try {
	if (!is_undefined(virtual_keyboard_blocks_input)) _vk_open = (virtual_keyboard_blocks_input(pid) == true);
} catch (e_vk_guard) {}
if (bag_is_open(pid) || pause_is_open(pid) || party_is_open(pid) || _battle_open || _vk_open) exit;
// advance one tile at a time; Run (B/O) speeds up tween
grid_step(id, pid);

// feed anim with your grid state
var moving = (grid.state == "move");
player_anim_update_basic(id, moving, grid.dir);