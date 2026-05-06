function __battle_resolve_platform_index(_value, _default){
    var fallback = (is_real(_default) ? floor(_default) : 3);
    if (is_real(_value)){
        var num = floor(_value);
        if (num < 0) num = 0;
        return num;
    }
    if (is_string(_value)){
        var key = string_lower(string(_value));
        switch (key){
            case "dark water":
            case "dark_water":
            case "darkwater":
            case "water dark":
            case "water_dark":
                return 0;
            case "rocks a":
            case "rocks_a":
            case "rocksa":
            case "grey caves":
            case "gray caves":
            case "grey_caves":
            case "gray_caves":
                return 1;
            case "light":
                return 2;
            case "grassy":
            case "grass":
            case "field":
                return 3;
            case "rocks b":
            case "rocks_b":
            case "rocksb":
            case "brown caves":
            case "brown_caves":
                return 4;
            case "dirt":
            case "earth":
                return 5;
            case "river":
            case "water":
            case "stream":
                return 6;
            case "snowy":
            case "snow":
                return 7;
            case "grassy snow":
            case "grassy_snow":
            case "snowy grass":
            case "snowy_grass":
                return 8;
            case "ice":
            case "icy":
                return 9;
            case "forest":
            case "lush forest":
            case "forest_path":
                return 10;
            case "ugly grass":
            case "patchy grass":
            case "scrub":
                return 11;
            case "wood bridge":
            case "wood_bridge":
            case "bridge":
            case "boardwalk":
                return 12;
            case "man made paths":
            case "man_made_paths":
            case "paved":
            case "concrete":
                return 13;
        }
    }
    return fallback;
}

function __battle_parse_platform_offset(_current, _value){
    var curr_x = 0;
    var curr_y = 0;
    if (is_struct(_current)){
        if (variable_struct_exists(_current, "x") && is_real(variable_struct_get(_current, "x"))) curr_x = real(variable_struct_get(_current, "x"));
        if (variable_struct_exists(_current, "y") && is_real(variable_struct_get(_current, "y"))) curr_y = real(variable_struct_get(_current, "y"));
    }
    if (is_struct(_value)){
        if (variable_struct_exists(_value, "x") && is_real(variable_struct_get(_value, "x"))) curr_x = real(variable_struct_get(_value, "x"));
        if (variable_struct_exists(_value, "y") && is_real(variable_struct_get(_value, "y"))) curr_y = real(variable_struct_get(_value, "y"));
    } else if (is_array(_value) && array_length(_value) >= 2){
        var vx = _value[0];
        var vy = _value[1];
        if (is_real(vx)) curr_x = real(vx);
        if (is_real(vy)) curr_y = real(vy);
    }
    return { x: curr_x, y: curr_y };
}

function __battle_theme_luma(_col){
    return (color_get_red(_col) * 0.299) + (color_get_green(_col) * 0.587) + (color_get_blue(_col) * 0.114);
}

function __battle_theme_blend(_a, _b, _amt){
    return merge_color(_a, _b, clamp(_amt, 0, 1));
}

function __battle_theme_refresh_text_colors(_theme){
    if (!is_struct(_theme)) return;
    var _panel = (variable_struct_exists(_theme, "col_panel") ? variable_struct_get(_theme, "col_panel") : c_white);
    var _outline = (variable_struct_exists(_theme, "col_outline") ? variable_struct_get(_theme, "col_outline") : c_black);
    var _panel_luma = __battle_theme_luma(_panel);
    var _is_light_panel = (_panel_luma >= 160);

    var _ui_text = _outline;
    var _ui_highlight = _outline;
    var _ui_highlight_text = c_white;
    if (_is_light_panel){
        _ui_text = __battle_theme_blend(_outline, c_black, 0.38);
        _ui_highlight = __battle_theme_blend(_outline, _panel, 0.16);
        _ui_highlight_text = __battle_theme_blend(_outline, c_white, 0.72);
    } else {
        _ui_text = __battle_theme_blend(c_white, _panel, 0.18);
        _ui_highlight = __battle_theme_blend(_outline, _panel, 0.22);
        _ui_highlight_text = __battle_theme_blend(c_white, _panel, 0.08);
    }

    variable_struct_set(_theme, "col_dialog_text", _ui_text);
    variable_struct_set(_theme, "col_ui_text", _ui_text);
    variable_struct_set(_theme, "col_ui_highlight", _ui_highlight);
    variable_struct_set(_theme, "col_ui_highlight_text", _ui_highlight_text);
}

