// ============================================================================
// scr_dialog2p_system.gml
// - 2-player dialog, per-camera draw (works single player too)
// - Classic Pokémon box by default (22 cols × 2 rows)
// - Uses global.DIALOG_SPEED (1/2/3) for type speed
// - Requires font_pokemon_draw(), and global.FONT_POKEMON (sprite + map). 
// ============================================================================

// ---------- Safe font metrics (fallbacks if struct incomplete) --------------
function __dlg_font_w(){
    return (variable_global_exists("FONT_CHAR_W") ? max(1, global.FONT_CHAR_W) : 8);
}
function __dlg_font_h(){
    return (variable_global_exists("FONT_CHAR_H") ? max(1, global.FONT_CHAR_H) : 8);
}

// ---------- Session factory (classic defaults) ------------------------------
function __dlg_make_session(){
    var cw = __dlg_font_w();
    var ch = __dlg_font_h();
    var _cols = 22;
    var _rows = 2;

    return {
        open        : false,   // keep field name 'open'
        _spd        : 2,       // 1/2/3, copied from global.DIALOG_SPEED on open
        cps_table   : [1,2,4], // chars per step (slow/normal/fast)

        // content
        all_lines   : [],
        lines       : ["",""],
        page_idx    : 0,
        char_idx    : 0,
        tick        : 0,
        arrow_tick  : 0,

        // style
        cols        : _cols,
        rows        : _rows,
        box_w       : _cols * cw,
        box_h       : _rows * ch + 8,
        border_pad  : 8,
        margin_h    : 4,
        margin_v    : 4,

        // cosmetics
        portrait       : noone,
        portrait_frame : 0,
        name_label     : "",
        sfx_tick       : noone
    };
}

// ---------- Init ------------------------------------------------------------
function dialog2p_init(){
    global.DIALOG2P = [ __dlg_make_session(), __dlg_make_session() ];
}

// ---------- Query -----------------------------------------------------------
function dialog2p_is_open(_pid){
    if (!variable_global_exists("DIALOG2P")) return false;
    var d = global.DIALOG2P[_pid];
    return (is_struct(d) && variable_struct_exists(d,"open")) ? d.open : false;
}

// ---------- Open text (wrap + reset) ---------------------------------------
function __dlg_wrap_text(_text, _box_w){
    var _col_w  = __dlg_font_w();
    var _maxcol = max(1, floor(_box_w / _col_w));

    var _out = [];
    var _src = string_split(_text, "\n");
    for (var li = 0; li < array_length(_src); li++){
        var _line = _src[li]; // changed from "ln" to "_line"
        var words = string_split(_line, " ");
        var cur = "";
        for (var wi = 0; wi < array_length(words); wi++){
            var w = words[wi];
            while (string_length(w) > _maxcol){
                array_push(_out, string_copy(w, 1, _maxcol));
                w = string_copy(w, _maxcol + 1, string_length(w) - _maxcol);
            }
            var tryln = (cur == "" ? w : cur + " " + w);
            if (string_length(tryln) <= _maxcol) cur = tryln;
            else { array_push(_out, cur); cur = w; }
        }
        if (cur != "") array_push(_out, cur);
        if (array_length(words) == 0) array_push(_out, "");
    }
    return _out;
}
function dialog2p_open_text(_pid, _text){
    var d = global.DIALOG2P[_pid];

    // If a battle slot exists for this pid and a faint is pending, do not
    // immediately replace the dialog. Instead enqueue the text as a pending
    // status message so it will be shown after the faint dialog completes.
    try {
        if (variable_global_exists("sys_battles") && is_array(global.sys_battles) && array_length(global.sys_battles) > _pid){
            var _Bchk = global.sys_battles[_pid];
            if (is_struct(_Bchk) && variable_struct_exists(_Bchk, "_faint_pending") && variable_struct_get(_Bchk, "_faint_pending") == true){
                // Ensure pending array exists and avoid duplicates/runaway growth
                var _ps = (variable_struct_exists(_Bchk, "_pending_status_msgs") ? variable_struct_get(_Bchk, "_pending_status_msgs") : []);
                var _txt_s = string(_text);
                var _already = false;
                for (var _ii=0; _ii<array_length(_ps); ++_ii) if (string(_ps[_ii]) == _txt_s){ _already = true; break; }
                if (!_already){
                    // Cap the pending queue to a reasonable size to avoid runaway loops
                    if (array_length(_ps) < 64) array_push(_ps, _txt_s);
                    else {
                        // If queue is full, drop the oldest and push the new one
                        var _tmpn = [];
                        for (var _jj = 1; _jj < array_length(_ps); ++_jj) _tmpn[array_length(_tmpn)] = _ps[_jj];
                        _tmpn[array_length(_tmpn)] = _txt_s;
                        _ps = _tmpn;
                    }
                    variable_struct_set(_Bchk, "_pending_status_msgs", _ps);
                }
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[dialog][queue] queued pid=" + string(_pid) + ", preview='" + string_copy(string(_text),1,min(48,string_length(string(_text)))) + "'");
                return;
            }
        }
    } catch (e_q) { /* ignore queuing failures and fall through to open */ }

    // Preserve previous content preview so we can avoid logging repeats
    var _prev_text = "";
    if (is_struct(d) && variable_struct_exists(d, "all_lines") && is_array(variable_struct_get(d, "all_lines"))){
        var _pl = variable_struct_get(d, "all_lines");
        for (var _pi=0; _pi<array_length(_pl); ++_pi) _prev_text += string(_pl[_pi]) + "\n";
        _prev_text = string_trim(_prev_text);
    }

    d._spd       = clamp(global.DIALOG_SPEED, 1, 3);
    d.all_lines  = __dlg_wrap_text(_text, d.box_w);
    d.page_idx   = 0;
    d.char_idx   = 0;
    d.tick       = 0;
    d.arrow_tick = 0;
    d.open       = true;

    // Debug: log dialog opens to help trace timing issues
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        // Only log opened/session debug when the new wrapped text is different from previous content
        var _new_preview = string_copy(string(_text), 1, min(48, string_length(string(_text))));
        // Reconstruct the full new wrapped text for accurate comparison
        var _new_full = "";
        for (var _ni=0; _ni<array_length(d.all_lines); ++_ni) _new_full += string(d.all_lines[_ni]) + "\n";
        _new_full = string_trim(_new_full);
        if (_new_full != _prev_text){
            try { if (variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG) show_debug_message("[dialog][debug] opened pid=" + string(_pid) + ", preview='" + _new_preview + "'"); } catch (e){}
            // Dump session internals to help trace why dialogs might not render
            try {
                var _dbg = "[dialog][debug] sess open=" + string(d.open) + ", pages=" + string(array_length(d.all_lines)) + ", page_idx=" + string(d.page_idx) + ", char_idx=" + string(d.char_idx);
                try { if (variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG) show_debug_message(_dbg); } catch (e_dbg) { /* ignore */ }
            } catch (e_dbg) { /* ignore */ }
        }
    }
    // Small input-grace window: ignore presses that occurred to open the dialog
    // (e.g. selecting a Pokémon) so the dialog doesn't immediately advance.
    // Use a short ms window (120ms) to be forgiving across frame timing.
    if (is_real(current_time)) variable_struct_set(d, "_open_grace_until", current_time + 120);
}

