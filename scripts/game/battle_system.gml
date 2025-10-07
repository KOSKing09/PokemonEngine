// [Battle] PokemonBattleSystem — Build v0.1.30 (PID, GUI, Letterbox)
// Updated 2025-10-06
// - PID-aware (works for local/online later): state lives in global.sys_battles[pid]
// - Draws entirely in Draw GUI (no camera dependency)
// - 240×160 logical canvas with letterbox fit
// - Command box fixed at y=136 (24px high) to fit exactly
// - Minimal move seeding; plugs into your Party system and species helpers
// -----------------------------------------------------------------------------
// CALLS you’ll use in objects:
//   battle_open(pid, wild_level);      // e.g., battle_open(0, irandom_range(5,18));
//   battle_update(pid);                // Step Event
//   battle_draw_gui(pid);              // Draw GUI Event
//   battle_close(pid);                 // when done
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
    // Automatically resolve the player instance for this pid so callers can be referenced later
    var _caller = noone;
    if (!is_undefined(player_by_pid)) {
        _caller = player_by_pid(_pid);
        if (_caller == noone) _caller = noone;
    }

    var _B = __battle_ensure_slot(_pid);
    if (_B.sys_open) return;

    _B.sys_open = true;
    // Start with a transition-in fade, then proceed into the intro sequence
    _B.phase    = "transition_in";
    _B.turn     = 0;
    _B.result   = "ongoing";
    _B.sys_rng  = random_get_seed();

    _B.sys_ui   = { menu:"root", selX:0, selY:0, msg_list:ds_list_create() };
    _B.sys_anim = { active:[
        {anim_id:"idle",timer:0,duration:999999,offX:0,offY:0,scale:1},
        {anim_id:"idle",timer:0,duration:999999,offX:0,offY:0,scale:1}
    ]};
    // Intro sequencing: transition_in -> enemy slide -> player call animation -> player scale up
    _B.phase_start_ms = current_time;
    _B.phase_durs = { transition: 300, enemy: 400, call: 700, player: 400 }; // ms durations
    // Hold durations (ms) for phases that require a freeze at the end
    _B.phase_holds = { call: 3000 };

    _B.theme = {
        col_bg:       make_color_rgb(184,224,200),
        col_outline:  make_color_rgb(72,88,80),
        col_panel:    make_color_rgb(208,232,224),
        col_hp_green: make_color_rgb(120,216,88),
        col_hp_yell:  make_color_rgb(248,208,56),
        col_hp_red:   make_color_rgb(232,72,56),
        col_text:     c_white
    };

    // Player actor from that player's party
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

    // remember caller instance (if any) and capture its battleAnim sprite reference for drawing
    _B.caller = _caller;
    if (_B.caller != noone && instance_exists(_B.caller) && variable_instance_exists(_B.caller, "battleAnim") && sprite_exists(_B.caller.battleAnim)){
        _B.caller_battleAnim = _B.caller.battleAnim;
    } else if (variable_global_exists("battleAnim") && sprite_exists(battleAnim)){
        // fallback to global skin battleAnim if present
        _B.caller_battleAnim = battleAnim;
    } else {
        _B.caller_battleAnim = undefined;
    }

    __battle_ensure_moves_from_levelup(_B.actor[0]);
    __battle_ensure_moves_from_levelup(_B.actor[1]);

    global.sys_battles[_pid] = _B;
}
function battle_close(_pid){
    var _B = __battle_ensure_slot(_pid);
    _B.sys_open = false;
}

