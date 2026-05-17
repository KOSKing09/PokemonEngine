function overworld_environment_default_state(){
    return {
        initialized: false,
        enabled: true,
        time_minutes: 8 * 60,
        time_scale: 1,
        day_length_minutes: 24 * 60,
        weather: "clear",
        weather_intensity: 0,
        weather_duration_ms: -1,
        weather_started_ms: 0,
        weather_source: "default",
        weather_layer_name: "__ENV_WEATHER",
        particle_system: -1,
        particle_types: {},
        auto_weather: true,
        last_weather_key: "",
        night_alpha_max: 0.38
    };
}

function overworld_environment_ensure(){
    if (!variable_global_exists("OVERWORLD_ENV") || !is_struct(global.OVERWORLD_ENV)){
        global.OVERWORLD_ENV = overworld_environment_default_state();
    }
    var _E = global.OVERWORLD_ENV;
    if (!variable_struct_exists(_E, "initialized")) _E.initialized = false;
    if (!variable_struct_exists(_E, "enabled")) _E.enabled = true;
    if (!variable_struct_exists(_E, "time_minutes")) _E.time_minutes = 8 * 60;
    if (!variable_struct_exists(_E, "time_scale")) _E.time_scale = 1;
    if (!variable_struct_exists(_E, "day_length_minutes")) _E.day_length_minutes = 24 * 60;
    if (!variable_struct_exists(_E, "weather")) _E.weather = "clear";
    if (!variable_struct_exists(_E, "weather_intensity")) _E.weather_intensity = 0;
    if (!variable_struct_exists(_E, "weather_duration_ms")) _E.weather_duration_ms = -1;
    if (!variable_struct_exists(_E, "weather_started_ms")) _E.weather_started_ms = current_time;
    if (!variable_struct_exists(_E, "weather_source")) _E.weather_source = "default";
    if (!variable_struct_exists(_E, "weather_layer_name")) _E.weather_layer_name = "__ENV_WEATHER";
    if (!variable_struct_exists(_E, "particle_system")) _E.particle_system = -1;
    if (!variable_struct_exists(_E, "particle_types") || !is_struct(_E.particle_types)) _E.particle_types = {};
    if (!variable_struct_exists(_E, "auto_weather")) _E.auto_weather = true;
    if (!variable_struct_exists(_E, "last_weather_key")) _E.last_weather_key = "";
    if (!variable_struct_exists(_E, "night_alpha_max")) _E.night_alpha_max = 0.38;
    global.OVERWORLD_ENV = _E;
    return _E;
}

function overworld_environment_particle_type(_name, _shape, _c1, _c2, _alpha1, _alpha2, _size_min, _size_max, _speed_min, _speed_max, _dir_min, _dir_max, _life_min, _life_max, _grav = 0, _grav_dir = 270){
    var _t = part_type_create();
    part_type_shape(_t, _shape);
    part_type_size(_t, _size_min, _size_max, 0, 0);
    part_type_color2(_t, _c1, _c2);
    part_type_alpha2(_t, _alpha1, _alpha2);
    part_type_speed(_t, _speed_min, _speed_max, 0, 0);
    part_type_direction(_t, _dir_min, _dir_max, 0, 0);
    part_type_life(_t, _life_min, _life_max);
    part_type_gravity(_t, _grav, _grav_dir);
    return _t;
}

function overworld_environment_init(){
    var _E = overworld_environment_ensure();
    if (_E.initialized) return true;

    var _layer = layer_get_id(_E.weather_layer_name);
    if (_layer == -1){
        try { _layer = layer_create(-9000, _E.weather_layer_name); } catch (e_weather_layer) { _layer = -1; }
    }

    try {
        _E.particle_system = (_layer != -1) ? part_system_create_layer(_layer, false) : part_system_create();
    } catch (e_weather_ps_layer) {
        try { _E.particle_system = part_system_create(); } catch (e_weather_ps) { _E.particle_system = -1; }
    }

    var _types = {};
    try {
        variable_struct_set(_types, "rain", overworld_environment_particle_type("rain", pt_shape_pixel, make_color_rgb(155, 190, 255), c_white, 0.62, 0, 0.45, 0.75, 8, 12, 250, 260, 22, 34, 0.08, 270));
        variable_struct_set(_types, "snow", overworld_environment_particle_type("snow", pt_shape_pixel, c_white, make_color_rgb(210, 235, 255), 0.78, 0, 0.9, 1.8, 0.7, 1.8, 250, 290, 90, 150, 0.012, 270));
        variable_struct_set(_types, "sand", overworld_environment_particle_type("sand", pt_shape_pixel, make_color_rgb(218, 188, 104), make_color_rgb(168, 126, 64), 0.52, 0, 0.55, 1.15, 3, 6, 175, 205, 42, 76, 0, 270));
        variable_struct_set(_types, "fog", overworld_environment_particle_type("fog", pt_shape_disk, make_color_rgb(190, 205, 210), make_color_rgb(230, 235, 235), 0.10, 0, 4, 10, 0.15, 0.55, 170, 210, 160, 260, 0, 270));
        variable_struct_set(_types, "ash", overworld_environment_particle_type("ash", pt_shape_pixel, make_color_rgb(165, 160, 150), make_color_rgb(90, 90, 90), 0.45, 0, 0.8, 1.4, 0.8, 2.4, 230, 280, 70, 130, 0.006, 270));
    } catch (e_weather_types) {}
    _E.particle_types = _types;
    _E.initialized = true;
    global.OVERWORLD_ENV = _E;
    return true;
}

