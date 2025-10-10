// [Pokémon Data]: PokemonDataLoaders — Build v3.3.0 — Updated 2025-10-04
// ============================================================================
// PokemonDataLoaders_STRUCTS.gml  (arrays + structs only)
// - Requires load_csv(path) that returns a ds_grid (built-in ok)
// - Writes to global._pokemon (array by species id)
// - Writes to global._poke_stats (array by species id) -> {hp,atk,def,spa,spd,spe}
// ============================================================================

// ---------- CSV SAFE HELPERS ----------
function __s_trim(_v)    { return is_string(_v) ? string_trim(_v) : string(_v); }
function __s_ok(_v)      { return (is_string(_v) && string_length(string_trim(_v)) > 0); }
function __r_ok(_v)      { return is_real(_v); }
function __to_int_safe(_v, _def){
    if (argument_count < 2) _def = 0;
    if (is_real(_v)) return floor(_v);
    if (is_string(_v)){
        var s = string_trim(_v);
        if (string_length(s) == 0) return _def;
        var r = real(s);
        return is_real(r) ? floor(r) : _def;
    }
    return _def;
}

// Build the `global._item_bag_map` from already-loaded `global._item_categories` and `global._items`.
function data_build_item_bag_map(){
    var cats = (variable_global_exists("_item_categories") && is_array(global._item_categories)) ? global._item_categories : [];
    var items_arr = (variable_global_exists("_items") && is_array(global._items)) ? global._items : [];
    var N = array_length(items_arr);

    // heuristic mapping rules
    var map_rules = [
        { key:"medicine", page:1 },
        { key:"heal|potion|medicine", page:1 },
        { key:"ball|pokeball|pokeballs|masterball|ultraball", page:2 },
        { key:"machine|tm|hm|machine", page:3 },
        { key:"berry|berries", page:4 },
        { key:"key|key-item|key items|key_items", page:4 }
    ];

    var id_to_page = [];
    var by_identifier = {};
    var by_category = {};

    for (var ci = 0; ci < array_length(cats); ci++){
        var crec = cats[ci];
        var pg = 0;
        if (is_struct(crec)){
            var ident = is_string(crec.identifier) ? string_lower(__s_trim(crec.identifier)) : "";
            var cname = is_string(crec.name) ? string_lower(__s_trim(crec.name)) : ident;
            var hay = ident + " " + cname;
            for (var mr = 0; mr < array_length(map_rules); mr++){
                var rule = map_rules[mr];
                var parts = string_split(rule.key, "|");
                for (var p = 0; p < array_length(parts); p++){
                    var sub = string_trim(parts[p]);
                    if (string_length(sub) == 0) continue;
                    if (string_pos(sub, hay) > 0) { pg = rule.page; break; }
                }
                if (pg != 0) break;
            }
            if (is_string(crec.identifier) && string_length(crec.identifier) > 0) variable_struct_set(by_identifier, crec.identifier, pg);
            variable_struct_set(by_category, crec.name, pg);
        }
        id_to_page[ci] = pg;
    }

    var mapping = [];
    if (N > 0) array_resize(mapping, N);
    for (var i = 0; i < N; i++){
        var pg2 = 0;
        var it = items_arr[i];
        if (is_struct(it) && variable_struct_exists(it, "category_id")){
            var cid2 = it.category_id;
            if (is_real(cid2) && cid2 >= 0 && cid2 < array_length(id_to_page) && !is_undefined(id_to_page[cid2])) pg2 = id_to_page[cid2];
        }
        if (!is_real(pg2) || pg2 < 0) pg2 = 0; if (pg2 > 4) pg2 = 4;
        mapping[i] = floor(pg2);
    }

    // apply overrides if present
    if (variable_global_exists("_item_bag_page_overrides") && is_struct(global._item_bag_page_overrides)){
        var overrides = global._item_bag_page_overrides;
        for (var kk = 0; kk < N; kk++){
            var it2 = items_arr[kk];
            if (!is_struct(it2)) continue;
            var ident2 = it2.identifier;
            if (is_string(ident2) && variable_struct_exists(overrides, ident2)){
                var op2 = variable_struct_get(overrides, ident2);
                if (is_real(op2)) mapping[kk] = clamp(floor(op2), 0, 4);
            }
        }
    }

    global._item_bag_map = { by_id: mapping, by_identifier: by_identifier, by_category: by_category, overrides: (variable_global_exists("_item_bag_page_overrides") ? global._item_bag_page_overrides : {}) };
    show_debug_message("[DATA][item_categories] built bag_map from in-memory categories for items=" + string(N));
    return true;
}

