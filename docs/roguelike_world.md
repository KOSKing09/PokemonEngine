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
    decor2: "EMERALD_FLOOR",
    _solid: "WALL",
    collision: "BLOCKS"
});
```

What each role means:

- `ground`: base walkable ground such as grass, sand, dirt, cave floor, water floor, or path.
- `decor`: non-blocking details such as flowers, short grass, pebbles, puddles, moss, and path trim.
- `_solid`: visible blockers such as trees, rocks, cliff faces, fences, walls, and water edges.
- `collision`: invisible or utility blocking layer used by the movement/collision system.

Roles are dynamic. The engine does not need a hard-coded list beyond the core defaults. Any key you add to `rogue_world_configure_layers(...)` becomes a usable role in biome decor, path rules, and prefab tiles.

Example:

```gml
rogue_world_configure_layers({
    ground: "FLOOR",
    decor: "FLOOR_OBJECTS",
    decor2: "EMERALD_FLOOR",
    roof: "ROOFS",
    water_overlay: "WATER_SHINE",
    _solid: "WALL",
    collision: "BLOCKS"
});
```

Then use those roles anywhere a tile rule accepts `role`:

```gml
decor: [
    { role:"decor2", tile:969, chance:0.025, overlay:true },
    { role:"roof", tile:12, chance:0.02, overlay:true }
]
```

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

Configured rogue layers are created automatically if the room does not already have them. For example, `flowers: "Rogue_Flowers"` creates a missing `Rogue_Flowers` tile layer at runtime. If a tile still cannot draw because the layer is missing or has no tilemap, the generator prints one debug message like:

```text
[ROGUE][tile] missing tile layer Rogue_Flowers; tile 12 could not draw.
```

`decor2` is not hard-coded into the engine. It works because `rooms/rm_world/RoomCreationCode.gml` maps `decor2` to `EMERALD_FLOOR` with `rogue_world_configure_layers(...)`. You can remove it, rename it, or add more roles the same way.

If you want a biome to draw to that manual layer, reference it directly:

```gml
decor: [
    { role:"decor", tile:36, chance:0.045 },
    { layer:"decor2", tile:12, chance:0.05, overlay:true }
]
```

Use `layer:"decor2"` when `decor2` has its own larger tileset. That tells the generator to use the actual `decor2` GameMaker tile layer instead of the normal `decor` role. `overlay:true` means the rule can draw as a second layer without stopping later decor rules. If `decor2` does not exist, the generator can create it on demand, but it will have to use a fallback/default tileset. For your bigger tileset, make sure the `decor2` tile layer is saved in `rm_world` with that tileset assigned.

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

Spawn safety note: room warps route through `world_place_player_after_warp(...)`, which now checks collision before placing the player. If the requested spawn point is inside `WALL`, `BLOCKS`, an NPC, an item, or a field prop, it searches nearby grid tiles and places the player on the closest safe tile it can find. A debug log is printed when a spawn is adjusted.

## Biomes

Biomes are fully data-driven. The generator only chooses biomes that have been registered in the current setup.

Planned biome ids:

- `grassland`
- `forest`
- `river`
- `ocean`
- `desert`
- `tundra`
- `swamp`
- `mountain`

These are the ids the system is built around for prefabs, encounters, weather, and arena selection. You do not need to add all of them immediately. A biome only appears after you register it with `rogue_world_register_biome(...)`.

Current `rm_world` only registers the available biomes you have set up. At the moment that means `grassland` and `forest`. The other planned biomes are documented so you know what to add later, but they will not generate until they are registered.

| Biome id | Climate role | Default weight | Temperature | Moisture | Battle area |
| --- | --- | ---: | --- | --- | --- |
| `grassland` | normal route / default safe biome | 6 | `0.22..0.86` | `0.18..0.78` | `grassy` |
| `forest` | wet/temperate tree regions | 4 | `0.24..0.82` | `0.52..1.00` | `forest` |
| `river` | very wet water route regions | 3 | `0.05..0.95` | `0.74..1.00` | `river` |
| `ocean` | large open water regions | 2 | `0.05..1.00` | `0.82..1.00` | `ocean` |
| `desert` | hot and dry regions | 2 | `0.68..1.00` | `0.00..0.32` | `desert` |
| `tundra` | cold route regions | 2 | `0.00..0.26` | `0.00..0.82` | `snow` |
| `swamp` | hot/warm and very wet regions | 2 | `0.45..0.95` | `0.76..1.00` | `marsh` |
| `mountain` | rocky cold/temperate dry regions | 2 | `0.08..0.72` | `0.00..0.70` | `rocky` |

Biomes are chosen from climate. Every generated tile gets:

- `temperature`: `0` is cold, `1` is hot.
- `moisture`: `0` is dry, `1` is wet.

Each biome defines the temperature/moisture range where it can appear. If multiple biomes match the same tile, `weight` decides which one is more common. If no biome matches, the generator falls back to the nearest biome by climate distance.

The world uses smooth climate noise, so biomes form regions instead of changing every single tile. These global settings live in `global.ROGUE_WORLD`:

```gml
global.ROGUE_WORLD.biome_cell_tiles = 128;
global.ROGUE_WORLD.climate_cell_tiles = 192;
global.ROGUE_WORLD.temperature_band_tiles = 1024;
```

Increase those numbers for larger, slower-changing regions. Decrease them for more chaotic biome changes.

`rm_world` chunks are currently `64` tiles wide. That means the default `biome_cell_tiles = 128` makes one biome selection cell span about two chunks. The default `climate_cell_tiles = 192` makes temperature/moisture regions span about three chunks.

If a biome appears in one chunk and is gone when you step into the next chunk, that is not a new room being created randomly. It means you crossed either a biome-cell boundary or a climate boundary. The chunk is rebuilt from deterministic world coordinates, so going back to the previous chunk should rebuild the same previous biome again. To make biomes last longer across chunks, raise the values:

```gml
global.ROGUE_WORLD.biome_cell_tiles = 256;
global.ROGUE_WORLD.climate_cell_tiles = 384;
global.ROGUE_WORLD.temperature_band_tiles = 1600;
```

That makes biome areas feel more like long routes instead of short patches.

## Biome Blending

Biome blending is enabled for `rm_world` so you can see the next biome coming before the floor fully changes. The generator checks nearby tiles around each generated tile. If it finds a different biome within `global.ROGUE_WORLD.biome_blend_distance_tiles`, it can stamp a configured blend tile on a decor layer.

Global settings:

```gml
global.ROGUE_WORLD.biome_blend_enabled = true;
global.ROGUE_WORLD.biome_blend_distance_tiles = 4;
```

Each biome owns its own blend rules:

```gml
rogue_world_register_biome("grassland", {
    floor_tile: 9,
    blend: [
        { toward:"forest", role:"decor2", tile:969, chance:0.75, overlay:true }
    ]
});

