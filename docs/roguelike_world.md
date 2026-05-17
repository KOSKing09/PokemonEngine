# Roguelike World

Owner: `scripts/roguelike_world/roguelike_world.gml`

`rm_world` is the first infinite-world foundation. It works like a reusable Emerald-style route room: the visible room is still a normal GameMaker room, but its tile layers are regenerated from infinite world coordinates. When the player crosses a room edge, the system advances the chunk coordinate, rebuilds the tilemaps from the same seed, and places the player on the opposite side.

This is how the world becomes infinite in GameMaker: the physical room is the active viewport, and `origin_tile_x/origin_tile_y` are the true world coordinates. The player is never meant to be trapped inside the original room border. The edge tiles stay walkable so stepping past an edge pages to the next generated chunk.

## Current Pieces

- `rm_world`: the generated world viewport room.
- `roguelike_world`: biome, prefab, reserved-zone, generation, and edge-paging runtime.
- `oroguewarp`: a warp object that prepares the roguelike seed/chunk and warps to `rm_world`.
- `rooms/rm_world/RoomCreationCode.gml`: calls `rogue_world_room_start()`.
- `objects/oGame/Step_1.gml`: calls `rogue_world_update_all()` every Step.
- `rooms/Room1/RoomCreationCode.gml`: currently spawns a dev `oroguewarp` at `(320, 128)` so the system can be tested.

## Room Requirements

`rm_world` needs these tile layers:

- `FLOOR`: generated ground.
- `FLOOR_OBJECTS`: flowers, grass details, and non-blocking tile decoration.
- `WALL`: visible solid tiles such as trees, rocks, cliffs, or water edges.
- `BLOCKS`: invisible/utility collision tiles.
- `Instances`: generated object layer for future NPCs, city prefabs, items, dungeon entrances, and props.

The generator currently assumes 64x64 tiles at 16 pixels each, matching the existing 1024x1024 `rm_world`.

## Layer Roles And Tilesets

The rogue generator does not directly pick a tileset. GameMaker tile layers own their tilesets in the room editor. That means you can use different tilesets by making different tile layers, assigning each layer the tileset you want, then telling the generator what each layer does.

Default role setup in `rooms/rm_world/RoomCreationCode.gml`:

```gml
rogue_world_configure_layers({
    ground: "FLOOR",
    decor: "FLOOR_OBJECTS",
    _solid: "WALL",
    collision: "BLOCKS"
});
```

What each role means:

- `ground`: base walkable ground such as grass, sand, dirt, cave floor, water floor, or path.
- `decor`: non-blocking details such as flowers, short grass, pebbles, puddles, moss, and path trim.
- `_solid`: visible blockers such as trees, rocks, cliff faces, fences, walls, and water edges.
- `collision`: invisible or utility blocking layer used by the movement/collision system.

The important rule: tile ids are local to the layer's tileset. If `FLOOR` uses `t_kanto`, then `floor_tile: 12` means tile `12` from `t_kanto`. If `WALL` uses `t_newbarktown`, then `solid_tile: 45` means tile `45` from `t_newbarktown`.

You can rename or add layers later:

```gml
rogue_world_configure_layers({
    ground: "Rogue_Ground_Kanto",
    decor: "Rogue_Decor_Kanto",
    _solid: "Rogue_Trees_NewBark",
    collision: "Rogue_Collision",
    flowers: "Rogue_Flowers",
    city_roofs: "Rogue_City_Roofs"
});
```

Then a biome or prefab can write to a role instead of a hard-coded layer:

```gml
decor: [
    { role:"flowers", tile:6, chance:0.08 },
    { role:"decor", tile:22, chance:0.04 }
]
```

If a rule uses `layer:"SomeLayer"` instead of `role:"decor"`, the generator writes directly to that layer name. Use roles for reusable biome code, and direct layer names for special one-off prefab details.

## Adding Tilemaps To Generation

To add a new generated tilemap layer:

1. Open `rm_world` in the room editor.
2. Add a new tile layer, for example `Rogue_Flowers`.
3. Assign that layer the tileset you want. This can be a different tileset from `FLOOR`, `WALL`, or any other layer.
4. Add the layer to `rogue_world_configure_layers(...)` in `rooms/rm_world/RoomCreationCode.gml`.
5. Use that role from a biome or prefab.

Example:

```gml
rogue_world_configure_layers({
    ground: "FLOOR",
    decor: "FLOOR_OBJECTS",
    _solid: "WALL",
    collision: "BLOCKS",
    flowers: "Rogue_Flowers",
    tree_tops: "Rogue_Tree_Tops",
    city_detail: "Rogue_City_Detail"
});
```

