// Runtime room for rogue interior JSON layouts.
// Export authored interiors into data/rogue_rooms, then enter them through an
// owarp with _room = rm_rogue_building and rogue_room_file set.
if (!is_undefined(rogue_world_configure_layers)){
    rogue_world_configure_layers({
        ground: "FLOOR",
        decor: "FLOOR_OBJECTS",
        _solid: "WALL",
        collision: "BLOCKS"
    });
}

if (!is_undefined(rogue_room_runtime_start)) rogue_room_runtime_start();
