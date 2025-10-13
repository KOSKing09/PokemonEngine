// Battle draw helpers (extracted from battle_system.gml)

function __battle_draw_enemy(_pid, _B, fx, fy){
    var scale_foe = 1.0;
    var E = _B.actor[1];
    if (!is_struct(E) || !variable_struct_exists(E, "mon")) return;
    if (string(_B.phase) == "transition_in") return;
    var mE = E.mon;
    if (is_undefined(pkicons_get_art96_by_mon) || is_undefined(pkicons_get_art96_subimg_by_mon)) return;
    var sprE = pkicons_get_art96_by_mon(mE);
    var subE = pkicons_get_art96_subimg_by_mon(mE, false);
    if (!sprite_exists(sprE)) return;
    var w = sprite_get_width(sprE);
    var h = sprite_get_height(sprE);
    var _ui = __battle_ensure_slot(_pid)._ui;
    var ui_s = (is_struct(_ui) && variable_struct_exists(_ui,"s")) ? _ui.s : 1;
    var drawScaleE = scale_foe * ui_s;
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
    // If a catch animation is active, allow it to modify the enemy scale and draw a pokéball
    var catchA = (variable_struct_exists(_B, "_catch_anim") ? _B._catch_anim : undefined);
    var ball_to_draw = undefined;
    if (is_struct(catchA) && catchA.active){
        var now = current_time;
        var since = now - (variable_struct_exists(catchA, "start_ms") ? catchA.start_ms : now);
        // Compute phases: throw -> impact -> shake -> resolve -> escape
        var phase = string(catchA.phase);
        // safe defaults for durations
        var throw_dur = (variable_struct_exists(catchA, "throw_dur") ? max(1, real(catchA.throw_dur)) : 380);
        var impact_dur = (variable_struct_exists(catchA, "impact_dur") ? max(1, real(catchA.impact_dur)) : 220);
        var shake_dur = (variable_struct_exists(catchA, "shake_dur") ? max(1, real(catchA.shake_dur)) : 900);
        var escape_dur = (variable_struct_exists(catchA, "escape_dur") ? max(1, real(catchA.escape_dur)) : 320);

        if (phase == "throw"){
            var t = clamp(since / throw_dur, 0, 1);
            // ball travels from trainer area (right of screen) to foe center along a parabolic arc
            var sx = __bxu(_pid, 32);
            var sy = __byu(_pid, 108);
            var txp = fx;
            var typ = fy;
            // base linear interpolation
            var bx_lin = lerp(sx, txp, t);
            var by_lin = lerp(sy, typ, t);
            // arc height (pixels) proportional to distance between start and target
            var dx = abs(txp - sx);
            var dy = abs(typ - sy);
            var h_arc = max(24, floor((dx + dy) * 0.25));
            // parabolic offset: peaks at t=0.5, value in range [0, h_arc]
            var arc = (1 - ((t - 0.5) * 2) * ((t - 0.5) * 2)) * h_arc;
            var bx = floor(bx_lin);
            var by = floor(by_lin - arc);
            // flight: use a slightly smaller ball and do NOT shrink the enemy until impact
            ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: bx, y: by, scale: 0.8};
        } else if (phase == "impact"){
            var e = now - (variable_struct_exists(catchA, "phase_start") ? catchA.phase_start : now);
            var t2 = clamp(e / impact_dur, 0, 1);
            var ease2 = sin(t2 * pi);
            // shrink the enemy nearly to zero so it appears to be pulled into the ball
            drawScaleE *= lerp(1, 0, ease2);
            // ball starts centered on the foe while impact completes
            var bx2 = fx;
            var by2 = fy;
            ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: bx2, y: by2, scale: 0.8};
        } else if (phase == "shake"){
            var e3 = now - (variable_struct_exists(catchA, "phase_start") ? catchA.phase_start : now);
            var t3 = clamp(e3 / shake_dur, 0, 1);
            var shakes = max(1, (variable_struct_exists(catchA, "shakes") ? real(catchA.shakes) : 3));
            // drop fraction: portion of shake where the ball falls to the bottom
            var drop_phase_frac = 0.25;
            var drop_prog = clamp(t3 / drop_phase_frac, 0, 1);
            // logical landing Y: shallow drop (about 15% of full height below center)
            var enemy_base_bottom = fy + (h * ui_s) * 0.15;
            // horizontal shake and rotation (use image angle via draw_sprite_ext angle param)
            var shakeOsc = sin(t3 * shakes * pi * 2);
            // disable rotation for now
            var rotDeg = 0;
            var raw_bob = cos(t3 * shakes * pi * 2) * 2;
            var bob = raw_bob * (1 - drop_prog); // fade bob as the ball finishes dropping
            // enemy remains hidden during the shake
            drawScaleE *= 0;
            // ball scale slightly shrinks as it drops
            var ballScale = lerp(0.8, 0.65, drop_prog);
            // ball Y moves from center (fy) down to the enemy_base_bottom as drop_prog goes 0->1, then small bob
            var by3 = lerp(fy, enemy_base_bottom, drop_prog) + bob;
            // keep the ball horizontally centered; rotation (rotDeg) will provide left/right turning visually
            var bx3 = fx;
            ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: bx3, y: by3, scale: ballScale};
            // keep rotation active during the shake; the ball will lock on phase change to 'resolve'
        } else if (phase == "resolve" || phase == "caught"){
            // ball rests at the bottom of the enemy sprite; enemy remains hidden
            var enemy_base_bottom_res = fy + (h * ui_s) * 0.15;
            // enemy remains fully hidden after resolve/caught
            drawScaleE *= 0;
            ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: fx, y: enemy_base_bottom_res, scale: 0.65};
        } else if (phase == "escape"){
            var e4 = now - (variable_struct_exists(catchA, "phase_start") ? catchA.phase_start : now);
            var t4 = clamp(e4 / escape_dur, 0, 1);
            // grow enemy back to normal from the near-zero hidden state
            // grow enemy back to normal from fully hidden (0 -> 1)
            drawScaleE *= lerp(0, 1, t4);
            // ball stays near the bottom while it fades and slightly drifts
            var enemy_base_bottom_e = fy + (h * ui_s) * 0.15;
            var bx4 = fx; // locked horizontally
            var by4 = enemy_base_bottom_e - lerp(0, 24, t4);
            var scaleb = lerp(0.65, 0.45, t4);
            ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: bx4, y: by4, scale: scaleb, alpha: lerp(1, 0, t4)};
        }
    }
    // Debug: avoid spamming the console every frame. Only log on phase change or first missing sprite.
    if (is_struct(catchA) && catchA.active){
        var lastp = (variable_struct_exists(catchA, "_dbg_last_phase") ? string(catchA._dbg_last_phase) : "");
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            if (lastp != string(catchA.phase)){
                show_debug_message("[battle][debug] catch draw phase change pid=" + string(_pid) + ", phase=" + string(catchA.phase));
                variable_struct_set(catchA, "_dbg_last_phase", string(catchA.phase));
            }
            if (!(is_struct(ball_to_draw) && !is_undefined(ball_to_draw.spr))){
                var logged_missing = (variable_struct_exists(catchA, "_dbg_missing_logged") ? catchA._dbg_missing_logged : false);
                if (!logged_missing){
                    show_debug_message("[battle][debug] catch active but no ball_to_draw or invalid sprite (pid=" + string(_pid) + ", phase=" + string(catchA.phase) + ")");
                    variable_struct_set(catchA, "_dbg_missing_logged", true);
                }
            }
        }
    }
    if (string(_B.phase) == "intro_enemy"){
        var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        var start_log = 240 + 40;
        var start_px = __bxu(_pid, start_log);
        var target_px = fx - (w*drawScaleE)/2;
        var t = 1 - (1 - p) * (1 - p);
        draw_x = floor(lerp(start_px, target_px, t));
            // If the animation entered 'resolve' (caught) and we still have the state, draw the steady ball
            if (is_struct(catchA) && catchA.active && string(catchA.phase) == "resolve"){
                // show ball centered, no rotation
                ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: fx, y: fy, scale: 0.8};
                // keep the enemy small so it looks like it remained inside
                drawScaleE *= 0.35;
            }
    }
    // Recompute draw_x/draw_y now that drawScaleE may have been modified by the catch animation
    // (this keeps the sprite centered while scaling instead of shifting left/right)
    // If `intro_enemy` set a custom draw_x we preserve it but still recalc draw_y
    if (!(string(_B.phase) == "intro_enemy")) draw_x = fx - (w*drawScaleE)/2;
    draw_y = fy - (h*drawScaleE)/2;

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

    // draw pokéball on top if present
    if (!is_undefined(ball_to_draw) && !is_undefined(ball_to_draw.spr) && sprite_exists(ball_to_draw.spr)){
        var fr = 0;
        if (variable_struct_exists(ball_to_draw, "frame")) fr = variable_struct_get(ball_to_draw, "frame");
        var bs = ball_to_draw.spr;
        var bsw = sprite_get_width(bs);
        var bsh = sprite_get_height(bs);
        // Center the sprite at ball_to_draw.x,y regardless of its internal origin
        var origin_x = sprite_get_xoffset(bs);
        var origin_y = sprite_get_yoffset(bs);
    // Compute origin->center vector (scaled) and account for UI scale so rotation pivot is correct
    var bscale_ui = ball_to_draw.scale * ui_s;
    var cx_off = (bsw * 0.5 - origin_x) * bscale_ui;
    var cy_off = (bsh * 0.5 - origin_y) * bscale_ui;
    // rotation disabled — draw sprite upright
    var rot = 0;
    var alpha = (variable_struct_exists(ball_to_draw, "alpha") ? real(ball_to_draw.alpha) : 1);
    // rotate the offset so the visual center stays at ball_to_draw.x,y even when rotated
    var th = rot * pi / 180;
    var rx = cx_off * cos(th) - cy_off * sin(th);
    var ry = cx_off * sin(th) + cy_off * cos(th);
    // place the sprite origin such that the rotated center is at the desired position
    var bx_draw = ball_to_draw.x - rx;
    var by_draw = ball_to_draw.y - ry;
    draw_sprite_ext(bs, fr, bx_draw, by_draw, ball_to_draw.scale * ui_s, ball_to_draw.scale * ui_s, rot, c_white, alpha);
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][debug] drew ball sprite pid=" + string(_pid) + ", spr=" + string(bs) + ", x=" + string(bx_draw) + ", y=" + string(by_draw));
    }
}

