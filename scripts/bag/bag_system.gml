/// bags_init() — create per-player bag structs and sample data
function bags_init() {
    if (!variable_global_exists("BAGS")) global.BAGS = [];
    var _players = max(1, (variable_global_exists("PAUSE_PLAYERS_ACTIVE") ? global.PAUSE_PLAYERS_ACTIVE : 1));
    array_resize(global.BAGS, _players);

    for (var _pid = 0; _pid < _players; _pid++) {
        var _b = {
            open: false,
            mode: "bag",       // "bag" or "equip"
            page: 0,           // 0=Items, 1=Pokéballs, 2=TM/HM, 3=Berries, 4=Key Items
            sel:  0,
            scroll: 0,
            spin_ticks: 0,
            // five pages (arrays)
            items: [ [], [], [], [], [] ]
        };

        // --- demo content you can remove/replace ---
        _b.items[0] = [
            { name:"Potion",        qty: 5, desc:"Restores 20 HP.",            icon: spr_item_placeholder },
            { name:"Antidote",      qty: 3, desc:"Cures poison.",              icon: spr_item_placeholder },
            { name:"Repel",         qty: 2, desc:"Repels weak Pokémon.",       icon: spr_item_placeholder },
        ];
        _b.items[1] = [
            { name:"Poké Ball",     qty:10, desc:"A device for catching.",     icon: spr_item_placeholder },
            { name:"Great Ball",    qty: 3, desc:"Higher catch rate.",         icon: spr_item_placeholder },
        ];
        _b.items[2] = [
            { name:"TM01",          qty: 1, desc:"A technical machine.",       icon: spr_item_placeholder }
        ];
        _b.items[3] = [
            { name:"Oran Berry",    qty: 7, desc:"Restores a Pokémon's HP.",   icon: spr_item_placeholder }
        ];
        _b.items[4] = [
            { name:"Wailmer Pail",  qty: 1, desc:"Key Item for watering.",     icon: spr_item_placeholder }
        ];
        // -------------------------------------------

        global.BAGS[_pid] = _b;
    }
}

/// bag_is_open(pid)
function bag_is_open(_pid) {
    return (variable_global_exists("BAGS") && is_array(global.BAGS) && array_length(global.BAGS) > _pid && global.BAGS[_pid].open);
}

/// bag_open(pid)
function bag_open(_pid) { if (is_array(global.BAGS) && array_length(global.BAGS) > _pid) global.BAGS[_pid].open = true; }

/// bag_close(pid)
function bag_close(_pid){ if (is_array(global.BAGS) && array_length(global.BAGS) > _pid) global.BAGS[_pid].open = false; }

/// bag_toggle(pid)
function bag_toggle(_pid){
    if (!variable_global_exists("BAGS") || !is_array(global.BAGS) || array_length(global.BAGS) <= _pid) return;
    global.BAGS[_pid].open = !global.BAGS[_pid].open;
}

/// bags_update() — selection, scrolling, tiny Poké Ball spin timer
function bags_update() {
    if (!variable_global_exists("BAGS")) return;

    var _players = array_length(global.BAGS);
    if (_players <= 0) return;

    for (var pid = 0; pid < _players; pid++) {
        var b = global.BAGS[pid];

        // --- Toggle open/close on Inventory ---
        if (controls_pressed(pid, "Inventory")) {
            b.open = !b.open;
            if (b.open) {
                b.spin_ticks = 18;     // start header Poké Ball spin
            }
        }

        // If not open, nothing else to do for this player
        if (!b.open) continue;

        // --- Basic input (same actions you already use) ---
        // Move selection
        var lst = b.items[b.page];
        var n   = array_length(lst);

        if (controls_pressed(pid, "MoveDown") && (n > 0)) {
            b.sel = clamp(b.sel + 1, 0, n - 1);
        }
        if (controls_pressed(pid, "MoveUp") && (n > 0)) {
            b.sel = clamp(b.sel - 1, 0, n - 1);
        }

        // Flip page (0..4): Items, Pokéballs, TM/HM, Berries, Key Items
        if (controls_pressed(pid, "MoveRight")) {
            b.page = (b.page + 1) mod 5;
            b.sel = 0; b.scroll = 0;
            b.spin_ticks = 18;
        }
        if (controls_pressed(pid, "MoveLeft")) {
            b.page = (b.page + 4) mod 5;  // -1 mod 5
            b.sel = 0; b.scroll = 0;
            b.spin_ticks = 18;
        }

        // Optional: use/confirm
        // if (controls_pressed(pid, "Interact") && n > 0) {
        //     var it = lst[b.sel];
        //     // TODO: use/equip item
        // }

        // --- Housekeeping: clamp + keep selection visible ---
        var rows = 8; // list rows visible in the right panel
        n        = array_length(b.items[b.page]); // page may have changed
        b.sel    = clamp(b.sel, 0, max(0, n - 1));
        b.scroll = clamp(b.scroll, 0, max(0, n - rows));
        if (b.sel < b.scroll)           b.scroll = b.sel;
        if (b.sel >= b.scroll + rows)   b.scroll = max(0, b.sel - rows + 1);

        // Header Poké Ball spin
        if (b.spin_ticks > 0) b.spin_ticks--;
    }
}


