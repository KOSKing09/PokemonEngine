/// @description Convenience wrapper for trainer encounters. Builds the correct battle options struct,
/// seeds the intro cutscene, and calls `battle_open` internally. Provide trainer metadata and
/// party members in `_trainer_data` (e.g. `{ trainer_name:"Ace", enemy_party:[monA, monB] }`).
/// Missing fields fall back to sensible defaults: the first healthy mon becomes the opener,
/// reward values are optional, and sprite indices default to the Emerald trainer sheet.
/// Example: `battle_open_trainer(0, { trainer_name:"Bug Catcher", enemy_party:[monA, monB], area_type:"rocks a" });`
/// Include `area_type` (or `theme.area_type`) to force a specific battlefield preset.
function battle_open_trainer(_pid, _trainer_data){
    var trainer_name = "Trainer";
    var trainer_sprite = sprite_exists(spr_PokemonEmeraldTrainers) ? spr_PokemonEmeraldTrainers : -1;
    var trainer_subimg = 0;
    var trainer_scale = 1;
    var ball_sprite = undefined;
    var ball_scale = 0.75;
    var throw_duration = 540;
    var throw_height = 52;
    var reveal_at = 0.82;
    var throw_origin_x = 210;
    var throw_origin_y = 72;
    var enemy_species = undefined;
    var enemy_level = undefined;
    var enemy_party_source = undefined;
    var enemy_party = [];
    var first_mon = undefined;
    var slide_out_duration = 260;
    var enemy_reveal_duration = 280;
    var area_type = undefined;

    if (is_struct(_trainer_data)){
        if (variable_struct_exists(_trainer_data, "trainer_name")) trainer_name = string(_trainer_data.trainer_name);
        else if (variable_struct_exists(_trainer_data, "name")) trainer_name = string(_trainer_data.name);

        if (variable_struct_exists(_trainer_data, "trainer_sprite")) trainer_sprite = _trainer_data.trainer_sprite;
        else if (variable_struct_exists(_trainer_data, "sprite")) trainer_sprite = _trainer_data.sprite;

        if (variable_struct_exists(_trainer_data, "sprite_index")) trainer_subimg = floor(real(_trainer_data.sprite_index));
        else if (variable_struct_exists(_trainer_data, "frame")) trainer_subimg = floor(real(_trainer_data.frame));
        else if (variable_struct_exists(_trainer_data, "subimg")) trainer_subimg = floor(real(_trainer_data.subimg));

        if (variable_struct_exists(_trainer_data, "sprite_scale")) trainer_scale = max(0.1, real(_trainer_data.sprite_scale));
        if (variable_struct_exists(_trainer_data, "ball_sprite")) ball_sprite = _trainer_data.ball_sprite;
        if (variable_struct_exists(_trainer_data, "ball_scale")) ball_scale = max(0.1, real(_trainer_data.ball_scale));
        if (variable_struct_exists(_trainer_data, "throw_duration")) throw_duration = max(120, real(_trainer_data.throw_duration));
        if (variable_struct_exists(_trainer_data, "throw_height")) throw_height = max(8, real(_trainer_data.throw_height));
        if (variable_struct_exists(_trainer_data, "reveal_at")) reveal_at = clamp(real(_trainer_data.reveal_at), 0.2, 0.99);
        if (variable_struct_exists(_trainer_data, "throw_origin_x")) throw_origin_x = real(_trainer_data.throw_origin_x);
        if (variable_struct_exists(_trainer_data, "throw_origin_y")) throw_origin_y = real(_trainer_data.throw_origin_y);
        if (variable_struct_exists(_trainer_data, "enemy_species")) enemy_species = variable_struct_get(_trainer_data, "enemy_species");
        if (variable_struct_exists(_trainer_data, "enemy_level")) enemy_level = max(1, real(_trainer_data.enemy_level));
        if (variable_struct_exists(_trainer_data, "enemy_mon") && is_struct(variable_struct_get(_trainer_data, "enemy_mon"))) first_mon = variable_struct_get(_trainer_data, "enemy_mon");
        if (variable_struct_exists(_trainer_data, "slide_out_duration")) slide_out_duration = max(60, real(variable_struct_get(_trainer_data, "slide_out_duration")));
        if (variable_struct_exists(_trainer_data, "enemy_reveal_duration")) enemy_reveal_duration = max(60, real(variable_struct_get(_trainer_data, "enemy_reveal_duration")));
        if (variable_struct_exists(_trainer_data, "area_type")) area_type = _trainer_data.area_type;
        else if (variable_struct_exists(_trainer_data, "theme")){
            var _theme_info = variable_struct_get(_trainer_data, "theme");
            if (is_struct(_theme_info) && variable_struct_exists(_theme_info, "area_type")) area_type = _theme_info.area_type;
        }

        var party_fields = ["party", "mons", "team", "enemy_party"];
        for (var pf = 0; pf < array_length(party_fields); ++pf){
            var fname = party_fields[pf];
            if (variable_struct_exists(_trainer_data, fname) && is_array(variable_struct_get(_trainer_data, fname))){
                enemy_party_source = variable_struct_get(_trainer_data, fname);
                break;
            }
        }
    }

    var party_default_level = 5;
    if (is_struct(_trainer_data)){
        if (variable_struct_exists(_trainer_data, "enemy_level") && is_real(variable_struct_get(_trainer_data, "enemy_level"))) party_default_level = max(1, floor(variable_struct_get(_trainer_data, "enemy_level")));
        else if (variable_struct_exists(_trainer_data, "level") && is_real(variable_struct_get(_trainer_data, "level"))) party_default_level = max(1, floor(variable_struct_get(_trainer_data, "level")));
    }

    if (is_array(enemy_party_source)){
        for (var ei = 0; ei < array_length(enemy_party_source); ++ei){
            var __raw_party_entry = enemy_party_source[ei];
            enemy_party[array_length(enemy_party)] = __battle_normalize_trainer_entry(__raw_party_entry, _trainer_data, party_default_level);
        }
    }

    if (is_undefined(first_mon) && array_length(enemy_party) > 0){
        for (var ci = 0; ci < array_length(enemy_party); ++ci){
            var cand = enemy_party[ci];
            if (is_struct(cand)){
                var hp = __battle_hp_now(cand);
                if (!is_real(hp)) hp = 0;
                if (hp > 0){ first_mon = cand; break; }
            }
        }
        if (is_undefined(first_mon)){
            var fallback = enemy_party[0];
            if (is_struct(fallback)) first_mon = fallback;
        }
    }

    var open_level = (is_real(enemy_level) ? floor(enemy_level) : 5);
    if (open_level < 1) open_level = 1;
    if (is_struct(first_mon)){
        if (variable_struct_exists(first_mon, "level")){
            var __lvl_val = variable_struct_get(first_mon, "level");
            if (is_real(__lvl_val)) open_level = max(1, floor(__lvl_val));
        } else if (variable_struct_exists(first_mon, "lvl")){
            var __lvl_alt = variable_struct_get(first_mon, "lvl");
            if (is_real(__lvl_alt)) open_level = max(1, floor(__lvl_alt));
        }
    }

    var opts = { type:"trainer", battle_type:"trainer" };
    if (array_length(enemy_party) > 0) opts.enemy_party = enemy_party;
    if (is_struct(first_mon)) opts.enemy_mon = first_mon;
    if (!is_undefined(enemy_level)) opts.enemy_level = max(1, floor(enemy_level));
    if (!is_undefined(enemy_species)) opts.enemy_species = enemy_species;
    if (is_struct(_trainer_data) && variable_struct_exists(_trainer_data, "battle_format")) opts.battle_format = string_lower(string(variable_struct_get(_trainer_data, "battle_format")));
    if (is_struct(_trainer_data) && variable_struct_exists(_trainer_data, "coop_enabled")) opts.coop_enabled = (variable_struct_get(_trainer_data, "coop_enabled") == true);
    if (is_struct(_trainer_data) && variable_struct_exists(_trainer_data, "player_pids") && is_array(variable_struct_get(_trainer_data, "player_pids"))) opts.player_pids = variable_struct_get(_trainer_data, "player_pids");
    var trainer_reward = undefined;
    if (is_struct(_trainer_data)){
        if (variable_struct_exists(_trainer_data, "trainer_reward") && is_real(variable_struct_get(_trainer_data, "trainer_reward"))){
            trainer_reward = max(0, floor(variable_struct_get(_trainer_data, "trainer_reward")));
        } else if (variable_struct_exists(_trainer_data, "reward") && is_real(variable_struct_get(_trainer_data, "reward"))){
            trainer_reward = max(0, floor(variable_struct_get(_trainer_data, "reward")));
        } else if (variable_struct_exists(_trainer_data, "payout") && is_real(variable_struct_get(_trainer_data, "payout"))){
            trainer_reward = max(0, floor(variable_struct_get(_trainer_data, "payout")));
        }
    }
    if (!is_undefined(trainer_reward)) opts.trainer_reward = trainer_reward;

    if (!is_undefined(area_type)) battle_open(_pid, open_level, area_type, opts);
    else battle_open(_pid, open_level, opts);

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;

    if (!sprite_exists(trainer_sprite)){
        if (sprite_exists(spr_PokemonEmeraldTrainers)) trainer_sprite = spr_PokemonEmeraldTrainers;
        else trainer_sprite = -1;
    }
    var _actors = undefined;
    if (variable_struct_exists(_B, "actor")) _actors = variable_struct_get(_B, "actor");
    var enemy_actor = undefined;
    var _enemy_lead_index = (!is_undefined(__battle_enemy_lead_index) ? __battle_enemy_lead_index(_pid) : 1);
    if (is_array(_actors) && array_length(_actors) > _enemy_lead_index) enemy_actor = _actors[_enemy_lead_index];
    if (is_struct(enemy_actor)){
        try { variable_struct_set(enemy_actor, "actor_index", _enemy_lead_index); } catch (e_ai) {}
        __battle_apply_party_moves(enemy_actor);
    }

    try {
        if (variable_struct_exists(_B, "phase_durs")){
            var phase_durs = variable_struct_get(_B, "phase_durs");
            var required_enemy_ms = throw_duration + 360;
            if (is_struct(phase_durs)){
                var existing = (variable_struct_exists(phase_durs, "enemy") ? phase_durs.enemy : undefined);
                if (!is_real(existing) || existing < required_enemy_ms) variable_struct_set(phase_durs, "enemy", required_enemy_ms);
            }
        }
    } catch (e_pd) {}

    if (is_undefined(ball_sprite)){
        if (!is_undefined(pkicons_init)) pkicons_init();
        if (!is_undefined(pkicons_get_item_icon_by_id)){
            var poke_ball_sprite = pkicons_get_item_icon_by_id(4);
            show_debug_message("[trainer_intro] pkicons_get_item_icon_by_id(4) => " + string(poke_ball_sprite));
            if (!is_undefined(poke_ball_sprite) && sprite_exists(poke_ball_sprite)) ball_sprite = poke_ball_sprite;
        }
    }

    var enemy_name = "Pokemon";
    if (is_struct(enemy_actor) && variable_struct_exists(enemy_actor, "name")) enemy_name = string(variable_struct_get(enemy_actor, "name"));
    var player_actor = undefined;
    if (is_array(_actors) && array_length(_actors) > 0) player_actor = _actors[0];
    var player_name = "Pokemon";
    if (is_struct(player_actor) && variable_struct_exists(player_actor, "name")) player_name = string(variable_struct_get(player_actor, "name"));

    var intro_state = {
        trainer_name: trainer_name,
        trainer_sprite: trainer_sprite,
        trainer_subimg: trainer_subimg,
        trainer_scale: trainer_scale,
        ball_sprite: ball_sprite,
        ball_scale: ball_scale,
        throw_duration: throw_duration,
        throw_height: throw_height,
        reveal_at: reveal_at,
        throw_origin_x: throw_origin_x,
        throw_origin_y: throw_origin_y,
        enemy_mon_name: enemy_name,
        player_mon_name: player_name,
        slide_out_duration: slide_out_duration,
        enemy_reveal_duration: enemy_reveal_duration,
        state: "dialog1",
        hide_enemy_mon: true,
        show_enemy_mon: false,
        enemy_scale_mult: 0,
        _slide_out_progress: 0,
        _dialog1_shown: false,
        _dialog2_shown: false,
        skip_intro_slide: false,
        entry_duration: 360,
        _entry_start_ms: undefined,
        _entry_progress: 0
    };
    try { variable_struct_set(_B, "_trainer_intro", intro_state); } catch (e_intro) {}

    if (is_struct(enemy_actor)){
        try {
            if (variable_struct_exists(enemy_actor, "battleAnim")){
                var animRef = variable_struct_get(enemy_actor, "battleAnim");
                if (!is_struct(animRef) || !variable_struct_exists(animRef, "state")){
                    variable_struct_set(enemy_actor, "battleAnim", undefined);
                    variable_struct_set(enemy_actor, "_battle_anim_reset", true);
                }
            }
        } catch (e_anim_reset) {}
    }

    var trainer_info = {
        name: trainer_name,
        sprite: trainer_sprite,
        subimg: trainer_subimg,
        scale: trainer_scale,
        ball_sprite: ball_sprite,
        ball_scale: ball_scale,
        throw_duration: throw_duration,
        throw_height: throw_height,
        reveal_at: reveal_at,
        throw_origin_x: throw_origin_x,
        throw_origin_y: throw_origin_y,
        slide_return_duration: slide_out_duration
    };
    try { variable_struct_set(_B, "_trainer_info", trainer_info); } catch (e_info) {}

    battle_intro_set_handlers(_pid, __battle_trainer_intro_update, __battle_trainer_intro_draw);
}

