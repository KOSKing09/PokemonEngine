// [PC System]: pc_system — Build v1.4.0 — Updated 2026-05-13
// Multiplayer-ready PC System.
// - Per-player PC state: global.SYS_PC[pid]
// - Split-screen safe draw calls: pc_draw_gui_rect(pid, rx, ry, rw, rh)
// - Uses existing controls system.
// - Uses existing party model via party_ensure(pid).
// - Draw-only Emerald-style generated UI.
// - 14 boxes x 30 slots per player by default.

globalvar SYS_PC;

function pc_init(){
    pc__ensure_all_states();
    return global.SYS_PC;
}

function pc_is_open(_pid){
    pc__ensure_all_states();

    if (argument_count > 0){
        var _p = pc__pid(_pid);
        if (_p < 0 || _p >= array_length(global.SYS_PC)) return false;
        var _st = global.SYS_PC[_p];
        return (is_struct(_st) && _st.sys_open == true);
    }

    for (var _i = 0; _i < array_length(global.SYS_PC); ++_i){
        var _state = global.SYS_PC[_i];
        if (is_struct(_state) && _state.sys_open == true) return true;
    }
    return false;
}

function pc_open(_pid){
    var _p = pc__pid(_pid);
    var _pc = pc__ensure_state(_p);
    if (_pc.sys_held_mon != undefined && !pc__return_held_to_origin(_p) && !pc__force_store_held_mon(_p)){
        _pc.sys_open = true;
        return false;
    }

    _pc.sys_open = true;
    _pc.sys_mode = "storage";
    _pc.sys_pid = _p;
    _pc.sys_title_text = "PC Storage";
    _pc.sys_cursor_area = "box";
    _pc.sys_cursor_index = 0;
    _pc.sys_status_text = "Move Pokemon";
    _pc.sys_input_cooldown = 6;
    _pc.sys_held_mon = undefined;
    _pc.sys_held_from_area = "";
    _pc.sys_held_from_box = -1;
    _pc.sys_held_from_index = -1;

    pc__ensure_party_capacity(_p);
    pc__dedupe_exact_mon_references(_p);
    if (!is_undefined(sfx_play_safe)) sfx_play_safe(snd_LogOn, 1);
    return true;
}

function pc_open_breeding(_pid){
    var _p = pc__pid(_pid);
    var _pc = pc__ensure_state(_p);
    if (_pc.sys_held_mon != undefined && !pc__return_held_to_origin(_p) && !pc__force_store_held_mon(_p)){
        _pc.sys_open = true;
        return false;
    }

    _pc.sys_open = true;
    _pc.sys_mode = "breeding";
    _pc.sys_pid = _p;
    _pc.sys_cursor_area = "box";
    _pc.sys_cursor_index = 0;
    _pc.sys_status_text = "Place two compatible parents.";
    _pc.sys_input_cooldown = 6;
    _pc.sys_held_mon = undefined;
    _pc.sys_held_from_area = "";
    _pc.sys_held_from_box = -1;
    _pc.sys_held_from_index = -1;
    _pc.sys_title_text = "Pokemon Nursery";

    pc__ensure_breeding_state(_p);
    pc__dedupe_exact_mon_references(_p);
    pc__breeding_refresh_all_pairs(_p);
    if (!is_undefined(sfx_play_safe)) sfx_play_safe(snd_LogOn, 1);
    return true;
}

function pc_open_eggs(_pid){
    var _p = pc__pid(_pid);
    var _pc = pc__ensure_state(_p);
    if (_pc.sys_held_mon != undefined && !pc__return_held_to_origin(_p) && !pc__force_store_held_mon(_p)){
        _pc.sys_open = true;
        return false;
    }

    _pc.sys_open = true;
    _pc.sys_mode = "eggs";
    _pc.sys_pid = _p;
    _pc.sys_cursor_area = "box";
    _pc.sys_cursor_index = 0;
    _pc.sys_status_text = "Egg Box";
    _pc.sys_input_cooldown = 6;
    _pc.sys_held_mon = undefined;
    _pc.sys_held_from_area = "";
    _pc.sys_held_from_box = -1;
    _pc.sys_held_from_index = -1;
    _pc.sys_title_text = "Egg Storage";

    pc__ensure_breeding_state(_p);
    if (!is_undefined(sfx_play_safe)) sfx_play_safe(snd_LogOn, 1);
    return true;
}

function pc_close(_pid){
    pc__ensure_all_states();

    if (argument_count > 0){
        var _p = pc__pid(_pid);
        var _pc = pc__ensure_state(_p);
        if (_pc.sys_held_mon != undefined && !pc__return_held_to_origin(_p) && !pc__force_store_held_mon(_p)){
            _pc.sys_open = true;
            return false;
        }
        _pc.sys_open = false;
        _pc.sys_status_text = "Closed";
        if (!is_undefined(sfx_play_safe)) sfx_play_safe(snd_TurnOff, 1);
        return true;
    }

    for (var _i = 0; _i < array_length(global.SYS_PC); ++_i){
        var _state = global.SYS_PC[_i];
        if (is_struct(_state)){
            if (_state.sys_held_mon != undefined && !pc__return_held_to_origin(_i) && !pc__force_store_held_mon(_i)){
                _state.sys_open = true;
                continue;
            }
            _state.sys_open = false;
            _state.sys_status_text = "Closed";
        }
    }
    if (!is_undefined(sfx_play_safe)) sfx_play_safe(snd_TurnOff, 1);
    return true;
}

function pc_toggle(_pid){
    var _p = pc__pid(_pid);
    if (pc_is_open(_p)) return pc_close(_p);
    return pc_open(_p);
}

function pc_update(){
    pc__ensure_all_states();

    for (var _pid = 0; _pid < array_length(global.SYS_PC); ++_pid){
        var _pc = global.SYS_PC[_pid];
        if (!is_struct(_pc) || _pc.sys_open != true) continue;

        if (!variable_struct_exists(_pc, "sys_input_cooldown")) _pc.sys_input_cooldown = 0;
        if (_pc.sys_input_cooldown > 0){
            _pc.sys_input_cooldown -= 1;
            continue;
        }

        pc__ensure_party_capacity(_pid);

        if (pc__is_breeding_mode(_pid) && pc__ctrl_pressed(_pid, "Inventory")){
            pc__breeding_toggle_source(_pid);
            continue;
        }

        var _theme_mod = pc__ctrl_down(_pid, "Inventory");

        if (pc__ctrl_pressed(_pid, "PageUp") && !pc__is_egg_mode(_pid)){
            if (_theme_mod) pc__cycle_theme(_pid, -1);
            else pc__cycle_box(_pid, -1);
        }

        if (pc__ctrl_pressed(_pid, "PageDown") && !pc__is_egg_mode(_pid)){
            if (_theme_mod) pc__cycle_theme(_pid, 1);
            else pc__cycle_box(_pid, 1);
        }

        if (pc__ctrl_repeat(_pid, "MoveLeft", 10, 4))  pc__move_cursor(_pid, -1, 0);
        if (pc__ctrl_repeat(_pid, "MoveRight", 10, 4)) pc__move_cursor(_pid, 1, 0);
        if (pc__ctrl_repeat(_pid, "MoveUp", 10, 4))    pc__move_cursor(_pid, 0, -1);
        if (pc__ctrl_repeat(_pid, "MoveDown", 10, 4))  pc__move_cursor(_pid, 0, 1);

        if (pc__ctrl_pressed(_pid, "Interact")) pc__pickup_or_place(_pid);

        if (pc__ctrl_pressed(_pid, "Back") || pc__ctrl_pressed(_pid, "Run")){
            if (_pc.sys_held_mon != undefined){
                pc__return_held_to_origin(_pid);
                _pc.sys_status_text = "Returned Pokemon";
            } else {
                pc_close(_pid);
            }
        }
    }
}

function pc_draw_gui(_pid){
    var _p = (argument_count > 0) ? pc__pid(_pid) : 0;
    if (!pc_is_open(_p)) return;
    pc_draw_gui_rect(_p, 0, 0, display_get_gui_width(), display_get_gui_height());
}

function pc_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    var _p = pc__pid(_pid);
    var _pc = pc__ensure_state(_p);
    if (_pc.sys_open != true) return;

    var _S  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _OX = _rx + (_rw - 240 * _S) div 2;
    var _OY = _ry + (_rh - 160 * _S) div 2;

    var _theme = pc__get_active_theme(_p);
    var _box = pc__get_active_box(_p);

    var _header_h = 16;
    var _footer_h = 14;
    var _party_x = 6;
    var _party_y = 22;
    var _party_w = 52;
    var _party_h = 118;
    var _box_x = 62;
    var _box_y = 22;
    var _box_w = 172;
    var _box_h = 118;

    draw_rectangle_colour(_OX, _OY, _OX + 240 * _S, _OY + 160 * _S, _theme.sys_bg0, _theme.sys_bg1, _theme.sys_bg1, _theme.sys_bg0, false);
    pc__draw_theme_pattern_scaled(_theme, _OX, _OY, _S);

    pc__draw_round_panel_scaled(_OX, _OY, _S, 4, 3, 232, _header_h, _theme.sys_panel_dark, _theme.sys_panel_light);
    draw_set_colour(_theme.sys_text_dark);
    draw_text(_OX + 10 * _S, _OY + 12 * _S, "P" + string(_p + 1) + " " + _pc.sys_title_text);
    draw_set_halign(fa_right);
    draw_text(_OX + 230 * _S, _OY + 12 * _S, _box.sys_name);
    draw_set_halign(fa_left);

    if (pc__is_breeding_mode(_p)) pc__draw_breeding_panel_scaled(_p, _OX, _OY, _S, _party_x, _party_y, _party_w, _party_h, _theme);
    else if (pc__is_egg_mode(_p)) pc__draw_egg_summary_panel_scaled(_p, _OX, _OY, _S, _party_x, _party_y, _party_w, _party_h, _theme);
    else pc__draw_party_panel_scaled(_p, _OX, _OY, _S, _party_x, _party_y, _party_w, _party_h, _theme);
    pc__draw_box_panel_scaled(_p, _OX, _OY, _S, _box_x, _box_y, _box_w, _box_h, _theme);

    pc__draw_round_panel_scaled(_OX, _OY, _S, 4, 144, 232, _footer_h, _theme.sys_panel_dark, _theme.sys_panel_light);
    draw_set_colour(_theme.sys_text_dark);
    draw_text(_OX + 10 * _S, _OY + 154 * _S, pc__fit_text_to_width(_pc.sys_status_text, 110 * _S));

    var _held_label = "None";
    if (_pc.sys_held_mon != undefined) _held_label = pc__mon_display_name(_pc.sys_held_mon);
    draw_set_halign(fa_right);
    draw_text(_OX + 230 * _S, _OY + 154 * _S, "Hold: " + pc__fit_text_to_width(_held_label, 68 * _S));
    draw_set_halign(fa_left);
}

function pc_store_mon(_pid, _mon){
    var _p = pc__pid(_pid);
    pc__ensure_state(_p);
    if (_mon == undefined) return false;

    _mon = pc__normalize_mon(_mon);

    var _party = pc__get_party_array(_p);
    var _cap = 6;
    if (!is_undefined(party_model_get_party_capacity)) _cap = max(1, party_model_get_party_capacity());

    for (var _i = 0; _i < _cap; ++_i){
        var _slot_mon = undefined;
        if (_i < array_length(_party)) _slot_mon = _party[_i];

        if (_slot_mon == undefined){
            return pc__write_party_slot(_p, _i, _mon);
        }
    }

    var _info = pc_store_mon_to_box_info(_p, _mon);
    return (is_struct(_info) && variable_struct_exists(_info, "ok") && _info.ok == true);
}

function pc_store_mon_to_box(_pid, _mon){
    var _info = pc_store_mon_to_box_info(_pid, _mon);
    return (is_struct(_info) && variable_struct_exists(_info, "ok") && _info.ok == true);
}

function pc__ensure_all_states(){
    var _count = pc__player_count();
    if (!variable_global_exists("SYS_PC") || !is_array(global.SYS_PC)) global.SYS_PC = [];
    if (array_length(global.SYS_PC) < _count) array_resize(global.SYS_PC, _count);
    for (var _i = 0; _i < _count; ++_i) pc__ensure_state(_i);
}

function pc__ensure_state(_pid){
    var _p = pc__pid(_pid);
    if (!variable_global_exists("SYS_PC") || !is_array(global.SYS_PC)) global.SYS_PC = [];
    if (array_length(global.SYS_PC) <= _p) array_resize(global.SYS_PC, _p + 1);

    if (!is_struct(global.SYS_PC[_p])){
        global.SYS_PC[_p] = pc__make_state(_p);
    }

    var _pc = global.SYS_PC[_p];
    if (!variable_struct_exists(_pc, "sys_boxes") || !is_array(_pc.sys_boxes)) _pc.sys_boxes = pc__make_boxes();
    if (!variable_struct_exists(_pc, "sys_theme_defs") || !is_array(_pc.sys_theme_defs)) _pc.sys_theme_defs = pc__build_theme_defs();
    if (!variable_struct_exists(_pc, "sys_open")) _pc.sys_open = false;
    if (!variable_struct_exists(_pc, "sys_pid")) _pc.sys_pid = _p;
    if (!variable_struct_exists(_pc, "sys_input_cooldown")) _pc.sys_input_cooldown = 0;
    if (!variable_struct_exists(_pc, "sys_mode")) _pc.sys_mode = "storage";
    if (!variable_struct_exists(_pc, "sys_breed_slots") || !is_array(_pc.sys_breed_slots)) _pc.sys_breed_slots = [];
    if (array_length(_pc.sys_breed_slots) < 12) array_resize(_pc.sys_breed_slots, 12);
    if (!variable_struct_exists(_pc, "sys_breed_wait_battles") || !is_array(_pc.sys_breed_wait_battles)) _pc.sys_breed_wait_battles = [];
    if (array_length(_pc.sys_breed_wait_battles) < 6) array_resize(_pc.sys_breed_wait_battles, 6);
    if (!variable_struct_exists(_pc, "sys_breed_heart") || !is_array(_pc.sys_breed_heart)) _pc.sys_breed_heart = [];
    if (array_length(_pc.sys_breed_heart) < 6) array_resize(_pc.sys_breed_heart, 6);
    if (!variable_struct_exists(_pc, "sys_breed_pair_key") || !is_array(_pc.sys_breed_pair_key)) _pc.sys_breed_pair_key = [];
    if (array_length(_pc.sys_breed_pair_key) < 6) array_resize(_pc.sys_breed_pair_key, 6);
    if (!variable_struct_exists(_pc, "sys_breed_source")) _pc.sys_breed_source = "box";
    if (!variable_struct_exists(_pc, "sys_egg_box") || !is_array(_pc.sys_egg_box)) _pc.sys_egg_box = [];
    if (!variable_struct_exists(_pc, "sys_imported_legacy")){
        _pc.sys_imported_legacy = true;
        if (!is_undefined(pc_import_legacy_storage)) pc_import_legacy_storage(_p);
    }
    return _pc;
}

