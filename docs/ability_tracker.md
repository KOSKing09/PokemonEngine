# Ability Tracker

Last updated: 2026-05-16

This tracker is for the CSV-driven ability system in `data_load_ability_effects_structs()` and `__ability_effect_apply_known_tags(...)`.

Counts from the current loader:

- Total abilities in `abilities.csv`: 367
- Abilities with custom grouping cases: 367
- Unique ability groups: 161
- Runtime-active or partially active grouped abilities: at least 225
- Grouped but still awaiting the rest of the battle/field/overworld code: about 142
- Not custom-grouped yet: 0

Status meanings:

- `runtime-active`: the ability has at least one current battle/runtime path using its group or action.
- `grouped-awaiting-code`: the ability is classified into groups/actions, but still needs one or more runtime hooks before it behaves correctly.
- `not-grouped-yet`: the CSV data and prose are loaded, but no custom grouping case exists yet.

## Runtime Hook Batch - 2026-05-16

Added generic runtime consumers for a large chunk of the grouped ability actions:

- Damage dealt: contact boosts, low-power boosts, move-keyword boosts (punch/bite/pulse/slicing style), recoil-move boosts, secondary-effect boosts, sound-move boosts, type/aura/weather type boosts, critical-hit boosts, and same/different sex modifiers.
- Damage taken: type multipliers, sound-move multipliers, and defensive conditional reducers like full-HP shields, Fluffy-style contact/fire behavior, and Ice Scales-style special reduction.
- Stat calculation: status-based special attack, HP-threshold attack/special attack, weather special attack, and sun party attack/special defense modifiers.
- Speed and priority: item-loss speed boosts, terrain speed boosts, random quick-move priority, and Stall-style move-last priority.
- Entry effects: terrain setters, special-weather setters, screen clearing, item reveal, move reveal, and danger-sense dialog hooks.
- End turn: Speed Boost-style stage changes, weather healing, Poison Heal-style status healing, weather damage, Shed Skin-style random cures, Hydration-style weather cures, and Bad Dreams-style sleeping-opponent damage.
- After-hit/contact: Stench-style flinch bonus and Poison Touch-style contact-dealt status.

This does not mean every ability is perfect yet. It means these grouped abilities now have real battle-loop entry points instead of being data-only. The remaining grouped abilities mostly need field, item, switch, overworld, form-change, ally/double-battle, or very custom one-off behavior.

## Runtime Hook Batch - 2026-05-16, Pass 2

Added the next group of runtime consumers:

- Accuracy/evasion: Compound Eyes, Hustle's physical accuracy penalty, Sand Veil, Snow Cloak, tangled/confusion-style evasion hooks, terrain evasion hooks, and No Guard routing through the generic action table.
- Switching/trapping: Arena Trap, Shadow Tag, Magnet Pull, and custom trap groups now block both player switching and trainer AI switching through the shared switch-check hook.
- Secondary effects: Serene Grace-style secondary chance multipliers and Shield Dust-style secondary blocking now feed into the shared move-meta status/ailment chance path.
- Recoil/drain: Rock Head-style recoil blocking and Liquid Ooze-style drain reversal now run through the shared drain/recoil move-meta path.

Remaining caveat: some secondary effects are stat-change-only or custom move scripts, so they may need one more pass outside the move-meta status path.

## Runtime Hook Batch - 2026-05-16, Pass 3

Added another set of runtime consumers:

- Stage changes: Simple-style doubled stage changes, Contrary-style inverted stage changes, stat-lowering immunity, and Defiant/Competitive-style reactions now live in the shared stage-change helper.
- Switch-out effects: Natural Cure and Regenerator now run when the player or trainer switches out an active Pokemon.
- PP pressure: Pressure-style extra PP consumption now resolves from the opposing active Pokemon when a move consumes PP.
- Move target filtering: Damp, Soundproof, Bulletproof, Overcoat/powder blocks, and Magic Bounce-style status blocking now have a generic move-target filter before damage is applied.

