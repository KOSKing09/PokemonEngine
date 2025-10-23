controls_update();

// open bag from player objects (you already do via Inventory)
bags_update();
pause_update();
party_update();     // alongside your bags_update();

// Allow dialog system to drain any queued messages when boxes are closed
if (!is_undefined(dialog2p_step)){
	dialog2p_step(0);
	if (variable_global_exists("DIALOG2P") && is_array(global.DIALOG2P) && array_length(global.DIALOG2P) > 1) dialog2p_step(1);
}

// (Developer F12 debug removed)
