# Pokemon Engine

Pokemon Engine is a GameMaker Studio Pokemon project with Emerald-style battle flow, party and bag UIs, external asset loading, and an expanding doubles/co-op battle path.

Start with these docs:

- `docs/runbook.md` for boot flow, manual run steps, smoke usage, and the Igor VM command
- `docs/script_systems.md` for a folder-by-folder map of the script subsystems
- `docs/battle_system.md` for battle-slot state, phases, and battle entrypoints
- `docs/battle_doubles.md` for doubles/co-op actor layout, ownership routing, target selection, and trainer doubles behavior
- `docs/bag_system.md` for bag boot/update/draw flow, inventory helpers, and battle-bag extension seams
- `docs/party_system.md` for party state, menu modes, summary flow, and battle swap integration
- `docs/dialog_system.md` for dialog queueing, draw ownership, battle integration, and split-screen dialog rules
- `docs/description_menus.md` for the shared rules behind item, Pokemon, and move description panels

Project notes:

- The current debug room seeds a demo party and bag on startup.
- `F1` in the default room toggles a sample wild double battle.
- Split-screen UI is enabled automatically when more than one `oPlayer` instance exists. The Draw GUI pass then renders separate left/right UI rects for pid `0` and pid `1`.
- Caught-Pokemon naming now uses `scripts/virtual_keyboard_system/` and is controller-safe. Physical keyboard input is still accepted, but only the first active nickname-entry pid owns physical keyboard characters during split-screen.
- Focused battle regressions are validated through `global.DEV_AUTO_*` smokes in `objects/oGame/Create_0.gml` and `objects/oPlayer/Step_1.gml`.
- Accuracy and evasion validation is covered by `global.DEV_AUTO_ACCURACY_SMOKE`, which checks both direct stage math and a move-applied `sand-attack` path through the live battle action flow.
