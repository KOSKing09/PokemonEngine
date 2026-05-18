# Runtime Systems

This guide covers the core runtime systems that sit underneath battle, party, bag, and overworld feature code.

## Boot ownership

The runtime boot path still starts in `objects/oGame/Create_0.gml`.

- Fonts and GUI size are initialized first.
- Data tables and indexes are loaded before gameplay systems use them.
- `transition_init()` sets the room and battle transition defaults.
- `world_init()` creates the lightweight world registry.
- Boot then seeds `global._REGIONMUSIC`, registers the current room with `world_room_register(room, room_get_name(room), global._REGIONMUSIC, false)`, and starts room audio through `world_play_music(global._REGIONMUSIC)`.
- `party_init()`, `bags_init(2)`, `poke_index_init(2)`, `scr_controls()`, `pause_init()`, `dialog2p_init()`, `evolution_init()`, `virtual_keyboard_init()`, `currency_init()`, and `pc_init()` are expected to be available before the first full gameplay Step.

The frame loop then depends on:

- `objects/oGame/Step_1.gml` calling `controls_update()` before any system reads input.
- Per-pid GUI composition in `objects/oGame/Draw_64.gml`.
- `objects/oGame/Other_4.gml` binding tile collision layers, registering `oNpc` as a solid object through `wc_set_solids([oNpc])`, and calling `world_room_apply()` when a room becomes active.

## Controls

Owner: `scripts/scr_controls/scr_controls.gml`

Main contract:

- Call `scr_controls()` once at boot.
- Call `controls_update()` every Step before reading `controls_pressed`, `controls_down`, `controls_released`, or `controls_axes`.
- Bindings live in `global.CTRL` and are persisted to `options.ini` through `controls_load()` and `controls_save()`.

Behavior notes:

- The system supports two logical players by default through `CTRL.max_players = 2`.
- `CTRL.pad_index = [0, 1]` maps pids to physical pads.
- Keyboard and pad input are merged into action booleans like `Interact`, `Inventory`, `Run`, `Back`, `PageUp`, `PageDown`, and `Pause`.
- Left-stick and d-pad state are folded into `axis_x`, `axis_y`, and the synthetic move booleans.
- Deadzone is stored in `options.ini` under `[Input] deadzone`.
- Split-screen layout is also persisted through the controls save path under `[Display] splitscreen_layout`.

Use this system first when input appears inconsistent. If `controls_update()` is skipped, every higher-level UI will read stale state.

## Grid And Collision

Owners:

- `scripts/grid_system/grid_system.gml`
- `scripts/collision_system/collision_system.gml`

Collision contract:

- `WC` is the shared collision singleton.
- `wc_reset()` clears collision bindings.
- `wc_bind_layers(layer_names)` binds collision tilemap layers.
- `wc_set_solids(object_array)` registers blocking objects.
- `wc_collides_at(inst, px, py)` checks a moved bbox against both tile and object collisions.

Grid contract:

- `grid_init(inst, tile_size, walk_px_per_frame, run_px_per_frame)` creates per-instance movement state.
- `grid_snap_to_tile(inst)` realigns the actor to the logical tile grid.
- `grid_set_block_checker(inst, fn)` exists as an extension seam, but the current flow still routes through `wc_collides_at`.
- `grid_step(inst, pid)` reads `controls_*` and advances buffered 4-way tile movement.

Behavior notes:

- The movement system keeps a short buffered direction window through `buffer_dir` and `buffer_ttl`.
- `Run` switches from `walk_speed` to `run_speed`.
- If a move becomes blocked mid-step, the actor snaps back to the nearest tile and returns to `idle`.
- Room start currently binds `oNpc` as a blocking world solid, so standard NPCs and Nurse Joy stop player movement through the normal collision path rather than only through interaction logic.

If world movement feels sticky or actors clip into walls, inspect collision bindings before changing player code.

## Split-Screen And Camera Helpers

Owner: `scripts/camera_system/camera_system.gml`

