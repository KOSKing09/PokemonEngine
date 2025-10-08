// [Battle] PokemonBattleSystem — Build v0.1.34 (basic turn engine)
// Updated 2025-10-08
// - NEW: Turn engine (player/enemy actions resolved by Speed)
// - NEW: Accuracy, damage, crit, variance (with scr_* move data if present; sane fallbacks)
// - NEW: Faint handling & simple win/lose flow (uses dialog; closes on victory/defeat)
// - Keeps: wrap ellipsis, switch-in midpoint apply, cry-trigger grow, PID-aware input, no built-in `id` collisions
// -----------------------------------------------------------------------------
// CALLS you’ll use in objects:
//   battle_open(pid, wild_level);      // e.g., battle_open(0, irandom_range(5,18));
//   battle_update(pid);                // Step Event
//   battle_draw_gui(pid);              // Draw GUI Event
//   battle_close(pid);                 // when done
//   battle_switch_to(pid, party_index);// switch active mon with visuals (midpoint swap)
// -----------------------------------------------------------------------------

// ===== Slot helpers (per-player battle state) =====
function __battle_ensure_slot(_pid){
    if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) global.sys_battles = [];
    if (array_length(global.sys_battles) <= _pid) array_resize(global.sys_battles, _pid + 1);
    var _B = global.sys_battles[_pid];
    if (!is_struct(_B)) { _B = { sys_open:false }; global.sys_battles[_pid] = _B; }
    return _B;
}
function battle_is_open(_pid){
    var _B = __battle_ensure_slot(_pid);
    return (_B.sys_open == true);
}

// ===== Open / Close =====
function battle_open(_a0, _a1){
    var _pid = 0, _wildLevel = 5;
    if (argument_count >= 2){ _pid = max(0, real(_a0)); _wildLevel = max(1, real(_a1)); }
    else if (argument_count == 1){ _pid = 0; _wildLevel = max(1, real(_a0)); }
    var _caller = noone;
    if (!is_undefined(player_by_pid)) {
        _caller = player_by_pid(_pid);
        if (_caller == noone) _caller = noone;
    }

    var _B = __battle_ensure_slot(_pid);
    if (_B.sys_open) return;

    _B.sys_open = true;
    _B.phase    = "transition_in";
    _B.turn     = 0;
    _B.result   = "ongoing";
    _B.sys_rng  = random_get_seed();

    _B.sys_ui   = { menu:"root", selX:0, selY:0, msg_list:ds_list_create() };
    _B.sys_anim = { active:[
        {anim_id:"idle",timer:0,duration:999999,offX:0,offY:0,scale:1},
        {anim_id:"idle",timer:0,duration:999999,offX:0,offY:0,scale:1}
    ]};
    _B.phase_start_ms = current_time;
    _B.phase_durs = { transition: 300, enemy: 400, call: 700, player: 400, switch_in: 600 };
    _B._intro_completed = false;

    // Cry/switch state & turn queue
    _B._cry_played_enemy = false;
    _B._cry_played_player = false;
    _B._cry_play_start_ms_enemy = undefined;
    _B._cry_play_start_ms_player = undefined;
    _B._switch_target_idx = undefined;
    _B._switch_opts = undefined;
    _B._switch_applied = false;
    _B.phase_holds = { call: 3000 };
    _B._pending_close = false;

    // Turn queue container (filled when a move is chosen)
    _B.turn_queue = undefined;
    _B.turn_i = 0;
    _B.turn_action_player = undefined; // {slot, move_id}
    _B.turn_action_enemy  = undefined; // {slot, move_id}

    _B.theme = {
        col_bg:       make_color_rgb(184,224,200),
        col_outline:  make_color_rgb(72,88,80),
        col_panel:    make_color_rgb(208,232,224),
        col_hp_green: make_color_rgb(120,216,88),
        col_hp_yell:  make_color_rgb(248,208,56),
        col_hp_red:   make_color_rgb(232,72,56),
        col_text:     c_white
    };

    // Player actor from party
    var _P = party_ensure(_pid);
    var _mons = _P.mons;
    var _first = 0;
    for (var _i=0; _i<array_length(_mons); ++_i){
        var _m = _mons[_i];
        if (!is_undefined(_m) && is_struct(_m) && variable_struct_exists(_m,"hp") && _m.hp > 0){ _first = _i; break; }
    }
    var _pm = _mons[_first];

    _B.actor = [];
    _B.actor[0] = __battle_actor_from_party_mon(_pm);

    // Wild actor (1..901 only)
    var _sp = irandom_range(1, 901);
    _B.actor[1] = __battle_actor_from_species_level(_sp, _wildLevel);

    _B.caller = _caller;
    if (_B.caller != noone && instance_exists(_B.caller) && variable_instance_exists(_B.caller, "battleAnim") && sprite_exists(_B.caller.battleAnim)){
        _B.caller_battleAnim = _B.caller.battleAnim;
    } else if (variable_global_exists("battleAnim") && sprite_exists(battleAnim)){
        _B.caller_battleAnim = battleAnim;
    } else {
        _B.caller_battleAnim = undefined;
    }

    if (!is_undefined(dialog2p_open_text)){
        var dlg_txt = "A wild " + string(_B.actor[1].name) + " has appeared!\n\nGo. " + string(_B.actor[0].name) + "!";
        dialog2p_open_text(_pid, dlg_txt);
        _B._dlg_active = true;
        _B._dlg_page_last = -1;
    } else {
        _B._dlg_active = false;
        _B._dlg_page_last = -1;
    }

    __battle_apply_party_moves(_B.actor[0]);   // use party's current moves/PP
    __battle_ensure_moves_from_levelup(_B.actor[1]); // wild

    global.sys_battles[_pid] = _B;
}
function battle_close(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (is_struct(_B.sys_ui) && variable_struct_exists(_B.sys_ui, "msg_list")){
        if (ds_exists(_B.sys_ui.msg_list, ds_type_list)){
            ds_list_destroy(_B.sys_ui.msg_list);
        }
    }
    _B.sys_open = false;
}

