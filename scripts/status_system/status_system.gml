// Status System v1.0 — clean single-file implementation
// Uses global.STATUS_SYS to avoid colliding with a script resource named 'status_system'
if (!variable_global_exists("STATUS_SYS")) global.STATUS_SYS = { version: "1.0", registry: {}, ids: [] };

function status_system_register(id, meta){
    if (!is_string(id) || string_length(id) == 0) return false;
    // Read existing registry value (could be a struct, an array, or a ds_map handle)
    var _reg_val = undefined;
    if (variable_struct_exists(global.STATUS_SYS, "registry")) _reg_val = variable_struct_get(global.STATUS_SYS, "registry");

    if (is_struct(_reg_val)){
        // struct: set field
        variable_struct_set(_reg_val, id, meta);
        variable_struct_set(global.STATUS_SYS, "registry", _reg_val);
    } else if (is_array(_reg_val)){
        // convert array to struct and set
        var _newreg = {};
        variable_struct_set(_newreg, id, meta);
        variable_struct_set(global.STATUS_SYS, "registry", _newreg);
    } else if (is_real(_reg_val) && ds_exists(_reg_val, ds_type_map)){
        // ds_map handle: replace/add key
        try { ds_map_replace(_reg_val, id, meta); } catch (e) { ds_map_add(_reg_val, id, meta); }
    } else {
        // fallback: create a struct registry
        var _newreg2 = {};
        variable_struct_set(_newreg2, id, meta);
        variable_struct_set(global.STATUS_SYS, "registry", _newreg2);
    }
    if (!is_array(global.STATUS_SYS.ids)) global.STATUS_SYS.ids = [];
    var found = false;
    for (var i = 0; i < array_length(global.STATUS_SYS.ids); ++i) if (global.STATUS_SYS.ids[i] == id) { found = true; break; }
    if (!found) global.STATUS_SYS.ids[array_length(global.STATUS_SYS.ids)] = id;
    return true;
}

function status_system_ensure_mon(mon){
    if (!is_struct(mon)) return false;
    if (!variable_struct_exists(mon, "statuses")) variable_struct_set(mon, "statuses", {});
    return true;
}

// Remove a status key from a mon's `statuses` struct in a safe way.
// GameMaker doesn't have a direct 'delete field' operation on structs, so
// we rebuild a new struct copying only valid entries. We use the known
// registry ids list as the authoritative set of status keys to preserve.
function __status_remove_key_from_statuses_struct(target_mon, key_to_remove){
    if (!is_struct(target_mon)) return;
    if (!variable_struct_exists(target_mon, "statuses")) return;
    var ss_old = variable_struct_get(target_mon, "statuses");
    if (!is_struct(ss_old)){
        // Nothing usable here, reset to empty
        variable_struct_set(target_mon, "statuses", {});
        return;
    }
    var newss = {};
    var ids = (variable_global_exists("STATUS_SYS") && is_array(global.STATUS_SYS.ids)) ? global.STATUS_SYS.ids : [];
    // Copy only entries that are defined and non-undefined from the known ids list.
    for (var _ii = 0; _ii < array_length(ids); ++_ii){
        var _k = ids[_ii];
        // Don't copy the key we're trying to remove
        if (_k == key_to_remove) continue;
        if (!variable_struct_exists(ss_old, _k)) continue;
        var _v = variable_struct_get(ss_old, _k);
        if (is_undefined(_v)) continue;
        variable_struct_set(newss, _k, _v);
    }
    // Assign the rebuilt struct back onto the target mon
    variable_struct_set(target_mon, "statuses", newss);
}

