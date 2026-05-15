// Battle UI / HUD helpers (extracted)


// ===== Rect pipeline (PID-aware, GUI-only) =====
function __bui_begin(_pid,_rx,_ry,_rw,_rh){
    var _B = __battle_ensure_slot(_pid);
    var base_w = 240, base_h = 160;
    var sx = _rw / base_w;
    var sy = _rh / base_h;
    var s = min(sx, sy);
    var content_w = floor(base_w * s);
    var content_h = floor(base_h * s);
    var origin_x = _rx + floor((_rw - content_w) / 2);
    var origin_y = _ry + floor((_rh - content_h) / 2);
    _B._ui = { rx: origin_x, ry: origin_y, rw: content_w, rh: content_h, base_w: base_w, base_h: base_h, s: s };
}
function __bui_end(_pid){
    var _B = __battle_ensure_slot(_pid);
    _B._ui = undefined;
}
function __bxu(_pid,_xv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _xv;
    return floor(_u.rx + _xv * _u.s);
}
function __byu(_pid,_yv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _yv;
    return floor(_u.ry + _yv * _u.s);
}
function __bwu(_pid,_wv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _wv;
    return floor(_wv * _u.s);
}
function __bhu(_pid,_hv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _hv;
    return floor(_hv * _u.s);
}

// ===== Panels & HUD =====
function __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn){
    var _t  = __battle_ensure_slot(_pid).theme;
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn);
    var _bw = __bwu(_pid,_rwIn), _bh = __bhu(_pid,_rhIn);
    draw_set_color(_t.col_outline); draw_rectangle(_bx,_by,_bx+_bw,_by+_bh,false);
    draw_set_color(_t.col_panel);   draw_rectangle(_bx+1,_by+1,_bx+_bw-1,_by+_bh-1,false);
}

