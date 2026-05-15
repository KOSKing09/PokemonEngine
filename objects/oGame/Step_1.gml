controls_update();
if (!is_undefined(transition_update)) transition_update();
var _transition_block = (!is_undefined(transition_is_blocking) && transition_is_blocking());

var _vk_block_0 = (!is_undefined(virtual_keyboard_blocks_input) && virtual_keyboard_blocks_input(0));
var _vk_block_1 = (!is_undefined(virtual_keyboard_blocks_input) && virtual_keyboard_blocks_input(1));
var _vk_block_any = (_vk_block_0 || _vk_block_1);

// open bag from player objects (you already do via Inventory)
if (!_vk_block_any && !_transition_block){
	bags_update();
	pause_update();
	party_update();
	poke_index_update();
	if (!is_undefined(pc_update)) pc_update();
}
var _battle_any_for_cutscene = (!is_undefined(battle_any_open) && battle_any_open());
if (!_battle_any_for_cutscene && !is_undefined(cutscene_step)){
	cutscene_step(0);
	if (variable_global_exists("CUTSCENE") && is_array(global.CUTSCENE) && array_length(global.CUTSCENE) > 1) cutscene_step(1);
}
if (!_battle_any_for_cutscene && !is_undefined(cutscene_update)){
	cutscene_update(0);
	if (variable_global_exists("CUTSCENE") && is_array(global.CUTSCENE) && array_length(global.CUTSCENE) > 1) cutscene_update(1);
}
evolution_update(0);
if (variable_global_exists("EVOLUTION") && is_array(global.EVOLUTION) && array_length(global.EVOLUTION) > 1) evolution_update(1);
virtual_keyboard_update(0);
if (variable_global_exists("VKEYBOARD") && is_array(global.VKEYBOARD) && array_length(global.VKEYBOARD) > 1) virtual_keyboard_update(1);

// Allow dialog system to drain any queued messages when boxes are closed
if (!is_undefined(dialog2p_step)){
	dialog2p_step(0);
	if (variable_global_exists("DIALOG2P") && is_array(global.DIALOG2P) && array_length(global.DIALOG2P) > 1) dialog2p_step(1);
}
if (!is_undefined(dialog2p_is_open) && !is_undefined(dialog2p_update)){
	if (dialog2p_is_open(0)) dialog2p_update(0);
	if (variable_global_exists("DIALOG2P") && is_array(global.DIALOG2P) && array_length(global.DIALOG2P) > 1){
		if (dialog2p_is_open(1)) dialog2p_update(1);
	}
}

if (!is_undefined(pokemon_center_update)){
	pokemon_center_update(0);
	if (variable_global_exists("DIALOG2P") && is_array(global.DIALOG2P) && array_length(global.DIALOG2P) > 1) pokemon_center_update(1);
}

if (!is_undefined(pokemon_followers_update_all)) pokemon_followers_update_all();

if (!is_undefined(battle_controller_update_all)) battle_controller_update_all();

// (Developer F12 debug removed)
