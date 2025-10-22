// [Battle] battle_impls — Build v0.2.0 — Updated 2025-10-18

// Extracted battle helper implementations to modularize large battle_system.gml
// These functions are internal impls; the public API in battle_system.gml
// continues to expose the original function names and delegates to these.

// --- Backward-compatible fallback shims ---
// Provide small, safe fallbacks for commonly-referenced globals that some
// move/battle code expects to exist. These prefer existing impls when
// available and otherwise provide a no-op or debug-friendly behavior.
try {
    if (is_undefined(dialog_queue)){
        function dialog_queue(_txt){
            // Prefer the battle dialog stub if available
            try { if (!is_undefined(__battle_stub_dialog)) __battle_stub_dialog(0, _txt); else show_debug_message(_txt); } catch (e) { try { show_debug_message(_txt); } catch (e2) {} }
        }
    }
} catch (e_sh) {}

try {
    if (is_undefined(move_get_name)){
        function move_get_name(_id){
            try { if (!is_undefined(scr_move_name_by_id)) return scr_move_name_by_id(_id); } catch (e) {}
            try { return __battle_move_name_impl(_id); } catch (e2) { return "MOVE " + string(_id); }
        }
    }
} catch (e_mgn) {}

try {
    if (is_undefined(move_get_power)){
        function move_get_power(_id){
            try { if (!is_undefined(scr_move_power_by_id)) return scr_move_power_by_id(_id); } catch (e) {}
            try { return __battle_move_power_impl(_id, undefined, undefined); } catch (e2) { return 0; }
        }
    }
} catch (e_mgp) {}

try {
    if (is_undefined(move_get_flags)){
        function move_get_flags(_id){
            // Try to read flags from move meta if available, otherwise fall back to 0
            try {
                if (!is_undefined(__battle_get_move_meta)){
                    var _mm = __battle_get_move_meta(_id);
                    if (is_struct(_mm) && variable_struct_exists(_mm, "flags")) return variable_struct_get(_mm, "flags");
                }
            } catch (e) {}
            try { if (variable_global_exists("_move_flags") && is_array(global._move_flags) && is_real(_id) && _id >= 0 && _id < array_length(global._move_flags)) return global._move_flags[_id]; } catch (e2) {}
            return 0;
        }
    }
} catch (e_mgf) {}

// Minimal flag constants used by a few helpers. Only define if missing so
// we don't overwrite project-specific values.
try { if (!variable_global_exists("MOVE_FLAG_DISABLE")) variable_global_set("MOVE_FLAG_DISABLE", 1); } catch (e) {}
try { if (!variable_global_exists("MOVE_FLAG_DRAIN")) variable_global_set("MOVE_FLAG_DRAIN", 2); } catch (e) {}

// Safe no-op stubs for optional functions referenced by battle code.
try { if (is_undefined("__battle_apply_disable") || is_undefined(__battle_apply_disable)) function __battle_apply_disable(_target, _move) { /* noop fallback */ } } catch (e) {}
try { if (is_undefined("__battle_apply_status_move") || is_undefined(__battle_apply_status_move)) function __battle_apply_status_move(_pid, _user, _target, _move) { /* noop fallback */ } } catch (e) {}
try { if (is_undefined("scr_move_meta_ailment_to_name") || is_undefined(scr_move_meta_ailment_to_name)) function scr_move_meta_ailment_to_name(_id) { return undefined; } } catch (e) {}


function __battle_set_hp_now_impl(_ent, _val){
    var v = (is_real(_val) ? max(0, floor(_val)) : 0);
    try {
        if (is_struct(_ent)){
            if (variable_struct_exists(_ent, "hp_now")) variable_struct_set(_ent, "hp_now", v);
            if (variable_struct_exists(_ent, "hp")) variable_struct_set(_ent, "hp", v);
            // Also mirror to inner mon if present
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
                var mi = variable_struct_get(_ent, "mon");
                if (variable_struct_exists(mi, "hp_now")) variable_struct_set(mi, "hp_now", v);
                if (variable_struct_exists(mi, "hp")) variable_struct_set(mi, "hp", v);
            }
        }
    } catch (e_set){}
}

function __battle_is_fainted_impl(_ent){
    return (__battle_hp_now(_ent) <= 0);
}

function __battle_clear_fainted_if_healed_impl(_ent){
    try {
        if (__battle_hp_now(_ent) > 0){
            if (is_struct(_ent) && variable_struct_exists(_ent, "_fainted")) variable_struct_set(_ent, "_fainted", false);
            if (is_struct(_ent) && variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
                var mi2 = variable_struct_get(_ent, "mon");
                if (variable_struct_exists(mi2, "_fainted")) variable_struct_set(mi2, "_fainted", false);
            }
        }
    } catch (e_clear){}
}

