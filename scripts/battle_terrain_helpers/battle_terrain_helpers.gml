// Terrain helpers extracted from battle_system to keep primary script lighter.

if (is_undefined(__battle_get_terrain_state)){
    function __battle_get_terrain_state(_pid){
        try {
            var field = __battle_field_ensure(_pid);
            if (is_struct(field) && variable_struct_exists(field, "terrain")) return variable_struct_get(field, "terrain");
        } catch (e) {}
        return undefined;
    }
    try { variable_global_set("__battle_get_terrain_state", __battle_get_terrain_state); } catch (e_set_terrain_state) { global.__battle_get_terrain_state = __battle_get_terrain_state; }
}

if (is_undefined(__battle_get_terrain_id)){
    function __battle_get_terrain_id(_pid){
        var terr = __battle_get_terrain_state(_pid);
        if (is_struct(terr) && variable_struct_exists(terr, "id")) return string_lower(string(variable_struct_get(terr, "id")));
        return "";
    }
}

if (is_undefined(__battle_field_set_terrain)){
    function __battle_field_set_terrain(_pid, _terrain_id, _opts){
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B)) return undefined;
        var field = __battle_field_ensure(_pid);
        if (!is_struct(field)) return undefined;
        var tid = string_lower(string(_terrain_id));
        if (string_length(tid) <= 0){
            variable_struct_set(field, "terrain", undefined);
            return undefined;
        }
        var opts = is_struct(_opts) ? _opts : {};
        var turns = 5;
        if (is_struct(opts) && variable_struct_exists(opts, "turns") && is_real(variable_struct_get(opts, "turns"))) turns = max(0, floor(variable_struct_get(opts, "turns")));
        else if (is_struct(opts) && variable_struct_exists(opts, "duration") && is_real(variable_struct_get(opts, "duration"))) turns = max(0, floor(variable_struct_get(opts, "duration")));
        var infinite = (is_struct(opts) && variable_struct_exists(opts, "infinite") && variable_struct_get(opts, "infinite") == true);
        var source = undefined;
        if (is_struct(opts) && variable_struct_exists(opts, "source")) source = variable_struct_get(opts, "source");
        var terr_struct = { id: tid, turns: turns, infinite: infinite, source: source };
        if (is_struct(opts) && variable_struct_exists(opts, "message")) variable_struct_set(terr_struct, "message", variable_struct_get(opts, "message"));
        variable_struct_set(field, "terrain", terr_struct);
        try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_meta_terr) {}
        return terr_struct;
    }
}

if (is_undefined(__battle_field_clear_terrain)){
    function __battle_field_clear_terrain(_pid){
        var field = __battle_field_ensure(_pid);
        if (!is_struct(field)) return undefined;
        var prev = (variable_struct_exists(field, "terrain") ? variable_struct_get(field, "terrain") : undefined);
        variable_struct_set(field, "terrain", undefined);
        return prev;
    }
    try { variable_global_set("__battle_field_clear_terrain", __battle_field_clear_terrain); } catch (e_set_clear_terrain) { global.__battle_field_clear_terrain = __battle_field_clear_terrain; }
}