function pc__make_state(_pid){
    return {
        sys_open: false,
        sys_pid: _pid,
        sys_boxes: pc__make_boxes(),
        sys_box_cols: 6,
        sys_box_rows: 5,
        sys_box_size: 30,
        sys_active_box: 0,
        sys_cursor_area: "box",
        sys_cursor_index: 0,
        sys_held_mon: undefined,
        sys_held_from_area: "",
        sys_held_from_box: -1,
        sys_held_from_index: -1,
        sys_theme_defs: pc__build_theme_defs(),
        sys_status_text: "Move Pokemon",
        sys_input_cooldown: 0,
        sys_title_text: "PC Storage",
        sys_mode: "storage",
        sys_breed_slots: [undefined, undefined, undefined, undefined, undefined, undefined, undefined, undefined, undefined, undefined, undefined, undefined],
        sys_breed_wait_battles: [-1, -1, -1, -1, -1, -1],
        sys_breed_heart: [false, false, false, false, false, false],
        sys_breed_pair_key: ["", "", "", "", "", ""],
        sys_breed_source: "box",
        sys_egg_box: []
    };
}

function pc__make_boxes(){
    var _theme_defs = pc__build_theme_defs();
    var _boxes = [];
    var _box_count = 14;
    var _box_size = 30;
    for (var _i = 0; _i < _box_count; ++_i){
        var _theme_index = _i mod max(1, array_length(_theme_defs));
        array_push(_boxes, pc__make_box("BOX " + string(_i + 1), _theme_index, _box_size));
    }
    return _boxes;
}

function pc__player_count(){
    var _count = 2;
    if (variable_global_exists("PAUSE_PLAYERS_ACTIVE") && is_real(global.PAUSE_PLAYERS_ACTIVE)) _count = max(_count, floor(global.PAUSE_PLAYERS_ACTIVE));
    if (variable_global_exists("PARTY") && is_array(global.PARTY)) _count = max(_count, array_length(global.PARTY));
    return max(1, _count);
}

function pc__pid(_pid){
    if (!is_real(_pid)) return 0;
    return max(0, floor(_pid));
}

function pc__ctrl_pressed(_pid, _action_name){
    if (!is_undefined(controls_pressed)){
        try { return controls_pressed(_pid, _action_name); } catch (e_pc_ctrl_pressed) {}
    }
    return false;
}

function pc__ctrl_down(_pid, _action_name){
    if (!is_undefined(controls_down)){
        try { return controls_down(_pid, _action_name); } catch (e_pc_ctrl_down) {}
    }
    return false;
}

function pc__ctrl_repeat(_pid, _action_name, _initial_delay, _repeat_interval){
    if (!is_undefined(controls_repeat)){
        try { return controls_repeat(_pid, _action_name, _initial_delay, _repeat_interval); } catch (e_pc_ctrl_repeat) {}
    }
    return pc__ctrl_pressed(_pid, _action_name);
}

function pc__draw_round_panel_scaled(_OX, _OY, _S, _x, _y, _w, _h, _edge_col, _fill_col){
    draw_set_colour(_edge_col);
    draw_roundrect(_OX + _x * _S, _OY + _y * _S, _OX + (_x + _w) * _S, _OY + (_y + _h) * _S, false);
    draw_set_colour(_fill_col);
    draw_roundrect(_OX + (_x + 1) * _S, _OY + (_y + 1) * _S, _OX + (_x + _w - 1) * _S, _OY + (_y + _h - 1) * _S, false);
}

function pc__draw_theme_pattern_scaled(_theme, _OX, _OY, _S){
    for (var _py = 10; _py < 154; _py += 24){
        for (var _px = 10; _px < 234; _px += 24){
            pc__draw_pattern_shape(_theme.sys_pattern, _OX + _px * _S, _OY + _py * _S, _theme.sys_panel_mid, 0.20);
        }
    }
}

function pc__draw_party_panel_scaled(_pid, _OX, _OY, _S, _x, _y, _w, _h, _theme){
    var _pc = pc__ensure_state(_pid);
    var _party = pc__get_party_array(_pid);

    pc__draw_round_panel_scaled(_OX, _OY, _S, _x, _y, _w, _h, _theme.sys_panel_dark, _theme.sys_panel_light);

    draw_set_colour(_theme.sys_accent);
    draw_roundrect(_OX + (_x + 3) * _S, _OY + (_y + 3) * _S, _OX + (_x + _w - 3) * _S, _OY + (_y + 14) * _S, false);
    draw_set_colour(c_white);
    draw_text(_OX + (_x + 8) * _S, _OY + (_y + 6) * _S, "PARTY");

    var _slot_h = 16;
    var _slot_x1 = _x + 4;
    var _slot_x2 = _x + _w - 4;
    var _text_x = _x + 23;
    var _text_center_x = _text_x + ((_slot_x2 - _text_x - 1) * 0.5);
    var _text_max_w = max(12, (_slot_x2 - _text_x - 1) * _S);

    for (var _i = 0; _i < 6; ++_i){
        var _sy = _y + 18 + (_i * _slot_h);
        var _is_cursor = (_pc.sys_cursor_area == "party" && _pc.sys_cursor_index == _i);
        var _mon = (_i < array_length(_party)) ? _party[_i] : undefined;

        draw_set_colour((_is_cursor ? _theme.sys_slot_hi : _theme.sys_slot_bg));
        draw_roundrect(_OX + _slot_x1 * _S, _OY + _sy * _S, _OX + _slot_x2 * _S, _OY + (_sy + 13) * _S, false);
        draw_set_colour((_is_cursor ? _theme.sys_accent_dark : _theme.sys_panel_dark));
        draw_roundrect(_OX + _slot_x1 * _S, _OY + _sy * _S, _OX + _slot_x2 * _S, _OY + (_sy + 13) * _S, true);

        pc__draw_mon_icon(_mon, _OX + (_x + 13) * _S, _OY + (_sy + 6.5) * _S, 13 * _S, _is_cursor);

        draw_set_colour(_theme.sys_text_dark);
        if (_mon != undefined){
            pc__draw_fit_text_scaled(pc__mon_display_name(_mon), _OX + _text_center_x * _S, _OY + (_sy + 2) * _S, _text_max_w, 0.35, _theme.sys_text_dark, fa_center);
            draw_set_halign(fa_center);
            draw_text(_OX + _text_center_x * _S, _OY + (_sy + 8) * _S, "Lv" + string(pc__mon_level(_mon)));
            draw_set_halign(fa_left);
        } else {
            draw_text(_OX + (_x + 25) * _S, _OY + (_sy + 5) * _S, "---");
        }

        if (_is_cursor) pc__draw_selector_corner(_OX + _slot_x1 * _S, _OY + _sy * _S, _OX + _slot_x2 * _S, _OY + (_sy + 13) * _S, _theme.sys_accent_dark);
    }
}

function pc__draw_breeding_panel_scaled(_pid, _OX, _OY, _S, _x, _y, _w, _h, _theme){
    var _pc = pc__ensure_state(_pid);
    pc__ensure_breeding_state(_pid);
    pc__breeding_refresh_all_pairs(_pid);

    pc__draw_round_panel_scaled(_OX, _OY, _S, _x, _y, _w, _h, _theme.sys_panel_dark, _theme.sys_panel_light);

    draw_set_colour(_theme.sys_accent);
    draw_roundrect(_OX + (_x + 3) * _S, _OY + (_y + 3) * _S, _OX + (_x + _w - 3) * _S, _OY + (_y + 14) * _S, false);
    draw_set_colour(c_white);
    draw_text(_OX + (_x + 8) * _S, _OY + (_y + 6) * _S, "BREED");

    for (var _pair = 0; _pair < 6; ++_pair){
        var _sy = _y + 18 + (_pair * 17);
        var _slot_a = _pair * 2;
        var _slot_b = _slot_a + 1;
        var _mon_a = _pc.sys_breed_slots[_slot_a];
        var _mon_b = _pc.sys_breed_slots[_slot_b];
        var _heart = (_pair < array_length(_pc.sys_breed_heart) && _pc.sys_breed_heart[_pair] == true);
        var _mf_pair = pc__breeding_is_male_female_pair(_mon_a, _mon_b);
        var _show_pair_heart = (_heart || _mf_pair);

        draw_set_colour(_theme.sys_slot_bg);
        draw_roundrect(_OX + (_x + 4) * _S, _OY + _sy * _S, _OX + (_x + _w - 4) * _S, _OY + (_sy + 15) * _S, false);
        draw_set_colour(_theme.sys_panel_dark);
        draw_roundrect(_OX + (_x + 4) * _S, _OY + _sy * _S, _OX + (_x + _w - 4) * _S, _OY + (_sy + 15) * _S, true);

        draw_set_colour(_theme.sys_text_dark);
        draw_text(_OX + (_x + 6) * _S, _OY + (_sy + 4) * _S, string(_pair + 1));

        for (var _side = 0; _side < 2; ++_side){
            var _slot = _slot_a + _side;
            var _mon = (_side == 0) ? _mon_a : _mon_b;
            var _sx = _x + 17 + (_side * 15);
            var _is_cursor = (_pc.sys_cursor_area == "party" && _pc.sys_cursor_index == _slot);
            draw_set_colour(_is_cursor ? _theme.sys_slot_hi : _theme.sys_panel_mid);
            draw_roundrect(_OX + _sx * _S, _OY + (_sy + 2) * _S, _OX + (_sx + 13) * _S, _OY + (_sy + 14) * _S, false);
            draw_set_colour(_is_cursor ? _theme.sys_accent_dark : _theme.sys_slot_line);
            draw_roundrect(_OX + _sx * _S, _OY + (_sy + 2) * _S, _OX + (_sx + 13) * _S, _OY + (_sy + 14) * _S, true);
            pc__draw_mon_icon(_mon, _OX + (_sx + 6.5) * _S, _OY + (_sy + 8) * _S, 11 * _S, _is_cursor);
            if (_mon != undefined){
                draw_set_colour(_theme.sys_text_dark);
                draw_text(_OX + (_sx + 10) * _S, _OY + (_sy + 8) * _S, pc__breeding_sex_symbol(_mon));
            }
            if (_is_cursor) pc__draw_selector_corner(_OX + _sx * _S, _OY + (_sy + 2) * _S, _OX + (_sx + 13) * _S, _OY + (_sy + 14) * _S, _theme.sys_accent_dark);
        }

        if (_show_pair_heart){
            var _heart_x = _OX + (_x + 31) * _S;
            var _heart_y = _OY + (_sy + 8) * _S;
            var _heart_col = _heart ? make_color_rgb(224, 54, 96) : make_color_rgb(164, 128, 154);
            pc__draw_breeding_heart(_heart_x, _heart_y, _S, 1, _heart_col);
            if (!_heart){
                draw_set_colour(_theme.sys_panel_dark);
                draw_text(_OX + (_x + 47) * _S, _OY + (_sy + 4) * _S, "M/F");
            }
        } else {
            draw_set_colour(_theme.sys_panel_dark);
            draw_text(_OX + (_x + 47) * _S, _OY + (_sy + 4) * _S, "--");
        }
    }

    draw_set_colour(_theme.sys_text_dark);
    var _egg_count = pc__egg_count(_pid);
    draw_text(_OX + (_x + 8) * _S, _OY + (_y + 123) * _S, "Eggs " + string(_egg_count));
    var _sel_pair = pc__breeding_pair_index_from_slot(_pc.sys_cursor_index);
    if (_pc.sys_cursor_area == "party" && _sel_pair >= 0 && _sel_pair < 6){
        var _wait = (_sel_pair < array_length(_pc.sys_breed_wait_battles) && is_real(_pc.sys_breed_wait_battles[_sel_pair])) ? max(0, floor(_pc.sys_breed_wait_battles[_sel_pair])) : 0;
        draw_text(_OX + (_x + 8) * _S, _OY + (_y + 132) * _S, "P" + string(_sel_pair + 1) + " Wait " + string(_wait));
    }
}

function pc__draw_breeding_heart(_heart_x, _heart_y, _S, _scale = 1, _colour = undefined){
    var _s = max(0.25, _S * _scale);
    var _fill = is_undefined(_colour) ? make_color_rgb(224, 54, 96) : _colour;
    draw_set_colour(make_color_rgb(82, 38, 62));
    draw_circle(_heart_x - 2 * _s, _heart_y - 1 * _s, 2.75 * _s, false);
    draw_circle(_heart_x + 2 * _s, _heart_y - 1 * _s, 2.75 * _s, false);
    draw_triangle(_heart_x - 5 * _s, _heart_y, _heart_x + 5 * _s, _heart_y, _heart_x, _heart_y + 6.5 * _s, false);

    draw_set_colour(_fill);
    draw_circle(_heart_x - 2 * _s, _heart_y - 1 * _s, 2 * _s, false);
    draw_circle(_heart_x + 2 * _s, _heart_y - 1 * _s, 2 * _s, false);
    draw_triangle(_heart_x - 4 * _s, _heart_y, _heart_x + 4 * _s, _heart_y, _heart_x, _heart_y + 5 * _s, false);
}

function pc__draw_egg_summary_panel_scaled(_pid, _OX, _OY, _S, _x, _y, _w, _h, _theme){
    var _pc = pc__ensure_breeding_state(_pid);
    pc__draw_round_panel_scaled(_OX, _OY, _S, _x, _y, _w, _h, _theme.sys_panel_dark, _theme.sys_panel_light);

    draw_set_colour(_theme.sys_accent);
    draw_roundrect(_OX + (_x + 3) * _S, _OY + (_y + 3) * _S, _OX + (_x + _w - 3) * _S, _OY + (_y + 14) * _S, false);
    draw_set_colour(c_white);
    draw_text(_OX + (_x + 8) * _S, _OY + (_y + 6) * _S, "EGGS");

    var _egg_count = pc__egg_count(_pid);
    draw_set_colour(_theme.sys_text_dark);
    draw_text(_OX + (_x + 8) * _S, _OY + (_y + 25) * _S, "Stored");
    draw_text(_OX + (_x + 8) * _S, _OY + (_y + 36) * _S, string(_egg_count) + "/30");

    var _egg = pc__get_cursor_mon(_pid);
    if (is_struct(_egg)){
        var _remain = (variable_struct_exists(_egg, "hatch_battles_remaining") && is_real(_egg.hatch_battles_remaining)) ? max(0, floor(_egg.hatch_battles_remaining)) : 0;
        var _sid = pc__breeding_species_id(_egg);
        var _species_name = (_sid > 0 && !is_undefined(scr_poke_name_by_id)) ? scr_poke_name_by_id(_sid) : "Pokemon";
        draw_text(_OX + (_x + 8) * _S, _OY + (_y + 58) * _S, "Selected");
        pc__draw_fit_text_scaled(_species_name, _OX + (_x + 8) * _S, _OY + (_y + 70) * _S, max(8, (_w - 16) * _S), 0.45, _theme.sys_text_dark, fa_left);
        draw_text(_OX + (_x + 8) * _S, _OY + (_y + 88) * _S, "Hatch");
        draw_text(_OX + (_x + 8) * _S, _OY + (_y + 100) * _S, string(_remain) + " battles");
    } else {
        draw_text(_OX + (_x + 8) * _S, _OY + (_y + 58) * _S, "No Egg");
    }
}