/// Resolve the trainer name stored on a battle slot or return a safe fallback.
function __battle_trainer_get_name(_B){
    if (!is_struct(_B)) return "The Trainer";
    if (variable_struct_exists(_B, "_trainer_info")){
        var info = variable_struct_get(_B, "_trainer_info");
        if (is_struct(info) && variable_struct_exists(info, "name")){
            return string(info.name);
        }
    }
    if (variable_struct_exists(_B, "_battle_opts") && is_struct(variable_struct_get(_B, "_battle_opts"))){
        var opts = variable_struct_get(_B, "_battle_opts");
        if (variable_struct_exists(opts, "trainer_name")) return string(opts.trainer_name);
    }
    return "The Trainer";
}

/// Determine whether a trainer party entry should be treated as alive.
function __battle_trainer_mon_is_alive(_mon){
    if (!is_struct(_mon)) return false;
    var _dbg_trainer = true;
    try {
        if (variable_global_exists("DATA_DEBUG_TRAINER")) _dbg_trainer = (global.DATA_DEBUG_TRAINER == true);
        else if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) _dbg_trainer = true;
    } catch (e_dbgflag_alive_mon) { _dbg_trainer = false; }
    var hp = __battle_hp_now(_mon);
    if (is_real(hp)){
        if (hp > 0){
            if (_dbg_trainer){
                try {
                    var _mon_name_true = "<unnamed>";
                    if (variable_struct_exists(_mon, "name")) _mon_name_true = string(variable_struct_get(_mon, "name"));
                    show_debug_message("[battle][trainer][alive-mon] " + _mon_name_true + " alive (hp=" + string(hp) + ")");
                } catch (e_dbg_alive_true) {}
            }
            return true;
        }
        if (hp <= 0){
            if (_dbg_trainer){
                try {
                    var _mon_name_zero = "<unnamed>";
                    if (variable_struct_exists(_mon, "name")) _mon_name_zero = string(variable_struct_get(_mon, "name"));
                    show_debug_message("[battle][trainer][alive-mon] " + _mon_name_zero + " flagged faint (hp=" + string(hp) + ")");
                } catch (e_dbg_alive_zero) {}
            }
            return false;
        }
    }
    var faint_flag = false;
    try { if (variable_struct_exists(_mon, "_fainted") && variable_struct_get(_mon, "_fainted")) faint_flag = true; } catch (e_ff) { faint_flag = false; }
    var has_hp_field = false;
    try { has_hp_field = variable_struct_exists(_mon, "hp_now") || variable_struct_exists(_mon, "hp"); } catch (e_hpf) { has_hp_field = false; }
    if (!has_hp_field && !faint_flag){
        if (_dbg_trainer){
            try {
                var _mon_name_fallback = "<unnamed>";
                if (variable_struct_exists(_mon, "name")) _mon_name_fallback = string(variable_struct_get(_mon, "name"));
                show_debug_message("[battle][trainer][alive-mon] " + _mon_name_fallback + " treated alive (no hp fields, no faint flag)");
            } catch (e_dbg_alive_fallback) {}
        }
        return true;
    }
    if (_dbg_trainer){
        try {
            var _mon_name_false = "<unnamed>";
            if (variable_struct_exists(_mon, "name")) _mon_name_false = string(variable_struct_get(_mon, "name"));
            show_debug_message("[battle][trainer][alive-mon] " + _mon_name_false + " treated faint (flag=" + string(faint_flag) + ", has_hp_field=" + string(has_hp_field) + ")");
        } catch (e_dbg_alive_false) {}
    }
    return false;
}

/// Check whether any trainer party member other than the excluded reference is still alive.
function __battle_trainer_has_alive_except(_B, _exclude){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_party")) return false;
    var party = variable_struct_get(_B, "_trainer_party");
    if (!is_array(party)) return false;
    var _dbg_trainer = true;
    try {
        if (variable_global_exists("DATA_DEBUG_TRAINER")) _dbg_trainer = (global.DATA_DEBUG_TRAINER == true);
        else if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) _dbg_trainer = true;
    } catch (e_dbgflag_alive) { _dbg_trainer = false; }
    for (var i = 0; i < array_length(party); ++i){
        var mon = party[i];
        if (!is_struct(mon)) continue;
        if (!is_undefined(_exclude)){
            if (mon == _exclude) continue;
            if (is_struct(_exclude) && variable_struct_exists(_exclude, "mon") && mon == variable_struct_get(_exclude, "mon")) continue;
            if (variable_struct_exists(mon, "mon") && is_struct(variable_struct_get(mon, "mon")) && variable_struct_get(mon, "mon") == _exclude) continue;
        }
        if (__battle_trainer_mon_is_alive(mon)){
            if (_dbg_trainer){
                try {
                    var mon_name_alive = "<unnamed>";
                    if (variable_struct_exists(mon, "name")) mon_name_alive = string(variable_struct_get(mon, "name"));
                    show_debug_message("[battle][trainer][alive-check] idx=" + string(i) + " mon=" + mon_name_alive + " still alive");
                } catch (e_dbg_alive_found) {}
            }
            return true;
        }
        if (_dbg_trainer){
            try {
                var mon_name = "<unnamed>";
                if (variable_struct_exists(mon, "name")) mon_name = string(variable_struct_get(mon, "name"));
                show_debug_message("[battle][trainer][alive-check] idx=" + string(i) + " mon=" + mon_name + " marked faint");
            } catch (e_dbg_alive) {}
        }
    }
    if (_dbg_trainer){
        try { show_debug_message("[battle][trainer][alive-check] no living mons found"); } catch (e_dbg_alive_none) {}
    }
    return false;
}

function __battle_trainer_active_party_index_for_actor(_B, _actorIndex){
    if (!is_struct(_B) || !is_real(_actorIndex)) return -1;
    var _slot = floor(_actorIndex);
    var _is_double = (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double");
    if (_is_double && variable_struct_exists(_B, "_trainer_party_active_indices") && is_array(variable_struct_get(_B, "_trainer_party_active_indices"))){
        var _active_indices = variable_struct_get(_B, "_trainer_party_active_indices");
        var _enemy_slot = _slot - 2;
        if (_enemy_slot >= 0 && _enemy_slot < array_length(_active_indices) && is_real(_active_indices[_enemy_slot])) return floor(_active_indices[_enemy_slot]);
    }
    if (variable_struct_exists(_B, "_trainer_party_active_idx") && is_real(variable_struct_get(_B, "_trainer_party_active_idx"))) return floor(variable_struct_get(_B, "_trainer_party_active_idx"));
    return -1;
}

function __battle_trainer_next_alive_index_excluding(_B, _exclude_indices, _from_idx = undefined){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_party")) return -1;
    var party = variable_struct_get(_B, "_trainer_party");
    if (!is_array(party) || array_length(party) <= 0) return -1;

    var len = array_length(party);
    var anchor = (is_real(_from_idx) ? clamp(floor(_from_idx), -1, len - 1) : -1);
    var _exclude = (is_array(_exclude_indices) ? _exclude_indices : []);

    var start = max(anchor + 1, 0);
    for (var i = start; i < len; ++i){
        var _skip_i = false;
        for (var _ei = 0; _ei < array_length(_exclude); ++_ei){
            if (is_real(_exclude[_ei]) && floor(_exclude[_ei]) == i){
                _skip_i = true;
                break;
            }
        }
        if (_skip_i) continue;
        var mon = party[i];
        if (is_struct(mon) && __battle_trainer_mon_is_alive(mon)) return i;
    }

    for (var j = 0; j < len && (anchor < 0 || j <= anchor); ++j){
        var _skip_j = false;
        for (var _ej = 0; _ej < array_length(_exclude); ++_ej){
            if (is_real(_exclude[_ej]) && floor(_exclude[_ej]) == j){
                _skip_j = true;
                break;
            }
        }
        if (_skip_j) continue;
        var mon2 = party[j];
        if (is_struct(mon2) && __battle_trainer_mon_is_alive(mon2)) return j;
    }

    return -1;
}

/// Return the next unfainted trainer party index, searching forward then wrapping to the start.
function __battle_trainer_next_alive_index(_B, _from_idx){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_party")) return -1;
    var party = variable_struct_get(_B, "_trainer_party");
    if (!is_array(party) || array_length(party) <= 0) return -1;

    var len = array_length(party);
    var anchor = -1;
    if (is_real(_from_idx)) anchor = clamp(floor(_from_idx), -1, len - 1);

    var _dbg_trainer = true;
    try {
        if (variable_global_exists("DATA_DEBUG_TRAINER")) _dbg_trainer = (global.DATA_DEBUG_TRAINER == true);
        else if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) _dbg_trainer = true;
    } catch (e_dbgflag_next) { _dbg_trainer = false; }

    var start = max(anchor + 1, 0);
    for (var i = start; i < len; ++i){
        if (i == anchor) continue;
        var mon = party[i];
        if (!is_struct(mon)) continue;
        if (__battle_trainer_mon_is_alive(mon)) return i;
        if (_dbg_trainer){
            try {
                var mon_name_fwd = "<unnamed>";
                if (variable_struct_exists(mon, "name")) mon_name_fwd = string(variable_struct_get(mon, "name"));
                show_debug_message("[battle][trainer][next] skip idx=" + string(i) + " mon=" + mon_name_fwd + " (fainted)");
            } catch (e_dbg_next_fwd) {}
        }
    }

    if (anchor >= 0){
        for (var j = 0; j < len && j <= anchor; ++j){
            if (j == anchor) continue;
            var mon2 = party[j];
            if (!is_struct(mon2)) continue;
            if (__battle_trainer_mon_is_alive(mon2)) return j;
            if (_dbg_trainer){
                try {
                    var mon_name_wrap = "<unnamed>";
                    if (variable_struct_exists(mon2, "name")) mon_name_wrap = string(variable_struct_get(mon2, "name"));
                    show_debug_message("[battle][trainer][next] wrap skip idx=" + string(j) + " mon=" + mon_name_wrap + " (fainted)");
                } catch (e_dbg_next_wrap) {}
            }
        }
    }

    return -1;
}

