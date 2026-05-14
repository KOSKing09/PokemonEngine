# Battle System - Developer Guide

This document summarizes the battle system architecture, public APIs, phases, state shape, and extension points. It's written for engineers and AI agents to navigate and extend the system confidently.

For doubles/co-op ownership, actor layout, target-pick flow, and trainer doubles behavior, use `docs/battle_doubles.md` alongside this file.
For local-versus request flow and setup before the battle slot opens, use `docs/versus_system.md` alongside this file.
For overworld wild battle triggers and encounter-table handoff into `battle_open(...)`, use `docs/overworld_encounters.md`.

## Runtime contracts

- Call `battle_open(pid, wildLevel)` to create a battle slot.
- Each Step: `battle_update(pid)`.
- Draw GUI: `battle_draw_gui(pid)` or `battle_draw_gui_rect(pid, x, y, w, h)`.
- Close: `battle_close(pid)` is called automatically after fade when `_pending_close` is set, or manually when appropriate.
- If caught-mon nickname entry is active, battle close is held until `virtual_keyboard_blocks_input(pid)` clears.

## Phases

- `transition_in`: fade from black.
- `intro_enemy`: enemy slide-in and cry.
- `intro_call`: trainer slide/call, dialog pages.
- `intro_player`: player mon flashes, grows out of the ball, then leads to command.
- `command`: player input.
- `turn`: turn queue resolves.
- `switch_in`: swap animation with the same ball flash/grow send-out treatment; may consume turn.

## Battle slot `_B` (selected fields)

- `sys_open: bool`, `phase: string`, `phase_start_ms: int`, `phase_progress: real`, `phase_durs: struct`
- `actor: [playerActor, enemyActor]`
- `sys_ui: { menu, selX, selY, msg_list }`, `_ui` (letterbox metrics), `theme`
- Turn: `turn_queue: array`, `turn_i: int`, `turn_action_player`, `turn_action_enemy`
- Flags: `_dlg_active`, `_faint_pending`, `_pending_open_party`, `_pending_status_msgs`, `_pending_close`, `_closing`
- Intro hooks: `_intro_update_fn`, `_intro_draw_fn`

## Public API

- `battle_is_open(pid) -> bool`
- `battle_open(pid, wildLevel)`
- `battle_open(pid, wildLevel, areaTypeOrOpts, opts)` accepts either an area type, an opts struct, or both.
- `battle_update(pid)`
- `battle_draw_gui(pid)`
- `battle_draw_gui_rect(pid, rx, ry, rw, rh)`
- `battle_close(pid)`
- `battle_switch_to(pid, party_idx, opts)` where `opts = { consume_turn?: true, auto_apply?: true }`
- `battle_intro_set_handlers(pid, updateFn, drawFn)` registers intro extension hooks.
- `battle_open_trainer(pid, trainer_payload)` normalizes trainer data and forwards into `battle_open(...)`.

Related non-battle entrypoints that commonly feed this system:

- `multiplayer_request_versus_battle(pid)` and `multiplayer_start_versus_battle(pid, format_override)` for local-versus setup
- `overworld_encounter_step(inst)` for wild encounter volumes that eventually call `battle_open(...)`

## Key internal helpers

- `__battle_ensure_slot(pid)` creates or accesses `_B`.
- `__battle_process_input(pid)` owns command UI input.
- `__battle_build_turn_actions(pid)` constructs action order.
- `__battle_step_turn_if_ready(pid)` resolves queued actions.
- `__battle_can_hit_target(attacker, defender, move_id)` is the central hit gate for ordinary move accuracy.
- `__battle_move_accuracy(move_id)` resolves move base accuracy for the hit gate.
- `battle_command_helpers.gml` owns command queue, command actor, and target-pick helpers extracted from the main battle script.
- `battle_theme_helpers.gml` owns platform/theme resolution and battle UI text-color helpers.
- `__battle_enemy_choose_action(pid)` is the simple enemy AI seam.
- `__party_find_next_alive(pid)` returns a usable replacement index or `-1`.
- `__battle_hp_now(ent)` is the canonical HP lookup helper.
- `__battle_apply_entry_hazards(pid, index)` applies hazards on entry.
- `__battle_check_play_cries(pid)` owns cry playback triggers.
- `__battle_trainer_schedule_next_mon(pid, idx)` enqueues the next trainer Pokemon to send after a faint.
- `__battle_trainer_apply_pending_send(pid)` applies a queued trainer send-out once dialogs clear and hazards resolve.
- `__battle_trainer_handle_defeat(pid)` queues defeat dialog pages and triggers trainer payout.