function pc__draw_box_panel_scaled(_pid, _OX, _OY, _S, _x, _y, _w, _h, _theme){
    var _pc = pc__ensure_state(_pid);
    var _box = pc__get_active_box(_pid);
    var _breed_party_source = (pc__is_breeding_mode(_pid) && variable_struct_exists(_pc, "sys_breed_source") && string(_pc.sys_breed_source) == "party");
    var _egg_mode = pc__is_egg_mode(_pid);

    pc__draw_round_panel_scaled(_OX, _OY, _S, _x, _y, _w, _h, _theme.sys_panel_dark, _theme.sys_panel_light);

    draw_set_colour(_theme.sys_accent);
    draw_roundrect(_OX + (_x + 3) * _S, _OY + (_y + 3) * _S, _OX + (_x + _w - 3) * _S, _OY + (_y + 14) * _S, false);
    draw_set_colour(c_white);
    draw_text(_OX + (_x + 8) * _S, _OY + (_y + 6) * _S, _egg_mode ? "EGG BOX" : (_breed_party_source ? "PARTY" : pc__fit_text_to_width(_box.sys_name, (_w - 16) * _S)));

    var _grid_x = _x + 5;
    var _grid_y = _y + 19;
    var _slot = 16;
    var _cols = 6;
    var _rows = 5;
    var _grid_w = _cols * _slot;
    var _grid_h = _rows * _slot;

    draw_set_colour(_theme.sys_box_bg);
    draw_roundrect(_OX + (_grid_x - 2) * _S, _OY + (_grid_y - 2) * _S, _OX + (_grid_x + _grid_w + 1) * _S, _OY + (_grid_y + _grid_h + 1) * _S, false);
    pc__draw_box_wallpaper_scaled(_theme, _OX, _OY, _S, _grid_x, _grid_y, _grid_w, _grid_h);

    for (var _row = 0; _row < _rows; ++_row){
        for (var _col = 0; _col < _cols; ++_col){
            var _slot_index = (_row * _cols) + _col;
            var _sx = _grid_x + (_col * _slot);
            var _sy = _grid_y + (_row * _slot);
            var _mon = undefined;
            if (_breed_party_source){
                var _party_pick = pc__get_party_array(_pid);
                if (_slot_index < 6 && _slot_index < array_length(_party_pick)) _mon = _party_pick[_slot_index];
            } else if (_egg_mode){
                if (_slot_index < array_length(_pc.sys_egg_box)) _mon = _pc.sys_egg_box[_slot_index];
            } else {
                _mon = _box.sys_mons[_slot_index];
            }
            var _is_cursor = (_pc.sys_cursor_area == "box" && _pc.sys_cursor_index == _slot_index);
            if (_breed_party_source && _slot_index >= 6){
                draw_set_alpha(0.32);
            }

            draw_set_colour((_is_cursor ? _theme.sys_slot_hi : _theme.sys_slot_bg));
            draw_roundrect(_OX + _sx * _S, _OY + _sy * _S, _OX + (_sx + 15) * _S, _OY + (_sy + 15) * _S, false);
            draw_set_colour((_is_cursor ? _theme.sys_accent_dark : _theme.sys_slot_line));
            draw_roundrect(_OX + _sx * _S, _OY + _sy * _S, _OX + (_sx + 15) * _S, _OY + (_sy + 15) * _S, true);

            pc__draw_mon_icon(_mon, _OX + (_sx + 7.5) * _S, _OY + (_sy + 7.5) * _S, 14 * _S, _is_cursor);
            if (_mon != undefined && pc__is_breeding_mode(_pid)){
                draw_set_colour(_theme.sys_text_dark);
                draw_set_halign(fa_right);
                draw_text(_OX + (_sx + 14) * _S, _OY + (_sy + 9) * _S, pc__breeding_sex_symbol(_mon));
                draw_set_halign(fa_left);
            }
            if (_egg_mode && _mon != undefined){
                var _remain_slot = (is_struct(_mon) && variable_struct_exists(_mon, "hatch_battles_remaining") && is_real(_mon.hatch_battles_remaining)) ? max(0, floor(_mon.hatch_battles_remaining)) : 0;
                draw_set_colour(_theme.sys_text_dark);
                draw_set_halign(fa_right);
                draw_text(_OX + (_sx + 14) * _S, _OY + (_sy + 9) * _S, string(_remain_slot));
                draw_set_halign(fa_left);
            }
            if (_is_cursor) pc__draw_selector_corner(_OX + _sx * _S, _OY + _sy * _S, _OX + (_sx + 15) * _S, _OY + (_sy + 15) * _S, _theme.sys_accent_dark);
            if (_breed_party_source && _slot_index >= 6) draw_set_alpha(1);
        }
    }

    var _info_x = _grid_x + _grid_w + 2;
    var _info_y = _grid_y;
    var _info_w = max(58, (_x + _w - 3) - _info_x);
    var _info_h = _grid_h;

    draw_set_colour(_theme.sys_panel_mid);
    draw_roundrect(_OX + _info_x * _S, _OY + _info_y * _S, _OX + (_info_x + _info_w) * _S, _OY + (_info_y + _info_h) * _S, false);
    draw_set_colour(_theme.sys_panel_dark);
    draw_roundrect(_OX + _info_x * _S, _OY + _info_y * _S, _OX + (_info_x + _info_w) * _S, _OY + (_info_y + _info_h) * _S, true);

    var _cursor_mon = pc__get_cursor_mon(_pid);
    var _info_text_w = max(8, (_info_w - 2) * _S);
    draw_set_colour(_theme.sys_text_dark);
    draw_text(_OX + (_info_x + 3) * _S, _OY + (_info_y + 4) * _S, "INFO");
    draw_text(_OX + (_info_x + 3) * _S, _OY + (_info_y + 16) * _S, _egg_mode ? "Egg storage" : (_breed_party_source ? "Party source" : pc__fit_text_to_width(_theme.sys_name, _info_text_w)));
    draw_text(_OX + (_info_x + 3) * _S, _OY + (_info_y + 30) * _S, _egg_mode ? string(pc__egg_count(_pid)) + "/30" : (_breed_party_source ? "Inv: Box" : string(pc__count_box_mons(_box)) + "/" + string(array_length(_box.sys_mons))));

    if (_cursor_mon != undefined){
        pc__draw_fit_text_scaled(pc__mon_display_name(_cursor_mon), _OX + (_info_x + 3) * _S, _OY + (_info_y + 46) * _S, _info_text_w, 0.50, _theme.sys_text_dark, fa_left);
        if (_egg_mode){
            var _remain_info = (variable_struct_exists(_cursor_mon, "hatch_battles_remaining") && is_real(_cursor_mon.hatch_battles_remaining)) ? max(0, floor(_cursor_mon.hatch_battles_remaining)) : 0;
            draw_text(_OX + (_info_x + 3) * _S, _OY + (_info_y + 55) * _S, "Hatch " + string(_remain_info));
        } else {
            draw_text(_OX + (_info_x + 3) * _S, _OY + (_info_y + 55) * _S, "Lv" + string(pc__mon_level(_cursor_mon)));
            if (pc__is_breeding_mode(_pid)) draw_text(_OX + (_info_x + 24) * _S, _OY + (_info_y + 55) * _S, "Sex " + pc__breeding_sex_symbol(_cursor_mon));
        }
        var _portrait_w = min(38, _info_w - 6);
        var _portrait_h = 28;
        var _portrait_x = _info_x + ((_info_w - _portrait_w) * 0.5);
        var _portrait_y = _info_y + 64;

        draw_set_colour(_theme.sys_slot_bg);
        draw_roundrect(_OX + _portrait_x * _S, _OY + _portrait_y * _S, _OX + (_portrait_x + _portrait_w) * _S, _OY + (_portrait_y + _portrait_h) * _S, false);
        draw_set_colour(_theme.sys_accent_dark);
        draw_roundrect(_OX + _portrait_x * _S, _OY + _portrait_y * _S, _OX + (_portrait_x + _portrait_w) * _S, _OY + (_portrait_y + _portrait_h) * _S, true);

        pc__draw_mon_icon(_cursor_mon, _OX + (_portrait_x + _portrait_w * 0.5) * _S, _OY + (_portrait_y + _portrait_h * 0.5) * _S, 25 * _S, false);
    } else {
        draw_text(_OX + (_info_x + 3) * _S, _OY + (_info_y + 46) * _S, "---");
    }
}

function pc__draw_box_wallpaper_scaled(_theme, _OX, _OY, _S, _x, _y, _w, _h){
    for (var _py = _y + 6; _py < _y + _h; _py += 18){
        for (var _px = _x + 6; _px < _x + _w; _px += 18){
            pc__draw_pattern_shape(_theme.sys_pattern, _OX + _px * _S, _OY + _py * _S, _theme.sys_accent, 0.14);
        }
    }
}

function pc__draw_mon_icon(_mon, _cx, _cy, _target_h){
    var _hovered = false;
    if (argument_count > 4) _hovered = argument[4];

    var _base_h = max(6, _target_h);
    var _pulse_mult = 1;
    if (_hovered){
        // Scale only. Do not change any anchor/offset with the pulse,
        // otherwise the Pokemon appears to slide while animating.
        _pulse_mult = 1 + (sin(current_time / 135) * 0.045);
    }
    var _safe_h = _base_h * _pulse_mult;

    if (_mon == undefined){
        draw_set_alpha(0.35);
        draw_set_colour(make_color_rgb(160, 168, 176));
        draw_circle(_cx, _cy, max(3, _base_h * 0.35), true);
        draw_set_alpha(1);
        return;
    }

    _mon = pc__normalize_mon(_mon);

    var _spr = -1;
    var _subimg = 0;

    if (!is_undefined(pkicons_get_icon32_dir_by_mon)){
        try { _spr = pkicons_get_icon32_dir_by_mon(_mon, "down"); } catch (e_pc_pkicon) { _spr = -1; }
    }

    if (_spr != -1 && !is_undefined(pkicons_icon32_frame_ui)){
        try { _subimg = pkicons_icon32_frame_ui(); } catch (e_pc_pkframe) { _subimg = 0; }
    }

    if (_spr == -1){
        if (variable_struct_exists(_mon, "icon") && is_real(variable_struct_get(_mon, "icon"))) _spr = variable_struct_get(_mon, "icon");
        else if (variable_struct_exists(_mon, "icon_sprite") && is_real(variable_struct_get(_mon, "icon_sprite"))) _spr = variable_struct_get(_mon, "icon_sprite");
        else if (variable_struct_exists(_mon, "sprite") && is_real(variable_struct_get(_mon, "sprite"))) _spr = variable_struct_get(_mon, "sprite");
        else if (variable_struct_exists(_mon, "front_sprite") && is_real(variable_struct_get(_mon, "front_sprite"))) _spr = variable_struct_get(_mon, "front_sprite");
    }

    if (variable_struct_exists(_mon, "icon_index") && is_real(variable_struct_get(_mon, "icon_index"))) _subimg = variable_struct_get(_mon, "icon_index");

    if (_spr != -1){
        var _spr_w = max(1, sprite_get_width(_spr));
        var _spr_h = max(1, sprite_get_height(_spr));

        var _draw_scale = _safe_h / _spr_h;
        var _draw_w = _spr_w * _draw_scale;
        var _draw_h = _spr_h * _draw_scale;

        draw_sprite_part_ext(
            _spr,
            _subimg,
            0,
            0,
            _spr_w,
            _spr_h,
            floor(_cx - (_draw_w * 0.5)),
            floor(_cy - (_draw_h * 0.5)),
            _draw_scale,
            _draw_scale,
            c_white,
            1
        );
        return;
    }

    if (!is_undefined(spr_mon_icon_placeholder)){
        var _ph = spr_mon_icon_placeholder;
        var _ph_w = max(1, sprite_get_width(_ph));
        var _ph_h = max(1, sprite_get_height(_ph));
        var _ph_scale = _safe_h / _ph_h;
        var _ph_draw_w = _ph_w * _ph_scale;
        var _ph_draw_h = _ph_h * _ph_scale;
        draw_sprite_part_ext(
            _ph,
            0,
            0,
            0,
            _ph_w,
            _ph_h,
            floor(_cx - (_ph_draw_w * 0.5)),
            floor(_cy - (_ph_draw_h * 0.5)),
            _ph_scale,
            _ph_scale,
            c_white,
            1
        );
        return;
    }

    draw_set_colour(make_color_rgb(236, 236, 236));
    draw_circle(_cx, _cy, _base_h * 0.45, false);
    draw_set_colour(make_color_rgb(214, 64, 64));
    draw_rectangle(_cx - _base_h * 0.45, _cy - _base_h * 0.45, _cx + _base_h * 0.45, _cy, false);
    draw_set_colour(make_color_rgb(236, 236, 236));
    draw_circle(_cx, _cy, _base_h * 0.12, true);
}

