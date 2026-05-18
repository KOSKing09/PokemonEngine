// Party UI helpers (migrated from party_system.gml)
// Implementations are named __party_impl_* and are called by forwarding stubs in party_system.gml

// Draw the full party summary UI for player `_pid` at GUI origin (_OX,_OY).
// Renders left panel, right frame, and optional learnset UI based on `_P`.
function __party_impl_draw_summary(_pid, _P, _OX, _OY, _S){
    var _C_BG    = make_color_rgb(88, 176, 152);
    var _C_BG2   = make_color_rgb(64, 144, 136);
    var _C_PAPER = make_color_rgb(255, 243, 195);
    var _C_EDGE  = make_color_rgb(24, 80, 88);
    var _C_ACC   = make_color_rgb(48, 152, 112);
    var _C_TEXT  = c_white;

    gpu_set_blendmode(bm_normal);
    draw_set_color(_C_BG);   draw_rectangle(_OX, _OY, _OX + 240*_S, _OY + 160*_S, false);
    draw_set_color(_C_BG2);
    for (var _stripe = -160; _stripe < 260; _stripe += 18){
        draw_line_width(_OX + _stripe * _S, _OY + 160 * _S, _OX + (_stripe + 80) * _S, _OY, 4 * _S);
    }
    draw_set_color(make_color_rgb(32, 104, 112));
    draw_rectangle(_OX, _OY, _OX + 240*_S, _OY + 20*_S, false);
    draw_set_color(_C_EDGE); draw_rectangle(_OX, _OY, _OX + 240*_S, _OY + 20*_S, true);

    var _mons = __party_mons(_pid), _n = array_length(_mons);
    __party_impl_draw_header_and_circles(_P, _OX, _OY, _S, _n, _C_ACC, _C_PAPER);

    var _LEFT_X = 8, _LEFT_Y = 24, _LEFT_W = 96, _LEFT_H = 120;
    var _RIGHT_X = 108, _RIGHT_Y = 24, _RIGHT_W = 124, _RIGHT_H = 120;

    var _M = __party_mon_get(_P, _pid);
    if (!is_struct(_M)){
        var _firstValidIndex = -1;
        for (var _validMonIndex = 0; _validMonIndex < _n; _validMonIndex++){
            if (is_struct(_mons[_validMonIndex])){
                _firstValidIndex = _validMonIndex;
                break;
            }
        }

        if (_firstValidIndex >= 0){
            _P.sel = _firstValidIndex;
            _M = _mons[_firstValidIndex];
        } else {
            return;
        }
    }
    var _leftInfo = __party_impl_draw_left_panel(_P, _M, _OX, _OY, _S, _LEFT_X, _LEFT_Y, _LEFT_W, _LEFT_H);
    var _rightInfo = __party_impl_draw_right_frame(_OX, _OY, _S, _RIGHT_X, _RIGHT_Y, _RIGHT_W, _RIGHT_H);

    // Defensive reads for leftInfo geometry
    var _descPad = (is_struct(_leftInfo) && variable_struct_exists(_leftInfo, "descPad")) ? variable_struct_get(_leftInfo, "descPad") : (3 * _S);
    var _descAreaH = (is_struct(_leftInfo) && variable_struct_exists(_leftInfo, "descAreaH")) ? variable_struct_get(_leftInfo, "descAreaH") : (50 * _S);
    var _descX = (is_struct(_leftInfo) && variable_struct_exists(_leftInfo, "descX")) ? variable_struct_get(_leftInfo, "descX") : (_OX + _LEFT_X * _S + (3 * _S));
    var _descY = (is_struct(_leftInfo) && variable_struct_exists(_leftInfo, "descY")) ? variable_struct_get(_leftInfo, "descY") : ((_OY + (_LEFT_Y + _LEFT_H) * _S) - (50 * _S) + (3 * _S));
    var _descW = (is_struct(_leftInfo) && variable_struct_exists(_leftInfo, "descW")) ? variable_struct_get(_leftInfo, "descW") : (min((_LEFT_W + 10) * _S, (108 - _LEFT_X - 4) * _S) - (3 * _S) * 2);
    var _descH = (is_struct(_leftInfo) && variable_struct_exists(_leftInfo, "descH")) ? variable_struct_get(_leftInfo, "descH") : ((_descAreaH) - (_descPad) * 2);

    // Draw the 'LEARN MOVES' badge at a fixed GUI position when the
    // learn LIST is active (user requested fixed coords at 15,15).
    var _lp_tmp_for_badge = (variable_struct_exists(_P, "learn_pending") ? variable_struct_get(_P, "learn_pending") : undefined);
    if (is_struct(_lp_tmp_for_badge)){
        var _step_badge = (variable_struct_exists(_lp_tmp_for_badge, "step") ? variable_struct_get(_lp_tmp_for_badge, "step") : "desc");
        if (string(_step_badge) == "list"){
            var _badgeGuiX = _OX + 15 * _S;
            var _badgeGuiY = _OY + 15 * _S - 5 * _S; // nudge up 5 UI pixels
            draw_set_color(make_color_rgb(220,40,40));
            if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);
            draw_text(_badgeGuiX, _badgeGuiY, "LEARN");
            if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
            draw_set_color(c_white);
        }
    }

    // Compute left description text. If a learn flow is active and the
    // user is viewing the learn list, show the currently-selected learn
    // move's short description instead of the mon's default description.
    var _lp = (variable_struct_exists(_P, "learn_pending") ? variable_struct_get(_P, "learn_pending") : undefined);
    var _descText = __party_get_desc_text(_P, _M);
    if (is_struct(_lp)){
        var _step_tmp = (variable_struct_exists(_lp, "step") ? variable_struct_get(_lp, "step") : "desc");
        // Debug: if the UI is about to show the full learn LIST unexpectedly,
        // print the current mode and learn_pending.step so the runtime trace
        // can help locate the state mutation source.
        if (string(_P.mode) == "summary_moves" && string(_step_tmp) != "desc"){
            // debug removed
        }
        if (string(_step_tmp) != "desc"){
            // Determine currently-selected move id from learn_pending.list_sel and global index
            var _sel_idx = (variable_struct_exists(_lp, "list_sel") ? variable_struct_get(_lp, "list_sel") : 0);
            var _move_id_candidate = -1;
            if (variable_struct_exists(_lp, "source_machine") && variable_struct_get(_lp, "source_machine") == true && variable_struct_exists(_lp, "move_id")){
                _move_id_candidate = variable_struct_get(_lp, "move_id");
            } else if (variable_global_exists("_move_index") && is_array(global._move_index)){
                var _mi = global._move_index;
                if (is_array(_mi) && _sel_idx >= 0 && _sel_idx < array_length(_mi)) _move_id_candidate = _mi[_sel_idx];
            }
            if (_move_id_candidate < 0 && variable_struct_exists(_lp, "move_id")) _move_id_candidate = variable_struct_get(_lp, "move_id");
            // Resolve short description from global._move_text if available
            if (is_real(_move_id_candidate) && _move_id_candidate >= 0 && variable_global_exists("_move_text") && is_array(global._move_text) && _move_id_candidate < array_length(global._move_text)){
                var _mvtmp = global._move_text[_move_id_candidate];
                if (is_string(_mvtmp)) _descText = _mvtmp;
                else if (is_struct(_mvtmp) && variable_struct_exists(_mvtmp, "short_desc")) _descText = variable_struct_get(_mvtmp, "short_desc");
                if (string_length(string_trim(_descText)) == 0) _descText = "No description available.";
            }
        }
    }
    // If a learn flow is pending, render the learn badge at the top-left
    // of the left description box and either the description page or the
    // selectable move list depending on state.
    var _lp = (variable_struct_exists(_P, "learn_pending") ? variable_struct_get(_P, "learn_pending") : undefined);
    // (Badge next to the Pokémon name is drawn below; no top-left badge here.)
    if (is_struct(_lp)){
    // badge drawing moved into the left panel beside the Pokémon name
        var _step = (variable_struct_exists(_lp, "step") ? variable_struct_get(_lp, "step") : "desc");
    // Only show the full right-panel learn LIST when the player is explicitly
    // viewing the moves summary (mode == "summary_moves") AND the learn
    // flow requested the list step. In other modes (e.g. summary_forget)
    // we prefer showing the description/left-box to avoid overlaying UIs.
        // Show description unless the learn flow explicitly requested the list
        // and the current mode allows list rendering (summary_moves OR summary_forget).
        if (string(_step) == "desc" || (string(_P.mode) != "summary_moves" && string(_P.mode) != "summary_forget")){
        __party_draw_learn_desc(_pid, _P, _OX, _OY, _S, _descX, _descY, _descW, _descH);
    } else {
        // draw the move list in the right panel area (guarded reads)
        var _rx = (is_struct(_rightInfo) && variable_struct_exists(_rightInfo, "rx1")) ? variable_struct_get(_rightInfo, "rx1") : (_OX + _RIGHT_X*_S);
        var _ry = (is_struct(_rightInfo) && variable_struct_exists(_rightInfo, "ry1")) ? variable_struct_get(_rightInfo, "ry1") : (_OY + _RIGHT_Y*_S);
        __party_impl_draw_learn_panel_frame(_rx, _ry, _RIGHT_W, _RIGHT_H, _S);
        // Now draw the selectable learn list
        __party_draw_learn_list(_pid, _P, _OX, _OY, _S, _rx, _ry, _RIGHT_W, _RIGHT_H, _descX, _descY, _descW, _descH);
    }
    } else {
        if (string_length(_descText) > 0) {
            var _clean = __party_impl_desc_clean_local(_descText);
            __party_impl_desc_draw_scrollable_colored(_descX, _descY, _descW, _descH, _clean);
        }
    }

    var _secondaryLine = __party_impl_draw_right_content(_P, _M, _rightInfo, _RIGHT_W, _RIGHT_H, _S);

    if (string_length(_secondaryLine) > 0){
        __party_impl_draw_secondary_help(_secondaryLine, _OX, _S, _leftInfo);
    }
}