This script currently owns layout and shake helpers more than a full camera state machine.

Main APIs:

- `splitscreen_get_layout()` returns `vertical` or `horizontal`.
- `splitscreen_set_layout(layout)` persists the chosen layout through `controls_save()`.
- `splitscreen_toggle_layout()` flips between the two supported layouts.
- `splitscreen_apply_gui_size()` resizes the GUI surface based on player count and shared-battle state.
- `splitscreen_get_gui_rect(pid)` returns the logical `240x160` rect a subsystem should draw into.
- `battle_uses_shared_screen(pid)` and `splitscreen_should_use_shared_screen()` force a single combined layout for co-op doubles.

Shake helpers:

- `cam_shake_create()` builds a shake state struct.
- `cam_shake_start(...)` arms the shake.
- `cam_shake_update(shake)` returns `{ x, y }` offsets each frame.

Most GUI ownership decisions still happen in `objects/oGame/Draw_64.gml`, but the rect math belongs here.

Room-change camera notes:

- `objects/oCamera/Create_0.gml` stores `bound_room = room` on the persistent camera instance.
- `objects/oCamera/Step_0.gml` refreshes `target1` and `target2` from `player_by_pid(...)` every frame.
- When `bound_room` changes, the camera clears its cached `split_layout` so the room's ports and application-surface sizing are re-applied immediately.

## Pause

Owner: `scripts/pause_system/pause_system.gml`

Main contract:

- Call `pause_init()` at boot.
- Call `pause_update()` each Step.
- Draw through the pause draw helpers already used by the GUI composition layer.

State shape:

- `global.PAUSE[pid]` stores per-player pause state.
- `global.PAUSE_OWNER` exists for legacy ownership checks.

Modes currently routed through the pause system:

- `main`
- `options`
- `input`
- `battle_settings`
- `multiplayer`
- `misc`

Main menu responsibilities:

- opens party, bag, poke index, options, save, and misc actions
- changes dialog speed and split-screen layout
- changes Battle Settings, including XP mode and the lead-Pokemon follower toggle
- drives local multiplayer options like queue mode, requested pid, and versus format
- opens the PC from the `misc` page through `pc_open(pid)`

Gate behavior:

- Pause does not update a pid while that pid already has the PC open.
- Pause input also yields while dialog is open.
- `world_is_paused_both()` is the shared-world check for both players pausing at once.

## Cutscenes

Owner: `scripts/CutsceneSystem/CutsceneSystem.gml`

This is a lightweight queued dispatcher with optional shared-player locks.

Main contract:

- Call `cutscene_init()` before first use.
- Queue work with `cutscene_enqueue(pid, payload)` or `cutscene_play_now(pid, payload)`.
- Advance queued work with `cutscene_step(pid)` and active work with `cutscene_update(pid)`.
- Query lock state with `cutscene_blocks_player(pid)` or `cutscene_is_playing(pid)`.

Recommended payload shape:

- `key`
- `gate`
- `duration_ms`
- `on_start(pid, item)`
- `on_update(pid, item, elapsed_ms)`
- `on_complete(pid, item)`

Built-in behavior:

- If `on_update` is missing but `duration_ms` exists, the item auto-completes on time.
- If both are missing, the item completes immediately.
- `gate = "no-intro"` blocks playback during early battle intro phases.
- `cutscene_wait_finished(pid, callback)` is the safe hook for chaining later work.

The same file also includes overworld-oriented helpers for dialog, moving NPCs, moving players, and shared player locks.

## Room Transitions

Owner: `scripts/transition_system/transition_system.gml`

Main contract:

- Call `transition_init()` at boot.
- Configure defaults with `transition_set_battle_style(...)` and `transition_set_room_style(...)`.
- Trigger room changes through `transition_room_goto(room_id, style, duration_ms)`.
- Trigger overworld warps through `world_warp_to_transition(room_id, spawn_x, spawn_y, opts, style, duration_ms)` when the warp should explicitly choose a transition.
- Advance transitions with `transition_update()`.
- Draw them in GUI space with `transition_draw_gui()` or `transition_draw_gui_rect(...)`.