// ===== Update / Draw =====
function battle_update(_pid){
    if (!battle_is_open(_pid)) return;
    var _B = __battle_ensure_slot(_pid);

    // Detect phase entry and run on-enter actions once
    var _curr_phase = (variable_struct_exists(_B, "phase") ? string(_B.phase) : "");
    if (!variable_struct_exists(_B, "_last_phase") || string(_B._last_phase) != _curr_phase){
        if (!is_undefined(__battle_on_phase_enter)) __battle_on_phase_enter(_pid, _curr_phase);
        _B._last_phase = _curr_phase;
    }

    var dlg_open = (is_undefined(dialog2p_is_open) ? false : dialog2p_is_open(_pid));
    if (dlg_open){
        if (!is_undefined(dialog2p_update)) dialog2p_update(_pid);
        var d = global.DIALOG2P[_pid];
        var page = (is_struct(d) ? d.page_idx : 0);

        if (!variable_struct_exists(_B, "_dlg_page_last")) _B._dlg_page_last = -1;
        if (page != _B._dlg_page_last){
            var now = current_time;
            if (!variable_struct_exists(_B, "_intro_completed") || !_B._intro_completed){
                if (page == 0){
                    if (string(_B.phase) == "transition_in"){
                        _B.phase = "intro_enemy"; _B.phase_start_ms = now;
                    }
                } else if (page == 1){
                    _B.phase = "intro_call"; _B.phase_start_ms = now;
                }
            }
            _B._dlg_page_last = page;
        }

        var now2 = current_time;
        if (string(_B.phase) == "intro_enemy"){
            var dur_e = _B.phase_durs.enemy;
            var elapsed_e = now2 - (variable_struct_exists(_B,"phase_start_ms") ? _B.phase_start_ms : now2);
            _B.phase_progress = max(0, min(1, elapsed_e / max(1, dur_e)));
        } else if (string(_B.phase) == "intro_call"){
            var dur_c = _B.phase_durs.call;
            var elapsed_c = now2 - (variable_struct_exists(_B,"phase_start_ms") ? _B.phase_start_ms : now2);
            _B.phase_progress = max(0, min(1, elapsed_c / max(1, dur_c)));
        } else if (string(_B.phase) == "intro_player"){
            var dur_p = _B.phase_durs.player;
            var elapsed_p = now2 - (variable_struct_exists(_B,"phase_start_ms") ? _B.phase_start_ms : now2);
            _B.phase_progress = max(0, min(1, elapsed_p / max(1, dur_p)));
        }
        if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
        _B._dlg_active = true;
        return;
    }

    // If a dialog just closed
    if (variable_struct_exists(_B, "_dlg_active") && _B._dlg_active){
        var now3 = current_time;
        _B._dlg_active = false;
        _B._dlg_page_last = -1;
        if (_B.phase == "intro_call"){
            _B.phase = "intro_player"; _B.phase_start_ms = now3;
        } else if (_B._pending_close){
            _B._pending_close = false; battle_close(_pid); return;
        }
        // don't reset menu during turn resolution
        if (string(_B.phase) == "command"){
            _B.sys_ui.menu = "root";
            _B.sys_ui.selX = 0; _B.sys_ui.selY = 0;
        }
    }

    // Phase timing (intros + switch)
    if (string(_B.phase) == "transition_in" || string(_B.phase) == "intro_enemy" || string(_B.phase) == "intro_call" || string(_B.phase) == "intro_player" || string(_B.phase) == "switch_in"){
        var now4 = current_time;
        var stage = string(_B.phase);
        var start = (variable_struct_exists(_B,"phase_start_ms") ? _B.phase_start_ms : now4);
        if (stage == "transition_in"){
            var dur = _B.phase_durs.transition;
            var elapsed = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed / max(1,dur)));
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed >= dur){ _B.phase = "intro_enemy"; _B.phase_start_ms = now4; } else return;
        }
        if (stage == "intro_enemy"){
            var dur2 = _B.phase_durs.enemy;
            var elapsed2 = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed2 / max(1,dur2)));
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed2 >= dur2){ _B.phase = "intro_call"; _B.phase_start_ms = now4; } else return;
        } else if (stage == "intro_call"){
            var dur3 = _B.phase_durs.call;
            var hold_ms = 0;
            if (variable_struct_exists(_B, "phase_holds") && variable_struct_exists(_B.phase_holds, "call")) hold_ms = max(0, real(_B.phase_holds.call));
            var elapsed3 = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed3 / max(1,dur3)));
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed3 >= dur3 + hold_ms){ _B.phase = "intro_player"; _B.phase_start_ms = now4; } else return;
        } else if (stage == "intro_player"){
            var dur4 = _B.phase_durs.player;
            var elapsed4 = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed4 / max(1,dur4)));
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed4 >= dur4){ _B.phase = "command"; _B._intro_completed = true; } else return;
        } else if (stage == "switch_in"){
            var dur5 = (_B.phase_durs.switch_in || 400);
            var elapsed5 = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed5 / max(1,dur5)));
            if (_B.phase_progress >= 0.5 && (!variable_struct_exists(_B, "_switch_applied") || !_B._switch_applied)){
                var idx = (variable_struct_exists(_B, "_switch_target_idx") ? _B._switch_target_idx : undefined);
                var opts = (variable_struct_exists(_B, "_switch_opts") ? _B._switch_opts : {});
                var auto_apply = !(variable_struct_exists(opts, "auto_apply") && opts.auto_apply == false);
                if (auto_apply && !is_undefined(party_ensure) && !is_undefined(idx) && is_real(idx)){
                    var P = party_ensure(_pid);
                    if (is_array(P.mons) && idx >= 0 && idx < array_length(P.mons)){
                        _B.actor[0] = __battle_actor_from_party_mon(P.mons[idx]);
                    }
                }
                _B._switch_applied = true;
            }
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed5 >= dur5){ _B.phase = "command"; } else return;
        }
        if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
    }

    // Turn resolution phase
    if (string(_B.phase) == "turn"){
        __battle_step_turn_if_ready(_pid);
        return;
    }

    // Command input
    __battle_process_input(_pid);
}

function battle_draw_gui(_pid){
    var _rect = __battle_view_rect_for_pid(_pid);
    if (is_array(_rect) && array_length(_rect) >= 4) {
        battle_draw_gui_rect(_pid, _rect[0], _rect[1], _rect[2], _rect[3]);
    }
}

function battle_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!battle_is_open(_pid)) return;
    var _B = __battle_ensure_slot(_pid);

    var _S  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _OX = _rx + (_rw - 240 * _S) div 2;
    var _OY = _ry + (_rh - 160 * _S) div 2;

    __bui_begin(_pid, _OX, _OY, 240*_S, 160*_S);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    draw_set_color(_B.theme.col_bg);
    draw_rectangle(__bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240), __byu(_pid,160), false);

    __battle_draw_battlers(_pid, _B);

    __battle_enemy_box_rect(_pid, 16,16,112,40, _B.actor[1]);
    __battle_player_box_rect(_pid,112,104,128,48, _B.actor[0]);
    __battle_cmd_box_rect(_pid,   8,136,224,24,   _B.sys_ui.selX, _B.sys_ui.selY);

    if (string(_B.phase) == "transition_in"){
        var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        var alpha = 1 - max(0, min(1, p));
        draw_set_color(c_black);
        draw_set_alpha(alpha);
        draw_rectangle(__bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240), __byu(_pid,160), false);
        draw_set_alpha(1);
    }

    __bui_end(_pid);
}