function __party_impl_mon_get_any(_M, _keys, _fallback){
    if (!is_struct(_M)) return _fallback;
    for (var _i = 0; _i < array_length(_keys); ++_i){
        if (variable_struct_exists(_M, _keys[_i])){
            var _v = variable_struct_get(_M, _keys[_i]);
            if (!is_undefined(_v)) return _v;
        }
    }
    return _fallback;
}

function __party_impl_mon_get_number(_M, _keys, _fallback){
    var _v = __party_impl_mon_get_any(_M, _keys, _fallback);
    if (is_real(_v)) return floor(_v);
    if (is_string(_v) && string_length(string_trim(_v)) > 0){
        var _r = real(_v);
        if (is_real(_r)) return floor(_r);
    }
    return _fallback;
}

function __party_impl_struct_number(_Sct, _keys, _fallback){
    if (!is_struct(_Sct)) return _fallback;
    for (var _i = 0; _i < array_length(_keys); ++_i){
        if (variable_struct_exists(_Sct, _keys[_i])){
            var _v = variable_struct_get(_Sct, _keys[_i]);
            if (is_real(_v)) return floor(_v);
            if (is_string(_v) && string_length(string_trim(_v)) > 0){
                var _r = real(_v);
                if (is_real(_r)) return floor(_r);
            }
        }
    }
    return _fallback;
}

function __party_impl_fit_text(_txt, _maxW){
    var _out = string(_txt);
    if (string_width(_out) <= _maxW) return _out;
    while (string_width(_out + "...") > _maxW && string_length(_out) > 3){
        _out = string_copy(_out, 1, string_length(_out) - 1);
    }
    return (string_length(_out) > 3) ? (_out + "...") : _out;
}

function __party_impl_draw_scaled_outline(_x1, _y1, _x2, _y2, _thick, _col){
    var _t = max(1, _thick);
    draw_set_color(_col);
    draw_rectangle(_x1, _y1, _x2, _y1 + _t, false);
    draw_rectangle(_x1, _y2 - _t, _x2, _y2, false);
    draw_rectangle(_x1, _y1, _x1 + _t, _y2, false);
    draw_rectangle(_x2 - _t, _y1, _x2, _y2, false);
}