function __battle_draw_levelup_panel(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_levelup_panel")) return;

    var _panel = variable_struct_get(_B, "_levelup_panel");
    if (!is_struct(_panel) || !variable_struct_exists(_panel, "active") || !_panel.active) return;

    var _rows = (variable_struct_exists(_panel, "rows") && is_array(variable_struct_get(_panel, "rows"))) ? variable_struct_get(_panel, "rows") : [];
    var _actor_idx = (variable_struct_exists(_panel, "actor_index") && is_real(variable_struct_get(_panel, "actor_index"))) ? clamp(floor(variable_struct_get(_panel, "actor_index")), 0, 1) : 0;
    var _center = !is_undefined(__battle_anim_queue_actor_center) ? __battle_anim_queue_actor_center(_pid, _actor_idx) : [__bxu(_pid, 64), __byu(_pid, 112)];
    var _elapsed = max(0, current_time - (variable_struct_exists(_panel, "start_ms") ? variable_struct_get(_panel, "start_ms") : current_time));
    var _slide_dur = max(1, (variable_struct_exists(_panel, "slide_dur") ? variable_struct_get(_panel, "slide_dur") : 220));
    var _count_dur = max(1, (variable_struct_exists(_panel, "count_dur") ? variable_struct_get(_panel, "count_dur") : 320));
    var _current_row = (variable_struct_exists(_panel, "current_row") && is_real(variable_struct_get(_panel, "current_row"))) ? floor(variable_struct_get(_panel, "current_row")) : -1;
    var _row_anim_start = (variable_struct_exists(_panel, "row_anim_start_ms") && is_real(variable_struct_get(_panel, "row_anim_start_ms"))) ? variable_struct_get(_panel, "row_anim_start_ms") : -1;
    var _close_ready = (variable_struct_exists(_panel, "close_ready") && variable_struct_get(_panel, "close_ready"));
    var _slide_t = clamp(_elapsed / _slide_dur, 0, 1);
    var _slide_e = 1 - power(1 - _slide_t, 3);

    var _pw = __bwu(_pid, 104);
    var _ph = __bhu(_pid, 82);
    var _target_x = clamp(_center[0] + __bwu(_pid, 18), __bxu(_pid, 96), __bxu(_pid, 240 - 104 - 8));
    var _target_y = clamp(_center[1] - __bhu(_pid, 60), __byu(_pid, 8), __byu(_pid, 160 - 82 - 8));
    var _panel_x = lerp(__bxu(_pid, 248), _target_x, _slide_e);
    var _panel_y = _target_y;
    var _header_h = __bhu(_pid, 14);
    var _footer_y = _panel_y + _ph - __bhu(_pid, 10);

    draw_set_alpha(0.25);
    draw_set_color(c_black);
    draw_rectangle(_panel_x + __bwu(_pid, 2), _panel_y + __bhu(_pid, 2), _panel_x + _pw + __bwu(_pid, 2), _panel_y + _ph + __bhu(_pid, 2), false);
    draw_set_alpha(1);

    draw_set_color(make_color_rgb(72, 112, 64));
    draw_rectangle(_panel_x, _panel_y, _panel_x + _pw, _panel_y + _ph, false);
    draw_set_color(make_color_rgb(232, 248, 216));
    draw_rectangle(_panel_x + 1, _panel_y + 1, _panel_x + _pw - 1, _panel_y + _ph - 1, false);
    draw_set_color(make_color_rgb(112, 168, 96));
    draw_rectangle(_panel_x + 1, _panel_y + 1, _panel_x + _pw - 1, _panel_y + _header_h, false);

    var _title_font = variable_global_exists("FNT_POKEMON") ? global.FNT_POKEMON : -1;
    var _small_font = variable_global_exists("FNT_POKEMON_SMALL") ? global.FNT_POKEMON_SMALL : _title_font;
    var _title_col = make_color_rgb(252, 248, 188);
    var _name_col = make_color_rgb(84, 96, 156);
    var _label_col = make_color_rgb(92, 108, 176);
    var _value_col = make_color_rgb(232, 132, 84);
    var _delta_col = make_color_rgb(104, 196, 120);
    var _prompt_col = make_color_rgb(248, 180, 92);

    draw_set_font(_title_font);
    draw_set_color(_title_col);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_text(_panel_x + (_pw * 0.5), _panel_y + __bhu(_pid, 3), "LEVEL UP");

    var _level_txt = "Lv" + string(variable_struct_exists(_panel, "level") ? variable_struct_get(_panel, "level") : 1);
    draw_set_halign(fa_right);
    draw_set_color(_title_col);
    draw_text(_panel_x + _pw - __bwu(_pid, 6), _panel_y + __bhu(_pid, 3), _level_txt);

    draw_set_font(_small_font);
    draw_set_halign(fa_left);
    var _name_max_w = _pw - __bwu(_pid, 12);
    var _name_txt = string(variable_struct_exists(_panel, "mon_name") ? variable_struct_get(_panel, "mon_name") : "");
    if (!is_undefined(__battle_text_fit_ellipsis)) _name_txt = __battle_text_fit_ellipsis(_pid, _name_txt, _name_max_w);
    draw_set_color(_name_col);
    draw_text(_panel_x + __bwu(_pid, 6), _panel_y + _header_h + __bhu(_pid, 3), _name_txt);

    var _row_y = _panel_y + _header_h + __bhu(_pid, 12);
    var _row_count = array_length(_rows);
    var _row_limit_y = _footer_y - __bhu(_pid, 8);
    var _row_gap = __bhu(_pid, 9);
    if (_row_count > 1){
        var _gap_cap = floor(max(0, _row_limit_y - _row_y) / (_row_count - 1));
        _row_gap = clamp(_gap_cap, __bhu(_pid, 6), __bhu(_pid, 9));
    }
    for (var _i = 0; _i < array_length(_rows); ++_i){
        if (_i > _current_row) continue;
        var _row = _rows[_i];
        if (!is_struct(_row)) continue;

        var _from = (variable_struct_exists(_row, "from") && is_real(variable_struct_get(_row, "from"))) ? real(variable_struct_get(_row, "from")) : 0;
        var _to = (variable_struct_exists(_row, "to") && is_real(variable_struct_get(_row, "to"))) ? real(variable_struct_get(_row, "to")) : _from;
        var _row_t = 1;
        if (_i == _current_row && _row_anim_start > 0) _row_t = clamp((current_time - _row_anim_start) / _count_dur, 0, 1);
        var _row_e = 1 - power(1 - _row_t, 2);
        var _value = round(lerp(_from, _to, _row_e));
        var _delta = floor(_to - _from);
        var _y = _row_y + (_i * _row_gap);

        draw_set_halign(fa_left);
        draw_set_color(_label_col);
        draw_text(_panel_x + __bwu(_pid, 6), _y, string(variable_struct_exists(_row, "label") ? variable_struct_get(_row, "label") : ""));

        draw_set_halign(fa_right);
        draw_set_color(_value_col);
        draw_text(_panel_x + _pw - __bwu(_pid, 6), _y, string(_value));

        if (_delta > 0 && _row_t > 0){
            draw_set_halign(fa_left);
            draw_set_color(_delta_col);
            draw_text(_panel_x + __bwu(_pid, 60), _y, "+" + string(_delta));
        }
    }

    var _prompt = "A NEXT";
    if (_close_ready) _prompt = "A CLOSE";
    else if (_current_row < 0) _prompt = "A START";
    draw_set_font(_small_font);
    draw_set_halign(fa_right);
    draw_set_color(_prompt_col);
    draw_text(_panel_x + _pw - __bwu(_pid, 6), _footer_y, _prompt);

    draw_set_color(c_white);
    draw_set_alpha(1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
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

function __battle_actor_display_name(_A){
    if (!is_struct(_A)) return "???";

    // Prefer nickname from the actual Pokemon struct first.
    // Battle actors often have a top-level name copied from species,
    // so checking _A.name first causes nicknames to be ignored.
    var _mon_ref = undefined;
    if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))) _mon_ref = variable_struct_get(_A, "mon");
    else if (variable_struct_exists(_A, "pokemon") && is_struct(variable_struct_get(_A, "pokemon"))) _mon_ref = variable_struct_get(_A, "pokemon");
    else if (variable_struct_exists(_A, "original_mon") && is_struct(variable_struct_get(_A, "original_mon"))) _mon_ref = variable_struct_get(_A, "original_mon");
    else if (variable_struct_exists(_A, "source_mon") && is_struct(variable_struct_get(_A, "source_mon"))) _mon_ref = variable_struct_get(_A, "source_mon");
    else if (variable_struct_exists(_A, "wild_mon") && is_struct(variable_struct_get(_A, "wild_mon"))) _mon_ref = variable_struct_get(_A, "wild_mon");
    else _mon_ref = _A;

    if (is_struct(_mon_ref)){
        if (variable_struct_exists(_mon_ref, "nickname")){
            var _nick = variable_struct_get(_mon_ref, "nickname");
            if (is_string(_nick) && string_length(string_trim(_nick)) > 0) return string_trim(_nick);
        }

        // Existing party helper is already nickname-aware; use it if available.
        if (!is_undefined(mon_display_name)){
            var _display = mon_display_name(_mon_ref);
            if (is_string(_display) && string_length(string_trim(_display)) > 0 && string(_display) != "???") return string_trim(_display);
        }

        if (variable_struct_exists(_mon_ref, "name")){
            var _mon_name = variable_struct_get(_mon_ref, "name");
            if (is_string(_mon_name) && string_length(string_trim(_mon_name)) > 0 && string(_mon_name) != "???") return string_trim(_mon_name);
        }
    }

    // Top-level actor nickname support, for actors that carry nickname directly.
    if (variable_struct_exists(_A, "nickname")){
        var _actor_nick = variable_struct_get(_A, "nickname");
        if (is_string(_actor_nick) && string_length(string_trim(_actor_nick)) > 0) return string_trim(_actor_nick);
    }

    // Then top-level actor name.
    if (variable_struct_exists(_A, "name")){
        var _name_raw = variable_struct_get(_A, "name");
        if (is_string(_name_raw) && string_length(string_trim(_name_raw)) > 0 && string(_name_raw) != "???") return string_trim(_name_raw);
    }

    // Species fallback.
    var _species_probe = undefined;
    if (variable_struct_exists(_A, "species") && is_real(variable_struct_get(_A, "species"))) _species_probe = variable_struct_get(_A, "species");
    else if (variable_struct_exists(_A, "species_id") && is_real(variable_struct_get(_A, "species_id"))) _species_probe = variable_struct_get(_A, "species_id");
    else if (is_struct(_mon_ref)){
        if (variable_struct_exists(_mon_ref, "species") && is_real(variable_struct_get(_mon_ref, "species"))) _species_probe = variable_struct_get(_mon_ref, "species");
        else if (variable_struct_exists(_mon_ref, "species_id") && is_real(variable_struct_get(_mon_ref, "species_id"))) _species_probe = variable_struct_get(_mon_ref, "species_id");
        else if (variable_struct_exists(_mon_ref, "id") && is_real(variable_struct_get(_mon_ref, "id"))) _species_probe = variable_struct_get(_mon_ref, "id");
        else if (variable_struct_exists(_mon_ref, "_id") && is_real(variable_struct_get(_mon_ref, "_id"))) _species_probe = variable_struct_get(_mon_ref, "_id");
    }

    if (!is_undefined(_species_probe) && is_real(_species_probe) && !is_undefined(scr_poke_name_by_id)){
        var _species_name = scr_poke_name_by_id(_species_probe);
        if (is_string(_species_name) && string_length(string_trim(_species_name)) > 0) return string_trim(_species_name);
    }

    return "???";
}

