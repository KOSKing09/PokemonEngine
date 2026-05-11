// ============================================================================
// Pause Menu (Emerald-style) — 2 players, drawn per camera
// Entries: [0] Pokemon, [1] Bag, [2] Poke-Index, [3] Options, [4] Save
// ============================================================================

globalvar PAUSE;

function pause_init(){
    global.PAUSE = [
        { open:false, sel:0, t:0, mode:"main", options_sel:0, input_sel:0, multiplayer_sel:0 },
        { open:false, sel:0, t:0, mode:"main", options_sel:0, input_sel:0, multiplayer_sel:0 }
    ];

    // safe legacy owner setup
    if (!variable_global_exists("PAUSE_OWNER")) global.PAUSE_OWNER = 0;
}



function pause_toggle(pid){
    var p = global.PAUSE[pid];
    var _opening = !p.open;
    p.open = _opening;
    if (_opening){
        p.sel = 0;
        p.t = 0;
        p.mode = "main";
        p.options_sel = 0;
        p.input_sel = 0;
        p.multiplayer_sel = 0;
    }
    pause_set_owner(pid); // record owner for dialog’s legacy check
}

function pause_is_open(pid){
    return (variable_global_exists("PAUSE") && global.PAUSE[pid].open);
}
// Put in your pause script (once)
globalvar PAUSE_OWNER;
if (!variable_global_exists("PAUSE_OWNER")) global.PAUSE_OWNER = 0;

/// Both players paused?
function world_is_paused_both(){
    return (variable_global_exists("PAUSE")
         && is_array(global.PAUSE)
         && array_length(global.PAUSE) >= 2
         && global.PAUSE[0].open && global.PAUSE[1].open);
}