function __party_impl_mon_type_text(_M){
    var _sid_try = __party_impl_mon_get_number(_M, ["species_id","species","id","_id"], -1);
    if (_sid_try >= 0 && !is_undefined(scr_poke_type_str)){
        var _resolved = scr_poke_type_str(_sid_try);
        if (string_length(string_trim(_resolved)) > 0) return _resolved;
    }
    var _t1 = string(__party_impl_mon_get_any(_M, ["type1"], ""));
    var _t2 = string(__party_impl_mon_get_any(_M, ["type2"], ""));
    if (string_length(string_trim(_t1)) > 0 && string_length(string_trim(_t2)) > 0 && _t2 != _t1) return _t1 + "/" + _t2;
    if (string_length(string_trim(_t1)) > 0) return _t1;
    var _raw = __party_impl_mon_get_any(_M, ["type"], "");
    if (is_array(_raw) && array_length(_raw) > 0){
        var _out = string(_raw[0]);
        for (var _i = 1; _i < array_length(_raw); ++_i) _out += "/" + string(_raw[_i]);
        return _out;
    }
    if (string_length(string_trim(string(_raw))) > 0) return string(_raw);
    return "--";
}

function __party_impl_mon_stat_value(_M, _stat){
    if (_stat == "HP") return __party_impl_mon_get_number(_M, ["hp_max","maxhp","max_hp","hp"], 0);
    if (_stat == "ATK") return __party_impl_mon_get_number(_M, ["attack","atk","stat_atk"], 0);
    if (_stat == "DEF") return __party_impl_mon_get_number(_M, ["defense","def","stat_def"], 0);
    if (_stat == "SP.A") return __party_impl_mon_get_number(_M, ["special_attack","sp_atk","spatk","spa","stat_spa"], 0);
    if (_stat == "SP.D") return __party_impl_mon_get_number(_M, ["special_defense","sp_def","spdef","spd","stat_spd"], 0);
    if (_stat == "SPD") return __party_impl_mon_get_number(_M, ["speed","spe","stat_spe"], 0);
    return 0;
}

function __party_impl_mon_iv_ev_text(_M, _fieldName, _prefix){
    var _box = is_struct(_M) && variable_struct_exists(_M, _fieldName) ? variable_struct_get(_M, _fieldName) : undefined;
    var _hp = __party_impl_struct_number(_box, ["hp"], __party_impl_mon_get_number(_M, [_prefix + "_hp"], 0));
    var _at = __party_impl_struct_number(_box, ["atk","attack"], __party_impl_mon_get_number(_M, [_prefix + "_atk"], 0));
    var _df = __party_impl_struct_number(_box, ["def","defense"], __party_impl_mon_get_number(_M, [_prefix + "_def"], 0));
    var _sa = __party_impl_struct_number(_box, ["spa","sp_atk","spatk","special_attack"], __party_impl_mon_get_number(_M, [_prefix + "_spa", _prefix + "_sp_atk"], 0));
    var _sd = __party_impl_struct_number(_box, ["spd","sp_def","spdef","special_defense"], __party_impl_mon_get_number(_M, [_prefix + "_spd", _prefix + "_sp_def"], 0));
    var _sp = __party_impl_struct_number(_box, ["spe","speed"], __party_impl_mon_get_number(_M, [_prefix + "_spe", _prefix + "_speed"], 0));
    return string(_hp) + "/" + string(_at) + "/" + string(_df) + "/" + string(_sa) + "/" + string(_sd) + "/" + string(_sp);
}

function __party_impl_draw_summary_row(_x, _y, _label, _value, _maxW, _S){
    var _boxH = max(9 * _S, string_height("A") + 3);
    draw_set_color(make_color_rgb(24, 96, 96));
    var _ty = _y + max(0, (_boxH - string_height("A")) * 0.5) - _S;
    draw_text(_x, _ty, _label);
    draw_set_color(make_color_rgb(32, 48, 56));
    var _vx = _x + 38 * _S;
    draw_text(_vx, _ty, __party_impl_fit_text(_value, max(8, _maxW - 38 * _S)));
}

function __party_impl_draw_summary_pair_row(_x, _y, _l1, _v1, _l2, _v2, _maxW, _S){
    var _gap = 3 * _S;
    var _half = floor((_maxW - _gap) * 0.5);
    var _boxH = max(9 * _S, string_height("A") + 3);
    var _ty = _y + max(0, (_boxH - string_height("A")) * 0.5) - _S;
    draw_set_color(make_color_rgb(24, 96, 96));
    draw_text(_x, _ty, _l1);
    draw_text(_x + _half + _gap, _ty, _l2);
    draw_set_color(make_color_rgb(32, 48, 56));
    draw_text(_x + 25*_S, _ty, __party_impl_fit_text(_v1, max(8, _half - 25*_S)));
    draw_text(_x + _half + _gap + 25*_S, _ty, __party_impl_fit_text(_v2, max(8, _half - 25*_S)));
}

