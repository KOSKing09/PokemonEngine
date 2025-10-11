// [Bag]: bag_system — Build v1.3.4 — Updated 2025-10-08
// Hotfix: Restore sprite drawing using resource indices and fix placeholder icon lookup.
// - Reverts to sprite_exists(<sprite_symbol>) style (no string name resolver).
// - Adds draw state reset at top of bag_draw_gui_rect.
// - Replaces 'spr_item_placeholder' symbol with safe asset_get_index lookup.
// - Keeps BAGS-based inventory + seeding.

function bags_init(_players){
    var _n = (argument_count > 0) ? max(1, floor(_players)) : 1;
    if (!variable_global_exists("BAGS") || !is_array(global.BAGS)) global.BAGS = [];
    if (array_length(global.BAGS) < _n) array_resize(global.BAGS, _n);

    var _hasEnsure = !is_undefined(bag_inventory_ensure);
    for (var _pid = 0; _pid < _n; _pid++){

        if (_hasEnsure) {
            bag_inventory_ensure(_pid);
        } else {
            var _b = (array_length(global.BAGS) > _pid) ? global.BAGS[_pid] : undefined;
            if (!is_struct(_b)) {
                _b = bag__default_bag();
                global.BAGS[_pid] = _b;
            } else {
                bag__ensure_props(_b, ["items","sys_qty","page","sel","scroll","spin_ticks","mode","open"], [bag__empty_items(), [], 0, 0, 0, 0, "bag", false]);
            }
        }
    }
}

// Compact helper to ensure struct properties exist with defaults
function bag__ensure_props(_s, _names, _defs){ if (!is_undefined(__bag_impl__ensure_props)) return __bag_impl__ensure_props(_s,_names,_defs); }

// Return a fresh default bag struct (used in multiple places)
function bag__default_bag(){ if (!is_undefined(__bag_impl__default_bag)) return __bag_impl__default_bag(); return { open:false, mode:"bag", page:0, sel:0, scroll:0, spin_ticks:0, items:[[],[],[],[],[]], sys_qty:[], item_menu_open:false, item_menu_sel:0, item_menu_row:0, lock:0 }; }

// Return a project placeholder sprite index if present, else fall back to PKICONS.missing_icon32 (or -1)
function bag__get_item_placeholder(){ if (!is_undefined(__bag_impl__get_item_placeholder)) return __bag_impl__get_item_placeholder(); var ph = asset_get_index("spr_item_placeholder"); if (ph == -1 && variable_global_exists("PKICONS") && is_struct(PKICONS) && variable_struct_exists(PKICONS, "missing_icon32")) ph = variable_struct_get(PKICONS, "missing_icon32"); return ph; }

// Return an empty items array for a bag (five pages)
function bag__empty_items(){ if (!is_undefined(__bag_impl__empty_items)) return __bag_impl__empty_items(); return [[],[],[],[],[]]; }

// Map an item to one of the five bag pages: 0=ITEMS,1=POKEBALLS,2=TMHM,3=BERRIES,4=KEY ITEMS
function bag__item_to_page(_iid, _it){
    // defaults
    var page = 0;
    if (!is_struct(_it)) return page;
    var ident = (variable_struct_exists(_it, "identifier") ? string(_it.identifier) : string(_it.name));
    ident = string_lower(string_trim(ident));

    // quick heuristics by identifier
    if (string_pos("ball", ident) > 0) { page = 1; return page; }
    if (string_pos("tm", ident) == 1 || string_pos("tm", ident) > 0 && string_pos("tm", ident) <= 3) { page = 2; return page; }
    if (string_pos("hm", ident) == 1 || string_pos("hm", ident) > 0 && string_pos("hm", ident) <= 3) { page = 2; return page; }
    if (string_pos("berry", ident) > 0) { page = 3; return page; }

    // key items detection: check flags or category name if available
    if (variable_global_exists("_item_flag_map") && is_array(global._item_flag_map) && _iid < array_length(global._item_flag_map)){
        var fmap = global._item_flag_map[_iid];
        if (is_array(fmap)){
            for (var fi = 0; fi < array_length(fmap); fi++){
                var code = string_lower(string_trim(fmap[fi]));
                if (code == "key" || code == "key_item" || code == "key_item_flag") { page = 4; return page; }
            }
        }
    }

    // If item_categorys exists, try to find the category record and inspect its name/identifier for 'key' or 'key-item'
    if (variable_global_exists("item_categorys") && is_array(global.item_categorys)){
        var cid = -1;
        if (variable_struct_exists(_it, "category_id")) cid = _it.category_id;
        if (cid > 0){
            for (var ci = 0; ci < array_length(global.item_categorys); ci++){
                var crec = global.item_categorys[ci];
                if (!is_struct(crec) || !variable_struct_exists(crec, "id")) continue;
                if (crec.id == cid){
                    var cname = string_lower(string_trim(variable_struct_exists(crec, "identifier") ? crec.identifier : (variable_struct_exists(crec, "name") ? crec.name : string(crec.id))));
                    if (string_pos("key", cname) > 0 || string_pos("key-item", cname) > 0 || string_pos("keyitems", cname) > 0) { page = 4; return page; }
                    // fallback: if pocket name indicates pokeballs/berries
                    if (variable_struct_exists(crec, "pocket")){
                        var pn = string_lower(string_trim(crec.pocket));
                        if (string_pos("ball", pn) > 0) { page = 1; return page; }
                        if (string_pos("berry", pn) > 0) { page = 3; return page; }
                    }
                    break;
                }
            }
        }
    }

    return page;
}

