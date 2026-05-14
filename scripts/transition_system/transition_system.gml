globalvar TRANSITION_SYS;

function transition_init(){
    if (!variable_global_exists("TRANSITION_SYS") || !is_struct(global.TRANSITION_SYS)){
        global.TRANSITION_SYS = {
            active: false,
            mode: "",
            phase: "idle",
            style: "emerald_blinds",
            start_ms: 0,
            duration_ms: 520,
            target_room: noone,
            changed_room: false
        };
    }
    if (!variable_global_exists("TRANSITION_BATTLE_STYLE")) global.TRANSITION_BATTLE_STYLE = "emerald_blinds";
    if (!variable_global_exists("TRANSITION_ROOM_STYLE")) global.TRANSITION_ROOM_STYLE = "emerald_fade_black";
    if (!variable_global_exists("TRANSITION_BATTLE_DURATION_MS")) global.TRANSITION_BATTLE_DURATION_MS = 620;
    if (!variable_global_exists("TRANSITION_ROOM_DURATION_MS")) global.TRANSITION_ROOM_DURATION_MS = 420;
}

function transition_styles_list(){
    return [
        "none",
        "emerald_fade_black",
        "emerald_fade_white",
        "emerald_blinds",
        "emerald_vertical_blinds",
        "emerald_checker",
        "emerald_diamond",
        "emerald_spotlight",
        "emerald_split_horizontal",
        "emerald_split_vertical",
        "emerald_diagonal",
        "emerald_wave",
        "emerald_zigzag",
        "emerald_spiral",
        "emerald_pokeball"
    ];
}

function transition_set_battle_style(_style){
    transition_init();
    global.TRANSITION_BATTLE_STYLE = transition_normalize_style(_style);
}

function transition_set_room_style(_style){
    transition_init();
    global.TRANSITION_ROOM_STYLE = transition_normalize_style(_style);
}

function transition_normalize_style(_style){
    var _s = string_lower(string(_style));
    if (_s == "fade" || _s == "black") return "emerald_fade_black";
    if (_s == "white" || _s == "flash") return "emerald_fade_white";
    if (_s == "horizontal_blinds" || _s == "blinds") return "emerald_blinds";
    if (_s == "vertical_blinds") return "emerald_vertical_blinds";
    if (_s == "checkerboard") return "emerald_checker";
    if (_s == "diamond_iris") return "emerald_diamond";
    if (_s == "circle" || _s == "circle_iris") return "emerald_spotlight";
    if (_s == "pokeball" || _s == "poke_ball") return "emerald_pokeball";
    var _styles = transition_styles_list();
    for (var _i = 0; _i < array_length(_styles); ++_i){
        if (_s == _styles[_i]) return _s;
    }
    return "emerald_blinds";
}

function transition_battle_style(){
    transition_init();
    return transition_normalize_style(global.TRANSITION_BATTLE_STYLE);
}

function transition_room_style(){
    transition_init();
    return transition_normalize_style(global.TRANSITION_ROOM_STYLE);
}

function transition_is_blocking(){
    transition_init();
    return global.TRANSITION_SYS.active == true;
}

function transition_room_goto(_room, _style = undefined, _duration_ms = undefined){
    transition_init();
    var _T = global.TRANSITION_SYS;
    _T.active = true;
    _T.mode = "room";
    _T.phase = "out";
    _T.style = is_undefined(_style) ? transition_room_style() : transition_normalize_style(_style);
    _T.start_ms = current_time;
    _T.duration_ms = is_real(_duration_ms) ? max(1, real(_duration_ms)) : max(1, real(global.TRANSITION_ROOM_DURATION_MS));
    _T.target_room = _room;
    _T.changed_room = false;
    global.TRANSITION_SYS = _T;
}

function transition_update(){
    transition_init();
    var _T = global.TRANSITION_SYS;
    if (!is_struct(_T) || _T.active != true) return;
    if (_T.mode != "room") return;

    var _dur = max(1, real(_T.duration_ms));
    var _p = clamp((current_time - real(_T.start_ms)) / _dur, 0, 1);
    if (_T.phase == "out" && _p >= 1){
        if (!_T.changed_room && _T.target_room != noone){
            _T.changed_room = true;
            _T.phase = "in";
            _T.start_ms = current_time;
            global.TRANSITION_SYS = _T;
            room_goto(_T.target_room);
            return;
        }
        _T.phase = "in";
        _T.start_ms = current_time;
    } else if (_T.phase == "in" && _p >= 1){
        _T.active = false;
        _T.phase = "idle";
    }
    global.TRANSITION_SYS = _T;
}