function status_system_apply_status(mon, status_id, opts){
    // Determine canonical storage target. If caller passed an actor wrapper (with .mon),
    // we'll try to store statuses on that actor wrapper when possible. If caller passed
    // an inner `mon`, and that mon is currently present in a battle, prefer storing on
    // the battle actor wrapper so battle pre-checks (which usually reference the actor)
    // will observe the status.
    // If caller passed an actor wrapper (with .mon), prefer storing statuses on inner mon.
    // Otherwise, store on the provided mon. This keeps a single canonical storage location
    // (the inner mon) so lookups are consistent across the codebase.
    var _target_mon = mon;
    if (is_struct(mon) && variable_struct_exists(mon, "mon") && is_struct(variable_struct_get(mon, "mon"))) _target_mon = variable_struct_get(mon, "mon");
    if (!status_system_ensure_mon(_target_mon)) return false;
    if (!is_string(status_id)) return false;
    var meta = undefined;
    if (variable_global_exists("STATUS_SYS") && variable_struct_exists(global.STATUS_SYS, "registry")){
        var _reg_l = variable_struct_get(global.STATUS_SYS, "registry");
        if (variable_struct_exists(_reg_l, status_id)) meta = variable_struct_get(_reg_l, status_id);
    }
    var inst = { id: status_id, applied_ms: current_time, duration_ms: undefined, turns: undefined, stacks:1, source:undefined };
    if (is_struct(opts)){
        // prefer explicit duration_ms if provided
        if (variable_struct_exists(opts, "duration_ms") && !is_undefined(variable_struct_get(opts, "duration_ms"))){
            var dm = variable_struct_get(opts, "duration_ms");
            if (is_real(dm) && dm > 0) inst.duration_ms = dm;
        } else if (variable_struct_exists(opts, "duration") && !is_undefined(variable_struct_get(opts, "duration"))){
            var d = variable_struct_get(opts, "duration");
            // only call real() when d is a number or a string that can be converted
            if (is_real(d)){
                if (d > 0 && d <= 10) inst.turns = floor(d);
                else if (d > 0) inst.duration_ms = d;
            } else if (is_string(d)){
                // try converting string to real safely
                var dconv = real(d);
                if (!is_undefined(dconv) && is_real(dconv) && dconv > 0){
                    if (dconv <= 10) inst.turns = floor(dconv); else inst.duration_ms = dconv;
                }
            }
        }
        if (variable_struct_exists(opts, "stacks") && !is_undefined(variable_struct_get(opts, "stacks"))) inst.stacks = variable_struct_get(opts, "stacks");
        if (variable_struct_exists(opts, "source") && !is_undefined(variable_struct_get(opts, "source"))) {
            var _src = variable_struct_get(opts, "source");
            if (is_struct(_src)){
                // create a lightweight summary to avoid recursive dumps
                var _src_min = {};
                if (variable_struct_exists(_src, "species_id")) variable_struct_set(_src_min, "species_id", variable_struct_get(_src, "species_id"));
                else if (variable_struct_exists(_src, "species")) variable_struct_set(_src_min, "species_id", variable_struct_get(_src, "species"));
                if (variable_struct_exists(_src, "name")) variable_struct_set(_src_min, "name", variable_struct_get(_src, "name"));
                else if (variable_struct_exists(_src, "nickname")) variable_struct_set(_src_min, "name", variable_struct_get(_src, "nickname"));
                if (variable_struct_exists(_src, "pid")) variable_struct_set(_src_min, "pid", variable_struct_get(_src, "pid"));
                if (variable_struct_exists(_src, "actor_idx")) variable_struct_set(_src_min, "actor_idx", variable_struct_get(_src, "actor_idx"));
                inst.source = _src_min;
            } else {
                inst.source = _src;
            }
        }
    }
    // honor skip_first_tick option so statuses applied mid-turn don't immediately tick
    if (is_struct(opts) && variable_struct_exists(opts, "skip_first_tick") && variable_struct_get(opts, "skip_first_tick") == true){
        variable_struct_set(inst, "_skip_first_tick", true);
    }
    var ss = variable_struct_get(_target_mon, "statuses");
    // Defensive: if someone accidentally overwrote the whole `statuses` field with
    // a non-struct value (number/array/ds_map handle), coerce it back to an empty
    // struct so subsequent reads/writes behave predictably.
    if (!is_struct(ss)){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system] coercing non-struct 'statuses' on target to {} (was="+string(ss)+")");
        variable_struct_set(_target_mon, "statuses", {});
        ss = variable_struct_get(_target_mon, "statuses");
    }
    // If the status is already present on this mon (or on actor wrapper), don't re-apply it.
    var already_present = variable_struct_exists(ss, status_id);
    // If the target currently has a Substitute active, most status-inflicting
    // moves/effects should fail. Respect that by refusing to apply non-substitute
    // statuses when a substitute is present. If the caller is explicitly trying
    // to apply a 'substitute' status itself, allow it.
    try {
        if (status_id != "substitute" && status_system_has_status(_target_mon, "substitute")){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system] blocked apply '" + string(status_id) + "' because target has substitute");
            return false;
        }
    } catch (e_block) { /* ignore any errors and continue */ }
    if (!already_present && is_struct(mon) && variable_struct_exists(mon, "statuses")){
        var ss_actor = variable_struct_get(mon, "statuses"); if (variable_struct_exists(ss_actor, status_id)) already_present = true;
    }
    if (already_present){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system] already has status='" + string(status_id) + "' on mon='" + string((variable_struct_exists(_target_mon, "name")?variable_struct_get(_target_mon,"name"):"<no-name>" ) ) + "' — skipping apply");
        return false;
    }
    variable_struct_set(ss, status_id, inst);
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        var _nm_target = (variable_struct_exists(_target_mon, "name") ? variable_struct_get(_target_mon, "name") : "<no-name>");
        show_debug_message("[status_system] applied status='" + string(status_id) + "' to mon='" + string(_nm_target) + "', inst=" + string(inst));
    }
    // Extra debug: verify lookups on both actor wrapper and inner mon (if available)
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        try {
            var _dbg_actor_has = "n/a";
            var _dbg_inner_has = "n/a";
            if (is_struct(mon) && variable_struct_exists(mon, "mon") && is_struct(variable_struct_get(mon, "mon"))){
                // caller passed actor wrapper
                _dbg_actor_has = string(status_system_has_status(mon, status_id));
                _dbg_inner_has = string(status_system_has_status(variable_struct_get(mon, "mon"), status_id));
            } else if (is_struct(mon)){
                _dbg_inner_has = string(status_system_has_status(mon, status_id));
                var _pid_dbg = __status_find_battle_pid(mon);
                if (!is_undefined(_pid_dbg)){
                    var _Bdbg = __battle_ensure_slot(_pid_dbg);
                    if (is_struct(_Bdbg) && variable_struct_exists(_Bdbg, "actor")){
                        var _actsdbg = variable_struct_get(_Bdbg, "actor");
                        for (var _adi = 0; _adi < array_length(_actsdbg); ++_adi){ if (is_struct(_actsdbg[_adi]) && variable_struct_exists(_actsdbg[_adi], "mon") && variable_struct_get(_actsdbg[_adi], "mon") == mon) { _dbg_actor_has = string(status_system_has_status(_actsdbg[_adi], status_id)); break; } }
                    }
                }
            }
            show_debug_message("[status_system][dbg] has_status(actor)=" + string(_dbg_actor_has) + ", has_status(inner)=" + string(_dbg_inner_has));
        } catch (e_dbg) { /* ignore */ }
    }
    // Request an Emerald-style confirmation dialog when a status is applied
    try {
        var _apply_msg = __status_apply_message_for(status_id, mon);
        // If an apply message exists, enqueue it into the battle flow. When callers
        // set opts.skip_dialog=true they intend the status system not to open
        // an immediate dialog; however the message should still be queued so the
        // battle engine can show it after the current dialog/action completes.
        if (!is_undefined(_apply_msg) && string_length(string(_apply_msg)) > 0) {
            __status_request_dialog_for_mon(mon, _apply_msg);
            // Also mark that a meta effect was applied for the battle slot (if present)
            try {
                var _pid_flag = __status_find_battle_pid(mon);
                if (!is_undefined(_pid_flag)){
                    var __Bf = __battle_ensure_slot(_pid_flag);
                    if (is_struct(__Bf)) variable_struct_set(__Bf, "_meta_effect_applied", true);
                }
            } catch (e_flag) { /* ignore */ }
        }
    } catch (e_msg) { /* ignore */ }
    if (is_struct(meta) && variable_struct_exists(meta, "on_apply") && !is_undefined(variable_struct_get(meta, "on_apply"))){
        try { variable_struct_get(meta, "on_apply")(mon, inst, opts); } catch (e) {}
    }
    return true;
}