// ===== Update / Draw =====
function battle_update(_pid){
    if (!battle_is_open(_pid)) return;
    var _B = __battle_ensure_slot(_pid);
    // Handle intro sequencing phases
    if (string(_B.phase) == "transition_in" || string(_B.phase) == "intro_enemy" || string(_B.phase) == "intro_call" || string(_B.phase) == "intro_player"){
        var now = current_time;
        var stage = string(_B.phase);
        var start = (variable_struct_exists(_B,"phase_start_ms") ? _B.phase_start_ms : now);
        if (stage == "transition_in"){
            var dur = _B.phase_durs.transition;
            var elapsed = now - start;
            _B.phase_progress = max(0, min(1, elapsed / max(1,dur)));
            if (elapsed >= dur){ _B.phase = "intro_enemy"; _B.phase_start_ms = now; }
            else return;
        }
        if (stage == "intro_enemy"){
            var dur = _B.phase_durs.enemy;
            var elapsed = now - start;
            _B.phase_progress = max(0, min(1, elapsed / max(1,dur)));
            if (elapsed >= dur){
                _B.phase = "intro_call";
                _B.phase_start_ms = now;
                // Freeze caller instance visual state to prevent its own image_index from animating
                if (variable_struct_exists(_B, "caller") && _B.caller != noone && instance_exists(_B.caller)){
                    if (variable_instance_exists(_B.caller, "image_index")) _B.caller.image_index = 0;
                    if (variable_instance_exists(_B.caller, "image_speed")) _B.caller.image_speed = 0;
                }
            }
            else return;
        } else if (stage == "intro_call"){
            var dur = _B.phase_durs.call;
            var hold_ms = 0;
            if (variable_struct_exists(_B, "phase_holds") && variable_struct_exists(_B.phase_holds, "call")) hold_ms = max(0, real(_B.phase_holds.call));
            var elapsed = now - start;
            // phase_progress reports progress through the nominal call duration (excluding any extra hold)
            _B.phase_progress = max(0, min(1, elapsed / max(1,dur)));
            // Only advance to the next phase after the call duration plus any configured hold (ms)
            if (elapsed >= dur + hold_ms){ _B.phase = "intro_player"; _B.phase_start_ms = now; }
            else return;
        } else if (stage == "intro_player"){
            var dur = _B.phase_durs.player;
            var elapsed = now - start;
            _B.phase_progress = max(0, min(1, elapsed / max(1,dur)));
            if (elapsed >= dur){ _B.phase = "command"; }
            else return;
        }
    }
    __battle_process_input(_pid);
}

function battle_draw_gui(_pid){
    var _rect = __battle_view_rect_for_pid(_pid); // [rx,ry,rw,rh] letterboxed inside GUI
    if (is_array(_rect) && array_length(_rect) >= 4) {
        battle_draw_gui_rect(_pid, _rect[0], _rect[1], _rect[2], _rect[3]);
    }
}

