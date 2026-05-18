globalvar EVOLUTION;

function __evolution_slot(){
    return {
        active: false,
        phase: "idle",
        queue: [],
        mon_ref: undefined,
        actor_ref: undefined,
        source_species_id: -1,
        target_species_id: -1,
        source_name: "",
        nickname_name: "",
        target_name: "",
        display_name: "",
        anim_start_ms: -1,
        anim_duration_ms: 2600,
        allow_cancel: false
    };
}

function evolution_init(){
    EVOLUTION = [__evolution_slot(), __evolution_slot()];
}

function evolution_ensure(_pid){
    if (!variable_global_exists("EVOLUTION") || !is_array(EVOLUTION)) EVOLUTION = [];
    if (array_length(EVOLUTION) <= _pid) array_resize(EVOLUTION, _pid + 1);
    if (!is_struct(EVOLUTION[_pid])) EVOLUTION[_pid] = __evolution_slot();
    return EVOLUTION[_pid];
}

function evolution_is_active(_pid){
    var _E = evolution_ensure(_pid);
    return is_struct(_E) && variable_struct_exists(_E, "active") && variable_struct_get(_E, "active") == true;
}

function evolution_has_pending(_pid){
    var _E = evolution_ensure(_pid);
    if (!is_struct(_E) || !variable_struct_exists(_E, "queue")) return false;
    var _q = variable_struct_get(_E, "queue");
    return is_array(_q) && array_length(_q) > 0;
}

function __evolution_species_id(_mon){
    if (!is_struct(_mon)) return -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(variable_struct_get(_mon, "species_id"))) return floor(variable_struct_get(_mon, "species_id"));
    if (variable_struct_exists(_mon, "id") && is_real(variable_struct_get(_mon, "id"))) return floor(variable_struct_get(_mon, "id"));
    return -1;
}

function __evolution_mon_level(_mon){
    if (!is_struct(_mon)) return 1;
    if (variable_struct_exists(_mon, "level") && is_real(variable_struct_get(_mon, "level"))) return floor(variable_struct_get(_mon, "level"));
    if (variable_struct_exists(_mon, "lvl") && is_real(variable_struct_get(_mon, "lvl"))) return floor(variable_struct_get(_mon, "lvl"));
    return 1;
}

function __evolution_mon_happiness(_mon){
    if (!is_struct(_mon)) return 0;
    var _fields = ["happiness", "friendship", "friendliness", "affection"];
    for (var _i = 0; _i < array_length(_fields); ++_i){
        var _k = _fields[_i];
        if (variable_struct_exists(_mon, _k) && is_real(variable_struct_get(_mon, _k))) return floor(variable_struct_get(_mon, _k));
    }
    return 0;
}

function __evolution_mon_display_name(_mon){
    return __evolution_mon_species_name(_mon);
}

function __evolution_mon_species_name(_mon){
    if (!is_struct(_mon)) return "Pokemon";
    var _sid = __evolution_species_id(_mon);
    if (_sid > 0 && !is_undefined(scr_poke_name_by_id)){
        var _species_name = scr_poke_name_by_id(_sid);
        if (is_string(_species_name) && string_length(string_trim(_species_name)) > 0) return string_trim(_species_name);
    }
    if (variable_struct_exists(_mon, "name")){
        var _name = string(variable_struct_get(_mon, "name"));
        if (string_length(string_trim(_name)) > 0 && string_lower(string_trim(_name)) != "undefined") return string_trim(_name);
    }
    return "Pokemon";
}

function __evolution_mon_nickname_or_species_name(_mon){
    if (!is_struct(_mon)) return "Pokemon";
    if (variable_struct_exists(_mon, "nickname")){
        var _nick = string(variable_struct_get(_mon, "nickname"));
        if (string_length(string_trim(_nick)) > 0 && string_lower(string_trim(_nick)) != "undefined") return string_trim(_nick);
    }
    return __evolution_mon_species_name(_mon);
}

