// Battle field helpers extracted from battle_system.gml to keep the core script leaner.
// Provides struct initialization, hazard accessors, and legacy migration helpers.

// Return a default hazards struct for a battle side.
function __battle_field_default_hazards(){
    return { spikes: 0, toxic_spikes: 0, stealth_rock: false, sticky_web: false };
}

// Return default protective barrier counters for a battle side.
function __battle_field_default_barriers(){
    return { light_screen: 0, reflect: 0, aurora_veil: 0 };
}

// Construct and return a default side struct (hazards/barriers/statuses).
function __battle_field_side_defaults(){
    return {
        hazards: __battle_field_default_hazards(),
        barriers: __battle_field_default_barriers(),
        statuses: {},
        residuals: []
    };
}

// Construct and return the full default battlefield struct for a battle slot.
function __battle_field_defaults(){
    return {
        weather: __battle_field_default_weather_state(),
        terrain: undefined,
        statuses: {},
        sides: [__battle_field_side_defaults(), __battle_field_side_defaults()],
        residual_queue: [],
        tick_guard: { residual: false }
    };
}

// Convert an actor index to its side index (0 = player/left, 1 = opponent/right).
function __battle_field_side_index_for_actor(_actor_index){
    if (is_real(_actor_index) && _actor_index > 0) return 1;
    return 0;
}

// Return the opposing side index for a given actor index.
function __battle_field_side_index_for_opponent(_actor_index){
    return (__battle_field_side_index_for_actor(_actor_index) == 0) ? 1 : 0;
}

// Ensure and return the struct for a specific side inside a battlefield struct.
function __battle_field_get_side_struct(_field, _side_index){
    if (!is_struct(_field)) return undefined;
    if (!variable_struct_exists(_field, "sides") || !is_array(_field.sides)) _field.sides = [];
    var idx = (is_real(_side_index) ? floor(_side_index) : 0);
    if (idx < 0) idx = 0;
    if (array_length(_field.sides) <= idx) array_resize(_field.sides, idx + 1);
    for (var i = 0; i < array_length(_field.sides); ++i){
        if (!is_struct(_field.sides[i])) _field.sides[i] = __battle_field_side_defaults();
        else {
            var side = _field.sides[i];
            if (!variable_struct_exists(side, "hazards") || !is_struct(variable_struct_get(side, "hazards"))) variable_struct_set(side, "hazards", __battle_field_default_hazards());
            if (!variable_struct_exists(side, "barriers") || !is_struct(variable_struct_get(side, "barriers"))) variable_struct_set(side, "barriers", __battle_field_default_barriers());
            if (!variable_struct_exists(side, "statuses") || !is_struct(variable_struct_get(side, "statuses"))) variable_struct_set(side, "statuses", {});
            if (!variable_struct_exists(side, "residuals") || !is_array(variable_struct_get(side, "residuals"))) variable_struct_set(side, "residuals", []);
        }
    }
    return _field.sides[idx];
}

// Return the hazards struct for a battlefield side, creating defaults if needed.
function __battle_field_get_hazard_struct(_field, _side_index){
    var side_struct = __battle_field_get_side_struct(_field, _side_index);
    if (!is_struct(side_struct)) return undefined;
    if (!variable_struct_exists(side_struct, "hazards") || !is_struct(variable_struct_get(side_struct, "hazards"))) variable_struct_set(side_struct, "hazards", __battle_field_default_hazards());
    return variable_struct_get(side_struct, "hazards");
}

// Apply a legacy-style hazard value into the modern hazards struct.
function __battle_field_apply_legacy_hazard(_field, _side_index, _name, _value, _clamp){
    if (!is_struct(_field)) return;
    var hazards = __battle_field_get_hazard_struct(_field, _side_index);
    if (!is_struct(hazards)) return;
    var name = string_lower(string(_name));
    switch (name){
        case "spikes":
            var max_layers = (is_real(_clamp) ? max(0, floor(_clamp)) : 3);
            variable_struct_set(hazards, "spikes", clamp(max(0, floor(is_real(_value) ? _value : 0)), 0, max_layers));
            break;
        case "toxic_spikes":
            var max_t = (is_real(_clamp) ? max(0, floor(_clamp)) : 2);
            variable_struct_set(hazards, "toxic_spikes", clamp(max(0, floor(is_real(_value) ? _value : 0)), 0, max_t));
            break;
        case "stealth_rock":
            variable_struct_set(hazards, "stealth_rock", (is_real(_value) ? _value > 0 : (_value == true)));
            break;
        case "sticky_web":
            variable_struct_set(hazards, "sticky_web", (is_real(_value) ? _value > 0 : (_value == true)));
            break;
    }
}

