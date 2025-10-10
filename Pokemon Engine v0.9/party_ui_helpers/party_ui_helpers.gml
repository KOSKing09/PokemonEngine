// Party UI helpers (migrated from party_system.gml)
// Implementations are named __party_impl_* and are called by forwarding stubs in party_system.gml

function __party_impl_draw_summary(_pid, _P, _OX, _OY, _S){
    var _C_BG    = make_color_rgb(224, 216, 248);
    var _C_PAPER = make_color_rgb(255, 243, 195);
    var _C_EDGE  = make_color_rgb(64, 56, 112);
    var _C_ACC   = make_color_rgb(208, 48, 48);
    var _C_TEXT  = c_white;

    gpu_set_blendmode(bm_normal);
    draw_set_color(_C_BG);   draw_rectangle(_OX, _OY, _OX + 240*_S, _OY + 160*_S, false);
    draw_set_color(_C_EDGE); draw_rectangle(_OX, _OY, _OX + 240*_S, _OY + 20*_S, true);

    var _mons = __party_mons(_pid), _n = array_length(_mons);
    __party_impl_draw_header_and_circles(_P, _OX, _OY, _S, _n, _C_ACC, _C_PAPER);

    var _LEFT_X = 8, _LEFT_Y = 24, _LEFT_W = 96, _LEFT_H = 120;
    var _RIGHT_X = 108, _RIGHT_Y = 24, _RIGHT_W = 124, _RIGHT_H = 120;

    var _M = __party_mon_get(_P, _pid);
    var _leftInfo = __party_impl_draw_left_panel(_P, _M, _OX, _OY, _S, _LEFT_X, _LEFT_Y, _LEFT_W, _LEFT_H);
    var _rightInfo = __party_impl_draw_right_frame(_OX, _OY, _S, _RIGHT_X, _RIGHT_Y, _RIGHT_W, _RIGHT_H);

    var _descPad = _leftInfo.descPad;
    var _descAreaH = _leftInfo.descAreaH;
    var _descX = _leftInfo.descX;
    var _descY = _leftInfo.descY;
    var _descW = _leftInfo.descW;
    var _descH = _leftInfo.descH;

    var _descText = __party_get_desc_text(_P, _M);
    if (string_length(_descText) > 0) {
        var _clean = __party_impl_desc_clean_local(_descText);
        __party_impl_desc_draw_scrollable_colored(_descX, _descY, _descW, _descH, _clean);
    }

    var _secondaryLine = __party_impl_draw_right_content(_P, _M, _rightInfo, _RIGHT_W, _RIGHT_H, _S);

    if (string_length(_secondaryLine) > 0){
        __party_impl_draw_secondary_help(_secondaryLine, _OX, _S, _leftInfo);
    }
}

