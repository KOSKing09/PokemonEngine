// Battle UI / HUD helpers (extracted)

function __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn){
    var _t  = __battle_ensure_slot(_pid).theme;
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn);
    var _bw = __bwu(_pid,_rwIn), _bh = __bhu(_pid,_rhIn);
    draw_set_color(_t.col_outline); draw_rectangle(_bx,_by,_bx+_bw,_by+_bh,false);
    draw_set_color(_t.col_panel);   draw_rectangle(_bx+1,_by+1,_bx+_bw-1,_by+_bh-1,false);
}

function __battle_enemy_box_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn,_A){
    var _t  = __battle_ensure_slot(_pid).theme;
    __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn), _bw = __bwu(_pid,_rwIn);
    draw_set_color(_t.col_text);

    var nameMax = _bw - __bwu(_pid, 48);
    var nameTxt = __battle_text_fit_ellipsis(_pid, string(_A.name), nameMax);
    draw_text(_bx+__bwu(_pid,8), _by+__bhu(_pid,6), nameTxt);

    draw_text(_bx+_bw-__bwu(_pid,29), _by+__bhu(_pid,6), "Lv"+string(_A.level));

    var _pct = max(0, min(1, __battle_hp_now(_A) / max(1, (variable_struct_exists(_A, "hp_max") ? variable_struct_get(_A, "hp_max") : 1))));
    var _barW = _bw-__bwu(_pid,32), _barX=_bx+__bwu(_pid,8), _barY=_by+__bhu(_pid,20), _bh=__bhu(_pid,6);
    draw_set_color(c_black); draw_rectangle(_barX-1,_barY-1,_barX+_barW+1,_barY+_bh+1,false);
    var _hpcol = _t.col_hp_green; if (_pct<0.5) _hpcol=_t.col_hp_yell; if (_pct<0.2) _hpcol=_t.col_hp_red;
    draw_set_color(_hpcol); draw_rectangle(_barX,_barY,_barX+_barW*_pct,_barY+_bh,false);
}

