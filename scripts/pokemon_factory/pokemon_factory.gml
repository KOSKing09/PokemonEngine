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

// Compute a derived stat using Pokémon-style formula (IV/EV aware)
function scr_compute_stat(_base, _iv, _ev, _level, _is_hp){
    var base = (is_real(_base) ? floor(_base) : 10);
    var ivv  = (is_real(_iv) ? floor(_iv) : 0);
    var evv  = (is_real(_ev) ? floor(_ev) : 0);
    var lvl  = (is_real(_level) ? max(1, floor(_level)) : 1);
    var a = floor(((base * 2 + ivv + floor(evv / 4)) * lvl) / 100);
    if (_is_hp) return max(1, a + lvl + 10);
    return max(1, a + 5);
}

// Ensure a mon struct has iv/ev fields (initializes IVs randomly and zeroes EVs)
function scr_init_mon_iv_ev(_mon){
    if (!is_struct(_mon)) return;
    if (!variable_struct_exists(_mon, "iv") || !is_struct(_mon.iv)){
        _mon.iv = { hp: irandom(31), atk: irandom(31), def: irandom(31), spa: irandom(31), spd: irandom(31), spe: irandom(31) };
    }
    if (!variable_struct_exists(_mon, "ev") || !is_struct(_mon.ev)){
        _mon.ev = { hp:0, atk:0, def:0, spa:0, spd:0, spe:0 };
        _mon.ev_total = 0;
    } else if (!variable_struct_exists(_mon, "ev_total") || !is_real(_mon.ev_total)){
        _mon.ev_total = 0;
    }
}

// --- Nature support: small built-in table and helper
if (!variable_global_exists("_NATURES")) {
    global._NATURES = [
        { id:0, name:"Hardy",  mul:{atk:1.0, def:1.0, spa:1.0, spd:1.0, spe:1.0} },
        { id:1, name:"Lonely", mul:{atk:1.1, def:0.9, spa:1.0, spd:1.0, spe:1.0} },
        { id:2, name:"Brave",  mul:{atk:1.1, def:1.0, spa:1.0, spd:1.0, spe:0.9} },
        { id:3, name:"Adamant",mul:{atk:1.1, def:1.0, spa:0.9, spd:1.0, spe:1.0} },
        { id:4, name:"Naughty",mul:{atk:1.1, def:1.0, spa:1.0, spd:0.9, spe:1.0} },
        { id:5, name:"Bold",   mul:{atk:0.9, def:1.1, spa:1.0, spd:1.0, spe:1.0} },
        { id:6, name:"Docile", mul:{atk:1.0, def:1.0, spa:1.0, spd:1.0, spe:1.0} },
        { id:7, name:"Relaxed",mul:{atk:1.0, def:1.1, spa:1.0, spd:1.0, spe:0.9} },
        { id:8, name:"Impish", mul:{atk:1.0, def:1.1, spa:0.9, spd:1.0, spe:1.0} },
        { id:9, name:"Lax",    mul:{atk:1.0, def:1.1, spa:1.0, spd:0.9, spe:1.0} }
    ];
}

function scr_nature_get_by_name(_name){
    // Prefer CSV-loaded global._natures when present
    if (variable_global_exists("_natures") && is_array(global._natures)){
        for (var i=0; i<array_length(global._natures); ++i){ var r = global._natures[i]; if (is_struct(r) && (string(r.name) == string(_name) || string(r.identifier) == string(_name))) return r; }
    }
    if (!variable_global_exists("_NATURES") || !is_array(global._NATURES)) return undefined;
    for (var i=0; i<array_length(global._NATURES); ++i){ if (string(global._NATURES[i].name) == string(_name)) return global._NATURES[i]; }
    return undefined;
}

function scr_nature_random_name(){
    // Prefer CSV-loaded list if available
    if (variable_global_exists("_natures") && is_array(global._natures) && array_length(global._natures) > 0){
        var idx2 = irandom(array_length(global._natures)-1); var r2 = global._natures[idx2]; if (is_struct(r2) && variable_struct_exists(r2, "name")) return string(r2.name);
    }
    if (!variable_global_exists("_NATURES") || !is_array(global._NATURES)) return "Hardy";
    var idx = irandom(array_length(global._NATURES)-1);
    return string(global._NATURES[idx].name);
}

function scr_nature_multiplier(_nature, _stat){
    if (is_string(_nature)){
        var rec = scr_nature_get_by_name(_nature);
        if (is_struct(rec) && variable_struct_exists(rec, "mul") && variable_struct_exists(rec.mul, _stat)) return real(variable_struct_get(rec.mul, _stat));
    } else if (is_struct(_nature) && variable_struct_exists(_nature, "mul") && variable_struct_exists(_nature.mul, _stat)){
        return real(variable_struct_get(_nature.mul, _stat));
    }
    return 1.0;
}