Remaining caveat: generic stage reactions do not yet distinguish the original source in every old move path, so `opponent_only` reactions are active but conservative. Move target filtering uses move identifiers as a fallback until move flags are fully imported.

## Runtime Hook Batch - 2026-05-16, Pass 4

Added the held-item and Berry runtime consumers:

- Item checks: Klutz-style held-item suppression now disables generic held item effects, Unnerve-style effects block opposing Berry use, and Ripen-style effects multiply Berry item results.
- Berry consumption: Cheek Pouch heals after a Berry is eaten, Harvest restores a previously consumed Berry at end turn, and Cud Chew marks a consumed Berry for next-turn reuse without looping forever.
- Item removal: Sticky Hold-style protection now blocks Knock Off and Pluck/Bug Bite-style Berry stealing/removal through the shared item-removal hook.

Remaining caveat: Gluttony-style early automatic Berry consumption still needs a dedicated held-item auto-use trigger for pinch Berries. This pass wires the item/berry ability hooks that already have item-use entry points.

## Runtime Hook Batch - 2026-05-16, Pass 5

Added the next runtime consumers:

- Turn-order and switch-in damage: Analytic now boosts damage when the user is marked as moving last, and Stakeout now boosts damage against Pokemon that switched in that turn.
- Type damage boosts: Steelworker, Steely Spirit, Rocky Payload, Transistor, and Dragon's Maw now resolve through the generic type damage multiplier path even when the CSV group data does not name the type explicitly.
- Entry stage events: Download compares opposing Defense vs. Sp. Def and boosts Attack or Sp. Atk on entry. Intrepid Sword and Dauntless Shield now run their entry stat boosts.
- End-turn stage events: Moody now raises one random stat by two stages and lowers a different random stat by one stage at end turn.
- After-hit reactions: Berserk, Anger Shell, Cotton Down, Gooey, Tangling Hair, Sand Spit, Perish Body, Wandering Spirit, and Lingering Aroma now have battle reactions after damage/contact.
- Threshold switching: Wimp Out and Emergency Exit now try to force a switch when damage drops the Pokemon below half HP.

Remaining caveat: forced switching is wired to the current player/trainer switch helpers, so double-battle edge cases may still need a dedicated chooser for the exact affected slot.

## Runtime Hook Batch - 2026-05-16, Pass 6

Added another generic runtime layer:

- Move type conversion: Normalize, Refrigerate, Pixilate, Aerilate, Galvanize, and Liquid Voice now convert move type through `scr_move_type_id_by_id(...)` and apply the expected damage boost.
- Critical-hit hooks: Super Luck adds a critical stage, and Merciless forces high critical chance against poisoned or badly poisoned targets.
- Multi-hit and turn checks: Skill Link forces max hits through the multi-hit resolver, and Truant skips every other move action.
- Status/volatile reactions: Synchronize reflects major status back to the source, and Steadfast reacts when flinch is consumed.
- First-hit and faint hooks: Disguise/Decoy-style first-hit guard now blocks the first damaging hit, Innards Out reflects last damage on faint, and Explode-style faint actions damage nearby battlers.
- Barrier and extra-hit hooks: Infiltrator bypasses Reflect/Light Screen/Aurora Veil damage reduction, and Parental Bond adds a second reduced hit.
- Type reactions: Earth Eater, Well-Baked Body, Thermal Exchange, Electromorphosis, Wind Power, and Wind Rider now have runtime reactions for their matching incoming move types.

Remaining caveat: this pass gives these groups battle-runtime behavior. Visual form swaps, exact species-specific form tables, and some advanced doubles/ally routing still need dedicated systems beyond the generic ability runner.

## Runtime Hook Batch - 2026-05-16, Pass 7

Added ally/global stat support:

