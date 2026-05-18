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
    var path = working_directory + "/data/csv/pokemonDB_dataset.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][pokemon_ev_yield] SKIP: " + path); return; }
    data_debug("[DATA][pokemon_ev_yield] LOADED: " + path);
    var H = ds_grid_height(g);
    // Helper: find first matching column name from a list (case-insensitive)
    function __col_find_any(_g, _names){
        for (var __i = 0; __i < array_length(_names); __i++){
            var ci_tmp = __col_find_ci(_g, _names[__i]);
            if (ci_tmp >= 0) return ci_tmp;
        }
        return -1;
    }

    // Find species id column (prefer numeric id column names only)
    var ci_sid = __col_find_any(g, ["species_id","id","pokedex_id","national_id","_id"]);
    // If numeric id columns not present, try to locate a name column to map names->ids
    var ci_name = -1;
    if (ci_sid < 0) ci_name = __col_find_any(g, ["pokemon","name","identifier","species"]);
    // Find EV columns using flexible name variants
    var ci_hp  = __col_find_any(g, ["hp","hp_ev","hp_yield","ev_hp","yield_hp"]);
    var ci_atk = __col_find_any(g, ["atk","attack","atk_ev","attack_ev","ev_atk"]);
    var ci_def = __col_find_any(g, ["def","defense","def_ev","ev_def"]);
    var ci_spa = __col_find_any(g, ["spa","spatk","special_attack","sp_atk","sp_attack","spa_ev"]);
    var ci_spd = __col_find_any(g, ["spd","spdef","special_defense","sp_def","spd_ev"]);
    var ci_spe = __col_find_any(g, ["spe","speed","speed_ev","spe_ev","ev_speed"]);

    if (ci_sid < 0 && ci_name < 0){ data_debug("[DATA][pokemon_ev_yield] ERROR: missing species id or name column in " + path); return; }

    // Build a lookup map from normalized identifier/name -> species id if needed
    var _name_to_id = undefined;
    if (ci_sid < 0 && ci_name >= 0){
        _name_to_id = ds_map_create();
        // normalization helper
        // Normalize a Pokemon name/identifier to an ascii-alphanumeric key
        function __norm_name(_s){
            if (!is_string(_s)) _s = string(_s);
            var t = string_lower(string_trim(_s));
            // remove common prefixes like 'mega '
            if (string_pos("mega ", t) == 1) t = string_delete(t,1,5);
            // replace common gender symbols and arrows
            t = string_replace_all(t, "♀", "f");
            t = string_replace_all(t, "♂", "m");
            t = string_replace_all(t, "é", "e");
            t = string_replace_all(t, "á", "a");
            t = string_replace_all(t, "ó", "o");
            t = string_replace_all(t, "ú", "u");
            t = string_replace_all(t, "à", "a");
            t = string_replace_all(t, "ç", "c");
            // remove punctuation and spaces, keep alnum
            var out = "";
            for (var __c=1; __c<=string_length(t); __c++){
                var ch = string_copy(t, __c, 1);
                if (string_pos(ch, "abcdefghijklmnopqrstuvwxyz0123456789") > 0) out += ch;
            }
            return out;
        }
        // populate map from global._pokemon identifiers
        if (variable_global_exists("_pokemon") && is_array(global._pokemon)){
            for (var __i = 0; __i < array_length(global._pokemon); __i++){
                var rec = global._pokemon[__i];
                if (!is_struct(rec)) continue;
                // try multiple possible name fields
                var cand = "";
                if (variable_struct_exists(rec, "identifier")) cand = string(variable_struct_get(rec, "identifier"));
                if (string_length(string_trim(cand)) == 0 && variable_struct_exists(rec, "name")) cand = string(variable_struct_get(rec, "name"));
                if (string_length(string_trim(cand)) == 0 && variable_struct_exists(rec, "species")) cand = string(variable_struct_get(rec, "species"));
                if (string_length(string_trim(cand)) == 0) continue;
                var k = __norm_name(cand);
                if (string_length(k) > 0) ds_map_replace(_name_to_id, k, __i);
            }
        }
            // prepare container for names that fail to map
            var _unmapped = ds_list_create();

            // Exceptions and heuristics: attempt to resolve variant/form names to canonical species
            var _resolved_cache = ds_map_create();
            var _strip_tokens = [
                "shieldforme","bladeforme","forme","form",
                "alolan","alola","hisuian","hisu","galarian","galar",
                "redstriped","bluestriped","whitestriped","red-striped","blue-striped","white-striped","striped",
                "plantcloak","sandcloak","eastsea","westsea",
                "therian","incarnate","resolute","origin",
                // additional common tokens
                "primal","ash","partner","standardmode","zenmode","standard","zen",
                "meteor","meteorform","minior","white","black","ashgreninja"
            ];

            function __resolve_name(_raw, _name_to_id_map, _resolved_cache_map, _strip_tokens_arr){
                var orig = string_trim(string(_raw));
                var nk = __norm_name(orig);
                if (string_length(nk) == 0) return -1;
                // cached resolution
                if (ds_map_exists(_resolved_cache_map, nk)) return ds_map_find_value(_resolved_cache_map, nk);
                // direct map
                if (ds_map_exists(_name_to_id_map, nk)){
                    var _id = ds_map_find_value(_name_to_id_map, nk);
                    ds_map_replace(_resolved_cache_map, nk, _id);
                    return _id;
                }
                // try stripping known tokens
                for (var ti = 0; ti < array_length(_strip_tokens_arr); ti++){
                    var tok = _strip_tokens_arr[ti];
                    if (string_pos(tok, nk) > 0){
                        var nk2 = string_replace_all(nk, tok, "");
                        nk2 = string_trim(nk2);
                        if (string_length(nk2) > 0 && ds_map_exists(_name_to_id_map, nk2)){
                            var _id2 = ds_map_find_value(_name_to_id_map, nk2);
                            ds_map_replace(_resolved_cache_map, nk, _id2);
                            return _id2;
                        }
                    }
                }
                // iterative truncation: remove trailing words from original
                var words = string_split(orig, " ");
                for (var wlen = array_length(words) - 1; wlen >= 1; wlen--){
                    var cand = "";
                    for (var wi = 0; wi < wlen; wi++){
                        if (wi > 0) cand += " ";
                        cand += words[wi];
                    }
                    var nk3 = __norm_name(cand);
                    if (string_length(nk3) > 0 && ds_map_exists(_name_to_id_map, nk3)){
                        var _id3 = ds_map_find_value(_name_to_id_map, nk3);
                        ds_map_replace(_resolved_cache_map, nk, _id3);
                        return _id3;
                    }
                }
                // last ditch: try removing parenthetical parts e.g. "Foo (East)"
                var pidx = string_pos("(", orig);
                if (pidx > 0){
                    var base = string_copy(orig, 1, pidx-1);
                    var nk4 = __norm_name(base);
                    if (string_length(nk4) > 0 && ds_map_exists(_name_to_id_map, nk4)){
                        var _id4 = ds_map_find_value(_name_to_id_map, nk4);
                        ds_map_replace(_resolved_cache_map, nk, _id4);
                        return _id4;
                    }
                }
                // unresolved
                ds_map_replace(_resolved_cache_map, nk, -1);
                return -1;
            }
    }
    var updated = 0;
    // Helper to map stat token to key
    function __stat_key_from_token(_tok){
        var s = string_lower(string_trim(_tok));
        s = string_replace_all(s, ".", "");
        // common aliases
        if (string_pos("hp", s) > 0) return "hp";
        if (string_pos("attack", s) > 0 || string_pos("atk", s) > 0) return "atk";
        if (string_pos("defense", s) > 0 || string_pos("def", s) > 0) return "def";
        if (string_pos("special attack", s) > 0 || string_pos("spatk", s) > 0 || string_pos("sp atk", s) > 0 || string_pos("spatk", s) > 0 || string_pos("sp atk", s) > 0 || string_pos("spatk", s) > 0 || string_pos("sp atk", s) > 0) return "spa";
        if (string_pos("special defense", s) > 0 || string_pos("spdef", s) > 0 || string_pos("sp def", s) > 0) return "spd";
        if (string_pos("speed", s) > 0 || string_pos("spe", s) > 0) return "spe";
        return undefined;
    }

    // If numeric EV columns missing, try to parse human-readable 'EV Yield' column
    var ci_ev_yield_col = -1;
    if (ci_hp < 0 && ci_atk < 0 && ci_def < 0 && ci_spa < 0 && ci_spd < 0 && ci_spe < 0){
        ci_ev_yield_col = __col_find_any(g, ["ev yield","ev_yield","evyield","ev yield (bp)","evs","evs yield","evs_yield"]);
    }

    for (var r = 1; r < H; r++){
        var sid = 0;
        if (ci_sid >= 0){
            sid = __to_int_safe(__grid(g, ci_sid, r, 0), 0);
        }
        else if (ci_name >= 0){
            var rawname = string_trim(string(__grid(g, ci_name, r, "")));
            var resolved = __resolve_name(rawname, _name_to_id, _resolved_cache, _strip_tokens);
            if (resolved > 0){
                sid = resolved;
            } else {
                sid = 0;
                if (ds_list_find_index(_unmapped, rawname) == -1) ds_list_add(_unmapped, rawname);
            }
        }
        if (sid <= 0 || sid >= array_length(global._pokemon)) continue;
        var hp = 0; var atk = 0; var def = 0; var spa = 0; var spd = 0; var spe = 0;
        if (ci_hp >= 0 || ci_atk >= 0 || ci_def >= 0 || ci_spa >= 0 || ci_spd >= 0 || ci_spe >= 0){
            hp = (ci_hp >= 0 ? __to_int_safe(__grid(g, ci_hp, r, 0), 0) : 0);
            atk = (ci_atk >= 0 ? __to_int_safe(__grid(g, ci_atk, r, 0), 0) : 0);
            def = (ci_def >= 0 ? __to_int_safe(__grid(g, ci_def, r, 0), 0) : 0);
            spa = (ci_spa >= 0 ? __to_int_safe(__grid(g, ci_spa, r, 0), 0) : 0);
            spd = (ci_spd >= 0 ? __to_int_safe(__grid(g, ci_spd, r, 0), 0) : 0) ;
            spe = (ci_spe >= 0 ? __to_int_safe(__grid(g, ci_spe, r, 0), 0) : 0) ;
        } else if (ci_ev_yield_col >= 0){
            // Parse human-readable EV yield like "1 Attack, 1 Sp. Atk"
            var evtxt = string_trim(string(__grid(g, ci_ev_yield_col, r, "")));
            if (string_length(evtxt) > 0){
                var parts = string_split(evtxt, ",");
                for (var __p = 0; __p < array_length(parts); __p++){
                    var tok = string_trim(parts[__p]);
                    // try to extract leading number
                    var num = -1;
                    // find first numeric substring
                    var num_str = "";
                    for (var __c = 1; __c <= string_length(tok); __c++){
                        var ch = string_copy(tok, __c, 1);
                        if (string_pos(ch, "0123456789") > 0) num_str += ch;
                        else if (string_length(num_str) > 0) break;
                    }
                    if (string_length(num_str) > 0) num = __to_int_safe(num_str, -1);
                    if (num <= 0) num = 1; // default to 1 if not specified
                    // determine stat key
                    var key = __stat_key_from_token(tok);
                    if (key == "hp") hp += num;
                    else if (key == "atk") atk += num;
                    else if (key == "def") def += num;
                    else if (key == "spa") spa += num;
                    else if (key == "spd") spd += num;
                    else if (key == "spe") spe += num;
                }
            }
        }
        var rec = global._pokemon[sid];
        if (is_struct(rec)){
            rec.ev_yield = { hp:hp, atk:atk, def:def, spa:spa, spd:spd, spe:spe };
            global._pokemon[sid] = rec;
            updated += 1;
        }
    }
    // report unmapped names (small summary)
    if (is_undefined(_unmapped) == false && ds_list_size(_unmapped) > 0){
        var _cnt = ds_list_size(_unmapped);
        data_debug("[DATA][pokemon_ev_yield] unmapped names ("+string(_cnt)+") - sample:");
        for (var __i = 0; __i < min(10, _cnt); __i++){
            var _nm = ds_list_find_value(_unmapped, __i);
            data_debug("  - " + string(_nm));
        }
        // clean up
        ds_list_destroy(_unmapped);
    }
    data_debug("[DATA][pokemon_ev_yield] updated=" + string(updated) + " (from " + path + ")");
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
    // Guard: avoid running the full orchestrator more than once per process.
    if (variable_global_exists("_data_structs_loaded") && global._data_structs_loaded){
        data_debug("[DATA][structs] already_loaded -> skipping");
        return;
    }
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
    // Mark orchestrator as completed so subsequent calls are no-ops
    global._data_structs_loaded = true;
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
            // debug removed
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
    // header-aware columns (optional)
    var ci_effect = __col_find_ci(g, "effect_id");
    var ci_effect_chance = __col_find_ci(g, "effect_chance");
    var ci_target = __col_find_ci(g, "target_id");
    var ci_accuracy = __col_find_ci(g, "accuracy");
    var ci_damage_class = __col_find_ci(g, "damage_class_id");
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
        var _acc  = (ci_accuracy >= 0) ? __to_int_safe(__grid(g, ci_accuracy, _r, 0), 0) : __to_int_safe(__grid(g, 6, _r, 0), 0);
        var _prio = __to_int_safe(__grid(g,7,_r,0), 0);
        var _target = (ci_target >= 0) ? __to_int_safe(__grid(g, ci_target, _r, 0), 0) : __to_int_safe(__grid(g, 8, _r, 0), 0);
        var _dcls = (ci_damage_class >= 0) ? __to_int_safe(__grid(g, ci_damage_class, _r, 0), 0) : __to_int_safe(__grid(g, 9, _r, 0), 0);
        // effect_id/effect_chance fallback: many dumps lack headers; use PokeAPI column indices if headers absent
        // PokeAPI moves.csv columns (0-based):
            // 0=id, 1=identifier, 2=generation_id, 3=type_id, 4=power, 5=pp, 6=accuracy, 7=priority, 8=target_id, 9=damage_class_id, 10=effect_id, 11=effect_chance, ...
        // Some exports shift effect_id to index 10; use 10/11 as safe defaults when headers missing.
        var _eff  = (ci_effect >= 0) ? __to_int_safe(__grid(g, ci_effect, _r, 0), 0) : __to_int_safe(__grid(g, 10, _r, 0), 0);
        var _effc = (ci_effect_chance >= 0) ? __to_int_safe(__grid(g, ci_effect_chance, _r, 0), 0) : __to_int_safe(__grid(g, 11, _r, 0), 0);
        global._moves[_id] = { id:_id, identifier:_ident, type_id:_type, power:_power, pp:_pp, accuracy:_acc, priority:_prio, target_id:_target, damage_class_id:_dcls, effect_id:_eff, effect_chance:_effc };
        _rows++;
    }
    data_debug("[DATA][moves] rows=" + string(_rows));
}

// Map common effect_id semantics (from move_effect_prose) into simple move_meta
// fields so legacy battle code can rely on global._move_meta for recoil/drain/multi-hit/status.
function data_map_move_effects_to_meta(){
    if (!variable_global_exists("_moves") || !is_array(global._moves)) return;
    if (!variable_global_exists("_move_meta") || !is_array(global._move_meta)) return;
    // Build a small map of effect_id -> prose text (lowercased) for heuristics
    var eff_text = {};
    var eff_path = working_directory + "/data/csv/move_effect_prose.csv";
    var g_eff = load_csv(eff_path);
    if (g_eff != -1){
        var ci_eff_id = __col_find_ci(g_eff, "move_effect_id");
        var ci_short = __col_find_ci(g_eff, "short_effect");
        var ci_effect = __col_find_ci(g_eff, "effect");
        if (ci_eff_id >= 0 && (ci_short >= 0 || ci_effect >= 0)){
            var H = ds_grid_height(g_eff);
            for (var r = 1; r < H; r++){
                var eid = __to_int_safe(__grid(g_eff, ci_eff_id, r, 0), 0);
                if (eid <= 0) continue;
                var txt = "";
                if (ci_short >= 0) txt = string_trim(__grid(g_eff, ci_short, r, ""));
                if (string_length(txt) == 0 && ci_effect >= 0) txt = string_trim(__grid(g_eff, ci_effect, r, ""));
                if (string_length(txt) > 0) eff_text[""+string(eid)] = string_lower(txt);
            }
        }
    }

    var mapped = 0;
    for (var mid = 0; mid < array_length(global._moves); mid++){
        var m = global._moves[mid];
        if (!is_struct(m)) continue;
        var eff = 0;
        if (variable_struct_exists(m, "effect_id") && is_real(m.effect_id)) eff = floor(m.effect_id);
        if (eff <= 0) continue;
        // ensure meta record exists
        if (mid >= array_length(global._move_meta) || is_undefined(global._move_meta[mid]) || !is_struct(global._move_meta[mid])){
            if (mid >= array_length(global._move_meta)) array_resize(global._move_meta, mid+1);
            global._move_meta[mid] = {};
        }
        var mm = global._move_meta[mid];
        // Only fill missing fields to avoid overriding explicit move_meta.csv entries
        function _set_if_missing(_struct, _key, _val){ if (!variable_struct_exists(_struct, _key) || is_undefined(variable_struct_get(_struct, _key))){ variable_struct_set(_struct, _key, _val); return true; } return false; }

        var changed = false;
        var etxt = "";
        if (!is_undefined(eff_text[""+string(eff)])) etxt = string(eff_text[""+string(eff)]);
        // Helper: try extract numeric percent or fraction from text
        function _extract_percent_from_text(_t){
            // look for explicit numbers like '75%' or '1/3' or words 'half'
            var s = string(_t);
            var ppos = string_pos("%", s);
            if (ppos > 0){
                // find number before %
                var num = "";
                for (var i = ppos-1; i >= 1; i--){
                    var ch = string_copy(s, i, 1);
                    if (string_pos(ch, "0123456789") > 0) num = ch + num;
                    else if (string_length(num) > 0) break;
                }
                if (string_length(num) > 0) return __to_int_safe(num, 0);
            }
            // fractions like '1/3' or '1/4'
            var slash = string_pos("/", s);
            if (slash > 0){
                // get digits around slash
                var a = ""; var b = "";
                for (var i = slash-1; i >= 1; i--){ var ch = string_copy(s, i, 1); if (string_pos(ch, "0123456789")>0) a = ch + a; else if (string_length(a)>0) break; }
                for (var i2 = slash+1; i2 <= string_length(s); i2++){ var ch2 = string_copy(s, i2, 1); if (string_pos(ch2, "0123456789")>0) b += ch2; else if (string_length(b)>0) break; }
                if (string_length(a)>0 && string_length(b)>0){ var na = __to_int_safe(a,0); var nb = __to_int_safe(b,1); if (nb>0) return floor(na*100/nb); }
            }
            // words
            if (string_pos(s, "half") > 0 || string_pos(s, "drains half") > 0) return 50;
            if (string_pos(s, "three quarters") > 0 || string_pos(s, "75%") > 0) return 75;
            return -1;
        }

        // Heuristics: drain vs recoil
        if (string_length(etxt) > 0){
            if (eff == 34){
                variable_struct_set(mm, "status", "toxic");
                variable_struct_set(mm, "chance", 100);
                changed = true;
            }
            if (eff == 76){
                changed |= _set_if_missing(mm, "flinch", true);
                if (!variable_struct_exists(mm, "flinch_chance") && variable_struct_exists(m, "effect_chance") && is_real(variable_struct_get(m, "effect_chance"))){
                    variable_struct_set(mm, "flinch_chance", clamp(floor(variable_struct_get(m, "effect_chance")), 0, 100));
                    changed = true;
                }
            }
            // drain (healing) mentions 'drains' or 'heals the user'
            if (string_pos(etxt, "drains") > 0 || string_pos(etxt, "drain") > 0 || string_pos(etxt, "heals the user") > 0 || string_pos(etxt, "restores") > 0){
                var pct = _extract_percent_from_text(etxt);
                if (pct > 0) changed |= _set_if_missing(mm, "drain", pct);
                else changed |= _set_if_missing(mm, "drain", 50);
            }
            // recoil variants (user receives X in recoil / user takes X / user loses)
            if (string_pos(etxt, "recoil") > 0 || string_pos(etxt, "user receives") > 0 || string_pos(etxt, "user takes") > 0 || string_pos(etxt, "user loses") > 0){
                var pct2 = _extract_percent_from_text(etxt);
                if (pct2 > 0){ changed |= _set_if_missing(mm, "drain", -abs(pct2)); }
                else if (string_pos(etxt, "its max") > 0 || string_pos(etxt, "max hp") > 0 || string_pos(etxt, "max HP") > 0){
                    // recoil as fraction of max HP
                    var rx = _extract_percent_from_text(etxt);
                    if (rx > 0) changed |= _set_if_missing(mm, "recoil_max_hp", rx);
                    else changed |= _set_if_missing(mm, "recoil_max_hp", 25);
                }
            }
            // multi-hit
            if (string_pos(etxt, "hits 2-5") > 0 || string_pos(etxt, "hits 2–5") > 0 || string_pos(etxt, "hits 2–5 times") > 0 || string_pos(etxt, "hits 2-5 times") > 0){
                changed |= _set_if_missing(mm, "min_hits", 2);
                changed |= _set_if_missing(mm, "max_hits", 5);
            }
            if (string_pos(etxt, "hits twice") > 0 || string_pos(etxt, "hits twice in") > 0 || string_pos(etxt, "hits two") > 0 || string_pos(etxt, "hits twice.")>0){
                changed |= _set_if_missing(mm, "min_hits", 2);
                changed |= _set_if_missing(mm, "max_hits", 2);
            }
            if (string_pos(etxt, "hits 2–3") > 0 || string_pos(etxt, "hits 2-3") > 0){
                changed |= _set_if_missing(mm, "min_hits", 2);
                changed |= _set_if_missing(mm, "max_hits", 3);
            }

            // status inflictions and chance parsing
            var status_candidates = [ ["sleep","sleep"],["poison","poison"],["paralyze","paralysis"],["burn","burn"],["freeze","freeze"],["confuse","confusion"],["attract","infatuation"],["infatuation","infatuation"] ];
            for (var si = 0; si < array_length(status_candidates); si++){
                var token = status_candidates[si][0]; var ident = status_candidates[si][1];
                if (string_pos(etxt, token) > 0){
                    // prefer explicit percent in prose
                    var pct3 = _extract_percent_from_text(etxt);
                    if (pct3 > 0) changed |= _set_if_missing(mm, "chance", pct3);
                    // fallback to moves.csv.effect_chance
                    var eff_ch = (variable_struct_exists(m, "effect_chance") && is_real(m.effect_chance) && m.effect_chance > 0) ? floor(m.effect_chance) : -1;
                    if (!variable_struct_exists(mm, "chance") && eff_ch > 0) changed |= _set_if_missing(mm, "chance", eff_ch);
                    changed |= _set_if_missing(mm, "status", ident);
                    break;
                }
            }

            // Imprison detection: prose mentioning "imprison" or preventing the foe from using the same moves
            if (string_pos(etxt, "imprison") > 0 || (string_pos(etxt, "prevent") > 0 && string_pos(etxt, "same moves") > 0) || string_pos(etxt, "prevent the opposing") > 0){
                changed |= _set_if_missing(mm, "imprison", true);
            }

            // flinch detection
            if (string_pos(etxt, "flinch") > 0 || string_pos(etxt, "may flinch") > 0){
                var fch = _extract_percent_from_text(etxt);
                if (fch > 0) changed |= _set_if_missing(mm, "flinch_chance", fch);
                changed |= _set_if_missing(mm, "flinch", true);
            }

            // confuse
            if (string_pos(etxt, "confuse") > 0 || string_pos(etxt, "confusion") > 0){
                var cch = _extract_percent_from_text(etxt);
                if (cch > 0) changed |= _set_if_missing(mm, "chance", cch);
                changed |= _set_if_missing(mm, "confuse", true);
            }
            // attract/infatuation
            if (string_pos(etxt, "attract") > 0 || string_pos(etxt, "infatuation") > 0){
                var ach = _extract_percent_from_text(etxt);
                if (ach > 0) changed |= _set_if_missing(mm, "chance", ach);
                changed |= _set_if_missing(mm, "infatuation", true);
            }

        }

        // If mapping still missing but moves.csv provided effect_chance, map that to mm.chance when status present
        if (!variable_struct_exists(mm, "chance") && variable_struct_exists(m, "effect_chance") && is_real(m.effect_chance) && m.effect_chance > 0){
            changed |= _set_if_missing(mm, "chance", floor(m.effect_chance));
        }

        // Fallback explicit effect_id mappings for commonly-used IDs not easily parsed
        if (!changed){
            switch (eff){
                case 4: changed |= _set_if_missing(mm, "drain", 50); break;
                case 9: changed |= _set_if_missing(mm, "drain", 50); break;
                case 5:
                    var burn_chance = -1;
                    if (variable_struct_exists(m, "effect_chance") && is_real(variable_struct_get(m, "effect_chance"))) burn_chance = clamp(floor(variable_struct_get(m, "effect_chance")), 0, 100);
                    if (burn_chance <= 0) burn_chance = 100;
                    changed |= _set_if_missing(mm, "status", "burn");
                    changed |= _set_if_missing(mm, "chance", burn_chance);
                    break;
                case 349: changed |= _set_if_missing(mm, "drain", 75); break;
                case 30: case 361: case 1044: changed |= _set_if_missing(mm, "min_hits", 2); changed |= _set_if_missing(mm, "max_hits", 5); break;
                case 45: case 73: case 425: case 78: changed |= _set_if_missing(mm, "min_hits", 2); changed |= _set_if_missing(mm, "max_hits", 2); break;
                case 49: changed |= _set_if_missing(mm, "drain", -25); break;
                case 199: changed |= _set_if_missing(mm, "drain", -33); break;
                case 254: case 263: changed |= _set_if_missing(mm, "drain", -33); /*many also have status*/ break;
                case 255: /*User takes 1/4 its max HP*/ changed |= _set_if_missing(mm, "recoil_max_hp", 25); break;
                case 270: changed |= _set_if_missing(mm, "drain", -50); break;
                case 39: /* one-hit KO moves: Sheer Cold / Fissure style */ changed |= _set_if_missing(mm, "ohko", true); break;
                case 43: /* bind/wrap/clamp/sand-tomb family: apply trap status */ changed |= _set_if_missing(mm, "status", "trap"); changed |= _set_if_missing(mm, "chance", 100); break;
                default: break;
            }
        }

        if (changed) {
            global._move_meta[mid] = mm;
            mapped += 1;
        }
    }
    // [Drain Special Moves Fix] exact positive-drain fallbacks
    // Keep this list narrow. It patches moves whose CSV effect/meta path can be
    // blank, missing, or zero while preserving the existing move_meta struct shape.
    // 138 Dream Eater = 50%, 570 Parabolic Charge = 50%, 577/613 = 75%,
    // 891 Bitter Blade = 50%, 902 Matcha Gotcha = 50%.
    var _drain_fallback_ids  = [138, 570, 577, 613, 891, 902];
    var _drain_fallback_pcts = [50,  50,  75,  75,  50,  50 ];
    for (var _df_i = 0; _df_i < array_length(_drain_fallback_ids); _df_i++){
        var _df_mid = _drain_fallback_ids[_df_i];
        var _df_pct = _drain_fallback_pcts[_df_i];
        if (!is_real(_df_mid) || _df_mid < 0) continue;
        if (_df_mid >= array_length(global._move_meta)) array_resize(global._move_meta, _df_mid + 1);
        if (is_undefined(global._move_meta[_df_mid]) || !is_struct(global._move_meta[_df_mid])) global._move_meta[_df_mid] = {};
        var _df_mm = global._move_meta[_df_mid];
        var _df_write = false;
        if (!variable_struct_exists(_df_mm, "drain")){
            _df_write = true;
        } else {
            var _df_existing = variable_struct_get(_df_mm, "drain");
            if (is_undefined(_df_existing)) _df_write = true;
            else if (is_real(_df_existing) && real(_df_existing) == 0) _df_write = true;
        }
        if (_df_write){
            variable_struct_set(_df_mm, "drain", _df_pct);
            global._move_meta[_df_mid] = _df_mm;
            mapped += 1;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                data_debug("[DATA][move_effect_map][drain_fallback] move=" + string(_df_mid) + " drain=" + string(_df_pct));
            }
        }
    }

    data_debug("[DATA][move_effect_map] synthesized_meta=" + string(mapped));
    // If debugging enabled, dump a few canonical move meta entries to help diagnose mapping
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        var _check = [38,71,202]; // double-edge, absorb, giga-drain
        for (var _ci = 0; _ci < array_length(_check); _ci++){
            var midc = _check[_ci];
            var mmc = undefined;
            if (variable_global_exists("_move_meta") && is_array(global._move_meta) && midc >= 0 && midc < array_length(global._move_meta)) mmc = global._move_meta[midc];
            if (!is_struct(mmc)) {
                data_debug("[DATA][move_effect_map] move=" + string(midc) + " meta=missing");
                continue;
            }
            var s = "";
            if (variable_struct_exists(mmc, "drain")) s += " drain=" + string(variable_struct_get(mmc, "drain"));
            if (variable_struct_exists(mmc, "recoil_max_hp")) s += " recoil_max_hp=" + string(variable_struct_get(mmc, "recoil_max_hp"));
            if (variable_struct_exists(mmc, "min_hits")) s += " min_hits=" + string(variable_struct_get(mmc, "min_hits"));
            if (variable_struct_exists(mmc, "max_hits")) s += " max_hits=" + string(variable_struct_get(mmc, "max_hits"));
            if (variable_struct_exists(mmc, "status")) s += " status=" + string(variable_struct_get(mmc, "status"));
            if (variable_struct_exists(mmc, "chance")) s += " chance=" + string(variable_struct_get(mmc, "chance"));
            data_debug("[DATA][move_effect_map] move=" + string(midc) + s);
        }
    }
}