// ===== Input (PID-aware; keyboard fallback) =====
function __battle_pressed(_pid, _name){
    if (!is_undefined(controls_pressed)){
        var aliases, i;

        if (_name=="Left"){
            aliases = ["MoveLeft","Left","UILeft","DPadLeft"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }
        if (_name=="Right"){
            aliases = ["MoveRight","Right","UIRight","DPadRight"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }
        if (_name=="Up"){
            aliases = ["MoveUp","Up","UIUp","DPadUp"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }
        if (_name=="Down"){
            aliases = ["MoveDown","Down","UIDown","DPadDown"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }

        if (_name=="A"){
            aliases = ["A","Confirm","Accept","Interact","Select","ButtonA"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }
        if (_name=="B"){
            aliases = ["B","Cancel","Back","Pause","ButtonB"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }
    }

    if (_name=="Left")  return keyboard_check_pressed(vk_left);
    if (_name=="Right") return keyboard_check_pressed(vk_right);
    if (_name=="Up")    return keyboard_check_pressed(vk_up);
    if (_name=="Down")  return keyboard_check_pressed(vk_down);

    if (_name=="A") return (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("Z")));
    if (_name=="B") return (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace) || keyboard_check_pressed(ord("X")));

    return false;
}
function __battle_process_input(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (string(_B.phase) != "command") return;

    var _l = __battle_pressed(_pid,"Left");
    var _r = __battle_pressed(_pid,"Right");
    var _u = __battle_pressed(_pid,"Up");
    var _d = __battle_pressed(_pid,"Down");
    var _a = __battle_pressed(_pid,"A");
    var _b = __battle_pressed(_pid,"B");

    if (_l) _B.sys_ui.selX = max(0, _B.sys_ui.selX - 1);
    if (_r) _B.sys_ui.selX = min(1, _B.sys_ui.selX + 1);
    if (_u) _B.sys_ui.selY = max(0, _B.sys_ui.selY - 1);
    if (_d) _B.sys_ui.selY = min(1, _B.sys_ui.selY + 1);

    var menu = string(_B.sys_ui.menu);
    var idx = _B.sys_ui.selX + _B.sys_ui.selY * 2;

    if (_b){
        if (menu == "fight"){
            _B.sys_ui.menu = "root";
            _B.sys_ui.selX = 0; _B.sys_ui.selY = 0;
        }
    }

    if (_a){
        if (menu == "root"){
            if (idx == 0){
                _B.sys_ui.menu = "fight";
                _B.sys_ui.selX = 0; _B.sys_ui.selY = 0;
            }
            else if (idx == 1){
                __battle_stub_dialog(_pid, "Your bag isn't hooked up yet.\n(TODO: open bag UI)");
            }
            else if (idx == 2){
                __battle_stub_dialog(_pid, "You checked your party.\n(TODO: switch Pokémon)");
            }
            else if (idx == 3){
                __battle_try_escape(_pid);
            }
        }
        else if (menu == "fight"){
            var move_idx = idx;
            var A = _B.actor[0];
            var mv = A.moves[move_idx];
            var pp = A.pps[move_idx];

            if (!is_real(mv) || mv < 0){
                __battle_stub_dialog(_pid, "No move registered there.\n(Try another slot.)");
            } else if (pp <= 0){
                __battle_stub_dialog(_pid, "There's no PP left for that move!\n(TODO: implement Struggle.)");
            } else {
                // Queue the player's choice and kick off the turn
                _B.turn_action_player = { slot: move_idx, move_id: mv };
                _B.turn_action_enemy  = __battle_enemy_choose_action(_pid); // {slot, move_id} or undefined
                _B.turn_queue = __battle_build_turn_actions(_pid);
                _B.turn_i = 0;
                _B.phase = "turn";
            }
        }
    }
}

// ===== Turn engine =====
function __battle_build_turn_actions(_pid){
    var _B = __battle_ensure_slot(_pid);
    var actions = [];

    var actP = _B.turn_action_player; // struct or undefined
    var actE = _B.turn_action_enemy;

    // Default targets: single-target to the opposite side
    if (is_struct(actP)){ actP.actor_index = 0; actP.target_index = 1; }
    if (is_struct(actE)){ actE.actor_index = 1; actE.target_index = 0; }

    // Determine order by Speed (tie-break: random)
    var spP = __battle_stat_get(_B.actor[0], "spd");
    var spE = __battle_stat_get(_B.actor[1], "spd");
    var firstEnemy = (spE > spP) || (spE == spP && choose(true,false));

    if (is_struct(actP) && is_struct(actE)){
        if (firstEnemy){ actions[0] = actE; actions[1] = actP; }
        else           { actions[0] = actP; actions[1] = actE; }
    } else if (is_struct(actP)){
        actions[0] = actP;
    } else if (is_struct(actE)){
        actions[0] = actE;
    }

    return actions;
}
function __battle_step_turn_if_ready(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;

    // If dialog is open, wait
    if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)) return;

    // Nothing queued? return to command
    if (!is_array(_B.turn_queue) || array_length(_B.turn_queue) == 0){
        _B.phase = "command";
        _B.sys_ui.menu = "root";
        return;
    }

    // All actions processed?
    if (_B.turn_i >= array_length(_B.turn_queue)){
        // After the turn, check win/lose
        var A0 = _B.actor[0];
        var A1 = _B.actor[1];

        if (A1.hp_now <= 0){
            var msg = "The wild " + string(A1.name) + " fainted!\nYou won!";
            __battle_stub_dialog(_pid, msg);
            _B.result = "win";
            _B._pending_close = true;
            _B.phase = "command"; // phase doesn't matter; dialog-close will end battle
            return;
        }

        if (A0.hp_now <= 0){
            // Try to find another alive mon in party
            var idxNext = __party_find_next_alive(_pid);
            if (idxNext >= 0){
                __battle_stub_dialog(_pid, string(A0.name) + " fainted!\n(TODO) Switch to another Pokémon.");
                // You can call battle_switch_to here automatically if desired:
                // battle_switch_to(_pid, idxNext, {});
            } else {
                __battle_stub_dialog(_pid, string(A0.name) + " fainted!\nYou blacked out...");
                _B.result = "lose";
                _B._pending_close = true;
            }
            _B.phase = "command";
            return;
        }

        // Neither side fainted: back to command
        _B.phase = "command";
        _B.sys_ui.menu = "root";
        return;
    }

    // Skip actions by fainted actors
    var step = _B.turn_queue[_B.turn_i];
    if (!is_struct(step)){ _B.turn_i += 1; return; }

    var actor_idx  = step.actor_index;
    var target_idx = step.target_index;

    if (actor_idx < 0 || actor_idx > 1 || target_idx < 0 || target_idx > 1){
        _B.turn_i += 1; return;
    }

    var A = _B.actor[actor_idx];
    var D = _B.actor[target_idx];

    if (!is_struct(A) || !is_struct(D)){
        _B.turn_i += 1; return;
    }

    // If acting Pokémon fainted already, skip
    if (A.hp_now <= 0){ _B.turn_i += 1; __battle_step_turn_if_ready(_pid); return; }

    // Perform the action -> returns a dialog string
    var out_msg = __battle_perform_action(_pid, step);
    if (string_length(out_msg) <= 0){
        // No text? move on silently
        _B.turn_i += 1;
        __battle_step_turn_if_ready(_pid);
        return;
    }

    // Show the message; after dialog closes we'll continue with the next step
    __battle_stub_dialog(_pid, out_msg);
    _B.turn_i += 1;
}
function __battle_perform_action(_pid, _step){
    var _B = __battle_ensure_slot(_pid);
    var A = _B.actor[_step.actor_index];
    var D = _B.actor[_step.target_index];

    var move_slot = _step.slot;
    var move_id   = _step.move_id;

    // Safety: re-read PP from actor (the player preview might be stale)
    var pp = (is_array(A.pps) && move_slot >= 0 && move_slot < array_length(A.pps)) ? A.pps[move_slot] : 0;
    if (pp <= 0){
        return string(A.name) + " has no PP left!\n(TODO) Struggle.";
    }

    // Decrement PP up front
    A.pps[move_slot] = max(0, pp - 1);

    var mv_name = __battle_move_name(move_id);
    var acc     = __battle_move_accuracy(move_id); // 100 default
    var hit     = (irandom(99) < clamp(floor(acc), 0, 100));

    if (!hit){
        return string(A.name) + " used " + mv_name + "!\nBut it missed!";
    }

    var mv_power   = __battle_move_power(move_id); // default 40
    var dmg        = __battle_calc_damage(A, D, move_id, mv_power);

    // Apply damage and build message
    var before = D.hp_now;
    __battle_apply_damage(_pid, _step.target_index, dmg);
    var after  = D.hp_now;

    var extra  = "";
    if (dmg <= 0) extra = "\nIt had no effect.";
    else {
        // optional: crit text if __battle_last_crit flag is set
        if (variable_struct_exists(_B, "_last_crit") && _B._last_crit == true){
            extra += "\nA critical hit!";
            _B._last_crit = false;
        }
    }
    if (after <= 0) extra += "\n" + string(D.name) + " fainted!";

    return string(A.name) + " used " + mv_name + "!" + extra;
}
function __battle_enemy_choose_action(_pid){
    var _B = __battle_ensure_slot(_pid);
    var A = _B.actor[1];
    if (!is_struct(A)) return undefined;

    // pick any slot that has a valid move and PP
    var choices = [];
    for (var i=0;i<4;++i){
        var mv = A.moves[i];
        var pp = A.pps[i];
        if (is_real(mv) && mv >= 0 && is_real(pp) && pp > 0){
            choices[array_length(choices)] = i;
        }
    }
    if (array_length(choices) == 0) return undefined;
    var slot = choices[irandom(array_length(choices)-1)];
    return { slot: slot, move_id: A.moves[slot] };
}

// ===== Helpers: menus, run, text =====
function __battle_menu_index(_selX,_selY){ return _selX + _selY*2; }
function __battle_move_name(_code){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_name_by_id)) return scr_move_name_by_id(_code);
        return "MOVE " + string(_code);
    }
    return "--";
}
function __battle_move_power(_code){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_power_by_id)){
            var p = scr_move_power_by_id(_code);
            if (is_real(p)) return max(0, real(p));
        }
    }
    return 40; // fallback
}
function __battle_move_accuracy(_code){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_accuracy_by_id)){
            var a = scr_move_accuracy_by_id(_code);
            if (is_real(a)) return clamp(real(a), 1, 100);
        }
    }
    return 100; // fallback
}
function __battle_try_escape(_pid){
    var _B = __battle_ensure_slot(_pid);
    _B.result = "escaped";
    if (!is_undefined(dialog2p_open_text)){
        dialog2p_open_text(_pid, "Got away safely!\n");
        _B._pending_close = true;
    } else {
        battle_close(_pid);
    }
}
function __battle_stub_dialog(_pid, _text){
    if (!is_undefined(dialog2p_open_text)){
        dialog2p_open_text(_pid, _text);
        var _B = __battle_ensure_slot(_pid);
        _B._dlg_active = true;
        _B._dlg_page_last = -1;
    }
}
function __battle_play_switch_in(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !_B.sys_open) return;
    _B.phase = "switch_in";
    _B.phase_start_ms = current_time;
    _B.phase_progress = 0;
}