/// Schedule the trainer's next Pokemon to enter after a faint; returns true when successfully queued.
function __battle_trainer_schedule_next_mon(_pid, _next_idx, _actor_index = 1){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;
    if (!variable_struct_exists(_B, "_trainer_party")) return false;
    var party = variable_struct_get(_B, "_trainer_party");
    if (!is_array(party) || _next_idx < 0 || _next_idx >= array_length(party)) return false;
    var mon = party[_next_idx];
    if (!is_struct(mon) || !__battle_trainer_mon_is_alive(mon)) return false;

    var trainer_name = __battle_trainer_get_name(_B);
    var mon_name = (variable_struct_exists(mon, "name") ? string(mon.name) : "their Pokemon");

    var pending = {
        idx: _next_idx,
        actor_index: (is_real(_actor_index) ? floor(_actor_index) : 1),
        ready_ms: current_time + 420,
        dialog_enqueued: false,
        message: string(trainer_name) + " sent out " + string(mon_name) + "!"
    };
    if (__battle_dialog_debug_enabled()){
        try { show_debug_message("[battle][trainer] schedule pending pid=" + string(_pid) + ", idx=" + string(_next_idx) + ", mon=" + string(mon_name)); } catch (e_dbg) {}
    }

    try { variable_struct_set(_B, "_trainer_pending_send", pending); } catch (e_set) { return false; }
    return true;
}

function __battle_find_player_party_active_index(_pid, _actorIndex){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return -1;
    var _actors = variable_struct_get(_B, "actor");
    var _lookup_actor_index = is_real(_actorIndex) ? floor(_actorIndex) : 0;
    if (_lookup_actor_index < 0 || _lookup_actor_index >= array_length(_actors) || !is_struct(_actors[_lookup_actor_index])) return -1;
    var _active_actor = _actors[_lookup_actor_index];
    var _active_mon = (variable_struct_exists(_active_actor, "mon") && is_struct(variable_struct_get(_active_actor, "mon"))) ? variable_struct_get(_active_actor, "mon") : _active_actor;
    var _mons = party_model_get_mons(_pid);
    if (!is_array(_mons)) return -1;
    for (var _i = 0; _i < array_length(_mons); ++_i){
        var _mon = _mons[_i];
        if (!is_struct(_mon)) continue;
        if (_mon == _active_mon || _mon == _active_actor) return _i;
    }
    return -1;
}

function __battle_is_player_party_index_active(_pid, _partyIndex){
    if (!is_real(_partyIndex)) return false;
    var _mons = party_model_get_mons(_pid);
    var _idx = floor(_partyIndex);
    if (!is_array(_mons) || _idx < 0 || _idx >= array_length(_mons)) return false;
    var _want_mon = _mons[_idx];
    if (!is_struct(_want_mon)) return false;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return false;
    var _actors = variable_struct_get(_B, "actor");
    for (var _i = 0; _i < array_length(_actors); ++_i){
        var _actor = _actors[_i];
        if (!is_struct(_actor) || __battle_actor_side(_i) != 0) continue;
        var _actor_mon = (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) ? variable_struct_get(_actor, "mon") : _actor;
        if (_actor == _want_mon || _actor_mon == _want_mon) return true;
    }
    return false;
}

function __battle_find_first_switchable_party_index(_pid){
    var _mons = party_model_get_mons(_pid);
    if (!is_array(_mons)) return -1;
    var _active_idx = __battle_find_player_party_active_index(_pid, 0);
    for (var _i = 0; _i < array_length(_mons); ++_i){
        if (_i == _active_idx) continue;
        var _mon = _mons[_i];
        if (!is_struct(_mon)) continue;
        var _hp = __battle_hp_now(_mon);
        if (is_real(_hp) && _hp > 0) return _i;
    }
    return -1;
}

function __battle_collect_switchable_party_indexes(_pid, _actorIndex){
    var _mons = party_model_get_mons(_pid);
    if (!is_array(_mons)) return [];
    var _active_idx = __battle_find_player_party_active_index(_pid, _actorIndex);
    var _out = [];
    for (var _i = 0; _i < array_length(_mons); ++_i){
        if (_i == _active_idx) continue;
        if (!__battle_party_index_is_usable(_pid, _i)) continue;
        if (__battle_is_player_party_index_active(_pid, _i)) continue;
        array_push(_out, _i);
    }
    return _out;
}

function __battle_pick_random_switchable_party_index(_pid, _actorIndex){
    var _choices = __battle_collect_switchable_party_indexes(_pid, _actorIndex);
    if (!is_array(_choices) || array_length(_choices) <= 0) return -1;
    return _choices[irandom(array_length(_choices) - 1)];
}

function __battle_trainer_begin_switch_prompt(_pid, _next_idx){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_party")) return false;
    var _party = variable_struct_get(_B, "_trainer_party");
    if (!is_array(_party) || !is_real(_next_idx) || _next_idx < 0 || _next_idx >= array_length(_party)) return false;
    var _mon = _party[_next_idx];
    if (!is_struct(_mon) || !__battle_trainer_mon_is_alive(_mon)) return false;

    var _next_name = __battle_dialog_actor_name(_mon, "Pokemon");
    var _trainer_name = __battle_trainer_get_name(_B);
    var _prompt = {
        active: true,
        enemy_next_idx: floor(_next_idx),
        enemy_next_name: _next_name,
        trainer_name: _trainer_name,
        sel: 1,
        player_choice: "none",
        player_switch_idx: -1,
        phase: "prompt"
    };
    try { variable_struct_set(_B, "_trainer_switch_prompt", _prompt); } catch (e_prompt_set) { return false; }
    try { variable_struct_set(_B, "_pending_close", false); } catch (e_pc_prompt) {}
    try { variable_struct_set(_B, "_action_active", false); } catch (e_act_prompt) {}
    variable_struct_set(_B, "phase", "command");
    return true;
}

function __battle_trainer_clear_switch_prompt(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    try { variable_struct_set(_B, "_trainer_switch_prompt", undefined); } catch (e_clear_prompt) {}
    try {
        var _P = party_ensure(_pid);
        if (is_struct(_P) && variable_struct_exists(_P, "_trainer_prompt_pick_mode")) variable_struct_set(_P, "_trainer_prompt_pick_mode", false);
    } catch (e_clear_prompt_party) {}
}

function __battle_trainer_open_switch_party(_pid){
    if (is_undefined(party_open) || is_undefined(party_ensure)) return false;
    party_open(_pid);
    var _P = party_ensure(_pid);
    if (!is_struct(_P)) return false;
    try { variable_struct_set(_P, "_trainer_prompt_pick_mode", true); } catch (e_pick_mode) {}
    try { variable_struct_set(_P, "_battle_swap_mode", false); } catch (e_swap_mode) {}
    try { variable_struct_set(_P, "_battle_swap_mode_forced", false); } catch (e_swap_forced) {}
    try { variable_struct_set(_P, "mode", "list"); } catch (e_pick_list) {}
    try { variable_struct_set(_P, "lock", 0); } catch (e_pick_lock) {}
    var _pick_idx = __battle_find_first_switchable_party_index(_pid);
    if (_pick_idx >= 0){
        try { variable_struct_set(_P, "sel", _pick_idx); } catch (e_pick_sel) {}
    }
    return true;
}

function __battle_trainer_update_switch_prompt(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_switch_prompt")) return false;
    var _prompt = variable_struct_get(_B, "_trainer_switch_prompt");
    if (!is_struct(_prompt) || !variable_struct_exists(_prompt, "active") || !_prompt.active) return false;

    var _phase = (variable_struct_exists(_prompt, "phase") ? string(variable_struct_get(_prompt, "phase")) : "prompt");
    if (_phase == "await_party"){
        var _party_open = (!is_undefined(party_is_open) && party_is_open(_pid)) || (!is_undefined(pc_is_open) && pc_is_open(_pid));
        if (!_party_open){
            var _pick = (variable_struct_exists(_prompt, "player_switch_idx") && is_real(variable_struct_get(_prompt, "player_switch_idx"))) ? floor(variable_struct_get(_prompt, "player_switch_idx")) : -1;
            if (_pick >= 0){
                variable_struct_set(_prompt, "player_choice", "yes");
            } else {
                variable_struct_set(_prompt, "player_choice", "no");
                variable_struct_set(_prompt, "player_switch_idx", -1);
            }
            variable_struct_set(_prompt, "phase", "queue_enemy_send");
            variable_struct_set(_B, "_trainer_switch_prompt", _prompt);
        }
        return true;
    }

    if (_phase == "queue_enemy_send"){
        if (!variable_struct_exists(_B, "_trainer_pending_send") || !is_struct(variable_struct_get(_B, "_trainer_pending_send"))){
            var _next_idx = (variable_struct_exists(_prompt, "enemy_next_idx") ? variable_struct_get(_prompt, "enemy_next_idx") : -1);
            if (__battle_trainer_schedule_next_mon(_pid, _next_idx)){
                variable_struct_set(_prompt, "phase", "await_enemy_send");
                variable_struct_set(_B, "_trainer_switch_prompt", _prompt);
            } else {
                __battle_trainer_clear_switch_prompt(_pid);
            }
        }
        return true;
    }

    if (_phase == "await_enemy_send"){
        var _dialog_open = (is_undefined(dialog2p_is_open) ? false : dialog2p_is_open(_pid));
        var _send_pending = (variable_struct_exists(_B, "_trainer_pending_send") && is_struct(variable_struct_get(_B, "_trainer_pending_send")));
        var _switch_anim = (variable_struct_exists(_B, "_trainer_switch") && is_struct(variable_struct_get(_B, "_trainer_switch")));
        if (_dialog_open || _send_pending || _switch_anim) return true;

        var _pick_idx2 = (variable_struct_exists(_prompt, "player_switch_idx") && is_real(variable_struct_get(_prompt, "player_switch_idx"))) ? floor(variable_struct_get(_prompt, "player_switch_idx")) : -1;
        if (_pick_idx2 >= 0){
            var _ok_switch = battle_switch_to(_pid, _pick_idx2, { auto_apply:true, consume_turn:false, forced:true });
            if (_ok_switch){
                __battle_trainer_clear_switch_prompt(_pid);
                return true;
            }
        }
        __battle_trainer_clear_switch_prompt(_pid);
        return true;
    }

    return true;
}