function pc__move_cursor(_pid, _dx, _dy){
    var _pc = pc__ensure_state(_pid);
    var _old_area = string(_pc.sys_cursor_area);
    var _old_index = _pc.sys_cursor_index;
    var _breed_mode = pc__is_breeding_mode(_pid);
    var _egg_mode = pc__is_egg_mode(_pid);

    if (_pc.sys_cursor_area == "party"){
        if (_egg_mode){
            _pc.sys_cursor_area = "box";
            _pc.sys_cursor_index = clamp(_pc.sys_cursor_index, 0, (_pc.sys_box_cols * _pc.sys_box_rows) - 1);
            _pc.sys_status_text = pc__cursor_status_text(_pid);
            if (!is_undefined(ui_play_select_sound)) ui_play_select_sound();
            return;
        }
        var _party_max = _breed_mode ? 11 : 5;
        var _old_party_index = _pc.sys_cursor_index;
        var _party_index = _old_party_index;
        if (_breed_mode){
            if (_dx > 0 && (_old_party_index mod 2) == 1){
                _pc.sys_cursor_area = "box";
                if (variable_struct_exists(_pc, "sys_breed_source") && string(_pc.sys_breed_source) == "party") _pc.sys_cursor_index = clamp(pc__breeding_pair_index_from_slot(_old_party_index), 0, 5);
                else _pc.sys_cursor_index = clamp(pc__breeding_pair_index_from_slot(_old_party_index) * _pc.sys_box_cols, 0, (_pc.sys_box_cols * _pc.sys_box_rows) - 1);
                _pc.sys_status_text = pc__cursor_status_text(_pid);
                if (!is_undefined(ui_play_select_sound)) ui_play_select_sound();
                return;
            }
            if (_dy != 0) _party_index += _dy * 2;
            else if (_dx != 0) _party_index += _dx;
            _party_index = clamp(_party_index, 0, _party_max);
        } else {
            _party_index = clamp(_pc.sys_cursor_index + _dy, 0, _party_max);
        }
        _pc.sys_cursor_index = _party_index;
        if (!_breed_mode && _dx > 0){
            _pc.sys_cursor_area = "box";
            _pc.sys_cursor_index = clamp(_party_index * _pc.sys_box_cols, 0, (_pc.sys_box_cols * _pc.sys_box_rows) - 1);
        }
    } else {
        var _source_party = (_breed_mode && variable_struct_exists(_pc, "sys_breed_source") && string(_pc.sys_breed_source) == "party");
        var _cols = _source_party ? 6 : _pc.sys_box_cols;
        var _rows = _source_party ? 1 : _pc.sys_box_rows;
        var _index = _pc.sys_cursor_index;
        var _col = _index mod _cols;
        var _row = floor(_index / _cols);

        _col += _dx;
        _row += _dy;

        if (_col < 0){
            if (_egg_mode){
                _col = 0;
                _row = clamp(_row, 0, _rows - 1);
                _pc.sys_cursor_index = (_row * _cols) + _col;
                _pc.sys_status_text = pc__cursor_status_text(_pid);
                if (!is_undefined(ui_play_select_sound)) ui_play_select_sound();
                return;
            }
            _pc.sys_cursor_area = "party";
            _pc.sys_cursor_index = _breed_mode ? clamp(_row * 2, 0, 11) : clamp(_row, 0, 5);
            _pc.sys_status_text = _breed_mode ? "Nursery slot selected" : "Party selected";
            if (!is_undefined(ui_play_select_sound)) ui_play_select_sound();
            return;
        }

        _col = clamp(_col, 0, _cols - 1);
        _row = clamp(_row, 0, _rows - 1);
        _pc.sys_cursor_index = (_row * _cols) + _col;
    }

    _pc.sys_status_text = pc__cursor_status_text(_pid);
    if ((_old_area != string(_pc.sys_cursor_area) || _old_index != _pc.sys_cursor_index) && !is_undefined(ui_play_select_sound)) ui_play_select_sound();
}

function pc__pickup_or_place(_pid){
    var _pc = pc__ensure_state(_pid);

    if (pc__is_egg_mode(_pid)){
        _pc.sys_status_text = "Eggs hatch after battles.";
        return false;
    }

    var _cursor_area = _pc.sys_cursor_area;
    var _cursor_index = floor(_pc.sys_cursor_index);
    var _cursor_box = -1;
    var _cursor_origin_area = _cursor_area;
    if (_cursor_area == "party" && pc__is_breeding_mode(_pid)) _cursor_origin_area = "breed_slot";
    if (_cursor_area == "box"){
        _cursor_box = 0;
        if (variable_struct_exists(_pc, "sys_active_box") && is_real(_pc.sys_active_box)) _cursor_box = floor(_pc.sys_active_box);
        if (pc__is_breeding_mode(_pid) && variable_struct_exists(_pc, "sys_breed_source") && string(_pc.sys_breed_source) == "party"){
            _cursor_origin_area = "breed_party";
            _cursor_box = -1;
        }
    }

    var _cursor_mon = pc__get_cursor_mon(_pid);

    // PICK UP
    if (_pc.sys_held_mon == undefined){
        if (_cursor_mon == undefined){
            _pc.sys_status_text = "No Pokemon here.";
            return false;
        }

        // Hold the exact Pokemon from this slot, then clear that exact slot.
        _pc.sys_held_mon = _cursor_mon;
        _pc.sys_held_from_area = _cursor_origin_area;
        _pc.sys_held_from_box = _cursor_box;
        _pc.sys_held_from_index = _cursor_index;

        // Clear stale legacy fields from older patch attempts.
        _pc.sys_held_origin_area = "";
        _pc.sys_held_origin_box = -1;
        _pc.sys_held_origin_index = -1;

        if (!pc__set_cursor_mon(_pid, undefined)){
            _pc.sys_status_text = "Could not pick up Pokemon.";
            _pc.sys_held_mon = undefined;
            _pc.sys_held_from_area = "";
            _pc.sys_held_from_box = -1;
            _pc.sys_held_from_index = -1;
            return false;
        }

        _pc.sys_status_text = "Holding " + pc__mon_display_name(_pc.sys_held_mon);
        if (!is_undefined(sfx_play_safe)) sfx_play_safe(snd_pickup, 1);
        return true;
    }

    // PLACE / SWAP
    // Important: capture the target BEFORE writing held into the slot.
    // If target exists, it becomes the new held Pokemon.
    var _held = _pc.sys_held_mon;
    var _target = _cursor_mon;

    if (!pc__set_cursor_mon(_pid, _held)){
        _pc.sys_status_text = "Could not place Pokemon.";
        return false;
    }
    pc__remove_exact_mon_reference_except(_pid, _held, _cursor_origin_area, _cursor_box, _cursor_index);

    if (_target != undefined){
        _pc.sys_held_mon = _target;
        _pc.sys_held_from_area = _cursor_origin_area;
        _pc.sys_held_from_box = _cursor_box;
        _pc.sys_held_from_index = _cursor_index;

        _pc.sys_held_origin_area = "";
        _pc.sys_held_origin_box = -1;
        _pc.sys_held_origin_index = -1;

        _pc.sys_status_text = "Swapped. Holding " + pc__mon_display_name(_pc.sys_held_mon);
        if (!is_undefined(sfx_play_safe)) sfx_play_safe(snd_pickup, 1);
        return true;
    }

    _pc.sys_status_text = "Placed " + pc__mon_display_name(_held);
    _pc.sys_held_mon = undefined;
    _pc.sys_held_from_area = "";
    _pc.sys_held_from_box = -1;
    _pc.sys_held_from_index = -1;
    _pc.sys_held_origin_area = "";
    _pc.sys_held_origin_box = -1;
    _pc.sys_held_origin_index = -1;
    if (!is_undefined(sfx_play_safe)) sfx_play_safe(snd_pickup, 1);
    return true;
}

function pc__return_held_to_origin(_pid){
    var _pc = pc__ensure_state(_pid);
    if (_pc.sys_held_mon == undefined) return false;

    var _restore_mon = _pc.sys_held_mon;
    var _restore_area = _pc.sys_held_from_area;
    var _restore_box = _pc.sys_held_from_box;
    var _restore_index = _pc.sys_held_from_index;

    var _returned = false;

    if ((_restore_area == "breed_slot" || (_restore_area == "party" && pc__is_breeding_mode(_pid))) && _restore_index >= 0){
        pc__ensure_breeding_state(_pid);
        if (_restore_index < 12 && _pc.sys_breed_slots[_restore_index] == undefined){
            _pc.sys_breed_slots[_restore_index] = _restore_mon;
            pc__breeding_refresh_pair(_pid, pc__breeding_pair_index_from_slot(_restore_index));
            _returned = true;
        }
    } else if (_restore_area == "breed_party" && _restore_index >= 0){
        var _party_return = pc__get_party_array(_pid);
        if (_restore_index < 6 && (_restore_index >= array_length(_party_return) || _party_return[_restore_index] == undefined)){
            _returned = pc__write_party_slot(_pid, _restore_index, _restore_mon);
        }
    } else if (_restore_area == "party" && _restore_index >= 0){
        var _party = pc__get_party_array(_pid);
        if (_restore_index < array_length(_party) && _party[_restore_index] == undefined){
            _returned = pc__write_party_slot(_pid, _restore_index, _restore_mon);
        }
    } else if (_restore_area == "box" && _restore_box >= 0 && _restore_index >= 0){
        var _boxes = _pc.sys_boxes;
        if (_restore_box < array_length(_boxes)){
            var _box = _boxes[_restore_box];
            if (is_struct(_box) && variable_struct_exists(_box, "sys_mons") && is_array(_box.sys_mons)){
                if (_restore_index >= array_length(_box.sys_mons)) array_resize(_box.sys_mons, _restore_index + 1);
                if (_box.sys_mons[_restore_index] == undefined){
                    _box.sys_mons[_restore_index] = _restore_mon;
                    _pc.sys_boxes[_restore_box] = _box;
                    _returned = true;
                }
            }
        }
    }

    if (!_returned){
        _returned = pc__set_first_available(_pid, _restore_mon);
    }

    if (_returned){
        _pc.sys_held_mon = undefined;
        _pc.sys_held_from_area = "";
        _pc.sys_held_from_box = -1;
        _pc.sys_held_from_index = -1;
        _pc.sys_held_origin_area = "";
        _pc.sys_held_origin_box = -1;
        _pc.sys_held_origin_index = -1;
        return true;
    }

    _pc.sys_status_text = "No room to return Pokemon";
    return false;
}

function pc__set_first_available(_pid, _mon){
    if (_mon != undefined) _mon = pc__normalize_mon(_mon);

    var _party = pc__get_party_array(_pid);
    var _cap = 6;
    if (!is_undefined(party_model_get_party_capacity)) _cap = max(1, party_model_get_party_capacity());

    for (var _i = 0; _i < _cap; ++_i){
        var _slot_mon = undefined;
        if (_i < array_length(_party)) _slot_mon = _party[_i];

        if (_slot_mon == undefined){
            return pc__write_party_slot(_pid, _i, _mon);
        }
    }

    return pc_store_mon_to_box(_pid, _mon);
}

function pc__force_store_held_mon(_pid){
    var _pc = pc__ensure_state(_pid);
    if (_pc.sys_held_mon == undefined) return true;

    var _mon = _pc.sys_held_mon;
    var _info = pc_store_mon_to_box_info(_pid, _mon);
    if (is_struct(_info) && variable_struct_exists(_info, "ok") && _info.ok == true){
        pc__clear_held_state(_pc);
        return true;
    }

    _pc.sys_status_text = "No room to return Pokemon";
    return false;
}

function pc__cycle_box(_pid, _dir){
    var _pc = pc__ensure_state(_pid);
    var _count = array_length(_pc.sys_boxes);
    if (_count <= 0) return;
    _pc.sys_active_box = (_pc.sys_active_box + _dir + _count) mod _count;
    _pc.sys_status_text = pc__get_active_box(_pid).sys_name;
    if (!is_undefined(ui_play_select_sound)) ui_play_select_sound();
}

function pc__cycle_theme(_pid, _dir){
    var _pc = pc__ensure_state(_pid);
    var _box = pc__get_active_box(_pid);
    var _theme_count = array_length(_pc.sys_theme_defs);
    if (_theme_count <= 0) return;
    _box.sys_theme_index = (_box.sys_theme_index + _dir + _theme_count) mod _theme_count;
    _pc.sys_status_text = "Theme: " + pc__get_active_theme(_pid).sys_name;
    if (!is_undefined(ui_play_select_sound)) ui_play_select_sound();
}

function pc__get_active_box(_pid){
    var _pc = pc__ensure_state(_pid);
    return _pc.sys_boxes[_pc.sys_active_box];
}

function pc__get_active_theme(_pid){
    var _pc = pc__ensure_state(_pid);
    var _box = pc__get_active_box(_pid);
    return _pc.sys_theme_defs[_box.sys_theme_index];
}

function pc__cursor_status_text(_pid){
    var _pc = pc__ensure_state(_pid);
    var _mon = pc__get_cursor_mon(_pid);
    if (_pc.sys_held_mon != undefined) return "Place " + pc__mon_display_name(_pc.sys_held_mon);
    if (_mon != undefined){
        if (pc__is_egg_mode(_pid)){
            var _remain = (is_struct(_mon) && variable_struct_exists(_mon, "hatch_battles_remaining") && is_real(_mon.hatch_battles_remaining)) ? max(0, floor(_mon.hatch_battles_remaining)) : 0;
            return "Egg hatches in " + string(_remain) + " battles";
        }
        if (pc__is_breeding_mode(_pid) && _pc.sys_cursor_area == "party") return pc__mon_display_name(_mon) + " in nursery";
        return pc__mon_display_name(_mon) + " Lv" + string(pc__mon_level(_mon));
    }
    if (pc__is_breeding_mode(_pid) && _pc.sys_cursor_area == "party") return "Empty nursery slot";
    return "Empty slot";
}

function pc__get_cursor_mon(_pid){
    var _pc = pc__ensure_state(_pid);

    if (pc__is_egg_mode(_pid)){
        pc__ensure_breeding_state(_pid);
        var _egg_slot = floor(_pc.sys_cursor_index);
        if (_egg_slot >= 0 && _egg_slot < array_length(_pc.sys_egg_box)) return _pc.sys_egg_box[_egg_slot];
        return undefined;
    }

    if (_pc.sys_cursor_area == "party"){
        var _slot = floor(_pc.sys_cursor_index);
        if (_slot < 0) return undefined;

        if (pc__is_breeding_mode(_pid)){
            pc__ensure_breeding_state(_pid);
            if (_slot >= 0 && _slot < 12) return _pc.sys_breed_slots[_slot];
            return undefined;
        }

        // Canonical read path for party slots.
        if (!is_undefined(party_model_get_mon)){
            var _model_mon = party_model_get_mon(_pid, _slot);
            if (!is_undefined(_model_mon)) return _model_mon;
        }

        var _party = pc__get_party_array(_pid);
        if (_slot >= 0 && _slot < array_length(_party)) return _party[_slot];
        return undefined;
    }

    if (pc__is_breeding_mode(_pid) && variable_struct_exists(_pc, "sys_breed_source") && string(_pc.sys_breed_source) == "party"){
        var _party_src = pc__get_party_array(_pid);
        if (_pc.sys_cursor_index >= 0 && _pc.sys_cursor_index < 6 && _pc.sys_cursor_index < array_length(_party_src)) return _party_src[_pc.sys_cursor_index];
        return undefined;
    }

    var _box = pc__get_active_box(_pid);
    if (_pc.sys_cursor_index >= 0 && _pc.sys_cursor_index < array_length(_box.sys_mons)) return _box.sys_mons[_pc.sys_cursor_index];
    return undefined;
}

function pc__set_cursor_mon(_pid, _mon){
    var _pc = pc__ensure_state(_pid);
    if (_mon != undefined) _mon = pc__normalize_mon(_mon);

    if (pc__is_egg_mode(_pid)) return false;

    if (_pc.sys_cursor_area == "party"){
        if (pc__is_breeding_mode(_pid)){
            pc__ensure_breeding_state(_pid);
            var _breed_slot = floor(_pc.sys_cursor_index);
            if (_breed_slot < 0 || _breed_slot >= 12) return false;
            _pc.sys_breed_slots[_breed_slot] = _mon;
            pc__breeding_refresh_pair(_pid, pc__breeding_pair_index_from_slot(_breed_slot));
            return true;
        }
        return pc__write_party_slot(_pid, _pc.sys_cursor_index, _mon);
    }

    if (pc__is_breeding_mode(_pid) && variable_struct_exists(_pc, "sys_breed_source") && string(_pc.sys_breed_source) == "party"){
        var _party_slot = floor(_pc.sys_cursor_index);
        if (_party_slot < 0 || _party_slot >= 6) return false;
        return pc__write_party_slot(_pid, _party_slot, _mon);
    }

    var _box = pc__get_active_box(_pid);
    if (!is_struct(_box)) return false;
    if (!variable_struct_exists(_box, "sys_mons") || !is_array(_box.sys_mons)) _box.sys_mons = [];

    var _idx = floor(_pc.sys_cursor_index);
    if (_idx < 0) return false;
    if (_idx >= array_length(_box.sys_mons)) array_resize(_box.sys_mons, _idx + 1);

    _box.sys_mons[_idx] = _mon;
    return true;
}