function pause_update(){
    for (var pid = 0; pid < 2; pid++){
        var p = PAUSE[pid];
        var _main_labels = __pause_main_labels(pid);
        var _entry_count = array_length(_main_labels);
        var _options_count = 5;
        var _input_count = 2;
        var _multiplayer_count = 5;

        // toggle
        if (controls_pressed(pid,"Pause")){
            if (pid == 1 && !multiplayer_player_joined(1)){
                multiplayer_spawn_player(1);
                continue;
            }
            pause_toggle(pid);
            continue;
        }
        if (!p.open) continue;
        p.t++;

        if (!variable_global_exists("DIALOG_SPEED")) global.DIALOG_SPEED = 2;

        if (string(p.mode) == "input"){
            if (controls_pressed(pid,"MoveDown")) p.input_sel = (p.input_sel + 1) mod _input_count;
            if (controls_pressed(pid,"MoveUp")){
                p.input_sel -= 1;
                if (p.input_sel < 0) p.input_sel = _input_count - 1;
            }

            if (p.input_sel == 0){
                if (controls_pressed(pid,"MoveLeft")) __pause_adjust_deadzone(-0.05);
                if (controls_pressed(pid,"MoveRight")) __pause_adjust_deadzone(0.05);
            }

            if (controls_pressed(pid,"Interact")){
                switch (p.input_sel){
                    case 0:
                        __pause_adjust_deadzone(0.05);
                        break;
                    case 1:
                        p.mode = "options";
                        p.input_sel = 0;
                        break;
                }
            }

            if (controls_pressed(pid,"Run") || controls_pressed(pid,"Back")){
                p.mode = "options";
                p.input_sel = 0;
            }
            continue;
        }

        if (string(p.mode) == "options"){
            if (controls_pressed(pid,"MoveDown") || controls_pressed(pid,"MoveRight")) p.options_sel = (p.options_sel + 1) mod _options_count;
            if (controls_pressed(pid,"MoveUp") || controls_pressed(pid,"MoveLeft")){
                p.options_sel -= 1;
                if (p.options_sel < 0) p.options_sel = _options_count - 1;
            }

            if (p.options_sel == 1){
                if (controls_pressed(pid,"MoveLeft")) __pause_adjust_dialog_speed(-1);
                if (controls_pressed(pid,"MoveRight")) __pause_adjust_dialog_speed(1);
            }
            if (p.options_sel == 2){
                if (controls_pressed(pid,"MoveLeft") || controls_pressed(pid,"MoveRight")) __pause_toggle_splitscreen_layout();
            }

            if (controls_pressed(pid,"Interact")){
                switch (p.options_sel){
                    case 0:
                        p.mode = "input";
                        p.input_sel = 0;
                        break;
                    case 1:
                        __pause_adjust_dialog_speed(1);
                        break;
                    case 2:
                        __pause_toggle_splitscreen_layout();
                        break;
                    case 3:
                        p.mode = "multiplayer";
                        p.multiplayer_sel = 0;
                        break;
                    case 4:
                        p.mode = "main";
                        p.options_sel = 0;
                        break;
                }
            }

            if (controls_pressed(pid,"Run") || controls_pressed(pid,"Back")){
                p.mode = "main";
                p.options_sel = 0;
            }
            continue;
        }

        if (string(p.mode) == "multiplayer"){
            if (controls_pressed(pid,"MoveDown") || controls_pressed(pid,"MoveRight")) p.multiplayer_sel = (p.multiplayer_sel + 1) mod _multiplayer_count;
            if (controls_pressed(pid,"MoveUp") || controls_pressed(pid,"MoveLeft")){
                p.multiplayer_sel -= 1;
                if (p.multiplayer_sel < 0) p.multiplayer_sel = _multiplayer_count - 1;
            }

            if (p.multiplayer_sel == 0 && (controls_pressed(pid,"MoveLeft") || controls_pressed(pid,"MoveRight"))) multiplayer_toggle_queue_mode();
            if (p.multiplayer_sel == 1 && (controls_pressed(pid,"MoveLeft") || controls_pressed(pid,"MoveRight"))) multiplayer_toggle_request_pid();
            if (p.multiplayer_sel == 2 && (controls_pressed(pid,"MoveLeft") || controls_pressed(pid,"MoveRight"))) multiplayer_toggle_versus_format();

            if (controls_pressed(pid,"Interact")){
                switch (p.multiplayer_sel){
                    case 0:
                        multiplayer_toggle_queue_mode();
                        break;
                    case 1:
                        multiplayer_toggle_request_pid();
                        break;
                    case 2:
                        multiplayer_toggle_versus_format();
                        break;
                    case 3:
                        __pause_do_multiplayer_versus(pid);
                        break;
                    case 4:
                        p.mode = "options";
                        p.multiplayer_sel = 0;
                        break;
                }
            }

            if (controls_pressed(pid,"Run") || controls_pressed(pid,"Back")){
                p.mode = "options";
                p.multiplayer_sel = 0;
            }
            continue;
        }

        // Emerald-style vertical list navigation.
        if (controls_pressed(pid,"MoveDown") || controls_pressed(pid,"MoveRight")) p.sel = (p.sel + 1) mod _entry_count;
        if (controls_pressed(pid,"MoveUp") || controls_pressed(pid,"MoveLeft")){
            p.sel -= 1;
            if (p.sel < 0) p.sel = _entry_count - 1;
        }

		// choose
		if (controls_pressed(pid,"Interact")){
			switch (p.sel){
				case 0: // Pokémon
					pause_toggle(pid); // close pause
					party_open(pid);   // THEN open party
					break;
				case 1: // Bag
					pause_toggle(pid);
					bag_open(pid);
					break;
                case 2: __pause_do_poke_index(pid); break;
                case 3: __pause_do_options(pid); break;
                case 4: __pause_do_save(pid); break;
                case 5: __pause_do_drop_out(pid); break;
			}
		}



        // cancel
        if (controls_pressed(pid,"Run")) pause_toggle(pid);
    }
}
	