function __battle_calc_damage_impl(_A, _D, _move_id, _power){
    var L = (is_real(_A.level) ? _A.level : 5);
    var Atk = __battle_stat_get(_A, "atk");
    var Def = __battle_stat_get(_D, "def");

    // base formula (Pokémon-like, simplified)
    var base = floor( (((2*L/5 + 2) * _power * Atk) / max(1,Def)) / 50 ) + 2;

    // variance 0.85..1.00
    var variance = 0.85 + random(0.15);
    var dmg = floor(base * variance);

    // crit ~ 1/24
    // crit: base chance ~1/24; allow per-move override via move_meta.crit_rate
    var crit = false;
    try {
        var crit_rate_level = 0;
        // Prefer move meta accessor if present
        if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
            try {
                var _mm = __battle_get_move_meta(_move_id);
                if (is_struct(_mm) && variable_struct_exists(_mm, "crit_rate") && is_real(variable_struct_get(_mm, "crit_rate"))) crit_rate_level = variable_struct_get(_mm, "crit_rate");
            } catch (e_mm) { crit_rate_level = 0; }
        } else if (variable_global_exists("_move_meta") && is_array(global._move_meta) && is_struct(global._move_meta[_move_id])){
            try { var _mm2 = global._move_meta[_move_id]; if (variable_struct_exists(_mm2, "crit_rate") && is_real(variable_struct_get(_mm2, "crit_rate"))) crit_rate_level = variable_struct_get(_mm2, "crit_rate"); } catch (e_m2) { crit_rate_level = 0; }
        }
        // Map crit_rate_level to a sampling denominator (conservative mapping)
        var denom = 24;
        if (is_real(crit_rate_level)){
            if (crit_rate_level <= 0) denom = 24;
            else if (crit_rate_level == 1) denom = 8; // higher crit chance
            else denom = 2; // very high crit chance for larger values
        }
        crit = (irandom(max(1, denom) - 1) == 0);
    } catch (e_crit) { crit = (irandom(23) == 0); }
    var critMul = crit ? 1.5 : 1.0;
    dmg = floor(dmg * critMul);

    // mark crit for message
    var _B = __battle_ensure_slot(0); // any slot; we only read flag in same pid flow
    try { if (is_struct(_B)) variable_struct_set(_B, "_last_crit", crit); } catch (e) {}

    // clamp
    dmg = max(0, dmg);
    return dmg;
}

function __battle_apply_damage_impl(_pid, _target_index, _dmg, _mult){
    var _B = __battle_ensure_slot(_pid);
    var T = undefined;
    try {
        if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
            var _actors_arr = variable_struct_get(_B, "actor");
            if (is_real(_target_index) && _target_index >= 0 && _target_index < array_length(_actors_arr)) T = _actors_arr[_target_index];
        }
    } catch (e_gett) { T = undefined; }
    if (!is_struct(T)) return;
    // If the target has an active Protect-like flag, consume it and skip damage.
    try {
        if (variable_struct_exists(T, "_protected") && variable_struct_get(T, "_protected") == true){
            // Request protected animation for the defender
            __battle_request_animation_safe(_pid, { type: "protected", target_index: _target_index });
            // Mark announce shown and consume protection so it doesn't persist
            variable_struct_set(T, "_protected_announce_shown", true);
            variable_struct_set(T, "_protected", false);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
                try {
                    var _tname_dbg2 = "unknown";
                    if (variable_struct_exists(T, "name")) _tname_dbg2 = variable_struct_get(T, "name");
                    else if (variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon")) && variable_struct_exists(variable_struct_get(T, "mon"), "name")) _tname_dbg2 = variable_struct_get(variable_struct_get(T, "mon"), "name");
                    show_debug_message("[battle][protect][consumed_impl] pid=" + string(_pid) + " target_index=" + string(_target_index) + " name=" + string(_tname_dbg2) + " dmg=" + string(_dmg));
                } catch (e_dbg3) { show_debug_message("[battle][protect][consumed_impl] target_index=" + string(_target_index) + " dmg=" + string(_dmg)); }
            }
            return;
        }
    } catch (e_prot){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][protect] guard error: " + string(e_prot)); }

    var cur_hp = __battle_hp_now(T);
    var newhp = max(0, cur_hp - max(0, round(_dmg * (is_real(_mult) ? _mult : 1))));
    __battle_set_hp_now(T, newhp);
    // If this damage caused a faint, mark the entity and inner mon as fainted
    // and schedule a pending party open on the battle slot so the UI can prompt
    // the player to choose a replacement after dialog closes.
    try {
        if (cur_hp > 0 && newhp <= 0){
            if (is_struct(T) && variable_struct_exists(T, "_fainted")) variable_struct_set(T, "_fainted", true);
            if (is_struct(T) && variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon"))){
                var __mi_f = variable_struct_get(T, "mon");
                if (variable_struct_exists(__mi_f, "_fainted")) variable_struct_set(__mi_f, "_fainted", true);
            }
            // Schedule pending party open on the battle slot so it's handled in battle_system
            try {
                var _B_sch = __battle_ensure_slot(_pid);
                if (is_struct(_B_sch)){
                    variable_struct_set(_B_sch, "_pending_open_party", true);
                    // Ensure the faint dialog has at least one frame to render before
                    // the party UI may open: set a short delay marker the battle
                    // update loop will honor.
                    // Give the faint dialog a slightly longer window to render before
                    // the party UI opens. Increase from 120ms to 300ms to reduce
                    // chances the party menu occludes the faint message on slow
                    // machines or when multiple UI updates occur in the same frame.
                    try { variable_struct_set(_B_sch, "_pending_open_party_delay_until", current_time + 300); } catch (e_pd) {}
                    // Immediately open a faint dialog so the player sees it at the moment of faint
                    try {
                        var _fnt_name = "(Unknown)";
                        if (variable_struct_exists(T, "name")) _fnt_name = variable_struct_get(T, "name");
                        else if (variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon")) && variable_struct_exists(variable_struct_get(T, "mon"), "name")) _fnt_name = variable_struct_get(variable_struct_get(T, "mon"), "name");
                        if (!is_undefined(__battle_stub_dialog)) __battle_stub_dialog(_pid, string(_fnt_name) + " fainted!");
                        else if (!is_undefined(dialog2p_open_text)) dialog2p_open_text(_pid, string(_fnt_name) + " fainted!");
                    } catch (e_sd_local) {}
                    // Mark faint as pending so it takes priority over multi-hit/status messages
                    // We set this after opening the faint dialog so the faint message itself
                    // is not enqueued by dialog2p_open_text.
                    try { variable_struct_set(_B_sch, "_faint_pending", true); } catch (e_fp_local) {}
                    // Store a reference to the fainted actor's inner mon (preferred) so selection
                    // mapping can resolve correctly even after the party is reordered.
                    var _refm = T;
                    if (variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon"))) _refm = variable_struct_get(T, "mon");
                    variable_struct_set(_B_sch, "_pending_open_party_next_mon_ref", _refm);
                    // Preserve current UI menu/selection so we can restore it after forced swap
                    try {
                        if (variable_struct_exists(_B_sch, "sys_ui") && is_struct(variable_struct_get(_B_sch, "sys_ui"))){
                            var _su = variable_struct_get(_B_sch, "sys_ui");
                            // Save menu and selection coordinates
                            if (variable_struct_exists(_su, "menu")) variable_struct_set(_B_sch, "_pending_open_party_prev_menu", variable_struct_get(_su, "menu"));
                            if (variable_struct_exists(_su, "selX")) variable_struct_set(_B_sch, "_pending_open_party_prev_selX", variable_struct_get(_su, "selX"));
                            if (variable_struct_exists(_su, "selY")) variable_struct_set(_B_sch, "_pending_open_party_prev_selY", variable_struct_get(_su, "selY"));
                        }
                    } catch (e_saveui) {}
                    // Also clear any deferred turn resume so we don't accidentally continue
                    // the turn while the party selection is pending.
                    variable_struct_set(_B_sch, "_defer_turn_until_no_dialog", false);
                }
            } catch (e_sch) {}
        }
    } catch (e_pf){}
    // Trigger visual lerp and hit SFX for this applied damage
    try {
        if (is_real(cur_hp) && is_real(newhp) && cur_hp != newhp){
            // Use provided multiplier when available, otherwise default to 1.0
            var use_mult = (is_real(_mult) ? _mult : 1.0);
            try { __battle_trigger_hit_effect(_pid, T, cur_hp, newhp, use_mult); } catch (e_th) { /* removed noisy sound debug */ }
        }
    } catch (e_any) { /* removed noisy sound debug */ }
    // Clear faint flag if healed above 0
    __battle_clear_fainted_if_healed(T);
}

function __battle_move_name_impl(_code){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_name_by_id)) return scr_move_name_by_id(_code);
        return "MOVE " + string(_code);
    }
    return "--";
}

