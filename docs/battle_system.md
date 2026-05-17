# Battle System - Setup Guide

This is the practical reference for opening battles, choosing arena themes, and knowing which script owns each part of the flow.

Related docs:

- `docs/overworld_encounters.md` covers encounter volumes and route tables that feed wild battles.
- `docs/battle_doubles.md` covers double battles, co-op ownership, actor slots, and target picking in more detail.
- `docs/versus_system.md` covers local versus setup before the battle slot opens.
- `docs/ability_tracker.md` tracks which abilities are runtime-active, grouped awaiting code, or not grouped yet.

## Quick Start

The battle system has three required pieces:

1. Open a battle once with `battle_open(...)` or `battle_open_trainer(...)`.
2. Run `battle_update(pid)` every Step while the game is active.
3. Run `battle_draw_gui(pid)` or `battle_draw_gui_rect(pid, x, y, w, h)` from Draw GUI.

Minimal wild battle:

```gml
// Open a wild Lv. 5 battle for player 0.
battle_open(0, 5);
```

Minimal wild battle with an arena:

```gml
battle_open(0, 8, "forest");
```

Minimal trainer battle:

```gml
var trainer_party = [
    pokemon_factory_create(10, 5, {}),
    pokemon_factory_create(13, 6, {})
];

battle_open_trainer(0, {
    trainer_name: "Bug Catcher Rick",
    sprite: spr_PokemonEmeraldTrainers,
    sprite_index: 12,
    party: trainer_party,
    area_type: "forest",
    trainer_reward: 50
});
```

Runtime loop:

```gml
// Step
controls_update();
battle_update(0);

// Draw GUI
battle_draw_gui(0);
```

## How Battles Start

`battle_open(...)` creates and seeds the battle slot. It does not keep the battle alive by itself. The running battle is driven by `battle_update(pid)` and drawn by `battle_draw_gui(pid)`.

Common entry paths:

- Debug wild battle: `objects/oPlayer/Step_1.gml` listens for F1, builds `_debug_opts`, picks an arena, and calls `battle_open(pid, open_level, area_type, opts)`.
- Overworld wild battle: an encounter object calls `overworld_encounter_step(id)`, which rolls species/levels and eventually calls `battle_open(...)`.
- Visible wild battle: visible encounter helpers still end at `battle_open(...)`, but start from spawned visible NPC-style encounter actors.
- Trainer battle: trainer setup calls `battle_open_trainer(pid, trainer_payload)`, which normalizes trainer data and then calls `battle_open(...)`.
- Local versus/co-op: multiplayer helpers build battle options, then call `battle_open(...)` or `battle_open_trainer(...)`.

## Public Battle API

- `battle_is_open(pid) -> bool`
- `battle_open(wild_level)`
- `battle_open(pid, wild_level)`
- `battle_open(pid, wild_level, area_type)`
- `battle_open(pid, wild_level, opts)`
- `battle_open(pid, wild_level, area_type, opts)`
- `battle_open_trainer(pid, trainer_payload)`
- `battle_update(pid)`
- `battle_draw_gui(pid)`
- `battle_draw_gui_rect(pid, rx, ry, rw, rh)`
- `battle_close(pid)`
- `battle_switch_to(pid, party_idx, opts)`
- `battle_intro_set_handlers(pid, updateFn, drawFn)`

Readable parameter names are part of the public contract for `battle_open`: `pid_or_level`, `wild_level`, `area_or_opts`, and `opts`. Avoid placeholder names like `_a0` there because GameMaker exposes them in call hints.

## Battle Open Arguments

`battle_open(...)` accepts a few overloads because GameMaker does not have named optional parameters.

```gml
battle_open(5);                         // PID 0, wild Lv. 5
battle_open(0, 5);                      // PID 0, wild Lv. 5
battle_open(0, 5, "river");             // PID 0, wild Lv. 5, river arena
battle_open(0, 5, { enemy_species: 25 }); // PID 0, wild Lv. 5 Pikachu
battle_open(0, 5, "river", opts);       // arena plus options
```

