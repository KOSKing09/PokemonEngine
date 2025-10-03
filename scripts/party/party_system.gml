// [Party System]: party_system — Build v4.8.7 — 2025-10-03
// Fix: Party list rows fallback = spr_mon_icon_placeholder (small icon).
//      Summary artwork fallback = spr_mon_placeholder (large art).
//      Removed spr_bag_pokeball_small entirely.
//      Selector uses spr_selector directly in list & submenu.

globalvar PARTY;

// ---------- Tunables ----------
#macro PARTY_ICON_H_UI 20
#macro PARTY_ROW_PAD_UI 2
#macro PARTY_HILITE_COL make_color_rgb(255,255,255)
#macro PARTY_HILITE_EDGE make_color_rgb(136,100,36)
#macro PARTY_HILITE_ALPHA 0.20

// ---------- Basic queries / toggles ----------
function party_is_open(_pid){
    if (!variable_global_exists("PARTY")) return false;
    if (!is_array(global.PARTY)) return false;
    if (array_length(global.PARTY) <= _pid) return false;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return false;
    if (!variable_struct_exists(_P,"open")) return false;
    return _P.open;
}
function party_open(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    _P.open         = true;
    _P.mode         = "list";
    _P.menu_sel     = 0;
    _P.swap_index   = -1;
    _P.sum_move_sel = 0;
    _P.sum_learn_sel= 0;
    _P.lock         = 4;
}
function party_close(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    _P.open = false;
}
function party_toggle(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    _P.open = !_P.open;
    if (_P.open){
        _P.mode         = "list";
        _P.menu_sel     = 0;
        _P.swap_index   = -1;
        _P.sum_move_sel = 0;
        _P.sum_learn_sel= 0;
        _P.lock         = 4;
    }
}

// ---------- Initialization / ensure ----------
function party_init(){
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    var _players = 1;
    if (variable_global_exists("PAUSE_PLAYERS_ACTIVE")) _players = max(1, global.PAUSE_PLAYERS_ACTIVE);
    array_resize(global.PARTY, _players);
    for (var _pid = 0; _pid < _players; _pid++){
        if (!is_struct(global.PARTY[_pid])){
            global.PARTY[_pid] = {
                open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0,
                mons:[], sum_move_sel:0, sum_learn_sel:0
            };
        }
    }
}
function party_ensure(_pid){
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    if (!is_array(global.PARTY)) global.PARTY = [];
    if (array_length(global.PARTY) <= _pid) array_resize(global.PARTY, _pid + 1);
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)){
        _P = { open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0, mons:[], sum_move_sel:0, sum_learn_sel:0 };
        global.PARTY[_pid] = _P;
    }
    if (!variable_struct_exists(_P,"open"))          _P.open         = false;
    if (!variable_struct_exists(_P,"mode"))          _P.mode         = "list";
    if (!variable_struct_exists(_P,"sel"))           _P.sel          = 0;
    if (!variable_struct_exists(_P,"scroll"))        _P.scroll       = 0;
    if (!variable_struct_exists(_P,"menu_sel"))      _P.menu_sel     = 0;
    if (!variable_struct_exists(_P,"swap_index"))    _P.swap_index   = -1;
    if (!variable_struct_exists(_P,"lock"))          _P.lock         = 0;
    if (!variable_struct_exists(_P,"mons") || !is_array(_P.mons)) _P.mons = [];
    if (!variable_struct_exists(_P,"sum_move_sel"))  _P.sum_move_sel = 0;
    if (!variable_struct_exists(_P,"sum_learn_sel")) _P.sum_learn_sel= 0;

    var _n = array_length(_P.mons), _rows = 6;
    if (_n <= 0){ _P.sel = 0; _P.scroll = 0; }
    else {
        if (_P.sel >= _n) _P.sel = _n - 1;
        if (_P.sel < 0)   _P.sel = 0;
        var _max_scroll = max(0, _n - _rows);
        if (_P.scroll < 0) _P.scroll = 0;
        if (_P.scroll > _max_scroll) _P.scroll = _max_scroll;
        if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
        if (_P.sel >= _P.scroll + _rows) _P.scroll = max(0, _P.sel - _rows + 1);
    }
    return _P;
}