function __battle_player_box_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn,_A){
    var _t  = __battle_ensure_slot(_pid).theme;
    __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn), _bw = __bwu(_pid,_rwIn);
    draw_set_color(_t.col_text);

    var nameMax = _bw - __bwu(_pid, 72);
    var nameTxt = __battle_text_fit_ellipsis(_pid, string(_A.name), nameMax);
    draw_text(_bx+__bwu(_pid,8), _by+__bhu(_pid,6), nameTxt);

    draw_text(_bx+_bw-__bwu(_pid,32), _by+__bhu(_pid,6), "Lv"+string(_A.level));

    var _pct = max(0, min(1, __battle_hp_now(_A) / max(1, (variable_struct_exists(_A, "hp_max") ? variable_struct_get(_A, "hp_max") : 1))));
    var _barW = _bw-__bwu(_pid,32), _barX=_bx+__bwu(_pid,8), _barY=_by+__bhu(_pid,20), _bh=__bhu(_pid,6);
    draw_set_color(c_black); draw_rectangle(_barX-1,_barY-1,_barX+_barW+1,_barY+_bh+1,false);
    var _hpcol = _t.col_hp_green; if (_pct<0.5) _hpcol=_t.col_hp_yell; if (_pct<0.2) _hpcol=_t.col_hp_red;
    draw_set_color(_hpcol); draw_rectangle(_barX,_barY,_barX+_barW*_pct,_barY+_bh,false);
    draw_text(_bx+_bw-__bwu(_pid,64), _by+__bhu(_pid,18), string(__battle_hp_now(_A))+"/"+string((variable_struct_exists(_A, "hp_max") ? variable_struct_get(_A, "hp_max") : 0)));

    // EXP bar (Emerald-style) drawn just under HP bar inside the player panel.
    // Reserve right side for the numeric exp text so the bar doesn't overlap the command/menu box.
    var _expBarY = _barY + _bh + __bhu(_pid,2); // place directly below hp bar with small padding
    var _expBarH = __bhu(_pid,3); // slightly thinner
    var _expPct = 0;
    var _B = __battle_ensure_slot(_pid);
    if (is_struct(_B) && variable_struct_exists(_B, "_exp_anim")){
        var _ea = variable_struct_get(_B, "_exp_anim");
        if (is_struct(_ea) && variable_struct_exists(_ea, "active") && _ea.active && variable_struct_exists(_ea, "cur")){
            _expPct = max(0, min(1, real(variable_struct_get(_ea, "cur"))));
        }
    }
    // fallback to static actor values when no animation present
    if (_expPct == 0){
        var monRef = (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(_A.mon)) ? _A.mon : _A;
        if (is_struct(monRef) && variable_struct_exists(monRef, "exp") && variable_struct_exists(monRef, "exp_next") && is_real(variable_struct_get(monRef, "exp_next")) && variable_struct_get(monRef, "exp_next") > 0){
            _expPct = max(0, min(1, real(variable_struct_get(monRef, "exp")) / real(variable_struct_get(monRef, "exp_next"))));
        }
    }
    // Make the EXP bar use the same width region as the HP bar but reserve the same right column used by the HP numeric text
    var _expReserve = __bwu(_pid,64);
    var _expBarW = max(8, _barW - _expReserve - __bwu(_pid,8));
    // draw exp bar background and fill
    draw_set_color(c_black); draw_rectangle(_barX-1, _expBarY-1, _barX + _expBarW + 1, _expBarY + _expBarH + 1, false);
    draw_set_color(make_color_rgb(56,120,232)); // blue-ish exp color
    draw_rectangle(_barX, _expBarY, _barX + _expBarW * _expPct, _expBarY + _expBarH, false);

    // draw exp numeric to the right of the bar (clamped inside the panel)
    var _expText = "";
    var monRef2 = (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(_A.mon)) ? _A.mon : _A;
    if (is_struct(monRef2) && variable_struct_exists(monRef2, "exp") && variable_struct_exists(monRef2, "exp_next")){
        _expText = string(variable_struct_get(monRef2, "exp")) + "/" + string(variable_struct_get(monRef2, "exp_next"));
    }
    // Position EXP numeric in the same right-aligned column as HP numeric text
    var _expTextX = _bx + _bw - __bwu(_pid,64);
    draw_text(_expTextX, _expBarY, _expText);
}

