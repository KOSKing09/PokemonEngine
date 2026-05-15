# Double Battles And Co-op

This guide documents the doubles and co-op battle foundation.

Use it when you need to change how double battles open, how active battlers are laid out, how command ownership works, how targets are chosen, or how trainer send-outs behave when there are two active enemies.

## Scope

The doubles path is not a separate battle engine. It is a format layer inside the normal battle system.

The same public entrypoints are used:

- `battle_open(pid, level, opts)`
- `battle_open_trainer(pid, trainer_payload)`
- `battle_update(pid)`
- `battle_draw_gui(pid)`

The important difference is that `battle_format`, `active_per_side`, `coop_enabled`, and actor ownership fields change how the existing engine routes control.

Split-screen is a separate presentation concern. It is driven by GUI composition in `objects/oGame/Draw_64.gml`, not by the doubles battle slot itself.

## Core slot structure

Doubles are stored on the normal battle slot `_B` created by `__battle_ensure_slot(pid)` in `scripts/battle_system/battle_system.gml`.

Important doubles-owned fields:

- `battle_format`: `"single"` or `"double"`
- `active_per_side`: `1` or `2`
- `coop_enabled`: whether player-side active slots are owned by separate player ids
- `player_pids`: `[pid0, pid1]` used for co-op ownership routing
- `actor_owner_pid`: owner id for each active actor slot
- `actor`: active battler array
- `_command_actor_index`: current player-controlled actor being entered in the command UI
- `_player_turn_actions`: queued player actions before the turn begins
- `_command_pending_action`: partially built action waiting for target selection
- `_target_pick_targets`: currently valid target actor indexes
- `_target_pick_index`: highlighted target entry in target-pick mode
- `_trainer_party_active_indices`: trainer-party indexes currently occupying enemy actor slots in double trainer battles

## Actor layout

Singles and doubles use different actor layouts.

Single battle layout:

- `actor[0]`: player active battler
- `actor[1]`: enemy active battler

Double battle layout:

- `actor[0]`: player-side slot 0
- `actor[1]`: player-side slot 1
- `actor[2]`: enemy-side slot 0
- `actor[3]`: enemy-side slot 1

The shared helper functions that understand this layout live in `scripts/battle_system/battle_system.gml`:

- `__battle_actor_side(actorIndex)`
- `__battle_actor_slot(actorIndex)`
- `__battle_actor_index_for_side_slot(pid, side, slot)`
- `__battle_get_side_actor(pid, side, slot)`
- `__battle_actor_index_alive(pid, actorIndex)`
- `__battle_get_default_target_index(pid, actorIndex)`
- `__battle_actor_owner_pid(pid, actorIndex)`
- `__battle_actor_control_pid(pid, actorIndex)`

When adding new logic, do not hard-code `0 = player, 1 = enemy` unless the code is truly single-battle-only.

## Ownership and co-op routing

The player-side ownership model is stored in `actor_owner_pid`.

Common shapes:

- single wild or trainer battle: `[player0, -1, -1, -1]`
- normal double battle: `[player0, player0, -1, -1]`
- co-op double battle: `[player0, player1, -1, -1]`

`player_pids` stores the same player ids at the battle level so the opening flow can build the correct lead actors and so later systems can resolve the owning party.

The command system uses `__battle_actor_control_pid(pid, actorIndex)` to decide which active battlers should be commandable from the current player's input loop.

## Opening flow

The doubles foundation is negotiated in `battle_open(...)` in `scripts/battle_system/battle_system.gml`.

Open-time options:

- `battle_type: "wild" | "trainer"`
- `battle_format: "single" | "double"`
- `coop_enabled: true | false`
- `player_pids: [pid0, pid1]`

Open-time flow:

1. normalize `battle_type`, `battle_format`, `coop_enabled`, and `player_pids`
2. collect opening party candidates for player 0 and optional player 1
3. decide whether the requested double battle is actually usable
4. fall back to single if the party or trainer setup cannot sustain doubles
5. build the active actor array in the shared doubles layout
6. store owner routing in `actor_owner_pid`

Current fallback rules:

- normal double falls back to single if player 0 has fewer than two usable mons
- co-op double falls back to normal player-0 double if player 1 has no usable mon
- if that fallback still cannot form two player-side actives, the battle falls back to single
- double trainer battles fall back to single if the trainer payload cannot supply two usable enemy mons

## Wild versus trainer doubles

Wild doubles are opened directly inside `battle_open(...)`.

- wild double enemy actors are built with `__battle_opening_actor_from_wild(2, level)` and `__battle_opening_actor_from_wild(3, level)`
- the default enemy actor is `actor[2]`

Trainer doubles are still opened through `battle_open_trainer(...)`, but the real doubles actor setup is applied inside `battle_open(...)` after the trainer payload has been normalized.

Trainer-specific doubles state:

- `_trainer_party`: normalized trainer party array
- `_trainer_party_active_indices`: which trainer-party entries currently occupy `actor[2]` and `actor[3]`
- `_trainer_party_active_idx`: legacy single-battle active index fallback

Trainer helper seams:

- `__battle_trainer_active_party_index_for_actor(_B, actorIndex)`
- `__battle_trainer_next_alive_index_excluding(_B, excludeIndices, fromIdx)`
- `__battle_trainer_next_alive_index(_B, fromIdx)`

If you change double-trainer send-out behavior, start in `scripts/battle_trainer/battle_trainer.gml`, not only in the generic battle script.

## Command system in doubles

The doubles command flow is owned by `scripts/battle_command_helpers/battle_command_helpers.gml`.

Core helpers:

- `__battle_command_actor_indexes(pid)` returns the currently commandable player-side actor indexes
- `__battle_find_player_turn_action(_B, actorIndex)` finds a queued action for a specific active battler
- `__battle_store_player_turn_action(_B, action)` stores or replaces the current action for that battler
- `__battle_next_command_actor_index(pid, afterActorIndex)` advances command entry to the next controllable battler
- `__battle_previous_command_actor_index(pid, beforeActorIndex)` moves backward through already-entered actions
- `__battle_all_command_actions_ready(pid)` tells the battle loop when it can build the turn queue
- `__battle_commit_player_action(pid, action)` finalizes one battler's action and advances to the next battler or into turn resolution

Current behavior:

- singles only queue commands for actor `0`
- doubles queue commands for every alive player-side actor owned by the current player id
- co-op ownership is respected through `actor_owner_pid`
- once all commandable battlers have actions queued, the engine builds the turn queue and enters `phase = "turn"`

Current split-screen/co-op usage notes:

- pid ownership still flows through the normal battle slot and `player_pids`
- GUI presentation for pid `0` and pid `1` is clipped to left/right screen halves by `battle_draw_gui_rect(...)`
- overworld dialog is suppressed in battle, so battle text remains inside the battle command box and theme instead of the standalone dialog box

## Target selection

Double battles use explicit target-pick helpers when a move needs a live target choice.

Owning helpers:

- `__battle_move_target_mode(move_id)`
- `__battle_target_candidates(pid, actorIndex, move_id)`
- `__battle_sort_target_candidates(pid, actorIndex, targets)`
- `__battle_target_candidate_select_index(targets, targetIndex)`
- `__battle_resolve_live_target_index(pid, actorIndex, targetIndex, move_id)`

Important rules:

- self-target and ally-target moves use the same shared helper path as opponent-target moves
- doubles target sorting prefers the opposing front slot first, then the alternate legal target
- if no explicit target survives, the helpers fall back through `__battle_get_default_target_index(...)`

UI ownership:

- target-pick prompts are rendered from `scripts/battle_ui/battle_ui.gml`
- target selector boxes and actor rectangles are computed in `scripts/battle_draw_helpers/battle_draw_helpers.gml`

## Draw and scene layout

The scene switches to doubles layout when `battle_format == "double"`.

Main owning files:

- `scripts/battle_draw/battle_draw.gml`
- `scripts/battle_draw_helpers/battle_draw_helpers.gml`

Key helper seams:

- `__battle_is_double_scene(_B)`
- `__battle_get_actor_scene_anchor(pid, _B, actorIndex)`
- `__battle_get_target_selector_rect(pid, _B, actorIndex)`
- `__battle_draw_target_selector(pid, _B, cam_offx, cam_offy)`
- `__battle_draw_platform(pid, _B, side, anchor_x, anchor_bottom, ui_scale)`

The anchor helper is the core scene-layout seam. It decides where each active battler stands in singles versus doubles.

If you want to change battler placement, do not start by editing random pixel constants in the top-level draw path. Start with `__battle_get_actor_scene_anchor(...)`.

Target selectors and hit effects prefer the actor's cached live render center and opaque sprite bounds. If a Pokemon sprite is missing, the helper falls back to the placeholder geometry so doubles targeting still points at the visible battler space.

Player-side doubles send-outs use `__battle_player_intro_segment(...)` to split intro timing by slot. That keeps both Pokemon from flashing and growing at the same instant during the battle intro while preserving the shared send-out animation for later switches.

Platform draw ordering:

- Doubles now draw enemy platforms in a separate background pass before the enemy sprite pass.
- Player platforms are also drawn in their own background pass before player sprites.
- `__battle_draw_enemy(...)` accepts a platform-skip path so the top-level draw order can prevent enemy slot 1 or slot 2 from repainting over another battler's platform.
- If a doubles scene has platform-overdraw bugs, start in `scripts/battle_draw/battle_draw.gml` before editing sprite placement math.

## Party and bag integration notes

Doubles are still wired into the normal party and bag systems.

Current important seams:

- party switch flows still route through `battle_switch_to(...)`
- bag code checks `battle_format` when routing battle-only items such as Balls
- target-sensitive battle item flows should read the active battle format rather than assuming a single enemy

If you add new bag or party behavior that depends on doubles, read `battle_format` from the battle slot rather than trying to infer doubles from actor count alone.

## Current foundation limits

Documented current limitations are important because later edits need to know what is intentionally unfinished.

- doubles uses the shared actor layout and shared turn executor now
- command entry is format-aware, but some higher-level UI polish is still incomplete
- doubles switch flow and per-actor command UX are still evolving
- co-op ownership exists at the routing layer, but any new player-specific UI must still opt into that ownership model explicitly

Treat these as design constraints when extending the current system.

## Where To Edit By Goal

- Change doubles open rules or fallback rules: `scripts/battle_system/battle_system.gml::battle_open(...)`
- Change actor ownership or control routing: `scripts/battle_system/battle_system.gml::__battle_actor_owner_pid(...)` and `scripts/battle_command_helpers/battle_command_helpers.gml`
- Change command sequencing for multiple player battlers: `scripts/battle_command_helpers/battle_command_helpers.gml`
- Change legal target generation or target ordering: `scripts/battle_command_helpers/battle_command_helpers.gml`
- Change battler placement or target-selector boxes: `scripts/battle_draw_helpers/battle_draw_helpers.gml`
- Change doubles-specific command UI text or target-pick prompts: `scripts/battle_ui/battle_ui.gml`
- Change double trainer replacement logic: `scripts/battle_trainer/battle_trainer.gml`

## Copyable open patterns

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
    trainer_name: "Bug Catcher Rick",
    battle_format: "double",
    enemy_party: trainer_party,
    area_type: "forest"
});

// Co-op double trainer battle
battle_open_trainer(0, {
    trainer_name: "Twin Trainers",
    battle_format: "double",
    coop_enabled: true,
    player_pids: [0, 1],
    enemy_party: trainer_party,
    area_type: "forest"
});
```

## Practical rules

- Always go through the side or slot helpers before introducing new actor-index logic.
- Add new doubles state in `__battle_ensure_slot(pid)` so single and double battles share one explicit slot shape.
- Keep format negotiation at battle-open time. Do not scatter doubles fallback rules throughout runtime update code.
- When changing trainer doubles, update both the active actor array and `_trainer_party_active_indices` so later replacements still know which party mons are live.
- When changing doubles UI, validate both normal doubles and co-op doubles because `actor_owner_pid` changes which battlers should be commandable.