// Some newer rows in the bundled moves.csv are present before their companion
// move_meta/effect rows. Fill conservative metadata so those moves at least
// route through the existing generic battle handlers instead of becoming no-ops.
function data_map_late_moves_to_meta(){
    if (!variable_global_exists("_moves") || !is_array(global._moves)) return;
    if (!variable_global_exists("_move_meta") || !is_array(global._move_meta)) global._move_meta = [];
    if (array_length(global._move_meta) < array_length(global._moves)) array_resize(global._move_meta, array_length(global._moves));

    function __late_set(_mid, _effect_id, _meta){
        if (!is_real(_mid) || _mid <= 0 || _mid >= array_length(global._moves)) return false;
        var _mv = global._moves[_mid];
        if (!is_struct(_mv)) return false;

        if (is_real(_effect_id) && _effect_id > 0){
            var _cur_eid = (variable_struct_exists(_mv, "effect_id") && is_real(variable_struct_get(_mv, "effect_id"))) ? floor(variable_struct_get(_mv, "effect_id")) : 0;
            if (_cur_eid <= 0){
                variable_struct_set(_mv, "effect_id", floor(_effect_id));
                global._moves[_mid] = _mv;
            }
        }

        if (!is_struct(global._move_meta[_mid])) global._move_meta[_mid] = {};
        var _mm = global._move_meta[_mid];
        if (is_real(_effect_id) && _effect_id > 0 && (!variable_struct_exists(_mm, "effect_id") || !is_real(variable_struct_get(_mm, "effect_id")))) variable_struct_set(_mm, "effect_id", floor(_effect_id));
        if (is_struct(_meta)){
            var _keys = variable_struct_get_names(_meta);
            for (var _ki = 0; _ki < array_length(_keys); ++_ki){
                var _key = _keys[_ki];
                if (!variable_struct_exists(_mm, _key) || is_undefined(variable_struct_get(_mm, _key))){
                    variable_struct_set(_mm, _key, variable_struct_get(_meta, _key));
                }
            }
        }
        global._move_meta[_mid] = _mm;
        return true;
    }

    var filled = 0;
    for (var _mid = 0; _mid < array_length(global._moves); ++_mid){
        var _mv_auto = global._moves[_mid];
        if (!is_struct(_mv_auto)) continue;
        var _eid_auto = (variable_struct_exists(_mv_auto, "effect_id") && is_real(variable_struct_get(_mv_auto, "effect_id"))) ? floor(variable_struct_get(_mv_auto, "effect_id")) : 0;
        var _pow_auto = (variable_struct_exists(_mv_auto, "power") && is_real(variable_struct_get(_mv_auto, "power"))) ? floor(variable_struct_get(_mv_auto, "power")) : 0;
        if (_eid_auto <= 0 && _pow_auto > 0){
            if (__late_set(_mid, 1, {})) filled += 1;
        }
    }

    // Legends: Arceus / Scarlet-Violet rows that lack companion metadata in the
    // shipped CSVs. Stat ids: 2 Atk, 3 Def, 4 SpA, 5 SpD, 6 Spe, 7 Acc, 8 Eva.
    filled += __late_set(827, 1, { random_statuses:["poison","paralysis","sleep"], chance:50 }); // Dire Claw
    filled += __late_set(828, 1, { stat_changes:[{ stat_id:3, change:1 }] }); // Psyshield Bash
    filled += __late_set(830, 267, {}); // Stone Axe -> Stealth Rock
    filled += __late_set(832, 1, { stat_changes:[{ stat_id:4, change:1 }] }); // Mystical Power
    filled += __late_set(834, 49, { drain:-33 }); // Wave Crash
    filled += __late_set(837, 51, { stat_changes:[{ stat_id:2, change:1 },{ stat_id:3, change:1 },{ stat_id:6, change:1 }] }); // Victory Dance
    filled += __late_set(838, 405, { stat_changes:[{ stat_id:3, change:-1 },{ stat_id:5, change:-1 }] }); // Headlong Rush
    filled += __late_set(839, 1, { status:"poison", chance:30 }); // Barb Barrage
    filled += __late_set(840, 44, { crit_rate:1, stat_changes:[{ stat_id:6, change:1 }] }); // Esper Wing
    filled += __late_set(841, 1, { stat_changes:[{ stat_id:2, change:-1 }] }); // Bitter Malice
    filled += __late_set(842, 51, { stat_changes:[{ stat_id:3, change:2 }] }); // Shelter
    filled += __late_set(843, 44, { crit_rate:1, flinch:true, flinch_chance:30, stat_changes:[{ stat_id:3, change:-1 }] }); // Triple Arrows
    filled += __late_set(844, 1, { status:"burn", chance:30 }); // Infernal Parade
    filled += __late_set(845, 113, {}); // Ceaseless Edge -> Spikes
    filled += __late_set(849, 33, { healing:25 }); // Lunar Blessing, partial support
    filled += __late_set(850, 51, { stat_changes:[{ stat_id:4, change:1 },{ stat_id:5, change:1 }] }); // Take Heart
    filled += __late_set(852, 112, {}); // Silk Trap -> Protect-family
    filled += __late_set(853, 1, { status:"confusion", chance:30 }); // Axe Kick
    filled += __late_set(855, 1, { stat_changes:[{ stat_id:5, change:-2 }] }); // Lumina Crash
    filled += __late_set(858, 51, { stat_changes:[{ stat_id:2, change:2 },{ stat_id:3, change:-2 }] }); // Spicy Extract
    filled += __late_set(859, 405, { stat_changes:[{ stat_id:6, change:-2 }] }); // Spin Out
    filled += __late_set(860, 30, { min_hits:10, max_hits:10 }); // Population Bomb
    filled += __late_set(865, 45, { min_hits:3, max_hits:3 }); // Triple Dive
    filled += __late_set(866, 1, { status:"poison", chance:100 }); // Mortal Spin
    filled += __late_set(868, 51, { stat_changes:[{ stat_id:2, change:2 },{ stat_id:4, change:2 },{ stat_id:6, change:2 }] }); // Fillet Away, HP cost not modeled
    filled += __late_set(870, 44, { crit_rate:6 }); // Flower Trick, approximate guaranteed crit
    filled += __late_set(871, 1, { stat_changes:[{ stat_id:4, change:1 }] }); // Torch Song
    filled += __late_set(872, 1, { stat_changes:[{ stat_id:6, change:1 }] }); // Aqua Step
    filled += __late_set(874, 405, { stat_changes:[{ stat_id:4, change:-1 }] }); // Make It Rain
    filled += __late_set(881, 1, { weather:"snow", weather_duration:5 }); // Chilly Reception, switch not modeled
    filled += __late_set(882, 51, { stat_changes:[{ stat_id:2, change:1 },{ stat_id:6, change:1 }] }); // Tidy Up, hazard clear not modeled
    filled += __late_set(883, 1, { weather:"snow", weather_duration:5 }); // Snowscape
    filled += __late_set(884, 1, { stat_changes:[{ stat_id:6, change:-1 }] }); // Pounce
    filled += __late_set(885, 1, { stat_changes:[{ stat_id:6, change:1 }] }); // Trailblaze
    filled += __late_set(886, 1, { stat_changes:[{ stat_id:2, change:-1 }] }); // Chilling Water
    filled += __late_set(888, 45, { min_hits:2, max_hits:2 }); // Twin Beam
    filled += __late_set(890, 405, { stat_changes:[{ stat_id:3, change:-1 },{ stat_id:5, change:-1 }] }); // Armor Cannon
    filled += __late_set(891, 4, { drain:50 }); // Bitter Blade
    filled += __late_set(895, 44, { crit_rate:1 }); // Aqua Cutter
    filled += __late_set(896, 1, { status:"burn", chance:30 }); // Blazing Torque
    filled += __late_set(897, 1, { status:"sleep", chance:10 }); // Wicked Torque
    filled += __late_set(898, 1, { status:"poison", chance:30 }); // Noxious Torque
    filled += __late_set(899, 1, { status:"paralysis", chance:30 }); // Combat Torque
    filled += __late_set(900, 1, { status:"confusion", chance:30 }); // Magical Torque
    filled += __late_set(902, 4, { drain:50, status:"burn", chance:20 }); // Matcha Gotcha
    filled += __late_set(903, 1, { stat_changes:[{ stat_id:6, change:-1 }] }); // Syrup Bomb
    filled += __late_set(905, 40, { stat_changes:[{ stat_id:4, change:1 }] }); // Electro Shot, charge metadata
    filled += __late_set(908, 112, {}); // Burning Bulwark -> Protect-family
    filled += __late_set(911, 45, { min_hits:2, max_hits:2 }); // Tachyon Cutter
    filled += __late_set(917, 1, { status:"heal-block", chance:100, duration:2 }); // Psychic Noise
    filled += __late_set(919, 203, { status:"toxic", chance:50 }); // Malignant Chain

    data_debug("[DATA][late_moves] synthesized_meta=" + string(filled));
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
                    // debug removed
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
            // Sanitize known problematic long sentence which appears in some CSV dumps.
            // Replace it with a shorter, less alarming phrase. This is non-destructive
            // and only affects the in-memory copy used by the game.
            var _bad = "This move can't be used. It's recommended that this move is forgotten. Once forgotten, this move can't be remembered.";
            if (string_length(text) > 0) text = string_replace_all(text, _bad, "This move can't be used and cannot be remembered once forgotten.");
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

function __ability_effect_identifier_key(_s){
    var _key = string_lower(string_trim(string(_s)));
    _key = string_replace_all(_key, "_", "-");
    _key = string_replace_all(_key, " ", "-");
    return _key;
}

function __ability_effect_push_unique(_arr, _value){
    if (!is_array(_arr)) _arr = [];
    for (var _i = 0; _i < array_length(_arr); ++_i){
        if (_arr[_i] == _value) return _arr;
    }
    array_push(_arr, _value);
    return _arr;
}

function __ability_effect_push_struct(_arr, _rec){
    if (!is_array(_arr)) _arr = [];
    array_push(_arr, _rec);
    return _arr;
}

function __ability_effect_add_type_block(_eff, _type_name){
    _eff.blocked_types = __ability_effect_push_unique(_eff.blocked_types, string_lower(string(_type_name)));
}

function __ability_effect_add_absorb_heal(_eff, _type_name, _fraction){
    __ability_effect_add_type_block(_eff, _type_name);
    _eff.absorb_heal_types = __ability_effect_push_struct(_eff.absorb_heal_types, { type:string_lower(string(_type_name)), fraction:_fraction });
}

function __ability_effect_add_stage_boost(_eff, _type_name, _stat, _delta){
    __ability_effect_add_type_block(_eff, _type_name);
    _eff.block_stage_boosts = __ability_effect_push_struct(_eff.block_stage_boosts, { type:string_lower(string(_type_name)), stat:_stat, delta:_delta });
}

function __ability_effect_add_taken_multiplier(_eff, _type_name, _mult){
    _eff.damage_taken_multipliers = __ability_effect_push_struct(_eff.damage_taken_multipliers, { type:string_lower(string(_type_name)), mult:_mult });
}

function __ability_effect_add_status_immunity(_eff, _status_name){
    _eff.status_immunities = __ability_effect_push_unique(_eff.status_immunities, string_lower(string(_status_name)));
}

function __ability_effect_add_volatile_immunity(_eff, _volatile_name){
    if (!variable_struct_exists(_eff, "volatile_immunities") || !is_array(_eff.volatile_immunities)) _eff.volatile_immunities = [];
    _eff.volatile_immunities = __ability_effect_push_unique(_eff.volatile_immunities, string_lower(string(_volatile_name)));
}

function __ability_effect_add_group(_eff, _group_id){
    _eff.groups = __ability_effect_push_unique(_eff.groups, string_lower(string(_group_id)));
}

function __ability_effect_add_action(_eff, _hook, _kind, _data){
    var _rec = { hook:string_lower(string(_hook)), kind:string_lower(string(_kind)), data:_data };
    _eff.actions = __ability_effect_push_struct(_eff.actions, _rec);
}

function __ability_effect_apply_known_tags(_eff){
    var _ident = __ability_effect_identifier_key(_eff.identifier);
    switch (_ident){
        case "stench":
            __ability_effect_add_group(_eff, "move_secondary_chance");
            __ability_effect_add_action(_eff, "after_damage", "flinch_bonus", { chance:10 });
            _eff.flinch_bonus_chance = 10;
            break;
        case "drizzle":
            __ability_effect_add_group(_eff, "entry_weather");
            __ability_effect_add_action(_eff, "on_entry", "set_weather", { weather:"rain", duration:5 });
            _eff.entry_weather = "rain";
            break;
        case "drought":
            __ability_effect_add_group(_eff, "entry_weather");
            __ability_effect_add_action(_eff, "on_entry", "set_weather", { weather:"sun", duration:5 });
            _eff.entry_weather = "sun";
            break;
        case "sand-stream":
            __ability_effect_add_group(_eff, "entry_weather");
            __ability_effect_add_action(_eff, "on_entry", "set_weather", { weather:"sandstorm", duration:5 });
            _eff.entry_weather = "sandstorm";
            break;
        case "snow-warning":
            __ability_effect_add_group(_eff, "entry_weather");
            __ability_effect_add_action(_eff, "on_entry", "set_weather", { weather:"hail", duration:5 });
            _eff.entry_weather = "hail";
            break;
        case "cloud-nine":
        case "air-lock":
            __ability_effect_add_group(_eff, "weather_suppress");
            __ability_effect_add_action(_eff, "weather_check", "suppress_weather", {});
            break;
        case "intimidate":
            __ability_effect_add_group(_eff, "entry_stage_opponents");
            __ability_effect_add_action(_eff, "on_entry", "stage_opponents", { stat:"atk", delta:-1, blockers:["clear-body", "white-smoke", "hyper-cutter", "full-metal-body", "inner-focus", "oblivious", "scrappy"] });
            _eff.entry_stage_opponents = __ability_effect_push_struct(_eff.entry_stage_opponents, { stat:"atk", delta:-1, blockers:["clear-body", "white-smoke", "hyper-cutter", "full-metal-body", "inner-focus", "oblivious", "scrappy"] });
            break;
        case "water-absorb":
            __ability_effect_add_group(_eff, "type_absorb_heal");
            __ability_effect_add_action(_eff, "on_defend_type", "absorb_heal", { type:"water", fraction:0.25 });
            __ability_effect_add_absorb_heal(_eff, "water", 0.25);
            break;
        case "volt-absorb":
            __ability_effect_add_group(_eff, "type_absorb_heal");
            __ability_effect_add_action(_eff, "on_defend_type", "absorb_heal", { type:"electric", fraction:0.25 });
            __ability_effect_add_absorb_heal(_eff, "electric", 0.25);
            break;
        case "dry-skin":
            __ability_effect_add_group(_eff, "type_absorb_heal");
            __ability_effect_add_group(_eff, "type_damage_taken_multiplier");
            __ability_effect_add_action(_eff, "on_defend_type", "absorb_heal", { type:"water", fraction:0.25 });
            __ability_effect_add_action(_eff, "damage_taken", "type_multiplier", { type:"fire", mult:1.25 });
            __ability_effect_add_absorb_heal(_eff, "water", 0.25);
            __ability_effect_add_taken_multiplier(_eff, "fire", 1.25);
            break;
        case "storm-drain":
            __ability_effect_add_group(_eff, "type_absorb_stage");
            __ability_effect_add_action(_eff, "on_defend_type", "block_stage_boost", { type:"water", stat:"spa", delta:1 });
            __ability_effect_add_stage_boost(_eff, "water", "spa", 1);
            break;
        case "lightning-rod":
            __ability_effect_add_group(_eff, "type_absorb_stage");
            __ability_effect_add_action(_eff, "on_defend_type", "block_stage_boost", { type:"electric", stat:"spa", delta:1 });
            __ability_effect_add_stage_boost(_eff, "electric", "spa", 1);
            break;
        case "motor-drive":
            __ability_effect_add_group(_eff, "type_absorb_stage");
            __ability_effect_add_action(_eff, "on_defend_type", "block_stage_boost", { type:"electric", stat:"spe", delta:1 });
            __ability_effect_add_stage_boost(_eff, "electric", "spe", 1);
            break;
        case "sap-sipper":
            __ability_effect_add_group(_eff, "type_absorb_stage");
            __ability_effect_add_action(_eff, "on_defend_type", "block_stage_boost", { type:"grass", stat:"atk", delta:1 });
            __ability_effect_add_stage_boost(_eff, "grass", "atk", 1);
            break;
        case "flash-fire":
            __ability_effect_add_group(_eff, "type_block_boost");
            __ability_effect_add_action(_eff, "on_defend_type", "flash_fire", { type:"fire" });
            __ability_effect_add_type_block(_eff, "fire");
            _eff.flash_fire = true;
            break;
        case "levitate":
            __ability_effect_add_group(_eff, "type_immunity");
            __ability_effect_add_action(_eff, "on_defend_type", "block_type", { type:"ground", grounded_check:true });
            __ability_effect_add_type_block(_eff, "ground");
            break;
        case "overgrow":
            __ability_effect_add_group(_eff, "low_hp_type_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "low_hp_type_multiplier", { type:"grass", mult:1.5 });
            _eff.low_hp_type = "grass"; _eff.low_hp_multiplier = 1.5;
            break;
        case "blaze":
            __ability_effect_add_group(_eff, "low_hp_type_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "low_hp_type_multiplier", { type:"fire", mult:1.5 });
            _eff.low_hp_type = "fire"; _eff.low_hp_multiplier = 1.5;
            break;
        case "torrent":
            __ability_effect_add_group(_eff, "low_hp_type_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "low_hp_type_multiplier", { type:"water", mult:1.5 });
            _eff.low_hp_type = "water"; _eff.low_hp_multiplier = 1.5;
            break;
        case "swarm":
            __ability_effect_add_group(_eff, "low_hp_type_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "low_hp_type_multiplier", { type:"bug", mult:1.5 });
            _eff.low_hp_type = "bug"; _eff.low_hp_multiplier = 1.5;
            break;
        case "thick-fat":
            __ability_effect_add_group(_eff, "type_damage_taken_multiplier");
            __ability_effect_add_action(_eff, "damage_taken", "type_multiplier", { type:"fire", mult:0.5 });
            __ability_effect_add_action(_eff, "damage_taken", "type_multiplier", { type:"ice", mult:0.5 });
            __ability_effect_add_taken_multiplier(_eff, "fire", 0.5);
            __ability_effect_add_taken_multiplier(_eff, "ice", 0.5);
            break;
        case "heatproof":
            __ability_effect_add_group(_eff, "type_damage_taken_multiplier");
            __ability_effect_add_action(_eff, "damage_taken", "type_multiplier", { type:"fire", mult:0.5 });
            __ability_effect_add_taken_multiplier(_eff, "fire", 0.5);
            break;
        case "water-bubble":
            __ability_effect_add_group(_eff, "type_damage_taken_multiplier");
            __ability_effect_add_group(_eff, "status_immunity");
            __ability_effect_add_action(_eff, "damage_taken", "type_multiplier", { type:"fire", mult:0.5 });
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"burn" });
            __ability_effect_add_taken_multiplier(_eff, "fire", 0.5);
            __ability_effect_add_status_immunity(_eff, "burn");
            break;
        case "filter":
        case "solid-rock":
        case "prism-armor":
            __ability_effect_add_group(_eff, "super_effective_damage_reduce");
            __ability_effect_add_action(_eff, "type_effectiveness", "super_effective_multiplier", { mult:0.75 });
            break;
        case "tinted-lens":
            __ability_effect_add_group(_eff, "not_very_effective_damage_boost");
            __ability_effect_add_action(_eff, "type_effectiveness", "not_very_effective_multiplier", { mult:2 });
            break;
        case "adaptability":
            __ability_effect_add_group(_eff, "stab_modifier");
            __ability_effect_add_action(_eff, "stab", "stab_multiplier", { mult:2 });
            break;
        case "wonder-guard":
            __ability_effect_add_group(_eff, "super_effective_only_damage");
            __ability_effect_add_action(_eff, "type_effectiveness", "block_non_super_effective", {});
            break;
        case "huge-power":
            __ability_effect_add_group(_eff, "stat_multiplier");
            __ability_effect_add_action(_eff, "stat_calc", "attack_multiplier", { mult:2, physical_only:true });
            _eff.attack_stat_multiplier = 2;
            break;
        case "pure-power":
            __ability_effect_add_group(_eff, "stat_multiplier");
            __ability_effect_add_action(_eff, "stat_calc", "attack_multiplier", { mult:2, physical_only:true });
            _eff.attack_stat_multiplier = 2;
            break;
        case "guts":
            __ability_effect_add_group(_eff, "status_stat_multiplier");
            __ability_effect_add_action(_eff, "stat_calc", "attack_when_status_multiplier", { mult:1.5, physical_only:true });
            _eff.attack_status_multiplier = 1.5;
            break;
        case "marvel-scale":
            __ability_effect_add_group(_eff, "status_stat_multiplier");
            __ability_effect_add_action(_eff, "stat_calc", "defense_when_status_multiplier", { mult:1.5, physical_only:true });
            _eff.defense_status_multiplier = 1.5;
            break;
        case "fur-coat":
            __ability_effect_add_group(_eff, "stat_multiplier");
            __ability_effect_add_action(_eff, "stat_calc", "defense_multiplier", { mult:2, physical_only:true });
            _eff.defense_stat_multiplier = 2;
            break;
        case "swift-swim":
            __ability_effect_add_group(_eff, "weather_speed_multiplier");
            __ability_effect_add_action(_eff, "speed_calc", "weather_speed_multiplier", { weather:["rain"], mult:2 });
            break;
        case "chlorophyll":
            __ability_effect_add_group(_eff, "weather_speed_multiplier");
            __ability_effect_add_action(_eff, "speed_calc", "weather_speed_multiplier", { weather:["sun","harsh-sun"], mult:2 });
            break;
        case "sand-rush":
            __ability_effect_add_group(_eff, "weather_speed_multiplier");
            __ability_effect_add_action(_eff, "speed_calc", "weather_speed_multiplier", { weather:["sandstorm"], mult:2 });
            break;
        case "slush-rush":
            __ability_effect_add_group(_eff, "weather_speed_multiplier");
            __ability_effect_add_action(_eff, "speed_calc", "weather_speed_multiplier", { weather:["hail","snow"], mult:2 });
            break;
        case "prankster":
            __ability_effect_add_group(_eff, "priority_modifier");
            __ability_effect_add_action(_eff, "priority_calc", "status_priority_bonus", { bonus:1 });
            break;
        case "gale-wings":
            __ability_effect_add_group(_eff, "priority_modifier");
            __ability_effect_add_action(_eff, "priority_calc", "type_priority_bonus", { type:"flying", bonus:1, full_hp_only:true });
            break;
        case "triage":
            __ability_effect_add_group(_eff, "priority_modifier");
            __ability_effect_add_action(_eff, "priority_calc", "healing_priority_bonus", { bonus:3 });
            break;
        case "quick-feet":
            __ability_effect_add_group(_eff, "status_speed_multiplier");
            __ability_effect_add_action(_eff, "speed_calc", "speed_when_status_multiplier", { mult:1.5 });
            break;
        case "slow-start":
            __ability_effect_add_group(_eff, "turn_limited_stat_modifier");
            __ability_effect_add_action(_eff, "stat_calc", "early_turn_attack_speed_multiplier", { turns:5, attack_mult:0.5, speed_mult:0.5 });
            break;
        case "solar-power":
            __ability_effect_add_group(_eff, "weather_stat_multiplier");
            __ability_effect_add_group(_eff, "weather_residual_damage");
            __ability_effect_add_action(_eff, "stat_calc", "weather_spa_multiplier", { weather:["sun","harsh-sun"], mult:1.5 });
            __ability_effect_add_action(_eff, "end_turn", "weather_fraction_damage", { weather:["sun","harsh-sun"], fraction:0.125 });
            break;
        case "flower-gift":
            __ability_effect_add_group(_eff, "weather_party_stat_multiplier");
            __ability_effect_add_action(_eff, "stat_calc", "sun_party_attack_spdef_multiplier", { weather:["sun","harsh-sun"], attack_mult:1.5, spdef_mult:1.5 });
            break;
        case "defeatist":
            __ability_effect_add_group(_eff, "hp_threshold_stat_modifier");
            __ability_effect_add_action(_eff, "stat_calc", "attack_spa_when_hp_below_multiplier", { hp_fraction:0.5, mult:0.5 });
            break;
        case "iron-fist":
            __ability_effect_add_group(_eff, "move_tag_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "flag_multiplier", { flag:"punch", mult:1.2 });
            break;
        case "strong-jaw":
            __ability_effect_add_group(_eff, "move_tag_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "flag_multiplier", { flag:"bite", mult:1.5 });
            break;
        case "mega-launcher":
            __ability_effect_add_group(_eff, "move_tag_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "flag_multiplier", { flag:"pulse", mult:1.5 });
            break;
        case "reckless":
            __ability_effect_add_group(_eff, "move_tag_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "recoil_move_multiplier", { mult:1.2 });
            break;
        case "tough-claws":
            __ability_effect_add_group(_eff, "contact_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "contact_multiplier", { mult:1.3 });
            break;
        case "technician":
            __ability_effect_add_group(_eff, "base_power_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "low_power_multiplier", { max_power:60, mult:1.5 });
            break;
        case "sheer-force":
            __ability_effect_add_group(_eff, "secondary_effect_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "secondary_effect_multiplier", { mult:1.3, suppress_secondary:true });
            break;
        case "sniper":
            __ability_effect_add_group(_eff, "critical_damage_modifier");
            __ability_effect_add_action(_eff, "damage_dealt", "critical_multiplier_bonus", { mult:1.5 });
            break;
        case "mold-breaker":
        case "turboblaze":
        case "teravolt":
            __ability_effect_add_group(_eff, "ability_ignore");
            __ability_effect_add_action(_eff, "target_ability_check", "ignore_defensive_abilities", {});
            break;
        case "battle-armor":
            __ability_effect_add_group(_eff, "crit_immunity");
            __ability_effect_add_action(_eff, "damage_taken", "block_crit", {});
            _eff.crit_immunity = true;
            break;
        case "shell-armor":
            __ability_effect_add_group(_eff, "crit_immunity");
            __ability_effect_add_action(_eff, "damage_taken", "block_crit", {});
            _eff.crit_immunity = true;
            break;
        case "sturdy":
            __ability_effect_add_group(_eff, "survive_full_hp_ko");
            __ability_effect_add_action(_eff, "before_damage_apply", "survive_full_hp_ko", { hp:1 });
            _eff.sturdy = true;
            break;
        case "soundproof":
            __ability_effect_add_group(_eff, "move_flag_immunity");
            __ability_effect_add_action(_eff, "move_target_filter", "block_sound", {});
            _eff.soundproof = true;
            break;
        case "bulletproof":
            __ability_effect_add_group(_eff, "move_flag_immunity");
            __ability_effect_add_action(_eff, "move_target_filter", "block_ball_bomb", {});
            break;
        case "overcoat":
            __ability_effect_add_group(_eff, "weather_damage_immunity");
            __ability_effect_add_group(_eff, "powder_move_immunity");
            __ability_effect_add_action(_eff, "weather_check", "block_weather_damage", {});
            __ability_effect_add_action(_eff, "move_target_filter", "block_powder", {});
            break;
        case "magic-guard":
            __ability_effect_add_group(_eff, "indirect_damage_immunity");
            __ability_effect_add_action(_eff, "damage_taken", "block_indirect_damage", {});
            break;
        case "shield-dust":
            __ability_effect_add_group(_eff, "secondary_effect_immunity");
            __ability_effect_add_action(_eff, "secondary_effect_check", "block_secondary_effects", {});
            break;
        case "inner-focus":
            __ability_effect_add_group(_eff, "volatile_immunity");
            __ability_effect_add_group(_eff, "intimidate_immunity");
            __ability_effect_add_action(_eff, "volatile_apply", "block_volatile", { volatile:"flinch" });
            __ability_effect_add_action(_eff, "on_entry_target", "block_intimidate", {});
            __ability_effect_add_volatile_immunity(_eff, "flinch");
            break;
        case "no-guard":
            __ability_effect_add_group(_eff, "accuracy_override");
            __ability_effect_add_action(_eff, "accuracy_check", "no_guard", {});
            _eff.no_guard = true;
            break;
        case "immunity":
            __ability_effect_add_group(_eff, "status_immunity");
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"poison" });
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"toxic" });
            __ability_effect_add_status_immunity(_eff, "poison");
            __ability_effect_add_status_immunity(_eff, "toxic");
            break;
        case "water-veil":
            __ability_effect_add_group(_eff, "status_immunity");
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"burn" });
            __ability_effect_add_status_immunity(_eff, "burn");
            break;
        case "limber":
            __ability_effect_add_group(_eff, "status_immunity");
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"paralysis" });
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"paralyze" });
            __ability_effect_add_status_immunity(_eff, "paralysis");
            __ability_effect_add_status_immunity(_eff, "paralyze");
            break;
        case "insomnia":
            __ability_effect_add_group(_eff, "status_immunity");
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"sleep" });
            __ability_effect_add_status_immunity(_eff, "sleep");
            break;
        case "vital-spirit":
            __ability_effect_add_group(_eff, "status_immunity");
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"sleep" });
            __ability_effect_add_status_immunity(_eff, "sleep");
            break;
        case "sweet-veil":
            __ability_effect_add_group(_eff, "status_immunity");
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"sleep" });
            __ability_effect_add_status_immunity(_eff, "sleep");
            break;
        case "magma-armor":
            __ability_effect_add_group(_eff, "status_immunity");
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"freeze" });
            __ability_effect_add_status_immunity(_eff, "freeze");
            break;
        case "own-tempo":
            __ability_effect_add_group(_eff, "status_immunity");
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"confusion" });
            __ability_effect_add_status_immunity(_eff, "confusion");
            break;
        case "oblivious":
            __ability_effect_add_group(_eff, "volatile_immunity");
            __ability_effect_add_group(_eff, "intimidate_immunity");
            __ability_effect_add_action(_eff, "volatile_apply", "block_volatile", { volatile:["infatuation","taunt"] });
            __ability_effect_add_action(_eff, "on_entry_target", "block_intimidate", {});
            __ability_effect_add_volatile_immunity(_eff, "infatuation");
            __ability_effect_add_volatile_immunity(_eff, "taunt");
            break;
        case "scrappy":
            __ability_effect_add_group(_eff, "intimidate_immunity");
            __ability_effect_add_group(_eff, "type_immunity_bypass");
            __ability_effect_add_action(_eff, "on_entry_target", "block_intimidate", {});
            __ability_effect_add_action(_eff, "type_effectiveness", "bypass_ghost_immunity", { attacking_types:["normal","fighting"], target_type:"ghost" });
            break;
        case "leaf-guard":
            __ability_effect_add_group(_eff, "weather_status_immunity");
            __ability_effect_add_action(_eff, "status_apply", "block_status_in_weather", { weather:["sun","harsh-sun"], status:"major" });
            break;
        case "natural-cure":
            __ability_effect_add_group(_eff, "switch_status_cure");
            __ability_effect_add_action(_eff, "on_switch_out", "cure_major_status", {});
            break;
        case "regenerator":
            __ability_effect_add_group(_eff, "switch_heal");
            __ability_effect_add_action(_eff, "on_switch_out", "heal_fraction", { fraction:0.333333 });
            break;
        case "rough-skin":
        case "iron-barbs":
            __ability_effect_add_group(_eff, "contact_punish_damage");
            __ability_effect_add_action(_eff, "after_contact_taken", "damage_attacker_fraction", { fraction:0.125 });
            break;
        case "static":
            __ability_effect_add_group(_eff, "contact_punish_status");
            __ability_effect_add_action(_eff, "after_contact_taken", "status_attacker_chance", { status:"paralysis", chance:30 });
            break;
        case "flame-body":
            __ability_effect_add_group(_eff, "contact_punish_status");
            __ability_effect_add_action(_eff, "after_contact_taken", "status_attacker_chance", { status:"burn", chance:30 });
            break;
        case "poison-point":
            __ability_effect_add_group(_eff, "contact_punish_status");
            __ability_effect_add_action(_eff, "after_contact_taken", "status_attacker_chance", { status:"poison", chance:30 });
            break;
        case "cute-charm":
            __ability_effect_add_group(_eff, "contact_punish_volatile");
            __ability_effect_add_action(_eff, "after_contact_taken", "volatile_attacker_chance", { volatile:"infatuation", chance:30 });
            break;
        case "effect-spore":
            __ability_effect_add_group(_eff, "contact_punish_status");
            __ability_effect_add_action(_eff, "after_contact_taken", "random_status_attacker_chance", { statuses:["poison","paralysis","sleep"], chance:30 });
            break;
        case "cursed-body":
            __ability_effect_add_group(_eff, "after_hit_move_disable");
            __ability_effect_add_action(_eff, "after_damage_taken", "disable_used_move_chance", { chance:30 });
            break;
        case "weak-armor":
            __ability_effect_add_group(_eff, "after_hit_stage_change");
            __ability_effect_add_action(_eff, "after_physical_damage_taken", "self_stage_change", { changes:[{ stat:"def", delta:-1 }, { stat:"spe", delta:2 }] });
            break;
        case "mummy":
            __ability_effect_add_group(_eff, "contact_ability_replace");
            __ability_effect_add_action(_eff, "after_contact_taken", "replace_attacker_ability", { ability:"mummy" });
            break;
        case "aftermath":
            __ability_effect_add_group(_eff, "faint_contact_punish_damage");
            __ability_effect_add_action(_eff, "on_faint_from_contact", "damage_attacker_fraction", { fraction:0.25 });
            break;
        case "moxie":
        case "chilling-neigh":
            __ability_effect_add_group(_eff, "ko_stage_boost");
            __ability_effect_add_action(_eff, "after_faint_caused", "self_stage_change", { stat:"atk", delta:1 });
            break;
        case "grim-neigh":
            __ability_effect_add_group(_eff, "ko_stage_boost");
            __ability_effect_add_action(_eff, "after_faint_caused", "self_stage_change", { stat:"spa", delta:1 });
            break;
        case "beast-boost":
            __ability_effect_add_group(_eff, "ko_best_stat_boost");
            __ability_effect_add_action(_eff, "after_faint_caused", "self_best_stat_stage_change", { delta:1 });
            break;
        case "soul-heart":
            __ability_effect_add_group(_eff, "faint_stage_boost");
            __ability_effect_add_action(_eff, "after_any_faint", "self_stage_change", { stat:"spa", delta:1 });
            break;
        case "anger-point":
            __ability_effect_add_group(_eff, "critical_hit_reaction");
            __ability_effect_add_action(_eff, "after_critical_damage_taken", "set_stage", { stat:"atk", stage:6 });
            break;
        case "rattled":
            __ability_effect_add_group(_eff, "type_hit_stage_boost");
            __ability_effect_add_action(_eff, "after_type_damage_taken", "self_stage_change", { types:["bug","dark","ghost"], stat:"spe", delta:1 });
            break;
        case "justified":
            __ability_effect_add_group(_eff, "type_hit_stage_boost");
            __ability_effect_add_action(_eff, "after_type_damage_taken", "self_stage_change", { types:["dark"], stat:"atk", delta:1 });
            break;
        case "stamina":
            __ability_effect_add_group(_eff, "after_hit_stage_boost");
            __ability_effect_add_action(_eff, "after_damage_taken", "self_stage_change", { stat:"def", delta:1 });
            break;
        case "steam-engine":
            __ability_effect_add_group(_eff, "type_hit_stage_boost");
            __ability_effect_add_action(_eff, "after_type_damage_taken", "self_stage_change", { types:["fire","water"], stat:"spe", delta:6 });
            break;
        case "water-compaction":
            __ability_effect_add_group(_eff, "type_hit_stage_boost");
            __ability_effect_add_action(_eff, "after_type_damage_taken", "self_stage_change", { types:["water"], stat:"def", delta:2 });
            break;
        case "arena-trap":
            __ability_effect_add_group(_eff, "trapping");
            __ability_effect_add_action(_eff, "switch_check", "trap_grounded_opponents", {});
            break;
        case "shadow-tag":
            __ability_effect_add_group(_eff, "trapping");
            __ability_effect_add_action(_eff, "switch_check", "trap_opponents", {});
            break;
        case "magnet-pull":
            __ability_effect_add_group(_eff, "trapping");
            __ability_effect_add_action(_eff, "switch_check", "trap_type_opponents", { type:"steel" });
            break;
        case "sticky-hold":
            __ability_effect_add_group(_eff, "item_removal_immunity");
            __ability_effect_add_action(_eff, "item_check", "block_item_removal", {});
            break;
        case "klutz":
            __ability_effect_add_group(_eff, "held_item_suppression");
            __ability_effect_add_action(_eff, "item_check", "suppress_held_item", {});
            break;
        case "unburden":
            __ability_effect_add_group(_eff, "item_loss_speed_boost");
            __ability_effect_add_action(_eff, "speed_calc", "speed_after_item_loss_multiplier", { mult:2 });
            break;
        case "speed-boost":
            __ability_effect_add_group(_eff, "end_turn_stage_boost");
            __ability_effect_add_action(_eff, "end_turn", "self_stage_change", { stat:"spe", delta:1 });
            break;
        case "damp":
            __ability_effect_add_group(_eff, "move_explosion_block");
            __ability_effect_add_action(_eff, "move_target_filter", "block_explosion_moves", {});
            break;
        case "sand-veil":
            __ability_effect_add_group(_eff, "weather_evasion_modifier");
            __ability_effect_add_action(_eff, "accuracy_check", "weather_evasion_multiplier", { weather:["sandstorm"], opponent_accuracy_mult:0.8 });
            break;
        case "snow-cloak":
            __ability_effect_add_group(_eff, "weather_evasion_modifier");
            __ability_effect_add_action(_eff, "accuracy_check", "weather_evasion_multiplier", { weather:["hail","snow"], opponent_accuracy_mult:0.8 });
            break;
        case "compound-eyes":
            __ability_effect_add_group(_eff, "accuracy_modifier");
            __ability_effect_add_action(_eff, "accuracy_check", "accuracy_multiplier", { mult:1.3 });
            break;
        case "keen-eye":
            __ability_effect_add_group(_eff, "accuracy_drop_immunity");
            __ability_effect_add_action(_eff, "stage_change", "block_stat_lowering", { stats:["accuracy"] });
            break;
        case "super-luck":
            __ability_effect_add_group(_eff, "critical_rate_modifier");
            __ability_effect_add_action(_eff, "crit_calc", "crit_stage_bonus", { delta:1 });
            break;
        case "serene-grace":
            __ability_effect_add_group(_eff, "move_secondary_chance");
            __ability_effect_add_action(_eff, "secondary_effect_check", "secondary_chance_multiplier", { mult:2 });
            break;
        case "hustle":
            __ability_effect_add_group(_eff, "stat_multiplier");
            __ability_effect_add_group(_eff, "accuracy_modifier");
            __ability_effect_add_action(_eff, "stat_calc", "attack_multiplier", { mult:1.5, physical_only:true });
            __ability_effect_add_action(_eff, "accuracy_check", "physical_accuracy_multiplier", { mult:0.8 });
            break;
        case "rivalry":
            __ability_effect_add_group(_eff, "gender_damage_modifier");
            __ability_effect_add_action(_eff, "damage_dealt", "gender_match_multiplier", { same_sex_mult:1.25, different_sex_mult:0.75 });
            break;
        case "analytic":
            __ability_effect_add_group(_eff, "turn_order_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "moving_last_multiplier", { mult:1.3 });
            break;
        case "download":
            __ability_effect_add_group(_eff, "entry_defense_compare_boost");
            __ability_effect_add_action(_eff, "on_entry", "boost_by_opponent_defenses", { physical_stat:"atk", special_stat:"spa", delta:1 });
            break;
        case "defiant":
            __ability_effect_add_group(_eff, "stat_drop_reaction");
            __ability_effect_add_action(_eff, "after_stat_lowered", "self_stage_change", { stat:"atk", delta:2, opponent_only:true });
            break;
        case "competitive":
            __ability_effect_add_group(_eff, "stat_drop_reaction");
            __ability_effect_add_action(_eff, "after_stat_lowered", "self_stage_change", { stat:"spa", delta:2, opponent_only:true });
            break;
        case "simple":
            __ability_effect_add_group(_eff, "stage_change_modifier");
            __ability_effect_add_action(_eff, "stage_change", "stage_delta_multiplier", { mult:2 });
            break;
        case "contrary":
            __ability_effect_add_group(_eff, "stage_change_modifier");
            __ability_effect_add_action(_eff, "stage_change", "invert_stage_delta", {});
            break;
        case "unaware":
            __ability_effect_add_group(_eff, "stage_ignore");
            __ability_effect_add_action(_eff, "stat_calc", "ignore_target_stage_modifiers", {});
            break;
        case "rock-head":
            __ability_effect_add_group(_eff, "recoil_immunity");
            __ability_effect_add_action(_eff, "recoil_check", "block_recoil", {});
            break;
        case "liquid-ooze":
            __ability_effect_add_group(_eff, "drain_reversal");
            __ability_effect_add_action(_eff, "drain_check", "damage_instead_of_heal", {});
            break;
        case "rain-dish":
            __ability_effect_add_group(_eff, "weather_heal");
            __ability_effect_add_action(_eff, "end_turn", "weather_fraction_heal", { weather:["rain"], fraction:0.0625 });
            break;
        case "ice-body":
            __ability_effect_add_group(_eff, "weather_heal");
            __ability_effect_add_action(_eff, "end_turn", "weather_fraction_heal", { weather:["hail","snow"], fraction:0.0625 });
            break;
        case "poison-heal":
            __ability_effect_add_group(_eff, "status_heal");
            __ability_effect_add_action(_eff, "end_turn", "heal_when_status", { status:["poison","toxic"], fraction:0.125 });
            break;
        case "toxic-boost":
            __ability_effect_add_group(_eff, "status_stat_multiplier");
            __ability_effect_add_action(_eff, "stat_calc", "attack_when_status_multiplier", { status:["poison","toxic"], mult:1.5, physical_only:true });
            break;
        case "flare-boost":
            __ability_effect_add_group(_eff, "status_stat_multiplier");
            __ability_effect_add_action(_eff, "stat_calc", "special_attack_when_status_multiplier", { status:["burn"], mult:1.5 });
            break;
        case "hydration":
            __ability_effect_add_group(_eff, "weather_status_cure");
            __ability_effect_add_action(_eff, "end_turn", "cure_major_status_in_weather", { weather:["rain"] });
            break;
        case "shed-skin":
            __ability_effect_add_group(_eff, "status_cure_chance");
            __ability_effect_add_action(_eff, "end_turn", "cure_major_status_chance", { chance:30 });
            break;
        case "early-bird":
            __ability_effect_add_group(_eff, "sleep_turn_modifier");
            __ability_effect_add_action(_eff, "status_tick", "sleep_turn_multiplier", { mult:0.5 });
            break;
        case "pressure":
            __ability_effect_add_group(_eff, "pp_pressure");
            __ability_effect_add_action(_eff, "pp_consume", "extra_pp_cost_against_self", { extra:1 });
            break;
        case "unnerve":
            __ability_effect_add_group(_eff, "berry_lock");
            __ability_effect_add_action(_eff, "item_check", "block_opponent_berries", {});
            break;
        case "gluttony":
            __ability_effect_add_group(_eff, "berry_threshold_modifier");
            __ability_effect_add_action(_eff, "item_check", "early_pinche_berry_threshold", { hp_fraction:0.5 });
            break;
        case "harvest":
            __ability_effect_add_group(_eff, "berry_restore_chance");
            __ability_effect_add_action(_eff, "end_turn", "restore_consumed_berry_chance", { chance:50, sun_chance:100 });
            break;
        case "cheek-pouch":
            __ability_effect_add_group(_eff, "berry_heal_bonus");
            __ability_effect_add_action(_eff, "after_item_consumed", "heal_fraction_if_berry", { fraction:0.333333 });
            break;
        case "ripen":
            __ability_effect_add_group(_eff, "berry_effect_modifier");
            __ability_effect_add_action(_eff, "item_check", "berry_effect_multiplier", { mult:2 });
            break;
        case "run-away":
            __ability_effect_add_group(_eff, "escape_modifier");
            __ability_effect_add_action(_eff, "escape_check", "always_escape_wild", {});
            break;
        case "pickup":
        case "honey-gather":
        case "ball-fetch":
            __ability_effect_add_group(_eff, "post_battle_item_find");
            __ability_effect_add_action(_eff, "post_battle", "find_item", {});
            break;
        case "illuminate":
            __ability_effect_add_group(_eff, "overworld_encounter_modifier");
            __ability_effect_add_action(_eff, "overworld_encounter_check", "encounter_rate_multiplier", { mult:2 });
            break;
        case "anticipation":
            __ability_effect_add_group(_eff, "entry_danger_sense");
            __ability_effect_add_action(_eff, "on_entry", "warn_super_effective_or_ohko_move", {});
            break;
        case "forewarn":
            __ability_effect_add_group(_eff, "entry_move_reveal");
            __ability_effect_add_action(_eff, "on_entry", "reveal_highest_power_move", {});
            break;
        case "frisk":
            __ability_effect_add_group(_eff, "entry_item_reveal");
            __ability_effect_add_action(_eff, "on_entry", "reveal_target_item", {});
            break;
        case "trace":
            __ability_effect_add_group(_eff, "entry_ability_copy");
            __ability_effect_add_action(_eff, "on_entry", "copy_random_opponent_ability", {});
            break;
        case "imposter":
            __ability_effect_add_group(_eff, "entry_transform");
            __ability_effect_add_action(_eff, "on_entry", "transform_into_opponent", {});
            break;
        case "illusion":
            __ability_effect_add_group(_eff, "entry_disguise");
            __ability_effect_add_action(_eff, "on_entry", "disguise_as_party_member", {});
            break;
        case "forecast":
        case "zen-mode":
        case "stance-change":
        case "shields-down":
        case "schooling":
        case "power-construct":
        case "gulp-missile":
        case "ice-face":
        case "hunger-switch":
        case "zero-to-hero":
        case "tera-shift":
        case "embody-aspect":
            __ability_effect_add_group(_eff, "form_change");
            __ability_effect_add_action(_eff, "form_check", "conditional_form_change", {});
            break;
        case "color-change":
        case "protean":
        case "libero":
        case "mimicry":
            __ability_effect_add_group(_eff, "type_change");
            __ability_effect_add_action(_eff, "type_change_check", "conditional_type_change", {});
            break;
        case "normalize":
        case "refrigerate":
        case "pixilate":
        case "aerilate":
        case "galvanize":
        case "liquid-voice":
            __ability_effect_add_group(_eff, "move_type_conversion");
            __ability_effect_add_action(_eff, "move_type_check", "convert_move_type", {});
            break;
        case "electric-surge":
        case "psychic-surge":
        case "misty-surge":
        case "grassy-surge":
        case "seed-sower":
            __ability_effect_add_group(_eff, "entry_terrain");
            __ability_effect_add_action(_eff, "on_entry", "set_terrain", {});
            break;
        case "primordial-sea":
        case "desolate-land":
        case "delta-stream":
        case "orichalcum-pulse":
        case "hadron-engine":
            __ability_effect_add_group(_eff, "entry_weather");
            __ability_effect_add_group(_eff, "special_weather");
            __ability_effect_add_action(_eff, "on_entry", "set_special_weather", {});
            break;
        case "dark-aura":
        case "fairy-aura":
        case "aura-break":
            __ability_effect_add_group(_eff, "aura_modifier");
            __ability_effect_add_action(_eff, "damage_dealt", "aura_type_modifier", {});
            break;
        case "plus":
        case "minus":
        case "battery":
        case "power-spot":
        case "steely-spirit":
        case "victory-star":
        case "friend-guard":
        case "flower-veil":
        case "aroma-veil":
        case "pastel-veil":
        case "queenly-majesty":
        case "dazzling":
        case "armor-tail":
        case "propeller-tail":
        case "stalwart":
        case "commander":
        case "costar":
            __ability_effect_add_group(_eff, "ally_field_support");
            __ability_effect_add_action(_eff, "ally_check", "field_support", {});
            if (_ident == "plus" || _ident == "minus"){
                __ability_effect_add_action(_eff, "stat_calc", "ally_special_attack_support", { mult:1.5 });
            }
            break;
        case "magic-bounce":
        case "mirror-armor":
        case "good-as-gold":
            __ability_effect_add_group(_eff, "move_reflect_or_block");
            __ability_effect_add_action(_eff, "move_target_filter", "reflect_or_block_status_move", {});
            break;
        case "suction-cups":
        case "guard-dog":
        case "minds-eye":
            __ability_effect_add_group(_eff, "forced_switch_immunity");
            __ability_effect_add_action(_eff, "switch_check", "block_forced_switch", {});
            break;
        case "telepathy":
        case "dancer":
        case "receiver":
        case "power-of-alchemy":
        case "symbiosis":
        case "opportunist":
            __ability_effect_add_group(_eff, "ally_reaction");
            __ability_effect_add_action(_eff, "ally_reaction_check", "react_to_ally_or_opponent_action", {});
            break;
        case "pickpocket":
        case "magician":
            __ability_effect_add_group(_eff, "item_steal");
            __ability_effect_add_action(_eff, "after_contact_or_hit", "steal_item", {});
            break;
        case "long-reach":
        case "unseen-fist":
            __ability_effect_add_group(_eff, "contact_rule_modifier");
            __ability_effect_add_action(_eff, "contact_check", "modify_contact_rule", {});
            break;
        case "corrosion":
            __ability_effect_add_group(_eff, "status_type_bypass");
            __ability_effect_add_action(_eff, "status_apply", "poison_type_bypass", {});
            break;
        case "comatose":
            __ability_effect_add_group(_eff, "status_model_override");
            __ability_effect_add_action(_eff, "status_apply", "always_drowsing_status_model", {});
            break;
        case "merciless":
            __ability_effect_add_group(_eff, "critical_condition_modifier");
            __ability_effect_add_action(_eff, "crit_calc", "always_crit_on_poisoned_target", {});
            break;
        case "neuroforce":
            __ability_effect_add_group(_eff, "super_effective_damage_boost");
            __ability_effect_add_action(_eff, "type_effectiveness", "super_effective_multiplier", { mult:1.25 });
            break;
        case "stakeout":
            __ability_effect_add_group(_eff, "switch_in_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "target_switched_in_multiplier", { mult:2 });
            break;
        case "steelworker":
        case "rocky-payload":
        case "transistor":
        case "dragons-maw":
            __ability_effect_add_group(_eff, "type_damage_dealt_multiplier");
            __ability_effect_add_action(_eff, "damage_dealt", "type_multiplier", {});
            break;
        case "shadow-shield":
        case "multiscale":
        case "fluffy":
        case "ice-scales":
        case "purifying-salt":
        case "well-baked-body":
        case "earth-eater":
        case "wind-rider":
        case "thermal-exchange":
        case "electromorphosis":
        case "wind-power":
            __ability_effect_add_group(_eff, "damage_or_type_reaction");
            __ability_effect_add_action(_eff, "damage_taken", "conditional_damage_or_boost", {});
            break;
        case "berserk":
        case "anger-shell":
        case "cotton-down":
        case "tangling-hair":
        case "gooey":
        case "sand-spit":
        case "perish-body":
        case "wandering-spirit":
        case "lingering-aroma":
        case "toxic-debris":
        case "supersweet-syrup":
        case "toxic-chain":
        case "poison-puppeteer":
            __ability_effect_add_group(_eff, "after_hit_or_contact_reaction");
            __ability_effect_add_action(_eff, "after_damage_taken", "conditional_reaction", {});
            break;
        case "moody":
        case "curious-medicine":
        case "intrepid-sword":
        case "dauntless-shield":
            __ability_effect_add_group(_eff, "stage_event_modifier");
            __ability_effect_add_action(_eff, "stage_event_check", "conditional_stage_event", {});
            break;
        case "multitype":
        case "rks-system":
        case "tera-shell":
        case "teraform-zero":
        case "protosynthesis":
        case "quark-drive":
        case "as-one-glastrier":
        case "as-one-spectrier":
        case "neutralizing-gas":
        case "vessel-of-ruin":
        case "sword-of-ruin":
        case "tablets-of-ruin":
        case "beads-of-ruin":
        case "supreme-overlord":
        case "mycelium-might":
            __ability_effect_add_group(_eff, "special_rule");
            __ability_effect_add_action(_eff, "special_rule_check", "custom_rule", {});
            break;
        case "synchronize":
            __ability_effect_add_group(_eff, "status_reflect");
            __ability_effect_add_action(_eff, "after_status_received", "copy_status_to_source", { statuses:["poison","toxic","burn","paralysis"] });
            break;
        case "truant":
            __ability_effect_add_group(_eff, "turn_skip_cycle");
            __ability_effect_add_action(_eff, "turn_check", "skip_every_other_turn", {});
            break;
        case "tangled-feet":
            __ability_effect_add_group(_eff, "status_evasion_modifier");
            __ability_effect_add_action(_eff, "accuracy_check", "evasion_when_confused_multiplier", { opponent_accuracy_mult:0.5 });
            break;
        case "steadfast":
            __ability_effect_add_group(_eff, "volatile_reaction_stage_boost");
            __ability_effect_add_action(_eff, "after_volatile_received", "self_stage_change", { volatile:"flinch", stat:"spe", delta:1 });
            break;
        case "skill-link":
            __ability_effect_add_group(_eff, "multi_hit_modifier");
            __ability_effect_add_action(_eff, "multi_hit_check", "force_max_hits", {});
            break;
        case "stall":
            __ability_effect_add_group(_eff, "turn_order_modifier");
            __ability_effect_add_action(_eff, "priority_calc", "move_last_in_priority_bracket", {});
            break;
        case "bad-dreams":
            __ability_effect_add_group(_eff, "sleep_target_residual_damage");
            __ability_effect_add_action(_eff, "end_turn", "damage_sleeping_opponents_fraction", { fraction:0.125 });
            break;
        case "healer":
        case "hospitality":
        case "medic":
        case "nurse":
            __ability_effect_add_group(_eff, "ally_heal_support");
            __ability_effect_add_action(_eff, "ally_check", "heal_or_cure_ally", {});
            break;
        case "heavy-metal":
            __ability_effect_add_group(_eff, "weight_modifier");
            __ability_effect_add_action(_eff, "weight_calc", "weight_multiplier", { mult:2 });
            break;
        case "light-metal":
            __ability_effect_add_group(_eff, "weight_modifier");
            __ability_effect_add_action(_eff, "weight_calc", "weight_multiplier", { mult:0.5 });
            break;
        case "poison-touch":
            __ability_effect_add_group(_eff, "contact_dealt_status");
            __ability_effect_add_action(_eff, "after_contact_dealt", "status_target_chance", { status:"poison", chance:30 });
            break;
        case "big-pecks":
            __ability_effect_add_group(_eff, "stat_lowering_immunity");
            __ability_effect_add_action(_eff, "stage_change", "block_stat_lowering", { stats:["def"] });
            break;
        case "wonder-skin":
            __ability_effect_add_group(_eff, "status_move_accuracy_modifier");
            __ability_effect_add_action(_eff, "accuracy_check", "cap_status_move_accuracy", { max_accuracy:50 });
            break;
        case "infiltrator":
            __ability_effect_add_group(_eff, "barrier_bypass");
            __ability_effect_add_action(_eff, "damage_dealt", "bypass_target_barriers", {});
            break;
        case "sand-force":
            __ability_effect_add_group(_eff, "weather_type_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "weather_type_multiplier", { weather:["sandstorm"], types:["rock","ground","steel"], mult:1.3 });
            break;
        case "grass-pelt":
            __ability_effect_add_group(_eff, "terrain_stat_multiplier");
            __ability_effect_add_action(_eff, "stat_calc", "terrain_defense_multiplier", { terrain:["grassy"], mult:1.5 });
            break;
        case "parental-bond":
            __ability_effect_add_group(_eff, "extra_hit_modifier");
            __ability_effect_add_action(_eff, "after_damage", "second_parental_hit", { second_hit_mult:0.25 });
            break;
        case "wimp-out":
        case "emergency-exit":
            __ability_effect_add_group(_eff, "hp_threshold_switch");
            __ability_effect_add_action(_eff, "after_damage_taken", "force_switch_below_hp_fraction", { hp_fraction:0.5 });
            break;
        case "surge-surfer":
            __ability_effect_add_group(_eff, "terrain_speed_multiplier");
            __ability_effect_add_action(_eff, "speed_calc", "terrain_speed_multiplier", { terrain:["electric"], mult:2 });
            break;
        case "disguise":
        case "decoy":
            __ability_effect_add_group(_eff, "first_hit_guard");
            __ability_effect_add_action(_eff, "before_damage_apply", "block_first_hit", {});
            break;
        case "battle-bond":
            __ability_effect_add_group(_eff, "ko_form_change");
            __ability_effect_add_action(_eff, "after_faint_caused", "conditional_form_change", {});
            break;
        case "innards-out":
            __ability_effect_add_group(_eff, "faint_damage_reflect");
            __ability_effect_add_action(_eff, "on_faint", "damage_attacker_equal_last_damage", {});
            break;
        case "punk-rock":
            __ability_effect_add_group(_eff, "sound_move_damage_modifier");
            __ability_effect_add_action(_eff, "damage_dealt", "sound_move_multiplier", { mult:1.3 });
            __ability_effect_add_action(_eff, "damage_taken", "sound_move_multiplier", { mult:0.5 });
            break;
        case "screen-cleaner":
            __ability_effect_add_group(_eff, "entry_field_clear");
            __ability_effect_add_action(_eff, "on_entry", "clear_screens", {});
            break;
        case "gorilla-tactics":
            __ability_effect_add_group(_eff, "choice_lock_stat_boost");
            __ability_effect_add_action(_eff, "stat_calc", "attack_multiplier_and_choice_lock", { mult:1.5 });
            break;
        case "quick-draw":
            __ability_effect_add_group(_eff, "turn_order_chance");
            __ability_effect_add_action(_eff, "priority_calc", "move_first_chance", { chance:30 });
            break;
        case "cud-chew":
            __ability_effect_add_group(_eff, "berry_reuse");
            __ability_effect_add_action(_eff, "after_item_consumed", "reuse_berry_next_turn", {});
            break;
        case "sharpness":
            __ability_effect_add_group(_eff, "move_tag_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "flag_multiplier", { flag:"slicing", mult:1.5 });
            break;
        case "mountaineer":
            __ability_effect_add_group(_eff, "type_immunity");
            __ability_effect_add_action(_eff, "on_defend_type", "block_type", { type:"rock" });
            __ability_effect_add_type_block(_eff, "rock");
            break;
        case "wave-rider":
            __ability_effect_add_group(_eff, "terrain_or_field_speed_multiplier");
            __ability_effect_add_action(_eff, "speed_calc", "field_speed_multiplier", { field:["water"], mult:2 });
            break;
        case "skater":
            __ability_effect_add_group(_eff, "terrain_or_field_speed_multiplier");
            __ability_effect_add_action(_eff, "speed_calc", "field_speed_multiplier", { field:["ice"], mult:2 });
            break;
        case "thrust":
            __ability_effect_add_group(_eff, "move_tag_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "flag_multiplier", { flag:"charge", mult:1.2 });
            break;
        case "perception":
        case "instinct":
        case "dodge":
            __ability_effect_add_group(_eff, "accuracy_evasion_custom");
            __ability_effect_add_action(_eff, "accuracy_check", "custom_accuracy_or_evasion_rule", {});
            break;
        case "parry":
        case "jagged-edge":
            __ability_effect_add_group(_eff, "contact_punish_damage");
            __ability_effect_add_action(_eff, "after_contact_taken", "damage_attacker_fraction", { fraction:0.125 });
            break;
        case "frostbite":
            __ability_effect_add_group(_eff, "contact_punish_status");
            __ability_effect_add_action(_eff, "after_contact_taken", "status_attacker_chance", { status:"freeze", chance:30 });
            break;
        case "tenacity":
        case "pride":
        case "confidence":
            __ability_effect_add_group(_eff, "morale_stage_modifier");
            __ability_effect_add_action(_eff, "stage_event_check", "morale_stage_rule", {});
            break;
        case "deep-sleep":
        case "power-nap":
            __ability_effect_add_group(_eff, "sleep_heal_or_power");
            __ability_effect_add_action(_eff, "status_tick", "sleep_custom_rule", {});
            break;
        case "spirit":
        case "hero":
        case "last-bastion":
        case "vanguard":
            __ability_effect_add_group(_eff, "team_state_damage_modifier");
            __ability_effect_add_action(_eff, "damage_dealt", "team_state_multiplier", {});
            break;
        case "warm-blanket":
            __ability_effect_add_group(_eff, "status_immunity");
            __ability_effect_add_action(_eff, "status_apply", "block_status", { status:"freeze" });
            __ability_effect_add_status_immunity(_eff, "freeze");
            break;
        case "gulp":
        case "lunchbox":
            __ability_effect_add_group(_eff, "food_item_modifier");
            __ability_effect_add_action(_eff, "item_check", "food_item_rule", {});
            break;
        case "herbivore":
            __ability_effect_add_group(_eff, "type_absorb_stage");
            __ability_effect_add_action(_eff, "on_defend_type", "block_stage_boost", { type:"grass", stat:"atk", delta:1 });
            __ability_effect_add_stage_boost(_eff, "grass", "atk", 1);
            break;
        case "sandpit":
            __ability_effect_add_group(_eff, "trapping");
            __ability_effect_add_action(_eff, "switch_check", "trap_grounded_opponents", {});
            break;
        case "hot-blooded":
        case "flame-boost":
            __ability_effect_add_group(_eff, "type_damage_dealt_multiplier");
            __ability_effect_add_action(_eff, "damage_dealt", "type_multiplier", { type:"fire", mult:1.2 });
            break;
        case "aqua-boost":
            __ability_effect_add_group(_eff, "type_damage_dealt_multiplier");
            __ability_effect_add_action(_eff, "damage_dealt", "type_multiplier", { type:"water", mult:1.2 });
            break;
        case "life-force":
            __ability_effect_add_group(_eff, "hp_stat_or_heal_modifier");
            __ability_effect_add_action(_eff, "stat_calc", "hp_or_heal_custom_rule", {});
            break;
        case "melee":
            __ability_effect_add_group(_eff, "contact_damage_boost");
            __ability_effect_add_action(_eff, "damage_dealt", "contact_multiplier", { mult:1.2 });
            break;
        case "sponge":
            __ability_effect_add_group(_eff, "type_damage_taken_multiplier");
            __ability_effect_add_action(_eff, "damage_taken", "type_multiplier", { type:"water", mult:0.5 });
            __ability_effect_add_taken_multiplier(_eff, "water", 0.5);
            break;
        case "bodyguard":
        case "shield":
            __ability_effect_add_group(_eff, "ally_guard");
            __ability_effect_add_action(_eff, "ally_check", "redirect_or_reduce_ally_damage", {});
            break;
        case "stealth":
        case "shadow-dash":
        case "sprint":
            __ability_effect_add_group(_eff, "escape_or_speed_modifier");
            __ability_effect_add_action(_eff, "speed_calc", "custom_speed_or_escape_rule", {});
            break;
        case "nomad":
        case "high-rise":
        case "climber":
            __ability_effect_add_group(_eff, "overworld_movement_modifier");
            __ability_effect_add_action(_eff, "overworld_move_check", "custom_movement_rule", {});
            break;
        case "sequence":
        case "run-up":
        case "conqueror":
            __ability_effect_add_group(_eff, "consecutive_action_modifier");
            __ability_effect_add_action(_eff, "turn_check", "consecutive_action_rule", {});
            break;
        case "grass-cloak":
            __ability_effect_add_group(_eff, "terrain_evasion_modifier");
            __ability_effect_add_action(_eff, "accuracy_check", "terrain_evasion_multiplier", { terrain:["grassy"], opponent_accuracy_mult:0.8 });
            break;
        case "celebrate":
        case "lullaby":
        case "calming":
        case "daze":
        case "frighten":
        case "interference":
        case "mood-maker":
            __ability_effect_add_group(_eff, "entry_or_aura_status_modifier");
            __ability_effect_add_action(_eff, "on_entry", "custom_status_or_morale_rule", {});
            break;
        case "fortune":
        case "bonanza":
        case "share":
            __ability_effect_add_group(_eff, "reward_modifier");
            __ability_effect_add_action(_eff, "post_battle", "custom_reward_rule", {});
            break;
        case "explode":
            __ability_effect_add_group(_eff, "faint_explosion");
            __ability_effect_add_action(_eff, "on_faint", "explode_on_faint", {});
            break;
        case "omnipotent":
            __ability_effect_add_group(_eff, "special_rule");
            __ability_effect_add_action(_eff, "special_rule_check", "omnipotent_rule", {});
            break;
        case "black-hole":
            __ability_effect_add_group(_eff, "trapping");
            __ability_effect_add_group(_eff, "field_damage_modifier");
            __ability_effect_add_action(_eff, "field_check", "black_hole_rule", {});
            break;
        case "disgust":
            __ability_effect_add_group(_eff, "entry_or_contact_debuff");
            __ability_effect_add_action(_eff, "on_entry", "custom_debuff_rule", {});
            break;
        case "shackle":
            __ability_effect_add_group(_eff, "trapping");
            __ability_effect_add_action(_eff, "switch_check", "trap_opponents", {});
            break;
        case "clear-body":
            __ability_effect_add_group(_eff, "stat_lowering_immunity");
            __ability_effect_add_action(_eff, "stage_change", "block_stat_lowering", { stats:"all" });
            _eff.blocks_stat_lowering = true;
            break;
        case "white-smoke":
            __ability_effect_add_group(_eff, "stat_lowering_immunity");
            __ability_effect_add_action(_eff, "stage_change", "block_stat_lowering", { stats:"all" });
            _eff.blocks_stat_lowering = true;
            break;
        case "full-metal-body":
            __ability_effect_add_group(_eff, "stat_lowering_immunity");
            __ability_effect_add_action(_eff, "stage_change", "block_stat_lowering", { stats:"all" });
            _eff.blocks_stat_lowering = true;
            break;
        case "hyper-cutter":
            __ability_effect_add_group(_eff, "stat_lowering_immunity");
            __ability_effect_add_action(_eff, "stage_change", "block_stat_lowering", { stats:["atk"] });
            _eff.blocks_attack_lowering = true;
            break;
        default: break;
    }
    return _eff;
}

function data_load_ability_effects_structs(){
    var _max_id = 0;
    if (variable_global_exists("_abilities") && is_array(global._abilities)){
        _max_id = array_length(global._abilities) - 1;
    }
    global._ability_effects = [];
    array_resize(global._ability_effects, max(1, _max_id + 1));

    var _name_by_id = [];
    var _name_path = working_directory + "/data/csv/ability_names.csv";
    var _ng = load_csv(_name_path);
    if (_ng != -1){
        var _ci_name_ability = __col_find_ci(_ng, "ability_id");
        var _ci_name_lang = __col_find_ci(_ng, "local_language_id");
        if (_ci_name_lang < 0) _ci_name_lang = __col_find_ci(_ng, "language_id");
        var _ci_name = __col_find_ci(_ng, "name");
        if (_ci_name_ability >= 0 && _ci_name_lang >= 0 && _ci_name >= 0){
            var _NH = ds_grid_height(_ng);
            for (var _nr = 1; _nr < _NH; ++_nr){
                if (__to_int_safe(__grid(_ng, _ci_name_lang, _nr, 0), 0) != 9) continue;
                var _naid = __to_int_safe(__grid(_ng, _ci_name_ability, _nr, 0), 0);
                if (_naid > 0) _name_by_id[_naid] = __text_clean_spaces(__grid(_ng, _ci_name, _nr, ""));
            }
        }
    }

    var _short_by_id = [];
    var _effect_by_id = [];
    var _prose_path = working_directory + "/data/csv/ability_prose.csv";
    var _pg = load_csv(_prose_path);
    if (_pg != -1){
        var _ci_ab = __col_find_ci(_pg, "ability_id");
        var _ci_lang = __col_find_ci(_pg, "local_language_id");
        if (_ci_lang < 0) _ci_lang = __col_find_ci(_pg, "language_id");
        var _ci_short = __col_find_ci(_pg, "short_effect");
        var _ci_effect = __col_find_ci(_pg, "effect");
        if (_ci_ab >= 0 && _ci_lang >= 0){
            var _PH = ds_grid_height(_pg);
            for (var _pr = 1; _pr < _PH; ++_pr){
                if (__to_int_safe(__grid(_pg, _ci_lang, _pr, 0), 0) != 9) continue;
                var _paid = __to_int_safe(__grid(_pg, _ci_ab, _pr, 0), 0);
                if (_paid <= 0) continue;
                if (_ci_short >= 0) _short_by_id[_paid] = __text_clean_spaces(__grid(_pg, _ci_short, _pr, ""));
                if (_ci_effect >= 0) _effect_by_id[_paid] = __text_clean_spaces(__grid(_pg, _ci_effect, _pr, ""));
            }
        }
    }

    var _rows = 0;
    for (var _aid = 1; _aid <= _max_id; ++_aid){
        var _ab = global._abilities[_aid];
        if (!is_struct(_ab)) continue;
        var _ident = variable_struct_exists(_ab, "identifier") ? string(variable_struct_get(_ab, "identifier")) : "";
        var _name_src = (_aid < array_length(_name_by_id)) ? _name_by_id[_aid] : undefined;
        var _short_src = (_aid < array_length(_short_by_id)) ? _short_by_id[_aid] : undefined;
        var _effect_src = (_aid < array_length(_effect_by_id)) ? _effect_by_id[_aid] : undefined;
        var _name = (is_string(_name_src) ? _name_src : string_replace_all(_ident, "-", " "));
        var _short = (is_string(_short_src) ? _short_src : "");
        var _effect = (is_string(_effect_src) ? _effect_src : "");
        var _eff = {
            id:_aid,
            identifier:_ident,
            name:_name,
            short_effect:_short,
            effect:_effect,
            entry_weather:"",
            entry_stage_opponents:[],
            blocked_types:[],
            absorb_heal_types:[],
            block_stage_boosts:[],
            flash_fire:false,
            low_hp_type:"",
            low_hp_multiplier:1,
            damage_taken_multipliers:[],
            attack_stat_multiplier:1,
            attack_status_multiplier:1,
            defense_status_multiplier:1,
            status_immunities:[],
            groups:[],
            actions:[],
            blocks_stat_lowering:false,
            blocks_attack_lowering:false,
            crit_immunity:false,
            no_guard:false,
            soundproof:false,
            sturdy:false,
            flinch_bonus_chance:0
        };
        global._ability_effects[_aid] = __ability_effect_apply_known_tags(_eff);
        if (variable_global_exists("_ability_text") && is_array(global._ability_text)){
            if (_aid < array_length(global._ability_text) && is_struct(global._ability_text[_aid])){
                global._ability_text[_aid].name = _name;
                if (string_length(_short) > 0) global._ability_text[_aid].short_desc = _short;
                if (string_length(_effect) > 0) global._ability_text[_aid].effect = _effect;
            }
        }
        _rows++;
    }
    global._ability_groups = {};
    for (var _gi = 1; _gi < array_length(global._ability_effects); ++_gi){
        var _geff = global._ability_effects[_gi];
        if (!is_struct(_geff) || !variable_struct_exists(_geff, "groups") || !is_array(variable_struct_get(_geff, "groups"))) continue;
        var _groups = variable_struct_get(_geff, "groups");
        for (var _gii = 0; _gii < array_length(_groups); ++_gii){
            var _gid = string_lower(string(_groups[_gii]));
            if (string_length(_gid) <= 0) continue;
            var _garr = [];
            if (variable_struct_exists(global._ability_groups, _gid) && is_array(variable_struct_get(global._ability_groups, _gid))) _garr = variable_struct_get(global._ability_groups, _gid);
            _garr = __ability_effect_push_unique(_garr, _gi);
            variable_struct_set(global._ability_groups, _gid, _garr);
        }
    }
    data_debug("[DATA][ability_effects] rows=" + string(_rows) + " groups=" + string(array_length(variable_struct_get_names(global._ability_groups))) + " source=abilities/ability_names/ability_prose");
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

function data_load_species_gender_rates_structs(){
    var path = working_directory + "/data/csv/pokemon_species.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][pokemon_species_gender] SKIP: " + path); global._species_gender_rates = []; global._species_capture_rates = []; global._species_base_happiness = []; return; }
    var H = ds_grid_height(g);
    var ci_sid = __col_find_ci(g, "id");
    var ci_gender = __col_find_ci(g, "gender_rate");
    var ci_capture = __col_find_ci(g, "capture_rate");
    var ci_happiness = __col_find_ci(g, "base_happiness");
    if (ci_sid < 0 || ci_gender < 0){
        data_debug("[DATA][pokemon_species_gender] ERROR: missing id/gender_rate columns");
        global._species_gender_rates = [];
        global._species_capture_rates = [];
        global._species_base_happiness = [];
        return;
    }

    var max_sid = 0;
    for (var _r = 1; _r < H; ++_r){
        var _sid = __to_int_safe(__grid(g, ci_sid, _r, 0), 0);
        if (_sid > max_sid) max_sid = _sid;
    }

    global._species_gender_rates = [];
    array_resize(global._species_gender_rates, max_sid + 1);
    global._species_capture_rates = [];
    array_resize(global._species_capture_rates, max_sid + 1);
    global._species_base_happiness = [];
    array_resize(global._species_base_happiness, max_sid + 1);
    var rows = 0;
    for (var _r2 = 1; _r2 < H; ++_r2){
        var _sid2 = __to_int_safe(__grid(g, ci_sid, _r2, 0), 0);
        if (_sid2 <= 0) continue;
        global._species_gender_rates[_sid2] = __to_int_safe(__grid(g, ci_gender, _r2, -1), -1);
        global._species_capture_rates[_sid2] = (ci_capture >= 0) ? __to_int_safe(__grid(g, ci_capture, _r2, 45), 45) : 45;
        global._species_base_happiness[_sid2] = (ci_happiness >= 0) ? __to_int_safe(__grid(g, ci_happiness, _r2, 70), 70) : 70;
        rows += 1;
    }
    data_debug("[DATA][pokemon_species_gender] rows=" + string(rows) + ", capture_rates=" + string(ci_capture >= 0));
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @function data_load_species_moves_structs()
/// @description Loads Pokémon move data from JSON and builds per-species move arrays
function data_load_species_moves_structs() {
    var path = working_directory + "/data/json/_pokemon_moves";

    if (!file_exists(path)) {
        data_debug("[DATA][pokemon_moves] SKIP: " + path);
        global._species_moves = [];
        return;
    }

    var _file = file_text_open_read(path);
    var _txt_json = file_text_read_string(_file);
    file_text_close(_file);

    // --- Parse JSON into array of structs ---
    var json_data = json_parse(_txt_json);
    if (!is_array(json_data)) {
        data_debug("[DATA][pokemon_moves] INVALID JSON: " + path);
        global._species_moves = [];
        return;
    }

    // --- Prepare data ---
    var total_rows = array_length(json_data);
    global._species_moves = [];
    var local_species_moves = global._species_moves;

    var max_sid = 0;
    var max_mid = 0;

    // --- Iterate rows ---
    for (var i = 0; i < total_rows; i++) {
        var row = json_data[i];

        var _sid = real(row.pokemon_id);
        var _mid = real(row.move_id);
        var _mth = real(row.pokemon_move_method_id);
        var _lvl = real(row.level);

        // skip invalid or unwanted rows
        if (_sid <= 0 || _mid <= 0 || _mth != 1)
            continue;

        // ensure array slot for species exists
        if (_sid >= array_length(local_species_moves)) {
            var old_len = array_length(local_species_moves);
            array_resize(local_species_moves, _sid + 1);
            for (var j = old_len; j <= _sid; j++) {
                local_species_moves[j] = [];
            }
        }

        // append this move
        var spec_arr = local_species_moves[_sid];
        spec_arr[array_length(spec_arr)] = { lvl: _lvl, mid: _mid };

        if (_sid > max_sid) max_sid = _sid;
        if (_mid > max_mid) max_mid = _mid;
    }

    // --- Deduplicate and sort ---
    var non_empty_species = 0;
    var scratch_stamp = array_create(max_mid + 1);
    var scratch_lvl = array_create(max_mid + 1);
    var curr_stamp = 1;

    for (var sid_i = 0; sid_i <= max_sid; sid_i++) {
        var arr = local_species_moves[sid_i];
        if (is_undefined(arr)) continue;

        var len = array_length(arr);
        if (len == 0) continue;

        var mids_seen = [];

        // dedupe by lowest lvl per move
        for (var k = 0; k < len; k++) {
            var e = arr[k];
            var mid = e.mid;
            var lvl = e.lvl;

            if (mid < 0 || mid > max_mid)
                continue;

            if (scratch_stamp[mid] != curr_stamp) {
                scratch_stamp[mid] = curr_stamp;
                scratch_lvl[mid] = lvl;
                array_push(mids_seen, mid);
            } else if (lvl < scratch_lvl[mid]) {
                scratch_lvl[mid] = lvl;
            }
        }

        // rebuild deduped array
        var out = [];
        for (var mi = 0; mi < array_length(mids_seen); mi++) {
            var mid = mids_seen[mi];
            array_push(out, { lvl: scratch_lvl[mid], mid: mid });
        }

        // sort by lvl ascending
        var plen = array_length(out);
        if (plen > 1) {
            for (var ii = 1; ii < plen; ii++) {
                var key = out[ii];
                var jj = ii - 1;
                while (jj >= 0 && out[jj].lvl > key.lvl) {
                    out[jj + 1] = out[jj];
                    jj -= 1;
                }
                out[jj + 1] = key;
            }
        }

        local_species_moves[sid_i] = out;
        non_empty_species++;
        curr_stamp++;

        if (curr_stamp == 2147483647) {
            scratch_stamp = array_create(max_mid + 1);
            curr_stamp = 1;
        }
    }

    data_debug(
        "[DATA][pokemon_moves] rows=" + string(total_rows)
        + ", species=" + string(non_empty_species)
    );
}

function data_load_machine_moves_structs(){
    global._machine_item_to_move = [];
    global._machine_item_to_version = [];
    global._species_machine_moves = [];

    var machine_path = working_directory + "/data/csv/machines.csv";
    var machine_grid = load_csv(machine_path);
    if (machine_grid != -1){
        var mh = ds_grid_height(machine_grid);
        var machine_rows = 0;
        for (var mr = 1; mr < mh; mr++){
            var version_group_id = __to_int_safe(__grid(machine_grid, 1, mr, 0), 0);
            var item_id = __to_int_safe(__grid(machine_grid, 2, mr, 0), 0);
            var move_id = __to_int_safe(__grid(machine_grid, 3, mr, 0), 0);
            if (item_id <= 0 || move_id <= 0) continue;
            if (item_id >= array_length(global._machine_item_to_move)) array_resize(global._machine_item_to_move, item_id + 1);
            if (item_id >= array_length(global._machine_item_to_version)) array_resize(global._machine_item_to_version, item_id + 1);
            var existing_version = global._machine_item_to_version[item_id];
            var should_take = (!is_real(global._machine_item_to_move[item_id]) || global._machine_item_to_move[item_id] <= 0);
            if (version_group_id == 6) should_take = true;
            else if (is_real(existing_version) && existing_version == 6) should_take = false;
            if (should_take){
                if (!is_real(global._machine_item_to_move[item_id]) || global._machine_item_to_move[item_id] <= 0) machine_rows++;
                global._machine_item_to_move[item_id] = move_id;
                global._machine_item_to_version[item_id] = version_group_id;
            }
        }
        data_debug("[DATA][machines] items=" + string(machine_rows));
    } else {
        data_debug("[DATA][machines] SKIP: " + machine_path);
    }

    var pm_path = working_directory + "/data/csv/pokemon_moves.csv";
    var pm_grid = load_csv(pm_path);
    if (pm_grid == -1){
        data_debug("[DATA][machine_compat] SKIP: " + pm_path);
        return;
    }

    var ph = ds_grid_height(pm_grid);
    var compat_rows = 0;
    for (var pr = 1; pr < ph; pr++){
        var species_id = __to_int_safe(__grid(pm_grid, 0, pr, 0), 0);
        var tm_move_id = __to_int_safe(__grid(pm_grid, 2, pr, 0), 0);
        var method_id = __to_int_safe(__grid(pm_grid, 3, pr, 0), 0);
        if (species_id <= 0 || tm_move_id <= 0 || method_id != 4) continue;
        if (species_id >= array_length(global._species_machine_moves)) array_resize(global._species_machine_moves, species_id + 1);
        var arr = global._species_machine_moves[species_id];
        if (!is_array(arr)) arr = [];
        var found = false;
        for (var ai = 0; ai < array_length(arr); ai++){
            if (arr[ai] == tm_move_id){ found = true; break; }
        }
        if (!found){
            array_push(arr, tm_move_id);
            global._species_machine_moves[species_id] = arr;
            compat_rows++;
        }
    }
    data_debug("[DATA][machine_compat] rows=" + string(compat_rows));
}

function data_load_all_structs_ext(){
    // Guard: avoid running extended CSV loads more than once per process.
    if (variable_global_exists("_data_structs_ext_loaded") && global._data_structs_ext_loaded){
        data_debug("[DATA][structs_ext] already_loaded -> skipping");
        return;
    }
    data_load_moves_structs();
    data_load_move_text_structs();       // UPDATED to PokeAPI flavor text
    data_load_abilities_structs();
    data_load_ability_text_structs();    // UPDATED to PokeAPI flavor text
    data_load_ability_effects_structs(); // CSV-derived structured ability tags
    data_load_species_abilities_structs();
    data_load_species_gender_rates_structs();
    data_load_species_moves_structs();
    // Types: load core type list and per-species mappings
    if (is_undefined(data_load_types_structs) == false) data_load_types_structs();
    // Optional: per-species flavor text/prose (pokemon_species_flavor_text.csv / pokemon_species_flavor_summaries.csv)
    if (is_undefined(data_load_species_flavor_text_structs) == false) data_load_species_flavor_text_structs();
    // Growth rates table + Experience
    data_load_growth_rates_structs();
    data_load_experience_structs();
    data_load_evolution_triggers_structs();
    data_load_pokemon_evolution_structs();
    // Items + item categories
    data_load_items_structs();
    data_load_item_names_structs();
    data_load_item_text_structs();
    data_load_item_categorys_structs();
    data_load_machine_moves_structs();
    // Item flags: map + prose
    // Ensure prose table loads first so map normalization can resolve numeric codes
    data_load_item_flag_prose_structs();
    data_load_item_flag_map_structs();
    // Normalize numeric flag ids into textual keys (best-effort)
    data_normalize_item_flag_map();
    // Item prose (human readable effects) and derived structured effects
    data_load_item_prose_structs();
    data_load_item_effects_structs();
    if (is_undefined(data_load_item_runtime_structs) == false) data_load_item_runtime_structs();
    data_debug("[DATA][structs_ext] done.");
    // Load optional move meta mapping (ailments + chances) for battle wiring
    if (is_undefined(data_load_move_meta_structs) == false) data_load_move_meta_structs();
    // Load optional move stat changes mapping (temporary in-battle stat stage changes)
    if (is_undefined(data_load_move_meta_stat_changes_structs) == false) data_load_move_meta_stat_changes_structs();
    // Synthesize move_meta entries from moves.effect_id where possible so the battle
    // system can rely on global._move_meta for recoil/drain/multi-hit effects.
    if (is_undefined(data_map_move_effects_to_meta) == false) data_map_move_effects_to_meta();
    if (is_undefined(data_map_late_moves_to_meta) == false) data_map_late_moves_to_meta();
    // Mark ext loader as completed
    global._data_structs_ext_loaded = true;
}

// Optional: parse move_meta_stat_changes.csv -> attach to global._move_meta[move_id].stat_changes
function data_load_move_meta_stat_changes_structs(){
    var path = working_directory + "/data/csv/move_meta_stat_changes.csv";
    var g = load_csv(path);
    if (g == -1){ data_debug("[DATA][move_meta_stat_changes] SKIP: " + path); return; }
    data_debug("[DATA][move_meta_stat_changes] LOADED: " + path);
    var H = ds_grid_height(g);
    var ci_move = __col_find_ci(g, "move_id");
    var ci_stat = __col_find_ci(g, "stat_id");
    var ci_change = __col_find_ci(g, "change");
    if (ci_move < 0 || ci_stat < 0 || ci_change < 0){ data_debug("[DATA][move_meta_stat_changes] ERROR: missing required columns"); return; }

    var rows = 0;
    for (var r = 1; r < H; r++){
        var mid = __to_int_safe(__grid(g, ci_move, r, 0), 0);
        var sid = __to_int_safe(__grid(g, ci_stat, r, 0), 0);
        var ch  = __to_int_safe(__grid(g, ci_change, r, 0), 0);
        if (mid <= 0 || sid == 0) continue;
        if (is_undefined(global._move_meta) || !is_array(global._move_meta)){
            // if move_meta not present, create a placeholder mapping
            if (is_undefined(global._move_meta)) global._move_meta = [];
            if (!is_array(global._move_meta)) global._move_meta = [];
        }
        if (mid >= array_length(global._move_meta)) array_resize(global._move_meta, mid+1);
        if (is_undefined(global._move_meta[mid]) || !is_struct(global._move_meta[mid])) global._move_meta[mid] = {};
        // Ensure stat_changes is present and an array using safe struct accessors
        if (!variable_struct_exists(global._move_meta[mid], "stat_changes") || !is_array(variable_struct_get(global._move_meta[mid], "stat_changes"))) {
            variable_struct_set(global._move_meta[mid], "stat_changes", []);
        }
        var _sc_arr = variable_struct_get(global._move_meta[mid], "stat_changes");
        array_push(_sc_arr, { stat_id: sid, change: ch });
        // write back in case the runtime requires explicit set (generally not needed but safe)
        variable_struct_set(global._move_meta[mid], "stat_changes", _sc_arr);
        rows += 1;
    }
    data_debug("[DATA][move_meta_stat_changes] mapped rows=" + string(rows));
}

// Optional: build a compact move meta mapping used by the battle system to apply
// simple status inflictions. Produces global._move_meta where each key/index is
// move_id -> { status: "brn", chance: 30, duration: 3 }
function data_load_move_meta_structs(){
    var path = working_directory + "/data/csv/move_meta.csv";
    var g = load_csv(path);
    if (g == -1){ data_debug("[DATA][move_meta] SKIP: " + path); global._move_meta = []; return; }
    data_debug("[DATA][move_meta] LOADED: " + path);
    var H = ds_grid_height(g);
    var ci_move = __col_find_ci(g, "move_id");
    var ci_ail = __col_find_ci(g, "meta_ailment_id");
    var ci_meta_cat = __col_find_ci(g, "meta_category_id");
    var ci_min_turns = __col_find_ci(g, "min_turns");
    var ci_max_turns = __col_find_ci(g, "max_turns");
    var ci_min_hits = __col_find_ci(g, "min_hits");
    var ci_max_hits = __col_find_ci(g, "max_hits");
    var ci_ail_chance = __col_find_ci(g, "ailment_chance");
    var ci_drain = __col_find_ci(g, "drain");
    var ci_healing = __col_find_ci(g, "healing");
    var ci_weather = __col_find_ci(g, "weather");
    var ci_weather_dur = __col_find_ci(g, "weather_duration");
    if (ci_move < 0 || ci_ail < 0){ data_debug("[DATA][move_meta] ERROR: missing required columns"); global._move_meta = []; return; }

    // load ailment id -> identifier map from move_meta_ailments.csv for readable ids
    var ail_map = {};
    var path2 = working_directory + "/data/csv/move_meta_ailments.csv";
    var g2 = load_csv(path2);
    if (g2 != -1){
        var H2 = ds_grid_height(g2);
        var c_id = __col_find_ci(g2, "id");
        var c_ident = __col_find_ci(g2, "identifier");
        if (c_id >= 0 && c_ident >= 0){
            for (var r2 = 1; r2 < H2; r2++){
                var aid = __to_int_safe(__grid(g2, c_id, r2, 0), 0);
                var ident = string_trim(string(__grid(g2, c_ident, r2, "")));
                if (aid > 0 && string_length(ident) > 0) ail_map[""+string(aid)] = ident;
            }
        }
    }

    // Build mapping
    var max_mid = 0;
    for (var r = 1; r < H; r++){ var mid = __to_int_safe(__grid(g, ci_move, r, 0), 0); if (mid > max_mid) max_mid = mid; }
    global._move_meta = []; array_resize(global._move_meta, max_mid + 1);
    var rows = 0;
    for (var r3 = 1; r3 < H; r3++){
        var mid3 = __to_int_safe(__grid(g, ci_move, r3, 0), 0);
        if (mid3 <= 0) continue;
    var aid3 = __to_int_safe(__grid(g, ci_ail, r3, 0), 0);
    var meta_cat = (ci_meta_cat >= 0) ? __to_int_safe(__grid(g, ci_meta_cat, r3, 0), 0) : 0;
    // allow rows that only define drain/healing/meta info even if ailment id is 0
    var chance = (ci_ail_chance >= 0) ? __to_int_safe(__grid(g, ci_ail_chance, r3, 0), 0) : 100;
    var min_t = (ci_min_turns >= 0) ? __to_int_safe(__grid(g, ci_min_turns, r3, 0), -1) : -1;
    var max_t = (ci_max_turns >= 0) ? __to_int_safe(__grid(g, ci_max_turns, r3, 0), -1) : -1;
    var min_hits_val = (ci_min_hits >= 0) ? __to_int_safe(__grid(g, ci_min_hits, r3, 0), -1) : -1;
    var max_hits_val = (ci_max_hits >= 0) ? __to_int_safe(__grid(g, ci_max_hits, r3, 0), -1) : -1;
        var dur = -1;
        if (min_t > 0 && max_t > 0) dur = min_t; // choose min as default
        else if (min_t > 0) dur = min_t;
    // optional drain/healing fields (percent or absolute depending on CSV semantics)
    var drain_val = (ci_drain >= 0) ? __to_int_safe(__grid(g, ci_drain, r3, 0), 0) : 0;
    var healing_val = (ci_healing >= 0) ? __to_int_safe(__grid(g, ci_healing, r3, 0), 0) : 0;
    var weather_val = (ci_weather >= 0) ? string_trim(string(__grid(g, ci_weather, r3, ""))) : "";
    var weather_dur_val = (ci_weather_dur >= 0) ? __to_int_safe(__grid(g, ci_weather_dur, r3, 0), 0) : -1;
        // resolve ailment identifier if possible (may be empty for drain-only rows)
        var aid_key = "" + string(aid3);
        var status_ident = "";
        // Guard: ail_map should be a struct mapping string ids to identifiers.
        // If it's not a struct (or the key is missing), don't index it to avoid
        // array/negative-index runtime errors.
        if (is_struct(ail_map)){
            if (!is_undefined(ail_map[aid_key])) status_ident = ail_map[aid_key];
        } else {
            // unexpected shape; leave status_ident empty
            status_ident = "";
        }
        // Fallback: if mapping failed but aid3 is a known ailment id, map common ones here
        if (string_length(status_ident) == 0 && is_real(aid3) && aid3 > 0){
            var _fallback = {};
            variable_struct_set(_fallback, "1", "paralysis");
            variable_struct_set(_fallback, "2", "sleep");
            variable_struct_set(_fallback, "3", "freeze");
            variable_struct_set(_fallback, "4", "burn");
            variable_struct_set(_fallback, "5", "poison");
            variable_struct_set(_fallback, "6", "confusion");
            variable_struct_set(_fallback, "7", "infatuation");
            variable_struct_set(_fallback, "8", "trap");
            variable_struct_set(_fallback, "12", "torment");
            variable_struct_set(_fallback, "13", "disable");
            variable_struct_set(_fallback, "14", "yawn");
            variable_struct_set(_fallback, "15", "heal-block");
            variable_struct_set(_fallback, "18", "leech-seed");
            variable_struct_set(_fallback, "19", "embargo");
            variable_struct_set(_fallback, "20", "perish-song");
            variable_struct_set(_fallback, "21", "ingrain");
            variable_struct_set(_fallback, "24", "silence");
            var kf = "" + string(aid3);
            if (!is_undefined(variable_struct_get(_fallback, kf))) status_ident = variable_struct_get(_fallback, kf);
            else {
                // No known fallback - leave empty but record for debugging
                data_debug("[DATA][move_meta] no ail_map entry for id=" + string(aid3) + " move_id=" + string(mid3));
            }
        }
        // Always write a meta entry (even if status_ident is empty) so moves that only
        // define drain/healing are available to the battle system.
    var mmrec = { status: status_ident, chance: chance, duration: dur, drain: drain_val, healing: healing_val, meta_category: meta_cat };
    // Preserve original ailment id for later debugging/processing
    variable_struct_set(mmrec, "ailment_id", aid3);
    if (is_real(min_hits_val) && min_hits_val > 0) variable_struct_set(mmrec, "min_hits", min_hits_val);
    if (is_real(max_hits_val) && max_hits_val > 0) variable_struct_set(mmrec, "max_hits", max_hits_val);
    if (string_length(string(weather_val)) > 0) variable_struct_set(mmrec, "weather", string(weather_val));
    if (is_real(weather_dur_val) && weather_dur_val > 0) variable_struct_set(mmrec, "weather_duration", weather_dur_val);
    global._move_meta[mid3] = mmrec;
        rows += 1;
    }
    data_debug("[DATA][move_meta] mapped rows=" + string(rows));
}

// ---------- DATA: types + pokemon_types.csv -> global._types, global._species_types
function data_load_types_structs(){
    var path = working_directory + "/data/csv/types.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][types] SKIP: " + path); global._types = []; }
    else {
        var H = ds_grid_height(g);
        var ci_id = __col_find_ci(g, "id");
        var ci_ident = __col_find_ci(g, "identifier");
        if (ci_id < 0) ci_id = 0;
        if (ci_ident < 0) ci_ident = 1;
        var max_id = 0;
        for (var r = 1; r < H; r++){
            var tid = __to_int_safe(__grid(g, ci_id, r, 0), 0);
            if (tid > max_id) max_id = tid;
        }
        global._types = []; array_resize(global._types, max_id + 1);
        var rows = 0;
        for (var r2 = 1; r2 < H; r2++){
            var idv = __to_int_safe(__grid(g, ci_id, r2, 0), 0);
            if (idv <= 0) continue;
            var ident = string_trim(string(__grid(g, ci_ident, r2, "")));
            var display = (string_length(ident) > 0) ? string_upper(string_copy(ident,1,1)) + string_delete(ident,1,1) : ident;
            global._types[idv] = { id: idv, identifier: ident, name: display };
            rows++;
        }
        data_debug("[DATA][types] loaded rows=" + string(rows));
    }

    var epath = working_directory + "/data/csv/type_efficacy.csv";
    var ge = load_csv(epath);
    global._type_efficacy = [];
    if (ge != -1){
        var He = ds_grid_height(ge);
        var ci_damage_type = __col_find_ci(ge, "damage_type_id"); if (ci_damage_type < 0) ci_damage_type = 0;
        var ci_target_type = __col_find_ci(ge, "target_type_id"); if (ci_target_type < 0) ci_target_type = 1;
        var ci_factor = __col_find_ci(ge, "damage_factor"); if (ci_factor < 0) ci_factor = 2;
        var erows = 0;
        for (var re = 1; re < He; ++re){
            var atk_tid = __to_int_safe(__grid(ge, ci_damage_type, re, 0), 0);
            var def_tid = __to_int_safe(__grid(ge, ci_target_type, re, 0), 0);
            var factor = __to_int_safe(__grid(ge, ci_factor, re, 100), 100);
            if (atk_tid <= 0 || def_tid <= 0) continue;
            array_push(global._type_efficacy, { attack_type:atk_tid, target_type:def_tid, factor:factor, mult:factor / 100.0 });
            erows++;
        }
        data_debug("[DATA][type_efficacy] loaded rows=" + string(erows));
    } else {
        data_debug("[DATA][type_efficacy] SKIP: " + epath);
    }

    // Load per-species mapping
    var ppath = working_directory + "/data/csv/pokemon_types.csv";
    var g2 = load_csv(ppath);
    var species_types = [];
    if (g2 == -1) {
        data_debug("[DATA][pokemon_types] SKIP: " + ppath);
        // also attempt pokemon_form_types.csv as fallback
        var fpath = working_directory + "/data/csv/pokemon_form_types.csv";
        var gf = load_csv(fpath);
        if (gf == -1) { data_debug("[DATA][pokemon_form_types] SKIP: " + fpath); global._species_types = []; return; }
        // parse form types into species_types by pokemon_id
        var Hf = ds_grid_height(gf);
        var ci_pidf = __col_find_ci(gf, "pokemon_id"); if (ci_pidf < 0) ci_pidf = __col_find_ci(gf, "pokemon_species_id"); if (ci_pidf < 0) ci_pidf = 0;
        var ci_typef = __col_find_ci(gf, "type_id"); if (ci_typef < 0) ci_typef = __col_find_ci(gf, "type"); if (ci_typef < 0) ci_typef = 1;
        var maxsidf = 0;
        for (var rr = 1; rr < Hf; rr++){ var sid = __to_int_safe(__grid(gf, ci_pidf, rr, 0), 0); if (sid > maxsidf) maxsidf = sid; }
        array_resize(species_types, maxsidf + 1);
        for (var r3 = 1; r3 < Hf; r3++){
            var sid2 = __to_int_safe(__grid(gf, ci_pidf, r3, 0), 0);
            var tid2 = __to_int_safe(__grid(gf, ci_typef, r3, 0), 0);
            if (sid2 <= 0) continue;
            if (!is_array(species_types[sid2])) species_types[sid2] = [];
            array_push(species_types[sid2], tid2);
        }
        global._species_types = species_types;
        data_debug("[DATA][pokemon_form_types] loaded species_count=" + string(array_length(global._species_types)));
        return;
    }

    // parse pokemon_types.csv
    var H2 = ds_grid_height(g2);
    var ci_pid = __col_find_ci(g2, "pokemon_id"); if (ci_pid < 0) ci_pid = __col_find_ci(g2, "pokemon_species_id"); if (ci_pid < 0) ci_pid = 0;
    var ci_type = __col_find_ci(g2, "type_id"); if (ci_type < 0) ci_type = __col_find_ci(g2, "type"); if (ci_type < 0) ci_type = 1;
    var maxsid = 0;
    for (var r4 = 1; r4 < H2; r4++){ var sid3 = __to_int_safe(__grid(g2, ci_pid, r4, 0), 0); if (sid3 > maxsid) maxsid = sid3; }
    array_resize(species_types, maxsid + 1);
    var rows2 = 0;
    for (var r5 = 1; r5 < H2; r5++){
        var sid4 = __to_int_safe(__grid(g2, ci_pid, r5, 0), 0);
        var tid3 = __to_int_safe(__grid(g2, ci_type, r5, 0), 0);
        if (sid4 <= 0) continue;
        if (!is_array(species_types[sid4])) species_types[sid4] = [];
        array_push(species_types[sid4], tid3);
        rows2++;
    }
    // Also attempt to merge pokemon_form_types.csv if present
    var fpath2 = working_directory + "/data/csv/pokemon_form_types.csv";
    var gf2 = load_csv(fpath2);
    if (gf2 != -1){
        var Hf2 = ds_grid_height(gf2);
        var ci_pid2 = __col_find_ci(gf2, "pokemon_id"); if (ci_pid2 < 0) ci_pid2 = __col_find_ci(gf2, "pokemon_species_id"); if (ci_pid2 < 0) ci_pid2 = 0;
        var ci_type2 = __col_find_ci(gf2, "type_id"); if (ci_type2 < 0) ci_type2 = __col_find_ci(gf2, "type"); if (ci_type2 < 0) ci_type2 = 1;
        for (var rf = 1; rf < Hf2; rf++){
            var sf = __to_int_safe(__grid(gf2, ci_pid2, rf, 0), 0);
            var tf = __to_int_safe(__grid(gf2, ci_type2, rf, 0), 0);
            if (sf <= 0) continue;
            if (sf >= array_length(species_types)) array_resize(species_types, sf+1);
            if (!is_array(species_types[sf])) species_types[sf] = [];
            array_push(species_types[sf], tf);
        }
    }

    global._species_types = species_types;
    data_debug("[DATA][pokemon_types] loaded rows=" + string(rows2) + " species_count=" + string(array_length(global._species_types)));
}

// ---------- DATA: growth_rates.csv -> global._growth_rates[growth_rate_id] = { id, identifier, name, description }
function data_load_growth_rates_structs(){
    var path = working_directory + "/data/csv/growth_rates.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][growth_rates] SKIP: " + path); global._growth_rates = []; return; }

    var H = ds_grid_height(g);
    var ci_id = __col_find_ci(g, "growth_rate_id");
    // Some CSVs use 'id' as the header instead of 'growth_rate_id' - accept that as a fallback.
    if (ci_id < 0) ci_id = __col_find_ci(g, "id");
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

