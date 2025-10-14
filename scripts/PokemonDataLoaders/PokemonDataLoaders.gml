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
    if (g == -1) { data_debug("[DATA][pokemon] FAILED: " + path); global._pokemon = []; return; }

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
                is_default: is_default,
                // default ev_yield shape; can be overridden by extended CSV loader
                ev_yield: { hp:0, atk:1, def:0, spa:0, spd:0, spe:0 }
            };
            global._pokemon[sid] = rec;
            rows++;
        }
    }
    data_debug("[DATA][pokemon] rows=" + string(rows));
}

// Optional CSV: pokemon_ev_yield.csv -> per-species EV yield values (hp,atk,def,spa,spd,spe)
function data_load_pokemon_ev_yield_structs(){
    var path = working_directory + "/data/csv/pokemon_ev_yield.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][pokemon_ev_yield] SKIP: " + path); return; }
    var H = ds_grid_height(g);
    // Expect columns: species_id, hp, atk, def, spa, spd, spe (case-insensitive)
    var ci_sid = __col_find_ci(g, "species_id");
    var ci_hp  = __col_find_ci(g, "hp");
    var ci_atk = __col_find_ci(g, "atk");
    var ci_def = __col_find_ci(g, "def");
    var ci_spa = __col_find_ci(g, "spa");
    var ci_spd = __col_find_ci(g, "spd");
    var ci_spe = __col_find_ci(g, "spe");
    if (ci_sid < 0){ data_debug("[DATA][pokemon_ev_yield] ERROR: missing species_id column"); return; }
    var updated = 0;
    for (var r = 1; r < H; r++){
        var sid = __to_int_safe(__grid(g, ci_sid, r, 0), 0);
        if (sid <= 0 || sid >= array_length(global._pokemon)) continue;
        var hp = (ci_hp >= 0 ? __to_int_safe(__grid(g, ci_hp, r, 0), 0) : 0);
        var atk = (ci_atk >= 0 ? __to_int_safe(__grid(g, ci_atk, r, 0), 0) : 0);
        var def = (ci_def >= 0 ? __to_int_safe(__grid(g, ci_def, r, 0), 0) : 0);
        var spa = (ci_spa >= 0 ? __to_int_safe(__grid(g, ci_spa, r, 0), 0) : 0);
        var spd = (ci_spd >= 0 ? __to_int_safe(__grid(g, ci_spd, r, 0), 0) : 0) ;
        var spe = (ci_spe >= 0 ? __to_int_safe(__grid(g, ci_spe, r, 0), 0) : 0) ;
        var rec = global._pokemon[sid];
        if (is_struct(rec)){
            rec.ev_yield = { hp:hp, atk:atk, def:def, spa:spa, spd:spd, spe:spe };
            global._pokemon[sid] = rec;
            updated += 1;
        }
    }
    data_debug("[DATA][pokemon_ev_yield] updated=" + string(updated));
}

// ---------- DATA: pokemon_stats.csv -> per species aggregate ----------
function data_load_pokemon_stats_structs(){
    var path = working_directory + "/data/csv/pokemon_stats.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][pokemon_stats] FAILED: " + path); global._poke_stats = []; return; }

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
    data_debug("[DATA][pokemon_stats] rows=" + string(rows));
}

// ---------- ORCHESTRATOR ----------
function data_load_all_structs(){
    data_load_pokemon_structs();
    data_load_pokemon_stats_structs();
    data_debug("[DATA][structs] done.");

    // --- EXT HOOK (safe, runs once if present) ---
    if (!variable_global_exists("_csv_ext_loaded") || !global._csv_ext_loaded) {
        if (is_undefined(data_load_all_structs_ext)) {
            // ext not defined -> skip silently
        } else {
            data_load_all_structs_ext();
            global._csv_ext_loaded = true;
        }
    }

    // Optional: load per-species EV yield CSV if present
    if (is_undefined(data_load_pokemon_ev_yield_structs) == false) data_load_pokemon_ev_yield_structs();
    // Optional: load natures CSV if present
    if (is_undefined(data_load_natures_structs) == false) data_load_natures_structs();
}

// Load natures.csv -> global._natures: array indexed by id (1-based) or by push order
function data_load_natures_structs(){
    var path = working_directory + "/data/csv/natures.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][natures] SKIP: " + path); return; }
    var H = ds_grid_height(g);
    // columns: id, identifier, decreased_stat_id, increased_stat_id ...
    var ci_id = __col_find_ci(g, "id");
    var ci_ident = __col_find_ci(g, "identifier");
    var ci_dec = __col_find_ci(g, "decreased_stat_id");
    var ci_inc = __col_find_ci(g, "increased_stat_id");
    if (ci_id < 0 || ci_ident < 0){ data_debug("[DATA][natures] missing required columns"); return; }
    global._natures = [];
    var rows = 0;
    for (var r = 1; r < H; r++){
        var nid = __to_int_safe(__grid(g, ci_id, r, 0), 0);
        if (nid <= 0) continue;
        var ident = string(__grid(g, ci_ident, r, ""));
        var dec = (ci_dec >= 0) ? __to_int_safe(__grid(g, ci_dec, r, 0), 0) : 0;
        var inc = (ci_inc >= 0) ? __to_int_safe(__grid(g, ci_inc, r, 0), 0) : 0;
        // map stat ids to keys: 1=hp,2=atk,3=def,4=spa,5=spd,6=spe
        function __stat_key(_id){ switch(_id){ case 1: return "hp"; case 2: return "atk"; case 3: return "def"; case 4: return "spa"; case 5: return "spd"; case 6: return "spe"; } return undefined; }
        var incKey = __stat_key(inc); var decKey = __stat_key(dec);
    var mul = { hp:1.0, atk:1.0, def:1.0, spa:1.0, spd:1.0, spe:1.0 };
    if (is_string(incKey)) variable_struct_set(mul, incKey, 1.1);
    if (is_string(decKey)) variable_struct_set(mul, decKey, 0.9);
        // Display name: capitalize identifier
        var display = (string_length(ident) > 0) ? string_upper(string_copy(ident,1,1)) + string_copy(ident,2,string_length(ident)) : ident;
        var rec = { id: nid, name: display, identifier: ident, mul: mul };
        array_push(global._natures, rec);
        rows += 1;
    }
    data_debug("[DATA][natures] loaded rows=" + string(rows));
}