// Draw the battle UI inside a given GUI rect (matches party_draw_gui_rect style)
function battle_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!battle_is_open(_pid)) return;
    var _B = __battle_ensure_slot(_pid);

    // Compute integer UI scale (like party system) so caller can assign rects for split-screen
    var _S  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _OX = _rx + (_rw - 240 * _S) div 2;
    var _OY = _ry + (_rh - 160 * _S) div 2;

    // Begin UI transform using our existing helpers (give __bui_begin the centered, sized rect)
    __bui_begin(_pid, _OX, _OY, 240*_S, 160*_S);

    // Set default font for the battle UI (match party system)
    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    // background
    draw_set_color(_B.theme.col_bg);
    draw_rectangle(__bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240), __byu(_pid,160), false);

    // draw battler sprites (opponent front-facing, player back-facing)
    function __battle_draw_battlers(_pid, _B) {
        // logical coordinates and scales (tweak for your layout)
    var foe_x_log = 165, foe_y_log = 40;
    // Keep the pokemon at the original position; draw the trainer/player near the border
    var mon_x_log = 64,  mon_y_log = 112; // pokemon back-sprite original spot
    var trainer_x_log = 32, trainer_y_log = 108; // trainer/player sprite near border (moved up 4 px)
        var scale_foe = 1.0, scale_us = 1.1;

        var fx = __bxu(_pid, foe_x_log);
        var fy = __byu(_pid, foe_y_log);
        var mx = __bxu(_pid, mon_x_log);
        var my = __byu(_pid, mon_y_log);
        var tx = __bxu(_pid, trainer_x_log);
        var ty = __byu(_pid, trainer_y_log);

    // Enemy (front-facing)
        var E = _B.actor[1];
        if (is_struct(E) && variable_struct_exists(E, "mon")) {
            // Don't draw the enemy during the initial transition fade; wait until the enemy slide phase
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
                        // Slide-in during intro_enemy phase: start off-screen on the far right and ease in
                        var draw_x = fx - (w*drawScaleE)/2;
                        var draw_y = fy - (h*drawScaleE)/2;
                        if (string(_B.phase) == "intro_enemy"){
                            var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
                            var start_log = 240 + 40; // logical x = 280
                            var start_px = __bxu(_pid, start_log);
                            var target_px = fx - (w*drawScaleE)/2;
                            // ease out
                            var t = 1 - (1 - p) * (1 - p);
                            draw_x = floor(lerp(start_px, target_px, t));
                        }
                        draw_sprite_ext(sprE, subE, draw_x, draw_y, drawScaleE, drawScaleE, 0, c_white, 1);
                    }
                }
            }
        }

        // Player (back-facing)
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
                    var draw_x = mx - (w*drawScaleP)/2;
                    var draw_y = my - (h*drawScaleP)/2;

                    // Do not draw the player's `sprite_index` here. The caller's `battleAnim` is drawn
                    // during the intro_call phase only (below). Also, hide the player's Pokémon
                    // entirely until the intro sequence finishes (phase == "command").
                    var player_drawn = false;

                    // During intro_call phase, slide the trainer in from the left then play the animation
                    if (string(_B.phase) == "intro_call"){
                        var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
                        // portion of the call phase used for sliding in (0..1)
                        var slide_frac = 0.35;
                        // logical start off-screen to left
                        var start_log = -40;
                        var start_px = __bxu(_pid, start_log);
                        var target_px = tx - 0; // tx already in pixels
                        // compute trainer x (pixels) depending on slide progress
                        var trainer_x_px = tx;
                        if (p < slide_frac){
                            var t = p / slide_frac;
                            // ease out
                            var e = 1 - (1 - t) * (1 - t);
                            trainer_x_px = floor(lerp(start_px, target_px, e));
                        } else {
                            trainer_x_px = tx;
                        }

                        // Draw caller-specific animation: while sliding, show frame 0; after placement, play frames
                        // but hold the final frame for a portion of the call phase so it pauses at the end.
                        if (variable_struct_exists(_B, "caller_battleAnim") && !is_undefined(_B.caller_battleAnim) && sprite_exists(_B.caller_battleAnim)){
                            var bs = _B.caller_battleAnim;
                            var frames = max(1, sprite_get_number(bs));
                            // Compute absolute ms segments for this call phase
                            var now_ms = current_time;
                            var call_start = (variable_struct_exists(_B, "phase_start_ms") ? _B.phase_start_ms : now_ms);
                            var call_dur = max(1, real(_B.phase_durs.call));
                            var hold_ms = 0;
                            if (variable_struct_exists(_B, "phase_holds") && variable_struct_exists(_B.phase_holds, "call")) hold_ms = max(0, real(_B.phase_holds.call));
                            var slide_ms = floor(call_dur * slide_frac);
                            var anim_ms = call_dur - slide_ms;
                            var elapsed_ms = now_ms - call_start;

                            var draw_frame = 0;
                            if (elapsed_ms < slide_ms){
                                // still sliding: keep frame 0
                                draw_frame = 0;
                            } else if (elapsed_ms < slide_ms + anim_ms){
                                // during animation playback: map elapsed into frames
                                var anim_elapsed = elapsed_ms - slide_ms;
                                if (frames <= 1){
                                    draw_frame = 0;
                                } else {
                                    var prog = clamp(anim_elapsed / max(1, anim_ms), 0, 0.999999);
                                    draw_frame = floor(prog * frames);
                                    if (draw_frame >= frames) draw_frame = frames - 1;
                                }
                            } else if (elapsed_ms < slide_ms + anim_ms + hold_ms){
                                // final hold: show last frame
                                draw_frame = max(0, frames - 1);
                            } else {
                                // Fallback: ensure last frame
                                draw_frame = max(0, frames - 1);
                            }

                            var bx = trainer_x_px - (sprite_get_width(bs)*ui_s)/2;
                            var by = ty - (sprite_get_height(bs)*ui_s)/2;
                            draw_sprite_ext(bs, draw_frame, bx, by, ui_s, ui_s, 0, c_white, 1);
                            // hide the pokemon image entirely during the call animation
                            return;
                        }

                        // Fallback: global battleAnim with same sliding behavior
                        if (variable_global_exists("battleAnim") && sprite_exists(battleAnim)){
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
                            if (elapsed_ms2 < slide_ms2){
                                draw_frame2 = 0;
                            } else if (elapsed_ms2 < slide_ms2 + anim_ms2){
                                var anim_elapsed2 = elapsed_ms2 - slide_ms2;
                                if (frames2 <= 1){
                                    draw_frame2 = 0;
                                } else {
                                    var prog2 = clamp(anim_elapsed2 / max(1, anim_ms2), 0, 0.999999);
                                    draw_frame2 = floor(prog2 * frames2);
                                    if (draw_frame2 >= frames2) draw_frame2 = frames2 - 1;
                                }
                            } else if (elapsed_ms2 < slide_ms2 + anim_ms2 + hold_ms2){
                                draw_frame2 = max(0, frames2 - 1);
                            } else {
                                draw_frame2 = max(0, frames2 - 1);
                            }

                            var bx2 = trainer_x_px - (sprite_get_width(bs2)*ui_s)/2;
                            var by2 = ty - (sprite_get_height(bs2)*ui_s)/2;
                            draw_sprite_ext(bs2, draw_frame2, bx2, by2, ui_s, ui_s, 0, c_white, 1);
                            return;
                        }
                    }

                    // Draw the player's Pokémon back-sprite during the player intro (scale-up),
                    // then draw normally during command. Keep it hidden during prior intro phases.
                    if (string(_B.phase) == "intro_player"){
                        var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
                        // ease-out from small to normal
                        var t = 1 - (1 - p) * (1 - p);
                        var minScale = 0.4;
                        var targetScale = drawScaleP;
                        var curScale = lerp(minScale * ui_s, targetScale, t);
                        draw_x = mx - (w*curScale)/2;
                        draw_y = my - (h*curScale)/2;
                        draw_sprite_ext(sprP, subP, draw_x, draw_y, curScale, curScale, 0, c_white, 1);
                    } else if (string(_B.phase) == "command"){
                        draw_sprite_ext(sprP, subP, draw_x, draw_y, drawScaleP, drawScaleP, 0, c_white, 1);
                    }
                }
            }
        }
    }
    __battle_draw_battlers(_pid, _B);

    // HUD boxes (fit within 240×160)
    __battle_enemy_box_rect(_pid, 16,16,112,40, _B.actor[1]);
    __battle_player_box_rect(_pid,112,104,128,48, _B.actor[0]);
    __battle_cmd_box_rect(_pid,   8,136,224,24,   _B.sys_ui.selX, _B.sys_ui.selY); // 136+24=160

    // Draw transition fade when in the transition_in phase
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