function __battle_theme_area_preset(_area_key){
    var fallback_names = [
        "dark water", "rocks a", "light", "grassy", "rocks b",
        "dirt", "river", "snowy", "grassy snow", "ice",
        "forest", "ugly grass", "wood bridge", "man made paths"
    ];
    var idx = __battle_resolve_platform_index(_area_key, 3);
    var canonical = fallback_names[clamp(idx, 0, array_length(fallback_names) - 1)];
    switch (idx){
        case 0:
            return {
                area_type: canonical,
                platform_enemy_index: 0,
                platform_player_index: 0,
                col_bg: make_color_rgb(48, 74, 120),
                col_panel: make_color_rgb(168, 208, 224),
                col_outline: make_color_rgb(30, 52, 88),
                col_text: c_white
            };
        case 1:
            return {
                area_type: canonical,
                platform_enemy_index: 1,
                platform_player_index: 1,
                col_bg: make_color_rgb(112, 116, 132),
                col_panel: make_color_rgb(196, 204, 220),
                col_outline: make_color_rgb(64, 68, 84),
                col_text: c_white
            };
        case 2:
            return {
                area_type: canonical,
                platform_enemy_index: 2,
                platform_player_index: 2,
                col_bg: make_color_rgb(224, 232, 224),
                col_panel: make_color_rgb(240, 244, 240),
                col_outline: make_color_rgb(150, 158, 168),
                col_text: make_color_rgb(56, 68, 76)
            };
        case 3:
            return {
                area_type: canonical,
                platform_enemy_index: 3,
                platform_player_index: 3,
                col_bg: make_color_rgb(184, 224, 200),
                col_panel: make_color_rgb(208, 232, 224),
                col_outline: make_color_rgb(72, 88, 80),
                col_text: c_white
            };
        case 4:
            return {
                area_type: canonical,
                platform_enemy_index: 4,
                platform_player_index: 4,
                col_bg: make_color_rgb(156, 112, 84),
                col_panel: make_color_rgb(216, 192, 164),
                col_outline: make_color_rgb(88, 60, 44),
                col_text: c_white
            };
        case 5:
            return {
                area_type: canonical,
                platform_enemy_index: 5,
                platform_player_index: 5,
                col_bg: make_color_rgb(196, 168, 120),
                col_panel: make_color_rgb(228, 204, 160),
                col_outline: make_color_rgb(116, 88, 56),
                col_text: make_color_rgb(50, 36, 24)
            };
        case 6:
            return {
                area_type: canonical,
                platform_enemy_index: 6,
                platform_player_index: 6,
                col_bg: make_color_rgb(100, 156, 204),
                col_panel: make_color_rgb(180, 216, 236),
                col_outline: make_color_rgb(52, 88, 124),
                col_text: c_white
            };
        case 7:
            return {
                area_type: canonical,
                platform_enemy_index: 7,
                platform_player_index: 7,
                col_bg: make_color_rgb(224, 236, 244),
                col_panel: make_color_rgb(244, 248, 252),
                col_outline: make_color_rgb(148, 168, 184),
                col_text: make_color_rgb(60, 72, 88)
            };
        case 8:
            return {
                area_type: canonical,
                platform_enemy_index: 8,
                platform_player_index: 8,
                col_bg: make_color_rgb(204, 232, 220),
                col_panel: make_color_rgb(232, 244, 236),
                col_outline: make_color_rgb(108, 136, 148),
                col_text: make_color_rgb(52, 66, 74)
            };
        case 9:
            return {
                area_type: canonical,
                platform_enemy_index: 9,
                platform_player_index: 9,
                col_bg: make_color_rgb(188, 220, 252),
                col_panel: make_color_rgb(220, 236, 252),
                col_outline: make_color_rgb(88, 132, 176),
                col_text: make_color_rgb(36, 60, 96)
            };
        case 10:
            return {
                area_type: canonical,
                platform_enemy_index: 10,
                platform_player_index: 10,
                col_bg: make_color_rgb(132, 188, 120),
                col_panel: make_color_rgb(204, 228, 196),
                col_outline: make_color_rgb(68, 108, 76),
                col_text: make_color_rgb(36, 52, 40)
            };
        case 11:
            return {
                area_type: canonical,
                platform_enemy_index: 11,
                platform_player_index: 11,
                col_bg: make_color_rgb(172, 196, 120),
                col_panel: make_color_rgb(216, 228, 176),
                col_outline: make_color_rgb(108, 124, 68),
                col_text: make_color_rgb(52, 60, 36)
            };
        case 12:
            return {
                area_type: canonical,
                platform_enemy_index: 12,
                platform_player_index: 12,
                col_bg: make_color_rgb(180, 148, 108),
                col_panel: make_color_rgb(220, 196, 156),
                col_outline: make_color_rgb(112, 80, 52),
                col_text: make_color_rgb(52, 36, 20)
            };
        case 13:
            return {
                area_type: canonical,
                platform_enemy_index: 13,
                platform_player_index: 13,
                col_bg: make_color_rgb(168, 176, 188),
                col_panel: make_color_rgb(212, 216, 224),
                col_outline: make_color_rgb(108, 116, 128),
                col_text: make_color_rgb(48, 54, 64)
            };
        default:
            return __battle_theme_area_preset(canonical);
    }
}