/// _bag_rect_scaler(rx, ry, rw, rh) -> {s, ox, oy, rw, rh} (integer scale centered in rect)
function _bag_rect_scaler(_rx, _ry, _rw, _rh) {
    var _s = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _ox = _rx + (_rw - 240 * _s) div 2;
    var _oy = _ry + (_rh - 160 * _s) div 2;
    return { s:_s, ox:_ox, oy:_oy, rw:_rw, rh:_rh };
}

/// _bag_ui_rect_gui() -> full-screen scaler (compat helper)
function _bag_ui_rect_gui() {
    // Use the current GUI size
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    return _bag_rect_scaler(0, 0, _gw, _gh);
}

/// bag_draw_gui_rect(pid, rx, ry, rw, rh) — draws Emerald UI into the given GUI rectangle
function bag_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!bag_is_open(_pid)) return;
    if (!variable_global_exists("BAGS") || !is_array(global.BAGS) || array_length(global.BAGS) <= _pid) return;

    var b  = global.BAGS[_pid];

    // Fit 240x160 into target rect (integer scale)
    var s  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var ox = _rx + (_rw - 240 * s) div 2;
    var oy = _ry + (_rh - 160 * s) div 2;

    // Colors
    var C_BG_A    = make_color_rgb(176,216,248);
    var C_BG_B    = make_color_rgb(160,200,236);
    var C_HEAD    = make_color_rgb(60,88,104);
    var C_PAPER   = make_color_rgb(255,243,195);
    var C_PAPER_E = make_color_rgb(136,100,36);

    // ---------- Procedural background stripes ----------
    var stripe_h = 8;
    for (var yy = 0; yy < 160; yy += stripe_h){
        draw_set_color((yy div stripe_h) & 1 ? C_BG_B : C_BG_A);
        draw_rectangle(ox, oy + yy*s, ox + 240*s, oy + (yy + stripe_h)*s, false);
    }

    // ---------- Layout in 240x160 UI space ----------
    var head_x=8, head_y=4, head_w=224, head_h=20;

    var left_x=8, left_y=28, left_w=112, left_h=120;

    // Right list panel (you set this previously)
    var list_x=109, list_y=5, list_w=104, list_h=144;

    // Item icon box (fixed)
    var ibx=8, iby=70, ibw=32, ibh=28;

    // Description box stops BEFORE right list (3px gap)
    var art_h = (left_h - 46 - 4);
    var art_y = left_y;

    var desc_x = left_x;
    var desc_y = left_y + art_h + 4;
    var desc_w = max(40, (list_x - 3) - desc_x);
    var desc_h = 46;

    // ---------- Title bar ----------
    if (sprite_exists(sbagbarTopUI)){
        draw_sprite(sbagbarTopUI, 0, ox + head_x*s, oy + head_y*s);
    } else {
        draw_set_color(C_HEAD);
        draw_rectangle(ox + head_x*s, oy + head_y*s, ox + (head_x+head_w)*s, oy + (head_y+head_h)*s, false);
    }

    // Poké Ball spinner: align Y with title bar, nudged up 1px
    if (sprite_exists(sbagpokeball)){
        var nf = max(1, sprite_get_number(sbagpokeball));
        var fr = (b.spin_ticks > 0) ? ((18 - b.spin_ticks) div max(1, floor(18/nf))) mod nf : 0;
        draw_sprite(sbagpokeball, fr, ox + 8*s, oy + (head_y - 1)*s);
    }

    // Page title sprite aligned to title bar Y
    if (sprite_exists(sbagbartextboxUI)){
        var tsub = clamp(b.page, 0, max(1, sprite_get_number(sbagbartextboxUI)) - 1);
        draw_sprite(sbagbartextboxUI, tsub, ox + 24*s, oy + head_y*s);
    }

    // ---------- Page dots (“pips”) at x=43,y=24 (five dots, 8px apart, 4×4) ----------
    {
        var pip_x0 = 43, pip_y = 24, pip_size = 4, pip_gap = 8;
        for (var i = 0; i < 5; i++){
            var px = ox + (pip_x0 + i * pip_gap) * s;
            var py = oy + pip_y * s;
            var col = (i == b.page) ? c_red : c_white;
            draw_set_color(col);
            draw_rectangle(px, py, px + pip_size * s, py + pip_size * s, false);
        }
    }

    // ---------- Arrows: left at (27,12), right at (101,12), animated float ----------
    {
        var tsec = current_time / 1000;             // seconds (float)
        var dx   = round(sin(tsec * 4.0) * 2);      // ±2px

        if (sprite_exists(sbagbarbuttonUI)){
            // left = subimage 0, right = subimage 2
            draw_sprite(sbagbarbuttonUI, 1, ox + (27 + dx) * s,  oy + 12 * s);
            draw_sprite(sbagbarbuttonUI, 2, ox + (101 - dx) * s, oy + 12 * s);
        }
    }


    // ---------- LEFT: page art (bag/pouch) — your -11px nudge applied ----------
    {
        var ART_SHIFT_X = -11; // you set this; keeping it
        var art_x = ibx + ibw + 4 + ART_SHIFT_X;           // start to the right of item icon box
        var art_w = left_w - (art_x - left_x);

        var spr   = (b.mode == "equip") ? sequipmentpouche : sbag;
        if (sprite_exists(spr)){
            var si   = clamp(b.page, 0, max(1, sprite_get_number(spr)) - 1);
            var sw   = max(1, sprite_get_width(spr));
            var sh   = max(1, sprite_get_height(spr));
            var scui = min(art_w / sw, art_h / sh);

            var dw   = sw * scui * s;
            var dh   = sh * scui * s;
            var ax   = ox + art_x*s + ((art_w*s) - dw) * 0.5;
            var ay   = oy + art_y*s + ((art_h*s)  - dh) * 0.5;

            draw_sprite_ext(spr, si, floor(ax), floor(ay), scui*s, scui*s, 0, c_white, 1);
        } else {
            draw_set_color(make_color_rgb(220,240,255));
            draw_rectangle(ox + art_x*s, oy + art_y*s, ox + (art_x+art_w)*s, oy + (art_y+art_h)*s, false);
        }
    }

    // ---------- Item icon box (8,70) 32x28 ----------
    {
        draw_set_color(c_white);
        draw_rectangle(ox + ibx*s, oy + iby*s, ox + (ibx+ibw)*s, oy + (iby+ibh)*s, false);
        draw_set_color(C_PAPER_E);
        draw_rectangle(ox + ibx*s - s, oy + iby*s - s, ox + (ibx+ibw)*s + s, oy + (iby+ibh)*s + s, true);

        var _lc    = b.items[b.page];
        var _count = array_length_1d(_lc);
        if (_count > 0){
            var _sel = clamp(b.sel, 0, _count - 1);
            var _it  = _lc[_sel];
            var _icn = (is_undefined(_it.icon) ? spr_item_placeholder : _it.icon);
            if (is_real(_icn) && _icn >= 0){
                var _iw  = max(1, sprite_get_width(_icn));
                var _ih  = max(1, sprite_get_height(_icn));
                var _isc = min((ibw-4)/_iw, (ibh-4)/_ih);
                var _ix  = ox + ibx*s + (ibw*s - _iw*_isc*s)*0.5;
                var _iy  = oy + iby*s + (ibh*s - _ih*_isc*s)*0.5;
                draw_sprite_ext(_icn, 0, floor(_ix), floor(_iy), _isc*s, _isc*s, 0, c_white, 1);
            }
        }
    }

    // ---------- Description panel (white text) ----------
    {
        var x1 = ox + desc_x*s, y1 = oy + desc_y*s, x2 = ox + (desc_x+desc_w)*s, y2 = oy + (desc_y+desc_h)*s;
        draw_set_color(C_PAPER);
        draw_rectangle(x1, y1, x2, y2, false);
        draw_set_color(C_PAPER_E);
        draw_rectangle(x1 - s, y1 - s, x2 + s, y2 + s, true);

        var _lc2    = b.items[b.page];
        var _count2 = array_length_1d(_lc2);
        var _sel2   = clamp(b.sel, 0, max(0, _count2 - 1));
        var _txt    = (_count2 > 0 && !is_undefined(_lc2[_sel2].desc)) ? string(_lc2[_sel2].desc) : "—";

        if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
        draw_set_color(c_white);

        var pad_ui    = 4;
        var wrap_w    = (desc_w - pad_ui*2) * s;
        var line_h    = max(12, string_height("A") + 2);
        var max_lines = floor((desc_h*s - pad_ui*2*s) / line_h);
        var tx        = x1 + pad_ui*s;
        var ty        = y1 + pad_ui*s;

        var lines = [];
        {
            var words = string_split(_txt, " ");
            var line  = "";
            for (var i = 0; i < array_length_1d(words); i++){
                var w = words[i];
                var t = (line == "") ? w : (line + " " + w);
                if (string_width(t) <= wrap_w) line = t;
                else {
                    if (line == "") {
                        var j = 1; while (j <= string_length(w) && string_width(string_copy(w,1,j)) <= wrap_w) j++;
                        array_push(lines, string_copy(w,1,j-1));
                        line = string_copy(w,j,string_length(w)-j+1);
                    } else {
                        array_push(lines, line);
                        line = w;
                    }
                }
            }
            if (line != "") array_push(lines, line);
        }

        var drawn = 0;
        for (var li = 0; li < array_length_1d(lines) && drawn < max_lines; ++li){
            draw_text(tx, ty + drawn*line_h, lines[li]);
            drawn++;
        }
        if (drawn < array_length_1d(lines) && max_lines > 0){
            var last = lines[drawn-1];
            while (string_width(last + "…") > wrap_w && string_length(last) > 0) last = string_delete(last, string_length(last), 1);
            draw_text(tx, ty + (drawn-1)*line_h, last + "…");
        }
    }

    // ---------- Right list panel ----------
    {
        var lx1 = ox + list_x*s, ly1 = oy + list_y*s, lx2 = ox + (list_x+list_w)*s, ly2 = oy + (list_y+list_h)*s;
        draw_set_color(C_PAPER);
        draw_rectangle(lx1, ly1, lx2, ly2, false);
        draw_set_color(C_PAPER_E);
        draw_rectangle(lx1 - s, ly1 - s, lx2 + s, ly2 + s, true);

        var rows   = 8;
        var row_h  = max(12, string_height("A") + 2);
        var _lc3    = b.items[b.page];
        var _count3 = array_length_1d(_lc3);
        var sel     = clamp(b.sel, 0, max(0, _count3 - 1));

        if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
        draw_set_color(c_white);

        for (var r = 0; r < rows; r++){
            var idx = b.scroll + r; if (idx >= _count3) break;
            var nm  = string(_lc3[idx].name);
            var qty = "× " + string(_lc3[idx].qty);

            var yline = oy + (list_y + 8 + r*row_h)*s;
            draw_text(ox + (list_x + 8)*s, yline, nm);
            draw_text(ox + (list_x + list_w - 8 - string_width(qty))*s, yline, qty);
            if (idx == sel) draw_text(ox + (list_x + 2)*s, yline, "►");
        }
    }
}