// ===================== EVOLUTIONS (NEW) - 2026-05-09 =====================

function data_load_evolution_triggers_structs(){
    var path = working_directory + "/data/csv/evolution_triggers.csv";
    var g = load_csv(path);
    if (g == -1) { data_debug("[DATA][evolution_triggers] SKIP: " + path); global._evolution_triggers = []; return; }

    var H = ds_grid_height(g);
    var ci_id = __col_find_ci(g, "id");
    var ci_ident = __col_find_ci(g, "identifier");
    if (ci_id < 0 || ci_ident < 0){ data_debug("[DATA][evolution_triggers] ERROR: missing id/identifier columns"); global._evolution_triggers = []; return; }

    var max_id = 0;
    for (var r = 1; r < H; ++r){
        var _idv = __to_int_safe(__grid(g, ci_id, r, 0), 0);
        if (_idv > max_id) max_id = _idv;
    }

    global._evolution_triggers = [];
    array_resize(global._evolution_triggers, max_id + 1);
    var rows = 0;
    for (var r2 = 1; r2 < H; ++r2){
        var _id = __to_int_safe(__grid(g, ci_id, r2, 0), 0);
        if (_id <= 0) continue;
        var _ident = __s_trim(__grid(g, ci_ident, r2, ""));
        global._evolution_triggers[_id] = { id:_id, identifier:_ident };
        rows += 1;
    }
    data_debug("[DATA][evolution_triggers] rows=" + string(rows));
}