// Load pokemon_species_flavor_text.csv (PokeAPI) -> global._species_flavor_text[sid] = "text"
function data_load_species_flavor_text_structs(){
    var path = working_directory + "/data/csv/pokemon_species_flavor_text.csv";
    var g = load_csv(path);
    if (g == -1) {
        // try fallback: flavor summaries CSV
        var p2 = working_directory + "/data/csv/pokemon_species_flavor_summaries.csv";
        var g2 = load_csv(p2);
        if (g2 == -1) { data_debug("[DATA][species_flavor_text] SKIP: no flavor CSVs"); global._species_flavor_text = []; return; }
        // use summaries fallback
        var H2 = ds_grid_height(g2);
        var ci_sid2 = __col_find_ci(g2, "pokemon_species_id");
        var ci_text2 = __col_find_ci(g2, "flavor_summary");
        if (ci_sid2 < 0 || ci_text2 < 0){ data_debug("[DATA][species_flavor_text] fallback missing columns"); global._species_flavor_text = []; return; }
        var maxsid = 0;
        for (var r = 1; r < H2; r++){ var sid = __to_int_safe(__grid(g2, ci_sid2, r, 0), 0); if (sid > maxsid) maxsid = sid; }
        global._species_flavor_text = []; array_resize(global._species_flavor_text, maxsid + 1);
        var rows = 0;
        for (var r2 = 1; r2 < H2; r2++){
            var sid = __to_int_safe(__grid(g2, ci_sid2, r2, 0), 0);
            if (sid <= 0) continue;
            var txt = __text_clean_spaces(__grid(g2, ci_text2, r2, ""));
            if (string_length(txt) == 0) continue;
            global._species_flavor_text[sid] = txt;
            // Targeted debug: help trace why certain sids (e.g., 173) may end up empty or incorrect
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG && sid == 173) {
                show_debug_message("[DATA_DBG][species_flavor_text] assigned sid=173 -> '" + string(txt) + "'");
            }
            rows++;
        }
        data_debug("[DATA][species_flavor_text] loaded fallback rows=" + string(rows));
        // Normalize: ensure unfilled or numeric slots don't contain raw 0 values
        if (variable_global_exists("_species_flavor_text") && is_array(global._species_flavor_text)){
            for (var _i = 0; _i < array_length(global._species_flavor_text); _i++){
                var _v = global._species_flavor_text[_i];
                if (!(is_string(_v) || is_struct(_v))) global._species_flavor_text[_i] = "";
            }
        }
        return;
    }

    var H = ds_grid_height(g);
    // Determine EN language id from languages.csv if present (fallback to 9)
    var en_id = 9;
    var lg = load_csv(working_directory + "/data/csv/languages.csv");
    if (lg != -1){ var ci_lid = __col_find_ci(lg, "id"); var ci_ident = __col_find_ci(lg, "identifier"); if (ci_lid >= 0 && ci_ident >= 0){ var HL = ds_grid_height(lg); for (var rr = 1; rr < HL; rr++){ var ident = string_lower(__s_trim(__grid(lg, ci_ident, rr, ""))); if (ident == "en"){ en_id = __to_int_safe(__grid(lg, ci_lid, rr, 9), 9); break; } } } }

    var ci_sid = __col_find_ci(g, "species_id");
    var ci_lang = __col_find_ci(g, "language_id");
    var ci_text = __col_find_ci(g, "flavor_text");
    if (ci_sid < 0 || ci_lang < 0 || ci_text < 0){ data_debug("[DATA][species_flavor_text] ERROR: missing columns"); global._species_flavor_text = []; return; }

    // determine max sid
    var maxsid = 0;
    for (var r3 = 1; r3 < H; r3++){ var sid3 = __to_int_safe(__grid(g, ci_sid, r3, 0), 0); if (sid3 > maxsid) maxsid = sid3; }
    global._species_flavor_text = []; array_resize(global._species_flavor_text, maxsid + 1);

    // We'll pick the first/latest flavor text per species in EN (no version grouping for now)
    var rows = 0;
    for (var r4 = 1; r4 < H; r4++){
        var sid4 = __to_int_safe(__grid(g, ci_sid, r4, 0), 0);
        if (sid4 <= 0) continue;
        var lgid = __to_int_safe(__grid(g, ci_lang, r4, 0), 0);
        if (lgid != en_id) continue;
        var raw_cell = string(__grid(g, ci_text, r4, ""));
        var txt = __text_clean_spaces(raw_cell);
        // If cleaning removed everything (rare), try the raw trimmed cell as a fallback
        if (string_length(txt) == 0){
            var raw_trim = string_trim(raw_cell);
            if (string_length(raw_trim) > 0) txt = raw_trim;
            else continue;
        }
        // prefer first seen; if already set, skip.
        // Note: array_resize initializes slots to numeric 0 which stringifies to "0",
        // so use an explicit is_string check + trimmed-length test to detect real non-empty strings.
        var _curr = global._species_flavor_text[sid4];
        if (!is_string(_curr) || string_length(__s_trim(_curr)) == 0) {
            global._species_flavor_text[sid4] = txt;
            rows++;
        }
    }
    data_debug("[DATA][species_flavor_text] loaded rows=" + string(rows));
    // Normalize: ensure unfilled or numeric slots don't contain raw 0 values
    if (variable_global_exists("_species_flavor_text") && is_array(global._species_flavor_text)){
        for (var _i2 = 0; _i2 < array_length(global._species_flavor_text); _i2++){
            var _vv = global._species_flavor_text[_i2];
            if (!(is_string(_vv) || is_struct(_vv))) global._species_flavor_text[_i2] = "";
        }
    }
}
// Simple data debug gate: use global.DATA_DEBUG to enable/disable data loader messages
function data_debug(_msg){
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message(_msg);
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
    if (g == -1) { data_debug("[DATA][moves] SKIP: " + path); global._moves = []; return; }
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
    data_debug("[DATA][moves] rows=" + string(_rows));
}

// UPDATED: Move flavor text (PokeAPI) -> move_flavor_text.csv (EN, latest version_group_id)
function data_load_move_text_structs(){
    var path = working_directory + "/data/csv/move_flavor_text.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][move_text] SKIP: " + path); global._move_text = []; return; }
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
                if (ident == "en"){ en_id = __to_int_safe(__grid(lg, ci_lid, rr, 9), 9); break; }
            }
        }
    }

    // Column indices in move_flavor_text.csv
    var ci_move = __col_find_ci(g, "move_id");
    var ci_vg   = __col_find_ci(g, "version_group_id"); // may be absent in some exports
    var ci_lang = __col_find_ci(g, "language_id");
    var ci_text = __col_find_ci(g, "flavor_text");
    if (ci_move < 0 || ci_lang < 0 || ci_text < 0){
        data_debug("[DATA][move_text] ERROR: required columns missing in move_flavor_text.csv");
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
    data_debug("[DATA][move_flavor_text] en_id=" + string(en_id) + " rows_seen=" + string(rows));
}