function __battle_trainer_start_switch_anim(_pid, _pending_actor, _pending_idx, _opts){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;

    var info = (variable_struct_exists(_B, "_trainer_info") ? variable_struct_get(_B, "_trainer_info") : undefined);
    var throw_duration = 540;
    var recall_duration = 220;
    var materialize_duration = 180;
    var pending_actor_index = 1;
    var throw_height = 52;
    var throw_origin_x = 210;
    var throw_origin_y = 72;
    var ball_sprite = undefined;
    var ball_scale = 0.75;
    if (is_struct(info)){
        if (variable_struct_exists(info, "throw_duration") && is_real(variable_struct_get(info, "throw_duration"))) throw_duration = max(120, real(variable_struct_get(info, "throw_duration")));
        if (variable_struct_exists(info, "throw_height") && is_real(variable_struct_get(info, "throw_height"))) throw_height = max(8, real(variable_struct_get(info, "throw_height")));
        if (variable_struct_exists(info, "throw_origin_x") && is_real(variable_struct_get(info, "throw_origin_x"))) throw_origin_x = real(variable_struct_get(info, "throw_origin_x"));
        if (variable_struct_exists(info, "throw_origin_y") && is_real(variable_struct_get(info, "throw_origin_y"))) throw_origin_y = real(variable_struct_get(info, "throw_origin_y"));
        if (variable_struct_exists(info, "ball_sprite")) ball_sprite = variable_struct_get(info, "ball_sprite");
        if (variable_struct_exists(info, "ball_scale") && is_real(variable_struct_get(info, "ball_scale"))) ball_scale = max(0.1, real(variable_struct_get(info, "ball_scale")));
    }

    var recall = true;
    var old_actor = undefined;
    if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
        var _actors_sw = variable_struct_get(_B, "actor");
        if (array_length(_actors_sw) > 1) old_actor = _actors_sw[1];
    }
    if (is_struct(_opts)){
        if (variable_struct_exists(_opts, "recall") && variable_struct_get(_opts, "recall") == false) recall = false;
        if (variable_struct_exists(_opts, "recall_duration") && is_real(variable_struct_get(_opts, "recall_duration"))) recall_duration = max(0, real(variable_struct_get(_opts, "recall_duration")));
        if (variable_struct_exists(_opts, "actor_index") && is_real(variable_struct_get(_opts, "actor_index"))) pending_actor_index = floor(variable_struct_get(_opts, "actor_index"));
    }

    if (recall && is_struct(old_actor)){
        var _old_hp = __battle_hp_now(old_actor);
        if (!is_real(_old_hp) || _old_hp <= 0) recall = false;
        try {
            if (variable_struct_exists(old_actor, "fainted") && variable_struct_get(old_actor, "fainted") == true) recall = false;
        } catch (e_old_fainted) {}
    } else {
        recall = false;
    }

    var anim = {
        phase: (recall ? "recall" : "throw"),
        phase_start_ms: current_time,
        recall_duration: recall_duration,
        throw_duration: throw_duration,
        materialize_duration: materialize_duration,
        throw_height: throw_height,
        throw_origin_x: throw_origin_x,
        throw_origin_y: throw_origin_y,
        ball_sprite: ball_sprite,
        ball_scale: ball_scale,
        pending_actor: _pending_actor,
        pending_idx: _pending_idx,
        pending_actor_index: pending_actor_index,
        applied: false,
        active: true
    };
    try { variable_struct_set(_B, "_trainer_switch", anim); } catch (e_anim) { return false; }
    try {
        var _anim_until = current_time + recall_duration + throw_duration + materialize_duration;
        if (!variable_struct_exists(_B, "_suppress_sys_ui_until") || !is_real(variable_struct_get(_B, "_suppress_sys_ui_until")) || variable_struct_get(_B, "_suppress_sys_ui_until") < _anim_until){
            variable_struct_set(_B, "_suppress_sys_ui_until", _anim_until);
        }
    } catch (e_sup_anim) {}
    return true;
}

function __battle_trainer_update_switch_anim(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_switch")) return false;
    var anim = variable_struct_get(_B, "_trainer_switch");
    if (!is_struct(anim)) return false;

    var now = current_time;
    var phase = (variable_struct_exists(anim, "phase") ? string(variable_struct_get(anim, "phase")) : "");
    var phase_start = (variable_struct_exists(anim, "phase_start_ms") && is_real(variable_struct_get(anim, "phase_start_ms"))) ? real(variable_struct_get(anim, "phase_start_ms")) : now;

    if (phase == "recall"){
        var recall_duration = (variable_struct_exists(anim, "recall_duration") && is_real(variable_struct_get(anim, "recall_duration"))) ? max(1, real(variable_struct_get(anim, "recall_duration"))) : 220;
        if (now - phase_start >= recall_duration){
            variable_struct_set(anim, "phase", "throw");
            variable_struct_set(anim, "phase_start_ms", now);
            phase = "throw";
            phase_start = now;
        }
    }

    if (phase == "throw"){
        var throw_duration = (variable_struct_exists(anim, "throw_duration") && is_real(variable_struct_get(anim, "throw_duration"))) ? max(1, real(variable_struct_get(anim, "throw_duration"))) : 540;
        var throw_prog = clamp((now - phase_start) / throw_duration, 0, 1);

        if (throw_prog >= 1){
            variable_struct_set(anim, "phase", "materialize");
            variable_struct_set(anim, "phase_start_ms", now);
            phase = "materialize";
            phase_start = now;
        }
    }

    if (phase == "materialize"){
        if ((!variable_struct_exists(anim, "applied") || variable_struct_get(anim, "applied") != true)){
            var new_actor = (variable_struct_exists(anim, "pending_actor") ? variable_struct_get(anim, "pending_actor") : undefined);
            var idx = (variable_struct_exists(anim, "pending_idx") ? variable_struct_get(anim, "pending_idx") : -1);
            var actor_index = (variable_struct_exists(anim, "pending_actor_index") && is_real(variable_struct_get(anim, "pending_actor_index"))) ? floor(variable_struct_get(anim, "pending_actor_index")) : 1;
            if (is_struct(new_actor)){
                var _actors_live = variable_struct_get(_B, "actor");
                _actors_live[actor_index] = new_actor;
                variable_struct_set(_B, "actor", _actors_live);
                try { variable_struct_set(new_actor, "actor_index", actor_index); } catch (e_ai_sw) {}
                __battle_apply_party_moves(new_actor);
                try {
                    if (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double"){
                        var _active_indices_sw = (variable_struct_exists(_B, "_trainer_party_active_indices") && is_array(variable_struct_get(_B, "_trainer_party_active_indices"))) ? variable_struct_get(_B, "_trainer_party_active_indices") : [];
                        var _enemy_slot_sw = actor_index - 2;
                        if (_enemy_slot_sw >= 0){
                            while (array_length(_active_indices_sw) <= _enemy_slot_sw) array_push(_active_indices_sw, -1);
                            _active_indices_sw[_enemy_slot_sw] = idx;
                            variable_struct_set(_B, "_trainer_party_active_indices", _active_indices_sw);
                        }
                    } else {
                        variable_struct_set(_B, "_trainer_party_active_idx", idx);
                    }
                } catch (e_idx_sw) {}
                try {
                    var __fn_entry_haz_sw = undefined;
                    if (variable_global_exists("__battle_apply_entry_hazards")) __fn_entry_haz_sw = variable_global_get("__battle_apply_entry_hazards");
                    if (!is_undefined(__fn_entry_haz_sw)) __fn_entry_haz_sw(_pid, actor_index);
                } catch (e_haz_sw) {}
                try { __battle_apply_pending_healing_wish_to_actor(_pid, actor_index, new_actor); } catch (e_hw_enemy_anim) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][healing-wish] enemy anim apply failed: " + string(e_hw_enemy_anim)); }
                try { if (!is_undefined(__battle_apply_entry_abilities)) __battle_apply_entry_abilities(_pid, actor_index); } catch (e_ability_enemy_anim) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ability] enemy anim entry failed: " + string(e_ability_enemy_anim)); }
                try {
                    variable_struct_set(_B, "_cry_played_enemy", false);
                    try { __battle_apply_pending_healing_wish_to_actor(_pid, actor_index, new_actor); } catch (e_hw_enemy_pending) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][healing-wish] enemy pending apply failed: " + string(e_hw_enemy_pending)); }
                    variable_struct_set(_B, "_cry_play_start_ms_enemy", current_time);
                } catch (e_cry_sw) {}
            }
            variable_struct_set(anim, "applied", true);
        }

        var materialize_duration = (variable_struct_exists(anim, "materialize_duration") && is_real(variable_struct_get(anim, "materialize_duration"))) ? max(1, real(variable_struct_get(anim, "materialize_duration"))) : 180;
        var materialize_prog = clamp((now - phase_start) / materialize_duration, 0, 1);
        if (materialize_prog >= 1){
            try { variable_struct_remove(_B, "_trainer_switch"); } catch (e_done_sw) { variable_struct_set(_B, "_trainer_switch", undefined); }
            return false;
        }
    }

    return true;
}