function __battle_move_power_impl(_code, _A, _D){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_power_by_id)){
            var p = scr_move_power_by_id(_code);
            if (is_real(p) && p > 0) return max(0, real(p));
            var vp = __battle_variable_move_power(_code, _A, _D);
            if (is_real(vp) && vp > 0) return vp;
            return 0;
        }
    }
    return 0;
}

function __battle_entity_weight_impl(_ent){
    try {
        if (!is_undefined(_ent) && is_struct(_ent)){
            if (variable_struct_exists(_ent, "weight") && is_real(variable_struct_get(_ent, "weight"))){
                var raww = real(variable_struct_get(_ent, "weight"));
                return __battle_weight_to_kg_impl(raww);
            }
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
                var mi = variable_struct_get(_ent, "mon");
                if (variable_struct_exists(mi, "weight") && is_real(variable_struct_get(mi, "weight"))) return __battle_weight_to_kg_impl(real(variable_struct_get(mi, "weight")));
                if (variable_struct_exists(mi, "species_id") && is_real(variable_struct_get(mi, "species_id"))){
                    var sid = variable_struct_get(mi, "species_id");
                    if (variable_global_exists("_pokemon") && is_array(global._pokemon) && sid >= 0 && sid < array_length(global._pokemon)){
                        var sp = global._pokemon[sid];
                        if (is_struct(sp) && variable_struct_exists(sp, "weight") && is_real(variable_struct_get(sp, "weight"))) return __battle_weight_to_kg_impl(real(variable_struct_get(sp, "weight")));
                    }
                }
            }
        }
    } catch (e_wt){ }
    return 0;
}

function __battle_weight_to_kg_impl(_raw){
    if (!is_real(_raw)) return 0;
    var r = real(_raw);
    if (r <= 0) return 0;
    return r / 10.0;
}

