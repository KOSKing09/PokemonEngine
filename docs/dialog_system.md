# Dialog System

This guide documents the current dialog system contracts, queueing model, draw ownership, and the seam between overworld dialog and battle message presentation.

Use it when you need to change dialog lifecycle, add a new queued message source, change how dialog is rendered in split-screen, or debug why a dialog does or does not appear.

## Runtime contract

- Boot once with `dialog2p_init()`.
- Call `dialog2p_step(pid)` each Step to drain queued items when no dialog is already open.
- Call `dialog2p_update(pid)` while that pid has an active dialog.
- Draw overworld dialog from Draw GUI with `dialog2p_draw_gui_rect(pid, rx, ry, rw, rh)`.
- In battle, use the battle command UI draw path instead of the standalone dialog renderer.

## Public API

- `dialog2p_init()` initializes `global.DIALOG2P` and `global.DIALOG2P_Q`.
- `dialog2p_is_open(pid)` returns whether the pid currently has an active dialog session.
- `dialog2p_enqueue_text(pid, text, key, gate)` is the legacy text wrapper around payload queueing.
- `dialog2p_show(pid, text, gate?)` prefers immediate show and falls back to enqueue semantics.
- `dialog2p_step(pid)` opens the next queued item if its gate allows it now.
- `dialog2p_queue_has_faint(pid)` checks whether a faint-priority item is still queued.
- `dialog2p_open_text(pid, text)` opens a raw text dialog.
- `dialog2p_enqueue(pid, payload)` queues a payload struct.
- `dialog2p_show_now(pid, payload)` bypasses the queue and replaces current content now.
- `dialog2p_wait_closed(pid, callback)` registers a callback to run when the current dialog closes.
- `dialog2p_set_portrait(pid, spr, subimg, name)` assigns portrait/name-label cosmetics.
- `dialog2p_update(pid)` advances typing, page flips, and close behavior.
- `dialog2p_draw_world(pid, cam)` is the world-space draw helper.
- `dialog2p_draw_gui_rect(pid, rx, ry, rw, rh)` is the GUI-space draw helper used by the current overworld path.

## Session and queue shape

Each `global.DIALOG2P[pid]` entry is a session struct. Important fields include:

- `open`: whether the session is currently visible
- `all_lines`: wrapped full dialog content
- `lines`: the currently active visible lines
- `page_idx`, `char_idx`, `tick`, `arrow_tick`: page/typewriter state
- `portrait`, `portrait_frame`, `name_label`: cosmetic state
- `_current_item`: the queued payload item currently being shown
- `_on_close_callbacks`: callbacks waiting for dialog close

Each `global.DIALOG2P_Q[pid]` entry is an array of queued payload structs. Common payload fields are:

- `text`: dialog body
- `key`: duplicate-suppression key
- `gate`: queue gate such as `any`, `after-faint`, or `no-intro`
- `is_faint`: high-priority marker used to pull faint pages to the front when needed

## Queueing and gates

The queue is not just FIFO text. It has battle-aware gating.

- `any`: open as soon as no dialog is already open
- `after-faint`: wait until `_faint_pending` is cleared for that pid's battle slot
- `no-intro`: wait until intro/transition/switch phases are finished

Important behavior:

- faint pages are prioritized if they are sitting behind a non-faint head entry
- non-faint messages can be diverted into `_pending_status_msgs` when battle faint handling is still active
- duplicate suppression is intentionally narrow so later turns can still show the same text again when appropriate

## Draw ownership rules

This is the seam that has been easy to break.

- Overworld and non-battle dialog use the standalone dialog box renderer.
- Battle uses the same dialog state for progression, but not the same box renderer.
- Battle message text belongs in `scripts/battle_ui/battle_ui.gml`, inside the command box and battle theme.
- `objects/oGame/Draw_64.gml` only calls `dialog2p_draw_gui_rect(...)` when that pid is not in battle.

If dialog appears in the wrong place, debug the draw owner first before editing queue logic.

## Split-screen behavior

Split-screen is active when more than one `oPlayer` instance exists.

- pid `0` dialog draws in the left GUI rect
- pid `1` dialog draws in the right GUI rect
- the dialog system itself remains per-pid; split-screen is mainly a draw-composition concern owned by `objects/oGame/Draw_64.gml`
- `objects/oGame/Step_1.gml` drains `dialog2p_step(0)` and `dialog2p_step(1)` when the per-pid arrays exist

This means you usually change split-screen dialog placement in the Draw GUI composition layer, not inside the core dialog queue code.

## Styling notes

The standalone dialog box now uses the updated pause-inspired palette for overworld use.

- text and border styling live in `scripts/DialogSystem/DialogSystem.gml`
- the next-page triangle accent remains red
- if you only want to change colors, stay in the dialog draw helpers and leave queue/update behavior alone

## Battle integration notes

- battle code can open or queue dialog through the shared `dialog2p_*` APIs
- battle still calls `dialog2p_update(pid)` while dialog is open so message progression matches battle state
- battle faint logic, trainer prompts, and status messages rely on queue gates and pending-message arrays
- standalone dialog drawing must stay suppressed during battle, otherwise the battle command UI and the separate box will both show

## Where To Edit

- Change queue semantics or duplicate suppression: `scripts/DialogSystem/DialogSystem.gml`
- Change battle-vs-overworld draw ownership: `objects/oGame/Draw_64.gml` and `scripts/battle_ui/battle_ui.gml`
- Change battle message text rendering: `scripts/battle_ui/battle_ui.gml`
- Change dialog callbacks or wait-for-close behavior: `dialog2p_wait_closed(...)` and the close path in `dialog2p_update(...)`
- Change overworld dialog colors or box layout: the draw helpers in `scripts/DialogSystem/DialogSystem.gml`

## Practical rules

- Do not use `dialog2p_draw_world(...)` from a Draw GUI event.
- Do not route battle messages through `dialog2p_draw_gui_rect(...)`.
- Keep queue logic in the dialog system and presentation logic in the draw owners.
- When debugging missing dialog, check in this order: queue state, `dialog2p_is_open(pid)`, per-frame `dialog2p_step/update` calls, then draw ownership.
