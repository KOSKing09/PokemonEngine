# Runbook

This project is a GameMaker Studio project. The runtime contracts live in scripts and are booted from the room/object events, not from a standalone CLI entrypoint.

## Documentation map

- `docs/script_systems.md`: quick ownership map when you only need to know which folder owns a behavior
- `docs/runtime_systems.md`: controls, collision and grid movement, split-screen layout, pause, cutscenes, transitions, and world room runtime
- `docs/overworld_systems.md`: overworld NPC interaction flow, trainer approach behavior, visible wild wandering mons, and world props
- `docs/roguelike_world.md`: infinite `rm_world` chunk generation, custom biomes, prefab hooks, reserved zones, and rogue-world warp setup
- `docs/progression_support_systems.md`: virtual keyboard, evolution queue, PC storage, and currency
- `docs/data_asset_systems.md`: data load, mon factory, demo seeders, font and skin helpers, and external pkicons assets
- `docs/battle_system.md`: battle slot shape, phase flow, entrypoints, and battle-specific extension seams
- `docs/battle_doubles.md`: doubles/co-op format rules, actor layout, ownership routing, target helpers, and trainer doubles seams
- `docs/versus_system.md`: local-versus request state, accept or decline flow, format selection, and battle-slot ownership setup
- `docs/overworld_encounters.md`: encounter tables, encounter-volume wiring, wild battle handoff, and co-op wild trigger rules
- `docs/bag_system.md`: bag state, inventory helpers, in-battle item use flow, and bag draw/input split
- `docs/party_system.md`: party state, menu modes, summary flow, and party/battle integration
- `docs/dialog_system.md`: dialog queue ownership, battle-vs-overworld rendering rules, callbacks, and split-screen draw behavior
- `docs/description_menus.md`: where item, species, and move description text comes from and which draw/input helpers own the UI

## Open and run

1. Open `Pokemon Rogue.yyp` in GameMaker Studio.
2. Run the default configuration from the IDE.
3. The startup room creates `oGame`, which loads data, seeds demo party data, configures controls, and enables the dialog/pause systems.

## Boot sequence

The current boot path is:

- `objects/oGame/Create_0.gml`
  - sets up fonts and GUI size (`240x160`)
  - loads data tables
  - initializes pkicons base paths
  - initializes transition defaults plus world room runtime and startup world music
  - calls `party_init()`, `bags_init()`, `scr_controls()`, `pause_init()`, `dialog2p_init()`, `evolution_init()`, and `virtual_keyboard_init()`
- `objects/oGame/Step_1.gml`
  - calls `controls_update()` before any input-driven UI reads
  - blocks bag, pause, and party updates while either pid has an active virtual keyboard overlay
  - advances `evolution_update(pid)` and `virtual_keyboard_update(pid)`
  - drains dialog queues with `dialog2p_step(pid)` for pid `0` and pid `1` when the backing arrays exist
- `objects/oPlayer/Step_1.gml`
  - calls `battle_update(0)` when a battle is open
  - runs developer smokes gated by `global.DEV_AUTO_*` flags
- `objects/oGame/Draw_64.gml`
  - switches to split-screen GUI layout automatically when more than one `oPlayer` exists
  - keeps overworld dialog on `dialog2p_draw_gui_rect(...)`
  - keeps battle dialog inside the battle command UI instead of drawing the standalone dialog box

## Runtime contracts by system

- Controls:
  - run `scr_controls()` once at boot
  - call `controls_update()` every Step before reading `controls_pressed()` or `controls_down()`
  - controller deadzone is persisted in `options.ini` under `[Input] deadzone`
  - pid-to-pad ownership is stored in `CTRL.pad_index = [0, 1]`
- Party:
  - call `party_init()` at boot
  - use `party_ensure(pid)` before touching `global.PARTY[pid]`
  - use `party_model_set_stored_mon_nickname(pid, store_info, nick)` when updating a caught mon that may already have been routed into party or PC storage
- Battle:
  - open wild battles with `battle_open(wildLevel)`, `battle_open(pid, wildLevel)`, or `battle_open(pid, wildLevel, areaTypeOrOpts, opts)`
  - open trainer battles with `battle_open_trainer(pid, trainer_payload)`, which forwards into `battle_open(...)`
  - press F1 in `objects/oPlayer/Step_1.gml` for the debug wild battle path
  - call `battle_update(pid)` in Step
  - call `battle_draw_gui(pid)` in Draw GUI
  - battle close waits while nickname entry is active through `virtual_keyboard_blocks_input(pid)`
- Overworld encounters:
  - call `overworld_encounter_init(id)` from the encounter volume's Create event
  - call `overworld_encounter_step(id)` from that volume's Step event
  - register route data with `overworld_encounter_register_table(region, habitat, entries)`
  - prefer per-instance overrides for local tuning instead of editing global defaults for every route
- World runtime and room audio:
  - use `world_room_register(room_id, display_name, music, indoor)` or `world_set_room_music(room_id, music)` to author room music
  - use `world_play_music(sound)` for immediate world-music playback and `world_stop_room_music()` to stop it cleanly
  - use `room_music = -1` on warp opts for explicit silent rooms
  - keep `world_room_apply()` running from `objects/oGame/Other_4.gml` so warp placement, room audio, and route bars re-apply on every room entry
- Multiplayer versus:
  - use `multiplayer_request_versus_battle(pid)` for player-driven versus starts
  - keep `multiplayer_update_versus_request(pid)` running so accept or decline input is processed
  - use `multiplayer_start_versus_battle(pid, format)` only for controlled tests or flows that intentionally bypass the accept prompt
