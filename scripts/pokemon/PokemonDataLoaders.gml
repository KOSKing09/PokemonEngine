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
}