function transition_draw_gui(){
    transition_draw_gui_rect(0, 0, display_get_gui_width(), display_get_gui_height());
}

function transition_draw_gui_rect(_rx, _ry, _rw, _rh){
    transition_init();
    var _T = global.TRANSITION_SYS;
    if (!is_struct(_T) || _T.active != true) return;
    var _dur = max(1, real(_T.duration_ms));
    var _p = clamp((current_time - real(_T.start_ms)) / _dur, 0, 1);
    var _cover = (_T.phase == "out") ? _p : (1 - _p);
    transition_draw_cover_rect(_T.style, _cover, _rx, _ry, _rw, _rh);
}

function transition_draw_battle_cover(_style, _progress, _rx, _ry, _rw, _rh){
    var _cover = 1 - clamp(real(_progress), 0, 1);
    transition_draw_cover_rect(_style, _cover, _rx, _ry, _rw, _rh);
}

function transition__ease(_t){
    _t = clamp(real(_t), 0, 1);
    return _t * _t * (3 - 2 * _t);
}

function transition__rect(_x1, _y1, _x2, _y2, _alpha, _color){
    if (_alpha <= 0) return;
    draw_set_color(_color);
    draw_set_alpha(clamp(_alpha, 0, 1));
    draw_rectangle(_x1, _y1, _x2, _y2, false);
}

