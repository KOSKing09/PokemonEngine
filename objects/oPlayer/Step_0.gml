// Only THIS player halts while THEY are in dialog
if (!is_undefined(transition_is_blocking) && transition_is_blocking()) exit;
if (!is_undefined(cutscene_blocks_player) && cutscene_blocks_player(pid)) exit;
if (dialog2p_is_open(pid)) exit;
var _battle_open = (!is_undefined(battle_is_open) && battle_is_open(pid));
var _vk_open = false;
try {
	if (!is_undefined(virtual_keyboard_blocks_input)) _vk_open = (virtual_keyboard_blocks_input(pid) == true);
} catch (e_vk_guard) {}
var _pc_open = (!is_undefined(pc_is_open) && pc_is_open(pid));
var _wild_assist_wait = (!is_undefined(multiplayer_wild_assist_request_active) && multiplayer_wild_assist_request_active());
var _npc_lock = (!is_undefined(overworld_player_locked_by_npc) && overworld_player_locked_by_npc(pid));
if (_battle_open && !is_undefined(player_force_stand_still)) player_force_stand_still(id);
if (_wild_assist_wait && !is_undefined(player_force_stand_still)) player_force_stand_still(id);
if (_npc_lock && !is_undefined(player_force_stand_still)) player_force_stand_still(id);
if (bag_is_open(pid) || _pc_open || pause_is_open(pid) || party_is_open(pid) || _battle_open || _vk_open || _wild_assist_wait || _npc_lock) exit;
// advance one tile at a time; Run (B/O) speeds up tween
grid_step(id, pid);

// feed anim with your grid state
var moving = (grid.state == "move");
player_anim_update_basic(id, moving, grid.dir);

depth = -(y - 5);