rogue_world_register_biome("forest", {
    floor_tile: 18,
    blend: [
        { toward:"grassland", role:"decor", tile:36, chance:0.55, overlay:true }
    ]
});
```

Blend rule fields:

- `toward`: target biome id, or `"*"` for any neighboring biome.
- `direction`: optional direction filter like `left`, `right`, `up`, `down`, or `"*"`.
- `role` or `layer`: where the transition tile is drawn.
- `tile` or `data`: tile index or raw tile data.
- `chance`: maximum chance at the biome edge. It fades lower farther from the edge.
- `overlay` or `stack`: lets later blend/decor rules keep drawing instead of stopping after the first match.

This does not change collision or the base floor tile. It only paints visual transition hints, so paths, safe landing lanes, and prefab blockers still behave normally.

## Quick Biome Setup

Yes: for a tile like grass, put the tile id number directly into the biome.

If grass is tile `9` on the layer assigned to the `ground` role, define the grassland biome like this:

```gml
rogue_world_register_biome("grassland", {
    floor_tile: 9,
    solid_tile: 1,
    solid_chance: 0.035,
    weight: 6,
    temperature_min: 0.22,
    temperature_max: 0.86,
    moisture_min: 0.18,
    moisture_max: 0.78,
    decor: [],
    battle_area_type: "grassy"
});
```

That means:

- `grassland` is the biome name/id.
- `floor_tile: 9` draws tile `9` on the `ground` layer.
- The `ground` layer is currently `FLOOR`.
- The actual tileset comes from whatever tileset is assigned to `FLOOR` in the room editor.
- `weight: 6` makes grassland common when its climate range matches.
- `temperature_min/max` defines where it can appear on the cold-to-hot scale.
- `moisture_min/max` defines where it can appear on the dry-to-wet scale.

So if `FLOOR` uses your outdoor tileset, tile `9` from that tileset becomes the grass ground for the generated world.

## Biome Weights And Climate

Use these fields on every biome:

```gml
rogue_world_register_biome("desert", {
    floor_tile: 120,
    solid_tile: 132,
    solid_chance: 0.02,
    weight: 2,
    temperature_min: 0.68,
    temperature_max: 1.00,
    moisture_min: 0.00,
    moisture_max: 0.32,
    decor: [
        { role:"decor", tile:144, chance:0.04 }
    ],
    battle_area_type: "desert"
});
```

Rules:

- Higher `weight` means the biome wins more often when multiple biomes match the same climate.
- A biome with `weight:0` is effectively disabled.
- A dry biome should have low `moisture_max`.
- A wet biome should have high `moisture_min`.
- A cold biome should have low `temperature_max`.
- A hot biome should have high `temperature_min`.

The generator checks the climate first, then rolls by weight. This means a desert never appears in a cold wet region just because its weight is high.

Custom biome setup in `rm_world` is now the source of truth. If you define only `grassland`, only `grassland` generates. If you define `grassland` and `forest`, only those two generate. The engine only creates a plain safe `grassland` fallback if no biome has been registered at all.

To add another biome later, add it directly to `rooms/rm_world/RoomCreationCode.gml`:

```gml
rogue_world_register_biome("river", {
    floor_tile: 24,
    weight: 3,
    temperature_min: 0.05,
    temperature_max: 0.95,
    moisture_min: 0.74,
    moisture_max: 1.00,
    decor: [],
    battle_area_type: "river"
});
```

Ocean is registered the same way once you have the correct water tile:

```gml
rogue_world_register_biome("ocean", {
    floor_tile: 0, // replace with your ocean/water tile id
    weight: 2,
    temperature_min: 0.05,
    temperature_max: 1.00,
    moisture_min: 0.82,
    moisture_max: 1.00,
    decor: [],
    battle_area_type: "ocean"
});
```

## Rogue Encounters

`rm_world` now uses the NEW visible encounter style by default. Wild Pokemon spawn as `oNpc` encounter Pokemon from nearby `obush` patches, using the patch's tile/biome to choose the Pokemon table and battle arena.

The flow is:

1. The rogue runtime looks for nearby `obush` patches around the camera.
2. It reads the bush tile's biome from the infinite world coordinates.
3. The biome points to an encounter table with `encounter_region_key` and `encounter_habitat`.
4. A visible wild Pokemon `oNpc` is spawned inside that bush patch.
5. Touching that visible Pokemon starts the battle through the normal visible encounter handoff.
6. The battle arena comes from the Pokemon's source tile/biome, so forest spawns use forest, grassland spawns use grassy, water spawns can use ocean/river later.

Hidden walking encounters are off by default in the roguelike world. Turn them on only for rooms or biomes that should behave like old cave/grass random battles:

```gml
global.ROGUE_WORLD.encounter_hidden_enabled = true;
```

Leave it `false` for the NEW visible-spawn system.

Current tables live in `rooms/rm_world/RoomCreationCode.gml`:

```gml
overworld_encounter_register_table("rogue_grassland", "grass", [
    { species_id: 16, weight: 28, min_level: 3, max_level: 6 },
    { species_id: 19, weight: 24, min_level: 3, max_level: 6 }
]);