/// pause_draw_gui_rect(pid, rx, ry, rw, rh)
/// Draws Emerald-style pause menu into a target GUI rect. All text = WHITE.
function pause_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!pause_is_open(_pid)) return;

    // Fit 240x160 into the rect (same approach as your bag)
    var s  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var ox = _rx + (_rw - 240 * s) div 2;
    var oy = _ry + (_rh - 160 * s) div 2;

    // Background dim (within this rect only)
    draw_set_alpha(0.35);
    draw_set_color(c_black);
    draw_rectangle(_rx, _ry, _rx + _rw, _ry + _rh, false);
    draw_set_alpha(1);

    var labels = __pause_main_labels(_pid);
    var options_labels = ["INPUT","TEXT SPEED","SPLIT","MULTIPLAYER","BACK"];
    var multiplayer_labels = ["QUEUE","REQUEST SIDE","VERSUS FORMAT","START VERSUS","BACK"];
    var input_labels = ["DEADZONE","BACK"];
    var p = global.PAUSE[_pid];
    var line_h = max(12, string_height("A") + 2);

    // Emerald-style narrow menu column, tucked into the top-right of the logical screen.
    var item_gap = 4*s;
    var top_pad = 10*s;
    var bottom_pad = 10*s;
    var left_pad = 18*s;
    var right_pad = 16*s;
    var pointer_w = 12*s;
    var item_h = max(16*s, line_h + 4*s);
    var _active_labels = labels;
    var _active_sel = p.sel;
    var _title = "MENU";
    if (string(p.mode) == "options"){
        _active_labels = options_labels;
        _active_sel = p.options_sel;
        _title = "OPTIONS";
    } else if (string(p.mode) == "multiplayer"){
        _active_labels = multiplayer_labels;
        _active_sel = p.multiplayer_sel;
        _title = "MULTIPLAYER";
    } else if (string(p.mode) == "input"){
        _active_labels = input_labels;
        _active_sel = p.input_sel;
        _title = "INPUT";
    }
    var longest_label = 0;
    for (var _i = 0; _i < array_length(_active_labels); ++_i){
        longest_label = max(longest_label, string_width(_active_labels[_i]));
    }
    if (string(p.mode) == "options") {
        longest_label = max(longest_label, string_width(__pause_dialog_speed_label()));
        longest_label = max(longest_label, string_width(__pause_splitscreen_label()));
    }
    if (string(p.mode) == "multiplayer") {
        longest_label = max(longest_label, string_width(__pause_multiplayer_queue_label()));
        longest_label = max(longest_label, string_width(__pause_multiplayer_request_label()));
        longest_label = max(longest_label, string_width(__pause_multiplayer_versus_label()));
    }
    if (string(p.mode) == "input") longest_label = max(longest_label, string_width(__pause_deadzone_label()));
    var pw = left_pad + pointer_w + longest_label + right_pad;
    var ph = top_pad + bottom_pad + array_length(_active_labels) * item_h + (array_length(_active_labels) - 1) * item_gap;
    var px = ox + 240*s - pw - 10*s;
    var py = oy + 10*s;

    draw_set_color(make_color_rgb(236, 228, 184));
    draw_roundrect(px, py, px + pw, py + ph, false);
    draw_set_color(make_color_rgb(52, 60, 76));
    draw_roundrect(px - 1, py - 1, px + pw + 1, py + ph + 1, true);

    // "MENU" — WHITE title above the command list.
    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);
    draw_text(px + 10*s, py + 4*s, _title);

    for (var i = 0; i < array_length(_active_labels); i++){
        var row_y = py + top_pad + i * (item_h + item_gap);
        var sel = (i == _active_sel);
        if (sel){
            draw_set_color(make_color_rgb(120, 160, 220));
            draw_roundrect(px + 8*s, row_y - 1*s, px + pw - 8*s, row_y + item_h - 1*s, false);
            draw_set_color(make_color_rgb(40, 64, 168));
            draw_roundrect(px + 7*s, row_y - 2*s, px + pw - 7*s, row_y + item_h, true);
        }

        var pointer_x = px + 12*s;
        var pointer_y = row_y + max(0, (item_h - line_h) * 0.5) + 5*s;
        draw_set_color(c_white);
        if (sel) draw_text(pointer_x, pointer_y, "> ");
        var tx = px + left_pad + pointer_w;
        var ty = row_y + max(0, (item_h - line_h) * 0.5) + 5*s;
        var _label_text = _active_labels[i];
        if (string(p.mode) == "options" && i == 1) _label_text = __pause_dialog_speed_label();
        if (string(p.mode) == "options" && i == 2) _label_text = __pause_splitscreen_label();
        if (string(p.mode) == "multiplayer" && i == 0) _label_text = __pause_multiplayer_queue_label();
        if (string(p.mode) == "multiplayer" && i == 1) _label_text = __pause_multiplayer_request_label();
        if (string(p.mode) == "multiplayer" && i == 2) _label_text = __pause_multiplayer_versus_label();
        if (string(p.mode) == "input" && i == 0) _label_text = __pause_deadzone_label();
        draw_text(tx, ty, _label_text);
    }
}

	
/// pause_draw_gui(pid) — single-player wrapper (full GUI)
function pause_draw_gui(_pid){
    var gw = display_get_gui_width();
    var gh = display_get_gui_height();
    pause_draw_gui_rect(_pid, 0, 0, gw, gh);
}