function __party_impl_draw_profile_block(_M, _x, _y, _w, _h, _S){
    var _C_LABEL = make_color_rgb(40, 96, 96);
    var _lh = max(12, string_height("A") + 2) * _S;
    __party_impl_text_white(_x + 6*_S, _y + 6*_S, "PROFILE");
    draw_set_color(_C_LABEL);
    draw_text(_x + 6*_S, _y + 6*_S + _lh*1, "OT/");
    draw_text(_x + 6*_S, _y + 6*_S + _lh*2, "TYPE/");
    draw_text(_x + 6*_S, _y + 6*_S + _lh*3, "ABILITY/");
    draw_text(_x + 6*_S, _y + 6*_S + _lh*5, "TRAINER MEMO");
    draw_set_color(c_white);
    var _ot="—", _idno="—", _typ="—", _abi="—", _nat="—", _metLv="—", _metMp="—";
    if (is_struct(_M)){
        if (variable_struct_exists(_M,"ot"))   _ot   = string(_M.ot);
        if (variable_struct_exists(_M,"idno")) _idno = string(_M.idno);
        var _type_names = [];
        if (variable_struct_exists(_M,"type")){
            if (is_array(_M.type)){
                for (var ti=0; ti<array_length(_M.type); ti++) array_push(_type_names, string(_M.type[ti]));
            } else {
                array_push(_type_names, string(_M.type));
            }
        }
        if (array_length(_type_names) == 0 && variable_struct_exists(_M,"types") && is_array(_M.types)){
            for (var ti2=0; ti2<array_length(_M.types); ti2++){
                var tid = _M.types[ti2];
                if (is_real(tid)) array_push(_type_names, "#"+string(tid));
            }
        }
        if (array_length(_type_names) == 0){
            if (variable_struct_exists(_M,"type1") && is_real(_M.type1) && _M.type1 >= 0) array_push(_type_names, "#"+string(_M.type1));
            if (variable_struct_exists(_M,"type2") && is_real(_M.type2) && _M.type2 >= 0) array_push(_type_names, "#"+string(_M.type2));
        }
        for (var tn = 0; tn < array_length(_type_names); tn++){
            var cur = _type_names[tn];
            if (string_length(cur) > 0 && string_char_at(cur,1) == "#"){
                var nid = real(string_delete(cur,1,1));
                var resolved = "";
                if (variable_global_exists("TYPE_ID_BY_NAME") && ds_exists(TYPE_ID_BY_NAME, ds_type_map)){
                    var _k = ds_map_find_first(TYPE_ID_BY_NAME);
                    while(_k != undefined){
                        var _v = ds_map_find_value(TYPE_ID_BY_NAME, _k);
                        if (is_real(_v) && _v == nid){ resolved = string(_k); break; }
                        _k = ds_map_find_next(TYPE_ID_BY_NAME, _k);
                    }
                }
                if (string_length(resolved) == 0){
                    var __builtin = ["Normal","Fire","Water","Electric","Grass","Ice","Fighting","Poison","Ground","Flying","Psychic","Bug","Rock","Ghost","Dark","Dragon","Steel","Fairy"];
                    if (nid >= 1 && nid <= array_length(__builtin)) resolved = __builtin[nid];
                    else resolved = "Type"+string(nid);
                }
                _type_names[tn] = resolved;
            } else {
                var s = string(cur);
                if (string_length(s) > 0) _type_names[tn] = string_upper(string_copy(s,1,1)) + string_delete(s,1,1);
            }
        }
        if (array_length(_type_names) > 0){
            if (array_length(_type_names) == 1) _typ = _type_names[0];
            else _typ = _type_names[0] + " / " + _type_names[1];
        }
        if (variable_struct_exists(_M,"ability"))  _abi  = string(_M.ability);
        if (variable_struct_exists(_M,"nature"))   _nat  = string(_M.nature);
        if (variable_struct_exists(_M,"met_level")) _metLv = string(_M.met_level);
        if (variable_struct_exists(_M,"met_map"))   _metMp = string(_M.met_map);
    }
    var _ot_label_x = _x + 6*_S;
    var _ot_value_x = _ot_label_x + string_width("OT/") + 4;
    draw_text(_ot_value_x, _y + 6*_S + _lh*1, _ot);
    var _type_label_x = _x + 6*_S;
    var _type_value_x = _type_label_x + string_width("TYPE/") + 4;
    draw_text(_type_value_x, _y + 6*_S + _lh*2, _typ);
    draw_text(_x + 60*_S, _y + 6*_S + _lh*3, _abi);
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*6, string_upper(_nat) + " nature,");
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*7, "met at Lv." + _metLv + ",");
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*8, _metMp + ".");
}

