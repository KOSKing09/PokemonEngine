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
    if (is_real(_v)) return floor(_v);
    if (is_string(_v)) {
        var s = string_trim(_v);
        if (string_length(s) == 0) return _def;
        return floor(real(s));
    }
    return _def;
}
function __to_real_safe(_v, _def){
    if (is_real(_v)) return _v;
    if (is_string(_v)) {
        var s = string_trim(_v);
        if (string_length(s) == 0) return _def;
        return real(s);
    }
    return _def;
}
function __grid(_g, _c, _r, _def){
    var W = ds_grid_width(_g), H = ds_grid_height(_g);
    return ((_c>=0 && _c<W && _r>=0 && _r<H) ? _g[# _c, _r] : _def);
}
function __arr_ensure_len(_arr, _len){
    if (array_length(_arr) < _len) array_resize(_arr, _len);
    return _arr;
}

// ---- NEW: header + text helpers (non-breaking; addition only) ----
function __col_find_ci(_g, _name){
    // Case-insensitive column header search on header row (row 0)
    var W = ds_grid_width(_g);
    var _needle = string_lower(_name);
    for (var c = 0; c < W; c++){
        var h = __s_trim(__grid(_g, c, 0, ""));
        if (string_lower(h) == _needle) return c;
    }
    return -1;
}
function __text_clean_spaces(_t){
    var s = string(_t);
    s = string_replace_all(s, "\\n", " ");
    s = string_replace_all(s, "\n", " ");
    s = string_replace_all(s, "\\r", " ");
    s = string_replace_all(s, "\r", " ");
    s = string_replace_all(s, "\\f", " ");
    s = string_replace_all(s, "  ", " ");
    return string_trim(s);
}

// ---------- DATA: pokemon.csv ----------
function data_load_pokemon_structs(){
    var path = working_directory + "/data/csv/pokemon.csv";
    var g = load_csv(path);
    if (g == -1) { show_debug_message("[DATA][pokemon] FAILED: " + path); global._pokemon = []; return; }

    var H = ds_grid_height(g);

    // Find max id so we can size the array once
    var max_id = 0;
    for (var r = 1; r < H; r++){
        var v = __grid(g, 0, r, 0);
        var sid = __to_int_safe(v, 0);
        if (sid > max_id) max_id = sid;
    }
    global._pokemon = [];
    array_resize(global._pokemon, max_id + 1);

    // Fill by id
    var rows = 0;
    for (var r = 1; r < H; r++){
        var sid        = __to_int_safe(__grid(g,0,r,""), 0);
        var identifier = string(__grid(g,1,r,""));
        var species_id = __to_int_safe(__grid(g,2,r,""), 0);
        var height     = __to_int_safe(__grid(g,3,r,""), 0);
        var weight     = __to_int_safe(__grid(g,4,r,""), 0);
        var base_exp   = __to_int_safe(__grid(g,5,r,""), 0);
        var order_     = __to_int_safe(__grid(g,6,r,""), 0);
        var is_default = __to_int_safe(__grid(g,7,r,""), 0);

        if (sid > 0 && string_length(identifier) > 0){
            var rec = {
                _id: sid,
                identifier: identifier,
                species_id: species_id,
                height: height,
                weight: weight,
                _base_exp: base_exp,
                _order: order_,
                is_default: is_default
            };
            global._pokemon[sid] = rec;
            rows++;
        }
    }
    show_debug_message("[DATA][pokemon] rows=" + string(rows));
}

// ---------- DATA: pokemon_stats.csv -> per species aggregate ----------
function data_load_pokemon_stats_structs(){
    var path = working_directory + "/data/csv/pokemon_stats.csv";
    var g = load_csv(path);
    if (g == -1) { show_debug_message("[DATA][pokemon_stats] FAILED: " + path); global._poke_stats = []; return; }

    // Ensure stats array covers all ids present in pokemon
    var max_id = max(0, array_length(global._pokemon)-1);
    global._poke_stats = [];
    array_resize(global._poke_stats, max_id + 1);

    // init each to defaults
    for (var i = 0; i <= max_id; i++){
        global._poke_stats[i] = { hp:45, atk:49, def:49, spa:65, spd:65, spe:45 };
    }

    // PokeAPI stat ids: 1=HP,2=Atk,3=Def,4=SpA,5=SpD,6=Spe
    var H = ds_grid_height(g);
    var rows = 0;
    for (var r = 1; r < H; r++){
        var pid = __to_int_safe(__grid(g,0,r,""), 0);
        var sid = __to_int_safe(__grid(g,1,r,""), 0);
        var val = __to_int_safe(__grid(g,2,r,""), 0);
        if (pid <= 0 || pid > max_id) continue;

        var ref = global._poke_stats[pid];
        if (is_struct(ref)){
            switch (sid){
                case 1: ref.hp  = val; break;
                case 2: ref.atk = val; break;
                case 3: ref.def = val; break;
                case 4: ref.spa = val; break;
                case 5: ref.spd = val; break;
                case 6: ref.spe = val; break;
            }
            rows++;
        }
    }
    show_debug_message("[DATA][pokemon_stats] rows=" + string(rows));
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