- Ally damage support: Battery, Power Spot, and Friend Guard now apply through the generic damage multiplier pass.
- Aura abilities: Dark Aura and Fairy Aura now boost matching move types while Aura Break reverses those aura boosts.
- Ruin auras: Sword of Ruin, Beads of Ruin, Tablets of Ruin, and Vessel of Ruin now apply approximate physical/special battle-side modifiers.
- Stat modifiers: Slow Start now affects early-turn Attack and Speed, Gorilla Tactics applies its Attack boost, Grass Pelt boosts Defense on Grassy Terrain, and Plus/Minus boost Special Attack when a matching ally is active.

Remaining caveat: these are generic battle-runtime hooks. Exact doubles targeting, choice-lock enforcement, and full Ruin holder-exclusion details may still need one more dedicated validation pass.

## Runtime-Active Or Partial

- adaptability, aftermath, air-lock, anger-point, battle-armor, beast-boost, blaze, chilling-neigh
- anticipation, aqua-boost, aura-break, bad-dreams, battery, beads-of-ruin, big-pecks, bulletproof, chlorophyll, clear-body
- cute-charm, damp, dark-aura, defeatist, dragons-maw, drizzle, drought, dry-skin, effect-spore
- competitive, contrary, defiant, flame-body, flame-boost, flare-boost, flash-fire, flower-gift
- fairy-aura, forewarn, friend-guard, frisk, frostbite, natural-cure, regenerator, pressure, simple, magic-bounce
- full-metal-body, fur-coat, gale-wings, grim-neigh, guts, hadron-engine, heatproof, herbivore
- gorilla-tactics, grass-pelt, huge-power, hustle, hyper-cutter, ice-body, immunity, inner-focus, insomnia, intimidate
- iron-barbs, iron-fist, jagged-edge, justified, keen-eye, levitate, lightning-rod, limber
- magic-guard, magma-armor, marvel-scale, mega-launcher, melee, motor-drive, mountaineer, mummy
- minus, no-guard, neuroforce, oblivious, overcoat, overgrow, own-tempo, poison-heal, poison-point
- plus, poison-touch, power-spot, prism-armor, prankster, pure-power, quick-draw, quick-feet, rain-dish, rattled
- reckless, rivalry, rock-head, sand-force, sand-rush, sand-stream, sand-veil, sap-sipper
- screen-cleaner, scrappy, serene-grace, shadow-tag, snow-cloak, compound-eyes, arena-trap, magnet-pull
- seed-sower, sharpness, shed-skin, sheer-force, shell-armor, shield-dust, slush-rush, sniper
- slow-start, snow-warning, solar-power, soul-heart, soundproof, speed-boost, sponge, stall, stamina
- static, steam-engine, stench, storm-drain, strong-jaw, surge-surfer, swarm, sweet-veil, sword-of-ruin
- swift-swim, technician, thick-fat, tinted-lens, torrent, tough-claws, triage, thrust
- tablets-of-ruin, toxic-boost, liquid-ooze, unburden, vessel-of-ruin, vital-spirit, volt-absorb, warm-blanket, water-absorb, water-bubble, water-compaction
- water-veil, weak-armor, white-smoke, wind-power, wonder-guard
- cheek-pouch, cud-chew, harvest, klutz, ripen, sticky-hold, unnerve
- analytic, anger-shell, berserk, cotton-down, dauntless-shield, download, emergency-exit, gooey
- intrepid-sword, lingering-aroma, moody, perish-body, rocky-payload, sand-spit, stakeout
- steelworker, steely-spirit, tangling-hair, transistor, wandering-spirit, wimp-out
- aerilate, decoy, disguise, earth-eater, electromorphosis, explode, galvanize, infiltrator
- innards-out, liquid-voice, merciless, normalize, parental-bond, pixilate, refrigerate, skill-link
- steadfast, synchronize, thermal-exchange, truant, well-baked-body, wind-rider

## Grouped Awaiting Runtime Code

This backlog list is intentionally conservative after the 2026-05-16 runtime hook batch. Some entries here now have partial runtime support through a generic hook but still need their last custom behavior, field behavior, item behavior, switch behavior, form behavior, ally behavior, or overworld behavior.

