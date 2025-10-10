// ============================================================================
// PokemonIndex_STRUCTS.gml  (arrays only)
// Builds:
//  - global._name_by_id[id] = "bulbasaur"
//  - global._name_list[] (sorted)
//  - global._id_list[]   (sorted; pairs with _name_list)
// Helpers:
//  - scr_poke_index_by_name(name) -> id (binary search)
//  - scr_poke_name_by_id(id) -> name
//  - scr_poke_stats(id) -> {hp,atk,def,spa,spd,spe}
//  - stat calcs (hp/stat) as before
// ============================================================================

/// scr_poke_index_build_simple_structs()  v1.1
/// Builds three arrays from global._pokemon (struct array from your CSV):
///   global._name_by_id[species_id] = "identifier"
///   global._name_list  = ["bulbasaur","ivysaur",... ]  (sorted a→z)
///   global._id_list    = [1, 2, ...]                   (same order as _name_list)
///
/// Requirements:
///   - global._pokemon is an array of structs with at least:
///       { _id: <real>, identifier: <string> }
function scr_poke_index_build_simple_structs()
{
    // validate source
    if (!(variable_global_exists("_pokemon") && is_array(global._pokemon))) {
        show_debug_message("[INDEX] _pokemon source missing (run data_load_all_structs() first).");
        return;
    }

    // fresh outputs
    global._name_by_id = [];
    global._name_list  = [];
    global._id_list    = [];

    var src = global._pokemon;
    var n   = array_length(src);

    // collect valid pairs
    var pairs = [];
    for (var i = 0; i < n; i++) {
        var rec = src[i];
        if (!is_struct(rec)) continue;

        var sid = (!is_undefined(rec._id) && is_real(rec._id)) ? rec._id : -1;
        var nam = (!is_undefined(rec.identifier)) ? string(rec.identifier) : "";

        if (sid > 0 && string_length(nam) > 0) {
            array_push(pairs, { idv: sid, n: string_lower(nam) });
        }
    }

    // insertion sort by name (case-insensitive); avoid string_compare()
    var m = array_length(pairs);
    for (var k = 1; k < m; k++) {
        var key = pairs[k];
        var j = k - 1;
        // compare using plain lexicographic operators on the pre-lowered strings
        while (j >= 0 && pairs[j].n > key.n) {
            pairs[j + 1] = pairs[j];
            j--;
        }
        pairs[j + 1] = key;
    }

    // fill outputs
    var max_id = 0;
    for (var t = 0; t < m; t++) {
        var p = pairs[t];
        global._name_by_id[p.idv] = p.n;   // sparse by species id
        array_push(global._name_list, p.n);
        array_push(global._id_list,   p.idv);
        if (p.idv > max_id) max_id = p.idv;
    }

    show_debug_message("[INDEX] built arrays: names=" + string(m) + " max_id=" + string(max_id));
}


/// scr_poke_index_by_name(name) -> species_id or -1   (structs, no string_compare)
/// Requires:
///   - global._name_list : array of lowercase identifiers, sorted A→Z
///   - global._id_list   : array of ids, same order/length as _name_list
function scr_poke_index_by_name(_name)
{
    if (is_undefined(_name)) return -1;
    if (!(variable_global_exists("_name_list") && is_array(global._name_list))) return -1;
    if (!(variable_global_exists("_id_list")   && is_array(global._id_list)))   return -1;

    var list = global._name_list;
    var ids  = global._id_list;
    var n    = array_length(list);
    if (n <= 0) return -1;

    var target = string_lower(string(_name));

    // standard binary search without string_compare()
    var lo = 0;
    var hi = n - 1;
    while (lo <= hi) {
        var mid = (lo + hi) div 2;
        var cur = list[mid];

        if (cur == target) return ids[mid];
        else if (cur > target) hi = mid - 1;   // lexicographic compare
        else                   lo = mid + 1;
    }
    return -1;
}


/// scr_poke_name_by_id(id) -> identifier (lowercase) or ""
function scr_poke_name_by_id(_sid)
{
    if (!is_real(_sid)) return "";
    if (!(variable_global_exists("_name_by_id") && is_array(global._name_by_id))) return "";
    var idx = floor(_sid);
    if (idx < 0 || idx >= array_length(global._name_by_id)) return "";
    var v = global._name_by_id[idx];
    return is_string(v) ? v : "";
}


function scr_poke_stats(_sid){
    if (!variable_global_exists("_poke_stats")) return {hp:45,atk:49,def:49,spa:65,spd:65,spe:45};
    if (_sid < 0 || _sid >= array_length(global._poke_stats)) return {hp:45,atk:49,def:49,spa:65,spd:65,spe:45};
    var s = global._poke_stats[_sid];
    return is_struct(s) ? s : {hp:45,atk:49,def:49,spa:65,spd:65,spe:45};
}

// STAT CALCS (same as before)
function scr_poke_calc_hp(_base, _lvl){
    var b = max(1, _base);
    var L = max(1, _lvl);
    return floor(((2*b)*L)/100) + L + 10;
}
function scr_poke_calc_stat(_base, _lvl){
    var b = max(1, _base);
    var L = max(1, _lvl);
    return floor(((2*b)*L)/100) + 5;
}