// ---------- Optional cosmetics ---------------------------------------------
function dialog2p_set_portrait(_pid, _spr, _subimg, _name){
    var d = global.DIALOG2P[_pid];
    d.portrait       = _spr;
    d.portrait_frame = _subimg;
    d.name_label     = string(_name);
}

// ---------- Update (advance/close, robust) ---------------------------------
function dialog2p_update(_pid){
    var d = global.DIALOG2P[_pid];
    if (!d.open) return;

    var i0 = d.page_idx*2, i1 = i0+1;
    var l0 = (i0 < array_length(d.all_lines)) ? d.all_lines[i0] : "";
    var l1 = (i1 < array_length(d.all_lines)) ? d.all_lines[i1] : "";
    d.lines = [l0, l1];

    var page_str = l0 + "\n" + l1;
    var page_len = string_length(page_str);
    var has_next = ((d.page_idx+1)*2) < array_length(d.all_lines);

    var advance = controls_pressed(_pid,"Interact") || controls_pressed(_pid,"Inventory");
    var cancel  = controls_pressed(_pid,"Run") || controls_pressed(_pid,"Pause");
    // DEVDEBUG: log input state for dialog advancement
    try { if (variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG){ var _ogr = (variable_struct_exists(d, "_open_grace_until") ? string(variable_struct_get(d, "_open_grace_until")) : "<nil>"); show_debug_message("[dialog][update] pid=" + string(_pid) + ", page_idx=" + string(d.page_idx) + ", char_idx=" + string(d.char_idx) + ", advance=" + string(advance) + ", cancel=" + string(cancel) + ", open_grace_until=" + _ogr); } } catch(e){}
    // respect a small input grace period set at open to avoid immediately
    // consuming the same 'Interact' press that opened the dialog (e.g. from
    // party selection). If present, suppress advance until the grace expires.
    var _now_time = (is_real(current_time) ? current_time : -1);
    if (is_struct(d) && variable_struct_exists(d, "_open_grace_until") && is_real(_now_time)){
        var _grace = variable_struct_get(d, "_open_grace_until");
        if (is_real(_grace) && _now_time <= _grace){
            advance = false;
        }
    }

    if (d.char_idx < page_len){
        if (advance){
            d.char_idx = page_len; // finish instantly
        } else {
            d.tick++;
            if (d.tick >= 1){
                d.tick = 0;
                var cps = d.cps_table[d._spd - 1];
                d.char_idx = clamp(d.char_idx + cps, 0, page_len);
                if (d.sfx_tick != noone) audio_play_sound(d.sfx_tick, 1, false);
            }
        }
    } else {
        if (advance || cancel){
            if (has_next){
                d.page_idx++;
                d.char_idx = 0;
                d.tick = 0;
            } else {
                // DEVDEBUG: log that dialog is closing and why
                try { if (variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG){ show_debug_message("[dialog][update] pid=" + string(_pid) + ", closing page_idx=" + string(d.page_idx) + ", advance=" + string(advance) + ", cancel=" + string(cancel)); } } catch(e){}
                d.open = false;
            }
        }
    }
    d.arrow_tick = (d.arrow_tick + 1) mod 60;
}