function __battle_theme_apply_area_type(_B, _explicit_area, _opts){
    if (!is_struct(_B) || !variable_struct_exists(_B, "theme")) return;
    var theme = _B.theme;
    var area_key = undefined;

    if (!is_undefined(_explicit_area)) area_key = _explicit_area;

    if (is_undefined(area_key) && variable_struct_exists(_B, "_area_type")){
        var stored = variable_struct_get(_B, "_area_type");
        if (!is_undefined(stored)) area_key = stored;
    }

    if (is_undefined(area_key) && is_struct(_opts)){
        if (variable_struct_exists(_opts, "area_type")) area_key = variable_struct_get(_opts, "area_type");
        else if (variable_struct_exists(_opts, "theme")){
            var _theme_opts = variable_struct_get(_opts, "theme");
            if (is_struct(_theme_opts) && variable_struct_exists(_theme_opts, "area_type")){
                area_key = variable_struct_get(_theme_opts, "area_type");
            }
        }
    }

    if (is_string(area_key)){
        area_key = string_lower(string_trim(area_key));
        if (string_length(area_key) <= 0) area_key = undefined;
    }

    if (is_undefined(area_key)) return;

    var preset = __battle_theme_area_preset(area_key);
    if (is_struct(preset)){
        if (variable_struct_exists(preset, "platform_enemy_index")) theme.platform_enemy_index = variable_struct_get(preset, "platform_enemy_index");
        if (variable_struct_exists(preset, "platform_player_index")) theme.platform_player_index = variable_struct_get(preset, "platform_player_index");
        if (variable_struct_exists(preset, "col_bg")) theme.col_bg = variable_struct_get(preset, "col_bg");
        if (variable_struct_exists(preset, "col_panel")) theme.col_panel = variable_struct_get(preset, "col_panel");
        if (variable_struct_exists(preset, "col_outline")) theme.col_outline = variable_struct_get(preset, "col_outline");
        if (variable_struct_exists(preset, "col_text")) theme.col_text = variable_struct_get(preset, "col_text");
        __battle_theme_refresh_text_colors(theme);
        var canonical = (variable_struct_exists(preset, "area_type") ? string(variable_struct_get(preset, "area_type")) : "");
        if (canonical != ""){
            try { variable_struct_set(_B, "_area_type", canonical); } catch (e_canon) {}
        } else {
            try { variable_struct_set(_B, "_area_type", area_key); } catch (e_area_fallback) {}
        }
    } else {
        try { variable_struct_set(_B, "_area_type", area_key); } catch (e_area_store) {}
    }
}

