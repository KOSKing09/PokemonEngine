// ============================================================================
// Pokémon Party UI (Emerald-style) — v4.1 (6-row list, white text, filled HP)
// - Draws a 240x160 UI into any GUI rect.
// - Modes: "list", "menu", "select"
// - No ternary operators; only if/else.
// - Uses: controls_pressed(pid,"..."), global.FNT_POKEMON (optional),
//         spr_selector (cursor), spr_mon_icon_placeholder (32x32, 2 frames).
// - This file is just the Party System (no demo seeding).
// ============================================================================

globalvar PARTY; // PARTY[pid] = struct { open, mode, sel, scroll, menu_sel, swap_index, lock, mons[] }

// --------- BASIC QUERIES / TOGGLES ------------------------------------------

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
    _P.open = true;
    _P.mode = "list"; // ensure submenu is closed when opening
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
    if (_P.open) _P.mode = "list";
}

// --------- INITIALIZATION / ENSURE ------------------------------------------

function party_init(){
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    var _players = 1;
    if (variable_global_exists("PAUSE_PLAYERS_ACTIVE")) {
        _players = max(1, global.PAUSE_PLAYERS_ACTIVE);
    }
    array_resize(global.PARTY, _players);

    for (var _pid = 0; _pid < _players; _pid++){
        if (!is_struct(global.PARTY[_pid])){
            global.PARTY[_pid] = {
                open:false,
                mode:"list",
                sel:0,
                scroll:0,
                menu_sel:0,
                swap_index:-1,
                lock:0,
                mons:[]
            };
        }
    }
}

/// party_ensure(_pid) -> struct P
function party_ensure(_pid){
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    if (!is_array(global.PARTY)) global.PARTY = [];
    if (array_length(global.PARTY) <= _pid) array_resize(global.PARTY, _pid + 1);

    var _P = global.PARTY[_pid];
    if (!is_struct(_P)){
        _P = {
            open:false,
            mode:"list",
            sel:0,
            scroll:0,
            menu_sel:0,
            swap_index:-1,
            lock:0,
            mons:[]
        };
        global.PARTY[_pid] = _P;
    }

    if (!variable_struct_exists(_P,"open"))        _P.open       = false;
    if (!variable_struct_exists(_P,"mode"))        _P.mode       = "list";
    if (!variable_struct_exists(_P,"sel"))         _P.sel        = 0;
    if (!variable_struct_exists(_P,"scroll"))      _P.scroll     = 0;
    if (!variable_struct_exists(_P,"menu_sel"))    _P.menu_sel   = 0;
    if (!variable_struct_exists(_P,"swap_index"))  _P.swap_index = -1;
    if (!variable_struct_exists(_P,"lock"))        _P.lock       = 0;
    if (!variable_struct_exists(_P,"mons") || !is_array(_P.mons)) _P.mons = [];

    // Clamp for 6 rows
    var _n = array_length(_P.mons);
    var _rows = 6;

    if (_n <= 0){
        _P.sel = 0;
        _P.scroll = 0;
    } else {
        if (_P.sel >= _n) _P.sel = _n - 1;
        if (_P.sel < 0)   _P.sel = 0;

        var _max_scroll = max(0, _n - _rows);
        if (_P.scroll < 0) _P.scroll = 0;
        if (_P.scroll > _max_scroll) _P.scroll = _max_scroll;

        if (_P.sel < _P.scroll) _P.scroll = _P.sel;
        if (_P.sel >= _P.scroll + _rows) _P.scroll = max(0, _P.sel - _rows + 1);
    }

    return _P;
}

