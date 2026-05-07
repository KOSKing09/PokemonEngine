# Pokemon Summary Menu

This guide is about the Pokemon summary screen in the party UI: the screen that shows the Pokemon info page and the move list page.

If you want to change the menu that shows Pokemon info, move descriptions, summary text, or the right-side move list, this is the owning guide.

## What this menu actually is

This is not a separate standalone system. It is a mode inside the party system.

The summary menu is driven by party state and rendered through party helpers:

- state and routing: `scripts/party_system/party_system.gml`
- summary input and page switching: `scripts/party_input/party_input.gml`
- summary draw wrapper: `scripts/party_system/party_system.gml::__party_draw_summary(...)`
- concrete summary UI implementation: `scripts/party_ui_helpers/party_ui_helpers.gml::__party_impl_draw_summary(...)`

## The main summary pages

The summary screen is mode-driven.

- `summary_profile`: the Pokemon info page
- `summary_moves`: the move list page
- `summary_forget`: the move-replacement page used during learn flow

In practice, the menu you meant is mostly these two pages:

- `summary_profile` for the Pokemon info page
- `summary_moves` for the move list and move description page

## Ownership map

- `scripts/party_system/party_system.gml::__party_draw_summary(...)`: public summary draw seam that forwards into the concrete UI helper
- `scripts/party_ui_helpers/party_ui_helpers.gml::__party_impl_draw_summary(...)`: overall summary screen composition
- `scripts/party_ui_helpers/party_ui_helpers.gml::__party_impl_draw_left_panel(...)`: left panel art, labels, and description-box geometry
- `scripts/party_ui_helpers/party_ui_helpers.gml::__party_impl_draw_right_frame(...)`: right-side panel frame
- `scripts/party_ui_helpers/party_ui_helpers.gml::__party_impl_draw_profile_block(...)`: Pokemon info page content
- `scripts/party_ui_helpers/party_ui_helpers.gml::__party_impl_draw_moves_block(...)`: move list page content
- `scripts/party_system/party_system.gml::__party_get_desc_text(...)`: chooses the text shown in the left description box
- `scripts/party_input/party_input.gml::__party_impl_party_update()`: page switching, scrolling, and summary controls

## Pokemon info page

The Pokemon info page is `summary_profile`.

It is drawn by:

- `__party_draw_summary(...)`
- `__party_impl_draw_summary(...)`
- `__party_impl_draw_profile_block(...)`

What lives on this page now:

- OT data
- type display
- ability
- nature
- trainer memo style text
- the left-side summary description area

Edit here when:

- you want to change which fields appear on the Pokemon info page: `__party_impl_draw_profile_block(...)`
- you want to rearrange the left or right panel layout: `__party_impl_draw_summary(...)`, `__party_impl_draw_left_panel(...)`, and `__party_impl_draw_right_frame(...)`
- you want to change the text shown in the left description area while on the info page: `__party_get_desc_text(...)`

## Move list page

The move list page is `summary_moves`.

It is drawn by:

- `__party_draw_summary(...)`
- `__party_impl_draw_summary(...)`
- `__party_impl_draw_moves_block(...)`

What lives on this page now:

- the Pokemon's known move list
- current move selection through `sum_move_sel`
- move description text in the left-side description panel
- learn-flow overlays when a move-teach flow is active

Edit here when:

- you want to change the move list layout or row contents: `__party_impl_draw_moves_block(...)`
- you want to change how selected move descriptions are chosen: `__party_get_desc_text(...)`
- you want to change page composition, title bars, circles, or left-right panel sizing: `__party_impl_draw_summary(...)`

## Where the description text comes from

The summary menu has one main description box on the left side.

Its text is selected by `scripts/party_system/party_system.gml::__party_get_desc_text(_P, _M)`.

Current behavior:

- `summary_profile` pulls Pokemon flavor text from `global._species_flavor_text`
- `summary_moves` pulls move prose from `global._move_text`
- `summary_forget` reuses move-description logic for move replacement

Edit `__party_get_desc_text(...)` when:

- the wrong text source is being used
- species fallback rules need to change
- move-description fallback rules need to change

Do not start in the draw helper if the real problem is that the wrong text is being chosen.

## Input and page switching

Summary navigation is owned by `scripts/party_input/party_input.gml::__party_impl_party_update()`.

That is the right place to change:

- how the player switches between `summary_profile` and `summary_moves`
- which buttons scroll the description text
- how `sum_move_sel` changes on the move page
- how the learn or forget flow takes over the summary screen

If the screen is showing the right content in the wrong place, edit draw helpers. If it is opening the wrong page or reacting to the wrong button, edit the input state machine.

## Learn and forget overlays

The summary screen also hosts the move-learning flow.

Key seams:

- `__party_learn_open(pid, mon_index, move_id)` seeds the learn state
- `__party_draw_learn_desc(...)` draws the description-first learn page
- `__party_draw_learn_list(...)` draws the selectable learn list
- `__party_input_learn(pid)` handles the learn-list interactions

This matters because `summary_moves` can temporarily stop behaving like the normal move page when `learn_pending` is active.

## Where To Edit By Goal

- Change the Pokemon info page fields: `scripts/party_ui_helpers/party_ui_helpers.gml::__party_impl_draw_profile_block(...)`
- Change the move list page rows or formatting: `scripts/party_ui_helpers/party_ui_helpers.gml::__party_impl_draw_moves_block(...)`
- Change summary page layout or panel geometry: `scripts/party_ui_helpers/party_ui_helpers.gml::__party_impl_draw_summary(...)`, `__party_impl_draw_left_panel(...)`, and `__party_impl_draw_right_frame(...)`
- Change description text source or fallback rules: `scripts/party_system/party_system.gml::__party_get_desc_text(...)`
- Change summary input or page switching: `scripts/party_input/party_input.gml::__party_impl_party_update()`
- Change learn or forget behavior inside the summary screen: `scripts/party_system/party_system.gml::__party_learn_open(...)`, `__party_draw_learn_desc(...)`, `__party_draw_learn_list(...)`, and `__party_input_learn(...)`

## Practical rules

- Treat the summary menu as part of the party system, not as a separate UI stack.
- Put data-source fixes in `party_system.gml`, input changes in `party_input.gml`, and layout changes in `party_ui_helpers.gml`.
- When changing the move page, validate both normal `summary_moves` and learn-flow cases because the same screen can be reused in both states.
- When changing the info page, check both the right-side profile block and the left description box because they are owned by different helpers.