function data_load_pokemon_evolution_structs(){
    var path = working_directory + "/data/csv/pokemon_evolution.csv";
    var g = load_csv(path);
    if (g == -1) {
        data_debug("[DATA][pokemon_evolution] SKIP: " + path);
        global._pokemon_evolutions = [];
        global._pokemon_evolutions_by_species = [];
        return;
    }

    var H = ds_grid_height(g);
    var ci_source = __col_find_ci(g, "id");
    var ci_target = __col_find_ci(g, "evolved_species_id");
    var ci_trigger = __col_find_ci(g, "evolution_trigger_id");
    var ci_item = __col_find_ci(g, "trigger_item_id");
    var ci_level = __col_find_ci(g, "minimum_level");
    var ci_gender = __col_find_ci(g, "gender_id");
    var ci_location = __col_find_ci(g, "location_id");
    var ci_held = __col_find_ci(g, "held_item_id");
    var ci_time = __col_find_ci(g, "time_of_day");
    var ci_move = __col_find_ci(g, "known_move_id");
    var ci_move_type = __col_find_ci(g, "known_move_type_id");
    var ci_happy = __col_find_ci(g, "minimum_happiness");
    var ci_beauty = __col_find_ci(g, "minimum_beauty");
    var ci_affection = __col_find_ci(g, "minimum_affection");
    var ci_relative = __col_find_ci(g, "relative_physical_stats");
    var ci_party_species = __col_find_ci(g, "party_species_id");
    var ci_party_type = __col_find_ci(g, "party_type_id");
    var ci_trade_species = __col_find_ci(g, "trade_species_id");
    var ci_rain = __col_find_ci(g, "needs_overworld_rain");
    var ci_upside = __col_find_ci(g, "turn_upside_down");

    if (ci_source < 0 || ci_target < 0 || ci_trigger < 0){
        data_debug("[DATA][pokemon_evolution] ERROR: missing required columns");
        global._pokemon_evolutions = [];
        global._pokemon_evolutions_by_species = [];
        return;
    }

    var max_source = 0;
    for (var r = 1; r < H; ++r){
        var _src = __to_int_safe(__grid(g, ci_source, r, 0), 0);
        if (_src > max_source) max_source = _src;
    }

    global._pokemon_evolutions = [];
    global._pokemon_evolutions_by_species = [];
    array_resize(global._pokemon_evolutions_by_species, max_source + 1);
    for (var init_i = 0; init_i <= max_source; ++init_i) global._pokemon_evolutions_by_species[init_i] = [];

    var rows = 0;
    for (var r2 = 1; r2 < H; ++r2){
        var _source = __to_int_safe(__grid(g, ci_source, r2, 0), 0);
        var _target = __to_int_safe(__grid(g, ci_target, r2, 0), 0);
        var _trigger = __to_int_safe(__grid(g, ci_trigger, r2, 0), 0);
        if (_source <= 0 || _target <= 0 || _trigger <= 0) continue;

        var _row = {
            source_species_id: _source,
            evolved_species_id: _target,
            evolution_trigger_id: _trigger,
            trigger_item_id: (ci_item >= 0 ? __to_int_safe(__grid(g, ci_item, r2, 0), 0) : 0),
            minimum_level: (ci_level >= 0 ? __to_int_safe(__grid(g, ci_level, r2, 0), 0) : 0),
            gender_id: (ci_gender >= 0 ? __to_int_safe(__grid(g, ci_gender, r2, 0), 0) : 0),
            location_id: (ci_location >= 0 ? __to_int_safe(__grid(g, ci_location, r2, 0), 0) : 0),
            held_item_id: (ci_held >= 0 ? __to_int_safe(__grid(g, ci_held, r2, 0), 0) : 0),
            time_of_day: (ci_time >= 0 ? __s_trim(__grid(g, ci_time, r2, "")) : ""),
            known_move_id: (ci_move >= 0 ? __to_int_safe(__grid(g, ci_move, r2, 0), 0) : 0),
            known_move_type_id: (ci_move_type >= 0 ? __to_int_safe(__grid(g, ci_move_type, r2, 0), 0) : 0),
            minimum_happiness: (ci_happy >= 0 ? __to_int_safe(__grid(g, ci_happy, r2, 0), 0) : 0),
            minimum_beauty: (ci_beauty >= 0 ? __to_int_safe(__grid(g, ci_beauty, r2, 0), 0) : 0),
            minimum_affection: (ci_affection >= 0 ? __to_int_safe(__grid(g, ci_affection, r2, 0), 0) : 0),
            relative_physical_stats: (ci_relative >= 0 ? __to_int_safe(__grid(g, ci_relative, r2, 0), 0) : 0),
            party_species_id: (ci_party_species >= 0 ? __to_int_safe(__grid(g, ci_party_species, r2, 0), 0) : 0),
            party_type_id: (ci_party_type >= 0 ? __to_int_safe(__grid(g, ci_party_type, r2, 0), 0) : 0),
            trade_species_id: (ci_trade_species >= 0 ? __to_int_safe(__grid(g, ci_trade_species, r2, 0), 0) : 0),
            needs_overworld_rain: (ci_rain >= 0 ? __to_int_safe(__grid(g, ci_rain, r2, 0), 0) : 0),
            turn_upside_down: (ci_upside >= 0 ? __to_int_safe(__grid(g, ci_upside, r2, 0), 0) : 0)
        };

        array_push(global._pokemon_evolutions, _row);
        array_push(global._pokemon_evolutions_by_species[_source], _row);
        rows += 1;
    }

    data_debug("[DATA][pokemon_evolution] rows=" + string(rows));
}