// ---------- ORCHESTRATOR ----------
function data_load_all_structs(){
    data_load_pokemon_structs();
    data_load_pokemon_stats_structs();
    show_debug_message("[DATA][structs] done.");

    // --- EXT HOOK (safe, runs once if present) ---
    if (!variable_global_exists("_csv_ext_loaded") || !global._csv_ext_loaded) {
        if (is_undefined(data_load_all_structs_ext)) {
            // ext not defined -> skip silently
        } else {
            data_load_all_structs_ext();
            global._csv_ext_loaded = true;
        }
    }

}
// ---------- EXTENDED DATA LOADERS (moves, abilities, texts, species links) ----------
// All CSVs optional. Missing files are skipped safely. Results go to new globals for lookups.
//  - global._moves[mid]           => { id, identifier, power, pp, priority, type_id, damage_class_id }
//  - global._move_text[mid]       => { name, short_desc, effect }  (legacy shape maintained; see note below)
//  - global._abilities[aid]       => { id, identifier }
//  - global._ability_text[aid]    => { name, short_desc, effect }  (legacy shape maintained; see note below)
//  - global._species_abilities[sid] => [aid, ...]
//  - global._species_moves[sid]     => [ { lvl, mid }, ... ]  (sorted by lvl)
//
// NOTE on flavor text shape:
//  PokeAPI flavor CSVs provide a single text field. To avoid breaking downstream UI that
//  expects {name, short_desc, effect}, we keep the struct keys and put the same cleaned
//  flavor string into both short_desc and effect, leaving name empty (or use localized
//  name tables if you later add them).

// Moves (core)
function data_load_moves_structs(){
    var path = working_directory + "/data/csv/moves.csv";
    var g = load_csv(path);
    if (g == -1) { show_debug_message("[DATA][moves] SKIP: " + path); global._moves = []; return; }
    var H = ds_grid_height(g);
    // size by max id
    var max_id = 0;
    for (var _r = 1; _r < H; _r++){
        var _id = __to_int_safe(__grid(g,0,_r,0),0);
        if (_id > max_id) max_id = _id;
    }
    global._moves = []; array_resize(global._moves, max_id+1);
    var _rows = 0;
    for (var _r = 1; _r < H; _r++){
        var _id   = __to_int_safe(__grid(g,0,_r,0), 0);
        if (_id <= 0) continue;
        var _ident= __s_trim(__grid(g,1,_r,""));
        var _type = __to_int_safe(__grid(g,3,_r,0), 0);
        var _power= __to_int_safe(__grid(g,4,_r,0), 0);
        var _pp   = __to_int_safe(__grid(g,5,_r,0), 0);
        var _prio = __to_int_safe(__grid(g,7,_r,0), 0);
        var _dcls = __to_int_safe(__grid(g,8,_r,0), 0);
        global._moves[_id] = { id:_id, identifier:_ident, type_id:_type, power:_power, pp:_pp, priority:_prio, damage_class_id:_dcls };
        _rows++;
    }
    show_debug_message("[DATA][moves] rows=" + string(_rows));
}

