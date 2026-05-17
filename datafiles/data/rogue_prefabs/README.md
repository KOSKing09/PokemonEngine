Room-authored roguelike prefab JSON files can live here when you want them bundled with the project.

During development, `rogue_world_export_current_room_prefab(...)` writes to:

`working_directory/data/rogue_prefabs/`

Copy exported JSON files here if GameMaker needs them included with the project build.

Town prefabs use the same folder. Mark them during export with `type:"town"` or
`tags:["town"]`; the rogue generator will reserve them for town anchor chunks
and connect those town chunks with generated paths.

Encounter prefabs should include `obush` objects for NEW visible wild Pokemon
spawns. By default rogue visible encounters must come from nearby `obush`
patches; loose tile-based spawns only happen if
`global.ROGUE_WORLD.encounter_visible_loose_spawns = true`.
