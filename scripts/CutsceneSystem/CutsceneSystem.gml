// ============================================================================
// CutsceneSystem.gml
// Lightweight, per-pid cutscene dispatcher.
// Similar ideas to DialogSystem: queued items, gates, on-complete callbacks,
// and helper functions to wait for completion.
//
// Cutscene payload shape (recommended):
// { key?, gate?, ts?, duration_ms?, on_start?, on_update?, on_complete? }
// - on_start(pid, item)  -> called once when cutscene starts
// - on_update(pid, item, dt_ms) -> called each Step while active; return true to mark completed
// - on_complete(pid, item) -> called once when complete
// If on_update is absent and duration_ms provided, cutscene auto-completes after duration.
// If neither provided, cutscene completes immediately.
// ============================================================================

// Debug helpers (toggle with global.DATA_DEBUG=true and global.CUTSCENE_DEBUG=true)
function __cut_dbg(_msg){
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG && variable_global_exists("CUTSCENE_DEBUG") && global.CUTSCENE_DEBUG){
        try { show_debug_message("[cutscene] " + string(_msg)); } catch (e) {}
    }
}
function __cut_dbgv(_msg){
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG && variable_global_exists("CUTSCENE_DEBUG_VERBOSE") && global.CUTSCENE_DEBUG_VERBOSE){
        try { show_debug_message("[cutscene][v] " + string(_msg)); } catch (e) {}
    }
}

function cutscene_init(){
    // Per-pid session (two players supported like dialog2p)
    global.CUTSCENE = [ { open:false, _current_item:noone, _on_complete_callbacks:[] }, { open:false, _current_item:noone, _on_complete_callbacks:[] } ];
    global.CUTSCENE_Q = [ [], [] ];
    global.CUTSCENE_SHARED_LOCK = [false, false];
    __cut_dbg("init sessions and queues");
}

function cutscene_is_playing(_pid){
    if (!variable_global_exists("CUTSCENE")) return false;
    var s = global.CUTSCENE[_pid];
    return (is_struct(s) && variable_struct_exists(s, "open")) ? s.open : false;
}

function cutscene_any_playing(){
    if (!variable_global_exists("CUTSCENE")) return false;
    for (var _i = 0; _i < array_length(global.CUTSCENE); ++_i){
        if (cutscene_is_playing(_i)) return true;
    }
    return false;
}

function cutscene_blocks_player(_pid){
    if (!variable_global_exists("CUTSCENE")) cutscene_init();
    if (cutscene_is_playing(_pid)) return true;
    if (variable_global_exists("CUTSCENE_SHARED_LOCK") && is_array(global.CUTSCENE_SHARED_LOCK) && _pid >= 0 && _pid < array_length(global.CUTSCENE_SHARED_LOCK)){
        return global.CUTSCENE_SHARED_LOCK[_pid] == true;
    }
    return false;
}

function __cut_gate_allows_now(_pid, _gate){
    var gate = string_lower(string(_gate));
    var _B = undefined;
    if (!is_undefined(__battle_ensure_slot)) _B = __battle_ensure_slot(_pid);
    else if (variable_global_exists("sys_battles") && is_array(global.sys_battles) && array_length(global.sys_battles) > _pid) _B = global.sys_battles[_pid];
    if (!is_struct(_B)) return true;
    // Provide a simple gate example: "no-intro" blocks during battle intro phases
    if (gate == "no-intro"){
        var _ph = (variable_struct_exists(_B, "phase") ? string(_B.phase) : "");
        if (_ph == "transition_in" || _ph == "intro_enemy" || _ph == "intro_call" || _ph == "intro_player" || _ph == "switch_in") return false;
    }
    return true;
}

