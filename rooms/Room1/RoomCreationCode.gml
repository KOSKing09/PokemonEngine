// Room1 encounter table.
// Edit these entries to control which Pokemon appear from Room1 encounter objects.
// `weight` is relative chance; higher numbers are more common.
// `min_level` and `max_level` are the level range for that species.
if (!is_undefined(overworld_encounter_register_table)){
    overworld_encounter_register_table("route0", "bush", [
        { species_id: 17,  weight: 26, min_level: 3, max_level: 6 },
        { species_id: 188, weight: 28, min_level: 4, max_level: 7 },
        { species_id: 268, weight: 24, min_level: 4, max_level: 8 },
        { species_id: 559, weight: 14, min_level: 5, max_level: 8 },
        { species_id: 471, weight: 8,  min_level: 6, max_level: 9 }
    ]);

    // Optional second table for any Room1 encounter object you set to habitat "grass".
    overworld_encounter_register_table("route0", "grass", [
        { species_id: 17,  weight: 30, min_level: 3, max_level: 6 },
        { species_id: 188, weight: 25, min_level: 4, max_level: 7 },
        { species_id: 268, weight: 20, min_level: 4, max_level: 8 },
        { species_id: 559, weight: 15, min_level: 5, max_level: 8 },
        { species_id: 471, weight: 10, min_level: 6, max_level: 9 }
    ]);
}

// Point Room1 bush encounters at the Room1 table above instead of the global demo fallback.
with (obush){
    if (!is_undefined(overworld_encounter_init)) overworld_encounter_init(id);
    encounter_region_key = "route0";
    encounter_habitat = "bush";
    encounter_area_type = "forest";
    encounter_chance = 1 / 12;
    encounter_level_min = 3;
    encounter_level_max = 9;
}

// Room1 NPC implementation sample: a non-trainer bug catcher that starts an
// overworld cutscene on interact. Copy this block and change id/position/text.
var _cutscene_npc = instance_create_layer(208, 240, "Instances", oNpc);
if (_cutscene_npc != noone){
    _cutscene_npc.npc_id = "room1_bugcatcher_cutscene_test";
    _cutscene_npc.npc_sprite_base = "spr_bugcatcher";
    _cutscene_npc.npc_facing_dir = 2;
    _cutscene_npc.trainer_enabled = false;
    _cutscene_npc.cutscene_on_interact = true;
    _cutscene_npc.cutscene_shared = true;
    _cutscene_npc.cutscene_lines = [
        "This is an overworld cutscene test.",
        "If player two is joined, both players are locked until I finish talking."
    ];
    _cutscene_npc.dialog_text = "Talk to me to test overworld cutscenes.";
}