function status_system_has_status(mon, status_id){
    if (!is_struct(mon)) return false;
    // Prefer canonical inner mon storage if caller passed an actor wrapper
    var _target = mon;
    if (is_struct(mon) && variable_struct_exists(mon, "mon") && is_struct(variable_struct_get(mon, "mon"))) _target = variable_struct_get(mon, "mon");
    if (!variable_struct_exists(_target, "statuses")) return false;
    var ss = variable_struct_get(_target, "statuses");
    if (!is_struct(ss)){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system] has_status found non-struct 'statuses' on target; returning false (val="+string(ss)+")");
        return false;
    }
    return variable_struct_exists(ss, status_id);
}

// Return the status instance struct for a given mon and status_id, or undefined.
function status_system_get(mon, status_id){
    if (!is_struct(mon)) return undefined;
    var _target = mon;
    if (is_struct(mon) && variable_struct_exists(mon, "mon") && is_struct(variable_struct_get(mon, "mon"))) _target = variable_struct_get(mon, "mon");
    if (!variable_struct_exists(_target, "statuses")) return undefined;
    var ss = variable_struct_get(_target, "statuses");
    if (!is_struct(ss)) return undefined;
    if (!variable_struct_exists(ss, status_id)) return undefined;
    var inst = variable_struct_get(ss, status_id);
    if (!is_struct(inst)) return undefined;
    return inst;
}