/// bag_draw_gui(pid) — single-player full-screen wrapper
function bag_draw_gui(_pid){
    var gw = display_get_gui_width();
    var gh = display_get_gui_height();
    bag_draw_gui_rect(_pid, 0, 0, gw, gh);
}

/// __bag_wrap_lines(text, max_width) -> array of wrapped lines (no drawing)
function __bag_wrap_lines(_text, _max_w){
    var _out = [];
    if (is_undefined(_text) || string_length(_text) == 0){
        array_push(_out, "—");
        return _out;
    }
    var _words = string_split(_text, " ");
    var _line  = "";
    for (var i = 0; i < array_length(_words); i++){
        var _w  = _words[i];
        var _try = (_line == "" ? _w : _line + " " + _w);
        if (string_width(_try) <= _max_w){
            _line = _try;
        } else {
            if (_line == ""){
                // super long word: hard break
                var _j = 1;
                while (_j <= string_length(_w) && string_width(string_copy(_w,1,_j)) <= _max_w) _j++;
                array_push(_out, string_copy(_w,1,_j-1));
                _line = string_copy(_w,_j,string_length(_w)-_j+1);
            } else {
                array_push(_out, _line);
                _line = _w;
            }
        }
    }
    if (_line != "") array_push(_out, _line);
    return _out;
}
