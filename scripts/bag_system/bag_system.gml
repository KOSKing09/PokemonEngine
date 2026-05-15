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
function bag__default_bag(){ if (!is_undefined(__bag_impl__default_bag)) return __bag_impl__default_bag(); return { open:false, mode:"bag", page:0, sel:0, scroll:0, spin_ticks:0, items:[[],[],[],[],[]], sys_qty:[], item_menu_open:false, item_menu_sel:0, item_menu_row:0, lock:0, registered_item_id:-1, registered_item_name:"", registered_item_real_name:"" }; }

// Return a project placeholder sprite index if present, else fall back to PKICONS.missing_icon32 (or -1)
function bag__get_item_placeholder(){ if (!is_undefined(__bag_impl__get_item_placeholder)) return __bag_impl__get_item_placeholder(); var ph = asset_get_index("spr_item_placeholder"); if (ph == -1 && variable_global_exists("PKICONS") && is_struct(PKICONS) && variable_struct_exists(PKICONS, "missing_icon32")) ph = variable_struct_get(PKICONS, "missing_icon32"); return ph; }

// Return an empty items array for a bag (five pages)
function bag__empty_items(){ if (!is_undefined(__bag_impl__empty_items)) return __bag_impl__empty_items(); return [[],[],[],[],[]]; }

// Strip simple wiki-style markup like [HP]{mechanic:hp} -> HP
function bag__strip_markup(_txt){
    if (!is_string(_txt)) _txt = string(_txt);
    var out = "";
    var len = string_length(_txt);
    var i = 1;
    while (i <= len){
        var ch = string_copy(_txt, i, 1);
        if (ch == "["){
            var label = "";
            var j = i + 1;
            while (j <= len){
                var cj = string_copy(_txt, j, 1);
                if (cj == "]") break;
                label += cj;
                j++;
            }
            if (j <= len && string_copy(_txt, j, 1) == "]"){
                out += label;
                j++;
                if (j <= len && string_copy(_txt, j, 1) == "{"){
                    j++;
                    while (j <= len && string_copy(_txt, j, 1) != "}"){ j++; }
                    if (j <= len && string_copy(_txt, j, 1) == "}") j++;
                }
                i = j;
                continue;
            }
        }
        out += ch;
        i++;
    }
    return out;
}

// Normalize whitespace and remove control characters from prose before drawing
function bag__clean_item_text(_txt){
    if (is_undefined(_txt)) return "";
    var t = (is_string(_txt) ? _txt : string(_txt));
    t = string_replace_all(t, "\r\n", "\n");
    t = string_replace_all(t, "\r", "\n");
    t = string_replace_all(t, chr(12), " ");
    t = string_replace_all(t, chr(9), " ");
    t = string_replace_all(t, "\n", " ");
    t = bag__strip_markup(t);
    while (string_pos("  ", t) > 0) t = string_replace_all(t, "  ", " ");
    return string_trim(t);
}

// Resolve a readable item description using available data tables
function bag__resolve_item_desc(_iid){
    if (!is_real(_iid) || _iid < 0) return "—";
    var txt = "";
    if (variable_global_exists("_item_prose") && is_array(global._item_prose) && _iid < array_length(global._item_prose)){
        var prose = global._item_prose[_iid];
        if (is_struct(prose)){
            if (variable_struct_exists(prose, "short_effect") && string_length(string_trim(prose.short_effect)) > 0) txt = prose.short_effect;
            else if (variable_struct_exists(prose, "effect") && string_length(string_trim(prose.effect)) > 0) txt = prose.effect;
        }
    }
    if (string_length(string_trim(txt)) == 0 && variable_global_exists("_item_text") && is_array(global._item_text) && _iid < array_length(global._item_text)){
        var itxt = global._item_text[_iid];
        if (is_struct(itxt)){
            if (variable_struct_exists(itxt, "short_desc") && string_length(string_trim(itxt.short_desc)) > 0) txt = itxt.short_desc;
            else if (variable_struct_exists(itxt, "flavor_text") && string_length(string_trim(itxt.flavor_text)) > 0) txt = itxt.flavor_text;
        }
    }
    txt = bag__clean_item_text(txt);
    if (string_length(txt) == 0) return "—";
    return txt;
}

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

