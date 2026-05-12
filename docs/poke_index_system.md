# Poke-Index System

The Poke-Index is an Emerald-style per-player Pokemon discovery UI. It uses the same player-id pattern as the bag and party systems, so player 1 and player 2 can each have their own seen/caught state.

## Public Helpers

- `poke_index_init(playerCount)` creates `global.POKE_INDEX`.
- `poke_index_open(pid)`, `poke_index_close(pid)`, `poke_index_is_open(pid)` manage visibility.
- `poke_index_update()` handles list navigation and the area page.
- `poke_index_draw_gui(pid)` and `poke_index_draw_gui_rect(pid, x, y, w, h)` draw the UI.
- `poke_index_mark_seen(pid, species_id)` and `poke_index_mark_caught(pid, species_id)` update discovery state.
- `poke_index_locations_for_species(species_id)` resolves wild locations from `global.OVERWORLD_ENCOUNTERS`.
- Main-list filters are stored per player as `filter`: `0 = ALL`, `1 = SEEN`, `2 = UNSEEN`.

## Current Wiring

- `objects/oGame/Create_0.gml` calls `poke_index_init(2)`.
- `objects/oGame/Step_1.gml` calls `poke_index_update()`.
- `objects/oGame/Draw_64.gml` draws the index in full-screen, split-screen, and shared-screen modes.
- The pause menu's `POKE-INDEX` entry opens the UI.
- Left/right on the main Poke-Index page cycles between all, seen, and unseen Pokemon.
- Wild/trainer enemy actors are marked seen when `battle_open(...)` finishes building enemy actors.
- Caught Pokemon are marked caught through the catch-finalization flow.

## Encounter Areas

The area page reads the same registered tables used by overworld encounters:

```gml
overworld_encounter_register_table("route_3", "grass", [
    { species_id: 16, weight: 35, min_level: 3, max_level: 5 }
]);
```

Seen Pokemon show matching `region - habitat` rows plus level ranges. Unknown Pokemon hide their names and areas.

## Route and Region Storage

The Poke-Index does not currently store a separate per-player "found at" history. Instead, it resolves where a Pokemon can appear from the shared overworld encounter registry:

- `global.OVERWORLD_ENCOUNTERS.tables`
- first key: route or region id, such as `"demo_route_1"` or `"route_3"`
- second key: habitat id, such as `"grass"`, `"bush"`, or `"water"`
- value: encounter entries containing `species_id`, `min_level`, and `max_level`

That registry is filled through:

```gml
overworld_encounter_register_table("route_3", "grass", [
    { species_id: 16, weight: 35, min_level: 3, max_level: 5 }
]);
```

Encounter instances choose which table to use with these instance fields:

```gml
encounter_region_key = "route_3";
encounter_habitat = "grass";
```

`poke_index_locations_for_species(species_id)` scans every registered region and habitat, finds entries with that `species_id`, and returns labels like `Route 3 - Grass Lv.3-5`.