// Clean a display name: remove hyphens and collapse multiple spaces
function bag__clean_display_name(_s){
    if (!is_string(_s)) _s = string(_s);
    var t = string_trim(_s);
    // replace hyphens with space
    t = string_replace_all(t, "-", " ");
    // collapse multiple spaces
    while (string_pos("  ", t) > 0) t = string_replace_all(t, "  ", " ");
    return string_trim(t);
}

function bag_is_open(_pid) { return (variable_global_exists("BAGS") && is_array(global.BAGS) && array_length(global.BAGS) > _pid && global.BAGS[_pid].open); }
function bag_open(_pid) { if (is_array(global.BAGS) && array_length(global.BAGS) > _pid) global.BAGS[_pid].open = true; }
function bag_close(_pid){ if (is_array(global.BAGS) && array_length(global.BAGS) > _pid) global.BAGS[_pid].open = false; }
function bag_toggle(_pid){ if (!variable_global_exists("BAGS") || !is_array(global.BAGS) || array_length(global.BAGS) <= _pid) return; global.BAGS[_pid].open = !global.BAGS[_pid].open; }

function bags_update(){
    // decrement short locks on bag slots so new menus become actionable quickly
    if (variable_global_exists("BAGS") && is_array(global.BAGS)){
        for (var _pid = 0; _pid < array_length(global.BAGS); _pid++){
            var _b = global.BAGS[_pid]; if (!is_struct(_b)) continue;
            if (variable_struct_exists(_b, "lock") && _b.lock > 0) _b.lock--;
        }
    }

    // run optional submenu updater first so it can open and consume input this frame
    if (!is_undefined(__bag_impl_bag_item_menu_update)){
        if (variable_global_exists("BAGS") && is_array(global.BAGS)){
            for (var pid = 0; pid < array_length(global.BAGS); pid++) __bag_impl_bag_item_menu_update(pid);
        }
    }

    // now run the main bag update (navigation) which will see item_menu_open state and skip if needed
    if (!is_undefined(__bag_impl_bags_update)) __bag_impl_bags_update();
}

// ---- Inventory (BAGS-based) ----
function bag_inventory_ensure(_pid){
    if (!variable_global_exists("BAGS") || !is_array(global.BAGS)) global.BAGS = [];
    if (array_length(global.BAGS) <= _pid) array_resize(global.BAGS, _pid + 1);
    var _b = global.BAGS[_pid];
        if (!is_struct(_b)) {
            _b = bag__default_bag();
            global.BAGS[_pid] = _b;
        } else {
            bag__ensure_props(_b, ["items","sys_qty","page","sel","scroll","spin_ticks","mode","open","item_menu_open","item_menu_sel","item_menu_row","lock"], [bag__empty_items(), [], 0, 0, 0, 0, "bag", false, false, 0, 0, 0]);
        }
    return _b;
}

function bag_inventory_get_qty(_pid, _itemId){
    var _b = bag_inventory_ensure(_pid);
    var _id = (is_real(_itemId) ? floor(_itemId) : -1);
    if (_id <= 0) return 0;
    var _arr = _b.sys_qty;
    if (!is_array(_arr)) { _b.sys_qty = []; return 0; }
    if (array_length(_arr) > _id) { var _v = _arr[_id]; return is_real(_v) ? _v : 0; }
    return 0;
}

function bag_inventory_set_qty(_pid, _itemId, _qty){
    var _b = bag_inventory_ensure(_pid);
    var _id = (is_real(_itemId) ? floor(_itemId) : -1);
    if (_id <= 0) return 0;
    var _q  = (is_real(_qty) ? max(0, floor(_qty)) : 0);
    if (array_length(_b.sys_qty) <= _id) array_resize(_b.sys_qty, _id + 1);
    _b.sys_qty[_id] = _q;
    return _q;
}