// --------- UPDATE (INPUT + STATE) -------------------------------------------
/// party_update()  // v4.2
function party_update(){
    if (!variable_global_exists("PARTY")) return;
    var _players = array_length(global.PARTY); if (_players <= 0) return;

    for (var _pid = 0; _pid < _players; _pid++){
        var P = party_ensure(_pid);
        if (!P.open) continue;

        // drain input lock
        if (P.lock > 0) P.lock--;

        var mons = P.mons;
        var n    = array_length(mons);
        var ROWS = 6;

        // ---- Close with Run in LIST or MENU (not in SELECT) ----
        if (P.mode != "select"){
            if (controls_pressed(_pid,"Run") && P.lock == 0){
                P.open = false;
                P.lock = 2;
                continue;
            }
        }

        // ---- Mode logic (NAV ONLY where it belongs) ----
        switch (P.mode){

            case "list":
            {
                // list navigation ONLY in list mode
                if (controls_pressed(_pid,"MoveDown") && n > 0) P.sel = clamp(P.sel + 1, 0, n - 1);
                if (controls_pressed(_pid,"MoveUp")   && n > 0) P.sel = clamp(P.sel - 1, 0, n - 1);

                // keep selection visible
                P.scroll = clamp(P.scroll, 0, max(0, n - ROWS));
                if (P.sel <  P.scroll)         P.scroll = P.sel;
                if (P.sel >= P.scroll + ROWS)  P.scroll = max(0, P.sel - ROWS + 1);

                // open submenu
                if (controls_pressed(_pid,"Interact") && P.lock == 0){
                    P.mode     = "menu";
                    P.menu_sel = 0;
                    P.lock     = 2;
                }
            } break;

            case "menu":
            {
                // IMPORTANT: no list navigation here (so list doesn't move under menu)
                // only move inside submenu
                if (controls_pressed(_pid,"MoveDown")) P.menu_sel = clamp(P.menu_sel + 1, 0, 3);
                if (controls_pressed(_pid,"MoveUp"))   P.menu_sel = clamp(P.menu_sel - 1, 0, 3);

                if (controls_pressed(_pid,"Interact") && P.lock == 0){
                    switch (P.menu_sel){
                        case 0: // Summary (stub)
                            P.mode = "list"; P.lock = 2;
                        break;
                        case 1: // Switch → enter SELECT
                            P.swap_index = P.sel;
                            P.mode       = "select";
                            P.lock       = 2;
                        break;
                        case 2: // Item (stub)
                            P.mode = "list"; P.lock = 2;
                        break;
                        case 3: // Cancel
                            P.mode = "list"; P.lock = 2;
                        break;
                    }
                }

                // allow closing with Run handled above (since not in select)
            } break;

            case "select":
            {
                // list navigation still allowed to pick a target
                if (controls_pressed(_pid,"MoveDown") && n > 0) P.sel = clamp(P.sel + 1, 0, n - 1);
                if (controls_pressed(_pid,"MoveUp")   && n > 0) P.sel = clamp(P.sel - 1, 0, n - 1);

                // keep selection visible
                P.scroll = clamp(P.scroll, 0, max(0, n - ROWS));
                if (P.sel <  P.scroll)         P.scroll = P.sel;
                if (P.sel >= P.scroll + ROWS)  P.scroll = max(0, P.sel - ROWS + 1);

                // confirm swap
                if (controls_pressed(_pid,"Interact") && P.lock == 0){
                    var src = P.swap_index, dst = P.sel;
                    if (n > 0 && src >= 0 && src < n && dst >= 0 && dst < n && src != dst){
                        var t    = mons[src];  mons[src] = mons[dst];  mons[dst] = t;
                        P.mons   = mons;
                        P.sel    = dst;
                    }
                    P.mode       = "list";
                    P.swap_index = -1;
                    P.lock       = 2;
                }

                // cancel back to list (not closing)
                if (controls_pressed(_pid,"Run") && P.lock == 0){
                    P.mode       = "list";
                    P.swap_index = -1;
                    P.lock       = 2;
                }
            } break;
        }
    }
}


// --------- DRAW --------------------------------------------------------------

