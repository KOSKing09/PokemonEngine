# Script Systems

This index documents the script folders by responsibility so later work can find the owning subsystem quickly.

## Detailed guides

- `docs/overworld_systems.md`: start here when changing overworld NPCs, trainer sight or challenge flow, visible wandering wild Pokemon, or world item props
- `docs/battle_system.md`: start here when changing turn flow, battler state, command routing, or battle UI integration
- `docs/battle_doubles.md`: start here when changing doubles/co-op actor ownership, target selection, trainer doubles behavior, or scene layout
- `docs/versus_system.md`: start here when changing local-versus request flow, accept or decline behavior, format selection, or split-screen versus ownership
- `docs/overworld_encounters.md`: start here when adding random encounters, route tables, encounter volumes, or wild co-op encounter rules
- `docs/bag_system.md`: start here when changing bag state, item use behavior, page seeding, or bag UI layout
- `docs/party_system.md`: start here when changing party modes, swap flow, summaries, or bag/party interactions
- `docs/dialog_system.md`: start here when changing dialog queueing, draw ownership, battle message presentation, or split-screen dialog behavior
- `docs/description_menus.md`: start here when changing item descriptions, move prose, flavor text, scroll behavior, or description box layout

## Core game loop and runtime

- `scripts/scr_controls/`: boot-time control singleton and per-frame input helpers
- `scripts/pause_system/`: pause state and pause UI
- `scripts/DialogSystem/`: dialog queue, dialog sessions, and dialog rendering helpers
- `scripts/virtual_keyboard_system/`: caught-Pokemon nickname prompt, controller keyboard grid, and physical-keyboard bridge
- `scripts/CutsceneSystem/`: queued cutscene execution and gating
- `scripts/CutsceneBuilders/`: reusable cutscene payload builders
- `scripts/camera_system/`: battle/world camera state and draw offsets
- `scripts/collision_system/`: world collision helpers
- `scripts/grid_system/`: grid utilities used by map/world systems
- `scripts/player_helper_scripts/`: player-instance helpers outside the main object events, including multiplayer versus requests and overworld encounter volumes or tables
- `scripts/SkinSystem/`: sprite/skin presentation helpers
- `scripts/font_pokemon/`: sprite-font loading and font helpers
- `scripts/currency_system/`: player money and payout helpers

## Data loading and Pokemon model

- `scripts/PokemonDataLoaders/`: CSV/JSON data load path into globals
- `scripts/PokemonDataVerify/`: verification helpers for loaded data
- `scripts/PokemonDemo/`: demo data seeding for startup/debug runs
- `scripts/PokemonIndexSystem/`: species/name lookup indexes
- `scripts/pokemonloader_debug/`: diagnostics for loader output and mismatches
- `scripts/pokemon_factory/`: Pokemon struct creation helpers for battle/tests
- `scripts/dev_assign_test_moves/`: developer utilities for forcing move sets

## Party and bag

- `scripts/party_system/`: public party API and top-level per-frame entrypoint
- `scripts/party_model/`: canonical mon access/update helpers used by party and battle
- `scripts/party_input/`: party navigation/input state machine
- `scripts/party_draw/`: party UI draw entrypoints
- `scripts/party_draw_helpers/`: lower-level draw helpers for party UI pieces
- `scripts/party_ui_helpers/`: shared party UI widget helpers
- `scripts/party_name_helpers/`: naming and nickname support helpers
- `scripts/bag_system/`: bag state, battle bag opening, and inventory helpers
- `scripts/bag_input/`: bag navigation and selection handling
- `scripts/bag_draw/`: bag UI drawing
- `scripts/bag_utils/`: shared bag helper logic

## Battle core

- `scripts/battle_system/`: public battle entrypoints, main update loop, and shared hit-rate resolution such as `__battle_can_hit_target`
- `scripts/battle_command_helpers/`: player command queue, command actor routing, and target-pick helpers
- `scripts/battle_draw_helpers/`: scene anchors, doubles placement helpers, target-selector rectangles, and shared draw geometry
- `scripts/battle_theme_helpers/`: platform/environment theme resolution and UI text-color refresh
- `scripts/battle_actions/`: action resolution helpers used by the turn engine
- `scripts/battle_impls/`: registered battle implementation functions used in hot paths
- `scripts/battle_moves_impls/`: move-specific implementation handlers
- `scripts/battle_move_meta_helpers/`: meta-effect dispatch and effect target resolution
- `scripts/battle_draw/`: battler draw helpers and GUI presentation helpers
- `scripts/battle_ui/`: command box and battle UI components
- `scripts/battle_animations/`: animation queue, overlays, and effect draw/update helpers
- `scripts/battle_state_overlay/`: battle overlay state and stat-change overlay helpers
- `scripts/battle_trainer/`: trainer battle send-out, reward, and prompt helpers

## Battle field/status/weather helpers

- `scripts/battle_field_helpers/`: hazard and side-condition storage/helpers
- `scripts/battle_entry_hazard_helpers/`: switch-in hazard application
- `scripts/battle_terrain_helpers/`: terrain state and terrain-side effects
- `scripts/battle_weather_helpers/`: weather state, lifecycle, and weather-specific calculations
- `scripts/battle_weather_particles/`: weather particle presentation
- `scripts/battle_jaw_lock_helpers/`: trap cleanup and Jaw Lock-specific seams
- `scripts/status_system/`: status registry, apply/clear/tick logic, status dialogs, and residual damage helpers
- `scripts/scr_apply_item_effects/`: battle item effect application helpers
- `scripts/scr_status_diag/`: status diagnostics/debug output

## Assets and external resources

- `scripts/pkicons_external/`: external icon/art/cry path resolution and playback helpers

## Test and smoke harnesses

- `scripts/test_trainer_battle_scenario/`: focused battle smokes and regression harnesses, including the canonical accuracy/evasion smoke path

## Ownership notes

- If the change affects input semantics, start in `scripts/scr_controls/` and the caller Step event.
- If the change affects split-screen composition or per-pid GUI ownership, start in `objects/oGame/Draw_64.gml` and then hop to the owning subsystem draw entrypoint.
- If the change affects overworld NPCs, trainer approach behavior, quest or item rewards from world actors, or visible wild spawns, start in `docs/overworld_systems.md`, then use `scripts/player_helper_scripts/`, `objects/oNpc/`, and the player `Interact` hook.
- If the change affects overworld random encounters, start in `docs/overworld_encounters.md`, then use `scripts/player_helper_scripts/` and the encounter object's Create or Step events as the owning seams.
- If the change affects local-versus request flow or accept or decline behavior, start in `docs/versus_system.md`, then use `scripts/player_helper_scripts/`, `scripts/battle_ui/`, and `scripts/battle_system/`.
- If the change affects caught-Pokemon naming, use `scripts/virtual_keyboard_system/`, `scripts/party_model/`, and the catch-finalization code in `scripts/battle_impls/`.
- If the change affects battle flow, start in `scripts/battle_system/` and then hop to the owning helper module.
- If the change affects doubles or co-op routing, start in `docs/battle_doubles.md`, then use `scripts/battle_system/`, `scripts/battle_command_helpers/`, `scripts/battle_draw_helpers/`, and `scripts/battle_trainer/` as the owning seams.
- If the change affects party data shape, use `scripts/party_model/` and `scripts/party_system/` before editing battle callers.
- If the change affects loaded data or names, inspect `scripts/PokemonDataLoaders/` and `scripts/PokemonIndexSystem/` first.
