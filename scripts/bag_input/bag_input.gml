// Bag input module — handles bag opening, navigation, paging and spin ticks.
function __bag_impl_bags_update(){
    if (!variable_global_exists("BAGS")) return;
    var _players = array_length(global.BAGS); if (_players <= 0) return;

    for (var pid = 0; pid < _players; pid++) {
        var b = global.BAGS[pid]; if (!is_struct(b)) continue;

        if (controls_pressed(pid, "Inventory")) { b.open = !b.open; if (b.open) b.spin_ticks = 18; }
        if (!b.open) continue;

        // If the item submenu is open, suppress normal bag navigation so input is handled by submenu only
        if (variable_struct_exists(b, "item_menu_open") && b.item_menu_open){
            if (b.spin_ticks > 0) b.spin_ticks--;
            if (variable_struct_exists(b, "lock") && b.lock > 0) b.lock--;
            continue;
        }

        var lst = b.items[b.page];
        var n   = array_length(lst);

        if (controls_pressed(pid, "MoveDown") && (n > 0)) b.sel = clamp(b.sel + 1, 0, n - 1);
        if (controls_pressed(pid, "MoveUp")   && (n > 0)) b.sel = clamp(b.sel - 1, 0, n - 1);

        if (controls_pressed(pid, "MoveRight")) { b.page = (b.page + 1) mod 5; b.sel = 0; b.scroll = 0; b.spin_ticks = 18; }
        if (controls_pressed(pid, "MoveLeft"))  { b.page = (b.page + 4) mod 5; b.sel = 0; b.scroll = 0; b.spin_ticks = 18; }

        var rows = 8;
        n        = array_length(b.items[b.page]);
        b.sel    = clamp(b.sel, 0, max(0, n - 1));
        b.scroll = clamp(b.scroll, 0, max(0, n - rows));
        if (b.sel < b.scroll)           b.scroll = b.sel;
        if (b.sel >= b.scroll + rows)   b.scroll = max(0, b.sel - rows + 1);

        if (b.spin_ticks > 0) b.spin_ticks--;
        if (variable_struct_exists(b, "lock") && b.lock > 0) b.lock--;
    }
}

