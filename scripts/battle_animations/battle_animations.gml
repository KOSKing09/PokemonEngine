// battle_animations.gml
// Modular animation helpers for the battle system (catch/throw/shake)
// Provides: __battle_anim_create_catch(_B, _item_id, _caught_struct, _opts)
//           __battle_anim_update(_B)
//           __battle_anim_get_draw_state(_B)

function __battle_anim_create_catch(_B, _item_id, _caught_struct, _opts){
        if (!is_struct(_B)) return undefined;
        var _local_opts = (argument_count > 3 && is_struct(_opts)) ? _opts : {};
    var now = current_time;
    var ball_spr = undefined;
    if (!is_undefined(pkicons_get_item_icon_by_id) && is_real(_item_id) && _item_id > 0){
        try { var s_try = pkicons_get_item_icon_by_id(floor(_item_id)); if (!is_undefined(s_try) && sprite_exists(s_try)) ball_spr = s_try; } catch (e) { ball_spr = undefined; }
    }

    var hop_total = (variable_struct_exists(_local_opts, "hop_total") ? max(1, floor(variable_struct_get(_local_opts, "hop_total"))) : 3);
    var success = (variable_struct_exists(_local_opts, "success") ? (variable_struct_get(_local_opts, "success") == true) : false);
    var break_hop = (variable_struct_exists(_local_opts, "break_hop") ? floor(variable_struct_get(_local_opts, "break_hop")) : 0);
    // when success is true, we require final hop; if break_hop is not provided and failure, pick random
    if (!success && break_hop <= 0) break_hop = irandom(hop_total - 1) + 1;
    if (success) break_hop = 0;

    var ca = {
        active: true,
        start_ms: now,
        phase: "throw",
    throw_dur: (variable_struct_exists(_local_opts, "throw_dur") ? variable_struct_get(_local_opts, "throw_dur") : 380),
    impact_dur: (variable_struct_exists(_local_opts, "impact_dur") ? variable_struct_get(_local_opts, "impact_dur") : 220),
        hop_total: hop_total,
        hop_index: 0,
    hop_dur: (variable_struct_exists(_local_opts, "hop_dur") ? variable_struct_get(_local_opts, "hop_dur") : 700),
    hop_pause: (variable_struct_exists(_local_opts, "hop_pause") ? variable_struct_get(_local_opts, "hop_pause") : 350),
    catch_hop_success: (success ? hop_total : 0),
    break_hop: break_hop,
    outcome: success,
        ball_sprite: (is_undefined(ball_spr) ? (variable_global_exists("sbagpokeball") ? sbagpokeball : undefined) : ball_spr),
        ball_frame: 0,
        start_x: undefined,
        start_y: undefined,
        target_x: undefined,
        target_y: undefined,
        enemy_orig_scale: undefined,
        enemy_scale_now: undefined,
        caught_struct: _caught_struct
    };

        variable_struct_set(_B, "_catch_anim", ca);
        return ca;
    }

// Simple battle animations module
// Provides: __battle_anim_update(_B) -> progresses animations
//           __battle_anim_draw(_pid) -> draws current animation state

function __battle_anim_update(_B){
    // Accept pid or slot
    var _slot = _B;
    if (is_real(_B)) _slot = __battle_ensure_slot(_B);
    if (!is_struct(_slot)) return { resolved:false };
    if (!variable_struct_exists(_slot, "sys_anim") || !is_struct(variable_struct_get(_slot, "sys_anim"))) return { resolved:false };
    var sa = variable_struct_get(_slot, "sys_anim");
    var active = (variable_struct_exists(sa, "active") ? variable_struct_get(sa, "active") : []);
    var current = (variable_struct_exists(sa, "current") ? variable_struct_get(sa, "current") : undefined);

    // If no current and there's an active, pop one
    if (!is_struct(current) && is_array(active) && array_length(active) > 0){
        var next = active[0];
        // remove from active
        var newarr = [];
        for (var ii=1; ii<array_length(active); ++ii) newarr[array_length(newarr)] = active[ii];
        variable_struct_set(sa, "active", newarr);
        // current spec
        var now = current_time;
        var dur = (is_struct(next) && variable_struct_exists(next, "duration") ? variable_struct_get(next, "duration") : 700);
        variable_struct_set(sa, "current", { spec: next, start: now, dur: dur, active: true });
        variable_struct_set(_slot, "sys_anim", sa);
        return { resolved:false };
    }

    if (is_struct(current) && variable_struct_exists(current, "active") && current.active){
        var now2 = current_time;
        var elapsed = now2 - (variable_struct_exists(current, "start") ? current.start : now2);
        if (elapsed >= (variable_struct_exists(current, "dur") ? current.dur : 0)){
            variable_struct_set(sa, "current", undefined);
            variable_struct_set(_slot, "sys_anim", sa);
            return { resolved:true, action: (is_struct(current.spec) && variable_struct_exists(current.spec, "action") ? variable_struct_get(current.spec, "action") : undefined) };
        }
    }
    return { resolved:false };
}

