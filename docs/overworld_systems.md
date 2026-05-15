# Overworld Systems

This guide covers the newer overworld object stack layered on top of `scripts/player_helper_scripts/player_helper_scripts.gml`.

It focuses on four related pieces:

- general-purpose NPC interactions through `oNpc`
- trainer challenge flow and multi-trainer groups
- visible wild Pokemon that wander inside encounter patches
- overworld item and prop objects added alongside those systems

Use this guide when a change is controlled by an overworld object event rather than by the battle or party UIs.

## Ownership

Primary ownership lives in `scripts/player_helper_scripts/player_helper_scripts.gml`.

The main object seams are:

- `objects/oNpc/Step_0.gml` -> `overworld_npc_step(id)`
- `objects/oNpc/Draw_0.gml` -> direct sprite draw
- `objects/obush/Step_0.gml` -> `overworld_encounter_step(id)`
- `objects/obush/Draw_0.gml` -> direct bush draw
- `objects/oPlayer/Step_1.gml` -> player `Interact` routing through `overworld_find_interactable_npc(...)`

Room-start collision ownership currently lives in `objects/oGame/Other_4.gml`, which binds `oNpc` into the world collision solids list so NPCs block movement.

Boot configuration currently happens in `objects/oGame/Create_0.gml`.

## Runtime State

Two globals now matter for overworld content.

`global.OVERWORLD_RUNTIME` stores persistent world-side state:

- `flags`: arbitrary bool or value flags keyed by id
- `quests`: quest state strings keyed by id
- `npc_pending`: per-pid pending NPC callback data used to finish rewards after dialog closes
- `trainer_pending`: per-pid pending trainer challenge payloads used to chain dialog into `battle_open_trainer(...)`

Use these helpers instead of writing the struct directly:

- `overworld_flag_get(flag_id, default)`
- `overworld_flag_set(flag_id, value)`
- `overworld_quest_get_state(quest_id, default_state)`
- `overworld_quest_set_state(quest_id, state)`

`global.OVERWORLD_ENCOUNTERS` still owns the shared encounter registry, but the visible-mode runtime also depends on these boot knobs from `oGame/Create_0.gml`:

- `OVERWORLD_ENCOUNTER_MODE`: `old` for classic hidden encounters, `new` for visible wandering Pokemon
- `OVERWORLD_SHINY_CHANCE`: default shiny odds for both hidden and visible overworld encounters
- `OVERWORLD_VISIBLE_MAX_ACTIVE`: cap across all visible encounter NPCs in the room
- `OVERWORLD_VISIBLE_PATCH_DENSITY`: how many bush tiles roughly map to one active visible encounter
- `OVERWORLD_VISIBLE_PATCH_MAX`: cap per connected bush patch
- `OVERWORLD_ENCOUNTER_GRACE_MS` and `OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS`: cooldown and grace timing guards used during visible encounters

## NPC Runtime

`overworld_npc_init(inst)` turns a plain `oNpc` instance into a reusable world actor by seeding defaults for four jobs:

- interaction and dialog
- quest state updates and item rewards
- passive movement through wandering or path points
- trainer challenge behavior

Important interaction fields:

- `npc_id`: dialog key and stable identity string
- `interact_radius`: how close the player must be for `Interact`
- `dialog_text`: default text
- `dialog_active_text`: alternate line when the linked quest is active
- `dialog_completed_text`: alternate line when the linked quest is completed

Reward and quest fields:

- `give_item_id`, `give_item_qty`
- `reward_once`, `reward_given`, `reward_text`
- `quest_id`, `quest_state_on_interact`, `quest_update_text`

Movement fields:

- `wander_enabled`, `wander_radius`, `wander_speed`
- `wander_pause_min`, `wander_pause_max`
- `npc_path_enabled`, `npc_path`, `npc_path_index`, `npc_path_loop`
- `npc_path_pause_frames`, `npc_path_speed`

Sprite-facing fields:

- `npc_sprite_base`
- `npc_sprite_up`, `npc_sprite_right`, `npc_sprite_down`, `npc_sprite_left`
- `npc_facing_dir`, `npc_anim_speed`

The sprite resolver accepts directional naming like `spr_bugcatcher_down`, `spr_bugcatcher_up`, `spr_bugcatcher_left`, and `spr_bugcatcher_right`. If `npc_sprite_base` is present, the helper tries to resolve those assets automatically.