function cutscene_enqueue(_pid, _payload){
    if (!variable_global_exists("CUTSCENE_Q")) cutscene_init();
    var q = global.CUTSCENE_Q[_pid];
    var payload = _payload;
    if (is_string(payload)) payload = { key: string(payload), duration_ms: 0 };
    if (!is_struct(payload)) return noone;
    var key = (variable_struct_exists(payload, "key") ? string(variable_struct_get(payload, "key")) : (is_real(current_time) ? string(current_time) : "cutscene"));
    var gate = (variable_struct_exists(payload, "gate") ? string_lower(string(variable_struct_get(payload, "gate"))) : "any");
    var item = { key: key, gate: gate, ts: (is_real(current_time) ? current_time : 0) };
    // copy known callbacks / fields
    if (variable_struct_exists(payload, "duration_ms")) item.duration_ms = variable_struct_get(payload, "duration_ms");
    if (variable_struct_exists(payload, "on_start")) item.on_start = variable_struct_get(payload, "on_start");
    if (variable_struct_exists(payload, "on_update")) item.on_update = variable_struct_get(payload, "on_update");
    if (variable_struct_exists(payload, "on_complete")) item.on_complete = variable_struct_get(payload, "on_complete");
    if (variable_struct_exists(payload, "pids")) item.pids = variable_struct_get(payload, "pids");
    if (variable_struct_exists(payload, "steps")) item.steps = variable_struct_get(payload, "steps");
    if (variable_struct_exists(payload, "step_index")) item.step_index = variable_struct_get(payload, "step_index");
    // copy optional behavior flags
    if (variable_struct_exists(payload, "allow_battle_progress")) item.allow_battle_progress = (variable_struct_get(payload, "allow_battle_progress") == true);
    // dedupe by key if desired
    var exists = false;
    for (var i=0; i<array_length(q); ++i){ var it = q[i]; if (is_struct(it) && variable_struct_exists(it, "key") && string(it.key) == key){ exists = true; break; } }
    if (!exists){ array_push(q, item); global.CUTSCENE_Q[_pid] = q; }
    __cut_dbg("enqueue pid=" + string(_pid) + ", key=" + key + ", gate=" + gate + ", progress=" + string(variable_struct_exists(item, "allow_battle_progress") && item.allow_battle_progress));
    return item;
}

function cutscene_play_now(_pid, _payload){
    var payload = _payload;
    if (!is_struct(payload) && is_string(payload)) payload = { key: string(payload), duration_ms: 0 };
    if (!is_struct(payload)) return noone;
    var item = cutscene_enqueue(_pid, payload);
    var _k = (is_struct(item) && variable_struct_exists(item, "key") ? string(variable_struct_get(item, "key")) : "<no-key>");
    __cut_dbg("play_now pid=" + string(_pid) + ", key=" + _k);
    // Immediately start it (bypass queueing) if no cutscene currently playing
    if (!cutscene_is_playing(_pid)){
        // Pop from head if it's the item we just enqueued, else open the provided item
        var q = global.CUTSCENE_Q[_pid];
        if (array_length(q) > 0 && is_struct(q[0]) && variable_struct_exists(q[0], "key") && is_struct(item) && variable_struct_exists(item, "key") && string(variable_struct_get(q[0], "key")) == string(variable_struct_get(item, "key"))){
            // pop head and start
            var _new = []; for (var ii=1; ii<array_length(q); ++ii) _new[array_length(_new)] = q[ii];
            global.CUTSCENE_Q[_pid] = _new;
            cutscene_play_item_impl(_pid, item);
        } else {
            cutscene_play_item_impl(_pid, item);
        }
    }
    return item;
}

function cutscene_play_item_impl(_pid, _item){
    if (!variable_global_exists("CUTSCENE")) cutscene_init();
    var s = global.CUTSCENE[_pid];
    try {
        variable_struct_set(s, "_current_item", _item);
    } catch (e) {}
    s.open = true;
    // bookkeeping for time-based duration
    try { variable_struct_set(s, "_start_time", (is_real(current_time) ? current_time : 0)); } catch (e) {}
    try { variable_struct_set(s, "_elapsed_ms", 0); } catch (e) {}
    // debug
    try {
        var _k = (is_struct(_item) && variable_struct_exists(_item, "key") ? string(variable_struct_get(_item, "key")) : "<no-key>");
        var _g = (is_struct(_item) && variable_struct_exists(_item, "gate") ? string(variable_struct_get(_item, "gate")) : "any");
        var _abp = (is_struct(_item) && variable_struct_exists(_item, "allow_battle_progress") ? (variable_struct_get(_item, "allow_battle_progress") == true) : false);
        __cut_dbg("start pid=" + string(_pid) + ", key=" + _k + ", gate=" + _g + ", allow_progress=" + string(_abp));
    } catch (e_dbg_start) {}
    // call on_start if present
    try { if (is_struct(_item) && variable_struct_exists(_item, "on_start") && !is_undefined(_item.on_start)) _item.on_start(_pid, _item); } catch (e_on) {}
}