// Abilities (core)
function data_load_abilities_structs(){
    var path = working_directory + "/data/csv/abilities.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][abilities] SKIP: " + path); global._abilities = []; return; }
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
    data_debug("[DATA][abilities] rows=" + string(_rows));
}

// UPDATED: Ability flavor text (PokeAPI) -> ability_flavor_text.csv (EN)
function data_load_ability_text_structs(){
    var path = working_directory + "/data/csv/ability_flavor_text.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][ability_text] SKIP: " + path); global._ability_text = []; return; }
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
    data_debug("[DATA][ability_text] ERROR: required columns missing in ability_flavor_text.csv");
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
    data_debug("[DATA][ability_flavor_text] en_id=" + string(en_id) + " rows_seen=" + string(rows));
}

function data_load_species_abilities_structs(){
    var path = working_directory + "/data/csv/pokemon_abilities.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][pokemon_abilities] SKIP: " + path); global._species_abilities = []; return; }
    var H = ds_grid_height(g);
    // Two-pass approach: first count entries per species, then allocate inner arrays and fill
    var max_sid = 0;
    var counts = [];
    for (var _r = 1; _r < H; _r++){
        var _sid = __to_int_safe(__grid(g,0,_r,0),0);
        if (_sid <= 0) continue;
        if (_sid > max_sid) max_sid = _sid;
        if (_sid >= array_length(counts)) array_resize(counts, _sid+1);
        counts[_sid] = (is_real(counts[_sid]) ? counts[_sid] + 1 : 1);
    }

    global._species_abilities = []; array_resize(global._species_abilities, max_sid+1);
    var positions = []; // insertion cursors for each species
    for (var _i = 0; _i <= max_sid; _i++){
        var c = (is_real(counts[_i]) ? counts[_i] : 0);
        if (c > 0){
            global._species_abilities[_i] = array_create(c, undefined);
            positions[_i] = 0;
        } else {
            global._species_abilities[_i] = [];
            positions[_i] = 0;
        }
    }
    var _rows = 0;
    for (var _r = 1; _r < H; _r++){
        var _sid = __to_int_safe(__grid(g,0,_r,0),0);
        var _aid = __to_int_safe(__grid(g,1,_r,0),0);
        if (_sid <= 0 || _aid <= 0) continue;
        var pos = positions[_sid];
        global._species_abilities[_sid][pos] = _aid;
        positions[_sid] = pos + 1;
        _rows++;
    }
    data_debug("[DATA][pokemon_abilities] rows=" + string(_rows));
}

function data_load_species_moves_structs(){
    var path = working_directory + "/data/csv/pokemon_moves.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][pokemon_moves] SKIP: " + path); global._species_moves = []; return; }
    var H = ds_grid_height(g);
    var max_sid = 0;
    for (var _r = 1; _r < H; _r++){
        var _sid = __to_int_safe(__grid(g,0,_r,0),0);
        if (_sid > max_sid) max_sid = _sid;
    }
    // Two-pass: count per species then allocate arrays and fill to avoid repeated resizing
    var counts = [];
    for (var _r = 1; _r < H; _r++){
        var _sid = __to_int_safe(__grid(g,0,_r,0),0);
        var _mid = __to_int_safe(__grid(g,2,_r,0),0);
        var _mth = __to_int_safe(__grid(g,3,_r,0),0);
        if (_sid <= 0 || _mid <= 0 || _mth != 1) continue;
        if (_sid >= array_length(counts)) array_resize(counts, _sid+1);
        counts[_sid] = (is_real(counts[_sid]) ? counts[_sid] + 1 : 1);
    }

    global._species_moves = []; array_resize(global._species_moves, max_sid+1);
    var positions = [];
    for (var _i = 0; _i <= max_sid; _i++){
        var c = (is_real(counts[_i]) ? counts[_i] : 0);
        if (c > 0){ global._species_moves[_i] = array_create(c, undefined); positions[_i] = 0; }
        else { global._species_moves[_i] = []; positions[_i] = 0; }
    }
    var _rows = 0;
    for (var _r = 1; _r < H; _r++){
        var _sid = __to_int_safe(__grid(g,0,_r,0),0);
        var _vg  = __to_int_safe(__grid(g,1,_r,0),0);
        var _mid = __to_int_safe(__grid(g,2,_r,0),0);
        var _mth = __to_int_safe(__grid(g,3,_r,0),0); // 1 = level-up
        var _lvl = __to_int_safe(__grid(g,4,_r,0),0);
        if (_sid <= 0 || _mid <= 0 || _mth != 1) continue;
        var pos = positions[_sid];
        global._species_moves[_sid][pos] = { lvl:_lvl, mid:_mid };
        positions[_sid] = pos + 1;
        _rows++;
    }
    // sort each species moves by lvl
    for (var _sid = 0; _sid < array_length(global._species_moves); _sid++){
        var _arr = global._species_moves[_sid];
        if (is_array(_arr) && array_length(_arr) > 1){
            array_sort(_arr, function(a,b){ return a.lvl - b.lvl; });
        }
    }
    data_debug("[DATA][pokemon_moves] rows=" + string(_rows));
}

function data_load_all_structs_ext(){
    data_load_moves_structs();
    data_load_move_text_structs();       // UPDATED to PokeAPI flavor text
    data_load_abilities_structs();
    data_load_ability_text_structs();    // UPDATED to PokeAPI flavor text
    data_load_species_abilities_structs();
    data_load_species_moves_structs();
    // Optional: per-species flavor text/prose (pokemon_species_flavor_text.csv / pokemon_species_flavor_summaries.csv)
    if (is_undefined(data_load_species_flavor_text_structs) == false) data_load_species_flavor_text_structs();
    // Growth rates table + Experience
    data_load_growth_rates_structs();
    data_load_experience_structs();
    // Items + item categories
    data_load_items_structs();
    data_load_item_categorys_structs();
    // Item flags: map + prose
    // Ensure prose table loads first so map normalization can resolve numeric codes
    data_load_item_flag_prose_structs();
    data_load_item_flag_map_structs();
    // Normalize numeric flag ids into textual keys (best-effort)
    data_normalize_item_flag_map();
    // Item prose (human readable effects) and derived structured effects
    data_load_item_prose_structs();
    data_load_item_effects_structs();
    data_debug("[DATA][structs_ext] done.");
}