// Draw the profile info block for a single mon (_M) into the left column.
// Shows OT, types, ability, nature, and trainer memo fields.
function __party_impl_draw_profile_block(_M, _x, _y, _w, _h, _S){
    var _oldFont = draw_get_font();
    if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);
    var _C_ACC = make_color_rgb(48, 152, 112);
    var _C_TEXT = make_color_rgb(32, 48, 56);
    var _C_LINE = make_color_rgb(128, 184, 152);
    var _C_BOX = make_color_rgb(255, 248, 216);
    var _innerX = _x + 5 * _S;
    var _innerW = (_w * _S) - 10 * _S;
    var _textX = _innerX + 4 * _S;
    var _textW = _innerW - 4 * _S;
    var _textYOff = 4 * _S;
    var _boxH = max(8 * _S, string_height("A") + 2);
    var _rowH = floor(((_h * _S) - 20 * _S) / 10);
    _rowH = max(string_height("A") + 1, _rowH);

    draw_set_color(make_color_rgb(255, 248, 216));
    draw_rectangle(_x + 3*_S, _y + 15*_S, _x + (_w*_S) - 3*_S, _y + (_h*_S) - 3*_S, false);
    __party_impl_draw_scaled_outline(_x + 3*_S, _y + 15*_S, _x + (_w*_S) - 3*_S, _y + (_h*_S) - 3*_S, _S, make_color_rgb(184, 216, 176));

    draw_set_color(_C_ACC);
    draw_rectangle(_x + 3*_S, _y + 3*_S, _x + (_w*_S) - 3*_S, _y + 13*_S, false);
    __party_impl_text_white(_textX + 2*_S, _y + 3*_S + _textYOff, "POKEMON DATA");

    var _ot = string(__party_impl_mon_get_any(_M, ["ot","original_trainer","trainer"], "--"));
    var _idno = string(__party_impl_mon_get_any(_M, ["idno","id_no","trainer_id"], "--"));
    var _typ = __party_impl_mon_type_text(_M);
    var _abi = string(__party_impl_mon_get_any(_M, ["ability","ability_name"], "--"));
    var _nat = string(__party_impl_mon_get_any(_M, ["nature","nature_name"], "--"));
    var _sex = string(__party_impl_mon_get_any(_M, ["sex","gender"], "--"));
    var _held = string(__party_impl_mon_get_any(_M, ["held_item_name","held_item_real_name","held_item_identifier","held_item","item"], "None"));
    var _metLv = string(__party_impl_mon_get_any(_M, ["met_level","met_lvl"], "--"));
    var _metMp = string(__party_impl_mon_get_any(_M, ["met_map","met_location","met_place"], "--"));
    var _curHp = __party_impl_mon_get_number(_M, ["hp_now","hp_current","current_hp","hp"], 0);
    var _maxHp = max(_curHp, __party_impl_mon_stat_value(_M, "HP"));
    var _exp = __party_impl_mon_get_number(_M, ["exp","experience"], 0);
    var _next = __party_impl_mon_get_number(_M, ["exp_next","next_exp","experience_next"], 0);

    var _yy = _y + 15 * _S + _textYOff;
    __party_impl_draw_summary_pair_row(_textX, _yy, "TYPE", _typ, "SEX", _sex, _textW, _S); _yy += _rowH;
    __party_impl_draw_summary_pair_row(_textX, _yy, "NAT", _nat, "ITEM", _held, _textW, _S); _yy += _rowH;
    __party_impl_draw_summary_row(_textX, _yy, "ABILITY", _abi, _textW, _S); _yy += _rowH;
    __party_impl_draw_summary_pair_row(_textX, _yy, "OT", _ot, "ID", _idno, _textW, _S); _yy += _rowH;

    var _dividerLift = 5 * _S;
    draw_set_color(_C_LINE); draw_rectangle(_textX, _yy - _dividerLift, _textX + _textW, _yy - _dividerLift + max(1, _S), false);
    _yy += max(2, _S);
    var _statTitleY = _yy + max(0, (_boxH - string_height("A")) * 0.5) - _S;
    draw_set_color(_C_ACC); draw_text(_textX, _statTitleY, "STATS");
    draw_set_color(_C_TEXT); draw_text(_textX + 38*_S, _statTitleY, "HP " + string(_curHp) + "/" + string(_maxHp));
    _yy += _rowH;

    var _expText = string(_exp);
    if (_next > 0) _expText += "/" + string(_next);
    var _statLabels = ["ATK","DEF","SP.A","SP.D","SPD","EXP"];
    for (var _si = 0; _si < array_length(_statLabels); ++_si){
        var _sx = _textX + (((_si mod 2) == 0) ? 0 : 58 * _S);
        var _sy = _yy + floor(_si / 2) * _rowH;
        var _sl = _statLabels[_si];
        var _sty = _sy + max(0, (_boxH - string_height("A")) * 0.5) - _S;
        draw_set_color(make_color_rgb(24, 96, 96)); draw_text(_sx, _sty, _sl);
        var _sv = (_sl == "EXP") ? _expText : string(__party_impl_mon_stat_value(_M, _sl));
        draw_set_color(_C_TEXT); draw_text(_sx + 24*_S, _sty, __party_impl_fit_text(_sv, 31*_S));
    }
    _yy += 3 * _rowH;

    draw_set_color(_C_LINE); draw_rectangle(_textX, _yy - _dividerLift, _textX + _textW, _yy - _dividerLift + max(1, _S), false);
    _yy += max(2, _S);
    __party_impl_draw_summary_pair_row(_textX, _yy, "IV", __party_impl_mon_iv_ev_text(_M, "ivs", "iv"), "EV", __party_impl_mon_iv_ev_text(_M, "evs", "ev"), _textW, _S); _yy += _rowH;

    draw_set_font(_oldFont);
    return;

    var _C_LABEL = make_color_rgb(40, 96, 96);
    var _lh = max(12, string_height("A") + 2) * _S;
    __party_impl_text_white(_x + 6*_S, _y + 6*_S, "PROFILE");
    draw_set_color(_C_LABEL);
    draw_text(_x + 6*_S, _y + 6*_S + _lh*1, "OT/");
    draw_text(_x + 6*_S, _y + 6*_S + _lh*2, "TYPE/");
    draw_text(_x + 6*_S, _y + 6*_S + _lh*3, "ABILITY/");
    draw_text(_x + 6*_S, _y + 6*_S + _lh*5, "TRAINER MEMO");
    draw_set_color(c_white);
    var _ot="—", _idno="—", _typ="", _abi="—", _nat="—", _metLv="—", _metMp="—";
    if (is_struct(_M)){
        if (variable_struct_exists(_M,"ot"))   _ot   = string(_M.ot);
        if (variable_struct_exists(_M,"idno")) _idno = string(_M.idno);
        var _type_names = [];
        if (variable_struct_exists(_M,"type")){
            if (is_array(_M.type)){
                for (var ti=0; ti<array_length(_M.type); ti++) array_push(_type_names, string(_M.type[ti]));
            } else {
                array_push(_type_names, string(_M.type));
            }
        }
        if (array_length(_type_names) == 0 && variable_struct_exists(_M,"types") && is_array(_M.types)){
            for (var ti2=0; ti2<array_length(_M.types); ti2++){
                var tid = _M.types[ti2];
                if (is_real(tid)) array_push(_type_names, "#"+string(tid));
            }
        }
        if (array_length(_type_names) == 0){
            if (variable_struct_exists(_M,"type1") && is_real(_M.type1) && _M.type1 >= 0) array_push(_type_names, "#"+string(_M.type1));
            if (variable_struct_exists(_M,"type2") && is_real(_M.type2) && _M.type2 >= 0) array_push(_type_names, "#"+string(_M.type2));
        }

        // If no explicit type info on the mon struct, prefer species-level resolver
        if (array_length(_type_names) == 0){
            var _sid_try = -1;
            if (variable_struct_exists(_M, "species_id") && is_real(_M.species_id)) _sid_try = floor(_M.species_id);
            else if (variable_struct_exists(_M, "_id") && is_real(_M._id)) _sid_try = floor(_M._id);
            if (_sid_try >= 0 && !is_undefined(scr_poke_type_str)){
                var _resolved = scr_poke_type_str(_sid_try);
                if (string_length(string_trim(_resolved)) > 0) _typ = _resolved;
            }
        }

        // If _typ wasn't set by the resolver above, fall back to local name resolution
        if (string_length(_typ) == 0){
            for (var tn = 0; tn < array_length(_type_names); tn++){
                var cur = _type_names[tn];
                if (string_length(cur) > 0 && string_char_at(cur,1) == "#"){
                    var nid = real(string_delete(cur,1,1));
                    var resolved = "";
                    if (variable_global_exists("TYPE_ID_BY_NAME")){
                        var _map_tmp = variable_global_get("TYPE_ID_BY_NAME");
                        if (!is_undefined(_map_tmp) && ds_exists(_map_tmp, ds_type_map)){
                            var _k = ds_map_find_first(_map_tmp);
                            while(_k != undefined){
                                var _v = ds_map_find_value(_map_tmp, _k);
                                if (is_real(_v) && _v == nid){ resolved = string(_k); break; }
                                _k = ds_map_find_next(_map_tmp, _k);
                            }
                        }
                    }
                    if (string_length(resolved) == 0){
                        var __builtin = ["Normal","Fire","Water","Electric","Grass","Ice","Fighting","Poison","Ground","Flying","Psychic","Bug","Rock","Ghost","Dark","Dragon","Steel","Fairy"];
                        if (nid >= 1 && nid <= array_length(__builtin)) resolved = __builtin[nid - 1];
                        else resolved = "Type"+string(nid);
                    }
                    _type_names[tn] = resolved;
                } else {
                    var s = string(cur);
                    if (string_length(s) > 0) _type_names[tn] = string_upper(string_copy(s,1,1)) + string_delete(s,1,1);
                }
            }
            if (array_length(_type_names) > 0){
                _typ = _type_names[0];
                for (var __ti = 1; __ti < array_length(_type_names); ++__ti) _typ += "/" + _type_names[__ti];
            }
        }
        if (variable_struct_exists(_M,"ability"))  _abi  = string(_M.ability);
        if (variable_struct_exists(_M,"nature"))   _nat  = string(_M.nature);
        if (variable_struct_exists(_M,"met_level")) _metLv = string(_M.met_level);
        if (variable_struct_exists(_M,"met_map"))   _metMp = string(_M.met_map);
    }
    // If no type resolved, show placeholder
    if (string_length(string_trim(_typ)) == 0) _typ = "—";
    var _ot_label_x = _x + 6*_S;
    var _ot_value_x = _ot_label_x + string_width("OT/") + 4;
    draw_text(_ot_value_x, _y + 6*_S + _lh*1, _ot);
    var _type_label_x = _x + 6*_S;
    var _type_value_x = _type_label_x + string_width("TYPE/") + 4;
    draw_text(_type_value_x, _y + 6*_S + _lh*2, _typ);
    draw_text(_x + 60*_S, _y + 6*_S + _lh*3, _abi);
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*6, string_upper(_nat) + " nature,");
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*7, "met at Lv." + _metLv + ",");
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*8, _metMp + ".");
}

