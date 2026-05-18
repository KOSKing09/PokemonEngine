// Party name and nickname helpers (extracted from party_system.gml)

#macro PARTY_NICKNAMES_ENABLED 1

// Return the display name for a mon, preferring `nickname` then `name`,
// falling back to species name via `scr_poke_name_by_id`.
function __party_impl_mon_display_name(_mon) {
    if (is_undefined(_mon)) return "???";

    if (is_struct(_mon)){
        if (variable_struct_exists(_mon, "mon") && is_struct(variable_struct_get(_mon, "mon"))) _mon = variable_struct_get(_mon, "mon");
        else if (variable_struct_exists(_mon, "pokemon") && is_struct(variable_struct_get(_mon, "pokemon"))) _mon = variable_struct_get(_mon, "pokemon");
    }

    if (!is_struct(_mon)) return "???";

    if (variable_struct_exists(_mon,"nickname")){
        var _nick = variable_struct_get(_mon, "nickname");
        if (is_string(_nick) && string_length(string_trim(_nick)) > 0 && string_lower(string_trim(_nick)) != "undefined") return string_trim(_nick);
    }

    if (variable_struct_exists(_mon,"name")){
        var _name = variable_struct_get(_mon, "name");
        if (is_string(_name) && string_length(string_trim(_name)) > 0 && string_lower(string_trim(_name)) != "undefined") return string_trim(_name);
    }

    var __sid = -1;
    if (variable_struct_exists(_mon,"species_id") && is_real(_mon.species_id)) __sid = _mon.species_id;
    else if (variable_struct_exists(_mon,"id") && is_real(_mon.id))            __sid = _mon.id;
    else if (variable_struct_exists(_mon,"species") && is_real(_mon.species))  __sid = _mon.species;
    else if (variable_struct_exists(_mon,"_id") && is_real(_mon._id))          __sid = _mon._id;

    if (__sid > 0 && !is_undefined(scr_poke_name_by_id)) return scr_poke_name_by_id(__sid);
    return "???";
}

// Ensure that a mon struct has canonical `name` and `nickname` fields.
// Mutates and returns the mon.
function __party_impl_party_mon_ensure_name(_mon) {
    if (is_undefined(_mon)) return _mon;
    if (!is_struct(_mon)) return _mon;
    if (!variable_struct_exists(_mon,"nickname")) _mon.nickname = undefined;
    if (!variable_struct_exists(_mon,"name") || !is_string(_mon.name) || string_length(_mon.name) <= 0) {
        var __sid2 = -1;
        if (variable_struct_exists(_mon,"species_id") && is_real(_mon.species_id)) __sid2 = _mon.species_id;
        else if (variable_struct_exists(_mon,"id") && is_real(_mon.id))             __sid2 = _mon.id;
        else if (variable_struct_exists(_mon,"species") && is_real(_mon.species))   __sid2 = _mon.species;
        else if (variable_struct_exists(_mon,"_id") && is_real(_mon._id))           __sid2 = _mon._id;
        _mon.name = (__sid2 > 0 && !is_undefined(scr_poke_name_by_id)) ? scr_poke_name_by_id(__sid2) : "???";
    }
    return _mon;
}

// Apply naming support (ensure names/nicknames) to all mons in player's party.
function __party_impl_party_apply_name_support(_pid) {
    if (!PARTY_NICKNAMES_ENABLED) return;
    var __P = party_ensure(_pid);
    if (is_undefined(__P)) return;
    var __mons = __P.mons;
    var __n = array_length(__mons);
    for (var __i=0; __i<__n; ++__i) {
        var __m = __mons[__i];
        if (!is_undefined(__m)) {
            __m = __party_impl_party_mon_ensure_name(__m);
            __mons[__i] = __m;
        }
    }
    __P.mons = __mons;
}

// Set or clear a mon's nickname in the party. Returns true on success.
function __party_impl_party_set_nickname(_pid, _index, _nick) {
    if (!PARTY_NICKNAMES_ENABLED) return false;
    var __P = party_ensure(_pid);
    if (is_undefined(__P)) return false;
    var __mons = __P.mons;
    if (_index < 0 || _index >= array_length(__mons)) return false;
    var __m = __mons[_index];
    if (is_undefined(__m)) return false;
    __m = __party_impl_party_mon_ensure_name(__m);
    if (is_string(_nick) && string_length(string_trim(_nick)) > 0) __m.nickname = string_trim(_nick);
    else __m.nickname = undefined;
    __mons[_index] = __m;
    __P.mons = __mons;
    return true;
}

// Ensure party naming support is applied and return the party struct.
function __party_impl_party_ensure_named(_pid) {
    var __P = party_ensure(_pid);
    __party_impl_party_apply_name_support(_pid);
    return __P;
}

// Helper used by tests: apply name support for battle-prepared parties.
function __party_impl_battle_test_prepare_names(_pid) {
    __party_impl_party_apply_name_support(_pid);
}
