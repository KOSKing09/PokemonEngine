function __battle_field_default_weather_state(){
    return {
        active: false,
        id: "",
        source: undefined,
        source_side: undefined,
        started_turn: 0,
        turns_total: 0,
        turns_remaining: 0,
        infinite: false,
        message: undefined,
        params: {},
        meta: {}
    };
}

function __battle_weather_sync_compat(_state){
    if (!is_struct(_state)) return;
    var infinite = (variable_struct_exists(_state, "infinite") && variable_struct_get(_state, "infinite") == true);
    if (infinite){
        variable_struct_set(_state, "turns_remaining", -1);
        variable_struct_set(_state, "expires_turn", undefined);
    } else {
        var rem = 0;
        if (variable_struct_exists(_state, "turns_remaining") && is_real(variable_struct_get(_state, "turns_remaining"))) rem = max(0, floor(variable_struct_get(_state, "turns_remaining")));
        variable_struct_set(_state, "turns_remaining", rem);
        variable_struct_set(_state, "expires_turn", rem);
    }
}

function __battle_weather_state_normalize(_raw){
    var state = __battle_field_default_weather_state();
    if (is_struct(_raw)){
        var raw_id = "";
        if (variable_struct_exists(_raw, "id")) raw_id = string(variable_struct_get(_raw, "id"));
        var wid = __battle_weather_normalize_id(raw_id);
        var active = false;
        if (variable_struct_exists(_raw, "active")) active = (variable_struct_get(_raw, "active") == true);
        else active = (string_length(wid) > 0);
        variable_struct_set(state, "id", wid);
        variable_struct_set(state, "active", active && string_length(wid) > 0);
        if (variable_struct_exists(_raw, "source")) variable_struct_set(state, "source", variable_struct_get(_raw, "source"));
        if (variable_struct_exists(_raw, "source_side")) variable_struct_set(state, "source_side", variable_struct_get(_raw, "source_side"));
        if (variable_struct_exists(_raw, "started_turn") && is_real(variable_struct_get(_raw, "started_turn"))) variable_struct_set(state, "started_turn", floor(variable_struct_get(_raw, "started_turn")));
        var infinite = (variable_struct_exists(_raw, "infinite") && variable_struct_get(_raw, "infinite") == true);
        variable_struct_set(state, "infinite", infinite);
        if (variable_struct_exists(_raw, "turns_total") && is_real(variable_struct_get(_raw, "turns_total"))) variable_struct_set(state, "turns_total", max(0, floor(variable_struct_get(_raw, "turns_total"))));
        var rem = 0;
        if (infinite) rem = -1;
        else if (variable_struct_exists(_raw, "turns_remaining") && is_real(variable_struct_get(_raw, "turns_remaining"))) rem = max(0, floor(variable_struct_get(_raw, "turns_remaining")));
        else if (variable_struct_exists(_raw, "expires_turn") && is_real(variable_struct_get(_raw, "expires_turn"))) rem = max(0, floor(variable_struct_get(_raw, "expires_turn")));
        variable_struct_set(state, "turns_remaining", (infinite ? -1 : rem));
        if (variable_struct_exists(_raw, "message")) variable_struct_set(state, "message", variable_struct_get(_raw, "message"));
        if (variable_struct_exists(_raw, "params") && is_struct(variable_struct_get(_raw, "params"))) variable_struct_set(state, "params", variable_struct_get(_raw, "params"));
        if (variable_struct_exists(_raw, "meta") && is_struct(variable_struct_get(_raw, "meta"))) variable_struct_set(state, "meta", variable_struct_get(_raw, "meta"));
    } else if (is_string(_raw)){
        var wid_str = __battle_weather_normalize_id(_raw);
        if (string_length(wid_str) > 0){
            variable_struct_set(state, "id", wid_str);
            variable_struct_set(state, "active", true);
        }
    }
    __battle_weather_sync_compat(state);
    return state;
}

function __battle_field_ensure_weather_struct(_field){
    if (!is_struct(_field)) return __battle_field_default_weather_state();
    var raw = undefined;
    if (variable_struct_exists(_field, "weather")) raw = variable_struct_get(_field, "weather");
    var normalized = __battle_weather_state_normalize(raw);
    variable_struct_set(_field, "weather", normalized);
    return normalized;
}