// UPDATED: Move flavor text (PokeAPI) -> move_flavor_text.csv (EN, latest version_group_id)
function data_load_move_text_structs(){
    var path = working_directory + "/data/csv/move_flavor_text.csv";
    var g = load_csv(path);
    if (g == -1) { show_debug_message("[DATA][move_text] SKIP: " + path); global._move_text = []; return; }
    var H = ds_grid_height(g);

    // Resolve EN language id from languages.csv (fallback to 9)
    var en_id = 9;
    var lang_path = working_directory + "/data/csv/languages.csv";
    var lg = load_csv(lang_path);
    if (lg != -1){
        var ci_lid = __col_find_ci(lg, "id");
        var ci_ident = __col_find_ci(lg, "identifier");
        if (ci_lid >= 0 && ci_ident >= 0){
            var HL = ds_grid_height(lg);
            for (var rr = 1; rr < HL; rr++){
                var ident = string_lower(__s_trim(__grid(lg, ci_ident, rr, "")));
                if (ident == "en"){
                    en_id = __to_int_safe(__grid(lg, ci_lid, rr, 9), 9);
                    break;
                }
            }
        }
    }

    // Column indices in move_flavor_text.csv
    var ci_move = __col_find_ci(g, "move_id");
    var ci_vg   = __col_find_ci(g, "version_group_id"); // may be absent in some exports
    var ci_lang = __col_find_ci(g, "language_id");
    var ci_text = __col_find_ci(g, "flavor_text");
    if (ci_move < 0 || ci_lang < 0 || ci_text < 0){
        show_debug_message("[DATA][move_text] ERROR: required columns missing in move_flavor_text.csv");
        global._move_text = [];
        return;
    }

    // Find max move_id
    var max_mid = 0;
    for (var r = 1; r < H; r++){
        var mid = __to_int_safe(__grid(g, ci_move, r, 0), 0);
        if (mid > max_mid) max_mid = mid;
    }
    global._move_text = []; array_resize(global._move_text, max_mid + 1);
    var maxVG = []; array_resize(maxVG, max_mid + 1);
    for (var i = 0; i <= max_mid; i++){ maxVG[i] = 0; }

    var rows = 0;
    for (var r2 = 1; r2 < H; r2++){
        var lang = __to_int_safe(__grid(g, ci_lang, r2, 0), 0);
        if (lang != en_id) continue;

        var mid2  = __to_int_safe(__grid(g, ci_move, r2, 0), 0);
        if (mid2 <= 0) continue;

        var vg    = (ci_vg >= 0) ? __to_int_safe(__grid(g, ci_vg, r2, 0), 0) : 0;
        var text  = __text_clean_spaces(__grid(g, ci_text, r2, ""));

        // Keep the latest version group text
        if (vg >= maxVG[mid2]){
            maxVG[mid2] = vg;
            // Preserve legacy shape: name empty, short_desc/effect both get flavor text
            global._move_text[mid2] = { name:"", short_desc:text, effect:text };
        }
        rows++;
    }
    show_debug_message("[DATA][move_flavor_text] en_id=" + string(en_id) + " rows_seen=" + string(rows));
}

// Abilities (core)
function data_load_abilities_structs(){
    var path = working_directory + "/data/csv/abilities.csv";
    var g = load_csv(path);
    if (g == -1) { show_debug_message("[DATA][abilities] SKIP: " + path); global._abilities = []; return; }
    var H = ds_grid_height(g);
    var max_id = 0;
    for (var _r = 1; _r < H; _r++){
        var _id = __to_int_safe(__grid(g,0,_r,0),0);
        if (_id > max_id) max_id = _id;
    }
    global._abilities = []; array_resize(global._abilities, max_id+1);
    var _rows = 0;
    for (var _r = 1; _r < H; _r++){
        var _id   = __to_int_safe(__grid(g,0,_r,0), 0);
        if (_id <= 0) continue;
        var _ident= __s_trim(__grid(g,1,_r,""));
        global._abilities[_id] = { id:_id, identifier:_ident };
        _rows++;
    }
    show_debug_message("[DATA][abilities] rows=" + string(_rows));
}

