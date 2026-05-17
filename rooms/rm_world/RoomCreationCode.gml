// Rogue world layer roles.
// Each named layer can use a different tileset in the room editor. The
// generator writes tile numbers into the layer assigned to each role.
if (!is_undefined(rogue_world_configure_layers)){
    rogue_world_configure_layers({
        ground: "FLOOR",
        decor: "FLOOR_OBJECTS",
        decor2: "EMERALD_FLOOR",
        _solid: "WALL",
        collision: "BLOCKS"
    });
}
if (variable_global_exists("ROGUE_WORLD") && is_struct(global.ROGUE_WORLD)){
    global.ROGUE_WORLD.biome_solids_enabled = false;
    global.ROGUE_WORLD.biome_cell_tiles = 128;
    global.ROGUE_WORLD.climate_cell_tiles = 192;
    global.ROGUE_WORLD.temperature_band_tiles = 1024;
    // Keep blending off until the edge-only blend pass is ready for heavier maps.
    // Turning this on is safe now, but it still adds work during chunk paging.
    global.ROGUE_WORLD.biome_blend_enabled = false;
    global.ROGUE_WORLD.biome_blend_distance_tiles = 4;
    global.ROGUE_WORLD.path_tile = 9;
    global.ROGUE_WORLD.path_width_tiles = 3;
    global.ROGUE_WORLD.town_grid_chunks = 6;
    global.ROGUE_WORLD.town_path_enabled = true;
    global.ROGUE_WORLD.chunk_cache_limit = 24;
    global.ROGUE_WORLD.edge_page_generate_after_ms = 210;
    global.ROGUE_WORLD.edge_warp_sound = snd_Warp_Exit;
    global.ROGUE_WORLD.edge_warp_sound_enabled = true;
    global.ROGUE_WORLD.encounter_enabled = true;
    global.ROGUE_WORLD.encounter_hidden_enabled = false;
    global.ROGUE_WORLD.encounter_visible_enabled = true;
    global.ROGUE_WORLD.encounter_visible_loose_spawns = false;
    global.ROGUE_WORLD.encounter_default_chance = 1 / 18;
    global.ROGUE_WORLD.encounter_default_level_min = 3;
    global.ROGUE_WORLD.encounter_default_level_max = 9;
    global.ROGUE_WORLD.encounter_path_enabled = false;
    global.ROGUE_WORLD.encounter_visible_spawn_min = 70;
    global.ROGUE_WORLD.encounter_visible_spawn_max = 150;
    global.ROGUE_WORLD.encounter_visible_max_active = 6;
    global.ROGUE_WORLD.encounter_visible_patch_radius_tiles = 6;
}

// Rogue biome encounter tables.
// Edit these exactly like Room1's route tables. Each biome below points at one
// of these region/habitat pairs through its encounter_* fields.
if (!is_undefined(overworld_encounter_register_table)){
    overworld_encounter_register_table("rogue_grassland", "grass", [
        { species_id: 16,  weight: 28, min_level: 3, max_level: 6 },
        { species_id: 19,  weight: 24, min_level: 3, max_level: 6 },
        { species_id: 263, weight: 20, min_level: 4, max_level: 7 },
        { species_id: 265, weight: 16, min_level: 4, max_level: 7 },
        { species_id: 10,  weight: 12, min_level: 3, max_level: 5 }
    ]);

    overworld_encounter_register_table("rogue_forest", "forest", [
        { species_id: 10,  weight: 24, min_level: 4, max_level: 7 },
        { species_id: 13,  weight: 22, min_level: 4, max_level: 7 },
        { species_id: 16,  weight: 18, min_level: 4, max_level: 8 },
        { species_id: 261, weight: 18, min_level: 5, max_level: 9 },
        { species_id: 285, weight: 18, min_level: 5, max_level: 10 }
    ]);
}

rogue_world_register_biome("grassland", {
    floor_tile: 9,
    solid_tile: 1,
    solid_chance: 0,
    decor: [
        { role:"decor", tile:36, chance:0.045 },
        { role:"decor2", tile:969, chance:0.005 }
    ],
    blend: [
        { toward:"forest", role:"decor2", tile:969, chance:0.75, overlay:true }
    ],
    battle_area_type: "grassy",
    encounter_region_key: "rogue_grassland",
    encounter_habitat: "grass",
    encounter_chance: 1 / 18,
    encounter_level_min: 3,
    encounter_level_max: 8,
    encounter_battle_format: "single",
    encounter_double_chance: 0.08,
    encounter_path_enabled: false
});

rogue_world_register_biome("forest", {
    floor_tile: 18,z
    solid_tile: 1,
    solid_chance: 0,
    blend: [
        { toward:"grassland", role:"decor", tile:36, chance:0.55, overlay:true }
    ],
    battle_area_type: "forest",
    encounter_region_key: "rogue_forest",
    encounter_habitat: "forest",
    encounter_chance: 1 / 14,
    encounter_level_min: 4,
    encounter_level_max: 10,
    encounter_battle_format: "single",
    encounter_double_chance: 0.12,
    encounter_path_enabled: false
});

if (!is_undefined(rogue_world_room_start)) rogue_world_room_start();
