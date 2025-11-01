// CutsceneBuilders.gml — helpers to build common cutscene payloads
// This file provides small wrappers that integrate existing battle flows with the
// CutsceneSystem for consistent logging and optional gating without duplicating visuals.

/// Build a non-blocking cutscene payload that monitors a pending player switch
/// until it is applied and the animation phase ends. Does NOT call battle_switch_to.
/// Usage: cutscene_play_now(pid, cutscene_switch_to_build(pid, dstIdx, opts));
function cutscene_switch_to_build(_pid, _dst_idx, _opts){
    var _k = "switch_to:" + string(_pid) + ":" + string(_dst_idx) + ":" + string(is_real(current_time) ? current_time : 0);
    return {
        key: _k,
        gate: "any",
        // Let the underlying battle system advance intro/switch timers; we only observe.
        allow_battle_progress: true,
        on_start: function(pid, item){
            // No-op: this builder observes the in-progress switch; the caller should have already
            // invoked battle_switch_to. We still emit a verbose log for traceability.
            try { __cut_dbg("switch_to monitor start pid=" + string(pid) + ", key=" + string(item.key)); } catch (e) {}
        },
        on_update: function(pid, item, dt_ms){
            var _B = (is_undefined(__battle_ensure_slot) ? undefined : __battle_ensure_slot(pid));
            if (!is_struct(_B)) return true; // nothing to monitor
            var ph = (variable_struct_exists(_B, "phase") ? string(variable_struct_get(_B, "phase")) : "");
            var applied = (variable_struct_exists(_B, "_switch_applied") && variable_struct_get(_B, "_switch_applied"));
            // Consider the switch complete once the apply happened and we have left the switch_in phase.
            if (applied && ph != "switch_in") return true;
            return false;
        },
        on_complete: function(pid, item){
            try { __cut_dbg("switch_to monitor complete pid=" + string(pid) + ", key=" + string(item.key)); } catch (e) {}
        }
    };
}

/// Convenience wrapper: request a switch via battle API and register a non-blocking cutscene
/// item to monitor it until applied. Returns true if the battle accepted the switch request.
function cutscene_switch_to(_pid, _dst_idx, _opts){
    var ok = false;
    try { if (!is_undefined(battle_switch_to)) ok = battle_switch_to(_pid, _dst_idx, _opts); } catch (e) { ok = false; }
    if (ok){
        try { if (!is_undefined(cutscene_play_now)) cutscene_play_now(_pid, cutscene_switch_to_build(_pid, _dst_idx, _opts)); } catch (e2) {}
    }
    return ok;
}