// ---------- Helpers ----------
function __party_mons(_pid){
    if (variable_global_exists("PARTY") && is_array(global.PARTY) && array_length(global.PARTY) > _pid){
        var _p = global.PARTY[_pid];
        if (is_struct(_p) && variable_struct_exists(_p,"mons") && is_array(_p.mons)) return _p.mons;
    }
    return [];
}
function __party_mon_get(_P, _pid){
    var _mons = __party_mons(_pid), _n = array_length(_mons);
    if (_n <= 0) return undefined;
    var _idx = _P.sel; if (_idx < 0 || _idx >= _n) return undefined;
    return _mons[_idx];
}
function __party_move_name(_id){
    if (!is_real(_id)) return "—";
    if (is_undefined(scr_move_name_by_id)) return "Move#" + string(_id);
    var _t = scr_move_name_by_id(_id);
    if (is_string(_t) && string_length(_t) > 0) return _t;
    return "Move#" + string(_id);
}

// ---------- Update ----------
function party_update(){
    if (!variable_global_exists("PARTY")) return;
    var _players = array_length(global.PARTY); if (_players <= 0) return;

    for (var _pid = 0; _pid < _players; _pid++){
        var _P = party_ensure(_pid);
        if (!_P.open) continue;
        if (_P.lock > 0) _P.lock--;

        var _mons = _P.mons, _n = array_length(_mons), _ROWS = 6;

        if (_P.mode != "select" && _P.mode != "summary_profile" && _P.mode != "summary_moves" && _P.mode != "summary_forget"){
            if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.open = false; _P.lock = 2; continue; }
        }

        switch (_P.mode){
            case "list": {
                if (controls_pressed(_pid,"MoveDown") && _n > 0) _P.sel = clamp(_P.sel + 1, 0, _n - 1);
                if (controls_pressed(_pid,"MoveUp")   && _n > 0) _P.sel = clamp(_P.sel - 1, 0, _n - 1);
                _P.scroll = clamp(_P.scroll, 0, max(0, _n - _ROWS));
                if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
                if (_P.sel >= _P.scroll + _ROWS) _P.scroll = max(0, _P.sel - _ROWS + 1);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){ _P.mode="menu"; _P.menu_sel=0; _P.lock=2; }
            } break;

            case "menu": {
                if (controls_pressed(_pid,"MoveDown")) _P.menu_sel = clamp(_P.menu_sel + 1, 0, 3);
                if (controls_pressed(_pid,"MoveUp"))   _P.menu_sel = clamp(_P.menu_sel - 1, 0, 3);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    switch (_P.menu_sel){
                        case 0: _P.mode="summary_profile"; _P.sum_move_sel=0; _P.sum_learn_sel=0; _P.lock=2; break;
                        case 1: _P.swap_index = _P.sel; _P.mode="select"; _P.lock=2; break;
                        case 2: _P.mode="list"; _P.lock=2; break;
                        case 3: _P.mode="list"; _P.lock=2; break;
                    }
                }
            } break;

            case "select": {
                if (controls_pressed(_pid,"MoveDown") && _n > 0) _P.sel = clamp(_P.sel + 1, 0, _n - 1);
                if (controls_pressed(_pid,"MoveUp")   && _n > 0) _P.sel = clamp(_P.sel - 1, 0, _n - 1);
                _P.scroll = clamp(_P.scroll, 0, max(0, _n - _ROWS));
                if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
                if (_P.sel >= _P.scroll + _ROWS) _P.scroll = max(0, _P.sel - _ROWS + 1);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    var _src = _P.swap_index, _dst = _P.sel;
                    if (_n > 0 && _src >= 0 && _src < _n && _dst >= 0 && _dst < _n && _src != _dst){
                        var _t = _mons[_src]; _mons[_src] = _mons[_dst]; _mons[_dst] = _t;
                        _P.mons = _mons; _P.sel = _dst;
                    }
                    _P.mode="list"; _P.swap_index=-1; _P.lock=2;
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode="list"; _P.swap_index=-1; _P.lock=2; }
            } break;

            case "summary_profile": {
                if (controls_pressed(_pid,"MoveRight") && _n > 0){ _P.sel = clamp(_P.sel + 1, 0, _n - 1); _P.lock = 2; }
                if (controls_pressed(_pid,"MoveLeft")  && _n > 0){ _P.sel = clamp(_P.sel - 1, 0, _n - 1); _P.lock = 2; }
                if (controls_pressed(_pid,"MoveDown")){ _P.mode = "summary_moves"; _P.lock = 2; }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "list"; _P.lock = 2; }
            } break;

            case "summary_moves": {
                var _M  = __party_mon_get(_P, _pid);
                var _mv = is_struct(_M) && variable_struct_exists(_M,"moves") ? _M.moves : [];
                var _lr = is_struct(_M) && variable_struct_exists(_M,"learnset") ? _M.learnset : [];
                var _nm = array_length(_mv), _nl = array_length(_lr);

                if (controls_pressed(_pid,"MoveUp")){ _P.mode = "summary_profile"; _P.lock = 2; }
                if (controls_pressed(_pid,"MoveRight") && _n > 0){ _P.sel = clamp(_P.sel + 1, 0, _n - 1); _P.lock = 2; }
                if (controls_pressed(_pid,"MoveLeft")  && _n > 0){ _P.sel = clamp(_P.sel - 1, 0, _n - 1); _P.lock = 2; }

                var _invHeld = controls_down(_pid,"Inventory");
                if (_invHeld){
                    if (_nl > 0){
                        if (controls_pressed(_pid,"MoveDown")) _P.sum_learn_sel = clamp(_P.sum_learn_sel + 1, 0, _nl - 1);
                        if (controls_pressed(_pid,"MoveUp"))   _P.sum_learn_sel = clamp(_P.sum_learn_sel - 1, 0, _nl - 1);
                    } else _P.sum_learn_sel = 0;
                } else {
                    if (_nm > 0){
                        if (controls_pressed(_pid,"MoveDown")) _P.sum_move_sel = clamp(_P.sum_move_sel + 1, 0, _nm - 1);
                        if (controls_pressed(_pid,"MoveUp"))   _P.sum_move_sel = clamp(_P.sum_move_sel - 1, 0, _nm - 1);
                    } else _P.sum_move_sel = 0;
                }

                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    if (_nl > 0){
                        var _learnId = _lr[_P.sum_learn_sel];
                        if (_nm < 4){ array_push(_mv, _learnId); _M.moves = _mv; _P.sum_move_sel = array_length(_mv) - 1; _P.lock = 4; }
                        else { _P.mode = "summary_forget"; _P.lock = 2; }
                    }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "list"; _P.lock = 2; }
            } break;

            case "summary_forget": {
                var _M2  = __party_mon_get(_P, _pid);
                var _mv2 = is_struct(_M2) && variable_struct_exists(_M2,"moves") ? _M2.moves : [];
                var _nm2 = array_length(_mv2);
                if (_nm2 <= 0){ _P.mode = "summary_moves"; break; }
                if (controls_pressed(_pid,"MoveDown")) _P.sum_move_sel = clamp(_P.sum_move_sel + 1, 0, _nm2 - 1);
                if (controls_pressed(_pid,"MoveUp"))   _P.sum_move_sel = clamp(_P.sum_move_sel - 1, 0, _nm2 - 1);
                var _lr2 = is_struct(_M2) && variable_struct_exists(_M2,"learnset") ? _M2.learnset : [];
                var _nl2 = array_length(_lr2);
                var _chosen = (_nl2 > 0) ? _lr2[_P.sum_learn_sel] : -1;
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    if (_chosen != -1){ _mv2[_P.sum_move_sel] = _chosen; _M2.moves = _mv2; _P.mode = "summary_moves"; _P.lock = 4; }
                    else { _P.mode = "summary_moves"; _P.lock = 2; }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "summary_moves"; _P.lock = 2; }
            } break;
        }
    }
}