overworld_encounter_register_table("rogue_forest", "forest", [
    { species_id: 10, weight: 24, min_level: 4, max_level: 7 },
    { species_id: 13, weight: 22, min_level: 4, max_level: 7 }
]);
```

Then each biome chooses which table it uses:

```gml
rogue_world_register_biome("grassland", {
    floor_tile: 9,
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
```

Encounter fields:

- `encounter_region_key`: route/table group, usually `rogue_` plus the biome id.
- `encounter_habitat`: table bucket, such as `grass`, `forest`, `water`, or `cave`.
- `encounter_chance`: chance rolled when the player steps onto a new tile in that biome.
- `encounter_level_min` and `encounter_level_max`: fallback level range and clamp for table entries.
- `encounter_battle_format`: `"single"` or `"double"`.
- `encounter_double_chance`: chance to upgrade a normal wild encounter into a double wild battle.
- `encounter_path_enabled`: set `true` if encounters are allowed on generated town-route paths.
- `battle_area_type`: battle arena style sent to `battle_open(...)`.

Global defaults are also set in `rooms/rm_world/RoomCreationCode.gml`:

```gml
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
```

Visible-spawn fields:

- `encounter_visible_enabled`: spawns visible wild Pokemon in the world.
- `encounter_hidden_enabled`: enables old-style random battles while walking.
- `encounter_visible_loose_spawns`: when `false`, visible Pokemon must spawn from nearby `obush` patches. Set `true` only for rooms where visible Pokemon are allowed to spawn from nearby valid tiles without a bush patch.
- `encounter_visible_spawn_min/max`: spawn timer range in frames.
- `encounter_visible_max_active`: max visible rogue encounter Pokemon alive at once.
- `encounter_visible_patch_radius_tiles`: how far a spawned Pokemon can wander from its source tile.

To add ocean encounters later, register an ocean biome and add a matching table:

```gml
overworld_encounter_register_table("rogue_ocean", "water", [
    { species_id: 129, weight: 70, min_level: 5, max_level: 12 },
    { species_id: 72,  weight: 30, min_level: 7, max_level: 14 }
]);

rogue_world_register_biome("ocean", {
    floor_tile: 0,
    battle_area_type: "ocean",
    encounter_region_key: "rogue_ocean",
    encounter_habitat: "water",
    encounter_chance: 1 / 16
});
```

## Weather And Day/Night

The overworld has a shared environment system:

```gml
overworld_environment_set_time(20, 30);              // 8:30 PM
overworld_environment_set_weather("rain", 0.75);    // rain at 75% intensity
overworld_environment_set_weather("clear");
```

Day/night is controlled by:

```gml
global.OVERWORLD_ENV.time_minutes;      // 0..1439
global.OVERWORLD_ENV.time_scale;        // game minutes per real second
global.OVERWORLD_ENV.day_length_minutes;// default 1440
global.OVERWORLD_ENV.night_alpha_max;   // max blue night tint
```

Default time starts at `8:00`. The clock ticks in `overworld_environment_update()` every Step:

```gml
time_minutes += real_seconds_passed * global.OVERWORLD_ENV.time_scale;
```

Default `time_scale` is `1`, so one real second equals one in-game minute. That makes one full 24-hour day last about 24 real minutes. Set `time_scale` higher for faster days or lower for slower days:

```gml
global.OVERWORLD_ENV.time_scale = 0.5; // 48 real minutes per day
global.OVERWORLD_ENV.time_scale = 2;   // 12 real minutes per day
```

Night tint begins around `18:00`, is fully dark from `20:00` to `5:00`, and fades out by `7:00`.

Weather uses GameMaker's particle system. Supported weather ids:

- `clear`
- `rain`
- `snow`
- `sand` or `sandstorm`
- `fog`
- `ash`

When `global.OVERWORLD_ENV.auto_weather` is `true`, rogue chunks choose weather from the dominant biome plus average temperature/moisture:

- cold and wet chunks can snow
- hot dry desert/mountain chunks can kick up sand
- wet swamp chunks can fog or rain
- wet forest/river/ocean chunks can rain

Manual weather calls override the current weather immediately. Rogue auto-weather will choose again when the player enters a new generated chunk.

## Prefab Obstacles, Trees, And Decor

Random biome solid blockers are disabled by default. The roguelike world now expects trees, rocks, buildings, and other blockers to come from prefabs instead of `solid_chance`.

That means these fields are legacy/optional:

```gml
solid_chance: 0.035
solid_tile: 24
```

They only do anything if you explicitly turn biome solids back on:

```gml
global.ROGUE_WORLD.biome_solids_enabled = true;
```

Leave `biome_solids_enabled` as `false` for the current prefab-only workflow. This prevents the annoying random placeholder blocks from appearing when a biome is missing final art.

Use prefabs for trees:

```gml
rogue_world_export_current_room_prefab_dialog("_tree.json", {
    export_all_tile_layers: true,
    biomes: ["grassland", "forest"],
    spawn_chance: 0.75,
    min_per_chunk: 1,
    max_per_chunk: 6
});
```

The prefab can paint art on any custom tile layer and collision on `BLOCKS`. The generator stamps that designed chunk instead of inventing random wall tiles.

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
- `solid_tile`: legacy tile id drawn on the `_solid` role only if `global.ROGUE_WORLD.biome_solids_enabled` is true. `wall_tile` is still accepted as an old alias.
- `solid_chance`: legacy chance a non-path tile becomes a solid obstacle. Ignored while `biome_solids_enabled` is false.
- `weight`: how often this biome is picked when its climate range matches.
- `temperature_min`, `temperature_max`: allowed climate temperature range.
- `moisture_min`, `moisture_max`: allowed climate moisture range.
- `decor`: array of optional non-blocking decoration tile rules.
- `battle_area_type`: the battle arena name used by rogue encounters.
- `encounter_region_key` and `encounter_habitat`: the registered encounter table used by this biome.

Trees can be handled two ways:

- as prefab tiles: paint tree art and `BLOCKS` collision in an authored prefab room, then export it
- as generated objects: export a prefab/object entry that creates a tree object later

## Prefabs

Prefabs are the hook for cities, houses, special landmarks, dungeon doors, groves, puzzle chunks, and future handcrafted pieces.

## Paths And Town Prefabs

The world now has a deterministic town-path network. The generator picks one town anchor chunk inside each town grid cell, then draws Emerald-style route paths between those anchors. These paths are not random every time you enter the chunk; they come from the world seed and chunk coordinates, so stepping back rebuilds the same road.

Current path settings live in `rooms/rm_world/RoomCreationCode.gml`:

```gml
global.ROGUE_WORLD.path_tile = 9;
rogue_world_configure_path_tiles([
    { role:"ground", tile:9 }
]);
global.ROGUE_WORLD.path_width_tiles = 3;
global.ROGUE_WORLD.town_grid_chunks = 6;
global.ROGUE_WORLD.town_path_enabled = true;
global.ROGUE_WORLD.chunk_cache_limit = 24;
global.ROGUE_WORLD.edge_page_generate_after_ms = 150;
global.ROGUE_WORLD.edge_warp_sound = snd_Warp_Exit;
global.ROGUE_WORLD.edge_warp_sound_enabled = true;
```

What those mean:

- `path_tile`: old/simple fallback tile id for roads.
- `rogue_world_configure_path_tiles(...)`: the real path layer setup. Each rule can write a path tile to a role or a direct layer name.
- `path_width_tiles`: road radius in tiles. `3` gives a wide path. Lower it for skinny routes.
- `town_grid_chunks`: how far apart town anchors are. With `6`, the system attempts one town anchor per `6x6` chunk region.
- `town_path_enabled`: set to `false` if you want to temporarily disable generated roads.
- `chunk_cache_limit`: how many generated chunks are kept in memory for fast revisits.
- `edge_page_generate_after_ms`: delay before rebuilding the next chunk during the fade. `150` ms lines it up near full black.
- `edge_warp_sound`: sound played when walking from one rogue chunk to the next. Defaults to `snd_Warp_Exit`.
- `edge_warp_sound_enabled`: set to `false` to silence chunk paging.

Simple path setup:

```gml
rogue_world_configure_path_tiles([
    { role:"ground", tile:9 }
]);
```

Multi-layer path setup:

```gml
rogue_world_configure_layers({
    ground: "FLOOR",
    decor: "FLOOR_OBJECTS",
    _solid: "WALL",
    collision: "BLOCKS",
    path_detail: "PATH_DETAILS"
});

rogue_world_configure_path_tiles([
    { role:"ground", tile:9 },       // road base on FLOOR
    { role:"decor", tile:36 },       // flowers/pebbles on FLOOR_OBJECTS
    { role:"path_detail", tile:4 }   // another tileset/layer just for path detail
]);
```

You can also write directly to a layer name:

```gml
rogue_world_configure_path_tiles([
    { layer:"FLOOR", tile:9 },
    { layer:"PATH_DETAILS", tile:4 }
]);
```

Use `role` when you want the path rule to follow whatever layer is assigned in `rogue_world_configure_layers(...)`. Use `layer` when you want the rule locked to one exact GameMaker layer name.

Town prefabs are just normal exported prefabs marked as towns. Any prefab with `type:"town"`, `kind:"town"`, or a `"town"` tag is reserved for town anchor chunks. Nature prefabs skip town chunks, and town prefabs skip normal nature chunks.

Export a town prefab like this:

```gml
rogue_world_export_current_room_prefab_dialog("town_small.json", {
    export_all_tile_layers: true,
    type: "town",
    tags: ["town"],
    weight: 1,
    biomes: []
});

game_end();
```

The town prefab is centered inside its anchor chunk. If you create several town prefabs, `weight` controls which one gets chosen more often. Example:

```gml
rogue_world_export_current_room_prefab_dialog("forest_town.json", {
    export_all_tile_layers: true,
    type: "town",
    tags: ["town", "forest"],
    weight: 3
});
```

For now town prefabs are selected from all loaded town prefabs. Biome-specific town filtering can be added later if you want forest towns, desert towns, beach towns, and mountain towns to have separate pools.

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
    export_all_tile_layers: true,
    type: "nature",
    weight: 1,
    biomes: ["grassland"]
});

game_end();
```

So by default it exports every tile layer in the room, including custom layers you added for tree art, flowers, roofs, shadows, and collision.

If you want to export only specific layers, use a `layers` array instead:

```gml
rogue_world_export_current_room_prefab_dialog("flower_patch.json", {
    layers: ["FLOOR", "FLOOR_OBJECTS", "WALL", "BLOCKS", "Rogue_Flowers"],
    type: "nature",
    weight: 2,
    biomes: ["grassland", "forest"],
    spawn_chance: 0.65,
    min_per_chunk: 0,
    max_per_chunk: 4
});
```

The lower-level exporter behaves the same way:

- if `opts.layers` is provided, it exports exactly those layers
- if `opts.export_all_tile_layers` is true, it exports all tile layers in the room
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
    type: "town",
    tags: ["town"],
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
- prefab type, such as `nature` or `town`
- tags, such as `["town"]`
- object placements by `object_name`
- custom object variables that can safely be converted to JSON
- basic object draw properties such as image scale, angle, alpha, blend, frame, speed, and visibility
- tile layer metadata: layer name, layer depth, layer order, tileset asset name, and tileset asset reference

Layer names matter. If the prefab has a tile on layer `WALL`, then `rm_world` needs a matching `WALL` layer, or you need to configure a matching role/layer setup before the prefab is applied. This is what lets different tile layers use different tilesets while the prefab still stamps correctly.

If the matching tile layer does not exist, the loader tries to create it automatically from the exported layer metadata. So a prefab layer named `Rogue_Flowers` can be injected into `rm_world` or `rm_rogue_building` at runtime if the tileset still exists in the project.

Example exported layer metadata:

```gml
layer_meta: [
    { layer:"Rogue_Flowers", tileset:"t_kanto", tileset_asset:"@ref tileset(t_kanto)", depth:350, order:3 }
]
```

Draw order is preserved by exported layer depth. If `Rogue_Flowers` was above `FLOOR` in the authored room, it should be injected above `FLOOR` when loaded. The `order` value is saved too so same-depth custom layers keep a stable relative stack.

The loader prefers `tileset_asset` because that is the actual GameMaker tileset reference needed to create a new tilemap. GameMaker may serialize that reference as `"@ref tileset(TileSet2)"` in JSON and stringify it at runtime as `"ref tileset TileSet2"`; the rogue loader supports both formats. The human-readable `tileset` name is kept as a fallback and for debugging. If no tileset is available at all, that injected layer is skipped and a debug message is printed.

If the layer already exists in the current room, the loader uses the normal tilemap lookup for that layer. If the layer is missing, there is no tilemap id to grab yet, so the loader creates the layer first using the exported layer name and tileset reference, then it writes the prefab's tiles into that new tilemap.

Injected prefab layers are created at the loaded room/chunk size, not at the cropped prefab size. This matters for tiny prefabs like `_tree`: the prefab may only be `2x2`, but the layer still needs enough cells for the tree to appear anywhere in the generated chunk.

Injected layers are remembered as dynamic rogue layers, so later chunk rebuilds and rogue room reloads clear them instead of leaving old custom-layer graphics behind.

If an exported custom layer shows `"tileset":""` or is missing `tileset_asset`, re-export it with the current exporter. You can also provide a tileset override in the export options:

```gml
rogue_world_export_current_room_prefab_dialog("_tree.json", {
    export_all_tile_layers: true,
    layer_tilesets: {
        wally: "TileSet2"
    },
    biomes: [],
    spawn_chance: 0.8,
    max_per_chunk: 14
});
```

That tells the loader which tileset to use if it has to create the custom `wally` layer in `rm_world`.

Object export is future-proof by default. The exporter scans normal room instances and saves their `object_name`, position, target instance layer, and simple custom variables. It skips runtime system objects such as `oPlayer`, `oGame`, and `oCamera`.

## Object Creation Data

Prefab objects and rogue room objects save the results of their instance creation code.

GameMaker does not safely run raw GML text from JSON. Instead, the exporter runs after the room has already created its instances, so any simple creation-code assignment has already become an instance variable.

For example, if an `oNpc` has this instance creation code:

```gml
npc_sprite_base = "spr_bugcatcher";
trainer_enabled = true;
trainer_name = "Bug Catcher";
trainer_species = 10;
trainer_level = 5;
```

The exporter stores those values in the object's `vars` block. When the prefab or rogue room reloads, the system recreates the object and applies those saved variables again.

This works for:

- numbers
- strings
- booleans
- arrays made from those values
- structs made from those values

This also works for object setup values like:

```gml
_room = rm_rogue_building;
rogue_room_file = "small_house.json";
return_to_rogue = true;
item_id = 4;
item_qty = 1;
```

After variables are restored, the loader runs a small generic finalize pass. NPCs are reinitialized through the NPC runtime, and field-move props are refreshed from their saved move settings. That means you can set objects up with instance creation code in the editor, export the room, and reload them without writing a separate script just for that prefab.

Do not use creation code that depends on live runtime things like instance ids, surfaces, buffers, or functions. Save plain setup data instead.

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
- `weight`: weighted bonus selection value when multiple matching prefabs can appear in a chunk.
- `biomes`: optional list of biome ids.
- `spawn_chance`: chance for each optional copy of this prefab to appear in a matching chunk.
- `min_per_chunk`: guaranteed copies in a matching chunk.
- `max_per_chunk`: maximum copies in a matching chunk.
- `tiles`: tile placements relative to the prefab origin.
- `objects`: instance placements relative to the prefab origin in pixels.

Generated instances get `rogue_generated = true`, so the next chunk rebuild can clean them safely.

## Adding Tree Prefabs

For trees, make the trees as an outdoor `rogue_prefab`, not a `rogue_room`.

Workflow:

1. Open `rm_prefab_export` or a custom prefab-authoring room.
2. Paint the tree tiles on the layer you want, such as `WALL`, `FLOOR_OBJECTS`, or a custom layer like `Rogue_Trees`.
3. Paint collision on `BLOCKS`, or mark object/tile logic as solid where needed.
4. Export the prefab with biome and count settings.

Example tree export:

```gml
rogue_world_export_current_room_prefab_dialog("tree_patch.json", {
    export_all_tile_layers: true,
    biomes: ["grassland", "forest"],
    spawn_chance: 0.75,
    min_per_chunk: 1,
    max_per_chunk: 6
});

game_end();
```

That means:

- only grassland and forest chunks can use it
- every matching chunk gets at least 1 tree patch
- each chunk can get up to 6 tree patches
- each optional extra patch rolls at `0.75`

If your tree prefab uses a custom layer like `Rogue_Trees`, use `export_all_tile_layers:true` or include `Rogue_Trees` in the `layers` array. The exporter saves the layer name, draw order, depth, and tileset. When the prefab loads into `rm_world`, the loader creates that layer if it is missing.

## Buildings And Interiors

Use prefabs for the outside of buildings, towns, huts, caves, and dungeon entrances. Use normal GameMaker rooms for the inside.

The exterior building should be part of a roguelike prefab. Put an `owarp` object on the building door in the prefab room. That `owarp` sends the player to the interior room.

Example exterior building door:

```gml
_room = rm_house_1;
_x = 128;
_y = 176;
warp_kind = "door";
remember_rogue_return = true;
rogue_return_offset_x = 0;
rogue_return_offset_y = 16;
```

`remember_rogue_return = true` means:

1. The player enters the door from the generated `rm_world` chunk.
2. The game stores the current rogue chunk origin and the return position.
3. The player warps into the normal interior room.

For the interior room exit, place another `owarp` at the exit door and set:

```gml
return_to_rogue = true;
warp_kind = "door";
```

That exit does not need a fixed `_room`, `_x`, or `_y`. It uses the stored rogue return data and sends the player back to the same generated chunk and doorway.

If you need the return position to be exact, set these on the exterior door:

```gml
rogue_return_x = 320;
rogue_return_y = 384;
```

If those are left as `-1`, the system uses the player's door position plus:

```gml
rogue_return_offset_x = 0;
rogue_return_offset_y = 16;
```

This is the best setup for random buildings:

1. Build the exterior as a room-authored prefab.
2. Put `owarp` on each exterior door.
3. Set each exterior door's target interior room.
4. Export the prefab JSON.
5. Build each interior as a normal room.
6. Put a `return_to_rogue = true` `owarp` on the interior exit.

The actual GameMaker room is still `rm_world`; the chunk origin is restored before returning, so the same generated chunk is rebuilt and the player appears outside the same random building.

## Rogue Room Prefabs

If you do not want to make a separate GameMaker room for every random interior, export interiors as `rogue_rooms`.

The project now has a reusable runtime room:

```text
rm_rogue_building
```

That room starts empty, loads one JSON file from:

```text
working_directory/data/rogue_rooms/
```

Then it draws the exported tiles, creates exported objects, and uses the exported width/height as the room's logical bounds. The physical GameMaker room is large enough to host different layouts, but the camera clamps to the loaded JSON size so a tiny house and a large hall do not feel like the same room.

To export an interior from an authored GameMaker room, use:

```gml
rogue_world_configure_layers({
    ground: "FLOOR",
    decor: "FLOOR_OBJECTS",
    _solid: "WALL",
    collision: "BLOCKS"
});

rogue_room_export_current_room_dialog("small_house.json", {
    layers: ["FLOOR", "FLOOR_OBJECTS", "WALL", "BLOCKS"],
    display_name: "Small House",
    spawn_x: 128,
    spawn_y: 176,
    crop: false
});

game_end();
```

Important: `crop:false` means the exported rogue room keeps the authored room size instead of shrinking to only the painted tiles. Use this for interiors when you care about the exact room dimensions.

Rogue room export defaults to `export_all_tile_layers:true` when you do not provide a `layers` array. That means custom interior layers are saved with their names, depth/order, tileset reference, and tile data. On load, `rm_rogue_building` injects any missing layers before drawing the room, using the same dynamic layer system as outdoor prefabs.

To enter a rogue room from an outdoor building prefab, put an `owarp` on the exterior door:

```gml
_room = rm_rogue_building;
rogue_room_file = "small_house.json";
remember_rogue_return = true;
warp_kind = "door";
```

The `_x` and `_y` on that exterior warp become the spawn point inside the loaded interior. If you want the JSON's default `spawn_x/spawn_y` instead, leave `_x` and `_y` set to the exported spawn values.

If `_x` and `_y` are left at `-1`, the loader uses the JSON's exported `spawn_x` and `spawn_y`.

Inside the loaded rogue room, the exit door is still just an `owarp`:

```gml
return_to_rogue = true;
warp_kind = "door";
```

Use `rogue_prefabs` for exterior buildings in the infinite world. Use `rogue_rooms` for reusable interiors that can have different sizes.

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
3. `rogue_world_generate_chunk()` rebuilds all generated tile layers for the new chunk.
4. The player is moved to the opposite side of the room with `world_place_player_after_warp(...)`.
5. A short same-room fade plays so the chunk swap has a transition.
6. The route bar shows the generated chunk name and chunk coordinate, such as `Haunted Forest 2,-1`.

The same room stays loaded, so existing transition/music systems do not need a new room for every route.

Important: the generator intentionally does not place blocker tiles on the outer edge of the chunk. If the outer edge is blocked, the player can never cross the room edge and the world will feel like it only exists inside `rm_world`.

The camera is clamped like a normal room. It does not overscroll outside `rm_world`; only the player touching the edge triggers the chunk page.

## Chunk Names

The roguelike world does not rename the actual GameMaker room. The actual room stays `rm_world`. Instead, each generated chunk gets a display name stored in:

```gml
global.ROGUE_WORLD.chunk_name
```

That name is shown in the route bar when the player enters a new chunk. The current naming rules live in `rogue_world_chunk_name_from_stats(stats)` inside `scripts/roguelike_world/roguelike_world.gml`.

Rogue chunk names use the shared `world_show_route_bar(...)` display with `style:"rogue"`. The route bar chooses a color palette from the generated chunk name and the current environment:

- forest names lean green
- river/ocean names lean blue
- desert names lean gold
- snow names lean pale blue
- swamp names lean muted green
- mountain names lean stone gray
- rain, snow, sand, fog, ash, and night can tint the accent color

The text is measured before drawing. Long names and coordinates scale down to fit inside the GUI width, and only fall back to a short `..` trim if the name is still too wide at the minimum scale.

The generator counts what it placed in the chunk:

- how much of the chunk is `forest`
- how much is `river`
- how much is `grassland`
- how many blocker tiles were placed
- how much decor was placed

Then it picks a name from those numbers. For example, a chunk with a lot of forest and enough blockers becomes:

```gml
if (_forest >= 0.45 && _solid >= 0.08) return "Haunted Forest";
```

To add your own names, add another condition before the final `return "Wild Frontier";`.

Example:

```gml
if (_forest >= 0.55 && _decor >= 0.10) return "Ancient Grove";
if (_river >= 0.45 && _grass >= 0.25) return "Misty Riverbank";
```

The order matters. Put more specific names first, then more general names after them.

Rogue room prefab names are different from outdoor chunk names. A rogue room uses the `display_name` you exported:

```gml
rogue_room_export_current_room_dialog("small_house.json", {
    display_name: "Small House"
});
```

That name is not random unless you choose to export multiple room files with different names and randomly choose which JSON file the exterior door uses.

Outdoor chunk names are generated from the chunk contents. They are not typed per room file because `rm_world` is one reusable infinite room. To provide your own outdoor names, edit `rogue_world_chunk_name_from_stats(stats)` and add rules for the content you care about:

```gml
if (_forest >= 0.55 && _decor >= 0.10) return "Ancient Grove";
if (_river >= 0.45 && _grass >= 0.25) return "Misty Riverbank";
```

So the naming split is:

- `rm_world` chunks: named by biome/content rules.
- `rogue_rooms`: named by your exported `display_name`.
- exterior building prefabs: can decide which `rogue_room_file` to open.

## Safe Spawn Rules

The roguelike generator clears safe landing lanes after every chunk rebuild:

- the outer three tile lanes on every room edge
- a small area around the entry spawn on the first chunk

This is done after random biome generation and after prefab stamping, so random blocks and prefab collision cannot trap the player right where they enter. If a spawn point is still blocked by an object, `world_place_player_after_warp(...)` searches nearby grid tiles and moves the player to the nearest safe tile.

## What Is Not Implemented Yet

This pass is the world-generation foundation. These are intentionally left for later patches:

- real biome tile ids
- real tree/flower/grass art rules
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
- `rogue_world_update_encounters()`
- `rogue_world_update_all()`
- `rogue_world_warp_to(seed, chunk_x, chunk_y, spawn_x, spawn_y)`
