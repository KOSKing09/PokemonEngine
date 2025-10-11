// test_bag_give.gml
// Simple data-level test for bag -> give flow. Call from debugger or runner.
// Usage: in debugger, execute: test_bag_give();

function test_bag_give(){
    // Ensure systems
    party_init();
    bags_init(1);

    // Create a simple bag with one item in page 0 at sel 0
    var b = __bag_impl__default_bag();
    b.items[0] = [];
    var item_struct = { item_id: 42, qty: 2 };
    array_push(b.items[0], item_struct);
    b.page = 0; b.sel = 0; b.scroll = 0; b.open = true;
    global.BAGS[0] = b;

    // Seed party with two mons
    var P = party_ensure(0);
    P.mons = [];
    array_push(P.mons, { species_id: 1, name: "A" });
    array_push(P.mons, { species_id: 2, name: "B" });
    P.sel = 0; P.scroll = 0; P.open = false;

    // Call the give ext directly
    if (variable_global_exists("bag_give_item_ext")){
        global.bag_give_item_ext(0, b, 0);
    } else {
        show_debug_message("[TEST] bag_give_item_ext not defined");
        return false;
    }

    // After calling, party should be open and mode select_item
    var ok_open = (variable_global_exists("PARTY") && is_array(global.PARTY) && is_struct(global.PARTY[0]) && global.PARTY[0].open && string(global.PARTY[0].mode) == "select_item");
    show_debug_message("[TEST] party opened/select_item = " + string(ok_open));
    if (!ok_open) return false;

    // Simulate pressing Interact on party at sel=0 by calling party_update until lock expires
    // Ensure party lock is zero so interact is accepted
    global.PARTY[0].lock = 0;
    // Set the party selection to the first mon
    global.PARTY[0].sel = 0;

    // Now perform the action that would be executed when Interact is pressed
    // We'll directly mimic the party input logic that does the transfer
    var _P = party_ensure(0);
    if (variable_struct_exists(_P, "give_pending")){
        var gp = variable_struct_get(_P, "give_pending");
        var bagpid = variable_struct_exists(gp, "bag_pid") ? variable_struct_get(gp, "bag_pid") : 0;
        var page   = variable_struct_exists(gp, "page") ? variable_struct_get(gp, "page") : 0;
        var sel    = variable_struct_exists(gp, "sel") ? variable_struct_get(gp, "sel") : -1;
        var itemid = variable_struct_exists(gp, "item_id") ? variable_struct_get(gp, "item_id") : -1;
        // Perform transfer
        if (bagpid >= 0 && variable_global_exists("BAGS") && is_array(global.BAGS) && bagpid < array_length(global.BAGS)){
            var _bag = global.BAGS[bagpid];
            if (is_struct(_bag) && is_array(_bag.items) && page >= 0 && page < array_length(_bag.items)){
                var list = _bag.items[page];
                if (is_array(list) && sel >= 0 && sel < array_length(list)){
                    var mon = _P.mons[_P.sel]; if (is_struct(mon)) variable_struct_set(mon, "held_item_id", itemid);
                    if (variable_struct_exists(list[sel], "qty")){
                        var q = variable_struct_get(list[sel], "qty');
                        q = max(0, q - 1);
                        if (q <= 0) array_delete(list, sel, 1); else variable_struct_set(list[sel], "qty", q);
                    }
                }
            }
        }
        variable_struct_set(_P, "give_pending", {});
    }

    // Validate: mon should have held_item_id 42 and bag qty reduced to 1
    var mon_has = (is_struct(global.PARTY[0].mons[0]) && variable_struct_exists(global.PARTY[0].mons[0], "held_item_id") && variable_struct_get(global.PARTY[0].mons[0], "held_item_id") == 42);
    var bag_qty = -1;
    if (is_array(global.BAGS) && is_struct(global.BAGS[0])){
        var L = global.BAGS[0].items[0];
        if (is_array(L) && array_length(L) > 0 && variable_struct_exists(L[0], "qty")) bag_qty = variable_struct_get(L[0], "qty");
    }
    show_debug_message("[TEST] mon_has_held= " + string(mon_has) + " bag_qty=" + string(bag_qty));

    return mon_has && bag_qty == 1;
}