Important globals:

- `global.TRANSITION_SYS`
- `global.TRANSITION_BATTLE_STYLE`
- `global.TRANSITION_ROOM_STYLE`
- `global.TRANSITION_BATTLE_DURATION_MS`
- `global.TRANSITION_ROOM_DURATION_MS`

Supported styles include:

- `none`
- `emerald_fade_black`
- `emerald_fade_white`
- `emerald_blinds`
- `emerald_vertical_blinds`
- `emerald_checker`
- `emerald_diamond`
- `emerald_spotlight`
- `emerald_split_horizontal`
- `emerald_split_vertical`
- `emerald_diagonal`
- `emerald_wave`
- `emerald_zigzag`
- `emerald_spiral`
- `emerald_pokeball`

Normalization aliases also exist:

- `fade` and `black` normalize to `emerald_fade_black`
- `white` and `flash` normalize to `emerald_fade_white`
- `horizontal_blinds` and `blinds` normalize to `emerald_blinds`
- `vertical_blinds` normalizes to `emerald_vertical_blinds`
- `checkerboard` normalizes to `emerald_checker`
- `diamond_iris` normalizes to `emerald_diamond`
- `circle` and `circle_iris` normalize to `emerald_spotlight`
- `pokeball` and `poke_ball` normalize to `emerald_pokeball`

This system only blocks room transitions directly. Battle intro rendering can still use `transition_draw_battle_cover(...)` without reusing the room-goto flow.

Where to change transitions:

- Default battle intro transition: `objects/oGame/Create_0.gml`, `transition_set_battle_style("emerald_blinds")`.
- Default room transition: `objects/oGame/Create_0.gml`, `transition_set_room_style("emerald_fade_black")`.
- Per-warp transition: pass `transition_style` and `transition_duration_ms` in the `opts` struct to `world_warp_to(...)`, or call `world_warp_to_transition(...)` directly.
- Battle close transition after a full-party loss: `scripts/battle_system/battle_system.gml`, `__battle_close_transition_style(...)`. Losses return `emerald_fade_white` for whiteout; non-loss endings return the normal black fade.
- Battle close transition drawing: `scripts/battle_system/battle_system.gml`, the `_closing` overlay block in `battle_update(...)`.

## World Runtime

Owner: `scripts/player_helper_scripts/player_helper_scripts.gml`

The same script that owns multiplayer and overworld helpers also owns a small room-runtime registry.

Main APIs:

- `world_init()` ensures `global.WORLD`
- `world_room_register(room_id, display_name, music, indoor)` registers room metadata
- `world_play_music(sound, loop)` plays background world music immediately
- `world_set_room_music(room_id, music)` changes the registered room music without rebuilding the rest of the room metadata
- `world_stop_room_music()` stops the currently tracked world-music playback handle
- `world_apply_room_music(room_id, override_music, override_set)` resolves the room's registered music or a warp override and applies silence when requested
- `world_room_apply()` applies pending warp placement, room music, and optional route-bar display when the room becomes active
- `world_warp_to(room_id, spawn_x, spawn_y, opts)` schedules a warp and then calls `transition_room_goto(...)` when available
- `world_warp_to_transition(room_id, spawn_x, spawn_y, opts, style, duration_ms)` does the same but lets the caller explicitly choose the transition style and timing
- `world_warp_player_if_in_rect(...)` is the common trigger helper for map rectangles
- `world_draw_route_bar()` draws the route name banner in GUI space
- `pokemon_followers_update_all()` keeps optional lead-Pokemon followers synced to each joined player
- `pokemon_followers_clear_all()` removes active followers when the Battle Settings follower option is disabled

State shape:

- `current_room`
- `previous_room`
- `current_music`: currently playing world-music handle
- `current_music_asset`: sound resource reference currently assigned to world music
- `room_info`
- `pending_warp`
- `route_bar`

Music and warp notes:

- Room metadata can store a normal sound resource or `-1` for explicit silence.
- `world_play_music(...)` and `world_apply_room_music(...)` accept normal GameMaker sound resource refs, not only numeric asset ids.
- Warp callers can override destination music by passing `room_music` in the warp opts struct.
- Passing `room_music = -1` makes the destination room silent even if `_REGIONMUSIC` exists.
- `objects/owarp/Step_0.gml` uses `world_warp_player_if_in_rect(...)` as the canonical map-trigger seam and forwards `transition_style` plus optional `room_music` overrides.
- `owarp` has `warp_kind` for default warp audio:
  - `warp_kind = "exit"` plays `snd_Warp_Exit`.
  - `warp_kind = "door"` plays `snd_Warp_Door`.
  - `warp_kind = "ladder"` plays `snd_Warp_Ladder`.
- `owarp.warp_sound` defaults to `-1`. Leave it at `-1` to use `warp_kind`, or set it to a sound resource for a one-off override.

This runtime is the seam between room entry, music restoration, route naming, warp placement, and world-audio state. If a room change behaves incorrectly, check `world_room_apply()` before changing player or NPC code.

Follower behavior:

- The follower option persists under `[Battle] follower_enabled` in `options.ini`.
- The follower is an `oNpc` instance marked with `follower_pokemon = true`, so it uses the same NPC step and interaction entry points.
- The follower tracks party slot 0 for each active pid. In splitscreen, player 2 gets their own follower only after they have joined.
- The follower only advances when the player actually changes grid position, so turning in place to face the follower does not make it jump around to the other side.
- Talking to the follower plays its cry when available and shows an Emerald-style name line, e.g. `TREECKO: TREECKO!`.

## Pokemon Center Nurse

Owner: `scripts/player_helper_scripts/player_helper_scripts.gml`

Nurse Joy is implemented as an `oNpc` specialization so Pokemon Centers can use the same interaction system as ordinary overworld NPCs.

Main APIs:

- `pokemon_center_nurse_start(npc, pid)` starts the Pokemon Center interaction.
- `pokemon_center_update(pid)` advances the prompt, yes/no choice, tray animation, party heal, and final dialog.
- `pokemon_center_draw_yesno_rect(pid, rx, ry, rw, rh)` draws the Emerald-style yes/no box after the prompt dialog closes.
- `pokemon_center_heal_party(pid)` heals the selected player's party.
- `pokemon_center_active_for_pid(pid)` reports whether a Pokemon Center flow is currently locking that player.

Setup example:

```gml
// Put this on an oNpc instance in the Pokemon Center room.
pokemon_center_nurse = true;
// Optional: custom radius or sprite overrides.
// Default init expands the interact radius to at least 40 pixels
// and auto-populates the Nurse Joy directional sprites when present.
```

Also place one `opokeballtray` instance near Nurse Joy. Its sprite is `spokeball_tray`; frame `0` is the empty tray and frames `1` through `6` show the party ball count. The tray defaults back to `image_index = 0` in its Create/Step events.

Flow:

- Nurse Joy opens with: `Hello, and welcome to the Pokemon Center. Would you like to rest your Pokemon?`
- After that dialog closes, the yes/no UI appears.
- `YES` shows `Okay, I'll take your Pokemon for a few seconds.`, counts the tray up to the current party size, heals the party, resets the tray to `0`, then Nurse Joy bows and says the end message.
- `NO` skips healing/tray animation and immediately shows the exit line: `We hope to see you again!`
- The nurse interaction keeps the player locked through the shared overworld lock seam while the prompt, yes/no UI, heal animation, or final dialog is active.
- The default nurse radius is intentionally large enough to support counter interactions without walking behind the desk.

Required draw/update hooks already live in `objects/oGame/Step_1.gml` and `objects/oGame/Draw_64.gml`. If the yes/no box does not appear, confirm those hooks are still calling `pokemon_center_update(...)` and `pokemon_center_draw_yesno_rect(...)`.