// ---------- Draw ----------
function party_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!party_is_open(_pid)) return;
    var _P = party_ensure(_pid);

    var _S  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _OX = _rx + (_rw - 240 * _S) div 2;
    var _OY = _ry + (_rh - 160 * _S) div 2;

    if (string(_P.mode) == "summary_profile" || string(_P.mode) == "summary_moves" || string(_P.mode) == "summary_forget"){
        __party_draw_summary(_pid, _P, _OX, _OY, _S);
        return;
    }

    var _C_BG_A    = make_color_rgb(252,236,180);
    var _C_BG_B    = make_color_rgb(248,220,140);
    var _C_PAPER   = make_color_rgb(255,243,195);
    var _C_PAPER_E = make_color_rgb(136,100,36);

    var _stripe_h = 8;
    for (var _yy = 0; _yy < 160; _yy += _stripe_h){
        draw_set_color( ((_yy div _stripe_h) & 1) == 1 ? _C_BG_B : _C_BG_A );
        draw_rectangle(_OX, _OY + _yy*_S, _OX + 240*_S, _OY + (_yy+_stripe_h)*_S, false);
    }

    var _LIST_X = 120, _LIST_Y = 8,  _LIST_W = 112, _LIST_H = 144;
    var _INFO_X = 8,   _INFO_Y = 98, _INFO_W = 104, _INFO_H = 54;

    var _lx1 = _OX + _LIST_X*_S,            _ly1 = _OY + _LIST_Y*_S;
    var _lx2 = _OX + (_LIST_X+_LIST_W)*_S,  _ly2 = _OY + (_LIST_Y+_LIST_H)*_S;
    draw_set_color(_C_PAPER);   draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(_lx1 - _S, _ly1 - _S, _lx2 + _S, _ly2 + _S, true);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    var _mons  = _P.mons;
    var _n     = array_length(_mons);
    var _ROWS  = 6;
    var _ROW_H = max(12, string_height("A") + 2);

    // Direct sprite references
    var sprSelector     = spr_selector;
    var sprPlaceholder  = spr_mon_icon_placeholder; // correct small icon placeholder

    for (var _r = 0; _r < _ROWS; _r++){
        var _idx = _P.scroll + _r; if (_idx >= _n) break;
        var _M = _mons[_idx];
        var _row_y_gui = _OY + (_LIST_Y + 8 + _r*(_ROW_H + PARTY_ROW_PAD_UI)) * _S;

        if (_idx == _P.sel){
            var _rx1 = _OX + (_LIST_X + 2) * _S;
            var _ry1 = _row_y_gui - (_ROW_H * 0.65) * _S;
            var _rx2 = _OX + (_LIST_X + _LIST_W - 2) * _S;
            var _ry2 = _ry1 + (_ROW_H * 1.25) * _S;
            draw_set_alpha(PARTY_HILITE_ALPHA);
            draw_set_color(PARTY_HILITE_COL);
            draw_rectangle(_rx1, _ry1, _rx2, _ry2, false);
            draw_set_alpha(1);
            draw_set_color(PARTY_HILITE_EDGE);
            draw_rectangle(_rx1, _ry1, _rx2, _ry2, true);
            draw_set_color(c_white);
        }

        // Selector at current row (list) using spr_selector directly
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
            var _iy_gui = _row_y_gui - _target_h_gui * 0.5;

            draw_sprite_ext(_sprDown, _frame, floor(_ix_gui), floor(_iy_gui), _sc_icon, _sc_icon, 0, c_white, 1);
            _drawnIconW_ui = ceil((_iw_gui) / _S);
        } else {
            _drawnIconW_ui = 18;
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
    draw_set_color(_C_PAPER);   draw_rectangle(_ix1, _iy1, _ix2, _iy2, false);
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

    if (string(_P.mode) == "menu"){
        var _MX = 96, _MY = 20, _MW = 76, _MH = 84;
        var _bx1 = _OX + _MX*_S;
        var _by1 = _OY + _MY*_S;
        var _bx2 = _OX + (_MX+_MW)*_S;
        var _by2 = _OY + (_MY+_MH)*_S;

        draw_set_color(_C_PAPER);   draw_rectangle(_bx1, _by1, _bx2, _by2, false);
        draw_set_color(_C_PAPER_E); draw_rectangle(_bx1 - _S, _by1 - _S, _bx2 + _S, _by2 + _S, true);

        if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
        draw_set_color(c_white);

        var _items = ["Summary","Switch","Item","Cancel"];
        var _m_h   = max(12, string_height("A") + 2);
        // Use spr_selector directly in menu
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
    }
}