// ---------- DATA: growth_rates.csv -> global._growth_rates[growth_rate_id] = { id, identifier, name, description }
function data_load_growth_rates_structs(){
    var path = working_directory + "/data/csv/growth_rates.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][growth_rates] SKIP: " + path); global._growth_rates = []; return; }

    var H = ds_grid_height(g);
    var ci_id = __col_find_ci(g, "growth_rate_id");
    var ci_ident = __col_find_ci(g, "identifier");
    var ci_name = __col_find_ci(g, "name");
    var ci_desc = __col_find_ci(g, "description");
    if (ci_id < 0) { data_debug("[DATA][growth_rates] ERROR: missing growth_rate_id column"); global._growth_rates = []; return; }

    // find max id
    var max_id = 0;
    for (var r = 1; r < H; r++){
        var idv = __to_int_safe(__grid(g, ci_id, r, 0), 0);
        if (idv > max_id) max_id = idv;
    }

    global._growth_rates = []; array_resize(global._growth_rates, max_id + 1);
    var rows = 0;
    for (var r2 = 1; r2 < H; r2++){
        var gid = __to_int_safe(__grid(g, ci_id, r2, 0), 0);
        if (gid <= 0) continue;
        var ident = (ci_ident >= 0) ? __s_trim(__grid(g, ci_ident, r2, "")) : string(gid);
        var namev = (ci_name >= 0) ? __s_trim(__grid(g, ci_name, r2, "")) : ident;
        var descv = (ci_desc >= 0) ? __text_clean_spaces(__grid(g, ci_desc, r2, "")) : "";
        global._growth_rates[gid] = { id: gid, identifier: ident, name: namev, description: descv };
        rows++;
    }
    data_debug("[DATA][growth_rates] rows=" + string(rows));
}

// Helper: returns growth rate metadata struct or undefined
function scr_get_growth_rate_meta(_gid){
    if (!is_real(_gid)) return undefined;
    if (!variable_global_exists("_growth_rates") || !is_array(global._growth_rates)) return undefined;
    var g = floor(_gid);
    if (g < 0 || g >= array_length(global._growth_rates)) return undefined;
    return global._growth_rates[g];
}

// ---------- DATA: experience.csv -> global._experience[growth_rate_id] = [exp_by_level]
function data_load_experience_structs(){
    var path = working_directory + "/data/csv/experience.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][experience] SKIP: " + path); global._experience = []; return; }

    var H = ds_grid_height(g);
    // find columns (case-insensitive header lookup)
    var ci_gid = __col_find_ci(g, "growth_rate_id");
    var ci_lvl = __col_find_ci(g, "level");
    var ci_exp = __col_find_ci(g, "experience");
    if (ci_gid < 0 || ci_lvl < 0 || ci_exp < 0){ data_debug("[DATA][experience] ERROR: missing required columns"); global._experience = []; return; }

    // Determine maximum growth_rate_id so we can size outer array
    var max_gid = 0;
    for (var r = 1; r < H; r++){
        var gid = __to_int_safe(__grid(g, ci_gid, r, 0), 0);
        if (gid > max_gid) max_gid = gid;
    }
    global._experience = []; array_resize(global._experience, max_gid + 1);

    // Temporary maps to accumulate per-growth arrays by gid
    var counts = [];
    // First pass: find max level per growth id
    for (var r2 = 1; r2 < H; r2++){
        var gid2 = __to_int_safe(__grid(g, ci_gid, r2, 0), 0);
        var lvl2 = __to_int_safe(__grid(g, ci_lvl, r2, 0), 0);
        if (gid2 <= 0 || lvl2 <= 0) continue;
        if (gid2 >= array_length(counts)) array_resize(counts, gid2 + 1);
        counts[gid2] = max(is_real(counts[gid2]) ? counts[gid2] : 0, lvl2);
    }

    for (var gid3 = 0; gid3 < array_length(counts); gid3++){
        var maxL = (is_real(counts[gid3]) ? counts[gid3] : 0);
        if (maxL > 0) global._experience[gid3] = array_create(maxL + 1, 0); // index by level (1..maxL)
        else global._experience[gid3] = [];
    }

    var rows = 0;
    for (var r3 = 1; r3 < H; r3++){
        var gid4 = __to_int_safe(__grid(g, ci_gid, r3, 0), 0);
        var lvl4 = __to_int_safe(__grid(g, ci_lvl, r3, 0), 0);
        var exp4 = __to_int_safe(__grid(g, ci_exp, r3, 0), 0);
        if (gid4 <= 0 || lvl4 <= 0) continue;
        if (gid4 < array_length(global._experience) && is_array(global._experience[gid4]) && lvl4 < array_length(global._experience[gid4])){
            global._experience[gid4][lvl4] = exp4;
            rows++;
        }
    }
    data_debug("[DATA][experience] rows=" + string(rows));
}

// Helper: get experience threshold for growth_rate_id and level (returns -1 if missing)
function scr_get_exp_for_level(_growth_id, _level){
    if (!is_real(_growth_id) || !is_real(_level)) return -1;
    var gid = floor(_growth_id);
    var lvl = floor(_level);
    if (!variable_global_exists("_experience") || !is_array(global._experience)) return -1;
    if (gid < 0 || gid >= array_length(global._experience)) return -1;
    var arr = global._experience[gid];
    if (!is_array(arr) || lvl <= 0 || lvl >= array_length(arr)) return -1;
    return arr[lvl];
}

// Helper: get next-level threshold for a mon struct (safest)
function scr_get_exp_next_for_mon(_mon){
    if (!is_struct(_mon)) return -1;
    var sid = -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(_mon.species_id)) sid = floor(_mon.species_id);
    else if (variable_struct_exists(_mon, "id") && is_real(_mon.id)) sid = floor(_mon.id);
    if (sid < 0) return -1;
    var lvl = 1;
    if (variable_struct_exists(_mon, "level") && is_real(_mon.level)) lvl = floor(_mon.level);
    else if (variable_struct_exists(_mon, "lvl") && is_real(_mon.lvl)) lvl = floor(_mon.lvl);

    // Get species record and its growth_rate_id
    if (!variable_global_exists("_pokemon") || !is_array(global._pokemon)) return -1;
    if (sid < 0 || sid >= array_length(global._pokemon)) return -1;
    var rec = global._pokemon[sid];
    if (!is_struct(rec)) return -1;
    var gid = -1;
    if (variable_struct_exists(rec, "growth_rate_id") && is_real(rec.growth_rate_id)) gid = floor(rec.growth_rate_id);
    else if (variable_struct_exists(rec, "_growth_rate") && is_real(rec._growth_rate)) gid = floor(rec._growth_rate);
    if (gid < 0) return -1;

    // lookup for level+1
    var next = scr_get_exp_for_level(gid, lvl + 1);
    return is_real(next) && next >= 0 ? next : -1;
}


