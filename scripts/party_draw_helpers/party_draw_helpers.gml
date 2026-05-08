// Helper: draw and text utilities extracted from party_system for modularity
// Contains implementations prefixed with __party_impl_ to be called from the main party API.

// Draw a shiny sparkle effect at (_x,_y).
// Params: _S scale, _seed deterministic variation.
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

function __party_status_ui_has_status(_subject, _base_mon, _status_id){
    if (!is_string(_status_id) || string_length(_status_id) <= 0) return false;
    try {
        if (!is_undefined(status_system_has_status)){
            if (is_struct(_subject) && status_system_has_status(_subject, _status_id)) return true;
            if (is_struct(_base_mon) && _base_mon != _subject && status_system_has_status(_base_mon, _status_id)) return true;
        }
    } catch (e_status_ui_has) {}
    try {
        if (is_struct(_base_mon) && variable_struct_exists(_base_mon, "statuses")){
            var _statuses = variable_struct_get(_base_mon, "statuses");
            if (is_struct(_statuses) && variable_struct_exists(_statuses, _status_id) && !is_undefined(variable_struct_get(_statuses, _status_id))) return true;
        }
    } catch (e_status_ui_fallback) {}
    return false;
}

function __party_status_ui_normalize_legacy(_raw){
    if (is_undefined(_raw)) return "";
    var _s = string_lower(string(_raw));
    _s = string_trim(_s);
    _s = string_replace_all(_s, "_", "-");
    _s = string_replace_all(_s, " ", "-");
    if (_s == "" || _s == "0" || _s == "none" || _s == "healthy" || _s == "ok" || _s == "false") return "";
    if (_s == "freezing" || _s == "frozen") _s = "freeze";
    if (_s == "burned") _s = "burn";
    if (_s == "paralyzed") _s = "paralysis";
    if (_s == "sleeping" || _s == "asleep" || _s == "drowsy") _s = "sleep";
    if (_s == "bad-poison") _s = "toxic";

    if (is_real(_raw)){
        var _num = floor(real(_raw));
        switch (_num){
            case 1: return "sleep";
            case 2: return "poison";
            case 3: return "burn";
            case 4: return "freeze";
            case 5: return "paralysis";
            case 6: return "toxic";
            default: break;
        }
    }

    return _s;
}

function __party_status_ui_matches_legacy(_subject, _base_mon, _status_ids){
    var _legacy_keys = ["status", "status_name", "major_status"];
    var _targets = [_base_mon, _subject];
    for (var _ti = 0; _ti < array_length(_targets); ++_ti){
        var _target = _targets[_ti];
        if (!is_struct(_target)) continue;
        for (var _ki = 0; _ki < array_length(_legacy_keys); ++_ki){
            var _key = _legacy_keys[_ki];
            try {
                if (!variable_struct_exists(_target, _key)) continue;
                var _normalized = __party_status_ui_normalize_legacy(variable_struct_get(_target, _key));
                if (_normalized == "") continue;
                for (var _si = 0; _si < array_length(_status_ids); ++_si){
                    if (_normalized == _status_ids[_si]) return true;
                }
            } catch (e_status_ui_legacy) {}
        }
    }
    return false;
}

function __party_status_ui_push_unique(_arr, _value){
    if (!is_array(_arr) || !is_string(_value) || string_length(_value) <= 0) return;
    for (var _i = 0; _i < array_length(_arr); ++_i){
        if (_arr[_i] == _value) return;
    }
    array_push(_arr, _value);
}

function __party_status_ui_legacy_value(_subject, _base_mon){
    var _legacy_keys = ["status", "status_name", "major_status"];
    var _targets = [_base_mon, _subject];
    for (var _ti = 0; _ti < array_length(_targets); ++_ti){
        var _target = _targets[_ti];
        if (!is_struct(_target)) continue;
        for (var _ki = 0; _ki < array_length(_legacy_keys); ++_ki){
            var _key = _legacy_keys[_ki];
            try {
                if (!variable_struct_exists(_target, _key)) continue;
                var _normalized = __party_status_ui_normalize_legacy(variable_struct_get(_target, _key));
                if (_normalized != "") return _normalized;
            } catch (e_status_ui_legacy_value) {}
        }
    }
    return "";
}