// Register impl functions into a global registry to allow battle_system.gml
// to call them without requiring duplicate script definitions.
function __battle_impls_register_all(){
    try {
        if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
        var _reg = variable_global_get("_battle_impls");
        // Populate known impl entries (add as needed)
        try { variable_struct_set(_reg, "__battle_set_hp_now_impl", __battle_set_hp_now_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_is_fainted_impl", __battle_is_fainted_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_clear_fainted_if_healed_impl", __battle_clear_fainted_if_healed_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_calc_damage_impl", __battle_calc_damage_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_apply_damage_impl", __battle_apply_damage_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_move_name_impl", __battle_move_name_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_move_power_impl", __battle_move_power_impl); } catch (e_reg) {}
        try { variable_struct_set(_reg, "__battle_entity_weight_impl", __battle_entity_weight_impl); } catch (e_reg) {}
        // Optional finalize/catch hook (may be implemented elsewhere). Register a safe placeholder.
        try { variable_struct_set(_reg, "__battle_finalize_catch", undefined); } catch (e_reg) {}
        // Proxy for __battle_perform_action_impl: will call the real impl if/when it's registered
        try {
            variable_struct_set(_reg, "__battle_perform_action_impl", function(_pid,_step){
                try {
                    if (variable_global_exists("_battle_impls") && variable_struct_exists(variable_global_get("_battle_impls"), "__battle_perform_action_impl_real")){
                        var _r = variable_struct_get(variable_global_get("_battle_impls"), "__battle_perform_action_impl_real");
                        if (!is_undefined(_r)) return _r(_pid, _step);
                    }
                } catch (ee) {}
                try { if (!is_undefined(__battle_perform_action_impl)) return __battle_perform_action_impl(_pid, _step); } catch (e2) {}
                return undefined;
            });
        } catch (e_reg2) {}
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_impls][reg] failed: " + string(e)); }
}

// Run once to populate the registry eagerly when this script is first loaded
try { __battle_impls_register_all(); } catch (e_init) {}

function __bui_begin_impl(_pid,_rx,_ry,_rw,_rh){
    var _B = __battle_ensure_slot(_pid);
    var base_w = 240, base_h = 160;
    var sx = _rw / base_w;
    var sy = _rh / base_h;
    var s = min(sx, sy);
    var content_w = floor(base_w * s);
    var content_h = floor(base_h * s);
    var origin_x = _rx + floor((_rw - content_w) / 2);
    var origin_y = _ry + floor((_rh - content_h) / 2);
    try { if (is_struct(_B)) variable_struct_set(_B, "_ui", { rx: origin_x, ry: origin_y, rw: content_w, rh: content_h, base_w: base_w, base_h: base_h, s: s }); } catch (e_ui) {}
}

function __bui_end_impl(_pid){
    var _B = __battle_ensure_slot(_pid);
    try { if (is_struct(_B)) variable_struct_set(_B, "_ui", undefined); } catch (e_ui2) {}
}

// Helper: determine whether a given move id should be ignored by Copycat
function __battle_move_copycat_is_ignored(_move_id){
    try {
        if (!is_real(_move_id)) return true;
        if (!variable_global_exists("_moves") || !is_array(global._moves)) return true;
        if (!is_struct(global._moves[_move_id])) return true;
        var ident = "";
        try { if (variable_struct_exists(global._moves[_move_id], "identifier")) ident = string(variable_struct_get(global._moves[_move_id], "identifier")); } catch (e_i) {}
        ident = string_lower(string(ident));
        // Canonical identifiers that Copycat must skip (kept as identifiers so they're data-stable)
        var ignore_ids = ["assist","metronome","sleep-talk","copycat","mimic","mirror-move","mirror-coat","sketch","me-first","protect","snatch","switcheroo","trick","struggle","encore","follow-me","quick-guard","feint","focus-punch","counter","covet","destiny-bond","detect","endure","chatter","helping-hand","thief","wide-guard","quick-guard","roar","whirlwind","uproar"];
        for (var i=0; i<array_length(ignore_ids); ++i){ if (string_lower(ignore_ids[i]) == ident) return true; }
        // Additional heuristics: if move appears invalid or is flagged as non-damaging in simple metadata, optionally skip.
        // Prefer identifier-based filtering; avoid false-positives by default. If move power lookup exists and returns undefined, don't skip.
        return false;
    } catch (e_any){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat][is_ignored] err="+string(e_any)); return true; }
}

