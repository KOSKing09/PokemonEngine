// [Party System]: party_system — Build v4.8.1 — 2025-10-03
// Fix: renamed stray `_hp_txt` to `hp_txt` in info panel draw (prevents undefined var crash).
// All other features from v4.8.0 retained (selector in list & submenu, spacing, calm icon anim).

globalvar PARTY;

// ---------- Tunables ----------
#macro PARTY_ICON_H_UI 20
#macro PARTY_ROW_PAD_UI 2
#macro PARTY_HILITE_COL make_color_rgb(255,255,255)
#macro PARTY_HILITE_EDGE make_color_rgb(136,100,36)
#macro PARTY_HILITE_ALPHA 0.20

// ---------- Asset helpers (safe) ----------
function __party_asset_index_or(_name){
    var nm = string(_name);
    if (string_length(nm) <= 0) return -1;
    var idx = asset_get_index(nm);
    return idx;
}

// ---------- Basic queries / toggles ----------
function party_is_open(_pid){
    if (!variable_global_exists("PARTY")) return false;
    if (!is_array(global.PARTY)) return false;
    if (array_length(global.PARTY) <= _pid) return false;
    var P = global.PARTY[_pid];
    if (!is_struct(P)) return false;
    if (!variable_struct_exists(P,"open")) return false;
    return P.open;
}
function party_open(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var P = global.PARTY[_pid];
    if (!is_struct(P)) return;
    P.open         = true;
    P.mode         = "list";
    P.menu_sel     = 0;
    P.swap_index   = -1;
    P.sum_move_sel = 0;
    P.sum_learn_sel= 0;
    P.lock         = 4;
}
function party_close(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var P = global.PARTY[_pid];
    if (!is_struct(P)) return;
    P.open = false;
}
function party_toggle(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var P = global.PARTY[_pid];
    if (!is_struct(P)) return;
    P.open = !P.open;
    if (P.open){
        P.mode         = "list";
        P.menu_sel     = 0;
        P.swap_index   = -1;
        P.sum_move_sel = 0;
        P.sum_learn_sel= 0;
        P.lock         = 4;
    }
}

// ---------- Initialization / ensure ----------
function party_init(){
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    var players = 1;
    if (variable_global_exists("PAUSE_PLAYERS_ACTIVE")) players = max(1, global.PAUSE_PLAYERS_ACTIVE);
    array_resize(global.PARTY, players);
    for (var pid = 0; pid < players; pid++){
        if (!is_struct(global.PARTY[pid])){
            global.PARTY[pid] = {
                open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0,
                mons:[], sum_move_sel:0, sum_learn_sel:0
            };
        }
    }
}
function party_ensure(_pid){
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    if (!is_array(global.PARTY)) global.PARTY = [];
    if (array_length(global.PARTY) <= _pid) array_resize(global.PARTY, _pid + 1);
    var P = global.PARTY[_pid];
    if (!is_struct(P)){
        P = { open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0, mons:[], sum_move_sel:0, sum_learn_sel:0 };
        global.PARTY[_pid] = P;
    }
    if (!variable_struct_exists(P,"open"))          P.open         = false;
    if (!variable_struct_exists(P,"mode"))          P.mode         = "list";
    if (!variable_struct_exists(P,"sel"))           P.sel          = 0;
    if (!variable_struct_exists(P,"scroll"))        P.scroll       = 0;
    if (!variable_struct_exists(P,"menu_sel"))      P.menu_sel     = 0;
    if (!variable_struct_exists(P,"swap_index"))    P.swap_index   = -1;
    if (!variable_struct_exists(P,"lock"))          P.lock         = 0;
    if (!variable_struct_exists(P,"mons") || !is_array(P.mons)) P.mons = [];
    if (!variable_struct_exists(P,"sum_move_sel"))  P.sum_move_sel = 0;
    if (!variable_struct_exists(P,"sum_learn_sel")) P.sum_learn_sel= 0;

    var n = array_length(P.mons), rows = 6;
    if (n <= 0){ P.sel = 0; P.scroll = 0; }
    else {
        if (P.sel >= n) P.sel = n - 1;
        if (P.sel < 0)  P.sel = 0;
        var max_scroll = max(0, n - rows);
        if (P.scroll < 0) P.scroll = 0;
        if (P.scroll > max_scroll) P.scroll = max_scroll;
        if (P.sel <  P.scroll)        P.scroll = P.sel;
        if (P.sel >= P.scroll + rows)  P.scroll = max(0, P.sel - rows + 1);
    }
    return P;
}