function status_system_clear_status(mon, status_id){
    if (!status_system_has_status(mon, status_id)) return false;
    // Work with canonical inner mon when available
    var _target = mon;
    if (is_struct(mon) && variable_struct_exists(mon, "mon") && is_struct(variable_struct_get(mon, "mon"))) _target = variable_struct_get(mon, "mon");
    var ss = variable_struct_get(_target, "statuses");
    if (!is_struct(ss)){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system][clear] non-struct 'statuses' detected on target; resetting before clear (val="+string(ss)+")");
        variable_struct_set(_target, "statuses", {});
        ss = variable_struct_get(_target, "statuses");
    }
    var inst = variable_struct_get(ss, status_id);
    var meta = undefined;
    if (variable_global_exists("STATUS_SYS") && variable_struct_exists(global.STATUS_SYS, "registry")){
        var _reg_l2 = variable_struct_get(global.STATUS_SYS, "registry");
        if (variable_struct_exists(_reg_l2, status_id)) meta = variable_struct_get(_reg_l2, status_id);
    }
    if (is_struct(meta) && variable_struct_exists(meta, "on_clear") && !is_undefined(variable_struct_get(meta, "on_clear"))){
        try { variable_struct_get(meta, "on_clear")(mon, inst); } catch (e) {}
    }
    // Clear the canonical entry
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system][clear] clearing status='" + string(status_id) + "' from target='" + string((variable_struct_exists(_target,"name")?variable_struct_get(_target,"name"):"<no-name>")) + "' (before exists=" + string(variable_struct_exists(ss, status_id)) + ")");
    // Use safe removal so we don't leave an `undefined` placeholder in the struct
    __status_remove_key_from_statuses_struct(_target, status_id);
    // Also defensively clear any duplicate entry on an actor wrapper that may reference this inner mon
    try {
        // If caller passed an actor wrapper, try clearing its statuses too
        if (is_struct(mon) && variable_struct_exists(mon, "statuses")){
            var ss_actor = variable_struct_get(mon, "statuses");
            if (variable_struct_exists(ss_actor, status_id)) __status_remove_key_from_statuses_struct(mon, status_id);
        }
        // If caller passed inner mon, search sys_battles for an actor wrapper that references it and clear there too
        if (is_struct(_target) && is_array(global.sys_battles)){
            for (var _bi = 0; _bi < array_length(global.sys_battles); ++_bi){
                var _BB = global.sys_battles[_bi];
                if (!is_struct(_BB) || !variable_struct_exists(_BB, "actor")) continue;
                var _acts = variable_struct_get(_BB, "actor");
                if (!is_array(_acts)) continue;
                for (var _ai = 0; _ai < array_length(_acts); ++_ai){
                    var _act = _acts[_ai];
                    if (!is_struct(_act)) continue;
                    if (variable_struct_exists(_act, "mon") && variable_struct_get(_act, "mon") == _target){
                        if (variable_struct_exists(_act, "statuses")){
                                var _ss_a = variable_struct_get(_act, "statuses");
                                // If the statuses map itself is corrupt, reset it. Otherwise
                                // if the specific entry is non-struct, remove it.
                                if (!is_struct(_ss_a)){
                                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system][clear] actor wrapper '" + string((variable_struct_exists(_act,"name")?variable_struct_get(_act,"name"):"<no-name>")) + "' had non-struct statuses; resetting (val="+string(_ss_a)+")");
                                    variable_struct_set(_act, "statuses", {});
                                } else if (variable_struct_exists(_ss_a, status_id)){
                                    var _inst_a = variable_struct_get(_ss_a, status_id);
                                    if (!is_struct(_inst_a)){
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system][clear] removing corrupt non-struct instance for '"+string(status_id)+"' on actor wrapper");
                                        __status_remove_key_from_statuses_struct(_act, status_id);
                                    } else {
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system][clear] also clearing status on actor wrapper '" + string((variable_struct_exists(_act,"name")?variable_struct_get(_act,"name"):"<no-name>")) + "'");
                                        __status_remove_key_from_statuses_struct(_act, status_id);
                                    }
                                }
                            }
                    }
                }
            }
        }
        // Additionally, scan player's party and any known lists for duplicate entries referencing this mon and clear statuses
        try {
            if (variable_global_exists("PARTY") && is_array(global.PARTY)){
                for (var _pi = 0; _pi < array_length(global.PARTY); ++_pi){
                    var _P = global.PARTY[_pi];
                    if (!is_struct(_P) || !variable_struct_exists(_P, "mons")) continue;
                    var _mons = variable_struct_get(_P, "mons");
                    if (!is_array(_mons)) continue;
                    for (var _mi = 0; _mi < array_length(_mons); ++_mi){
                        var _m = _mons[_mi];
                        if (!is_struct(_m)) continue;
                        if (_m == _target || (variable_struct_exists(_m, "mon") && variable_struct_get(_m, "mon") == _target)){
                            if (variable_struct_exists(_m, "statuses")){
                                var _ss_m = variable_struct_get(_m, "statuses");
                                if (!is_struct(_ss_m)){
                                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system][clear] party entry for mon='" + string((variable_struct_exists(_m,"name")?variable_struct_get(_m,"name"):"<no-name>")) + "' has non-struct statuses; resetting (val="+string(_ss_m)+")");
                                    variable_struct_set(_m, "statuses", {});
                                } else if (variable_struct_exists(_ss_m, status_id)){
                                    var _inst_m = variable_struct_get(_ss_m, status_id);
                                    if (!is_struct(_inst_m)){
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system][clear] removing corrupt non-struct instance for '"+string(status_id)+"' on party mon '"+string((variable_struct_exists(_m,"name")?variable_struct_get(_m,"name"):"<no-name>"))+"'");
                                        __status_remove_key_from_statuses_struct(_m, status_id);
                                    } else {
                                        __status_remove_key_from_statuses_struct(_m, status_id);
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system][clear] cleared status on party entry for mon='" + string((variable_struct_exists(_m,"name")?variable_struct_get(_m,"name"):"<no-name>")) + "'");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch (e_party) { /* ignore */ }
    } catch (e_clear_dupe) { /* swallow */ }
    // Post-clear verification (debug-only)
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        var still = false;
        try { still = status_system_has_status(mon, status_id); } catch (e_st) { still = false; }
        if (still){
            show_debug_message("[status_system][clear] WARNING: status '" + string(status_id) + "' still present on mon after clear — beginning diagnostics");
            try {
                // Show the canonical target's statuses snapshot
                var _tar = _target;
                if (is_struct(_tar) && variable_struct_exists(_tar, "statuses")){
                    var _ss_tar = variable_struct_get(_tar, "statuses");
                    show_debug_message("[status_system][clear][diag] target statuses => " + string(_ss_tar));
                    if (is_struct(_ss_tar) && variable_struct_exists(_ss_tar, status_id)) show_debug_message("[status_system][clear][diag] target has key '"+string(status_id)+"' => value="+string(variable_struct_get(_ss_tar,status_id)));
                } else {
                    show_debug_message("[status_system][clear][diag] target has no 'statuses' field or it's non-struct");
                }
                // Scan sys_battles for any actor wrappers that still contain the status
                if (variable_global_exists("sys_battles") && is_array(global.sys_battles)){
                    for (var _bi2 = 0; _bi2 < array_length(global.sys_battles); ++_bi2){
                        var _BB2 = global.sys_battles[_bi2];
                        if (!is_struct(_BB2) || !variable_struct_exists(_BB2, "actor")) continue;
                        var _acts2 = variable_struct_get(_BB2, "actor");
                        if (!is_array(_acts2)) continue;
                        for (var _ai2 = 0; _ai2 < array_length(_acts2); ++_ai2){
                            var _act2 = _acts2[_ai2];
                            if (!is_struct(_act2)) continue;
                            if (variable_struct_exists(_act2, "statuses")){
                                var _ss_a2 = variable_struct_get(_act2, "statuses");
                                if (is_struct(_ss_a2) && variable_struct_exists(_ss_a2, status_id)) show_debug_message("[status_system][clear][diag] sys_battles["+string(_bi2)+"] actor["+string(_ai2)+"] has status => " + string(variable_struct_get(_ss_a2,status_id)) );
                                else if (!is_struct(_ss_a2)) show_debug_message("[status_system][clear][diag] sys_battles["+string(_bi2)+"] actor["+string(_ai2)+"] has non-struct statuses => " + string(_ss_a2));
                            }
                            // also check if actor wrapper has inner .mon with statuses
                            if (variable_struct_exists(_act2, "mon") && is_struct(variable_struct_get(_act2, "mon"))){
                                var _inner2 = variable_struct_get(_act2, "mon");
                                if (variable_struct_exists(_inner2, "statuses")){
                                    var _ss_i2 = variable_struct_get(_inner2, "statuses");
                                    if (is_struct(_ss_i2) && variable_struct_exists(_ss_i2, status_id)) show_debug_message("[status_system][clear][diag] sys_battles["+string(_bi2)+"] actor["+string(_ai2)+"].mon has status => " + string(variable_struct_get(_ss_i2,status_id)) );
                                }
                            }
                        }
                    }
                }
                // Scan PARTY for lingering entries
                if (variable_global_exists("PARTY") && is_array(global.PARTY)){
                    for (var _pi2 = 0; _pi2 < array_length(global.PARTY); ++_pi2){
                        var _P2 = global.PARTY[_pi2]; if (!is_struct(_P2) || !variable_struct_exists(_P2, "mons")) continue;
                        var _mons2 = variable_struct_get(_P2, "mons"); if (!is_array(_mons2)) continue;
                        for (var _mi2 = 0; _mi2 < array_length(_mons2); ++_mi2){ var _m2 = _mons2[_mi2]; if (!is_struct(_m2)) continue; if (variable_struct_exists(_m2, "statuses")){
                                    var _ss_m2 = variable_struct_get(_m2, "statuses");
                                    if (is_struct(_ss_m2) && variable_struct_exists(_ss_m2, status_id)) show_debug_message("[status_system][clear][diag] PARTY["+string(_pi2)+"] mons["+string(_mi2)+"] has status => " + string(variable_struct_get(_ss_m2,status_id)) );
                                    else if (!is_struct(_ss_m2)) show_debug_message("[status_system][clear][diag] PARTY["+string(_pi2)+"] mons["+string(_mi2)+"] non-struct statuses => " + string(_ss_m2));
                                }
                        }
                    }
                }
            } catch (e_diag) { show_debug_message("[status_system][clear][diag] diagnostic failed: " + string(e_diag)); }
        } else {
            show_debug_message("[status_system][clear] status '" + string(status_id) + "' successfully cleared");
        }
    }
    return true;
}

function status_system_tick_statuses(mon, dt){
    if (!is_struct(mon)) return;
    // Prefer canonical inner mon storage if caller passed an actor wrapper
    var _target = mon;
    if (variable_struct_exists(mon, "mon") && is_struct(variable_struct_get(mon, "mon"))) _target = variable_struct_get(mon, "mon");
    if (!variable_struct_exists(_target, "statuses")) return;
    var ss = variable_struct_get(_target, "statuses");
    if (!is_struct(ss)){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system] tick found non-struct 'statuses' on mon; coercing to {} (val="+string(ss)+")");
        variable_struct_set(_target, "statuses", {});
        ss = variable_struct_get(_target, "statuses");
    }
    var ids = (variable_global_exists("STATUS_SYS") && is_array(global.STATUS_SYS.ids)) ? global.STATUS_SYS.ids : [];
    for (var i = 0; i < array_length(ids); ++i){
        var sid = ids[i];
        if (!variable_struct_exists(ss, sid)) continue;
        var inst = variable_struct_get(ss, sid);
        // Defensive: ensure inst is a struct before accessing fields. Some codepaths
        // may accidentally write non-struct values into the statuses map. If we
        // encounter a non-struct instance, remove it immediately so it doesn't
        // block clears/ticks (this prevents the stuck-sleep symptom).
        if (!is_struct(inst)){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_system] found non-struct status entry for '" + string(sid) + "' on mon; removing corrupt entry (val=" + string(inst) + ")");
            // Remove the bad entry safely and continue
            __status_remove_key_from_statuses_struct(_target, sid);
            continue;
        }
        var meta = undefined;
        if (variable_global_exists("STATUS_SYS") && variable_struct_exists(global.STATUS_SYS, "registry")){
            var _reg_l3 = variable_struct_get(global.STATUS_SYS, "registry");
            if (variable_struct_exists(_reg_l3, sid)) meta = variable_struct_get(_reg_l3, sid);
        }
        if (is_struct(meta) && variable_struct_exists(meta, "on_tick") && !is_undefined(variable_struct_get(meta, "on_tick"))){
            try { variable_struct_get(meta, "on_tick")(mon, inst, dt); } catch (e) {}
        }
        // If this instance was flagged to skip the first tick (applied mid-turn), clear the flag
        // and do not process a tick this pass.
        if (variable_struct_exists(inst, "_skip_first_tick") && variable_struct_get(inst, "_skip_first_tick") == true){
            variable_struct_set(inst, "_skip_first_tick", false);
            variable_struct_set(ss, sid, inst);
            continue;
        }
        if (is_real(inst.turns) && inst.turns > 0){
            inst.turns = inst.turns - 1;
            variable_struct_set(ss, sid, inst);
            if (inst.turns <= 0) status_system_clear_status(mon, sid);
            continue;
        }
        if (is_real(inst.duration_ms) && inst.duration_ms > 0){
            var elapsed = (is_real(current_time) ? current_time - inst.applied_ms : 0);
            if (elapsed >= inst.duration_ms) status_system_clear_status(mon, sid);
        }
    }
}