function __party_impl_draw_moves_block(_P, _M, _x, _y, _w, _h, _S, _highlightForget){
    var _lh = max(12, string_height("A") + 2) * _S;
    draw_set_color(c_white);
    draw_text(_x + 6*_S, _y + 6*_S, "MOVES");

    var _mv = is_struct(_M) && variable_struct_exists(_M,"moves") ? _M.moves : [];
    var _nm = array_length(_mv);
    for (var _i = 0; _i < max(4,_nm); _i++){
        var _lineY = _y + 20*_S + _lh*_i;
        var _txt = (_i < _nm) ? __party_move_name(_mv[_i]) : "—";
        draw_set_color( _i == _P.sum_move_sel ? (_highlightForget ? make_color_rgb(232,64,48) : make_color_rgb(72,200,88)) : c_white );
        draw_text(_x + 10*_S, _lineY, _txt);
    }

    var _lr = is_struct(_M) && variable_struct_exists(_M,"learnset") ? _M.learnset : [];
    var _nl = array_length(_lr);
    for (var _j = 0; _j < _nl; _j++){
        var _lineY2 = _y + 20*_S + _lh*_j;
        var _txt2 = __party_move_name(_lr[_j]);
        draw_set_color( _j == _P.sum_learn_sel ? make_color_rgb(72,160,232) : c_white );
        draw_text(_x + (_w*_S) - 110*_S, _lineY2, _txt2);
    }

    draw_set_color(c_white);
    var _primaryHelp, _secondaryHelp;
    if (_highlightForget){
        _primaryHelp   = "A: Confirm  B: Back";
        _secondaryHelp = "(Choose a move to overwrite)";
    } else {
        _primaryHelp   = "A: Learn  B: Back";
        _secondaryHelp = "Hold Inv+Up/Down: Learnset";
    }
    var _tx = _x + 6*_S;
    var _lhh = max(12, string_height("A") + 2);
    var _innerBottomPad = 6*_S;
    var _pMaxW = (_w*_S) - 12*_S;
    var _aLine, _bLine;
    if (_highlightForget){ _aLine = "A: Confirm"; _bLine = "B: Back"; }
    else { _aLine = "A: Learn"; _bLine = "B: Back"; }
    function _party_trunc_line(_t,_mw){
        if (string_width(_t) <= _mw) return _t;
        while (string_width(_t + "...") > _mw && string_length(_t) > 4){
            _t = string_copy(_t,1,string_length(_t)-1);
        }
        if (string_length(_t) > 3) _t += "...";
        return _t;
    }
    _aLine = _party_trunc_line(_aLine,_pMaxW);
    _bLine = _party_trunc_line(_bLine,_pMaxW);
    var _pyBottom = _y + (_h*_S) - _lhh - _innerBottomPad;
    var _pyTop    = _pyBottom - _lhh;
    draw_text(_tx, _pyTop, _aLine);
    draw_text(_tx, _pyBottom, _bLine);
    return _secondaryHelp;
}

function __party_impl_draw_secondary_help(_text, _OX, _S, _leftInfo){
    var _fullLeft  = _OX + 0;
    var _fullRight = _OX + 240*_S;
    var _availW = _fullRight - _fullLeft - 4*_S;
    var _drawX = _fullLeft + 2*_S;
    var _baseY = (_leftInfo.descY + _leftInfo.descH) + 11*_S;
    draw_set_color(c_white);
    var _words = string_split(_text, " ");
    var _lines = [];
    var _acc = "";
    for (var i=0; i<array_length(_words); i++){
        var w = _words[i];
        var t = (_acc == "") ? w : (_acc + " " + w);
        if (string_width(t) <= _availW){ _acc = t; }
        else { if (string_length(_acc) > 0) array_push(_lines, _acc); _acc = w; }
        if (array_length(_lines) >= 2) break;
    }
    if (array_length(_lines) < 2 && string_length(_acc) > 0) array_push(_lines, _acc);
    if (array_length(_lines) > 2) array_resize(_lines, 2);
    if (array_length(_lines) == 2 && i < array_length(_words)){
        var last = _lines[1];
        while (string_width(last + "...") > _availW && string_length(last) > 5){ last = string_copy(last,1,string_length(last)-1); }
        if (string_length(last) > 3) last += "...";
        _lines[1] = last;
    }
    var _lineHeight = max(12, string_height("A") + 2);
    for (var li=0; li<array_length(_lines); li++){
        draw_text(_drawX, _baseY + li * _lineHeight, _lines[li]);
    }
}