// Migrate legacy battlefield keys stored on _B into the normalized _field.
function __battle_field_migrate_legacy(_B, _field){
    if (!is_struct(_B) || !is_struct(_field)) return;
    var migrated = (variable_struct_exists(_field, "_legacy_migrated") && variable_struct_get(_field, "_legacy_migrated") == true);
    if (migrated) return;

    if (variable_struct_exists(_B, "_weather")){
        var _legacy_weather = variable_struct_get(_B, "_weather");
        var _converted_weather = __battle_weather_state_normalize(_legacy_weather);
        variable_struct_set(_field, "weather", _converted_weather);
        variable_struct_set(_B, "_weather", undefined);
    }

    var has_terrain = false;
    var terr_id = "";
    if (variable_struct_exists(_B, "_terrain")){
        terr_id = variable_struct_get(_B, "_terrain");
        variable_struct_set(_B, "_terrain", undefined);
        has_terrain = true;
    }
    var terr_turns = 0;
    if (variable_struct_exists(_B, "_terrain_turns")){
        terr_turns = variable_struct_get(_B, "_terrain_turns");
        variable_struct_set(_B, "_terrain_turns", undefined);
        has_terrain = true;
    }
    if (has_terrain){
        var terr_struct = {
            id: string_lower(string(terr_id)),
            turns: (is_real(terr_turns) ? max(0, floor(terr_turns)) : 0),
            infinite: false
        };
        variable_struct_set(_field, "terrain", terr_struct);
    }

    var migrations = [
        { key:"_side_spikes_player", side:0, name:"spikes", clamp:3 },
        { key:"_side_spikes_enemy", side:1, name:"spikes", clamp:3 },
        { key:"_side_spikes", side:1, name:"spikes", clamp:3 },
        { key:"_side_toxic_spikes_player", side:0, name:"toxic_spikes", clamp:2 },
        { key:"_side_toxic_spikes_enemy", side:1, name:"toxic_spikes", clamp:2 },
        { key:"_side_toxic_spikes", side:1, name:"toxic_spikes", clamp:2 },
        { key:"_side_stealth_rock_player", side:0, name:"stealth_rock", clamp:1 },
        { key:"_side_stealth_rock_enemy", side:1, name:"stealth_rock", clamp:1 },
        { key:"_side_stealth_rock", side:1, name:"stealth_rock", clamp:1 },
        { key:"_side_sticky_web_player", side:0, name:"sticky_web", clamp:1 },
        { key:"_side_sticky_web_enemy", side:1, name:"sticky_web", clamp:1 },
        { key:"_side_sticky_web", side:1, name:"sticky_web", clamp:1 }
    ];
    for (var mi = 0; mi < array_length(migrations); ++mi){
        var entry = migrations[mi];
        if (!is_struct(entry)) continue;
        if (variable_struct_exists(_B, entry.key)){
            var v = variable_struct_get(_B, entry.key);
            __battle_field_apply_legacy_hazard(_field, entry.side, entry.name, v, entry.clamp);
            variable_struct_set(_B, entry.key, undefined);
        }
    }

    variable_struct_set(_field, "_legacy_migrated", true);
}

// Ensure a battlefield struct exists for the given _pid and return it.
function __battle_field_ensure(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return undefined;
    var field = (variable_struct_exists(_B, "_field") ? variable_struct_get(_B, "_field") : undefined);
    if (!is_struct(field)){
        field = __battle_field_defaults();
        variable_struct_set(_B, "_field", field);
    }
    __battle_field_get_side_struct(field, 0);
    __battle_field_get_side_struct(field, 1);
    if (!variable_struct_exists(field, "statuses") || !is_struct(variable_struct_get(field, "statuses"))) variable_struct_set(field, "statuses", {});
    if (!variable_struct_exists(field, "residual_queue") || !is_array(variable_struct_get(field, "residual_queue"))) variable_struct_set(field, "residual_queue", []);
    if (!variable_struct_exists(field, "tick_guard") || !is_struct(variable_struct_get(field, "tick_guard"))) variable_struct_set(field, "tick_guard", { residual: false });
    __battle_field_ensure_weather_struct(field);
    __battle_field_migrate_legacy(_B, field);
    __battle_field_ensure_weather_struct(field);
    return field;
}

// Reset the residual tick guard on a battlefield slot (slot-level helper).
function __battle_field_reset_residual_guard_slot(_B){
    if (!is_struct(_B)) return;
    var field = (variable_struct_exists(_B, "_field") ? variable_struct_get(_B, "_field") : undefined);
    if (is_struct(field)){
        if (!variable_struct_exists(field, "tick_guard") || !is_struct(variable_struct_get(field, "tick_guard"))) variable_struct_set(field, "tick_guard", { residual: false });
        var tg = variable_struct_get(field, "tick_guard");
        if (is_struct(tg)) variable_struct_set(tg, "residual", false);
    }
    try { variable_struct_set(_B, "_statuses_ticked", false); } catch (e_st) {}
}