// ===================== ITEMS (NEW) - 2025-10-09 =====================

function data_load_items_structs(){
    var csv_path = working_directory + "/data/csv/items.csv";
    var g = load_csv(csv_path);
    if (g == -1) { data_debug("[DATA][items] SKIP: " + csv_path); global._items = []; return; }
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

    data_debug("[DATA][items] rows=" + string(rows));
}


// ---------- ITEMS: categories / pockets (NEW) ----------
// Loads item_categories.csv (optional). Produces:
//  - global.item_categorys[pocket_id] = { id, identifier, name, pocket_id, pocket_name }
//  - global._item_to_bag_page[item_id] = pocket_index (0-4)  -- best-effort mapping for bag seeding
function data_load_item_categorys_structs(){
    var csv_path = working_directory + "/data/csv/item_categories.csv";
    var g = load_csv(csv_path);
    if (g == -1) { data_debug("[DATA][item_categories] SKIP: " + csv_path); global.item_categorys = []; global._item_to_bag_page = []; return; }

    var H = ds_grid_height(g);
    // discover max id
    var max_id = 0;
    for (var r = 1; r < H; r++){
        var idv = __to_int_safe(__grid(g,0,r,0), 0);
        if (idv > max_id) max_id = idv;
    }

    global.item_categorys = []; array_resize(global.item_categorys, max_id + 1);
    // Build a simple pocket -> page mapping. Default pocket ordering will be filled into pages 0..n-1,
    // but bag expects at most 5 pages; we'll clamp to 0..4. If CSV has a 'pocket_id' or 'pocket' column,
    // we will use that to group categories into pockets; otherwise categories map directly by id.

    // Try to find pocket column names (case-insensitive)
    var ci_id = __col_find_ci(g, "id");
    var ci_ident = __col_find_ci(g, "identifier");
    var ci_name = __col_find_ci(g, "name");
    var ci_pocket = __col_find_ci(g, "pocket") ;

    // Create mapping from pocket name to page index (do this with a dict to avoid repeated array_push)
    var pocket_map = {}; // pocket_name -> index
    var pocket_list_counts = []; // temporary to preserve insertion order
    var rows = 0;
    for (var r2 = 1; r2 < H; r2++){
        var cid = (ci_id >= 0) ? __to_int_safe(__grid(g, ci_id, r2, 0), 0) : __to_int_safe(__grid(g, 0, r2, 0), 0);
        if (cid <= 0) continue;
        var ident = (ci_ident >= 0) ? __s_trim(__grid(g, ci_ident, r2, "")) : string(__grid(g,1,r2,""));
        var namev = (ci_name >= 0) ? __s_trim(__grid(g, ci_name, r2, "")) : ident;
        var pocket_name = (ci_pocket >= 0) ? __s_trim(__grid(g, ci_pocket, r2, "")) : string(cid);

        var pocket_id = -1;
        // Defensive: only treat pocket_map as a struct if it really is one; pocket_name should be a string
        if (is_struct(pocket_map) && is_string(pocket_name) && variable_struct_exists(pocket_map, pocket_name)){
            pocket_id = pocket_map[pocket_name];
        } else {
            pocket_id = array_length(pocket_list_counts);
            pocket_list_counts[pocket_id] = pocket_name;
            if (is_struct(pocket_map)) pocket_map[pocket_name] = pocket_id;
            else {
                // If pocket_map somehow isn't a struct, fall back to creating a local struct mapping
                pocket_map = {};
                pocket_map[pocket_name] = pocket_id;
            }
        }

        global.item_categorys[cid] = { id:cid, identifier:ident, name:namev, pocket:pocket_name, pocket_id:pocket_id };
        rows++;
    }

    // Convert the collected pocket list into a simple array and clamp pages to 0..4
    global._item_pockets = pocket_list_counts;
    global._item_to_bag_page = [];
    // Find column for items -> category mapping if present in items.csv (we already read items earlier)
    // Fallback: use category_id stored on each global._items[item_id].category_id
    for (var iid = 1; iid < array_length(global._items); iid++){
        var it = global._items[iid];
        if (!is_struct(it)) continue;
        var cat = -1;
        if (variable_struct_exists(it, "category_id")) cat = it.category_id;
        if (cat <= 0) {
            global._item_to_bag_page[iid] = 0;
            continue;
        }
        if (cat < array_length(global.item_categorys) && is_struct(global.item_categorys[cat]) && variable_struct_exists(global.item_categorys[cat], "pocket_id")){
            var pg = global.item_categorys[cat].pocket_id;
            if (!is_real(pg) || pg < 0) pg = 0;
            // clamp 0..4
            pg = min(4, max(0, floor(pg)));
            global._item_to_bag_page[iid] = pg;
        } else {
            // try lookup by pocket name
            var pocket_name = (cat < array_length(global.item_categorys) && is_struct(global.item_categorys[cat])) ? global.item_categorys[cat].pocket : string(cat);
            var pg = 0;
            // find pocket index in pocket_order
            for (var pidx = 0; pidx < array_length(pocket_list_counts); pidx++){
                if (pocket_list_counts[pidx] == pocket_name){ pg = pidx; break; }
            }
            pg = min(4, max(0, floor(pg)));
            global._item_to_bag_page[iid] = pg;
        }
    }

    data_debug("[DATA][item_categories] rows=" + string(rows) + " pockets=" + string(array_length(global._item_pockets)) );
}