Argument meanings:

- `pid`: player id, usually `0`.
- `wild_level`: fallback level used for wild spawns and as a default if options do not provide enemy levels.
- `area_type`: arena/theme name such as `"forest"` or `"river"`.
- `opts`: struct that controls battle type, format, enemy data, co-op ownership, arena overrides, and transition style.

## Battle Types

The battle type is read from `opts.battle_type`, or `opts.type` as a fallback.

Supported `battle_open(...)` values:

- `"wild"`: default. Enemy Pokemon are generated from species/level options or fallback wild spawn logic.
- `"trainer"`: enemy Pokemon come from `enemy_party`, `enemy_mon`, or `battle_open_trainer(...)`.

Local versus is not opened by passing `battle_type: "versus"`. Use `multiplayer_start_versus_battle(...)`; it opens a trainer-style battle, then tags the battle slot with `versus_enabled` and player ownership metadata.

Direct wild battle:

```gml
battle_open(0, 7, "grassy", {
    battle_type: "wild",
    enemy_species: 25,
    enemy_level: 7
});
```

Direct trainer-style battle without the wrapper:

```gml
var enemy_party = [
    pokemon_factory_create(133, 10, {}),
    pokemon_factory_create(10, 11, {})
];

battle_open(0, 10, "man made paths", {
    battle_type: "trainer",
    enemy_party: enemy_party,
    trainer_reward: 100
});
```

Prefer `battle_open_trainer(...)` for normal trainer encounters because it also sets up trainer intro data.

## Abilities And Dialog

Pokemon abilities are loaded from the CSV data and assigned by `pokemon_factory_create(...)`.

Ability data comes from these files:

- `data/csv/abilities.csv`: ability id and identifier, like `water-absorb`.
- `data/csv/ability_names.csv`: display names, like `Water Absorb`.
- `data/csv/ability_prose.csv`: English short/effect text.
- `data/csv/pokemon_abilities.csv`: which abilities each species can have.

`data_load_ability_effects_structs()` combines those CSVs into `global._ability_effects`. Every ability gets a record with its id, identifier, display name, and prose.

The generic ability layer works like the move-meta layer:

- `global._ability_effects[ability_id]`: one structured record per ability.
- `effect.groups`: broad behavior buckets, such as `entry_weather`, `type_absorb_heal`, `status_immunity`, `crit_immunity`, `stat_multiplier`, and `survive_full_hp_ko`.
- `effect.actions`: generic hook records with `{ hook, kind, data }`, such as `on_entry/set_weather`, `on_defend_type/absorb_heal`, `status_apply/block_status`, and `damage_taken/type_multiplier`.
- `global._ability_groups[group_id]`: reverse lookup from a behavior group to ability ids.

Battle code should prefer the generic helpers:

- `__battle_actor_ability_effect(actor)`
- `__battle_actor_ability_has_group(actor, group_id)`
- `__battle_actor_ability_actions(actor, hook)`
- `__battle_queue_ability_action_dialog(actor, action, target, context)`

That means the game now uses CSV-derived ability data first, then falls back to older hardcoded checks. The battle engine still does not magically implement every unique mainline ability, because many abilities need custom logic in a specific move, turn, item, weather, terrain, or overworld hook. But the data is centralized now, so adding support for another ability usually means adding tags in `__ability_effect_apply_known_tags(...)`, then wiring a hook if that ability needs one.

Implemented ability categories include:

- Entry weather: `Drizzle`, `Drought`, `Sand Stream`, `Snow Warning`.
- Entry stat pressure: `Intimidate`, with blockers like `Clear Body`, `White Smoke`, `Hyper Cutter`, `Full Metal Body`, `Inner Focus`, `Oblivious`, and `Scrappy`.
- Type immunities/healing/stat boosts: `Water Absorb`, `Storm Drain`, `Dry Skin`, `Volt Absorb`, `Lightning Rod`, `Motor Drive`, `Flash Fire`, `Sap Sipper`, and `Levitate`.
- Type chart and STAB modifiers: normal type effectiveness from `type_efficacy.csv`, same-type attack bonus, `Adaptability`, `Tinted Lens`, `Filter`, `Solid Rock`, `Prism Armor`, `Wonder Guard`, and `Scrappy`.
- Damage/stat modifiers: `Overgrow`, `Blaze`, `Torrent`, `Swarm`, `Thick Fat`, `Heatproof`, `Dry Skin`, `Huge Power`, `Pure Power`, `Fur Coat`, `Guts`, `Marvel Scale`, `Battle Armor`, and `Shell Armor`.
- Speed and priority modifiers: `Swift Swim`, `Chlorophyll`, `Sand Rush`, `Slush Rush`, `Quick Feet`, `Prankster`, `Gale Wings`, and `Triage`.
- Grouped one-off damage hooks: `Iron Fist`, `Strong Jaw`, `Mega Launcher`, `Reckless`, `Tough Claws`, `Technician`, `Sheer Force`, and `Sniper`.
- Status and volatile blockers: `Immunity`, `Water Veil`, `Water Bubble`, `Limber`, `Insomnia`, `Vital Spirit`, `Sweet Veil`, `Magma Armor`, `Own Tempo`, `Leaf Guard`, `Inner Focus`, and `Oblivious`.
- Contact, trapping, item, and switch groups are tagged for hooks: `Rough Skin`, `Iron Barbs`, `Static`, `Flame Body`, `Poison Point`, `Cute Charm`, `Effect Spore`, `Cursed Body`, `Weak Armor`, `Mummy`, `Aftermath`, `Arena Trap`, `Shadow Tag`, `Magnet Pull`, `Sticky Hold`, `Klutz`, `Unburden`, `Natural Cure`, and `Regenerator`.
- After-hit and faint reaction hooks are active for `Moxie`, `Chilling Neigh`, `Grim Neigh`, `Beast Boost`, `Soul-Heart`, `Anger Point`, `Rattled`, `Justified`, `Stamina`, `Steam Engine`, and `Water Compaction`.
- Move-specific helpers include support checks for things like `Soundproof`, `Bulletproof`, `Overcoat`, `Magic Guard`, `Shield Dust`, `No Guard`, `Mold Breaker`, `Turboblaze`, `Teravolt`, `Plus`, and `Minus` where those move paths use them.

Type effectiveness is applied in `__battle_calc_damage_impl(...)` through `__battle_move_type_effectiveness_multiplier(...)`. So examples like Water attacking Fire, Electric attacking Ground, or Ghost attacking Normal use the loaded CSV type chart during damage, not only for hit sounds or debug text.

Battle feedback sounds are tied to the dialog/effect paths:

- `snd_SuperEffective` plays when battle text reports a super-effective hit.
- `snd_NotVeryEffective` plays when battle text reports not-very-effective or no-effect feedback.
- `snd_Heal` plays when battle text reports healing/restoration.
- `snd_Stat_Raise` and `snd_Stat_Lower` play when stat-change dialog appears.
- Status sounds are handled by `status_system.gml` for sleep, burn, poison, freeze, paralysis, confusion, and infatuation.

Ability messages go through battle dialog helpers. Generic ability actions call `__battle_queue_ability_action_dialog(...)`, which writes short Emerald-style battle lines such as `<Pokemon>'s INTIMIDATE!`, `<target>'s ATTACK was cut!`, `It started to rain!`, or `status was prevented!`. That helper calls `dialog_queue(...)`, and `dialog_queue(...)` falls back to `dialog2p_show_now(...)` if the full dialog queue is not available. So abilities that have messages are tied into the same dialog presentation system as move text and battle status text.

When adding a new ability, search for these hook points first:

- `data_load_ability_effects_structs(...)`
- `__ability_effect_apply_known_tags(...)`
- `__battle_apply_entry_abilities(...)`
- `__battle_apply_ability_heal_or_block(...)`
- `__battle_ability_damage_multiplier(...)`
- `__battle_actor_ability_effect(...)`
- `__battle_actor_ability_has_group(...)`
- `__battle_actor_ability_actions(...)`
- `__battle_actor_has_any_ability(...)`
- `status_system_can_apply_status(...)`
- move effect helpers in `scripts/battle_move_meta_helpers/`

## Stat Overlay Stencils

Stat changes use a cutout stencil overlay driven by:

- `scripts/battle_move_meta_helpers/battle_move_meta_helpers.gml`: applies stat stage changes and queues `_pending_stat_overlays`.
- `scripts/battle_system/battle_system.gml`: consumes the pending stat overlays when the matching stat dialog is shown.
- `scripts/battle_state_overlay/battle_state_overlay.gml`: builds stat overlay payloads.
- `scripts/battle_animations/battle_animations.gml`: draws the tiled stat effect through the battler sprite stencil.

Single-target stat changes call `__battle_trigger_stat_overlay(...)`.

Multi-target stat changes, such as doubles moves that drop both opposing Pokemon, now call `__battle_trigger_stat_overlay_multi(...)`. The animation payload carries `target_indexes`, so one shared stat overlay can stencil all affected battlers at the same time instead of only cutting out the first Pokemon.

## Open Options

Common `opts` fields:

- `battle_type` or `type`: `"wild"` or `"trainer"`.
- `battle_format`: `"single"` or `"double"`. Anything else becomes `"single"`.
- `coop_enabled`: `true` to let player 1 own the second player-side battler in doubles.
- `player_pids`: array of player ids, usually `[0, 1]` for co-op or versus.
- `area_type`: arena preset name. Same as passing the third argument.
- `theme`: optional nested struct. `theme.area_type` is also accepted.
- `transition_style`: optional battle transition override if the transition system is loaded.
- `enemy_species`: wild species id, or an array of species ids for double wild battles.
- `enemy_level`: single wild/trainer fallback enemy level.
- `enemy_levels`: array of levels for double wild battles. Some fallback paths also accept a single number, but prefer `enemy_level` for single battles.
- `enemy_shiny`: `true`, or an array like `[true, false]` for double wild battles.
- `enemy_mon`: a prepared mon struct for the enemy lead.
- `enemy_party`: array of prepared mon structs for trainer-style battles.
- `trainer_reward`, `reward`, or `payout`: money/reward value for trainer battles.

Double wild example:

```gml
battle_open(0, 12, "forest", {
    battle_type: "wild",
    battle_format: "double",
    enemy_species: [16, 19],
    enemy_levels: [12, 11]
});
```

Co-op double wild example:

```gml
battle_open(0, 12, "forest", {
    battle_type: "wild",
    battle_format: "double",
    coop_enabled: true,
    player_pids: [0, 1],
    enemy_species: [16, 19],
    enemy_levels: [12, 11]
});
```

## Trainer Payload

Use `battle_open_trainer(pid, trainer_payload)` for normal NPC trainer battles.

Common `trainer_payload` fields:

- `trainer_name` or `name`: display name.
- `sprite` or `trainer_sprite`: trainer sprite asset.
- `sprite_index`, `frame`, or `subimg`: trainer sprite frame.
- `sprite_scale`: trainer sprite scale.
- `party`, `mons`, `team`, or `enemy_party`: array of enemy mons.
- `enemy_mon`: explicit lead mon.
- `enemy_species`: fallback species if not using a party.
- `enemy_level` or `level`: default level for entries that need one.
- `area_type`: arena preset.
- `theme.area_type`: alternate place to provide arena preset.
- `battle_format`: `"single"` or `"double"`.
- `coop_enabled`: co-op doubles flag.
- `player_pids`: ownership pids, usually `[0, 1]`.
- `trainer_reward`, `reward`, or `payout`: reward paid on defeat.
- `ball_sprite`, `ball_scale`, `throw_duration`, `throw_height`, `reveal_at`, `throw_origin_x`, `throw_origin_y`: trainer intro throw tuning.
- `slide_out_duration`, `enemy_reveal_duration`: trainer intro timing.