Then use those roles in biome decor:

```gml
rogue_world_register_biome("flower_route", {
    floor_tile: 12,
    solid_tile: 45,
    solid_chance: 0.03,
    decor: [
        { role:"flowers", tile:3, chance:0.08 },
        { role:"flowers", tile:4, chance:0.04 },
        { role:"decor", tile:18, chance:0.03 }
    ],
    battle_area_type: "grassy"
});
```

Collision is separate on purpose. If a tree uses `_solid` for the visible tree tile, it still needs the generator or prefab rule to write a blocking tile into the `collision` role. Prefab tile entries can do this with `solid:true`.

## Entering The World

Use `oroguewarp` for an overworld entrance.

Instance creation code:

```gml
rogue_seed = 1337;
rogue_chunk_x = 0;
rogue_chunk_y = 0;
rogue_spawn_x = 128;
rogue_spawn_y = 128;
rogue_return_edge = "up";
warp_kind = "door";
```

When an `oroguewarp` sends the player into `rm_world`, the rogue runtime stores:

- the room the player came from
- the return position just below the entrance warp
- the entry chunk and spawn point inside `rm_world`
- the return edge, from `rogue_return_edge`

To leave the infinite world, walk into the return edge on the entry chunk. For the current Room1 test entrance, `rogue_return_edge = "up"`, so the top edge of the first rogue chunk sends you back.

Valid return edges:

- `"up"`
- `"down"`
- `"left"`
- `"right"`
- `"any"`
- `"auto"` uses the edge behind the player based on facing direction

When the player overlaps the warp, it calls:

```gml
rogue_world_set_return(previous_room, return_x, return_y, return_facing, rogue_return_edge);
rogue_world_prepare_enter(rogue_seed, rogue_chunk_x, rogue_chunk_y, rogue_spawn_x, rogue_spawn_y, entry_facing, rogue_return_edge);
world_warp_to(rm_world, rogue_spawn_x, rogue_spawn_y, {
    transition_style: "emerald_fade_black",
    show_route: true,
    facing: 2
});
```

You can also enter from code:

```gml
rogue_world_set_return(room, player.x, player.y + 16, player.facing_dir);
rogue_world_warp_to(1337, 0, 0, 128, 128);
```

The return edge is only active on the entry chunk. The other edges keep generating infinite chunks.

## Biomes

Biomes are fully data-driven. The placeholder defaults are only there until final tile numbers are supplied.

Default registered ids:

- `grassland`
- `forest`
- `river`

## Quick Biome Setup

Yes: for a tile like grass, put the tile id number directly into the biome.

If grass is tile `9` on the layer assigned to the `ground` role, define the grassland biome like this:

```gml
rogue_world_register_biome("grassland", {
    floor_tile: 9,
    solid_tile: 1,
    solid_chance: 0.035,
    decor: [],
    battle_area_type: "grassy"
});
```

That means:

- `grassland` is the biome name/id.
- `floor_tile: 9` draws tile `9` on the `ground` layer.
- The `ground` layer is currently `FLOOR`.
- The actual tileset comes from whatever tileset is assigned to `FLOOR` in the room editor.

So if `FLOOR` uses your outdoor tileset, tile `9` from that tileset becomes the grass ground for the generated world.

## Random Blocks, Trees, And Decor

The generator places random blocker tiles because each biome can define:

```gml
solid_chance: 0.035
```

That means "sometimes place a solid obstacle on a non-path tile." If `solid_tile` is still set to a placeholder tile, it looks like random blocks. To stop that completely:

```gml
solid_chance: 0
```

To turn those blocks into trees, set `solid_tile` to your tree tile id:

```gml
rogue_world_register_biome("forest", {
    floor_tile: 9,
    solid_tile: 24,
    solid_chance: 0.12,
    decor: [],
    battle_area_type: "forest"
});
```

That draws tile `24` on the `_solid` role and writes collision to the `collision` role.

For flowers, grass clumps, rocks, and other non-blocking decorations, use `decor`:

```gml
decor: [
    { role:"decor", tile:31, chance:0.06 },
    { role:"flowers", tile:4, chance:0.03 }
]
```

Use biome rules for scattered natural decoration. Use prefabs for designed clusters, groves, paths, buildings, towns, landmarks, and decor patterns that need to be placed exactly.

Register or replace a biome:

```gml
rogue_world_register_biome("flower_field", {
    floor_tile: 12,
    solid_tile: 45,
    solid_chance: 0.04,
    decor: [
        { role:"decor", tile:88, chance:0.10 }, // flowers
        { role:"decor", tile:89, chance:0.04 }  // tall grass detail
    ],
    battle_area_type: "grassy"
});
```

Important fields:

- `floor_tile`: tile id drawn on `FLOOR`.
- `solid_tile`: tile id drawn on the `_solid` role when the generator places a blocking tile. `wall_tile` is still accepted as an old alias.
- `solid_chance`: chance a non-path tile becomes a solid obstacle.
- `decor`: array of optional non-blocking decoration tile rules.
- `battle_area_type`: the battle arena name to use later when encounters are attached.

Trees can be handled two ways:

- as solid tiles: draw the tree tile on the `_solid` role and write a collision tile into the `collision` role
- as generated objects: register a prefab/object entry that creates a tree object later

## Prefabs

Prefabs are the hook for cities, houses, special landmarks, dungeon doors, groves, puzzle chunks, and future handcrafted pieces.

## Room-Authored Prefabs

The preferred way to build bigger prefabs is to make them in a normal GameMaker room, then export that room into a JSON prefab file. This lets you place tiles and supported objects visually in the editor instead of hand-writing hundreds of tile entries.

The project now includes `rm_prefab_export`, a blank export-authoring room with these layers:

- `FLOOR`
- `FLOOR_OBJECTS`
- `WALL`
- `BLOCKS`
- `Instances`

To use it:

1. Open `rm_prefab_export`.
2. Paint the prefab on the tile layers.
3. Place objects on `Instances` if the prefab needs NPCs, items, warps, doors, trees, or dungeon entrances.
4. Run `rm_prefab_export` from GameMaker.
5. Pick the folder and filename in the save dialog.
6. The exporter writes the JSON file and closes the game.

`rm_prefab_export` uses this creation code:

```gml
rogue_world_export_current_room_prefab_dialog("rogue_prefab.json", {
    layers: ["FLOOR", "FLOOR_OBJECTS", "WALL", "BLOCKS"],
    weight: 1,
    biomes: ["grassland"]
});

game_end();
```

So by default it exports only those listed layers, not every possible layer in the room. If you add a new tile layer, add it to the `layers` array:

```gml
rogue_world_export_current_room_prefab_dialog("flower_patch.json", {
    layers: ["FLOOR", "FLOOR_OBJECTS", "WALL", "BLOCKS", "Rogue_Flowers"],
    weight: 2,
    biomes: ["grassland", "forest"]
});
```

The lower-level exporter behaves the same way:

- if `opts.layers` is provided, it exports exactly those layers
- if `opts.layers` is not provided, it exports the currently configured rogue role layers

Recommended workflow:

1. Make a new room for the prefab, for example `rm_prefab_tiny_city`.
2. Add tile layers with the same names you want the prefab to preserve, such as `FLOOR`, `FLOOR_OBJECTS`, `WALL`, and `BLOCKS`.
3. Assign whatever tileset you want to each layer in the room editor.
4. Paint only the prefab area. Empty surrounding space is cropped out automatically.
5. Place supported objects if needed, such as `oNpc`, `oitem`, `oFieldMoveProp`, or `oroguewarp`.
6. Add this to the prefab room's Room Creation Code and run the room once:

```gml
rogue_world_configure_layers({
    ground: "FLOOR",
    decor: "FLOOR_OBJECTS",
    _solid: "WALL",
    collision: "BLOCKS"
});

rogue_world_export_current_room_prefab("tiny_city", "tiny_city.json", {
    weight: 1,
    biomes: ["grassland", "forest"]
});

game_end();
```

That writes:

```text
working_directory/data/rogue_prefabs/tiny_city.json
```

When `rm_world` starts, it automatically loads every `.json` file in:

```text
working_directory/data/rogue_prefabs/
```

The exported prefab stores:

- exact source layer names
- raw tile data, including tile index and flip/rotation data
- cropped width and height
- object placements by `object_name`
- custom object variables that can safely be converted to JSON

Layer names matter. If the prefab has a tile on layer `WALL`, then `rm_world` needs a matching `WALL` layer, or you need to configure a matching role/layer setup before the prefab is applied. This is what lets different tile layers use different tilesets while the prefab still stamps correctly.

Object export is future-proof by default. The exporter scans normal room instances and saves their `object_name`, position, target instance layer, and simple custom variables. It skips runtime system objects such as `oPlayer`, `oGame`, and `oCamera`.

