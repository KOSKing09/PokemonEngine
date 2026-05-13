# Overworld Encounters

This guide covers the current random encounter system in the overworld, where the encounter data lives, how encounter volumes trigger battles, and how to add a new route, habitat, or encounter object safely.

The system now has two operating modes:

- `old`: classic hidden encounters that fire when the player enters the volume and passes the encounter roll
- `new` or `visible`: encounter-bearing patches spawn visible wandering Pokemon and only open battle on contact

For the broader NPC or trainer object stack, use `docs/overworld_systems.md`.

## Ownership

Primary code lives in `scripts/player_helper_scripts/player_helper_scripts.gml`.

The main public seams are:

- `overworld_encounter_init(inst)`
- `overworld_encounter_register_table(region_key, habitat_key, entries)`
- `overworld_encounter_can_start(pid)`
- `overworld_encounter_step(inst)`

The wild battle handoff happens through `battle_open(...)` in `scripts/battle_system/battle_system.gml`.

## Runtime model

Each encounter object is just a world instance with encounter variables on it.

`overworld_encounter_init(inst)` ensures these defaults exist:

- `encounter_enabled`: master on/off switch
- `encounter_radius`: fallback radius if the object bounds are not usable
- `encounter_chance`: roll checked when a player enters the encounter volume
- `encounter_level_min`, `encounter_level_max`: fallback level range
- `encounter_area_type`: battle theme selector such as `forest`
- `encounter_region_key`: route or area id used to find the encounter table
- `encounter_habitat`: table key inside the region such as `grass` or `bush`
- `encounter_battle_format`: `single` or `double`
- `encounter_coop_enabled`: lets co-op wild battles start when multiplayer queue mode allows it
- `encounter_cooldown`, `encounter_cooldown_frames`: per-instance throttle after a trigger
- `_encounter_inside_pids`: remembers whether pid `0` or pid `1` is already inside the volume

Global table state lives in `global.OVERWORLD_ENCOUNTERS`:

- `tables`: nested `region -> habitat -> encounter entries`
- `defaults_seeded`: one-time seeding guard for demo data
- `pending`: shared encounter-start lock so multiple volumes do not start multiple battles at once

Global mode defaults are seeded by `overworld_encounter_init(inst)` and normally configured from `objects/oGame/Create_0.gml`:

- `OVERWORLD_ENCOUNTER_MODE`
- `OVERWORLD_SHINY_CHANCE`
- `OVERWORLD_VISIBLE_MAX_ACTIVE`
- `OVERWORLD_VISIBLE_PATCH_DENSITY`
- `OVERWORLD_VISIBLE_PATCH_MAX`
- `OVERWORLD_ENCOUNTER_GRACE_MS`
- `OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS`

## How triggering works

`overworld_encounter_step(inst)` is written to be called from the encounter object's Step event.

In `old` mode, the encounter object rolls a hidden encounter directly.

In `new` or `visible` mode, the object manages a patch-local spawn timer and visible encounter NPCs instead.

The sections below describe both paths.

## Hidden Encounter Triggering

A battle can start only when all of these are true:

- the encounter instance exists and is enabled
- its local cooldown has reached `0`
- the player is allowed to start gameplay interactions right now
- no battle is already open
- no other encounter is already in flight through `global.OVERWORLD_ENCOUNTERS.pending`
- the player is moving, not idle
- the player has just entered the encounter volume this frame
- the random `encounter_chance` roll succeeds

The volume check prefers real instance bounds. If both the encounter object and player expose bounding box values, overlap is used. If not, the code falls back to point-in-rectangle, then finally to `encounter_radius` distance from the instance origin.

This matters for bushes: large sprites should use their real bounds or an explicit radius rather than relying on the object origin.

## Visible Encounter Mode

Visible mode turns an encounter patch into a small overworld spawner.

Runtime model:

- the encounter object still owns the route and habitat metadata
- the patch computes connected bush bounds through `__overworld_encounter_bounds(...)`
- exactly one bush tile in that connected patch becomes the anchor through `__overworld_encounter_is_area_anchor(...)`
- only that anchor may keep `_encounter_visible_npcs` and spawn visible overworld Pokemon

Visible-mode instance fields seeded by `overworld_encounter_init(inst)`:

- `encounter_mode`: `global`, `old`, `new`, or `visible`
- `encounter_visible_spawn_min`, `encounter_visible_spawn_max`
- `encounter_visible_lifetime_min`, `encounter_visible_lifetime_max`
- `encounter_visible_speed`
- `encounter_visible_pause_min`, `encounter_visible_pause_max`
- `encounter_visible_camera_only`
- `encounter_visible_grid_size`
- `encounter_visible_max_active`
- `encounter_visible_shiny_chance`
- `_encounter_visible_npc`, `_encounter_visible_npcs`, `_encounter_visible_timer`

Spawn rules in visible mode:

- non-anchor bushes do not spawn
- off-camera patches can be suppressed when `encounter_visible_camera_only` is true
- the patch respects both the global visible cap and the patch-local cap
- each spawn uses the same registered encounter table data as hidden mode

Spawned visible Pokemon are `oNpc` instances tagged with `encounter_pokemon = true`.

They carry:

- `encounter_species_id`
- `encounter_level`
- `encounter_shiny`
- `encounter_owner`
- `encounter_lifetime`
- movement bounds and wander target fields

Contact with the player opens a wild battle through `battle_open(...)` using an opts struct that includes:

- `encounter_region_key`
- `encounter_habitat`
- `encounter_source = "visible_bush_npc"`

Visible encounters can still produce doubles through `encounter_battle_format` or `encounter_double_chance`.

## Encounter table shape

A table entry is a struct with these common fields:

- `species_id`: preferred species id
- `weight`: relative spawn chance within that table
- `min_level`
- `max_level`

Fallback keys `id` or `species` are also accepted for species lookup, but use `species_id` for consistency.

Use these two knobs for different jobs:

- `encounter_chance` on the object decides how often walking into the volume actually starts a wild battle at all
- `weight` on each table entry decides which species is chosen once that wild battle roll succeeds

Example table:

```gml
overworld_encounter_register_table("route_2", "grass", [
    { species_id: 16, weight: 40, min_level: 2, max_level: 4 },
    { species_id: 19, weight: 35, min_level: 2, max_level: 5 },
    { species_id: 161, weight: 20, min_level: 3, max_level: 5 },
    { species_id: 172, weight: 5, min_level: 4, max_level: 6 }
]);
```

Weights are relative. In the example above, the `species_id: 16` entry is eight times as likely as the `species_id: 172` entry once an encounter starts.

## How species and levels are chosen

`__overworld_encounter_roll(...)` picks one or two entries depending on `encounter_battle_format`.

- `single`: returns one species and one level
- `double`: returns arrays for `enemy_species` and `enemy_levels`

Those values are forwarded into `battle_open(...)` through the wild battle opts struct.

That is true for both modes. Visible mode simply promotes one selected wild entry into a physical overworld NPC before battle starts.

If a table lookup fails, battle open falls back to the supplied level range, but you should treat an empty table as misconfiguration and fix the route data rather than rely on fallback randomness.

## Adding a new encounter table

Add new route data by registering a region key and habitat key.

Example:

```gml
overworld_encounter_register_table("route_3", "bush", [
    { species_id: 261, weight: 45, min_level: 4, max_level: 6 },
    { species_id: 263, weight: 35, min_level: 4, max_level: 7 },
    { species_id: 509, weight: 15, min_level: 5, max_level: 7 },
    { species_id: 519, weight: 5, min_level: 6, max_level: 8 }
]);
```

Recommended place to seed project-wide defaults:

- the one-time seed block inside `overworld_encounter_tables_init()` for prototype data
- a dedicated loader or room-setup helper later, once route data grows beyond a few tables

## Room setup example

Once route data stops being throwaway prototype data, move it out of `player_helper_scripts.gml` and seed it from a room controller, route setup object, or boot-time loader script.

Short Create-event example for a route controller object:

```gml
// objects/oRoute3Controller/Create_0.gml
if (!is_undefined(overworld_encounter_register_table)) {
    overworld_encounter_register_table("route_3", "grass", [
        { species_id: 16, weight: 35, min_level: 3, max_level: 5 },
        { species_id: 19, weight: 30, min_level: 3, max_level: 5 },
        { species_id: 161, weight: 20, min_level: 4, max_level: 6 },
        { species_id: 21, weight: 10, min_level: 4, max_level: 6 },
        { species_id: 172, weight: 5, min_level: 5, max_level: 7 }
    ]);

    overworld_encounter_register_table("route_3", "bush", [
        { species_id: 261, weight: 45, min_level: 4, max_level: 6 },
        { species_id: 263, weight: 30, min_level: 4, max_level: 6 },
        { species_id: 509, weight: 20, min_level: 5, max_level: 7 },
        { species_id: 519, weight: 5, min_level: 6, max_level: 8 }
    ]);
}
```

