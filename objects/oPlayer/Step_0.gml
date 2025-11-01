if (keyboard_check_pressed(vk_f2)) {
	var _slot = undefined;
	if (variable_global_exists("sys_battles") && is_array(global.sys_battles)) {
		if (pid >= 0 && pid < array_length(global.sys_battles)) _slot = global.sys_battles[pid];
	}
	var _sys_open = false;
	var _phase = "";
	var _is_trainer = false;
	if (is_struct(_slot)) {
		try { if (variable_struct_exists(_slot, "sys_open")) _sys_open = (variable_struct_get(_slot, "sys_open") == true); } catch (e_sys) {}
		try { if (variable_struct_exists(_slot, "phase")) _phase = string(variable_struct_get(_slot, "phase")); } catch (e_phase) { _phase = ""; }
		try { if (variable_struct_exists(_slot, "_trainer_party") && is_array(variable_struct_get(_slot, "_trainer_party"))) _is_trainer = true; } catch (e_trainer) { _is_trainer = false; }
	}
	if (_sys_open && _is_trainer && _phase == "command") {
		global.__debug_trainer_switch_request = { pid: pid, ts: current_time };
		if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
			show_debug_message("[battle][debug] Trainer switch request queued for pid=" + string(pid));
		}
	} else if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
		show_debug_message("[battle][debug] Trainer switch shortcut unavailable (phase=" + string(_phase) + ")");
	}
}

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