// Returns a small draw state struct consumed by battle_draw.gml
function __battle_anim_get_draw_state(_B){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_catch_anim")) return undefined;
    var A = variable_struct_get(_B, "_catch_anim");
    if (!is_struct(A)) return undefined;
    var out = { phase: string(A.phase), hop_index: (variable_struct_exists(A, "hop_index") ? A.hop_index : 0), hop_total: (variable_struct_exists(A, "hop_total") ? A.hop_total : 0), ball_sprite: A.ball_sprite, ball_frame: (variable_struct_exists(A, "ball_frame") ? A.ball_frame : 0), bounce:0 };
    // compute a simple fractional progress for the current hop if in shake
    if (string(A.phase) == "shake"){
        var now = current_time;
        var e2 = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
        var hop_dur = (variable_struct_exists(A, "hop_dur") ? max(1, real(A.hop_dur)) : 320);
        var hop_pause = (variable_struct_exists(A, "hop_pause") ? max(0, real(A.hop_pause)) : 180);
        var cycle = hop_dur + hop_pause;
        var phaseFr = clamp((hop_dur > 0 ? max(0, min(1, e2 / cycle * (hop_dur / cycle))) : 0), 0, 1);
        out.bounce = sin(phaseFr * pi) * 8;
    }
        return out;
    }
	


function __battle_anim_draw(_pid){
    if (!battle_is_open(_pid)) return;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "sys_anim")) return;
    var sa = variable_struct_get(_B, "sys_anim");
    var cur = (variable_struct_exists(sa, "current") ? variable_struct_get(sa, "current") : undefined);
    if (!is_struct(cur) || !variable_struct_exists(cur, "spec")) return;
    var spec = cur.spec;
    var now = current_time;
    var elapsed = now - (variable_struct_exists(cur, "start") ? cur.start : now);
    var frac_v = 0;
    if (variable_struct_exists(cur, "dur") && cur.dur > 0) frac_v = clamp(elapsed / cur.dur, 0, 1);

    // Draw different visuals by spec.type
    var t = (variable_struct_exists(spec, "type") ? string(variable_struct_get(spec, "type")) : "unknown");
    draw_set_color(c_white);
    draw_set_alpha(1);
    // choose target coords: default to player or enemy centers
    var tx = 120; var ty = 80;
    if (variable_struct_exists(spec, "target_index")){
        var idx = variable_struct_get(spec, "target_index");
        if (idx == 0){ tx = __bxu(_pid, 64); ty = __byu(_pid, 112); } else { tx = __bxu(_pid, 165); ty = __byu(_pid, 40); }
    }

    if (t == "status_inflict" || t == "status_apply"){
        var st = (variable_struct_exists(spec, "status") ? string(variable_struct_get(spec, "status")) : "");
        // draw small status name above target, fade out
    var alpha = 1 - frac_v;
        draw_set_alpha(alpha);
        draw_set_color(c_black);
        draw_rectangle(tx-30, ty-38, tx+30, ty-18, false);
        draw_set_color(c_white);
        draw_text(tx-24, ty-36, string_upper(st));
        draw_set_alpha(1);
    } else if (t == "status_tick_damage" || t == "confusion_hit"){
        var amt = (variable_struct_exists(spec, "amount") ? string(variable_struct_get(spec, "amount")) : "");
        // pop-up damage text
    var y_off = - (frac_v * 20);
        draw_set_color(c_red);
        draw_text(tx, ty + y_off, "-" + string(amt));
        draw_set_color(c_white);
    } else if (t == "status_blocked"){
        var st2 = (variable_struct_exists(spec, "status") ? string(variable_struct_get(spec, "status")) : "");
    draw_set_color(c_yellow);
    draw_text(tx-24, ty-36, string_upper(st2) + "!");
        draw_set_color(c_white);
    } else {
        // generic: small translucent filled dot; if DATA_DEBUG is enabled, log the unexpected spec
        if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE){
            try { show_debug_message("[battle][anim] generic spec=" + string(spec)); } catch (e) {}
        }
        var alpha2 = 0.6 * (1 - frac_v);
        draw_set_alpha(alpha2);
        draw_set_color(c_white);
        draw_circle(tx, ty, 3, true);
        draw_set_alpha(1);
    }
}