function __battle_weather_reset_state(_state){
    if (!is_struct(_state)) return __battle_field_default_weather_state();
    variable_struct_set(_state, "active", false);
    variable_struct_set(_state, "id", "");
    variable_struct_set(_state, "source", undefined);
    variable_struct_set(_state, "source_side", undefined);
    variable_struct_set(_state, "started_turn", 0);
    variable_struct_set(_state, "turns_total", 0);
    variable_struct_set(_state, "turns_remaining", 0);
    variable_struct_set(_state, "infinite", false);
    variable_struct_set(_state, "message", undefined);
    variable_struct_set(_state, "params", {});
    variable_struct_set(_state, "meta", {});
    __battle_weather_sync_compat(_state);
    return _state;
}

function __battle_weather_is_active(_weather){
    if (!is_struct(_weather)) return false;
    var active = (variable_struct_exists(_weather, "active") && variable_struct_get(_weather, "active") == true);
    var wid = string(variable_struct_exists(_weather, "id") ? variable_struct_get(_weather, "id") : "");
    return active && string_length(wid) > 0;
}

function __battle_weather_is_infinite(_weather){
    if (!is_struct(_weather)) return false;
    return (variable_struct_exists(_weather, "infinite") && variable_struct_get(_weather, "infinite") == true);
}

function __battle_weather_get_normalized_id(_weather){
    if (!is_struct(_weather)) return "";
    return __battle_weather_normalize_id(variable_struct_exists(_weather, "id") ? variable_struct_get(_weather, "id") : "");
}

function __battle_weather_remaining_turns_struct(_weather){
    if (!__battle_weather_is_active(_weather)) return 0;
    if (__battle_weather_is_infinite(_weather)) return -1;
    var rem = (variable_struct_exists(_weather, "turns_remaining") && is_real(variable_struct_get(_weather, "turns_remaining"))) ? variable_struct_get(_weather, "turns_remaining") : 0;
    return max(0, floor(rem));
}

function __battle_weather_set_remaining_turns_struct(_weather, _turns){
    if (!is_struct(_weather)) return;
    if (__battle_weather_is_infinite(_weather)){
        variable_struct_set(_weather, "turns_remaining", -1);
        __battle_weather_sync_compat(_weather);
        return;
    }
    var rem = max(0, floor(_turns));
    variable_struct_set(_weather, "turns_remaining", rem);
    if (!variable_struct_exists(_weather, "turns_total") || !is_real(variable_struct_get(_weather, "turns_total")) || variable_struct_get(_weather, "turns_total") < rem){
        variable_struct_set(_weather, "turns_total", rem);
    }
    variable_struct_set(_weather, "active", (rem > 0) && string_length(__battle_weather_get_normalized_id(_weather)) > 0);
    __battle_weather_sync_compat(_weather);
}

if (is_undefined(__battle_weather_remaining_turns)){
    function __battle_weather_remaining_turns(_pid_or_weather){
        var state = undefined;
        if (is_struct(_pid_or_weather)) state = _pid_or_weather;
        else if (is_real(_pid_or_weather)) state = __battle_get_weather(_pid_or_weather);
        if (__battle_weather_is_infinite(state)) return -1;
        if (!__battle_weather_is_active(state)) return 0;
        return __battle_weather_remaining_turns_struct(state);
    }
}

if (is_undefined(__battle_get_weather)){
    function __battle_get_weather(_pid){
        try {
            var field = __battle_field_ensure(_pid);
            if (is_struct(field)) return __battle_field_ensure_weather_struct(field);
        } catch (e) {}
        return __battle_field_default_weather_state();
    }
}

if (is_undefined(__battle_clear_weather)){
    function __battle_clear_weather(_pid){
        try {
            var field = __battle_field_ensure(_pid);
            if (is_struct(field)){
                var state = __battle_field_ensure_weather_struct(field);
                state = __battle_weather_reset_state(state);
                variable_struct_set(field, "weather", state);
            }
        } catch (e) {}
    }
}