function overworld_environment_set_time(_hour, _minute = 0){
    var _E = overworld_environment_ensure();
    _E.time_minutes = (floor(_hour) * 60 + floor(_minute)) mod max(1, floor(_E.day_length_minutes));
    global.OVERWORLD_ENV = _E;
}

function overworld_environment_hour(){
    var _E = overworld_environment_ensure();
    return floor(_E.time_minutes / 60) mod 24;
}

function overworld_environment_time_string(){
    var _E = overworld_environment_ensure();
    var _h = floor(_E.time_minutes / 60) mod 24;
    var _m = floor(_E.time_minutes) mod 60;
    return string(_h) + ":" + ((_m < 10) ? "0" : "") + string(_m);
}

function overworld_environment_is_night(){
    var _h = overworld_environment_hour();
    return (_h >= 20 || _h < 5);
}

function overworld_environment_set_weather(_weather, _intensity = 1, _duration_ms = -1, _source = "script"){
    overworld_environment_init();
    var _E = overworld_environment_ensure();
    var _w = string_lower(string(_weather));
    switch (_w){
        case "rain":
        case "snow":
        case "sand":
        case "sandstorm":
        case "fog":
        case "ash":
        case "clear":
            break;
        default:
            _w = "clear";
            break;
    }
    if (_w == "sandstorm") _w = "sand";
    _E.weather = _w;
    _E.weather_intensity = (_w == "clear") ? 0 : clamp(real(_intensity), 0, 1);
    _E.weather_duration_ms = real(_duration_ms);
    _E.weather_started_ms = current_time;
    _E.weather_source = string(_source);
    if (_E.particle_system != -1){
        try { part_system_clear(_E.particle_system); } catch (e_weather_clear) {}
    }
    global.OVERWORLD_ENV = _E;
}

function overworld_environment_weather_for_climate(_biome_id, _temperature, _moisture, _roll){
    var _biome = string_lower(string(_biome_id));
    var _temp = clamp(real(_temperature), 0, 1);
    var _moist = clamp(real(_moisture), 0, 1);
    var _r = clamp(real(_roll), 0, 1);

    if (_temp <= 0.28 && _moist >= 0.36) return (_r < 0.64) ? "snow" : "clear";
    if ((_biome == "desert" || _biome == "mountain") && _moist <= 0.28) return (_r < 0.24) ? "sand" : "clear";
    if (_biome == "swamp" && _moist >= 0.70) return (_r < 0.72) ? "fog" : ((_r < 0.92) ? "rain" : "clear");
    if (_moist >= 0.82) return (_r < 0.58) ? "rain" : "fog";
    if (_biome == "ocean") return (_r < 0.38) ? "rain" : ((_r < 0.56) ? "fog" : "clear");
    if (_biome == "river" && _moist >= 0.62) return (_r < 0.36) ? "rain" : "clear";
    if (_biome == "forest" && _moist >= 0.58) return (_r < 0.26) ? "rain" : "clear";
    return "clear";
}