- anticipation, aqua-boost, arena-trap, armor-tail, aroma-veil
- as-one-glastrier, as-one-spectrier, bad-dreams, ball-fetch, battle-bond
- big-pecks, black-hole, bodyguard, bonanza, bulletproof, calming, celebrate
- climber, color-change, comatose, commander, competitive, compound-eyes, confidence
- conqueror, contrary, corrosion, costar, curious-medicine, cursed-body
- damp, dancer, daze, dazzling, deep-sleep
- defeatist, defiant, delta-stream, desolate-land, disgust, dodge
- early-bird, electric-surge, embody-aspect
- flame-boost, flare-boost, flower-gift, flower-veil, fluffy, forecast, forewarn
- fortune, frighten, frisk, frostbite, gluttony, good-as-gold
- grass-cloak, grassy-surge, guard-dog, gulp, gulp-missile
- hadron-engine, healer, heavy-metal, herbivore, hero, high-rise, honey-gather
- hospitality, hot-blooded, hunger-switch, hustle, hydration, ice-body, ice-face, ice-scales
- illuminate, illusion, imposter, instinct, interference
- iron-fist, jagged-edge, keen-eye, last-bastion, leaf-guard, libero, life-force
- light-metal, liquid-ooze, long-reach, lullaby, lunchbox, magic-bounce
- magician, magnet-pull, medic, mega-launcher, melee, mimicry, minds-eye
- mirror-armor, misty-surge, mold-breaker, mood-maker, mountaineer, multiscale
- multitype, mycelium-might, natural-cure, neuroforce, neutralizing-gas, nomad, nurse
- omnipotent, opportunist, orichalcum-pulse, parry, pastel-veil, perception
- pickpocket, pickup, poison-heal, poison-puppeteer, poison-touch, power-construct
- power-nap, power-of-alchemy, prankster, pressure, pride, primordial-sea, propeller-tail
- protean, protosynthesis, psychic-surge, punk-rock, purifying-salt, quark-drive, queenly-majesty, quick-draw
- rain-dish, receiver, reckless, regenerator, rivalry, rks-system
- rock-head, run-away, run-up, sand-force, sand-veil, sandpit
- schooling, screen-cleaner, seed-sower, sequence, serene-grace, shackle, shadow-dash, shadow-shield
- shadow-tag, share, sharpness, shed-skin, sheer-force, shield, shield-dust, shields-down
- simple, skater, sniper, snow-cloak, solar-power, soul-heart
- speed-boost, spirit, sponge, sprint, stall, stalwart, stance-change
- stealth, stench, strong-jaw, suction-cups
- supersweet-syrup, supreme-overlord, surge-surfer, symbiosis
- tangled-feet, technician, telepathy, tenacity, tera-shell, tera-shift, teraform-zero
- teravolt, thrust, tough-claws, toxic-boost, toxic-chain, toxic-debris, trace
- turboblaze, unaware, unburden, unseen-fist, vanguard
- victory-star, vital-spirit, warm-blanket, wave-rider, weak-armor
- wind-power, wonder-skin, zen-mode, zero-to-hero

## Not Grouped Yet

- None

## Unique Groups

