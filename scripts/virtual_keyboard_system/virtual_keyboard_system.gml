globalvar VKEYBOARD;

function __vk_layout_rows(){
    return [
        ["a","b","c","d","e","f","g","h","i","j"],
        ["k","l","m","n","o","p","q","r","s","t"],
        ["u","v","w","x","y","z","-","'",".","0"],
        ["1","2","3","4","5","6","7","8","9","SPACE"],
        ["SHIFT","CAPS","DEL","OK","SKIP"]
    ];
}

function __vk_default_state(){
    return {
        requested: false,
        active: false,
        phase: "idle",
        pid: 0,
        species_name: "Pokemon",
        title: "Nickname",
        text: "",
        max_len: 12,
        store_info: undefined,
        prompt_sel: 0,
        cursor_row: 0,
        cursor_col: 0,
        caps_lock: false,
        shift_once: false,
        next_input_ms: 0,
        keyboard_latch: "",
        keyboard_snapshot: ""
    };
}

function virtual_keyboard_init(){
    VKEYBOARD = [__vk_default_state(), __vk_default_state()];
}

function virtual_keyboard_ensure(_pid){
    if (!variable_global_exists("VKEYBOARD") || !is_array(VKEYBOARD)) VKEYBOARD = [];
    if (array_length(VKEYBOARD) <= _pid) array_resize(VKEYBOARD, _pid + 1);
    if (!is_struct(VKEYBOARD[_pid])) VKEYBOARD[_pid] = __vk_default_state();
    return VKEYBOARD[_pid];
}

function virtual_keyboard_is_active(_pid){
    var _S = virtual_keyboard_ensure(_pid);
    return is_struct(_S) && variable_struct_exists(_S, "active") && variable_struct_get(_S, "active") == true;
}

function virtual_keyboard_blocks_input(_pid){
    var _S = virtual_keyboard_ensure(_pid);
    if (!is_struct(_S)) return false;
    if (variable_struct_exists(_S, "requested") && variable_struct_get(_S, "requested") == true) return true;
    if (variable_struct_exists(_S, "active") && variable_struct_get(_S, "active") == true) return true;
    return false;
}

function virtual_keyboard_request_caught_nickname(_pid, _store_info, _species_name){
    if (!is_struct(_store_info) || !variable_struct_exists(_store_info, "ok") || variable_struct_get(_store_info, "ok") != true) return false;
    var _S = virtual_keyboard_ensure(_pid);
    variable_struct_set(_S, "requested", true);
    variable_struct_set(_S, "active", false);
    variable_struct_set(_S, "phase", "wait_dialog");
    variable_struct_set(_S, "pid", _pid);
    variable_struct_set(_S, "species_name", string(_species_name));
    variable_struct_set(_S, "title", "Give a nickname?");
    variable_struct_set(_S, "text", "");
    variable_struct_set(_S, "store_info", _store_info);
    variable_struct_set(_S, "prompt_sel", 0);
    variable_struct_set(_S, "cursor_row", 0);
    variable_struct_set(_S, "cursor_col", 0);
    variable_struct_set(_S, "caps_lock", false);
    variable_struct_set(_S, "shift_once", false);
    variable_struct_set(_S, "next_input_ms", current_time + 180);
    variable_struct_set(_S, "keyboard_latch", "");
    variable_struct_set(_S, "keyboard_snapshot", "");
    return true;
}

function __vk_token(_row, _col){
    var _rows = __vk_layout_rows();
    if (_row < 0 || _row >= array_length(_rows)) return "";
    var _cells = _rows[_row];
    if (!is_array(_cells) || _col < 0 || _col >= array_length(_cells)) return "";
    return string(_cells[_col]);
}

function __vk_clamp_cursor(_S){
    if (!is_struct(_S)) return;
    var _rows = __vk_layout_rows();
    var _row = clamp(variable_struct_get(_S, "cursor_row"), 0, array_length(_rows) - 1);
    var _cells = _rows[_row];
    var _col = clamp(variable_struct_get(_S, "cursor_col"), 0, array_length(_cells) - 1);
    variable_struct_set(_S, "cursor_row", _row);
    variable_struct_set(_S, "cursor_col", _col);
}

function __vk_accept_char(_ch){
    if (!is_string(_ch) || string_length(_ch) <= 0) return false;
    var _ord = ord(_ch);
    if (_ord >= ord("0") && _ord <= ord("9")) return true;
    if (_ord >= ord("A") && _ord <= ord("Z")) return true;
    if (_ord >= ord("a") && _ord <= ord("z")) return true;
    if (_ch == " " || _ch == "-" || _ch == "'" || _ch == ".") return true;
    return false;
}