// ---------- Helpers ----------
function __party_mons(_pid){
    if (variable_global_exists("PARTY") && is_array(global.PARTY) && array_length(global.PARTY) > _pid){
        var p = global.PARTY[_pid];
        if (is_struct(p) && variable_struct_exists(p,"mons") && is_array(p.mons)) return p.mons;
    }
    return [];
}
function __party_mon_get(_P, _pid){
    var mons = __party_mons(_pid), n = array_length(mons);
    if (n <= 0) return undefined;
    var idx = _P.sel; if (idx < 0 || idx >= n) return undefined;
    return mons[idx];
}
function __party_move_name(_id){
    if (!is_real(_id)) return "—";
    if (is_undefined(scr_move_name_by_id)) return "Move#" + string(_id);
    var t = scr_move_name_by_id(_id);
    if (is_string(t) && string_length(t) > 0) return t;
    return "Move#" + string(_id);
}

// ---------- Update ----------
function party_update(){
    if (!variable_global_exists("PARTY")) return;
    var players = array_length(global.PARTY); if (players <= 0) return;

    for (var pid = 0; pid < players; pid++){
        var P = party_ensure(pid);
        if (!P.open) continue;
        if (P.lock > 0) P.lock--;

        var mons = P.mons, n = array_length(mons), ROWS = 6;

        if (P.mode != "select" && P.mode != "summary_profile" && P.mode != "summary_moves" && P.mode != "summary_forget"){
            if (controls_pressed(pid,"Run") && P.lock == 0){ P.open = false; P.lock = 2; continue; }
        }

        switch (P.mode){
            case "list": {
                if (controls_pressed(pid,"MoveDown") && n > 0) P.sel = clamp(P.sel + 1, 0, n - 1);
                if (controls_pressed(pid,"MoveUp")   && n > 0) P.sel = clamp(P.sel - 1, 0, n - 1);
                P.scroll = clamp(P.scroll, 0, max(0, n - ROWS));
                if (P.sel <  P.scroll)        P.scroll = P.sel;
                if (P.sel >= P.scroll + ROWS) P.scroll = max(0, P.sel - ROWS + 1);
                if (controls_pressed(pid,"Interact") && P.lock == 0){ P.mode="menu"; P.menu_sel=0; P.lock=2; }
            } break;

            case "menu": {
                if (controls_pressed(pid,"MoveDown")) P.menu_sel = clamp(P.menu_sel + 1, 0, 3);
                if (controls_pressed(pid,"MoveUp"))   P.menu_sel = clamp(P.menu_sel - 1, 0, 3);
                if (controls_pressed(pid,"Interact") && P.lock == 0){
                    switch (P.menu_sel){
                        case 0: P.mode="summary_profile"; P.sum_move_sel=0; P.sum_learn_sel=0; P.lock=2; break;
                        case 1: P.swap_index = P.sel; P.mode="select"; P.lock=2; break;
                        case 2: P.mode="list"; P.lock=2; break;
                        case 3: P.mode="list"; P.lock=2; break;
                    }
                }
            } break;

            case "select": {
                if (controls_pressed(pid,"MoveDown") && n > 0) P.sel = clamp(P.sel + 1, 0, n - 1);
                if (controls_pressed(pid,"MoveUp")   && n > 0) P.sel = clamp(P.sel - 1, 0, n - 1);
                P.scroll = clamp(P.scroll, 0, max(0, n - ROWS));
                if (P.sel <  P.scroll)        P.scroll = P.sel;
                if (P.sel >= P.scroll + ROWS) P.scroll = max(0, P.sel - ROWS + 1);
                if (controls_pressed(pid,"Interact") && P.lock == 0){
                    var src = P.swap_index, dst = P.sel;
                    if (n > 0 && src >= 0 && src < n && dst >= 0 && dst < n && src != dst){
                        var t = mons[src]; mons[src] = mons[dst]; mons[dst] = t;
                        P.mons = mons; P.sel = dst;
                    }
                    P.mode="list"; P.swap_index=-1; P.lock=2;
                }
                if (controls_pressed(pid,"Run") && P.lock == 0){ P.mode="list"; P.swap_index=-1; P.lock=2; }
            } break;

            case "summary_profile": {
                if (controls_pressed(pid,"MoveRight") && n > 0){ P.sel = clamp(P.sel + 1, 0, n - 1); P.lock = 2; }
                if (controls_pressed(pid,"MoveLeft")  && n > 0){ P.sel = clamp(P.sel - 1, 0, n - 1); P.lock = 2; }
                if (controls_pressed(pid,"MoveDown")){ P.mode = "summary_moves"; P.lock = 2; }
                if (controls_pressed(pid,"Run") && P.lock == 0){ P.mode = "list"; P.lock = 2; }
            } break;

            case "summary_moves": {
                var M  = __party_mon_get(P, pid);
                var mv = is_struct(M) && variable_struct_exists(M,"moves") ? M.moves : [];
                var lr = is_struct(M) && variable_struct_exists(M,"learnset") ? M.learnset : [];
                var nm = array_length(mv), nl = array_length(lr);

                if (controls_pressed(pid,"MoveUp")){ P.mode = "summary_profile"; P.lock = 2; }
                if (controls_pressed(pid,"MoveRight") && n > 0){ P.sel = clamp(P.sel + 1, 0, n - 1); P.lock = 2; }
                if (controls_pressed(pid,"MoveLeft")  && n > 0){ P.sel = clamp(P.sel - 1, 0, n - 1); P.lock = 2; }

                var invHeld = controls_down(pid,"Inventory");
                if (invHeld){
                    if (nl > 0){
                        if (controls_pressed(pid,"MoveDown")) P.sum_learn_sel = clamp(P.sum_learn_sel + 1, 0, nl - 1);
                        if (controls_pressed(pid,"MoveUp"))   P.sum_learn_sel = clamp(P.sum_learn_sel - 1, 0, nl - 1);
                    } else P.sum_learn_sel = 0;
                } else {
                    if (nm > 0){
                        if (controls_pressed(pid,"MoveDown")) P.sum_move_sel = clamp(P.sum_move_sel + 1, 0, nm - 1);
                        if (controls_pressed(pid,"MoveUp"))   P.sum_move_sel = clamp(P.sum_move_sel - 1, 0, nm - 1);
                    } else P.sum_move_sel = 0;
                }

                if (controls_pressed(pid,"Interact") && P.lock == 0){
                    if (nl > 0){
                        var learnId = lr[P.sum_learn_sel];
                        if (nm < 4){ array_push(mv, learnId); M.moves = mv; P.sum_move_sel = array_length(mv) - 1; P.lock = 4; }
                        else { P.mode = "summary_forget"; P.lock = 2; }
                    }
                }
                if (controls_pressed(pid,"Run") && P.lock == 0){ P.mode = "list"; P.lock = 2; }
            } break;

            case "summary_forget": {
                var M2  = __party_mon_get(P, pid);
                var mv2 = is_struct(M2) && variable_struct_exists(M2,"moves") ? M2.moves : [];
                var nm2 = array_length(mv2);
                if (nm2 <= 0){ P.mode = "summary_moves"; break; }
                if (controls_pressed(pid,"MoveDown")) P.sum_move_sel = clamp(P.sum_move_sel + 1, 0, nm2 - 1);
                if (controls_pressed(pid,"MoveUp"))   P.sum_move_sel = clamp(P.sum_move_sel - 1, 0, nm2 - 1);
                var lr2 = is_struct(M2) && variable_struct_exists(M2,"learnset") ? M2.learnset : [];
                var nl2 = array_length(lr2);
                var chosen = (nl2 > 0) ? lr2[P.sum_learn_sel] : -1;
                if (controls_pressed(pid,"Interact") && P.lock == 0){
                    if (chosen != -1){ mv2[P.sum_move_sel] = chosen; M2.moves = mv2; P.mode = "summary_moves"; P.lock = 4; }
                    else { P.mode = "summary_moves"; P.lock = 2; }
                }
                if (controls_pressed(pid,"Run") && P.lock == 0){ P.mode = "summary_moves"; P.lock = 2; }
            } break;
        }
    }
}