Trainer double example:

```gml
var trainer_party = [
    pokemon_factory_create(133, 12, {}),
    pokemon_factory_create(10, 12, {})
];

battle_open_trainer(0, {
    trainer_name: "Duo Ada & Ben",
    sprite: spr_PokemonEmeraldTrainers,
    sprite_index: 4,
    party: trainer_party,
    battle_format: "double",
    area_type: "wood bridge",
    trainer_reward: 180
});
```

## Arena Themes

Arena themes are selected with `area_type`. This sets the platform frame for both sides and updates the battle UI colors.

You can pass the arena in any of these ways:

```gml
battle_open(0, 5, "forest");

battle_open(0, 5, {
    area_type: "forest"
});

battle_open(0, 5, {
    theme: { area_type: "forest" }
});

battle_open_trainer(0, {
    trainer_name: "Hiker Hal",
    party: trainer_party,
    area_type: "rocks a"
});
```

Canonical arena presets:

| `area_type` | Platform index | Typical use |
| --- | ---: | --- |
| `"dark water"` | 0 | deep water, night water, dark surf |
| `"rocks a"` | 1 | gray caves, rocky interiors |
| `"light"` | 2 | bright neutral / pale arena |
| `"grassy"` | 3 | open grass field, default |
| `"rocks b"` | 4 | brown caves, dry rock |
| `"dirt"` | 5 | dirt path, earth |
| `"river"` | 6 | river, water, stream |
| `"snowy"` | 7 | snow field |
| `"grassy snow"` | 8 | snowy grass |
| `"ice"` | 9 | ice floor, icy routes |
| `"forest"` | 10 | forest path, lush forest |
| `"ugly grass"` | 11 | patchy grass, scrub |
| `"wood bridge"` | 12 | bridge, boardwalk |
| `"man made paths"` | 13 | paved path, concrete |

Accepted aliases:

- `"dark_water"`, `"darkwater"`, `"water dark"`, `"water_dark"` -> `"dark water"`
- `"rocks_a"`, `"rocksa"`, `"grey caves"`, `"gray caves"`, `"grey_caves"`, `"gray_caves"` -> `"rocks a"`
- `"grass"`, `"field"` -> `"grassy"`
- `"rocks_b"`, `"rocksb"`, `"brown caves"`, `"brown_caves"` -> `"rocks b"`
- `"earth"` -> `"dirt"`
- `"water"`, `"stream"` -> `"river"`
- `"snow"` -> `"snowy"`
- `"grassy_snow"`, `"snowy grass"`, `"snowy_grass"` -> `"grassy snow"`
- `"icy"` -> `"ice"`
- `"lush forest"`, `"forest_path"` -> `"forest"`
- `"patchy grass"`, `"scrub"` -> `"ugly grass"`
- `"wood_bridge"`, `"bridge"`, `"boardwalk"` -> `"wood bridge"`
- `"man_made_paths"`, `"paved"`, `"concrete"` -> `"man made paths"`

Arena implementation lives in `scripts/battle_theme_helpers/battle_theme_helpers.gml`.

## Platform Overrides

Most battles should use `area_type`. Use platform overrides only when an encounter needs a custom look.

Supported fields can live directly in `opts` or inside `opts.theme`:

- `platform_environment`: shared arena name or index for both sides.
- `platform_enemy_environment`: arena name or index for enemy side only.
- `platform_player_environment`: arena name or index for player side only.
- `platform_enemy_index`: numeric platform frame or arena name for enemy side.
- `platform_player_index`: numeric platform frame or arena name for player side.
- `platform_enemy_sprite`: enemy platform sprite.
- `platform_player_sprite`: player platform sprite.
- `platform_scale`: shared platform scale.
- `platform_enemy_scale`: enemy platform scale.
- `platform_player_scale`: player platform scale.
- `platform_offset`: shared `{ x, y }` or `[x, y]` offset.
- `platform_enemy_offset`: enemy platform offset.
- `platform_player_offset`: player platform offset.

Example:

```gml
battle_open(0, 8, "forest", {
    platform_enemy_environment: "rocks a",
    platform_player_environment: "grassy",
    platform_player_offset: { x: 0, y: -28 }
});
```

## Overworld Encounter Setup

For normal route encounters, do not call `battle_open(...)` directly from the player Step event. Use encounter objects so cooldowns, pending locks, and route tables stay consistent.

Yes, you can set route encounter tables from a room's `RoomCreationCode.gml`. That is a good place for room-specific route data because it keeps the encounter table near the map that uses it.

Room creation code pattern:

```gml
// rooms/Route3/RoomCreationCode.gml

// 1) Register the encounter tables for this room/route.
if (!is_undefined(overworld_encounter_register_table)){
    overworld_encounter_register_table("route_3", "grass", [
        { species_id: 16, weight: 45, min_level: 4, max_level: 6 }, // Pidgey
        { species_id: 19, weight: 35, min_level: 4, max_level: 6 }, // Rattata
        { species_id: 25, weight: 20, min_level: 5, max_level: 7 }  // Pikachu
    ]);

    overworld_encounter_register_table("route_3", "bush", [
        { species_id: 10, weight: 50, min_level: 3, max_level: 5 }, // Caterpie
        { species_id: 13, weight: 40, min_level: 3, max_level: 5 }, // Weedle
        { species_id: 43, weight: 10, min_level: 5, max_level: 7 }  // Oddish
    ]);

    overworld_encounter_register_table("route_3", "water", [
        { species_id: 129, weight: 80, min_level: 5, max_level: 8 }, // Magikarp
        { species_id: 60, weight: 20, min_level: 6, max_level: 9 }   // Poliwag
    ]);
}

// 2) Point encounter objects in this room at those tables.
// This example configures every obush instance in the room as a forest bush encounter.
with (obush){
    if (!is_undefined(overworld_encounter_init)) overworld_encounter_init(id);
    encounter_region_key = "route_3";
    encounter_habitat = "bush";
    encounter_area_type = "forest";
    encounter_chance = 1 / 12;
    encounter_level_min = 3;
    encounter_level_max = 7;
    encounter_battle_format = "single";
}
```

If you have different encounter objects in the same room, give them different habitats:

```gml
// Grass patch object uses route_3/grass and the grassy arena.
with (oTallGrass){
    if (!is_undefined(overworld_encounter_init)) overworld_encounter_init(id);
    encounter_region_key = "route_3";
    encounter_habitat = "grass";
    encounter_area_type = "grassy";
    encounter_chance = 1 / 16;
}

// Water encounter object uses route_3/water and the river arena.
with (oWaterEncounter){
    if (!is_undefined(overworld_encounter_init)) overworld_encounter_init(id);
    encounter_region_key = "route_3";
    encounter_habitat = "water";
    encounter_area_type = "river";
    encounter_chance = 1 / 20;
}
```

If your room only has one special encounter volume, you can skip the registry and put a direct table on that instance:

```gml
with (obush){
    if (!is_undefined(overworld_encounter_init)) overworld_encounter_init(id);
    encounter_area_type = "forest";
    encounter_habitat = "bush";
    encounter_table = [
        { species_id: 10, weight: 60, min_level: 3, max_level: 5 },
        { species_id: 13, weight: 40, min_level: 3, max_level: 5 }
    ];
}
```

Use registered route tables when multiple objects should share the same encounter data. Use `encounter_table` directly when one placed instance needs a custom one-off table.