function __evolution_field_has_value(_row, _field){
    if (!is_struct(_row) || !variable_struct_exists(_row, _field)) return false;
    var _v = variable_struct_get(_row, _field);
    if (is_undefined(_v)) return false;
    if (is_string(_v)) return string_length(string_trim(_v)) > 0 && string_trim(_v) != "0";
    if (is_real(_v)) return floor(_v) != 0;
    if (is_bool(_v)) return _v;
    return true;
}

function __evolution_trigger_identifier(_trigger_id){
    var _tid = is_real(_trigger_id) ? floor(_trigger_id) : -1;
    if (_tid <= 0) return "";
    if (!variable_global_exists("_evolution_triggers") || !is_array(global._evolution_triggers)) return "";
    if (_tid >= array_length(global._evolution_triggers)) return "";
    var _rec = global._evolution_triggers[_tid];
    if (!is_struct(_rec) || !variable_struct_exists(_rec, "identifier")) return "";
    return string_lower(string(variable_struct_get(_rec, "identifier")));
}

function __evolution_row_supported_for_level(_row, _mon){
    if (!is_struct(_row) || !is_struct(_mon)) return false;
    if (__evolution_trigger_identifier(variable_struct_get(_row, "evolution_trigger_id")) != "level-up") return false;

    var _unsupported = [
        "trigger_item_id", "gender_id", "location_id", "held_item_id", "time_of_day",
        "known_move_id", "known_move_type_id", "minimum_beauty", "minimum_affection",
        "relative_physical_stats", "party_species_id", "party_type_id", "trade_species_id",
        "needs_overworld_rain", "turn_upside_down"
    ];
    for (var _i = 0; _i < array_length(_unsupported); ++_i){
        if (__evolution_field_has_value(_row, _unsupported[_i])) return false;
    }

    var _level = __evolution_mon_level(_mon);
    var _min_level = (variable_struct_exists(_row, "minimum_level") && is_real(variable_struct_get(_row, "minimum_level"))) ? floor(variable_struct_get(_row, "minimum_level")) : 0;
    if (_min_level > 0 && _level < _min_level) return false;

    var _min_happy = (variable_struct_exists(_row, "minimum_happiness") && is_real(variable_struct_get(_row, "minimum_happiness"))) ? floor(variable_struct_get(_row, "minimum_happiness")) : 0;
    if (_min_happy > 0 && __evolution_mon_happiness(_mon) < _min_happy) return false;

    if (_min_level <= 0 && _min_happy <= 0) return false;
    return true;
}

function evolution_find_levelup_target(_mon){
    var _sid = __evolution_species_id(_mon);
    if (_sid <= 0 || is_undefined(scr_get_species_evolutions)) return undefined;
    var _rows = scr_get_species_evolutions(_sid);
    if (!is_array(_rows)) return undefined;

    var _best = undefined;
    var _best_score = -1;
    for (var _i = 0; _i < array_length(_rows); ++_i){
        var _row = _rows[_i];
        if (!__evolution_row_supported_for_level(_row, _mon)) continue;
        var _score = 0;
        if (variable_struct_exists(_row, "minimum_level") && is_real(variable_struct_get(_row, "minimum_level"))) _score += floor(variable_struct_get(_row, "minimum_level"));
        if (variable_struct_exists(_row, "minimum_happiness") && is_real(variable_struct_get(_row, "minimum_happiness"))) _score += floor(variable_struct_get(_row, "minimum_happiness"));
        if (_score > _best_score){
            _best = _row;
            _best_score = _score;
        }
    }
    return _best;
}

function evolution_enqueue_levelup(_pid, _mon_ref, _actor_ref = undefined){
    var _row = evolution_find_levelup_target(_mon_ref);
    if (!is_struct(_row)) return false;

    var _E = evolution_ensure(_pid);
    var _q = variable_struct_get(_E, "queue");
    var _target = variable_struct_get(_row, "evolved_species_id");
    for (var _i = 0; _i < array_length(_q); ++_i){
        var _entry = _q[_i];
        if (!is_struct(_entry)) continue;
        if (variable_struct_exists(_entry, "mon_ref") && variable_struct_get(_entry, "mon_ref") == _mon_ref && variable_struct_exists(_entry, "target_species_id") && variable_struct_get(_entry, "target_species_id") == _target) return false;
    }

    array_push(_q, { mon_ref:_mon_ref, actor_ref:_actor_ref, target_species_id:_target, row:_row });
    variable_struct_set(_E, "queue", _q);
    return true;
}