function __vk_alpha_char(_ch){
    if (!is_string(_ch) || string_length(_ch) != 1) return false;
    var _ord = ord(_ch);
    if (_ord >= ord("A") && _ord <= ord("Z")) return true;
    if (_ord >= ord("a") && _ord <= ord("z")) return true;
    return false;
}

function __vk_char_output(_S, _ch){
    if (!is_struct(_S) || !is_string(_ch) || string_length(_ch) <= 0) return _ch;
    if (!__vk_alpha_char(_ch)) return _ch;
    var _use_upper = false;
    if (variable_struct_exists(_S, "caps_lock") && variable_struct_get(_S, "caps_lock") == true) _use_upper = !_use_upper;
    if (variable_struct_exists(_S, "shift_once") && variable_struct_get(_S, "shift_once") == true) _use_upper = !_use_upper;
    return _use_upper ? string_upper(_ch) : string_lower(_ch);
}

function __vk_consume_shift(_S, _ch){
    if (!is_struct(_S) || !is_string(_ch) || string_length(_ch) <= 0) return;
    if (!__vk_alpha_char(_ch)) return;
    if (variable_struct_exists(_S, "shift_once") && variable_struct_get(_S, "shift_once") == true){
        variable_struct_set(_S, "shift_once", false);
    }
}

function __vk_display_token(_S, _token){
    if (!is_struct(_S)) return _token;
    if (_token == "SHIFT") return (variable_struct_get(_S, "shift_once") == true) ? "Shift*" : "Shift";
    if (_token == "CAPS") return (variable_struct_get(_S, "caps_lock") == true) ? "Caps*" : "Caps";
    return __vk_char_output(_S, _token);
}

function __vk_physical_keyboard_owner_pid(){
    if (!variable_global_exists("VKEYBOARD") || !is_array(VKEYBOARD)) return -1;
    for (var _pid = 0; _pid < array_length(VKEYBOARD); ++_pid){
        var _S = VKEYBOARD[_pid];
        if (!is_struct(_S)) continue;
        if (!variable_struct_exists(_S, "active") || variable_struct_get(_S, "active") != true) continue;
        if (!variable_struct_exists(_S, "phase") || string(variable_struct_get(_S, "phase")) != "entry") continue;
        return _pid;
    }
    return -1;
}

function __vk_append_text(_S, _ch){
    if (!is_struct(_S) || !__vk_accept_char(_ch)) return;
    var _txt = string(variable_struct_get(_S, "text"));
    var _max = (variable_struct_exists(_S, "max_len") && is_real(variable_struct_get(_S, "max_len"))) ? floor(variable_struct_get(_S, "max_len")) : 12;
    if (string_length(_txt) >= _max) return;
    var _out = __vk_char_output(_S, string(_ch));
    variable_struct_set(_S, "text", _txt + _out);
    __vk_consume_shift(_S, _out);
}

function __vk_backspace(_S){
    if (!is_struct(_S)) return;
    var _txt = string(variable_struct_get(_S, "text"));
    var _len = string_length(_txt);
    if (_len <= 0) return;
    variable_struct_set(_S, "text", string_delete(_txt, _len, 1));
}

function __vk_finish(_pid, _apply_name){
    var _S = virtual_keyboard_ensure(_pid);
    var _species_name = string(variable_struct_get(_S, "species_name"));
    var _txt = string_trim(string(variable_struct_get(_S, "text")));
    var _store_info = variable_struct_get(_S, "store_info");
    if (_apply_name && is_struct(_store_info) && !is_undefined(party_model_set_stored_mon_nickname)){
        party_model_set_stored_mon_nickname(_pid, _store_info, _txt);
        if (string_length(_txt) > 0){
            try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, _species_name + " was nicknamed\n" + _txt + "!"); } catch (e_vk_done) {}
        }
    }
    VKEYBOARD[_pid] = __vk_default_state();
}

function __vk_handle_prompt(_pid, _S){
    var _now = current_time;
    if (_now < variable_struct_get(_S, "next_input_ms")) return;
    if (!is_undefined(controls_pressed) && (controls_pressed(_pid, "MoveLeft") || controls_pressed(_pid, "MoveRight"))){
        variable_struct_set(_S, "prompt_sel", 1 - floor(variable_struct_get(_S, "prompt_sel")));
        variable_struct_set(_S, "next_input_ms", _now + 120);
        return;
    }
    if (!is_undefined(controls_pressed) && controls_pressed(_pid, "Interact")){
        if (floor(variable_struct_get(_S, "prompt_sel")) == 0){
            variable_struct_set(_S, "phase", "entry");
            variable_struct_set(_S, "next_input_ms", _now + 140);
            variable_struct_set(_S, "keyboard_latch", "");
            variable_struct_set(_S, "keyboard_snapshot", "");
            try { keyboard_string = ""; } catch (e_vk_clear_string) {}
        } else {
            __vk_finish(_pid, false);
        }
        return;
    }
    if (!is_undefined(controls_pressed) && (controls_pressed(_pid, "Run") || controls_pressed(_pid, "Back"))){
        __vk_finish(_pid, false);
    }
}