// Helper: find the move id candidate for Copycat for a given user (walks per-target history backwards)
function __battle_find_copycat_candidate(_pid, _user){
    try {
        if (!is_struct(_user)) return undefined;
        var _hist = [];
        try { if (variable_struct_exists(_user, "_last_moves") && is_array(variable_struct_get(_user, "_last_moves"))) _hist = variable_struct_get(_user, "_last_moves"); } catch (e_h) { _hist = []; }
        var _Bslot = __battle_ensure_slot(_pid);
        for (var hi = array_length(_hist)-1; hi >= 0; --hi){
            var rec = _hist[hi];
            if (!is_struct(rec) || !variable_struct_exists(rec, "move")) continue;
            var cand = variable_struct_get(rec, "move");
            if (!is_real(cand)) continue;
            // ignore based on identifier/meta
            if (__battle_move_copycat_is_ignored(cand)){
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat][preview] skipping move id="+string(cand)+" (ignored)");
                continue;
            }
            // ensure source still on-field — be robust to actor-wrapper recreation by matching _uid or inner .mon
            var src = (variable_struct_exists(rec, "src") ? variable_struct_get(rec, "src") : undefined);
            var src_ok = false;
            try {
                if (is_struct(src) && is_struct(_Bslot) && variable_struct_exists(_Bslot, "actor") && is_array(variable_struct_get(_Bslot, "actor"))){
                    var acts = variable_struct_get(_Bslot, "actor");
                    for (var ai=0; ai<array_length(acts); ++ai){
                        var act = acts[ai];
                        if (!is_struct(act)) continue;
                        var matched = false;
                        // Prefer UID matching when available
                        try {
                            if (variable_struct_exists(src, "_uid") && variable_struct_exists(act, "_uid") && is_real(variable_struct_get(src, "_uid")) && is_real(variable_struct_get(act, "_uid"))){
                                if (variable_struct_get(src, "_uid") == variable_struct_get(act, "_uid")) matched = true;
                            }
                        } catch (e_uidm) {}
                        // Fallback to direct struct equality
                        if (!matched && act == src) matched = true;
                        // Fallback to inner mon equality (sometimes stored src could be .mon)
                        if (!matched){
                            try {
                                if (variable_struct_exists(src, "mon") && variable_struct_exists(act, "mon") && variable_struct_get(src, "mon") == variable_struct_get(act, "mon")) matched = true;
                            } catch (e_mon) {}
                        }
                        if (matched){ try { if (__battle_hp_now(act) > 0) src_ok = true; else src_ok = false; } catch (e_chk) { src_ok = true; } break; }
                    }
                }
            } catch (e_s) { src_ok = false; }
            if (!src_ok){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat][preview] skipping move id="+string(cand)+" (source gone)"); continue; }
            return cand;
        }
    } catch (e_all){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat][find] error: " + string(e_all)); }
    return undefined;
}

// Debug helper: print the _last_moves history for an actor struct
function __battle_dbg_dump_last_moves(_actor){
    try {
        if (!is_struct(_actor)) { show_debug_message("[battle][dbg] actor not a struct"); return; }
        if (!variable_struct_exists(_actor, "_last_moves") || !is_array(variable_struct_get(_actor, "_last_moves"))){ show_debug_message("[battle][dbg] no _last_moves present"); return; }
        var arr = variable_struct_get(_actor, "_last_moves");
        show_debug_message("[battle][dbg] _last_moves len=" + string(array_length(arr)));
        for (var i=0;i<array_length(arr);++i){ var r=arr[i]; if (!is_struct(r)) continue; var mv=(variable_struct_exists(r,"move")?string(variable_struct_get(r,"move")):"?"); var src=(variable_struct_exists(r,"src") && variable_struct_exists(variable_struct_get(r,"src"),"name") ? variable_struct_get(variable_struct_get(r,"src"),"name") : "?"); var ts=(variable_struct_exists(r,"ts")?string(r.ts):"?"); show_debug_message("  ["+string(i)+"] move="+mv+" src="+src+" ts="+ts); }
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][dbg] dump failed: " + string(e)); }
}

function __bxu_impl(_pid,_xv){
    var _slot = __battle_ensure_slot(_pid);
    var _u = (is_struct(_slot) && variable_struct_exists(_slot, "_ui") ? variable_struct_get(_slot, "_ui") : undefined);
    if (is_undefined(_u)) return _xv;
    return floor(variable_struct_exists(_u, "rx") ? variable_struct_get(_u, "rx") + _xv * variable_struct_get(_u, "s") : _xv);
}

function __byu_impl(_pid,_yv){
    var _slot = __battle_ensure_slot(_pid);
    var _u = (is_struct(_slot) && variable_struct_exists(_slot, "_ui") ? variable_struct_get(_slot, "_ui") : undefined);
    if (is_undefined(_u)) return _yv;
    return floor(variable_struct_exists(_u, "ry") ? variable_struct_get(_u, "ry") + _yv * variable_struct_get(_u, "s") : _yv);
}

function __bwu_impl(_pid,_wv){
    var _slot = __battle_ensure_slot(_pid);
    var _u = (is_struct(_slot) && variable_struct_exists(_slot, "_ui") ? variable_struct_get(_slot, "_ui") : undefined);
    if (is_undefined(_u)) return _wv;
    return floor(_wv * (variable_struct_exists(_u, "s") ? variable_struct_get(_u, "s") : 1));
}

function __bhu_impl(_pid,_hv){
    var _slot = __battle_ensure_slot(_pid);
    var _u = (is_struct(_slot) && variable_struct_exists(_slot, "_ui") ? variable_struct_get(_slot, "_ui") : undefined);
    if (is_undefined(_u)) return _hv;
    return floor(_hv * (variable_struct_exists(_u, "s") ? variable_struct_get(_u, "s") : 1));
}