// Phase enter hook: you can add SFX here if needed
function __battle_on_phase_enter(_pid, _phase){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    return;
}

// Check phase progress and trigger cries when movement/slide has finished.
function __battle_check_play_cries(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    var now = current_time;

    if (string(_B.phase) == "intro_enemy"){
        var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        if (p >= 1 && (!variable_struct_exists(_B, "_cry_played_enemy") || !_B._cry_played_enemy)){
            _B._cry_play_start_ms_enemy = now;
            if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_B.actor[1]) && variable_struct_exists(_B.actor[1], "mon")){
                var _aud_e = pkicons_play_cry_by_mon(_B.actor[1].mon);
                if (is_real(_aud_e) && _aud_e >= 0) { }
            }
            _B._cry_played_enemy = true;
        }
    }

    if (string(_B.phase) == "intro_player"){
        var p2 = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        if (p2 >= 1 && (!variable_struct_exists(_B, "_cry_played_player") || !_B._cry_played_player)){
            _B._cry_play_start_ms_player = now;
            if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "mon")){
                var _aud_p = pkicons_play_cry_by_mon(_B.actor[0].mon);
                if (is_real(_aud_p) && _aud_p >= 0) { }
            }
            _B._cry_played_player = true;
            _B._cry_queued_from_switch = false;
        }
    }

    if (string(_B.phase) == "switch_in"){
        var p3 = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        if (p3 >= 0.5 && (!variable_struct_exists(_B, "_cry_played_player") || !_B._cry_played_player)){
            _B._cry_play_start_ms_player = now;

            var _mon_to_play = undefined;
            if (variable_struct_exists(_B, "_cry_queued_from_switch") && _B._cry_queued_from_switch && variable_struct_exists(_B, "_switch_target_idx") && is_real(_B._switch_target_idx)){
                var _P = party_ensure(_pid);
                if (is_struct(_P) && is_array(_P.mons) && _B._switch_target_idx >= 0 && _B._switch_target_idx < array_length(_P.mons)){
                    _mon_to_play = _P.mons[_B._switch_target_idx];
                }
            }
            if (!is_struct(_mon_to_play) && is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "mon")) _mon_to_play = _B.actor[0].mon;

            if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_mon_to_play)){
                var _aud_s = pkicons_play_cry_by_mon(_mon_to_play);
                if (is_real(_aud_s) && _aud_s >= 0) { }
            }

            _B._cry_played_player = true;
            _B._cry_queued_from_switch = false;
        }
    }
}

// API: switch the player's active Pokémon to the party index with visuals
function battle_switch_to(_pid, _party_idx, _opts){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !_B.sys_open) return false;
    if (string(_B.phase) != "command") return false;

    if (is_undefined(_opts)) _opts = {};
    _B._switch_target_idx = _party_idx;
    _B._switch_opts = _opts;
    _B.phase = "switch_in";
    _B.phase_start_ms = current_time;
    _B.phase_progress = 0;
    _B._cry_played_player = false;
    _B._cry_queued_from_switch = true;
    return true;
}

// Ellipsize helper (uses current font)
function __battle_text_fit_ellipsis(_pid, _str, _max_px){
    var s = string(_str);
    if (string_width(s) <= _max_px) return s;
    var ell = "…";
    var n = string_length(s);
    while (n > 1){
        n -= 1;
        var cand = string_copy(s, 1, n) + ell;
        if (string_width(cand) <= _max_px) return cand;
    }
    return ell;
}

// ===== Actor creation =====
function __battle_actor_from_party_mon(_M){
    var _sid = -1;
    if (variable_struct_exists(_M,"id") && is_real(_M.id)) _sid = _M.id;
    else if (variable_struct_exists(_M,"species_id") && is_real(_M.species_id)) _sid = _M.species_id;

    var _nm = "???";
    if (variable_struct_exists(_M,"name") && is_string(_M.name) && string_length(_M.name) > 0) _nm = string(_M.name);
    else if (_sid > 0) _nm = scr_poke_name_by_id(_sid);

    var _hpMax = 20;
    if (variable_struct_exists(_M,"hp_max"))      _hpMax = _M.hp_max;
    else if (variable_struct_exists(_M,"maxhp"))  _hpMax = _M.maxhp;

    var _hpNow = variable_struct_exists(_M,"hp") ? _M.hp : _hpMax;

    var _lvl   = 5;
    if (variable_struct_exists(_M,"level")) _lvl = _M.level;
    else if (variable_struct_exists(_M,"lvl")) _lvl = _M.lvl;

    var _actor = {
        species : _sid,
        level   : _lvl,
        name    : _nm,
        hp_now  : _hpNow,
        hp_max  : _hpMax,
        moves   : [-1,-1,-1,-1],
        pps     : [0,0,0,0]
    };
    if (is_struct(_M)) {
        _actor.mon = _M;
        if ((!variable_struct_exists(_actor.mon, "species_id") || !is_real(_actor.mon.species_id))) {
            if (variable_struct_exists(_actor.mon, "id") && is_real(_actor.mon.id)) {
                _actor.mon.species_id = _actor.mon.id;
            } else if (variable_struct_exists(_actor.mon, "species") && is_real(_actor.mon.species)) {
                _actor.mon.species_id = _actor.mon.species;
            }
        }
    } else {
        _actor.mon = { species_id:_sid, shiny:false };
    }
    return _actor;
}
function __battle_actor_from_species_level(_sp,_lvl){
    var _nm = scr_poke_name_by_id(_sp);
    var _actor = {
        species:_sp,
        level:_lvl,
        name:_nm,
        hp_now:30,
        hp_max:30,
        moves:[-1,-1,-1,-1],
        pps:[0,0,0,0]
    };
    _actor.mon = { species_id:_sp, shiny:false };
    return _actor;
}

