# Copilot instructions — Pokemon Rogue (GameMaker)

Keep guidance short and focused: this is a GameMaker project made of script files (.gml) and .yy resources. The goal is to help an AI agent become productive quickly by surfacing the project's structure, runtime contracts, common helpers, and pitfalls.

## Big picture
- Runtime: GameMaker project (scripts + .yy resources). Most systems are implemented as global script libraries that expect to be called from object Step / Draw GUI events.
- Major subsystems:
  - pkicons_external/ — art, icon, and cry loader + helpers (sprite paths, streaming cries).
  - party_system/ — party UI and mons management (input-driven, 240×160 logical UI pipeline).
  - scr_controls/ — centralized input binding and per-frame state (controls_update, controls_pressed).
  - battle_system/ — battle state machine and GUI (battle_open, battle_update, battle_draw_gui).
  - PokemonDataLoaders, PokemonDataVerify, PokemonDemo — data seeding/validation helpers used by party/battle.

## Key runtime contracts (what must be called / initialized)
- scr_controls.scr_controls() runs once at boot to create global `CTRL`. Each Step the game must call `controls_update()` so `controls_pressed()` and other helpers return meaningful values.
- party_init() / party_ensure(pid) are used to initialize per-player party state stored in global.PARTY.
- pkicons_init() is called by pkicons helpers; before using file-based loaders you should call pkicons_set_*_base() to configure asset folders.
- Battle usage pattern (expected by agents working on UI/logic):
  - battle_open(pid, wildLevel) — initializes global.sys_battles[pid]
  - battle_update(pid) — should be called in Step
  - battle_draw_gui(pid) — should be called in Draw GUI

## Important helper APIs & files (use these as entry points)
- scripts/pkicons_external/pkicons_external.gml
  - pkicons_set_art96_base(path), pkicons_set_icon32_base(path)
  - pkicons_get_art96_by_mon(mon), pkicons_get_art96_subimg_by_mon(mon, back)
  - pkicons_play_cry_by_mon(mon), pkicons_get_cry(species)
  - pkicons_inspect_ogg(pathOrSpecies) (debug)
- scripts/scr_controls/scr_controls.gml
  - scr_controls() (boot)
  - controls_update() — call each Step
  - controls_pressed(pid, action), controls_down(pid, action), controls_released(pid, action)
  - controls_actions() returns available rebinding action names
- scripts/party_system/party_system.gml
  - party_init(), party_ensure(pid), party_apply_name_support(pid)
  - party_update() is written to be called from Step; it relies heavily on `controls_pressed` semantics
  - Uses logical 240×160 UI pipeline and helpers like __party_draw_shiny_sparkle
- scripts/battle_system/battle_system.gml
  - battle_open(pid, level), battle_update(pid), battle_draw_gui(pid)
  - Uses a 240×160 logical canvas and helpers: __bui_begin/__bxu/__byu/__bwu/__bhu (convert logical→GUI)
  - Stores per-player battle state in global.sys_battles[pid] via __battle_ensure_slot(pid)

## Data shapes and conventions
- Mon (pokemon) structs: the codebase uses a flexible mon shape. Common fields:
  - species_id (preferred), id, species (fallbacks), name, nickname, shiny, hp, level, battleAnim
  - Many functions normalize species into `species_id` (watch out for `id` vs `species_id`).
- Per-player lists/slots: global.PARTY is an array of player party structs; global.sys_battles is an array of battle slot structs. Use party_ensure / __battle_ensure_slot helpers to safely access/resize.
- File-based assets: pkicons relies on configured base directories (set with pkicons_set_*_base). Files are looked up with multiple candidate patterns; use pkicons_inspect_ogg for diagnostics.

## UI pipeline & drawing conventions
- Logical UI canvas: most UI code targets a 240×160 logical layout and uses a letterboxed rect. Use __bui_begin / __bui_end and conversions __bxu/__byu/__bwu/__bhu when drawing inside a provided rect.
- Use the party system's rect pipeline as canonical example (see `party_system.gml` macros for layout constants). The battle UI mirrors that approach.

## Project-specific patterns & naming
- Prefix conventions:
  - scr_* — scripts that provide subsystems or singletons (e.g., scr_controls)
  - __*  — internal/private helpers used within a script (e.g., __battle_draw_battlers)
  - pkicons_* — pkicons public API
- Global arrays / singletons: many systems store state in global variables named `PARTY`, `PKICONS`, `CTRL`, `sys_battles`. Agents should use the *ensure* helpers rather than manipulating arrays directly.

## Debugging & developer workflows (discoverable helpers)
- There is no build script here — open the project in GameMaker Studio (use the .yy files) and run from the IDE.
- Useful in-code debug helpers:
  - Toggle PKICONS.debug (global.PKICONS.debug) to get verbose pkicons logs.
  - pkicons_inspect_ogg(species) / pkicons_get_cry_debug(species) to inspect cry file resolution and streaming behavior.
  - show_debug_message used in a few places for quick logging.
- Options and bindings are persisted in `options.ini` (controls_load/save read/write it); modifying bindings should be done via provided controls API.

## Common pitfalls / gotchas (call out areas that break often)
- Field name mismatches: some code uses `.id`, others use `.species_id` or `.species`. Always normalize with party_mon_ensure_name or check both fields.
- Input will appear broken unless `controls_update()` is called each Step and `scr_controls()` run at boot.
- Instance creation uses `instance_create_layer(..., "Instances", ...)` in some places — layer names are project-specific; verify that layer exists in rooms.
- Audio: pkicons plays cries via streaming APIs (audio_create_stream / audio_play_sound) which can fail on runtimes that lack the API — use pkicons_inspect_ogg to check.
- Never gate sprite resources with `is_real()`. Always rely on `sprite_exists()` (or compare against `-1`) when validating sprites so resource lookups stay cross-platform safe.

## Minimal examples (explicit, copyable)
- Run a basic battle UI in the game's loop (Step + Draw GUI):
  - At boot: scr_controls(); party_init(); // configure pkicons paths if needed
  - Step loop: controls_update(); party_update(); battle_update(0);
  - Draw GUI: battle_draw_gui(0); // or party_draw_gui_rect(...) for party
- Configure pkicons asset bases before loading cries/icons:
  - pkicons_set_icon32_base("C:/path/to/icons/");
  - pkicons_set_art96_base("C:/path/to/art96/");

## When to ask for help / good PR notes
- If you change a global state shape (mon struct, global.PARTY, sys_battles) leave migration helpers (normalize species_id, ensure name fields) and update party_apply_name_support.
- If adding new UI that uses the 240×160 pipeline, follow the __bui_begin / __bxu conversions so letterboxing remains correct.

If anything here is unclear or you'd like me to expand a short section into examples (for instance: how to animate the `obattleActor` intro using `_B.phase_progress`, or the exact expected fields on `obattleActor`), tell me which part and I will iterate.