// ---------- Draw ----------
function party_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!party_is_open(_pid)) return;
    var P = party_ensure(_pid);

    var S  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var OX = _rx + (_rw - 240 * S) div 2;
    var OY = _ry + (_rh - 160 * S) div 2;

    if (string(P.mode) == "summary_profile" || string(P.mode) == "summary_moves" || string(P.mode) == "summary_forget"){
        __party_draw_summary(_pid, P, OX, OY, S);
        return;
    }

    var C_BG_A    = make_color_rgb(252,236,180);
    var C_BG_B    = make_color_rgb(248,220,140);
    var C_PAPER   = make_color_rgb(255,243,195);
    var C_PAPER_E = make_color_rgb(136,100,36);

    var stripe_h = 8;
    for (var yy = 0; yy < 160; yy += stripe_h){
        draw_set_color( ((yy div stripe_h) & 1) == 1 ? C_BG_B : C_BG_A );
        draw_rectangle(OX, OY + yy*S, OX + 240*S, OY + (yy+stripe_h)*S, false);
    }

    var LIST_X = 120, LIST_Y = 8,  LIST_W = 112, LIST_H = 144;
    var INFO_X = 8,   INFO_Y = 98, INFO_W = 104, INFO_H = 54;

    var lx1 = OX + LIST_X*S,            ly1 = OY + LIST_Y*S;
    var lx2 = OX + (LIST_X+LIST_W)*S,   ly2 = OY + (LIST_Y+LIST_H)*S;
    draw_set_color(C_PAPER);   draw_rectangle(lx1, ly1, lx2, ly2, false);
    draw_set_color(C_PAPER_E); draw_rectangle(lx1 - S, ly1 - S, lx2 + S, ly2 + S, true);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    var mons  = P.mons;
    var n     = array_length(mons);
    var ROWS  = 6;
    var ROW_H = max(12, string_height("A") + 2);

    var sprSelector    = __party_asset_index_or("spr_selector");
    var sprPlaceholder = __party_asset_index_or("spr_mon_icon_placeholder");

    for (var r = 0; r < ROWS; r++){
        var idx = P.scroll + r; if (idx >= n) break;
        var M = mons[idx];
        var row_y_gui = OY + (LIST_Y + 8 + r*(ROW_H + PARTY_ROW_PAD_UI)) * S;

        if (idx == P.sel){
            var rx1 = OX + (LIST_X + 2) * S;
            var ry1 = row_y_gui - (ROW_H * 0.65) * S;
            var rx2 = OX + (LIST_X + LIST_W - 2) * S;
            var ry2 = ry1 + (ROW_H * 1.25) * S;
            draw_set_alpha(PARTY_HILITE_ALPHA);
            draw_set_color(PARTY_HILITE_COL);
            draw_rectangle(rx1, ry1, rx2, ry2, false);
            draw_set_alpha(1);
            draw_set_color(PARTY_HILITE_EDGE);
            draw_rectangle(rx1, ry1, rx2, ry2, true);
            draw_set_color(c_white);
        }

        if (idx == P.sel && sprite_exists(sprSelector)){
            var sh2 = max(1, sprite_get_height(sprSelector));
            var tgt2 = ROW_H * S;
            var sc2  = tgt2 / sh2;
            draw_sprite_ext(sprSelector, 0, OX + (LIST_X + 2)*S - 10*S, row_y_gui - tgt2*0.15, sc2, sc2, 0, c_white, 1);
        }

        var sprDown = -1;
        if (!is_undefined(pkicons_get_icon32_dir_by_mon)) sprDown = pkicons_get_icon32_dir_by_mon(M, "down");
        var hasIcon = sprite_exists(sprDown);
        if (!hasIcon && sprite_exists(sprPlaceholder)){ sprDown = sprPlaceholder; hasIcon = true; }

        var drawnIconW_ui = 0;
        if (hasIcon){
            var frame = 0;
            if (!is_undefined(pkicons_icon32_frame_ui)) frame = pkicons_icon32_frame_ui();

            var ih = max(1, sprite_get_height(sprDown));
            var target_h_gui = PARTY_ICON_H_UI * S;
            var sc_icon = target_h_gui / ih;

            var ix_gui = OX + (LIST_X + 2) * S;
            var iw_gui = sprite_get_width(sprDown) * sc_icon;
            var iy_gui = row_y_gui - target_h_gui * 0.5;

            draw_sprite_ext(sprDown, frame, floor(ix_gui), floor(iy_gui), sc_icon, sc_icon, 0, c_white, 1);
            drawnIconW_ui = ceil((iw_gui) / S);
        } else {
            drawnIconW_ui = 18;
        }

        var disp_name = "???";
        if (is_struct(M)){
            if (variable_struct_exists(M,"species_id")){
                var sid = M.species_id;
                if (is_real(sid) && sid >= 0){
                    var idn = scr_poke_name_by_id(sid);
                    if (string_length(idn) > 0){
                        disp_name = string_replace_all(idn, "-", " ");
                        if (string_length(disp_name) > 0){
                            disp_name = string_upper(string_copy(disp_name,1,1)) + string_delete(disp_name,1,1);
                        }
                    }
                }
            } else if (variable_struct_exists(M,"species")) disp_name = string(M.species);
            else if (variable_struct_exists(M,"name"))     disp_name = string(M.name);
        }
        var name_x_ui = 120 + 2 + drawnIconW_ui + 6;
        var name_x_gui = OX + name_x_ui * S;
        draw_text(name_x_gui, row_y_gui, disp_name);
    }

    var ix1 = OX + INFO_X*S, iy1 = OY + INFO_Y*S;
    var ix2 = OX + (INFO_X+INFO_W)*S, iy2 = OY + (INFO_Y+INFO_H)*S;
    draw_set_color(C_PAPER);   draw_rectangle(ix1, iy1, ix2, iy2, false);
    draw_set_color(C_PAPER_E); draw_rectangle(ix1 - S, iy1 - S, ix2 + S, iy2 + S, true);

    if (n > 0){
        var Li = clamp(P.sel, 0, n - 1);
        var L = mons[Li];

        var nm_disp = "???";
        if (is_struct(L)){
            if (variable_struct_exists(L,"species_id")){
                var sid2 = L.species_id;
                if (is_real(sid2) && sid2 >= 0){
                    var idn2 = scr_poke_name_by_id(sid2);
                    if (string_length(idn2) > 0){
                        nm_disp = string_replace_all(idn2, "-", " ");
                        if (string_length(nm_disp) > 0){
                            nm_disp = string_upper(string_copy(nm_disp,1,1)) + string_delete(nm_disp,1,1);
                        }
                    }
                }
            } else if (variable_struct_exists(L,"species")) nm_disp = string(L.species);
            else if (variable_struct_exists(L,"name"))     nm_disp = string(L.name);
        }
        draw_set_color(c_white);
        draw_text(ix1 + 6*S, iy1 + 6*S, nm_disp);

        var nature_txt = "—";
        if (is_struct(L)){
            if (variable_struct_exists(L,"nature"))      nature_txt = string(L.nature);
            else if (variable_struct_exists(L,"Nature")) nature_txt = string(L.Nature);
            else if (variable_struct_exists(L,"nat"))    nature_txt = string(L.nat);
        }
        draw_text(ix1 + 6*S, iy1 + 20*S, "Nature: " + nature_txt);

        var hp_cur = 0; if (is_struct(L)){ if (variable_struct_exists(L,"hp")) hp_cur = L.hp; else if (variable_struct_exists(L,"HP")) hp_cur = L.HP; }
        var hp_max = 1; if (is_struct(L)){ if (variable_struct_exists(L,"maxhp")) hp_max = L.maxhp; else if (variable_struct_exists(L,"hp_max")) hp_max = L.hp_max; }
        if (!is_real(hp_max) || hp_max <= 0) hp_max = max(1, hp_cur);

        var lvl_val = 1; if (is_struct(L)){ if (variable_struct_exists(L,"level")) lvl_val = L.level; else if (variable_struct_exists(L,"lvl")) lvl_val = L.lvl; }

        var bar_x = ix1 + 6*S, bar_y = iy1 + 34*S, bar_w = (INFO_W - 12) * S, bar_h = 6 * S;
        draw_set_color(C_PAPER_E); draw_rectangle(bar_x - S, bar_y - S, bar_x + bar_w + S, bar_y + bar_h + S, true);

        var ratio = (hp_max > 0) ? clamp(hp_cur / hp_max, 0, 1) : 0;
        var hp_col = (ratio >= 0.5) ? make_color_rgb(56,200,72) : (ratio >= 0.2 ? make_color_rgb(248,200,40) : make_color_rgb(232,64,48));
        var fill_w = floor(bar_w * ratio);
        draw_set_color(hp_col); draw_rectangle(bar_x, bar_y, bar_x + fill_w, bar_y + bar_h, false);

        var hp_txt = string(hp_cur) + " / " + string(hp_max);
        var hp_tx  = bar_x + bar_w - string_width(hp_txt);
        var hp_ty  = bar_y + bar_h + (2*S) + 6;

        draw_set_color(c_white);
        draw_text(bar_x, hp_ty, "Lv " + string(lvl_val));
        draw_text(hp_tx, hp_ty, hp_txt); // <-- fixed: use hp_txt (no underscore)
    }

    if (string(P.mode) == "menu"){
        var MX = 96, MY = 20, MW = 76, MH = 84;
        var bx1 = OX + MX*S;
        var by1 = OY + MY*S;
        var bx2 = OX + (MX+MW)*S;
        var by2 = OY + (MY+MH)*S;

        draw_set_color(C_PAPER);   draw_rectangle(bx1, by1, bx2, by2, false);
        draw_set_color(C_PAPER_E); draw_rectangle(bx1 - S, by1 - S, bx2 + S, by2 + S, true);

        if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
        draw_set_color(c_white);

        var items = ["Summary","Switch","Item","Cancel"];
        var m_h   = max(12, string_height("A") + 2);
        var sprSelMenu = __party_asset_index_or("spr_selector");
        for (var i = 0; i < 4; i++){
            var yy_menu = by1 + (6 + i*m_h);
            if (i == P.menu_sel){
                if (sprite_exists(sprSelMenu)){
                    var selh = max(1, sprite_get_height(sprSelMenu));
                    var tgt  = m_h;
                    var sc   = tgt / selh;
                    draw_sprite_ext(sprSelMenu, 0, bx1 + 4*S, yy_menu - tgt*0.15, sc, sc, 0, c_white, 1);
                } else {
                    draw_text(bx1 + 4*S, yy_menu, "►");
                }
            }
            draw_text(bx1 + 16*S, yy_menu, items[i]);
        }
    }
}