Use this instance variable to prevent a placed object from being exported:

```gml
rogue_prefab_export = false;
```

Use export options to force an allowlist or denylist:

```gml
rogue_world_export_current_room_prefab("city_gate", "city_gate.json", {
    include_objects: [oNpc, oitem, oroguewarp],
    weight: 1
});

rogue_world_export_current_room_prefab("forest_piece", "forest_piece.json", {
    exclude_objects: [oPlayer, "obj_debug_marker"],
    weight: 2
});
```

For custom future objects, keep prefab setup values as simple numbers, strings, booleans, arrays, or structs. Runtime references like instance ids, surfaces, buffers, functions, and live asset handles should be recreated by the object's Create event instead of being saved into the prefab file.

Register a prefab:

```gml
rogue_world_register_prefab({
    id: "tiny_city_test",
    w: 10,
    h: 8,
    weight: 1,
    biomes: ["grassland"],
    tiles: [
        { role:"ground", x:0, y:0, tile:12 },
        { role:"ground", x:1, y:0, tile:12 },
        { role:"_solid", x:4, y:2, tile:45, solid:true }
    ],
    objects: [
        {
            object: oNpc,
            x: 48,
            y: 48,
            vars: {
                dialog_text: "Welcome to a generated town!",
                npc_sprite_base: "spr_bugcatcher"
            }
        }
    ]
});
```

Prefab fields:

- `id`: readable identifier.
- `w`, `h`: size in tiles.
- `weight`: future weighted selection value.
- `biomes`: optional list of biome ids.
- `tiles`: tile placements relative to the prefab origin.
- `objects`: instance placements relative to the prefab origin in pixels.

Generated instances get `rogue_generated = true`, so the next chunk rebuild can clean them safely.

## Reserved Zones

Reserved zones are for city/interior/special content that should not be overwritten by the normal wild generator.

```gml
rogue_world_register_reserved_zone(1000, 1000, 8, 8, "city_zone_0");
```

Fields are chunk coordinates, not pixels:

- `chunk_x`
- `chunk_y`
- `w_chunks`
- `h_chunks`
- `id`

Right now reserved chunks generate safe grassland instead of normal biome noise. This gives us a protected coordinate range for future city/prefab/static-zone work. If we later build cities directly inside the roguelike coordinate space, those chunks are the places to anchor them.

## Edge Paging

The infinite feel comes from `rogue_world_edge_page_for_player(pid)`.

The system does not create a new GameMaker room for each chunk. It keeps the player in `rm_world`, changes the infinite-world origin, clears the generated tile layers, and redraws the same room as the next chunk.

Chunk size is defined in code:

```gml
chunk_tiles: 64,
tile_size: 16
```

So one chunk is `64 * 16 = 1024` pixels wide and tall, matching the current `rm_world` size.

When a player crosses the left/right/top/bottom edge:

1. If this is the stored return edge on the entry chunk, the player warps back to the previous room with the normal room transition.
2. Otherwise, `origin_tile_x` or `origin_tile_y` moves by 64 tiles.
3. The player is moved to the opposite side of the room.
4. `rogue_world_generate_chunk()` rebuilds all generated tile layers.
5. A short same-room fade plays so the chunk swap has a transition.
6. The route bar shows `Wild Frontier x,y`.

The same room stays loaded, so existing transition/music systems do not need a new room for every route.

Important: the generator intentionally does not place blocker tiles on the outer edge of the chunk. If the outer edge is blocked, the player can never cross the room edge and the world will feel like it only exists inside `rm_world`.

## What Is Not Implemented Yet

This pass is the world-generation foundation. These are intentionally left for later patches:

- real biome tile ids
- real tree/flower/grass art rules
- encounter tables per generated biome
- item placement
- dungeon entrances
- city prefab library
- static city-zone authoring tools
- save/load persistence for discovered chunks and cleared items

## Main Functions

- `rogue_world_ensure()`
- `rogue_world_set_return(room_id, x, y, facing)`
- `rogue_world_register_biome(id, def)`
- `rogue_world_register_prefab(def)`
- `rogue_world_register_reserved_zone(chunk_x, chunk_y, w_chunks, h_chunks, id)`
- `rogue_world_prepare_enter(seed, chunk_x, chunk_y)`
- `rogue_world_return_to_previous()`
- `rogue_world_room_start()`
- `rogue_world_generate_chunk()`
- `rogue_world_update_all()`
- `rogue_world_warp_to(seed, chunk_x, chunk_y, spawn_x, spawn_y)`
