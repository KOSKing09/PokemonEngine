// Modularized draw implementations for the Party System
// This file contains the concrete implementations for the party UI draw helpers.
// The original wrappers live in `party_system.gml` and will forward to these
// functions when present. Keeping implementations here allows the draw code to
// be split out while preserving backwards compatibility.

// Full-screen party draw (moved from party_system.gml)
function __party_impl_party_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!party_is_open(_pid)) return;
    var _P = party_ensure(_pid);

    var _S  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _OX = _rx + (_rw - 240 * _S) div 2;
    var _OY = _ry + (_rh - 160 * _S) div 2;

    if (string(_P.mode) == "summary_profile" || string(_P.mode) == "summary_moves" || string(_P.mode) == "summary_forget"){
        // Debug: report entering summary draw with current learn_pending state
        var _mode_dbg = "unknown";
        if (is_struct(_P) && variable_struct_exists(_P, "mode")) _mode_dbg = string(variable_struct_get(_P, "mode"));
        if (is_struct(_P) && variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
            var _lp_dbg = variable_struct_get(_P, "learn_pending");
            var _lp_step_dbg = (variable_struct_exists(_lp_dbg, "step") ? variable_struct_get(_lp_dbg, "step") : "desc");
            // debug message removed
        } else {
            // debug message removed
        }
        __party_draw_summary(_pid, _P, _OX, _OY, _S);
        return;
    }

    var _C_BG_A    = make_color_rgb(252,236,180);
    var _C_BG_B    = make_color_rgb(248,220,140);
    var _C_PAPER   = make_color_rgb(255,243,195);
    var _C_PAPER_E = make_color_rgb(136,100,36);

    var _stripe_h = 8;
    // Ensure full alpha before drawing background stripes
    for (var _yy = 0; _yy < 160; _yy += _stripe_h){
        draw_set_color( ((_yy div _stripe_h) & 1) == 1 ? _C_BG_B : _C_BG_A );
        draw_rectangle(_OX, _OY + _yy*_S, _OX + 240*_S, _OY + (_yy+_stripe_h)*_S, false);
    }

    var _LIST_X = 120, _LIST_Y = 8,  _LIST_W = 112, _LIST_H = 144;
    var _INFO_X = 8,   _INFO_Y = 98, _INFO_W = 104, _INFO_H = 54;

    var _lx1 = _OX + _LIST_X*_S,            _ly1 = _OY + _LIST_Y*_S;
    var _lx2 = _OX + (_LIST_X+_LIST_W)*_S,  _ly2 = _OY + (_LIST_Y+_LIST_H)*_S;
    var _PARCHMENT = make_color_rgb(255,243,195);
    draw_set_color(_PARCHMENT);   draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(_lx1 - _S, _ly1 - _S, _lx2 + _S, _ly2 + _S, true);

    var _partyFontOld = __party_use_font();
    draw_set_color(c_white);

    var _mons  = _P.mons;
    var _n     = array_length(_mons);
    var _ROWS  = 6;
    var _ROW_H = max(12, string_height("A") + 2);

    var sprSelector     = spr_selector;
    var sprPlaceholder  = spr_mon_icon_placeholder;

    for (var _r = 0; _r < _ROWS; _r++){
        var _idx = _P.scroll + _r; if (_idx >= _n) break;
        var _M = _mons[_idx];
        var _row_y_gui = _OY + (_LIST_Y + 8 + _r*(_ROW_H + PARTY_ROW_PAD_UI)) * _S;

        if (_idx == _P.sel){
            var _rx1 = _OX + (_LIST_X + 2) * _S;
            var _ry1 = _row_y_gui - (_ROW_H * 0.65) * _S;
            var _rx2 = _OX + (_LIST_X + _LIST_W - 2) * _S;
            var _ry2 = _ry1 + (_ROW_H * 1.25) * _S;
            draw_set_color(PARTY_HILITE_COL);
            draw_rectangle(_rx1, _ry1, _rx2, _ry2, false);
            draw_set_color(PARTY_HILITE_EDGE);
            draw_rectangle(_rx1, _ry1, _rx2, _ry2, true);
            draw_set_color(c_white);
        }

        if (_idx == _P.sel){
            var _sh2 = max(1, sprite_get_height(sprSelector));
            var _tgt2 = _ROW_H * _S;
            var _sc2  = _tgt2 / _sh2;
            draw_sprite_ext(sprSelector, 0, _OX + (_LIST_X + 2)*_S - 10*_S, _row_y_gui - _tgt2*0.15, _sc2, _sc2, 0, c_white, 1);
        }

        var _sprDown = -1;
        if (!is_undefined(pkicons_get_icon32_dir_by_mon)) _sprDown = pkicons_get_icon32_dir_by_mon(_M, "down");
        var _hasIcon = (_sprDown != -1);
        if (!_hasIcon){ _sprDown = sprPlaceholder; _hasIcon = true; }

        var _drawnIconW_ui = 0;
        if (_hasIcon){
            var _frame = 0;
            if (!is_undefined(pkicons_icon32_frame_ui)) _frame = pkicons_icon32_frame_ui();
            var _ih = max(1, sprite_get_height(_sprDown));
            var _target_h_gui = PARTY_ICON_H_UI * _S;
            var _sc_icon = _target_h_gui / _ih;
            var _ix_gui = _OX + (_LIST_X + 2) * _S;
            var _iw_gui = sprite_get_width(_sprDown) * _sc_icon;
            var _iy_gui = _row_y_gui - _target_h_gui * 0.5 - 4*_S; // raised by 4 UI pixels
            draw_sprite_ext(_sprDown, _frame, floor(_ix_gui), floor(_iy_gui), _sc_icon, _sc_icon, 0, c_white, 1);
            // Sparkle overlay (new helper) – visually animated & stable
            if (is_struct(_M) && variable_struct_exists(_M,"shiny") && _M.shiny){
                var _cx = floor(_ix_gui + _iw_gui * 0.65);
                var _cy = floor(_iy_gui + _target_h_gui * 0.30);
                __party_draw_shiny_sparkle(_cx,_cy,_S,_idx);
            }
            _drawnIconW_ui = ceil((_iw_gui) / _S);
        } else {
            _drawnIconW_ui = 18;
        }

        // Draw small held-item icon at bottom-left of the party portrait if the mon has one
        if (is_struct(_M)){
            var _held_spr = -1;
            // prefer the canonical real name if present
            if (variable_struct_exists(_M, "held_item_real_name") && string_length(string(_M.held_item_real_name)) > 0){
                if (!is_undefined(pkicons_get_item_icon_by_name)) _held_spr = pkicons_get_item_icon_by_name(string(_M.held_item_real_name));
            }
            // fallback to held_item_id
            if ((_held_spr == -1 || is_undefined(_held_spr)) && variable_struct_exists(_M, "held_item_id") && is_real(_M.held_item_id) && _M.held_item_id > 0){
                if (!is_undefined(pkicons_get_item_icon_by_id)) _held_spr = pkicons_get_item_icon_by_id(_M.held_item_id);
            }
            // if we have a usable sprite, draw a small 5x5 px icon at bottom-left of the icon area
            if ((!is_undefined(_held_spr) && _held_spr != -1) && sprite_exists(_held_spr)){
                var _small_w = 5; var _small_h = 5;
                var _sx = _OX + (_LIST_X + 2) * _S; // left edge of icon area
                var _sy = _row_y_gui - (_ROW_H * 0.5) * _S + (_ROW_H * 0.5) * _S; // bottom of row icon area
                // place slightly inset from bottom-left of the icon region
                var _px = floor(_sx + 2 * _S);
                var _py = floor(_row_y_gui + (_target_h_gui * 0.5) - (_small_h * _S) - 1 * _S - 5 * _S + 3 * _S);
                // compute scale to map sprite intrinsic size to 5x5 UI pixels
                var _spr_w = max(1, sprite_get_width(_held_spr));
                var _spr_h = max(1, sprite_get_height(_held_spr));
                var _scale_x = (_small_w) / _spr_w;
                var _scale_y = (_small_h) / _spr_h;
                var _scale = min(_scale_x, _scale_y);
                draw_sprite_ext(_held_spr, 0, _px, _py, _scale, _scale, 0, c_white, 1);
            }
        }

        var _disp_name = "???";
        if (is_struct(_M)){
            if (variable_struct_exists(_M,"species_id")){
                var _sid = _M.species_id;
                if (is_real(_sid) && _sid >= 0){
                    var _idn = scr_poke_name_by_id(_sid);
                    if (string_length(_idn) > 0){
                        _disp_name = string_replace_all(_idn, "-", " ");
                        if (string_length(_disp_name) > 0){
                            _disp_name = string_upper(string_copy(_disp_name,1,1)) + string_delete(_disp_name,1,1);
                        }
                    }
                }
            } else if (variable_struct_exists(_M,"species")) _disp_name = string(_M.species);
            else if (variable_struct_exists(_M,"name"))     _disp_name = string(_M.name);
        }
        var _name_x_ui = 120 + 2 + _drawnIconW_ui + 6;
        var _name_x_gui = _OX + _name_x_ui * _S;
        draw_text(_name_x_gui, _row_y_gui, _disp_name);
    }

    var _ix1 = _OX + _INFO_X*_S, _iy1 = _OY + _INFO_Y*_S;
    var _ix2 = _OX + (_INFO_X+_INFO_W)*_S, _iy2 = _OY + (_INFO_Y+_INFO_H)*_S;
    var _PARCHMENT = make_color_rgb(255,243,195);
    draw_set_color(_PARCHMENT);   draw_rectangle(_ix1, _iy1, _ix2, _iy2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(_ix1 - _S, _iy1 - _S, _ix2 + _S, _iy2 + _S, true);

    if (_n > 0){
        var _Li = clamp(_P.sel, 0, _n - 1);
        var _L = _mons[_Li];

        var _nm_disp = "???";
        if (is_struct(_L)){
            if (variable_struct_exists(_L,"species_id")){
                var _sid2 = _L.species_id;
                if (is_real(_sid2) && _sid2 >= 0){
                    var _idn2 = scr_poke_name_by_id(_sid2);
                    if (string_length(_idn2) > 0){
                        _nm_disp = string_replace_all(_idn2, "-", " ");
                        if (string_length(_nm_disp) > 0){
                            _nm_disp = string_upper(string_copy(_nm_disp,1,1)) + string_delete(_nm_disp,1,1);
                        }
                    }
                }
            } else if (variable_struct_exists(_L,"species")) _nm_disp = string(_L.species);
            else if (variable_struct_exists(_L,"name"))     _nm_disp = string(_L.name);
        }
        draw_set_color(c_white);
        draw_text(_ix1 + 6*_S, _iy1 + 6*_S, _nm_disp);

        var _nature_txt = "—";
        if (is_struct(_L)){
            if (variable_struct_exists(_L,"nature"))      _nature_txt = string(_L.nature);
            else if (variable_struct_exists(_L,"Nature")) _nature_txt = string(_L.Nature);
            else if (variable_struct_exists(_L,"nat"))    _nature_txt = string(_L.nat);
        }
        draw_text(_ix1 + 6*_S, _iy1 + 20*_S, "Nature: " + _nature_txt);

        var _hp_cur = 0; if (is_struct(_L)){ if (variable_struct_exists(_L,"hp")) _hp_cur = _L.hp; else if (variable_struct_exists(_L,"HP")) _hp_cur = _L.HP; }
        var _hp_max = 1; if (is_struct(_L)){ if (variable_struct_exists(_L,"maxhp")) _hp_max = _L.maxhp; else if (variable_struct_exists(_L,"hp_max")) _hp_max = _L.hp_max; }
        if (!is_real(_hp_max) || _hp_max <= 0) _hp_max = max(1, _hp_cur);

        var _lvl_val = 1; if (is_struct(_L)){ if (variable_struct_exists(_L,"level")) _lvl_val = _L.level; else if (variable_struct_exists(_L,"lvl")) _lvl_val = _L.lvl; }

        var _bar_x = _ix1 + 6*_S, _bar_y = _iy1 + 34*_S, _bar_w = (_INFO_W - 12) * _S, _bar_h = 6 * _S;
        draw_set_color(_C_PAPER_E); draw_rectangle(_bar_x - _S, _bar_y - _S, _bar_x + _bar_w + _S, _bar_y + _bar_h + _S, true);

        var _ratio = (_hp_max > 0) ? clamp(_hp_cur / _hp_max, 0, 1) : 0;
        var _hp_col = (_ratio >= 0.5) ? make_color_rgb(56,200,72) : (_ratio >= 0.2 ? make_color_rgb(248,200,40) : make_color_rgb(232,64,48));
        var _fill_w = floor(_bar_w * _ratio);
        draw_set_color(_hp_col); draw_rectangle(_bar_x, _bar_y, _bar_x + _fill_w, _bar_y + _bar_h, false);

        var _hp_txt = string(_hp_cur) + " / " + string(_hp_max);
        var _hp_tx  = _bar_x + _bar_w - string_width(_hp_txt);
        var _hp_ty  = _bar_y + _bar_h + (2*_S) + 6;

        draw_set_color(c_white);
        draw_text(_bar_x, _hp_ty, "Lv " + string(_lvl_val));
        draw_text(_hp_tx, _hp_ty, _hp_txt);
    }

    if (string(_P.mode) == "menu" || string(_P.mode) == "item_action"){
        var _MX = 96, _MY = 20, _MW = 76, _MH = 84;
        var _bx1 = _OX + _MX*_S;
        var _by1 = _OY + _MY*_S;
        var _bx2 = _OX + (_MX+_MW)*_S;
        var _by2 = _OY + (_MY+_MH)*_S;

        var _PARCHMENT = make_color_rgb(255,243,195);
        draw_set_color(_PARCHMENT);   draw_rectangle(_bx1, _by1, _bx2, _by2, false);
        draw_set_color(_C_PAPER_E); draw_rectangle(_bx1 - _S, _by1 - _S, _bx2 + _S, _by2 + _S, true);

        draw_set_color(c_white);

        // When party was opened from a battle for swapping, change "Switch" -> "Swap In"
        var _swap_label = "Switch";
        try {
            var _tmpP = party_ensure(_pid);
            if (is_struct(_tmpP) && variable_struct_exists(_tmpP, "_battle_swap_mode") && variable_struct_get(_tmpP, "_battle_swap_mode") && !is_undefined(battle_is_open) && battle_is_open(_pid)) _swap_label = "Swap In";
        } catch (e_lbl) { /* ignore */ }
        var _items = ["Summary", _swap_label, "Item", "Cancel"];
        var _m_h   = max(12, string_height("A") + 2);
        for (var _i = 0; _i < 4; _i++){
            var _yy_menu = _by1 + (6 + _i*_m_h);
            if (_i == _P.menu_sel){
                var _selh = max(1, sprite_get_height(spr_selector));
                var _tgt  = _m_h;
                var _sc   = _tgt / _selh;
                draw_sprite_ext(spr_selector, 0, _bx1 + 4*_S, _yy_menu - _tgt*0.15, _sc, _sc, 0, c_white, 1);
            }
            draw_text(_bx1 + 16*_S, _yy_menu, _items[_i]);
        }
        // If in item_action mode, draw a small submenu replacing the 'Item' entry
        if (string(_P.mode) == "item_action"){
            var _ix = _bx1 + 36*_S;
            var _iy = _by1 + (6 + 2*_m_h);
            var _labels = ["Take","Cancel"];
            var _menuSel = 0;
            if (variable_struct_exists(_P, "item_menu_sel")) _menuSel = variable_struct_get(_P, "item_menu_sel");
            var _shouldShowGive = false;
            if (variable_struct_exists(_P, "give_pending")){
                _shouldShowGive = true;
            } else {
                var _selMon = undefined;
                if (variable_struct_exists(_P, "mons") && is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _selMon = _P.mons[_P.sel];
                if (!is_undefined(_selMon) && is_struct(_selMon) && variable_struct_exists(_selMon, "held_item_id")){
                    var _hid_tmp = variable_struct_get(_selMon, "held_item_id");
                    if (is_real(_hid_tmp) && _hid_tmp > 0){ _shouldShowGive = false; } else { _shouldShowGive = true; }
                } else {
                    _shouldShowGive = true;
                }
            }
            // extend labels if necessary
            if (_shouldShowGive) {
                _labels[0] = "Give";
            }
            // Draw a small parchment box with border for the submenu so it's clearly visible
            var _sub_count = array_length(_labels);
            var _sub_w = 56 * _S; // width in GUI px
            var _sub_h = max(12, _sub_count * _m_h) + 4 * _S;
            var _sub_x1 = _ix - 6 * _S;
            var _sub_y1 = _iy - 2 * _S;
            var _sub_x2 = _sub_x1 + _sub_w;
            var _sub_y2 = _sub_y1 + _sub_h;
            draw_set_color(_PARCHMENT);
            draw_rectangle(_sub_x1, _sub_y1, _sub_x2, _sub_y2, false);
            draw_set_color(_C_PAPER_E);
            draw_rectangle(_sub_x1 - _S, _sub_y1 - _S, _sub_x2 + _S, _sub_y2 + _S, true);
            // Draw labels inside box
            for (var _ii = 0; _ii < _sub_count; _ii++){
                var _y2 = _iy + (_ii * _m_h);
                if (_ii == _menuSel){ draw_set_color(c_white); draw_text(_ix + 4*_S, _y2, "> " + _labels[_ii]); }
                else { draw_set_color(c_white); draw_text(_ix + 4*_S, _y2, _labels[_ii]); }
            }
        }
    }
}

// Keep only the main full-screen draw implementation and learn helpers here.
// Small helper implementations (font, text, sparkles, desc renderer, scrollbar)
// are provided by `scripts/party_draw_helpers/party_draw_helpers.gml` and
// UI layout helpers (left/right panels, header and circles) live in
// `scripts/party_ui_helpers/party_ui_helpers.gml`.