// ---------- Summary / Description ----------
function __party_draw_summary(_pid, P, OX, OY, S){
    var C_BG    = make_color_rgb(224, 216, 248);
    var C_PAPER = make_color_rgb(255, 255, 255);
    var C_EDGE  = make_color_rgb(64, 56, 112);
    var C_ACC   = make_color_rgb(208, 48, 48);
    var C_TEXT  = c_white;

    draw_set_color(C_BG);   draw_rectangle(OX, OY, OX + 240*S, OY + 160*S, false);
    draw_set_color(C_EDGE); draw_rectangle(OX, OY, OX + 240*S, OY + 20*S, true);

    var mons = __party_mons(_pid), n = array_length(mons);
    for (var i = 0; i < 6; i++){
        var cx = OX + (104 + i*16)*S, cy = OY + 10*S;
        draw_set_color( (i < n) ? (i == P.sel ? C_ACC : C_PAPER) : make_color_rgb(136,136,136) );
        draw_circle(cx, cy, 4*S, false);
    }

    var LEFT_X = 8, LEFT_Y = 24, LEFT_W = 96, LEFT_H = 120;
    var RIGHT_X = 108, RIGHT_Y = 24, RIGHT_W = 124, RIGHT_H = 120;
    var lx1 = OX + LEFT_X*S,  ly1 = OY + LEFT_Y*S;
    var lx2 = OX + (LEFT_X + LEFT_W)*S, ly2 = OY + (LEFT_Y + LEFT_H)*S;
    var rx1 = OX + RIGHT_X*S, ry1 = OY + RIGHT_Y*S;
    var rx2 = OX + (RIGHT_X + RIGHT_W)*S, ry2 = OY + (RIGHT_Y + RIGHT_H)*S;

    draw_set_color(C_PAPER); draw_rectangle(lx1, ly1, lx2, ly2, false);
    draw_set_color(C_EDGE);  draw_rectangle(lx1- S, ly1- S, lx2+ S, ly2+ S, true);
    draw_set_color(C_PAPER); draw_rectangle(rx1, ry1, rx2, ry2, false);
    draw_set_color(C_EDGE);  draw_rectangle(rx1- S, ry1- S, rx2+ S, ry2+ S, true);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(C_TEXT);

    var sprBall = __party_asset_index_or("spr_bag_pokeball_small");

    var M = __party_mon_get(P, _pid);
    if (is_struct(M)){
        var nm = "???";
        if (variable_struct_exists(M,"species_id") && is_real(M.species_id)){
            var idn = scr_poke_name_by_id(M.species_id);
            if (string_length(idn) > 0){
                nm = string_replace_all(idn, "-", " ");
                if (string_length(nm) > 0) nm = string_upper(string_copy(nm,1,1)) + string_delete(nm,1,1);
            }
        } else if (variable_struct_exists(M,"species")) nm = string(M.species);
        else if (variable_struct_exists(M,"name"))     nm = string(M.name);
        draw_text(lx1 + 6*S, ly1 + 6*S, nm);

        var sprArt = -1;
        if (!is_undefined(pkicons_get_art96_by_mon)) sprArt = pkicons_get_art96_by_mon(M);
        if (!sprite_exists(sprArt)){
            var pl = __party_asset_index_or("spr_mon_placeholder");
            if (sprite_exists(pl)) sprArt = pl;
        }
        if (sprite_exists(sprArt)){
            var artW = sprite_get_width(sprArt), artH = sprite_get_height(sprArt);
            var boxW = (LEFT_W - 12) * S,       boxH = (LEFT_H - 36) * S;
            var sc   = min(boxW / artW, boxH / artH);
            var dx   = lx1 + (LEFT_W*S - artW*sc) * 0.5;
            var dy   = ly1 + 18*S + (boxH - artH*sc) * 0.5;
            draw_sprite_ext(sprArt, 0, dx, dy, sc, sc, 0, c_white, 1);
        }

        var lvl = 1; if (variable_struct_exists(M,"level")) lvl = M.level; else if (variable_struct_exists(M,"lvl")) lvl = M.lvl;
        draw_text(lx1 + 6*S, ly2 - 16*S, "Lv " + string(lvl));
        if (sprite_exists(sprBall)) draw_sprite_ext(sprBall,0,lx2 - 14*S,ly2 - 14*S,S,S,0,c_white,1);
    }

    if (string(P.mode) == "summary_profile"){
        __party_draw_profile_block(M, rx1, ry1, RIGHT_W, RIGHT_H, S);
    } else if (string(P.mode) == "summary_moves"){
        __party_draw_moves_block(P, M, rx1, ry1, RIGHT_W, RIGHT_H, S, false);
    } else if (string(P.mode) == "summary_forget"){
        __party_draw_moves_block(P, M, rx1, ry1, RIGHT_W, RIGHT_H, S, true);
    }
}