function cutscene_step(_pid){
    // If a cutscene is playing, do nothing. Otherwise attempt to pop queue head and start
    if (!variable_global_exists("CUTSCENE_Q")) cutscene_init();
    if (cutscene_is_playing(_pid)) return;
    var q = global.CUTSCENE_Q[_pid];
    if (!is_array(q) || array_length(q) == 0) return;
    var item = q[0];
    if (!is_struct(item)){
        var _new = []; for (var ii=1; ii<array_length(q); ++ii) _new[array_length(_new)] = q[ii]; global.CUTSCENE_Q[_pid] = _new; return;
    }
    var gate = (variable_struct_exists(item, "gate") ? string(item.gate) : "any");
    if (__cut_gate_allows_now(_pid, gate)){
        var _new2 = []; for (var jj=1; jj<array_length(q); ++jj) _new2[array_length(_new2)] = q[jj]; global.CUTSCENE_Q[_pid] = _new2;
        __cut_dbgv("drain head pid=" + string(_pid) + ", key=" + string(variable_struct_get(item, "key")) + ", gate ok");
        cutscene_play_item_impl(_pid, item);
    } else {
        __cut_dbgv("gate blocked pid=" + string(_pid) + ", key=" + string(variable_struct_get(item, "key")) + ", gate=" + gate);
    }
}

function cutscene_update(_pid){
    if (!variable_global_exists("CUTSCENE")) cutscene_init();
    var s = global.CUTSCENE[_pid];
    if (!s.open) return;
    var _item = (variable_struct_exists(s, "_current_item") ? variable_struct_get(s, "_current_item") : noone);
    var dt = 1; // assume 1 step; real dt tracking can be implemented by the caller if needed
    // update elapsed
    try { var st = (variable_struct_exists(s, "_start_time") ? variable_struct_get(s, "_start_time") : 0); if (is_real(current_time)) variable_struct_set(s, "_elapsed_ms", max(0, current_time - st)); } catch (e) {}
    var finished = false;
    var finish_reason = "";
    // If an on_update exists, call it. If it returns true, mark finished.
    try {
        if (!is_undefined(_item) && _item != noone && is_struct(_item) && variable_struct_exists(_item, "on_update") && !is_undefined(_item.on_update)){
            var _res = _item.on_update(_pid, _item, (variable_struct_exists(s, "_elapsed_ms") ? variable_struct_get(s, "_elapsed_ms") : 0));
            if (_res == true){ finished = true; finish_reason = "on_update"; }
        } else {
            // No update callback: complete when duration_ms elapsed (if provided)
            if (!is_undefined(_item) && _item != noone && is_struct(_item) && variable_struct_exists(_item, "duration_ms") && is_real(variable_struct_get(_item, "duration_ms"))){
                var _dur = variable_struct_get(_item, "duration_ms");
                var _el = (variable_struct_exists(s, "_elapsed_ms") ? variable_struct_get(s, "_elapsed_ms") : 0);
                if (_el >= _dur){ finished = true; finish_reason = "duration"; }
            } else {
                // No duration and no on_update -> instant complete
                finished = true; finish_reason = "instant";
            }
        }
    } catch (e_update) { /* ignore and attempt to finish gracefully */ }

    if (finished){
        try { __cut_dbg("complete pid=" + string(_pid) + ", key=" + string(variable_struct_get(_item, "key")) + ", reason=" + finish_reason); } catch (e_logc) {}
        // call on_complete if present
        try { if (!is_undefined(_item) && _item != noone && is_struct(_item) && variable_struct_exists(_item, "on_complete") && !is_undefined(_item.on_complete)) _item.on_complete(_pid, _item); } catch (e_c) {}
        // call any registered waiters
        try {
            var _waiters = (variable_struct_exists(s, "_on_complete_callbacks") ? variable_struct_get(s, "_on_complete_callbacks") : []);
            for (var _wi=0; _wi<array_length(_waiters); ++_wi){ try { var _f = _waiters[_wi]; if (!is_undefined(_f) && _f != noone) _f(); } catch(e_w){} }
            variable_struct_set(s, "_on_complete_callbacks", []);
        } catch (e_w2) {}
        try { variable_struct_set(s, "_current_item", noone); } catch (e_ci) {}
        s.open = false;
    }
}

