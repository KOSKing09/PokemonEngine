# Battle System — Developer Guide

This document summarizes the battle system architecture, public APIs, phases, state shape, and extension points. It’s written for engineers and AI agents to navigate and extend the system confidently.

## Runtime contracts
- Call `battle_open(pid, wildLevel)` to create a battle slot.
- Each Step: `battle_update(pid)`.
- Draw GUI: `battle_draw_gui(pid)` (or `battle_draw_gui_rect(pid, x,y,w,h)`).
- Close: `battle_close(pid)` is called automatically after fade when `_pending_close` is set, or manually when appropriate.

## Phases
- `transition_in`: fade from black.
- `intro_enemy`: enemy slide-in and cry.
- `intro_call`: trainer slide/call, dialog pages.
- `intro_player`: player mon scales in; leads to command.
- `command`: player input.
- `turn`: turn queue resolves.
- `switch_in`: swap animation; may consume turn.

## Battle slot `_B` (selected fields)
- `sys_open: bool`, `phase: string`, `phase_start_ms: int`, `phase_progress: real`, `phase_durs: struct`
- `actor: [playerActor, enemyActor]`
- `sys_ui: { menu, selX, selY, msg_list }`, `_ui` (letterbox metrics), `theme`
- Turn: `turn_queue: array`, `turn_i: int`, `turn_action_player`, `turn_action_enemy`
- Flags: `_dlg_active`, `_faint_pending`, `_pending_open_party`, `_pending_status_msgs`, `_pending_close`, `_closing`
- Intro hooks: `_intro_update_fn`, `_intro_draw_fn`

## Public API (documented)
- `battle_is_open(pid) -> bool`
- `battle_open(pid, wildLevel)`
- `battle_update(pid)`
- `battle_draw_gui(pid)`
- `battle_draw_gui_rect(pid, rx,ry,rw,rh)`
- `battle_close(pid)`
- `battle_switch_to(pid, party_idx, opts)` where `opts = { consume_turn?: true, auto_apply?: true }`
- `battle_intro_set_handlers(pid, updateFn, drawFn)` — extension hook registration

## Key internal helpers
- `__battle_ensure_slot(pid)` — create/access `_B`.
- `__battle_process_input(pid)` — command UI input.
- `__battle_build_turn_actions(pid)` — construct action order.
- `__battle_step_turn_if_ready(pid)` — resolve queued actions.
- `__battle_enemy_choose_action(pid)` — simple enemy AI.
- `__party_find_next_alive(pid)` — usable replacement index or -1.
- `__battle_hp_now(ent)` — canonical HP lookup.
- `__battle_apply_entry_hazards(pid, index)` — hazards on entry.
- `__battle_check_play_cries(pid)` — cry playback triggers.
- `__battle_trainer_schedule_next_mon(pid, idx)` — enqueue the next trainer Pokémon to send out after a faint.
- `__battle_trainer_apply_pending_send(pid)` — apply a queued trainer send-out once dialogs clear and hazards resolve.
- `__battle_trainer_handle_defeat(pid)` — queue defeat dialog pages and trigger the trainer payout via the currency system.

## Extension points
- Intro animations: `battle_intro_set_handlers(pid, updateFn(pid,B), drawFn(pid,B))`.
- UI suppression windows: `_suppress_sys_ui_until`, `_suppress_wait_for_dialog_close`.
- Dialog integration via `dialog2p_open_text`, `dialog2p_is_open`, `dialog2p_update`.

## Message ordering and close flow
- Status/defeat messages accumulate in `_pending_status_msgs`.
- On defeat: queue `"You’re out of usable Pokémon!"` then `"<Trainer> has whited out!"`; start fade only after these are displayed.
- Fade overlay uses `_close_start_ms`/`_close_dur_ms`; close triggers when elapsed >= duration.

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
- If you add new state in `_B`, update this doc and add a brief docblock where it’s created.

## Trainer Battle — Entry Points (quick reference)

- `battle_open_trainer(pid, trainer_payload)` — convenience wrapper to open a trainer battle. `trainer_payload` typically contains:
	- `trainer_name` (string)
	- `sprite` (trainer sprite resource) and `sprite_index` (int)
	- `party` (array of mon structs, preferably created via `pokemon_factory_create`)
	- `area_type` (optional string)
	- `trainer_reward` (optional numeric reward/money to grant on defeat)

- `__battle_trainer_schedule_next_mon(pid, idx)` — called when an enemy mon faints to enqueue the next alive party member for sending-out. It writes a `_trainer_pending_send` struct on the battle slot with `idx`, `ready_ms`, and `message`.

- `__battle_trainer_apply_pending_send(pid)` — should be invoked from `battle_update()` when dialog gates clear and the pending send's `ready_ms` has passed; it displays the "sent out" dialog then replaces the enemy actor with the new mon and applies entry hazards.

- `__battle_trainer_handle_defeat(pid)` — awards the trainer payout (uses `currency_add` if present or `global.PLAYER_MONEY`) and enqueues defeat/reward dialog lines to `_pending_status_msgs`.

Implementation tips:
- Place `__battle_trainer_apply_pending_send(pid)` calls inside safe phase boundaries (e.g., at the start of `battle_update()` when `phase` moves back to `command`) so sends don't interrupt animations or active turns.
- Use the existing `__battle_actor_from_party_mon(mon)` and `__battle_apply_party_moves(actor)` helpers rather than duplicating actor initialization logic.
- Guard against double-sends by checking and clearing `_trainer_pending_send` once applied.

Example trainer payload (used in tests):
```gml
var trainer_party = [ pokemon_factory_create(133,5,{}), pokemon_factory_create(10,5,{}), pokemon_factory_create(252,5,{}) ];
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