function bag_inventory_add_item(_pid, _itemId, _qtyAdd){
    var _cur  = bag_inventory_get_qty(_pid, _itemId);
    var _next = _cur + (is_real(_qtyAdd) ? max(0, floor(_qtyAdd)) : 0);
    return bag_inventory_set_qty(_pid, _itemId, _next);
}

function bag_inventory_remove_item(_pid, _itemId, _qtyRem){
    var _cur  = bag_inventory_get_qty(_pid, _itemId);
    var _next = max(0, _cur - (is_real(_qtyRem) ? max(0, floor(_qtyRem)) : 0));
    return bag_inventory_set_qty(_pid, _itemId, _next);
}

// ---- Seeding ----
function bags_seed_from_items(_pid){
    var _b = bag_inventory_ensure(_pid);
        _b.items = bag__empty_items();

        // small helper: preferred display name for an item id
        function _bag__display_name(_iid, _it){
            // prefer localized/item_text name if present
            if (variable_global_exists("_item_text") && is_array(global._item_text) && _iid < array_length(global._item_text) && is_struct(global._item_text[_iid])){
                var jt = global._item_text[_iid];
                if (variable_struct_exists(jt, "name") && is_string(jt.name) && string_length(string_trim(jt.name)) > 0) return jt.name;
                if (variable_struct_exists(jt, "short_desc") && is_string(jt.short_desc) && string_length(string_trim(jt.short_desc)) > 0) return jt.short_desc;
            }
            if (is_struct(_it) && variable_struct_exists(_it, "name") && is_string(_it.name) && string_length(string_trim(_it.name)) > 0) return _it.name;
            if (is_struct(_it) && variable_struct_exists(_it, "identifier") && is_string(_it.identifier) && string_length(string_trim(_it.identifier)) > 0) return _it.identifier;
            return "?";
        }

    // Heuristic seeding: assign each item directly to one of 5 pages using bag__item_to_page
    for (var iid = 1; iid < array_length(global._items); iid++){
        var it = global._items[iid];
        if (!is_struct(it)) continue;
        var qty = bag_inventory_get_qty(_pid, iid);
        if (qty <= 0) continue;

        var page = bag__item_to_page(iid, it);
        page = clamp(page, 0, 4);

        var desc = "—";
        if (variable_global_exists("_item_text") && is_array(global._item_text) && iid < array_length(global._item_text) && is_struct(global._item_text[iid])){
            var _d2 = global._item_text[iid].flavor_text;
            if (is_string(_d2) && string_length(string_trim(_d2)) > 0) desc = _d2;
        }
        var icon = bag__get_item_placeholder();
        // prefer identifier for lookups (preserve raw CSV identifier which may contain hyphens)
        var lookup_name = undefined;
        if (is_struct(it) && variable_struct_exists(it, "identifier") && string_length(string_trim(it.identifier)) > 0) lookup_name = string(it.identifier);
        else if (is_struct(it) && variable_struct_exists(it, "name") && string_length(string_trim(it.name)) > 0) lookup_name = string(it.name);
        if (!is_undefined(pkicons_get_item_icon_by_name) && !is_undefined(lookup_name)){
            var spr_try = pkicons_get_item_icon_by_name(string(lookup_name));
            if (!is_undefined(spr_try) && sprite_exists(spr_try)) icon = spr_try;
        }
    var dname = _bag__display_name(iid, it);
    // store both cleaned display name and raw identifier for lookups
    var realnm = (is_struct(it) && variable_struct_exists(it, "identifier") && string_length(string_trim(it.identifier)) > 0) ? string(it.identifier) : ((is_struct(it) && variable_struct_exists(it, "name")) ? string(it.name) : "");
    var row = { name: bag__clean_display_name(dname), real_name: realnm, qty: qty, desc: desc, icon: icon, item_id: iid };
        array_push(_b.items[page], row);
    }

    // Post-pass: ensure any items with qty>0 that weren't placed get added to page 0
    for (var iidp = 1; iidp < array_length(global._items); iidp++){
        var itm = global._items[iidp];
        if (!is_struct(itm)) continue;
        var qtp = bag_inventory_get_qty(_pid, iidp);
        if (qtp <= 0) continue;
        // check placed
        var placed = false;
        for (var pp = 0; pp < array_length(_b.items); pp++){
            var arrp = _b.items[pp];
            for (var jj = 0; jj < array_length(arrp); jj++){
                if (arrp[jj].item_id == iidp) { placed = true; break; }
            }
            if (placed) break;
        }
        if (!placed){
            var nm = _bag__display_name(iidp, itm);
            var ic = bag__get_item_placeholder();
            var lookup_name2 = undefined;
            if (is_struct(itm) && variable_struct_exists(itm, "identifier") && string_length(string_trim(itm.identifier)) > 0) lookup_name2 = string(itm.identifier);
            else if (is_struct(itm) && variable_struct_exists(itm, "name") && string_length(string_trim(itm.name)) > 0) lookup_name2 = string(itm.name);
            if (!is_undefined(pkicons_get_item_icon_by_name) && !is_undefined(lookup_name2)){
                var st = pkicons_get_item_icon_by_name(string(lookup_name2)); if (!is_undefined(st) && sprite_exists(st)) ic = st;
            }
            var realnm2 = (is_struct(itm) && variable_struct_exists(itm, "identifier") && string_length(string_trim(itm.identifier)) > 0) ? string(itm.identifier) : ((is_struct(itm) && variable_struct_exists(itm, "name")) ? string(itm.name) : "");
            array_push(_b.items[0], { name:bag__clean_display_name(nm), real_name: realnm2, qty:qtp, desc:"—", icon:ic, item_id:iidp });
        }
    }

    _b.sel = 0;
    _b.scroll = 0;
}