// Read an item's prose entry to extract a numeric ball multiplier (e.g. "1.5x" or "×2").
// Returns 1.0 when no multiplier is found or on error.
function bag__get_ball_modifier(_iid){
    if (!is_real(_iid) || _iid <= 0) return 1.0;
    if (!variable_global_exists("_item_prose") || !is_array(global._item_prose)) return 1.0;
    if (_iid >= array_length(global._item_prose)) return 1.0;
    var rec = global._item_prose[_iid]; if (!is_struct(rec)) return 1.0;
    var txt = "";
    if (variable_struct_exists(rec, "short_effect")) txt = string_trim(string(variable_struct_get(rec, "short_effect")));
    else if (variable_struct_exists(rec, "effect")) txt = string_trim(string(variable_struct_get(rec, "effect")));
    if (string_length(txt) == 0) return 1.0;

    // normalize multiplication sign
    txt = string_replace_all(txt, "×", "x");
    txt = string_lower(txt);

    // try to find an explicit 'x' multiplier (e.g. "x1.5" or "1.5x")
    var ix = string_pos("x", txt);
    if (ix > 0){
        // try number after the x
        var after = string_trim(string_copy(txt, ix + 1, 256));
        var num = "";
        for (var i = 1; i <= string_length(after); i++){
            var ch = string_copy(after, i, 1);
            if ((ch >= "0" && ch <= "9") || ch == ".") num += ch; else break;
        }
        if (string_length(num) > 0){
            // ensure there's at least one digit (avoid lone ".") before converting
            var _hasd = false;
            for (var _di = 1; _di <= string_length(num); _di++){ var _chd = string_copy(num, _di, 1); if (_chd >= "0" && _chd <= "9") { _hasd = true; break; } }
            if (_hasd){ var v = real(num); if (is_real(v) && v > 0) return v; }
        }

        // try number before the x
        var before = string_trim(string_copy(txt, 1, ix - 1));
        var num2 = "";
    for (var j = string_length(before); j >= 1; j--){ var ch2 = string_copy(before, j, 1); if ((ch2 >= "0" && ch2 <= "9") || ch2 == ".") num2 = ch2 + num2; else break; }
        if (string_length(num2) > 0){
            var _hasd2 = false;
            for (var _di2 = 1; _di2 <= string_length(num2); _di2++){ var _chd2 = string_copy(num2, _di2, 1); if (_chd2 >= "0" && _chd2 <= "9") { _hasd2 = true; break; } }
            if (_hasd2){ var v2 = real(num2); if (is_real(v2) && v2 > 0) return v2; }
        }
    }

    // fallback: attempt to extract first floating number in the text
    var acc = "";
    for (var k = 1; k <= string_length(txt); k++){
        var c = string_copy(txt, k, 1);
    if ((c >= "0" && c <= "9") || c == ".") acc += c;
        else if (string_length(acc) > 0) break;
    }
    if (string_length(acc) > 0){
        var _hasd3 = false;
        for (var _di3 = 1; _di3 <= string_length(acc); _di3++){ var _chd3 = string_copy(acc, _di3, 1); if (_chd3 >= "0" && _chd3 <= "9") { _hasd3 = true; break; } }
        if (_hasd3){ var v3 = real(acc); if (is_real(v3) && v3 > 0) return v3; }
    }

    return 1.0;
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

function bag__item_display_name(_iid, _row, _it){
    var _name = "";
    if (is_struct(_row)){
        if (variable_struct_exists(_row, "name") && string_length(string_trim(string(variable_struct_get(_row, "name")))) > 0) _name = string(variable_struct_get(_row, "name"));
        else if (variable_struct_exists(_row, "real_name") && string_length(string_trim(string(variable_struct_get(_row, "real_name")))) > 0) _name = string(variable_struct_get(_row, "real_name"));
    }
    if (string_length(string_trim(_name)) <= 0 && is_struct(_it)){
        if (variable_struct_exists(_it, "name") && string_length(string_trim(string(variable_struct_get(_it, "name")))) > 0) _name = string(variable_struct_get(_it, "name"));
        else if (variable_struct_exists(_it, "identifier") && string_length(string_trim(string(variable_struct_get(_it, "identifier")))) > 0) _name = string(variable_struct_get(_it, "identifier"));
    }
    if (string_length(string_trim(_name)) <= 0 && is_real(_iid)) _name = "item " + string(floor(_iid));
    return bag__clean_display_name(_name);
}

function bag__item_article(_display_name){
    var _txt = string_lower(string_trim(string(_display_name)));
    if (string_length(_txt) <= 0) return "a";
    var _ch = string_copy(_txt, 1, 1);
    if (_ch == "a" || _ch == "e" || _ch == "i" || _ch == "o" || _ch == "u") return "an";
    return "a";
}

// Resolve item flags into a convenient struct: reads global._item_flag_map and builds
// a tolerant flag_set (struct) plus boolean convenience fields.
function bag__resolve_item_flags(_iid, _it){
    var out = { flag_arr: [], flag_set: {}, usable_in_battle: false, is_consumable_flagged: false };
    if (!is_real(_iid) || _iid <= 0) return out;
    if (variable_global_exists("_item_flag_map") && is_array(global._item_flag_map) && _iid > 0 && _iid < array_length(global._item_flag_map)) out.flag_arr = global._item_flag_map[_iid];
    if (!is_array(out.flag_arr)) out.flag_arr = [];
    // build tolerant flag set
    var fset = {};
    for (var fi = 0; fi < array_length(out.flag_arr); fi++){
        var rawf = string_trim(string(out.flag_arr[fi]));
        if (string_length(rawf) == 0) continue;
        var resolved_key = undefined;
        // If token is numeric, try to map to prose entry using data_get_item_flag_entry
        var only_digits = true;
        for (var d = 1; d <= string_length(rawf); d++){ var ch = string_copy(rawf, d, 1); if (ch < "0" || ch > "9") { only_digits = false; break; } }
        if (only_digits && !is_undefined(data_get_item_flag_entry)){
            var ent = data_get_item_flag_entry(rawf);
            if (is_struct(ent)){
                if (variable_struct_exists(ent, "key") && string_length(string_trim(variable_struct_get(ent, "key"))) > 0) resolved_key = string_trim(variable_struct_get(ent, "key"));
                else if (variable_struct_exists(ent, "name") && string_length(string_trim(variable_struct_get(ent, "name"))) > 0) resolved_key = string_lower(string_trim(variable_struct_get(ent, "name")));
            }
        }
        var k = (is_undefined(resolved_key) ? string_lower(string_trim(rawf)) : string_lower(string_trim(resolved_key)));
        k = string_replace_all(k, "_", "-");
        // store both normalized and raw forms for tolerant lookup
        variable_struct_set(fset, k, true);
        variable_struct_set(fset, rawf, true);
    }
    out.flag_set = fset;
    out.usable_in_battle = (is_struct(fset) && (variable_struct_exists(fset, "usable-in-battle") || variable_struct_exists(fset, "usable_in_battle") || variable_struct_exists(fset, "usableinbattle")));
    out.is_consumable_flagged = (is_struct(fset) && (variable_struct_exists(fset, "consumable") || variable_struct_exists(fset, "consumed") ));
    return out;
}

function bag__item_effect_types(_iid){
    var types = [];
    if (!is_real(_iid) || _iid < 0) return types;
    if (!variable_global_exists("_item_effects") || !is_array(global._item_effects)) return types;
    if (_iid >= array_length(global._item_effects)) return types;
    var effs = global._item_effects[_iid];
    if (!is_array(effs)) return types;
    for (var i = 0; i < array_length(effs); ++i){
        var eff = effs[i];
        var t = undefined;
        if (is_struct(eff) && variable_struct_exists(eff, "type")) t = eff.type;
        else if (is_array(eff) && array_length(eff) > 0) t = eff[0];
        if (!is_string(t)) continue;
        var tl = string_lower(string(t));
        var exists = false;
        for (var j = 0; j < array_length(types); ++j){ if (types[j] == tl){ exists = true; break; } }
        if (!exists) array_push(types, tl);
    }
    return types;
}

function bag__effect_types_has(_types, _needle){
    if (!is_array(_types)) return false;
    for (var i = 0; i < array_length(_types); i++){
        if (string(_types[i]) == string(_needle)) return true;
    }
    return false;
}

function bag__machine_move_id(_iid, _it){
    if (!is_real(_iid) || _iid <= 0) return -1;
    if (variable_global_exists("_machine_item_to_move") && is_array(global._machine_item_to_move) && _iid < array_length(global._machine_item_to_move)){
        var mapped = global._machine_item_to_move[_iid];
        if (is_real(mapped) && mapped > 0) return floor(mapped);
    }
    var ident = "";
    if (is_struct(_it)){
        if (variable_struct_exists(_it, "identifier")) ident = string_lower(string(variable_struct_get(_it, "identifier")));
        else if (variable_struct_exists(_it, "name")) ident = string_lower(string(variable_struct_get(_it, "name")));
    }
    if (string_length(ident) >= 4){
        var prefix = string_copy(ident, 1, 2);
        if (prefix == "tm" || prefix == "hm"){
            return -2;
        }
    }
    return -1;
}

function bag__machine_consumes_on_use(_iid, _ident, _flag_set){
    var ident = string_lower(string(_ident));
    if (string_copy(ident, 1, 2) == "hm") return false;
    if (is_struct(_flag_set) && (variable_struct_exists(_flag_set, "consumable") || variable_struct_exists(_flag_set, "consumed"))) return true;
    if (string_copy(ident, 1, 2) == "tm") return true;
    return false;
}

function bag_is_open(_pid){ return (variable_global_exists("BAGS") && is_array(global.BAGS) && array_length(global.BAGS) > _pid && global.BAGS[_pid].open); }
function bag_open(_pid) { if (is_array(global.BAGS) && array_length(global.BAGS) > _pid) global.BAGS[_pid].open = true; }
function bag_close(_pid){ if (is_array(global.BAGS) && array_length(global.BAGS) > _pid) global.BAGS[_pid].open = false; }
function bag_toggle(_pid){ if (!variable_global_exists("BAGS") || !is_array(global.BAGS) || array_length(global.BAGS) <= _pid) return; global.BAGS[_pid].open = !global.BAGS[_pid].open; }

function bag_registered_clear(_pid){
    var _b = bag_inventory_ensure(_pid);
    _b.registered_item_id = -1;
    _b.registered_item_name = "";
    _b.registered_item_real_name = "";
}

function bag_registered_set(_pid, _row){
    var _b = bag_inventory_ensure(_pid);
    if (!is_struct(_row) || !variable_struct_exists(_row, "item_id")) return false;
    variable_struct_set(_b, "registered_item_id", floor(variable_struct_get(_row, "item_id")));
    variable_struct_set(_b, "registered_item_name", variable_struct_exists(_row, "name") ? string(variable_struct_get(_row, "name")) : "");
    variable_struct_set(_b, "registered_item_real_name", variable_struct_exists(_row, "real_name") ? string(variable_struct_get(_row, "real_name")) : string(variable_struct_get(_b, "registered_item_name")));
    return true;
}

function bag_registered_matches_row(_pid, _row){
    if (!is_struct(_row) || !variable_struct_exists(_row, "item_id")) return false;
    var _b = bag_inventory_ensure(_pid);
    if (!variable_struct_exists(_b, "registered_item_id")) return false;
    return floor(variable_struct_get(_row, "item_id")) == floor(variable_struct_get(_b, "registered_item_id"));
}

function bag_registered_find_row(_pid, _item_id){
    var _iid = is_real(_item_id) ? floor(_item_id) : -1;
    if (_iid <= 0) return undefined;
    var _b = bag_inventory_ensure(_pid);
    if (bag_inventory_get_qty(_pid, _iid) <= 0) return undefined;

    var _pages = variable_struct_exists(_b, "items") ? variable_struct_get(_b, "items") : [];
    if (is_array(_pages)){
        for (var _p = 0; _p < array_length(_pages); ++_p){
            var _arr = _pages[_p];
            if (!is_array(_arr)) continue;
            for (var _i = 0; _i < array_length(_arr); ++_i){
                var _row = _arr[_i];
                if (is_struct(_row) && variable_struct_exists(_row, "item_id") && floor(_row.item_id) == _iid) return _row;
            }
        }
    }

    var _it = undefined;
    if (variable_global_exists("_items") && is_array(global._items) && _iid < array_length(global._items)) _it = global._items[_iid];
    if (!is_struct(_it)) return undefined;

    var _desc = bag__resolve_item_desc(_iid);
    var _icon = bag__get_item_placeholder();
    var _lookup_name = undefined;
    if (variable_struct_exists(_it, "identifier") && string_length(string_trim(variable_struct_get(_it, "identifier"))) > 0) _lookup_name = string(variable_struct_get(_it, "identifier"));
    else if (variable_struct_exists(_it, "name") && string_length(string_trim(variable_struct_get(_it, "name"))) > 0) _lookup_name = string(variable_struct_get(_it, "name"));
    if (!is_undefined(pkicons_get_item_icon_by_name) && !is_undefined(_lookup_name)){
        var _spr = pkicons_get_item_icon_by_name(_lookup_name);
        if (!is_undefined(_spr) && sprite_exists(_spr)) _icon = _spr;
    }

    var _name = bag__item_display_name(_iid, undefined, _it);
    var _real_name = !is_undefined(_lookup_name) ? _lookup_name : _name;
    return { name:_name, real_name:_real_name, qty:bag_inventory_get_qty(_pid, _iid), desc:_desc, icon:_icon, item_id:_iid };
}

function bag_registered_use(_pid){
    var _b = bag_inventory_ensure(_pid);
    var _iid = variable_struct_exists(_b, "registered_item_id") ? floor(variable_struct_get(_b, "registered_item_id")) : -1;
    if (_iid <= 0){
        try { dialog2p_show_now(_pid, "No item registered."); } catch (e_no_registered_now) { try { dialog2p_show(_pid, "No item registered."); } catch (e_no_registered) {} }
        return false;
    }

    if (bag_inventory_get_qty(_pid, _iid) <= 0){
        bag_registered_clear(_pid);
        try { dialog2p_show_now(_pid, "The registered item is no longer in the Bag."); } catch (e_missing_registered_now) { try { dialog2p_show(_pid, "The registered item is no longer in the Bag."); } catch (e_missing_registered) {} }
        return false;
    }

    var _row = bag_registered_find_row(_pid, _iid);
    if (!is_struct(_row)){
        bag_registered_clear(_pid);
        try { dialog2p_show_now(_pid, "The registered item could not be found."); } catch (e_missing_row_now) { try { dialog2p_show(_pid, "The registered item could not be found."); } catch (e_missing_row) {} }
        return false;
    }

    if (is_undefined(bag__use_item_on_self)) return false;
    return bag__use_item_on_self(_pid, _row);
}

// Open the bag in a battle-aware mode. This sets a mode flag so the bag UI
// and Use/Give/Discard behaviors can adapt while a battle is active.
function bag_open_for_battle(_pid){
    var _b = bag_inventory_ensure(_pid);
    _b.open = true;
    _b.mode = "battle";
    _b.lock = 6; // short lock to avoid immediate double-input from menu transition
    _b.item_menu_open = false;
    _b.item_menu_sel = 0;
    // Clear party-give flags if present
    if (variable_struct_exists(_b, "give_from_party")) { _b.give_from_party = false; _b.give_to_mon = undefined; }
}

function bag__battle_item_target_block_reason(_pid, _target, _item_id){
    if (is_undefined(battle_is_open) || !battle_is_open(_pid)) return "";
    if (is_undefined(status_system_has_status) || !is_struct(_target)) return "";

    var _blocked = false;
    try { _blocked = status_system_has_status(_target, "embargo"); } catch (e_bag_embargo) { _blocked = false; }
    if (!_blocked) return "";

    var _name = "That Pokémon";
    try {
        if (!is_undefined(__status_mon_display_name)) _name = string(__status_mon_display_name(_target));
        else if (!is_undefined(mon_display_name)) _name = string(mon_display_name(_target));
        else if (variable_struct_exists(_target, "name") && string_length(string(variable_struct_get(_target, "name"))) > 0) _name = string(variable_struct_get(_target, "name"));
    } catch (e_bag_name) { _name = "That Pokémon"; }
    return _name + " can't receive items because of Embargo!";
}

// Default in-battle Use handler. Call this from the bag UI when the player
// selects Use while the bag is open in battle mode. It implements a small set
// of commonly expected behaviors (Poké Ball -> attempt catch, basic Potion
// healing), and otherwise reports that the item can't be used here.
// Parameters:
//   _pid: player id
//   _row: a bag row struct (as produced by bags_seed_from_items) containing item_id and name

function bag__store_captured_mon(_pid, _mon){
    if (!is_undefined(party_model_store_caught_mon)){
        return party_model_store_caught_mon(_pid, _mon);
    }

    if (!is_undefined(pc_store_mon)){
        var _ok = pc_store_mon(_pid, _mon);
        return { ok:_ok, location:(_ok ? "stored" : "none"), mon:_mon };
    }

    if (!is_undefined(party_model_add_mon)){
        var _slot = bag__store_captured_mon(_pid, _mon);
        return { ok:(_slot >= 0), location:"party", slot_index:_slot, mon:_mon };
    }

    return { ok:false, location:"none", mon:_mon };
}

function bag__use_item_on_self(_pid, _row){
    if (!is_struct(_row) || !variable_struct_exists(_row, "item_id")) return false;
    var iid = floor(_row.item_id);
    var it = undefined;
    if (variable_global_exists("_items") && is_array(global._items) && iid >= 0 && iid < array_length(global._items)) it = global._items[iid];

    // trainer/name
    var trainer = "YOU";
    if (is_undefined(party_ensure) == false){
        var Pn = party_ensure(_pid);
        if (is_struct(Pn) && variable_struct_exists(Pn, "name") && string_length(string(variable_struct_get(Pn, "name"))) > 0) trainer = string(variable_struct_get(Pn, "name"));
        else if (variable_global_exists("PLAYER_NAME")) trainer = string(global.PLAYER_NAME);
    } else if (variable_global_exists("PLAYER_NAME")) trainer = string(global.PLAYER_NAME);

    var disp = bag__item_display_name(iid, _row, it);
    var prefix = string(trainer) + " used " + bag__item_article(disp) + " " + string(disp) + "!";

    // Determine whether we're in a battle. Some item behaviors (Poké Balls)
    // are battle-only; others (consumables like Potions) should work outside
    // of battle and open the party selector. We avoid an early-return here
    // so out-of-battle handlers below can run.
    var inBattle = (!is_undefined(battle_is_open) && battle_is_open(_pid));
    if (!inBattle){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[bag][debug] not in battle: proceeding with out-of-battle handlers (pid=" + string(_pid) + ")");
    }

    // When inBattle only: ensure slot state
    var _B = undefined;
    if (inBattle){
        _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B)){
            show_debug_message("[bag][debug] abort: __battle_ensure_slot returned non-struct for pid=" + string(_pid));
            return false;
        }
    }
    var _battle_action_actor_index = 0;
    if (inBattle && is_struct(_B)){
        try {
            if (variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true && !is_undefined(__battle_command_ui_state)){
                var _bag_ui = __battle_command_ui_state(_B, _pid);
                if (is_struct(_bag_ui) && variable_struct_exists(_bag_ui, "command_actor_index") && is_real(variable_struct_get(_bag_ui, "command_actor_index"))){
                    _battle_action_actor_index = floor(variable_struct_get(_bag_ui, "command_actor_index"));
                }
            } else if (variable_struct_exists(_B, "_command_actor_index") && is_real(variable_struct_get(_B, "_command_actor_index"))){
                _battle_action_actor_index = floor(variable_struct_get(_B, "_command_actor_index"));
            }
            if (!is_undefined(__battle_actor_control_pid) && __battle_actor_control_pid(_pid, _battle_action_actor_index) != _pid){
                _battle_action_actor_index = __battle_actor_index_for_side_slot(_pid, 0, 0);
            }
            if (!is_real(_battle_action_actor_index) || _battle_action_actor_index < 0) _battle_action_actor_index = 0;
        } catch (e_bag_actor_index) { _battle_action_actor_index = 0; }
    }

    // NOTE: flag array and usable_in_battle are determined later. Check moved down after flags are parsed.

    // Heuristic: pokéballs attempt capture
    var ident = "";
    if (is_struct(it)){
        if (variable_struct_exists(it, "identifier")) ident = string_lower(string(variable_struct_get(it, "identifier")));
        else if (variable_struct_exists(it, "name")) ident = string_lower(string(variable_struct_get(it, "name")));
    }

    var effect_types = bag__item_effect_types(iid);
    var recognized_party_consumable = false;
    var recognized_direct_item = false;
    if (is_array(effect_types)){
        for (var et_i = 0; et_i < array_length(effect_types); ++et_i){
            var etype = effect_types[et_i];
            if (!is_string(etype)) continue;
            if (etype == "heal_flat" || etype == "heal_full" || etype == "full_restore" || etype == "revive" || etype == "revive_half" || etype == "revive_full" || etype == "revive_all" || etype == "cure_status" || etype == "cure_all" || etype == "restore_pp"){
                recognized_party_consumable = true;
            }
            if (etype == "ev_raise" || etype == "ev_drop" || etype == "level_up" || etype == "pp_up" || etype == "evolve_item"){
                recognized_party_consumable = true;
            }
            if (etype == "escape_battle" || etype == "repel" || etype == "encounter_rate" || etype == "battle_stage" || etype == "dire_hit" || etype == "guard_spec"){
                recognized_direct_item = true;
            }
        }
    }

    var page = bag__item_to_page(iid, it);
    var consumed = false;
    var out_txt = prefix;
    // Resolve flags using the centralized resolver which also maps numeric tokens
    // to prose keys using the data loader helpers.
    var _rf = bag__resolve_item_flags(iid, it);
    var flag_arr = (is_struct(_rf) && variable_struct_exists(_rf, "flag_arr")) ? variable_struct_get(_rf, "flag_arr") : [];
    var flag_set = (is_struct(_rf) && variable_struct_exists(_rf, "flag_set")) ? variable_struct_get(_rf, "flag_set") : {};
    var usable_in_battle = (is_struct(_rf) && variable_struct_exists(_rf, "usable_in_battle")) ? variable_struct_get(_rf, "usable_in_battle") : false;
    var is_consumable_flagged = (is_struct(_rf) && variable_struct_exists(_rf, "is_consumable_flagged")) ? variable_struct_get(_rf, "is_consumable_flagged") : false;
    var allow_out_of_battle = false; // local helper to permit out-of-battle flows for flagged items

    // If the item has explicit flags but isn't marked usable-in-battle, we used to block it here entirely.
    // That made some items unusable outside battle when flag maps existed but didn't include a 'consumable' hint.
    // Change: only block when we're currently *in* a battle. Outside battle, prefer to allow out-of-battle handlers
    // (party selection / consumable application) so players can use items like Potions even if flags are incomplete.
    if (is_array(flag_arr) && array_length(flag_arr) > 0 && !usable_in_battle && !is_consumable_flagged && !recognized_party_consumable && !recognized_direct_item){
        if (inBattle){
            show_debug_message("[bag][debug] abort: item has flags but not usable_in_battle and not consumable (iid=" + string(iid) + ")");
            out_txt += "\nYou can't use that here.";
            try { dialog2p_show(_pid, out_txt); } catch (e_) {}
            return false;
        } else {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[bag][debug] flagged item not usable_in_battle but not in battle — allowing out-of-battle handlers (iid=" + string(iid) + ")");
            // Permit out-of-battle handling for flagged-but-not-usable items so players
            // can still use consumables (Potions, Revives) even when flag maps are incomplete.
            allow_out_of_battle = true;
        }
    }

    // Debug: dump resolved flags and decision values when using an item
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        var eff_dbg = "";
        if (is_array(effect_types)){
            for (var ed = 0; ed < array_length(effect_types); ++ed){
                if (ed > 0) eff_dbg += ",";
                eff_dbg += string(effect_types[ed]);
            }
        }
        show_debug_message("[bag][debug] use_item_on_self iid=" + string(iid) + ", flag_arr=" + string(flag_arr) + ", usable_in_battle=" + string(usable_in_battle) + ", is_consumable_flagged=" + string(is_consumable_flagged) + ", ident=" + string(ident) + ", recognized_party=" + string(recognized_party_consumable) + ", effects=[" + eff_dbg + "]");
    }

    if (recognized_direct_item){
        if (bag__effect_types_has(effect_types, "repel") || bag__effect_types_has(effect_types, "encounter_rate")){
            if (inBattle){
                out_txt += "\nYou can't use that here.";
                try { dialog2p_show(_pid, out_txt); } catch (e_field_in_battle) {}
                return false;
            }
            if (!variable_global_exists("BAG_FIELD_EFFECTS") || !is_array(global.BAG_FIELD_EFFECTS)) global.BAG_FIELD_EFFECTS = [];
            if (array_length(global.BAG_FIELD_EFFECTS) <= _pid) array_resize(global.BAG_FIELD_EFFECTS, _pid + 1);
            var _field = global.BAG_FIELD_EFFECTS[_pid];
            if (!is_struct(_field)) _field = { repel_steps:0, encounter_rate_steps:0, encounter_rate_multiplier:1 };
            var _effs_field = (variable_global_exists("_item_effects") && is_array(global._item_effects) && iid < array_length(global._item_effects)) ? global._item_effects[iid] : [];
            for (var _fei = 0; _fei < array_length(_effs_field); _fei++){
                var _fe = _effs_field[_fei];
                if (!is_struct(_fe)) continue;
                var _ft = variable_struct_exists(_fe, "type") ? string(_fe.type) : "";
                var _fp = variable_struct_exists(_fe, "params") ? _fe.params : {};
                if (_ft == "repel"){
                    _field.repel_steps = (is_struct(_fp) && variable_struct_exists(_fp, "steps")) ? max(1, floor(_fp.steps)) : 250;
                } else if (_ft == "encounter_rate"){
                    _field.encounter_rate_steps = (is_struct(_fp) && variable_struct_exists(_fp, "steps")) ? max(1, floor(_fp.steps)) : 250;
                    _field.encounter_rate_multiplier = (is_struct(_fp) && variable_struct_exists(_fp, "multiplier")) ? real(_fp.multiplier) : 1;
                }
            }
            global.BAG_FIELD_EFFECTS[_pid] = _field;
            bag_inventory_remove_item(_pid, iid, 1);
            bags_seed_from_items(_pid);
            bag_close(_pid);
            try { dialog2p_show(_pid, out_txt + "\nIt took effect."); } catch (e_field_dialog) {}
            return true;
        }

        if (bag__effect_types_has(effect_types, "escape_battle")){
            if (!inBattle || !is_struct(_B)){
                out_txt += "\nYou can't use that here.";
                try { dialog2p_show(_pid, out_txt); } catch (e_escape_no_battle) {}
                return false;
            }
            var _battle_mode_direct = variable_struct_exists(_B, "battle_type") ? string_lower(string(_B.battle_type)) : "wild";
            var _battle_versus_direct = (variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true);
            if (_battle_mode_direct == "trainer" || _battle_versus_direct){
                out_txt += "\nNo! There's no running from a Trainer battle!";
                try { dialog2p_show(_pid, out_txt); } catch (e_escape_trainer) {}
                return false;
            }
            _B.result = "escaped";
            _B._pending_close = true;
            bag_inventory_remove_item(_pid, iid, 1);
            bags_seed_from_items(_pid);
            bag_close(_pid);
            try { dialog2p_show(_pid, out_txt + "\nGot away safely!"); } catch (e_escape_dialog) {}
            return true;
        }

        if (bag__effect_types_has(effect_types, "battle_stage") || bag__effect_types_has(effect_types, "dire_hit") || bag__effect_types_has(effect_types, "guard_spec")){
            if (!inBattle || !is_struct(_B)){
                out_txt += "\nYou can't use that here.";
                try { dialog2p_show(_pid, out_txt); } catch (e_x_no_battle) {}
                return false;
            }
            var _actors_direct = variable_struct_exists(_B, "actor") ? _B.actor : undefined;
            var _A_direct = (is_array(_actors_direct) && _battle_action_actor_index >= 0 && _battle_action_actor_index < array_length(_actors_direct)) ? _actors_direct[_battle_action_actor_index] : undefined;
            var _M_direct = (is_struct(_A_direct) && variable_struct_exists(_A_direct, "mon") && is_struct(_A_direct.mon)) ? _A_direct.mon : _A_direct;
            var _res_direct = (!is_undefined(scr_apply_item_effects)) ? scr_apply_item_effects(iid, _M_direct, _A_direct) : { applied:false };
            if (is_struct(_res_direct) && _res_direct.applied){
                bag_inventory_remove_item(_pid, iid, 1);
                bags_seed_from_items(_pid);
                bag_close(_pid);
                var _detail_direct = out_txt;
                if (variable_struct_exists(_res_direct, "messages") && is_array(_res_direct.messages) && array_length(_res_direct.messages) > 0) _detail_direct += "\n" + string(_res_direct.messages[0]);
                try { dialog2p_show(_pid, _detail_direct); } catch (e_x_dialog) {}
                return true;
            }
            out_txt += "\nBut it had no effect!";
            try { dialog2p_show(_pid, out_txt); } catch (e_x_no_effect) {}
            return false;
        }
    }

    var machine_move_id = bag__machine_move_id(iid, it);
    if (machine_move_id != -1){
        if (inBattle){
            out_txt += "\nYou can't use that here.";
            try { dialog2p_show(_pid, out_txt); } catch (e_machine_battle) {}
            return false;
        }
        if (machine_move_id <= 0){
            out_txt += "\nThe machine data is missing for this item.";
            try { dialog2p_show(_pid, out_txt); } catch (e_machine_missing) {}
            return false;
        }
        if (!is_undefined(party_open) && !is_undefined(party_ensure)){
            var _b_machine = bag_inventory_ensure(_pid);
            bag_close(_pid);
            party_open(_pid);
            var P_machine = party_ensure(_pid);
            if (is_struct(P_machine)){
                P_machine.mode = "select_item";
                P_machine.lock = 4;
                P_machine.teach_pending = {
                    bag_pid: _pid,
                    page: _b_machine.page,
                    row: _b_machine.sel,
                    item_id: iid,
                    item_real_name: (variable_struct_exists(_row, "real_name") ? variable_struct_get(_row, "real_name") : ident),
                    move_id: machine_move_id,
                    consumes: bag__machine_consumes_on_use(iid, ident, flag_set),
                    out_prefix: out_txt
                };
                P_machine.use_pending = undefined;
            }
            return true;
        }
    }

    // Pokéball behavior — only allowed on wild opponents (battle-only)
    if (page == 1 || string_pos("ball", ident) > 0){
        if (!inBattle){
            out_txt += "\nYou can't use that here.";
            try { dialog2p_show(_pid, out_txt); } catch (e_) {}
            return false;
        }
        var battle_mode = "wild";
        if (variable_struct_exists(_B, "battle_type")) battle_mode = string_lower(string(variable_struct_get(_B, "battle_type")));
        else if (variable_struct_exists(_B, "_battle_mode")) battle_mode = string_lower(string(variable_struct_get(_B, "_battle_mode")));
        var A1 = undefined;
        if (!is_undefined(__battle_get_side_actor)) A1 = __battle_get_side_actor(_pid, 1, 0);
        if (!is_struct(A1)){
            var _actor_arr = (variable_struct_exists(_B, "actor") ? variable_struct_get(_B, "actor") : undefined);
            A1 = (is_array(_actor_arr) && array_length(_actor_arr) > 1) ? _actor_arr[1] : undefined;
        }
        if (!is_struct(A1)){
            out_txt += "\nBut nothing happened.";
            try { dialog2p_show(_pid, out_txt); } catch (e_) {}
            return false;
        }

        // Wild-vs-trainer is tracked on the battle slot. Avoid inferring it from
        // actor payload shape because wild battlers may also carry canonical mon fields.
        var _battle_versus_ball = (variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true);
        var is_wild = (battle_mode != "trainer" && !_battle_versus_ball);

        if (!is_wild){
            // Explicit feedback for unusable item in this context
            out_txt += "\nThe opposing Trainer blocked the Ball! Don't be a thief!";
            try { dialog2p_show(_pid, out_txt); } catch (e_) {}
            return false;
        }

        // Delegate to the battle turn system so the ball is consumed only when the
        // action actually executes, and double wild battles can target a specific foe.
        var ball_mult = bag__get_ball_modifier(iid);
        if (true){
            var action_actor_index = _battle_action_actor_index;
            var _bag_versus_action = (variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true);
            if (!_bag_versus_action && !is_undefined(__battle_actor_side) && __battle_actor_side(action_actor_index) != 0) action_actor_index = 0;

            var target_candidates = [];
            var battle_format = (variable_struct_exists(_B, "battle_format") ? string_lower(string(variable_struct_get(_B, "battle_format"))) : "single");
            if (battle_format == "double"){
                var _actors = (variable_struct_exists(_B, "actor") ? variable_struct_get(_B, "actor") : undefined);
                if (is_array(_actors) && !is_undefined(__battle_actor_side) && !is_undefined(__battle_actor_index_alive)){
                    for (var _ai = 0; _ai < array_length(_actors); ++_ai){
                        if (__battle_actor_side(_ai) != 1) continue;
                        if (!__battle_actor_index_alive(_pid, _ai)) continue;
                        array_push(target_candidates, _ai);
                    }
                }
            } else {
                if (is_undefined(__battle_actor_index_alive) || __battle_actor_index_alive(_pid, 1)) array_push(target_candidates, 1);
            }
            if (array_length(target_candidates) <= 0){
                out_txt += "\nBut there was no wild target.";
                try { dialog2p_show(_pid, out_txt); } catch (e_) {}
                return false;
            }

            var default_target = target_candidates[0];
            if (!is_undefined(__battle_get_default_target_index)) default_target = __battle_get_default_target_index(_pid, action_actor_index);
            var _bag_return_state = undefined;
            var _bag_state = bag_inventory_ensure(_pid);
            if (is_struct(_bag_state)){
                _bag_return_state = {
                    page: (variable_struct_exists(_bag_state, "page") ? variable_struct_get(_bag_state, "page") : 0),
                    sel: (variable_struct_exists(_bag_state, "sel") ? variable_struct_get(_bag_state, "sel") : 0),
                    scroll: (variable_struct_exists(_bag_state, "scroll") ? variable_struct_get(_bag_state, "scroll") : 0),
                    item_menu_row: (variable_struct_exists(_bag_state, "item_menu_row") ? variable_struct_get(_bag_state, "item_menu_row") : 0)
                };
            }
            var actP = { item_use: true, item_id: iid, ball_mult: ball_mult, actor_index: action_actor_index, target_index: default_target, bag_return_state: _bag_return_state };

            bag_close(_pid);

            if (array_length(target_candidates) > 1 && !is_undefined(__battle_commit_player_action)){
                if (!is_undefined(__battle_sort_target_candidates)) target_candidates = __battle_sort_target_candidates(_pid, action_actor_index, target_candidates);
                variable_struct_set(_B, "_command_pending_action", actP);
                variable_struct_set(_B, "_target_pick_targets", target_candidates);
                var target_sel = 0;
                if (!is_undefined(__battle_target_candidate_select_index)) target_sel = __battle_target_candidate_select_index(target_candidates, default_target);
                variable_struct_set(_B, "_target_pick_index", target_sel);
                try { variable_struct_set(_B, "_input_grace_until", current_time + 180); } catch (e_ball_target_grace) {}
                var _sys_ui = variable_struct_exists(_B, "sys_ui") ? variable_struct_get(_B, "sys_ui") : undefined;
                if (is_struct(_sys_ui)){
                    variable_struct_set(_sys_ui, "menu", "target");
                    variable_struct_set(_sys_ui, "selX", target_sel mod 2);
                    variable_struct_set(_sys_ui, "selY", target_sel div 2);
                }
                return true;
            }

            if (array_length(target_candidates) > 0){
                var target_valid = false;
                for (var _tc_i = 0; _tc_i < array_length(target_candidates); ++_tc_i){
                    if (target_candidates[_tc_i] == default_target){ target_valid = true; break; }
                }
                if (!target_valid) variable_struct_set(actP, "target_index", target_candidates[0]);
            }

            if (!is_undefined(__battle_commit_player_action)) consumed = __battle_commit_player_action(_pid, actP);
            else {
                if (is_struct(_B)) variable_struct_set(_B, "turn_action_player", actP);
                if (is_struct(_B)) variable_struct_set(_B, "turn_action_enemy", (is_undefined(__battle_enemy_choose_action) ? undefined : __battle_enemy_choose_action(_pid)));
                if (is_struct(_B)) variable_struct_set(_B, "turn_queue", (is_undefined(__battle_build_turn_actions) ? undefined : __battle_build_turn_actions(_pid)));
                if (is_struct(_B)) variable_struct_set(_B, "turn_i", 0);
                if (is_struct(_B)) variable_struct_set(_B, "phase", "turn");
                consumed = true;
            }
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[bag][debug] queued item as player turn pid=" + string(_pid) + ", iid=" + string(iid) + ", mult=" + string(ball_mult) + ", target=" + string(variable_struct_get(actP, "target_index")));
        } else {
            // fallback: immediate chance resolution (legacy)
            var a1_hp_now = (variable_struct_exists(A1, "hp_now") ? variable_struct_get(A1, "hp_now") : (variable_struct_exists(A1, "hp") ? variable_struct_get(A1, "hp") : 0));
            var a1_hp_max = (variable_struct_exists(A1, "hp_max") ? variable_struct_get(A1, "hp_max") : (variable_struct_exists(A1, "maxhp") ? variable_struct_get(A1, "maxhp") : 1));
            var hpPct = max(0, min(1, a1_hp_now / max(1, a1_hp_max)));
            var chance = clamp(floor((1 - hpPct) * 70) + 20, 5, 95);
            var success = (irandom(99) < chance);
            if (success){
                variable_struct_set(_B, "result", "caught");
                var caught = undefined;
                if (variable_struct_exists(A1, "mon") && is_struct(variable_struct_get(A1, "mon"))) caught = variable_struct_get(A1, "mon");
                else if (is_struct(A1)) caught = A1;
                if (is_struct(caught)){
                    if (!variable_struct_exists(caught, "exp")) variable_struct_set(caught, "exp", 0);
                    var clevel = (variable_struct_exists(caught, "level") && is_real(variable_struct_get(caught, "level"))) ? variable_struct_get(caught, "level") : 1;
                    if (!variable_struct_exists(caught, "exp_next")) variable_struct_set(caught, "exp_next", max(20, clevel * clevel * 2));
                }
                var a1name = (variable_struct_exists(A1, "name") ? string(variable_struct_get(A1, "name")) : "?");
                out_txt += "\nGotcha!\nYou caught " + string(a1name) + "!";
                consumed = true;
                variable_struct_set(_B, "_pending_close", true);
            } else {
                out_txt += "\nOh no! The Pokémon broke free!";
                consumed = true;
            }
        }
        // Ball consumption now occurs when the queued battle action executes.
    // If we enqueued a catch on the battle slot (either via _queued_catch or by
    // setting turn_action_player with item_use), the battle system will show
    // the result dialog later. Avoid opening a duplicate dialog now.
    var _should_open = true;
    if (variable_struct_exists(_B, "_queued_catch") && is_struct(variable_struct_get(_B, "_queued_catch"))) _should_open = false;
    if (variable_struct_exists(_B, "turn_action_player") && is_struct(variable_struct_get(_B, "turn_action_player")) && variable_struct_exists(variable_struct_get(_B, "turn_action_player"), "item_use") && variable_struct_get(variable_struct_get(_B, "turn_action_player"), "item_use") == true) _should_open = false;
    if (_should_open) { try { dialog2p_show(_pid, out_txt); } catch(e_){} }
        return consumed;
    }

    var ident_lower = string_lower(string(ident));
    var disp_lower = string_lower(string(disp));
    var should_open_party = recognized_party_consumable;
    if (!should_open_party){
        var heur = ident_lower;
        if (string_length(heur) == 0) heur = disp_lower;
        if (string_pos("potion", heur) > 0 || string_pos("revive", heur) > 0 || string_pos("heal", heur) > 0 || string_pos("status", heur) > 0 || string_pos("berry", heur) > 0 || string_pos("ether", heur) > 0 || string_pos("elixir", heur) > 0 || string_pos("powder", heur) > 0 || string_pos("herb", heur) > 0){
            should_open_party = true;
        }
    }

    // Basic healing/status/PP items: defer to party selector when recognized
    if ((usable_in_battle || is_consumable_flagged || allow_out_of_battle || (!is_array(flag_arr) || array_length(flag_arr) == 0) || recognized_party_consumable) && should_open_party){
    // Instead of applying immediately to the active battler, open the party
    // selector so the player can choose which Pokémon to use the consumable on.
    var _b = bag_inventory_ensure(_pid);
    // Store a pending-use payload on the party so party_input can apply it when the player selects a mon.
    if (!is_undefined(party_open) && !is_undefined(party_ensure)){
        // Close bag and open party in select_item mode with a use_pending struct
        // Do NOT open the dialog here — the party UI draws on top of the bag and
        // may also occlude dialog boxes. Instead, party_input will close the
        // party and open the dialog after the player selects a target.
        bag_close(_pid);
        party_open(_pid);
        var P = party_ensure(_pid);
        if (is_struct(P)){
            P.mode = "select_item";
            P.lock = 4;
            // use_pending mirrors give_pending shape but denotes a use action
            P.use_pending = { bag_pid: _pid, page: _b.page, row: _b.sel, item_id: iid, item_real_name: (variable_struct_exists(_row, "real_name") ? variable_struct_get(_row, "real_name") : (is_struct(it) && variable_struct_exists(it, "identifier") ? variable_struct_get(it, "identifier") : "")), out_prefix: out_txt };
        }
        return true;
    }
    }

    // Default: not usable in battle
    show_debug_message("[bag][debug] abort: default fallthrough — not usable (iid=" + string(iid) + ")");
    out_txt += "\nYou can't use that here.";
    try { dialog2p_show(_pid, out_txt); } catch (e_) {}
    return false;
}

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
            bag__ensure_props(_b, ["items","sys_qty","page","sel","scroll","spin_ticks","mode","open","item_menu_open","item_menu_sel","item_menu_row","lock","registered_item_id","registered_item_name","registered_item_real_name"], [bag__empty_items(), [], 0, 0, 0, 0, "bag", false, false, 0, 0, 0, -1, "", ""]);
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

        var desc = bag__resolve_item_desc(iid);
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
            array_push(_b.items[0], { name:bag__clean_display_name(nm), real_name: realnm2, qty:qtp, desc:bag__resolve_item_desc(iidp), icon:ic, item_id:iidp });
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