function __status_apply_percent_damage(mon, pct, sid){
    if (!is_struct(mon)) return false;
    var curKey = undefined; var maxKey = undefined;
    if (variable_struct_exists(mon, "hp_now")) curKey = "hp_now";
    else if (variable_struct_exists(mon, "hp_current")) curKey = "hp_current";
    else if (variable_struct_exists(mon, "hp")) curKey = "hp";
    if (variable_struct_exists(mon, "hp_max")) maxKey = "hp_max";
    else if (variable_struct_exists(mon, "hp_total")) maxKey = "hp_total";
    else if (variable_struct_exists(mon, "hp")) maxKey = "hp";
    if (is_undefined(curKey) || is_undefined(maxKey)) return false;
    var cur = variable_struct_get(mon, curKey);
    var maxv = variable_struct_get(mon, maxKey);
    if (!is_real(cur) || !is_real(maxv) || maxv <= 0) return false;
    var dmg = max(1, floor(maxv * pct));
    var newcur = max(0, cur - dmg);
    variable_struct_set(mon, curKey, newcur);
        __battle_request_animation_safe(mon, { type: "status_tick_damage", status: "tick", amount: dmg });
    // Also request a small in-battle dialog similar to Emerald: "Pikachu is hurt by poison!"
    try {
        var stname = (is_string(sid) && string_length(sid) > 0) ? sid : "";
        // If no explicit sid provided, attempt to select a present status id for context
        if (string_length(stname) == 0 && is_struct(mon) && variable_struct_exists(mon, "statuses")){
            var _ss = variable_struct_get(mon, "statuses");
            if (is_struct(_ss)){
                if (variable_global_exists("STATUS_SYS") && is_array(global.STATUS_SYS.ids)){
                    var _ids = global.STATUS_SYS.ids;
                    for (var _ii = 0; _ii < array_length(_ids); ++_ii){
                        var cand = _ids[_ii];
                        if (variable_struct_exists(_ss, cand)) { stname = cand; break; }
                    }
                }
            }
        }
        var dmg_msg = " is hurt by its status!";
        if (string_length(stname) > 0) dmg_msg = " is hurt by " + string_upper(string(stname)) + "!";
    var _dlg_txt = (variable_struct_exists(mon, "name") ? string(variable_struct_get(mon, "name")) : "Pokémon") + " " + string(dmg_msg) + " (-" + string(dmg) + ")";
    __status_request_dialog_for_mon(mon, _dlg_txt);
    } catch (e_dialog) { /* ignore */ }
    return true;
}