function __battle_cmd_box_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn,_selX,_selY){
    var _t  = __battle_ensure_slot(_pid).theme;
    __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn), _bw = __bwu(_pid,_rwIn), _bh = __bhu(_pid,_rhIn);

    // Dialog rendering (clamped)
    if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)){
        var d = global.DIALOG2P[_pid];
        if (is_struct(d)){
            var i0 = d.page_idx*2, i1 = i0+1;
            var l0 = (i0 < array_length(d.all_lines)) ? d.all_lines[i0] : "";
            var l1 = (i1 < array_length(d.all_lines)) ? d.all_lines[i1] : "";
            var page_str = l0 + "\n" + l1;
            var vis_str = string_copy(page_str, 1, d.char_idx);
            
            // Split into two visible lines
            var vis0 = vis_str, vis1 = "";
            var npos = string_pos("\n", vis_str);
            if (npos > 0){
                vis0 = string_copy(vis_str, 1, npos - 1);
                vis1 = string_copy(vis_str, npos + 1, string_length(vis_str));
            }

            var maxW = _bw - __bwu(_pid,16);
            vis0 = __battle_text_fit_ellipsis(_pid, vis0, maxW);
            vis1 = __battle_text_fit_ellipsis(_pid, vis1, maxW);

            if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
            draw_set_color(_t.col_text);
            var _fh = (!is_undefined(__dlg_font_h) ? __dlg_font_h() : 8);
            draw_text(_bx + __bwu(_pid,8), _by + __bhu(_pid,6), vis0);
            draw_text(_bx + __bwu(_pid,8), _by + __bhu(_pid,6) + __bhu(_pid, _fh + 2), vis1);
            // Debug: note that the battle UI dialog branch executed. Only log once the page is fully visible
            var _page_full_len = string_length(l0 + "\n" + l1);
            if (is_real(d.char_idx) && d.char_idx >= _page_full_len){
                // Log once per page when verbose debug enabled
                    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE){
                    var _last = (variable_struct_exists(d, "_dbg_page_last") ? variable_struct_get(d, "_dbg_page_last") : -1);
                    if (_last != d.page_idx){
                        show_debug_message("[battle_ui][debug] drawing dialog pid=" + string(_pid) + ", vis0='" + string_copy(vis0,1,min(48,string_length(vis0))) + "', vis1='" + string_copy(vis1,1,min(48,string_length(vis1))) + "'");
                        variable_struct_set(d, "_dbg_page_last", d.page_idx);
                    }
                }
            }
        }
        return;
    }

    var _B = __battle_ensure_slot(_pid);

    // If a catch animation is active (throw/impact/shake/resolve), hide the command/root menus
    // so the UI doesn't reappear after the "used item" dialog.
    if (variable_struct_exists(_B, "_catch_anim")){
        var _ca_tmp = variable_struct_get(_B, "_catch_anim");
        if (is_struct(_ca_tmp) && variable_struct_exists(_ca_tmp, "active") && _ca_tmp.active){
            var _cph_tmp = (variable_struct_exists(_ca_tmp, "phase") ? string(variable_struct_get(_ca_tmp, "phase")) : "");
            if (!(_cph_tmp == "caught" || _cph_tmp == "escape")){
                return;
            }
        }
    }

    // FIGHT submenu
    if (string(_B.sys_ui.menu) == "fight"){
        var restoreFont = -1;
        if (variable_global_exists("FNT_POKEMON")) restoreFont = global.FNT_POKEMON;
        if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);

        var A = _B.actor[0];
        var cellW = (_bw * 0.5) - __bwu(_pid,16);
        for (var i=0; i<4; ++i){
            var col = i % 2;
            var row = i div 2;
            var tx = _bx + __bwu(_pid,12) + (col * (_bw * 0.5));
            var ty = _by + __bhu(_pid,6)  + (row * (_bh * 0.5));
            var hilite = (_selX == col) && (_selY == row);

            var mv = A.moves[i];
            var pp = A.pps[i];
            var nm = __battle_move_name(mv);
            var label = nm + "  " + (is_real(pp) ? string(pp) : "0") + " PP";
            label = __battle_text_fit_ellipsis(_pid, label, cellW);

            draw_set_color(hilite ? c_yellow : _t.col_text);
            draw_text(tx, ty, label);
        }

        if (restoreFont != -1) draw_set_font(restoreFont);
        return;
    }

    // Root menu
    var labels = ["FIGHT","BAG","POK\u00E9MON","RUN"];
    var restoreFont2 = -1;
    if (variable_global_exists("FNT_POKEMON")) restoreFont2 = global.FNT_POKEMON;
    if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);

    var rootCellW = (_bw * 0.5) - __bwu(_pid,16);
    for (var j=0; j<4; ++j){
        var tx2 = _bx + __bwu(_pid,12) + ((j % 2) * (_bw * 0.5));
        var ty2 = _by + __bhu(_pid,6)  + (floor(j / 2) * (_bh * 0.5));
        var hilite2 = (_selX == (j % 2)) && (_selY == floor(j / 2));
        var lbl = __battle_text_fit_ellipsis(_pid, labels[j], rootCellW);
        draw_set_color(hilite2 ? c_yellow : _t.col_text);
        draw_text(tx2, ty2, lbl);
    }
    if (restoreFont2 != -1) draw_set_font(restoreFont2);
}