function pc__count_box_mons(_box){
    var _count = 0;
    if (!is_struct(_box) || !is_array(_box.sys_mons)) return 0;
    for (var _i = 0; _i < array_length(_box.sys_mons); ++_i){
        if (_box.sys_mons[_i] != undefined) _count += 1;
    }
    return _count;
}

function pc__ensure_party_capacity(_pid){
    if (is_undefined(party_ensure)) return false;
    var _party_struct = party_ensure(_pid);
    if (!is_struct(_party_struct)) return false;
    if (!variable_struct_exists(_party_struct, "mons") || !is_array(variable_struct_get(_party_struct, "mons"))) variable_struct_set(_party_struct, "mons", []);
    return true;
}

function pc__get_party_array(_pid){
    var _p = pc__pid(_pid);

    if (!variable_global_exists("PARTY")) global.PARTY = [];
    if (!is_array(global.PARTY)) global.PARTY = [];
    if (array_length(global.PARTY) <= _p) array_resize(global.PARTY, _p + 1);

    var _P = global.PARTY[_p];
    if (!is_struct(_P)){
        _P = { open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0, mons:[], sum_move_sel:0, sum_learn_sel:0 };
        global.PARTY[_p] = _P;
    }

    if (!variable_struct_exists(_P, "mons") || !is_array(_P.mons)){
        _P.mons = [];
        global.PARTY[_p] = _P;
    }

    // Read through the canonical party model when available.
    if (!is_undefined(party_model_get_mons)){
        var _mons = party_model_get_mons(_p);
        if (is_array(_mons)) return _mons;
    }

    return _P.mons;
}

function pc__make_box(_name, _theme_index, _box_size){
    var _mons = [];
    for (var _i = 0; _i < _box_size; ++_i) array_push(_mons, undefined);
    return { sys_name: _name, sys_theme_index: _theme_index, sys_mons: _mons };
}

function pc__build_theme_defs(){
    return [
        { sys_name: "Forest",  sys_bg0: make_color_rgb(144, 200, 156), sys_bg1: make_color_rgb(88, 152, 100), sys_panel_light: make_color_rgb(230, 246, 228), sys_panel_mid: make_color_rgb(200, 230, 198), sys_panel_dark: make_color_rgb(58, 108, 62), sys_accent: make_color_rgb(78, 158, 92), sys_accent_dark: make_color_rgb(46, 104, 58), sys_box_bg: make_color_rgb(190, 232, 188), sys_slot_bg: make_color_rgb(236, 247, 234), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(86, 126, 92), sys_text_dark: make_color_rgb(36, 66, 40), sys_pattern: "leaf" },
        { sys_name: "Sea",     sys_bg0: make_color_rgb(146, 198, 236), sys_bg1: make_color_rgb(92, 146, 206), sys_panel_light: make_color_rgb(230, 244, 252), sys_panel_mid: make_color_rgb(196, 226, 244), sys_panel_dark: make_color_rgb(56, 94, 146), sys_accent: make_color_rgb(68, 136, 212), sys_accent_dark: make_color_rgb(44, 84, 132), sys_box_bg: make_color_rgb(190, 226, 246), sys_slot_bg: make_color_rgb(238, 247, 255), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(78, 112, 156), sys_text_dark: make_color_rgb(34, 54, 82), sys_pattern: "bubble" },
        { sys_name: "Sky",     sys_bg0: make_color_rgb(196, 224, 255), sys_bg1: make_color_rgb(132, 182, 244), sys_panel_light: make_color_rgb(246, 250, 255), sys_panel_mid: make_color_rgb(220, 236, 255), sys_panel_dark: make_color_rgb(88, 126, 180), sys_accent: make_color_rgb(110, 168, 248), sys_accent_dark: make_color_rgb(62, 104, 166), sys_box_bg: make_color_rgb(216, 234, 255), sys_slot_bg: make_color_rgb(246, 250, 255), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(96, 124, 176), sys_text_dark: make_color_rgb(42, 62, 94), sys_pattern: "cloud" },
        { sys_name: "Volcano", sys_bg0: make_color_rgb(236, 176, 132), sys_bg1: make_color_rgb(200, 104, 72), sys_panel_light: make_color_rgb(255, 236, 220), sys_panel_mid: make_color_rgb(246, 210, 190), sys_panel_dark: make_color_rgb(128, 62, 44), sys_accent: make_color_rgb(216, 102, 60), sys_accent_dark: make_color_rgb(142, 58, 38), sys_box_bg: make_color_rgb(250, 214, 194), sys_slot_bg: make_color_rgb(255, 242, 234), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(156, 88, 72), sys_text_dark: make_color_rgb(84, 40, 30), sys_pattern: "flame" },
        { sys_name: "Cave",    sys_bg0: make_color_rgb(184, 180, 196), sys_bg1: make_color_rgb(122, 116, 140), sys_panel_light: make_color_rgb(238, 236, 244), sys_panel_mid: make_color_rgb(210, 206, 220), sys_panel_dark: make_color_rgb(82, 78, 102), sys_accent: make_color_rgb(126, 120, 160), sys_accent_dark: make_color_rgb(70, 68, 94), sys_box_bg: make_color_rgb(214, 210, 226), sys_slot_bg: make_color_rgb(244, 243, 250), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(102, 98, 126), sys_text_dark: make_color_rgb(52, 48, 70), sys_pattern: "gem" },
        { sys_name: "City",    sys_bg0: make_color_rgb(206, 214, 228), sys_bg1: make_color_rgb(150, 164, 184), sys_panel_light: make_color_rgb(242, 246, 252), sys_panel_mid: make_color_rgb(218, 226, 238), sys_panel_dark: make_color_rgb(86, 100, 122), sys_accent: make_color_rgb(102, 130, 166), sys_accent_dark: make_color_rgb(64, 88, 122), sys_box_bg: make_color_rgb(222, 230, 240), sys_slot_bg: make_color_rgb(248, 250, 254), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(100, 116, 140), sys_text_dark: make_color_rgb(42, 56, 74), sys_pattern: "window" },
        { sys_name: "Desert",  sys_bg0: make_color_rgb(238, 214, 144), sys_bg1: make_color_rgb(212, 170, 92), sys_panel_light: make_color_rgb(255, 246, 224), sys_panel_mid: make_color_rgb(246, 228, 182), sys_panel_dark: make_color_rgb(138, 106, 52), sys_accent: make_color_rgb(220, 170, 74), sys_accent_dark: make_color_rgb(152, 112, 46), sys_box_bg: make_color_rgb(252, 234, 196), sys_slot_bg: make_color_rgb(255, 248, 234), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(162, 124, 72), sys_text_dark: make_color_rgb(82, 62, 30), sys_pattern: "dune" },
        { sys_name: "Snow",    sys_bg0: make_color_rgb(230, 240, 252), sys_bg1: make_color_rgb(176, 202, 234), sys_panel_light: make_color_rgb(252, 254, 255), sys_panel_mid: make_color_rgb(232, 242, 252), sys_panel_dark: make_color_rgb(110, 136, 172), sys_accent: make_color_rgb(150, 190, 244), sys_accent_dark: make_color_rgb(88, 126, 178), sys_box_bg: make_color_rgb(238, 246, 255), sys_slot_bg: make_color_rgb(252, 254, 255), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(120, 142, 174), sys_text_dark: make_color_rgb(52, 70, 98), sys_pattern: "snow" },
        { sys_name: "Stars",   sys_bg0: make_color_rgb(112, 118, 196), sys_bg1: make_color_rgb(68, 74, 146), sys_panel_light: make_color_rgb(228, 230, 248), sys_panel_mid: make_color_rgb(188, 192, 234), sys_panel_dark: make_color_rgb(48, 54, 110), sys_accent: make_color_rgb(240, 204, 92), sys_accent_dark: make_color_rgb(176, 138, 48), sys_box_bg: make_color_rgb(166, 170, 224), sys_slot_bg: make_color_rgb(234, 236, 252), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(80, 86, 156), sys_text_dark: make_color_rgb(28, 30, 74), sys_pattern: "star" },
        { sys_name: "Hearts",  sys_bg0: make_color_rgb(244, 188, 214), sys_bg1: make_color_rgb(220, 126, 166), sys_panel_light: make_color_rgb(255, 238, 246), sys_panel_mid: make_color_rgb(248, 212, 228), sys_panel_dark: make_color_rgb(144, 78, 106), sys_accent: make_color_rgb(232, 102, 150), sys_accent_dark: make_color_rgb(168, 62, 106), sys_box_bg: make_color_rgb(252, 224, 236), sys_slot_bg: make_color_rgb(255, 244, 248), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(168, 96, 126), sys_text_dark: make_color_rgb(88, 42, 62), sys_pattern: "heart" },
        { sys_name: "Machine", sys_bg0: make_color_rgb(186, 206, 206), sys_bg1: make_color_rgb(116, 144, 148), sys_panel_light: make_color_rgb(236, 246, 246), sys_panel_mid: make_color_rgb(208, 228, 228), sys_panel_dark: make_color_rgb(60, 88, 94), sys_accent: make_color_rgb(92, 152, 160), sys_accent_dark: make_color_rgb(48, 92, 98), sys_box_bg: make_color_rgb(204, 228, 230), sys_slot_bg: make_color_rgb(242, 250, 250), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(92, 122, 126), sys_text_dark: make_color_rgb(34, 58, 62), sys_pattern: "gear" },
        { sys_name: "Field",   sys_bg0: make_color_rgb(196, 228, 156), sys_bg1: make_color_rgb(132, 184, 92), sys_panel_light: make_color_rgb(242, 252, 232), sys_panel_mid: make_color_rgb(220, 242, 200), sys_panel_dark: make_color_rgb(78, 110, 52), sys_accent: make_color_rgb(112, 182, 82), sys_accent_dark: make_color_rgb(64, 112, 50), sys_box_bg: make_color_rgb(218, 242, 194), sys_slot_bg: make_color_rgb(246, 252, 240), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(94, 132, 74), sys_text_dark: make_color_rgb(44, 68, 30), sys_pattern: "petal" },
        { sys_name: "Retro",   sys_bg0: make_color_rgb(232, 210, 180), sys_bg1: make_color_rgb(182, 144, 108), sys_panel_light: make_color_rgb(252, 242, 226), sys_panel_mid: make_color_rgb(236, 220, 194), sys_panel_dark: make_color_rgb(106, 76, 54), sys_accent: make_color_rgb(170, 112, 70), sys_accent_dark: make_color_rgb(116, 72, 42), sys_box_bg: make_color_rgb(244, 228, 202), sys_slot_bg: make_color_rgb(252, 246, 238), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(124, 94, 72), sys_text_dark: make_color_rgb(62, 42, 28), sys_pattern: "diamond" },
        { sys_name: "Party",   sys_bg0: make_color_rgb(214, 188, 242), sys_bg1: make_color_rgb(162, 122, 212), sys_panel_light: make_color_rgb(246, 236, 255), sys_panel_mid: make_color_rgb(226, 208, 246), sys_panel_dark: make_color_rgb(92, 66, 136), sys_accent: make_color_rgb(182, 108, 236), sys_accent_dark: make_color_rgb(120, 72, 172), sys_box_bg: make_color_rgb(232, 216, 250), sys_slot_bg: make_color_rgb(248, 242, 255), sys_slot_hi: make_color_rgb(255, 244, 192), sys_slot_line: make_color_rgb(120, 92, 160), sys_text_dark: make_color_rgb(54, 38, 86), sys_pattern: "confetti" }
    ];
}

function pc__draw_pattern_shape(_pattern, _cx, _cy, _col, _alpha){
    draw_set_alpha(_alpha);
    draw_set_colour(_col);
    switch (_pattern){
        case "leaf": draw_ellipse(_cx - 7, _cy - 3, _cx + 1, _cy + 5, false); draw_ellipse(_cx - 1, _cy - 5, _cx + 7, _cy + 3, false); break;
        case "bubble": draw_circle(_cx, _cy, 6, false); draw_circle(_cx + 8, _cy - 6, 3, false); break;
        case "cloud": draw_circle(_cx - 4, _cy, 4, false); draw_circle(_cx + 2, _cy - 2, 5, false); draw_circle(_cx + 8, _cy, 4, false); break;
        case "flame": draw_triangle(_cx, _cy - 8, _cx - 6, _cy + 5, _cx + 6, _cy + 5, false); break;
        case "gem":
        case "diamond": draw_triangle(_cx, _cy - 7, _cx - 7, _cy, _cx, _cy + 7, false); draw_triangle(_cx, _cy - 7, _cx + 7, _cy, _cx, _cy + 7, false); break;
        case "window": draw_rectangle(_cx - 7, _cy - 7, _cx + 7, _cy + 7, false); draw_line(_cx, _cy - 7, _cx, _cy + 7); draw_line(_cx - 7, _cy, _cx + 7, _cy); break;
        case "dune": draw_circle(_cx - 4, _cy + 2, 5, false); draw_circle(_cx + 3, _cy + 1, 7, false); break;
        case "snow":
        case "star": draw_line(_cx - 6, _cy, _cx + 6, _cy); draw_line(_cx, _cy - 6, _cx, _cy + 6); draw_line(_cx - 4, _cy - 4, _cx + 4, _cy + 4); draw_line(_cx - 4, _cy + 4, _cx + 4, _cy - 4); break;
        case "heart": draw_circle(_cx - 3, _cy - 2, 3, false); draw_circle(_cx + 3, _cy - 2, 3, false); draw_triangle(_cx - 7, _cy, _cx + 7, _cy, _cx, _cy + 8, false); break;
        case "gear": draw_circle(_cx, _cy, 6, true); draw_circle(_cx, _cy, 3, true); draw_rectangle(_cx - 1, _cy - 9, _cx + 1, _cy - 5, false); draw_rectangle(_cx - 1, _cy + 5, _cx + 1, _cy + 9, false); draw_rectangle(_cx - 9, _cy - 1, _cx - 5, _cy + 1, false); draw_rectangle(_cx + 5, _cy - 1, _cx + 9, _cy + 1, false); break;
        case "petal": draw_ellipse(_cx - 7, _cy - 2, _cx - 1, _cy + 4, false); draw_ellipse(_cx + 1, _cy - 2, _cx + 7, _cy + 4, false); draw_ellipse(_cx - 3, _cy - 7, _cx + 3, _cy - 1, false); draw_ellipse(_cx - 3, _cy + 1, _cx + 3, _cy + 7, false); break;
        case "confetti": draw_rectangle(_cx - 5, _cy - 2, _cx - 1, _cy + 2, false); draw_rectangle(_cx + 1, _cy - 5, _cx + 5, _cy - 1, false); draw_rectangle(_cx + 3, _cy + 2, _cx + 7, _cy + 6, false); break;
    }
    draw_set_alpha(1);
}