if (is_undefined(__battle_weather_normalize_id)){
    function __battle_weather_normalize_id(_id){
        var raw = string_lower(string(_id));
        switch (raw){
            case "sun": case "sunny": case "sunlight": case "sunny-day":
                return "sun";
            case "harsh-sun": case "harsh_sun": case "harsh sunlight": case "harsh-sunlight":
                return "harsh-sun";
            case "rain": case "rain-dance": case "downpour":
                return "rain";
            case "sandstorm": case "sand storm":
                return "sandstorm";
            case "hail": case "hailstorm":
                return "hail";
            case "snow": case "snowstorm": case "snowscape":
                return "snow";
            case "fog": case "mist":
                return "fog";
            default:
                return raw;
        }
    }
}

if (is_undefined(__battle_weather_lookup_type_id)){
    function __battle_weather_lookup_type_id(_name){
        var key = string_lower(string(_name));
        try {
            if (variable_global_exists("TYPE_ID_BY_NAME")){
                var _map = variable_global_get("TYPE_ID_BY_NAME");
                if (ds_exists(_map, ds_type_map)){
                    var val = ds_map_find_value(_map, key);
                    if (is_real(val)) return floor(val);
                }
            }
        } catch (e_map) {}
        switch (key){
            case "normal": return 1;
            case "fighting": return 2;
            case "flying": return 3;
            case "poison": return 4;
            case "ground": return 5;
            case "rock": return 6;
            case "bug": return 7;
            case "ghost": return 8;
            case "steel": return 9;
            case "fire": return 10;
            case "water": return 11;
            case "grass": return 12;
            case "electric": return 13;
            case "psychic": return 14;
            case "ice": return 15;
            case "dragon": return 16;
            case "dark": return 17;
            case "fairy": return 18;
        }
        return -1;
    }
}

if (is_undefined(__battle_weather_base_duration)){
    function __battle_weather_base_duration(_wid){
        switch (__battle_weather_normalize_id(_wid)){
            case "sun":
            case "harsh-sun":
            case "rain":
            case "sandstorm":
            case "hail":
            case "snow":
            case "fog":
                return 5;
            default:
                return 5;
        }
    }
}

if (is_undefined(__battle_text_list_has_token)){
    function __battle_text_list_has_token(_texts, _needle){
        if (!is_array(_texts)) return false;
        var needle = string_lower(string(_needle));
        if (string_length(needle) <= 0) return false;
        for (var kk = 0; kk < array_length(_texts); ++kk){
            var entry = _texts[kk];
            if (is_undefined(entry)) continue;
            if (is_array(entry) || is_struct(entry)) continue;
            if (!is_string(entry)) entry = string(entry);
            if (string_length(entry) <= 0) continue;
            var entry_l = string_lower(entry);
            if (string_pos(needle, entry_l) > 0 || string_pos(entry_l, needle) > 0) return true;
        }
        return false;
    }
}

if (is_undefined(__battle_weather_apply_item_extension)){
    function __battle_weather_apply_item_extension(_dur, _wid, _source){
        var dur = max(0, floor(_dur));
        if (!is_struct(_source)) return dur;
        try {
            if (!is_undefined(item_runtime_actor_held_actions)){
                var _runtime_actions = item_runtime_actor_held_actions(_source, "weather_duration");
                var _wid_runtime = __battle_weather_normalize_id(_wid);
                for (var _ri = 0; _ri < array_length(_runtime_actions); ++_ri){
                    var _act = _runtime_actions[_ri];
                    if (!is_struct(_act) || !variable_struct_exists(_act, "data")) continue;
                    var _data = variable_struct_get(_act, "data");
                    if (!is_struct(_data) || !variable_struct_exists(_data, "turns")) continue;
                    var _turns = variable_struct_get(_data, "turns");
                    if (!is_real(_turns)) continue;
                    var _weather_ok = true;
                    if (variable_struct_exists(_data, "weather")){
                        var _need = __battle_weather_normalize_id(variable_struct_get(_data, "weather"));
                        _weather_ok = (_need == _wid_runtime || (_need == "hail" && _wid_runtime == "snow") || (_need == "snow" && _wid_runtime == "hail") || (_need == "sun" && _wid_runtime == "harsh-sun"));
                    }
                    if (_weather_ok) dur = max(dur, floor(_turns));
                }
            }
        } catch (e_weather_runtime_item) {}
        var texts = [];
        try {
            if (variable_struct_exists(_source, "held_item_identifier")) array_push(texts, string_lower(string(variable_struct_get(_source, "held_item_identifier"))));
        } catch (e_id) {}
        try {
            if (variable_struct_exists(_source, "held_item_real_name")) array_push(texts, string_lower(string(variable_struct_get(_source, "held_item_real_name"))));
        } catch (e_real) {}
        try {
            if (variable_struct_exists(_source, "held_item_name")) array_push(texts, string_lower(string(variable_struct_get(_source, "held_item_name"))));
        } catch (e_name) {}
        try {
            if (variable_struct_exists(_source, "mon") && is_struct(variable_struct_get(_source, "mon"))){
                var _mon = variable_struct_get(_source, "mon");
                if (variable_struct_exists(_mon, "held_item_identifier")) array_push(texts, string_lower(string(variable_struct_get(_mon, "held_item_identifier"))));
                if (variable_struct_exists(_mon, "held_item_real_name")) array_push(texts, string_lower(string(variable_struct_get(_mon, "held_item_real_name"))));
                if (variable_struct_exists(_mon, "held_item_name")) array_push(texts, string_lower(string(variable_struct_get(_mon, "held_item_name"))));
            }
        } catch (e_mon) {}
        var wid = __battle_weather_normalize_id(_wid);
        if (wid == "sun" || wid == "harsh-sun"){
            if (__battle_text_list_has_token(texts, "heat-rock")) return max(dur, 8);
        } else if (wid == "rain"){
            if (__battle_text_list_has_token(texts, "damp-rock")) return max(dur, 8);
        } else if (wid == "sandstorm"){
            if (__battle_text_list_has_token(texts, "smooth-rock")) return max(dur, 8);
        } else if (wid == "hail" || wid == "snow"){
            if (__battle_text_list_has_token(texts, "icy-rock")) return max(dur, 8);
        }
        return dur;
    }
}

