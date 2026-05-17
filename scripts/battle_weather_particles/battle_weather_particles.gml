function __battle_weather_particles_get_id(_pid){
    if (is_undefined(__battle_get_weather) || is_undefined(__battle_weather_is_active)) return "";
    var _weather = __battle_get_weather(_pid);
    if (!__battle_weather_is_active(_weather)) return "";
    if (!is_undefined(__battle_weather_get_normalized_id)) return __battle_weather_get_normalized_id(_weather);
    return string_lower(string(variable_struct_exists(_weather, "id") ? variable_struct_get(_weather, "id") : ""));
}

function __battle_weather_particles_sprite(_name){
    var _spr = asset_get_index(_name);
    if (!is_undefined(_spr) && _spr != -1){
        try { if (sprite_exists(_spr)) return _spr; } catch (e_weather_sprite_exists) {}
    }
    return undefined;
}

function __battle_weather_particles_draw_rain(_pid){
    var _spr = __battle_weather_particles_sprite("spr_raindrop");
    var _has_sprite = !is_undefined(_spr);
    var _frames = 1;
    try { if (_has_sprite) _frames = max(1, sprite_get_number(_spr)); } catch (e_rain_frames) { _frames = 1; }

    var _x0 = __bxu(_pid, 0);
    var _y0 = __byu(_pid, 0);
    var _w = __bwu(_pid, 240);
    var _h = __bhu(_pid, 136);
    var _sx = max(1, __bwu(_pid, 1));
    var _sy = max(1, __bhu(_pid, 1));
    var _now = current_time;

    draw_set_color(make_color_rgb(38, 72, 116));
    draw_set_alpha(0.18);
    draw_rectangle(_x0, _y0, _x0 + _w, _y0 + _h, false);

    var _cols = 14;
    var _rows = 8;
    var _cell_w = 20 * _sx;
    var _cell_h = 24 * _sy;
    var _cycle = 680;
    var _fall = _cell_h + 32 * _sy;
    for (var _layer = 0; _layer < 2; ++_layer){
        var _speed = (_layer == 0) ? 1.0 : 1.55;
        var _alpha = (_layer == 0) ? 0.58 : 0.78;
        var _scale = ((_layer == 0) ? 0.72 : 0.92) * _sx;
        for (var _i = 0; _i < _cols * _rows; ++_i){
            var _col = _i mod _cols;
            var _row = _i div _cols;
            var _seed = abs(sin((_i + 1) * 27.713 + _layer * 91.17));
            var _jitter = (_seed - floor(_seed));
            var _phase = frac((_now * _speed + _i * 37 + _layer * 83) / _cycle);
            var _rx = _x0 - 28 * _sx + _col * _cell_w + _jitter * 10 * _sx - _phase * 36 * _sx;
            var _ry = _y0 - 32 * _sy + _row * _cell_h + _phase * _fall;
            while (_ry > _y0 + _h + 20 * _sy) _ry -= _rows * _cell_h;

            if (_has_sprite){
                var _frame = floor((_phase * _frames * 1.4) + _i + _layer) mod _frames;
                draw_sprite_ext(_spr, _frame, _rx, _ry, _scale, _scale, 0, c_white, _alpha);
            } else {
                draw_set_color(make_color_rgb(174, 206, 248));
                draw_set_alpha(_alpha);
                draw_line_width(_rx, _ry, _rx - 8 * _sx, _ry + 18 * _sy, max(1, floor(_sx)));
            }
        }
    }

    draw_set_alpha(1);
    draw_set_color(c_white);
}

function __battle_weather_particles_draw_sandstorm(_pid){
    var _x0 = __bxu(_pid, 0);
    var _y0 = __byu(_pid, 0);
    var _w = __bwu(_pid, 240);
    var _h = __bhu(_pid, 136);
    var _sx = max(1, __bwu(_pid, 1));
    var _now = current_time;
    draw_set_color(make_color_rgb(164, 134, 78));
    draw_set_alpha(0.14);
    draw_rectangle(_x0, _y0, _x0 + _w, _y0 + _h, false);
    for (var _i = 0; _i < 34; ++_i){
        var _seed = abs(sin((_i + 3) * 18.371));
        var _phase = frac((_now + _i * 41) / 900);
        var _x = _x0 + _w - _phase * (_w + 44 * _sx) + (_seed - floor(_seed)) * 32 * _sx;
        var _y = _y0 + 14 * _sx + ((_i * 17) mod 112) * _sx;
        draw_set_alpha(0.28);
        draw_line_width(_x, _y, _x + 16 * _sx, _y - 3 * _sx, max(1, floor(_sx)));
    }
    draw_set_alpha(1);
    draw_set_color(c_white);
}

