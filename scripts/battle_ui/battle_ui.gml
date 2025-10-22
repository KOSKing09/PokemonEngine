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

    var _vis_hp = __battle_hp_visual(_A);
    var _pct = max(0, min(1, _vis_hp / max(1, (variable_struct_exists(_A, "hp_max") ? variable_struct_get(_A, "hp_max") : 1))));
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

    var _vis_hp2 = __battle_hp_visual(_A);
    var _pct = max(0, min(1, _vis_hp2 / max(1, (variable_struct_exists(_A, "hp_max") ? variable_struct_get(_A, "hp_max") : 1))));
    var _barW = _bw-__bwu(_pid,32), _barX=_bx+__bwu(_pid,8), _barY=_by+__bhu(_pid,20), _bh=__bhu(_pid,6);
    draw_set_color(c_black); draw_rectangle(_barX-1,_barY-1,_barX+_barW+1,_barY+_bh+1,false);
    var _hpcol = _t.col_hp_green; if (_pct<0.5) _hpcol=_t.col_hp_yell; if (_pct<0.2) _hpcol=_t.col_hp_red;
    draw_set_color(_hpcol); draw_rectangle(_barX,_barY,_barX+_barW*_pct,_barY+_bh,false);
    // Show numeric using visual HP to smoothly animate numbers
    var _vis_hp3 = __battle_hp_visual(_A);
    draw_text(_bx+_bw-__bwu(_pid,64), _by+__bhu(_pid,18), string(_vis_hp3)+"/"+string((variable_struct_exists(_A, "hp_max") ? variable_struct_get(_A, "hp_max") : 0)));

    // EXP bar (Emerald-style) drawn just under HP bar inside the player panel.
    // Reserve right side for the numeric exp text so the bar doesn't overlap the command/menu box.
    var _expBarY = _barY + _bh + __bhu(_pid,2); // place directly below hp bar with small padding
    var _expBarH = __bhu(_pid,3); // slightly thinner
    var _expPct = 0;
    var _B = __battle_ensure_slot(_pid);
    // If the battle slot thinks a dialog is active (set by wrappers when
    // opening a dialog), hide the command UI until that flag is cleared.
    // Also hide while a turn/action sequence is still active so the root
    // command/menu cannot appear mid-animation. This covers cases where
    // the dialog system may not report open yet or where we set a queued
    // active marker to avoid UI flashing.
    try { if (variable_struct_exists(_B, "_dlg_active") && variable_struct_get(_B, "_dlg_active")) return; } catch (e_dlgguard) {}
    try { if (variable_struct_exists(_B, "_action_active") && variable_struct_get(_B, "_action_active")) return; } catch (e_actguard) {}
    // If the battle has queued system animations, multi-hit sequences, pending
    // status messages, or is deferring the turn until dialogs close, hide UI
    // until those finish to avoid the command menu briefly appearing.
    try {
        if (variable_struct_exists(_B, "sys_anim") && is_struct(variable_struct_get(_B, "sys_anim"))){
            var _sact = variable_struct_get(_B, "sys_anim");
            if (variable_struct_exists(_sact, "active") && is_array(variable_struct_get(_sact, "active")) && array_length(variable_struct_get(_sact, "active")) > 0) return;
        }
        if (variable_struct_exists(_B, "_pending_multi_hit") && is_struct(variable_struct_get(_B, "_pending_multi_hit"))) return;
        if (variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs")) && array_length(variable_struct_get(_B, "_pending_status_msgs")) > 0) return;
        if (variable_struct_exists(_B, "_defer_turn_until_no_dialog") && variable_struct_get(_B, "_defer_turn_until_no_dialog")) return;
    } catch (e_queueguard){}
    // If a global cutscene flag or a dedicated cutscene instance is running,
    // hide the command UI as well. Many cutscene systems set a global flag
    // like CUTSCENE_ACTIVE; check a few common names safely.
    try {
        if (variable_global_exists("CUTSCENE_ACTIVE") && global.CUTSCENE_ACTIVE){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_ui][debug] suppressed UI: CUTSCENE_ACTIVE");
            return;
        }
        if (variable_global_exists("GLOBAL_CUTSCENE") && global.GLOBAL_CUTSCENE){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_ui][debug] suppressed UI: GLOBAL_CUTSCENE");
            return;
        }
        if (variable_global_exists("CUTSCENE") && global.CUTSCENE){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_ui][debug] suppressed UI: CUTSCENE");
            return;
        }
        // If a dedicated cutscene object exists and an instance is present, hide UI.
        // (Not checking specific object types here to avoid undeclared-symbol errors.)
    } catch (e_cutscene_guard){}
    // If a caller/global battle animation is playing (trainer/player intro or other
    // battleAnim), hide the command/root menus so they don't overlap the animation.
    // We must respect dialog: if a dialog is open, it's already handled above.
    try {
        var _phase_str = (variable_struct_exists(_B, "phase") ? string(variable_struct_get(_B, "phase")) : "");
    // Consider intro_player as an animation phase as well: some caller
    // battleAnim sprites/rendering happen during the player intro and we
    // should hide the system UI until the animation+holds fully finish.
    var _anim_phase_allowed_check = (_phase_str == "intro_call" || _phase_str == "intro_player" || _phase_str == "switch_in");
        // If an eligible animation sprite exists on the battle slot, hide UI while
        // the full animation duration (including holds) hasn't elapsed. This is
        // more robust than testing phase_progress alone because some flows use
        // phase_holds to keep the animation visible while dialog appears.
        if (_anim_phase_allowed_check){
            // Determine the animation total duration using the phase-specific duration
            // (intro_call -> "call", intro_player -> "player", switch_in -> "switch_in").
            var _start_ms = (variable_struct_exists(_B, "phase_start_ms") ? real(variable_struct_get(_B, "phase_start_ms")) : current_time);
            var _dur_key = "call";
            if (_phase_str == "intro_player") _dur_key = "player";
            else if (_phase_str == "switch_in") _dur_key = "switch_in";

            var _call_dur = 0;
            if (variable_struct_exists(_B, "phase_durs") && variable_struct_exists(variable_struct_get(_B, "phase_durs"), _dur_key)){
                _call_dur = max(0, real(variable_struct_get(variable_struct_get(_B, "phase_durs"), _dur_key)));
            }
            var _hold_ms = 0;
            if (variable_struct_exists(_B, "phase_holds") && variable_struct_exists(variable_struct_get(_B, "phase_holds"), _dur_key)){
                _hold_ms = max(0, real(variable_struct_get(variable_struct_get(_B, "phase_holds"), _dur_key)));
            }
            var _total_ms = _call_dur + _hold_ms;
            // Add a small safety buffer so UI doesn't flash immediately when dialog closes
            var _safety_buf = 120;
            var _elapsed = current_time - _start_ms;

            // If a caller-specific anim sprite exists and is valid, hide UI until elapsed >= total
            var _hide_for_anim = false;
            if (variable_struct_exists(_B, "caller_battleAnim")){
                var _cb_anim2 = variable_struct_get(_B, "caller_battleAnim");
                if (!is_undefined(_cb_anim2) && sprite_exists(_cb_anim2)){
                    if (_elapsed < (_total_ms + _safety_buf)) _hide_for_anim = true;
                }
            }
            // Otherwise check for global fallback anim
            if (! _hide_for_anim && variable_global_exists("battleAnim") && sprite_exists(global.battleAnim)){
                if (_elapsed < (_total_ms + _safety_buf)) _hide_for_anim = true;
            }
            if (_hide_for_anim) return;
        }
    } catch (e_anim_check){}
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
                // If this slot is Copycat, attempt to show the candidate move name in the UI.
                // Important: __battle_move_name expects a numeric move id, not a string.
                var nm = "";
                var is_copycat_slot = false;
                try {
                    if (is_string(mv) && mv == "copycat") is_copycat_slot = true;
                    else if (is_real(mv) && variable_global_exists("_moves") && is_array(global._moves) == false && is_struct(global._moves[mv]) && variable_struct_exists(global._moves[mv], "identifier") && string_lower(variable_struct_get(global._moves[mv], "identifier")) == "copycat") is_copycat_slot = true;
                    else if (is_real(mv) && variable_global_exists("_moves") && is_array(global._moves) && is_struct(global._moves[mv]) && variable_struct_exists(global._moves[mv], "identifier") && string_lower(variable_struct_get(global._moves[mv], "identifier")) == "copycat") is_copycat_slot = true;
                } catch (e_ic) { is_copycat_slot = false; }
            // Always display the slot's own move name (e.g. "Copycat").
            // The preview of the last move is intentionally disabled here to
            // avoid confusing the player; if you want a preview, show it only
            // on highlight or via a tooltip elsewhere.
            nm = __battle_move_name(mv);
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