// ===== Move population =====
function __battle_ensure_moves_from_levelup(_A){
    for (var i=0; i<4; ++i){ _A.moves[i] = -1; _A.pps[i] = 0; }

    var cand = [];

    if (!is_undefined(scr_poke_moveset_by_id)){
        var pool = scr_poke_moveset_by_id(_A.species);

        if (is_array(pool)){
            for (var j = 0; j < array_length(pool); ++j){
                var entry = pool[j];
                var mv = -1, reqLv = -1;
                if (is_array(entry)){
                    if (array_length(entry) >= 1 && is_real(entry[0])) mv = entry[0];
                    if (array_length(entry) >= 2 && is_real(entry[1])) reqLv = entry[1];
                } else if (is_real(entry)){
                    mv = entry;
                }
                if (is_real(mv) && mv >= 0 && (reqLv < 0 || _A.level >= reqLv)){
                    cand[array_length(cand)] = mv;
                }
            }
        } else if (ds_exists(pool, ds_type_list)){
            var n = ds_list_size(pool);
            for (var k = 0; k < n; ++k){
                var entry2 = ds_list_find_value(pool, k);
                var mv2 = -1, reqLv2 = -1;
                if (is_array(entry2)){
                    if (array_length(entry2) >= 1 && is_real(entry2[0])) mv2 = entry2[0];
                    if (array_length(entry2) >= 2 && is_real(entry2[1])) reqLv2 = entry2[1];
                } else if (is_real(entry2)){
                    mv2 = entry2;
                }
                if (is_real(mv2) && mv2 >= 0 && (reqLv2 < 0 || _A.level >= reqLv2)){
                    cand[array_length(cand)] = mv2;
                }
            }
        }
    }

    var total = array_length(cand);
    if (total > 0){
        var take = min(4, total);
        for (var m = 0; m < take; ++m){
            var mvPick = cand[total - 1 - m];
            _A.moves[m] = mvPick;
            _A.pps[m]   = 10; // placeholder PP
        }
    } else {
        _A.moves[0] = 1; _A.pps[0] = 10;
    }
}
function __battle_apply_party_moves(_A){
    for (var i=0; i<4; ++i){ _A.moves[i] = -1; _A.pps[i] = 0; }

    var m = (is_struct(_A) && variable_struct_exists(_A, "mon")) ? _A.mon : undefined;
    if (!is_struct(m)) { __battle_ensure_moves_from_levelup(_A); return; }

    var got = 0;

    // CASE 1: mon.moves array
    if (variable_struct_exists(m, "moves") && is_array(m.moves)){
        var mvArr = m.moves;
        var ppArr = (variable_struct_exists(m, "pps") && is_array(m.pps)) ? m.pps : undefined;

        var cnt = min(4, array_length(mvArr));
        for (var i1 = 0; i1 < cnt; ++i1){
            var e = mvArr[i1];
            var mvCode = -1;
            var havePP = false;
            var ppVal = 0;

            if (is_real(e)){
                mvCode = e;
                if (is_array(ppArr) && i1 < array_length(ppArr) && is_real(ppArr[i1])){
                    ppVal = max(0, real(ppArr[i1])); havePP = true;
                }
            } else if (is_array(e)){
                if (array_length(e) >= 1 && is_real(e[0])) mvCode = e[0];
                if (array_length(e) >= 2 && is_real(e[1])) { ppVal = max(0, real(e[1])); havePP = true; }
            } else if (is_struct(e)){
                if (variable_struct_exists(e, "move")     && is_real(e.move))     mvCode = e.move;
                else if (variable_struct_exists(e, "move_id") && is_real(e.move_id)) mvCode = e.move_id;
                else if (variable_struct_exists(e, "id")  && is_real(e.id))       mvCode = e.id;

                if (variable_struct_exists(e, "pp")       && is_real(e.pp))       { ppVal = max(0, real(e.pp)); havePP = true; }
                else if (variable_struct_exists(e, "pp_cur") && is_real(e.pp_cur)){ ppVal = max(0, real(e.pp_cur)); havePP = true; }
                else if (variable_struct_exists(e, "pp_current") && is_real(e.pp_current)){ ppVal = max(0, real(e.pp_current)); havePP = true; }
            }

            if (is_real(mvCode) && mvCode >= 0){
                _A.moves[i1] = mvCode;
                _A.pps[i1]   = havePP ? ppVal : 10;
                got += 1;
            }
        }
    }

    // CASE 2: mon.move1..move4 (+ pp1..pp4)
    if (got == 0){
        var moved = false;
        for (var i2 = 0; i2 < 4; ++i2){
            var idx = i2 + 1;
            var mvField = "move" + string(idx);
            if (variable_struct_exists(m, mvField)){
                var mvVal = variable_struct_get(m, mvField);
                if (is_real(mvVal) && mvVal >= 0){
                    _A.moves[i2] = mvVal;
                    moved = true;

                    var ppField = "pp" + string(idx);
                    if (variable_struct_exists(m, ppField) && is_real(variable_struct_get(m, ppField))){
                        _A.pps[i2] = max(0, real(variable_struct_get(m, ppField)));
                    } else {
                        _A.pps[i2] = 10;
                    }
                }
            }
        }
        if (moved){ got = 1; }
    }

    // CASE 3: alt arrays (move_ids/known_moves + pps)
    if (got == 0){
        var mvAlt = undefined, ppAlt = undefined;
        if (variable_struct_exists(m, "move_ids") && is_array(m.move_ids)) mvAlt = m.move_ids;
        else if (variable_struct_exists(m, "known_moves") && is_array(m.known_moves)) mvAlt = m.known_moves;
        if (variable_struct_exists(m, "pps") && is_array(m.pps)) ppAlt = m.pps;

        if (is_array(mvAlt)){
            var cnt2 = min(4, array_length(mvAlt));
            for (var i3 = 0; i3 < cnt2; ++i3){
                var mvV = mvAlt[i3];
                if (is_real(mvV) && mvV >= 0){
                    _A.moves[i3] = mvV;
                    _A.pps[i3]   = (is_array(ppAlt) && i3 < array_length(ppAlt) && is_real(ppAlt[i3]))
                                   ? max(0, real(ppAlt[i3])) : 10;
                }
            }
        }
    }

    // Still nothing? seed from level-up
    var hasAny = false;
    for (var z=0; z<4; ++z){ if (is_real(_A.moves[z]) && _A.moves[z] >= 0) { hasAny = true; break; } }
    if (!hasAny) __battle_ensure_moves_from_levelup(_A);
}

// ===== Minimal stats & damage =====
function __battle_stat_get(_A, _stat){
    // Pull from mon if present, else derive from level
    var lvl = (is_struct(_A) && is_real(_A.level)) ? _A.level : 5;
    var m = (is_struct(_A) && variable_struct_exists(_A,"mon")) ? _A.mon : undefined;

    if (is_struct(m)){
        if (_stat=="atk"){
            if (variable_struct_exists(m,"atk") && is_real(m.atk)) return m.atk;
            if (variable_struct_exists(m,"attack") && is_real(m.attack)) return m.attack;
        }
        if (_stat=="def"){
            if (variable_struct_exists(m,"def") && is_real(m.def)) return m.def;
            if (variable_struct_exists(m,"defense") && is_real(m.defense)) return m.defense;
        }
        if (_stat=="spd"){
            if (variable_struct_exists(m,"spd") && is_real(m.spd)) return m.spd;
            if (variable_struct_exists(m,"speed") && is_real(m.speed)) return m.speed;
        }
    }

    // Derived baseline if no stats exist (simple + level scaling)
    if (_stat=="atk") return 10 + lvl * 2;
    if (_stat=="def") return 10 + lvl * 2;
    if (_stat=="spd") return 10 + lvl * 2;
    return 10 + lvl * 2;
}
function __battle_calc_damage(_A, _D, _move_id, _power){
    var L = (is_real(_A.level) ? _A.level : 5);
    var Atk = __battle_stat_get(_A, "atk");
    var Def = __battle_stat_get(_D, "def");

    // base formula (Pokémon-like, simplified)
    var base = floor( (((2*L/5 + 2) * _power * Atk) / max(1,Def)) / 50 ) + 2;

    // variance 0.85..1.00
    var variance = 0.85 + random(0.15);
    var dmg = floor(base * variance);

    // crit ~ 1/24
    var crit = (irandom(23) == 0);
    var critMul = crit ? 1.5 : 1.0;
    dmg = floor(dmg * critMul);

    // mark crit for message
    var _B = __battle_ensure_slot(0); // any slot; we only read flag in same pid flow
    _B._last_crit = crit;

    // clamp
    dmg = max(0, dmg);
    return dmg;
}
function __battle_apply_damage(_pid, _target_index, _dmg){
    var _B = __battle_ensure_slot(_pid);
    var T = _B.actor[_target_index];
    if (!is_struct(T)) return;
    var newhp = max(0, T.hp_now - max(0, _dmg));
    T.hp_now = newhp;

    // write back to party mon if present
    if (is_struct(T.mon)){
        if (variable_struct_exists(T.mon, "hp")) T.mon.hp = newhp;
        else if (variable_struct_exists(T.mon, "hp_now")) T.mon.hp_now = newhp;
    }
}
function __party_find_next_alive(_pid){
    if (is_undefined(party_ensure)) return -1;
    var P = party_ensure(_pid);
    if (!is_struct(P) || !is_array(P.mons)) return -1;
    for (var i=0;i<array_length(P.mons);++i){
        var m = P.mons[i];
        if (is_struct(m) && variable_struct_exists(m,"hp") && is_real(m.hp) && m.hp > 0){
            // skip if this is already the current actor
            var A0 = __battle_ensure_slot(_pid).actor[0];
            if (is_struct(A0) && variable_struct_exists(A0,"mon") && A0.mon == m) continue;
            return i;
        }
    }
    return -1;
}

// ===== Rect pipeline (PID-aware, GUI-only) =====
function __bui_begin(_pid,_rx,_ry,_rw,_rh){
    var _B = __battle_ensure_slot(_pid);
    var base_w = 240, base_h = 160;
    var sx = _rw / base_w;
    var sy = _rh / base_h;
    var s = min(sx, sy);
    var content_w = floor(base_w * s);
    var content_h = floor(base_h * s);
    var origin_x = _rx + floor((_rw - content_w) / 2);
    var origin_y = _ry + floor((_rh - content_h) / 2);
    _B._ui = { rx: origin_x, ry: origin_y, rw: content_w, rh: content_h, base_w: base_w, base_h: base_h, s: s };
}
function __bui_end(_pid){
    var _B = __battle_ensure_slot(_pid);
    _B._ui = undefined;
}
function __bxu(_pid,_xv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _xv;
    return floor(_u.rx + _xv * _u.s);
}
function __byu(_pid,_yv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _yv;
    return floor(_u.ry + _yv * _u.s);
}
function __bwu(_pid,_wv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _wv;
    return floor(_wv * _u.s);
}
function __bhu(_pid,_hv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _hv;
    return floor(_hv * _u.s);
}

