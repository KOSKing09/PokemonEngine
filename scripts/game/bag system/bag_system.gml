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
function bag__default_bag(){ if (!is_undefined(__bag_impl__default_bag)) return __bag_impl__default_bag(); return { open:false, mode:"bag", page:0, sel:0, scroll:0, spin_ticks:0, items:[[],[],[],[],[]], sys_qty:[] }; }

// Return a project placeholder sprite index if present, else fall back to PKICONS.missing_icon32 (or -1)
function bag__get_item_placeholder(){ if (!is_undefined(__bag_impl__get_item_placeholder)) return __bag_impl__get_item_placeholder(); var ph = asset_get_index("spr_item_placeholder"); if (ph == -1 && variable_global_exists("PKICONS") && is_struct(PKICONS) && variable_struct_exists(PKICONS, "missing_icon32")) ph = variable_struct_get(PKICONS, "missing_icon32"); return ph; }

// Return an empty items array for a bag (five pages)
function bag__empty_items(){ if (!is_undefined(__bag_impl__empty_items)) return __bag_impl__empty_items(); return [[],[],[],[],[]]; }

function bag_is_open(_pid) { return (variable_global_exists("BAGS") && is_array(global.BAGS) && array_length(global.BAGS) > _pid && global.BAGS[_pid].open); }
function bag_open(_pid) { if (is_array(global.BAGS) && array_length(global.BAGS) > _pid) global.BAGS[_pid].open = true; }
function bag_close(_pid){ if (is_array(global.BAGS) && array_length(global.BAGS) > _pid) global.BAGS[_pid].open = false; }
function bag_toggle(_pid){ if (!variable_global_exists("BAGS") || !is_array(global.BAGS) || array_length(global.BAGS) <= _pid) return; global.BAGS[_pid].open = !global.BAGS[_pid].open; }

function bags_update(){ if (!is_undefined(__bag_impl_bags_update)) return __bag_impl_bags_update(); }

// ---- Inventory (BAGS-based) ----
function bag_inventory_ensure(_pid){
    if (!variable_global_exists("BAGS") || !is_array(global.BAGS)) global.BAGS = [];
    if (array_length(global.BAGS) <= _pid) array_resize(global.BAGS, _pid + 1);
    var _b = global.BAGS[_pid];
        if (!is_struct(_b)) {
            _b = bag__default_bag();
            global.BAGS[_pid] = _b;
        } else {
            bag__ensure_props(_b, ["items","sys_qty","page","sel","scroll","spin_ticks","mode","open"], [bag__empty_items(), [], 0, 0, 0, 0, "bag", false]);
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

    var _count = (variable_global_exists("_items") && is_array(global._items)) ? array_length(global._items) : 0;
    for (var _i = 1; _i < _count; _i++){
        var _it = global._items[_i];
        if (!is_struct(_it)) continue;

        var _qty = bag_inventory_get_qty(_pid, _i);
        if (_qty <= 0) continue;

        var _page = 0;
        if (variable_global_exists("_item_to_bag_page") && is_array(global._item_to_bag_page) && _i < array_length(global._item_to_bag_page)){
            _page = global._item_to_bag_page[_i];
            if (!is_real(_page) || _page < 0 || _page > 4) _page = 0;
        }

        var _desc = "—";
        if (variable_global_exists("_item_text") && is_array(global._item_text) && _i < array_length(global._item_text) && is_struct(global._item_text[_i])){
            var _d2 = global._item_text[_i].flavor_text;
            if (is_string(_d2) && string_length(string_trim(_d2)) > 0) _desc = _d2;
        }

        // Icon: placeholder by name, then external resolver if present
    var _icon = -1;
    var _sprIdx = bag__get_item_placeholder();
    if (_sprIdx != -1) _icon = _sprIdx;
        if (!is_undefined(pkicons_get_item_icon_by_name)){
            var _spr_try = pkicons_get_item_icon_by_name(string(_it.name));
            // Accept any value the runtime considers a sprite (including ref sprite values)
            if (!is_undefined(_spr_try) && sprite_exists(_spr_try)) _icon = _spr_try;
        }

        var _row = { name: _it.name, qty: _qty, desc: _desc, icon: _icon, item_id: _i };
        array_push(_b.items[_page], _row);
    }

    _b.sel = 0;
    _b.scroll = 0;
}

function bags_seed_all(){
    if (!variable_global_exists("BAGS") || !is_array(global.BAGS)) return;
    for (var _pid = 0; _pid < array_length(global.BAGS); _pid++){ bags_seed_from_items(_pid); }
}

// ---- Draw helpers ----
function _bag_rect_scaler(_rx, _ry, _rw, _rh){ if (!is_undefined(__bag_impl__bag_rect_scaler)) return __bag_impl__bag_rect_scaler(_rx,_ry,_rw,_rh); var _s = max(1, min(floor(_rw / 240), floor(_rh / 160))); var _ox = _rx + (_rw - 240 * _s) div 2; var _oy = _ry + (_rh - 160 * _s) div 2; return { s:_s, ox:_ox, oy:_oy, rw:_rw, rh:_rh }; }

function _bag_ui_rect_gui(){ if (!is_undefined(__bag_impl__bag_ui_rect_gui)) return __bag_impl__bag_ui_rect_gui(); var _gw = display_get_gui_width(); var _gh = display_get_gui_height(); return _bag_rect_scaler(0, 0, _gw, _gh); }

// ---- Draw GUI ----
function bag_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){ if (!is_undefined(__bag_impl_bag_draw_gui_rect)) return __bag_impl_bag_draw_gui_rect(_pid,_rx,_ry,_rw,_rh); }

function bag_draw_gui(_pid){ var gw = display_get_gui_width(); var gh = display_get_gui_height(); bag_draw_gui_rect(_pid, 0, 0, gw, gh); }

function __bag_wrap_lines(_text, _max_w){ if (!is_undefined(__bag_impl_wrap_lines)) return __bag_impl_wrap_lines(_text, _max_w); var _out = []; if (is_undefined(_text) || string_length(_text) == 0){ array_push(_out, "—"); return _out; } var _words = string_split(_text, " "); var _line  = ""; for (var i = 0; i < array_length(_words); i++){ var _w  = _words[i]; var _try = (_line == "" ? _w : _line + " " + _w); if (string_width(_try) <= _max_w) _line = _try; else { if (_line == "") { var _j = 1; while (_j <= string_length(_w) && string_width(string_copy(_w,1,_j)) <= _max_w) _j++; array_push(_out, string_copy(_w,1,_j-1)); _line = string_copy(_w,_j,string_length(_w)-_j+1); } else { array_push(_out, _line); _line = _w; } } } if (_line != "") array_push(_out, _line); return _out; }