// UPDATED: Ability flavor text (PokeAPI) -> ability_flavor_text.csv (EN)
function data_load_ability_text_structs(){
    var path = working_directory + "/data/csv/ability_flavor_text.csv";
    var g = load_csv(path);
    if (g == -1) { show_debug_message("[DATA][ability_text] SKIP: " + path); global._ability_text = []; return; }
    var H = ds_grid_height(g);

    // Resolve EN language id from languages.csv (fallback 9)
    var en_id = 9;
    var lang_path = working_directory + "/data/csv/languages.csv";
    var lg = load_csv(lang_path);
    if (lg != -1){
        var ci_lid = __col_find_ci(lg, "id");
        var ci_ident = __col_find_ci(lg, "identifier");
        if (ci_lid >= 0 && ci_ident >= 0){
            var HL = ds_grid_height(lg);
            for (var rr = 1; rr < HL; rr++){
                var ident = string_lower(__s_trim(__grid(lg, ci_ident, rr, "")));
                if (ident == "en"){
                    en_id = __to_int_safe(__grid(lg, ci_lid, rr, 9), 9);
                    break;
                }
            }
        }
    }

    // Column indices
    var ci_ability = __col_find_ci(g, "ability_id");
    var ci_lang    = __col_find_ci(g, "language_id");
    var ci_text    = __col_find_ci(g, "flavor_text");
    if (ci_text < 0) ci_text = __col_find_ci(g, "effect"); // some dumps use 'effect'
    if (ci_ability < 0 || ci_lang < 0 || ci_text < 0){
        show_debug_message("[DATA][ability_text] ERROR: required columns missing in ability_flavor_text.csv");
        global._ability_text = [];
        return;
    }

    // Find max ability id
    var max_aid = 0;
    for (var r = 1; r < H; r++){
        var aid = __to_int_safe(__grid(g, ci_ability, r, 0), 0);
        if (aid > max_aid) max_aid = aid;
    }
    global._ability_text = []; array_resize(global._ability_text, max_aid + 1);

    var rows = 0;
    for (var r2 = 1; r2 < H; r2++){
        var lgid = __to_int_safe(__grid(g, ci_lang, r2, 0), 0);
        if (lgid != en_id) continue;

        var ab2  = __to_int_safe(__grid(g, ci_ability, r2, 0), 0);
        if (ab2 <= 0) continue;

        var text = __text_clean_spaces(__grid(g, ci_text, r2, ""));
        // Preserve legacy shape
        global._ability_text[ab2] = { name:"", short_desc:text, effect:text };
        rows++;
    }
    show_debug_message("[DATA][ability_flavor_text] en_id=" + string(en_id) + " rows_seen=" + string(rows));
}

function data_load_species_abilities_structs(){
    var path = working_directory + "/data/csv/pokemon_abilities.csv";
    var g = load_csv(path);
    if (g == -1) { show_debug_message("[DATA][pokemon_abilities] SKIP: " + path); global._species_abilities = []; return; }
    var H = ds_grid_height(g);
    // size by max species id
    var max_sid = 0;
    for (var _r = 1; _r < H; _r++){
        var _sid = __to_int_safe(__grid(g,0,_r,0),0);
        if (_sid > max_sid) max_sid = _sid;
    }
    global._species_abilities = []; array_resize(global._species_abilities, max_sid+1);
    for (var _i = 0; _i <= max_sid; _i++) global._species_abilities[_i] = [];
    var _rows = 0;
    for (var _r = 1; _r < H; _r++){
        var _sid = __to_int_safe(__grid(g,0,_r,0),0);
        var _aid = __to_int_safe(__grid(g,1,_r,0),0);
        if (_sid <= 0 || _aid <= 0) continue;
        array_push(global._species_abilities[_sid], _aid);
        _rows++;
    }
    show_debug_message("[DATA][pokemon_abilities] rows=" + string(_rows));
}