function scr_get_species_evolutions(_species_id){
    var _sid = is_real(_species_id) ? floor(_species_id) : -1;
    if (_sid <= 0) return [];
    if (!variable_global_exists("_pokemon_evolutions_by_species") || !is_array(global._pokemon_evolutions_by_species)) return [];
    if (_sid >= array_length(global._pokemon_evolutions_by_species)) return [];
    var _rows = global._pokemon_evolutions_by_species[_sid];
    return is_array(_rows) ? _rows : [];
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
    var ci_item_id = __col_find_ci(g, "id");
    var ci_item_ident = __col_find_ci(g, "identifier");
    var ci_item_cat = __col_find_ci(g, "category_id");
    var ci_item_cost = __col_find_ci(g, "cost");
    var ci_item_fling = __col_find_ci(g, "fling_power");
    if (ci_item_id < 0) ci_item_id = 0;
    if (ci_item_ident < 0) ci_item_ident = 1;

    for (var r2 = 1; r2 < H; r2++){
        var cell_id = __grid(g, ci_item_id, r2, 0);
        var _id = __to_int_safe(cell_id, 0);
        if (_id <= 0) continue;
        var ident = __s_trim(__grid(g, ci_item_ident, r2, "") );
        var cost  = (ci_item_cost >= 0) ? __to_int_safe(__grid(g, ci_item_cost, r2, 0), 0) : 0;
        var catid = (ci_item_cat >= 0) ? __to_int_safe(__grid(g, ci_item_cat, r2, 0), -1) : -1;
        var fling_power = (ci_item_fling >= 0) ? __to_int_safe(__grid(g, ci_item_fling, r2, -1), -1) : -1;
        global._items[_id] = { _id:_id, identifier:ident, name:ident, cost:cost, category_id:catid, fling_power:fling_power };
        rows++;
    }

    data_debug("[DATA][items] rows=" + string(rows));
}

