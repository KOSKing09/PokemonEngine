// Bag input module — handles bag opening, navigation, paging and spin ticks.
function __bag_impl_bags_update(){
    if (!variable_global_exists("BAGS")) return;
    var _players = array_length(global.BAGS); if (_players <= 0) return;

    for (var pid = 0; pid < _players; pid++) {
        var b = global.BAGS[pid]; if (!is_struct(b)) continue;

        if (controls_pressed(pid, "Inventory")) { b.open = !b.open; if (b.open) b.spin_ticks = 18; }
        if (!b.open) continue;

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
    }
}