function data_load_species_moves_structs(){
    var path = working_directory + "/data/csv/pokemon_moves.csv";
    var g = load_csv(path);
    if (g == -1) { show_debug_message("[DATA][pokemon_moves] SKIP: " + path); global._species_moves = []; return; }
    var H = ds_grid_height(g);
    var max_sid = 0;
    for (var _r = 1; _r < H; _r++){
        var _sid = __to_int_safe(__grid(g,0,_r,0),0);
        if (_sid > max_sid) max_sid = _sid;
    }
    global._species_moves = []; array_resize(global._species_moves, max_sid+1);
    for (var _i = 0; _i <= max_sid; _i++) global._species_moves[_i] = [];
    var _rows = 0;
    for (var _r = 1; _r < H; _r++){
        var _sid = __to_int_safe(__grid(g,0,_r,0),0);
        var _vg  = __to_int_safe(__grid(g,1,_r,0),0);
        var _mid = __to_int_safe(__grid(g,2,_r,0),0);
        var _mth = __to_int_safe(__grid(g,3,_r,0),0); // 1 = level-up
        var _lvl = __to_int_safe(__grid(g,4,_r,0),0);
        if (_sid <= 0 || _mid <= 0 || _mth != 1) continue;
        array_push(global._species_moves[_sid], { lvl:_lvl, mid:_mid });
        _rows++;
    }
    // sort each species moves by lvl
    for (var _sid = 0; _sid < array_length(global._species_moves); _sid++){
        var _arr = global._species_moves[_sid];
        if (is_array(_arr) && array_length(_arr) > 1){
            array_sort(_arr, function(a,b){ return a.lvl - b.lvl; });
        }
    }
    show_debug_message("[DATA][pokemon_moves] rows=" + string(_rows));
}

function data_load_all_structs_ext(){
    data_load_moves_structs();
    data_load_move_text_structs();       // UPDATED to PokeAPI flavor text
    data_load_abilities_structs();
    data_load_ability_text_structs();    // UPDATED to PokeAPI flavor text
    data_load_species_abilities_structs();
    data_load_species_moves_structs();
    show_debug_message("[DATA][structs_ext] done.");
}


// ===================== ITEMS (NEW) - 2025-10-09 =====================

function data_load_items_structs(){
    var csv_path = working_directory + "/data/csv/items.csv";
    var g = load_csv(csv_path);
    if (g == -1) { show_debug_message("[DATA][items] SKIP: " + csv_path); global._items = []; return; }
    var H = ds_grid_height(g);

    var max_id = 0;
    for (var r = 1; r < H; r++){
        var cell = __grid(g, 0, r, 0);
        var idv = __to_int_safe(cell, 0);
        if (idv > max_id) max_id = idv;
    }

    global._items = [];
    array_resize(global._items, max_id + 1);
    var rows = 0;

    for (var r2 = 1; r2 < H; r2++){
        var cell_id = __grid(g, 0, r2, 0);
        var _id = __to_int_safe(cell_id, 0);
        if (_id <= 0) continue;
        var ident = __s_trim(__grid(g,1,r2,"") );
        var cost  = __to_int_safe(__grid(g,2,r2,0), 0);
        var catid = __to_int_safe(__grid(g,3,r2,0), -1);
        var fling_power = __to_int_safe(__grid(g,4,r2,-1), -1);
        global._items[_id] = { _id:_id, identifier:ident, name:ident, cost:cost, category_id:catid, fling_power:fling_power };
        rows++;
    }

    show_debug_message("[DATA][items] rows=" + string(rows));
}

// Compute a mapping from item id -> bag page index (0..4).
// This is a safe, best-effort mapper using item.category_id when available.
// Legacy flat-array mapping removed. Use `data_load_item_categories_structs()` to build `global._item_bag_map` instead.

// Debug helper: dump the struct-based item bag map (or legacy array) for verification
function data_dump_item_bag_map(_limit){
    var map = (variable_global_exists("_item_bag_map") && is_struct(global._item_bag_map)) ? global._item_bag_map : undefined;
    if (is_undefined(map)) { show_debug_message("[DATA][dump_bag_map] no mapping present"); return false; }

    show_debug_message("[DATA][dump_bag_map] struct present: by_id=" + string(array_length(map.by_id)) + ", by_identifier=" + string(variable_struct_size(map.by_identifier)));

    var items = (variable_global_exists("_items") && is_array(global._items)) ? global._items : [];
    var N = array_length(items);
    var L = (argument_count > 0 && is_real(_limit) && _limit > 0) ? min(_limit, N-1) : min(50, N-1);
    for (var i = 1; i <= L; i++){
        var it = items[i];
        if (!is_struct(it)) continue;
        var pid = -1;
        if (array_length(map.by_id) > i) pid = map.by_id[i];
        var ident = (variable_struct_exists(it, "identifier") ? it.identifier : "") + "";
        var cid = (variable_struct_exists(it, "category_id") ? string(it.category_id) : "?");
        show_debug_message("[DATA][dump_bag_map] id=" + string(it._id) + " ident=" + ident + " cat=" + cid + " -> page=" + string(pid));
    }
    return true;
}