/// Apply any pending trainer send-out once dialog has cleared; returns true when the swap completes.
function __battle_trainer_apply_pending_send(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_pending_send")) return false;
    var pending = variable_struct_get(_B, "_trainer_pending_send");
    if (!is_struct(pending)) return false;

    var party = (variable_struct_exists(_B, "_trainer_party") ? variable_struct_get(_B, "_trainer_party") : undefined);
    if (!is_array(party)) { if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send"); return false; }

    var idx = (variable_struct_exists(pending, "idx") ? pending.idx : -1);
    var actor_index = (variable_struct_exists(pending, "actor_index") && is_real(variable_struct_get(pending, "actor_index"))) ? floor(variable_struct_get(pending, "actor_index")) : 1;
    if (!is_real(idx) || idx < 0 || idx >= array_length(party)) { if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send"); return false; }
    var mon = party[idx];
    if (!is_struct(mon)) { if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send"); return false; }
    if (!__battle_trainer_mon_is_alive(mon)){
        try { if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send"); } catch (e_drop_dead) {}
        return false;
    }

    var now = current_time;
    var dialog_open = (is_undefined(dialog2p_is_open) ? false : dialog2p_is_open(_pid));

    if (!variable_struct_exists(pending, "dialog_enqueued") || !pending.dialog_enqueued){
        if (!dialog_open){
            var msg = (variable_struct_exists(pending, "message") ? string(pending.message) : "A Pokemon was sent out!");
            try {
                if (!is_undefined(dialog2p_enqueue)) dialog2p_enqueue(_pid, { text: msg, key: msg, gate: "trainer-send" });
                else if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, msg);
            } catch (e_msg) {}
            pending.dialog_enqueued = true;
            pending.ready_ms = now + 160;
            try { variable_struct_set(_B, "_trainer_pending_send", pending); } catch (e_upd) {}
            if (__battle_dialog_debug_enabled()){
                try { show_debug_message("[battle][trainer] dialog enqueued pid=" + string(_pid) + ", msg=" + string(msg)); } catch (e_dbg3) {}
            }
        }
        return false;
    }

    if (dialog_open) return false;
    if (variable_struct_exists(pending, "ready_ms") && is_real(pending.ready_ms) && now < pending.ready_ms) return false;

    var new_actor = __battle_actor_from_party_mon(mon);
    var _anim_started = false;
    try {
        if (!is_undefined(__battle_trainer_start_switch_anim)) _anim_started = __battle_trainer_start_switch_anim(_pid, new_actor, idx, { recall: false, actor_index: actor_index });
    } catch (e_anim_pending) { _anim_started = false; }
    if (!_anim_started){
        var _actors_send = variable_struct_get(_B, "actor");
        _actors_send[actor_index] = new_actor;
        variable_struct_set(_B, "actor", _actors_send);
        try {
            if (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double"){
                var _active_indices = (variable_struct_exists(_B, "_trainer_party_active_indices") && is_array(variable_struct_get(_B, "_trainer_party_active_indices"))) ? variable_struct_get(_B, "_trainer_party_active_indices") : [];
                var _enemy_slot = actor_index - 2;
                if (_enemy_slot >= 0){
                    while (array_length(_active_indices) <= _enemy_slot) array_push(_active_indices, -1);
                    _active_indices[_enemy_slot] = idx;
                    variable_struct_set(_B, "_trainer_party_active_indices", _active_indices);
                }
            } else {
                variable_struct_set(_B, "_trainer_party_active_idx", idx);
            }
        } catch (e_act_idx) {}
        if (is_struct(new_actor)){
            try { variable_struct_set(new_actor, "actor_index", actor_index); } catch (e_ai) {}
            __battle_apply_party_moves(new_actor);
        }

        try {
            var __fn_entry_haz = undefined;
            if (variable_global_exists("__battle_apply_entry_hazards")){
                __fn_entry_haz = variable_global_get("__battle_apply_entry_hazards");
            }
            if (!is_undefined(__fn_entry_haz)) __fn_entry_haz(_pid, actor_index);
        } catch (e_haz) {}
        try { if (!is_undefined(__battle_apply_entry_abilities)) __battle_apply_entry_abilities(_pid, actor_index); } catch (e_ability_enemy_send) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ability] enemy send entry failed: " + string(e_ability_enemy_send)); }
        try { variable_struct_set(_B, "_cry_played_enemy", false); variable_struct_set(_B, "_cry_play_start_ms_enemy", current_time); } catch (e_cr) {}
    }
    try {
        if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send");
    } catch (e_clr) {}

    try {
        var desired = current_time + 420;
        var existing = (variable_struct_exists(_B, "_suppress_sys_ui_until") ? variable_struct_get(_B, "_suppress_sys_ui_until") : -1);
        if (!is_real(existing) || existing < desired) variable_struct_set(_B, "_suppress_sys_ui_until", desired);
    } catch (e_sup) {}

    variable_struct_set(_B, "phase", "command");
    try { variable_struct_set(_B, "_pending_close", false); } catch (e_pc) {}
    try { variable_struct_set(_B, "_faint_pending", false); } catch (e_fp) {}
    try { variable_struct_set(_B, "_faint_dialog_active", false); } catch (e_fdreset) {}
    try { variable_struct_set(_B, "_command_pending_action", undefined); } catch (e_clear_send_action) {}
    try { variable_struct_set(_B, "_target_pick_targets", undefined); } catch (e_clear_send_targets) {}
    try { variable_struct_set(_B, "_target_pick_index", 0); } catch (e_clear_send_idx) {}
    try {
        var _sys_ui = (variable_struct_exists(_B, "sys_ui") ? variable_struct_get(_B, "sys_ui") : undefined);
        if (is_struct(_sys_ui) && string(variable_struct_get(_sys_ui, "menu")) == "target"){
            variable_struct_set(_sys_ui, "menu", "root");
            variable_struct_set(_sys_ui, "selX", 0);
            variable_struct_set(_sys_ui, "selY", 0);
        }
    } catch (e_clear_send_menu) {}

    return true;
}

if (is_undefined(__battle_trainer_debug_force_switch)){
    function __battle_trainer_debug_force_switch(_pid){
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B)) return false;
        var __set_reason = function(_reason){
            try { variable_struct_set(_B, "_debug_trainer_force_switch_reason", _reason); } catch (e_reason) {}
        };
        __set_reason(undefined);
        var mode = "";
        try {
            if (variable_struct_exists(_B, "_battle_mode")) mode = string_lower(string(variable_struct_get(_B, "_battle_mode")));
        } catch (e_mode) { mode = ""; }
        if (mode != "trainer") { __set_reason("not_trainer"); return false; }
        var party = (variable_struct_exists(_B, "_trainer_party") ? variable_struct_get(_B, "_trainer_party") : undefined);
        if (!is_array(party)) { __set_reason("no_party"); return false; }
        var active_idx = -1;
        var enemy_actor = undefined;
        if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
            var _actors_dbg = variable_struct_get(_B, "actor");
            if (array_length(_actors_dbg) > 1) enemy_actor = _actors_dbg[1];
        }
        try {
            if (is_struct(enemy_actor)){
                var __fn_jaw_block_dbg = undefined;
                if (variable_global_exists("__battle_jaw_lock_is_blocked")){
                    __fn_jaw_block_dbg = variable_global_get("__battle_jaw_lock_is_blocked");
                }
                if (!is_undefined(__fn_jaw_block_dbg) && __fn_jaw_block_dbg(enemy_actor)) { __set_reason("jaw_lock"); return false; }
            }
        } catch (e_jl_block) {}
        if (is_struct(enemy_actor)){
            try {
                if (!is_undefined(status_system_has_status)){
                    if (status_system_has_status(enemy_actor, "trap")) { __set_reason("trap"); return false; }
                    if (variable_struct_exists(enemy_actor, "mon") && is_struct(variable_struct_get(enemy_actor, "mon"))){
                        var _enemy_mon_dbg = variable_struct_get(enemy_actor, "mon");
                        if (status_system_has_status(_enemy_mon_dbg, "trap")) { __set_reason("trap"); return false; }
                    }
                }
            } catch (e_trap_chk) {}
        }
        try {
            if (variable_struct_exists(_B, "_trainer_party_active_idx")) active_idx = variable_struct_get(_B, "_trainer_party_active_idx");
        } catch (e_act) { active_idx = -1; }
        if (!is_real(active_idx) || active_idx < 0 || active_idx >= array_length(party)) active_idx = -1;
        var next_idx = __battle_trainer_next_alive_index(_B, active_idx);
        if (!is_real(next_idx) || next_idx < 0 || next_idx >= array_length(party)) { __set_reason("no_next"); return false; }
        if (active_idx == next_idx) { __set_reason("same_idx"); return false; }
        try { variable_struct_set(_B, "_debug_trainer_force_switch_idx", next_idx); } catch (e_idx) { __set_reason("set_idx_fail"); return false; }
        try {
            var cur_actor = undefined;
            if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                var _actors_dbg = variable_struct_get(_B, "actor");
                if (array_length(_actors_dbg) > 1) cur_actor = _actors_dbg[1];
            }
            var from_name = undefined;
            if (is_struct(cur_actor) && variable_struct_exists(cur_actor, "name")) from_name = string(variable_struct_get(cur_actor, "name"));
            var next_mon = party[next_idx];
            var to_name = undefined;
            if (is_struct(next_mon) && variable_struct_exists(next_mon, "name")) to_name = string(variable_struct_get(next_mon, "name"));
            variable_struct_set(_B, "_debug_trainer_force_switch_from", from_name);
            variable_struct_set(_B, "_debug_trainer_force_switch_to", to_name);
        } catch (e_meta) {}
        __set_reason(undefined);
        return true;
    }
}

if (is_undefined(__battle_trainer_perform_switch_action)){
    function __battle_trainer_perform_switch_action(_pid, _dst_idx, _step_meta){
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B)) return "But it failed!";
        var party = (variable_struct_exists(_B, "_trainer_party") ? variable_struct_get(_B, "_trainer_party") : undefined);
        if (!is_array(party)) return "But it failed!";
        var idx = floor(_dst_idx);
        if (!is_real(idx) || idx < 0 || idx >= array_length(party)) return "But it failed!";
        var mon = party[idx];
        if (!is_struct(mon) || !__battle_trainer_mon_is_alive(mon)) return "But it failed!";

        var actors_arr = (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))) ? variable_struct_get(_B, "actor") : [];
        var old_actor = undefined;
        if (array_length(actors_arr) > 1) old_actor = actors_arr[1];

        var trainer_name = __battle_trainer_get_name(_B);
        var from_name = (is_struct(old_actor) && variable_struct_exists(old_actor, "name")) ? string(variable_struct_get(old_actor, "name")) : "their Pokemon";
        var to_name = __battle_dialog_actor_name(mon, "a Pokemon");
        if (is_struct(_step_meta)){
            try {
                if (variable_struct_exists(_step_meta, "debug_from") && is_string(variable_struct_get(_step_meta, "debug_from"))){
                    var _df = string(variable_struct_get(_step_meta, "debug_from"));
                    if (string_length(_df) > 0) from_name = _df;
                }
                if (variable_struct_exists(_step_meta, "debug_to") && is_string(variable_struct_get(_step_meta, "debug_to"))){
                    var _dt = string(variable_struct_get(_step_meta, "debug_to"));
                    if (string_length(_dt) > 0) to_name = _dt;
                }
            } catch (e_dbg) {}
        }

        try {
            var __fn_jaw_release_trainer = undefined;
            if (variable_global_exists("__battle_jaw_lock_release")){
                __fn_jaw_release_trainer = variable_global_get("__battle_jaw_lock_release");
            }
            if (!is_undefined(__fn_jaw_release_trainer)) __fn_jaw_release_trainer(old_actor);
        } catch (e_jaw) {}
        try {
            if (!is_undefined(status_system_clear_status) && is_struct(old_actor)){
                status_system_clear_status(old_actor, "trap");
                status_system_clear_status(old_actor, "perish-song");
                status_system_clear_status(old_actor, "infatuation");
                if (variable_struct_exists(old_actor, "mon") && is_struct(variable_struct_get(old_actor, "mon"))){
                    status_system_clear_status(variable_struct_get(old_actor, "mon"), "trap");
                    status_system_clear_status(variable_struct_get(old_actor, "mon"), "perish-song");
                    status_system_clear_status(variable_struct_get(old_actor, "mon"), "infatuation");
                }
                if (!is_undefined(status_system_has_status) && !is_undefined(status_system_get) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                    var _acts_inf_tr = variable_struct_get(_B, "actor");
                    var _old_mon = (variable_struct_exists(old_actor, "mon") && is_struct(variable_struct_get(old_actor, "mon")) ? variable_struct_get(old_actor, "mon") : undefined);
                    for (var _it_inf = 0; _it_inf < array_length(_acts_inf_tr); ++_it_inf){
                        var _cand_inf_tr = _acts_inf_tr[_it_inf];
                        if (!is_struct(_cand_inf_tr) || _cand_inf_tr == old_actor) continue;
                        if (!status_system_has_status(_cand_inf_tr, "infatuation")) continue;
                        var _inst_inf_tr = status_system_get(_cand_inf_tr, "infatuation");
                        var _src_inf_tr = (is_struct(_inst_inf_tr) && variable_struct_exists(_inst_inf_tr, "source") ? variable_struct_get(_inst_inf_tr, "source") : undefined);
                        var _clear_inf_tr = (_src_inf_tr == old_actor) || (!is_undefined(_old_mon) && _src_inf_tr == _old_mon);
                        if (!_clear_inf_tr && is_struct(_src_inf_tr) && variable_struct_exists(_src_inf_tr, "mon") && !is_undefined(_old_mon)) _clear_inf_tr = (variable_struct_get(_src_inf_tr, "mon") == _old_mon);
                        if (_clear_inf_tr){
                            status_system_clear_status(_cand_inf_tr, "infatuation");
                            if (variable_struct_exists(_cand_inf_tr, "mon") && is_struct(variable_struct_get(_cand_inf_tr, "mon"))) status_system_clear_status(variable_struct_get(_cand_inf_tr, "mon"), "infatuation");
                        }
                    }
                }
            }
        } catch (e_trap) {}

        var new_actor = __battle_actor_from_party_mon(mon);
        var _anim_started = false;
        try {
            if (!is_undefined(__battle_trainer_start_switch_anim)) _anim_started = __battle_trainer_start_switch_anim(_pid, new_actor, idx, { recall: true });
        } catch (e_anim) { _anim_started = false; }
        if (!_anim_started){
            if (array_length(actors_arr) <= 1) actors_arr[1] = new_actor;
            else actors_arr[1] = new_actor;
            try { variable_struct_set(_B, "actor", actors_arr); } catch (e_setarr) {}
            try { variable_struct_set(_B, "_trainer_party_active_idx", idx); } catch (e_idxset) {}

            if (is_struct(new_actor)){
                try { variable_struct_set(new_actor, "actor_index", 1); } catch (e_ai) {}
                if (!is_undefined(__battle_apply_party_moves)) __battle_apply_party_moves(new_actor);
                try { __battle_apply_baton_pass_payload(_B, new_actor, 1); } catch (e_bp_apply_enemy) {}
            }

            try {
                var __fn_entry_haz_trainer = undefined;
                if (variable_global_exists("__battle_apply_entry_hazards")){
                    __fn_entry_haz_trainer = variable_global_get("__battle_apply_entry_hazards");
                }
                if (!is_undefined(__fn_entry_haz_trainer)) __fn_entry_haz_trainer(_pid, 1);
            } catch (e_haz) {}
            try { __battle_apply_pending_healing_wish_to_actor(_pid, 1, new_actor); } catch (e_hw_enemy_direct) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][healing-wish] enemy direct apply failed: " + string(e_hw_enemy_direct)); }
            try { if (!is_undefined(__battle_apply_entry_abilities)) __battle_apply_entry_abilities(_pid, 1); } catch (e_ability_enemy_direct) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ability] enemy direct entry failed: " + string(e_ability_enemy_direct)); }
            try {
                variable_struct_set(_B, "_cry_played_enemy", false);
                variable_struct_set(_B, "_cry_play_start_ms_enemy", current_time);
            } catch (e_cry) {}
        }
        try {
            variable_struct_set(_B, "_debug_trainer_force_switch_idx", undefined);
            variable_struct_set(_B, "_debug_trainer_force_switch_from", undefined);
            variable_struct_set(_B, "_debug_trainer_force_switch_to", undefined);
        } catch (e_clrdbg) {}

        var msg = string(trainer_name) + " withdrew " + string(from_name) + "!";
        msg += "\n" + string(trainer_name) + " sent out " + string(to_name) + "!";
        return msg;
    }
}