function overworld_environment_apply_rogue_chunk(_stats, _dominant_biome){
    if (!is_struct(_stats)) return false;
    var _E = overworld_environment_ensure();
    if (!_E.auto_weather) return false;
    var _total = max(1, variable_struct_exists(_stats, "total") ? real(_stats.total) : 1);
    var _temp = variable_struct_exists(_stats, "temperature_sum") ? real(_stats.temperature_sum) / _total : 0.5;
    var _moist = variable_struct_exists(_stats, "moisture_sum") ? real(_stats.moisture_sum) / _total : 0.5;
    var _chunk_x = variable_struct_exists(_stats, "chunk_x") ? floor(_stats.chunk_x) : 0;
    var _chunk_y = variable_struct_exists(_stats, "chunk_y") ? floor(_stats.chunk_y) : 0;
    var _key = string(_chunk_x) + "," + string(_chunk_y) + ":" + string(_dominant_biome);
    if (_E.last_weather_key == _key && string(_E.weather_source) == "rogue") return true;

    var _roll = (!is_undefined(rogue_hash01)) ? rogue_hash01(_chunk_x, _chunk_y, 871) : random(1);
    var _weather = overworld_environment_weather_for_climate(_dominant_biome, _temp, _moist, _roll);
    var _intensity = 0.45 + ((_moist + _roll) * 0.25);
    if (_weather == "sand") _intensity = 0.35 + ((1 - _moist) * 0.35);
    if (_weather == "fog") _intensity = 0.30 + (_moist * 0.35);
    if (_weather == "clear") _intensity = 0;
    overworld_environment_set_weather(_weather, clamp(_intensity, 0, 1), -1, "rogue");
    _E = overworld_environment_ensure();
    _E.last_weather_key = _key;
    global.OVERWORLD_ENV = _E;
    return true;
}

function overworld_environment_emit_weather(){
    var _E = overworld_environment_ensure();
    if (!_E.enabled || _E.particle_system == -1 || _E.weather == "clear" || _E.weather_intensity <= 0) return false;
    if (!is_struct(_E.particle_types) || !variable_struct_exists(_E.particle_types, _E.weather)) return false;

    var _cam = view_camera[0];
    var _vx = 0;
    var _vy = 0;
    var _vw = room_width;
    var _vh = room_height;
    try {
        _vx = camera_get_view_x(_cam);
        _vy = camera_get_view_y(_cam);
        _vw = camera_get_view_width(_cam);
        _vh = camera_get_view_height(_cam);
    } catch (e_weather_camera) {}

    var _ptype = variable_struct_get(_E.particle_types, _E.weather);
    var _amount = max(1, floor(_E.weather_intensity * 7));
    var _x0 = _vx - 32;
    var _x1 = _vx + _vw + 32;
    var _y0 = _vy - 24;
    var _y1 = _vy + _vh + 24;

    for (var _i = 0; _i < _amount; ++_i){
        var _px = random_range(_x0, _x1);
        var _py = _y0;
        if (_E.weather == "sand" || _E.weather == "fog" || _E.weather == "ash") _py = random_range(_y0, _y1);
        part_particles_create(_E.particle_system, _px, _py, _ptype, 1);
    }
    return true;
}

function overworld_environment_update(){
    overworld_environment_init();
    var _E = overworld_environment_ensure();
    if (!_E.enabled) return false;
    var _dt = 1 / max(1, room_speed);
    try { _dt = delta_time / 1000000; } catch (e_env_dt) {}
    _E.time_minutes = (real(_E.time_minutes) + (_dt * real(_E.time_scale))) mod max(1, real(_E.day_length_minutes));
    if (_E.weather_duration_ms > 0 && current_time - _E.weather_started_ms >= _E.weather_duration_ms){
        _E.weather_duration_ms = -1;
        global.OVERWORLD_ENV = _E;
        overworld_environment_set_weather("clear", 0, -1, "timer");
    } else {
        global.OVERWORLD_ENV = _E;
    }
    overworld_environment_emit_weather();
    return true;
}

function overworld_environment_overlay_alpha(){
    var _E = overworld_environment_ensure();
    var _m = real(_E.time_minutes) mod real(_E.day_length_minutes);
    var _h = _m / 60;
    var _night = real(_E.night_alpha_max);
    if (_h >= 20 || _h < 5) return _night;
    if (_h >= 18 && _h < 20) return rogue_lerp(0.06, _night, (_h - 18) / 2);
    if (_h >= 5 && _h < 7) return rogue_lerp(_night, 0.02, (_h - 5) / 2);
    return 0;
}

function overworld_environment_draw_overlay(){
    var _E = overworld_environment_ensure();
    if (!_E.enabled) return false;
    var _alpha = overworld_environment_overlay_alpha();
    if (_alpha <= 0) return false;
    var _cam = view_camera[0];
    var _vx = 0;
    var _vy = 0;
    var _vw = room_width;
    var _vh = room_height;
    try {
        _vx = camera_get_view_x(_cam);
        _vy = camera_get_view_y(_cam);
        _vw = camera_get_view_width(_cam);
        _vh = camera_get_view_height(_cam);
    } catch (e_env_overlay_camera) {}
    draw_set_alpha(clamp(_alpha, 0, 1));
    draw_set_color(make_color_rgb(14, 26, 58));
    draw_rectangle(_vx, _vy, _vx + _vw, _vy + _vh, false);
    draw_set_alpha(1);
    draw_set_color(c_white);
    return true;
}
