// Bag draw helpers — rendering the bag UI. Keep UI-only logic here.
function __bag_impl_bag_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!bag_is_open(_pid)) return;
    if (!variable_global_exists("BAGS") || !is_array(global.BAGS) || array_length(global.BAGS) <= _pid) return;
    var b  = global.BAGS[_pid];

    // Reset draw state to avoid invisible sprites
    draw_set_alpha(1);
    draw_set_color(c_white);
    gpu_set_blendmode(bm_normal);

    var _rect = _bag_rect_scaler(_rx, _ry, _rw, _rh);
    var s = _rect.s; var ox = _rect.ox; var oy = _rect.oy;
    var _tsec = current_time / 1000;
    var _pulse = 0.9 + 0.1 * sin(_tsec * 3.0);

    var C_BG_A    = make_color_rgb(176,216,248);
    var C_BG_B    = make_color_rgb(160,200,236);
    var C_HEAD    = make_color_rgb(60,88,104);
    var C_PAPER   = make_color_rgb(255,243,195);
    var C_PAPER_E = make_color_rgb(136,100,36);

    // background stripes
    var stripe_h = 8;
    for (var yy = 0; yy < 160; yy += stripe_h){ draw_set_color((yy div stripe_h) & 1 ? C_BG_B : C_BG_A); draw_rectangle(ox, oy + yy*s, ox + 240*s, oy + (yy + stripe_h)*s, false); }

    // Layout constants (kept compact)
    var head_x=8, head_y=4, head_w=224, head_h=20;
    var left_x=8, left_y=28, left_w=112, left_h=120;
    var list_x=109, list_y=5, list_w=104, list_h=144;
    var ibx=8, iby=70, ibw=32, ibh=28;
    var art_h = (left_h - 46 - 4), art_y = left_y;
    var desc_x = left_x, desc_y = left_y + art_h + 4, desc_w = max(40, (list_x - 3) - desc_x), desc_h = 46;

    // Title bar
    if (sprite_exists(sbagbarTopUI)) draw_sprite(sbagbarTopUI, 0, ox + head_x*s, oy + head_y*s);
    else { draw_set_color(C_HEAD); draw_rectangle(ox + head_x*s, oy + head_y*s, ox + (head_x+head_w)*s, oy + (head_y+head_h)*s, false); }

    // Poké Ball spinner
    if (sprite_exists(sbagpokeball)){ var nf = max(1, sprite_get_number(sbagpokeball)); var fr = (b.spin_ticks > 0) ? ((18 - b.spin_ticks) div max(1, floor(18/nf))) mod nf : 0; draw_sprite(sbagpokeball, fr, ox + 8*s, oy + (head_y - 1)*s); }

    // Page title
    if (sprite_exists(sbagbartextboxUI)){ var tsub = clamp(b.page, 0, max(1, sprite_get_number(sbagbartextboxUI)) - 1); draw_sprite(sbagbartextboxUI, tsub, ox + 24*s, oy + head_y*s); }

    // pips
    { var pip_x0 = 43, pip_y = 24, pip_size = 4, pip_gap = 8;
        for (var i = 0; i < 5; i++){ var px = ox + (pip_x0 + i * pip_gap) * s; var py = oy + pip_y * s; var col = (i == b.page) ? c_red : c_white; draw_set_color(col); draw_rectangle(px, py, px + pip_size * s, py + pip_size * s, false); }
    }

    // arrows
    if (sprite_exists(sbagbarbuttonUI)){ var dx = round(sin(_tsec * 4.0) * 2); draw_sprite(sbagbarbuttonUI, 1, ox + (27 + dx) * s,  oy + 12 * s); draw_sprite(sbagbarbuttonUI, 2, ox + (101 - dx) * s, oy + 12 * s); }

    // left art
    {  var ART_SHIFT_X = -11, art_x = ibx + ibw + 4 + ART_SHIFT_X, art_w = left_w - (art_x - left_x);
        var spr = (b.mode == "equip") ? sequipmentpouche : sbag;
        if (sprite_exists(spr)){ var si = clamp(b.page, 0, max(1, sprite_get_number(spr)) - 1); var sw = max(1, sprite_get_width(spr)); var sh = max(1, sprite_get_height(spr)); var scui = min(art_w / sw, art_h / sh);
            var dw = sw * scui * s, dh = sh * scui * s, ax = ox + art_x*s + ((art_w*s) - dw) * 0.5, ay = oy + art_y*s + ((art_h*s)  - dh) * 0.5;
            draw_sprite_ext(spr, si, floor(ax), floor(ay), scui*s, scui*s, 0, c_white, 1);
        } else { draw_set_color(make_color_rgb(220,240,255)); draw_rectangle(ox + art_x*s, oy + art_y*s, ox + (art_x+art_w)*s, oy + (art_y+art_h)*s, false); }
    }

    // item icon box and description and right list are handled by helper functions to keep this function tidy
    __bag_impl_draw_item_icon_box(b, ox, oy, s, ibx, iby, ibw, ibh, desc_x, desc_y, desc_w, desc_h, list_x, list_y, list_w, list_h, C_PAPER, C_PAPER_E, _pulse);
}