// ---------- ITEMS: flags (map + prose) ----------
// data/csv/item_flag_map.csv => maps item_id -> flag codes (simple CSV with columns like item_id,flag_code)
// Produces global._item_flag_map[item_id] = ["flag1","flag2",...]
function data_load_item_flag_map_structs(){
    var csv_path = working_directory + "/data/csv/item_flag_map.csv";
    var g = load_csv(csv_path);
    if (g == -1) { data_debug("[DATA][item_flag_map] SKIP: " + csv_path); global._item_flag_map = []; return; }
    var H = ds_grid_height(g);

    // find columns if header exists
    var ci_item = __col_find_ci(g, "item_id");
    var ci_flag = __col_find_ci(g, "flag") ;
    if (ci_item < 0) ci_item = 0; if (ci_flag < 0) ci_flag = 1;

    // find max item id to size array
    var max_iid = 0;
    for (var r = 1; r < H; r++){
        var iid = __to_int_safe(__grid(g, ci_item, r, 0), 0);
        if (iid > max_iid) max_iid = iid;
    }
    // Count entries per item id
    var counts = [];
    for (var r = 1; r < H; r++){
        var iid = __to_int_safe(__grid(g, ci_item, r, 0), 0);
        var flag = __s_trim(__grid(g, ci_flag, r, ""));
        if (iid <= 0 || string_length(flag) == 0) continue;
        if (iid >= array_length(counts)) array_resize(counts, iid+1);
        counts[iid] = (is_real(counts[iid]) ? counts[iid] + 1 : 1);
    }

    global._item_flag_map = [];
    array_resize(global._item_flag_map, max_iid + 1);
    var positions = [];
    for (var i = 0; i <= max_iid; i++){
        var c = (is_real(counts[i]) ? counts[i] : 0);
        if (c > 0){ global._item_flag_map[i] = array_create(c, undefined); positions[i] = 0; }
        else { global._item_flag_map[i] = []; positions[i] = 0; }
    }

    var rows = 0;
    for (var r2 = 1; r2 < H; r2++){
        var iid = __to_int_safe(__grid(g, ci_item, r2, 0), 0);
        if (iid <= 0) continue;
        var raw_flag = __s_trim(__grid(g, ci_flag, r2, ""));
        if (string_length(raw_flag) == 0) continue;
        // Do not attempt to canonicalize numeric flag ids here; leave raw values as-is.
        // Normalization will be done later by data_normalize_item_flag_map() after all loaders finish.
        var norm = raw_flag;
        var pos = positions[iid];
        global._item_flag_map[iid][pos] = norm;
        positions[iid] = pos + 1;
        rows++;
    }
    data_debug("[DATA][item_flag_map] rows=" + string(rows));
}

// data/csv/item_flag_prose.csv => maps flag_code -> prose/description
// Produces global._item_flag_text[flag_code] = { code:flag_code, description: "..." }
function data_load_item_flag_prose_structs(){
    var csv_path = working_directory + "/data/csv/item_flag_prose.csv";
    var g = load_csv(csv_path);
    if (g == -1) {
        // Ensure the globals exist (empty) so callers can detect them but avoid nil checks failing
        global._item_flag_text = [];
        global._item_flag_text_by_code = {};
        data_debug("[DATA][item_flag_prose] SKIP: file missing or unreadable: " + csv_path + " (working_directory=" + string(working_directory) + ")");
        return;
    }
    var H = ds_grid_height(g);

    // Support multiple CSV header styles: prefer 'flag'/'name'/'description' but fall back to common alternatives.
    var ci_flag = __col_find_ci(g, "flag");
    if (ci_flag < 0) ci_flag = __col_find_ci(g, "item_flag_id");
    var ci_name = __col_find_ci(g, "name");
    if (ci_name < 0) ci_name = __col_find_ci(g, "text");
    var ci_desc = __col_find_ci(g, "description");
    if (ci_desc < 0) ci_desc = __col_find_ci(g, "text");
    if (ci_flag < 0) ci_flag = 0; if (ci_name < 0) ci_name = 1; if (ci_desc < 0) ci_desc = ci_name;

    // We'll store as an associative-like array by code index: find unique codes and store them sequentially,
    // but also build a helper lookup by code via a struct `global._item_flag_text_by_code` so callers can find by code.
    global._item_flag_text_by_code = {}; // small struct lookup
    // First count rows so we can allocate the array once
    var total = 0;
    for (var r2 = 1; r2 < H; r2++){
        var code = __s_trim(__grid(g, ci_flag, r2, ""));
        if (string_length(code) == 0) continue;
        total++;
    }
    global._item_flag_text = array_create(total, undefined);
    var idx = 0;
    var rows = 0;
    for (var r2 = 1; r2 < H; r2++){
        var code = __s_trim(__grid(g, ci_flag, r2, ""));
        if (string_length(code) == 0) continue;
        var name_val = __s_trim(__grid(g, ci_name, r2, ""));
        var desc_val = __text_clean_spaces(__grid(g, ci_desc, r2, ""));
        // Normalize name to a short key: lowercase and convert spaces/underscores to hyphens
        var key = string_lower(string_trim(name_val));
        key = string_replace_all(key, " ", "-");
        key = string_replace_all(key, "_", "-");
        var entry = { code:code, name:name_val, key:key, text:desc_val };
        global._item_flag_text[idx] = entry;
    // Store by string key to avoid numeric coercion issues
    global._item_flag_text_by_code[string(code)] = entry;
        idx++; rows++;
    }
    data_debug("[DATA][item_flag_prose] rows=" + string(rows));

    // Extra debug: check runtime shape/type of the helper lookup and probe a sample code
    var _ptype = "missing";
    if (variable_global_exists("_item_flag_text_by_code")){
        if (is_struct(global._item_flag_text_by_code)) _ptype = "struct";
        else if (is_array(global._item_flag_text_by_code)) _ptype = "array";
        else if (is_real(global._item_flag_text_by_code) && ds_exists(global._item_flag_text_by_code, ds_type_map)) _ptype = "ds_map";
        else _ptype = "other";
    }
    data_debug("[DATA][item_flag_prose] prose_type=" + _ptype);
    // probe lookup on first non-empty code from the CSV
    var _probe_code = "";
    for (var r4 = 1; r4 < H; r4++){
        var _pc = __s_trim(__grid(g, ci_flag, r4, ""));
        if (string_length(_pc) > 0){ _probe_code = _pc; break; }
    }
    if (string_length(_probe_code) > 0){
        var _found = false;
        if (!is_undefined(data_get_item_flag_entry)){
            var _entry = data_get_item_flag_entry(_probe_code);
            _found = is_struct(_entry) || is_array(_entry) || (is_real(_entry) && ds_exists(_entry, ds_type_map));
        }
        data_debug("[DATA][item_flag_prose] probe_lookup code=" + string(_probe_code) + " -> found=" + string(_found));
    } else {
        data_debug("[DATA][item_flag_prose] probe_lookup: no code found in CSV rows");
    }

}

