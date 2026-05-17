# PC Breeding System

Owner: `scripts/pc_system/pc_system.gml`

The breeding system is an Emerald-style nursery that lives inside the PC. It is opened from the pause menu through:

`MISC -> BREEDING`

Egg storage is opened separately through:

`MISC -> EGGS`

## Player Flow

1. Open `MISC -> BREEDING`.
2. Pick up Pokemon from the normal PC box grid, or press `Inventory` to switch the right panel between `BOX` and `PARTY`.
3. Move left into the `BREED` panel.
4. Place Pokemon into any of the six pair rows. Each row has two parent slots.
5. If a row has one male and one female, a muted purple outlined heart appears so you know the gender match was detected, but the pair cannot make Eggs yet.
6. If that male/female pair also shares an Egg Group, the outlined heart turns red and the pair can make Eggs.
7. Finish battles to advance the nursery timer.
8. When an Egg is produced, it goes into the Egg Box.
9. Egg hatch timers also advance after battles.
10. When an Egg hatches, the hatched Pokemon is automatically moved into a normal PC box.
11. Open `MISC -> EGGS` to inspect stored Eggs and see their remaining hatch battle counts.

## Controls

- `Inventory`: while in breeding mode, switches the right-side picker between the active PC box and the player's party.
- `PageUp` / `PageDown`: cycles PC boxes when the right-side picker is using boxes.
- Move left from the picker to reach the `BREED` panel.
- Move up/down in the `BREED` panel to switch between pair rows.
- Move left/right in the `BREED` panel to switch between that row's two parent slots. Press right again from the second slot to return to the picker.
- Press `Interact` to pick up, place, or swap Pokemon.
- To remove a parent from breeding, pick it up from the `BREED` panel, press right to return to the picker, press `Inventory` if you want the party picker, then place it into an empty PC or party slot.
- Picking up, placing, or swapping Pokemon in the PC/breeding UI plays `snd_pickup`. Cursor movement still uses the normal selector sound.

In `MISC -> EGGS`, the Egg Box is view-only. Move around the grid to inspect Eggs. The number drawn on each Egg is its remaining battle count before hatching.

## Compatibility Rules

Current runtime rules:

- The two parents must be one male and one female.
- Eggs cannot breed.
- The two parents must share at least one egg group.
- The Undiscovered / no-eggs group is ignored for matching.
- Ditto special-case breeding is not implemented yet because this first version follows the requested different-gender setup.

Heart colors:

- Purple outlined heart / `M/F`: the two slots are one male and one female, but they are missing Egg Group compatibility. They cannot produce Eggs.
- Red outlined heart: the two slots are one male and one female and share a valid Egg Group. This pair can produce Eggs.

## Egg Species

The Egg Pokemon is chosen from the female parent. The system takes the female parent's species, then walks backward through `pokemon_species.csv` using `evolves_from_species_id` until it reaches the base species.

Examples:

- Female Charizard + compatible male: Egg species becomes Charmander.
- Female Raichu + compatible male: Egg species becomes Pichu or Pikachu depending on how that evolution line is represented in the CSV data.
- Female Pidgeotto + compatible male: Egg species becomes Pidgey.

The CSV data controls this flow:

- `pokemon_egg_groups.csv`: decides whether the two parents can breed together.
- `pokemon_species.csv` column `evolves_from_species_id`: lets the system walk the female parent's evolution line back to the baby/base species.
- `pokemon_species.csv` column `hatch_counter`: decides how long the Egg takes to hatch, converted into battle counts.
- `natures.csv`: supplies the random nature pool used when neither parent passes nature through Everstone.

## Nature Inheritance

Nature does not affect whether two Pokemon can breed.

When an Egg is created:

- If neither parent holds Everstone, the Egg gets a random nature from the loaded nature table.
- If one parent holds Everstone, the Egg inherits that parent's nature.
- If both parents hold Everstone, the Egg randomly inherits one of those two parent natures.

Everstone is detected by item id `206` or by held item name `everstone`.

## Timers

This project uses battles instead of steps. Each compatible red-heart pair has its own wait timer:

- Same species compatible pair: Egg after about `2` completed battles.
- Same egg group but different species: Egg after about `4` completed battles.
- Egg hatch time is based on the species `hatch_counter` from `pokemon_species.csv`, converted into battle counts and clamped between `3` and `10` battles.

The mating timer only advances after completed battles. Walking around does not advance it right now. The timers advance from `battle_close(pid)` through `pc_breeding_on_battle_complete(pid)`.

When a compatible pair produces an Egg, that pair's wait timer resets to its normal wait amount so it can produce another Egg after more battles.

Creating an Egg plays `snd_Receive_Egg`.

## Egg Box

Eggs are stored on the PC state:

- `global.SYS_PC[pid].sys_egg_box`
- `global.SYS_PC[pid].sys_breed_slots`
- `global.SYS_PC[pid].sys_breed_wait_battles`
- `global.SYS_PC[pid].sys_breed_heart`

This is intentionally separate from the normal storage boxes. Eggs do not take normal box slots until they hatch. When an Egg hatches, it is removed from `sys_egg_box` and the new Pokemon is stored through `pc_store_mon_to_box_info(pid, mon)`.

You do receive Eggs automatically, but they go into the Egg Box instead of the party. The breeding screen shows the Egg count, and `MISC -> EGGS` opens the Egg Box directly. After enough completed battles, the Egg hatches automatically and the hatched Pokemon appears in normal PC storage.

## Player-Born Boost

Hatched Pokemon are marked:

- `player_born = true`
- `player_born_bonus = true`
- `bred_in_pc = true`

They also get a strong starter boost:

- every IV is raised to at least `20`
- every EV stat starts at `32`
- `ev_total` starts at `192`

After the boost is applied, the hatched Pokemon's stats are recalculated with its IVs, EVs, level, and nature. This makes PC-bred Pokemon meaningfully stronger than most wild Pokemon without needing a separate item or daycare reward flow.

## Main Functions

- `pc_open_breeding(pid)`: opens the PC directly in nursery mode.
- `pc_open_eggs(pid)`: opens the PC directly in Egg Box mode.
- `pc_breeding_on_battle_complete(pid)`: advances Egg generation and Egg hatching after a battle.
- `pc__breeding_compatibility(a, b)`: checks gender and egg-group compatibility.
- `pc__breeding_make_egg(pid, compat)`: creates an Egg in the Egg Box.
- `pc__breeding_hatch_egg(pid, egg)`: creates the hatched Pokemon and stores it in the normal PC.

## Files Used

The system lazily reads:

- `data/csv/pokemon_egg_groups.csv`
- `data/csv/pokemon_species.csv`

Those tables are cached into:

- `global._breeding_egg_groups`
- `global._breeding_base_species`
- `global._breeding_hatch_counter`
