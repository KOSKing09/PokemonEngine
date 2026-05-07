# Party System

This guide explains how the party UI is initialized, which public helpers are safe to call, how the mode/state machine is organized, and where to edit party logic versus input versus draw behavior.

## Runtime contract

- Boot once with `party_init()`.
- Use `party_ensure(pid)` before touching `global.PARTY[pid]` directly.
- Call `party_update()` every Step.
- Call `party_draw_gui(pid)` or `party_draw_gui_rect(pid, x, y, w, h)` from Draw GUI.
- When the party is opened from battle, let battle code set swap flags through `party_set_swap_mode(...)` instead of inventing separate ad hoc markers.

## Public API

- `party_init()` initializes `global.PARTY` for the active player count.
- `party_ensure(pid)` returns the canonical party struct and fills in defaults.
- `party_is_open(pid)`, `party_open(pid)`, `party_close(pid)`, and `party_toggle(pid)` manage visibility.
- `party_set_swap_mode(pid, swap, forced)` and `party_clear_swap_mode(pid)` coordinate battle swap behavior.
- `party_apply_name_support(pid)`, `party_set_nickname(pid, index, nick)`, and `party_ensure_named(pid)` manage nickname/display-name support.
- `party_draw_gui(pid)` and `party_draw_gui_rect(pid, rx, ry, rw, rh)` are the stable draw entrypoints.

## State shape

Each `global.PARTY[pid]` slot is a struct with the current menu state and the player's mons.

Common fields:

- `open`: whether the party UI is visible
- `mode`: current UI mode such as `list`, `menu`, `select`, `select_item`, `summary_profile`, `summary_moves`, or `summary_forget`
- `sel`: selected party index
- `scroll`: top visible party row in the list view
- `menu_sel`: selected option inside the per-mon menu
- `swap_index`: source index for out-of-battle swaps
- `lock`: short input lock during transitions
- `mons`: array of canonical mon structs
- `sum_move_sel`, `sum_learn_sel`: summary and learn-flow selection state
- `learn_pending`: move-learn payload used by the summary/forget flow
- `give_pending` and `use_pending`: temporary payloads passed in from the bag system
- `_battle_swap_mode`, `_battle_swap_mode_forced`, `_battle_baton_pass_mode`: battle-owned flags for switch behavior

## Ownership map

- `scripts/party_system/party_system.gml`: public wrappers, state defaults, summary text selection helpers, and learn-flow helpers
- `scripts/party_input/party_input.gml`: actual per-frame state machine for list/menu/summary/select flows
- `scripts/party_draw/party_draw.gml`: full-screen draw implementation and list layout
- `scripts/party_draw_helpers/` and `scripts/party_ui_helpers/`: lower-level rendering helpers used by the summary and list UI
- `scripts/party_model/`: canonical mon access and mutation helpers
- `scripts/party_name_helpers/`: naming and nickname support

## Mode guide

- `list`: main party list navigation
- `menu`: per-mon action menu, usually `Summary / Switch or Swap In / Item / Cancel`
- `select`: choosing another party member for a swap flow
- `select_item`: choosing a target mon for a bag action
- `summary_profile`: Pokemon summary info page, with the left description box and the right-side profile block
- `summary_moves`: move list page, with move selection on the right and move description text on the left
- `summary_forget`: replacement flow when learning a new move

The main mode dispatcher lives in `scripts/party_input/party_input.gml::__party_impl_party_update()`.

The concrete summary-page draw implementation is forwarded into `scripts/party_ui_helpers/party_ui_helpers.gml`:

- `__party_impl_draw_summary(...)` composes the whole summary screen
- `__party_impl_draw_profile_block(...)` owns the right-side Pokemon info page
- `__party_impl_draw_moves_block(...)` owns the right-side move list page

## Where To Edit

- Add new persistent party-state fields: `party_ensure(pid)` in `scripts/party_system/party_system.gml`
- Change open/close behavior or default mode setup: `party_open(pid)` and `party_close(pid)`
- Change list/menu/summary controls: `scripts/party_input/party_input.gml::__party_impl_party_update()`
- Change full party list layout or row rendering: `scripts/party_draw/party_draw.gml::__party_impl_party_draw_gui_rect(...)`
- Change summary text sourcing: `scripts/party_system/party_system.gml::__party_get_desc_text(...)`
- Change summary text rendering or scroll/highlight behavior: `__party_desc_draw_scrollable_colored(...)` and the helpers it forwards to
- Change learn/forget flow: `__party_learn_open(...)`, `__party_draw_learn_desc(...)`, `__party_draw_learn_list(...)`, and `__party_input_learn(...)`
- Change battle swap integration: `party_set_swap_mode(...)`, `party_clear_swap_mode(...)`, and the swap branches in `party_input.gml`

## Summary menu flow

The party summary menu is the Pokemon screen that shows the info page and the move-list page.

Its main draw path is:

1. `__party_draw_summary(...)`
2. `__party_impl_draw_summary(...)`
3. right-side content helper chosen by mode

The right-side content helper is usually:

- `__party_impl_draw_profile_block(...)` for `summary_profile`
- `__party_impl_draw_moves_block(...)` for `summary_moves`

The left side keeps one conceptual description area, but the text shown there changes by mode.

- `summary_profile`: species flavor text or species display-name fallback
- `summary_moves`: selected move prose from `global._move_text`
- `summary_forget`: move prose while selecting a move to replace
- learn flow `desc` step: prose for the move being taught

Text sourcing happens in `__party_get_desc_text(_P, _M)` for the normal summary pages.

Scrolling behavior is not handled by the draw wrapper itself. Input code accumulates scroll requests into `global.sys_party_desc_scroll_req`, and the description renderer consumes that state.

## Bag and battle integration

The party UI is the target selector for several other systems.

Bag integration:

- `Give` from the bag opens the party and fills `P.give_pending`
- `Use` for healing/revive-style items can open the party and fill `P.use_pending`
- `select_item` mode finishes the item targeting flow and hands control back to the bag or battle system

Battle integration:

- battle can open the party for ordinary switch, forced replacement, or Baton Pass flows
- battle-side flags are stored on the party struct instead of on ad hoc globals
- trainer about-to-send prompts also use the party list as a constrained pick screen

When adding a new cross-system flow, prefer adding one explicit pending payload on the party struct rather than teaching the party UI to inspect many unrelated globals.

## Copyable examples

Initialize and open the party:

```gml
party_init();
party_open(0);
```

Ensure a mon array exists before editing it:

```gml
var P = party_ensure(0);
if (array_length(P.mons) > 0) {
    P.mons[0].nickname = "Starter";
}
```

Open a move-learning flow for one mon:

```gml
__party_learn_open(0, 2, 33);
```

Mark the party as a forced battle replacement screen:

```gml
party_set_swap_mode(0, true, true);
party_open(0);
```

## Practical rules

- Add new fields in `party_ensure(pid)` so older save/runtime states do not crash when the UI opens.
- Keep input-state changes in `party_input.gml` and presentation changes in `party_draw.gml` or the draw-helper modules.
- Use `party_model_*` helpers when changing mon data shape instead of writing battle-specific assumptions into the UI layer.
- If a new summary page needs new prose, add a new mode and a dedicated text-selection branch rather than overloading an unrelated one.