function __party_impl_draw_left_panel(_P, _M, _OX, _OY, _S, _LEFT_X, _LEFT_Y, _LEFT_W, _LEFT_H){
    var _lx1 = _OX + _LEFT_X*_S,  _ly1 = _OY + _LEFT_Y*_S;
    var _lx2 = _OX + (_LEFT_X + _LEFT_W)*_S, _ly2 = _OY + (_LEFT_Y + _LEFT_H)*_S;
    var _PARCHMENT = make_color_rgb(255,243,195);
    draw_set_color(_PARCHMENT); draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
    var _C_EDGE = make_color_rgb(64, 56, 112);
    draw_set_color(_C_EDGE);  draw_rectangle(_lx1- _S, _ly1- _S, _lx2+ _S, _ly2+ _S, true);

    var _DESC_PAD = 3 * _S;
    var _DESC_AREA_H = 38 * _S;

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    if (is_struct(_M)){
        var _nm = "???";
        if (variable_struct_exists(_M,"species_id") && is_real(_M.species_id)){
            var _idn = scr_poke_name_by_id(_M.species_id);
            if (string_length(_idn) > 0){
                _nm = string_replace_all(_idn, "-", " ");
                if (string_length(_nm) > 0) _nm = string_upper(string_copy(_nm,1,1)) + string_delete(_nm,1,1);
            }
        } else if (variable_struct_exists(_M,"species")) _nm = string(_M.species);
        else if (variable_struct_exists(_M,"name"))     _nm = string(_M.name);
        draw_text(_lx1 + 6*_S, _ly1 + 6*_S, _nm);

        var _sprArt = -1;
        if (!is_undefined(pkicons_get_art96_by_mon)) _sprArt = pkicons_get_art96_by_mon(_M);
        if (_sprArt == -1) _sprArt = spr_mon_placeholder;

        if (_sprArt != -1){
            var _artW = sprite_get_width(_sprArt), _artH = sprite_get_height(_sprArt);
            var _innerW   = (_LEFT_W - 12) * _S;
            var _topY     = _ly1 + 18 * _S;
            var _bottomY  = _ly2 - _DESC_AREA_H - PARTY_SUMMARY_ART_MARGIN * _S;
            var _availH   = max(1, _bottomY - _topY);
            var _sc   = min(_innerW / _artW, _availH / _artH);
            var _dx   = _lx1 + (_LEFT_W * _S - _artW * _sc) * 0.5 + (PARTY_SUMMARY_ART_OFFSET_X * _S);
            var _idealY = _topY + (_availH - _artH * _sc) * 0.5;
            var _dy   = clamp(_idealY + (PARTY_SUMMARY_ART_OFFSET_Y * _S), _topY, _bottomY - _artH * _sc);
            var _sub = 0;
            if (!is_undefined(pkicons_get_art96_subimg_by_mon)) _sub = pkicons_get_art96_subimg_by_mon(_M,false);

            var _anim_scale = 1;
            var _anim_offx = 0;
            var _anim_offy = 0;
            if (is_struct(_P) && variable_struct_exists(_P,"summary_sprite_anim_start_ms") && _P.summary_sprite_anim_active){
                var _start = _P.summary_sprite_anim_start_ms;
                var _D_ms = 420;
                var _elapsed = max(0, current_time - _start);
                var _t = clamp(_elapsed / _D_ms, 0, 1);
                var _peak = 1.18;
                var _rise = sin(min(_t * 1.6, 1) * pi * 0.5);
                if (_t < 0.6) _anim_scale = lerp(1, _peak, _rise);
                else _anim_scale = lerp(_peak, 1, ( _t - 0.6 ) / 0.4 );
                var _shake_amp = 2 * _S * (1 - _t);
                var _time_s = current_time / 1000;
                _anim_offx = lengthdir_x(_shake_amp, (_time_s*360 + (_P.sel*37)) mod 360);
                _anim_offy = lengthdir_y(_shake_amp, (_time_s*360 + (_P.sel*51)) mod 360);
                if (_t >= 1){ _P.summary_sprite_anim_active = false; _P.summary_sprite_anim_start_ms = -1; }
            }

            draw_sprite_ext(_sprArt, _sub, _dx + _anim_offx, _dy + _anim_offy, _sc * _anim_scale, _sc * _anim_scale, 0, c_white, 1);
            if (is_struct(_M) && variable_struct_exists(_M,"shiny") && _M.shiny && !is_undefined(__party_impl_draw_shiny_sparkle)){
                var _sx = _dx + _artW * _sc * 0.78;
                var _sy = _dy + _artH * _sc * 0.22;
                __party_impl_draw_shiny_sparkle(_sx,_sy,_S, (_M.species_id) ?? 0);
            }
        }

        var _lvl = 1; if (variable_struct_exists(_M,"level")) _lvl = _M.level; else if (variable_struct_exists(_M,"lvl")) _lvl = _M.lvl;
        var _name_lh = max(12, string_height("A") + 2) * _S;
        draw_text(_lx1 + 6*_S, _ly1 + 6*_S + _name_lh, "Lv " + string(_lvl));
    }

    return { descPad: _DESC_PAD, descAreaH: _DESC_AREA_H, descX: (_lx1 + _DESC_PAD), descY: (_ly2 - _DESC_AREA_H + _DESC_PAD), descW: min((_LEFT_W + 10) * _S, (108 - _LEFT_X - 4) * _S) - _DESC_PAD*2, descH: _DESC_AREA_H - _DESC_PAD*2 };
}

