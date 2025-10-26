
// Drain any queued dialog first (opens next item if allowed), then advance if open
if (!is_undefined(dialog2p_step)) dialog2p_step(pid);
// Advance this player's dialog if open
if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(pid)) {
    if (!is_undefined(dialog2p_update)) dialog2p_update(pid);
}

// battle system
if (battle_is_open(0)){
	battle_update(0);
}

if (keyboard_check_pressed(vk_f1)){
	if (!battle_is_open(0)){
        /* 
        var trainer_party = [];
        if (!is_undefined(pokemon_factory_create)){
            var trainer_mon = pokemon_factory_create(25, irandom_range(7, 9), {});
            if (is_struct(trainer_mon)) trainer_party[array_length(trainer_party)] = trainer_mon;
        }
        var trainer_payload = {
            trainer_name: "Bug Catcher Rick",
            sprite: spr_PokemonEmeraldTrainers,
            sprite_index: 12,
            party: trainer_party
        };
        battle_open_trainer(0, trainer_payload);
        */
        battle_open(0, irandom_range(5,10), "man made paths");
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

if (!is_undefined(dialog2p_is_open) && !dialog2p_is_open(pid)) {
    var box = instance_nearest(x, y, oDialogBox);
    if (box != noone && point_distance(x, y, box.x, box.y) <= 16) {
            if (controls_pressed(pid,"Interact") && talk_cd <= 0) {
            if (!variable_global_exists("DIALOG_SPEED")) global.DIALOG_SPEED = 2;
            var box_text = "";
            if (instance_exists(box) && variable_instance_exists(box, "text")) {
                box_text = string(variable_instance_get(box, "text"));
            }
            try {
                if (!is_undefined(dialog2p_show_now)) {
                    dialog2p_show_now(pid, box_text);
                } else if (!is_undefined(dialog2p_enqueue_text)) {
                    dialog2p_enqueue_text(pid, box_text, box_text, "any");
                }
            } catch (e_) {}
            talk_cd = ceil(game_get_speed(gamespeed_fps) * 0.25); // ~0.25s lockout
        }
    }
}