Minimal encounter object:

```gml
// Create event
if (!is_undefined(overworld_encounter_init)) overworld_encounter_init(id);
encounter_region_key = "route_3";
encounter_habitat = "grass";
encounter_area_type = "forest";
encounter_chance = 1 / 16;
encounter_radius = 24;

// Step event
if (!is_undefined(overworld_encounter_step)) overworld_encounter_step(id);
```

Route table:

```gml
overworld_encounter_register_table("route_3", "grass", [
    { species_id: 16, weight: 45, min_level: 4, max_level: 6 },
    { species_id: 19, weight: 35, min_level: 4, max_level: 6 },
    { species_id: 25, weight: 20, min_level: 5, max_level: 7 }
]);
```

Useful encounter instance fields:

- `encounter_area_type`: battle arena preset.
- `encounter_region_key`: route/area table key.
- `encounter_habitat`: table bucket such as `"grass"`, `"bush"`, or `"water"`.
- `encounter_table`: direct table override for one instance.
- `encounter_level_min`, `encounter_level_max`: fallback levels.
- `encounter_chance`: chance checked when entering the volume.
- `encounter_radius`: fallback contact radius.
- `encounter_battle_format`: `"single"` or `"double"`.
- `encounter_double_chance`: chance to upgrade a single encounter into a double.
- `encounter_coop_enabled`: allow co-op handoff when multiplayer queue mode allows it.
- `encounter_enabled`: temporary on/off switch.

`objects/obush/Create_0.gml` is the current concrete template and defaults to `"forest"`.

## Battle Phases

- `transition_in`: fade from black.
- `intro_enemy`: wild enemy slide-in and cry, or trainer intro setup.
- `intro_call`: trainer slide/call/dialog pages.
- `intro_player`: player mon send-out.
- `command`: player input.
- `turn`: turn queue resolves.
- `switch_in`: swap animation and optional turn consumption.

## Battle Slot Shape

The active battle slot is `_B = __battle_ensure_slot(pid)`.

Important fields:

- `sys_open`: whether battle is open.
- `phase`, `phase_start_ms`, `phase_progress`, `phase_durs`: phase state and timing.
- `battle_type`: `"wild"` or `"trainer"`.
- `battle_format`: `"single"` or `"double"`.
- `active_per_side`: `1` or `2`.
- `coop_enabled`: co-op ownership flag.
- `player_pids`: player ids for player-side ownership.
- `actor`: active battler array.
- `actor_owner_pid`: owner pid per active actor slot.
- `sys_ui`: command/menu state.
- `theme`: current colors and platform settings.
- `_area_type`: canonical arena name after theme resolution.
- `_battle_opts`: original options struct when provided.
- `_trainer_party`, `_trainer_party_active_idx`: trainer party state.
- `_trainer_reward`, `_trainer_reward_paid`: reward state.
- `_pending_status_msgs`, `_pending_close`, `_closing`: message and close flow.

Actor layout:

- Single battle: `actor[0]` is player lead, `actor[1]` is enemy lead.
- Double battle: `actor[0]` and `actor[1]` are player side, `actor[2]` and `actor[3]` are enemy side.

## Key Helpers