// Debug: list all items that the current rules consider holdable
function bag_debug_list_holdables(){
    // Basic presence checks
    if (!variable_global_exists("_items") || !is_array(global._items)) { show_debug_message("[bag_debug] ERROR: global._items not loaded (length missing)"); return; }
    var items_len = array_length(global._items);
    var fmap_len = (variable_global_exists("_item_flag_map") && is_array(global._item_flag_map)) ? array_length(global._item_flag_map) : 0;
    var prose_ok = (variable_global_exists("_item_flag_text_by_code") && is_struct(global._item_flag_text_by_code));
    show_debug_message("[bag_debug] scanning items for holdable=true | items_len=" + string(items_len) + " flag_map_len=" + string(fmap_len) + " prose_table=" + string(prose_ok));

    // If flag map is empty, print a hint about loader ordering
    if (fmap_len == 0) show_debug_message("[bag_debug] NOTE: _item_flag_map is empty. This may indicate loaders haven't run yet or CSV was missing. Ensure data_load_item_flag_map_structs() executed.");

    var found = 0;
    var sample_show = 0;
    for (var iid = 1; iid < items_len; iid++){
        var it = global._items[iid]; if (!is_struct(it)) continue;
        var ok = false;
        if (!is_undefined(bag__item_is_holdable)) ok = bag__item_is_holdable(iid);
        if (ok){
            var ident = (variable_struct_exists(it, "identifier") ? it.identifier : (variable_struct_exists(it, "name") ? it.name : string(iid)));
            var fmap = (variable_global_exists("_item_flag_map") && is_array(global._item_flag_map) && iid < array_length(global._item_flag_map)) ? global._item_flag_map[iid] : [];
            show_debug_message("[bag_debug][holdable] " + string(iid) + ": " + string(ident) + " flags=" + string(fmap));
            found++;
            // show a small sample of the first few holdables
            sample_show++;
            if (sample_show >= 50) break;
        }
    }
    show_debug_message("[bag_debug] total holdable items=" + string(found));
    // If none found, provide additional hints for troubleshooting
    if (found == 0){
        show_debug_message("[bag_debug] HINT: No items were marked holdable. If you expect some, check: ");
        show_debug_message("  - Confirm data CSVs exist: data/csv/item_flag_map.csv and item_flag_prose.csv");
        show_debug_message("  - Ensure data_load_profile_run() or data_load_all_structs_ext() ran before this call");
        show_debug_message("  - Run bag_debug_list_holdables() manually from an in-game console after startup to rule out ordering issues");
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

// Determine whether an item can be held by a Pokemon.
// Accepts: an item row struct (with .item_id), an item id (number), or an identifier/name (string).
// Returns true if the item is considered holdable (based on item_flags and heuristics), false otherwise.
function bag__item_is_holdable(_item){
    // Resolve to item id if possible
    var iid = -1;
    if (is_struct(_item)){
        if (variable_struct_exists(_item, "item_id") && is_real(_item.item_id)) iid = floor(_item.item_id);
        else if (variable_struct_exists(_item, "identifier") && is_string(_item.identifier)){
            var ident = string_lower(string_trim(_item.identifier));
            // search global._items for matching identifier
            if (variable_global_exists("_items") && is_array(global._items)){
                for (var ii = 1; ii < array_length(global._items); ii++){
                    var it = global._items[ii]; if (!is_struct(it)) continue;
                    if (variable_struct_exists(it, "identifier") && string_lower(string_trim(it.identifier)) == ident){ iid = ii; break; }
                    if (variable_struct_exists(it, "name") && string_lower(string_trim(it.name)) == ident){ iid = ii; break; }
                }
            }
        }
    } else if (is_real(_item)){
        iid = floor(_item);
    } else if (is_string(_item)){
        var idl = string_lower(string_trim(_item));
        if (variable_global_exists("_items") && is_array(global._items)){
            for (var ii2 = 1; ii2 < array_length(global._items); ii2++){
                var it2 = global._items[ii2]; if (!is_struct(it2)) continue;
                if (variable_struct_exists(it2, "identifier") && string_lower(string_trim(it2.identifier)) == idl){ iid = ii2; break; }
                if (variable_struct_exists(it2, "name") && string_lower(string_trim(it2.name)) == idl){ iid = ii2; break; }
            }
        }
    }

    if (iid <= 0) return false;

    // If item_flag_map exists, check for holdable flags
    if (variable_global_exists("_item_flag_map") && is_array(global._item_flag_map) && iid < array_length(global._item_flag_map)){
        var fmap = global._item_flag_map[iid];
        if (is_array(fmap)){
            // Normalize flags: if numeric ids are present, try to map them to prose codes
            for (var fi = 0; fi < array_length(fmap); fi++){
                var raw = fmap[fi];
                var code = string_lower(string_trim(raw));
                var resolved = code;
                // If code looks numeric, and a prose-by-code table exists, map it to the prose key
                var only_digits = true;
                for (var cc = 1; cc <= string_length(code); cc++){ var ch = string_copy(code, cc, 1); if (ch < "0" || ch > "9") { only_digits = false; break; } }
                if (only_digits){
                    var entry = undefined;
                    if (!is_undefined(data_get_item_flag_entry)) entry = data_get_item_flag_entry(code);
                    if (is_struct(entry)){
                        // Prefer the normalized key produced by the prose loader, fall back to name (use safe accessors)
                        if (variable_struct_exists(entry, "key") && string_length(string_trim(variable_struct_get(entry, "key"))) > 0) resolved = string_trim(variable_struct_get(entry, "key"));
                        else if (variable_struct_exists(entry, "name") && string_length(string_trim(variable_struct_get(entry, "name"))) > 0) resolved = string_lower(string_trim(variable_struct_get(entry, "name")));
                    }
                }
                // Normalize underscores to hyphens for consistent comparison (e.g., holdable_passive -> holdable-passive)
                resolved = string_replace_all(resolved, "_", "-");

                // Decision rules: only explicit holdable-passive/active are allowed.
                // NOTE: some data sources include a generic 'holdable' token that is too broad
                // for gameplay; only treat explicit passive/active holdable flags as valid.
                if (resolved == "holdable-passive" || resolved == "holdable-active"){
                    return true;
                }
                // explicit exclusions
                if (resolved == "key" || resolved == "key_item" || resolved == "mail"){
                    return false;
                }
            }
        }
    }

    // Fallback heuristics: allow most items that aren't clearly key/consumable/reserved
    // Disallow common non-holdable categories by identifier
    if (variable_global_exists("_items") && is_array(global._items) && iid < array_length(global._items)){
        var rec = global._items[iid];
        if (is_struct(rec)){
            var ident2 = "";
            if (variable_struct_exists(rec, "identifier")) ident2 = string_lower(string_trim(rec.identifier));
            else if (variable_struct_exists(rec, "name")) ident2 = string_lower(string_trim(rec.name));
            // disallow TM/HM and pokeballs by identifier heuristics
            if (string_pos("tm", ident2) == 1 || string_pos("hm", ident2) == 1) return false;
            if (string_pos("ball", ident2) > 0) return false;
            if (string_pos("key", ident2) > 0 || string_pos("key-item", ident2) > 0) return false;
        }
    }

    // Otherwise default to not holdable to be conservative
    return false;
}