// Draw the moves block (right-side) showing current moves and help hints.
// If `_highlightForget` is true, highlight selection for forgetting/replacing.
function __party_impl_draw_moves_block(_P, _M, _x, _y, _w, _h, _S, _highlightForget){
    var _lh = max(12, string_height("A") + 2) * _S;
    draw_set_color(c_white);
    var _pendingLearnMove = -1;
    if (_highlightForget && is_struct(_P) && variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
        var _lp_forget_draw = variable_struct_get(_P, "learn_pending");
        if (variable_struct_exists(_lp_forget_draw, "move_id")) _pendingLearnMove = variable_struct_get(_lp_forget_draw, "move_id");
    }
    draw_text(_x + 6*_S, _y + 6*_S, _highlightForget ? "FORGET?" : "MOVES");
    if (_highlightForget && is_real(_pendingLearnMove) && _pendingLearnMove > 0){
        draw_set_color(make_color_rgb(72, 200, 88));
        var _learnLabel = "Learn " + __party_move_name(_pendingLearnMove);
        var _learnMaxW = (_w * _S) - 12 * _S;
        while (string_width(_learnLabel) > _learnMaxW && string_length(_learnLabel) > 6){
            _learnLabel = string_copy(_learnLabel, 1, string_length(_learnLabel) - 1);
        }
        draw_text(_x + 6*_S, _y + 16*_S, _learnLabel);
    }

    var _mv = is_struct(_M) && variable_struct_exists(_M,"moves") ? _M.moves : [];
    var _nm = array_length(_mv);
    for (var _i = 0; _i < max(4,_nm); _i++){
        var _lineY = _y + (_highlightForget ? 32 : 20) * _S + _lh*_i;
        // Draw existing move name or a blank placeholder for empty slots so
        // the player can visually see and learn into empty slots.
        var _txt = (_i < _nm) ? __party_move_name(_mv[_i]) : "-----";
        if (_i == _P.sum_move_sel){
            if (_highlightForget){
                draw_set_color(make_color_rgb(216, 72, 56));
                draw_rectangle(_x + 6*_S, _lineY - 6*_S, _x + (_w*_S) - 6*_S, _lineY + _lh - 6*_S, false);
                draw_set_color(make_color_rgb(112, 32, 32));
                draw_rectangle(_x + 6*_S, _lineY - 6*_S, _x + (_w*_S) - 6*_S, _lineY + _lh - 6*_S, true);
                draw_set_color(c_white);
                draw_text(_x + 10*_S, _lineY, "> " + _txt);
            } else {
                draw_set_color(make_color_rgb(72,200,88));
                draw_text(_x + 10*_S, _lineY, _txt);
            }
        } else {
            draw_set_color(c_white);
            draw_text(_x + 10*_S, _lineY, _txt);
        }
    }

    // Do not render the small learnset column here. The small column can
    // overlap or duplicate the full learn list UI. The full right-panel
    // learn list is drawn only when the player explicitly enters the
    // learn LIST (learn_pending.step == "list").
    var _renderLearnsetHere = false;
    var _lr = is_struct(_M) && variable_struct_exists(_M,"learnset") ? _M.learnset : [];
    var _nl = array_length(_lr);
    // small learnset column intentionally disabled

    draw_set_color(c_white);
    var _primaryHelp, _secondaryHelp;
    if (_highlightForget){
        _primaryHelp   = "A: Confirm  B: Back";
        _secondaryHelp = "(Choose a move to overwrite)";
    } else {
        _primaryHelp   = "A: Learn  B: Back";
        _secondaryHelp = "Hold Inv+Up/Down: Learnset";
    }
    var _tx = _x + 6*_S;
    var _lhh = max(12, string_height("A") + 2);
    var _innerBottomPad = 6*_S;
    var _pMaxW = (_w*_S) - 12*_S;
    var _aLine, _bLine;
    if (_highlightForget){ _aLine = "A: Confirm"; _bLine = "B: Back"; }
    else { _aLine = "A: Learn"; _bLine = "B: Back"; }
    function _party_trunc_line(_t,_mw){
        if (string_width(_t) <= _mw) return _t;
        while (string_width(_t + "...") > _mw && string_length(_t) > 4){
            _t = string_copy(_t,1,string_length(_t)-1);
        }
        if (string_length(_t) > 3) _t += "...";
        return _t;
    }
    _aLine = _party_trunc_line(_aLine,_pMaxW);
    _bLine = _party_trunc_line(_bLine,_pMaxW);
    var _pyBottom = _y + (_h*_S) - _lhh - _innerBottomPad;
    var _pyTop    = _pyBottom - _lhh;
    draw_text(_tx, _pyTop, _aLine);
    draw_text(_tx, _pyBottom, _bLine);
    return _secondaryHelp;
}