// Try to locate the battle pid for a given mon (searches global.sys_battles).
function __status_find_battle_pid(mon){
    if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) return undefined;
    for (var i = 0; i < array_length(global.sys_battles); ++i){
        var _B = global.sys_battles[i];
        if (!is_struct(_B) || !variable_struct_exists(_B, "actor")) continue;
        var acts = variable_struct_get(_B, "actor");
        for (var ai = 0; ai < array_length(acts); ++ai){
            var a = acts[ai];
            if (a == mon) return i;
            if (is_struct(a) && variable_struct_exists(a, "mon") && variable_struct_get(a, "mon") == mon) return i;
        }
    }
    return undefined;
}

// Map status id to a short Emerald-style apply message (returns string or undefined)
function __status_apply_message_for(id, mon){
    var name = (is_struct(mon) && variable_struct_exists(mon, "name") ? string(variable_struct_get(mon, "name")) : "Pokémon");
    switch (string(id)){
        case "sleep": return string(name) + " fell asleep!";
        case "paralysis": return string(name) + " is paralyzed!";
        case "freeze": return string(name) + " was frozen solid!";
        case "burn": return string(name) + " was burned!";
        case "poison": return string(name) + " was poisoned!";
        case "confusion": return string(name) + " became confused!";
        case "trap": return string(name) + " became trapped!";
        case "leech-seed": return string(name) + " was seeded!";
        default: return string(name) + " is affected by " + string_upper(string(id)) + "!";
    }
}

// Show an in-battle dialog for a given mon (if dialog system available), fallback to debug log.
function __status_request_dialog_for_mon(mon, text){
    // Reject invalid targets or missing text early. Avoid treating `undefined`
    // as the literal string "undefined" which would enqueue a bogus dialog.
    if (!is_struct(mon)) return false;
    if (is_undefined(text)) return false;
    var _txt = string_trim(string(text));
    if (string_length(_txt) == 0) return false;
    var pid = __status_find_battle_pid(mon);
    if (!is_undefined(pid) && is_real(pid)){
        try {
            // Enqueue into the battle slot so the battle engine controls ordering.
            var _B = __battle_ensure_slot(pid);
            if (is_struct(_B)){
                var pending = (variable_struct_exists(_B, "_pending_status_msgs") ? variable_struct_get(_B, "_pending_status_msgs") : undefined);
                if (!is_array(pending)) pending = [];
                // Split incoming text by newlines so each line becomes its own dialog entry
                var rest = _txt;
                var added_any = false;
                while (string_length(string_trim(rest)) > 0){
                    var nl = string_pos("\n", rest);
                    var line = "";
                    if (nl > 0) { line = string_trim(string_copy(rest, 1, nl - 1)); rest = string_delete(rest, 1, nl); }
                    else { line = string_trim(rest); rest = ""; }
                    if (string_length(line) == 0) continue;
                    // avoid duplicates in pending
                    var _skip_line = false;
                    for (var _i2=0; _i2<array_length(pending); ++_i2) if (pending[_i2] == line) { _skip_line = true; break; }
                    if (!_skip_line){ pending[array_length(pending)] = line; added_any = true; }
                }
                if (added_any) variable_struct_set(_B, "_pending_status_msgs", pending);
                return added_any;
            }
        } catch (e) {}
    }
    // fallback: debug message (keeps runtime safe if no dialog system)
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status][dialog] " + string(text));
    return false;
}