function __battle_theme_apply_platform_opts(_B, _opts){
    if (!is_struct(_B) || !variable_struct_exists(_B, "theme")) return;
    var theme = _B.theme;
    var sources = [];
    if (is_struct(_opts)){
        sources[array_length(sources)] = _opts;
        if (variable_struct_exists(_opts, "theme")){
            var t = variable_struct_get(_opts, "theme");
            if (is_struct(t)) sources[array_length(sources)] = t;
        }
    }
    for (var si = 0; si < array_length(sources); ++si){
        var src = sources[si];
        if (!is_struct(src)) continue;

        if (variable_struct_exists(src, "platform_environment")){
            var env_idx = __battle_resolve_platform_index(variable_struct_get(src, "platform_environment"), theme.platform_enemy_index);
            theme.platform_enemy_index = env_idx;
            theme.platform_player_index = env_idx;
        }
        if (variable_struct_exists(src, "platform_enemy_environment")){
            theme.platform_enemy_index = __battle_resolve_platform_index(variable_struct_get(src, "platform_enemy_environment"), theme.platform_enemy_index);
        }
        if (variable_struct_exists(src, "platform_player_environment")){
            theme.platform_player_index = __battle_resolve_platform_index(variable_struct_get(src, "platform_player_environment"), theme.platform_player_index);
        }
        if (variable_struct_exists(src, "platform_enemy_index")){
            theme.platform_enemy_index = __battle_resolve_platform_index(variable_struct_get(src, "platform_enemy_index"), theme.platform_enemy_index);
        }
        if (variable_struct_exists(src, "platform_player_index")){
            theme.platform_player_index = __battle_resolve_platform_index(variable_struct_get(src, "platform_player_index"), theme.platform_player_index);
        }
        if (variable_struct_exists(src, "platform_enemy_sprite")){
            theme.platform_enemy_sprite = variable_struct_get(src, "platform_enemy_sprite");
        }
        if (variable_struct_exists(src, "platform_player_sprite")){
            theme.platform_player_sprite = variable_struct_get(src, "platform_player_sprite");
        }
        if (variable_struct_exists(src, "platform_enemy_scale")){
            var scale_enemy = variable_struct_get(src, "platform_enemy_scale");
            if (is_real(scale_enemy)) theme.platform_enemy_scale = max(0.05, real(scale_enemy));
        }
        if (variable_struct_exists(src, "platform_player_scale")){
            var scale_player = variable_struct_get(src, "platform_player_scale");
            if (is_real(scale_player)) theme.platform_player_scale = max(0.05, real(scale_player));
        }
        if (variable_struct_exists(src, "platform_scale")){
            var scale_shared = variable_struct_get(src, "platform_scale");
            if (is_real(scale_shared)){
                var shared_val = max(0.05, real(scale_shared));
                theme.platform_enemy_scale = shared_val;
                theme.platform_player_scale = shared_val;
            }
        }
        if (variable_struct_exists(src, "platform_enemy_offset")){
            theme.platform_enemy_offset = __battle_parse_platform_offset(theme.platform_enemy_offset, variable_struct_get(src, "platform_enemy_offset"));
        }
        if (variable_struct_exists(src, "platform_player_offset")){
            theme.platform_player_offset = __battle_parse_platform_offset(theme.platform_player_offset, variable_struct_get(src, "platform_player_offset"));
        }
        if (variable_struct_exists(src, "platform_offset")){
            var off_shared = __battle_parse_platform_offset(theme.platform_player_offset, variable_struct_get(src, "platform_offset"));
            theme.platform_player_offset = off_shared;
            theme.platform_enemy_offset = off_shared;
        }
    }
    __battle_theme_refresh_text_colors(theme);
}