- `__battle_ensure_slot(pid)`: creates or returns the battle slot.
- `__battle_process_input(pid)`: command UI input.
- `__battle_build_turn_actions(pid)`: builds turn queue.
- `__battle_step_turn_if_ready(pid)`: resolves queued actions.
- `__battle_transform_available_modes(pid, actor_index)`: returns the active Pokemon's usable Mega/Z/Dynamax modes.
- `__battle_apply_transformation_action(pid, step, actor_index, actor)`: applies the queued battle transformation before the move resolves.
- `__battle_tick_dynamax_runtime(pid)`: decrements Dynamax and reverts it after three turns.
- `__battle_can_hit_target(attacker, defender, move_id)`: central accuracy/hit gate.
- `__battle_move_accuracy(move_id)`: move base accuracy.
- `__battle_enemy_choose_action(pid)`: simple enemy AI.
- `__party_find_next_alive(pid)`: usable replacement index.
- `__battle_hp_now(ent)`: canonical HP lookup.
- `__battle_apply_entry_hazards(pid, index)`: entry hazards.
- `__battle_check_play_cries(pid)`: cry playback triggers.
- `__battle_trainer_schedule_next_mon(pid, idx)`: queue next trainer send-out.
- `__battle_trainer_apply_pending_send(pid)`: apply queued trainer send-out.
- `__battle_trainer_handle_defeat(pid)`: defeat dialog and payout.
- `__battle_theme_apply_area_type(_B, area, opts)`: apply arena preset.
- `__battle_theme_apply_platform_opts(_B, opts)`: apply platform overrides.

## Where To Edit

- Opening options, battle type setup, and actor seeding: `scripts/battle_system/battle_system.gml::battle_open(...)`
- Trainer payload parsing and trainer intro: `scripts/battle_trainer/battle_trainer.gml`
- Arena presets and platform overrides: `scripts/battle_theme_helpers/battle_theme_helpers.gml`
- Battle drawing and platform rendering: `scripts/battle_draw/`, `scripts/battle_draw_helpers/`, `scripts/battle_ui/`
- Command selection, target picking, and input routing: `scripts/battle_command_helpers/` and `__battle_process_input(...)`
- Move resolution and damage/status behavior: `scripts/battle_actions/`, `scripts/battle_impls/`, `scripts/battle_move_meta_helpers/`
- Wild encounter handoff: `scripts/player_helper_scripts/player_helper_scripts.gml` encounter helper region
- Debug F1 open path: `objects/oPlayer/Step_1.gml`

## Battle Presentation Notes

- Battler feet are grounded from the sprite's opaque bounding-box bottom, so small grounded Pokemon sit on the platform while floating Pokemon keep their float offset.
- Rendered battlers cache `_render_center_x`, `_render_center_y`, `_render_ground_y`, `_render_opaque_w`, and `_render_opaque_h` for effects and target selectors.
- Send-out animations for player, enemy, and trainer Pokemon share the flash-then-grow treatment.
- Doubles intros stagger paired Pokemon so they do not flash in at exactly the same time.
- Catch attempts store the ball's platform contact point; the shake phase stays anchored to that point.
- Mega/Z/Dynamax use the Fight menu `PageDown` / `S` burst toggle. The selected mode appears in the Fight panel, then triggers when the player chooses a move.
- Mega and Gigantamax form changes require real 96x96 Pokemon art from `pkicons_has_art96(...)`; placeholder-only forms are blocked with an in-battle message instead of transforming.
- The transformation flash is drawn over the battle field with stronger colors than the evolution scene: pink/cyan for Mega, gold/orange for Z-Power, and red/violet for Dynamax.
- Battle message text belongs inside `scripts/battle_ui/battle_ui.gml`, not the standalone overworld dialog renderer.

## Close Flow

- Battle close can be requested manually with `battle_close(pid)`.
- Normal defeat/catch/end flows usually set `_pending_close`, then fade before final close.
- If caught-mon nickname entry is active, close waits while `virtual_keyboard_blocks_input(pid)` is true.
- Status and defeat messages accumulate in `_pending_status_msgs`.

## Safe Editing Checklist

1. Start from the public seam that owns the behavior.
2. For new open options, parse them in `battle_open(...)` and store normalized state on `_B`.
3. For arena changes, edit `battle_theme_helpers.gml` and update the arena table in this doc.
4. For trainer setup, prefer `battle_open_trainer(...)` instead of duplicating wrapper behavior.
5. Add/update focused smoke coverage in `scripts/test_trainer_battle_scenario/` when runtime behavior changes.
6. Run the relevant Igor/GameMaker smoke path, then restore any temporary `global.DEV_AUTO_*` flags.