function __evolution_can_begin(_pid){
    if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)) return false;
    if (!is_undefined(pause_is_open) && pause_is_open(_pid)) return false;
    if (!is_undefined(bag_is_open) && bag_is_open(_pid)) return false;
    if (!is_undefined(party_is_open) && party_is_open(_pid)) return false;
    if (!is_undefined(pc_is_open) && pc_is_open(_pid)) return false;
    if (!is_undefined(battle_is_open) && battle_is_open(_pid)){
        var _B = __battle_ensure_slot(_pid);
        if (is_struct(_B) && variable_struct_exists(_B, "_exp_anim")){
            var _exp_anim = variable_struct_get(_B, "_exp_anim");
            if (is_struct(_exp_anim) && variable_struct_exists(_exp_anim, "active") && variable_struct_get(_exp_anim, "active") == true) return false;
        }
    }
    return true;
}

function __evolution_sync_actor(_actor, _mon){
    if (!is_struct(_actor) || !is_struct(_mon)) return;
    var _keys = ["species_id","id","species","name","level","exp","exp_next","hp","hp_now","hp_max","maxhp","atk","def","spa","spd","spe","icon","type1","type2","types","growth_id","shiny"];
    for (var _i = 0; _i < array_length(_keys); ++_i){
        var _k = _keys[_i];
        if (variable_struct_exists(_mon, _k)) variable_struct_set(_actor, _k, variable_struct_get(_mon, _k));
    }
    if (variable_struct_exists(_actor, "mon")) variable_struct_set(_actor, "mon", _mon);
}

function __evolution_apply_to_mon(_mon, _target_species_id){
    if (!is_struct(_mon) || is_undefined(pokemon_factory_create)) return false;
    var _target = is_real(_target_species_id) ? floor(_target_species_id) : -1;
    if (_target <= 0) return false;

    var _level = __evolution_mon_level(_mon);
    var _old_hp_max = (variable_struct_exists(_mon, "hp_max") && is_real(variable_struct_get(_mon, "hp_max"))) ? real(variable_struct_get(_mon, "hp_max")) : ((__evolution_species_id(_mon) > 0) ? real(variable_struct_get(_mon, "hp")) : 1);
    var _old_hp_now = (variable_struct_exists(_mon, "hp_now") && is_real(variable_struct_get(_mon, "hp_now"))) ? real(variable_struct_get(_mon, "hp_now")) : ((__evolution_field_has_value(_mon, "hp") && is_real(variable_struct_get(_mon, "hp"))) ? real(variable_struct_get(_mon, "hp")) : _old_hp_max);

    var _opts = {
        ot: (variable_struct_exists(_mon, "ot") ? variable_struct_get(_mon, "ot") : undefined),
        idno: (variable_struct_exists(_mon, "idno") ? variable_struct_get(_mon, "idno") : _target),
        shiny: (variable_struct_exists(_mon, "shiny") ? variable_struct_get(_mon, "shiny") : false),
        moves: (variable_struct_exists(_mon, "moves") ? variable_struct_get(_mon, "moves") : [-1,-1,-1,-1]),
        exp: (variable_struct_exists(_mon, "exp") ? variable_struct_get(_mon, "exp") : 0),
        held_item_id: (variable_struct_exists(_mon, "held_item_id") ? variable_struct_get(_mon, "held_item_id") : -1),
        held_item_meta: (variable_struct_exists(_mon, "held_item_meta") ? variable_struct_get(_mon, "held_item_meta") : 0),
        pokeball_item_id: (variable_struct_exists(_mon, "pokeball_item_id") ? variable_struct_get(_mon, "pokeball_item_id") : 4)
    };
    var _new_mon = pokemon_factory_create(_target, _level, _opts);
    if (!is_struct(_new_mon)) return false;

    var _preserve_keys = ["nickname","iv","ev","ev_total","pps","seen_moves","status","status_id","status_turns","happiness","friendship","friendliness","affection","sex","gender","sex_id","gender_id","nature","nature_name","held_item_real_name","battleAnim"];
    for (var _i = 0; _i < array_length(_preserve_keys); ++_i){
        var _pk = _preserve_keys[_i];
        if (variable_struct_exists(_mon, _pk)) variable_struct_set(_new_mon, _pk, variable_struct_get(_mon, _pk));
    }

    if (variable_struct_exists(_new_mon, "iv") && variable_struct_exists(_new_mon, "ev")){
        // Recalculate evolved stats using the preserved IV/EV spread.
        var _tmp_iv = variable_struct_get(_new_mon, "iv");
        var _tmp_ev = variable_struct_get(_new_mon, "ev");
        variable_struct_set(_new_mon, "iv", _tmp_iv);
        variable_struct_set(_new_mon, "ev", _tmp_ev);
    }

    var _new_hp_max = (variable_struct_exists(_new_mon, "hp_max") && is_real(variable_struct_get(_new_mon, "hp_max"))) ? real(variable_struct_get(_new_mon, "hp_max")) : _old_hp_max;
    var _hp_delta = _new_hp_max - _old_hp_max;
    var _new_hp_now = clamp(_old_hp_now + _hp_delta, 1, _new_hp_max);
    variable_struct_set(_new_mon, "hp_now", _new_hp_now);
    variable_struct_set(_new_mon, "hp", _new_hp_now);
    variable_struct_set(_new_mon, "name", !is_undefined(scr_poke_name_by_id) ? string(scr_poke_name_by_id(_target)) : string(variable_struct_exists(_new_mon, "species") ? variable_struct_get(_new_mon, "species") : "Pokemon"));

    var _keys = variable_struct_get_names(_new_mon);
    for (var _k_i = 0; _k_i < array_length(_keys); ++_k_i){
        var _k = _keys[_k_i];
        variable_struct_set(_mon, _k, variable_struct_get(_new_mon, _k));
    }
    return true;
}

