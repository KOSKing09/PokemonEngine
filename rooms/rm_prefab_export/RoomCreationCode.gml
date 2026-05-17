// Paint prefab tiles/objects in this room, then run this room from GameMaker.
// A save dialog opens so you can choose the folder and JSON filename. After the
// dialog/export finishes, the game closes.
if (!is_undefined(rogue_world_configure_layers)){
    rogue_world_configure_layers({
        ground: "FLOOR",
        decor: "FLOOR_OBJECTS",
        _solid: "WALL",
        collision: "BLOCKS"
    });
}

if (!is_undefined(rogue_world_export_current_room_prefab_dialog)){
    rogue_world_export_current_room_prefab_dialog("rogue_prefab.json", {
        export_all_tile_layers: true,
        layer_tilesets: {
            wally: "TileSet2"
        },
        weight: 1,
        biomes: ["grassland"]
    });
}

game_end();