Then point the room's encounter objects at that region key:

```gml
// Example bush Create event overrides
encounter_region_key = "route_3";
encounter_habitat = "bush";
encounter_area_type = "forest";
```

This keeps the encounter registry close to the room or route that owns it while still using the shared wild-battle runtime.

Practical rule:

- keep `overworld_encounter_tables_init()` for demo defaults and emergency fallback data
- put real route data in route-owned Create scripts or a dedicated loader so content is not buried in the helper library

## Adding a new encounter object

Any object can become an encounter volume if it calls the runtime helpers.

Minimal pattern:

```gml
// Create event
if (!is_undefined(overworld_encounter_init)) overworld_encounter_init(id);
encounter_region_key = "route_3";
encounter_habitat = "grass";
encounter_area_type = "forest";
encounter_chance = 1 / 16;
encounter_radius = 24;

// Step event
if (!is_undefined(overworld_encounter_step)) overworld_encounter_step(id);

// Draw event
if (!is_undefined(overworld_encounter_draw)) overworld_encounter_draw(id);
```

`objects/obush/Create_0.gml` is the current concrete example. It sets:

- `encounter_region_key = "demo_route_1"`
- `encounter_habitat = "bush"`
- `encounter_area_type = "forest"`
- `encounter_chance = 1 / 12`
- `encounter_radius = max(sprite_width, sprite_height)`

That makes `obush` a practical template when creating more encounter-bearing tiles or world props.

In visible mode, adding the Draw event matters because the encounter object itself is responsible for the patch prop draw while the spawned visible Pokemon use `oNpc` draw logic.

## Per-instance overrides

You can override data on a placed instance without touching the global table registry.

Useful overrides:

- `encounter_table`: direct array of entries for this one instance
- `encounter_level_min`, `encounter_level_max`: route segment tuning
- `encounter_battle_format = "double"`: double wild encounters
- `encounter_mode = "old"` or `"new"`: force this one volume off the global default
- `encounter_coop_enabled = true`: allow co-op encounter handoff in multiplayer solo/co-op queue flow
- `encounter_enabled = false`: temporarily disable a volume from cutscenes or quest logic
- `encounter_visible_camera_only = false`: let visible spawns stay active even when the patch is off camera
- `encounter_visible_max_active`: patch-local cap for visible wilds

Direct per-instance table example:

```gml
encounter_table = [
    { species_id: 129, weight: 70, min_level: 5, max_level: 7 },
    { species_id: 339, weight: 25, min_level: 5, max_level: 7 },
    { species_id: 340, weight: 5, min_level: 7, max_level: 9 }
];
encounter_habitat = "water";
encounter_area_type = "river";
```

## Co-op and multiplayer behavior

Wild encounters can optionally become co-op encounters through `multiplayer_should_start_coop_for_pid(...)`.

Current rules:

- `encounter_coop_enabled` must be true on the encounter instance
- multiplayer queue mode must be `coop`
- player 2 must exist
- the triggering pid must match the configured multiplayer request pid

When those checks pass, the encounter opens with:

- `coop_enabled = true`
- `player_pids = [0, 1]`

The battle slot then uses the existing battle doubles and co-op ownership rules.

## Safety notes

Use these rules to avoid repeated encounter bugs:

- Keep `overworld_encounter_step(inst)` on the encounter object, not on the player, so the overlap state stays local to the volume.
- In visible mode, keep the owning state on the encounter object and let only the patch anchor spawn or clear visible NPCs.
- Do not call `battle_open(...)` directly from world object Step code when you can use the encounter helpers. The helpers already handle entry detection, cooldown, and pending-lock behavior.
- If a battle does not open successfully, the encounter code clears the global `pending` lock again. Do not add extra global locks around it unless you also define the unlock path.
- If you place connected bushes, expect only one of them to behave as the active patch owner. That is by design.
- If you need immediate testing, raise `encounter_chance`. If you need production behavior, lower the chance instead of adding more trigger conditions.

## Fast checklist

1. Register a route table with `overworld_encounter_register_table(...)`.
2. Call `overworld_encounter_init(id)` from the encounter object's Create event.
3. Set `encounter_region_key`, `encounter_habitat`, and `encounter_area_type`.
4. Optionally tune `encounter_chance`, `encounter_radius`, level range, or battle format.
5. Call `overworld_encounter_step(id)` from the object's Step event.
6. Run the room and confirm the encounter enters battle only once per contact.