function __evolution_begin_next(_pid){
    var _E = evolution_ensure(_pid);
    var _q = variable_struct_get(_E, "queue");
    if (!is_array(_q) || array_length(_q) <= 0) return false;

    var _entry = _q[0];
    var _rest = [];
    for (var _i = 1; _i < array_length(_q); ++_i) array_push(_rest, _q[_i]);
    variable_struct_set(_E, "queue", _rest);

    var _mon = variable_struct_exists(_entry, "mon_ref") ? variable_struct_get(_entry, "mon_ref") : undefined;
    if (!is_struct(_mon)) return false;

    var _source = __evolution_species_id(_mon);
    var _target = variable_struct_exists(_entry, "target_species_id") ? floor(variable_struct_get(_entry, "target_species_id")) : -1;
    if (_source <= 0 || _target <= 0 || _source == _target) return false;

    variable_struct_set(_E, "active", true);
    variable_struct_set(_E, "phase", "announce");
    variable_struct_set(_E, "mon_ref", _mon);
    variable_struct_set(_E, "actor_ref", variable_struct_exists(_entry, "actor_ref") ? variable_struct_get(_entry, "actor_ref") : undefined);
    variable_struct_set(_E, "source_species_id", _source);
    variable_struct_set(_E, "target_species_id", _target);
    variable_struct_set(_E, "source_name", __evolution_mon_species_name(_mon));
    variable_struct_set(_E, "nickname_name", __evolution_mon_nickname_or_species_name(_mon));
    variable_struct_set(_E, "target_name", !is_undefined(scr_poke_name_by_id) ? string(scr_poke_name_by_id(_target)) : "Pokemon");
    variable_struct_set(_E, "display_name", __evolution_mon_species_name(_mon));
    variable_struct_set(_E, "allow_cancel", false);

    try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "What?\n" + string(variable_struct_get(_E, "display_name")) + " is evolving!"); } catch (e_evo_announce) {}
    return true;
}

