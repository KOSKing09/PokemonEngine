// Rogue world layer roles.
// Each named layer can use a different tileset in the room editor. The
// generator writes tile numbers into the layer assigned to each role.
if (!is_undefined(rogue_world_configure_layers)){
    rogue_world_configure_layers({
        ground: "FLOOR",
        decor: "FLOOR_OBJECTS",
        _solid: "WALL",
        collision: "BLOCKS"
    });
}

rogue_world_register_biome("grassland", {
    floor_tile: 9,
    solid_tile: 1,
    solid_chance: 0.035,
    decor: [
        { role:"decor", tile:0, chance:0.045 },
        { role:"decor", tile:0, chance:0.025 }
    ],
    battle_area_type: "grassy"
});

if (!is_undefined(rogue_world_room_start)) rogue_world_room_start();