// Debug helper: prints a short summary of loaded items and categories
function debug_print_items_and_categories(){
    var cntItems = (variable_global_exists("_items") && is_array(global._items)) ? array_length(global._items) : 0;
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[DEBUG] _items count=" + string(cntItems));
    for (var i = 1; i < min(10, cntItems); i++){
        var it = global._items[i];
    if (is_struct(it) && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[DEBUG] item " + string(i) + ": id=" + string(it._id) + ", name=" + string(it.name) + ", cat=" + string(it.category_id));
    }

    var cntCats = (variable_global_exists("item_categorys") && is_array(global.item_categorys)) ? array_length(global.item_categorys) : 0;
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[DEBUG] item_categorys count=" + string(cntCats));
    for (var c = 0; c < min(20, cntCats); c++){
        var cat = global.item_categorys[c];
    if (is_struct(cat) && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[DEBUG] cat " + string(c) + ": id=" + string(cat.id) + ", name=" + string(cat.name) + ", pocket=" + string(cat.pocket) + ", pocket_id=" + string(cat.pocket_id));
    }
}

// Normalize any numeric flag ids in global._item_flag_map to textual keys using
// global._item_flag_text_by_code. Safe to call multiple times.
function data_normalize_item_flag_map(){
    if (!variable_global_exists("_item_flag_map") || !is_array(global._item_flag_map)) { data_debug("[DATA][normalize_flags] _item_flag_map missing"); return; }
    // If prose table missing, attempt to run the prose loader now (best-effort)
    if (!variable_global_exists("_item_flag_text_by_code") || !is_struct(global._item_flag_text_by_code)){
        if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) data_debug("[DATA][normalize_flags] _item_flag_text_by_code missing — attempting to load prose now");
        if (!is_undefined(data_load_item_flag_prose_structs)){
            data_load_item_flag_prose_structs();
            if (variable_global_exists("_item_flag_text_by_code") && is_struct(global._item_flag_text_by_code)){
                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) data_debug("[DATA][normalize_flags] prose loader succeeded on retry");
            } else {
                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) data_debug("[DATA][normalize_flags] prose loader retry failed — aborting normalization");
                return;
            }
        } else {
            if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) data_debug("[DATA][normalize_flags] prose loader function not available — aborting normalization");
            return;
        }
    }
    var changed = 0;
    var total_checked = 0;
    for (var iid = 0; iid < array_length(global._item_flag_map); iid++){
        var fmap = global._item_flag_map[iid];
        if (!is_array(fmap) || array_length(fmap) == 0) continue;
        for (var fi = 0; fi < array_length(fmap); fi++){
            var raw = string_trim(string(global._item_flag_map[iid][fi]));
            // detect numeric-only tokens
            var only_digits = true;
            for (var d = 1; d <= string_length(raw); d++){ var ch = string_copy(raw, d, 1); if (ch < "0" || ch > "9") { only_digits = false; break; } }
            if (!only_digits) continue;
            total_checked++;
            var ent = data_get_item_flag_entry(raw);
            if (is_struct(ent)){
                var key = "";
                if (variable_struct_exists(ent, "key") && string_length(string_trim(variable_struct_get(ent, "key"))) > 0) key = string_trim(variable_struct_get(ent, "key"));
                else if (variable_struct_exists(ent, "name") && string_length(string_trim(variable_struct_get(ent, "name"))) > 0) key = string_lower(string_trim(variable_struct_get(ent, "name")));
                key = string_replace_all(key, "_", "-");
                if (string_length(key) > 0 && string_lower(string_trim(raw)) != string_lower(string_trim(key))){
                    global._item_flag_map[iid][fi] = key;
                    changed++;
                }
            }
        }
    }
    data_debug("[DATA][normalize_flags] checked=" + string(total_checked) + " changed=" + string(changed));
}

// Tolerant lookup for item_flag prose entries. Returns the entry struct or undefined.
function data_get_item_flag_entry(_code){
    if (!variable_global_exists("_item_flag_text_by_code")) return undefined;
    var m = global._item_flag_text_by_code;
    var key = string(_code);
    // struct-like
    if (is_struct(m)){
        if (variable_struct_exists(m, key)) return variable_struct_get(m, key);
        if (variable_struct_exists(m, _code)) return variable_struct_get(m, _code);
        return undefined;
    }
    // ds_map-like
    if (is_real(m) && ds_exists(m, ds_type_map)){
        if (ds_map_exists(m, key)) return ds_map_find_value(m, key);
        if (ds_map_exists(m, _code)) return ds_map_find_value(m, _code);
        return undefined;
    }
    // fallback: if it's an array (unlikely), try numeric index
    if (is_array(m)){
        // try to find an entry whose .code matches
        for (var i = 0; i < array_length(m); i++){
            if (is_struct(m[i]) && variable_struct_exists(m[i], "code") && string_trim(variable_struct_get(m[i], "code")) == string(_code)) return m[i];
        }
    }
    return undefined;
}

// ---------- ITEMS: prose (human readable effects) ----------
// Loads data/csv/item_prose.csv and produces global._item_prose[item_id] = { short_effect, effect }
function data_load_item_prose_structs(){
    var csv_path = working_directory + "/data/csv/item_prose.csv";
    var g = load_csv(csv_path);
    if (g == -1) { data_debug("[DATA][item_prose] SKIP: " + csv_path); global._item_prose = []; return; }
    var H = ds_grid_height(g);

    // detect language id column and filter to English (fallback to id=9)
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
                if (ident == "en"){ en_id = __to_int_safe(__grid(lg, ci_lid, rr, 9), 9); break; }
            }
        }
    }

    // find columns
    var ci_item = __col_find_ci(g, "item_id"); if (ci_item < 0) ci_item = 0;
    var ci_lang = __col_find_ci(g, "local_language_id"); if (ci_lang < 0) ci_lang = 1;
    var ci_short = __col_find_ci(g, "short_effect"); if (ci_short < 0) ci_short = 2;
    var ci_effect = __col_find_ci(g, "effect"); if (ci_effect < 0) ci_effect = ci_short;

    // find max id
    var max_id = 0;
    for (var r = 1; r < H; r++){
        var iid = __to_int_safe(__grid(g, ci_item, r, 0), 0);
        if (iid > max_id) max_id = iid;
    }

    global._item_prose = []; array_resize(global._item_prose, max_id + 1);
    var rows = 0;
    for (var r2 = 1; r2 < H; r2++){
        var iid2 = __to_int_safe(__grid(g, ci_item, r2, 0), 0);
        if (iid2 <= 0) continue;
        var lgid = __to_int_safe(__grid(g, ci_lang, r2, 0), 0);
        if (lgid != en_id) continue;
        var s = __text_clean_spaces(__grid(g, ci_short, r2, ""));
        var e = __text_clean_spaces(__grid(g, ci_effect, r2, ""));
        global._item_prose[iid2] = { short_effect: s, effect: e };
        rows++;
    }
    data_debug("[DATA][item_prose] rows=" + string(rows));
}