function bags_seed_all(){
    if (!variable_global_exists("BAGS") || !is_array(global.BAGS)) return;
    for (var _pid = 0; _pid < array_length(global.BAGS); _pid++){ bags_seed_from_items(_pid); }
}

// Debug helper: print bag pages for a player id
function debug_print_bag(_pid){
    if (!variable_global_exists("BAGS") || !is_array(global.BAGS) || _pid < 0 || _pid >= array_length(global.BAGS)) { show_debug_message("[DEBUG][bag] invalid pid"); return; }
    var _b = bag_inventory_ensure(_pid);
    show_debug_message("[DEBUG][bag] pid=" + string(_pid) + " sys_qty_len=" + string(array_length(_b.sys_qty)));
    for (var p = 0; p < array_length(_b.items); p++){
        var arr = _b.items[p];
        show_debug_message("[DEBUG][bag] page=" + string(p) + " items=" + string(array_length(arr)));
        for (var ii = 0; ii < array_length(arr); ii++){
            var r = arr[ii];
            show_debug_message("[DEBUG][bag]  - " + string(r.item_id) + ": " + string(r.name) + " x" + string(r.qty));
        }
    }
}

// Diagnostic: list items with qty>0 and explain placement (or why not placed)
function debug_bag_orphans(_pid){
    if (!variable_global_exists("BAGS") || !is_array(global.BAGS) || _pid < 0 || _pid >= array_length(global.BAGS)) { show_debug_message("[DEBUG][bag] invalid pid"); return; }
    var _b = bag_inventory_ensure(_pid);
    if (!variable_global_exists("_items") || !is_array(global._items)) { show_debug_message("[DEBUG][bag] no global._items loaded"); return; }

    show_debug_message("[DEBUG][bag_orphans] scanning items for pid=" + string(_pid));
    var foundAny = false;
    for (var iid = 1; iid < array_length(global._items); iid++){
        var it = global._items[iid];
        if (!is_struct(it)) continue;
        var qty = bag_inventory_get_qty(_pid, iid);
        if (qty <= 0) continue;
        foundAny = true;
        // Determine where the seeder would place it
        if (!variable_global_exists("item_categorys") || !is_array(global.item_categorys) || array_length(global.item_categorys) == 0){
            show_debug_message("[DEBUG][bag_orphans] item=" + string(iid) + ", name=" + string(it.name) + ", qty=" + string(qty) + " => all items go to page 0 (no categories)");
            continue;
        }
        var cidVal = -1;
        if (variable_struct_exists(it, "category_id")) cidVal = it.category_id;
        if (cidVal <= 0){
            show_debug_message("[DEBUG][bag_orphans] item=" + string(iid) + ", name=" + string(it.name) + ", qty=" + string(qty) + " => NO category_id on item");
            continue;
        }
        // find category record with matching .id (category ids may be sparse)
        var catIndex = -1;
        for (var ci = 0; ci < array_length(global.item_categorys); ci++){
            if (!is_struct(global.item_categorys[ci])) continue;
            if (variable_struct_exists(global.item_categorys[ci], "id") && global.item_categorys[ci].id == cidVal){ catIndex = ci; break; }
        }
        if (catIndex == -1){
            show_debug_message("[DEBUG][bag_orphans] item=" + string(iid) + ", name=" + string(it.name) + ", qty=" + string(qty) + " => category id " + string(cidVal) + " missing in global.item_categorys (no matching .id)");
            continue;
        }
        var catrec = global.item_categorys[catIndex];
        var pocketName = (variable_struct_exists(catrec, "pocket") ? catrec.pocket : string(cidVal));
        // determine pocket order
        var pockets = [];
        if (variable_global_exists("_item_pockets") && is_array(global._item_pockets) && array_length(global._item_pockets) > 0) pockets = global._item_pockets;
        else {
            for (var cidx = 0; cidx < array_length(global.item_categorys); cidx++){ if (!is_struct(global.item_categorys[cidx])) continue; var pn = global.item_categorys[cidx].pocket; var found=false; for (var qq=0; qq<array_length(pockets); qq++) if (pockets[qq]==pn) { found=true; break; } if (!found) array_push(pockets, pn); }
        }
        // find pocket index
        var pidx = -1;
        for (var k = 0; k < array_length(pockets); k++){ if (pockets[k] == pocketName) { pidx = k; break; } }
        if (pidx == -1){
            show_debug_message("[DEBUG][bag_orphans] item=" + string(iid) + ", name=" + string(it.name) + ", qty=" + string(qty) + " => pocket '" + string(pocketName) + "' not in pocket order");
            continue;
        }
        if (pidx >= 5){
            show_debug_message("[DEBUG][bag_orphans] item=" + string(iid) + ", name=" + string(it.name) + ", qty=" + string(qty) + " => pocket index " + string(pidx) + " >= 5 (out of pages)");
            continue;
        }
        // check whether it's actually present on that page
        var placed = false;
        var arr = _b.items[pidx];
        for (var zz = 0; zz < array_length(arr); zz++){ if (arr[zz].item_id == iid) { placed = true; break; } }
        if (placed) show_debug_message("[DEBUG][bag_orphans] item=" + string(iid) + ", name=" + string(it.name) + ", qty=" + string(qty) + " => placed on page " + string(pidx));
        else show_debug_message("[DEBUG][bag_orphans] item=" + string(iid) + ", name=" + string(it.name) + ", qty=" + string(qty) + " => SHOULD be on page " + string(pidx) + " but wasn't found in _b.items[" + string(pidx) + "]");
    }
    if (!foundAny) show_debug_message("[DEBUG][bag_orphans] no items with qty>0 for pid=" + string(_pid));
}