if (is_undefined(__battle_set_weather)){
    function __battle_set_weather(_pid, _weather_id, _opts){
        var wid_norm = __battle_weather_normalize_id(_weather_id);
        if (string_length(wid_norm) <= 0) return undefined;
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B)) return undefined;
        var field = __battle_field_ensure(_pid);
        if (!is_struct(field)) return undefined;
        var state = __battle_field_ensure_weather_struct(field);
        var opts = (is_struct(_opts) ? _opts : {});
        var src = undefined;
        if (is_struct(opts)){
            if (variable_struct_exists(opts, "source")) src = variable_struct_get(opts, "source");
            else if (variable_struct_exists(opts, "source_actor")) src = variable_struct_get(opts, "source_actor");
        }
        var infinite = (is_struct(opts) && variable_struct_exists(opts, "infinite") && variable_struct_get(opts, "infinite") == true);
        var dur = __battle_weather_base_duration(wid_norm);
        if (is_struct(opts) && variable_struct_exists(opts, "duration") && is_real(variable_struct_get(opts, "duration"))){
            dur = max(0, floor(variable_struct_get(opts, "duration")));
        }
        dur = __battle_weather_apply_item_extension(dur, wid_norm, src);
        __battle_weather_reset_state(state);
        variable_struct_set(state, "active", true);
        variable_struct_set(state, "id", wid_norm);
        variable_struct_set(state, "source", src);
        if (is_struct(opts) && variable_struct_exists(opts, "source_side")) variable_struct_set(state, "source_side", variable_struct_get(opts, "source_side"));
        variable_struct_set(state, "started_turn", (variable_struct_exists(_B, "turn_i") ? variable_struct_get(_B, "turn_i") : 0));
        variable_struct_set(state, "infinite", infinite);
        var turns_total = dur;
        variable_struct_set(state, "turns_total", turns_total);
        if (infinite){
            variable_struct_set(state, "turns_remaining", -1);
        } else {
            variable_struct_set(state, "turns_remaining", turns_total);
        }
        if (is_struct(opts) && variable_struct_exists(opts, "message")) variable_struct_set(state, "message", variable_struct_get(opts, "message"));
        if (is_struct(opts) && variable_struct_exists(opts, "params") && is_struct(variable_struct_get(opts, "params"))) variable_struct_set(state, "params", variable_struct_get(opts, "params"));
        else if (is_struct(opts) && variable_struct_exists(opts, "param")) variable_struct_set(state, "params", { value: variable_struct_get(opts, "param") });
        __battle_weather_sync_compat(state);
        variable_struct_set(field, "weather", state);
        try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_meta_flag) {}
        try { __battle_request_animation_safe(_pid, { type: "weather_start", id: wid_norm, source: src }); } catch (e_anim) {}
        var msg = "";
        if (variable_struct_exists(state, "message") && string_length(string(variable_struct_get(state, "message"))) > 0) msg = string(variable_struct_get(state, "message"));
        else {
            switch (wid_norm){
                case "sun": msg = "The sunlight turned harsh!"; break;
                case "harsh-sun": msg = "The sunlight grew extremely harsh!"; break;
                case "rain": msg = "It started to rain!"; break;
                case "sandstorm": msg = "A sandstorm kicked up!"; break;
                case "hail": msg = "It started to hail!"; break;
                case "snow": msg = "Snow began to fall!"; break;
                case "fog": msg = "A thick fog settled in!"; break;
            }
        }
        if (string_length(msg) > 0){
            try {
                if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, msg);
                else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, msg, msg, "any");
            } catch (e_msg) {}
        }
        return state;
    }
}