/// Award the trainer payout once and queue defeat dialogs for the status message pipeline.
function __battle_trainer_handle_defeat(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    if (variable_struct_exists(_B, "_trainer_reward_paid") && variable_struct_get(_B, "_trainer_reward_paid")) return;

    var reward = 0;
    if (variable_struct_exists(_B, "_trainer_reward") && is_real(variable_struct_get(_B, "_trainer_reward"))){
        reward = max(0, floor(variable_struct_get(_B, "_trainer_reward")));
    }

    if (!is_undefined(currency_add)) currency_add(reward);
    else {
        if (!variable_global_exists("PLAYER_MONEY") || !is_real(global.PLAYER_MONEY)) global.PLAYER_MONEY = 0;
        global.PLAYER_MONEY = max(0, floor(global.PLAYER_MONEY)) + reward;
    }

    var trainer_name = __battle_trainer_get_name(_B);
    var pend = (variable_struct_exists(_B, "_pending_status_msgs") ? variable_struct_get(_B, "_pending_status_msgs") : []);
    if (!is_array(pend)) pend = [];
    var defeat_msg = string(trainer_name) + " was defeated!";
    array_push(pend, defeat_msg);
    if (__battle_dialog_debug_enabled()) show_debug_message("[battle][dialog] status pend enqueue pid=" + string(_pid) + ", text=" + defeat_msg);
    if (reward > 0){
        var reward_msg = "You got $" + string(reward) + " for winning!";
        array_push(pend, reward_msg);
        if (__battle_dialog_debug_enabled()) show_debug_message("[battle][dialog] status pend enqueue pid=" + string(_pid) + ", text=" + reward_msg);
    }
    try { variable_struct_set(_B, "_pending_status_msgs", pend); } catch (e_pend) {}
    try { variable_struct_set(_B, "_trainer_reward_paid", true); } catch (e_paid) {}
    var __vict_start2 = __battle_fetch_global_function("__battle_trainer_start_victory_slide");
    if (!is_undefined(__vict_start2)) __vict_start2(_pid);
    var _dbg_trainer = false;
    try {
        if (variable_global_exists("DATA_DEBUG_TRAINER")) _dbg_trainer = (global.DATA_DEBUG_TRAINER == true);
        else if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) _dbg_trainer = true;
    } catch (e_dbgflag_hand) { _dbg_trainer = false; }
    if (_dbg_trainer){
        try { show_debug_message("[battle][trainer] defeat handled reward=" + string(reward)); } catch (e_dbg_handle) {}
    }
}

// Queue or immediately show trainer-intro dialog text during the trainer intro sequence.
function __battle_trainer_intro_show_dialog(_pid, _text){
    var txt = string(_text);
    if (string_length(txt) <= 0) return;
    try {
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, txt);
        else if (!is_undefined(dialog2p_enqueue)) dialog2p_enqueue(_pid, txt);
    } catch (e_show) {}
}

// Open the dialog system for the trainer intro sequence; sets up UI state.
function __battle_trainer_intro_dialog_open(_pid){
    try {
        if (!is_undefined(dialog2p_is_open)) return dialog2p_is_open(_pid);
    } catch (e_is) {}
    return false;
}

function __battle_trainer_intro_dialog_pids(_B, _pid){
    var _out = [max(0, floor(_pid))];
    if (is_struct(_B) && variable_struct_exists(_B, "player_pids") && is_array(variable_struct_get(_B, "player_pids"))){
        var _ppids = variable_struct_get(_B, "player_pids");
        _out = [];
        for (var _i = 0; _i < array_length(_ppids); ++_i){
            if (!is_real(_ppids[_i])) continue;
            array_push(_out, max(0, floor(_ppids[_i])));
        }
    }
    return _out;
}

function __battle_trainer_intro_all_dialogs_closed(_B, _pid){
    var _pids = __battle_trainer_intro_dialog_pids(_B, _pid);
    for (var _i = 0; _i < array_length(_pids); ++_i){
        if (__battle_trainer_intro_dialog_open(_pids[_i])) return false;
    }
    return true;
}

function __battle_trainer_intro_trainer_name_for_pid(_B, _pid, _fallback){
    var _name = string(_fallback);
    if (is_struct(_B) && variable_struct_exists(_B, "_versus_trainer_names") && is_array(variable_struct_get(_B, "_versus_trainer_names"))){
        var _names = variable_struct_get(_B, "_versus_trainer_names");
        if (_pid >= 0 && _pid < array_length(_names) && is_string(_names[_pid])) _name = _names[_pid];
    }
    return _name;
}

function __battle_trainer_intro_enemy_name_for_pid(_B, _pid, _fallback){
    var _name = string(_fallback);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return _name;
    var _actors = variable_struct_get(_B, "actor");
    for (var _i = 0; _i < array_length(_actors); ++_i){
        var _owner = (!is_undefined(__battle_actor_owner_pid) ? __battle_actor_owner_pid(_pid, _i) : -1);
        if (!is_real(_owner) || floor(_owner) == floor(_pid)) continue;
        var _actor = _actors[_i];
        if (is_struct(_actor)){
            var _mon = (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) ? variable_struct_get(_actor, "mon") : _actor;
            if (!is_undefined(mon_display_name)){
                var _disp = mon_display_name(_mon);
                if (is_string(_disp) && string_length(string_trim(_disp)) > 0 && string(_disp) != "???") return string_trim(_disp);
            }
            if (variable_struct_exists(_mon, "nickname")){
                var _nick = string(variable_struct_get(_mon, "nickname"));
                if (string_length(string_trim(_nick)) > 0 && string_lower(string_trim(_nick)) != "undefined") return string_trim(_nick);
            }
            if (variable_struct_exists(_actor, "name")) return string(variable_struct_get(_actor, "name"));
        }
    }
    return _name;
}

function __battle_trainer_intro_player_name_for_pid(_B, _pid, _fallback){
    var _name = string(_fallback);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return _name;
    var _actors = variable_struct_get(_B, "actor");
    for (var _i = 0; _i < array_length(_actors); ++_i){
        var _owner = (!is_undefined(__battle_actor_owner_pid) ? __battle_actor_owner_pid(_pid, _i) : -1);
        if (!is_real(_owner) || floor(_owner) != floor(_pid)) continue;
        var _actor = _actors[_i];
        if (is_struct(_actor)){
            var _mon = (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) ? variable_struct_get(_actor, "mon") : _actor;
            if (!is_undefined(mon_display_name)){
                var _disp = mon_display_name(_mon);
                if (is_string(_disp) && string_length(string_trim(_disp)) > 0 && string(_disp) != "???") return string_trim(_disp);
            }
            if (variable_struct_exists(_mon, "nickname")){
                var _nick = string(variable_struct_get(_mon, "nickname"));
                if (string_length(string_trim(_nick)) > 0 && string_lower(string_trim(_nick)) != "undefined") return string_trim(_nick);
            }
            if (variable_struct_exists(_actor, "name")) return string(variable_struct_get(_actor, "name"));
        }
    }
    return _name;
}

