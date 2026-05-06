# Script Systems

This index documents the script folders by responsibility so later work can find the owning subsystem quickly.

## Core game loop and runtime

- `scripts/scr_controls/`: boot-time control singleton and per-frame input helpers
- `scripts/pause_system/`: pause state and pause UI
- `scripts/DialogSystem/`: dialog queue, dialog sessions, and dialog rendering helpers
- `scripts/CutsceneSystem/`: queued cutscene execution and gating
- `scripts/CutsceneBuilders/`: reusable cutscene payload builders
- `scripts/camera_system/`: battle/world camera state and draw offsets
- `scripts/collision_system/`: world collision helpers
- `scripts/grid_system/`: grid utilities used by map/world systems
- `scripts/player_helper_scripts/`: player-instance helpers outside the main object events
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

- `scripts/battle_system/`: public battle entrypoints and main update loop
- `scripts/battle_command_helpers/`: player command queue, command actor routing, and target-pick helpers
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

- `scripts/test_trainer_battle_scenario/`: focused battle smokes and regression harnesses

## Ownership notes

- If the change affects input semantics, start in `scripts/scr_controls/` and the caller Step event.
- If the change affects battle flow, start in `scripts/battle_system/` and then hop to the owning helper module.
- If the change affects party data shape, use `scripts/party_model/` and `scripts/party_system/` before editing battle callers.
- If the change affects loaded data or names, inspect `scripts/PokemonDataLoaders/` and `scripts/PokemonIndexSystem/` first.