// ---------- Draw in WORLD space for a given camera (splitscreen-friendly) ---
function __dlg_draw_lines_spritefont(_l0, _l1, _x, _y){
    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
    draw_text(_x, _y, _l0);
    if (_l1 != "") draw_text(_x, _y + __dlg_font_h() + 2, _l1);
}


function dialog2p_draw_world(_pid, _cam){
    var d = global.DIALOG2P[_pid];
    if (!d.open) return;

    // Debug logging for dialog draw. Disabled by default; enable by setting
    // global.DIALOG_DEBUG = true (requires DATA_DEBUG to also be true).
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG && variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG){
        try {
            // Only log when the page index changes or at most once per second to avoid spam
            var _pages = array_length(d.all_lines);
            var _state = string(d.page_idx) + "/" + string(_pages);
            var _last = (variable_struct_exists(d, "_dbg_last_state") ? variable_struct_get(d, "_dbg_last_state") : "");
            var _last_time = (variable_struct_exists(d, "_dbg_last_time") ? variable_struct_get(d, "_dbg_last_time") : -999999);
            var _now = (is_real(current_time) ? current_time : 0);
            if (_state != _last || (_now - _last_time) > 1000){
                show_debug_message("[dialog][debug] draw pid=" + string(_pid) + ", page_idx=" + string(d.page_idx) + ", pages=" + string(_pages) );
                variable_struct_set(d, "_dbg_last_state", _state);
                variable_struct_set(d, "_dbg_last_time", _now);
            }
        } catch (e_dbg) {}
    }

    var vx = camera_get_view_x(_cam);
    var vy = camera_get_view_y(_cam);
    var vw = camera_get_view_width(_cam);
    var vh = camera_get_view_height(_cam);

    var pad = d.border_pad;
    var name_h = (d.name_label != "" ? 14 : 0);
    var bw = d.box_w + pad*2;
    var bh = d.box_h + pad*2 + name_h;

    // clamp to camera & anchor bottom-center, crisp pixels
    bw = max(32, min(bw, vw - 2*d.margin_h));
    bh = max(24, min(bh, vh - 2*d.margin_v));

    var px = round(vx + (vw - bw) * 0.5);
    var py = round(vy + vh - (bh + d.margin_v));

    // panel
    draw_set_color(make_color_rgb(30,34,46));
    draw_rectangle(px, py, px + bw, py + bh, false);
    draw_set_color(make_color_rgb(80,85,100));
    draw_roundrect(px, py, px + bw, py + bh, false);

    // name
    var y_off = 0;
    if (d.name_label != ""){
        draw_set_color(c_white);
        draw_set_halign(fa_left);
        draw_text(px + pad, py + 4, d.name_label);
        y_off = 14;
    }

    // portrait (optional)
    var text_left = pad;
    if (d.portrait != noone){
        var ph = sprite_get_height(d.portrait);
        var pw = sprite_get_width(d.portrait);
        var scale = min((d.box_h) / max(1, ph), 1);
        var pox = round(px + pad);
        var poy = round(py + pad + y_off + (d.box_h - ph*scale) * 0.5);
        draw_sprite_ext(d.portrait, d.portrait_frame, pox, poy, scale, scale, 0, c_white, 1);
        text_left += pw*scale + 6;
    }

    // visible text of this page
    var a = d.lines[0], b = d.lines[1];
    var page_str = a + "\n" + b;
    var page_len = string_length(page_str);
    var vis_str  = string_copy(page_str, 1, d.char_idx);

    var vis0 = vis_str, vis1 = "";
    var npos = string_pos("\n", vis_str);
    if (npos > 0){
        vis0 = string_copy(vis_str, 1, npos - 1);
        vis1 = string_copy(vis_str, npos + 1, string_length(vis_str));
    }

    var tx = round(px + text_left);
    var ty = round(py + pad + y_off);
    __dlg_draw_lines_spritefont(vis0, vis1, tx, ty);

    // next-page arrow
    var has_next = ((d.page_idx+1)*2) < array_length(d.all_lines);
    if (d.char_idx >= page_len && has_next){
        if ((d.arrow_tick div 30) == 0){
            var ax = round(px + bw - pad - 12);
            var ay = round(py + bh - pad - 10);
            draw_set_color(c_white);
            draw_triangle(ax, ay, ax+8, ay, ax+4, ay+6, false);
        }
    }
}