function pokemon_factory_gender_rate(_sid){
    var _s = (is_real(_sid) ? floor(_sid) : -1);
    if (_s >= 0 && variable_global_exists("_species_gender_rates") && is_array(global._species_gender_rates) && _s < array_length(global._species_gender_rates)){
        var _rate = global._species_gender_rates[_s];
        if (is_real(_rate)) return clamp(floor(_rate), -1, 8);
    }
    if (_s >= 0 && variable_global_exists("_pokemon") && is_array(global._pokemon) && _s < array_length(global._pokemon)){
        var _rec = global._pokemon[_s];
        if (is_struct(_rec) && variable_struct_exists(_rec, "gender_rate") && is_real(_rec.gender_rate)) return clamp(floor(_rec.gender_rate), -1, 8);
    }
    return 4;
}

function pokemon_factory_normalize_sex(_value){
    var _s = string_lower(string(_value));
    if (_s == "m" || _s == "male" || _s == "boy") return "male";
    if (_s == "f" || _s == "female" || _s == "girl") return "female";
    if (_s == "genderless" || _s == "none" || _s == "unknown" || _s == "n/a") return "genderless";
    return "";
}

function pokemon_factory_roll_sex(_sid, _seed){
    var _rate = pokemon_factory_gender_rate(_sid);
    if (_rate < 0) return "genderless";
    if (_rate <= 0) return "male";
    if (_rate >= 8) return "female";
    if (is_real(_seed)){
        var _roll = abs(floor(_seed)) mod 8;
        return (_roll < _rate) ? "female" : "male";
    }
    return (irandom(7) < _rate) ? "female" : "male";
}

function pokemon_factory_sex_id(_sex){
    var _s = pokemon_factory_normalize_sex(_sex);
    if (_s == "female") return 1;
    if (_s == "male") return 2;
    return 0;
}

