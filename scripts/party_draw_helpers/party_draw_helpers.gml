// Helper: draw and text utilities extracted from party_system for modularity
// Contains implementations prefixed with __party_impl_ to be called from the main party API.

function __party_impl_draw_shiny_sparkle(_x,_y,_S,_seed){
    // Stable animated sparkle (diamond + cross) that rotates & pulses.
    var t_ms = current_time;
    var t    = t_ms / 1000;
    var rot  = (t * PARTY_SHINY_SPARKLE_ROT_SPEED + _seed * 37) mod 360;
    var pulse = 0.55 + 0.45 * sin(t * PARTY_SHINY_SPARKLE_PULSE_HZ + _seed);
    var r  = PARTY_SHINY_SPARKLE_BASE_R * _S * pulse;
    var r2 = r * 0.55;

    // Outer glow diamond (two filled triangles)
    draw_set_color(make_color_rgb(255,240,110));
    var x1 = _x + lengthdir_x(r, rot);
    var y1 = _y + lengthdir_y(r, rot);
    var x3 = _x + lengthdir_x(r, rot+180);
    var y3 = _y + lengthdir_y(r, rot+180);
    var x2 = _x + lengthdir_x(r2, rot+90);
    var y2 = _y + lengthdir_y(r2, rot+90);
    var x4 = _x + lengthdir_x(r2, rot+270);
    var y4 = _y + lengthdir_y(r2, rot+270);
    draw_triangle(x1,y1,x2,y2,x3,y3,false);
    draw_triangle(x3,y3,x4,y4,x1,y1,false);

    // Rotated cross (thin rays) — faint
    draw_set_color(make_color_rgb(255,255,200));
    var rLine = r * 1.15;
    var xA = _x + lengthdir_x(rLine, rot+45);
    var yA = _y + lengthdir_y(rLine, rot+45);
    var xB = _x + lengthdir_x(rLine, rot+225);
    var yB = _y + lengthdir_y(rLine, rot+225);
    var xC = _x + lengthdir_x(rLine, rot+135);
    var yC = _y + lengthdir_y(rLine, rot+135);
    var xD = _x + lengthdir_x(rLine, rot+315);
    var yD = _y + lengthdir_y(rLine, rot+315);
    draw_line_width(xA,yA,xB,yB,1);
    draw_line_width(xC,yC,xD,yD,1);

    // Inner core (steady)
    draw_set_color(c_white);
    var core = max(1, r * 0.30);
    draw_rectangle(_x-core,_y-core,_x+core,_y+core,false);
    draw_set_color(c_white);
}

function __party_impl_desc_clean_local(_s){
    var _t = string(_s);
    _t = string_replace_all(_t, "\n", " ");
    _t = string_replace_all(_t, "\r", " ");
    _t = string_replace_all(_t, "\f", " ");
    _t = string_replace_all(_t, "\\n", " ");
    _t = string_replace_all(_t, "\\r", " ");
    _t = string_replace_all(_t, "\\f", " ");
    while (string_pos("  ", _t) > 0) _t = string_replace_all(_t, "  ", " ");
    return string_trim(_t);
}

