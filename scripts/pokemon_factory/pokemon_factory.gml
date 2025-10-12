// [Pokémon]: pokemon_factory_create — Drop-in (enhanced) — 2025-10-09
function __pfc_int(_v, _def)    { return (is_undefined(_v) || !is_real(_v)) ? _def : floor(_v); }
function __pfc_bool(_v, _def)   { return is_bool(_v) ? _v : (_v ? true : _def); }
function __pfc_arr(_v, _def)    { return (is_array(_v)) ? _v : _def; }

function __pfc_move_pp(_mid) {
    if (!is_real(_mid) || _mid <= 0) return 5;
    if (variable_global_exists("_moves") && is_array(global._moves) && _mid < array_length(global._moves)) {
        var mv = global._moves[_mid];
        if (is_struct(mv) && variable_struct_exists(mv, "pp") && is_real(mv.pp)) return max(1, mv.pp);
    }
    return 5;
}

function __pfc_last4_levelup_moves(_sid, _level) {
    var out = [-1,-1,-1,-1];
    if (!is_real(_sid) || _sid <= 0) return out;
    if (!variable_global_exists("_species_moves") || !is_array(global._species_moves)) return out;
    if (_sid >= array_length(global._species_moves)) return out;

    var rows = global._species_moves[_sid];
    if (!is_array(rows)) return out;

    var elig = [];
    for (var i = 0; i < array_length(rows); i++) {
        var r = rows[i];
        if (!is_struct(r)) continue;
        var lvl = __pfc_int(r.lvl, 0);
        var mid = __pfc_int(r.mid, -1);
        if (mid > 0 && lvl <= _level) array_push(elig, mid);
    }
    // Deduplicate while preserving order (so the same move isn't learned multiple times)
    if (array_length(elig) > 1){
        var seen2 = [];
        var uniq2 = [];
        for (var ii = 0; ii < array_length(elig); ii++){
            var mvv = elig[ii];
            var already = false;
            for (var jj = 0; jj < array_length(seen2); jj++) if (seen2[jj] == mvv) { already = true; break; }
            if (!already){ array_push(seen2, mvv); array_push(uniq2, mvv); }
        }
        elig = uniq2;
    }
    var n = array_length(elig);
    if (n <= 0) return out;
    var k = 0;
    for (var j = max(0, n - 4); j < n && k < 4; j++) out[k++] = elig[j];
    while (k < 4) out[k++] = -1;
    return out;
}