## Extension points

- Intro animations: `battle_intro_set_handlers(pid, updateFn(pid, B), drawFn(pid, B))`.
- UI suppression windows: `_suppress_sys_ui_until`, `_suppress_wait_for_dialog_close`.
- Dialog integration via `dialog2p_open_text`, `dialog2p_is_open`, and `dialog2p_update`.
- Caught-mon naming integration via `virtual_keyboard_request_caught_nickname(...)` after catch storage succeeds.

## Adding code safely

- Add new battle-wide state where `_B` is created in `__battle_ensure_slot(pid)` so the default shape is explicit and static analysis keeps up.
- Add new opening-time options in `battle_open(...)`, then normalize or fan them out immediately into `_B` fields. Do not leave option parsing scattered later in the update flow.
- Put per-turn or per-action logic in the owning helper module when one already exists instead of growing `battle_system.gml` unless the logic truly owns the main phase machine.
- Keep `battle_update(pid)` as the orchestration layer: phase transitions, dialog and cutscene gates, queued sends, pending closes, and calls into narrower helpers.
- Keep `battle_draw_gui(pid)` and `battle_draw_gui_rect(...)` as the public draw API, but prefer editing `battle_draw.gml`, `battle_ui.gml`, or `battle_draw_helpers.gml` for presentation changes.

## Where to edit

- Opening a new battle type or new open option: `scripts/battle_system/battle_system.gml::battle_open(...)`
- Doubles/co-op actor routing, target helpers, and trainer doubles behavior: `docs/battle_doubles.md`
- Trainer-specific entrypoints and send-out or prompt flow: `scripts/battle_trainer/battle_trainer.gml`
- Command selection, target picking, and player input routing: `scripts/battle_command_helpers/` and `scripts/battle_system/battle_system.gml::__battle_process_input(...)`
- Turn construction and resolution order: `scripts/battle_system/battle_system.gml::__battle_build_turn_actions(...)` and `scripts/battle_system/battle_system.gml::__battle_step_turn_if_ready(...)`
- Shared move hit, status, and meta logic: `scripts/battle_actions/`, `scripts/battle_impls/`, and `scripts/battle_move_meta_helpers/`
- Battle presentation and command boxes: `scripts/battle_draw/`, `scripts/battle_ui/`, and `scripts/battle_draw_helpers/`
- Trainer battle payload shape and wrapper examples: `scripts/battle_trainer/battle_trainer.gml::battle_open_trainer(...)`

## Battle presentation notes

- Battler feet are grounded from the sprite's opaque bounding-box bottom, so small grounded Pokemon sit on the platform while floating Pokemon keep their float offset.
- Rendered battlers cache `_render_center_x`, `_render_center_y`, `_render_ground_y`, `_render_opaque_w`, and `_render_opaque_h` for hit effects, target selectors, and fallback sprites.
- Send-out animations for player, enemy, and trainer Pokemon share the same flash-then-grow presentation. Doubles intros segment the timing so paired Pokemon do not flash in at the same time.
- Catch attempts store the ball's platform contact point. During the shake phase the ball stays on that point and rocks left/right like Emerald; its shadow uses the same contact position.

## Minimal editing workflow