// ===== Input (PID-aware; falls back to keyboard) =====
function __battle_pressed(_pid, _name){
    // Prefer the project's control system when available
    if (!is_undefined(controls_pressed)){
        var act = "";
        if (_name=="Left") act = "MoveLeft";
        else if (_name=="Right") act = "MoveRight";
        else if (_name=="Up") act = "MoveUp";
        else if (_name=="Down") act = "MoveDown";
        else if (_name=="A") act = "Interact";
        else if (_name=="B") act = "Pause";
        if (string_length(act) > 0) return controls_pressed(_pid, act);
    }
    // Fallback: direct keyboard checks
    if (_name=="Left")  return keyboard_check_pressed(vk_left);
    if (_name=="Right") return keyboard_check_pressed(vk_right);
    if (_name=="Up")    return keyboard_check_pressed(vk_up);
    if (_name=="Down")  return keyboard_check_pressed(vk_down);
    if (_name=="A")     return keyboard_check_pressed(vk_enter);
    if (_name=="B")     return keyboard_check_pressed(vk_escape);
    return false;
}
function __battle_process_input(_pid){
    // Placeholder navigation; hook to your menu later
    var _l = __battle_pressed(_pid,"Left");
    var _r = __battle_pressed(_pid,"Right");
    var _u = __battle_pressed(_pid,"Up");
    var _d = __battle_pressed(_pid,"Down");
    var _a = __battle_pressed(_pid,"A");
    var _b = __battle_pressed(_pid,"B");

    var _B = __battle_ensure_slot(_pid);
    if (_l) _B.sys_ui.selX = max(0, _B.sys_ui.selX - 1);
    if (_r) _B.sys_ui.selX = min(1, _B.sys_ui.selX + 1);
    if (_u) _B.sys_ui.selY = max(0, _B.sys_ui.selY - 1);
    if (_d) _B.sys_ui.selY = min(1, _B.sys_ui.selY + 1);
    if (_b) { /* back/cancel later */ }
    if (_a) { /* confirm later */ }
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
    // Keep reference to the original party mon struct so draw code can access .shiny, .icon, etc.
    if (is_struct(_M)) {
        _actor.mon = _M;
        // Normalize species_id: many systems use `id` or `species`; ensure species_id exists and is numeric
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
    // Create a minimal mon struct for wild actors so pkicons helpers can use .shiny and species
    _actor.mon = { species_id:_sp, shiny:false };
    return _actor;
}

// ===== Move population =====
function __battle_ensure_moves_from_levelup(_A){
    // reset
    for (var i=0; i<4; ++i){ _A.moves[i] = -1; _A.pps[i] = 0; }

    // simplest seed from your helpers if available
    if (!is_undefined(scr_poke_moveset_by_id)){
        var _pool = scr_poke_moveset_by_id(_A.species);
        if (is_array(_pool) && array_length(_pool) > 0){
            // pick up to 4 last (most recent) moves <= level if you later have [move, lvl] tuples
            _A.moves[0] = _pool[0];
            _A.pps[0]   = 10;
        }
    }
}

// ===== Rect pipeline (PID-aware, GUI-only) =====
function __bui_begin(_pid,_rx,_ry,_rw,_rh){
    var _B = __battle_ensure_slot(_pid);
    // Store the provided letterbox rect but compute a single uniform scale to
    // preserve the 240x160 logical aspect ratio and center the content.
    var base_w = 240, base_h = 160;
    var sx = _rw / base_w;
    var sy = _rh / base_h;
    var s = min(sx, sy);
    // Compute centered content origin within provided rect
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


// ===== Panels & HUD (PID-aware) =====
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
    draw_text(_bx+__bwu(_pid,8), _by+__bhu(_pid,6), string(_A.name));
    draw_text(_bx+_bw-__bwu(_pid,32), _by+__bhu(_pid,6), "Lv"+string(_A.level));
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
    draw_text(_bx+__bwu(_pid,8), _by+__bhu(_pid,6), string(_A.name));
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
    var _labels = ["FIGHT","BAG","POK\u00E9MON","RUN"];
    // Use small font for command labels if available
    var _restoreFont = -1;
    if (variable_global_exists("FNT_POKEMON")) _restoreFont = global.FNT_POKEMON;
    if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);
    for (var _i=0; _i<4; ++_i){
        var _tx = _bx + __bwu(_pid,12) + ((_i % 2) * (_bw * 0.5));
        var _ty = _by + __bhu(_pid,6)  + (floor(_i / 2) * (_bh * 0.5));
        var _hilite = (_selX == (_i % 2)) && (_selY == floor(_i / 2));
        draw_set_color(_hilite ? c_yellow : _t.col_text);
        draw_text(_tx,_ty,_labels[_i]);
    }
    if (_restoreFont != -1) draw_set_font(_restoreFont);
}

// ===== GUI Letterbox rect (per PID, GUI-only; cameras ignored) =====
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
