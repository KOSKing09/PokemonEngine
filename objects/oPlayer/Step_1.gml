

// Advance this player's dialog if open
if (dialog2p_is_open(pid)) {
    dialog2p_update(pid);
}

// battle system
if (battle_is_open(0)){
	battle_update(0);
}

if (keyboard_check_pressed(vk_f1)){
	if (!battle_is_open(0)){
		battle_open(0, irandom_range(5, 35));
	}else{
		battle_close(0);
	}
}

// detect closing edge: if it was open last frame and now not
if (!variable_instance_exists(id,"_dlg_was")) _dlg_was = false;
var _now = dialog2p_is_open(pid);
if (_dlg_was && !_now) talk_cd = max(talk_cd, ceil(game_get_speed(gamespeed_fps) * 0.20)); // ~0.2s
_dlg_was = _now;

if (talk_cd > 0) talk_cd--;

// open when close to a box, but respect cooldown

if (!dialog2p_is_open(pid)) {
    var box = instance_nearest(x, y, oDialogBox);
    if (box != noone && point_distance(x, y, box.x, box.y) <= 16) {
        if (controls_pressed(pid,"Interact") && talk_cd <= 0) {
            if (!variable_global_exists("DIALOG_SPEED")) global.DIALOG_SPEED = 2;
            dialog2p_open_text(pid, box.text);
            talk_cd = ceil(game_get_speed(gamespeed_fps) * 0.25); // ~0.25s lockout
        }
    }
}