// [FORCE FIX] __battle_apply_move with full Copycat control
function __battle_apply_move(_pid, _user, _target, _move){
    if (!__battle_check_can_act(_user)) return;

    var _flags = move_get_flags(_move);
    // Read global flag masks into locals to avoid bare global symbol references
    var FLAG_DISABLE = (variable_global_exists("MOVE_FLAG_DISABLE") ? variable_global_get("MOVE_FLAG_DISABLE") : 1);
    var FLAG_DRAIN = (variable_global_exists("MOVE_FLAG_DRAIN") ? variable_global_get("MOVE_FLAG_DRAIN") : 2);

    // === DISABLED MOVE ===
    var _disabledMove = undefined;
    try { if (is_struct(_user) && variable_struct_exists(_user, "sys_disabledMove")) _disabledMove = variable_struct_get(_user, "sys_disabledMove"); } catch (e_dm) { _disabledMove = undefined; }
    if (is_real(_disabledMove) && _disabledMove == _move){
        var _uname = (is_struct(_user) && variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user");
        dialog_queue(_uname + " is disabled and can't use that move!");
        return;
    }

    

    // === COPYCAT: improved, per-target lookup (delegated to helper) ===
    var _moveEntry = undefined;
    try { if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move) && _move >= 0 && _move < array_length(global._moves)) _moveEntry = global._moves[_move]; } catch (e_me) { _moveEntry = undefined; }
    var _isCopycatMove = false;
    try { if (is_struct(_moveEntry) && variable_struct_exists(_moveEntry, "identifier") && string_lower(variable_struct_get(_moveEntry, "identifier")) == "copycat") _isCopycatMove = true; } catch (e_ic) { _isCopycatMove = false; }
    if (_isCopycatMove){
        // Simple Copycat semantics: copy the global last move used in the battle when available
        var _copiedMove = undefined;
        try { if (variable_global_exists("lastMoveUsed_ID") && !is_undefined(global.lastMoveUsed_ID) && is_real(global.lastMoveUsed_ID) && global.lastMoveUsed_ID >= 0 && global.lastMoveUsed_ID != _move) _copiedMove = global.lastMoveUsed_ID; } catch (e_cp) { _copiedMove = undefined; }
        if (!is_real(_copiedMove)){
            dialog_queue(_user.name + " failed to Copycat!");
            return;
        }
        var _copiedName = (is_undefined(move_get_name) ? __battle_move_name_impl(_copiedMove) : move_get_name(_copiedMove));
        dialog_queue(_user.name + " used " + _copiedName + "!");
        try { variable_struct_set(_user, "_suppress_last_move_record", true); } catch (e_s1) {}
        try { __battle_apply_move(_pid, _user, _target, _copiedMove); } catch (e_replay){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat] replay failed: " + string(e_replay)); }
        try { if (variable_struct_exists(_user, "_suppress_last_move_record")) variable_struct_set(_user, "_suppress_last_move_record", false); } catch (e_s2) {}
        return;
    }

    // === RECORD LAST MOVE USED ===
    if (!_isCopycatMove){
        global.lastMoveUsed_ID = _move;
        var _moveName = move_get_name(_move);
        dialog_queue(_user.name + " used " + _moveName + "!");
        // Also record per-target history for Copycat's reference (unless suppressed)
        try {
            var _suppress = (variable_struct_exists(_user, "_suppress_last_move_record") && variable_struct_get(_user, "_suppress_last_move_record") == true);
        } catch (e_sup2){ var _suppress = false; }
        if (!(_suppress)){
            try {
                if (is_struct(_target)){
                    if (!variable_struct_exists(_target, "_last_moves") || !is_array(variable_struct_get(_target, "_last_moves"))) variable_struct_set(_target, "_last_moves", []);
                    var _arr2 = variable_struct_get(_target, "_last_moves");
                    array_push(_arr2, { move: _move, src: _user, ts: current_time });
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                        try { if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][record_last_move] target=" + string(variable_struct_exists(_target, "name") ? variable_struct_get(_target, "name") : "?") + " move=" + string(_move) + " src=" + string(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "?") + " ts=" + string(current_time)); } catch (e_dbg) {}
                    }
                    if (array_length(_arr2) > 8){ var _start2 = array_length(_arr2) - 8; var _new2 = []; for (var _ki2 = _start2; _ki2 < array_length(_arr2); ++_ki2) array_push(_new2, _arr2[_ki2]); _arr2 = _new2; }
                    variable_struct_set(_target, "_last_moves", _arr2);
                }
            } catch (e_rec2){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][record_last_move2] failed: " + string(e_rec2)); }
        }
    }

    // === DISABLE FLAG ===
    if (_flags & FLAG_DISABLE){
        __battle_apply_disable(_target, _move);
        dialog_queue(_target.name + " was disabled!");
        return;
    }

    // === PROTECTED FLAG ===
    var _t_protected = false;
    try { if (is_struct(_target) && variable_struct_exists(_target, "sys_protected") && variable_struct_get(_target, "sys_protected") == true) _t_protected = true; } catch (e_tp) { _t_protected = false; }
    if (_t_protected){
        var _tname = (is_struct(_target) && variable_struct_exists(_target, "name") ? variable_struct_get(_target, "name") : "The target");
        dialog_queue(_tname + " protected itself!");
        return;
    }


    // === SEMI-INVULNERABLE CHECK ===
    try {
        if (is_struct(_target) && variable_struct_exists(_target, "_semi_invuln") && !is_undefined(variable_struct_get(_target, "_semi_invuln"))){
            var _phase = string_lower(string(variable_struct_get(_target, "_semi_invuln")));
            var _mname = string_lower(__battle_move_name(_move));
            var _allow = false; var _mult = 1.0;
            if (_phase == "fly"){
                if (string_pos("gust", _mname) > 0 || string_pos("twister", _mname) > 0) { _allow = true; _mult = 2.0; }
            } else if (_phase == "dig"){
                if (string_pos("earthquake", _mname) > 0 || string_pos("magnitude", _mname) > 0) { _allow = true; _mult = 2.0; }
            } else if (_phase == "dive"){
                if (string_pos("surf", _mname) > 0 || string_pos("whirlpool", _mname) > 0) { _allow = true; _mult = 2.0; }
            } else if (_phase == "bounce"){
                if (string_pos("gust", _mname) > 0 || string_pos("twister", _mname) > 0) { _allow = true; _mult = 2.0; }
            }
            if (!_allow){
                dialog_queue(_user.name + "'s attack missed!");
                return;
            } else {
                // Stash multiplier for this strike (consumed below)
                var _semi_invuln_mult = _mult;
                // Store on user temp field to carry through to apply call if needed
                try { variable_struct_set(_user, "__semi_mult_tmp", _semi_invuln_mult); } catch (e_sm) {}
            }
        }
    } catch (e_si) {}
    // === ACCURACY CHECK ===
    if (!__battle_can_hit_target(_user, _target, _move)){
        dialog_queue(_user.name + "'s attack missed!");
        return;
    }

    // === STATUS MOVE ===
    var _power = move_get_power(_move);
    if (_power <= 0){
        __battle_apply_status_move(_pid, _user, _target, _move);
        return;
    }

    // === DAMAGE + ANIM ===
    __battle_request_animation_safe(_pid, { type: "move", user: _user, target: _target, move_id: _move });
    var _dmg = __battle_calc_damage(_user, _target, _move, move_get_power(_move));
    // Resolve target index robustly: prefer explicit actor_index, then 'slot',
    // then attempt to locate the target object in the battle slot actor array.
    var _tidx = undefined;
    try {
        if (is_struct(_target) && variable_struct_exists(_target, "actor_index") && is_real(variable_struct_get(_target, "actor_index"))) _tidx = variable_struct_get(_target, "actor_index");
        else if (is_struct(_target) && variable_struct_exists(_target, "slot") && is_real(variable_struct_get(_target, "slot"))) _tidx = variable_struct_get(_target, "slot");
        else {
            var _Btmp_try = __battle_ensure_slot(_pid);
            if (is_struct(_Btmp_try) && variable_struct_exists(_Btmp_try, "actor") && is_array(variable_struct_get(_Btmp_try, "actor")) && is_struct(_target)){
                var __actor_arr_try = variable_struct_get(_Btmp_try, "actor");
                for (var _ai_try = 0; _ai_try < array_length(__actor_arr_try); ++_ai_try){ if (is_struct(__actor_arr_try[_ai_try]) && __actor_arr_try[_ai_try] == _target){ _tidx = _ai_try; break; } }
            }
        }
    } catch (e_ti) { _tidx = undefined; }
    if (!is_real(_tidx)) _tidx = 0; // safe fallback
    var _semim = 1.0;
    try { if (variable_struct_exists(_user, "__semi_mult_tmp")) { _semim = max(1.0, real(variable_struct_get(_user, "__semi_mult_tmp"))); variable_struct_set(_user, "__semi_mult_tmp", undefined); } } catch (e_sm2) {}
    __battle_apply_damage(_pid, _tidx, _dmg, _semim);

    // === APPLY AILMENT / FLINCH / STAT EFFECTS FROM move_meta ===
    try {
        var _mm = undefined;
        if (!is_undefined(__battle_get_move_meta) && is_real(_move)){
            try { _mm = __battle_get_move_meta(_move); } catch (e_m) { _mm = undefined; }
        } else if (variable_global_exists("_move_meta") && is_array(global._move_meta) && _move >= 0 && _move < array_length(global._move_meta)){
            try { _mm = global._move_meta[_move]; } catch (e_gm2) { _mm = undefined; }
        }
        if (is_struct(_mm)){
            // Ailment application
            try {
                var ail_id = (variable_struct_exists(_mm, "meta_ailment_id") ? variable_struct_get(_mm, "meta_ailment_id") : undefined);
                var ach = (variable_struct_exists(_mm, "ailment_chance") && is_real(variable_struct_get(_mm, "ailment_chance"))) ? floor(variable_struct_get(_mm, "ailment_chance")) : 0;
                if (is_real(ail_id) && ail_id > 0 && ach > 0 && !is_undefined(status_system_apply_status)){
                    // Attempt to resolve ailment name for clearer debug output
                    var sname_dbg = undefined;
                    try { if (!is_undefined(scr_move_meta_ailment_to_name)) sname_dbg = scr_move_meta_ailment_to_name(ail_id); } catch (e_sdbg) { sname_dbg = undefined; }
                    if (is_undefined(sname_dbg) && variable_global_exists("_move_meta_ailments") && is_array(global._move_meta_ailments) && ail_id < array_length(global._move_meta_ailments)){
                        try { var _amn_dbg = global._move_meta_ailments[ail_id]; if (is_struct(_amn_dbg) && variable_struct_exists(_amn_dbg, "name")) sname_dbg = variable_struct_get(_amn_dbg, "name"); } catch (e_amdbg) { sname_dbg = undefined; }
                    }
                    // If Water Pledge double-effect is active for user's side, double the chance
                    try {
                        var _Bslot_local = __battle_ensure_slot(_pid);
                        if (is_struct(_Bslot_local) && variable_struct_exists(_Bslot_local, "_pledge_flags") && is_struct(variable_struct_get(_Bslot_local, "_pledge_flags"))){
                            var pf_local = variable_struct_get(_Bslot_local, "_pledge_flags");
                            var user_side = (variable_struct_exists(_user, "actor_index") && variable_struct_get(_user, "actor_index") == 0) ? 0 : 1;
                            var wk = "water_pledge_double_effect_side_" + string(user_side);
                            if (variable_struct_exists(pf_local, wk) && is_real(variable_struct_get(pf_local, wk)) && variable_struct_get(pf_local, wk) > 0){
                                ach = min(100, floor(ach * 2));
                            }
                        }
                    } catch (e_pfd) {}
                    var roll = irandom(99);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] ailment attempt for move=" + string(_move) + ", id=" + string(ail_id) + ", name=" + string(sname_dbg) + ", chance=" + string(ach) + ", roll=" + string(roll));
                    if (roll < ach){
                        // Map ailment id to status name if helper exists
                        var sname = undefined;
                        try { if (!is_undefined(scr_move_meta_ailment_to_name)) sname = scr_move_meta_ailment_to_name(ail_id); } catch (e_sm) { sname = undefined; }
                        // Fallback: try global._move_meta_ailments mapping
                        if (is_undefined(sname) && variable_global_exists("_move_meta_ailments") && is_array(global._move_meta_ailments) && ail_id < array_length(global._move_meta_ailments)){
                            try { var _amn = global._move_meta_ailments[ail_id]; if (is_struct(_amn) && variable_struct_exists(_amn, "name")) sname = variable_struct_get(_amn, "name"); } catch (e_am) { sname = undefined; }
                        }
                        if (!is_undefined(sname) && is_string(sname) && string_length(sname) > 0){
                            try { status_system_apply_status(_target, string_lower(sname), { source: _user }); } catch (e_ss) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status apply failed: " + string(e_ss)); }
                        } else {
                            // If we couldn't map name, attempt to apply common named statuses by id heuristics
                            try {
                                // common ailment ids: 1=sleep,2=poison,3=burn,4=freeze,5=paralysis,6=confuse,8=trap
                                var cand = undefined;
                                if (is_real(ail_id)){
                                    switch(floor(ail_id)){
                                        case 1: cand = "sleep"; break;
                                        case 2: cand = "poison"; break;
                                        case 3: cand = "burn"; break;
                                        case 4: cand = "freeze"; break;
                                        case 5: cand = "paralyze"; break;
                                        case 6: cand = "confusion"; break;
                                    }
                                }
                                if (!is_undefined(cand)) try { status_system_apply_status(_target, cand, { source: _user }); } catch (e_ss2) {}
                            } catch (e_apply) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] ailment apply heuristics failed: " + string(e_apply)); }
                        }
                    }
                }
            } catch (e_a) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] ailment handler error: " + string(e_a)); }
        }
    } catch (e_any) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] post-dmg apply failed: " + string(e_any)); }

    // === DRAIN FLAG ===
    if (_flags & FLAG_DRAIN){
        var _heal = ceil(_dmg * 0.5);
        _user.hp = min(_user.hp + _heal, _user.hp_max);
        dialog_queue(_user.name + " absorbed health!");
    }

    _user.sys_lastMoveUsed = _move;
}