// ---------- Summary / Description ----------
function __party_draw_summary(_pid, _P, _OX, _OY, _S){
    var _C_BG    = make_color_rgb(224, 216, 248);
    var _C_PAPER = make_color_rgb(255, 255, 255);
    var _C_EDGE  = make_color_rgb(64, 56, 112);
    var _C_ACC   = make_color_rgb(208, 48, 48);
    var _C_TEXT  = c_white;

    draw_set_color(_C_BG);   draw_rectangle(_OX, _OY, _OX + 240*_S, _OY + 160*_S, false);
    draw_set_color(_C_EDGE); draw_rectangle(_OX, _OY, _OX + 240*_S, _OY + 20*_S, true);

    var _mons = __party_mons(_pid), _n = array_length(_mons);
    for (var _i = 0; _i < 6; _i++){
        var _cx = _OX + (104 + _i*16)*_S, _cy = _OY + 10*_S;
        draw_set_color( (_i < _n) ? (_i == _P.sel ? _C_ACC : _C_PAPER) : make_color_rgb(136,136,136) );
        draw_circle(_cx, _cy, 4*_S, false);
    }

    var _LEFT_X = 8, _LEFT_Y = 24, _LEFT_W = 96, _LEFT_H = 120;
    var _RIGHT_X = 108, _RIGHT_Y = 24, _RIGHT_W = 124, _RIGHT_H = 120;
    var _lx1 = _OX + _LEFT_X*_S,  _ly1 = _OY + _LEFT_Y*_S;
    var _lx2 = _OX + (_LEFT_X + _LEFT_W)*_S, _ly2 = _OY + (_LEFT_Y + _LEFT_H)*_S;
    var _rx1 = _OX + _RIGHT_X*_S, _ry1 = _OY + _RIGHT_Y*_S;
    var _rx2 = _OX + (_RIGHT_X + _RIGHT_W)*_S, _ry2 = _OY + (_RIGHT_Y + _RIGHT_H)*_S;

    draw_set_color(_C_PAPER); draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
    draw_set_color(_C_EDGE);  draw_rectangle(_lx1- _S, _ly1- _S, _lx2+ _S, _ly2+ _S, true);
    draw_set_color(_C_PAPER); draw_rectangle(_rx1, _ry1, _rx2, _ry2, false);
    draw_set_color(_C_EDGE);  draw_rectangle(_rx1- _S, _ry1- _S, _rx2+ _S, _ry2+ _S, true);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(_C_TEXT);

    var _M = __party_mon_get(_P, _pid);
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
        if (_sprArt == -1){
            _sprArt = spr_mon_placeholder; // summary art fallback (large)
        }
        if (_sprArt != -1){
            var _artW = sprite_get_width(_sprArt), _artH = sprite_get_height(_sprArt);
            var _boxW = (_LEFT_W - 12) * _S,       _boxH = (_LEFT_H - 36) * _S;
            var _sc   = min(_boxW / _artW, _boxH / _artH);
            var _dx   = _lx1 + (_LEFT_W*_S - _artW*_sc) * 0.5;
            var _dy   = _ly1 + 18*_S + (_boxH - _artH*_sc) * 0.5;
            draw_sprite_ext(_sprArt, 0, _dx, _dy, _sc, _sc, 0, c_white, 1);
        }

        var _lvl = 1; if (variable_struct_exists(_M,"level")) _lvl = _M.level; else if (variable_struct_exists(_M,"lvl")) _lvl = _M.lvl;
        draw_text(_lx1 + 6*_S, _ly2 - 16*_S, "Lv " + string(_lvl));
        // Pokéball icon intentionally removed.
    }

    if (string(_P.mode) == "summary_profile"){
        __party_draw_profile_block(_M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S);
    } else if (string(_P.mode) == "summary_moves"){
        __party_draw_moves_block(_P, _M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S, false);
    } else if (string(_P.mode) == "summary_forget"){
        __party_draw_moves_block(_P, _M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S, true);
    }
}