function __party_impl_desc_draw_scrollable_colored(_x, _y, _w, _h, _text) {
    if (string_length(string(_text)) <= 0) return;

    // Reset scroll if content changed (compare hash/key)
    static _scroll = 0;
    static _lastKey = "";
    var _key = string(_text);
    if (_key != _lastKey) { _scroll = 0; _lastKey = _key; }

    var _restoreTo = -1;
    if (variable_global_exists("FNT_POKEMON")) _restoreTo = global.FNT_POKEMON;
    if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    var _words = string_split(string(_text), " ");
    var _lines = [];
    var _cur = "";
    var _i, _n = array_length(_words);

    for (_i = 0; _i < _n; _i++) {
        var _test = (_cur == "") ? _words[_i] : (_cur + " " + _words[_i]);
        if (string_width(_test) <= _w) {
            _cur = _test;
        } else {
            if (string_length(_cur) == 0) {
                var _word = _words[_i];
                var _k, _seg = "";
                for (_k = 1; _k <= string_length(_word); _k++) {
                    var _segTest = _seg + string_copy(_word, _k, 1);
                    if (string_width(_segTest) > _w) {
                        array_push(_lines, _seg);
                        _seg = string_copy(_word, _k, 1);
                    } else {
                        _seg = _segTest;
                    }
                }
                _cur = _seg;
            } else {
                array_push(_lines, _cur);
                _cur = _words[_i];
            }
        }
    }
    if (string_length(_cur) > 0) array_push(_lines, _cur);

    var _lineH = max(12, string_height("A") + 2);
    var _totalH = array_length(_lines) * _lineH;

    if (variable_global_exists("sys_party_desc_scroll_req")){
        _scroll += global.sys_party_desc_scroll_req;
        global.sys_party_desc_scroll_req = 0;
    }
    var _maxScroll = max(0, _totalH - _h);
    if (_scroll < 0) _scroll = 0;
    if (_scroll > _maxScroll) _scroll = _maxScroll;

    var _hitPhysical=false, _hitSpecial=false, _hitStatus=false, _hitHeal=false, _hitDefense=false;
    var _hitType = ds_map_create();
    var _types = ["fire","water","grass","electric","ice","fighting","psychic","dark","fairy","ground","flying","rock","steel","bug","ghost","dragon","poison"];
    for (var ti = 0; ti < array_length(_types); ti++) ds_map_add(_hitType, _types[ti], 0);

    var _startLine = floor(_scroll / _lineH);
    var _offsetY = -(_scroll - (_startLine * _lineH));
    var _yPos = _y + _offsetY;

    for (var li = _startLine; li < array_length(_lines); li++) {
        if (_yPos + _lineH > _y + _h) break;

        var L = _lines[li];
        var parts = string_split(L, " ");
        var xx = _x;
        for (var wi = 0; wi < array_length(parts); wi++){
            var w = parts[wi];
            var wlower = string_lower(w);
            var core = wlower;
            core = string_replace_all(core, ",", "");
            core = string_replace_all(core, ".", "");
            core = string_replace_all(core, "!", "");
            core = string_replace_all(core, "?", "");

            var useCol = c_white;

            if (!_hitPhysical && core == "physical"){ useCol = make_color_rgb(255,140,120); _hitPhysical = true; }
            else if (! _hitSpecial && core == "special"){ useCol = make_color_rgb(120,180,255); _hitSpecial = true; }
            else if (! _hitStatus && core == "status"){ useCol = make_color_rgb(255,240,140); _hitStatus = true; }
            else if (! _hitHeal && core == "heal"){ useCol = make_color_rgb(120,255,160); _hitHeal = true; }
            else if (! _hitDefense && (core == "defense" || core == "defensive")){ useCol = make_color_rgb(200,200,200); _hitDefense = true; }
            else {
                if (ds_map_exists(_hitType, core) && (ds_map_find_value(_hitType, core) == 0)){
                    var col = c_white;
                    switch (core){
                        case "fire": col = make_color_rgb(255,150,80); break;
                        case "water": col = make_color_rgb(100,180,255); break;
                        case "grass": col = make_color_rgb(100,220,120); break;
                        case "electric": col = make_color_rgb(255,235,120); break;
                        case "ice": col = make_color_rgb(190,250,255); break;
                        case "fighting": col = make_color_rgb(240,100,100); break;
                        case "psychic": col = make_color_rgb(255,120,255); break;
                        case "dark": col = make_color_rgb(150,100,80); break;
                        case "fairy": col = make_color_rgb(255,200,255); break;
                        case "ground": col = make_color_rgb(220,180,100); break;
                        case "flying": col = make_color_rgb(200,240,255); break;
                        case "rock": col = make_color_rgb(220,200,140); break;
                        case "steel": col = make_color_rgb(200,200,220); break;
                        case "bug": col = make_color_rgb(180,220,100); break;
                        case "ghost": col = make_color_rgb(180,130,220); break;
                        case "dragon": col = make_color_rgb(120,100,255); break;
                        case "poison": col = make_color_rgb(200,120,200); break;
                    }
                    useCol = col;
                    ds_map_replace(_hitType, core, 1);
                }
            }

            draw_set_color(useCol);
            draw_text(xx, _yPos, parts[wi]);
            var adv = string_width(parts[wi]);
            xx += adv + string_width(" ");
        }

        _yPos += _lineH;
    }

    var _totalH2 = array_length(_lines) * _lineH;
    var _maxScroll2 = max(0, _totalH2 - _h);
    
    if (_maxScroll2 > 0) {
        var _trackW   = 5;
        var _trackH   = _h;
        var _trackX1  = _x + _w - _trackW + 3; 
        var _trackY1  = _y;
        var _trackX2  = _trackX1 + _trackW;
        var _trackY2  = _trackY1 + _trackH;
        var _inset    = 1;

        var _oldCol   = draw_get_color();
        var _oldAlpha = draw_get_alpha();

        draw_set_color(c_black);
        draw_rectangle(_trackX1, _trackY1, _trackX2, _trackY2, false);
        draw_set_color(c_white);
        draw_rectangle(_trackX1, _trackY1, _trackX2, _trackY2, true);

        var _visibleFrac = clamp(_h / _totalH2, 0, 1);
        var _thumbH      = max(8, floor((_trackH - _inset*2) * _visibleFrac));
        var _t           = (_maxScroll2 > 0) ? (_scroll / _maxScroll2) : 0;
        var _usableH     = (_trackH - _inset*2 - _thumbH);
        var _thumbTop    = _trackY1 + _inset + floor(_usableH * _t);
        var _thumbBot    = _thumbTop + _thumbH;

        draw_set_color(make_color_rgb(160,120,64));
        draw_rectangle(_trackX1 + _inset, _thumbTop, _trackX2 - _inset, _thumbBot, false);

        draw_set_color(c_black);
        draw_rectangle(_trackX1 + _inset, _thumbTop, _trackX2 - _inset, _thumbBot, true);

        draw_set_color(_oldCol);
    }
    if (_restoreTo != -1) draw_set_font(_restoreTo);
}