function cutscene_wait_finished(_pid, _callback){
    if (!variable_global_exists("CUTSCENE")) cutscene_init();
    var s = global.CUTSCENE[_pid];
    if (!s.open){ try { if (!is_undefined(_callback) && _callback != noone) _callback(); } catch(e) {} return; }
    try {
        var _list = (variable_struct_exists(s, "_on_complete_callbacks") ? variable_struct_get(s, "_on_complete_callbacks") : []);
        array_push(_list, _callback);
        variable_struct_set(s, "_on_complete_callbacks", _list);
        __cut_dbgv("wait_finished pid=" + string(_pid) + ", now waiting callbacks=" + string(array_length(_list)));
    } catch (e_wc) { /* ignore */ }
}

function cutscene_interrupt(_pid){
    if (!variable_global_exists("CUTSCENE")) cutscene_init();
    var s = global.CUTSCENE[_pid];
    if (!s.open) return;
    var _item = (variable_struct_exists(s, "_current_item") ? variable_struct_get(s, "_current_item") : noone);
    try { __cut_dbg("interrupt pid=" + string(_pid) + ", key=" + string(variable_struct_get(_item, "key"))); } catch (e_logi) {}
    try { if (!is_undefined(_item) && _item != noone && is_struct(_item) && variable_struct_exists(_item, "on_complete") && !is_undefined(_item.on_complete)) _item.on_complete(_pid, _item); } catch (e) {}
    // clear current and mark closed
    try { variable_struct_set(s, "_current_item", noone); } catch (e) {}
    s.open = false;
}

// Utility: peek queue as array (for debug)
function cutscene_peek_queue(_pid){ if (!variable_global_exists("CUTSCENE_Q")) cutscene_init(); return global.CUTSCENE_Q[_pid]; }

function __cutscene_set_shared_lock(_pids, _locked){
    if (!variable_global_exists("CUTSCENE_SHARED_LOCK")) cutscene_init();
    var _locks = global.CUTSCENE_SHARED_LOCK;
    if (!is_array(_locks)) _locks = [false, false];
    if (is_array(_pids)){
        for (var _i = 0; _i < array_length(_pids); ++_i){
            if (!is_real(_pids[_i])) continue;
            var _pid = max(0, floor(_pids[_i]));
            if (array_length(_locks) <= _pid) array_resize(_locks, _pid + 1);
            _locks[_pid] = _locked == true;
        }
    }
    global.CUTSCENE_SHARED_LOCK = _locks;
}