// ===== Panels & HUD =====
function __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn){
    var _t  = __battle_ensure_slot(_pid).theme;
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn);
    var _bw = __bwu(_pid,_rwIn), _bh = __bhu(_pid,_rhIn);
    draw_set_color(_t.col_outline); draw_rectangle(_bx,_by,_bx+_bw,_by+_bh,false);
    draw_set_color(_t.col_panel);   draw_rectangle(_bx+1,_by+1,_bx+_bw-1,_by+_bh-1,false);
}
function __battle_enemy_box_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn,_A){
    var _t  = __battle_ensure_slot(_pid).theme;
    __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn), _bw = __bwu(_pid,_rwIn);
    draw_set_color(_t.col_text);

    var nameMax = _bw - __bwu(_pid, 48);
    var nameTxt = __battle_text_fit_ellipsis(_pid, string(_A.name), nameMax);
    draw_text(_bx+__bwu(_pid,8), _by+__bhu(_pid,6), nameTxt);

    draw_text(_bx+_bw-__bwu(_pid,29), _by+__bhu(_pid,6), "Lv"+string(_A.level));

    var _pct = max(0, min(1, _A.hp_now / max(1,_A.hp_max)));
    var _barW = _bw-__bwu(_pid,32), _barX=_bx+__bwu(_pid,8), _barY=_by+__bhu(_pid,20), _bh=__bhu(_pid,6);
    draw_set_color(c_black); draw_rectangle(_barX-1,_barY-1,_barX+_barW+1,_barY+_bh+1,false);
    var _hpcol = _t.col_hp_green; if (_pct<0.5) _hpcol=_t.col_hp_yell; if (_pct<0.2) _hpcol=_t.col_hp_red;
    draw_set_color(_hpcol); draw_rectangle(_barX,_barY,_barX+_barW*_pct,_barY+_bh,false);
}
function __battle_player_box_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn,_A){
    var _t  = __battle_ensure_slot(_pid).theme;
    __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn), _bw = __bwu(_pid,_rwIn);
    draw_set_color(_t.col_text);

    var nameMax = _bw - __bwu(_pid, 72);
    var nameTxt = __battle_text_fit_ellipsis(_pid, string(_A.name), nameMax);
    draw_text(_bx+__bwu(_pid,8), _by+__bhu(_pid,6), nameTxt);

    draw_text(_bx+_bw-__bwu(_pid,32), _by+__bhu(_pid,6), "Lv"+string(_A.level));

    var _pct = max(0, min(1, _A.hp_now / max(1,_A.hp_max)));
    var _barW = _bw-__bwu(_pid,32), _barX=_bx+__bwu(_pid,8), _barY=_by+__bhu(_pid,20), _bh=__bhu(_pid,6);
    draw_set_color(c_black); draw_rectangle(_barX-1,_barY-1,_barX+_barW+1,_barY+_bh+1,false);
    var _hpcol = _t.col_hp_green; if (_pct<0.5) _hpcol=_t.col_hp_yell; if (_pct<0.2) _hpcol=_t.col_hp_red;
    draw_set_color(_hpcol); draw_rectangle(_barX,_barY,_barX+_barW*_pct,_barY+_bh,false);
    draw_text(_bx+_bw-__bwu(_pid,64), _by+__bhu(_pid,18), string(_A.hp_now)+"/"+string(_A.hp_max));
}
function __battle_cmd_box_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn,_selX,_selY){
    var _t  = __battle_ensure_slot(_pid).theme;
    __battle_panel_rect(_pid,_rxIn,_ryIn,_rwIn,_rhIn);
    var _bx = __bxu(_pid,_rxIn), _by = __byu(_pid,_ryIn), _bw = __bwu(_pid,_rwIn), _bh = __bhu(_pid,_rhIn);

    // Dialog rendering (clamped)
    if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)){
        var d = global.DIALOG2P[_pid];
        if (is_struct(d)){
            var i0 = d.page_idx*2, i1 = i0+1;
            var l0 = (i0 < array_length(d.all_lines)) ? d.all_lines[i0] : "";
            var l1 = (i1 < array_length(d.all_lines)) ? d.all_lines[i1] : "";
            var page_str = l0 + "\n" + l1;
            var vis_str = string_copy(page_str, 1, d.char_idx);

            var vis0 = vis_str, vis1 = "";
            var npos = string_pos("\n", vis_str);
            if (npos > 0){
                vis0 = string_copy(vis_str, 1, npos - 1);
                vis1 = string_copy(vis_str, npos + 1, string_length(vis_str));
            }

            var maxW = _bw - __bwu(_pid,16);
            vis0 = __battle_text_fit_ellipsis(_pid, vis0, maxW);
            vis1 = __battle_text_fit_ellipsis(_pid, vis1, maxW);

            if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
            draw_set_color(_t.col_text);
            var _fh = (!is_undefined(__dlg_font_h) ? __dlg_font_h() : 8);
            draw_text(_bx + __bwu(_pid,8), _by + __bhu(_pid,6), vis0);
            draw_text(_bx + __bwu(_pid,8), _by + __bhu(_pid,6) + __bhu(_pid, _fh + 2), vis1);
        }
        return;
    }

    var _B = __battle_ensure_slot(_pid);

    // FIGHT submenu
    if (string(_B.sys_ui.menu) == "fight"){
        var restoreFont = -1;
        if (variable_global_exists("FNT_POKEMON")) restoreFont = global.FNT_POKEMON;
        if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);

        var A = _B.actor[0];
        var cellW = (_bw * 0.5) - __bwu(_pid,16);
        for (var i=0; i<4; ++i){
            var col = i % 2;
            var row = i div 2;
            var tx = _bx + __bwu(_pid,12) + (col * (_bw * 0.5));
            var ty = _by + __bhu(_pid,6)  + (row * (_bh * 0.5));
            var hilite = (_selX == col) && (_selY == row);

            var mv = A.moves[i];
            var pp = A.pps[i];
            var nm = __battle_move_name(mv);
            var label = nm + "  " + (is_real(pp) ? string(pp) : "0") + " PP";
            label = __battle_text_fit_ellipsis(_pid, label, cellW);

            draw_set_color(hilite ? c_yellow : _t.col_text);
            draw_text(tx, ty, label);
        }

        if (restoreFont != -1) draw_set_font(restoreFont);
        return;
    }

    // Root menu
    var labels = ["FIGHT","BAG","POK\u00E9MON","RUN"];
    var restoreFont2 = -1;
    if (variable_global_exists("FNT_POKEMON")) restoreFont2 = global.FNT_POKEMON;
    if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);

    var rootCellW = (_bw * 0.5) - __bwu(_pid,16);
    for (var j=0; j<4; ++j){
        var tx2 = _bx + __bwu(_pid,12) + ((j % 2) * (_bw * 0.5));
        var ty2 = _by + __bhu(_pid,6)  + (floor(j / 2) * (_bh * 0.5));
        var hilite2 = (_selX == (j % 2)) && (_selY == floor(j / 2));
        var lbl = __battle_text_fit_ellipsis(_pid, labels[j], rootCellW);
        draw_set_color(hilite2 ? c_yellow : _t.col_text);
        draw_text(tx2, ty2, lbl);
    }
    if (restoreFont2 != -1) draw_set_font(restoreFont2);
}

// ===== GUI Letterbox rect =====
function __battle_view_rect_for_pid(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    var _logic_w = 240;
    var _logic_h = 160;
    var _aspect  = _logic_w / _logic_h; // 1.5
    var _guiAsp  = _gw / max(1,_gh);

    var _rw, _rh, _rx, _ry;
    if (_guiAsp > _aspect) {
        _rh = _gh;
        _rw = floor(_rh * _aspect);
        _rx = (_gw - _rw) div 2;
        _ry = 0;
    } else {
        _rw = _gw;
        _rh = floor(_rw / _aspect);
        _rx = 0;
        _ry = (_gh - _rh) div 2;
    }
    return [_rx, _ry, _rw, _rh];
}

