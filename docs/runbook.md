# Runbook

This project is a GameMaker Studio project. The runtime contracts live in scripts and are booted from the room/object events, not from a standalone CLI entrypoint.

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
  - calls `party_init()`, `bags_init()`, `scr_controls()`, `pause_init()`, and `dialog2p_init()`
- `objects/oPlayer/Step_1.gml`
  - advances dialog queues
  - calls `battle_update(0)` when a battle is open
  - runs developer smokes gated by `global.DEV_AUTO_*` flags

## Runtime contracts by system

- Controls:
  - run `scr_controls()` once at boot
  - call `controls_update()` every Step before reading `controls_pressed()` or `controls_down()`
- Party:
  - call `party_init()` at boot
  - use `party_ensure(pid)` before touching `global.PARTY[pid]`
- Battle:
  - open with `battle_open(...)` or `battle_open_trainer(...)`
  - call `battle_update(pid)` in Step
  - call `battle_draw_gui(pid)` in Draw GUI
- Dialog:
  - `dialog2p_step(pid)` advances queued dialogs
  - `dialog2p_update(pid)` advances an active dialog page
- Pkicons:
  - call `pkicons_set_art96_base(...)`, `pkicons_set_icon32_base(...)`, and `pkicons_set_cries_base(...)` before relying on external assets

## Manual debug entrypoints

- `F1` in the default debug room toggles a sample wild double battle from `objects/oPlayer/Step_1.gml`
- The default debug startup seeds a party and bag so battle, party, and bag UIs can be exercised immediately

## Smoke tests

Focused battle smokes are triggered by `global.DEV_AUTO_*` flags in `objects/oGame/Create_0.gml` and advanced from `objects/oPlayer/Step_1.gml`.

Common flags:

- `global.DEV_AUTO_FORCED_PLAYER_SWITCH_SMOKE`
- `global.DEV_AUTO_DOUBLES_ENEMY_FAINT_SEND_SMOKE`
- `global.DEV_AUTO_BURN_POISON_RESIDUAL_SMOKE`
- `global.DEV_AUTO_VISUAL_TARGET_SMOKE`

Recommended workflow:

1. Temporarily set one smoke flag to `true` in `objects/oGame/Create_0.gml`.
2. Run the project once.
3. Capture or inspect the log in `tmp/`.
4. Restore the flag to `false` after validation.

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
