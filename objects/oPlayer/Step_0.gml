// Only THIS player halts while THEY are in dialog
if (dialog2p_is_open(pid)) exit;
var _battle_open = false;
if (variable_global_exists("sys_battles") && is_array(global.sys_battles)) {
	if (pid >= 0 && pid < array_length(global.sys_battles)) {
		var _slot_guard = global.sys_battles[pid];
		if (is_struct(_slot_guard)) {
			try { if (variable_struct_exists(_slot_guard, "sys_open")) _battle_open = (variable_struct_get(_slot_guard, "sys_open") == true); } catch (e_guard) {}
		}
	}
}
if (bag_is_open(pid) || pause_is_open(pid) || party_is_open(pid) || _battle_open) exit;
// advance one tile at a time; Run (B/O) speeds up tween
grid_step(id, pid);

// feed anim with your grid state
var moving = (grid.state == "move");
player_anim_update_basic(id, moving, grid.dir);