function __vk_handle_physical_keyboard(_pid, _S){
    if (!is_struct(_S)) return;
    if (__vk_physical_keyboard_owner_pid() != _pid) return;
    var _now = current_time;
    if (_now < variable_struct_get(_S, "next_input_ms")) return;

    var _kb_text = "";
    try { _kb_text = string(keyboard_string); } catch (e_vk_string) { _kb_text = ""; }
    var _snapshot = string(variable_struct_get(_S, "keyboard_snapshot"));
    if (string_length(_kb_text) < string_length(_snapshot)) _snapshot = "";
    if (string_length(_kb_text) > string_length(_snapshot)){
        var _delta = string_copy(_kb_text, string_length(_snapshot) + 1, string_length(_kb_text) - string_length(_snapshot));
        for (var _di = 1; _di <= string_length(_delta); ++_di){
            var _ch = string_copy(_delta, _di, 1);
            if (__vk_accept_char(_ch)) __vk_append_text(_S, _ch);
        }
    }
    variable_struct_set(_S, "keyboard_snapshot", _kb_text);
    if (keyboard_check_pressed(vk_backspace)) __vk_backspace(_S);
    if (keyboard_check_pressed(vk_enter)) __vk_finish(variable_struct_get(_S, "pid"), true);
    if (keyboard_check_pressed(vk_escape)) __vk_finish(variable_struct_get(_S, "pid"), false);
}

function __vk_handle_grid_token(_pid, _S, _token){
    if (!is_struct(_S)) return;
    if (_token == "SPACE") { __vk_append_text(_S, " "); return; }
    if (_token == "SHIFT") { variable_struct_set(_S, "shift_once", variable_struct_get(_S, "shift_once") != true); return; }
    if (_token == "CAPS") { variable_struct_set(_S, "caps_lock", variable_struct_get(_S, "caps_lock") != true); return; }
    if (_token == "DEL") { __vk_backspace(_S); return; }
    if (_token == "OK") { __vk_finish(_pid, true); return; }
    if (_token == "SKIP") { __vk_finish(_pid, false); return; }
    __vk_append_text(_S, _token);
}

function __vk_handle_entry(_pid, _S){
    var _now = current_time;
    if (_now < variable_struct_get(_S, "next_input_ms")) return;

    if (!is_undefined(controls_pressed) && controls_pressed(_pid, "MoveLeft")){
        variable_struct_set(_S, "cursor_col", variable_struct_get(_S, "cursor_col") - 1);
        __vk_clamp_cursor(_S);
        variable_struct_set(_S, "next_input_ms", _now + 110);
        return;
    }
    if (!is_undefined(controls_pressed) && controls_pressed(_pid, "MoveRight")){
        variable_struct_set(_S, "cursor_col", variable_struct_get(_S, "cursor_col") + 1);
        __vk_clamp_cursor(_S);
        variable_struct_set(_S, "next_input_ms", _now + 110);
        return;
    }
    if (!is_undefined(controls_pressed) && controls_pressed(_pid, "MoveUp")){
        variable_struct_set(_S, "cursor_row", variable_struct_get(_S, "cursor_row") - 1);
        __vk_clamp_cursor(_S);
        variable_struct_set(_S, "next_input_ms", _now + 110);
        return;
    }
    if (!is_undefined(controls_pressed) && controls_pressed(_pid, "MoveDown")){
        variable_struct_set(_S, "cursor_row", variable_struct_get(_S, "cursor_row") + 1);
        __vk_clamp_cursor(_S);
        variable_struct_set(_S, "next_input_ms", _now + 110);
        return;
    }
    if (!is_undefined(controls_pressed) && controls_pressed(_pid, "Interact")){
        __vk_handle_grid_token(_pid, _S, __vk_token(variable_struct_get(_S, "cursor_row"), variable_struct_get(_S, "cursor_col")));
        variable_struct_set(_S, "next_input_ms", _now + 120);
        return;
    }
    if (!is_undefined(controls_pressed) && (controls_pressed(_pid, "Run") || controls_pressed(_pid, "Back"))){
        __vk_backspace(_S);
        variable_struct_set(_S, "next_input_ms", _now + 120);
        return;
    }
    __vk_handle_physical_keyboard(_pid, _S);
}