function __evolution_finish(_pid){
    EVOLUTION[_pid] = __evolution_slot();
}

function evolution_update(_pid){
    var _E = evolution_ensure(_pid);
    if (!evolution_is_active(_pid)){
        if (evolution_has_pending(_pid) && __evolution_can_begin(_pid)) __evolution_begin_next(_pid);
        return;
    }

    var _phase = string(variable_struct_get(_E, "phase"));
    if (_phase == "announce"){
        if (is_undefined(dialog2p_is_open) || !dialog2p_is_open(_pid)){
            variable_struct_set(_E, "phase", "anim");
            variable_struct_set(_E, "anim_start_ms", current_time);
            variable_struct_set(_E, "allow_cancel", true);
            var _mon = variable_struct_get(_E, "mon_ref");
            if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_mon)) pkicons_play_cry_by_mon(_mon);
        }
        return;
    }

    if (_phase == "anim"){
        var _can_cancel = variable_struct_exists(_E, "allow_cancel") && variable_struct_get(_E, "allow_cancel") == true;
        if (_can_cancel && !is_undefined(controls_pressed) && (controls_pressed(_pid, "Run") || controls_pressed(_pid, "Back"))){
            variable_struct_set(_E, "phase", "cancel_wait");
            variable_struct_set(_E, "allow_cancel", false);
            try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Huh?\n" + string(variable_struct_get(_E, "display_name")) + " stopped evolving!"); } catch (e_evo_cancel) {}
            return;
        }

        var _started = variable_struct_get(_E, "anim_start_ms");
        var _dur = variable_struct_get(_E, "anim_duration_ms");
        if (!is_real(_started) || _started < 0) _started = current_time;
        if (current_time - _started >= _dur){
            var _mon2 = variable_struct_get(_E, "mon_ref");
            var _target2 = variable_struct_get(_E, "target_species_id");
            var _actor = variable_struct_get(_E, "actor_ref");
            if (__evolution_apply_to_mon(_mon2, _target2)){
                __evolution_sync_actor(_actor, _mon2);
                if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_mon2)) pkicons_play_cry_by_mon(_mon2);
                variable_struct_set(_E, "phase", "result_wait");
                variable_struct_set(_E, "allow_cancel", false);
                try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Congratulations!\n" + string(variable_struct_get(_E, "nickname_name")) + " evolved into " + string(variable_struct_get(_E, "target_name")) + "!"); } catch (e_evo_done) {}
            } else {
                variable_struct_set(_E, "phase", "cancel_wait");
                try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Evolution failed."); } catch (e_evo_fail) {}
            }
        }
        return;
    }

    if (_phase == "cancel_wait" || _phase == "result_wait"){
        if (is_undefined(dialog2p_is_open) || !dialog2p_is_open(_pid)) __evolution_finish(_pid);
    }
}

function evolution_draw_gui(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    evolution_draw_gui_rect(_pid, 0, 0, _gw, _gh);
}

function __evolution_draw_sprite_centered(_spr, _subimg, _cx, _cy, _scale, _blend, _alpha){
    if (!sprite_exists(_spr) || _alpha <= 0) return;
    var _w = sprite_get_width(_spr) * _scale;
    var _h = sprite_get_height(_spr) * _scale;
    var _draw_x = _cx - _w * 0.5;
    var _draw_y = _cy - _h * 0.5;
    draw_sprite_ext(_spr, _subimg, _draw_x, _draw_y, _scale, _scale, 0, _blend, _alpha);
}