if (is_undefined(__battle_weather_actor_has_type)){
    function __battle_weather_actor_has_type(_actor, _type_id){
        if (!is_struct(_actor) || !is_real(_type_id)) return false;
        try {
            if (variable_struct_exists(_actor, "types") && is_array(variable_struct_get(_actor, "types"))){
                var arr = variable_struct_get(_actor, "types");
                for (var i = 0; i < array_length(arr); ++i) if (is_real(arr[i]) && arr[i] == _type_id) return true;
            }
        } catch (e_ta) {}
        try { if (variable_struct_exists(_actor, "type1") && is_real(variable_struct_get(_actor, "type1")) && variable_struct_get(_actor, "type1") == _type_id) return true; } catch (e_t1) {}
        try { if (variable_struct_exists(_actor, "type2") && is_real(variable_struct_get(_actor, "type2")) && variable_struct_get(_actor, "type2") == _type_id) return true; } catch (e_t2) {}
        try {
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
                var _mon = variable_struct_get(_actor, "mon");
                if (variable_struct_exists(_mon, "types") && is_array(variable_struct_get(_mon, "types"))){
                    var marr = variable_struct_get(_mon, "types");
                    for (var j = 0; j < array_length(marr); ++j) if (is_real(marr[j]) && marr[j] == _type_id) return true;
                }
                if (variable_struct_exists(_mon, "type1") && is_real(variable_struct_get(_mon, "type1")) && variable_struct_get(_mon, "type1") == _type_id) return true;
                if (variable_struct_exists(_mon, "type2") && is_real(variable_struct_get(_mon, "type2")) && variable_struct_get(_mon, "type2") == _type_id) return true;
                if (variable_struct_exists(_mon, "species_id") && variable_global_exists("_species_types") && is_array(global._species_types)){
                    var sid = variable_struct_get(_mon, "species_id");
                    if (is_real(sid) && sid >= 0 && sid < array_length(global._species_types)){
                        var spec = global._species_types[sid];
                        if (is_array(spec)) for (var k = 0; k < array_length(spec); ++k) if (is_real(spec[k]) && spec[k] == _type_id) return true;
                    }
                }
            }
        } catch (e_mon_types) {}
        return false;
    }
}

if (is_undefined(__battle_weather_actor_has_ability)){
    function __battle_weather_actor_has_ability(_actor, _needles){
        if (!is_struct(_actor)) return false;
        var names = is_array(_needles) ? _needles : [string(_needles)];
        var ability_txt = "";
        try { if (variable_struct_exists(_actor, "ability")) ability_txt = string_lower(string(variable_struct_get(_actor, "ability"))); } catch (e_ab1) {}
        if (string_length(ability_txt) <= 0){
            try {
                if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
                    var m = variable_struct_get(_actor, "mon");
                    if (variable_struct_exists(m, "ability")) ability_txt = string_lower(string(variable_struct_get(m, "ability")));
                }
            } catch (e_ab2) {}
        }
        if (string_length(ability_txt) <= 0) return false;
        for (var ii = 0; ii < array_length(names); ++ii){
            var needle = string_lower(string(names[ii]));
            if (string_length(needle) <= 0) continue;
            if (string_pos(needle, ability_txt) > 0 || ability_txt == needle) return true;
        }
        return false;
    }
}