// Draw a short two-line secondary help string below the main panels.
function __party_impl_draw_secondary_help(_text, _OX, _S, _leftInfo){
    var _fullLeft  = _OX + 0;
    var _fullRight = _OX + 240*_S;
    var _availW = _fullRight - _fullLeft - 4*_S;
    var _drawX = _fullLeft + 2*_S;
    var _baseY = (_leftInfo.descY + _leftInfo.descH) + 11*_S;
    draw_set_color(c_white);
    var _words = string_split(_text, " ");
    var _lines = [];
    var _acc = "";
    for (var i=0; i<array_length(_words); i++){
        var w = _words[i];
        var t = (_acc == "") ? w : (_acc + " " + w);
        if (string_width(t) <= _availW){ _acc = t; }
        else { if (string_length(_acc) > 0) array_push(_lines, _acc); _acc = w; }
        if (array_length(_lines) >= 2) break;
    }
    if (array_length(_lines) < 2 && string_length(_acc) > 0) array_push(_lines, _acc);
    if (array_length(_lines) > 2) array_resize(_lines, 2);
    if (array_length(_lines) == 2 && i < array_length(_words)){
        var last = _lines[1];
        while (string_width(last + "...") > _availW && string_length(last) > 5){ last = string_copy(last,1,string_length(last)-1); }
        if (string_length(last) > 3) last += "...";
        _lines[1] = last;
    }
    var _lineHeight = max(12, string_height("A") + 2);
    for (var li=0; li<array_length(_lines); li++){
        draw_text(_drawX, _baseY + li * _lineHeight, _lines[li]);
    }
}