function __bag_impl_draw_item_icon_box(_b, _ox, _oy, _s, _ibx, _iby, _ibw, _ibh, _desc_x, _desc_y, _desc_w, _desc_h, _list_x, _list_y, _list_w, _list_h, _C_PAPER, _C_PAPER_E, _pulse){
    // icon box
    draw_set_color(c_white); draw_rectangle(_ox + _ibx*_s, _oy + _iby*_s, _ox + (_ibx+_ibw)*_s, _oy + (_iby+_ibh)*_s, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(_ox + _ibx*_s - _s, _oy + _iby*_s - _s, _ox + (_ibx+_ibw)*_s + _s, _oy + (_iby+_ibh)*_s + _s, true);

    var sel_icon_x1 = _ox + (_ibx - 2) * _s, sel_icon_y1 = _oy + (_iby - 2) * _s, sel_icon_x2 = _ox + (_ibx + _ibw + 2) * _s, sel_icon_y2 = _oy + (_iby + _ibh + 2) * _s;
    draw_set_alpha(_pulse); draw_set_color(make_color_rgb(255,250,220)); draw_rectangle(sel_icon_x1, sel_icon_y1, sel_icon_x2, sel_icon_y2, false); draw_set_alpha(1);
    draw_set_color(_C_PAPER_E); draw_rectangle(sel_icon_x1 - _s, sel_icon_y1 - _s, sel_icon_x2 + _s, sel_icon_y2 + _s, true);

    var _lc = _b.items[_b.page]; var _count = array_length_1d(_lc);
    if (_count > 0){
        var _sel = clamp(_b.sel, 0, _count - 1);
        var _it  = _lc[_sel];
        var ph = bag__get_item_placeholder();
        var _icn = (is_undefined(_it.icon) || !sprite_exists(_it.icon)) ? ph : _it.icon;
        if (!is_undefined(_icn) && sprite_exists(_icn)){
            var _iw = max(1, sprite_get_width(_icn)); var _ih = max(1, sprite_get_height(_icn));
            var _isc = min((_ibw-4)/_iw, (_ibh-4)/_ih);
            var _scaled_w = _iw * _isc * _s;
            var _scaled_h = _ih * _isc * _s;
            var _ix = _ox + (_ibx * _s) + ((_ibw * _s) - _scaled_w) * 0.5;
            var _iy = _oy + (_iby * _s) + ((_ibh * _s) - _scaled_h) * 0.5;
            draw_sprite_ext(_icn, 0, floor(_ix), floor(_iy), _isc * _s, _isc * _s, 0, c_white, 1);
        }
    }

    // description
    __bag_impl_draw_description(_b, _ox, _oy, _s, _desc_x, _desc_y, _desc_w, _desc_h, _C_PAPER, _C_PAPER_E);

    // right list
    __bag_impl_draw_right_list(_b, _ox, _oy, _s, _list_x, _list_y, _list_w, _list_h, _C_PAPER, _C_PAPER_E, _pulse);
}

function __bag_impl_draw_description(_b, _ox, _oy, _s, _desc_x, _desc_y, _desc_w, _desc_h, _C_PAPER, _C_PAPER_E){
    var x1 = _ox + _desc_x*_s, y1 = _oy + _desc_y*_s, x2 = _ox + (_desc_x+_desc_w)*_s, y2 = _oy + (_desc_y+_desc_h)*_s;
    draw_set_color(_C_PAPER); draw_rectangle(x1, y1, x2, y2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(x1 - _s, y1 - _s, x2 + _s, y2 + _s, true);

    var _lc2 = _b.items[_b.page], _count2 = array_length_1d(_lc2), _sel2 = clamp(_b.sel, 0, max(0, _count2 - 1));
    var _txt = (_count2 > 0 && !is_undefined(_lc2[_sel2].desc)) ? string(_lc2[_sel2].desc) : "—";

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    var pad_ui = 4, wrap_w = (_desc_w - pad_ui*2) * _s, line_h = max(12, string_height("A") + 2), max_lines = floor((_desc_h*_s - pad_ui*2*_s) / line_h), tx = x1 + pad_ui*_s, ty = y1 + pad_ui*_s;

    var lines = __bag_wrap_lines(_txt, wrap_w);
    var drawn = 0; for (var li = 0; li < array_length_1d(lines) && drawn < max_lines; ++li){ draw_text(tx, ty + drawn*line_h, lines[li]); drawn++; }
    if (drawn < array_length_1d(lines) && max_lines > 0){ var last = lines[drawn-1]; while (string_width(last + "…") > wrap_w && string_length(last) > 0) last = string_delete(last, string_length(last), 1); draw_text(tx, ty + (drawn-1)*line_h, last + "…"); }
}

// Text wrap helper (draw-only implementation)
function __bag_impl_wrap_lines(_text, _max_w){
    var _out = []; if (is_undefined(_text) || string_length(_text) == 0){ array_push(_out, "—"); return _out; }
    var _words = string_split(_text, " "); var _line  = "";
    for (var i = 0; i < array_length(_words); i++){
        var _w  = _words[i]; var _try = (_line == "" ? _w : _line + " " + _w);
        if (string_width(_try) <= _max_w) _line = _try;
        else {
            if (_line == ""){
                var _j = 1;
                while (_j <= string_length(_w) && string_width(string_copy(_w,1,_j)) <= _max_w) _j++;
                array_push(_out, string_copy(_w,1,_j-1));
                _line = string_copy(_w,_j,string_length(_w)-_j+1);
            } else { array_push(_out, _line); _line = _w; }
        }
    }
    if (_line != "") array_push(_out, _line);
    return _out;
}

function __bag_impl_draw_right_list(_b, _ox, _oy, _s, _list_x, _list_y, _list_w, _list_h, _C_PAPER, _C_PAPER_E, _pulse){
    var lx1 = _ox + _list_x*_s, ly1 = _oy + _list_y*_s, lx2 = _ox + (_list_x+_list_w)*_s, ly2 = _oy + (_list_y+_list_h)*_s;
    draw_set_color(_C_PAPER); draw_rectangle(lx1, ly1, lx2, ly2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(lx1 - _s, ly1 - _s, lx2 + _s, ly2 + _s, true);

    var rows = 8, row_h = max(12, string_height("A") + 2), _lc3 = _b.items[_b.page], _count3 = array_length_1d(_lc3), sel = clamp(_b.sel, 0, max(0, _count3 - 1));

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    for (var r = 0; r < rows; r++){
        var idx = _b.scroll + r; if (idx >= _count3) break;
        var nm  = string(_lc3[idx].name);
        var qty = "× " + string(_lc3[idx].qty);
        var row_top = _oy + (_list_y + 8 + r*row_h) * _s;
        var fh = string_height("A");
        var yline = row_top + (row_h * _s - fh) * 0.5;

        if (idx == sel){
            var sel_x1 = _ox + (_list_x + 2) * _s;
            var sel_x2 = _ox + (_list_x + _list_w - 2) * _s;
            var center_y = yline + (fh * 0.5) - 5 * _s;
            var half_h = (row_h * _s) * 0.25;
            var sel_y1 = center_y - half_h;
            var sel_y2 = center_y + half_h;
            draw_set_alpha(_pulse);
            draw_set_color(make_color_rgb(200,220,255));
            draw_rectangle(sel_x1, sel_y1, sel_x2, sel_y2, false);
            draw_set_alpha(1);
            draw_set_color(_C_PAPER_E);
            draw_rectangle(sel_x1 - _s, sel_y1 - _s, sel_x2 + _s, sel_y2 + _s, true);
        }

        draw_set_color(c_white);
        draw_text(_ox + (_list_x + 8) * _s, yline, nm);
        draw_set_color(c_white);
        draw_text(_ox + (_list_x + _list_w - 8 - string_width(qty)) * _s, yline, qty);

        if (idx == sel){ draw_set_color(c_white); draw_set_alpha(_pulse); draw_text(_ox + (_list_x + 2) * _s, yline, "►"); draw_set_alpha(1); }
    }
}