function __battle_draw_player(_pid, _B, mx, my, tx, ty){
    var scale_us = 1.1;
    var P = _B.actor[0];
    if (!is_struct(P) || !variable_struct_exists(P, "mon")) return;
    if (is_undefined(pkicons_get_art96_by_mon) || is_undefined(pkicons_get_art96_subimg_by_mon)) return;
    var mP = P.mon;
    var sprP = pkicons_get_art96_by_mon(mP);
    var subP = pkicons_get_art96_subimg_by_mon(mP, true);
    var w = sprite_exists(sprP) ? sprite_get_width(sprP) : 0;
    var h = sprite_exists(sprP) ? sprite_get_height(sprP) : 0;
    var _ui = __battle_ensure_slot(_pid)._ui;
    var ui_s = (is_struct(_ui) && variable_struct_exists(_ui,"s")) ? _ui.s : 1;
    var drawScaleP = scale_us * ui_s;
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

        if (_anim_phase_allowed && variable_global_exists("battleAnim") && sprite_exists(global.battleAnim)){
            var bs2 = global.battleAnim;
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
        if (sprite_exists(sprP)) draw_sprite_ext(sprP, subP, draw_x2, draw_y2, curScale, curScale, 0, c_white, 1);
        else {
            // Fallback: draw a simple placeholder so player isn't invisible
            draw_set_color(make_color_rgb(20,20,20)); draw_set_alpha(0.45);
            var fw = max(8, floor(64 * ui_s * curScale));
            var fh = max(8, floor(64 * ui_s * curScale));
            draw_ellipse(mx - fw/2, my - fh/2, mx + fw/2, my + fh/2, false);
            draw_set_alpha(1);
            draw_set_color(c_white);
            draw_text(mx - fw/2, my - fh/2 - __bhu(_pid,6), string(P.name));
        }
    } else if (string(_B.phase) == "command" || string(_B.phase) == "turn"){
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
        if (sprite_exists(sprP)) draw_sprite_ext(sprP, subP, draw_x, draw_y, drawScaleP * _bs_p, drawScaleP, 0, c_white, 1);
        else {
            // Fallback while idle/command
            draw_set_color(make_color_rgb(20,20,20)); draw_set_alpha(0.45);
            var fw2 = max(8, floor(64 * ui_s * drawScaleP * _bs_p));
            var fh2 = max(8, floor(64 * ui_s * drawScaleP));
            draw_ellipse(mx - fw2/2, my - fh2/2, mx + fw2/2, my + fh2/2, false);
            draw_set_alpha(1);
            draw_set_color(c_white);
            draw_text(mx - fw2/2, my - fh2/2 - __bhu(_pid,6), string(P.name));
        }
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
                var do_auto_apply = !(variable_struct_exists(opts, "auto_apply") && variable_struct_get(opts, "auto_apply") == false);
                if (do_auto_apply && !is_undefined(party_ensure)){
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
