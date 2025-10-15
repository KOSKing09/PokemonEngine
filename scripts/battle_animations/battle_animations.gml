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

// Update animations on the battle slot. Returns { resolved:boolean, action:string }
function __battle_anim_update(_B){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_catch_anim")) return { resolved:false, action:"none" };
    var A = variable_struct_get(_B, "_catch_anim");
    if (!is_struct(A) || !variable_struct_exists(A, "active") || !A.active) return { resolved:false, action:"none" };

    var now = current_time;
    var elapsed = now - (variable_struct_exists(A, "start_ms") ? A.start_ms : now);

    if (string(A.phase) == "throw"){
        if (elapsed >= A.throw_dur){ A.phase = "impact"; A.phase_start = now; }
        return { resolved:false, action:"none" };
    }
    if (string(A.phase) == "impact"){
        var e = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
        if (e >= A.impact_dur){ A.phase = "shake"; A.phase_start = now; }
        return { resolved:false, action:"none" };
    }
    if (string(A.phase) == "shake"){
        var e2 = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
        var hop_dur = (variable_struct_exists(A, "hop_dur") ? max(1, real(A.hop_dur)) : 320);
        var hop_pause = (variable_struct_exists(A, "hop_pause") ? max(0, real(A.hop_pause)) : 180);
        var cycle = hop_dur + hop_pause;
        if (!variable_struct_exists(A, "hop_index") || A.hop_index <= 0){ A.hop_index = 1; A.phase_start = now; e2 = 0; }
        if (e2 >= cycle){
            if (variable_struct_exists(A, "outcome") && A.outcome){
                if (variable_struct_exists(A, "hop_total") && A.hop_index < A.hop_total){ A.hop_index += 1; A.phase_start = now; }
                else { A.phase = "resolve"; A.phase_start = now; return { resolved:true, action:"caught" }; }
            } else {
                var _bh = (variable_struct_exists(A, "break_hop") ? A.break_hop : 0);
                if (is_real(_bh) && _bh == A.hop_index){ A.phase = "escape"; A.phase_start = now; A.escape_dur = 320; return { resolved:true, action:"broke" }; }
                else if (variable_struct_exists(A, "hop_total") && A.hop_index < A.hop_total){ A.hop_index += 1; A.phase_start = now; }
                else { A.phase = "escape"; A.phase_start = now; A.escape_dur = 320; return { resolved:true, action:"broke" }; }
            }
        }
        variable_struct_set(_B, "_catch_anim", A);
        return { resolved:false, action:"none" };
    }
    if (string(A.phase) == "resolve"){
        if (variable_struct_exists(A, "outcome") && A.outcome){
            // success: finalize
            variable_struct_set(_B, "_pending_caught_struct", A.caught_struct);
            // keep the catch_anim struct for draw to show 'caught' visual; caller may clear it
            return { resolved:true, action:"caught" };
        } else {
            // fallback to broke
            return { resolved:true, action:"broke" };
        }
    }
    if (string(A.phase) == "escape"){
        var e5 = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
        if (e5 >= (is_real(A.escape_dur) ? A.escape_dur : 320)){
            // clear
            variable_struct_set(_B, "_catch_anim", undefined);
            return { resolved:true, action:"broke" };
        }
        return { resolved:false, action:"none" };
    }
    return { resolved:false, action:"none" };
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