// ---------- Summary helpers ----------
function __party_draw_profile_block(_M, _x, _y, _w, _h, _S){
    var C_LABEL = make_color_rgb(40, 96, 96);
    var lh = max(12, string_height("A") + 2) * _S;
    draw_set_color(c_white); draw_text(_x + 6*_S, _y + 6*_S, "PROFILE");
    draw_set_color(C_LABEL);
    draw_text(_x + 6*_S, _y + 6*_S + lh*1, "OT/");
    draw_text(_x + 6*_S, _y + 6*_S + lh*2, "TYPE/");
    draw_text(_x + 6*_S, _y + 6*_S + lh*3, "ABILITY/");
    draw_text(_x + 6*_S, _y + 6*_S + lh*5, "TRAINER MEMO");
    draw_set_color(c_white);
    var ot="—", idno="—", typ="—", abi="—", nat="—", metLv="—", metMp="—";
    if (is_struct(_M)){
        if (variable_struct_exists(_M,"ot"))   ot   = string(_M.ot);
        if (variable_struct_exists(_M,"idno")) idno = string(_M.idno);
        if (variable_struct_exists(_M,"type")){
            if (is_array(_M.type)){
                var tA = string(_M.type[0]); var tB = (array_length(_M.type) > 1) ? string(_M.type[1]) : "";
                typ = (string_length(tB) > 0) ? (tA + " / " + tB) : tA;
            } else typ = string(_M.type);
        }
        if (variable_struct_exists(_M,"ability"))  abi  = string(_M.ability);
        if (variable_struct_exists(_M,"nature"))   nat  = string(_M.nature);
        if (variable_struct_exists(_M,"met_level")) metLv = string(_M.met_level);
        if (variable_struct_exists(_M,"met_map"))   metMp = string(_M.met_map);
    }
    draw_text(_x + 60*_S, _y + 6*_S + lh*1, ot + "   IDNo" + idno);
    draw_text(_x + 60*_S, _y + 6*_S + lh*2, typ);
    draw_text(_x + 60*_S, _y + 6*_S + lh*3, abi);
    draw_text(_x + 6*_S,  _y + 6*_S + lh*6, string_upper(nat) + " nature,");
    draw_text(_x + 6*_S,  _y + 6*_S + lh*7, "met at Lv." + metLv + ",");
    draw_text(_x + 6*_S,  _y + 6*_S + lh*8, metMp + ".");
}
function __party_draw_moves_block(_P, _M, _x, _y, _w, _h, _S, _highlightForget){
    var lh = max(12, string_height("A") + 2) * _S;
    draw_set_color(c_white);
    draw_text(_x + 6*_S, _y + 6*_S, "MOVES");
    draw_text(_x + _w*_S - 60*_S, _y + 6*_S, "LEARNSET");

    var mv = is_struct(_M) && variable_struct_exists(_M,"moves") ? _M.moves : [];
    var nm = array_length(mv);
    for (var i = 0; i < max(4,nm); i++){
        var lineY = _y + 20*_S + lh*i;
        var txt = (i < nm) ? __party_move_name(mv[i]) : "—";
        draw_set_color( i == _P.sum_move_sel ? (_highlightForget ? make_color_rgb(232,64,48) : make_color_rgb(72,200,88)) : c_white );
        draw_text(_x + 10*_S, lineY, txt);
    }

    var lr = is_struct(_M) && variable_struct_exists(_M,"learnset") ? _M.learnset : [];
    var nl = array_length(lr);
    for (var j = 0; j < nl; j++){
        var lineY2 = _y + 20*_S + lh*j;
        var txt2 = __party_move_name(lr[j]);
        draw_set_color( j == _P.sum_learn_sel ? make_color_rgb(72,160,232) : c_white );
        draw_text(_x + (_w*_S) - 110*_S, lineY2, txt2);
    }

    draw_set_color(c_white);
    if (_highlightForget) draw_text(_x + 6*_S, _y + (_h*_S) - 14*_S, "Choose a move to forget.  B: Back");
    else draw_text(_x + 6*_S, _y + (_h*_S) - 14*_S, "A: Learn  |  Hold Inventory + Up/Down: Choose Learnset  |  L/R: Switch  |  Up: Profile  |  B: Back");
}

// ---------- Entrypoint ----------
function party_draw_gui(_pid){
    var gw = display_get_gui_width();
    var gh = display_get_gui_height();
    party_draw_gui_rect(_pid, 0, 0, gw, gh);
}
