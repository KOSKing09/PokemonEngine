// Battle UI / HUD helpers (extracted)

function __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn){
    var _t  = __battle_ensure_slot(_pid).theme;
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn);
    var _bw = __bwu(_pid,_rwIn), _bh = __bhu(_pid,_rhIn);
    draw_set_color(_t.col_outline); draw_rectangle(_bx,_by,_bx+_bw,_by+_bh,false);
    draw_set_color(_t.col_panel);   draw_rectangle(_bx+1,_by+1,_bx+_bw-1,_by+_bh-1,false);
}

function __battle_stage_counter_parts(_A){
    var _out = [];
    if (!is_struct(_A) || !variable_struct_exists(_A, "_stages") || !is_struct(variable_struct_get(_A, "_stages"))) return _out;

    var _stages = variable_struct_get(_A, "_stages");
    var _keys = ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"];
    for (var _i = 0; _i < array_length(_keys); ++_i){
        var _key = _keys[_i];
        if (!variable_struct_exists(_stages, _key) || !is_real(variable_struct_get(_stages, _key))) continue;
        var _stage = clamp(floor(variable_struct_get(_stages, _key)), -6, 6);
        if (_stage == 0) continue;

        var _label = string_upper(_key);
        switch (_key){
            case "atk": _label = "ATK"; break;
            case "def": _label = "DEF"; break;
            case "spa": _label = "SPA"; break;
            case "spd": _label = "SPD"; break;
            case "spe": _label = "SPE"; break;
            case "accuracy": _label = "ACC"; break;
            case "evasion": _label = "EVA"; break;
        }

        array_push(_out, {
            text: _label + ((_stage > 0) ? "+" : "") + string(_stage),
            positive: (_stage > 0)
        });
    }

    return _out;
}

function __battle_draw_stage_counters(_x, _y, _A, _max_width = -1){
    var _parts = __battle_stage_counter_parts(_A);
    if (!is_array(_parts) || array_length(_parts) <= 0) return 0;

    var _old_color = draw_get_color();
    var _old_halign = draw_get_halign();
    var _old_valign = draw_get_valign();
    var _restore_font = undefined;
    if (variable_global_exists("FNT_POKEMON")) _restore_font = global.FNT_POKEMON;
    if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    var _cursor_x = _x;
    var _drawn_w = 0;
    var _gap = 2;
    var _text_y = _y + 2;

    for (var _i = 0; _i < array_length(_parts); ++_i){
        var _part = _parts[_i];
        var _text = variable_struct_get(_part, "text");
        var _text_w = max(1, string_width(_text));
        var _next_w = _text_w + ((_i > 0) ? _gap : 0);
        if (is_real(_max_width) && _max_width > 0 && (_drawn_w + _next_w) > _max_width) break;
        if (_i > 0) _cursor_x += _gap;
        draw_set_color(variable_struct_get(_part, "positive") ? make_color_rgb(72, 168, 96) : make_color_rgb(216, 88, 72));
        draw_text(_cursor_x, _text_y, _text);
        _cursor_x += _text_w;
        _drawn_w = _cursor_x - _x;
    }

    draw_set_color(_old_color);
    draw_set_halign(_old_halign);
    draw_set_valign(_old_valign);
    if (!is_undefined(_restore_font)) draw_set_font(_restore_font);
    return _drawn_w;
}

function __battle_measure_stage_counters(_A, _max_width = -1){
    var _parts = __battle_stage_counter_parts(_A);
    if (!is_array(_parts) || array_length(_parts) <= 0) return 0;

    var _restore_font = undefined;
    if (variable_global_exists("FNT_POKEMON")) _restore_font = global.FNT_POKEMON;
    if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);

    var _drawn_w = 0;
    var _gap = 2;
    for (var _i = 0; _i < array_length(_parts); ++_i){
        var _text = variable_struct_get(_parts[_i], "text");
        var _text_w = max(1, string_width(_text));
        var _next_w = _text_w + ((_i > 0) ? _gap : 0);
        if (is_real(_max_width) && _max_width > 0 && (_drawn_w + _next_w) > _max_width) break;
        _drawn_w += _next_w;
    }

    if (!is_undefined(_restore_font)) draw_set_font(_restore_font);
    return _drawn_w;
}