// Item submenu handling: Use / Give / Discard / Cancel
// This runs inside the same update loop after regular navigation so it observes b.lock and prevents double-input.
function __bag_impl_bag_item_menu_update(_pid){
    if (!variable_global_exists("BAGS")) return;
    if (!is_array(global.BAGS) || array_length(global.BAGS) <= _pid) return;
    var b = global.BAGS[_pid]; if (!is_struct(b)) return;
    if (!b.open) return;
    if (!variable_struct_exists(b, "item_menu_open")) b.item_menu_open = false;

    // open the menu when Interact is pressed on an item and no other menu is open
    var lst = b.items[b.page]; var n = array_length(lst);
    if (n <= 0) return;

    // If party requested to Give to a mon, allow direct selection from bag: Interact -> give to mon
    if (variable_struct_exists(b, "give_from_party") && b.give_from_party && variable_struct_exists(b, "give_to_mon")){
                // pressing Interact when a bag item is selected will give it to the party mon
        if (controls_pressed(_pid, "Interact") && b.lock == 0){
            var row = b.sel; if (row >= 0 && row < n){ var it = lst[row];
                var monIndex = b.give_to_mon;
                // Ensure item is holdable before giving
                if (!is_undefined(bag__item_is_holdable) && !bag__item_is_holdable(it)){
                    // Don't close the bag or clear the give request — allow the player to pick another item.
                    show_debug_message("[bag->party] Selected item is not holdable; choose another item.");
                    b.lock = 8; // small delay to avoid spam
                } else {
                    // ensure party exists and target mon
                    if (!is_undefined(party_ensure)){
                        var P = party_ensure(_pid); // note: party was opened by caller
                        if (is_struct(P) && is_array(P.mons) && monIndex >= 0 && monIndex < array_length(P.mons)){
                            var target = P.mons[monIndex]; if (!is_struct(target)) target = P.mons[monIndex] = {};
                            // return prev held item to bag
                            var prev = (variable_struct_exists(target, "held_item_id") ? variable_struct_get(target, "held_item_id") : -1);
                            if (is_real(prev) && prev > 0) bag_inventory_add_item(_pid, prev, 1);
                            // set held item to selected and preserve canonical identifier for render/lookup
                            variable_struct_set(target, "held_item_id", it.item_id);
                            if (is_struct(it) && variable_struct_exists(it, "real_name") && string_length(string(it.real_name)) > 0){
                                variable_struct_set(target, "held_item_real_name", string(it.real_name));
                            } else if (is_struct(it) && variable_struct_exists(it, "name") && string_length(string(it.name)) > 0){
                                variable_struct_set(target, "held_item_real_name", string(it.name));
                            }
                            // remove one from bag
                            bag_inventory_remove_item(_pid, it.item_id, 1);
                            bags_seed_from_items(_pid);
                            show_debug_message("[bag->party] Gave item " + string(it.item_id) + " to mon " + string(monIndex));
                        }
                    }

                    // Clear flags and return to party menu
                    b.give_from_party = false; b.give_to_mon = undefined; b.lock = 4; // small lock
                    // re-open party UI and restore to menu so player returns to party menu
                    if (!is_undefined(party_open) && !is_undefined(party_ensure)){
                        party_open(_pid);
                        var P2 = party_ensure(_pid);
                        if (is_struct(P2)){ P2.mode = "menu"; P2.lock = 4; }
                    }
                    bag_close(_pid);
                }
            }
        }
        // still allow normal navigation while in give_from_party mode; do not open the item submenu
        if (b.spin_ticks > 0) b.spin_ticks--;
        if (variable_struct_exists(b, "lock") && b.lock > 0) b.lock--;
        return;
    }
    // Explicit open branch with diagnostics to help debug why Interact may be ignored
    if (controls_pressed(_pid, "Interact")){
        if (n <= 0){ show_debug_message("[bag] Interact pressed but no items on this page (n=0)"); }
        else if (b.item_menu_open){ show_debug_message("[bag] Interact pressed but item_menu already open"); }
        else if (b.lock != 0){ show_debug_message("[bag] Interact pressed but b.lock=" + string(b.lock)); }
        else {
            // open the menu
            b.item_menu_open = true; b.item_menu_sel = 0; b.item_menu_row = b.sel; b.lock = 2; return;
        }
    }

    if (!b.item_menu_open) return;

    // Build dynamic labels to match drawing so indices remain consistent
    var _rowNav = clamp(b.item_menu_row, 0, max(0, n - 1));
    var _itNav = (n > 0 && _rowNav < n) ? lst[_rowNav] : undefined;
    var _labelsNav = ["Use","Discard","Cancel"];
    if (!is_undefined(bag__item_is_holdable) && bag__item_is_holdable(_itNav)) array_insert(_labelsNav, 1, "Give");
    var _maxIdx = array_length(_labelsNav) - 1;
    // navigate submenu using dynamic bounds
    if (controls_pressed(_pid, "MoveDown")){
        b.item_menu_sel = clamp(b.item_menu_sel + 1, 0, _maxIdx);
    }
    if (controls_pressed(_pid, "MoveUp")){
        b.item_menu_sel = clamp(b.item_menu_sel - 1, 0, _maxIdx);
    }

    // selection by label (keeps behavior consistent when 'Give' is present or not)
    if (controls_pressed(_pid, "Interact") && b.lock == 0){
        var sel = clamp(b.item_menu_sel, 0, _maxIdx);
        var row = b.item_menu_row; var it = lst[row];
        b.item_menu_open = false; b.lock = 2;
        var action = _labelsNav[sel];
        if (action == "Use"){
            show_debug_message("[bag] Use action not handled in core. Implement bag__use_item_on_self to handle it.");
        } else if (action == "Give"){
            // Close bag, ensure party and set give_pending
            bag_close(_pid);
            if (!is_undefined(party_open)){
                party_open(_pid);
                var P = party_ensure(_pid);
                P.mode = "select_item";
                var _realnm_pending = undefined;
                if (is_struct(it) && variable_struct_exists(it, "real_name")) _realnm_pending = string(it.real_name);
                else if (is_struct(it) && variable_struct_exists(it, "name")) _realnm_pending = string(it.name);
                P.give_pending = { bag_pid: _pid, page: b.page, row: row, item_id: it.item_id, item_real_name: _realnm_pending };
                P.lock = 4;
            }
        } else if (action == "Discard"){
            bag_inventory_remove_item(_pid, it.item_id, 1);
            bags_seed_from_items(_pid);
        } else if (action == "Cancel"){
            // nothing
        }
        if (variable_struct_exists(b, "give_from_party") && b.give_from_party){ b.give_from_party = false; b.give_to_mon = undefined; }
        return;
    }

    if (controls_pressed(_pid, "Run") && b.lock == 0){ b.item_menu_open = false; b.lock = 2; }
}

// Public wrapper for update
// Note: actual public bags_update() lives in bag_system.gml; we expose helper implementations here.