function __reg_basic(id, name){ var meta = { id:id, name:name, persist:false, max_stacks:1 }; status_system_register(id, meta); }

var _basic = ["paralysis","sleep","freeze","burn","poison","confusion","infatuation","trap","nightmare","torment","disable","yawn","heal-block","no-type-immunity","leech-seed","embargo","perish-song","ingrain","silence","tar-shot"];
for (var j = 0; j < array_length(_basic); ++j) __reg_basic(_basic[j], _basic[j]);

if (variable_global_exists("STATUS_SYS") && variable_struct_exists(global.STATUS_SYS, "registry")){
    var _reg = variable_struct_get(global.STATUS_SYS, "registry");
    // burn
    if (variable_struct_exists(_reg, "burn")){
        var _burn = variable_struct_get(_reg, "burn");
    variable_struct_set(_burn, "on_tick", function(mon, s, dt){ __status_apply_percent_damage(mon, 1.0/8.0, "burn"); });
        variable_struct_set(_reg, "burn", _burn);
    }
    // poison
    if (variable_struct_exists(_reg, "poison")){
        var _poison = variable_struct_get(_reg, "poison");
    variable_struct_set(_poison, "on_tick", function(mon, s, dt){ __status_apply_percent_damage(mon, 1.0/8.0, "poison"); });
        variable_struct_set(_reg, "poison", _poison);
    }
    // leech-seed
    if (variable_struct_exists(_reg, "leech-seed")){
        var _ls = variable_struct_get(_reg, "leech-seed");
    variable_struct_set(_ls, "on_tick", function(mon, s, dt){
        var did = __status_apply_percent_damage(mon, 1.0/8.0, "leech-seed");
        if (did && is_struct(s) && variable_struct_exists(s, "source") && is_struct(variable_struct_get(s, "source"))){
            var src = variable_struct_get(s, "source");
            try {
                // Prefer canonical HP helpers when available so in-battle HP changes remain consistent
                var heal = 0;
                if (variable_struct_exists(src, "hp_max") && is_real(variable_struct_get(src, "hp_max"))) heal = max(1, floor(variable_struct_get(src, "hp_max") * 1.0/8.0));
                if (heal <= 0) heal = 1;
                if (!is_undefined(__battle_set_hp_now) && !is_undefined(__battle_hp_now)){
                    var cur = __battle_hp_now(src);
                    var cap = (variable_struct_exists(src, "hp_max") ? variable_struct_get(src, "hp_max") : cur);
                    __battle_set_hp_now(src, min(cap, cur + heal));
                    if (!is_undefined(__battle_clear_fainted_if_healed)) __battle_clear_fainted_if_healed(src);
                    // mark meta flag on the battle slot
                    try { var _pid_s = __status_find_battle_pid(src); if (!is_undefined(_pid_s)){ var __Bf2 = __battle_ensure_slot(_pid_s); if (is_struct(__Bf2)) variable_struct_set(__Bf2, "_meta_effect_applied", true); } } catch(e_pf){}
                } else {
                    // fallback to direct field manipulation
                    if (variable_struct_exists(src, "hp_now") && variable_struct_exists(src, "hp_max")){
                        var cur2 = variable_struct_get(src, "hp_now"); var cap2 = variable_struct_get(src, "hp_max"); variable_struct_set(src, "hp_now", min(cap2, cur2 + heal));
                    }
                }
            } catch (e_tickheal) { /* ignore */ }
        }
    });
        variable_struct_set(_reg, "leech-seed", _ls);
    }
    // trap (Bind/Wrap/Clamp/Sand Tomb family)
    if (variable_struct_exists(_reg, "trap")){
        var _tr = variable_struct_get(_reg, "trap");
        // on_apply: set default turns for Gen3-style bind (2-5 turns randomly)
        variable_struct_set(_tr, "on_apply", function(mon, s, opts){
            try {
                // In Gen3 bind/wrap/etc. usually last 2-5 turns; emulate with random 2..5
                var dur = irandom_range(2,5);
                if (is_struct(s)) s.turns = dur;
                __battle_request_animation_safe(mon, { type: "status_apply", status: "trap" });
            } catch (e) {}
        });
        // on_tick: apply 1/8 of max HP as damage (rounded down, minimum 1), heal source if available
        variable_struct_set(_tr, "on_tick", function(mon, s, dt){
            try {
                // Skip first tick immediately after apply when requested
                if (is_struct(s) && variable_struct_exists(s, "_skip_first_tick") && s._skip_first_tick == true){
                    // clear the flag and do not apply damage this tick
                    variable_struct_set(s, "_skip_first_tick", undefined);
                    return;
                }
                // Compute damage amount: floor(maxhp/8) min 1
                var mh = (variable_struct_exists(mon, "hp_max") ? variable_struct_get(mon, "hp_max") : (is_struct(mon) && variable_struct_exists(mon, "mon") && variable_struct_exists(variable_struct_get(mon, "mon"), "hp_max") ? variable_struct_get(variable_struct_get(mon, "mon"), "hp_max") : undefined));
                if (!is_real(mh) || mh <= 0) mh = 1;
                var dmg = max(1, floor(real(mh) * 1.0/8.0));
                var did = __status_apply_percent_damage(mon, 1.0/8.0, "trap");
                if (did && is_struct(s) && variable_struct_exists(s, "source") && is_struct(variable_struct_get(s, "source"))){
                    var src = variable_struct_get(s, "source");
                    try {
                        // Heal source by same amount using canonical helpers when possible
                        if (!is_undefined(__battle_set_hp_now) && !is_undefined(__battle_hp_now)){
                            var cur = __battle_hp_now(src);
                            var cap = (variable_struct_exists(src, "hp_max") ? variable_struct_get(src, "hp_max") : cur);
                            __battle_set_hp_now(src, min(cap, cur + dmg));
                            if (!is_undefined(__battle_clear_fainted_if_healed)) __battle_clear_fainted_if_healed(src);
                            // mark meta flag on the battle slot
                            try { var _pid_s = __status_find_battle_pid(src); if (!is_undefined(_pid_s)){ var __Bf2 = __battle_ensure_slot(_pid_s); if (is_struct(__Bf2)) variable_struct_set(__Bf2, "_meta_effect_applied", true); } } catch(e_pf){}
                        } else {
                            if (variable_struct_exists(src, "hp_now") && variable_struct_exists(src, "hp_max")){
                                var cur2 = variable_struct_get(src, "hp_now"); var cap2 = variable_struct_get(src, "hp_max"); variable_struct_set(src, "hp_now", min(cap2, cur2 + dmg));
                            }
                        }
                    } catch (e_hs) {}
                }
            } catch (e_tick) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status][trap] on_tick failed: " + string(e_tick)); }
        });
        // on_clear: request a cleared dialog
        variable_struct_set(_tr, "on_clear", function(mon, s){ try { __battle_request_animation_safe(mon, { type: "status_cured", status: "trap" }); } catch (e) {} });
        variable_struct_set(_reg, "trap", _tr);
    }
    // sleep
    if (variable_struct_exists(_reg, "sleep")){
        var _sl = variable_struct_get(_reg, "sleep");
    variable_struct_set(_sl, "on_apply", function(mon, s, opts){ var dur = irandom_range(2,5); if (is_struct(s)) s.turns = dur; __battle_request_animation_safe(mon, { type: "status_apply", status: "sleep" }); });
    // When sleep is cleared (turns expire or cured), show a wake-up animation and dialog
    variable_struct_set(_sl, "on_clear", function(mon, s){
        try {
            __battle_request_animation_safe(mon, { type: "status_cured", status: "sleep" });
        } catch (e_anim) {}
        try {
            var _nm = (is_struct(mon) && variable_struct_exists(mon, "name") ? variable_struct_get(mon, "name") : "Pokémon");
            __status_request_dialog_for_mon(mon, string(_nm) + " woke up!");
        } catch (e_dlg) {}
    });
        variable_struct_set(_reg, "sleep", _sl);
    }
    // confusion
    if (variable_struct_exists(_reg, "confusion")){
        var _cf = variable_struct_get(_reg, "confusion");
    variable_struct_set(_cf, "on_apply", function(mon, s, opts){ var durc = irandom_range(2,5); if (is_struct(s)) s.turns = durc; __battle_request_animation_safe(mon, { type: "status_apply", status: "confusion" }); });
    variable_struct_set(_cf, "on_tick", function(mon, s, dt){ var r = irandom(99); if (r < 50){ if (!is_undefined(__battle_apply_move_damage)){ try { __battle_apply_move_damage(undefined, 0, mon, mon, -1, 40); } catch (e) {} } __battle_request_animation_safe(mon, { type: "confusion_hit" }); } });
        variable_struct_set(_reg, "confusion", _cf);
    }
    // freeze
    if (variable_struct_exists(_reg, "freeze")){
        var _fr = variable_struct_get(_reg, "freeze");
    variable_struct_set(_fr, "on_tick", function(mon, s, dt){ var r2 = irandom(99); if (r2 < 20){ status_system_clear_status(mon, "freeze"); __battle_request_animation_safe(mon, { type: "status_cured", status: "freeze" }); } });
        variable_struct_set(_reg, "freeze", _fr);
    }
    // save back registry (global.STATUS_SYS.registry)
    variable_struct_set(global.STATUS_SYS, "registry", _reg);

}

function scr_status_apply_debug(pid, actor_index, status_id){
    var _B = __battle_ensure_slot(pid);
    if (!is_struct(_B)) return false;
    if (!is_real(actor_index) || actor_index < 0 || actor_index > 1) return false;
    var acts = (variable_struct_exists(_B, "actor") ? variable_struct_get(_B, "actor") : undefined);
    if (!is_array(acts) || array_length(acts) <= actor_index) return false;
    var A = acts[actor_index];
    if (!is_struct(A)) return false;
    return status_system_apply_status(A, status_id, { duration:2 });
}