// Award EVs to a mon (clamped per-stat and total). _ev_gain should be a struct with keys hp/atk/def/spa/spd/spe
function scr_award_ev_to_mon(_mon, _ev_gain){
    if (!is_struct(_mon)) return;
    if (!variable_struct_exists(_mon, "ev") || !is_struct(_mon.ev)){
        _mon.ev = { hp:0, atk:0, def:0, spa:0, spd:0, spe:0 };
        _mon.ev_total = 0;
    }
    var keys = ["hp","atk","def","spa","spd","spe"];
    var maxPer = 252;
    var maxTotal = 510;
    for (var i=0; i<array_length(keys); ++i){
        var k = keys[i];
        var gain = (is_struct(_ev_gain) && variable_struct_exists(_ev_gain, k) && is_real(variable_struct_get(_ev_gain,k))) ? floor(variable_struct_get(_ev_gain,k)) : 0;
        if (gain <= 0) continue;
        // read current EV stat safely
        var curEv = 0;
        if (variable_struct_exists(_mon, "ev") && is_struct(variable_struct_get(_mon, "ev"))){
            var evStruct = variable_struct_get(_mon, "ev");
            if (variable_struct_exists(evStruct, k) && is_real(variable_struct_get(evStruct, k))) curEv = floor(variable_struct_get(evStruct, k));
        }
        var curTotal = (variable_struct_exists(_mon, "ev_total") && is_real(variable_struct_get(_mon, "ev_total"))) ? floor(variable_struct_get(_mon, "ev_total")) : 0;
        var availStat = maxPer - max(0, curEv);
        var availTotal = maxTotal - max(0, curTotal);
        var add = min(gain, availStat, availTotal);
        if (add <= 0) continue;
        // write back safely
        if (!variable_struct_exists(_mon, "ev") || !is_struct(variable_struct_get(_mon, "ev"))) _mon.ev = { hp:0, atk:0, def:0, spa:0, spd:0, spe:0 };
        var evStruct2 = variable_struct_get(_mon, "ev");
        variable_struct_set(evStruct2, k, curEv + add);
        variable_struct_set(_mon, "ev", evStruct2);
        variable_struct_set(_mon, "ev_total", curTotal + add);
    }
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
    var _sex = "";
    if (variable_struct_exists(_o, "sex")) _sex = pokemon_factory_normalize_sex(_o.sex);
    if (string_length(_sex) <= 0 && variable_struct_exists(_o, "gender")) _sex = pokemon_factory_normalize_sex(_o.gender);
    if (string_length(_sex) <= 0) _sex = pokemon_factory_roll_sex(_s, _idno + (_s * 1000) + L);
    var _sex_id = pokemon_factory_sex_id(_sex);

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
    // If no per-mon types were found, try the safe resolver if available
    if (array_length(_types_arr) == 0 && !is_undefined(scr_poke_types_by_id)) {
        var _resolved = scr_poke_types_by_id(_s);
        if (is_array(_resolved) && array_length(_resolved) > 0) {
            for (var __ri = 0; __ri < array_length(_resolved); __ri++) array_push(_types_arr, _resolved[__ri]);
            if (array_length(_resolved) > 0) _t1 = _resolved[0];
            if (array_length(_resolved) > 1) _t2 = _resolved[1];
        }
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
    var pokeball_item_id = 4;
    if (variable_struct_exists(_o, "pokeball_item_id") && is_real(_o.pokeball_item_id)) pokeball_item_id = floor(_o.pokeball_item_id);
    else if (variable_struct_exists(_o, "ball_item_id") && is_real(_o.ball_item_id)) pokeball_item_id = floor(_o.ball_item_id);
    else if (variable_struct_exists(_o, "capture_ball_item_id") && is_real(_o.capture_ball_item_id)) pokeball_item_id = floor(_o.capture_ball_item_id);
    if (!is_real(pokeball_item_id) || pokeball_item_id <= 0) pokeball_item_id = 4;

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
        // IV/EV will be initialized below; place placeholders here for schema clarity
        iv         : undefined,
        ev         : undefined,
        ev_total   : 0,
        // derived stats (may be recomputed using IV/EV-aware formula below)
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
        sex        : _sex,
        gender     : _sex,
        sex_id     : _sex_id,
        gender_id  : _sex_id,
        type1      : _t1,
        type2      : _t2,
        types      : _types_arr,
        moves      : moves,
        pps        : pps,
        status     : 0,
        pokeball_item_id : pokeball_item_id,
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

    // Initialize IV/EV for the mon and recompute derived stats using scr_compute_stat if base stats exist
    scr_init_mon_iv_ev(mon);

    // try to read base stats and, if present, recompute derived stats with IV/EV
    var base = undefined;
    if (variable_global_exists("_poke_stats") && is_array(global._poke_stats) && _s >= 0 && _s < array_length(global._poke_stats)) base = global._poke_stats[_s];
    else if (variable_global_exists("_pokemon") && is_array(global._pokemon) && _s >= 0 && _s < array_length(global._pokemon)){
        var __rec3 = global._pokemon[_s];
        if (is_struct(__rec3) && variable_struct_exists(__rec3, "base_stats")) base = __rec3.base_stats;
        else base = __rec3; // some loaders put stats at top-level
    }

    // helper to read base with common aliases
    function __bs_get_local(_b, _names){ if (!is_struct(_b)) return undefined; for (var ii=0; ii<array_length(_names); ++ii){ var k=_names[ii]; if (variable_struct_exists(_b,k) && is_real(variable_struct_get(_b,k))) return real(variable_struct_get(_b,k)); } return undefined; }

    var b_hp  = __bs_get_local(base, ["hp","base_hp"]);
    var b_atk = __bs_get_local(base, ["atk","attack","base_atk"]);
    var b_def = __bs_get_local(base, ["def","defense","base_def"]);
    var b_spa = __bs_get_local(base, ["spa","spatk","sp_atk","sp_attack","base_spa"]);
    var b_spd = __bs_get_local(base, ["spd","spdef","sp_def","sp_defense","base_spd"]);
    var b_spe = __bs_get_local(base, ["spe","speed","base_spe"]);

    if (is_real(b_hp) || is_real(b_atk) || is_real(b_def) || is_real(b_spa) || is_real(b_spd) || is_real(b_spe)){
        // compute derived stats with IV/EV using guarded struct accessors
        var iv = (variable_struct_exists(mon, "iv") && is_struct(variable_struct_get(mon, "iv"))) ? variable_struct_get(mon, "iv") : undefined;
        var ev = (variable_struct_exists(mon, "ev") && is_struct(variable_struct_get(mon, "ev"))) ? variable_struct_get(mon, "ev") : undefined;
        var lvl = (is_real(mon.level) ? mon.level : 1);

        var iv_hp = (is_struct(iv) && variable_struct_exists(iv, "hp") && is_real(variable_struct_get(iv, "hp"))) ? real(variable_struct_get(iv, "hp")) : 0;
        var iv_atk = (is_struct(iv) && variable_struct_exists(iv, "atk") && is_real(variable_struct_get(iv, "atk"))) ? real(variable_struct_get(iv, "atk")) : 0;
        var iv_def = (is_struct(iv) && variable_struct_exists(iv, "def") && is_real(variable_struct_get(iv, "def"))) ? real(variable_struct_get(iv, "def")) : 0;
        var iv_spa = (is_struct(iv) && variable_struct_exists(iv, "spa") && is_real(variable_struct_get(iv, "spa"))) ? real(variable_struct_get(iv, "spa")) : 0;
        var iv_spd = (is_struct(iv) && variable_struct_exists(iv, "spd") && is_real(variable_struct_get(iv, "spd"))) ? real(variable_struct_get(iv, "spd")) : 0;
        var iv_spe = (is_struct(iv) && variable_struct_exists(iv, "spe") && is_real(variable_struct_get(iv, "spe"))) ? real(variable_struct_get(iv, "spe")) : 0;

        var ev_hp = (is_struct(ev) && variable_struct_exists(ev, "hp") && is_real(variable_struct_get(ev, "hp"))) ? real(variable_struct_get(ev, "hp")) : 0;
        var ev_atk = (is_struct(ev) && variable_struct_exists(ev, "atk") && is_real(variable_struct_get(ev, "atk"))) ? real(variable_struct_get(ev, "atk")) : 0;
        var ev_def = (is_struct(ev) && variable_struct_exists(ev, "def") && is_real(variable_struct_get(ev, "def"))) ? real(variable_struct_get(ev, "def")) : 0;
        var ev_spa = (is_struct(ev) && variable_struct_exists(ev, "spa") && is_real(variable_struct_get(ev, "spa"))) ? real(variable_struct_get(ev, "spa")) : 0;
        var ev_spd = (is_struct(ev) && variable_struct_exists(ev, "spd") && is_real(variable_struct_get(ev, "spd"))) ? real(variable_struct_get(ev, "spd")) : 0;
        var ev_spe = (is_struct(ev) && variable_struct_exists(ev, "spe") && is_real(variable_struct_get(ev, "spe"))) ? real(variable_struct_get(ev, "spe")) : 0;

        mon.hp_max = is_real(b_hp) ? scr_compute_stat(b_hp, iv_hp, ev_hp, lvl, true) : mon.hp_max;
        mon.maxhp = mon.hp_max;
        mon.hp = mon.hp_max;
        mon.hp_now = mon.hp_max;
        // assign base computed stats
        mon.atk = is_real(b_atk) ? scr_compute_stat(b_atk, iv_atk, ev_atk, lvl, false) : mon.atk;
        mon.def = is_real(b_def) ? scr_compute_stat(b_def, iv_def, ev_def, lvl, false) : mon.def;
        mon.spa = is_real(b_spa) ? scr_compute_stat(b_spa, iv_spa, ev_spa, lvl, false) : mon.spa;
        mon.spd = is_real(b_spd) ? scr_compute_stat(b_spd, iv_spd, ev_spd, lvl, false) : mon.spd;
        mon.spe = is_real(b_spe) ? scr_compute_stat(b_spe, iv_spe, ev_spe, lvl, false) : mon.spe;

        // Ensure mon has a nature (string name); if absent, assign a random one
        if (!variable_struct_exists(mon, "nature") || !is_string(mon.nature) || string_length(string(mon.nature)) == 0){
            mon.nature = scr_nature_random_name();
        }
        // Apply nature multipliers to non-HP stats (floor after multiply)
        var nat = mon.nature;
        mon.atk = max(1, floor(mon.atk * scr_nature_multiplier(nat, "atk")));
        mon.def = max(1, floor(mon.def * scr_nature_multiplier(nat, "def")));
        mon.spa = max(1, floor(mon.spa * scr_nature_multiplier(nat, "spa")));
        mon.spd = max(1, floor(mon.spd * scr_nature_multiplier(nat, "spd")));
        mon.spe = max(1, floor(mon.spe * scr_nature_multiplier(nat, "spe")));
    }
    // Keep HP aliases synchronized so party/battle/UI code sees a full-health
    // freshly created mon regardless of which canonical field it reads.
    mon.maxhp = mon.hp_max;
    mon.hp = mon.hp_max;
    mon.hp_now = mon.hp_max;
    try {
        if ((!variable_struct_exists(mon, "ability_id") || !is_real(mon.ability_id)) && !is_undefined(scr_poke_pick_ability)){
            var _ability_id = scr_poke_pick_ability(_s, _s * 1000 + L);
            if (is_real(_ability_id) && _ability_id > 0){
                mon.ability_id = _ability_id;
                if (!is_undefined(scr_ability_name_by_id)) mon.ability = scr_ability_name_by_id(_ability_id);
            }
        } else if (variable_struct_exists(mon, "ability_id") && is_real(mon.ability_id) && (!variable_struct_exists(mon, "ability") || string_length(string(mon.ability)) <= 0) && !is_undefined(scr_ability_name_by_id)){
            mon.ability = scr_ability_name_by_id(mon.ability_id);
        }
    } catch (e_ability_assign) {}
    // Populate a per-mon `learnset` for convenience: list of move IDs the species can learn up to this level.
    // This allows UI code that prefers a per-mon learnset (mon.learnset) to work without additional fallbacks.
    if (!is_undefined(scr_poke_moves_upto_level)){
        var __ls = scr_poke_moves_upto_level(_s, L);
        if (is_array(__ls)) variable_struct_set(mon, "learnset", __ls);
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[DATA_DEBUG] pokemon_factory_create: assigned learnset length=" + string(is_array(__ls) ? array_length(__ls) : 0) + " for species=" + string(_s) + " lvl=" + string(L));
    }
    // Compute an initial grounded flag so UI/debug can inspect at a glance.
    // This uses types and, if already present on the mon, ability. It may be
    // updated later when ability is assigned by demo/runtime code.
    try {
        if (!is_undefined(scr_compute_grounded_flag)) mon.grounded = scr_compute_grounded_flag(mon);
    } catch (e_gf) { /* ignore */ }
    // Debug: report HP values assigned at creation when DATA_DEBUG enabled
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        try { show_debug_message("[DATA_DEBUG][pokemon_factory_create] species=" + string(_s) + ", level=" + string(L) + ", hp=" + string(variable_struct_exists(mon,"hp") ? variable_struct_get(mon,"hp") : "<none>") + ", hp_max=" + string(variable_struct_exists(mon,"hp_max") ? variable_struct_get(mon,"hp_max") : "<none>")); } catch (e_dbg) {}
    }
    return mon;
}