function __battle_weather_particles_draw_hail(_pid){
    var _x0 = __bxu(_pid, 0);
    var _y0 = __byu(_pid, 0);
    var _w = __bwu(_pid, 240);
    var _h = __bhu(_pid, 136);
    var _sx = max(1, __bwu(_pid, 1));
    var _now = current_time;
    draw_set_color(make_color_rgb(186, 222, 250));
    draw_set_alpha(0.12);
    draw_rectangle(_x0, _y0, _x0 + _w, _y0 + _h, false);
    draw_set_color(make_color_rgb(224, 244, 255));
    for (var _i = 0; _i < 22; ++_i){
        var _phase = frac((_now + _i * 61) / 780);
        var _x = _x0 + ((_i * 31) mod 250) * _sx - _phase * 18 * _sx;
        var _y = _y0 - 12 * _sx + _phase * (_h + 24 * _sx);
        draw_set_alpha(0.55);
        draw_circle(_x, _y, max(1, floor(1.5 * _sx)), false);
    }
    draw_set_alpha(1);
    draw_set_color(c_white);
}

function __battle_weather_particles_draw_fog(_pid){
    var _x0 = __bxu(_pid, 0);
    var _y0 = __byu(_pid, 0);
    var _w = __bwu(_pid, 240);
    var _h = __bhu(_pid, 136);
    var _sx = max(1, __bwu(_pid, 1));
    var _now = current_time;
    draw_set_color(make_color_rgb(210, 218, 226));
    for (var _i = 0; _i < 5; ++_i){
        var _phase = frac((_now + _i * 370) / 2600);
        var _y = _y0 + (18 + _i * 20) * _sx;
        var _x = _x0 - 90 * _sx + _phase * (_w + 180 * _sx);
        draw_set_alpha(0.11);
        draw_ellipse(_x - 70 * _sx, _y - 8 * _sx, _x + 70 * _sx, _y + 8 * _sx, false);
    }
    draw_set_alpha(1);
    draw_set_color(c_white);
}

function __battle_weather_particles_draw_sun(_pid, _harsh){
    var _x0 = __bxu(_pid, 0);
    var _y0 = __byu(_pid, 0);
    var _w = __bwu(_pid, 240);
    var _h = __bhu(_pid, 136);
    var _sx = max(1, __bwu(_pid, 1));
    var _now = current_time;
    draw_set_color(_harsh ? make_color_rgb(255, 126, 54) : make_color_rgb(255, 208, 86));
    draw_set_alpha(_harsh ? 0.13 : 0.09);
    draw_rectangle(_x0, _y0, _x0 + _w, _y0 + _h, false);
    for (var _i = 0; _i < 5; ++_i){
        var _phase = frac((_now + _i * 520) / 2600);
        var _x = _x0 - 36 * _sx + _phase * (_w + 72 * _sx);
        var _y = _y0 + (10 + _i * 22) * _sx;
        draw_set_alpha(_harsh ? 0.16 : 0.1);
        draw_line_width(_x, _y, _x + 58 * _sx, _y + 7 * _sx, max(1, floor(_sx)));
    }
    draw_set_alpha(1);
    draw_set_color(c_white);
}

function __battle_weather_particles_draw(_pid, _B){
    if (!is_struct(_B) || !variable_struct_exists(_B, "sys_open") || variable_struct_get(_B, "sys_open") != true) return false;
    var _wid = __battle_weather_particles_get_id(_pid);
    switch (_wid){
        case "rain":
            __battle_weather_particles_draw_rain(_pid);
            return true;
        case "sandstorm":
            __battle_weather_particles_draw_sandstorm(_pid);
            return true;
        case "hail":
        case "snow":
            __battle_weather_particles_draw_hail(_pid);
            return true;
        case "fog":
            __battle_weather_particles_draw_fog(_pid);
            return true;
        case "sun":
            __battle_weather_particles_draw_sun(_pid, false);
            return true;
        case "harsh-sun":
            __battle_weather_particles_draw_sun(_pid, true);
            return true;
    }
    return false;
}
