# Versus System

This guide covers the local multiplayer versus request flow, the current runtime state shape, and the seams to use when changing battle acceptance, format selection, or split-screen ownership.

## Ownership

The request and setup logic lives in `scripts/player_helper_scripts/player_helper_scripts.gml`.

The resulting battle still runs through the normal battle system in `scripts/battle_system/battle_system.gml`, with presentation and command routing spread across the existing battle helper modules.

Use this guide together with `docs/battle_system.md` and `docs/battle_doubles.md`.

## Runtime state

The multiplayer singleton is created by `multiplayer_ensure_state()` and stored in `global.MULTIPLAYER`.

Relevant fields for versus flow:

- `player_count`
- `queue_mode`: `solo` or `coop`
- `request_pid`: which pid is used as the co-op encounter trigger owner
- `versus_format`: `single` or `double`
- `versus_request`: current pending request state

`versus_request` currently contains:

- `active`
- `requester_pid`
- `responder_pid`
- `prompt_shown`
- `prompt_closed_ms`
- `response`
- `battle_format`

## Public helpers

Format and option helpers:

- `multiplayer_queue_mode()`
- `multiplayer_set_queue_mode(mode)`
- `multiplayer_toggle_queue_mode()`
- `multiplayer_request_pid()`
- `multiplayer_set_request_pid(pid)`
- `multiplayer_toggle_request_pid()`
- `multiplayer_versus_format()`
- `multiplayer_set_versus_format(format)`
- `multiplayer_toggle_versus_format()`

Player/runtime helpers:

- `multiplayer_player_joined(pid)`
- `multiplayer_sync_runtime()`
- `multiplayer_spawn_player(pid)`
- `multiplayer_drop_player(pid)`
- `multiplayer_seed_party_if_missing(pid, count)`

Versus-specific helpers:

- `multiplayer_clear_versus_request()`
- `multiplayer_battle_open()`
- `multiplayer_request_versus_battle(pid)`
- `multiplayer_update_versus_request(pid)`
- `multiplayer_start_versus_battle(pid, format_override)`

## Flow overview

The current versus flow is request-driven.

1. A player sends a request with `multiplayer_request_versus_battle(pid)`.
2. The code latches the chosen format from `multiplayer_versus_format()` into `global.MULTIPLAYER.versus_request.battle_format`.
3. The requester and responder party counts are validated before the request is accepted.
4. The responder sees a dialog prompt.
5. The responder presses `Interact` to accept or `Back` to decline.
6. `multiplayer_update_versus_request(pid)` closes the prompt, waits a short debounce window, then either starts or clears the request.
7. On accept, `multiplayer_start_versus_battle(...)` opens a trainer-style battle slot and marks it as versus-enabled.
8. On decline, both players receive the appropriate dialog and the request state is cleared.

## Request behavior

`multiplayer_request_versus_battle(pid)` is the safe entrypoint.

It refuses to create a request when:

- the responder is not present
- a battle is already open
- another versus request is already active
- the requester lacks enough usable mons for the selected format
- the responder lacks enough usable mons for the selected format

The selected format is derived from `multiplayer_versus_format()`:

- `single` requires one usable mon per side
- `double` requires two usable mons per side

The request is stored before any acceptance prompt is shown, so both sides share one authoritative request payload.

## Accept and decline behavior

`multiplayer_update_versus_request(pid)` should be called from the normal multiplayer/world update path for each pid.

The responder flow is:

- first update shows the request dialog
- while the dialog is open, `Interact` writes `response = "accept"`
- while the dialog is open, `Back` writes `response = "decline"`
- after the dialog closes, the code waits until `current_time` passes `prompt_closed_ms`
- then it either starts the battle or clears the request and sends decline feedback

Current decline message behavior:

- requester gets `PLAYER X has declined to battle in a SINGLE/DOUBLE battle.`
- responder gets `SINGLE/DOUBLE battle request declined.`

## How versus battles are opened

`multiplayer_start_versus_battle(pid, format_override)` currently uses `battle_open_trainer(...)` with player 2's party passed in as `enemy_party`.

After opening, the code marks the battle slot with versus-specific fields:

- `versus_enabled = true`
- `_versus_trainer_names = [player2Name, player1Name]`
- `player_pids = [0, 1]`
- `coop_enabled = false`
- `actor_owner_pid`

`actor_owner_pid` depends on format:

- single: `[0, 1, -1, -1]`
- double: `[0, 0, 1, 1]`

Then `__battle_bind_shared_slot_aliases(_B, 0)` binds the shared slot so both pids reference the same battle state.

## Battle-side expectations

Once `versus_enabled` is set, battle code must respect per-player versus UI state rather than assuming one shared local player.

Important battle-side seams:

- `scripts/battle_ui/battle_ui.gml`: command boxes, wait text, dialog ownership, target prompts
- `scripts/battle_draw_helpers/battle_draw_helpers.gml`: target selectors and doubles placement
- `scripts/battle_system/battle_system.gml`: command phase resets, command actor routing, shared-slot state, and close/open lifecycle
- `docs/battle_doubles.md`: doubles ownership and actor layout details

## Adding a new versus entrypoint

If you need a new menu action or object interaction to start versus, do not call `multiplayer_start_versus_battle(...)` directly unless you explicitly want to skip acceptance.

Preferred pattern:

```gml
multiplayer_set_versus_format("double");
multiplayer_request_versus_battle(0);
```

That preserves:

- joined-player checks
- party-count validation
- active-request locking
- decline handling
- shared dialog text

## Changing the default format

Use:

```gml
multiplayer_set_versus_format("single");
multiplayer_set_versus_format("double");
```

The value is persisted to `options.ini` by `multiplayer_save_options()` under the `Multiplayer` section.

## Debug checklist

Use this list when versus behaves incorrectly:

1. Confirm both players exist with `multiplayer_player_joined(0)` and `multiplayer_player_joined(1)`.
2. Confirm both sides have enough non-fainted mons for the selected format.
3. Confirm no old battle slot is still open through `multiplayer_battle_open()`.
4. Confirm `multiplayer_update_versus_request(pid)` is still being called for the responder pid.
5. If the battle opens but UI ownership is wrong, inspect the `versus_enabled`, `player_pids`, and `actor_owner_pid` fields on the battle slot.
6. If doubles selectors or command resets are wrong, continue in `docs/battle_doubles.md` and the owning battle helper modules.

## Minimal examples

Single versus request:

```gml
multiplayer_set_versus_format("single");
multiplayer_request_versus_battle(0);
```

Double versus request:

```gml
multiplayer_set_versus_format("double");
multiplayer_request_versus_battle(1);
```

Immediate versus battle open, bypassing accept flow:

```gml
multiplayer_start_versus_battle(0, "single");
```

Use the direct start helper sparingly. It is best suited for tests or controlled debug scenarios.