function __battle_check_can_act(_user){
    // Safely read status fields from the actor struct to avoid runtime errors
    var _status = undefined; var _status_turns = 0;
    try {
        if (is_struct(_user) && variable_struct_exists(_user, "sys_status")) _status = variable_struct_get(_user, "sys_status");
        if (is_struct(_user) && variable_struct_exists(_user, "sys_status_turns")) _status_turns = variable_struct_get(_user, "sys_status_turns");
    } catch (e_st) { _status = undefined; _status_turns = 0; }

    switch (_status){
        case "freeze":
            if (irandom(3) < 3){
                try { dialog_queue(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user" + " is frozen solid!"); } catch (e) { dialog_queue("The user is frozen solid!"); }
                return false;
            } else {
                try { dialog_queue(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user" + " thawed out!"); } catch (e) { dialog_queue("The user thawed out!"); }
                try { if (is_struct(_user)) variable_struct_set(_user, "sys_status", undefined); } catch (e2) {}
                return true;
            }
        case "sleep":
            if (_status_turns > 0){
                try { dialog_queue(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user" + " is fast asleep..."); } catch (e) { dialog_queue("The user is fast asleep..."); }
                try { if (is_struct(_user)) variable_struct_set(_user, "sys_status_turns", max(0, _status_turns - 1)); } catch (e2) {}
                return false;
            } else {
                try { dialog_queue(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user" + " woke up!"); } catch (e) { dialog_queue("The user woke up!"); }
                try { if (is_struct(_user)) variable_struct_set(_user, "sys_status", undefined); } catch (e2) {}
                return true;
            }
        case "paralyze":
            if (irandom(3) == 0){
                try { dialog_queue(variable_struct_exists(_user, "name") ? variable_struct_get(_user, "name") : "The user" + " is paralyzed! It can't move!"); } catch (e) { dialog_queue("The user is paralyzed! It can't move!"); }
                return false;
            }
            return true;
        default:
            return true;
    }
}