function pc__draw_selector_corner(_x1, _y1, _x2, _y2, _col){
    draw_set_colour(_col);
    draw_line(_x1, _y1, _x1 + 8, _y1); draw_line(_x1, _y1, _x1, _y1 + 8);
    draw_line(_x2, _y1, _x2 - 8, _y1); draw_line(_x2, _y1, _x2, _y1 + 8);
    draw_line(_x1, _y2, _x1 + 8, _y2); draw_line(_x1, _y2, _x1, _y2 - 8);
    draw_line(_x2, _y2, _x2 - 8, _y2); draw_line(_x2, _y2, _x2, _y2 - 8);
}

function pc__fit_text_to_width(_txt, _max_w){
    var _out = string(_txt);
    if (string_lower(_out) == "undefined") _out = "Pokemon";
    if (string_width(_out) <= _max_w) return _out;
    var _suffix = ".";
    while (string_length(_out) > 1 && string_width(_out + _suffix) > _max_w) _out = string_delete(_out, string_length(_out), 1);
    return _out + _suffix;
}

function pc__draw_fit_text_scaled(_txt, _x, _y, _max_w, _min_scale, _colour, _halign){
    var _old_halign = draw_get_halign();
    var _text = string(_txt);
    if (string_lower(_text) == "undefined") _text = "Pokemon";

    draw_set_colour(_colour);
    draw_set_halign(_halign);

    var _w = max(1, string_width(_text));
    var _scale = min(1, _max_w / _w);
    _scale = max(0.20, _scale);

    if (_scale < 1){
        draw_text_transformed(_x, _y, _text, _scale, _scale, 0);
    } else {
        draw_text(_x, _y, _text);
    }

    draw_set_halign(_old_halign);
}

function pc__mon_display_name(_mon){
    if (_mon == undefined) return "---";
    _mon = pc__normalize_mon(_mon);
    if (!is_undefined(__party_impl_mon_display_name)){
        try {
            var _party_name = __party_impl_mon_display_name(_mon);
            if (is_string(_party_name) && string_length(_party_name) > 0 && string_lower(_party_name) != "undefined") return _party_name;
        } catch (e_pc_party_name) {}
    }
    if (!is_undefined(mon_display_name)){
        try {
            var _mon_name = mon_display_name(_mon);
            if (is_string(_mon_name) && string_length(_mon_name) > 0 && string_lower(_mon_name) != "undefined") return _mon_name;
        } catch (e_pc_mon_name) {}
    }
    if (variable_struct_exists(_mon, "nickname")){
        var _nickname_raw = variable_struct_get(_mon, "nickname");
        if (!is_undefined(_nickname_raw) && is_string(_nickname_raw) && string_length(_nickname_raw) > 0 && string_lower(_nickname_raw) != "undefined") return _nickname_raw;
    }
    if (variable_struct_exists(_mon, "name")){
        var _name_raw = variable_struct_get(_mon, "name");
        if (!is_undefined(_name_raw) && is_string(_name_raw) && string_length(_name_raw) > 0 && string_lower(_name_raw) != "undefined") return _name_raw;
    }
    var _species_id = -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(variable_struct_get(_mon, "species_id"))) _species_id = floor(variable_struct_get(_mon, "species_id"));
    else if (variable_struct_exists(_mon, "_id") && is_real(variable_struct_get(_mon, "_id"))) _species_id = floor(variable_struct_get(_mon, "_id"));
    if (_species_id > 0 && !is_undefined(scr_poke_name_by_id)){
        try {
            var _species_name = scr_poke_name_by_id(_species_id);
            if (is_string(_species_name) && string_length(_species_name) > 0 && string_lower(_species_name) != "undefined") return _species_name;
        } catch (e_pc_species_name) {}
    }
    if (_species_id > 0) return "Pokemon#" + string(_species_id);
    return "Pokemon";
}

function pc__mon_level(_mon){
    if (_mon == undefined) return 0;
    if (variable_struct_exists(_mon, "level") && is_real(variable_struct_get(_mon, "level"))) return floor(variable_struct_get(_mon, "level"));
    if (variable_struct_exists(_mon, "lvl") && is_real(variable_struct_get(_mon, "lvl"))) return floor(variable_struct_get(_mon, "lvl"));
    return 1;
}


function pc_blocks_player_input(_pid){
    if (is_undefined(pc_is_open)) return false;
    return pc_is_open(_pid);
}

function pc_import_legacy_storage(_pid){
    var _p = pc__pid(_pid);
    var _pc = pc__ensure_state(_p);

    if (!variable_global_exists("PC_STORAGE")) return false;
    if (!is_array(global.PC_STORAGE)) return false;
    if (_p >= array_length(global.PC_STORAGE)) return false;

    var _legacy = global.PC_STORAGE[_p];
    if (!is_struct(_legacy)) return false;
    if (!variable_struct_exists(_legacy, "boxes") || !is_array(variable_struct_get(_legacy, "boxes"))) return false;

    var _legacy_boxes = variable_struct_get(_legacy, "boxes");
    var _imported_any = false;

    for (var _b = 0; _b < array_length(_legacy_boxes); ++_b){
        var _legacy_box = _legacy_boxes[_b];
        if (!is_struct(_legacy_box)) continue;
        if (!variable_struct_exists(_legacy_box, "mons") || !is_array(variable_struct_get(_legacy_box, "mons"))) continue;

        while (array_length(_pc.sys_boxes) <= _b){
            array_push(_pc.sys_boxes, pc__make_box("BOX " + string(array_length(_pc.sys_boxes) + 1), array_length(_pc.sys_boxes) mod max(1, array_length(_pc.sys_theme_defs)), _pc.sys_box_size));
        }

        var _dst_box = _pc.sys_boxes[_b];
        var _legacy_mons = variable_struct_get(_legacy_box, "mons");

        for (var _m = 0; _m < array_length(_legacy_mons); ++_m){
            var _mon = _legacy_mons[_m];
            if (_mon == undefined) continue;

            var _already = false;
            for (var _s = 0; _s < array_length(_dst_box.sys_mons); ++_s){
                if (_dst_box.sys_mons[_s] == _mon){
                    _already = true;
                    break;
                }
            }

            if (!_already){
                var _placed = false;
                for (var _slot = 0; _slot < array_length(_dst_box.sys_mons); ++_slot){
                    if (_dst_box.sys_mons[_slot] == undefined){
                        _dst_box.sys_mons[_slot] = _mon;
                        _placed = true;
                        _imported_any = true;
                        break;
                    }
                }
                if (!_placed){
                    array_push(_dst_box.sys_mons, _mon);
                    _imported_any = true;
                }
            }
        }

        _pc.sys_boxes[_b] = _dst_box;
    }

    return _imported_any;
}

function pc__normalize_mon(_mon){
    if (!is_struct(_mon)) return _mon;

    // IMPORTANT: this must never rebuild the Pokemon from species data.
    // It only fills missing identity/name fields so moves/nickname/current battle state survive.
    if (!is_undefined(party_model_ensure_species_id)){
        try { _mon = party_model_ensure_species_id(_mon); } catch (e_pc_norm_sid) {}
    }

    if (!is_undefined(party_mon_ensure_name)){
        try { _mon = party_mon_ensure_name(_mon); } catch (e_pc_norm_name) {}
    }

    return _mon;
}

function pc_store_mon_to_box_info(_pid, _mon){
    var _p = pc__pid(_pid);
    var _pc = pc__ensure_state(_p);
    if (_mon == undefined) return { ok:false, location:"none", mon:undefined };

    _mon = pc__normalize_mon(_mon);
    pc__remove_exact_mon_reference_except(_p, _mon, "none", -1, -1);

    for (var _b = 0; _b < array_length(_pc.sys_boxes); ++_b){
        var _box = _pc.sys_boxes[_b];
        if (!is_struct(_box)) continue;
        if (!variable_struct_exists(_box, "sys_mons") || !is_array(_box.sys_mons)) _box.sys_mons = [];

        for (var _s = 0; _s < array_length(_box.sys_mons); ++_s){
            if (_box.sys_mons[_s] == undefined){
                _box.sys_mons[_s] = _mon;
                _pc.sys_boxes[_b] = _box;
                _pc.sys_active_box = _b;
                _pc.sys_status_text = pc__mon_display_name(_mon) + " was sent to " + _box.sys_name;
                return { ok:true, location:"pc", box_index:_b, slot_index:_s, mon:_mon };
            }
        }
    }

    var _new_box_index = array_length(_pc.sys_boxes);
    var _theme_index = _new_box_index mod max(1, array_length(_pc.sys_theme_defs));
    var _new_box = pc__make_box("BOX " + string(_new_box_index + 1), _theme_index, _pc.sys_box_size);
    _new_box.sys_mons[0] = _mon;
    array_push(_pc.sys_boxes, _new_box);
    _pc.sys_active_box = _new_box_index;
    _pc.sys_status_text = pc__mon_display_name(_mon) + " was sent to " + _new_box.sys_name;

    return { ok:true, location:"pc", box_index:_new_box_index, slot_index:0, mon:_mon };
}

function pc_set_stored_mon_nickname(_pid, _box_index, _slot_index, _nick){
    var _p = pc__pid(_pid);
    var _pc = pc__ensure_state(_p);

    if (!is_real(_box_index) || !is_real(_slot_index)) return false;
    var _b = floor(_box_index);
    var _s = floor(_slot_index);

    if (_b < 0 || _b >= array_length(_pc.sys_boxes)) return false;
    var _box = _pc.sys_boxes[_b];
    if (!is_struct(_box) || !variable_struct_exists(_box, "sys_mons") || !is_array(_box.sys_mons)) return false;
    if (_s < 0 || _s >= array_length(_box.sys_mons)) return false;

    var _mon = _box.sys_mons[_s];
    if (!is_struct(_mon)) return false;

    _mon = pc__normalize_mon(_mon);
    if (is_string(_nick) && string_length(string_trim(_nick)) > 0) variable_struct_set(_mon, "nickname", string_trim(_nick));
    else variable_struct_set(_mon, "nickname", undefined);

    _box.sys_mons[_s] = _mon;
    _pc.sys_boxes[_b] = _box;
    _pc.sys_status_text = pc__mon_display_name(_mon);

    return true;
}

function pc__write_party_slot(_pid, _slot, _mon){
    var _p = pc__pid(_pid);
    var _s = floor(_slot);
    if (_s < 0) return false;

    if (!variable_global_exists("PARTY")) global.PARTY = [];
    if (!is_array(global.PARTY)) global.PARTY = [];
    if (array_length(global.PARTY) <= _p) array_resize(global.PARTY, _p + 1);

    var _P = global.PARTY[_p];
    if (!is_struct(_P)){
        _P = { open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0, mons:[], sum_move_sel:0, sum_learn_sel:0 };
        global.PARTY[_p] = _P;
    }

    if (!variable_struct_exists(_P, "mons") || !is_array(_P.mons)) _P.mons = [];
    var _mons = _P.mons;
    if (array_length(_mons) <= _s) array_resize(_mons, _s + 1);

    if (is_struct(_mon)){
        _mon = pc__normalize_mon(_mon);
        _mons[_s] = _mon;
    } else {
        // Emptying a party slot must also hit the real global.PARTY array.
        _mons[_s] = undefined;
    }

    while (array_length(_mons) > 0 && _mons[array_length(_mons) - 1] == undefined){
        array_resize(_mons, array_length(_mons) - 1);
    }

    _P.mons = _mons;
    global.PARTY[_p] = _P;
    return true;
}

function pc__mon_name(_mon){
    if (!is_struct(_mon)) return "Pokemon";

    if (variable_struct_exists(_mon, "nickname")){
        var _nick = variable_struct_get(_mon, "nickname");
        if (is_string(_nick) && string_length(string_trim(_nick)) > 0) return string_trim(_nick);
    }

    if (!is_undefined(mon_display_name)){
        var _display = mon_display_name(_mon);
        if (is_string(_display) && string_length(string_trim(_display)) > 0 && string(_display) != "???") return string_trim(_display);
    }

    if (variable_struct_exists(_mon, "name")){
        var _name = variable_struct_get(_mon, "name");
        if (is_string(_name) && string_length(string_trim(_name)) > 0 && string(_name) != "???") return string_trim(_name);
    }

    var _sid = -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(variable_struct_get(_mon, "species_id"))) _sid = variable_struct_get(_mon, "species_id");
    else if (variable_struct_exists(_mon, "species") && is_real(variable_struct_get(_mon, "species"))) _sid = variable_struct_get(_mon, "species");
    else if (variable_struct_exists(_mon, "id") && is_real(variable_struct_get(_mon, "id"))) _sid = variable_struct_get(_mon, "id");
    else if (variable_struct_exists(_mon, "_id") && is_real(variable_struct_get(_mon, "_id"))) _sid = variable_struct_get(_mon, "_id");

    if (is_real(_sid) && _sid > 0 && !is_undefined(scr_poke_name_by_id)){
        var _species_name = scr_poke_name_by_id(_sid);
        if (is_string(_species_name) && string_length(string_trim(_species_name)) > 0) return string_trim(_species_name);
    }

    return "Pokemon";
}

function pc__held_active_box_index(_pid){
    var _pc = pc__ensure_state(_pid);
    var _box_count = 0;
    if (variable_struct_exists(_pc, "sys_boxes") && is_array(_pc.sys_boxes)) _box_count = array_length(_pc.sys_boxes);

    var _box_index = 0;
    if (variable_struct_exists(_pc, "sys_active_box") && is_real(_pc.sys_active_box)) _box_index = floor(_pc.sys_active_box);
    else if (variable_struct_exists(_pc, "sys_box_index") && is_real(_pc.sys_box_index)) _box_index = floor(_pc.sys_box_index);
    else if (variable_struct_exists(_pc, "sys_box") && is_real(_pc.sys_box)) _box_index = floor(_pc.sys_box);

    if (_box_count <= 0) return 0;
    return clamp(_box_index, 0, _box_count - 1);
}

function pc__get_slot_mon(_pid, _area, _box_index, _slot_index){
    var _pc = pc__ensure_state(_pid);
    var _idx = floor(_slot_index);
    if (_idx < 0) return undefined;

    if (_area == "party"){
        var _party = pc__get_party_array(_pid);
        if (_idx >= 0 && _idx < array_length(_party)) return _party[_idx];
        return undefined;
    }

    var _b = floor(_box_index);
    if (_b < 0 || _b >= array_length(_pc.sys_boxes)) return undefined;

    var _box = _pc.sys_boxes[_b];
    if (!is_struct(_box) || !variable_struct_exists(_box, "sys_mons") || !is_array(_box.sys_mons)) return undefined;
    if (_idx >= 0 && _idx < array_length(_box.sys_mons)) return _box.sys_mons[_idx];

    return undefined;
}