function __party_status_ui_collect(_mon_or_actor){
    if (!is_struct(_mon_or_actor)) return [];

    var _base_mon = _mon_or_actor;
    if (variable_struct_exists(_mon_or_actor, "mon") && is_struct(variable_struct_get(_mon_or_actor, "mon"))) _base_mon = variable_struct_get(_mon_or_actor, "mon");

    var _hp_now = undefined;
    if (variable_struct_exists(_base_mon, "hp_now")) _hp_now = variable_struct_get(_base_mon, "hp_now");
    else if (variable_struct_exists(_base_mon, "hp")) _hp_now = variable_struct_get(_base_mon, "hp");
    else if (variable_struct_exists(_base_mon, "HP")) _hp_now = variable_struct_get(_base_mon, "HP");

    var _is_fainted = false;
    try {
        if (variable_struct_exists(_mon_or_actor, "_fainted") && variable_struct_get(_mon_or_actor, "_fainted") == true) _is_fainted = true;
        if (!_is_fainted && variable_struct_exists(_base_mon, "_fainted") && variable_struct_get(_base_mon, "_fainted") == true) _is_fainted = true;
    } catch (e_status_ui_collect_faint) {}
    if (_is_fainted || (is_real(_hp_now) && _hp_now <= 0)) return ["fnt"];

    var _out = [];

    var _legacy = __party_status_ui_legacy_value(_mon_or_actor, _base_mon);
    if (_legacy != "") __party_status_ui_push_unique(_out, _legacy);

    var _priority = [
        "poison","toxic","paralysis","paralyze","sleep","freeze","burn",
        "confusion","infatuation","trap","yawn","nightmare","disable","encore",
        "taunt","torment","heal-block","embargo","leech-seed","ingrain","substitute",
        "perish-song","uproar","imprison","magic-coat","snatch","miracle-eye",
        "grudge","tailwind","gravity","roost","follow-me","helping-hand","dynamax"
    ];

    for (var _pi = 0; _pi < array_length(_priority); ++_pi){
        var _sid = _priority[_pi];
        if (__party_status_ui_has_status(_mon_or_actor, _base_mon, _sid)) __party_status_ui_push_unique(_out, _sid);
    }

    try {
        if (variable_global_exists("STATUS_SYS") && is_array(global.STATUS_SYS.ids)){
            var _ids = global.STATUS_SYS.ids;
            for (var _gi = 0; _gi < array_length(_ids); ++_gi){
                var _gid = string_lower(string(_ids[_gi]));
                if (string_length(_gid) <= 0) continue;
                if (__party_status_ui_has_status(_mon_or_actor, _base_mon, _gid)) __party_status_ui_push_unique(_out, _gid);
            }
        }
    } catch (e_status_ui_collect_registry) {}

    var _pkrs_keys = ["pkrs", "pokerus", "has_pkrs", "has_pokerus"];
    for (var _pk_i = 0; _pk_i < array_length(_pkrs_keys); ++_pk_i){
        var _pk_key = _pkrs_keys[_pk_i];
        try {
            if (!variable_struct_exists(_base_mon, _pk_key)) continue;
            var _pk_val = variable_struct_get(_base_mon, _pk_key);
            if ((is_bool(_pk_val) && _pk_val) || (is_real(_pk_val) && _pk_val > 0) || (is_string(_pk_val) && string_length(string_trim(_pk_val)) > 0 && string_lower(string_trim(_pk_val)) != "false" && string_trim(_pk_val) != "0")){
                __party_status_ui_push_unique(_out, "pkrs");
                break;
            }
        } catch (e_status_ui_collect_pkrs) {}
    }

    return _out;
}

function __party_status_ui_sprite_frame_for(_sid){
    switch (string_lower(string(_sid))){
        case "poison":
        case "toxic": return 0;
        case "paralysis":
        case "paralyze": return 1;
        case "sleep": return 2;
        case "freeze": return 3;
        case "burn": return 4;
        case "pkrs": return 5;
        case "fnt": return 6;
        case "confusion": return 7;
    }
    return -1;
}

function __party_status_ui_sprite_frames(_mon_or_actor){
    var _statuses = __party_status_ui_collect(_mon_or_actor);
    if (!is_array(_statuses) || array_length(_statuses) <= 0) return [];

    var _frames = [];
    for (var _i = 0; _i < array_length(_statuses); ++_i){
        var _frame = __party_status_ui_sprite_frame_for(_statuses[_i]);
        if (_frame >= 0) __party_status_ui_push_unique(_frames, string(_frame));
    }

    var _out = [];
    for (var _j = 0; _j < array_length(_frames); ++_j){
        array_push(_out, real(_frames[_j]));
    }
    return _out;
}

function __party_draw_status_ui(_x, _y, _scale, _mon_or_actor, _max_width = -1, _alpha = 1){
    if (!sprite_exists(spr_statusUI)) return 0;

    var _statuses = __party_status_ui_collect(_mon_or_actor);
    if (!is_array(_statuses) || array_length(_statuses) <= 0) return 0;

    var _safe_scale = max(0.5, real(_scale));
    var _old_alpha = draw_get_alpha();
    var _old_color = draw_get_color();
    var _sprite_w = max(1, sprite_get_width(spr_statusUI));
    var _sprite_h = max(1, sprite_get_height(spr_statusUI));
    var _draw_step = max(1, floor(_sprite_w * _safe_scale));
    var _draw_h = max(1, floor(_sprite_h * _safe_scale));
    var _gap = max(1, round(2 * _safe_scale));
    var _cursor_x = _x;
    var _drawn_w = 0;

    draw_set_alpha(clamp(_alpha, 0, 1));
    draw_set_color(c_white);

    for (var _si = 0; _si < array_length(_statuses); ++_si){
        var _sid = _statuses[_si];
        var _frame = __party_status_ui_sprite_frame_for(_sid);
        var _item_w = _draw_step;
        if (_frame < 0) continue;
        var _next_w = _item_w + ((_drawn_w > 0) ? _gap : 0);
        if (is_real(_max_width) && _max_width > 0 && (_drawn_w + _next_w) > _max_width) break;
        if (_drawn_w > 0) _cursor_x += _gap;
        draw_sprite_ext(spr_statusUI, _frame, _cursor_x, _y, _safe_scale, _safe_scale, 0, c_white, clamp(_alpha, 0, 1));
        _cursor_x += _item_w;
        _drawn_w = _cursor_x - _x;
    }

    draw_set_alpha(_old_alpha);
    draw_set_color(_old_color);
    return _drawn_w;
}

// Clean description text by removing control/newline characters and trimming.
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

// Draw scrollable, color-annotated description text into a box.
// Highlights keywords (types, physical/special/status/heal) with colors.
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

// Draw a simple vertical scrollbar for a scrollable text area.
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

// Helper to set the project's Pokemon font, returning previous font id.
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