// Update tick for the trainer intro animation; advances timelines and dialog.
function __battle_trainer_intro_update(_pid, _B){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_intro")) return;
    var intro = variable_struct_get(_B, "_trainer_intro");
    if (!is_struct(intro)) return;

    var now = current_time;
    var state = "dialog1";
    if (variable_struct_exists(intro, "state")) state = string(intro.state);

    var entry_dur = 360;
    if (variable_struct_exists(intro, "entry_duration") && is_real(intro.entry_duration)) entry_dur = max(120, real(intro.entry_duration));
    var entry_start = undefined;
    if (variable_struct_exists(intro, "_entry_start_ms") && is_real(intro._entry_start_ms)) entry_start = intro._entry_start_ms;
    if (!is_real(entry_start)){
        entry_start = now;
        variable_struct_set(intro, "_entry_start_ms", entry_start);
    }
    var entry_prog = clamp((now - entry_start) / entry_dur, 0, 1);
    variable_struct_set(intro, "_entry_progress", entry_prog);

    if (state == "cleanup"){
        battle_intro_set_handlers(_pid, undefined, undefined);
        try { variable_struct_set(_B, "_trainer_intro", undefined); } catch (e_clear) {}
        return;
    }

    if (state == "dialog1"){
        var shown1 = (variable_struct_exists(intro, "_dialog1_shown") && intro._dialog1_shown);
        if (!shown1){
            var _dialog_pids = __battle_trainer_intro_dialog_pids(_B, _pid);
            for (var _di = 0; _di < array_length(_dialog_pids); ++_di){
                var _dialog_pid = _dialog_pids[_di];
                var _intro_trainer_name = __battle_trainer_intro_trainer_name_for_pid(_B, _dialog_pid, intro.trainer_name);
                __battle_trainer_intro_show_dialog(_dialog_pid, _intro_trainer_name + " would like to battle!");
            }
            variable_struct_set(intro, "_dialog1_shown", true);
        }
        variable_struct_set(intro, "state", "wait_dialog1");
    } else if (state == "wait_dialog1"){
        variable_struct_set(intro, "hide_enemy_mon", true);
        if (__battle_trainer_intro_all_dialogs_closed(_B, _pid)) variable_struct_set(intro, "state", "throw_prep");
    } else if (state == "throw_prep"){
        var start_ms = current_time;
        variable_struct_set(intro, "_throw_start_ms", start_ms);
        variable_struct_set(intro, "_throw_progress", 0);
        try { variable_struct_set(_B, "phase_start_ms", start_ms); } catch (e_start) {}
        var slide_dur = 260;
        if (variable_struct_exists(intro, "slide_out_duration")) slide_dur = max(60, real(variable_struct_get(intro, "slide_out_duration")));
        variable_struct_set(intro, "_slide_out_start_ms", start_ms);
        variable_struct_set(intro, "_slide_out_duration", slide_dur);
        variable_struct_set(intro, "_slide_out_progress", 0);
        if (!(variable_struct_exists(intro, "_dialog2_shown") && intro._dialog2_shown)){
            var _dialog_pids2 = __battle_trainer_intro_dialog_pids(_B, _pid);
            for (var _di2 = 0; _di2 < array_length(_dialog_pids2); ++_di2){
                var _dialog_pid2 = _dialog_pids2[_di2];
                var _enemy_name = __battle_trainer_intro_enemy_name_for_pid(_B, _dialog_pid2, intro.enemy_mon_name);
                __battle_trainer_intro_show_dialog(_dialog_pid2, "Go " + _enemy_name + "!");
            }
            variable_struct_set(intro, "_dialog2_shown", true);
        }
        variable_struct_set(intro, "state", "throw");
    } else if (state == "throw"){
        var start = (variable_struct_exists(intro, "_throw_start_ms") ? variable_struct_get(intro, "_throw_start_ms") : now);
        var dur = (variable_struct_exists(intro, "throw_duration") ? max(1, real(variable_struct_get(intro, "throw_duration"))) : 540);
        var prog = clamp((now - start) / dur, 0, 1);
        variable_struct_set(intro, "_throw_progress", prog);
        var slide_start = (variable_struct_exists(intro, "_slide_out_start_ms") ? variable_struct_get(intro, "_slide_out_start_ms") : start);
        var slide_dur_cur = (variable_struct_exists(intro, "_slide_out_duration") ? max(1, real(variable_struct_get(intro, "_slide_out_duration"))) : 260);
        var slide_prog = clamp((now - slide_start) / slide_dur_cur, 0, 1);
        variable_struct_set(intro, "_slide_out_progress", slide_prog);
        var reveal_at = (variable_struct_exists(intro, "reveal_at") ? clamp(real(variable_struct_get(intro, "reveal_at")), 0, 1) : 0.85);
        if (prog >= reveal_at){
            variable_struct_set(intro, "show_enemy_mon", true);
            variable_struct_set(intro, "hide_enemy_mon", false);
            if (!variable_struct_exists(intro, "_enemy_reveal_start_ms")){
                variable_struct_set(intro, "_enemy_reveal_start_ms", now);
                variable_struct_set(intro, "_enemy_scale_progress", 0);
            }
        }
        if (prog >= 1){
            variable_struct_set(intro, "state", "wait_dialog2");
        }
    } else if (state == "wait_dialog2"){
        variable_struct_set(intro, "show_enemy_mon", true);
        variable_struct_set(intro, "hide_enemy_mon", false);
        variable_struct_set(intro, "_slide_out_progress", 1);
        if (!variable_struct_exists(intro, "_enemy_reveal_start_ms")){
            variable_struct_set(intro, "_enemy_reveal_start_ms", now);
            variable_struct_set(intro, "_enemy_scale_progress", 1);
            variable_struct_set(intro, "enemy_scale_mult", 1);
        }
        if (__battle_trainer_intro_all_dialogs_closed(_B, _pid)){
            if (!(variable_struct_exists(intro, "_player_dialog_shown") && intro._player_dialog_shown)){
                var _dialog_pids3 = __battle_trainer_intro_dialog_pids(_B, _pid);
                for (var _di3 = 0; _di3 < array_length(_dialog_pids3); ++_di3){
                    var _dialog_pid3 = _dialog_pids3[_di3];
                    var _player_name = __battle_trainer_intro_player_name_for_pid(_B, _dialog_pid3, intro.player_mon_name);
                    __battle_trainer_intro_show_dialog(_dialog_pid3, "Go " + _player_name + "!");
                }
                variable_struct_set(intro, "_player_dialog_shown", true);
            }
            _B.phase = "intro_call";
            _B.phase_start_ms = now;
            _B.phase_progress = 0;
            variable_struct_set(intro, "state", "player_dialog");
        } else {
            _B.phase_progress = 1;
        }
    } else if (state == "player_dialog"){
        if (string(_B.phase) != "intro_call"){
            _B.phase = "intro_call";
            _B.phase_start_ms = now;
            _B.phase_progress = 0;
        }
        if (__battle_trainer_intro_all_dialogs_closed(_B, _pid)){
            variable_struct_set(intro, "state", "cleanup");
            _B.phase = "intro_call";
            _B.phase_start_ms = now;
            _B.phase_progress = 0;
        } else {
            _B.phase_progress = 1;
        }
    }

    var slide_prog = 0;
    var ph = string(_B.phase);
    if (ph == "intro_enemy"){
        var ph_prog = 0;
        if (variable_struct_exists(_B, "phase_progress")) ph_prog = clamp(real(_B.phase_progress), 0, 1);
        slide_prog = ph_prog;
    } else if (ph == "intro_call" || ph == "intro_player" || ph == "command" || ph == "turn"){
        slide_prog = 1;
    }
    variable_struct_set(intro, "_slide_progress", slide_prog);

    var slide_out_prog_now = 0;
    if (variable_struct_exists(intro, "_slide_out_progress")) slide_out_prog_now = clamp(real(variable_struct_get(intro, "_slide_out_progress")), 0, 1);
    var state_now = string(variable_struct_exists(intro, "state") ? intro.state : "");
    if (state_now == "wait_dialog2" || state_now == "player_dialog" || state_now == "cleanup") slide_out_prog_now = 1;
    variable_struct_set(intro, "_slide_out_progress", slide_out_prog_now);

    var reveal_start = undefined;
    if (variable_struct_exists(intro, "_enemy_reveal_start_ms")) reveal_start = variable_struct_get(intro, "_enemy_reveal_start_ms");
    if (is_real(reveal_start)){
        var reveal_dur = 280;
        if (variable_struct_exists(intro, "enemy_reveal_duration")) reveal_dur = max(60, real(variable_struct_get(intro, "enemy_reveal_duration")));
        var scale_prog = clamp((now - reveal_start) / reveal_dur, 0, 1);
        var sendout_values = __battle_sendout_anim_values(scale_prog, 1);
        variable_struct_set(intro, "_enemy_scale_progress", scale_prog);
        variable_struct_set(intro, "enemy_scale_mult", clamp(variable_struct_get(sendout_values, "scale"), 0, 1.2));
    } else {
        if (state_now == "dialog1" || state_now == "wait_dialog1" || state_now == "throw_prep" || state_now == "throw"){
            variable_struct_set(intro, "enemy_scale_mult", 0);
        }
    }
}

// Draw the trainer intro cinematic (trainer sprite, throw animation, overlays).
function __battle_trainer_intro_draw(_pid, _B){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_intro")) return;
    var intro = variable_struct_get(_B, "_trainer_intro");
    if (!is_struct(intro)) return;

    var ui_s = 1;
    try {
        if (variable_struct_exists(_B, "_ui")){
            var __ui = variable_struct_get(_B, "_ui");
            if (is_struct(__ui) && variable_struct_exists(__ui, "s")) ui_s = __ui.s;
        }
    } catch (e_ui) { ui_s = 1; }

    var trainer_target_x = __bxu(_pid, 165);
    var trainer_target_y = __byu(_pid, 40);
    var enemy_center_x = trainer_target_x;
    var enemy_center_y = trainer_target_y;

    var enemy_actor_draw = (!is_undefined(__battle_get_side_actor) ? __battle_get_side_actor(_pid, 1, 0) : undefined);

    var enemy_sprite_w = 64;
    var enemy_sprite_h = 64;
    if (is_struct(enemy_actor_draw)){
        var mon_draw = undefined;
        if (variable_struct_exists(enemy_actor_draw, "mon")) mon_draw = variable_struct_get(enemy_actor_draw, "mon");
        if (!is_undefined(pkicons_get_art96_by_mon)){
            var spr_draw = pkicons_get_art96_by_mon(mon_draw);
            if (!is_undefined(spr_draw) && sprite_exists(spr_draw)){
                enemy_sprite_w = sprite_get_width(spr_draw);
                enemy_sprite_h = sprite_get_height(spr_draw);
            }
        }
    }

    var anchor_scale = 1;
    if (is_struct(enemy_actor_draw) && variable_struct_exists(enemy_actor_draw, "scale")){
        var anchor_scale_raw = variable_struct_get(enemy_actor_draw, "scale");
        if (is_real(anchor_scale_raw)) anchor_scale = max(0.1, anchor_scale_raw);
    }

    var draw_scale_target = ui_s * anchor_scale;
    var enemy_shadow_h = max(2, floor((enemy_sprite_w * draw_scale_target) * 0.12));
    var enemy_shadow_offset = enemy_shadow_h * 0.8 + floor(15 * ui_s);
    var enemy_anchor_x = enemy_center_x;
    var enemy_anchor_y = enemy_center_y + enemy_shadow_offset;

    var slide_start = __bxu(_pid, 280);
    var entry_prog_local = 0;
    if (variable_struct_exists(intro, "_entry_progress")) entry_prog_local = clamp(real(variable_struct_get(intro, "_entry_progress")), 0, 1);
    var slide_prog = entry_prog_local;
    if (variable_struct_exists(intro, "_slide_progress")) slide_prog = max(slide_prog, clamp(real(variable_struct_get(intro, "_slide_progress")), 0, 1));
    var ease_in = 1 - (1 - slide_prog) * (1 - slide_prog);
    var trainer_entry_cx = lerp(slide_start, trainer_target_x, ease_in);

    var slide_out_prog = 0;
    if (variable_struct_exists(intro, "_slide_out_progress")) slide_out_prog = clamp(real(variable_struct_get(intro, "_slide_out_progress")), 0, 1);
    var ease_out = 1 - power(1 - slide_out_prog, 2);
    var trainer_cx = lerp(trainer_entry_cx, slide_start, ease_out);

    var trainer_sprite = intro.trainer_sprite;
    if (!(!is_undefined(trainer_sprite) && sprite_exists(trainer_sprite))){
        if (sprite_exists(spr_PokemonEmeraldTrainers)) trainer_sprite = spr_PokemonEmeraldTrainers;
        else trainer_sprite = -1;
    }
    if (trainer_sprite != -1){
        var trainer_scale = (variable_struct_exists(intro, "trainer_scale") && is_real(intro.trainer_scale)) ? intro.trainer_scale : 1;
        var subimg_raw = (variable_struct_exists(intro, "trainer_subimg") && is_real(intro.trainer_subimg)) ? intro.trainer_subimg : 0;
        var frames = max(1, sprite_get_number(trainer_sprite));
        var trainer_subimg = ((floor(subimg_raw) % frames) + frames) % frames;
        var spr_w = sprite_get_width(trainer_sprite);
        var spr_h = sprite_get_height(trainer_sprite);
        var draw_x = trainer_cx - (spr_w * trainer_scale * ui_s) * 0.5;
        var draw_y = trainer_target_y - (spr_h * trainer_scale * ui_s) * 0.5;
        draw_sprite_ext(trainer_sprite, trainer_subimg, draw_x, draw_y, trainer_scale * ui_s, trainer_scale * ui_s, 0, c_white, 1);
    }

    var state = string(variable_struct_exists(intro, "state") ? intro.state : "");
    var throw_progress = (variable_struct_exists(intro, "_throw_progress") ? clamp(real(intro._throw_progress), 0, 1) : 0);
    var ball_target_x = enemy_anchor_x;
    var ball_ground_y = enemy_center_y + (enemy_sprite_h * ui_s) * 0.5 - max(1, floor(2 * ui_s));
    var ball_target_y = ball_ground_y;
    variable_struct_set(intro, "_enemy_ball_anchor_y", ball_target_y);
    var draw_ball = (state == "throw" || state == "wait_dialog2" || state == "player_dialog");

    if (draw_ball){
        var ball_sprite = (variable_struct_exists(intro, "ball_sprite") ? intro.ball_sprite : undefined);
        if (is_undefined(ball_sprite) || !sprite_exists(ball_sprite)){
            if (!is_undefined(pkicons_get_item_icon_by_id)){
                var pb_try = pkicons_get_item_icon_by_id(4);
                if (is_struct(intro) && !variable_struct_exists(intro, "_pokeball_debug_retry")){
                    show_debug_message("[trainer_intro] draw retry pkicons item 4 => " + string(pb_try));
                    variable_struct_set(intro, "_pokeball_debug_retry", true);
                }
                if (!is_undefined(pb_try) && sprite_exists(pb_try)){
                    ball_sprite = pb_try;
                    variable_struct_set(intro, "ball_sprite", pb_try);
                }
            }
        }
        var ball_scale = (variable_struct_exists(intro, "ball_scale") && is_real(intro.ball_scale)) ? intro.ball_scale : 0.75;
        var origin_log_x = (variable_struct_exists(intro, "throw_origin_x") && is_real(intro.throw_origin_x)) ? intro.throw_origin_x : 210;
        var origin_log_y = (variable_struct_exists(intro, "throw_origin_y") && is_real(intro.throw_origin_y)) ? intro.throw_origin_y : 72;
        var start_x = __bxu(_pid, origin_log_x);
        var start_y = __byu(_pid, origin_log_y);
        var bx = ball_target_x;
        var by = ball_target_y;
        if (state == "throw"){
            bx = lerp(start_x, ball_target_x, throw_progress);
            by = lerp(start_y, ball_target_y, throw_progress);
            var arc_h = __bhu(_pid, (variable_struct_exists(intro, "throw_height") && is_real(intro.throw_height)) ? intro.throw_height : 52);
            by -= sin(throw_progress * pi) * arc_h;
            variable_struct_set(intro, "_ball_land_x", bx);
            variable_struct_set(intro, "_ball_land_y", by);
        } else {
            if (!variable_struct_exists(intro, "_ball_land_x")){
                variable_struct_set(intro, "_ball_land_x", ball_target_x);
                variable_struct_set(intro, "_ball_land_y", ball_target_y);
            }
            if (variable_struct_exists(intro, "_ball_land_x")) bx = variable_struct_get(intro, "_ball_land_x");
            if (variable_struct_exists(intro, "_ball_land_y")) by = variable_struct_get(intro, "_ball_land_y");
        }

        var ball_alpha = 1;
        if (variable_struct_exists(intro, "_enemy_scale_progress")){
            var scale_prog_raw = variable_struct_get(intro, "_enemy_scale_progress");
            if (is_real(scale_prog_raw)) ball_alpha = clamp(1 - clamp(scale_prog_raw, 0, 1), 0, 1);
        } else if (variable_struct_exists(intro, "enemy_scale_mult")){
            var scale_mult_raw = variable_struct_get(intro, "enemy_scale_mult");
            if (is_real(scale_mult_raw)) ball_alpha = clamp(1 - clamp(scale_mult_raw, 0, 1), 0, 1);
        }

        if (!is_undefined(ball_sprite) && sprite_exists(ball_sprite)){
            var origin_x = sprite_get_xoffset(ball_sprite);
            var origin_y = sprite_get_yoffset(ball_sprite);
            var spr_w_ball = sprite_get_width(ball_sprite);
            var spr_h_ball = sprite_get_height(ball_sprite);
            var scale_draw = ball_scale * ui_s;
            var ball_center_target_y = ball_ground_y - spr_h_ball * scale_draw * 0.5;
            if (state == "throw"){
                bx = lerp(start_x, ball_target_x, throw_progress);
                by = lerp(start_y, ball_center_target_y, throw_progress);
                var arc_h_late = __bhu(_pid, (variable_struct_exists(intro, "throw_height") && is_real(intro.throw_height)) ? intro.throw_height : 52);
                by -= sin(throw_progress * pi) * arc_h_late;
                variable_struct_set(intro, "_ball_land_x", bx);
                variable_struct_set(intro, "_ball_land_y", by);
            } else {
                if (!variable_struct_exists(intro, "_ball_land_x")){
                    variable_struct_set(intro, "_ball_land_x", ball_target_x);
                    variable_struct_set(intro, "_ball_land_y", ball_center_target_y);
                }
                if (variable_struct_exists(intro, "_ball_land_x")) bx = variable_struct_get(intro, "_ball_land_x");
                if (variable_struct_exists(intro, "_ball_land_y")) by = variable_struct_get(intro, "_ball_land_y");
            }
            var center_off_x = (spr_w_ball * 0.5 - origin_x) * scale_draw;
            var center_off_y = (spr_h_ball * 0.5 - origin_y) * scale_draw;
            var draw_x = bx - center_off_x;
            var draw_y = by - center_off_y;
            var ball_hop = max(0, ball_ground_y - (by + spr_h_ball * scale_draw * 0.5));
            var shadow_alpha = clamp((1 - ball_hop / max(1, __bhu(_pid, 48))) * ball_alpha, 0, 1);
            draw_set_color(c_black);
            draw_set_alpha(0.32 * shadow_alpha);
            var shadow_w = max(3, spr_w_ball * scale_draw * lerp(0.42, 0.68, shadow_alpha));
            var shadow_h = max(2, shadow_w * 0.22);
            draw_ellipse(ball_target_x - shadow_w * 0.5, ball_ground_y - shadow_h * 0.5, ball_target_x + shadow_w * 0.5, ball_ground_y + shadow_h * 0.5, false);
            draw_set_alpha(1);
            draw_set_color(c_white);
            draw_sprite_ext(ball_sprite, 0, draw_x, draw_y, scale_draw, scale_draw, 0, c_white, ball_alpha);
        } else {
            var radius = __bhu(_pid, 6);
            var prev_alpha = draw_get_alpha();
            draw_set_alpha(ball_alpha);
            draw_set_color(c_white);
            draw_circle(bx, ball_ground_y - radius, radius, false);
            draw_set_color(c_white);
            draw_set_alpha(prev_alpha);
        }
    }
}

