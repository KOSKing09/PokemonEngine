# Effect ID And Data Coverage Report

Date: 2026-05-11

## Summary

- The old report was stale. It only described an earlier effect-id scrape and did not reflect the later `moves.csv`, ability, and item data loader work.
- The move-data update was real and important: ordinary battle accuracy was being computed from `scr_move_accuracy_by_id(...)`, which reads `global._moves[mid].accuracy`. If the move loader reads that field incorrectly, the central hit gate is fed bad base values.
- The current loader pipeline now covers core moves, late move-meta backfills, abilities, species-ability links, items, item categories, item flags, item prose, and item effect structs.

## Accuracy Fix Status

- `scripts/PokemonDataLoaders/PokemonDataLoaders.gml::data_load_moves_structs()` now reads `accuracy` from the correct CSV column.
- The same loader now reads `damage_class_id` from the correct `damage_class_id` column instead of accidentally using `target_id`.
- `scripts/PokemonIndexSystem/PokemonIndexSystem.gml::scr_move_accuracy_by_id(...)` is the value source used by the battle hit gate through `__battle_move_accuracy(...)`.

Why this mattered:

- This was not a cosmetic data issue.
- If `global._moves[mid].accuracy` is wrong, standard move hit checks can be wrong even when the battle-side accuracy math is otherwise correct.
- If `damage_class_id` is wrong, later logic that branches on status versus physical versus special can also behave incorrectly.

Short version: yes, the accuracy glitch was real enough to affect live battles, because it sat under the shared move-data lookup used by the main battle accuracy path.

## Current Move Coverage

- `data_load_moves_structs()` loads core move rows including `accuracy`, `priority`, `target_id`, `damage_class_id`, `effect_id`, and `effect_chance`.
- `data_load_move_text_structs()` loads move flavor text.
- `data_load_species_moves_structs()` loads learnsets.
- `data_load_machine_moves_structs()` loads TM or HM style learn compatibility.
- `data_load_move_meta_structs()` and `data_load_move_meta_stat_changes_structs()` load structured move-meta CSV support when present.
- `data_map_move_effects_to_meta()` synthesizes legacy move-meta from effect prose heuristics.
- `data_map_late_moves_to_meta()` backfills newer `moves.csv` rows that were missing companion metadata in the shipped CSV set.

Late move-meta additions now explicitly cover newer rows such as:

- Dire Claw
- Stone Axe
- Victory Dance
- Population Bomb
- Snowscape
- Bitter Blade
- Tachyon Cutter
- Malignant Chain
- Silk Trap
- Burning Bulwark
- Axe Kick

Battle-side move handling added alongside that loader work:

- `scripts/battle_move_meta_helpers/battle_move_meta_helpers.gml` now supports random-status families such as Dire Claw.
- `scripts/battle_impls/battle_impls.gml` treats Silk Trap and Burning Bulwark as Protect-family moves.
- Miss recoil is wired for moves such as Axe Kick and Supercell Slam.

## Confirmed Effect-Id Families

The earlier report listed 40 confirmed handled effect-id families. The current move-meta backfill adds more confirmed families on top of that list.

Previously reported families:

`4, 30, 39, 43, 45, 49, 73, 78, 113, 199, 250, 254, 255, 263, 267, 270, 280, 325, 326, 327, 340, 341, 349, 351, 352, 353, 361, 367, 369, 392, 395, 415, 418, 419, 421, 422, 423, 424, 425, 1044`

Additional effect-id families now explicitly confirmed by the current late-move pass:

`1, 33, 40, 44, 51, 112, 203, 405`

That brings the confirmed handled family count in this report to at least 48.

Important caveat:

- This still is not the same thing as saying every move in the dataset has perfect battle semantics.
- Several newer moves are intentionally marked as partial support in comments where only the main battle behavior has been modeled so far.

## Current Ability Coverage

Ability data loading is now present and wired through the extended loader path:

- `data_load_abilities_structs()` loads core ability ids and identifiers.
- `data_load_ability_text_structs()` loads English ability flavor text.
- `data_load_species_abilities_structs()` links species to ability ids.

What this means in practice:

- The project now has structured ability data and localized prose available for UI and lookup code.
- This does not automatically mean every ability mechanic is fully implemented in battle logic; it means the loader-side coverage exists.

## Current Item Coverage

Item data coverage is also much broader than the old report showed. The extended loader path now calls:

- `data_load_items_structs()`
- `data_load_item_categorys_structs()`
- `data_load_machine_moves_structs()`
- `data_load_item_flag_prose_structs()`
- `data_load_item_flag_map_structs()`
- `data_normalize_item_flag_map()`
- `data_load_item_prose_structs()`
- `data_load_item_effects_structs()`

What this means in practice:

- Core item rows are loaded.
- Bag-pocket or category mapping is loaded.
- Item flags and human-readable flag prose are loaded and normalized.
- Item prose text is loaded.
- Structured item effects are derived for gameplay consumers.

Short version: the data side for items is no longer just a partial stub. The project now has a full item-data pipeline in the loader layer.

## What This Report Now Means

- Treat this document as a current coverage snapshot, not a claim that every mechanic in the game is fully feature-complete.
- On the moves side, the big change is that the core CSV loader is now feeding better base data into battle logic, and the late-move pass fills a real gap for newer move rows.
- On the abilities and items side, the big change is that the structured data pipelines are present and called from `data_load_all_structs_ext()`.

## Recommended Next Follow-Up

- If you want the canonical CSV audit to match this report, patch `datafiles/data/effect_id_audit_report.csv` with the reconciled statuses and locations for the newly confirmed families.
- If you want runtime confidence rather than loader confidence, extend the smoke suite with one or two focused tests for a late move, an ability lookup path, and one structured item-effect path.