// Draw the left panel with mon artwork, level, and small badges.
// Returns geometry info used by other draw helpers (descX, descY, descW, descH).
function __party_impl_draw_left_panel(_P, _M, _OX, _OY, _S, _LEFT_X, _LEFT_Y, _LEFT_W, _LEFT_H){
    var _lx1 = _OX + _LEFT_X*_S,  _ly1 = _OY + _LEFT_Y*_S;
    var _lx2 = _OX + (_LEFT_X + _LEFT_W)*_S, _ly2 = _OY + (_LEFT_Y + _LEFT_H)*_S;
    var _PARCHMENT = make_color_rgb(255,243,195);
    draw_set_color(_PARCHMENT); draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
    draw_set_color(make_color_rgb(248, 224, 160));
    __party_impl_draw_scaled_outline(_lx1 + 2*_S, _ly1 + 2*_S, _lx2 - 2*_S, _ly2 - 2*_S, _S, make_color_rgb(248, 224, 160));
    var _C_EDGE = make_color_rgb(24, 80, 88);
    __party_impl_draw_scaled_outline(_lx1- _S, _ly1- _S, _lx2+ _S, _ly2+ _S, 2*_S, _C_EDGE);

    var _DESC_PAD = 3 * _S;
    var _DESC_AREA_H = 50 * _S;

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    if (is_struct(_M)){
        var _nm = __party_impl_species_display_name(_M);
        draw_text(_lx1 + 6*_S, _ly1 + 6*_S, _nm);

        // (Badge moved to level area) — no badge drawn here any more.

        var _sprArt = -1;
        if (!is_undefined(pkicons_get_art96_by_mon)) _sprArt = pkicons_get_art96_by_mon(_M);
        if (_sprArt == -1) _sprArt = spr_mon_placeholder;

        if (_sprArt != -1){
            var _artW = sprite_get_width(_sprArt), _artH = sprite_get_height(_sprArt);
            var _innerW   = (_LEFT_W - 12) * _S;
            var _topY     = _ly1 + 18 * _S;
            var _bottomY  = _ly2 - _DESC_AREA_H - PARTY_SUMMARY_ART_MARGIN * _S;
            var _availH   = max(1, _bottomY - _topY);
            var _sc   = min(_innerW / _artW, _availH / _artH);
            var _dx   = _lx1 + (_LEFT_W * _S - _artW * _sc) * 0.5 + (PARTY_SUMMARY_ART_OFFSET_X * _S);
            var _idealY = _topY + (_availH - _artH * _sc) * 0.5;
            var _dy   = clamp(_idealY + (PARTY_SUMMARY_ART_OFFSET_Y * _S), _topY, _bottomY - _artH * _sc);
            var _sub = 0;
            if (!is_undefined(pkicons_get_art96_subimg_by_mon)) _sub = pkicons_get_art96_subimg_by_mon(_M,false);

            var _anim_scale = 1;
            var _anim_offx = 0;
            var _anim_offy = 0;
            if (is_struct(_P) && variable_struct_exists(_P,"summary_sprite_anim_start_ms") && _P.summary_sprite_anim_active){
                var _start = _P.summary_sprite_anim_start_ms;
                var _D_ms = 420;
                var _elapsed = max(0, current_time - _start);
                var _t = clamp(_elapsed / _D_ms, 0, 1);
                var _peak = 1.18;
                var _rise = sin(min(_t * 1.6, 1) * pi * 0.5);
                if (_t < 0.6) _anim_scale = lerp(1, _peak, _rise);
                else _anim_scale = lerp(_peak, 1, ( _t - 0.6 ) / 0.4 );
                var _shake_amp = 2 * _S * (1 - _t);
                var _time_s = current_time / 1000;
                _anim_offx = lengthdir_x(_shake_amp, (_time_s*360 + (_P.sel*37)) mod 360);
                _anim_offy = lengthdir_y(_shake_amp, (_time_s*360 + (_P.sel*51)) mod 360);
                if (_t >= 1){ _P.summary_sprite_anim_active = false; _P.summary_sprite_anim_start_ms = -1; }
            }

            draw_sprite_ext(_sprArt, _sub, _dx + _anim_offx, _dy + _anim_offy, _sc * _anim_scale, _sc * _anim_scale, 0, c_white, 1);
            if (is_struct(_M) && variable_struct_exists(_M,"shiny") && _M.shiny && !is_undefined(__party_impl_draw_shiny_sparkle)){
                var _sx = _dx + _artW * _sc * 0.78;
                var _sy = _dy + _artH * _sc * 0.22;
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                        var _dbg_uid = (variable_struct_exists(_M,"_debug_uid") ? string(_M._debug_uid) : "-1");
                        var _sub = -1; try { _sub = pkicons_get_art96_subimg_by_mon(_M,false); } catch (e_sub) { _sub = -2; }
                    }
                    __party_impl_draw_shiny_sparkle(_sx,_sy,_S, (_M.species_id) ?? 0);
            }
        }

        var _lvl = 1; if (variable_struct_exists(_M,"level")) _lvl = _M.level; else if (variable_struct_exists(_M,"lvl")) _lvl = _M.lvl;
        var _name_lh = max(12, string_height("A") + 2) * _S;
        draw_text(_lx1 + 6*_S, _ly1 + 6*_S + _name_lh, "Lv " + string(_lvl));
        // Draw 'LEARN MOVES' badge to the right of the level if there are
        // filtered learnset entries that the player hasn't inspected yet.
        var _filtered_ls = __party_get_learnset_for_mon(_M);
        var _has_unseen = false;
        if (is_array(_filtered_ls) && array_length(_filtered_ls) > 0){
            var _sm = (variable_struct_exists(_M, "seen_moves") ? variable_struct_get(_M, "seen_moves") : []);
            for (var __li = 0; __li < array_length(_filtered_ls); __li++){
                var __midv = _filtered_ls[__li];
                var __f = false;
                for (var __si2 = 0; __si2 < array_length(_sm); __si2++) if (_sm[__si2] == __midv) { __f = true; break; }
                if (!__f){ _has_unseen = true; break; }
            }
        }
        if (_has_unseen){
            var _lvlTxt = "Lv " + string(_lvl);
            var _lvlX = _lx1 + 6*_S;
            var _lvlW = string_width(_lvlTxt);
            var _badgeX = _lvlX + _lvlW + 8*_S;
            var _badgeY = _ly1 + 6*_S + _name_lh;
            draw_set_color(make_color_rgb(220,40,40));
            if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);
            draw_text(_badgeX, _badgeY, "LEARN");
            if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
            draw_set_color(c_white);
        }
    }

    return { descPad: _DESC_PAD, descAreaH: _DESC_AREA_H, descX: (_lx1 + _DESC_PAD), descY: (_ly2 - _DESC_AREA_H + _DESC_PAD), descW: min((_LEFT_W + 10) * _S, (108 - _LEFT_X - 4) * _S) - _DESC_PAD*2, descH: _DESC_AREA_H - _DESC_PAD*2 };
}

function __party_impl_species_display_name(_M){
    if (!is_struct(_M)) return "???";

    var _sid = -1;
    if (variable_struct_exists(_M, "species_id") && is_real(_M.species_id)) _sid = floor(_M.species_id);
    else if (variable_struct_exists(_M, "species") && is_real(_M.species)) _sid = floor(_M.species);
    else if (variable_struct_exists(_M, "id") && is_real(_M.id)) _sid = floor(_M.id);
    else if (variable_struct_exists(_M, "_id") && is_real(_M._id)) _sid = floor(_M._id);

    if (_sid > 0 && !is_undefined(scr_poke_name_by_id)){
        var _idn = scr_poke_name_by_id(_sid);
        if (is_string(_idn) && string_length(string_trim(_idn)) > 0){
            var _out = string_replace_all(string_trim(_idn), "-", " ");
            return string_upper(string_copy(_out, 1, 1)) + string_delete(_out, 1, 1);
        }
    }

    if (variable_struct_exists(_M, "name")){
        var _name = string(variable_struct_get(_M, "name"));
        if (string_length(string_trim(_name)) > 0 && string_lower(string_trim(_name)) != "undefined") return string_trim(_name);
    }

    return "???";
}

function __party_impl_draw_learn_panel_frame(_rx, _ry, _rw, _rh, _S){
    var _x2 = _rx + _rw * _S;
    var _y2 = _ry + _rh * _S;
    draw_set_color(make_color_rgb(224, 248, 216));
    draw_rectangle(_rx, _ry, _x2, _y2, false);
    __party_impl_draw_scaled_outline(_rx - _S, _ry - _S, _x2 + _S, _y2 + _S, 2*_S, make_color_rgb(32, 120, 88));
    draw_set_color(make_color_rgb(48, 152, 112));
    draw_rectangle(_rx + 3*_S, _ry + 3*_S, _x2 - 3*_S, _ry + 15*_S, false);
    __party_impl_text_white(_rx + 7*_S, _ry + 4*_S, "LEARN MOVE");
}