function __battle_actor_level_value(_A){
    if (is_struct(_A) && variable_struct_exists(_A, "level") && is_real(variable_struct_get(_A, "level"))) return floor(variable_struct_get(_A, "level"));
    if (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && variable_struct_exists(variable_struct_get(_A, "mon"), "level") && is_real(variable_struct_get(variable_struct_get(_A, "mon"), "level"))) return floor(variable_struct_get(variable_struct_get(_A, "mon"), "level"));
    return 1;
}

function __battle_actor_hp_summary(_A){
    var _cur = max(0, floor(__battle_hp_visual(_A)));
    var _max = max(1, floor(__battle_hp_max(_A)));
    var _pct = clamp(floor((_cur * 100) / max(1, _max)), 0, 100);
    return {
        cur: _cur,
        maxhp: _max,
        pct: _pct
    };
}

function __battle_enemy_box_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn,_A,_label,_compact){
    if (!is_struct(_A)) return;

    var _is_compact = (!is_undefined(_compact) && _compact == true);
    var _label_txt = (is_undefined(_label) ? "" : string(_label));
    var _name_y = _is_compact ? 2 : 6;
    var _bar_y = _is_compact ? 9 : 20;
    var _bar_h = _is_compact ? 3 : 6;
    var _status_y_off = _is_compact ? 19 : 28;
    var _status_scale = _is_compact ? 0.55 : 0.8;

    var _t  = __battle_ensure_slot(_pid).theme;
    __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn), _bw = __bwu(_pid,_rwIn);
    var _name_col = (_is_compact ? make_color_rgb(84, 116, 208) : make_color_rgb(74, 104, 196));
    var _level_col = make_color_rgb(224, 152, 66);
    var _restore_font = -1;
    if (variable_global_exists("FNT_POKEMON")) _restore_font = global.FNT_POKEMON;
    if (_is_compact && variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);

    var nameMax = _bw - __bwu(_pid, _is_compact ? 34 : 48);
    var _name_raw = __battle_actor_display_name(_A);
    if (string_length(_label_txt) > 0) _name_raw = _label_txt + " " + _name_raw;
    var nameTxt = __battle_text_fit_ellipsis(_pid, _name_raw, nameMax);
    draw_set_color(_name_col);
    draw_text(_bx+__bwu(_pid,6), _by+__bhu(_pid, _name_y), nameTxt);

    var _lvl_disp = __battle_actor_level_value(_A);
    draw_set_color(_level_col);
    draw_text(_bx+_bw-__bwu(_pid, _is_compact ? 23 : 29), _by+__bhu(_pid, _name_y), "Lv"+string(_lvl_disp));

    var _hp_info = __battle_actor_hp_summary(_A);
    var _vis_hp = _hp_info.cur;
    var _hp_max = _hp_info.maxhp;
    var _pct = max(0, min(1, _vis_hp / max(1, _hp_max)));
    var _barW = _bw-__bwu(_pid,20), _barX=_bx+__bwu(_pid,6), _barY=_by+__bhu(_pid, _bar_y), _bh=__bhu(_pid, _bar_h);
    draw_set_color(c_black); draw_rectangle(_barX-1,_barY-1,_barX+_barW+1,_barY+_bh+1,false);
    var _hpcol = _t.col_hp_green; if (_pct<0.5) _hpcol=_t.col_hp_yell; if (_pct<0.2) _hpcol=_t.col_hp_red;
    draw_set_color(_hpcol); draw_rectangle(_barX,_barY,_barX+_barW*_pct,_barY+_bh,false);
    var _statusX = _barX;
    var _statusY = _by + __bhu(_pid, _status_y_off);
    var _statusW = 0;
    if (!is_undefined(__party_draw_status_ui)){
        _statusW = __party_draw_status_ui(_statusX, _statusY, _status_scale, _A, _barW);
    }
    if (!is_undefined(__battle_draw_stage_counters)){
        var _stageX = _statusX + _statusW;
        if (_statusW > 0) _stageX += __bwu(_pid, _is_compact ? 1 : 2);
        var _stageMax = max(0, (_barX + _barW) - _stageX);
        __battle_draw_stage_counters(_stageX, _statusY, _A, _stageMax);
    }
    if (_restore_font != -1) draw_set_font(_restore_font);
}