function pc__set_slot_mon(_pid, _area, _box_index, _slot_index, _mon){
    var _pc = pc__ensure_state(_pid);
    var _idx = floor(_slot_index);
    if (_idx < 0) return false;

    if (_mon != undefined) _mon = pc__normalize_mon(_mon);

    if (_area == "party"){
        return pc__write_party_slot(_pid, _idx, _mon);
    }

    var _b = floor(_box_index);
    if (_b < 0 || _b >= array_length(_pc.sys_boxes)) return false;

    var _box = _pc.sys_boxes[_b];
    if (!is_struct(_box)) return false;
    if (!variable_struct_exists(_box, "sys_mons") || !is_array(_box.sys_mons)) _box.sys_mons = [];
    if (_idx >= array_length(_box.sys_mons)) array_resize(_box.sys_mons, _idx + 1);

    _box.sys_mons[_idx] = _mon;
    _pc.sys_boxes[_b] = _box;
    return true;
}

function pc__remove_exact_mon_reference_except(_pid, _mon, _keep_area, _keep_box, _keep_index){
    if (!is_struct(_mon)) return 0;

    var _removed = 0;
    var _pc = pc__ensure_state(_pid);

    // Party exact-reference cleanup.
    var _party = pc__get_party_array(_pid);
    for (var _pi = 0; _pi < array_length(_party); ++_pi){
        var _is_keep_party = ((_keep_area == "party" || _keep_area == "breed_party") && _pi == _keep_index);
        if (!_is_keep_party && _party[_pi] == _mon){
            pc__write_party_slot(_pid, _pi, undefined);
            _removed += 1;
        }
    }

    // Box exact-reference cleanup.
    for (var _b = 0; _b < array_length(_pc.sys_boxes); ++_b){
        var _box = _pc.sys_boxes[_b];
        if (!is_struct(_box) || !variable_struct_exists(_box, "sys_mons") || !is_array(_box.sys_mons)) continue;

        for (var _si = 0; _si < array_length(_box.sys_mons); ++_si){
            var _is_keep_box = (_keep_area == "box" && _b == _keep_box && _si == _keep_index);
            if (!_is_keep_box && _box.sys_mons[_si] == _mon){
                _box.sys_mons[_si] = undefined;
                _removed += 1;
            }
        }

        _pc.sys_boxes[_b] = _box;
    }

    pc__ensure_breeding_state(_pid);
    for (var _bs = 0; _bs < 12; ++_bs){
        var _is_keep_breed = ((_keep_area == "breed_slot" || (_keep_area == "party" && pc__is_breeding_mode(_pid))) && _bs == _keep_index);
        if (!_is_keep_breed && _pc.sys_breed_slots[_bs] == _mon){
            _pc.sys_breed_slots[_bs] = undefined;
            _removed += 1;
        }
    }
    pc__breeding_refresh_all_pairs(_pid);

    return _removed;
}

function pc__dedupe_exact_mon_references(_pid){
    var _pc = pc__ensure_state(_pid);
    var _seen = [];
    var _removed = 0;

    var _party = pc__get_party_array(_pid);
    for (var _pi = 0; _pi < array_length(_party); ++_pi){
        var _party_mon = _party[_pi];
        if (!is_struct(_party_mon)) continue;

        var _seen_party = false;
        for (var _sp = 0; _sp < array_length(_seen); ++_sp){
            if (_seen[_sp] == _party_mon){ _seen_party = true; break; }
        }

        if (_seen_party){
            pc__write_party_slot(_pid, _pi, undefined);
            _removed += 1;
        } else {
            array_push(_seen, _party_mon);
        }
    }

    for (var _b = 0; _b < array_length(_pc.sys_boxes); ++_b){
        var _box = _pc.sys_boxes[_b];
        if (!is_struct(_box) || !variable_struct_exists(_box, "sys_mons") || !is_array(_box.sys_mons)) continue;

        for (var _si = 0; _si < array_length(_box.sys_mons); ++_si){
            var _box_mon = _box.sys_mons[_si];
            if (!is_struct(_box_mon)) continue;

            var _seen_box = false;
            for (var _sb = 0; _sb < array_length(_seen); ++_sb){
                if (_seen[_sb] == _box_mon){ _seen_box = true; break; }
            }

            if (_seen_box){
                _box.sys_mons[_si] = undefined;
                _removed += 1;
            } else {
                array_push(_seen, _box_mon);
            }
        }

        _pc.sys_boxes[_b] = _box;
    }

    pc__ensure_breeding_state(_pid);
    for (var _bsi = 0; _bsi < 12; ++_bsi){
        var _breed_mon = _pc.sys_breed_slots[_bsi];
        if (!is_struct(_breed_mon)) continue;
        var _seen_breed = false;
        for (var _sbr = 0; _sbr < array_length(_seen); ++_sbr){
            if (_seen[_sbr] == _breed_mon){ _seen_breed = true; break; }
        }
        if (_seen_breed){
            _pc.sys_breed_slots[_bsi] = undefined;
            _removed += 1;
        } else {
            array_push(_seen, _breed_mon);
        }
    }
    pc__breeding_refresh_all_pairs(_pid);

    if (_removed > 0) _pc.sys_status_text = "Cleaned duplicate Pokemon";
    return _removed;
}

function pc__is_breeding_mode(_pid){
    var _pc = pc__ensure_state(_pid);
    return (variable_struct_exists(_pc, "sys_mode") && string(_pc.sys_mode) == "breeding");
}

function pc__is_egg_mode(_pid){
    var _pc = pc__ensure_state(_pid);
    return (variable_struct_exists(_pc, "sys_mode") && string(_pc.sys_mode) == "eggs");
}

function pc__ensure_breeding_state(_pid){
    var _pc = pc__ensure_state(_pid);
    if (!variable_struct_exists(_pc, "sys_breed_slots") || !is_array(_pc.sys_breed_slots)) _pc.sys_breed_slots = [];
    if (array_length(_pc.sys_breed_slots) < 12) array_resize(_pc.sys_breed_slots, 12);
    if (!variable_struct_exists(_pc, "sys_breed_wait_battles") || !is_array(_pc.sys_breed_wait_battles)) _pc.sys_breed_wait_battles = [];
    if (array_length(_pc.sys_breed_wait_battles) < 6) array_resize(_pc.sys_breed_wait_battles, 6);
    for (var _wi = 0; _wi < 6; ++_wi) if (!is_real(_pc.sys_breed_wait_battles[_wi])) _pc.sys_breed_wait_battles[_wi] = -1;
    if (!variable_struct_exists(_pc, "sys_breed_heart") || !is_array(_pc.sys_breed_heart)) _pc.sys_breed_heart = [];
    if (array_length(_pc.sys_breed_heart) < 6) array_resize(_pc.sys_breed_heart, 6);
    for (var _hi = 0; _hi < 6; ++_hi) if (!is_bool(_pc.sys_breed_heart[_hi])) _pc.sys_breed_heart[_hi] = false;
    if (!variable_struct_exists(_pc, "sys_breed_pair_key") || !is_array(_pc.sys_breed_pair_key)) _pc.sys_breed_pair_key = [];
    if (array_length(_pc.sys_breed_pair_key) < 6) array_resize(_pc.sys_breed_pair_key, 6);
    for (var _ki = 0; _ki < 6; ++_ki) if (!is_string(_pc.sys_breed_pair_key[_ki])) _pc.sys_breed_pair_key[_ki] = "";
    if (!variable_struct_exists(_pc, "sys_breed_source")) _pc.sys_breed_source = "box";
    if (!variable_struct_exists(_pc, "sys_egg_box") || !is_array(_pc.sys_egg_box)) _pc.sys_egg_box = [];
    return _pc;
}

function pc__breeding_pair_index_from_slot(_slot){
    if (!is_real(_slot)) return 0;
    return clamp(floor(floor(_slot) / 2), 0, 5);
}

function pc__breeding_toggle_source(_pid){
    var _pc = pc__ensure_breeding_state(_pid);
    var _cur = variable_struct_exists(_pc, "sys_breed_source") ? string(_pc.sys_breed_source) : "box";
    _pc.sys_breed_source = (_cur == "party") ? "box" : "party";
    _pc.sys_cursor_area = "box";
    _pc.sys_cursor_index = 0;
    _pc.sys_status_text = (_pc.sys_breed_source == "party") ? "Picking from party." : "Picking from PC box.";
    return true;
}

function pc__breeding_species_id(_mon){
    if (!is_struct(_mon)) return -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(_mon.species_id)) return floor(_mon.species_id);
    if (variable_struct_exists(_mon, "id") && is_real(_mon.id)) return floor(_mon.id);
    if (variable_struct_exists(_mon, "_id") && is_real(_mon._id)) return floor(_mon._id);
    return -1;
}

function pc__breeding_sex(_mon){
    if (!is_struct(_mon)) return "";
    if (!is_undefined(pokemon_factory_normalize_sex)){
        if (variable_struct_exists(_mon, "sex")){
            var _sx = pokemon_factory_normalize_sex(_mon.sex);
            if (string_length(_sx) > 0) return _sx;
        }
        if (variable_struct_exists(_mon, "gender")){
            var _gx = pokemon_factory_normalize_sex(_mon.gender);
            if (string_length(_gx) > 0) return _gx;
        }
    }
    if (variable_struct_exists(_mon, "sex_id") && is_real(_mon.sex_id)){
        if (floor(_mon.sex_id) == 1) return "female";
        if (floor(_mon.sex_id) == 2) return "male";
    }
    if (variable_struct_exists(_mon, "gender_id") && is_real(_mon.gender_id)){
        if (floor(_mon.gender_id) == 1) return "female";
        if (floor(_mon.gender_id) == 2) return "male";
    }
    return "";
}

function pc__breeding_sex_symbol(_mon){
    var _sex = pc__breeding_sex(_mon);
    if (_sex == "male") return "M";
    if (_sex == "female") return "F";
    return "?";
}

function pc__breeding_load_tables(){
    if (variable_global_exists("_breeding_egg_groups") && is_array(global._breeding_egg_groups)) return true;

    global._breeding_egg_groups = [];
    global._breeding_base_species = [];
    global._breeding_hatch_counter = [];

    var _path_groups = working_directory + "/data/csv/pokemon_egg_groups.csv";
    var _g = load_csv(_path_groups);
    if (_g != -1){
        var _h = ds_grid_height(_g);
        var _max_sid = 0;
        for (var _r = 1; _r < _h; ++_r){
            var _sid = __to_int_safe(__grid(_g, 0, _r, 0), 0);
            if (_sid > _max_sid) _max_sid = _sid;
        }
        array_resize(global._breeding_egg_groups, _max_sid + 1);
        for (var _r2 = 1; _r2 < _h; ++_r2){
            var _sid2 = __to_int_safe(__grid(_g, 0, _r2, 0), 0);
            var _eg = __to_int_safe(__grid(_g, 1, _r2, 0), 0);
            if (_sid2 <= 0 || _eg <= 0) continue;
            var _arr = global._breeding_egg_groups[_sid2];
            if (!is_array(_arr)) _arr = [];
            array_push(_arr, _eg);
            global._breeding_egg_groups[_sid2] = _arr;
        }
        ds_grid_destroy(_g);
    }

    var _path_species = working_directory + "/data/csv/pokemon_species.csv";
    var _sgrid = load_csv(_path_species);
    if (_sgrid != -1){
        var _sh = ds_grid_height(_sgrid);
        var _ci_id = __col_find_ci(_sgrid, "id");
        var _ci_evolves = __col_find_ci(_sgrid, "evolves_from_species_id");
        var _ci_hatch = __col_find_ci(_sgrid, "hatch_counter");
        var _max_species = 0;
        for (var _sr = 1; _sr < _sh; ++_sr){
            var _ssid = __to_int_safe(__grid(_sgrid, _ci_id, _sr, 0), 0);
            if (_ssid > _max_species) _max_species = _ssid;
        }
        array_resize(global._breeding_base_species, _max_species + 1);
        array_resize(global._breeding_hatch_counter, _max_species + 1);
        for (var _init = 0; _init < array_length(global._breeding_base_species); ++_init) global._breeding_base_species[_init] = _init;

        for (var _sr2 = 1; _sr2 < _sh; ++_sr2){
            var _sid3 = __to_int_safe(__grid(_sgrid, _ci_id, _sr2, 0), 0);
            if (_sid3 <= 0) continue;
            var _parent = (_ci_evolves >= 0) ? __to_int_safe(__grid(_sgrid, _ci_evolves, _sr2, 0), 0) : 0;
            if (_parent > 0) global._breeding_base_species[_sid3] = _parent;
            if (_ci_hatch >= 0) global._breeding_hatch_counter[_sid3] = __to_int_safe(__grid(_sgrid, _ci_hatch, _sr2, 20), 20);
        }
        var _changed = true;
        var _guard = 0;
        while (_changed && _guard < 16){
            _changed = false;
            _guard += 1;
            for (var _bi = 1; _bi < array_length(global._breeding_base_species); ++_bi){
                var _p = global._breeding_base_species[_bi];
                if (is_real(_p) && _p > 0 && _p < array_length(global._breeding_base_species) && global._breeding_base_species[_p] != _p){
                    global._breeding_base_species[_bi] = global._breeding_base_species[_p];
                    _changed = true;
                }
            }
        }
        ds_grid_destroy(_sgrid);
    }

    return true;
}

function pc__breeding_groups_for_species(_sid){
    pc__breeding_load_tables();
    var _s = is_real(_sid) ? floor(_sid) : -1;
    if (_s >= 0 && variable_global_exists("_breeding_egg_groups") && is_array(global._breeding_egg_groups) && _s < array_length(global._breeding_egg_groups)){
        var _arr = global._breeding_egg_groups[_s];
        if (is_array(_arr)) return _arr;
    }
    return [];
}

function pc__breeding_share_egg_group(_sid_a, _sid_b){
    var _a = pc__breeding_groups_for_species(_sid_a);
    var _b = pc__breeding_groups_for_species(_sid_b);
    for (var _i = 0; _i < array_length(_a); ++_i){
        var _ga = _a[_i];
        if (_ga == 15) continue;
        for (var _j = 0; _j < array_length(_b); ++_j){
            if (_ga == _b[_j] && _b[_j] != 15) return true;
        }
    }
    return false;
}

function pc__breeding_is_male_female_pair(_a, _b){
    if (!is_struct(_a) || !is_struct(_b)) return false;
    var _sexa = pc__breeding_sex(_a);
    var _sexb = pc__breeding_sex(_b);
    return ((_sexa == "male" && _sexb == "female") || (_sexa == "female" && _sexb == "male"));
}

