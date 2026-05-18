if (!is_undefined(overworld_npc_step)) overworld_npc_step(id);
if (variable_instance_exists(id, "encounter_pokemon") && variable_instance_get(id, "encounter_pokemon") == true) {
    image_xscale = 0.67;
    image_yscale = 0.67;
    depth = -(y + 16);
} else {
    depth = -(y - 8);
}