function __party_impl_draw_right_frame(_OX, _OY, _S, _RIGHT_X, _RIGHT_Y, _RIGHT_W, _RIGHT_H){
    var _rx1 = _OX + _RIGHT_X*_S, _ry1 = _OY + _RIGHT_Y*_S;
    var _rx2 = _OX + (_RIGHT_X + _RIGHT_W)*_S, _ry2 = _OY + (_RIGHT_Y + _RIGHT_H)*_S;
    var _PARCHMENT = make_color_rgb(255,243,195);
    draw_set_color(_PARCHMENT); draw_rectangle(_rx1, _ry1, _rx2, _ry2, false);
    var _C_EDGE = make_color_rgb(64, 56, 112);
    draw_set_color(_C_EDGE);  draw_rectangle(_rx1- _S, _ry1- _S, _rx2+ _S, _ry2+ _S, true);
    return { rx1: _rx1, ry1: _ry1, rx2: _rx2, ry2: _ry2 };
}

function __party_impl_draw_header_and_circles(_P, _OX, _OY, _S, _n, _C_ACC, _C_PAPER){
    var _modeStr = string(_P.mode);
    draw_set_color(c_white);
    if (_modeStr == "summary_moves" || _modeStr == "summary_forget"){
        var _hintY = _OY + 10*_S;
        draw_text(_OX + 4*_S, _hintY, "L/R: Switch");
        var _profileHint = "Up: Profile";
        var _phW = string_width(_profileHint);
        draw_text(_OX + 240*_S - _phW - 4*_S, _hintY, _profileHint);
    } else if (_modeStr == "summary_profile") {
        var _movesHint = "Up: Moves";
        var _mhW = string_width(_movesHint);
        var _hintY2 = _OY + 10*_S;
        draw_text(_OX + 240*_S - _mhW - 4*_S, _hintY2, _movesHint);
    }
    var _radBase = 3;
    var _spinAng = _P.summary_spin_angle;
    var _isSummary = (string(_P.mode) == "summary_profile" || string(_P.mode) == "summary_moves" || string(_P.mode) == "summary_forget");
    for (var _i = 0; _i < 6; _i++){
        var _cx = _OX + (104 + _i*12)*_S - 20*_S;
        var _cy = _OY + 12*_S;
        var _col = (_i < _n) ? (_i == _P.sel ? _C_ACC : _C_PAPER) : make_color_rgb(136,136,136);
        draw_set_color(_col);
        var _r = _radBase * _S;
        if (_i == _P.sel && _isSummary){
            var _scale = _P.summary_cur_scale;
            draw_circle(_cx, _cy, _r * _scale, false);
            var _len = _r * 0.9 * _scale;
            var _x2 = _cx + lengthdir_x(_len, _spinAng);
            var _y2 = _cy + lengthdir_y(_len, _spinAng);
            draw_set_color(_C_ACC);
            draw_line(_cx, _cy, _x2, _y2);
            draw_set_color(_col);
        } else {
            draw_circle(_cx, _cy, _r, false);
        }
    }
}

function __party_impl_draw_right_content(_P, _M, _rightInfo, _RIGHT_W, _RIGHT_H, _S){
    var _rx1 = _rightInfo.rx1, _ry1 = _rightInfo.ry1, _rx2 = _rightInfo.rx2, _ry2 = _rightInfo.ry2;
    var _secondaryLine = "";
    if (string(_P.mode) == "summary_profile"){
        __party_impl_draw_profile_block(_M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S);
        if (is_struct(_M)){
            var _idno_ext = "";
            if (variable_struct_exists(_M,"idno")) _idno_ext = string(_M.idno);
            if (string_length(_idno_ext) > 0){
                var _id_label = "IDNo " + _idno_ext;
                var _bx_center = _rx1 + (_RIGHT_W*_S) * 0.5;
                var _id_w2 = string_width(_id_label);
                var _id_draw_x2 = floor(_bx_center - _id_w2 * 0.5);
                var _below_gap = 9*_S;
                draw_text(_id_draw_x2, _ry2 + _below_gap, _id_label);
            }
        }
    } else if (string(_P.mode) == "summary_moves"){
        _secondaryLine = __party_impl_draw_moves_block(_P, _M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S, false);
    } else if (string(_P.mode) == "summary_forget"){
        _secondaryLine = __party_impl_draw_moves_block(_P, _M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S, true);
    }
    return _secondaryLine;
}
