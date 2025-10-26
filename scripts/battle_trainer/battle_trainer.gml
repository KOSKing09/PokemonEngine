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
    var first_mon = undefined;
    var slide_out_duration = 260;
    var enemy_reveal_duration = 280;

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

        var party_fields = ["party", "mons", "team", "enemy_party"];
        for (var pf = 0; pf < array_length(party_fields); ++pf){
            var fname = party_fields[pf];
            if (variable_struct_exists(_trainer_data, fname) && is_array(variable_struct_get(_trainer_data, fname))){
                enemy_party_source = variable_struct_get(_trainer_data, fname);
                break;
            }
        }
    }

    var enemy_party = [];
    if (is_array(enemy_party_source)){
        for (var ei = 0; ei < array_length(enemy_party_source); ++ei){
            enemy_party[array_length(enemy_party)] = enemy_party_source[ei];
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

    var opts = { type:"trainer" };
    if (array_length(enemy_party) > 0) opts.enemy_party = enemy_party;
    if (is_struct(first_mon)) opts.enemy_mon = first_mon;
    if (!is_undefined(enemy_level)) opts.enemy_level = max(1, floor(enemy_level));
    if (!is_undefined(enemy_species)) opts.enemy_species = enemy_species;
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

    battle_open(_pid, open_level, opts);

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;

    if (!sprite_exists(trainer_sprite)){
        if (sprite_exists(spr_PokemonEmeraldTrainers)) trainer_sprite = spr_PokemonEmeraldTrainers;
        else trainer_sprite = -1;
    }
    var _actors = undefined;
    if (variable_struct_exists(_B, "actor")) _actors = variable_struct_get(_B, "actor");
    var enemy_actor = undefined;
    if (is_array(_actors) && array_length(_actors) > 1) enemy_actor = _actors[1];
    if (is_struct(enemy_actor)){
        try { variable_struct_set(enemy_actor, "actor_index", 1); } catch (e_ai) {}
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
        slide_return_duration: slide_out_duration
    };
    try { variable_struct_set(_B, "_trainer_info", trainer_info); } catch (e_info) {}

    battle_intro_set_handlers(_pid, __battle_trainer_intro_update, __battle_trainer_intro_draw);
}

function __battle_trainer_intro_show_dialog(_pid, _text){
    var txt = string(_text);
    if (string_length(txt) <= 0) return;
    try {
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, txt);
        else if (!is_undefined(dialog2p_enqueue)) dialog2p_enqueue(_pid, txt);
    } catch (e_show) {}
}

function __battle_trainer_intro_dialog_open(_pid){
    try {
        if (!is_undefined(dialog2p_is_open)) return dialog2p_is_open(_pid);
    } catch (e_is) {}
    return false;
}

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
            __battle_trainer_intro_show_dialog(_pid, string(intro.trainer_name) + " would like to battle!");
            variable_struct_set(intro, "_dialog1_shown", true);
        }
        variable_struct_set(intro, "state", "wait_dialog1");
    } else if (state == "wait_dialog1"){
        variable_struct_set(intro, "hide_enemy_mon", true);
        if (!__battle_trainer_intro_dialog_open(_pid)) variable_struct_set(intro, "state", "throw_prep");
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
            __battle_trainer_intro_show_dialog(_pid, "Go " + string(intro.enemy_mon_name) + "!");
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
        if (!__battle_trainer_intro_dialog_open(_pid)){
            if (!(variable_struct_exists(intro, "_player_dialog_shown") && intro._player_dialog_shown)){
                __battle_trainer_intro_show_dialog(_pid, "Go " + string(intro.player_mon_name) + "!");
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
        if (!__battle_trainer_intro_dialog_open(_pid)){
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
        var scale_ease = 1 - power(1 - scale_prog, 2);
        variable_struct_set(intro, "_enemy_scale_progress", scale_prog);
        variable_struct_set(intro, "enemy_scale_mult", clamp(scale_ease, 0, 1.2));
    } else {
        if (state_now == "dialog1" || state_now == "wait_dialog1" || state_now == "throw_prep" || state_now == "throw"){
            variable_struct_set(intro, "enemy_scale_mult", 0);
        }
    }
}

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

    var enemy_actor_draw = undefined;
    if (variable_struct_exists(_B, "actor")){
        var __actors_draw = variable_struct_get(_B, "actor");
        if (is_array(__actors_draw) && array_length(__actors_draw) > 1) enemy_actor_draw = __actors_draw[1];
    }

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
    var ball_target_y = enemy_center_y + ((enemy_sprite_h * ui_s) * 0.15);
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
        if (variable_struct_exists(intro, "enemy_scale_mult")){
            var scale_mult_raw = variable_struct_get(intro, "enemy_scale_mult");
            if (is_real(scale_mult_raw)) ball_alpha = clamp(1 - clamp(scale_mult_raw, 0, 1), 0, 1);
        }

        if (!is_undefined(ball_sprite) && sprite_exists(ball_sprite)){
            var origin_x = sprite_get_xoffset(ball_sprite);
            var origin_y = sprite_get_yoffset(ball_sprite);
            var spr_w_ball = sprite_get_width(ball_sprite);
            var spr_h_ball = sprite_get_height(ball_sprite);
            var scale_draw = ball_scale * ui_s;
            var center_off_x = (spr_w_ball * 0.5 - origin_x) * scale_draw;
            var center_off_y = (spr_h_ball * 0.5 - origin_y) * scale_draw;
            var draw_x = bx - center_off_x;
            var draw_y = by - center_off_y;
            draw_sprite_ext(ball_sprite, 0, draw_x, draw_y, scale_draw, scale_draw, 0, c_white, ball_alpha);
        } else {
            var radius = __bhu(_pid, 6);
            var prev_alpha = draw_get_alpha();
            draw_set_alpha(ball_alpha);
            draw_set_color(c_white);
            draw_circle(bx, by, radius, false);
            draw_set_color(c_white);
            draw_set_alpha(prev_alpha);
        }
    }
}

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
