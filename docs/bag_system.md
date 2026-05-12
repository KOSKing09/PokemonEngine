# Bag System

This guide covers how the bag is booted, which public helpers are safe to call, how the bag behaves in and out of battle, and where to edit layout versus logic versus text sourcing.

## Runtime contract

- Boot once with `bags_init(playerCount)`.
- Call `bags_seed_from_items(pid)` or `bags_seed_all()` after changing inventory quantities so the visible page rows stay in sync with `sys_qty`.
- Call `bags_update()` every Step.
- Call `bag_draw_gui(pid)` or `bag_draw_gui_rect(pid, x, y, w, h)` from Draw GUI.
- Use `bag_open_for_battle(pid)` instead of `bag_open(pid)` when the bag is opened from battle input so mode-specific behavior is set up correctly.

## Public API

- `bags_init(players)` initializes `global.BAGS` and ensures each player has a bag struct.
- `bag_inventory_ensure(pid)` returns the canonical bag struct for that player.
- `bag_inventory_get_qty(pid, itemId)` reads quantity from `sys_qty`.
- `bag_inventory_set_qty(pid, itemId, qty)` writes quantity into `sys_qty`.
- `bag_inventory_add_item(pid, itemId, qtyAdd)` and `bag_inventory_remove_item(pid, itemId, qtyRem)` mutate quantities.
- `bags_seed_from_items(pid)` rebuilds the five visible bag pages from `sys_qty` and item metadata.
- `bag_is_open(pid)`, `bag_open(pid)`, `bag_close(pid)`, and `bag_toggle(pid)` manage visibility.
- `bag_open_for_battle(pid)` opens the bag in `mode = "battle"` and resets submenu state.
- `bag_draw_gui(pid)` and `bag_draw_gui_rect(pid, rx, ry, rw, rh)` are the stable draw entrypoints.

## State shape

Each `global.BAGS[pid]` slot is a struct created by `bag__default_bag()`.

Common fields:

- `open`: whether the bag UI is visible
- `mode`: usually `"bag"` or `"battle"`
- `page`: current pocket index `0..4`
- `sel`: selected row within the current page
- `scroll`: first visible row in the current page list
- `items`: five arrays of visible row structs used by the UI
- `sys_qty`: quantity table indexed by item id
- `item_menu_open`, `item_menu_sel`, `item_menu_row`: submenu state for `Use/Give/Discard/Cancel`
- `lock`: short input lock used during transitions
- `give_from_party`, `give_to_mon`: temporary flags used when the party menu sends the player into the bag to choose a held item

Visible item rows created by `bags_seed_from_items(pid)` look like:

```gml
{
    name: "Potion",
    real_name: "potion",
    qty: 3,
    desc: "Restores HP.",
    icon: spr_or_external_icon,
    item_id: 17
}
```

## Ownership map

- `scripts/bag_system/bag_system.gml`: bag state, inventory helpers, row seeding, item metadata helpers, and battle-aware use flow
- `scripts/bag_input/bag_input.gml`: open/close input, page navigation, selection movement, and item submenu actions
- `scripts/bag_draw/bag_draw.gml`: layout, description box, list rendering, submenu drawing, and scaling inside the 240x160 GUI canvas
- `scripts/bag_utils/bag_utils.gml`: shared helper logic used by the bag stack

## Where To Edit

- Add or change inventory storage rules: `bag_inventory_*` helpers in `scripts/bag_system/bag_system.gml`
- Change how items are assigned to pockets: `bag__item_to_page(...)` in `scripts/bag_system/bag_system.gml`
- Change which description text is shown for items: `bag__resolve_item_desc(...)` in `scripts/bag_system/bag_system.gml`
- Change holdable-item or battle-usable rules: `bag__resolve_item_flags(...)`, `bag__item_is_holdable(...)`, and `bag__use_item_on_self(...)`
- Change button behavior, page wrapping, or submenu navigation: `scripts/bag_input/bag_input.gml`
- Change bag layout, icon placement, list rows, or description box rendering: `scripts/bag_draw/bag_draw.gml`

## Description behavior

The bag does not have a standalone description-menu system. Item prose is resolved during row seeding, stored on each visible row as `row.desc`, and drawn by `__bag_impl_draw_description(...)`.

Text flow:

1. `bag__resolve_item_desc(itemId)` pulls prose from `global._item_prose` or `global._item_text`.
2. `bag__clean_item_text(...)` strips markup and normalizes whitespace.
3. `bags_seed_from_items(pid)` copies the cleaned prose into each row's `desc` field.
4. `__bag_impl_draw_description(...)` wraps and truncates the selected row's `desc`.

If you want scrolling instead of truncation, the owning seam is `__bag_impl_draw_description(...)` in `scripts/bag_draw/bag_draw.gml`.

## Battle bag flow

When the bag is opened from battle, use `bag_open_for_battle(pid)`.

Key behavior:

- `mode` changes to `"battle"`
- item submenu choices still come from `bag_input.gml`
- `Use` routes into `bag__use_item_on_self(pid, row)`
- Poke Balls are queued as battle actions, not resolved immediately in the UI layer
- healing and revive-style items can hand off to the party UI by opening `party_open(pid)` and populating `P.use_pending`

This split is important: bag code decides what item action to queue, but battle and party code finish the action in their own state machines.

## CSV Item Behaviors

The bag now uses the CSV data for both medicine-style items and machines.

- `data/csv/item_prose.csv` is parsed by `data_load_item_effects_structs()` into `global._item_effects`.
- `scripts/scr_apply_item_effects/scr_apply_item_effects.gml` applies supported effects: HP restore, full restore, revive, status cure, PP restore, EV vitamins/reducers, Rare Candy level-up, PP Up/PP Max, item evolution, and battle X-item boosts.
- `data/csv/machines.csv` is parsed by `data_load_machine_moves_structs()` into `global._machine_item_to_move[item_id]`.
- `data/csv/pokemon_moves.csv` is also parsed for method `4` rows, producing `global._species_machine_moves[species_id]` for TM/HM compatibility checks.
- Machine lookup prefers Emerald's `version_group_id = 6` when the same TM/HM item id appears in multiple generations.

TM/HM use flow:

1. Bag `Use` detects a machine item with `bag__machine_move_id(item_id, item_struct)`.
2. The bag closes and opens the player's party in `mode = "select_item"` with `P.teach_pending`.
3. Party input checks `party__machine_can_teach(mon, move_id)`.
4. If the Pokemon has room, `scr_move_learn_try(...)` teaches immediately.
5. If four moves are already known, the party enters `summary_forget` and teaches the pending machine move after the player chooses a move to replace.
6. TMs consume one item after a successful learn; HMs do not.

Other direct-use CSV items:

- Vitamins, wings, EV-reducing berries, Rare Candy, PP Up/PP Max, medicine, and evolution stones open the party selector.
- Poke Doll, Fluffy Tail, and Poke Toy end wild battles.
- Repel/Lure-style field items store per-player overworld encounter modifiers in `global.BAG_FIELD_EFFECTS`.
- X Attack/X Defense/X Speed/X Accuracy/X Sp. Atk/X Sp. Def, Dire Hit, and Guard Spec apply to the active battler during battle.
- Held-only/passive items remain handled through the existing `Give` flow; their battle passives are not simulated by the bag use button.

## Copyable examples

Initialize and seed a debug bag:

```gml
bags_init(1);
bag_inventory_add_item(0, 17, 5);
bag_inventory_add_item(0, 4, 10);
bags_seed_from_items(0);
```

Open the bag manually from code:

```gml
if (!bag_is_open(0)) {
    bag_open(0);
}
```

Open the battle-aware bag:

```gml
if (battle_is_open(0)) {
    bag_open_for_battle(0);
}
```

Change an item description source:

```gml
function bag__resolve_item_desc(_iid){
    var txt = "";
    if (variable_global_exists("_item_text") && is_array(global._item_text) && _iid < array_length(global._item_text)){
        var rec = global._item_text[_iid];
        if (is_struct(rec) && variable_struct_exists(rec, "short_desc")) txt = rec.short_desc;
    }
    return bag__clean_item_text(txt);
}
```

## Practical rules

- Treat `sys_qty` as the source of truth for inventory counts. The visible `items` arrays are cached UI rows.
- After changing counts, reseed the bag pages before expecting the UI to show the change.
- Keep bag input in `bag_input.gml` and bag rendering in `bag_draw.gml`; do not grow `bag_system.gml` with layout code unless a helper truly needs state access.
- If a new item behavior depends on battle state, queue it into battle rather than resolving everything directly in the submenu handler.