// ---------- ITEMS: effect resolver (simple, best-effort) ----------
// Produces global._item_effects[item_id] = [ { type:..., params:... }, ... ]
function data_load_item_effects_structs(){
    if (!variable_global_exists("_item_prose") || !is_array(global._item_prose)) { data_debug("[DATA][item_effects] _item_prose missing"); global._item_effects = []; return; }
    var max_id = array_length(global._item_prose) - 1;
    if (max_id < 0) { global._item_effects = []; return; }
    global._item_effects = []; array_resize(global._item_effects, max_id + 1);

    // simple patterns (English short_effects) - conservative matching order
    var patterns = [];
    // heal_flat: "Restores N HP."
    patterns[0] = { re: "Restores ([0-9]+) HP", type: "heal_flat" };
    // restore_full: "Restores HP to full"
    patterns[1] = { re: "Restores HP to full", type: "heal_full" };
    // revive half/full
    patterns[2] = { re: "Revives with half HP", type: "revive_half" };
    patterns[3] = { re: "Revives with full HP", type: "revive_full" };
    // cure single status: "Cures poison.", "Cures sleep.", etc.
    patterns[4] = { re: "Cures ([a-zA-Z -]+)\.", type: "cure_status" };
    // cures any status / confusion combined
    patterns[5] = { re: "Cures any status ailment", type: "cure_all" };
    // restores PP: "Restores 10 PP for one move" or "Restores PP to full for one move"
    patterns[6] = { re: "Restores ([0-9]+) PP for (one move|each move)", type: "restore_pp" };
    patterns[7] = { re: "Restores PP to full for (one move|each move)", type: "restore_pp_full" };
    // revives all
    patterns[8] = { re: "Revives all fainted Pokémon", type: "revive_all" };

    for (var iid = 0; iid <= max_id; iid++){
        var entry = global._item_prose[iid];
        if (!is_struct(entry)) continue;
        var s = entry.short_effect;
        if (!is_string(s) || string_length(s) == 0) continue;
        var effects = [];
        var matched = false;

        // Apply each pattern in sequence
        // heal_flat
    var m = string_pos(s, "Restores ");
    if (m > 0 && string_pos(s, "HP") > 0){
            // try to extract number
            var toks = string_split(s, " ");
            for (var ti = 0; ti < array_length(toks); ti++){
                var t = string_replace_all(toks[ti], ",", "");
                var digs = true;
                for (var c = 1; c <= string_length(t); c++){ var ch = string_copy(t, c, 1); if (ch < "0" || ch > "9") { digs = false; break; } }
                if (digs && string_length(t) > 0){
                    var n = __to_int_safe(t, 0);
                    if (n > 0){ effects[ array_length(effects) ] = { type:"heal_flat", params:{ amount:n } }; matched = true; break; }
                }
            }
            if (matched){ global._item_effects[iid] = effects; continue; }
        }

        // heal_full
        if (string_pos("Restores HP to full", s) > 0){ effects[ array_length(effects) ] = { type:"heal_full", params:{} }; global._item_effects[iid] = effects; continue; }

        // revive patterns
        if (string_pos("Revives with half HP", s) > 0){ effects[ array_length(effects) ] = { type:"revive", params:{ mode:"half" } }; global._item_effects[iid] = effects; continue; }
        if (string_pos("Revives with full HP", s) > 0){ effects[ array_length(effects) ] = { type:"revive", params:{ mode:"full" } }; global._item_effects[iid] = effects; continue; }
        if (string_pos("Revives all fainted", s) > 0 || string_pos("Revives all fainted Pokémon", s) > 0){ effects[ array_length(effects) ] = { type:"revive_all", params:{} }; global._item_effects[iid] = effects; continue; }

        // cure all / full-restore
        if (string_pos("Cures any status ailment", s) > 0 && string_pos("Restores HP to full", s) > 0){ effects[ array_length(effects) ] = { type:"full_restore", params:{} }; global._item_effects[iid] = effects; continue; }
        if (string_pos("Cures any status ailment", s) > 0){ effects[ array_length(effects) ] = { type:"cure_all", params:{} }; global._item_effects[iid] = effects; continue; }

        // simple single-status cure (e.g., "Cures poison.")
        var cure_prefix = "Cures ";
        if (string_pos(cure_prefix, s) > 0){
            var after = string_delete(s, 1, string_pos(cure_prefix, s)-1);
            after = string_delete(after, 1, string_length(cure_prefix));
            // take first word up to period
            var endp = string_pos(".", after);
            var status_word = (endp > 0) ? string_copy(after, 1, endp-1) : string_trim(after);
            status_word = string_lower(string_trim(string_replace_all(status_word, " ", "-")));
            if (string_length(status_word) > 0){ effects[ array_length(effects) ] = { type:"cure_status", params:{ status:status_word } }; global._item_effects[iid] = effects; continue; }
        }

        // restore PP numeric or full
        if (string_pos("Restores", s) > 0 && string_pos("PP", s) > 0){
            // numeric amount?
            var toks2 = string_split(s, " ");
            for (var ti2 = 0; ti2 < array_length(toks2); ti2++){
                var t2 = string_replace_all(toks2[ti2], ",", "");
                var okd = true;
                for (var c2 = 1; c2 <= string_length(t2); c2++){ var ch2 = string_copy(t2, c2, 1); if (ch2 < "0" || ch2 > "9") { okd = false; break; } }
                if (okd && string_length(t2) > 0){ var n2 = __to_int_safe(t2, 0); if (n2 > 0){ effects[ array_length(effects) ] = { type:"restore_pp", params:{ amount:n2 } }; global._item_effects[iid] = effects; matched = true; break; } }
            }
            if (matched) continue;
            if (string_pos("Restores PP to full", s) > 0){ effects[ array_length(effects) ] = { type:"restore_pp", params:{ full:true } }; global._item_effects[iid] = effects; continue; }
        }

        // fallback: store empty array so callers know we've parsed but found no structured effects
        global._item_effects[iid] = [];
    }
    data_debug("[DATA][item_effects] parsed up to id=" + string(max_id));
}