// ===== Battlers drawing =====
function __battle_draw_battlers(_pid, _B) {
    var foe_x_log = 165, foe_y_log = 40;
    var mon_x_log = 64,  mon_y_log = 112;
    var trainer_x_log = 32, trainer_y_log = 108;
    var scale_foe = 1.0, scale_us = 1.1;

    var fx = __bxu(_pid, foe_x_log);
    var fy = __byu(_pid, foe_y_log);
    var mx = __bxu(_pid, mon_x_log);
    var my = __byu(_pid, mon_y_log);
    var tx = __bxu(_pid, trainer_x_log);
    var ty = __byu(_pid, trainer_y_log);

    // Enemy
    var E = _B.actor[1];
    if (is_struct(E) && variable_struct_exists(E, "mon")) {
        if (string(_B.phase) != "transition_in") {
            var mE = E.mon;
            if (!is_undefined(pkicons_get_art96_by_mon) && !is_undefined(pkicons_get_art96_subimg_by_mon)) {
                var sprE = pkicons_get_art96_by_mon(mE);
                var subE = pkicons_get_art96_subimg_by_mon(mE, false); // front
                if (sprite_exists(sprE)) {
                    var w = sprite_get_width(sprE);
                    var h = sprite_get_height(sprE);
                    var _ui = __battle_ensure_slot(_pid)._ui;
                    var ui_s = (is_struct(_ui) && variable_struct_exists(_ui,"s")) ? _ui.s : 1;
                    var drawScaleE = scale_foe * ui_s;

                    // cry-grow
                    var cry_started_e = (variable_struct_exists(_B, "_cry_play_start_ms_enemy") && is_real(_B._cry_play_start_ms_enemy)) ? real(_B._cry_play_start_ms_enemy) : -1;
                    if (cry_started_e > 0){
                        var tnow_e = current_time;
                        var dt_e = tnow_e - cry_started_e;
                        var grow_dur = 600;
                        if (dt_e >= 0 && dt_e <= grow_dur){
                            var prog_e = dt_e / grow_dur;
                            var ease_e = sin(prog_e * pi);
                            var grow = 1 + ease_e * 0.06;
                            drawScaleE *= grow;
                        }
                    }

                    var draw_x = fx - (w*drawScaleE)/2;
                    var draw_y = fy - (h*drawScaleE)/2;
                    if (string(_B.phase) == "intro_enemy"){
                        var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
                        var start_log = 240 + 40; // 280
                        var start_px = __bxu(_pid, start_log);
                        var target_px = fx - (w*drawScaleE)/2;
                        var t = 1 - (1 - p) * (1 - p);
                        draw_x = floor(lerp(start_px, target_px, t));
                    }
                    // subtle breathing
                    var _breath_amp = 0.03;
                    var _breath_period = 2000;
                    var _bs_e = 1;
                    if (string(_B.phase) == "command"){
                        var _tms = current_time;
                        _bs_e = 1 + sin((_tms * 2 * pi) / _breath_period) * _breath_amp;
                    }
                    draw_set_color(make_color_rgb(20,20,20));
                    draw_set_alpha(0.45);
                    var shadow_w_e = floor((w * drawScaleE * _bs_e) * 0.6);
                    var shadow_h_e = max(2, floor((w * drawScaleE) * 0.12));
                    var shadow_cx_e = floor(draw_x + (w * drawScaleE * _bs_e) * 0.5);
                    var shadow_cy_e = floor(draw_y + (h * drawScaleE) * 0.5 + shadow_h_e * 0.8 + floor(15 * ui_s));
                    draw_ellipse(shadow_cx_e - shadow_w_e div 2, shadow_cy_e - shadow_h_e div 2, shadow_cx_e + shadow_w_e div 2, shadow_cy_e + shadow_h_e div 2, false);
                    draw_set_alpha(1);
                    draw_sprite_ext(sprE, subE, draw_x, draw_y, drawScaleE * _bs_e, drawScaleE, 0, c_white, 1);
                }
            }
        }
    }

    // Player
    var P = _B.actor[0];
    if (is_struct(P) && variable_struct_exists(P, "mon")) {
        var mP = P.mon;
        if (!is_undefined(pkicons_get_art96_by_mon) && !is_undefined(pkicons_get_art96_subimg_by_mon)) {
            var sprP = pkicons_get_art96_by_mon(mP);
            var subP = pkicons_get_art96_subimg_by_mon(mP, true); // back
            if (sprite_exists(sprP)) {
                var w = sprite_get_width(sprP);
                var h = sprite_get_height(sprP);
                var _ui = __battle_ensure_slot(_pid)._ui;
                var ui_s = (is_struct(_ui) && variable_struct_exists(_ui,"s")) ? _ui.s : 1;
                var drawScaleP = scale_us * ui_s;

                // cry-grow
                var cry_started_p = (variable_struct_exists(_B, "_cry_play_start_ms_player") && is_real(_B._cry_play_start_ms_player)) ? real(_B._cry_play_start_ms_player) : -1;
                if (cry_started_p > 0){
                    var tnow_p = current_time;
                    var dt_p = tnow_p - cry_started_p;
                    var grow_dur_p = 600;
                    if (dt_p >= 0 && dt_p <= grow_dur_p){
                        var prog_p = dt_p / grow_dur_p;
                        var ease_p = sin(prog_p * pi);
                        var growp = 1 + ease_p * 0.06;
                        drawScaleP *= growp;
                    }
                }

                var draw_x = mx - (w*drawScaleP)/2;
                var draw_y = my - (h*drawScaleP)/2;

                if (string(_B.phase) == "intro_call"){
                    var p2 = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
                    var slide_frac = 0.35;
                    var start_log = -40;
                    var start_px = __bxu(_pid, start_log);
                    var target_px = tx;
                    var trainer_x_px = (p2 < slide_frac) ? floor(lerp(start_px, target_px, 1 - (1 - (p2 / slide_frac)) * (1 - (p2 / slide_frac)))) : tx;

                    var _phase = string(_B.phase);
                    var _anim_phase_allowed = (_phase == "intro_call" || _phase == "switch_in");
                    if (_anim_phase_allowed && variable_struct_exists(_B, "caller_battleAnim") && !is_undefined(_B.caller_battleAnim) && sprite_exists(_B.caller_battleAnim)){
                        var bs = _B.caller_battleAnim;
                        var frames = max(1, sprite_get_number(bs));
                        var now_ms = current_time;
                        var call_start = (variable_struct_exists(_B, "phase_start_ms") ? _B.phase_start_ms : now_ms);
                        var call_dur = max(1, real(_B.phase_durs.call));
                        var hold_ms = 0;
                        if (variable_struct_exists(_B, "phase_holds") && variable_struct_exists(_B.phase_holds, "call")) hold_ms = max(0, real(_B.phase_holds.call));
                        var slide_ms = floor(call_dur * slide_frac);
                        var anim_ms = call_dur - slide_ms;
                        var elapsed_ms = now_ms - call_start;

                        var draw_frame = 0;
                        if (elapsed_ms < slide_ms){ draw_frame = 0; }
                        else if (elapsed_ms < slide_ms + anim_ms){
                            var anim_elapsed = elapsed_ms - slide_ms;
                            if (frames <= 1){ draw_frame = 0; }
                            else {
                                var prog = clamp(anim_elapsed / max(1, anim_ms), 0, 0.999999);
                                draw_frame = floor(prog * frames);
                                if (draw_frame >= frames) draw_frame = frames - 1;
                            }
                        } else if (elapsed_ms < slide_ms + anim_ms + hold_ms){ draw_frame = max(0, frames - 1); }
                        else { draw_frame = max(0, frames - 1); }

                        var bx = trainer_x_px - (sprite_get_width(bs)*ui_s)/2;
                        var by = ty - (sprite_get_height(bs)*ui_s)/2;
                        draw_sprite_ext(bs, draw_frame, bx, by, ui_s, ui_s, 0, c_white, 1);
                        if (string(_B.phase) == "intro_call") return;
                    }

                    if (_anim_phase_allowed && variable_global_exists("battleAnim") && sprite_exists(battleAnim)){
                        var bs2 = battleAnim;
                        var frames2 = max(1, sprite_get_number(bs2));
                        var now_ms2 = current_time;
                        var call_start2 = (variable_struct_exists(_B, "phase_start_ms") ? _B.phase_start_ms : now_ms2);
                        var call_dur2 = max(1, real(_B.phase_durs.call));
                        var hold_ms2 = 0;
                        if (variable_struct_exists(_B, "phase_holds") && variable_struct_exists(_B.phase_holds, "call")) hold_ms2 = max(0, real(_B.phase_holds.call));
                        var slide_ms2 = floor(call_dur2 * slide_frac);
                        var anim_ms2 = call_dur2 - slide_ms2;
                        var elapsed_ms2 = now_ms2 - call_start2;

                        var draw_frame2 = 0;
                        if (elapsed_ms2 < slide_ms2){ draw_frame2 = 0; }
                        else if (elapsed_ms2 < slide_ms2 + anim_ms2){
                            var anim_elapsed2 = elapsed_ms2 - slide_ms2;
                            if (frames2 <= 1){ draw_frame2 = 0; }
                            else {
                                var prog2 = clamp(anim_elapsed2 / max(1, anim_ms2), 0, 0.999999);
                                draw_frame2 = floor(prog2 * frames2);
                                if (draw_frame2 >= frames2) draw_frame2 = frames2 - 1;
                            }
                        } else if (elapsed_ms2 < slide_ms2 + anim_ms2 + hold_ms2){ draw_frame2 = max(0, frames2 - 1); }
                        else { draw_frame2 = max(0, frames2 - 1); }

                        var bx2 = trainer_x_px - (sprite_get_width(bs2)*ui_s)/2;
                        var by2 = ty - (sprite_get_height(bs2)*ui_s)/2;
                        draw_sprite_ext(bs2, draw_frame2, bx2, by2, ui_s, ui_s, 0, c_white, 1);
                        if (string(_B.phase) == "intro_call") return;
                    }
                }

                if (string(_B.phase) == "intro_player"){
                    var p3 = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
                    var t3 = 1 - (1 - p3) * (1 - p3);
                    var minScale = 0.4;
                    var targetScale = drawScaleP;
                    var curScale = lerp(minScale * ui_s, targetScale, t3);
                    var draw_x2 = mx - (w*curScale)/2;
                    var draw_y2 = my - (h*curScale)/2;
                    draw_set_color(make_color_rgb(20,20,20));
                    draw_set_alpha(0.45);
                    var shadow_w_p = floor((w * curScale) * 0.6);
                    var shadow_h_p = max(2, floor((w * curScale) * 0.12));
                    var shadow_cx_p = floor(draw_x2 + (w * curScale) * 0.5);
                    var shadow_cy_p = floor(draw_y2 + (h * curScale) * 0.5 + shadow_h_p * 0.8 + floor(15 * ui_s));
                    draw_ellipse(shadow_cx_p - shadow_w_p div 2, shadow_cy_p - shadow_h_p div 2, shadow_cx_p + shadow_w_p div 2, shadow_cy_p + shadow_h_p div 2, false);
                    draw_set_alpha(1);
                    draw_sprite_ext(sprP, subP, draw_x2, draw_y2, curScale, curScale, 0, c_white, 1);
                } else if (string(_B.phase) == "command"){
                    var _breath_amp_p = 0.03;
                    var _breath_period_p = 2000;
                    var _bs_p = 1;
                    if (string(_B.phase) == "command"){
                        var _tms_p = current_time;
                        var _offset = floor(_breath_period_p / 2);
                        _bs_p = 1 + sin(((_tms_p + _offset) * 2 * pi) / _breath_period_p) * _breath_amp_p;
                    }
                    draw_set_color(make_color_rgb(20,20,20));
                    draw_set_alpha(0.45);
                    var shadow_w_p2 = floor((w * drawScaleP * _bs_p) * 0.6);
                    var shadow_h_p2 = max(2, floor((w * drawScaleP) * 0.12));
                    var shadow_cx_p2 = floor(draw_x + (w * drawScaleP * _bs_p) * 0.5);
                    var shadow_cy_p2 = floor(draw_y + (h * drawScaleP) * 0.5 + shadow_h_p2 * 0.8 + floor(15 * ui_s));
                    draw_ellipse(shadow_cx_p2 - shadow_w_p2 div 2, shadow_cy_p2 - shadow_h_p2 div 2, shadow_cx_p2 + shadow_w_p2 div 2, shadow_cy_p2 + shadow_h_p2 div 2, false);
                    draw_set_alpha(1);
                    draw_sprite_ext(sprP, subP, draw_x, draw_y, drawScaleP * _bs_p, drawScaleP, 0, c_white, 1);
                }

                // switch_in visuals
                if (string(_B.phase) == "switch_in"){
                    var prog = (variable_struct_exists(_B, "phase_progress") ? _B.phase_progress : 0);
                    var out_prog = min(1, prog * 2);
                    var in_prog = max(0, (prog - 0.5) * 2);

                    var outScale = lerp(drawScaleP, drawScaleP * 0.4, out_prog);
                    var inScale = lerp(drawScaleP * 0.4, drawScaleP, in_prog);

                    if (prog < 0.5){
                        var draw_x_out = mx - (w * outScale) / 2;
                        var draw_y_out = my - (h * outScale) / 2;
                        draw_set_color(make_color_rgb(20,20,20)); draw_set_alpha(0.45);
                        var sw = floor((w * outScale) * 0.6);
                        var sh = max(2, floor((w * outScale) * 0.12));
                        var scx = floor(draw_x_out + (w * outScale) * 0.5);
                        var scy = floor(draw_y_out + (h * outScale) * 0.5 + sh * 0.8 + floor(15 * ui_s));
                        draw_ellipse(scx - sw div 2, scy - sh div 2, scx + sw div 2, scy + sh div 2, false);
                        draw_set_alpha(1);
                        draw_sprite_ext(sprP, subP, draw_x_out, draw_y_out, outScale, outScale, 0, c_white, 1);

                        if (out_prog >= 1 && variable_struct_exists(_B, "_switch_target_idx")){
                            var idx = _B._switch_target_idx;
                            var opts = (variable_struct_exists(_B, "_switch_opts") ? _B._switch_opts : {});
                            var auto_apply = !(variable_struct_exists(opts, "auto_apply") && opts.auto_apply == false);
                            if (auto_apply && !is_undefined(party_ensure)){
                                var Pset = party_ensure(_pid);
                                if (is_array(Pset.mons) && idx >= 0 && idx < array_length(Pset.mons)){
                                    _B.actor[0] = __battle_actor_from_party_mon(Pset.mons[idx]);
                                }
                            }
                            _B._switch_target_idx = undefined;
                        }
                    } else {
                        var curA = _B.actor[0];
                        var sprIn = -1, subIn = 0, wIn = 0, hIn = 0;
                        if (is_struct(curA) && is_struct(curA.mon) && !is_undefined(pkicons_get_art96_by_mon) && !is_undefined(pkicons_get_art96_subimg_by_mon)){
                            sprIn = pkicons_get_art96_by_mon(curA.mon);
                            subIn = pkicons_get_art96_subimg_by_mon(curA.mon, true);
                            if (sprite_exists(sprIn)){ wIn = sprite_get_width(sprIn); hIn = sprite_get_height(sprIn); }
                        }
                        var draw_x_in = mx - (wIn * inScale) / 2;
                        var draw_y_in = my - (hIn * inScale) / 2;
                        draw_set_color(make_color_rgb(20,20,20)); draw_set_alpha(0.45);
                        var sw2 = floor((wIn * inScale) * 0.6);
                        var sh2 = max(2, floor((wIn * inScale) * 0.12));
                        var scx2 = floor(draw_x_in + (wIn * inScale) * 0.5);
                        var scy2 = floor(draw_y_in + (hIn * inScale) * 0.5 + sh2 * 0.8 + floor(15 * ui_s));
                        draw_ellipse(scx2 - sw2 div 2, scy2 - sh2 div 2, scx2 + sw2 div 2, scy2 + sh2 div 2, false);
                        draw_set_alpha(1);
                        if (sprite_exists(sprIn)) draw_sprite_ext(sprIn, subIn, draw_x_in, draw_y_in, inScale, inScale, 0, c_white, 1);
                    }
                }
            }
        }
    }
}