Pokemon Center specialization:

- Setting `pokemon_center_nurse = true` on an `oNpc` instance upgrades it into Nurse Joy.
- `overworld_npc_init(...)` auto-fills the directional Nurse Joy sprites when those assets exist.
- The nurse is forced non-wandering, non-trainer, and gets an interaction radius of at least `40` so the player can talk across a counter.

## Player Interaction Hook

`objects/oPlayer/Step_1.gml` is the main overworld interaction entrypoint.

When the player presses `Interact` and dialog is not already open, it does this in order:

1. Calls `overworld_find_interactable_npc(id, 18)`.
2. If that returns an `oNpc`, calls `overworld_npc_interact(_npc, pid)`.
3. If nothing handled the input, falls back to the legacy `oDialogBox` interaction.

That means NPC interactions now sit in front of the old dialog-box seam.

`overworld_find_interactable_npc(...)` prefers the tile in front of the player based on `facing_dir`, then checks distance against `interact_radius`.

Visible encounter NPCs are explicitly excluded from this path through the `encounter_pokemon` flag.

Movement lock note:

- `overworld_player_locked_by_npc(pid)` is the shared lock seam used by `objects/oPlayer/Step_0.gml`.
- Trainer approach/dialog state and the active Pokemon Center nurse flow both route through that same lock, so world movement stops while those interactions own the player.

## Reward and Quest Flow

Normal NPC dialog is two-stage on purpose:

1. `overworld_npc_interact(...)` opens dialog immediately.
2. `__overworld_npc_dialog_closed_pid0/1()` fires after the dialog closes.
3. `overworld_npc_finalize_interaction(...)` then grants rewards or updates quest state.

That keeps bag updates and quest updates from racing with the active text session.

Reward rules:

- if `give_item_id > 0`, the helper adds the item through `bag_inventory_add_item(pid, item_id, qty)`
- if `reward_once` is true, the item is only granted until `reward_given` becomes true
- quest state changes are skipped once the target state is already active or completed

Practical rule: if an NPC should always hand out an item every time, set `reward_once = false`.

## Trainer NPC Flow

The trainer subsystem is just an `oNpc` with `trainer_enabled = true`.

Core trainer fields:

- `trainer_name`
- `trainer_dialog`
- `trainer_after_dialog`
- `trainer_reward`
- `trainer_party` or the fallback `trainer_species` plus `trainer_level`
- `trainer_area_type`
- `trainer_battle_format`
- `trainer_coop_enabled`
- `trainer_sight_range`, `trainer_sight_width`
- `trainer_challenge_group`, `trainer_group_radius`

Flow:

1. `__overworld_trainer_player_in_sight(...)` checks line-of-sight using the NPC's current facing.
2. The trainer enters `trainer_state = "approach"` and walks to a tile adjacent to the target player.
3. `__overworld_trainer_begin_dialog(...)` collects one or more trainers, queues their challenge lines, and builds the trainer battle payload.
4. `__overworld_trainer_open_pending_battle(...)` forwards that payload into `battle_open_trainer(...)`.

Grouped trainers:

- use the same `trainer_challenge_group` string on nearby NPCs
- the leader gathers them with `__overworld_trainer_collect_group(...)`
- grouped encounters force doubles and merge their parties and money reward into one payload

Co-op trainer battles:

- still depend on multiplayer queue mode being `coop`
- set `trainer_coop_enabled = true`
- when co-op is valid, the payload uses `player_pids = [0, 1]` and forces doubles

## Visible Encounter Pokemon

Visible wild Pokemon are also `oNpc` instances, but they opt into a separate path by setting `encounter_pokemon = true`.

Those instances are spawned by `__overworld_encounter_visible_spawn(owner_bush)` and then routed through `overworld_encounter_pokemon_npc_step(inst)` instead of the normal NPC step path.

Each visible encounter NPC stores:

- `encounter_owner`: the bush or encounter volume that spawned it
- `encounter_species_id`, `encounter_level`, `encounter_shiny`
- `encounter_lifetime`, `encounter_fade_frames`
- `encounter_bounds_left/top/right/bottom`
- `encounter_grid_size`
- `wander_target_x`, `wander_target_y`, `wander_speed`
- `encounter_dir`: used to resolve the directional overworld sprite

Sprite resolution comes from the external icon loader:

- `pkicons_get_overworld_dir_by_mon(...)` first
- `pkicons_get_icon32_dir_by_mon(...)` as a fallback
- placeholder sprite if no overworld skin exists

Presentation and collision:

- visible Pokemon NPCs draw at `image_xscale = image_yscale = 0.67`, matching the 16-pixel overworld scale target
- `__overworld_encounter_pokemon_npc_bounds(...)` derives contact bounds from the sprite bounding box and instance scale
- player contact uses those scaled bounds instead of a hard-coded square, so small Pokemon do not trigger battles before the player actually reaches them
- spawn placement and repathing now use rectangle-clear checks against every visible NPC in the owning patch, so wandering Pokemon do not stack on top of each other
- `__overworld_encounter_pokemon_npc_find_clear_point(...)` is the main anti-overlap seam for both initial spawn and runtime unstick behavior
- if a visible Pokemon cannot find any clear point in the patch, it is removed instead of remaining embedded in another visible Pokemon

Battle handoff:

- contact with a player checks `__overworld_encounter_visible_player_hit(...)`
- `__overworld_encounter_pokemon_npc_start_battle(...)` builds a wild battle opts struct
- that opts struct tags the source as `encounter_source = "visible_bush_npc"`

The visible NPC is destroyed after a successful battle open or when its lifetime expires.

## Bush Patch Ownership

In visible mode, connected bush tiles behave like one encounter patch.

`__overworld_encounter_bounds(inst)` expands a bush's bounds outward across adjacent `obush` instances. `__overworld_encounter_is_area_anchor(inst)` then chooses a single top-left-most bush instance as the patch owner.

Only the anchor bush is allowed to:

- keep the live visible encounter NPC array
- tick the visible spawn timer
- spawn visible wild Pokemon

The anchor now owns `_encounter_visible_npcs` as the canonical list; `_encounter_visible_npc` remains as a legacy first-entry alias.

Non-anchor bushes return early in `overworld_encounter_step(...)`. If they somehow still own visible NPCs, they clear and destroy them.

This is the main reason visible encounter state should stay on the encounter object rather than on the player.

## Bush Objects and Draw Events

`obush` now has both Step and Draw events.

- Step calls `overworld_encounter_step(id)`
- Draw renders the bush sprite directly

That explicit Draw event matters because the visible encounter mode treats bush objects as authored props rather than relying on default draw ordering.

The same pattern now exists on `oNpc` and `oPlayer`:

- `oNpc/Draw_0.gml` draws the NPC sprite directly
- `oPlayer/Draw_0.gml` draws the player sprite with a `y - 5` offset

Depth is still managed in Step through per-object `depth` writes.

## World Item Object

`oitem` is now a dedicated overworld object with the `sitem` sprite.

Current state:

- it has a Create event only
- that Create event scales the sprite down with `image_xscale = image_yscale = 0.67`
- there is no Step or pickup helper wired yet

Treat it as a presentation seam right now, not a full pickup system. Item rewards still come from NPC interaction via `give_item_id` and `give_item_qty`.

If you later build field pickups, either:

- extend `oitem` with its own interact or overlap logic, or
- reuse `overworld_npc_finalize_interaction(...)` semantics so reward flags stay consistent

## Concrete Asset Additions

The new overworld content includes:

- `spr_bugcatcher_down`
- `spr_bugcatcher_up`
- `spr_bugcatcher_left`
- `spr_bugcatcher_right`
- `sitem`

That asset set matches the current automatic NPC sprite lookup rules and the new world-item object.

## Fast Checklist

For a talking NPC:

1. Place `oNpc`.
2. Set `dialog_text`.
3. Optionally set `quest_id` or `give_item_id`.
4. Optionally set `npc_sprite_base = "spr_bugcatcher"` or explicit directional sprites.

For a trainer:

1. Place `oNpc`.
2. Set `trainer_enabled = true`.
3. Fill `trainer_name`, `trainer_dialog`, `trainer_party` or species and level fallback.
4. Optionally set `trainer_challenge_group` for multi-trainer encounters.

For visible wild encounters:

1. Place one or more `obush` instances.
2. Set the encounter table keys on the bush patch owner.
3. Leave encounter mode at `global` or force `encounter_mode = "new"`.
4. Ensure the patch has overworld species art if you want visible Pokemon instead of placeholders.

For world items:

1. Use `oitem` only for display today.
2. Use NPC reward fields for actual item grants until pickup logic exists.