// Draw the right parchment frame and return its GUI coordinates.
function __party_impl_draw_right_frame(_OX, _OY, _S, _RIGHT_X, _RIGHT_Y, _RIGHT_W, _RIGHT_H){
    var _rx1 = _OX + _RIGHT_X*_S, _ry1 = _OY + _RIGHT_Y*_S;
    var _rx2 = _OX + (_RIGHT_X + _RIGHT_W)*_S, _ry2 = _OY + (_RIGHT_Y + _RIGHT_H)*_S;
    var _PARCHMENT = make_color_rgb(255,243,195);
    draw_set_color(_PARCHMENT); draw_rectangle(_rx1, _ry1, _rx2, _ry2, false);
    draw_set_color(make_color_rgb(248, 224, 160));
    __party_impl_draw_scaled_outline(_rx1 + 2*_S, _ry1 + 2*_S, _rx2 - 2*_S, _ry2 - 2*_S, _S, make_color_rgb(248, 224, 160));
    var _C_EDGE = make_color_rgb(24, 80, 88);
    __party_impl_draw_scaled_outline(_rx1- _S, _ry1- _S, _rx2+ _S, _ry2+ _S, 2*_S, _C_EDGE);
    return { rx1: _rx1, ry1: _ry1, rx2: _rx2, ry2: _ry2 };
}

// Draw the header hints and the selection circles for the party slots.
function __party_impl_draw_header_and_circles(_P, _OX, _OY, _S, _n, _C_ACC, _C_PAPER){
    var _modeStr = string(_P.mode);
    draw_set_color(c_white);
    // Determine if a learn flow is present and whether the learn LIST
    // (not the description) is currently visible. We only suppress the
    // normal header hints when the learn list is open.
    var _hasLearnPending = (is_struct(_P) && variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending")));
    var _learnListActive = false;
    if (_hasLearnPending){
        var _lp_tmp2 = variable_struct_get(_P, "learn_pending");
        var _lp_step2 = (variable_struct_exists(_lp_tmp2, "step") ? variable_struct_get(_lp_tmp2, "step") : "desc");
        _learnListActive = (string(_lp_step2) != "desc");
    }
    if (!_learnListActive){
        if (_modeStr == "summary_moves" || _modeStr == "summary_forget"){
            var _hintY = _OY + 10*_S;
            draw_text(_OX + 4*_S, _hintY, "L/R: Switch");
            var _profileHint = "Up: Profile";
            var _phW = string_width(_profileHint);
            draw_text(_OX + 240*_S - _phW - 4*_S, _hintY, _profileHint);
        } else if (_modeStr == "summary_profile") {
            var _movesHint = "Up: Moves";
            var _mhW = string_width(_movesHint);
            var _hintY2 = _OY + 10*_S;
            draw_text(_OX + 240*_S - _mhW - 4*_S, _hintY2, _movesHint);
        }
    } else {
        // When the learn LIST is active, suppress the top hint (user requested no header text)
    }
    var _radBase = 3;
    var _spinAng = _P.summary_spin_angle;
    var _isSummary = (string(_P.mode) == "summary_profile" || string(_P.mode) == "summary_moves" || string(_P.mode) == "summary_forget");
    for (var _i = 0; _i < 6; _i++){
        var _cx = _OX + (104 + _i*12)*_S - 20*_S;
        var _cy = _OY + 12*_S;
        var _col = (_i < _n) ? (_i == _P.sel ? _C_ACC : _C_PAPER) : make_color_rgb(136,136,136);
        draw_set_color(_col);
        var _r = _radBase * _S;
        if (_i == _P.sel && _isSummary){
            var _scale = _P.summary_cur_scale;
            draw_circle(_cx, _cy, _r * _scale, false);
            var _len = _r * 0.9 * _scale;
            var _x2 = _cx + lengthdir_x(_len, _spinAng);
            var _y2 = _cy + lengthdir_y(_len, _spinAng);
            draw_set_color(_C_ACC);
            draw_line(_cx, _cy, _x2, _y2);
            draw_set_color(_col);
        } else {
            draw_circle(_cx, _cy, _r, false);
        }
    }
}

// Draw content inside the right frame depending on `_P.mode` (profile/moves/forget).
// Returns a secondary help string displayed under the panels.
function __party_impl_draw_right_content(_P, _M, _rightInfo, _RIGHT_W, _RIGHT_H, _S){
    var _rx1 = _rightInfo.rx1, _ry1 = _rightInfo.ry1, _rx2 = _rightInfo.rx2, _ry2 = _rightInfo.ry2;
    var _secondaryLine = "";
    // If a learn flow is active and the user is viewing the learn list
    // (step != "desc"), do not draw the standard right-side profile/moves
    // block to avoid overlapping the learn list UI.
    if (is_struct(_P) && variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))) {
        var _lp_tmp = variable_struct_get(_P, "learn_pending");
        var _lp_step = (variable_struct_exists(_lp_tmp, "step") ? variable_struct_get(_lp_tmp, "step") : "desc");
        if (string(_lp_step) != "desc") return "";
    }
    if (string(_P.mode) == "summary_profile"){
        __party_impl_draw_profile_block(_M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S);
        if (is_struct(_M)){
            var _idno_ext = "";
            if (variable_struct_exists(_M,"idno")) _idno_ext = string(_M.idno);
            if (string_length(_idno_ext) > 0){
                var _id_label = "IDNo " + _idno_ext;
                var _bx_center = _rx1 + (_RIGHT_W*_S) * 0.5;
                var _id_w2 = string_width(_id_label);
                var _id_draw_x2 = floor(_bx_center - _id_w2 * 0.5);
                var _below_gap = 9*_S;
                draw_text(_id_draw_x2, _ry2 + _below_gap, _id_label);
            }
        }
    } else if (string(_P.mode) == "summary_moves"){
        _secondaryLine = __party_impl_draw_moves_block(_P, _M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S, false);
    } else if (string(_P.mode) == "summary_forget"){
        _secondaryLine = __party_impl_draw_moves_block(_P, _M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S, true);
    }
    return _secondaryLine;
}