- Dialog:
  - `dialog2p_step(pid)` advances queued dialogs
  - `dialog2p_update(pid)` advances an active dialog page
  - draw overworld dialog with `dialog2p_draw_gui_rect(...)` from Draw GUI
  - do not use the standalone dialog renderer in battle; battle command UI owns battle message presentation
- Virtual keyboard / caught nicknames:
  - call `virtual_keyboard_init()` at boot
  - call `virtual_keyboard_update(pid)` each Step
  - call `virtual_keyboard_draw_gui(pid)` or `virtual_keyboard_draw_gui_rect(pid, rx, ry, rw, rh)` from Draw GUI
  - use `virtual_keyboard_request_caught_nickname(pid, store_info, species_name)` after a successful catch-storage handoff
  - treat `virtual_keyboard_blocks_input(pid)` as a gameplay/input gate for movement and overlapping menus
  - preserve the name-entry input grace and `keyboard_string` delta path so the opening `Interact` press is ignored and repeated typed characters are accepted
- Pkicons:
  - call `pkicons_set_art96_base(...)`, `pkicons_set_icon32_base(...)`, and `pkicons_set_cries_base(...)` before relying on external assets

## Manual debug entrypoints

- `F1` in the default debug room toggles a sample wild double battle from `objects/oPlayer/Step_1.gml`
- The F1 path revives up to the first two party mons, picks a random battle theme, and then prefers weighted `demo_route_1` grass/bush encounter-table rolls for both enemy slots at roughly `Lv. 5-10`
- If the encounter helpers are unavailable, the same F1 path falls back to fully random species ids and levels
- The default debug startup seeds a party and bag so battle, party, and bag UIs can be exercised immediately

## Split-screen usage

- Split-screen is automatic when the room contains more than one `oPlayer` instance.
- pid `0` uses the left half of the GUI and pid `1` uses the right half.
- `objects/oGame/Draw_64.gml` is the main composition seam for split-screen UI ownership.
- Systems with split-screen-aware draw entrypoints currently include battle, pause, bag, party, evolution, the virtual keyboard, and overworld dialog.
- Physical keyboard character entry for the virtual keyboard is intentionally owned by the first active nickname-entry pid so split-screen players do not both consume the same typed text.

## Smoke tests

Focused battle smokes are triggered by `global.DEV_AUTO_*` flags in `objects/oGame/Create_0.gml` and advanced from `objects/oPlayer/Step_1.gml`.

Common flags:

- `global.DEV_AUTO_FORCED_PLAYER_SWITCH_SMOKE`
- `global.DEV_AUTO_DOUBLES_ENEMY_FAINT_SEND_SMOKE`
- `global.DEV_AUTO_BURN_POISON_RESIDUAL_SMOKE`
- `global.DEV_AUTO_VISUAL_TARGET_SMOKE`
- `global.DEV_AUTO_ACCURACY_SMOKE`

Accuracy smoke coverage:

- validates neutral `100`-accuracy hit behavior
- validates extreme stage math (`accuracy = -6`, `evasion = +6`) through `__battle_can_hit_target`
- validates move-applied accuracy drops by stacking `sand-attack` to the stage cap, then confirming later `tackle` uses miss through the live action path

Recommended workflow:

1. Temporarily set one smoke flag to `true` in `objects/oGame/Create_0.gml`.
2. Run the project once.
3. Capture or inspect the log in `tmp/`.
4. Restore the flag to `false` after validation.

Suggested log names:

- `tmp/accuracy-smoke.log` for the accuracy/evasion regression path

## Igor command

The current Windows VM smoke path is:

```powershell
& 'c:/ProgramData/GameMakerStudio2/Cache/runtimes/runtime-2024.14.2.256/bin/igor/windows/x64/Igor.exe' `
  '--project=c:/Users/trane/GameMakerProjects/PokemonEngine/Pokemon Rogue.yyp' `
  '--user=c:/Users/trane/AppData/Roaming/GameMakerStudio2/tranerogers_396227' `
  '--runtimePath=c:/ProgramData/GameMakerStudio2/Cache/runtimes/runtime-2024.14.2.256' `
  '--runtime=VM' `
  '--config=Default' `
  '--cache=c:/Users/trane/GameMakerProjects/PokemonEngine/tmp/igor/cache' `
  '--temp=c:/Users/trane/GameMakerProjects/PokemonEngine/tmp/igor/temp' `
  '--of=c:/Users/trane/GameMakerProjects/PokemonEngine/tmp/igor/out/Pokemon Rogue.win' `
  '--tf=c:/Users/trane/GameMakerProjects/PokemonEngine/Pokemon Rogue.zip' `
  -- windows Run
```

To keep a smoke log, pipe the output to `Tee-Object`:

```powershell
& 'c:/ProgramData/GameMakerStudio2/Cache/runtimes/runtime-2024.14.2.256/bin/igor/windows/x64/Igor.exe' ... 2>&1 |
  Tee-Object 'c:/Users/trane/GameMakerProjects/PokemonEngine/tmp/your_smoke.log'
```

## Refactor note

The battle system is still the largest single script. The current extraction boundary is:

- `scripts/battle_command_helpers/` for command queue and target-pick helpers
- `scripts/battle_theme_helpers/` for environment/platform theme helpers

If you continue splitting battle code, keep helper files grouped by responsibility and leave the public entrypoints in `scripts/battle_system/battle_system.gml`.