// ---- Draw helpers ----
function _bag_rect_scaler(_rx, _ry, _rw, _rh){ if (!is_undefined(__bag_impl__bag_rect_scaler)) return __bag_impl__bag_rect_scaler(_rx,_ry,_rw,_rh); var _s = max(1, min(floor(_rw / 240), floor(_rh / 160))); var _ox = _rx + (_rw - 240 * _s) div 2; var _oy = _ry + (_rh - 160 * _s) div 2; return { s:_s, ox:_ox, oy:_oy, rw:_rw, rh:_rh }; }

function _bag_ui_rect_gui(){ if (!is_undefined(__bag_impl__bag_ui_rect_gui)) return __bag_impl__bag_ui_rect_gui(); var _gw = display_get_gui_width(); var _gh = display_get_gui_height(); return _bag_rect_scaler(0, 0, _gw, _gh); }

// ---- Draw GUI ----
function bag_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){ if (!is_undefined(__bag_impl_bag_draw_gui_rect)) return __bag_impl_bag_draw_gui_rect(_pid,_rx,_ry,_rw,_rh); }

function bag_draw_gui(_pid){ var gw = display_get_gui_width(); var gh = display_get_gui_height(); bag_draw_gui_rect(_pid, 0, 0, gw, gh); }

function __bag_wrap_lines(_text, _max_w){ if (!is_undefined(__bag_impl_wrap_lines)) return __bag_impl_wrap_lines(_text, _max_w); var _out = []; if (is_undefined(_text) || string_length(_text) == 0){ array_push(_out, "—"); return _out; } var _words = string_split(_text, " "); var _line  = ""; for (var i = 0; i < array_length(_words); i++){ var _w  = _words[i]; var _try = (_line == "" ? _w : _line + " " + _w); if (string_width(_try) <= _max_w) _line = _try; else { if (_line == "") { var _j = 1; while (_j <= string_length(_w) && string_width(string_copy(_w,1,_j)) <= _max_w) _j++; array_push(_out, string_copy(_w,1,_j-1)); _line = string_copy(_w,_j,string_length(_w)-_j+1); } else { array_push(_out, _line); _line = _w; } } } if (_line != "") array_push(_out, _line); return _out; }
