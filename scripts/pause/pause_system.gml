// ============================================================================
// Pause Menu (Emerald-style) — 2 players, drawn per camera
// Entries: [0] Pokémon, [1] Bag, [2] Options, [3] Save
// ============================================================================

globalvar PAUSE;

function pause_init(){
    global.PAUSE = [
        { open:false, sel:0, t:0 },
        { open:false, sel:0, t:0 }
    ];

    // safe legacy owner setup
    if (!variable_global_exists("PAUSE_OWNER")) global.PAUSE_OWNER = 0;
}



function pause_toggle(pid){
    var p = global.PAUSE[pid];
    p.open = !p.open;
    if (p.open){ p.sel = 0; p.t = 0; }
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

        // toggle
        if (controls_pressed(pid,"Pause")){
            pause_toggle(pid);
            continue;
        }
        if (!p.open) continue;
        p.t++;

        // grid nav (2x2)
        if (controls_pressed(pid,"MoveRight")) p.sel = (p.sel % 2 == 0) ? p.sel + 1 : p.sel;
        if (controls_pressed(pid,"MoveLeft"))  p.sel = (p.sel % 2 == 1) ? p.sel - 1 : p.sel;
        if (controls_pressed(pid,"MoveDown"))  p.sel = (p.sel < 2) ? p.sel + 2 : p.sel;
        if (controls_pressed(pid,"MoveUp"))    p.sel = (p.sel >= 2) ? p.sel - 2 : p.sel;

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
				case 2: __pause_do_options(pid); break;
				case 3: __pause_do_save(pid); break;
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

    // Panel
    var px = ox + 16*s, py = oy + 16*s, pw = 240*s - 32*s, ph = 160*s - 32*s;

    draw_set_color(make_color_rgb(72,80,96));
    draw_roundrect(px, py, px+pw, py+ph, false);
    draw_set_color(make_color_rgb(28,32,44));
    draw_roundrect(px-1, py-1, px+pw+1, py+ph+1, true);

    // Header bar
    var head_h = 28*s;
    draw_set_color(make_color_rgb(52,60,76));
    draw_roundrect(px+6, py+6, px+pw-6, py+head_h, false);

    // "MENU" — WHITE, moved down 4px from header top
    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);
    draw_text(px + 16, py + 6 + 4, "MENU"); // +4px vertical nudge

    // 2x2 entries
    var pad    = 12*s;
    var cell_w = (pw - pad*3) * 0.5;
    var cell_h = (ph - head_h - pad*3) * 0.5;
    var labels = ["POKEMON","BAG","OPTIONS","SAVE"];
    var p      = global.PAUSE[_pid];

    // Label measure (safe)
    var line_h = max(12, string_height("A") + 2);

    for (var i = 0; i < 4; i++){
        var col = i mod 2, row = i div 2;
        var cx  = px + pad + col * (cell_w + pad);
        var cy  = py + head_h + pad + row * (cell_h + pad);
        var sel = (i == p.sel);

        // Card fill + border
        draw_set_color(sel ? make_color_rgb(120,160,220) : make_color_rgb(236,228,184));
        draw_roundrect(cx, cy, cx + cell_w, cy + cell_h, false);

        draw_set_color(sel ? make_color_rgb(40,64,168) : make_color_rgb(52,60,76));
        draw_roundrect(cx-1, cy-1, cx + cell_w+1, cy + cell_h+1, true);

        // Label — WHITE (no black anywhere)
        draw_set_color(c_white);
        var tx = cx + (cell_w - string_width(labels[i])) * 0.5;
        var ty = cy + (cell_h - line_h) * 0.5;
        draw_text(tx, ty, labels[i]);
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
    // Example: cycle dialog speed 1-3 and persist
    if (!variable_global_exists("DIALOG_SPEED")) global.DIALOG_SPEED = 2;
    global.DIALOG_SPEED = (global.DIALOG_SPEED % 3) + 1;

    // if you have controls_save(), persist speed
    ini_open(working_directory + "/options.ini");
    ini_write_real("Dialog","speed", global.DIALOG_SPEED);
    ini_close();
    pause_toggle(pid);
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
	


/// Legacy: who last toggled pause (for dialog system checks)
function pause_set_owner(_pid){ global.PAUSE_OWNER = _pid; }