function __battle_enemy_box_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn,_A){
    if (!is_struct(_A)) return;

    var _t  = __battle_ensure_slot(_pid).theme;
    __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn), _bw = __bwu(_pid,_rwIn);
    draw_set_color(_t.col_text);

    var nameMax = _bw - __bwu(_pid, 48);
    var _name_raw = "???";
    if (variable_struct_exists(_A, "name")) _name_raw = string(variable_struct_get(_A, "name"));
    else if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && variable_struct_exists(variable_struct_get(_A, "mon"), "name")){
        _name_raw = string(variable_struct_get(variable_struct_get(_A, "mon"), "name"));
    }
    if (_name_raw == "???"){
        var _species_probe = undefined;
        if (variable_struct_exists(_A, "species") && is_real(variable_struct_get(_A, "species"))) _species_probe = variable_struct_get(_A, "species");
        else if (variable_struct_exists(_A, "species_id") && is_real(variable_struct_get(_A, "species_id"))) _species_probe = variable_struct_get(_A, "species_id");
        else if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))){
            var _mon_ref_name = variable_struct_get(_A, "mon");
            if (variable_struct_exists(_mon_ref_name, "species") && is_real(variable_struct_get(_mon_ref_name, "species"))) _species_probe = variable_struct_get(_mon_ref_name, "species");
            else if (variable_struct_exists(_mon_ref_name, "species_id") && is_real(variable_struct_get(_mon_ref_name, "species_id"))) _species_probe = variable_struct_get(_mon_ref_name, "species_id");
        }
        if (!is_undefined(_species_probe) && is_real(_species_probe) && !is_undefined(scr_poke_name_by_id)){
            _name_raw = string(scr_poke_name_by_id(_species_probe));
        }
    }
    var nameTxt = __battle_text_fit_ellipsis(_pid, _name_raw, nameMax);
    draw_text(_bx+__bwu(_pid,8), _by+__bhu(_pid,6), nameTxt);

    var _lvl_disp = 1;
    if (variable_struct_exists(_A, "level") && is_real(variable_struct_get(_A, "level"))) _lvl_disp = variable_struct_get(_A, "level");
    else if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && variable_struct_exists(variable_struct_get(_A, "mon"), "level") && is_real(variable_struct_get(variable_struct_get(_A, "mon"), "level"))) _lvl_disp = variable_struct_get(variable_struct_get(_A, "mon"), "level");
    draw_text(_bx+_bw-__bwu(_pid,29), _by+__bhu(_pid,6), "Lv"+string(_lvl_disp));

    var _vis_hp = __battle_hp_visual(_A);
    var _hp_max = __battle_hp_max(_A);
    var _pct = max(0, min(1, _vis_hp / max(1, _hp_max)));
    var _barW = _bw-__bwu(_pid,32), _barX=_bx+__bwu(_pid,8), _barY=_by+__bhu(_pid,20), _bh=__bhu(_pid,6);
    draw_set_color(c_black); draw_rectangle(_barX-1,_barY-1,_barX+_barW+1,_barY+_bh+1,false);
    var _hpcol = _t.col_hp_green; if (_pct<0.5) _hpcol=_t.col_hp_yell; if (_pct<0.2) _hpcol=_t.col_hp_red;
    draw_set_color(_hpcol); draw_rectangle(_barX,_barY,_barX+_barW*_pct,_barY+_bh,false);
    var _statusX = _barX;
    var _statusY = _barY + _bh + __bhu(_pid, 2);
    var _statusW = 0;
    if (!is_undefined(__party_draw_status_ui)){
        _statusW = __party_draw_status_ui(_statusX, _statusY, 0.8, _A, _barW);
    }
    if (!is_undefined(__battle_draw_stage_counters)){
        var _stageX = _statusX + _statusW;
        if (_statusW > 0) _stageX += __bwu(_pid, 2);
        var _stageMax = max(0, (_barX + _barW) - _stageX);
        __battle_draw_stage_counters(_stageX, _statusY, _A, _stageMax);
    }
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

    var _vis_hp2 = __battle_hp_visual(_A);
    var _pct = max(0, min(1, _vis_hp2 / max(1, (variable_struct_exists(_A, "hp_max") ? variable_struct_get(_A, "hp_max") : 1))));
    var _barW = _bw-__bwu(_pid,32), _barX=_bx+__bwu(_pid,8), _barY=_by+__bhu(_pid,20), _bh=__bhu(_pid,6);
    draw_set_color(c_black); draw_rectangle(_barX-1,_barY-1,_barX+_barW+1,_barY+_bh+1,false);
    var _hpcol = _t.col_hp_green; if (_pct<0.5) _hpcol=_t.col_hp_yell; if (_pct<0.2) _hpcol=_t.col_hp_red;
    draw_set_color(_hpcol); draw_rectangle(_barX,_barY,_barX+_barW*_pct,_barY+_bh,false);
    // Show numeric using visual HP to smoothly animate numbers and align near bar end
    var _vis_hp3 = __battle_hp_visual(_A);
    var _hpText = string(_vis_hp3) + "/" + string((variable_struct_exists(_A, "hp_max") ? variable_struct_get(_A, "hp_max") : 0));
    var _hpTextX = _barX + _barW - __bwu(_pid,6) - string_width(_hpText);
    draw_text(_hpTextX, _by+__bhu(_pid,18), _hpText);

    // Top row: status sprites and temporary stage counters.
    var _topRowX = _bx + __bwu(_pid,8);
    var _topRowY = _by + __bhu(_pid,13);
    var _topRowMax = _bw - __bwu(_pid,16);
    var _statusReserve = 0;
    if (!is_undefined(__party_draw_status_ui)) _statusReserve = __party_draw_status_ui(_topRowX, _topRowY, 0.8, _A, _topRowMax);
    if (!is_undefined(__battle_draw_stage_counters)){
        var _stageTopX = _topRowX + _statusReserve;
        if (_statusReserve > 0) _stageTopX += __bwu(_pid, 2);
        var _stageTopMax = max(0, (_topRowX + _topRowMax) - _stageTopX);
        __battle_draw_stage_counters(_stageTopX, _topRowY, _A, _stageTopMax);
    }

    var _expReserve = __bwu(_pid,64);
    var _expBarY = _barY + _bh + __bhu(_pid,2);
    var _expBarH = __bhu(_pid,3);
    var _expPct = 0;
    var _B = __battle_ensure_slot(_pid);
    // Note: command/menu suppression (dialog/cutscene/animations) should not
    // hide the player panel's EXP bar. Those guards belong in the command box
    // draw path, not here.
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
    var _expBarX = _barX;
    var _expBarW = max(8, _barW - _expReserve - __bwu(_pid,8));
    // draw exp bar background and fill
    draw_set_color(c_black); draw_rectangle(_expBarX-1, _expBarY-1, _expBarX + _expBarW + 1, _expBarY + _expBarH + 1, false);
    draw_set_color(make_color_rgb(56,120,232)); // blue-ish exp color
    draw_rectangle(_expBarX, _expBarY, _expBarX + _expBarW * _expPct, _expBarY + _expBarH, false);

    // draw exp numeric to the right of the bar (clamped inside the panel)
    var _expText = "";
    var monRef2 = (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(_A.mon)) ? _A.mon : _A;
    if (is_struct(monRef2) && variable_struct_exists(monRef2, "exp") && variable_struct_exists(monRef2, "exp_next")){
        _expText = string(variable_struct_get(monRef2, "exp")) + "/" + string(variable_struct_get(monRef2, "exp_next"));
    }
    // Position EXP numeric in the same right-aligned column as HP numeric text
    var _expTextX = _bx + _bw - __bwu(_pid,8) - string_width(_expText);
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
    // Do not show the command/root menus during intro phases or while the
    // intro has not been marked completed. This prevents the brief flash of
    // the command UI between the "Go" dialog and the Pokémon cry/intro.
    try {
        if (variable_struct_exists(_B, "_intro_completed") && !variable_struct_get(_B, "_intro_completed")) return;
        var _ph = (variable_struct_exists(_B, "phase") ? string(variable_struct_get(_B, "phase")) : "");
        if (_ph == "transition_in" || _ph == "intro_enemy" || _ph == "intro_call" || _ph == "intro_player") return;
        // If update code requested to wait until dialog fully closes before showing the
        // UI, hide the command box here as well to cover the exact frame of closure.
        if (variable_struct_exists(_B, "_suppress_wait_for_dialog_close") && variable_struct_get(_B, "_suppress_wait_for_dialog_close")) return;
    } catch (e_introguard) {}
    // If a closing fade is active, hide command UI entirely
    try { if (variable_struct_exists(_B, "_closing") && variable_struct_get(_B, "_closing")) return; } catch (e_closeguard) {}

    // If a switch animation is active (switch_in phase), hide the command/root menus
    // so the command window stays blank while the Pokémon is switching. This mirrors
    // the existing behavior used for catch animations.
    // Respect explicit suppression timer set by battle_system during switch animations
    if (variable_struct_exists(_B, "phase") && string(_B.phase) == "switch_in"){
        return;
    }
    if (variable_struct_exists(_B, "_suppress_sys_ui_until")){
        var _su = variable_struct_get(_B, "_suppress_sys_ui_until");
        if (is_real(_su) && current_time < _su) return;
        // clean up expired suppression
        if (is_real(_su) && current_time >= _su) variable_struct_set(_B, "_suppress_sys_ui_until", undefined);
    }

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
        // NOTE: removed noisy DATA_DEBUG fight-menu spam. Re-enable only when
        // troubleshooting by setting DATA_DEBUG_VERBOSE = true and re-inserting
        // a single-shot debug print guarded by that flag.
        var cellW = (_bw * 0.5) - __bwu(_pid,16);
        for (var i=0; i<4; ++i){
            var col = i % 2;
            var row = i div 2;
            var tx = _bx + __bwu(_pid,12) + (col * (_bw * 0.5));
            var ty = _by + __bhu(_pid,6)  + (row * (_bh * 0.5));
            var hilite = (_selX == col) && (_selY == row);

                // Safely read move id and PP for this slot. Actor or its arrays may be
                // missing or shorter than 4; defensively fall back to placeholders.
                var mv = -1;
                var pp = 0;
                try {
                    if (is_struct(A)){
                        if (variable_struct_exists(A, "moves") && is_array(variable_struct_get(A, "moves")) && i >= 0 && i < array_length(variable_struct_get(A, "moves"))) mv = variable_struct_get(A, "moves")[i];
                        if (variable_struct_exists(A, "pps") && is_array(variable_struct_get(A, "pps")) && i >= 0 && i < array_length(variable_struct_get(A, "pps"))) pp = variable_struct_get(A, "pps")[i];
                    }
                } catch (e_read) { mv = -1; pp = 0; }
                var nm = "";
                var is_copycat_slot = false;
                try {
                    if (is_string(mv) && mv == "copycat") is_copycat_slot = true;
                    else if (is_real(mv) && variable_global_exists("_moves") && is_array(global._moves) == false && is_struct(global._moves[mv]) && variable_struct_exists(global._moves[mv], "identifier") && string_lower(variable_struct_get(global._moves[mv], "identifier")) == "copycat") is_copycat_slot = true;
                    else if (is_real(mv) && variable_global_exists("_moves") && is_array(global._moves) && is_struct(global._moves[mv]) && variable_struct_exists(global._moves[mv], "identifier") && string_lower(variable_struct_get(global._moves[mv], "identifier")) == "copycat") is_copycat_slot = true;
                } catch (e_ic) { is_copycat_slot = false; }
                nm = __battle_move_name(mv);
                if (is_copycat_slot && !is_undefined(__battle_find_copycat_candidate)){
                    try {
                        var copycat_mv = __battle_find_copycat_candidate(_pid, A);
                        if (is_real(copycat_mv) && copycat_mv != mv){
                            nm = __battle_move_name(copycat_mv);
                        }
                    } catch (e_cc_preview) {}
                }
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