function __battle_player_box_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn,_A,_label,_compact){
    if (!is_struct(_A)) return;

    var _is_compact = (!is_undefined(_compact) && _compact == true);
    var _label_txt = (is_undefined(_label) ? "" : string(_label));
    var _name_y = _is_compact ? 2 : 6;
    var _bar_y = _is_compact ? 9 : 20;
    var _bar_h = _is_compact ? 3 : 6;
    var _status_y_off = _is_compact ? 19 : 13;
    var _status_scale = _is_compact ? 0.55 : 0.8;
    var _t  = __battle_ensure_slot(_pid).theme;
    __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn), _bw = __bwu(_pid,_rwIn);
    var _name_col2 = (_is_compact ? make_color_rgb(46, 142, 110) : make_color_rgb(52, 126, 166));
    var _level_col2 = make_color_rgb(228, 142, 72);
    var _exp_col = make_color_rgb(94, 116, 214);
    var _restore_font2 = -1;
    if (variable_global_exists("FNT_POKEMON")) _restore_font2 = global.FNT_POKEMON;
    if (_is_compact && variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);

    var _name_raw = __battle_actor_display_name(_A);
    if (_name_raw == "???") _name_raw = "Pokemon";
    if (string_length(_label_txt) > 0) _name_raw = _label_txt + " " + _name_raw;
    var nameMax = _bw - __bwu(_pid, _is_compact ? 34 : 72);
    var nameTxt = __battle_text_fit_ellipsis(_pid, _name_raw, nameMax);
    draw_set_color(_name_col2);
    draw_text(_bx+__bwu(_pid,6), _by+__bhu(_pid, _name_y), nameTxt);

    var _lvl_disp2 = string(__battle_actor_level_value(_A));
    draw_set_color(_level_col2);
    draw_text(_bx+_bw-__bwu(_pid, _is_compact ? 23 : 32), _by+__bhu(_pid, _name_y), "Lv"+_lvl_disp2);

    var _hp_info2 = __battle_actor_hp_summary(_A);
    var _vis_hp2 = _hp_info2.cur;
    var _pct = max(0, min(1, _vis_hp2 / max(1, _hp_info2.maxhp)));
    var _barW = _bw-__bwu(_pid,20), _barX=_bx+__bwu(_pid,6), _barY=_by+__bhu(_pid, _bar_y), _bh=__bhu(_pid, _bar_h);
    draw_set_color(c_black); draw_rectangle(_barX-1,_barY-1,_barX+_barW+1,_barY+_bh+1,false);
    var _hpcol = _t.col_hp_green; if (_pct<0.5) _hpcol=_t.col_hp_yell; if (_pct<0.2) _hpcol=_t.col_hp_red;
    draw_set_color(_hpcol); draw_rectangle(_barX,_barY,_barX+_barW*_pct,_barY+_bh,false);

    // Top row: status sprites and temporary stage counters.
    var _topRowX = _bx + __bwu(_pid,8);
    var _topRowY = _by + __bhu(_pid, _status_y_off);
    var _topRowMax = _bw - __bwu(_pid,16);
    var _statusReserve = 0;
    if (!is_undefined(__party_draw_status_ui)) _statusReserve = __party_draw_status_ui(_topRowX, _topRowY, _status_scale, _A, _topRowMax);
    if (!is_undefined(__battle_draw_stage_counters)){
        var _stageTopX = _topRowX + _statusReserve;
        if (_statusReserve > 0) _stageTopX += __bwu(_pid, _is_compact ? 1 : 2);
        var _stageTopMax = max(0, (_topRowX + _topRowMax) - _stageTopX);
        __battle_draw_stage_counters(_stageTopX, _topRowY, _A, _stageTopMax);
    }

    if (_is_compact){
        if (_restore_font2 != -1) draw_set_font(_restore_font2);
        return;
    }

    var _show_exp = false;
    var _actor_idx_exp = (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) ? floor(variable_struct_get(_A, "actor_index")) : -1;
    var _owner_pid_exp = (is_struct(_A) && variable_struct_exists(_A, "owner_pid") && is_real(variable_struct_get(_A, "owner_pid"))) ? floor(variable_struct_get(_A, "owner_pid")) : undefined;
    if (is_real(_actor_idx_exp) && _actor_idx_exp >= 0 && __battle_actor_side(_actor_idx_exp) == 0){
        if (is_real(_owner_pid_exp)) _show_exp = (_owner_pid_exp == _pid);
        else _show_exp = true;
    }
    if (!_show_exp){
        if (_restore_font2 != -1) draw_set_font(_restore_font2);
        return;
    }

    var _expReserve = __bwu(_pid, 64);
    var _expBarY = _is_compact ? (_by + __bhu(_pid, 18)) : (_barY + _bh + __bhu(_pid,2));
    var _expBarH = __bhu(_pid, 3);
    var _expPct = 0;
    var _B = __battle_ensure_slot(_pid);
    // Note: command/menu suppression (dialog/cutscene/animations) should not
    // hide the player panel's EXP bar. Those guards belong in the command box
    // draw path, not here.
    if (is_struct(_B) && variable_struct_exists(_B, "_exp_anim")){
        var _ea = variable_struct_get(_B, "_exp_anim");
        if (is_struct(_ea) && variable_struct_exists(_ea, "cur")){
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
    var _expBarX = _is_compact ? (_bx + __bwu(_pid, 3)) : _barX;
    var _expBarW = _is_compact ? max(8, _bw - __bwu(_pid, 6)) : max(8, _barW - _expReserve - __bwu(_pid,8));
    // draw exp bar background and fill
    draw_set_color(c_black); draw_rectangle(_expBarX-1, _expBarY-1, _expBarX + _expBarW + 1, _expBarY + _expBarH + 1, false);
    draw_set_color(make_color_rgb(56,120,232)); // blue-ish exp color
    draw_rectangle(_expBarX, _expBarY, _expBarX + _expBarW * _expPct, _expBarY + _expBarH, false);

    if (_is_compact) return;

    // draw exp numeric to the right of the bar (clamped inside the panel)
    var _expText = "";
    var monRef2 = (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(_A.mon)) ? _A.mon : _A;
    if (is_struct(monRef2) && variable_struct_exists(monRef2, "exp") && variable_struct_exists(monRef2, "exp_next")){
        _expText = string(variable_struct_get(monRef2, "exp")) + "/" + string(variable_struct_get(monRef2, "exp_next"));
    }
    // Position EXP numeric in the same right-aligned column as HP numeric text
    var _expTextX = _bx + _bw - __bwu(_pid,8) - string_width(_expText);
    draw_set_color(_exp_col);
    draw_text(_expTextX, _expBarY, _expText);
    if (_restore_font2 != -1) draw_set_font(_restore_font2);
}

function __battle_ui_state_for_pid(_B, _pid){
    if (!is_struct(_B)) return undefined;
    if (!variable_struct_exists(_B, "sys_ui") || !is_struct(variable_struct_get(_B, "sys_ui"))){
        variable_struct_set(_B, "sys_ui", { menu:"root", selX:0, selY:0, msg_list:undefined });
    }

    var _versus = variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true;
    if (!_versus) return variable_struct_get(_B, "sys_ui");

    if (!variable_struct_exists(_B, "_versus_ui") || !is_array(variable_struct_get(_B, "_versus_ui")) || array_length(variable_struct_get(_B, "_versus_ui")) < 2){
        variable_struct_set(_B, "_versus_ui", [
            { menu:"root", selX:0, selY:0, command_actor_index:0, command_pending_action:undefined, target_pick_targets:undefined, target_pick_index:0 },
            { menu:"root", selX:0, selY:0, command_actor_index:0, command_pending_action:undefined, target_pick_targets:undefined, target_pick_index:0 }
        ]);
    }

    var _ui_list = variable_struct_get(_B, "_versus_ui");
    var _ui_index = clamp(floor(_pid), 0, 1);
    var _ui = _ui_list[_ui_index];
    if (!is_struct(_ui)) _ui = { menu:"root", selX:0, selY:0, command_actor_index:0, command_pending_action:undefined, target_pick_targets:undefined, target_pick_index:0 };
    if (!variable_struct_exists(_ui, "menu") || string_length(string(variable_struct_get(_ui, "menu"))) <= 0) variable_struct_set(_ui, "menu", "root");
    if (!variable_struct_exists(_ui, "selX") || !is_real(variable_struct_get(_ui, "selX"))) variable_struct_set(_ui, "selX", 0);
    if (!variable_struct_exists(_ui, "selY") || !is_real(variable_struct_get(_ui, "selY"))) variable_struct_set(_ui, "selY", 0);
    if (!variable_struct_exists(_ui, "command_actor_index") || !is_real(variable_struct_get(_ui, "command_actor_index"))) variable_struct_set(_ui, "command_actor_index", 0);
    if (!variable_struct_exists(_ui, "target_pick_index") || !is_real(variable_struct_get(_ui, "target_pick_index"))) variable_struct_set(_ui, "target_pick_index", 0);
    _ui_list[_ui_index] = _ui;
    variable_struct_set(_B, "_versus_ui", _ui_list);
    return _ui;
}

function __battle_cmd_box_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn,_selX,_selY){
    var _B = __battle_ensure_slot(_pid);
    var _UI = __battle_ui_state_for_pid(_B, _pid);
    var _t  = _B.theme;
    var _versus = is_struct(_B) && variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true;
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn), _bw = __bwu(_pid,_rwIn), _bh = __bhu(_pid,_rhIn);

    // Dialog rendering (clamped)
    var _dialog_pid = _pid;
    var _dialog_pid_open = -1;
    var _dialog_open = (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_dialog_pid));
    if (_dialog_open) _dialog_pid_open = _dialog_pid;
    var _any_dialog_open = _dialog_open;
    var _has_own_dialog_queue = false;
    var _has_own_pending_status = false;
    try {
        if (variable_global_exists("DIALOG2P_Q") && is_array(global.DIALOG2P_Q) && array_length(global.DIALOG2P_Q) > _pid){
            var _own_q = global.DIALOG2P_Q[_pid];
            _has_own_dialog_queue = (is_array(_own_q) && array_length(_own_q) > 0);
        }
    } catch (e_dialog_q) { _has_own_dialog_queue = false; }
    try {
        if (variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs"))){
            var _own_pending = variable_struct_get(_B, "_pending_status_msgs");
            for (var _op_i = 0; _op_i < array_length(_own_pending); ++_op_i){
                var _op_msg = _own_pending[_op_i];
                if (!is_undefined(__battle_pending_msg_pid) && __battle_pending_msg_pid(_op_msg, -1) == _pid){
                    _has_own_pending_status = true;
                    break;
                }
            }
        }
    } catch (e_dialog_pending) { _has_own_pending_status = false; }
    if (is_struct(_B) && variable_struct_exists(_B, "player_pids") && is_array(variable_struct_get(_B, "player_pids"))){
        var _dialog_pids = variable_struct_get(_B, "player_pids");
        for (var _dpi = 0; _dpi < array_length(_dialog_pids); ++_dpi){
            var _dpid = _dialog_pids[_dpi];
            if (!is_real(_dpid)) continue;
            _dpid = floor(_dpid);
            if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_dpid)){
                _any_dialog_open = true;
                if (_dialog_pid_open < 0) _dialog_pid_open = _dpid;
            }
        }
    }
    if (!_dialog_open && _dialog_pid_open >= 0 && !_has_own_dialog_queue && !_has_own_pending_status) _dialog_pid = _dialog_pid_open;
    _dialog_open = (_dialog_pid >= 0 && !is_undefined(dialog2p_is_open) && dialog2p_is_open(_dialog_pid));
    if (_dialog_open){
        __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
        var d = (!is_undefined(dialog2p_ensure_pid)) ? dialog2p_ensure_pid(_dialog_pid) : global.DIALOG2P[_dialog_pid];
        if (is_struct(d)){
            var _page_idx = variable_struct_exists(d, "page_idx") ? variable_struct_get(d, "page_idx") : 0;
            var _all_lines = (variable_struct_exists(d, "all_lines") && is_array(variable_struct_get(d, "all_lines"))) ? variable_struct_get(d, "all_lines") : [];
            var _char_idx = variable_struct_exists(d, "char_idx") ? variable_struct_get(d, "char_idx") : 0;
            var i0 = _page_idx*2, i1 = i0+1;
            var l0 = (i0 < array_length(_all_lines)) ? _all_lines[i0] : "";
            var l1 = (i1 < array_length(_all_lines)) ? _all_lines[i1] : "";
            var page_str = l0 + "\n" + l1;
            var vis_str = string_copy(page_str, 1, _char_idx);

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
            var _dialog_col = (variable_struct_exists(_t, "col_dialog_text") ? variable_struct_get(_t, "col_dialog_text") : _t.col_text);
            __dlg_draw_lines_spritefont(
                vis0,
                vis1,
                _bx + __bwu(_pid,8),
                _by + __bhu(_pid,6),
                _dialog_col
            );
        }
        return;
    }
    if (_any_dialog_open){
        __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
        return;
    }

    if (variable_struct_exists(_B, "_pending_close") && variable_struct_get(_B, "_pending_close")) return;
    __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
    if (is_struct(_B) && variable_struct_exists(_B, "_trainer_switch_prompt")){
        var _prompt = variable_struct_get(_B, "_trainer_switch_prompt");
        if (is_struct(_prompt) && variable_struct_exists(_prompt, "active") && _prompt.active){
            var _phase_prompt = (variable_struct_exists(_prompt, "phase") ? string(variable_struct_get(_prompt, "phase")) : "prompt");
            if (_phase_prompt == "prompt"){
                var _font_main = variable_global_exists("FNT_POKEMON") ? global.FNT_POKEMON : -1;
                var _font_small = variable_global_exists("FNT_POKEMON_SMALL") ? global.FNT_POKEMON_SMALL : _font_main;
                if (_font_main != -1) draw_set_font(_font_main);

                var _trainer_name = (variable_struct_exists(_prompt, "trainer_name") ? string(variable_struct_get(_prompt, "trainer_name")) : "Trainer");
                var _mon_name = (variable_struct_exists(_prompt, "enemy_next_name") ? string(variable_struct_get(_prompt, "enemy_next_name")) : "Pokemon");
                var _prompt_source = (variable_struct_exists(_prompt, "source") ? string(variable_struct_get(_prompt, "source")) : "trainer");
                var _msg0 = "";
                var _msg1 = "";
                if (_prompt_source == "two_player_replace"){
                    _msg0 = __battle_text_fit_ellipsis(_pid, _trainer_name + " is using", _bw - __bwu(_pid, 18));
                    _msg1 = __battle_text_fit_ellipsis(_pid, _mon_name + ". Switch Pokemon?", _bw - __bwu(_pid, 18));
                } else {
                    _msg0 = __battle_text_fit_ellipsis(_pid, _trainer_name + " is about to use", _bw - __bwu(_pid, 18));
                    _msg1 = __battle_text_fit_ellipsis(_pid, _mon_name + ". Change Pokemon?", _bw - __bwu(_pid, 18));
                }
                var _dialog_col2 = (variable_struct_exists(_t, "col_dialog_text") ? variable_struct_get(_t, "col_dialog_text") : _t.col_text);
                draw_set_color(_dialog_col2);
                draw_set_halign(fa_left);
                draw_set_valign(fa_top);
                draw_text(_bx + __bwu(_pid, 8), _by + __bhu(_pid, 6), _msg0);
                draw_text(_bx + __bwu(_pid, 8), _by + __bhu(_pid, 18), _msg1);

                var _menu_w = __bwu(_pid, 52);
                var _menu_h = __bhu(_pid, 34);
                var _menu_x = _bx + _bw - _menu_w - __bwu(_pid, 10);
                var _menu_y = _by - _menu_h - __bhu(_pid, 4);
                draw_set_alpha(0.2);
                draw_set_color(c_black);
                draw_rectangle(_menu_x + __bwu(_pid, 2), _menu_y + __bhu(_pid, 2), _menu_x + _menu_w + __bwu(_pid, 2), _menu_y + _menu_h + __bhu(_pid, 2), false);
                draw_set_alpha(1);
                draw_set_color(_t.col_outline);
                draw_rectangle(_menu_x, _menu_y, _menu_x + _menu_w, _menu_y + _menu_h, false);
                draw_set_color(_t.col_panel);
                draw_rectangle(_menu_x + 1, _menu_y + 1, _menu_x + _menu_w - 1, _menu_y + _menu_h - 1, false);

                if (_font_small != -1) draw_set_font(_font_small);
                var _sel_prompt_ui = (variable_struct_exists(_prompt, "sel") && is_real(variable_struct_get(_prompt, "sel"))) ? floor(variable_struct_get(_prompt, "sel")) : 1;
                var _opts = ["YES", "NO"];
                var _row_box_h = __bhu(_pid, 11);
                var _row_gap = __bhu(_pid, 3);
                var _row_x1 = _menu_x + __bwu(_pid, 4);
                var _row_x2 = _menu_x + _menu_w - __bwu(_pid, 4);
                var _row_y0 = _menu_y + __bhu(_pid, 4);
                draw_set_halign(fa_center);
                    draw_set_valign(fa_top);
                for (var _pi = 0; _pi < 2; ++_pi){
                    var _row_y = _row_y0 + (_pi * (_row_box_h + _row_gap));
                    var _hilite = (_pi == _sel_prompt_ui);
                    if (_hilite){
                        draw_set_color(_t.col_ui_highlight);
                        draw_rectangle(_row_x1, _row_y, _row_x2, _row_y + _row_box_h, false);
                    }
                    draw_set_color(_hilite ? _t.col_panel : ((variable_struct_exists(_t, "col_ui_text") ? variable_struct_get(_t, "col_ui_text") : _t.col_text)));
                        var _label_y = _row_y + max(0, floor((_row_box_h - string_height(_opts[_pi])) * 0.5)) + __bhu(_pid, 6);
                        draw_text((_row_x1 + _row_x2) * 0.5, _label_y, _opts[_pi]);
                }
                draw_set_halign(fa_left);
                draw_set_valign(fa_top);
                return;
            }
            return;
        }
    }

    // Do not show the command/root menus during intro phases or while the
    // intro has not been marked completed. This prevents the brief flash of
    // the command UI between the "Go" dialog and the Pokémon cry/intro.
    try {
        if (variable_struct_exists(_B, "_intro_completed") && !variable_struct_get(_B, "_intro_completed")) return;
        var _ph = (variable_struct_exists(_B, "phase") ? string(variable_struct_get(_B, "phase")) : "");
        if (_ph == "transition_in" || _ph == "intro_enemy" || _ph == "intro_call" || _ph == "intro_player") return;
        if (_ph == "turn") return;
        // If update code requested to wait until dialog fully closes before showing the
        // UI, hide the command box here as well to cover the exact frame of closure.
        if (variable_struct_exists(_B, "_suppress_wait_for_dialog_close") && variable_struct_get(_B, "_suppress_wait_for_dialog_close")) return;
        if (variable_struct_exists(_B, "_action_active") && variable_struct_get(_B, "_action_active")) return;
    } catch (e_introguard) {}
    try { if (!is_undefined(__battle_has_forced_switch_lock) && __battle_has_forced_switch_lock(_pid)) return; } catch (e_forced_ui_guard) {}
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

    if (variable_struct_exists(_B, "_levelup_panel")){
        var _lp_tmp = variable_struct_get(_B, "_levelup_panel");
        if (is_struct(_lp_tmp) && variable_struct_exists(_lp_tmp, "active") && _lp_tmp.active) return;
    }

    if (_versus && string(variable_struct_get(_B, "phase")) == "command"){
        var _vs_current_owner = -1;
        if (variable_struct_exists(_UI, "command_actor_index") && is_real(variable_struct_get(_UI, "command_actor_index")) && !is_undefined(__battle_actor_control_pid)){
            _vs_current_owner = __battle_actor_control_pid(_pid, floor(variable_struct_get(_UI, "command_actor_index")));
        }
        var _vs_actors_for_pid = (!is_undefined(__battle_command_actor_indexes)) ? __battle_command_actor_indexes(_pid) : [];
        var _vs_has_pending_command = false;
        if (is_array(_vs_actors_for_pid)){
            for (var _vs_wait_i = 0; _vs_wait_i < array_length(_vs_actors_for_pid); ++_vs_wait_i){
                var _vs_queued_action = (!is_undefined(__battle_find_player_turn_action)) ? __battle_find_player_turn_action(_B, _vs_actors_for_pid[_vs_wait_i]) : undefined;
                if (!is_struct(_vs_queued_action)){
                    _vs_has_pending_command = true;
                    break;
                }
            }
        }
        if (!_vs_has_pending_command || (is_real(_vs_current_owner) && _vs_current_owner >= 0 && _vs_current_owner != _pid)) return;
    }

    if (!_versus && variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double"){
        var _current_actor_owner = -1;
        if (variable_struct_exists(_B, "_command_actor_index") && is_real(variable_struct_get(_B, "_command_actor_index")) && !is_undefined(__battle_actor_control_pid)){
            _current_actor_owner = __battle_actor_control_pid(_pid, floor(variable_struct_get(_B, "_command_actor_index")));
        }
        var _actors_for_pid = (!is_undefined(__battle_command_actor_indexes)) ? __battle_command_actor_indexes(_pid) : [];
        var _has_pending_command = false;
        if (is_array(_actors_for_pid)){
            for (var _wait_i = 0; _wait_i < array_length(_actors_for_pid); ++_wait_i){
                var _queued_wait_action = (!is_undefined(__battle_find_player_turn_action)) ? __battle_find_player_turn_action(_B, _actors_for_pid[_wait_i]) : undefined;
                if (!is_struct(_queued_wait_action)){
                    _has_pending_command = true;
                    break;
                }
            }
        }
        if (!_has_pending_command || (is_real(_current_actor_owner) && _current_actor_owner >= 0 && _current_actor_owner != _pid)){
            draw_set_color(variable_struct_exists(_t, "col_ui_text") ? variable_struct_get(_t, "col_ui_text") : _t.col_text);
            if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);
            var _wait_txt = (!_has_pending_command) ? ((variable_struct_exists(_B, "coop_enabled") && variable_struct_get(_B, "coop_enabled") == true) ? "Waiting for partner..." : "Commands ready...") : "Partner choosing...";
            draw_text(_bx + __bwu(_pid, 8), _by + __bhu(_pid, 8), __battle_text_fit_ellipsis(_pid, _wait_txt, _bw - __bwu(_pid, 16)));
            if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
            return;
        }
    }

    if (string(variable_struct_get(_UI, "menu")) == "target"){
        var _restore_font_target = -1;
        if (variable_global_exists("FNT_POKEMON")) _restore_font_target = global.FNT_POKEMON;
        if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);
        var _target_msg = "Choose a target";
        var _actor_idx = (variable_struct_exists(_UI, "command_actor_index") && is_real(variable_struct_get(_UI, "command_actor_index"))) ? floor(variable_struct_get(_UI, "command_actor_index")) : ((variable_struct_exists(_B, "_command_actor_index") && is_real(variable_struct_get(_B, "_command_actor_index"))) ? floor(variable_struct_get(_B, "_command_actor_index")) : 0);
        if (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double") _target_msg = "P" + string(__battle_actor_slot(_actor_idx) + 1) + ": choose a target";
        draw_set_color(variable_struct_exists(_t, "col_ui_text") ? variable_struct_get(_t, "col_ui_text") : _t.col_text);
        draw_text(_bx + __bwu(_pid, 8), _by + __bhu(_pid, 8), _target_msg);
        draw_text(_bx + __bwu(_pid, 8), _by + __bhu(_pid, 16), "Use arrows, A confirm, B back");
        if (_restore_font_target != -1) draw_set_font(_restore_font_target);
        return;
    }

    // FIGHT submenu
    if (string(variable_struct_get(_UI, "menu")) == "fight"){
        var restoreFont = -1;
        if (variable_global_exists("FNT_POKEMON")) restoreFont = global.FNT_POKEMON;
        if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);

        var _command_actor_idx = (variable_struct_exists(_UI, "command_actor_index") && is_real(variable_struct_get(_UI, "command_actor_index"))) ? floor(variable_struct_get(_UI, "command_actor_index")) : ((variable_struct_exists(_B, "_command_actor_index") && is_real(variable_struct_get(_B, "_command_actor_index"))) ? floor(variable_struct_get(_B, "_command_actor_index")) : 0);
        var A = _B.actor[_command_actor_idx];
        if (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double"){
            var _actor_label = "P" + string(__battle_actor_slot(_command_actor_idx) + 1);
            draw_set_color(variable_struct_exists(_t, "col_ui_text") ? variable_struct_get(_t, "col_ui_text") : _t.col_text);
            draw_text(_bx + _bw - __bwu(_pid, 24), _by + __bhu(_pid, 2), _actor_label);
        }
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

            var _fight_col = (hilite && variable_struct_exists(_t, "col_ui_highlight_text")) ? variable_struct_get(_t, "col_ui_highlight_text") : ((variable_struct_exists(_t, "col_ui_text") ? variable_struct_get(_t, "col_ui_text") : _t.col_text));
            draw_set_color(_fight_col);
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

    if (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double"){
        var _root_actor_idx = (variable_struct_exists(_B, "_command_actor_index") && is_real(variable_struct_get(_B, "_command_actor_index"))) ? floor(variable_struct_get(_B, "_command_actor_index")) : 0;
        var _root_actor_label = "P" + string(__battle_actor_slot(_root_actor_idx) + 1);
        draw_set_color(variable_struct_exists(_t, "col_ui_text") ? variable_struct_get(_t, "col_ui_text") : _t.col_text);
        draw_text(_bx + _bw - __bwu(_pid, 24), _by + __bhu(_pid, 2), _root_actor_label);
    }

    var rootCellW = (_bw * 0.5) - __bwu(_pid,16);
    for (var j=0; j<4; ++j){
        var tx2 = _bx + __bwu(_pid,12) + ((j % 2) * (_bw * 0.5));
        var ty2 = _by + __bhu(_pid,6)  + (floor(j / 2) * (_bh * 0.5));
        var hilite2 = (_selX == (j % 2)) && (_selY == floor(j / 2));
        var lbl = __battle_text_fit_ellipsis(_pid, labels[j], rootCellW);
        var _root_col = (hilite2 && variable_struct_exists(_t, "col_ui_highlight_text")) ? variable_struct_get(_t, "col_ui_highlight_text") : ((variable_struct_exists(_t, "col_ui_text") ? variable_struct_get(_t, "col_ui_text") : _t.col_text));
        draw_set_color(_root_col);
        draw_text(tx2, ty2, lbl);
    }
    if (restoreFont2 != -1) draw_set_font(restoreFont2);
}

// ===== GUI Letterbox rect =====
function __battle_view_rect_for_pid(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    var _logic_w = 240;
    var _logic_h = 160;
    var _aspect  = _logic_w / _logic_h; // 1.5
    var _guiAsp  = _gw / max(1,_gh);

    var _rw, _rh, _rx, _ry;
    if (_guiAsp > _aspect) {
        _rh = _gh;
        _rw = floor(_rh * _aspect);
        _rx = (_gw - _rw) div 2;
        _ry = 0;
    } else {
        _rw = _gw;
        _rh = floor(_rw / _aspect);
        _rx = 0;
        _ry = (_gh - _rh) div 2;
    }
    return [_rx, _ry, _rw, _rh];
}