function transition_draw_cover_rect(_style, _cover, _rx, _ry, _rw, _rh){
    var _s = transition_normalize_style(_style);
    var _c = transition__ease(clamp(real(_cover), 0, 1));
    if (_s == "none" || _c <= 0) return;

    var _x1 = _rx;
    var _y1 = _ry;
    var _x2 = _rx + _rw;
    var _y2 = _ry + _rh;
    var _cx = _rx + _rw * 0.5;
    var _cy = _ry + _rh * 0.5;
    var _black = c_black;
    var _white = c_white;

    if (_s == "emerald_fade_black"){
        transition__rect(_x1, _y1, _x2, _y2, _c, _black);
    } else if (_s == "emerald_fade_white"){
        transition__rect(_x1, _y1, _x2, _y2, _c, _white);
    } else if (_s == "emerald_blinds"){
        var _rows = 10;
        for (var _r = 0; _r < _rows; ++_r){
            var _h = ceil(_rh / _rows) + 1;
            var _yy = _y1 + _r * _h;
            var _w = _rw * _c;
            if ((_r mod 2) == 0) transition__rect(_x1, _yy, _x1 + _w, _yy + _h, 1, _black);
            else transition__rect(_x2 - _w, _yy, _x2, _yy + _h, 1, _black);
        }
    } else if (_s == "emerald_vertical_blinds"){
        var _cols = 12;
        for (var _col = 0; _col < _cols; ++_col){
            var _w2 = ceil(_rw / _cols) + 1;
            var _xx = _x1 + _col * _w2;
            var _h2 = _rh * _c;
            if ((_col mod 2) == 0) transition__rect(_xx, _y1, _xx + _w2, _y1 + _h2, 1, _black);
            else transition__rect(_xx, _y2 - _h2, _xx + _w2, _y2, 1, _black);
        }
    } else if (_s == "emerald_checker"){
        var _cell = max(6, floor(min(_rw, _rh) / 12));
        var _nx = ceil(_rw / _cell);
        var _ny = ceil(_rh / _cell);
        var _limit = _c * (_nx + _ny + 2);
        for (var _cyi = 0; _cyi < _ny; ++_cyi){
            for (var _cxi = 0; _cxi < _nx; ++_cxi){
                if (_cxi + _cyi <= _limit){
                    transition__rect(_x1 + _cxi * _cell, _y1 + _cyi * _cell, _x1 + (_cxi + 1) * _cell + 1, _y1 + (_cyi + 1) * _cell + 1, 1, _black);
                }
            }
        }
    } else if (_s == "emerald_diamond"){
        var _step = max(8, floor(min(_rw, _rh) / 8));
        var _rad = _step * (0.2 + _c * 2.2);
        for (var _dy = -_step; _dy < _rh + _step; _dy += _step){
            for (var _dx = -_step; _dx < _rw + _step; _dx += _step){
                var _px = _x1 + _dx + _step * 0.5;
                var _py = _y1 + _dy + _step * 0.5;
                draw_set_color(_black);
                draw_set_alpha(1);
                draw_triangle(_px, _py - _rad, _px + _rad, _py, _px, _py + _rad, false);
                draw_triangle(_px, _py - _rad, _px - _rad, _py, _px, _py + _rad, false);
            }
        }
    } else if (_s == "emerald_spotlight"){
        var _rad2 = max(_rw, _rh) * _c * 0.85;
        draw_set_color(_black);
        draw_set_alpha(1);
        draw_circle(_cx, _cy, _rad2, false);
    } else if (_s == "emerald_split_horizontal"){
        var _hh = (_rh * 0.5) * _c;
        transition__rect(_x1, _y1, _x2, _y1 + _hh, 1, _black);
        transition__rect(_x1, _y2 - _hh, _x2, _y2, 1, _black);
    } else if (_s == "emerald_split_vertical"){
        var _ww = (_rw * 0.5) * _c;
        transition__rect(_x1, _y1, _x1 + _ww, _y2, 1, _black);
        transition__rect(_x2 - _ww, _y1, _x2, _y2, 1, _black);
    } else if (_s == "emerald_diagonal"){
        var _d = (_rw + _rh) * _c;
        draw_set_color(_black);
        draw_set_alpha(1);
        draw_triangle(_x1, _y1, _x1 + _d, _y1, _x1, _y1 + _d, false);
        draw_triangle(_x2, _y2, _x2 - _d, _y2, _x2, _y2 - _d, false);
    } else if (_s == "emerald_wave"){
        var _bars = 14;
        for (var _b = 0; _b < _bars; ++_b){
            var _bh = ceil(_rh / _bars) + 1;
            var _phase = sin((_b * 0.85) + _c * 3.14159265);
            var _bw = _rw * clamp(_c + _phase * 0.12, 0, 1);
            transition__rect(_x1, _y1 + _b * _bh, _x1 + _bw, _y1 + (_b + 1) * _bh, 1, _black);
        }
    } else if (_s == "emerald_zigzag"){
        var _bands = 9;
        for (var _z = 0; _z < _bands; ++_z){
            var _zh = ceil(_rh / _bands) + 1;
            var _offset = ((_z mod 2) == 0) ? 0 : _rw * 0.08;
            transition__rect(_x1 - _offset, _y1 + _z * _zh, _x1 + _rw * _c + _offset, _y1 + (_z + 1) * _zh, 1, _black);
        }
    } else if (_s == "emerald_spiral"){
        var _rings = 6;
        for (var _q = 0; _q < _rings; ++_q){
            var _qp = clamp(_c * _rings - _q, 0, 1);
            if (_qp <= 0) continue;
            var _pad = _q * min(_rw, _rh) * 0.055;
            var _th = max(2, min(_rw, _rh) * 0.055 * _qp);
            transition__rect(_x1 + _pad, _y1 + _pad, _x2 - _pad, _y1 + _pad + _th, 1, _black);
            transition__rect(_x2 - _pad - _th, _y1 + _pad, _x2 - _pad, _y2 - _pad, 1, _black);
            transition__rect(_x1 + _pad, _y2 - _pad - _th, _x2 - _pad, _y2 - _pad, 1, _black);
            transition__rect(_x1 + _pad, _y1 + _pad, _x1 + _pad + _th, _y2 - _pad, 1, _black);
        }
    } else if (_s == "emerald_pokeball"){
        transition__rect(_x1, _y1, _x2, _cy, _c, make_color_rgb(180, 32, 32));
        transition__rect(_x1, _cy, _x2, _y2, _c, _white);
        transition__rect(_x1, _cy - 2, _x2, _cy + 2, _c, _black);
        draw_set_color(_black);
        draw_set_alpha(_c);
        draw_circle(_cx, _cy, min(_rw, _rh) * 0.11 * _c, false);
        draw_set_color(_white);
        draw_circle(_cx, _cy, min(_rw, _rh) * 0.055 * _c, false);
    } else {
        transition__rect(_x1, _y1, _x2, _y2, _c, _black);
    }

    draw_set_alpha(1);
    draw_set_color(c_white);
}