// ---------- Summary helpers ----------
function __party_draw_profile_block(_M, _x, _y, _w, _h, _S){
    var _C_LABEL = make_color_rgb(40, 96, 96);
    var _lh = max(12, string_height("A") + 2) * _S;
    draw_set_color(c_white); draw_text(_x + 6*_S, _y + 6*_S, "PROFILE");
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
        if (variable_struct_exists(_M,"type")){
            if (is_array(_M.type)){
                var _tA = string(_M.type[0]); var _tB = (array_length(_M.type) > 1) ? string(_M.type[1]) : "";
                _typ = (string_length(_tB) > 0) ? (_tA + " / " + _tB) : _tA;
            } else _typ = string(_M.type);
        }
        if (variable_struct_exists(_M,"ability"))  _abi  = string(_M.ability);
        if (variable_struct_exists(_M,"nature"))   _nat  = string(_M.nature);
        if (variable_struct_exists(_M,"met_level")) _metLv = string(_M.met_level);
        if (variable_struct_exists(_M,"met_map"))   _metMp = string(_M.met_map);
    }
    draw_text(_x + 60*_S, _y + 6*_S + _lh*1, _ot + "   IDNo" + _idno);
    draw_text(_x + 60*_S, _y + 6*_S + _lh*2, _typ);
    draw_text(_x + 60*_S, _y + 6*_S + _lh*3, _abi);
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*6, string_upper(_nat) + " nature,");
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*7, "met at Lv." + _metLv + ",");
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*8, _metMp + ".");
}
function __party_draw_moves_block(_P, _M, _x, _y, _w, _h, _S, _highlightForget){
    var _lh = max(12, string_height("A") + 2) * _S;
    draw_set_color(c_white);
    draw_text(_x + 6*_S, _y + 6*_S, "MOVES");
    draw_text(_x + _w*_S - 60*_S, _y + 6*_S, "LEARNSET");

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
    if (_highlightForget) draw_text(_x + 6*_S, _y + (_h*_S) - 14*_S, "Choose a move to forget.  B: Back");
    else draw_text(_x + 6*_S, _y + (_h*_S) - 14*_S, "A: Learn  |  Hold Inventory + Up/Down: Choose Learnset  |  L/R: Switch  |  Up: Profile  |  B: Back");
}

// ---------- Entrypoint ----------
function party_draw_gui(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    party_draw_gui_rect(_pid, 0, 0, _gw, _gh);
}
