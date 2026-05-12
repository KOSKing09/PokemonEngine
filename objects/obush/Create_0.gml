
image_speed = 0;
if (!is_undefined(overworld_encounter_init)) overworld_encounter_init(id);
if (!variable_instance_exists(id, "encounter_region_key")) variable_instance_set(id, "encounter_region_key", "demo_route_1");
if (!variable_instance_exists(id, "encounter_habitat")) variable_instance_set(id, "encounter_habitat", "bush");
if (!variable_instance_exists(id, "encounter_area_type")) variable_instance_set(id, "encounter_area_type", "forest");
if (!variable_instance_exists(id, "encounter_chance")) variable_instance_set(id, "encounter_chance", 1 / 12);
if (!variable_instance_exists(id, "encounter_radius")) variable_instance_set(id, "encounter_radius", max(sprite_width, sprite_height));