// --- ACTION HANDLERS (stub these as you build features) ---------------------
/// Called when selecting Pokémon from pause
function __pause_do_pokemon(pid){
    var P = party_ensure(pid);

    // Open party screen
    P.open       = true;
    P.mode       = "list";
    P.menu_sel   = 0;
    P.swap_index = -1;

    // Lock inputs for a couple frames to prevent instant close
    P.lock = 2;

    // Close pause menu itself
    pause_toggle(pid);
}





function __pause_do_options(pid){
    var p = global.PAUSE[pid];
    p.mode = "options";
    p.options_sel = 0;
}

function __pause_main_labels(_pid){
    var _labels = ["POKEMON","BAG","POKE-INDEX","OPTIONS","SAVE"];
    if (_pid == 1 && multiplayer_player_joined(1)) array_push(_labels, "DROP OUT");
    return _labels;
}

function __pause_do_poke_index(pid){
    pause_toggle(pid);
    try {
        if (!is_undefined(dialog2p_show_now)) {
            dialog2p_show_now(pid, { text: "Poke-Index menu coming soon." });
            return;
        }
    } catch (e_poke_index_dialog) {}
    try { show_debug_message("[pause] Poke-Index menu coming soon."); } catch (e_poke_index_dbg) {}
}

function __pause_do_save(pid){
    // Minimal stub save (extend with your data)
    var path = working_directory + "/save_slot_" + string(pid) + ".ini";
    ini_open(path);
    ini_write_real("Meta","version", 1);
    ini_write_real("Dialog","speed", global.DIALOG_SPEED);
    ini_close();
    pause_toggle(pid);
}

function __pause_adjust_dialog_speed(_dir){
    if (!variable_global_exists("DIALOG_SPEED")) global.DIALOG_SPEED = 2;
    var _step = (is_real(_dir) ? floor(_dir) : 1);
    if (_step == 0) _step = 1;
    global.DIALOG_SPEED += _step;
    if (global.DIALOG_SPEED > 3) global.DIALOG_SPEED = 1;
    if (global.DIALOG_SPEED < 1) global.DIALOG_SPEED = 3;
    if (!is_undefined(controls_save)) controls_save();
}

function __pause_do_drop_out(_pid){
    if (_pid != 1) return false;
    if (multiplayer_battle_open()){
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Finish the current battle before dropping out.");
        return false;
    }
    var _dropped = multiplayer_drop_player(1);
    if (_dropped) pause_toggle(_pid);
    return _dropped;
}

function __pause_do_multiplayer_versus(_pid){
    if (!multiplayer_player_joined(1)){
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Player 2 can drop in with Start before versus is available.");
        return false;
    }
    return multiplayer_start_versus_battle(_pid);
}

function __pause_multiplayer_queue_label(){
    return "QUEUE " + string_upper(multiplayer_queue_mode());
}

function __pause_multiplayer_request_label(){
    return "CO-OP SCREEN P" + string(multiplayer_request_pid() + 1);
}

function __pause_multiplayer_versus_label(){
    return "VERSUS " + string_upper(multiplayer_versus_format());
}

function __pause_dialog_speed_label(){
    var _label = "TEXT SPEED";
    var _suffix = "MID";
    if (!variable_global_exists("DIALOG_SPEED")) global.DIALOG_SPEED = 2;
    switch (clamp(global.DIALOG_SPEED, 1, 3)){
        case 1: _suffix = "SLOW"; break;
        case 2: _suffix = "MID"; break;
        case 3: _suffix = "FAST"; break;
    }
    return _label + " " + _suffix;
}

function __pause_adjust_deadzone(_delta){
    if (!variable_global_exists("CTRL") || !is_struct(CTRL)) return;
    var _step = (is_real(_delta) ? _delta : 0);
    CTRL.deadzone = clamp(CTRL.deadzone + _step, 0.05, 0.95);
    if (!is_undefined(controls_save)) controls_save();
}

function __pause_deadzone_label(){
    var _pct = 25;
    if (variable_global_exists("CTRL") && is_struct(CTRL) && is_real(CTRL.deadzone)) _pct = round(CTRL.deadzone * 100);
    return "DEADZONE " + string(_pct) + "%";
}

function __pause_toggle_splitscreen_layout(){
    if (!is_undefined(splitscreen_toggle_layout)) splitscreen_toggle_layout();
}

function __pause_splitscreen_label(){
    if (!is_undefined(splitscreen_layout_label)) return splitscreen_layout_label();
    return "SPLIT VERT";
}
	


/// Legacy: who last toggled pause (for dialog system checks)
function pause_set_owner(_pid){ global.PAUSE_OWNER = _pid; }




