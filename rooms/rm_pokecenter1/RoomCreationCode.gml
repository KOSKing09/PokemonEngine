// Pokemon Center room setup.
// The nurse is placed as an oNpc instance in rm_pokecenter1.yy. Keep the full
// nurse setup here so the room does not depend on hidden instance defaults.
with (oNpc){
    if (variable_instance_exists(id, "pokemon_center_nurse") && pokemon_center_nurse == true){
        pokemon_center_nurse = true;
        npc_id = "pokecenter_nurse";
        npc_sprite_base = "spr_nursejoy";
        npc_facing_dir = 2;
        trainer_enabled = false;
        wander_enabled = false;
        interact_radius = 40;
        dialog_text = "Hello, and welcome to the Pokemon Center.";
        if (!is_undefined(overworld_npc_init)) overworld_npc_init(id);
        if (!is_undefined(pokemon_center_set_nurse_pose)) pokemon_center_set_nurse_pose(id, "down");
    }
}