/// scr_compute_grounded_flag(monOrActor) -> bool
/// Returns true if the mon/actor is considered grounded at snapshot time.
/// Rules (current simplified implementation):
/// - Not Flying type AND does not have Levitate ability.
/// - Ignores transient effects (Magnet Rise, Air Balloon) for now.
function scr_compute_grounded_flag(_obj){
    if (!is_struct(_obj)) return true;
    var flying_id = undefined;
    try { if (variable_global_exists("TYPE_ID_BY_NAME")){
        var _tmap = variable_global_get("TYPE_ID_BY_NAME");
        if (ds_exists(_tmap, ds_type_map)) flying_id = ds_map_find_value(_tmap, string_lower("flying"));
    } } catch (e_tf) { flying_id = undefined; }

    // Pull type array from common shapes: .types, .type1/.type2, or species lookup
    var types_arr = [];
    try {
        if (variable_struct_exists(_obj, "types") && is_array(_obj.types)){
            types_arr = _obj.types;
        } else {
            var t1 = (variable_struct_exists(_obj, "type1") && is_real(_obj.type1)) ? _obj.type1 : -1;
            var t2 = (variable_struct_exists(_obj, "type2") && is_real(_obj.type2)) ? _obj.type2 : -1;
            if (t1 != -1) array_push(types_arr, t1);
            if (t2 != -1) array_push(types_arr, t2);
            if (array_length(types_arr) == 0 && variable_struct_exists(_obj, "species_id") && is_real(_obj.species_id) && variable_global_exists("_species_types") && is_array(global._species_types)){
                var sid = _obj.species_id;
                if (sid >= 0 && sid < array_length(global._species_types)){
                    var ta = global._species_types[sid];
                    if (is_array(ta)) types_arr = ta;
                }
            }
        }
    } catch (e_ty) { /* keep empty */ }

    // If we can resolve Flying type id and the mon has it, it's not grounded
    if (!is_undefined(flying_id) && is_real(flying_id)){
        for (var i=0; i<array_length(types_arr); ++i){ if (is_real(types_arr[i]) && types_arr[i] == flying_id) return false; }
    }

    // Ability check: treat Levitate as airborne. Accept string name or known id (26).
    try {
        if (variable_struct_exists(_obj, "ability")){
            var ab = _obj.ability;
            if ((is_string(ab) && string_lower(string(ab)) == "levitate") || (is_real(ab) && floor(ab) == 26)) return false;
        }
    } catch (e_ab) { /* ignore */ }

    return true;
}
