# Progression Support Systems

This guide covers the player-facing support systems that sit between battle results and persistent roster management.

## Virtual Keyboard

Owner: `scripts/virtual_keyboard_system/virtual_keyboard_system.gml`

Purpose:

- controller-safe nickname entry after catches
- split-screen-safe ownership for physical keyboard input
- a shared input gate so overworld and menus do not keep moving underneath the prompt

Main contract:

- Call `virtual_keyboard_init()` at boot.
- Call `virtual_keyboard_update(pid)` each Step.
- Draw with `virtual_keyboard_draw_gui(pid)` or `virtual_keyboard_draw_gui_rect(pid, rx, ry, rw, rh)`.
- Use `virtual_keyboard_request_caught_nickname(pid, store_info, species_name)` after a successful catch-storage handoff.

Important queries:

- `virtual_keyboard_is_active(pid)`
- `virtual_keyboard_blocks_input(pid)`

Behavior notes:

- State is stored per pid in `global.VKEYBOARD[pid]`.
- The flow is `requested -> prompt -> entry -> finish`.
- The prompt can be accepted or skipped before the text grid opens.
- Only the first active pid in `entry` phase owns physical `keyboard_string` characters.
- `SHIFT` is single-use, `CAPS` is sticky, and `Back` or `Run` deletes characters during entry.

If caught-mon naming overlaps with other menus, treat `virtual_keyboard_blocks_input(pid)` as the authoritative gameplay gate.

## Evolution

Owner: `scripts/evolution_system/evolution_system.gml`

Purpose:

- queues post-battle or post-level evolution work
- gates evolution so it does not start while dialog, pause, bag, party, PC, or battle EXP animation is still active
- applies the evolved mon data back onto the same mon struct

Main contract:

- Call `evolution_init()` at boot.
- Call `evolution_update(pid)` every Step.
- Queue work with `evolution_enqueue_levelup(pid, mon_ref, actor_ref)`.

Useful queries:

- `evolution_is_active(pid)`
- `evolution_has_pending(pid)`
- `evolution_find_levelup_target(mon)`

Behavior notes:

- State lives in `global.EVOLUTION[pid]`.
- The current supported automatic trigger path is level-up evolution through `level-up` evolution rows.
- Unsupported trigger fields are explicitly screened out before a row is accepted.
- The system preserves important mon fields such as nickname, IVs, EVs, move PP, shiny state, held item, and status-related fields.
- The animation phase can be canceled with `Run` or `Back` when `allow_cancel` is true.

If evolution starts too early or overwrites the wrong mon fields, inspect `__evolution_can_begin` and `__evolution_apply_to_mon` before changing callers.

## PC Storage

Owner: `scripts/pc_system/pc_system.gml`

Purpose:

- per-player Pokemon storage boxes
- split-screen-safe PC UI
- drag or swap style party-to-box and box-to-party movement

Main contract:

- Call `pc_init()` at boot.
- Call `pc_update()` each Step.
- Draw with `pc_draw_gui(pid)` or `pc_draw_gui_rect(pid, rx, ry, rw, rh)`.
- Open with `pc_open(pid)` and close with `pc_close(pid)`.

Important queries:

- `pc_is_open(pid)`
- `pc_toggle(pid)`
- `pc_store_mon(pid, mon)`
- `pc_store_mon_to_box(pid, mon)`

State shape:

- `global.SYS_PC[pid]`
- `sys_boxes`
- `sys_active_box`
- `sys_cursor_area`
- `sys_cursor_index`
- `sys_held_mon`
- `sys_status_text`

Behavior notes:

- The UI defaults to 14 boxes with 30 slots each per player.
- `Inventory` acts as a modifier during PC input so shoulder/page actions can be repurposed.
- `PageUp` and `PageDown` change either theme or active box depending on modifier state.
- Closing the PC returns any currently held mon to its origin first.
- Legacy storage import still runs on first state creation through `pc_import_legacy_storage` when available.

The PC system is intended to be safe for split-screen draw composition. Use the rect draw entrypoint rather than drawing directly to full GUI space.

## Currency

Owner: `scripts/currency_system/currency_system.gml`

Purpose:

- simple global money container for rewards, shops, and payouts

Main contract:

- Call `currency_init(starting_amount)` when you want to seed or guarantee the currency singleton.
- Read with `currency_get()`.
- Mutate with `currency_add(delta)` or `currency_set(amount)`.

State shape:

- `global.CURRENCY.money`

Behavior notes:

- Values are clamped to non-negative integers.
- `currency_add` accepts negative values and safely floors the result at zero.

## How These Systems Fit Together

Common progression flow:

1. Battle or overworld capture code stores or routes a mon.
2. `virtual_keyboard_request_caught_nickname(...)` optionally asks for a nickname.
3. Post-battle EXP or level work queues `evolution_enqueue_levelup(...)` when appropriate.
4. The player can later manage overflow or manual storage movement through `pc_open(pid)`.

When changing roster progression, keep the ordering stable: nickname first, evolution after UI gates clear, PC only through the storage helpers.