function pc__breeding_compatibility(_a, _b){
    if (!is_struct(_a) || !is_struct(_b)) return { ok:false, reason:"Need two Pokemon." };
    if (variable_struct_exists(_a, "is_egg") && _a.is_egg == true) return { ok:false, reason:"Eggs cannot breed." };
    if (variable_struct_exists(_b, "is_egg") && _b.is_egg == true) return { ok:false, reason:"Eggs cannot breed." };

    var _sa = pc__breeding_species_id(_a);
    var _sb = pc__breeding_species_id(_b);
    if (_sa <= 0 || _sb <= 0) return { ok:false, reason:"Missing species." };

    var _sexa = pc__breeding_sex(_a);
    var _sexb = pc__breeding_sex(_b);
    if (!((_sexa == "male" && _sexb == "female") || (_sexa == "female" && _sexb == "male"))) return { ok:false, reason:"Need one male and one female." };
    if (!pc__breeding_share_egg_group(_sa, _sb)) return { ok:false, reason:"Egg groups do not match." };

    var _female = (_sexa == "female") ? _a : _b;
    var _child = pc__breeding_base_child_species(pc__breeding_species_id(_female));
    var _wait = (_sa == _sb) ? 2 : 4;
    var _child_nature = pc__breeding_choose_child_nature(_a, _b);
    return { ok:true, reason:"The pair gets along.", child_species:_child, child_nature:_child_nature, wait_battles:_wait };
}

function pc__breeding_base_child_species(_sid){
    pc__breeding_load_tables();
    var _s = is_real(_sid) ? floor(_sid) : -1;
    if (_s > 0 && variable_global_exists("_breeding_base_species") && is_array(global._breeding_base_species) && _s < array_length(global._breeding_base_species)){
        var _base = global._breeding_base_species[_s];
        if (is_real(_base) && _base > 0) return floor(_base);
    }
    return _s;
}

function pc__breeding_mon_nature(_mon){
    if (!is_struct(_mon)) return "";
    if (variable_struct_exists(_mon, "nature") && is_string(_mon.nature) && string_length(string(_mon.nature)) > 0) return string(_mon.nature);
    return "";
}

function pc__breeding_mon_holds_everstone(_mon){
    if (!is_struct(_mon)) return false;
    if (variable_struct_exists(_mon, "held_item_id") && is_real(_mon.held_item_id) && floor(_mon.held_item_id) == 206) return true;
    var _held_name = "";
    if (variable_struct_exists(_mon, "held_item_real_name")) _held_name = string_lower(string(_mon.held_item_real_name));
    else if (variable_struct_exists(_mon, "held_item_name")) _held_name = string_lower(string(_mon.held_item_name));
    return (_held_name == "everstone");
}

function pc__breeding_choose_child_nature(_a, _b){
    var _choices = [];
    if (pc__breeding_mon_holds_everstone(_a)){
        var _na = pc__breeding_mon_nature(_a);
        if (string_length(_na) > 0) array_push(_choices, _na);
    }
    if (pc__breeding_mon_holds_everstone(_b)){
        var _nb = pc__breeding_mon_nature(_b);
        if (string_length(_nb) > 0) array_push(_choices, _nb);
    }
    if (array_length(_choices) > 0) return _choices[irandom(array_length(_choices) - 1)];
    if (!is_undefined(scr_nature_random_name)) return scr_nature_random_name();
    return "Hardy";
}

function pc__breeding_pair_key(_a, _b){
    if (!is_struct(_a) || !is_struct(_b)) return "";
    var _ida = variable_struct_exists(_a, "idno") ? string(_a.idno) : string(pc__breeding_species_id(_a)) + ":" + pc__breeding_sex(_a);
    var _idb = variable_struct_exists(_b, "idno") ? string(_b.idno) : string(pc__breeding_species_id(_b)) + ":" + pc__breeding_sex(_b);
    return _ida + "|" + _idb;
}

function pc__breeding_refresh_pair(_pid, _pair_index = 0){
    var _pc = pc__ensure_breeding_state(_pid);
    var _pair = clamp(floor(_pair_index), 0, 5);
    var _slot_a = _pair * 2;
    var _a = _pc.sys_breed_slots[_slot_a];
    var _b = _pc.sys_breed_slots[_slot_a + 1];
    var _compat = pc__breeding_compatibility(_a, _b);
    _pc.sys_breed_heart[_pair] = _compat.ok == true;

    if (_compat.ok == true){
        var _key = pc__breeding_pair_key(_a, _b);
        variable_struct_set(_compat, "pair_index", _pair);
        variable_struct_set(_compat, "pair_key", _key);
        if (_pc.sys_breed_pair_key[_pair] != _key || _pc.sys_breed_wait_battles[_pair] < 0){
            _pc.sys_breed_pair_key[_pair] = _key;
            _pc.sys_breed_wait_battles[_pair] = _compat.wait_battles;
        }
        if (pc__is_breeding_mode(_pid) && pc__breeding_pair_index_from_slot(_pc.sys_cursor_index) == _pair) _pc.sys_status_text = "Pair " + string(_pair + 1) + ": " + _compat.reason;
    } else {
        _pc.sys_breed_pair_key[_pair] = "";
        _pc.sys_breed_wait_battles[_pair] = -1;
        if (pc__is_breeding_mode(_pid) && pc__breeding_pair_index_from_slot(_pc.sys_cursor_index) == _pair) _pc.sys_status_text = "Pair " + string(_pair + 1) + ": " + _compat.reason;
    }
    return _compat;
}

function pc__breeding_refresh_all_pairs(_pid){
    var _last = undefined;
    for (var _pair = 0; _pair < 6; ++_pair){
        _last = pc__breeding_refresh_pair(_pid, _pair);
    }
    return _last;
}

function pc__egg_count(_pid){
    var _pc = pc__ensure_breeding_state(_pid);
    var _count = 0;
    for (var _i = 0; _i < array_length(_pc.sys_egg_box); ++_i){
        if (is_struct(_pc.sys_egg_box[_i])) _count += 1;
    }
    return _count;
}

function pc__egg_first_empty_slot(_pid){
    var _pc = pc__ensure_breeding_state(_pid);
    for (var _i = 0; _i < array_length(_pc.sys_egg_box); ++_i){
        if (!is_struct(_pc.sys_egg_box[_i])) return _i;
    }
    if (array_length(_pc.sys_egg_box) < 30){
        array_push(_pc.sys_egg_box, undefined);
        return array_length(_pc.sys_egg_box) - 1;
    }
    return -1;
}

function pc__breeding_hatch_battles_for_species(_sid){
    pc__breeding_load_tables();
    var _counter = 20;
    if (variable_global_exists("_breeding_hatch_counter") && is_array(global._breeding_hatch_counter) && _sid >= 0 && _sid < array_length(global._breeding_hatch_counter)){
        if (is_real(global._breeding_hatch_counter[_sid])) _counter = max(1, floor(global._breeding_hatch_counter[_sid]));
    }
    return clamp(ceil(_counter / 5), 3, 10);
}

function pc__breeding_make_egg(_pid, _compat){
    var _slot = pc__egg_first_empty_slot(_pid);
    if (_slot < 0) return false;

    var _child = (is_struct(_compat) && variable_struct_exists(_compat, "child_species") && is_real(_compat.child_species)) ? floor(_compat.child_species) : 1;
    var _nature = (is_struct(_compat) && variable_struct_exists(_compat, "child_nature") && is_string(_compat.child_nature) && string_length(_compat.child_nature) > 0) ? string(_compat.child_nature) : (is_undefined(scr_nature_random_name) ? "Hardy" : scr_nature_random_name());
    var _egg = {
        is_egg: true,
        species_id: _child,
        id: _child,
        species: "Egg",
        name: "Egg",
        level: 1,
        nature: _nature,
        hatch_battles_remaining: pc__breeding_hatch_battles_for_species(_child),
        player_born: true,
        bred_in_pc: true,
        parent_key: (is_struct(_compat) && variable_struct_exists(_compat, "pair_key")) ? _compat.pair_key : ""
    };

    var _pc = pc__ensure_breeding_state(_pid);
    _pc.sys_egg_box[_slot] = _egg;
    _pc.sys_status_text = "An Egg was found in the Egg Box.";
    if (!is_undefined(sfx_play_safe)) sfx_play_safe(snd_Receive_Egg, 1);
    return true;
}

function pc__breeding_recalculate_stats(_mon){
    if (!is_struct(_mon)) return _mon;
    var _sid = pc__breeding_species_id(_mon);
    var _stats = (!is_undefined(scr_poke_stats) && _sid > 0) ? scr_poke_stats(_sid) : undefined;
    if (is_undefined(_stats)) return _mon;
    if (!is_undefined(scr_init_mon_iv_ev)) scr_init_mon_iv_ev(_mon);

    var _iv = (variable_struct_exists(_mon, "iv") && is_struct(_mon.iv)) ? _mon.iv : { hp:0, atk:0, def:0, spa:0, spd:0, spe:0 };
    var _ev = (variable_struct_exists(_mon, "ev") && is_struct(_mon.ev)) ? _mon.ev : { hp:0, atk:0, def:0, spa:0, spd:0, spe:0 };
    var _lvl = (variable_struct_exists(_mon, "level") && is_real(_mon.level)) ? max(1, floor(_mon.level)) : 1;
    var _nature = pc__breeding_mon_nature(_mon);
    if (string_length(_nature) <= 0 && !is_undefined(scr_nature_random_name)){
        _nature = scr_nature_random_name();
        _mon.nature = _nature;
    }

    var _keys = ["hp","atk","def","spa","spd","spe"];
    for (var _i = 0; _i < array_length(_keys); ++_i){
        var _k = _keys[_i];
        var _base = (variable_struct_exists(_stats, _k) && is_real(variable_struct_get(_stats, _k))) ? floor(variable_struct_get(_stats, _k)) : 10;
        var _ivv = (variable_struct_exists(_iv, _k) && is_real(variable_struct_get(_iv, _k))) ? floor(variable_struct_get(_iv, _k)) : 0;
        var _evv = (variable_struct_exists(_ev, _k) && is_real(variable_struct_get(_ev, _k))) ? floor(variable_struct_get(_ev, _k)) : 0;
        var _is_hp = (_k == "hp");
        var _value = (!is_undefined(scr_compute_stat)) ? scr_compute_stat(_base, _ivv, _evv, _lvl, _is_hp) : max(1, floor((_base * 2 + _ivv + floor(_evv / 4)) * _lvl / 100) + (_is_hp ? _lvl + 10 : 5));
        if (!_is_hp && !is_undefined(scr_nature_multiplier)) _value = max(1, floor(_value * scr_nature_multiplier(_nature, _k)));
        if (_is_hp){
            _mon.hp_max = _value;
            _mon.maxhp = _value;
            _mon.hp = _value;
            _mon.hp_now = _value;
        } else {
            variable_struct_set(_mon, _k, _value);
        }
    }
    return _mon;
}

function pc__breeding_apply_player_born_boost(_mon){
    if (!is_struct(_mon)) return _mon;
    if (!is_undefined(scr_init_mon_iv_ev)) scr_init_mon_iv_ev(_mon);

    var _iv = (variable_struct_exists(_mon, "iv") && is_struct(_mon.iv)) ? _mon.iv : { hp:0, atk:0, def:0, spa:0, spd:0, spe:0 };
    var _ev = (variable_struct_exists(_mon, "ev") && is_struct(_mon.ev)) ? _mon.ev : { hp:0, atk:0, def:0, spa:0, spd:0, spe:0 };
    var _keys = ["hp","atk","def","spa","spd","spe"];
    for (var _i = 0; _i < array_length(_keys); ++_i){
        var _k = _keys[_i];
        var _ivv = (variable_struct_exists(_iv, _k) && is_real(variable_struct_get(_iv, _k))) ? floor(variable_struct_get(_iv, _k)) : 0;
        variable_struct_set(_iv, _k, max(_ivv, 20));
        variable_struct_set(_ev, _k, 32);
    }
    _mon.iv = _iv;
    _mon.ev = _ev;
    _mon.ev_total = 192;
    _mon.player_born = true;
    _mon.player_born_bonus = true;
    _mon.bred_in_pc = true;
    return pc__breeding_recalculate_stats(_mon);
}

function pc__breeding_hatch_egg(_pid, _egg){
    if (!is_struct(_egg)) return false;
    var _sid = (variable_struct_exists(_egg, "species_id") && is_real(_egg.species_id)) ? floor(_egg.species_id) : 1;
    var _mon = undefined;
    if (!is_undefined(pokemon_factory_create)) _mon = pokemon_factory_create(_sid, 1, { pid:_pid, pokeball_item_id:4 });
    if (!is_struct(_mon)) return false;
    if (variable_struct_exists(_egg, "nature") && is_string(_egg.nature) && string_length(_egg.nature) > 0) _mon.nature = string(_egg.nature);
    _mon = pc__breeding_apply_player_born_boost(_mon);
    var _info = pc_store_mon_to_box_info(_pid, _mon);
    return (is_struct(_info) && variable_struct_exists(_info, "ok") && _info.ok == true);
}

function pc_breeding_on_battle_complete(_pid){
    var _pc = pc__ensure_breeding_state(_pid);

    for (var _i = 0; _i < array_length(_pc.sys_egg_box); ++_i){
        var _egg = _pc.sys_egg_box[_i];
        if (!is_struct(_egg)) continue;
        if (!variable_struct_exists(_egg, "hatch_battles_remaining") || !is_real(_egg.hatch_battles_remaining)) _egg.hatch_battles_remaining = 5;
        _egg.hatch_battles_remaining -= 1;
        if (_egg.hatch_battles_remaining <= 0){
            if (pc__breeding_hatch_egg(_pid, _egg)){
                _pc.sys_egg_box[_i] = undefined;
                _pc.sys_status_text = "An Egg hatched and moved to a Box.";
            } else {
                _egg.hatch_battles_remaining = 1;
                _pc.sys_egg_box[_i] = _egg;
            }
        } else {
            _pc.sys_egg_box[_i] = _egg;
        }
    }

    for (var _pair = 0; _pair < 6; ++_pair){
        var _compat = pc__breeding_refresh_pair(_pid, _pair);
        if (is_struct(_compat) && _compat.ok == true){
            _pc.sys_breed_wait_battles[_pair] -= 1;
            if (_pc.sys_breed_wait_battles[_pair] <= 0){
                if (pc__breeding_make_egg(_pid, _compat)) _pc.sys_breed_wait_battles[_pair] = _compat.wait_battles;
                else _pc.sys_breed_wait_battles[_pair] = 1;
            }
        }
    }
    return true;
}

function pc__clear_held_state(_pc){
    _pc.sys_held_mon = undefined;
    _pc.sys_held_from_area = "";
    _pc.sys_held_from_box = -1;
    _pc.sys_held_from_index = -1;

    // Legacy cleanup from earlier broken patches. Keep these cleared so code cannot
    // accidentally read stale origin values.
    _pc.sys_held_origin_area = "";
    _pc.sys_held_origin_box = -1;
    _pc.sys_held_origin_index = -1;
}
