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
        // effect_id/effect_chance fallback: many dumps lack headers; use PokeAPI column indices if headers absent
        // PokeAPI moves.csv columns (0-based):
        // 0=id, 1=identifier, 2=generation_id, 3=type_id, 4=power, 5=pp, 6=accuracy, 7=priority, 8=damage_class_id, 9=effect_id?, 10=effect_id, 11=effect_chance, ...
        // Some exports shift effect_id to index 10; use 10/11 as safe defaults when headers missing.
        var _eff  = (ci_effect >= 0) ? __to_int_safe(__grid(g, ci_effect, _r, 0), 0) : __to_int_safe(__grid(g, 10, _r, 0), 0);
        var _effc = (ci_effect_chance >= 0) ? __to_int_safe(__grid(g, ci_effect_chance, _r, 0), 0) : __to_int_safe(__grid(g, 11, _r, 0), 0);
        global._moves[_id] = { id:_id, identifier:_ident, type_id:_type, power:_power, pp:_pp, priority:_prio, damage_class_id:_dcls, effect_id:_eff, effect_chance:_effc };
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

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @function data_load_species_moves_structs()
/// @description Loads Pokémon move data from JSON and builds per-species move arrays
function data_load_species_moves_structs() {
    var path = working_directory + "/data/json/_pokemon_moves";

    if (!file_exists(path)) {
        show_debug_message("[DATA][pokemon_moves] SKIP: " + path);
        global._species_moves = [];
        return;
    }

    var _file = file_text_open_read(path);
    var _txt_json = file_text_read_string(_file);
    file_text_close(_file);

    // --- Parse JSON into array of structs ---
    var json_data = json_parse(_txt_json);
    if (!is_array(json_data)) {
        show_debug_message("[DATA][pokemon_moves] INVALID JSON: " + path);
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

    show_debug_message(
        "[DATA][pokemon_moves] rows=" + string(total_rows)
        + ", species=" + string(non_empty_species)
    );
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
    data_load_species_abilities_structs();
    data_load_species_moves_structs();
    // Types: load core type list and per-species mappings
    if (is_undefined(data_load_types_structs) == false) data_load_types_structs();
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
    // Load optional move meta mapping (ailments + chances) for battle wiring
    if (is_undefined(data_load_move_meta_structs) == false) data_load_move_meta_structs();
    // Load optional move stat changes mapping (temporary in-battle stat stage changes)
    if (is_undefined(data_load_move_meta_stat_changes_structs) == false) data_load_move_meta_stat_changes_structs();
    // Synthesize move_meta entries from moves.effect_id where possible so the battle
    // system can rely on global._move_meta for recoil/drain/multi-hit effects.
    if (is_undefined(data_map_move_effects_to_meta) == false) data_map_move_effects_to_meta();
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
        var s_lower = string_lower(s);
        var effects = [];
        var matched = false;
        var scope_hint_pp = "single";
        if (string_pos("each move", s_lower) > 0 || string_pos("all moves", s_lower) > 0 || string_pos("every move", s_lower) > 0 || string_pos("all of its moves", s_lower) > 0 || string_pos("all four moves", s_lower) > 0)
            scope_hint_pp = "all";

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
        if (string_pos("cures any status ailment", s_lower) > 0){ effects[ array_length(effects) ] = { type:"cure_all", params:{} }; global._item_effects[iid] = effects; continue; }

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