function evolution_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    var _E = evolution_ensure(_pid);
    if (!evolution_is_active(_pid)) return;
    if (string(variable_struct_get(_E, "phase")) != "anim") return;

    var _s = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _ox = _rx + (_rw - 240 * _s) div 2;
    var _oy = _ry + (_rh - 160 * _s) div 2;
    var _elapsed = max(0, current_time - variable_struct_get(_E, "anim_start_ms"));
    var _t = max(0, min(1, _elapsed / max(1, variable_struct_get(_E, "anim_duration_ms"))));
    var _cycle_ms = (_t < 0.30) ? 130 : ((_t < 0.70) ? 82 : 54);
    var _phase_idx = floor(_elapsed / _cycle_ms);
    var _show_old = ((_phase_idx mod 2) == 0);
    var _flash_wave = 0.5 + 0.5 * sin(_elapsed / 42);
    var _flash_gate = ((_phase_idx mod 4) == 1 || (_phase_idx mod 4) == 2) ? 1 : 0;
    var _flash_alpha = clamp((0.12 + 0.58 * _flash_wave) * _flash_gate * (0.35 + 0.65 * _t), 0, 0.88);
    var _ring_alpha = clamp(0.16 + 0.18 * _flash_wave, 0, 0.42);

    draw_set_alpha(0.92);
    draw_set_color(make_color_rgb(16, 64, 44));
    draw_rectangle(_rx, _ry, _rx + _rw, _ry + _rh, false);
    draw_set_alpha(1);

    var _cx = _ox + 120 * _s;
    var _cy = _oy + 68 * _s;
    draw_set_alpha(_ring_alpha + 0.06);
    draw_set_color(make_color_rgb(224, 248, 208));
    draw_circle(_cx, _cy, 54 * _s, false);
    draw_set_alpha(_ring_alpha);
    draw_circle(_cx, _cy, 36 * _s, false);
    draw_set_alpha(1);

    var _src_sid = variable_struct_get(_E, "source_species_id");
    var _dst_sid = variable_struct_get(_E, "target_species_id");
    var _src_mon = variable_struct_exists(_E, "mon_ref") ? variable_struct_get(_E, "mon_ref") : { species_id:_src_sid, shiny:false };
    var _dst_mon = { species_id:_dst_sid, shiny:(is_struct(_src_mon) && variable_struct_exists(_src_mon, "shiny") ? variable_struct_get(_src_mon, "shiny") : false) };
    var _src_spr = !is_undefined(pkicons_get_art96_by_mon) ? pkicons_get_art96_by_mon(_src_mon) : -1;
    var _dst_spr = !is_undefined(pkicons_get_art96_by_mon) ? pkicons_get_art96_by_mon(_dst_mon) : -1;
    var _src_subimg = !is_undefined(pkicons_get_art96_subimg_by_mon) ? pkicons_get_art96_subimg_by_mon(_src_mon, false) : 0;
    var _dst_subimg = !is_undefined(pkicons_get_art96_subimg_by_mon) ? pkicons_get_art96_subimg_by_mon(_dst_mon, false) : 0;
    var _old_alpha = _show_old ? 1.0 : 0.0;
    var _new_alpha = _show_old ? 0.0 : 1.0;
    if (_t > 0.82){
        _old_alpha = clamp((1 - _t) / 0.18, 0, 1);
        _new_alpha = 1;
    }

    __evolution_draw_sprite_centered(_src_spr, _src_subimg, _cx, _cy, _s, c_white, _old_alpha);
    __evolution_draw_sprite_centered(_dst_spr, _dst_subimg, _cx, _cy, _s, c_white, _new_alpha);

    __evolution_draw_sprite_centered(_src_spr, _src_subimg, _cx, _cy, _s, make_color_rgb(248, 248, 248), _flash_alpha * _old_alpha);
    __evolution_draw_sprite_centered(_dst_spr, _dst_subimg, _cx, _cy, _s, make_color_rgb(248, 248, 248), _flash_alpha * _new_alpha);

    if (_flash_alpha > 0){
        draw_set_alpha(_flash_alpha * 0.72);
        draw_set_color(c_white);
        draw_rectangle(_rx, _ry, _rx + _rw, _ry + _rh, false);
        draw_set_alpha(1);
    }

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);
    draw_text(_ox + 48 * _s, _oy + 126 * _s, string(variable_struct_get(_E, "display_name")) + " is evolving!");
    if (variable_struct_exists(_E, "allow_cancel") && variable_struct_get(_E, "allow_cancel")){
        draw_text(_ox + 74 * _s, _oy + 140 * _s, "Press B to cancel");
    }
}
