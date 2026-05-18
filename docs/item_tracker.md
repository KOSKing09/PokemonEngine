# Item Runtime Tracker

Owner: `scripts/PokemonDataLoaders/PokemonDataLoaders.gml`, `scripts/bag_system/bag_system.gml`, `scripts/scr_apply_item_effects/scr_apply_item_effects.gml`, `scripts/party_input/party_input.gml`

This tracker separates item data that is loaded from item behavior that is actually running in game.

## Item Conversion Tracker
            
Latest verified count from `tmp/igor/item_runtime_held_patch_compile.log`:

- Total CSV items loaded: 2180
- Converted into the generic runtime layer: 2180
- Still unconverted / no runtime group yet: 0
- Converted items with at least one runtime action hook: 1401
- Converted items already consumed by live systems: 1751
- Converted but marked pending for missing gameplay systems: 0

Count meanings:

- Converted: the item has at least one `global._item_runtime` group or action.
- Action hook: the item has a hook such as `use_target`, `battle_use`, `field_use`, `weather_duration`, `terrain_duration`, `screen_duration`, `damage_dealt`, `damage_taken`, `end_turn`, `after_damage`, `after_damage_taken`, `move_select`, or `breeding`.
- Runtime consumed: the hook is already read by live bag, battle, field, or breeding code.
- Pending: the item is recognized, but still has an explicit `_pending` runtime group. This count is now zero.

## Data Pipeline

Implemented:

- `items.csv`: core item ids, identifiers, category ids, costs, and metadata.
- `item_categories.csv`: bag pocket/category mapping.
- `item_flag_map.csv` and `item_flag_prose.csv`: holdable, consumable, and battle-use flag lookup.
- `item_prose.csv`: item descriptions and short effect text.
- `machines.csv`: TM/HM item id to move id.
- `pokemon_moves.csv`: TM/HM species compatibility rows.
- `pokemon_evolution.csv`: item-triggered evolution rows.

## Runtime Implemented

Generic runtime layer:

- `data_load_item_runtime_structs()` builds `global._item_runtime[item_id]` after CSV item effects are parsed.
- `global._item_runtime[item_id].groups` gives every known item broad behavior tags such as `medicine_hp`, `poke_ball`, `berry`, `berry_trigger`, `choice_item`, `held_type_boost`, `held_type_gem`, `held_weather_rock`, `held_screen_extender`, `held_terrain_extender`, `held_breeding_nature`, `key_item_registered`, `crafting_material`, `fossil_restore`, `tera_shard`, `mega_stone`, `z_crystal`, and `dynamax_crystal`.
- `global._item_runtime[item_id].actions[hook]` stores behavior records by timing hook, for example `use_target`, `battle_use`, `field_use`, `damage_dealt`, `end_turn`, `after_damage`, `before_faint`, `screen_duration`, `terrain_duration`, `weather_duration`, `move_select`, `reward_calc`, and `breeding`.
- Runtime helpers:
  - `item_runtime_get(item_id)`
  - `item_runtime_has_group(item_id, group)`
  - `item_runtime_actions(item_id, hook)`
  - `item_runtime_actor_held_item_id(actor)`
  - `item_runtime_actor_has_held_group(actor, group)`
  - `item_runtime_actor_held_actions(actor, hook)`

Category fallback grouping:

- Every loaded item now receives at least one runtime group.
- Category and pocket tags are added as `category_*` and `pocket_*` groups from `item_categories.csv`.
- Items without a full bespoke mechanic are still registered under explicit runtime groups and generic actions instead of `_pending` buckets.
- This means `unconverted_items` tracks true loader failures, and `pending` tracks only explicit `_pending` groups. Both are now zero.
- `items.csv` now reads `category_id`, `cost`, and `fling_power` by header name, so category grouping no longer uses swapped columns.
- `item_categories.csv` now maps `pocket_id` through `item_pockets.csv`, so the loader reports the expected 8 pockets instead of treating every category as its own pocket.

Current pending bucket breakdown:

No pending buckets remain. The latest runtime log reports an empty `[DATA][item_runtime][pending_groups]` line.

Direct bag or party target use:

- HP healing items: flat HP, full HP, Full Restore-style HP plus status cure.
- Revive items: half HP, full HP, and all-party revive effects when parsed.
- Status cures: single status and cure-all medicine.
- PP restoration: Ether/Elixir-style single-move and all-move PP restore.
- EV items: vitamins, wings, and EV-reducing berries.
- Rare Candy: level-up plus stat recalculation.
- EXP Candy XS/S/M/L/XL: grants experience to the selected Pokemon and levels it if it crosses the next threshold.
- Health/Mighty/Tough/Smart/Courage/Quick Candy, including L and XL: adds persistent stat candy bonuses and recalculates stats.
- Species Candies: only apply to the matching Pokemon species and raise all six stats by the candy amount.
- Nature Mints: set the Pokemon nature identifier and recalculate the affected stats.
- Dynamax Candy: raises the Pokemon's stored `dynamax_level` up to 10 for future Dynamax systems.
- Ability Capsule / Ability Patch: changes the selected Pokemon's ability using `pokemon_abilities.csv`.
- Mochi: stat Mochi raises EVs; Fresh-Start Mochi resets EVs and recalculates stats.
- Tera Shards: set the selected Pokemon's stored `tera_type`.
- PP Up / PP Max: PP-up counter and PP capacity increase.
- Item evolution: evolution stones and other item-triggered species rows.
- Battle X items: X stat boosts, Dire Hit, and Guard Spec.
- Escape items: Poke Doll, Fluffy Tail, and Poke Toy end wild battles.
- Field encounter items: Repel and encounter-rate modifiers.
- Lure / Super Lure / Max Lure: registered as encounter-rate field effects.
- Flutes: Blue/Yellow/Red Flutes are parsed as party-target status cures instead of sitting in field-tool pending.
- Poke Balls: queued through battle catch actions, including double-battle target selection. Battle runtime now uses `pokemon_species.csv` `capture_rate`, current HP, major status, and per-ball modifiers instead of a flat HP-percent shortcut. Implemented ball rules include standard balls, Master/Park/Origin guaranteed capture, Net/Dive/Nest/Repeat/Timer/Dusk/Quick/Dream/Beast balls, Apricorn balls, Legends-style balls, Heal Ball healing, and Friend/Luxury friendship setup.
- TMs/HMs: party target selection, compatibility check, learn/replace flow, and TM consumption.
- Held items: Give flow assigns held item ids/names to Pokemon and returns replaced held items to the bag.
- Held duration items: Light Clay, Terrain Extender, and weather rocks now expose generic runtime actions and the battle duration hooks consume those actions.
- Held battle stat/damage items:
  - Choice Band, Choice Specs, and Choice Scarf now feed their generic `stat_calc` actions into battle damage stat calculation.
  - Life Orb now feeds its generic `damage_dealt` multiplier into battle damage and its recoil into `after_damage`.
  - Shell Bell now heals from its generic `after_damage` action.
  - Type boosters, plates, incenses, Muscle Band, Wise Glasses, and type Gems now feed generic `damage_dealt` multipliers into battle damage where their type/category matches.
- Held end-turn items:
  - Leftovers heals from its generic `end_turn` action.
  - Black Sludge heals Poison-type Pokemon and damages non-Poison Pokemon from its generic `end_turn` action.
- Held KO-survival items:
  - Focus Sash now consumes its generic `before_faint` action and lets a full-HP holder survive at 1 HP.
  - Focus Band now consumes its generic `before_faint` action and gives the holder a chance to survive at 1 HP.
- Held choice-lock items:
  - Choice Band, Choice Specs, and Choice Scarf now consume their generic `move_select` action so the first chosen move becomes locked while the holder stays in battle.
- Held auto-use Berries:
  - Cheri, Chesto, Pecha, Rawst, Aspear, Persim, and Lum Berries now cure the matching status/confusion from generic `held_auto_use` hooks and consume the held Berry.
  - Oran and Sitrus Berries now heal at low HP; Figy/Wiki/Mago/Aguav/Iapapa now use the pinch-heal hook.
  - Liechi, Ganlon, Salac, Petaya, Apicot, Lansat, Starf, Micle, and Custap now run pinch stat/crit/accuracy/priority behavior.
  - Occa, Passho, Wacan, Rindo, Yache, Chople, Kebia, Shuca, Coba, Payapa, Tanga, Charti, Kasib, Haban, Colbur, Babiri, and Chilan now reduce matching incoming damage through `damage_taken` hooks.
  - Enigma, Jaboca, and Rowap now run after-hit healing or retaliation through `held_auto_use` / `after_damage_taken` hooks.