/// party_draw_gui_rect(_pid, _rx, _ry, _rw, _rh)  // v4.3 (no ternaries)
function party_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!party_is_open(_pid)) return;

    var _P = party_ensure(_pid);

    // ---- Scale 240×160 into target rect ----
    var _S  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _OX = _rx + (_rw - 240 * _S) div 2;
    var _OY = _ry + (_rh - 160 * _S) div 2;

    // ---- Colors ----
    var _C_BG_A    = make_color_rgb(252,236,180);
    var _C_BG_B    = make_color_rgb(248,220,140);
    var _C_PAPER   = make_color_rgb(255,243,195);
    var _C_PAPER_E = make_color_rgb(136,100,36);

    // ---- Background stripes ----
    var _stripe_h = 8;
    var _yy;
    for (_yy = 0; _yy < 160; _yy += _stripe_h){
        if ( ((_yy div _stripe_h) & 1) == 1 ) draw_set_color(_C_BG_B); else draw_set_color(_C_BG_A);
        draw_rectangle(_OX, _OY + _yy*_S, _OX + 240*_S, _OY + (_yy+_stripe_h)*_S, false);
    }

    // ---- Layout (UI space) ----
    var _LIST_X = 120, _LIST_Y = 8,  _LIST_W = 112, _LIST_H = 144; // right list (6 rows)
    var _INFO_X = 8,   _INFO_Y = 98, _INFO_W = 104, _INFO_H = 54;  // bottom-left info

    // ---- Right list frame ----
    var _lx1 = _OX + _LIST_X*_S;
    var _ly1 = _OY + _LIST_Y*_S;
    var _lx2 = _OX + (_LIST_X+_LIST_W)*_S;
    var _ly2 = _OY + (_LIST_Y+_LIST_H)*_S;
    draw_set_color(_C_PAPER);   draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(_lx1 - _S, _ly1 - _S, _lx2 + _S, _ly2 + _S, true);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    // ---- List metrics ----
    var _mons  = _P.mons;
    var _n     = array_length(_mons);
    var _ROWS  = 6;
    var _ROW_H = max(12, string_height("A") + 2);

    // ---- Icon / selector params ----
    var _spr_icon   = spr_mon_icon_placeholder;
    var _has_icon   = sprite_exists(_spr_icon);
    var _iw_base    = 32;
    var _ih_base    = 32;
    if (_has_icon){
        _iw_base = sprite_get_width(_spr_icon);
        _ih_base = sprite_get_height(_spr_icon);
    }
    var _ih_target  = _ROW_H * _S;
    var _isc_base   = _ih_target / _ih_base;
    var _sel_scale  = 1.18;
    var _bob_pix    = 2;
    var _bob        = sin(current_time/1000 * 5.0) * _bob_pix;

    var _pad_l_ui   = 2;
    var _txt_pad_ui = 4;

    // ---- Draw rows ----
    var _r;
    for (_r = 0; _r < _ROWS; _r++){
        var _idx = _P.scroll + _r;
        if (_idx >= _n) break;

        var _M = _mons[_idx];
        var _row_y_gui = _OY + (_LIST_Y + 8 + _r*_ROW_H) * _S;

        // selector
        if (_idx == _P.sel){
            if (sprite_exists(spr_selector)){
                var _sh2 = max(1, sprite_get_height(spr_selector));
                var _tgt2 = _ROW_H * _S;
                var _sc2  = _tgt2 / _sh2;
                draw_sprite_ext(spr_selector, 0, _OX + (_LIST_X + 4)*_S, _row_y_gui - _tgt2*0.15, _sc2, _sc2, 0, c_white, 1);
            } else {
                draw_text(_OX + (_LIST_X + 2)*_S, _row_y_gui, "►");
            }
        }

        // icon
        if (_has_icon){
            var _is_sel = (_idx == _P.sel);
            var _sc_icon;
            if (_is_sel) _sc_icon = _isc_base * _sel_scale; else _sc_icon = _isc_base;

            var _ix_gui = _OX + (_LIST_X + _pad_l_ui) * _S;
            var _ih_gui = _ih_base * _sc_icon;
            var _iy_gui = _row_y_gui - _ih_gui * 0.65;
            if (_is_sel) _iy_gui += _bob;

            var _subimg = 0;
            if (_is_sel){
                var _nf = max(1, sprite_get_number(_spr_icon));
                _subimg = (floor(current_time / 120) mod _nf);
            }
            draw_sprite_ext(_spr_icon, _subimg, floor(_ix_gui), floor(_iy_gui), _sc_icon, _sc_icon, 0, c_white, 1);
        }

        // display name
        var _disp_name = "???";
        if (is_struct(_M)){
            if (variable_struct_exists(_M, "species_id")){
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
            } else if (variable_struct_exists(_M, "species")) {
                _disp_name = string(_M.species);
            } else if (variable_struct_exists(_M, "name")) {
                _disp_name = string(_M.name);
            }
        }

        var _sel_scale_for_name = 1.0;
        if (_idx == _P.sel) _sel_scale_for_name = _sel_scale;

        var _name_x_ui = _LIST_X + _pad_l_ui + ceil((_iw_base * _isc_base) / _S * _sel_scale_for_name) + _txt_pad_ui;
        var _name_x_gui = _OX + _name_x_ui * _S;
        draw_text(_name_x_gui, _row_y_gui, _disp_name);
    }

    // footer in select
    if (string(_P.mode) == "select"){
        var _msg = "Select target";
        var _mx = _lx1 + ((_lx2 - _lx1) - string_width(_msg)) * 0.5 + 4;
        var _my = _ly2 - 10;
        draw_text(_mx, _my, _msg);
    }

    // ---- Info panel ----
    var _ix1 = _OX + _INFO_X*_S, _iy1 = _OY + _INFO_Y*_S;
    var _ix2 = _OX + (_INFO_X+_INFO_W)*_S, _iy2 = _OY + (_INFO_Y+_INFO_H)*_S;
    draw_set_color(_C_PAPER);   draw_rectangle(_ix1, _iy1, _ix2, _iy2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(_ix1 - _S, _iy1 - _S, _ix2 + _S, _iy2 + _S, true);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    if (array_length(_P.mons) > 0){
        var _sel_index = clamp(_P.sel, 0, array_length(_P.mons) - 1);
        var _L = _P.mons[_sel_index];

        // name again (clean)
        var _nm_disp = "???";
        if (is_struct(_L)){
            if (variable_struct_exists(_L, "species_id")){
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
            } else if (variable_struct_exists(_L, "species")) {
                _nm_disp = string(_L.species);
            } else if (variable_struct_exists(_L, "name")) {
                _nm_disp = string(_L.name);
            }
        }
        draw_text(_ix1 + 6*_S, _iy1 + 6*_S, _nm_disp);

        // nature (robust)
        var _nature_txt = "—";
        if (is_struct(_L)){
            if (variable_struct_exists(_L,"nature"))         _nature_txt = string(_L.nature);
            else if (variable_struct_exists(_L,"Nature"))    _nature_txt = string(_L.Nature);
            else if (variable_struct_exists(_L,"nat"))       _nature_txt = string(_L.nat);
        }
        draw_text(_ix1 + 6*_S, _iy1 + 20*_S, "Nature: " + _nature_txt);

        // hp current / max (robust)
        var _hp_cur = 0;
        if (is_struct(_L)){
            if (variable_struct_exists(_L,"hp"))      _hp_cur = _L.hp;
            else if (variable_struct_exists(_L,"HP")) _hp_cur = _L.HP;
        }

        var _hp_max = 1;
        if (is_struct(_L)){
            if (variable_struct_exists(_L,"maxhp"))      _hp_max = _L.maxhp;
            else if (variable_struct_exists(_L,"hp_max")) _hp_max = _L.hp_max;
        }
        if (!is_real(_hp_max) || _hp_max <= 0) _hp_max = max(1, _hp_cur);

        // level (robust)
        var _lvl_val = 1;
        if (is_struct(_L)){
            if (variable_struct_exists(_L,"level")) _lvl_val = _L.level;
            else if (variable_struct_exists(_L,"lvl")) _lvl_val = _L.lvl;
        }

        // HP bar (filled)
        var _bar_x = _ix1 + 6*_S;
        var _bar_y = _iy1 + 34*_S;
        var _bar_w = (_INFO_W - 12) * _S;
        var _bar_h = 6 * _S;

        draw_set_color(_C_PAPER_E);
        draw_rectangle(_bar_x - _S, _bar_y - _S, _bar_x + _bar_w + _S, _bar_y + _bar_h + _S, true);

        var _ratio = 0;
        if (_hp_max > 0) _ratio = clamp(_hp_cur / _hp_max, 0, 1);

        var _hp_col;
        if (_ratio >= 0.5)      _hp_col = make_color_rgb(56,200,72);
        else if (_ratio >= 0.2) _hp_col = make_color_rgb(248,200,40);
        else                    _hp_col = make_color_rgb(232,64,48);

        var _fill_w = floor(_bar_w * _ratio);
        draw_set_color(_hp_col);
        draw_rectangle(_bar_x, _bar_y, _bar_x + _fill_w, _bar_y + _bar_h, false);

        // texts under bar
        var _hp_txt = string(_hp_cur) + " / " + string(_hp_max);
        var _hp_tx  = _bar_x + _bar_w - string_width(_hp_txt);
        var _hp_ty  = _bar_y + _bar_h + (2*_S) + 6;

        draw_set_color(c_white);
        draw_text(_bar_x, _hp_ty, "Lv " + string(_lvl_val));
        draw_text(_hp_tx, _hp_ty, _hp_txt);
    }

    // ---- Submenu (drawn last; no background scrolling here) ----
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
        var _i;
        for (_i = 0; _i < 4; _i++){
            var _yy_menu = _by1 + (6 + _i*_m_h);
            if (_i == _P.menu_sel){
                if (sprite_exists(spr_selector)){
                    var _selh = max(1, sprite_get_height(spr_selector));
                    var _tgt  = _m_h;
                    var _sc   = _tgt / _selh;
                    draw_sprite_ext(spr_selector, 0, _bx1 + 4*_S, _yy_menu - _tgt*0.15, _sc, _sc, 0, c_white, 1);
                } else {
                    draw_text(_bx1 + 4*_S, _yy_menu, "►");
                }
            }
            draw_text(_bx1 + 16*_S, _yy_menu, _items[_i]);
        }
    }
}




function party_draw_gui(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    party_draw_gui_rect(_pid, 0, 0, _gw, _gh);
}
