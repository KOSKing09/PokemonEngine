# Data And Asset Systems

This guide covers the support systems that load data, build runtime mon structs, seed debug state, and resolve external presentation assets.

## Data Loaders

Owner: `scripts/PokemonDataLoaders/PokemonDataLoaders.gml`

Purpose:

- load CSV-backed Pokemon data into array and struct globals
- normalize raw text and numeric fields for the rest of the engine
- populate species, stats, EV-yield, and related lookup tables

Boot contract:

- `objects/oGame/Create_0.gml` calls `data_load_profile_run()` as the main boot-time loader.
- The script expects CSV files under `working_directory + "/data/csv/"`.
- `global._pokemon` and related globals must exist before many downstream systems can resolve species data.

Key responsibilities visible in the loader script:

- creates `global._pokemon` as an array indexed by species id
- fills base stats and EV-yield related records
- provides safe conversion helpers and case-insensitive column lookup helpers
- supports name-to-species fallback when a CSV row does not expose a direct numeric species id field

When a loader edit breaks many unrelated systems at once, start here before touching battle, party, or UI code.

## Pokemon Factory

Owner: `scripts/pokemon_factory/pokemon_factory.gml`

Purpose:

- builds canonical mon structs from species id, level, and optional overrides
- computes learned moves, PP, stats, IVs, EVs, nature, and baseline identity fields

Main APIs:

- `pokemon_factory_create(species_id, level, opts)`
- `scr_compute_stat(...)`
- `scr_init_mon_iv_ev(mon)`
- `scr_award_ev_to_mon(mon, ev_gain)`

Behavior notes:

- Move PP is inferred from `global._moves` through `__pfc_move_pp`.
- Level-up move seeding pulls the last eligible four moves from `global._species_moves`.
- The factory resolves icon sprites through `pkicons_get_icon32_dir` when available, then falls back to placeholders.
- Type resolution prefers `global._species_types` and only falls back to older struct shapes when needed.
- Nature support uses CSV-backed natures when available and falls back to a built-in table.

If a mon struct is malformed, fix creation here rather than patching every caller.

## Demo Seeding

Owner: `scripts/PokemonDemo/PokemonDemo.gml`

Purpose:

- seeds deterministic or random debug parties at boot
- guarantees name support on generated mons

Main APIs:

- `scr_poke_runtime_demo_init_random(count)`
- `scr_party_debug_seed_random(pid, count)`
- `scr_party_debug_seed_list(pid, species_array)`
- `scr_party_demo_apply_forced(pid)`

Boot usage:

- `objects/oGame/Create_0.gml` seeds the demo party through `scr_poke_runtime_demo_init_random(6)`.
- `global.DEMO_FORCE_SPECIES` can overwrite seeded slots for deterministic testing.

Behavior notes:

- Demo seeding routes through `party_model_add_mon` and `party_model_update_mon` rather than mutating party arrays blindly.
- `demo_mon_ensure_name` guarantees `.name` and `.nickname` fields exist in the expected shape.
- A single seeded party slot is marked shiny for immediate visual validation.

## Sprite Font And Player Skin

Owners:

- `scripts/font_pokemon/font_pokemon.gml`
- `scripts/SkinSystem/SkinSystem.gml`

Font contract:

- `font_pokemon_init(sprite, order_string, glyph_w, glyph_h)` builds the runtime character map.
- `font_pokemon_draw(text, x, y)` renders the sprite font.
- `font_pokemon_debug_strip(x, y)` is the diagnostic helper when glyph order does not match sprite frames.

Skin contract:

- `skin_set(name)` returns a small sprite bundle for the player avatar and trainer battle art.

Behavior notes:

- Font mapping depends on the ORDER string exactly matching the font sprite's subimage order.
- The current skin script is intentionally lightweight and returns sprite references rather than owning player state itself.

## External Pokemon And Item Assets

Owner: `scripts/pkicons_external/pkicons_external.gml`

Purpose:

- resolves external Pokemon art, icons, cries, and item icons
- caches file-backed sprites and audio paths
- provides stable fallbacks when files are missing

Main contract:

- Call `pkicons_init()` before using the subsystem.
- Configure bases with:
  - `pkicons_set_art96_base(path)`
  - `pkicons_set_icon32_base(path)`
  - `pkicons_set_overworld_base(normal_dir, shiny_dir)`
  - `pkicons_set_cries_base(path)`
  - `pkicons_set_item_icon_base(path)`

Important behavior:

- Placeholder sprite ids are cached into `global.PKICONS.missing_icon32` and `global.PKICONS.missing_art96`.
- Overworld sheets reuse the same directional assumptions as icon32 sheets.
- Item icons are resolved by canonical item identifier first, then numeric fallbacks.
- Multiple debug channels exist: `debug`, `debug_items`, and `debug_crys`.

If a sprite or cry lookup works in one subsystem but not another, fix the base-path or cache logic here rather than special-casing callers.

## Lightweight Support Globals

These systems are small enough that they usually do not need their own dedicated guide yet, but they are part of the core data and presentation stack:

- `scripts/PokemonDataVerify/` validates loaded dataset integrity.
- `scripts/pokemonloader_debug/` contains loader diagnostics.
- `scripts/dev_assign_test_moves/` provides move-set shortcuts for testing.

Use this document with `docs/poke_index_system.md` when you are changing anything that starts with raw data and ends with a generated mon or resolved asset.