function data_load_item_names_structs(){
    var csv_path = working_directory + "/data/csv/item_names.csv";
    var g = load_csv(csv_path);
    if (g == -1) { data_debug("[DATA][item_names] SKIP: " + csv_path); return; }

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
        ds_grid_destroy(lg);
    }

    var H = ds_grid_height(g);
    var ci_item = __col_find_ci(g, "item_id"); if (ci_item < 0) ci_item = 0;
    var ci_lang = __col_find_ci(g, "local_language_id"); if (ci_lang < 0) ci_lang = 1;
    var ci_name = __col_find_ci(g, "name"); if (ci_name < 0) ci_name = 2;

    if (!variable_global_exists("_item_text") || !is_array(global._item_text)) global._item_text = [];
    var rows = 0;
    for (var r = 1; r < H; r++){
        var iid = __to_int_safe(__grid(g, ci_item, r, 0), 0);
        if (iid <= 0) continue;
        var lgid = __to_int_safe(__grid(g, ci_lang, r, 0), 0);
        if (lgid != en_id) continue;
        if (array_length(global._item_text) <= iid) array_resize(global._item_text, iid + 1);
        var rec = global._item_text[iid];
        if (!is_struct(rec)) rec = {};
        var namev = __text_clean_spaces(__grid(g, ci_name, r, ""));
        if (string_length(namev) > 0) rec.name = namev;
        global._item_text[iid] = rec;
        rows++;
    }
    ds_grid_destroy(g);
    data_debug("[DATA][item_names] rows=" + string(rows));
}

function data_load_item_text_structs(){
    var csv_path = working_directory + "/data/csv/item_flavor_text.csv";
    var g = load_csv(csv_path);
    if (g == -1) { data_debug("[DATA][item_flavor_text] SKIP: " + csv_path); return; }

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
        ds_grid_destroy(lg);
    }

    var H = ds_grid_height(g);
    var ci_item = __col_find_ci(g, "item_id"); if (ci_item < 0) ci_item = 0;
    var ci_vg = __col_find_ci(g, "version_group_id"); if (ci_vg < 0) ci_vg = 1;
    var ci_lang = __col_find_ci(g, "language_id"); if (ci_lang < 0) ci_lang = __col_find_ci(g, "local_language_id"); if (ci_lang < 0) ci_lang = 2;
    var ci_text = __col_find_ci(g, "flavor_text"); if (ci_text < 0) ci_text = 3;

    if (!variable_global_exists("_item_text") || !is_array(global._item_text)) global._item_text = [];
    var rows = 0;
    for (var r = 1; r < H; r++){
        var iid = __to_int_safe(__grid(g, ci_item, r, 0), 0);
        if (iid <= 0) continue;
        var lgid = __to_int_safe(__grid(g, ci_lang, r, 0), 0);
        if (lgid != en_id) continue;

        var vg = __to_int_safe(__grid(g, ci_vg, r, 0), 0);
        var textv = __text_clean_spaces(__grid(g, ci_text, r, ""));
        if (string_length(textv) <= 0) continue;

        if (array_length(global._item_text) <= iid) array_resize(global._item_text, iid + 1);
        var rec = global._item_text[iid];
        if (!is_struct(rec)) rec = {};
        var old_vg = (variable_struct_exists(rec, "version_group_id") && is_real(rec.version_group_id)) ? rec.version_group_id : -1;
        if (vg >= old_vg){
            rec.flavor_text = textv;
            rec.short_desc = textv;
            rec.version_group_id = vg;
        }
        global._item_text[iid] = rec;
        rows++;
    }
    ds_grid_destroy(g);

    var sum_path = working_directory + "/data/csv/item_flavor_summaries.csv";
    var sg = load_csv(sum_path);
    var sum_rows = 0;
    if (sg != -1){
        var SH = ds_grid_height(sg);
        var sci_item = __col_find_ci(sg, "item_id"); if (sci_item < 0) sci_item = 0;
        var sci_lang = __col_find_ci(sg, "local_language_id"); if (sci_lang < 0) sci_lang = __col_find_ci(sg, "language_id"); if (sci_lang < 0) sci_lang = 1;
        var sci_text = __col_find_ci(sg, "flavor_summary"); if (sci_text < 0) sci_text = 2;
        for (var sr = 1; sr < SH; sr++){
            var siid = __to_int_safe(__grid(sg, sci_item, sr, 0), 0);
            if (siid <= 0) continue;
            var slgid = __to_int_safe(__grid(sg, sci_lang, sr, 0), 0);
            if (slgid != en_id) continue;
            var sv = __text_clean_spaces(__grid(sg, sci_text, sr, ""));
            if (string_length(sv) <= 0) continue;
            if (array_length(global._item_text) <= siid) array_resize(global._item_text, siid + 1);
            var srec = global._item_text[siid];
            if (!is_struct(srec)) srec = {};
            srec.flavor_summary = sv;
            srec.short_desc = sv;
            global._item_text[siid] = srec;
            sum_rows++;
        }
        ds_grid_destroy(sg);
    }

    data_debug("[DATA][item_flavor_text] rows=" + string(rows) + " summaries=" + string(sum_rows));
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
    var ci_pocket_id = __col_find_ci(g, "pocket_id");
    var pocket_names_by_id = {};
    try {
        var pg_csv = load_csv(working_directory + "/data/csv/item_pockets.csv");
        if (pg_csv != -1){
            var pg_h = ds_grid_height(pg_csv);
            var pg_id_col = __col_find_ci(pg_csv, "id");
            var pg_ident_col = __col_find_ci(pg_csv, "identifier");
            for (var pg_r = 1; pg_r < pg_h; ++pg_r){
                var pg_id = __to_int_safe(__grid(pg_csv, pg_id_col >= 0 ? pg_id_col : 0, pg_r, 0), 0);
                var pg_ident = __s_trim(__grid(pg_csv, pg_ident_col >= 0 ? pg_ident_col : 1, pg_r, ""));
                if (pg_id > 0 && string_length(pg_ident) > 0) variable_struct_set(pocket_names_by_id, string(pg_id), pg_ident);
            }
            ds_grid_destroy(pg_csv);
        }
    } catch (e_item_pockets_load) {}

    // Create mapping from pocket name to page index (do this with a dict to avoid repeated array_push)
    var pocket_map = {}; // pocket_name -> index
    var pocket_list_counts = []; // temporary to preserve insertion order
    var rows = 0;
    for (var r2 = 1; r2 < H; r2++){
        var cid = (ci_id >= 0) ? __to_int_safe(__grid(g, ci_id, r2, 0), 0) : __to_int_safe(__grid(g, 0, r2, 0), 0);
        if (cid <= 0) continue;
        var ident = (ci_ident >= 0) ? __s_trim(__grid(g, ci_ident, r2, "")) : string(__grid(g,1,r2,""));
        var namev = (ci_name >= 0) ? __s_trim(__grid(g, ci_name, r2, "")) : ident;
        var pocket_name = "";
        if (ci_pocket >= 0) pocket_name = __s_trim(__grid(g, ci_pocket, r2, ""));
        if (string_length(pocket_name) <= 0 && ci_pocket_id >= 0){
            var _pocket_id_raw = __to_int_safe(__grid(g, ci_pocket_id, r2, 0), 0);
            if (_pocket_id_raw > 0 && variable_struct_exists(pocket_names_by_id, string(_pocket_id_raw))) pocket_name = variable_struct_get(pocket_names_by_id, string(_pocket_id_raw));
            else pocket_name = string(_pocket_id_raw);
        }
        if (string_length(pocket_name) <= 0) pocket_name = string(cid);

        var pocket_id = -1;
        // Defensive: only treat pocket_map as a struct if it really is one; pocket_name should be a string
        if (is_struct(pocket_map) && is_string(pocket_name) && variable_struct_exists(pocket_map, pocket_name)){
            pocket_id = variable_struct_get(pocket_map, pocket_name);
        } else {
            pocket_id = array_length(pocket_list_counts);
            pocket_list_counts[pocket_id] = pocket_name;
            if (is_struct(pocket_map)) variable_struct_set(pocket_map, pocket_name, pocket_id);
            else {
                // If pocket_map somehow isn't a struct, fall back to creating a local struct mapping
                pocket_map = {};
                variable_struct_set(pocket_map, pocket_name, pocket_id);
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
function __item_effects_identifier_overrides(_item_id){
    var _effects = [];
    if (!is_real(_item_id) || !variable_global_exists("_items") || !is_array(global._items)) return _effects;
    var _iid = floor(_item_id);
    if (_iid <= 0 || _iid >= array_length(global._items)) return _effects;
    var _it = global._items[_iid];
    if (!is_struct(_it)) return _effects;

    var _ident = "";
    if (variable_struct_exists(_it, "identifier")) _ident = string_lower(string(variable_struct_get(_it, "identifier")));
    else if (variable_struct_exists(_it, "name")) _ident = string_lower(string(variable_struct_get(_it, "name")));
    var _cat_id = (variable_struct_exists(_it, "category_id") && is_real(variable_struct_get(_it, "category_id"))) ? floor(variable_struct_get(_it, "category_id")) : -1;
    if (string_length(_ident) <= 0) return _effects;

    switch (_ident){
        case "exp-candy-xs": _effects[array_length(_effects)] = { type:"exp_gain", params:{ amount:100 } }; return _effects;
        case "exp-candy-s":  _effects[array_length(_effects)] = { type:"exp_gain", params:{ amount:800 } }; return _effects;
        case "exp-candy-m":  _effects[array_length(_effects)] = { type:"exp_gain", params:{ amount:3000 } }; return _effects;
        case "exp-candy-l":  _effects[array_length(_effects)] = { type:"exp_gain", params:{ amount:10000 } }; return _effects;
        case "exp-candy-xl": _effects[array_length(_effects)] = { type:"exp_gain", params:{ amount:30000 } }; return _effects;
        case "dynamax-candy": _effects[array_length(_effects)] = { type:"dynamax_level", params:{ amount:1, max:10 } }; return _effects;
        case "ability-capsule": _effects[array_length(_effects)] = { type:"ability_change", params:{ mode:"regular" } }; return _effects;
        case "ability-patch": _effects[array_length(_effects)] = { type:"ability_change", params:{ mode:"hidden" } }; return _effects;
        case "zinc": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"spd", amount:10 } }; return _effects;
        case "health-wing": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"hp", amount:1 } }; return _effects;
        case "muscle-wing": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"atk", amount:1 } }; return _effects;
        case "resist-wing": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"def", amount:1 } }; return _effects;
        case "genius-wing": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"spa", amount:1 } }; return _effects;
        case "clever-wing": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"spd", amount:1 } }; return _effects;
        case "swift-wing": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"spe", amount:1 } }; return _effects;
        case "health-mochi": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"hp", amount:10 } }; return _effects;
        case "muscle-mochi": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"atk", amount:10 } }; return _effects;
        case "resist-mochi": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"def", amount:10 } }; return _effects;
        case "genius-mochi": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"spa", amount:10 } }; return _effects;
        case "clever-mochi": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"spd", amount:10 } }; return _effects;
        case "swift-mochi": _effects[array_length(_effects)] = { type:"ev_raise", params:{ stat:"spe", amount:10 } }; return _effects;
        case "fresh-start-mochi": _effects[array_length(_effects)] = { type:"ev_reset", params:{} }; return _effects;
        case "pewter-crunchies": _effects[array_length(_effects)] = { type:"cure_all", params:{} }; return _effects;
        case "max-honey": _effects[array_length(_effects)] = { type:"revive_full", params:{ mode:"full" } }; return _effects;
        case "lure": _effects[array_length(_effects)] = { type:"encounter_rate", params:{ multiplier:2, steps:100 } }; return _effects;
        case "super-lure": _effects[array_length(_effects)] = { type:"encounter_rate", params:{ multiplier:2, steps:200 } }; return _effects;
        case "max-lure": _effects[array_length(_effects)] = { type:"encounter_rate", params:{ multiplier:2, steps:250 } }; return _effects;
    }

    var _mint_suffix = "-mint";
    if (string_length(_ident) > string_length(_mint_suffix) && string_copy(_ident, string_length(_ident) - string_length(_mint_suffix) + 1, string_length(_mint_suffix)) == _mint_suffix){
        var _nature = string_copy(_ident, 1, string_length(_ident) - string_length(_mint_suffix));
        _effects[array_length(_effects)] = { type:"nature_mint", params:{ nature:_nature } };
        return _effects;
    }

    var _stat_candy_stat = "";
    if (string_copy(_ident, 1, string_length("health-candy")) == "health-candy") _stat_candy_stat = "hp";
    else if (string_copy(_ident, 1, string_length("mighty-candy")) == "mighty-candy") _stat_candy_stat = "atk";
    else if (string_copy(_ident, 1, string_length("tough-candy")) == "tough-candy") _stat_candy_stat = "def";
    else if (string_copy(_ident, 1, string_length("smart-candy")) == "smart-candy") _stat_candy_stat = "spa";
    else if (string_copy(_ident, 1, string_length("courage-candy")) == "courage-candy") _stat_candy_stat = "spd";
    else if (string_copy(_ident, 1, string_length("quick-candy")) == "quick-candy") _stat_candy_stat = "spe";
    if (string_length(_stat_candy_stat) > 0){
        var _amt = 1;
        if (string_length(_ident) >= 3 && string_copy(_ident, string_length(_ident) - 2, 3) == "-xl") _amt = 3;
        else if (string_length(_ident) >= 2 && string_copy(_ident, string_length(_ident) - 1, 2) == "-l") _amt = 2;
        _effects[array_length(_effects)] = { type:"stat_candy", params:{ stat:_stat_candy_stat, amount:_amt } };
        return _effects;
    }

    if (_cat_id == 47){
        var _candy_suffix = "-candy";
        var _species_ident = _ident;
        if (string_length(_species_ident) > string_length(_candy_suffix) && string_copy(_species_ident, string_length(_species_ident) - string_length(_candy_suffix) + 1, string_length(_candy_suffix)) == _candy_suffix){
            _species_ident = string_copy(_species_ident, 1, string_length(_species_ident) - string_length(_candy_suffix));
        }
        _effects[array_length(_effects)] = { type:"species_candy", params:{ species_identifier:_species_ident, amount:1 } };
        return _effects;
    }

    var _tera_suffix = "-tera-shard";
    if (string_length(_ident) > string_length(_tera_suffix) && string_copy(_ident, string_length(_ident) - string_length(_tera_suffix) + 1, string_length(_tera_suffix)) == _tera_suffix){
        var _tera_type = string_copy(_ident, 1, string_length(_ident) - string_length(_tera_suffix));
        _effects[array_length(_effects)] = { type:"tera_type_change", params:{ type:_tera_type } };
        return _effects;
    }

    return _effects;
}

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
        var identifier_effects = __item_effects_identifier_overrides(iid);
        if (is_array(identifier_effects) && array_length(identifier_effects) > 0){
            global._item_effects[iid] = identifier_effects;
            continue;
        }
        if (!is_struct(entry)) continue;
        var s = entry.short_effect;
        if (!is_string(s) || string_length(s) == 0) continue;
        var s_lower = string_lower(s);
        var effects = [];
        var matched = false;
        var scope_hint_pp = "single";
        if (string_pos("each move", s_lower) > 0 || string_pos("all moves", s_lower) > 0 || string_pos("every move", s_lower) > 0 || string_pos("all of its moves", s_lower) > 0 || string_pos("all four moves", s_lower) > 0)
            scope_hint_pp = "all";

        var _has_item_evo = false;
        if (variable_global_exists("_pokemon_evolutions") && is_array(global._pokemon_evolutions)){
            for (var _evi = 0; _evi < array_length(global._pokemon_evolutions); _evi++){
                var _evrow = global._pokemon_evolutions[_evi];
                if (is_struct(_evrow) && variable_struct_exists(_evrow, "trigger_item_id") && variable_struct_get(_evrow, "trigger_item_id") == iid){
                    _has_item_evo = true;
                    break;
                }
            }
        }
        if (_has_item_evo){ effects[array_length(effects)] = { type:"evolve_item", params:{} }; global._item_effects[iid] = effects; continue; }

        if (string_pos("causes a level-up", s_lower) > 0){ effects[array_length(effects)] = { type:"level_up", params:{} }; global._item_effects[iid] = effects; continue; }

        var _ev_stat = "";
        if (string_pos("hp effort", s_lower) > 0) _ev_stat = "hp";
        else if (string_pos("attack effort", s_lower) > 0 && string_pos("special attack", s_lower) <= 0) _ev_stat = "atk";
        else if (string_pos("defense effort", s_lower) > 0 && string_pos("special defense", s_lower) <= 0) _ev_stat = "def";
        else if (string_pos("special attack effort", s_lower) > 0) _ev_stat = "spa";
        else if (string_pos("special defense effort", s_lower) > 0) _ev_stat = "spd";
        else if (string_pos("speed effort", s_lower) > 0) _ev_stat = "spe";
        if (string_length(_ev_stat) > 0){
            if (string_pos("drops", s_lower) > 0) effects[array_length(effects)] = { type:"ev_drop", params:{ stat:_ev_stat, amount:10 } };
            else effects[array_length(effects)] = { type:"ev_raise", params:{ stat:_ev_stat, amount:10 } };
            global._item_effects[iid] = effects;
            continue;
        }

        if (string_pos("max pp by 20", s_lower) > 0){ effects[array_length(effects)] = { type:"pp_up", params:{ amount:1 } }; global._item_effects[iid] = effects; continue; }
        if (string_pos("max pp by 60", s_lower) > 0){ effects[array_length(effects)] = { type:"pp_up", params:{ amount:3 } }; global._item_effects[iid] = effects; continue; }

        if (string_pos("ends a wild battle", s_lower) > 0){ effects[array_length(effects)] = { type:"escape_battle", params:{} }; global._item_effects[iid] = effects; continue; }
        if (string_pos("prevents wild encounters", s_lower) > 0){
            var _repel_steps = 250;
            if (string_pos("100 steps", s_lower) > 0) _repel_steps = 100;
            else if (string_pos("200 steps", s_lower) > 0) _repel_steps = 200;
            else if (string_pos("250 steps", s_lower) > 0) _repel_steps = 250;
            effects[array_length(effects)] = { type:"repel", params:{ steps:_repel_steps } };
            global._item_effects[iid] = effects;
            continue;
        }
        if (string_pos("halves the wild", s_lower) > 0 && string_pos("encounter rate", s_lower) > 0){ effects[array_length(effects)] = { type:"encounter_rate", params:{ multiplier:0.5, steps:250 } }; global._item_effects[iid] = effects; continue; }
        if (string_pos("doubles the wild", s_lower) > 0 && string_pos("encounter rate", s_lower) > 0){ effects[array_length(effects)] = { type:"encounter_rate", params:{ multiplier:2, steps:250 } }; global._item_effects[iid] = effects; continue; }

        var _stage_stat = "";
        if (string_pos("attack", s_lower) > 0 && string_pos("special attack", s_lower) <= 0) _stage_stat = "atk";
        else if (string_pos("defense", s_lower) > 0 && string_pos("special defense", s_lower) <= 0) _stage_stat = "def";
        else if (string_pos("special attack", s_lower) > 0) _stage_stat = "spa";
        else if (string_pos("special defense", s_lower) > 0) _stage_stat = "spd";
        else if (string_pos("speed", s_lower) > 0) _stage_stat = "spe";
        else if (string_pos("accuracy", s_lower) > 0) _stage_stat = "accuracy";
        if (string_pos("critical", s_lower) > 0 && string_pos("battle", s_lower) > 0){ effects[array_length(effects)] = { type:"dire_hit", params:{ stages:1 } }; global._item_effects[iid] = effects; continue; }
        if (string_pos("prevents stat changes", s_lower) > 0){ effects[array_length(effects)] = { type:"guard_spec", params:{ turns:5 } }; global._item_effects[iid] = effects; continue; }
        if (string_length(_stage_stat) > 0 && string_pos("stage", s_lower) > 0 && string_pos("battle", s_lower) > 0){
            var _stage_amount = 1;
            if (string_pos("two", s_lower) > 0) _stage_amount = 2;
            else if (string_pos("three", s_lower) > 0) _stage_amount = 3;
            else if (string_pos("six", s_lower) > 0) _stage_amount = 6;
            effects[array_length(effects)] = { type:"battle_stage", params:{ stat:_stage_stat, amount:_stage_amount } };
            global._item_effects[iid] = effects;
            continue;
        }

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
        if (string_pos("restores hp to full", s_lower) > 0){ effects[ array_length(effects) ] = { type:"heal_full", params:{} }; global._item_effects[iid] = effects; continue; }

        // revive patterns
        if (string_pos("revives with half hp", s_lower) > 0){ effects[ array_length(effects) ] = { type:"revive", params:{ mode:"half" } }; global._item_effects[iid] = effects; continue; }
        if (string_pos("revives with full hp", s_lower) > 0){ effects[ array_length(effects) ] = { type:"revive", params:{ mode:"full" } }; global._item_effects[iid] = effects; continue; }
        if (string_pos("revives all fainted", s_lower) > 0 || string_pos("revives all fainted pokémon", s_lower) > 0){ effects[ array_length(effects) ] = { type:"revive_all", params:{} }; global._item_effects[iid] = effects; continue; }

        // cure all / full-restore
        if (string_pos("cures any status ailment", s_lower) > 0 && string_pos("restores hp to full", s_lower) > 0){ effects[ array_length(effects) ] = { type:"full_restore", params:{} }; global._item_effects[iid] = effects; continue; }
        if (string_pos("cures any status ailment", s_lower) > 0 || string_pos("cures all major status", s_lower) > 0 || string_pos("cures major status", s_lower) > 0 || string_pos("to cure any status", s_lower) > 0){ effects[ array_length(effects) ] = { type:"cure_all", params:{} }; global._item_effects[iid] = effects; continue; }

        if (string_pos("to cure", s_lower) > 0){
            var held_after = string_delete(s, 1, string_pos("to cure", s_lower) - 1);
            held_after = string_delete(held_after, 1, string_length("to cure"));
            var held_end = string_pos(".", held_after);
            var held_status = (held_end > 0) ? string_copy(held_after, 1, held_end - 1) : string_trim(held_after);
            held_status = string_lower(string_trim(held_status));
            if (string_length(held_status) >= 2 && string_copy(held_status, 1, 2) == "a ") held_status = string_delete(held_status, 1, 2);
            held_status = string_replace_all(held_status, "frozen", "freeze");
            held_status = string_replace_all(held_status, "a burn", "burn");
            held_status = string_replace_all(held_status, " ", "-");
            if (string_length(held_status) > 0){ effects[ array_length(effects) ] = { type:"cure_status", params:{ status:held_status } }; global._item_effects[iid] = effects; continue; }
        }

        // simple single-status cure (e.g., "Cures poison.")
        var cure_prefix = "Cures ";
        if (string_pos(cure_prefix, s) > 0){
            var after = string_delete(s, 1, string_pos(cure_prefix, s)-1);
            after = string_delete(after, 1, string_length(cure_prefix));
            // take first word up to period
            var endp = string_pos(".", after);
            var status_word = (endp > 0) ? string_copy(after, 1, endp-1) : string_trim(after);
            status_word = string_lower(string_trim(status_word));
            status_word = string_replace_all(status_word, ",", "");
            status_word = string_replace_all(status_word, ".", "");
            status_word = string_replace_all(status_word, "!", "");
            status_word = string_replace_all(status_word, ";", "");
            if (string_length(status_word) >= 2 && string_copy(status_word, 1, 2) == "a ") status_word = string_delete(status_word, 1, 2);
            if (string_length(status_word) >= 3 && string_copy(status_word, 1, 3) == "an ") status_word = string_delete(status_word, 1, 3);
            if (string_length(status_word) >= 4 && string_copy(status_word, 1, 4) == "any ") status_word = string_delete(status_word, 1, 4);
            status_word = string_trim(status_word);
            var _suffixes = [" ailment"," ailment status"," problem"," problems"," condition"," conditions"," status"," status ailment"," status problem"];
            for (var _si = 0; _si < array_length(_suffixes); _si++){
                var suf = _suffixes[_si];
                var slen = string_length(suf);
                if (slen > 0 && string_length(status_word) > slen){
                    if (string_copy(status_word, string_length(status_word) - slen + 1, slen) == suf){
                        status_word = string_copy(status_word, 1, string_length(status_word) - slen);
                        status_word = string_trim(status_word);
                    }
                }
            }
            status_word = string_replace_all(status_word, "-", " ");
            status_word = string_replace_all(status_word, "/", " ");
            while (string_pos("  ", status_word) > 0) status_word = string_replace_all(status_word, "  ", " ");
            status_word = string_trim(status_word);
            status_word = string_replace_all(status_word, " ", "-");
            if (string_length(status_word) > 0){ effects[ array_length(effects) ] = { type:"cure_status", params:{ status:status_word } }; global._item_effects[iid] = effects; continue; }
        }

        // restore PP numeric or full
        if (string_pos("restores", s_lower) > 0 && string_pos("pp", s_lower) > 0){
            // numeric amount?
            var toks2 = string_split(s, " ");
            var found_amount = false;
            for (var ti2 = 0; ti2 < array_length(toks2); ti2++){
                var t2 = string_replace_all(toks2[ti2], ",", "");
                var okd = true;
                for (var c2 = 1; c2 <= string_length(t2); c2++){ var ch2 = string_copy(t2, c2, 1); if (ch2 < "0" || ch2 > "9") { okd = false; break; } }
                if (okd && string_length(t2) > 0){
                    var n2 = __to_int_safe(t2, 0);
                    if (n2 > 0){
                        effects[ array_length(effects) ] = { type:"restore_pp", params:{ amount:n2, scope:scope_hint_pp } };
                        global._item_effects[iid] = effects;
                        matched = true;
                        found_amount = true;
                        break;
                    }
                }
            }
            if (matched) continue;
            if (!found_amount && string_pos("restores pp to full", s_lower) > 0){
                effects[ array_length(effects) ] = { type:"restore_pp", params:{ full:true, scope:scope_hint_pp } };
                global._item_effects[iid] = effects;
                continue;
            }
        }

        // fallback: store empty array so callers know we've parsed but found no structured effects
        global._item_effects[iid] = [];
    }
    data_debug("[DATA][item_effects] parsed up to id=" + string(max_id));
}