function __party_impl_draw_scrollbar(_rx, _ry, _rw, _rh, _scroll, _pageSize, _totalItems) {
    var _oldCol = draw_get_color();
    var _oldAlpha = draw_get_alpha();

    var _inset = 1;
    var _visible = max(1, _pageSize);
    var _total = max(_visible, _totalItems);
    var _maxScroll = max(0, _total - _visible);
    var _t = 0;
    if (_maxScroll > 0) { _t = clamp(_scroll / _maxScroll, 0, 1); }

    draw_set_color(c_black);
    draw_rectangle(_rx, _ry, _rx + _rw, _ry + _rh, false);
    draw_set_color(c_white);
    draw_rectangle(_rx, _ry, _rx + _rw, _ry + _rh, true);

    var _visibleFrac = (_total > 0) ? (_visible / _total) : 1;
    var _thumbH = max(8, floor((_rh - _inset*2) * _visibleFrac));
    var _usable = (_rh - _inset*2 - _thumbH);
    if (_usable < 0) _usable = 0;
    var _thumbTop = _ry + _inset + floor(_usable * _t);
    var _thumbBot = _thumbTop + _thumbH;

    draw_set_color(make_color_rgb(160,120,64));
    draw_rectangle(_rx + _inset, _thumbTop, _rx + _rw - _inset, _thumbBot, false);
    draw_set_color(c_black);
    draw_rectangle(_rx + _inset, _thumbTop, _rx + _rw - _inset, _thumbBot, true);

    draw_set_color(_oldCol);
}

function __party_impl_use_font(){
    var _old = -1;
    if (variable_global_exists("FNT_POKEMON")){
        _old = draw_get_font();
        draw_set_font(global.FNT_POKEMON);
    }
    return _old;
}
function __party_impl_restore_font(_old){ if (_old != -1) draw_set_font(_old); }
function __party_impl_text_white(_x,_y,_txt){ var _old = __party_impl_use_font(); draw_set_color(c_white); draw_text(_x,_y,_txt); __party_impl_restore_font(_old); }
