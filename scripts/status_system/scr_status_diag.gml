// Diagnostic helper: scan global.sys_battles and global.PARTY for any non-struct
// values stored in a `statuses` field. Useful when hunting down the bug where
// status_system_tick_statuses sees non-struct entries.
function scr_status_scan_bad_statuses(){
    var found = false;
    try {
        if (variable_global_exists("sys_battles") && is_array(global.sys_battles)){
            for (var i = 0; i < array_length(global.sys_battles); ++i){
                var _B = global.sys_battles[i];
                if (!is_struct(_B) || !variable_struct_exists(_B, "actor")) continue;
                var acts = variable_struct_get(_B, "actor");
                for (var a = 0; a < array_length(acts); ++a){
                    var act = acts[a];
                    if (!is_struct(act)) continue;
                    if (variable_struct_exists(act, "statuses") && !is_struct(variable_struct_get(act, "statuses"))){
                        found = true;
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_diag] battle["+string(i)+"] actor["+string(a)+"] has non-struct 'statuses' => " + string(variable_struct_get(act, "statuses")));
                    }
                    if (variable_struct_exists(act, "mon") && is_struct(variable_struct_get(act, "mon"))){
                        var mon = variable_struct_get(act, "mon");
                        if (variable_struct_exists(mon, "statuses") && !is_struct(variable_struct_get(mon, "statuses"))){
                            found = true;
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_diag] battle["+string(i)+"] actor["+string(a)+"].mon has non-struct 'statuses' => " + string(variable_struct_get(mon, "statuses")));
                        }
                    }
                }
            }
        }
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_diag] error scanning sys_battles: " + string(e)); }

    try {
        if (variable_global_exists("PARTY") && is_array(global.PARTY)){
            for (var p = 0; p < array_length(global.PARTY); ++p){
                var P = global.PARTY[p];
                if (!is_struct(P) || !variable_struct_exists(P, "mons")) continue;
                var mons = variable_struct_get(P, "mons");
                if (!is_array(mons)) continue;
                for (var m = 0; m < array_length(mons); ++m){
                    var mon = mons[m];
                    if (!is_struct(mon)) continue;
                    if (variable_struct_exists(mon, "statuses") && !is_struct(variable_struct_get(mon, "statuses"))){
                        found = true;
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_diag] PARTY["+string(p)+"] mons["+string(m)+"] has non-struct 'statuses' => " + string(variable_struct_get(mon, "statuses")));
                    }
                }
            }
        }
    } catch (e2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_diag] error scanning PARTY: " + string(e2)); }

    if (!found){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[status_diag] no non-struct statuses found"); }
    return found;
}