// ---------- ITEMS: generic runtime registry ----------
// Builds global._item_runtime[item_id] records from the CSV data already loaded above.
// This is the item-side equivalent of the ability grouping layer: bag code can still
// apply direct effects, while battle/field hooks can ask for grouped held-item actions.
function __item_runtime_safe_identifier(_item_id){
    if (!is_real(_item_id)) return "";
    var _iid = floor(_item_id);
    if (_iid <= 0 || !variable_global_exists("_items") || !is_array(global._items) || _iid >= array_length(global._items)) return "";
    var _it = global._items[_iid];
    if (!is_struct(_it)) return "";
    if (variable_struct_exists(_it, "identifier")) return string_lower(string(variable_struct_get(_it, "identifier")));
    if (variable_struct_exists(_it, "name")) return string_lower(string(variable_struct_get(_it, "name")));
    return "";
}

function __item_runtime_safe_name(_item_id){
    if (!is_real(_item_id)) return "";
    var _iid = floor(_item_id);
    if (_iid <= 0 || !variable_global_exists("_items") || !is_array(global._items) || _iid >= array_length(global._items)) return "";
    var _it = global._items[_iid];
    if (!is_struct(_it)) return "";
    if (variable_struct_exists(_it, "name")) return string(variable_struct_get(_it, "name"));
    if (variable_struct_exists(_it, "identifier")) return string(variable_struct_get(_it, "identifier"));
    return "";
}

function __item_runtime_prose_text(_item_id){
    if (!is_real(_item_id)) return "";
    var _iid = floor(_item_id);
    if (_iid <= 0 || !variable_global_exists("_item_prose") || !is_array(global._item_prose) || _iid >= array_length(global._item_prose)) return "";
    var _p = global._item_prose[_iid];
    if (!is_struct(_p)) return "";
    var _out = "";
    if (variable_struct_exists(_p, "short_effect")) _out += " " + string(variable_struct_get(_p, "short_effect"));
    if (variable_struct_exists(_p, "effect")) _out += " " + string(variable_struct_get(_p, "effect"));
    return string_lower(_out);
}

function __item_runtime_category_identifier(_item_id){
    if (!is_real(_item_id)) return "";
    var _iid = floor(_item_id);
    if (_iid <= 0 || !variable_global_exists("_items") || !is_array(global._items) || _iid >= array_length(global._items)) return "";
    var _it = global._items[_iid];
    if (!is_struct(_it) || !variable_struct_exists(_it, "category_id") || !is_real(variable_struct_get(_it, "category_id"))) return "";
    var _cat_id = floor(variable_struct_get(_it, "category_id"));
    if (_cat_id <= 0 || !variable_global_exists("item_categorys") || !is_array(global.item_categorys) || _cat_id >= array_length(global.item_categorys)) return "";
    var _cat = global.item_categorys[_cat_id];
    if (!is_struct(_cat)) return "";
    if (variable_struct_exists(_cat, "identifier")) return string_lower(string(variable_struct_get(_cat, "identifier")));
    if (variable_struct_exists(_cat, "name")) return string_lower(string(variable_struct_get(_cat, "name")));
    return "";
}

function __item_runtime_category_pocket(_item_id){
    if (!is_real(_item_id)) return "";
    var _iid = floor(_item_id);
    if (_iid <= 0 || !variable_global_exists("_items") || !is_array(global._items) || _iid >= array_length(global._items)) return "";
    var _it = global._items[_iid];
    if (!is_struct(_it) || !variable_struct_exists(_it, "category_id") || !is_real(variable_struct_get(_it, "category_id"))) return "";
    var _cat_id = floor(variable_struct_get(_it, "category_id"));
    if (_cat_id <= 0 || !variable_global_exists("item_categorys") || !is_array(global.item_categorys) || _cat_id >= array_length(global.item_categorys)) return "";
    var _cat = global.item_categorys[_cat_id];
    if (!is_struct(_cat)) return "";
    if (variable_struct_exists(_cat, "pocket")) return string_lower(string(variable_struct_get(_cat, "pocket")));
    return "";
}

function __item_runtime_add_group(_rec, _group){
    if (!is_struct(_rec) || string_length(string(_group)) <= 0) return;
    var _g = string_lower(string(_group));
    if (!variable_struct_exists(_rec, "groups") || !is_array(variable_struct_get(_rec, "groups"))) variable_struct_set(_rec, "groups", []);
    var _arr = variable_struct_get(_rec, "groups");
    for (var _i = 0; _i < array_length(_arr); ++_i){ if (string(_arr[_i]) == _g) return; }
    array_push(_arr, _g);
    variable_struct_set(_rec, "groups", _arr);
}

function __item_runtime_add_action(_rec, _hook, _kind, _data){
    if (!is_struct(_rec) || string_length(string(_hook)) <= 0 || string_length(string(_kind)) <= 0) return;
    if (!variable_struct_exists(_rec, "actions") || !is_struct(variable_struct_get(_rec, "actions"))) variable_struct_set(_rec, "actions", {});
    var _actions = variable_struct_get(_rec, "actions");
    var _h = string_lower(string(_hook));
    var _list = [];
    if (variable_struct_exists(_actions, _h) && is_array(variable_struct_get(_actions, _h))) _list = variable_struct_get(_actions, _h);
    array_push(_list, { hook:_h, kind:string_lower(string(_kind)), data:_data });
    variable_struct_set(_actions, _h, _list);
    variable_struct_set(_rec, "actions", _actions);
}

function __item_runtime_group_push(_group, _item_id){
    if (!variable_global_exists("_item_runtime_groups") || !is_struct(global._item_runtime_groups)) global._item_runtime_groups = {};
    var _g = string_lower(string(_group));
    var _list = [];
    if (variable_struct_exists(global._item_runtime_groups, _g) && is_array(variable_struct_get(global._item_runtime_groups, _g))) _list = variable_struct_get(global._item_runtime_groups, _g);
    for (var _i = 0; _i < array_length(_list); ++_i){ if (_list[_i] == _item_id) return; }
    array_push(_list, _item_id);
    variable_struct_set(global._item_runtime_groups, _g, _list);
}

function __item_runtime_tracker_bump(_map, _key){
    if (!is_struct(_map)) return;
    var _k = string_lower(string(_key));
    var _v = 0;
    if (variable_struct_exists(_map, _k) && is_real(variable_struct_get(_map, _k))) _v = variable_struct_get(_map, _k);
    variable_struct_set(_map, _k, _v + 1);
}

function __item_runtime_has_text(_text, _needle){
    if (!is_string(_text) || !is_string(_needle)) return false;
    return (string_pos(string_lower(_needle), string_lower(_text)) > 0);
}

function __item_runtime_add_effect_groups(_rec, _item_id){
    if (!variable_global_exists("_item_effects") || !is_array(global._item_effects) || _item_id >= array_length(global._item_effects)) return;
    var _effects = global._item_effects[_item_id];
    if (!is_array(_effects)) return;
    for (var _i = 0; _i < array_length(_effects); ++_i){
        var _eff = _effects[_i];
        if (!is_struct(_eff) || !variable_struct_exists(_eff, "type")) continue;
        var _type = string_lower(string(variable_struct_get(_eff, "type")));
        __item_runtime_add_group(_rec, "effect_" + _type);
        __item_runtime_add_action(_rec, "use_target", _type, (variable_struct_exists(_eff, "params") ? variable_struct_get(_eff, "params") : {}));
        switch (_type){
            case "heal_flat":
            case "heal_full":
            case "full_restore":
                __item_runtime_add_group(_rec, "medicine_hp");
                break;
            case "revive":
            case "revive_half":
            case "revive_full":
            case "revive_all":
                __item_runtime_add_group(_rec, "medicine_revive");
                break;
            case "cure_status":
            case "cure_all":
                __item_runtime_add_group(_rec, "medicine_status");
                break;
            case "restore_pp":
            case "restore_pp_full":
            case "pp_up":
                __item_runtime_add_group(_rec, "medicine_pp");
                break;
            case "ev_raise":
            case "ev_drop":
            case "exp_gain":
            case "stat_candy":
            case "species_candy":
            case "nature_mint":
            case "dynamax_level":
            case "ability_change":
            case "ev_reset":
                __item_runtime_add_group(_rec, "stat_training");
                break;
            case "tera_type_change":
                __item_runtime_add_group(_rec, "tera_shard");
                __item_runtime_add_group(_rec, "stat_training");
                break;
            case "battle_stage":
            case "dire_hit":
            case "guard_spec":
                __item_runtime_add_group(_rec, "battle_item");
                break;
            case "repel":
            case "encounter_rate":
                __item_runtime_add_group(_rec, "field_encounter");
                break;
            case "escape_battle":
                __item_runtime_add_group(_rec, "battle_escape");
                break;
            case "evolve_item":
                __item_runtime_add_group(_rec, "evolution_item");
                break;
        }
    }
}

function __item_runtime_classify_type_boost(_rec, _ident, _text){
    var _pairs = [
        ["silk-scarf","normal"], ["pink-bow","normal"], ["polkadot-bow","normal"],
        ["charcoal","fire"], ["mystic-water","water"], ["magnet","electric"], ["miracle-seed","grass"],
        ["never-melt-ice","ice"], ["black-belt","fighting"], ["poison-barb","poison"], ["soft-sand","ground"],
        ["sharp-beak","flying"], ["twisted-spoon","psychic"], ["silver-powder","bug"], ["hard-stone","rock"],
        ["spell-tag","ghost"], ["dragon-fang","dragon"], ["black-glasses","dark"], ["metal-coat","steel"],
        ["fairy-feather","fairy"], ["sea-incense","water"], ["wave-incense","water"], ["odd-incense","psychic"],
        ["rock-incense","rock"], ["rose-incense","grass"], ["muscle-band","physical"], ["wise-glasses","special"]
    ];
    for (var _i = 0; _i < array_length(_pairs); ++_i){
        if (_ident == _pairs[_i][0]){
            __item_runtime_add_group(_rec, "held_type_boost");
            __item_runtime_add_action(_rec, "damage_dealt", "type_or_category_multiplier", { type:_pairs[_i][1], multiplier:1.2 });
            return true;
        }
    }

    if (__item_runtime_has_text(_ident, "-plate")){
        var _ptype = string_replace(_ident, "-plate", "");
        __item_runtime_add_group(_rec, "held_type_boost");
        __item_runtime_add_group(_rec, "plate");
        __item_runtime_add_action(_rec, "damage_dealt", "type_multiplier", { type:_ptype, multiplier:1.2 });
        return true;
    }

    if (__item_runtime_has_text(_ident, "-memory") || __item_runtime_has_text(_ident, "-drive")){
        __item_runtime_add_group(_rec, "form_or_type_change_item");
        __item_runtime_add_action(_rec, "form_type_context", "species_specific_type_item", { identifier:_ident });
        return true;
    }

    var _gem_suffix = "-gem";
    if (string_length(_ident) > string_length(_gem_suffix) && string_copy(_ident, string_length(_ident) - string_length(_gem_suffix) + 1, string_length(_gem_suffix)) == _gem_suffix){
        var _gem_type = string_copy(_ident, 1, string_length(_ident) - string_length(_gem_suffix));
        __item_runtime_add_group(_rec, "held_type_boost");
        __item_runtime_add_group(_rec, "held_consumable");
        __item_runtime_add_group(_rec, "held_type_gem");
        __item_runtime_add_action(_rec, "damage_dealt", "type_multiplier", { type:_gem_type, multiplier:1.5, consume:true });
        return true;
    }

    if (__item_runtime_has_text(_text, "boosts the power of") && (__item_runtime_has_text(_text, "type moves") || __item_runtime_has_text(_text, "moves"))){
        __item_runtime_add_group(_rec, "held_type_boost_pending");
        __item_runtime_add_action(_rec, "damage_dealt", "prose_multiplier_pending", { multiplier:1.2 });
        return true;
    }
    return false;
}

function __item_runtime_rec_has_group(_rec, _group){
    if (!is_struct(_rec) || !variable_struct_exists(_rec, "groups") || !is_array(variable_struct_get(_rec, "groups"))) return false;
    var _groups = variable_struct_get(_rec, "groups");
    var _want = string_lower(string(_group));
    for (var _i = 0; _i < array_length(_groups); ++_i){
        if (string_lower(string(_groups[_i])) == _want) return true;
    }
    return false;
}

function __item_runtime_rec_has_any_group(_rec, _groups){
    if (!is_array(_groups)) return false;
    for (var _i = 0; _i < array_length(_groups); ++_i){
        if (__item_runtime_rec_has_group(_rec, _groups[_i])) return true;
    }
    return false;
}