- ability_ignore
- accuracy_drop_immunity
- accuracy_evasion_custom
- accuracy_modifier
- accuracy_override
- after_hit_move_disable
- after_hit_or_contact_reaction
- after_hit_stage_boost
- after_hit_stage_change
- ally_field_support
- ally_guard
- ally_heal_support
- ally_reaction
- aura_modifier
- barrier_bypass
- base_power_damage_boost
- berry_effect_modifier
- berry_heal_bonus
- berry_lock
- berry_restore_chance
- berry_reuse
- berry_threshold_modifier
- choice_lock_stat_boost
- consecutive_action_modifier
- contact_ability_replace
- contact_damage_boost
- contact_dealt_status
- contact_punish_damage
- contact_punish_status
- contact_punish_volatile
- contact_rule_modifier
- crit_immunity
- critical_condition_modifier
- critical_damage_modifier
- critical_hit_reaction
- critical_rate_modifier
- damage_or_type_reaction
- drain_reversal
- end_turn_stage_boost
- entry_ability_copy
- entry_danger_sense
- entry_defense_compare_boost
- entry_disguise
- entry_field_clear
- entry_item_reveal
- entry_move_reveal
- entry_or_aura_status_modifier
- entry_or_contact_debuff
- entry_stage_opponents
- entry_terrain
- entry_transform
- entry_weather
- escape_modifier
- escape_or_speed_modifier
- extra_hit_modifier
- faint_contact_punish_damage
- faint_damage_reflect
- faint_explosion
- faint_stage_boost
- field_damage_modifier
- first_hit_guard
- food_item_modifier
- forced_switch_immunity
- form_change
- gender_damage_modifier
- held_item_suppression
- hp_stat_or_heal_modifier
- hp_threshold_stat_modifier
- hp_threshold_switch
- indirect_damage_immunity
- intimidate_immunity
- item_loss_speed_boost
- item_removal_immunity
- item_steal
- ko_best_stat_boost
- ko_form_change
- ko_stage_boost
- low_hp_type_boost
- morale_stage_modifier
- move_explosion_block
- move_flag_immunity
- move_reflect_or_block
- move_secondary_chance
- move_tag_damage_boost
- move_type_conversion
- multi_hit_modifier
- not_very_effective_damage_boost
- overworld_encounter_modifier
- overworld_movement_modifier
- post_battle_item_find
- powder_move_immunity
- pp_pressure
- priority_modifier
- recoil_immunity
- reward_modifier
- secondary_effect_damage_boost
- secondary_effect_immunity
- sleep_heal_or_power
- sleep_target_residual_damage
- sleep_turn_modifier
- sound_move_damage_modifier
- special_rule
- special_weather
- stab_modifier
- stage_change_modifier
- stage_event_modifier
- stage_ignore
- stat_drop_reaction
- stat_lowering_immunity
- stat_multiplier
- status_cure_chance
- status_evasion_modifier
- status_heal
- status_immunity
- status_model_override
- status_move_accuracy_modifier
- status_reflect
- status_speed_multiplier
- status_stat_multiplier
- status_type_bypass
- super_effective_damage_boost
- super_effective_damage_reduce
- super_effective_only_damage
- survive_full_hp_ko
- switch_heal
- switch_in_damage_boost
- switch_status_cure
- team_state_damage_modifier
- terrain_evasion_modifier
- terrain_or_field_speed_multiplier
- terrain_speed_multiplier
- terrain_stat_multiplier
- trapping
- turn_limited_stat_modifier
- turn_order_chance
- turn_order_damage_boost
- turn_order_modifier
- turn_skip_cycle
- type_absorb_heal
- type_absorb_stage
- type_block_boost
- type_change
- type_damage_dealt_multiplier
- type_damage_taken_multiplier
- type_hit_stage_boost
- type_immunity
- type_immunity_bypass
- volatile_immunity
- volatile_reaction_stage_boost
- weather_damage_immunity
- weather_evasion_modifier
- weather_heal
- weather_party_stat_multiplier
- weather_residual_damage
- weather_speed_multiplier
- weather_stat_multiplier
- weather_status_cure
- weather_status_immunity
- weather_suppress
- weather_type_damage_boost
- weight_modifier

## How To Update This Tracker

1. Add or update cases in `__ability_effect_apply_known_tags(...)`.
2. If the group already has runtime support, move the ability to `Runtime-Active Or Partial`.
3. If the ability only has a group/action record, put it in `Grouped Awaiting Runtime Code`.
4. If an ability has no case yet, leave it in `Not Grouped Yet`.
5. Run the game once and confirm the debug line: `[DATA][ability_effects] rows=367 groups=<count>`.