1. Start from the public seam that owns the behavior you want to change.
2. Confirm whether the battle script is orchestrating or deciding. If it only forwards, hop one helper deeper before editing.
3. Add or update focused smoke coverage in `scripts/test_trainer_battle_scenario/` when the change affects runtime behavior.
4. Run the relevant Igor smoke path, then restore any temporary `global.DEV_AUTO_*` flag changes.

## Accuracy and evasion

- Ordinary hit checks are centralized in `__battle_can_hit_target(attacker, defender, move_id)` inside `scripts/battle_system/battle_system.gml`.
- Stage-based miss logic uses the battler wrapper structs, not only inner `mon` payloads.
- Accuracy bypass cases are handled before the roll through `__battle_should_ignore_accuracy(...)`, so move-specific ignore-accuracy behavior stays in one seam.
- Battle-action callers such as `__battle_apply_move_damage(...)` route through this helper, so misses in the smoke harness exercise the same path as normal battle turns.
- Verified smoke coverage lives in `scripts/test_trainer_battle_scenario/test_trainer_battle_scenario.gml::test_battle_accuracy_smoke_start(...)` and covers both direct stage injection and move-applied `sand-attack` accuracy drops.

## Message ordering and close flow

- Status and defeat messages accumulate in `_pending_status_msgs`.
- On defeat, the system queues `You're out of usable Pokemon!` and then `<Trainer> has whited out!`; fade starts only after these are displayed.
- Fade overlay uses `_close_start_ms` and `_close_dur_ms`; close triggers when elapsed is greater than or equal to duration.

## Minimal usage example

```gml
// Boot
scr_controls();
party_init();
// Optionally configure pkicons asset bases
// pkicons_set_icon32_base("C:/art/icons/");
// pkicons_set_art96_base("C:/art/art96/");

// Create a wild battle
battle_open(0, 5);

// Step
controls_update();
battle_update(0);

// Draw GUI
battle_draw_gui(0);
```

## Notes

- The code defensively guards undefined symbols for portability between runtime editions.
- If you add new state in `_B`, update this doc and add a brief docblock where it's created.

## Battle dialog ownership

- Battle still uses the shared dialog state for message progression and gating.
- The standalone dialog box renderer is for overworld and non-battle presentation.
- In battle, message text belongs inside the battle command UI and battle theme.
- The main ownership seam is `scripts/battle_ui/battle_ui.gml`; do not route battle message presentation through `dialog2p_draw_gui_rect(...)`.
- `objects/oGame/Draw_64.gml` explicitly suppresses the standalone dialog draw when `battle_is_open(pid)` is true.

## Double battle foundation and co-op ownership

- The battle slot tracks `battle_type`, `battle_format`, `active_per_side`, `coop_enabled`, and `actor_owner_pid`.
- Singles still use the existing active layout: `actor[0] = player`, `actor[1] = enemy`.
- Doubles use the shared layout: `actor[0] = player slot 0`, `actor[1] = player slot 1`, `actor[2] = enemy slot 0`, `actor[3] = enemy slot 1`.
- `actor_owner_pid` records who owns each active slot so later command input can branch correctly for co-op battles.
- `battle_open(pid, level, opts)` accepts `battle_type`, `battle_format`, `coop_enabled`, and `player_pids` for co-op ownership routing.

Opening rules in the current foundation pass:

- Normal double wild: player 0 sends the first two usable party mons; enemy side spawns two wild mons; falls back to single if player 0 has fewer than two usable mons.
- Co-op double wild: actor 0 comes from player 0, actor 1 comes from player 1, enemy side spawns two wild mons; falls back to normal player-0 double if player 1 has no usable mon, otherwise single.
- Normal and co-op double trainer: enemy side reads the first two usable entries from the provided trainer party.

New helper functions available to format-aware battle code:

- `__battle_actor_side(actorIndex)`
- `__battle_actor_slot(actorIndex)`
- `__battle_is_ally_index(aIndex, bIndex)`
- `__battle_is_enemy_index(aIndex, bIndex)`
- `__battle_actor_index_alive(pid, actorIndex)`
- `__battle_get_default_target_index(pid, actorIndex)`
- `__battle_actor_owner_pid(pid, actorIndex)`
- `__battle_actor_control_pid(pid, actorIndex)`

Current command simplification for doubles:

- command entry is format-aware and respects controllable player-owned battlers
- target picking and switch flow use the doubles-aware helper paths
- some higher-level doubles UI polish is still evolving

Copyable open examples:

```gml
// Double wild battle
battle_open(0, 12, {
  battle_type: "wild",
  battle_format: "double"
});

// Co-op double wild battle
battle_open(0, 12, {
  battle_type: "wild",
  battle_format: "double",
  coop_enabled: true,
  player_pids: [0, 1]
});

// Double trainer battle
var trainer_party = [
  pokemon_factory_create(133, 12, {}),
  pokemon_factory_create(10, 12, {})
];
battle_open_trainer(0, {
  battle_type: "trainer",
  battle_format: "double",
  enemy_party: trainer_party,
  area_type: "forest"
});

// Co-op double trainer battle
battle_open_trainer(0, {
  battle_type: "trainer",
  battle_format: "double",
  coop_enabled: true,
  player_pids: [0, 1],
  enemy_party: trainer_party,
  area_type: "forest"
});
```

## Trainer battle entry points

- `battle_open_trainer(pid, trainer_payload)` is the convenience wrapper to open a trainer battle.

`trainer_payload` typically contains:

- `trainer_name` (string)
- `sprite` (trainer sprite resource) and `sprite_index` (int)
- `party` (array of mon structs, preferably created via `pokemon_factory_create`)
- `area_type` (optional string)
- `trainer_reward` (optional numeric reward or money to grant on defeat)

- `__battle_trainer_schedule_next_mon(pid, idx)` is called when an enemy mon faints to enqueue the next alive party member for send-out.
- `__battle_trainer_apply_pending_send(pid)` should be invoked from `battle_update()` when dialog gates clear and the pending send's `ready_ms` has passed.
- `__battle_trainer_handle_defeat(pid)` awards the trainer payout and enqueues defeat or reward dialog lines.

## Trainer about-to-send prompt

- Trainer battles pause after an enemy trainer Pokemon faints when another usable trainer mon remains.
- The battle slot stores `_trainer_switch_prompt` with the pending enemy index and name, current yes or no selection, optional player switch target, and a small internal phase string.

Flow:

- enemy trainer mon faints -> `_trainer_switch_prompt.phase = "prompt"`
- `No` or `Back` -> existing `__battle_trainer_schedule_next_mon` and `__battle_trainer_apply_pending_send` flow runs unchanged
- `Yes` -> party opens in a temporary pick mode that only accepts valid non-fainted, non-active mons
- canceling that party pick mode is treated the same as `No`
- trainer send-out resolves first, then any stored player switch runs through `battle_switch_to(..., { consume_turn:false, forced:true })`

Wild battle faint flow and trainer defeat flow stay unchanged.

Implementation tips:

- Place `__battle_trainer_apply_pending_send(pid)` calls inside safe phase boundaries so sends do not interrupt animations or active turns.
- Use the existing `__battle_actor_from_party_mon(mon)` and `__battle_apply_party_moves(actor)` helpers rather than duplicating actor initialization logic.
- Guard against double-sends by checking and clearing `_trainer_pending_send` once applied.

Example trainer payload used in tests:

```gml
var trainer_party = [
  pokemon_factory_create(133, 5, {}),
  pokemon_factory_create(10, 5, {}),
  pokemon_factory_create(252, 5, {})
];
var trainer_payload = {
  trainer_name: "Bug Catcher Rick",
  sprite: spr_PokemonEmeraldTrainers,
  sprite_index: 12,
  party: trainer_party,
  area_type: "forest",
  trainer_reward: 50
};
battle_open_trainer(0, trainer_payload);
```