// Begin the victory slide animation after trainer defeat; schedules end states.
function __battle_trainer_start_victory_slide(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;

    var mode = "wild";
    if (variable_struct_exists(_B, "_battle_mode")) mode = string_lower(string(variable_struct_get(_B, "_battle_mode")));
    if (mode != "trainer") return;

    if (variable_struct_exists(_B, "_trainer_victory_slide") && is_struct(variable_struct_get(_B, "_trainer_victory_slide"))) return;

    var info = (variable_struct_exists(_B, "_trainer_info") ? variable_struct_get(_B, "_trainer_info") : undefined);
    if (!is_struct(info)) return;

    var sprite_ref = (variable_struct_exists(info, "sprite") ? info.sprite : -1);
    var subimg_ref = (variable_struct_exists(info, "subimg") ? info.subimg : 0);
    var scale_ref = (variable_struct_exists(info, "scale") && is_real(info.scale)) ? real(info.scale) : 1;
    var slide_dur = 320;
    if (variable_struct_exists(info, "slide_return_duration") && is_real(info.slide_return_duration)) slide_dur = max(120, real(info.slide_return_duration));

    var state = {
        state: "enter",
        start_ms: current_time,
        enter_duration: slide_dur,
        start_logical_x: 280,
        target_logical_x: 165,
        target_logical_y: 40,
        sprite: sprite_ref,
        subimg: subimg_ref,
        scale: scale_ref,
        progress: 0
    };

    try { variable_struct_set(_B, "_trainer_victory_slide", state); } catch (e_set) {}
}

// Update loop for the trainer victory animation (slide-out, rewards).
function __battle_trainer_victory_update(_pid, _B){
    if (!is_struct(_B)) _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_victory_slide")) return;

    var slide = variable_struct_get(_B, "_trainer_victory_slide");
    if (!is_struct(slide)) return;

    var now = current_time;
    if (!variable_struct_exists(slide, "start_ms") || !is_real(slide.start_ms)) variable_struct_set(slide, "start_ms", now);
    var start_ms = real(variable_struct_get(slide, "start_ms"));
    var dur = 320;
    if (variable_struct_exists(slide, "enter_duration") && is_real(slide.enter_duration)) dur = max(60, real(slide.enter_duration));

    var progress = clamp((now - start_ms) / max(1, dur), 0, 1);
    variable_struct_set(slide, "progress", progress);
    if (progress >= 1){
        variable_struct_set(slide, "progress", 1);
        variable_struct_set(slide, "state", "hold");
        if (!variable_struct_exists(slide, "hold_logical_x")) variable_struct_set(slide, "hold_logical_x", (variable_struct_exists(slide, "target_logical_x") ? slide.target_logical_x : 165));
    }
}

// Draw elements for the victory slide (trainer leaving, UI overlays).
function __battle_trainer_draw_victory(_pid, _B){
    if (!is_struct(_B)) _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_victory_slide")) return;

    var slide = variable_struct_get(_B, "_trainer_victory_slide");
    if (!is_struct(slide)) return;

    var ui_s = 1;
    if (variable_struct_exists(_B, "_ui")){
        var __ui = variable_struct_get(_B, "_ui");
        if (is_struct(__ui) && variable_struct_exists(__ui, "s")) ui_s = __ui.s;
    }

    var target_log_x = 165;
    if (variable_struct_exists(slide, "target_logical_x") && is_real(slide.target_logical_x)) target_log_x = real(slide.target_logical_x);
    var target_log_y = 40;
    if (variable_struct_exists(slide, "target_logical_y") && is_real(slide.target_logical_y)) target_log_y = real(slide.target_logical_y);
    var start_log_x = 280;
    if (variable_struct_exists(slide, "start_logical_x") && is_real(slide.start_logical_x)) start_log_x = real(slide.start_logical_x);

    var progress = 0;
    if (variable_struct_exists(slide, "progress") && is_real(slide.progress)) progress = clamp(real(slide.progress), 0, 1);
    var state = string(variable_struct_exists(slide, "state") ? slide.state : "enter");

    var ease = 1 - power(1 - progress, 2);
    var cx_log = lerp(start_log_x, target_log_x, ease);
    if (state == "hold" && variable_struct_exists(slide, "hold_logical_x") && is_real(slide.hold_logical_x)) cx_log = real(slide.hold_logical_x);

    var cx = __bxu(_pid, cx_log);
    var cy = __byu(_pid, target_log_y);

    var sprite_use = -1;
    if (variable_struct_exists(slide, "sprite")) sprite_use = slide.sprite;
    if (!sprite_exists(sprite_use)){
        var info = (variable_struct_exists(_B, "_trainer_info") ? variable_struct_get(_B, "_trainer_info") : undefined);
        if (is_struct(info) && variable_struct_exists(info, "sprite") && sprite_exists(info.sprite)) sprite_use = info.sprite;
        else if (sprite_exists(spr_PokemonEmeraldTrainers)) sprite_use = spr_PokemonEmeraldTrainers;
        else sprite_use = -1;
    }
    if (sprite_use == -1) return;

    var subimg = 0;
    if (variable_struct_exists(slide, "subimg") && is_real(slide.subimg)) subimg = real(slide.subimg);
    else {
        var info_sub = (variable_struct_exists(_B, "_trainer_info") ? variable_struct_get(_B, "_trainer_info") : undefined);
        if (is_struct(info_sub) && variable_struct_exists(info_sub, "subimg") && is_real(info_sub.subimg)) subimg = real(info_sub.subimg);
    }
    var frames = max(1, sprite_get_number(sprite_use));
    subimg = ((floor(subimg) % frames) + frames) % frames;

    var scale = 1;
    if (variable_struct_exists(slide, "scale") && is_real(slide.scale)) scale = real(slide.scale);
    else {
        var info_scale = (variable_struct_exists(_B, "_trainer_info") ? variable_struct_get(_B, "_trainer_info") : undefined);
        if (is_struct(info_scale) && variable_struct_exists(info_scale, "scale") && is_real(info_scale.scale)) scale = real(info_scale.scale);
    }

    var spr_w = sprite_get_width(sprite_use);
    var spr_h = sprite_get_height(sprite_use);
    var draw_x = cx - (spr_w * scale * ui_s) * 0.5;
    var draw_y = cy - (spr_h * scale * ui_s) * 0.5;

    draw_sprite_ext(sprite_use, subimg, draw_x, draw_y, scale * ui_s, scale * ui_s, 0, c_white, 1);
}

try {
    global.__battle_trainer_start_victory_slide = __battle_trainer_start_victory_slide;
    global.__battle_trainer_victory_update = __battle_trainer_victory_update;
    global.__battle_trainer_draw_victory = __battle_trainer_draw_victory;
} catch (e_global_assign) {}