function virtual_keyboard_update(_pid){
    var _S = virtual_keyboard_ensure(_pid);
    if (!is_struct(_S)) return;

    if (variable_struct_get(_S, "requested") == true && variable_struct_get(_S, "active") != true){
        if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)) return;
        variable_struct_set(_S, "active", true);
        variable_struct_set(_S, "phase", "prompt");
        variable_struct_set(_S, "next_input_ms", current_time + 160);
    }

    if (variable_struct_get(_S, "active") != true) return;

    var _phase = string(variable_struct_get(_S, "phase"));
    if (_phase == "prompt") {
        __vk_handle_prompt(_pid, _S);
        return;
    }
    if (_phase == "entry") {
        __vk_handle_entry(_pid, _S);
    }
}

function virtual_keyboard_draw_gui(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    virtual_keyboard_draw_gui_rect(_pid, 0, 0, _gw, _gh);
}

function virtual_keyboard_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    var _S = virtual_keyboard_ensure(_pid);
    if (!is_struct(_S) || variable_struct_get(_S, "active") != true) return;

    var _s = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _ox = _rx + (_rw - 240 * _s) div 2;
    var _oy = _ry + (_rh - 160 * _s) div 2;

    draw_set_alpha(0.78);
    draw_set_color(c_black);
    draw_rectangle(_rx, _ry, _rx + _rw, _ry + _rh, false);
    draw_set_alpha(1);

    draw_set_color(make_color_rgb(232, 232, 216));
    draw_rectangle(_ox + 16 * _s, _oy + 12 * _s, _ox + 224 * _s, _oy + 148 * _s, false);
    draw_set_color(make_color_rgb(56, 56, 56));
    draw_rectangle(_ox + 20 * _s, _oy + 16 * _s, _ox + 220 * _s, _oy + 144 * _s, true);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(make_color_rgb(48, 48, 48));
    draw_text(_ox + 26 * _s, _oy + 20 * _s, string(variable_struct_get(_S, "title")));
    draw_text(_ox + 26 * _s, _oy + 34 * _s, string(variable_struct_get(_S, "species_name")));

    draw_set_color(c_white);
    draw_rectangle(_ox + 24 * _s, _oy + 48 * _s, _ox + 216 * _s, _oy + 64 * _s, false);
    draw_set_color(make_color_rgb(48, 48, 48));
    var _txt = string(variable_struct_get(_S, "text"));
    draw_text(_ox + 28 * _s, _oy + 52 * _s, _txt + ((current_time div 300 mod 2 == 0 && string(variable_struct_get(_S, "phase")) == "entry") ? "_" : ""));

    if (string(variable_struct_get(_S, "phase")) == "prompt"){
        var _sel = floor(variable_struct_get(_S, "prompt_sel"));
        var _labels = ["YES", "NO"];
        for (var _i = 0; _i < 2; ++_i){
            var _bx0 = _ox + (48 + _i * 72) * _s;
            var _by0 = _oy + 88 * _s;
            draw_set_color((_i == _sel) ? make_color_rgb(72, 136, 224) : make_color_rgb(208, 208, 208));
            draw_rectangle(_bx0, _by0, _bx0 + 56 * _s, _by0 + 18 * _s, false);
            draw_set_color((_i == _sel) ? c_white : make_color_rgb(48, 48, 48));
            draw_text(_bx0 + 16 * _s, _by0 + 4 * _s, _labels[_i]);
        }
        return;
    }

    var _rows = __vk_layout_rows();
    var _cur_row = floor(variable_struct_get(_S, "cursor_row"));
    var _cur_col = floor(variable_struct_get(_S, "cursor_col"));
    for (var _r = 0; _r < array_length(_rows); ++_r){
        var _cells = _rows[_r];
        for (var _c = 0; _c < array_length(_cells); ++_c){
            var _token = string(_cells[_c]);
            var _label = __vk_display_token(_S, _token);
            var _cell_w = (string_length(_label) > 1 ? max(22, string_length(_label) * 6) : 14);
            var _x0 = _ox + (24 + _c * 18) * _s;
            if (_r == 4) _x0 = _ox + (20 + _c * 40) * _s;
            var _y0 = _oy + (76 + _r * 14) * _s;
            if (_r == 4) _y0 = _oy + 132 * _s;
            var _sel_cell = (_r == _cur_row && _c == _cur_col);
            draw_set_color(_sel_cell ? make_color_rgb(72, 136, 224) : make_color_rgb(208, 208, 208));
            draw_rectangle(_x0, _y0, _x0 + _cell_w * _s, _y0 + 12 * _s, false);
            draw_set_color(_sel_cell ? c_white : make_color_rgb(40, 40, 40));
            draw_text(_x0 + 3 * _s, _y0 + 2 * _s, _label);
        }
    }
}