function __cutscene_overworld_step(_step, _pid, _item){
    if (!is_struct(_step)) return true;
    var _action = variable_struct_exists(_step, "action") ? string_lower(string(variable_struct_get(_step, "action"))) : "wait";
    if (_action == "wait"){
        if (!variable_struct_exists(_step, "_start_ms")) variable_struct_set(_step, "_start_ms", current_time);
        var _dur = variable_struct_exists(_step, "duration_ms") && is_real(variable_struct_get(_step, "duration_ms")) ? max(0, real(variable_struct_get(_step, "duration_ms"))) : 0;
        return current_time - real(variable_struct_get(_step, "_start_ms")) >= _dur;
    }
    if (_action == "dialog"){
        var _dpid = variable_struct_exists(_step, "pid") && is_real(variable_struct_get(_step, "pid")) ? floor(variable_struct_get(_step, "pid")) : _pid;
        if (!variable_struct_exists(_step, "_shown")){
            variable_struct_set(_step, "_shown", true);
            if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_dpid, string(variable_struct_get(_step, "text")));
        }
        return is_undefined(dialog2p_is_open) || !dialog2p_is_open(_dpid);
    }
    if (_action == "face_npc"){
        if (variable_struct_exists(_step, "inst")){
            var _npc = variable_struct_get(_step, "inst");
            if (instance_exists(_npc)){
                var _dir = variable_struct_exists(_step, "dir") ? variable_struct_get(_step, "dir") : 2;
                variable_instance_set(_npc, "npc_facing_dir", floor(real(_dir)));
                if (!is_undefined(__overworld_npc_anim_update)) __overworld_npc_anim_update(_npc, false, 0, 0);
            }
        }
        return true;
    }
    if (_action == "move_npc"){
        var _mnpc = variable_struct_exists(_step, "inst") ? variable_struct_get(_step, "inst") : noone;
        if (!instance_exists(_mnpc)) return true;
        var _mx = variable_struct_exists(_step, "x") ? real(variable_struct_get(_step, "x")) : variable_instance_get(_mnpc, "x");
        var _my = variable_struct_exists(_step, "y") ? real(variable_struct_get(_step, "y")) : variable_instance_get(_mnpc, "y");
        var _ms = variable_struct_exists(_step, "speed") ? max(0.1, real(variable_struct_get(_step, "speed"))) : 1;
        if (!is_undefined(__overworld_npc_move_towards)) return !__overworld_npc_move_towards(_mnpc, _mx, _my, _ms);
        variable_instance_set(_mnpc, "x", _mx);
        variable_instance_set(_mnpc, "y", _my);
        return true;
    }
    if (_action == "move_player"){
        var _mpid = variable_struct_exists(_step, "pid") && is_real(variable_struct_get(_step, "pid")) ? floor(variable_struct_get(_step, "pid")) : _pid;
        var _pl = !is_undefined(player_by_pid) ? player_by_pid(_mpid) : noone;
        if (_pl == noone) return true;
        var _tx = variable_struct_exists(_step, "x") ? real(variable_struct_get(_step, "x")) : variable_instance_get(_pl, "x");
        var _ty = variable_struct_exists(_step, "y") ? real(variable_struct_get(_step, "y")) : variable_instance_get(_pl, "y");
        var _sp = variable_struct_exists(_step, "speed") ? max(0.1, real(variable_struct_get(_step, "speed"))) : 1;
        var _x = variable_instance_get(_pl, "x");
        var _y = variable_instance_get(_pl, "y");
        var _dist = point_distance(_x, _y, _tx, _ty);
        if (_dist <= _sp){
            variable_instance_set(_pl, "x", _tx);
            variable_instance_set(_pl, "y", _ty);
            return true;
        }
        var _ang = point_direction(_x, _y, _tx, _ty);
        variable_instance_set(_pl, "x", _x + lengthdir_x(_sp, _ang));
        variable_instance_set(_pl, "y", _y + lengthdir_y(_sp, _ang));
        return false;
    }
    if (_action == "callback"){
        if (!variable_struct_exists(_step, "_called")){
            variable_struct_set(_step, "_called", true);
            if (variable_struct_exists(_step, "fn")){
                var _fn = variable_struct_get(_step, "fn");
                if (!is_undefined(_fn)) _fn(_pid, _item, _step);
            }
        }
        return true;
    }
    return true;
}

function __cutscene_overworld_update(_pid, _item, _elapsed_ms){
    if (!is_struct(_item) || !variable_struct_exists(_item, "steps")) return true;
    var _steps = variable_struct_get(_item, "steps");
    if (!is_array(_steps)) return true;
    var _index = variable_struct_exists(_item, "step_index") && is_real(variable_struct_get(_item, "step_index")) ? floor(variable_struct_get(_item, "step_index")) : 0;
    while (_index < array_length(_steps)){
        var _step = _steps[_index];
        if (!__cutscene_overworld_step(_step, _pid, _item)){
            _steps[_index] = _step;
            variable_struct_set(_item, "steps", _steps);
            variable_struct_set(_item, "step_index", _index);
            return false;
        }
        _steps[_index] = _step;
        _index += 1;
        variable_struct_set(_item, "step_index", _index);
    }
    variable_struct_set(_item, "steps", _steps);
    return true;
}

function cutscene_play_overworld(_pids, _steps, _key = "overworld_cutscene"){
    if (!variable_global_exists("CUTSCENE")) cutscene_init();
    var _pid_list = is_array(_pids) ? _pids : [_pids];
    if (array_length(_pid_list) <= 0) _pid_list = [0];
    var _master = 0;
    for (var _i = 0; _i < array_length(_pid_list); ++_i){
        if (is_real(_pid_list[_i])){ _master = max(0, floor(_pid_list[_i])); break; }
    }
    return cutscene_play_now(_master, {
        key: _key,
        gate: "any",
        pids: _pid_list,
        steps: _steps,
        step_index: 0,
        on_start: function(_pid, _item){
            if (variable_struct_exists(_item, "pids")) __cutscene_set_shared_lock(variable_struct_get(_item, "pids"), true);
        },
        on_update: __cutscene_overworld_update,
        on_complete: function(_pid, _item){
            if (variable_struct_exists(_item, "pids")) __cutscene_set_shared_lock(variable_struct_get(_item, "pids"), false);
        }
    });
}

// End of CutsceneSystem