function pokemon_factory_create(_sid, _level, _opts){
    var _s = (is_undefined(_sid) || !is_real(_sid)) ? -1 : floor(_sid);
    var L  = (is_undefined(_level) || !is_real(_level)) ? 5 : floor(_level);
    // Cap levels at 100 because experience CSV only includes 1..100
    L = min(100, max(1, L));
    var _o = (is_struct(_opts)) ? _opts : {};

    var st = is_undefined(scr_poke_stats) ? undefined : scr_poke_stats(_s);
    var base_hp  = (is_undefined(st) || is_undefined(st.hp))  ? 45 : st.hp;
    var base_atk = (is_undefined(st) || is_undefined(st.atk)) ? 49 : st.atk;
    var base_def = (is_undefined(st) || is_undefined(st.def)) ? 49 : st.def;
    var base_spa = (is_undefined(st) || is_undefined(st.spa)) ? 65 : st.spa;
    var base_spd = (is_undefined(st) || is_undefined(st.spd)) ? 65 : st.spd;
    var base_spe = (is_undefined(st) || is_undefined(st.spe)) ? 45 : st.spe;

    var hpmax = (is_undefined(scr_poke_calc_hp))   ? (20 + L * 2) : scr_poke_calc_hp(base_hp, L);
    var atk   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_atk, L);
    var def   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_def, L);
    var spa   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_spa, L);
    var spd   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_spd, L);
    var spe   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_spe, L);

    var _ot = (variable_struct_exists(_o, "ot")) ? string(_o.ot) : (variable_global_exists("PLAYER_NAME") ? string(global.PLAYER_NAME) : "YOU");
    if (variable_struct_exists(_o, "pid") && is_real(_o.pid) && _o.pid == 1 && variable_global_exists("PLAYER2_NAME")) _ot = string(global.PLAYER2_NAME);
    var _idno = (variable_struct_exists(_o, "idno") && is_real(_o.idno)) ? floor(_o.idno) : _s;

    var _icon = (variable_struct_exists(_o, "icon")) ? _o.icon : -1;
    if (_icon == -1) {
        if (!is_undefined(pkicons_get_icon32_dir)) {
            var _tmp = pkicons_get_icon32_dir(_s, "down");
            if (is_undefined(_tmp) || !sprite_exists(_tmp)) _tmp = pkicons_get_icon32_dir(_s, "front");
            if (!is_undefined(_tmp) && sprite_exists(_tmp)) _icon = _tmp;
        }
        if (_icon == -1) {
            if (variable_global_exists("spr_mon_icon_placeholder")) _icon = spr_mon_icon_placeholder;
            else { var ph = asset_get_index("spr_mon_icon_placeholder"); if (ph != -1) _icon = ph; }
        }
    }

    var _t1 = -1, _t2 = -1; var _types_arr = [];
    if (variable_struct_exists(_o, "seed_types_override") && is_array(_o.seed_types_override)) {
        _types_arr = _o.seed_types_override;
        if (array_length(_types_arr) > 0) _t1 = _types_arr[0];
        if (array_length(_types_arr) > 1) _t2 = _types_arr[1];
    } else if (variable_global_exists("_species_types") && is_array(global._species_types)) {
        if (_s < array_length(global._species_types)) {
            var __ta = global._species_types[_s];
            if (is_array(__ta)) {
                if (array_length(__ta) > 0) _t1 = __ta[0];
                if (array_length(__ta) > 1) _t2 = __ta[1];
                for (var __i=0; __i<array_length(__ta); __i++) array_push(_types_arr, __ta[__i]);
            }
        }
    } else if (variable_global_exists("_pokemon") && is_array(global._pokemon)) {
        if (_s < array_length(global._pokemon)) {
            var __rec = global._pokemon[_s];
            if (is_struct(__rec)) {
                if (variable_struct_exists(__rec,"type1")) _t1 = __rec.type1;
                if (variable_struct_exists(__rec,"type2")) _t2 = __rec.type2;
            }
        }
        if (_t1 != -1) array_push(_types_arr,_t1);
        if (_t2 != -1) array_push(_types_arr,_t2);
    }
    if (array_length(_types_arr) == 0) { _t1 = 1; array_push(_types_arr,_t1); }

    var moves = [-1,-1,-1,-1];
    if (variable_struct_exists(_o, "moves") && is_array(_o.moves)) {
        for (var mi = 0; mi < 4; mi++) moves[mi] = (mi < array_length(_o.moves) && is_real(_o.moves[mi])) ? floor(_o.moves[mi]) : -1;
    } else {
        moves = __pfc_last4_levelup_moves(_s, L);
    }
    var pps = [0,0,0,0];
    for (var _pi = 0; _pi < 4; _pi++) {
        if (moves[_pi] > 0) pps[_pi] = __pfc_move_pp(moves[_pi]);
        else pps[_pi] = 0;
    }

    var held_item_id   = (variable_struct_exists(_o, "held_item_id") && is_real(_o.held_item_id)) ? floor(_o.held_item_id) : -1;
    var held_item_meta = (variable_struct_exists(_o, "held_item_meta") && is_real(_o.held_item_meta)) ? floor(_o.held_item_meta) : 0;

    var _exp = (variable_struct_exists(_o, "exp") && is_real(_o.exp)) ? floor(_o.exp) : 0;
    // Prefer CSV-driven threshold if available: scr_get_exp_next_for_mon expects a mon-like struct
    var _exp_next = -1;
    if (variable_struct_exists(_o, "exp_next") && is_real(_o.exp_next)) {
        _exp_next = floor(_o.exp_next);
    } else {
        // construct a lightweight mon-like probe
        var __probe = { species_id: _s, id: _s, level: L };
        if (!is_undefined(scr_get_exp_next_for_mon)) {
            var __v = scr_get_exp_next_for_mon(__probe);
            if (is_real(__v) && __v > 0) _exp_next = floor(__v);
        }
    }
    if (!is_real(_exp_next) || _exp_next <= 0) _exp_next = max(20, L * L * 2);

    var mon = {
        species_id : _s,
        id         : _s,
        species    : (is_undefined(scr_poke_name_by_id) ? (variable_struct_exists(_o,"species") ? _o.species : "???:") : scr_poke_name_by_id(_s)),
        level      : L,
        exp        : _exp,
        exp_next   : _exp_next,
        hp         : hpmax,
        maxhp      : hpmax,
        hp_max     : hpmax,
        atk        : atk,
        def        : def,
        spa        : spa,
        spd        : spd,
        spe        : spe,
        ot         : _ot,
        idno       : _idno,
        icon       : _icon,
        shiny      : __pfc_bool((variable_struct_exists(_o, "shiny") ? _o.shiny : undefined), false),
        type1      : _t1,
        type2      : _t2,
        types      : _types_arr,
        moves      : moves,
        pps        : pps,
        status     : 0,
        held_item_id   : held_item_id,
        held_item_meta : held_item_meta
    };
    // Attach growth_id from species master record when available so experience lookups work
    if (variable_global_exists("_pokemon") && is_array(global._pokemon) && _s >= 0 && _s < array_length(global._pokemon)){
        var __rec2 = global._pokemon[_s];
        if (is_struct(__rec2)){
            if (variable_struct_exists(__rec2, "growth_rate_id") && is_real(__rec2.growth_rate_id)) mon.growth_id = floor(__rec2.growth_rate_id);
            else if (variable_struct_exists(__rec2, "_growth_rate") && is_real(__rec2._growth_rate)) mon.growth_id = floor(__rec2._growth_rate);
            else if (variable_struct_exists(__rec2, "growth") && is_real(__rec2.growth)) mon.growth_id = floor(__rec2.growth);
        }
    }

    // If a CSV-driven experience table exists, initialize the mon.exp to the cumulative exp for its current level
    // Safely initialize exp/exp_next from CSV if growth_id and level are available
    var _has_exp_field = (variable_struct_exists(mon, "exp") && is_real(variable_struct_get(mon, "exp")));
    var _exp_val = _has_exp_field ? variable_struct_get(mon, "exp") : undefined;
    var _has_growth = (variable_struct_exists(mon, "growth_id") && is_real(variable_struct_get(mon, "growth_id")));
    var _has_level = (variable_struct_exists(mon, "level") && is_real(variable_struct_get(mon, "level")));
    if ((!_has_exp_field || _exp_val <= 0) && _has_growth && _has_level && !is_undefined(scr_get_exp_for_level)){
        var _gid = variable_struct_get(mon, "growth_id");
        var _lvl = variable_struct_get(mon, "level");
        var _cur_e = scr_get_exp_for_level(_gid, _lvl);
        if (is_real(_cur_e) && _cur_e >= 0) variable_struct_set(mon, "exp", _cur_e);
        var _nxt_e = scr_get_exp_for_level(_gid, min(100, _lvl + 1));
        if (is_real(_nxt_e) && _nxt_e > 0) variable_struct_set(mon, "exp_next", _nxt_e);
    }
    return mon;
}