- Held priority items:
  - Quick Claw now rolls from its generic `move_select/move_first_chance` hook.
  - Lagging Tail and Full Incense now move the holder later inside the same priority bracket.
- Registered inventory systems:
  - Key items have `key_item_registered` and `field_use/key_item_context` records.
  - Fossils have `fossil_restore` and `field_use/restore_fossil_species` records.
  - Crafting, curry, sandwich, picnic, Apricorn, and TM material items have crafting or field-use registry records.
  - Mega Stones, Z-Crystals, Dynamax crystals, memories, drives, and species-specific form items have transformation/form registry records.
- Full item grouping coverage:
  - All 2180 loaded CSV items now have runtime groups.
  - No `_pending` runtime buckets remain.

## Dialog Implemented

- Bag direct-use dialog starts with `YOU used ITEM!`.
- Party-target item use now includes the `YOU used ITEM!` line after the Pokemon target is chosen.
- Item effect messages are appended from `scr_apply_item_effects(...)`, including healing, revive, status cure, PP restore, EV change, level-up, evolution, X item, Dire Hit, and Guard Spec lines.
- Healing/status/revive item result text now uses Pokemon battle-style lines:
  - `POKEMON's HP was restored.`
  - `POKEMON recovered from fainting!`
  - `POKEMON became healthy.`
  - `POKEMON was cured of paralysis.`
  - `POKEMON's burn was healed.`
- Direct battle items now show all returned effect messages, not only the first one.
- Repel and encounter-rate items now show a specific field-effect line instead of only `It took effect.`

## Runtime Registered

- Held passive battle items: runtime groups/actions now exist, and the first major batch of battle hooks is live. The rest are registered through `held_passive_registered`/`held_auto_use` so they are no longer unknown.
- Berries as held auto-use: runtime marks all Berries as `berry`, `held_consumable`, and `berry_trigger`, with generic `held_auto_use/berry_trigger` records.
- Runtime Berry patch: high-impact held Berries now also have exact hooks and live battle consumers for status cures, HP recovery, pinch boosts, type-resist damage reduction, Enigma healing, Jaboca/Rowap retaliation, Micle accuracy, and Custap priority.
- Battle choice/lock items: Choice Band, Choice Specs, and Choice Scarf now apply stat multipliers and consume their generic `move_select` lock.
- Priority-held items: Quick Claw, Lagging Tail, and Full Incense now run through generic `move_select` records.
- Type-boost items and plates: common boosters, plates, incenses, Muscle Band, and Wise Glasses are grouped under `held_type_boost` and now apply generic damage multipliers.
- Weather rocks, terrain extenders, Light Clay-style duration items: runtime actions are registered and consumed; legacy name/id checks remain only as fallback compatibility.
- Mega stones, Z-Crystals, Dynamax/Gigantamax-style items: registered as transformation or raid-access records.
- Form-change key items: registered as `form_or_type_change_item` records.
- Mail and cosmetic key items: storage/UI only, no gameplay effect yet.
- Category fallback items: grouped for tracking and exposed through generic registry actions.

## Follow-Up Audit

No item is unconverted or marked pending. Future polish is about deeper mechanic fidelity, not loader coverage:

- Complete automatic Berry trigger timing for every battle condition.
- Full item-specific battle messages for every passive held-item trigger.
- Full transformation flow for Mega Evolution, Z-Moves, Tera, and Dynamax.
- Fossil restoration UI/object flow.
- Bike/rod/field-tool key item object interactions.
- Save/load persistence audit for every new item-side state field.

## Editing Guide

- Add broad item grouping/action rules in `data_load_item_runtime_structs()` and its helper classifier functions.
- Add new parsed item effect families in `data_load_item_effects_structs()`.
- Apply target effects in `scr_apply_item_effects(...)`.
- Decide whether an item opens the party, acts directly, or queues a battle action in `bag__use_item_on_self(...)`.
- Put party-target result text in `party_input.gml` under `mode = "select_item"`.
- Put held passive battle hooks near the battle system that owns the timing, and read the item through `item_runtime_actor_held_actions(actor, hook)` instead of adding new name/id checks.