// Runs the item-related loaders in the correct order and computes bag pages.
// Safe: missing functions or CSVs are skipped. Will attempt to seed `BAGS` if present.
function data_load_all_items(){
    var ok = true;
    // Core item data
    if (!is_undefined(data_load_items_structs)) data_load_items_structs();
    // Optional supplemental loaders - call if defined
    if (!is_undefined(data_load_item_names_structs)) data_load_item_names_structs();
    if (!is_undefined(data_load_item_text_structs)) data_load_item_text_structs();
    if (!is_undefined(data_load_item_categories_structs)) data_load_item_categories_structs();
    if (!is_undefined(data_load_machines_structs)) data_load_machines_structs();

    // Mapping is computed by data_load_item_categories_structs(); no legacy compute function.

    // If BAGS exist, seed them now
    if (variable_global_exists("BAGS") && is_array(global.BAGS) && !is_undefined(bags_seed_all)){
        bags_seed_all();
    }
    show_debug_message("[DATA][items_orch] done.");
    return ok;
}

// Load item categories and compute `global._item_bag_map` from category identifiers.
function data_load_item_categories_structs(){
    var path = working_directory + "/data/csv/item_categories.csv";
    var g = load_csv(path);
    if (g == -1) { show_debug_message("[DATA][item_categories] SKIP: " + path); global._item_categories = []; return; }

    var H = ds_grid_height(g);
    var max_id = 0;
    var ci_id = __col_find_ci(g, "id");
    var ci_ident = __col_find_ci(g, "identifier");
    // Fallback: if no header, assume columns like PokeAPI (id, identifier, ...)
    if (ci_id < 0) ci_id = 0;
    if (ci_ident < 0) ci_ident = 1;

    for (var r = 1; r < H; r++){
        var v = __to_int_safe(__grid(g, ci_id, r, 0), 0);
        if (v > max_id) max_id = v;
    }

    var cats = [];
    array_resize(cats, max_id + 1);
    var rows = 0;
    for (var r2 = 1; r2 < H; r2++){
        var cid = __to_int_safe(__grid(g, ci_id, r2, 0), 0);
        if (cid <= 0) continue;
        var ident = string(__grid(g, ci_ident, r2, ""));
        ident = string_lower(__s_trim(ident));
        cats[cid] = { id:cid, identifier:ident, name:ident };
        rows++;
    }

    // Attempt localized category names via item_category_prose.csv (optional)
    var prose_path = working_directory + "/data/csv/item_category_prose.csv";
    var gp = load_csv(prose_path);
    var used_prose = (gp != -1);
    if (used_prose){
        var H2 = ds_grid_height(gp);
        var ci_cat = __col_find_ci(gp, "item_category_id");
        var ci_lang = __col_find_ci(gp, "local_language_id");
        var ci_name = __col_find_ci(gp, "name");
        var en_id = 9;
        // resolve EN id from languages.csv if present
        var lg = load_csv(working_directory + "/data/csv/languages.csv");
        if (lg != -1){ var cid_l = __col_find_ci(lg, "identifier"); var cid_id = __col_find_ci(lg, "id"); if (cid_l >= 0 && cid_id >= 0){ for (var rr = 1; rr < ds_grid_height(lg); rr++){ var lidv = __to_int_safe(__grid(lg, cid_id, rr, 0), 0); var lidstr = string_lower(__s_trim(__grid(lg, cid_l, rr, ""))); if (lidstr == "en") { en_id = lidv; break; } } } }

        if (ci_cat >= 0 && ci_lang >= 0 && ci_name >= 0){
            for (var r3 = 1; r3 < H2; r3++){
                var lid = __to_int_safe(__grid(gp, ci_lang, r3, 0), 0);
                if (lid != en_id) continue;
                var cc = __to_int_safe(__grid(gp, ci_cat, r3, 0), 0);
                if (cc <= 0) continue;
                var nm = __text_clean_spaces(__grid(gp, ci_name, r3, ""));
                if (is_undefined(cats[cc])) cats[cc] = { id:cc, identifier:"", name:nm };
                else cats[cc].name = nm;
            }
        }
    }

    global._item_categories = cats;
    show_debug_message("[DATA][item_categories] rows=" + string(rows));

    // Build mapping from category identifier -> bag page index.
    // This emulates the original loader: use category.identifier to determine page.
    var id_to_page = {};
    // manual mapping heuristics (identifier substrings)
    var map_rules = [
        { key:"medicine", page:1 },
        { key:"heal|potion|medicine", page:1 },
        { key:"ball|pokeball|pokeballs", page:2 },
        { key:"machine|tm|hm|machine", page:3 },
        { key:"berry|berries", page:4 },
        { key:"key|key-item|key items|key_items", page:4 }
    ];

    // Build id_to_page using category identifiers and names
    for (var ci = 0; ci < array_length(cats); ci++){
        var crec = cats[ci];
        var pg = 0;
        if (is_struct(crec)){
            var ident = is_string(crec.identifier) ? string_lower(__s_trim(crec.identifier)) : "";
            var cname = is_string(crec.name) ? string_lower(__s_trim(crec.name)) : ident;
            var hay = ident + " " + cname;
            for (var mr = 0; mr < array_length(map_rules); mr++){
                var rule = map_rules[mr];
                var parts = string_split(rule.key, "|");
                for (var p = 0; p < array_length(parts); p++){
                    var sub = string_trim(parts[p]);
                    if (string_length(sub) == 0) continue;
                    if (string_pos(sub, hay) > 0) { pg = rule.page; break; }
                }
                if (pg != 0) break;
            }
        }
        id_to_page[ci] = pg;
    }

    // Now compute mapping using item.category_id (struct will be built below)
    var items_arr = (variable_global_exists("_items") && is_array(global._items)) ? global._items : [];
    var N = array_length(items_arr);
    var mapping = [];
    if (N > 0) array_resize(mapping, N);
    for (var i = 0; i < N; i++){
        var pg = 0;
        var it = items_arr[i];
        if (is_struct(it) && variable_struct_exists(it, "category_id")){
            var cid2 = it.category_id;
            if (is_real(cid2) && cid2 >= 0 && cid2 < array_length(id_to_page) && !is_undefined(id_to_page[cid2])) pg = id_to_page[cid2];
        }
        if (!is_real(pg) || pg < 0) pg = 0; if (pg > 4) pg = 4;
        mapping[i] = floor(pg);
    }
    // Apply manual overrides if present (maps item identifier -> page)
    // Example: global._item_bag_page_overrides = { "masterball":2, "super_potion":1 }
    if (variable_global_exists("_item_bag_page_overrides") && is_struct(global._item_bag_page_overrides)){
        var overrides = global._item_bag_page_overrides;
        for (var jj = 0; jj < N; jj++){
            var it = items_arr[jj];
            if (!is_struct(it)) continue;
            var iid = it.identifier;
            if (!is_string(iid)) continue;
            if (variable_struct_exists(overrides, iid)){
                var op = variable_struct_get(overrides, iid);
                if (is_real(op)) mapping[jj] = clamp(floor(op), 0, 4);
            }
        }
    }

    // populate struct-based map
    global._item_bag_map = { by_id: mapping, by_identifier: by_identifier, by_category: by_category, overrides: {} };
    show_debug_message("[DATA][item_categories] computed bag_map for items=" + string(N));

    // Show a short sample for verification
    var sampleN = min(12, N-1);
    for (var s = 1; s <= sampleN; s++){
        var which = s;
        if (which >= N) break;
        var si = items_arr[which];
        if (!is_struct(si)) continue;
        show_debug_message("[DATA][item_sample] id=" + string(si._id) + " ident=" + string(si.identifier) + " cat=" + string(si.category_id) + " -> page=" + string(mapping[which]));
    }

    return true;
}