// Reset residual tick guards for the battlefield of _pid.
function __battle_field_reset_residual_guard(_pid){
    var _B = __battle_ensure_slot(_pid);
    __battle_field_reset_residual_guard_slot(_B);
}

// Mark that residual effects have been processed for the given slot.
function __battle_field_mark_residual_processed_slot(_B){
    if (!is_struct(_B)) return;
    var field = (variable_struct_exists(_B, "_field") ? variable_struct_get(_B, "_field") : undefined);
    if (is_struct(field)){
        if (!variable_struct_exists(field, "tick_guard") || !is_struct(variable_struct_get(field, "tick_guard"))) variable_struct_set(field, "tick_guard", { residual: false });
        var tg = variable_struct_get(field, "tick_guard");
        if (is_struct(tg)) variable_struct_set(tg, "residual", true);
    }
    try { variable_struct_set(_B, "_statuses_ticked", true); } catch (e_st) {}
}

// Mark residual effects processed for battlefield of _pid.
function __battle_field_mark_residual_processed(_pid){
    var _B = __battle_ensure_slot(_pid);
    __battle_field_mark_residual_processed_slot(_B);
}

// Read a named hazard value for a side (e.g., "spikes", "toxic_spikes").
function __battle_field_get_hazard(_pid, _side_index, _name){
    var field = __battle_field_ensure(_pid);
    if (!is_struct(field)) return undefined;
    var hazards = __battle_field_get_hazard_struct(field, _side_index);
    if (!is_struct(hazards)) return undefined;
    switch (string_lower(string(_name))){
        case "spikes": return variable_struct_get(hazards, "spikes");
        case "toxic_spikes": return variable_struct_get(hazards, "toxic_spikes");
        case "stealth_rock": return variable_struct_get(hazards, "stealth_rock");
        case "sticky_web": return variable_struct_get(hazards, "sticky_web");
    }
    return undefined;
}

// Read a hazard with a default fallback when missing.
function __battle_field_get_hazard_or(_pid, _side_index, _name, _default){
    var hv = __battle_field_get_hazard(_pid, _side_index, _name);
    if (is_undefined(hv)) return _default;
    return hv;
}

// Set a named battlefield hazard, returns the applied canonical value.
function __battle_field_set_hazard(_pid, _side_index, _name, _value){
    var field = __battle_field_ensure(_pid);
    if (!is_struct(field)) return undefined;
    var hazards = __battle_field_get_hazard_struct(field, _side_index);
    if (!is_struct(hazards)) return undefined;
    var name = string_lower(string(_name));
    switch (name){
        case "spikes":
            var spikes_val = clamp(max(0, floor(is_real(_value) ? _value : 0)), 0, 3);
            variable_struct_set(hazards, "spikes", spikes_val);
            return spikes_val;
        case "toxic_spikes":
            var tox_val = clamp(max(0, floor(is_real(_value) ? _value : 0)), 0, 2);
            variable_struct_set(hazards, "toxic_spikes", tox_val);
            return tox_val;
        case "stealth_rock":
            var rock_val = (is_real(_value) ? _value > 0 : (_value == true));
            variable_struct_set(hazards, "stealth_rock", rock_val);
            return rock_val;
        case "sticky_web":
            var web_val = (is_real(_value) ? _value > 0 : (_value == true));
            variable_struct_set(hazards, "sticky_web", web_val);
            return web_val;
    }
    return undefined;
}

// Increment a numeric hazard by `_delta`, clamped to canonical ranges.
function __battle_field_increment_hazard(_pid, _side_index, _name, _delta){
    var field = __battle_field_ensure(_pid);
    if (!is_struct(field)) return undefined;
    var hazards = __battle_field_get_hazard_struct(field, _side_index);
    if (!is_struct(hazards)) return undefined;
    var name = string_lower(string(_name));
    var delta = (is_real(_delta) ? _delta : 1);
    switch (name){
        case "spikes":
            var cur_spikes = (variable_struct_exists(hazards, "spikes") ? variable_struct_get(hazards, "spikes") : 0);
            cur_spikes = clamp(max(0, floor(cur_spikes + delta)), 0, 3);
            variable_struct_set(hazards, "spikes", cur_spikes);
            return cur_spikes;
        case "toxic_spikes":
            var cur_toxic = (variable_struct_exists(hazards, "toxic_spikes") ? variable_struct_get(hazards, "toxic_spikes") : 0);
            cur_toxic = clamp(max(0, floor(cur_toxic + delta)), 0, 2);
            variable_struct_set(hazards, "toxic_spikes", cur_toxic);
            return cur_toxic;
    }
    return __battle_field_set_hazard(_pid, _side_index, name, _delta);
}

function __battle_field_clear_hazard(_pid, _side_index, _name){
    var name = string_lower(string(_name));
    if (name == "stealth_rock" || name == "sticky_web") return __battle_field_set_hazard(_pid, _side_index, name, false);
    return __battle_field_set_hazard(_pid, _side_index, name, 0);
}