if (is_undefined(__battle_weather_suppressed_by_ability)){
    function __battle_weather_suppressed_by_ability(_pid){
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return false;
        var actors = variable_struct_get(_B, "actor");
        for (var wi = 0; wi < array_length(actors); ++wi){
            var act = actors[wi];
            if (!is_struct(act)) continue;
            if (__battle_hp_now(act) <= 0) continue;
            try {
                if (!is_undefined(__battle_actor_ability_has_group) && __battle_actor_ability_has_group(act, "weather_suppress")) return true;
            } catch (e_weather_group) {}
            if (__battle_weather_actor_has_ability(act, ["cloud nine", "cloud-nine", "air lock", "air-lock"])) return true;
        }
        return false;
    }
}

if (is_undefined(__battle_weather_apply_end_of_turn)){
    function __battle_weather_apply_end_of_turn(_pid, _weather){
        if (!is_struct(_weather)) return;
        if (!__battle_weather_is_active(_weather)) return;
        if (__battle_weather_suppressed_by_ability(_pid)) return;
        var wid = __battle_weather_normalize_id(variable_struct_exists(_weather, "id") ? variable_struct_get(_weather, "id") : "");
        if (string_length(wid) <= 0) return;
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
        var actors = variable_struct_get(_B, "actor");
        var rock_id = __battle_weather_lookup_type_id("rock");
        var ground_id = __battle_weather_lookup_type_id("ground");
        var steel_id = __battle_weather_lookup_type_id("steel");
        var ice_id = __battle_weather_lookup_type_id("ice");
        var any_effect = false;
        switch (wid){
            case "sandstorm":
                for (var si = 0; si < array_length(actors); ++si){
                    var act = actors[si];
                    if (!is_struct(act)) continue;
                    if (__battle_hp_now(act) <= 0) continue;
                    if (__battle_weather_actor_has_type(act, rock_id) || __battle_weather_actor_has_type(act, ground_id) || __battle_weather_actor_has_type(act, steel_id)) continue;
                    if (__battle_weather_actor_has_ability(act, ["magic guard", "overcoat"])) continue;
                    var max_hp = max(1, __battle_hp_max(act));
                    var dmg = max(1, floor(max_hp / 16));
                    __battle_apply_damage(_pid, si, dmg, 1.0);
                    any_effect = true;
                }
                if (string_length(wid) > 0){
                    var msg_ss = "The sandstorm rages.";
                    try {
                        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, msg_ss);
                        else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, msg_ss, msg_ss, "any");
                    } catch (e_msg_ss) {}
                }
                break;
            case "hail":
            case "snow":
                for (var hi = 0; hi < array_length(actors); ++hi){
                    var act_h = actors[hi];
                    if (!is_struct(act_h)) continue;
                    if (__battle_hp_now(act_h) <= 0) continue;
                    if (__battle_weather_actor_has_type(act_h, ice_id)) continue;
                    if (__battle_weather_actor_has_ability(act_h, ["magic guard", "overcoat"])) continue;
                    var max_hp_h = max(1, __battle_hp_max(act_h));
                    var dmg_h = max(1, floor(max_hp_h / 16));
                    __battle_apply_damage(_pid, hi, dmg_h, 1.0);
                    any_effect = true;
                }
                var msg_h = (wid == "snow") ? "The snowstorm rages." : "The hail crashes down.";
                try {
                    if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, msg_h);
                    else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, msg_h, msg_h, "any");
                } catch (e_msg_h) {}
                break;
            case "rain":
                if (string_length(wid) > 0){
                    var msg_r = "Rain continues to fall.";
                    try {
                        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, msg_r);
                        else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, msg_r, msg_r, "any");
                    } catch (e_msg_r) {}
                }
                break;
            case "sun":
            case "harsh-sun":
                var msg_s = (wid == "harsh-sun") ? "The harsh sunlight continues to flare." : "The sunlight is strong.";
                try {
                    if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, msg_s);
                    else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, msg_s, msg_s, "any");
                } catch (e_msg_s) {}
                break;
            case "fog":
                var msg_f = "The fog is deep.";
                try {
                    if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, msg_f);
                    else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, msg_f, msg_f, "any");
                } catch (e_msg_f) {}
                break;
            default:
                break;
        }
        if (any_effect){
            try { __battle_request_animation_safe(_pid, { type: "weather_tick", id: wid }); } catch (e_tick) {}
        }
    }
}