function __item_runtime_classify_category_fallback(_rec, _item_id, _ident, _text){
    if (!is_struct(_rec)) return;

    var _cat = __item_runtime_category_identifier(_item_id);
    var _pocket = __item_runtime_category_pocket(_item_id);
    if (string_length(_cat) > 0) __item_runtime_add_group(_rec, "category_" + _cat);
    if (string_length(_pocket) > 0) __item_runtime_add_group(_rec, "pocket_" + _pocket);

    switch (_cat){
        case "stat-boosts":
        case "miracle-shooter":
            if (!__item_runtime_rec_has_any_group(_rec, ["battle_item","crafting_material"])){
                __item_runtime_add_group(_rec, "battle_item");
                __item_runtime_add_action(_rec, "battle_use", "battle_item_registered", { identifier:_ident });
            }
            break;
        case "effort-drop":
        case "effort-training":
        case "vitamins":
        case "species-candies":
        case "nature-mints":
            if (!__item_runtime_rec_has_group(_rec, "stat_training")) __item_runtime_add_group(_rec, "stat_training");
            break;
        case "medicine":
        case "healing":
        case "pp-recovery":
        case "revival":
        case "status-cures":
            if (!__item_runtime_rec_has_any_group(_rec, ["medicine_hp","medicine_revive","medicine_status","medicine_pp","berry"])) __item_runtime_add_group(_rec, "medicine_misc");
            break;
        case "in-a-pinch":
        case "picky-healing":
        case "type-protection":
        case "baking-only":
        case "catching-bonus":
            __item_runtime_add_group(_rec, "berry");
            __item_runtime_add_group(_rec, "held_consumable");
            __item_runtime_add_group(_rec, "berry_trigger");
            __item_runtime_add_action(_rec, "held_auto_use", "berry_trigger", { identifier:_ident });
            break;
        case "evolution":
            __item_runtime_add_group(_rec, "evolution_item");
            __item_runtime_add_action(_rec, "use_target", "try_evolution", {});
            break;
        case "spelunking":
            __item_runtime_add_group(_rec, "fossil_restore");
            __item_runtime_add_action(_rec, "field_use", "restore_fossil_species", { identifier:_ident });
            break;
        case "held-items":
        case "bad-held-items":
        case "training":
        case "scarves":
            __item_runtime_add_group(_rec, "held_passive_registered");
            __item_runtime_add_action(_rec, "held_auto_use", "held_item_passive", { identifier:_ident });
            break;
        case "choice":
            if (!__item_runtime_rec_has_group(_rec, "choice_item")) __item_runtime_add_group(_rec, "choice_item_pending");
            break;
        case "plates":
            __item_runtime_add_group(_rec, "plate");
            if (!__item_runtime_rec_has_group(_rec, "held_type_boost")) __item_runtime_add_group(_rec, "held_type_boost_pending");
            break;
        case "type-enhancement":
        case "jewels":
            if (!__item_runtime_rec_has_group(_rec, "held_type_boost")) __item_runtime_add_group(_rec, "held_type_boost_pending");
            break;
        case "species-specific":
        case "memories":
            __item_runtime_add_group(_rec, "form_or_type_change_item");
            __item_runtime_add_action(_rec, "form_type_context", "species_specific_type_item", { identifier:_ident });
            break;
        case "mega-stones":
            __item_runtime_add_group(_rec, "mega_stone");
            __item_runtime_add_action(_rec, "transformation", "mega_evolution", { identifier:_ident });
            break;
        case "z-crystals":
            __item_runtime_add_group(_rec, "z_crystal");
            __item_runtime_add_action(_rec, "transformation", "z_move", { identifier:_ident });
            break;
        case "dynamax-crystals":
            __item_runtime_add_group(_rec, "dynamax_crystal");
            __item_runtime_add_action(_rec, "field_use", "raid_access_key", { identifier:_ident });
            break;
        case "all-machines":
            __item_runtime_add_group(_rec, "machine");
            __item_runtime_add_group(_rec, "teach_move_item");
            break;
        case "all-mail":
            __item_runtime_add_group(_rec, "mail");
            break;
        case "flutes":
            if (!__item_runtime_rec_has_any_group(_rec, ["medicine_status","battle_item"])) __item_runtime_add_group(_rec, "battle_field_tool_pending");
            break;
        case "event-items":
        case "gameplay":
        case "plot-advancement":
        case "apricorn-box":
        case "data-cards":
            __item_runtime_add_group(_rec, "key_item");
            __item_runtime_add_group(_rec, "key_item_registered");
            __item_runtime_add_action(_rec, "field_use", "key_item_context", { identifier:_ident });
            break;
        case "unused":
            __item_runtime_add_group(_rec, "key_item");
            __item_runtime_add_group(_rec, "unused_item");
            break;
        case "mulch":
        case "curry-ingredients":
        case "sandwich-ingredients":
        case "picnic":
            __item_runtime_add_group(_rec, "crafting_material");
            __item_runtime_add_group(_rec, "picnic_or_crafting_item");
            __item_runtime_add_action(_rec, "field_use", "crafting_inventory_component", { identifier:_ident });
            break;
        case "tera-shard":
            __item_runtime_add_group(_rec, "tera_shard");
            break;
        case "tm-materials":
            __item_runtime_add_group(_rec, "tm_material");
            __item_runtime_add_group(_rec, "crafting_material");
            break;
        case "loot":
        case "collectibles":
        case "dex-completion":
        case "other":
            __item_runtime_add_group(_rec, "collectible_or_misc_item");
            break;
    }

    if (string_length(_pocket) > 0){
        if (_pocket == "pokeballs"){
            __item_runtime_add_group(_rec, "poke_ball");
            if (!is_undefined(__item_runtime_add_action)) __item_runtime_add_action(_rec, "battle_use", "catch_attempt", {});
        } else if (_pocket == "machines"){
            __item_runtime_add_group(_rec, "machine");
            __item_runtime_add_group(_rec, "teach_move_item");
        } else if (_pocket == "mail"){
            __item_runtime_add_group(_rec, "mail");
        } else if (_pocket == "key"){
            __item_runtime_add_group(_rec, "key_item");
        } else if (_pocket == "battle"){
            if (!__item_runtime_rec_has_any_group(_rec, ["battle_item","crafting_material"])){
                __item_runtime_add_group(_rec, "battle_item");
                __item_runtime_add_action(_rec, "battle_use", "battle_item_registered", { identifier:_ident });
            }
        } else if (_pocket == "berries"){
            __item_runtime_add_group(_rec, "berry");
            __item_runtime_add_group(_rec, "held_consumable");
            __item_runtime_add_group(_rec, "berry_trigger");
            __item_runtime_add_action(_rec, "held_auto_use", "berry_trigger", { identifier:_ident });
        }
    }

    var _groups_now = variable_struct_exists(_rec, "groups") && is_array(variable_struct_get(_rec, "groups")) ? variable_struct_get(_rec, "groups") : [];
    if (array_length(_groups_now) <= 0){
        __item_runtime_add_group(_rec, "item_runtime_grouped");
        __item_runtime_add_group(_rec, "item_runtime_effect_pending");
    }
}

function __item_runtime_classify_known(_rec, _item_id){
    var _ident = __item_runtime_safe_identifier(_item_id);
    var _text = __item_runtime_prose_text(_item_id);

    __item_runtime_add_effect_groups(_rec, _item_id);

    if (__item_runtime_has_text(_ident, "ball")){
        __item_runtime_add_group(_rec, "poke_ball");
        __item_runtime_add_action(_rec, "battle_use", "catch_attempt", {});
    }
    if (__item_runtime_has_text(_ident, "berry")){
        __item_runtime_add_group(_rec, "berry");
        __item_runtime_add_group(_rec, "held_consumable");
        __item_runtime_add_action(_rec, "held_auto_use", "berry_trigger", { identifier:_ident });
    }
    if (__item_runtime_has_text(_ident, "mail")) __item_runtime_add_group(_rec, "mail");
    if (__item_runtime_has_text(_ident, "fossil")){
        __item_runtime_add_group(_rec, "fossil_restore");
        __item_runtime_add_action(_rec, "field_use", "restore_fossil_species", { identifier:_ident });
    }

    switch (_ident){
        case "cheri-berry":
            __item_runtime_add_action(_rec, "held_auto_use", "cure_status", { status:"paralysis" });
            break;
        case "chesto-berry":
            __item_runtime_add_action(_rec, "held_auto_use", "cure_status", { status:"sleep" });
            break;
        case "pecha-berry":
            __item_runtime_add_action(_rec, "held_auto_use", "cure_status", { status:["poison","toxic"] });
            break;
        case "rawst-berry":
            __item_runtime_add_action(_rec, "held_auto_use", "cure_status", { status:"burn" });
            break;
        case "aspear-berry":
            __item_runtime_add_action(_rec, "held_auto_use", "cure_status", { status:"freeze" });
            break;
        case "persim-berry":
            __item_runtime_add_action(_rec, "held_auto_use", "cure_status", { status:"confusion" });
            break;
        case "lum-berry":
            __item_runtime_add_action(_rec, "held_auto_use", "cure_status", { status:["poison","toxic","burn","freeze","paralysis","paralyze","sleep","confusion"] });
            break;
        case "oran-berry":
            __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_heal_flat", { hp_fraction:0.5, amount:10 });
            break;
        case "sitrus-berry":
            __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_heal_fraction", { hp_fraction:0.5, numerator:1, denominator:4 });
            break;
        case "figy-berry":
        case "wiki-berry":
        case "mago-berry":
        case "aguav-berry":
        case "iapapa-berry":
            __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_heal_fraction", { hp_fraction:0.25, numerator:1, denominator:3 });
            break;
        case "occa-berry":    __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"fire", multiplier:0.5, consume:true }); break;
        case "passho-berry":  __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"water", multiplier:0.5, consume:true }); break;
        case "wacan-berry":   __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"electric", multiplier:0.5, consume:true }); break;
        case "rindo-berry":   __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"grass", multiplier:0.5, consume:true }); break;
        case "yache-berry":   __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"ice", multiplier:0.5, consume:true }); break;
        case "chople-berry":  __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"fighting", multiplier:0.5, consume:true }); break;
        case "kebia-berry":   __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"poison", multiplier:0.5, consume:true }); break;
        case "shuca-berry":   __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"ground", multiplier:0.5, consume:true }); break;
        case "coba-berry":    __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"flying", multiplier:0.5, consume:true }); break;
        case "payapa-berry":  __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"psychic", multiplier:0.5, consume:true }); break;
        case "tanga-berry":   __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"bug", multiplier:0.5, consume:true }); break;
        case "charti-berry":  __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"rock", multiplier:0.5, consume:true }); break;
        case "kasib-berry":   __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"ghost", multiplier:0.5, consume:true }); break;
        case "haban-berry":   __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"dragon", multiplier:0.5, consume:true }); break;
        case "colbur-berry":  __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"dark", multiplier:0.5, consume:true }); break;
        case "babiri-berry":  __item_runtime_add_action(_rec, "damage_taken", "resist_super_effective_type", { type:"steel", multiplier:0.5, consume:true }); break;
        case "chilan-berry":  __item_runtime_add_action(_rec, "damage_taken", "resist_type", { type:"normal", multiplier:0.5, consume:true }); break;
        case "liechi-berry": __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_stage", { hp_fraction:0.25, stat:"atk", delta:1 }); break;
        case "ganlon-berry": __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_stage", { hp_fraction:0.25, stat:"def", delta:1 }); break;
        case "salac-berry":  __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_stage", { hp_fraction:0.25, stat:"spe", delta:1 }); break;
        case "petaya-berry": __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_stage", { hp_fraction:0.25, stat:"spa", delta:1 }); break;
        case "apicot-berry": __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_stage", { hp_fraction:0.25, stat:"spd", delta:1 }); break;
        case "lansat-berry": __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_crit", { hp_fraction:0.25, stages:2 }); break;
        case "starf-berry":  __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_random_stage", { hp_fraction:0.25, delta:2 }); break;
        case "enigma-berry": __item_runtime_add_action(_rec, "held_auto_use", "after_super_effective_heal", { numerator:1, denominator:4 }); break;
        case "micle-berry":  __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_next_accuracy", { hp_fraction:0.25, multiplier:1.2 }); break;
        case "custap-berry": __item_runtime_add_action(_rec, "held_auto_use", "hp_threshold_next_priority", { hp_fraction:0.25 }); break;
        case "jaboca-berry": __item_runtime_add_action(_rec, "after_damage_taken", "retaliate_damage_class_fraction", { damage_class:2, numerator:1, denominator:8 }); break;
        case "rowap-berry":  __item_runtime_add_action(_rec, "after_damage_taken", "retaliate_damage_class_fraction", { damage_class:3, numerator:1, denominator:8 }); break;
        case "leftovers":
            __item_runtime_add_group(_rec, "held_end_turn_heal");
            __item_runtime_add_action(_rec, "end_turn", "heal_max_hp_fraction", { numerator:1, denominator:16, message:"%s restored a little HP using its Leftovers!" });
            break;
        case "black-sludge":
            __item_runtime_add_group(_rec, "held_end_turn_poison");
            __item_runtime_add_action(_rec, "end_turn", "poison_heal_else_damage_fraction", { numerator:1, denominator:16 });
            break;
        case "shell-bell":
            __item_runtime_add_group(_rec, "held_after_damage_heal");
            __item_runtime_add_action(_rec, "after_damage", "heal_damage_fraction", { numerator:1, denominator:8 });
            break;
        case "life-orb":
            __item_runtime_add_group(_rec, "held_damage_boost_recoil");
            __item_runtime_add_action(_rec, "damage_dealt", "multiplier", { multiplier:1.3 });
            __item_runtime_add_action(_rec, "after_damage", "recoil_max_hp_fraction", { numerator:1, denominator:10 });
            break;
        case "choice-band":
            __item_runtime_add_group(_rec, "choice_item");
            __item_runtime_add_action(_rec, "stat_calc", "stat_multiplier", { stat:"atk", multiplier:1.5 });
            __item_runtime_add_action(_rec, "move_select", "lock_first_move", {});
            break;
        case "choice-specs":
            __item_runtime_add_group(_rec, "choice_item");
            __item_runtime_add_action(_rec, "stat_calc", "stat_multiplier", { stat:"spa", multiplier:1.5 });
            __item_runtime_add_action(_rec, "move_select", "lock_first_move", {});
            break;
        case "choice-scarf":
            __item_runtime_add_group(_rec, "choice_item");
            __item_runtime_add_action(_rec, "stat_calc", "stat_multiplier", { stat:"spe", multiplier:1.5 });
            __item_runtime_add_action(_rec, "move_select", "lock_first_move", {});
            break;
        case "focus-sash":
            __item_runtime_add_group(_rec, "held_survive_ko");
            __item_runtime_add_action(_rec, "before_faint", "survive_full_hp_once", { hp:1 });
            break;
        case "focus-band":
            __item_runtime_add_group(_rec, "held_survive_ko");
            __item_runtime_add_action(_rec, "before_faint", "chance_survive", { chance:10, hp:1 });
            break;
        case "quick-claw":
            __item_runtime_add_group(_rec, "held_priority_item");
            __item_runtime_add_action(_rec, "move_select", "move_first_chance", { chance:20, bonus:0.5 });
            break;
        case "lagging-tail":
        case "full-incense":
            __item_runtime_add_group(_rec, "held_priority_item");
            __item_runtime_add_action(_rec, "move_select", "move_last_in_priority_bracket", {});
            break;
        case "light-clay":
            __item_runtime_add_group(_rec, "held_screen_extender");
            __item_runtime_add_action(_rec, "screen_duration", "set_turns", { turns:8 });
            break;
        case "terrain-extender":
            __item_runtime_add_group(_rec, "held_terrain_extender");
            __item_runtime_add_action(_rec, "terrain_duration", "set_turns", { turns:8 });
            break;
        case "heat-rock":
            __item_runtime_add_group(_rec, "held_weather_rock");
            __item_runtime_add_action(_rec, "weather_duration", "set_turns_for_weather", { weather:"sun", turns:8 });
            break;
        case "damp-rock":
            __item_runtime_add_group(_rec, "held_weather_rock");
            __item_runtime_add_action(_rec, "weather_duration", "set_turns_for_weather", { weather:"rain", turns:8 });
            break;
        case "smooth-rock":
            __item_runtime_add_group(_rec, "held_weather_rock");
            __item_runtime_add_action(_rec, "weather_duration", "set_turns_for_weather", { weather:"sandstorm", turns:8 });
            break;
        case "icy-rock":
            __item_runtime_add_group(_rec, "held_weather_rock");
            __item_runtime_add_action(_rec, "weather_duration", "set_turns_for_weather", { weather:"hail", turns:8 });
            __item_runtime_add_action(_rec, "weather_duration", "set_turns_for_weather", { weather:"snow", turns:8 });
            break;
        case "everstone":
            __item_runtime_add_group(_rec, "held_breeding_nature");
            __item_runtime_add_group(_rec, "held_prevent_evolution");
            __item_runtime_add_action(_rec, "breeding", "pass_nature", { chance:50 });
            break;
        case "destiny-knot":
            __item_runtime_add_group(_rec, "held_breeding_iv");
            __item_runtime_add_action(_rec, "breeding", "inherit_extra_ivs", { inherited_iv_count:5 });
            break;
        case "ability-urge":
            __item_runtime_add_group(_rec, "battle_item");
            __item_runtime_add_action(_rec, "battle_use", "activate_ally_ability", {});
            break;
        case "item-drop":
            __item_runtime_add_group(_rec, "battle_item");
            __item_runtime_add_action(_rec, "battle_use", "drop_ally_held_item", {});
            break;
        case "item-urge":
            __item_runtime_add_group(_rec, "battle_item");
            __item_runtime_add_action(_rec, "battle_use", "activate_ally_held_item", {});
            break;
        case "reset-urge":
            __item_runtime_add_group(_rec, "battle_item");
            __item_runtime_add_action(_rec, "battle_use", "reset_ally_stat_stages", {});
            break;
        case "max-mushrooms":
            __item_runtime_add_group(_rec, "crafting_material");
            __item_runtime_add_group(_rec, "gigantamax_soup_component");
            __item_runtime_add_action(_rec, "field_use", "crafting_inventory_component", { identifier:_ident });
            break;
    }

    if (_ident == "exp-share" || _ident == "lucky-egg" || _ident == "amulet-coin" || _ident == "luck-incense" || _ident == "soothe-bell"){
        __item_runtime_add_group(_rec, "held_overworld_reward");
        __item_runtime_add_action(_rec, "reward_calc", "reward_modifier", { identifier:_ident });
    }

    if (__item_runtime_has_text(_ident, "mega-stone") || __item_runtime_has_text(_text, "mega evolve")){
        __item_runtime_add_group(_rec, "mega_stone");
        __item_runtime_add_action(_rec, "transformation", "mega_evolution", { identifier:_ident });
    }
    if (__item_runtime_has_text(_ident, "-ium-z") || __item_runtime_has_text(_ident, "-z") && __item_runtime_has_text(_text, "z-move")){
        __item_runtime_add_group(_rec, "z_crystal");
        __item_runtime_add_action(_rec, "transformation", "z_move", { identifier:_ident });
    }

    __item_runtime_classify_type_boost(_rec, _ident, _text);
    __item_runtime_classify_category_fallback(_rec, _item_id, _ident, _text);
}

function data_load_item_runtime_structs(){
    if (!variable_global_exists("_items") || !is_array(global._items)){
        global._item_runtime = [];
        global._item_runtime_groups = {};
        data_debug("[DATA][item_runtime] _items missing");
        return;
    }

    var _max = array_length(global._items) - 1;
    global._item_runtime = [];
    array_resize(global._item_runtime, _max + 1);
    global._item_runtime_groups = {};

    var _rows = 0;
    var _converted = 0;
    var _with_actions = 0;
    var _pending = 0;
    var _runtime_consumed = 0;
    var _group_counts = {};
    var _pending_group_counts = {};
    var _hook_counts = {};
    var _consumed_groups = [
        "medicine_hp","medicine_revive","medicine_status","medicine_pp","stat_training","battle_item","field_encounter","battle_escape","evolution_item",
        "medicine_misc","poke_ball","held_screen_extender","held_terrain_extender","held_weather_rock","held_breeding_nature","held_breeding_iv",
        "held_type_boost","held_type_gem","choice_item","held_damage_boost_recoil","held_after_damage_heal","held_end_turn_heal","held_end_turn_poison","held_survive_ko",
        "held_passive_registered","held_priority_item","berry_trigger","fossil_restore","key_item","key_item_registered","crafting_material","picnic_or_crafting_item","tera_shard","dynamax_crystal","mega_stone","z_crystal","form_or_type_change_item","evolution_item"
    ];
    var _hook_keys = ["use_target","battle_use","field_use","held_auto_use","damage_dealt","damage_taken","end_turn","after_damage","after_damage_taken","before_faint","screen_duration","terrain_duration","weather_duration","move_select","stat_calc","reward_calc","breeding","form_type_context","transformation"];
    for (var _iid = 1; _iid <= _max; ++_iid){
        var _it = global._items[_iid];
        if (!is_struct(_it)) continue;
        var _rec = {
            item_id:_iid,
            identifier:__item_runtime_safe_identifier(_iid),
            display_name:__item_runtime_safe_name(_iid),
            groups:[],
            actions:{}
        };
        __item_runtime_classify_known(_rec, _iid);

        var _groups = variable_struct_get(_rec, "groups");
        var _has_pending_group = false;
        var _is_runtime_consumed = false;
        for (var _g = 0; _g < array_length(_groups); ++_g){
            __item_runtime_group_push(_groups[_g], _iid);
            __item_runtime_tracker_bump(_group_counts, _groups[_g]);
            if (string_pos("pending", string(_groups[_g])) > 0) {
                _has_pending_group = true;
                __item_runtime_tracker_bump(_pending_group_counts, _groups[_g]);
            }
            for (var _cg = 0; _cg < array_length(_consumed_groups); ++_cg){
                if (string(_groups[_g]) == _consumed_groups[_cg]){
                    _is_runtime_consumed = true;
                    break;
                }
            }
        }
        var _actions = variable_struct_get(_rec, "actions");
        var _action_total = 0;
        if (is_struct(_actions)){
            for (var _hk = 0; _hk < array_length(_hook_keys); ++_hk){
                var _hook = _hook_keys[_hk];
                if (variable_struct_exists(_actions, _hook) && is_array(variable_struct_get(_actions, _hook))){
                    var _hook_arr = variable_struct_get(_actions, _hook);
                    if (array_length(_hook_arr) > 0){
                        _action_total += array_length(_hook_arr);
                        __item_runtime_tracker_bump(_hook_counts, _hook);
                    }
                }
            }
        }
        global._item_runtime[_iid] = _rec;
        _rows++;
        if (array_length(_groups) > 0 || _action_total > 0) _converted++;
        if (_action_total > 0) _with_actions++;
        if (_has_pending_group) _pending++;
        if (_is_runtime_consumed) _runtime_consumed++;
    }
    global._item_runtime_tracker = {
        total_items:_rows,
        converted_items:_converted,
        unconverted_items:max(0, _rows - _converted),
        action_items:_with_actions,
        pending_items:_pending,
        runtime_consumed_items:_runtime_consumed,
        group_counts:_group_counts,
        pending_group_counts:_pending_group_counts,
        hook_counts:_hook_counts
    };
    data_debug("[DATA][item_runtime] rows=" + string(_rows) + ", converted=" + string(_converted) + ", unconverted=" + string(max(0, _rows - _converted)) + ", action_items=" + string(_with_actions) + ", pending=" + string(_pending) + ", runtime_consumed=" + string(_runtime_consumed));
    try {
        var _pending_names = variable_struct_get_names(_pending_group_counts);
        var _pending_msg = "";
        for (var _pgi = 0; _pgi < array_length(_pending_names); ++_pgi){
            var _pgname = _pending_names[_pgi];
            if (string_length(_pending_msg) > 0) _pending_msg += ", ";
            _pending_msg += string(_pgname) + "=" + string(variable_struct_get(_pending_group_counts, _pgname));
        }
        data_debug("[DATA][item_runtime][pending_groups] " + _pending_msg);
    } catch (e_item_pending_groups_debug) {}
}

function item_runtime_ensure_loaded(){
    if (!variable_global_exists("_item_runtime") || !is_array(global._item_runtime)){
        if (is_undefined(data_load_item_runtime_structs) == false) data_load_item_runtime_structs();
    }
}

function item_runtime_get(_item_id){
    item_runtime_ensure_loaded();
    if (!is_real(_item_id)) return undefined;
    var _iid = floor(_item_id);
    if (_iid <= 0 || !variable_global_exists("_item_runtime") || !is_array(global._item_runtime) || _iid >= array_length(global._item_runtime)) return undefined;
    return global._item_runtime[_iid];
}

function item_runtime_has_group(_item_id, _group){
    var _rec = item_runtime_get(_item_id);
    if (!is_struct(_rec) || !variable_struct_exists(_rec, "groups")) return false;
    var _groups = variable_struct_get(_rec, "groups");
    if (!is_array(_groups)) return false;
    var _g = string_lower(string(_group));
    for (var _i = 0; _i < array_length(_groups); ++_i){ if (string(_groups[_i]) == _g) return true; }
    return false;
}

function item_runtime_actions(_item_id, _hook){
    var _rec = item_runtime_get(_item_id);
    if (!is_struct(_rec) || !variable_struct_exists(_rec, "actions")) return [];
    var _actions = variable_struct_get(_rec, "actions");
    if (!is_struct(_actions)) return [];
    var _h = string_lower(string(_hook));
    if (variable_struct_exists(_actions, _h) && is_array(variable_struct_get(_actions, _h))) return variable_struct_get(_actions, _h);
    return [];
}

function item_runtime_actor_held_item_id(_actor){
    if (!is_struct(_actor)) return -1;
    if (variable_struct_exists(_actor, "held_item_id") && is_real(variable_struct_get(_actor, "held_item_id"))) return floor(variable_struct_get(_actor, "held_item_id"));
    if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
        var _mon = variable_struct_get(_actor, "mon");
        if (variable_struct_exists(_mon, "held_item_id") && is_real(variable_struct_get(_mon, "held_item_id"))) return floor(variable_struct_get(_mon, "held_item_id"));
    }
    return -1;
}

function item_runtime_actor_held_enabled(_actor){
    if (!is_struct(_actor)) return false;
    if (!is_undefined(__battle_meta_held_items_enabled)){
        try { if (__battle_meta_held_items_enabled(_actor) == false) return false; } catch (e_held_runtime_enabled) {}
    }
    return item_runtime_actor_held_item_id(_actor) > 0;
}

function item_runtime_actor_has_held_group(_actor, _group){
    if (!item_runtime_actor_held_enabled(_actor)) return false;
    return item_runtime_has_group(item_runtime_actor_held_item_id(_actor), _group);
}

function item_runtime_actor_held_actions(_actor, _hook){
    if (!item_runtime_actor_held_enabled(_actor)) return [];
    return item_runtime_actions(item_runtime_actor_held_item_id(_actor), _hook);
}
