// ============================================================================
// scr_dialog2p_system.gml
// - 2-player dialog, per-camera draw (works single player too)
// - Classic Pokémon box by default (22 cols × 2 rows)
// - Uses global.DIALOG_SPEED (1/2/3) for type speed
// - Requires font_pokemon_draw(), and global.FONT_POKEMON (sprite + map). 
// ============================================================================

// ---------- Safe font metrics (fallbacks if struct incomplete) --------------
function __dlg_font_w(){
    return (variable_global_exists("FONT_CHAR_W") ? max(1, global.FONT_CHAR_W) : 8);
}
function __dlg_font_h(){
    return (variable_global_exists("FONT_CHAR_H") ? max(1, global.FONT_CHAR_H) : 8);
}

// ---------- Session factory (classic defaults) ------------------------------
function __dlg_make_session(){
    var cw = __dlg_font_w();
    var ch = __dlg_font_h();
    var _cols = 22;
    var _rows = 2;

    return {
        open        : false,   // keep field name 'open'
        _spd        : 2,       // 1/2/3, copied from global.DIALOG_SPEED on open
        cps_table   : [1,2,4], // chars per step (slow/normal/fast)

        // content
        all_lines   : [],
        lines       : ["",""],
        page_idx    : 0,
        char_idx    : 0,
        tick        : 0,
        arrow_tick  : 0,

        // style
        cols        : _cols,
        rows        : _rows,
        box_w       : _cols * cw,
        box_h       : _rows * ch + 8,
        border_pad  : 8,
        margin_h    : 4,
        margin_v    : 4,

        // cosmetics
        portrait       : noone,
        portrait_frame : 0,
        name_label     : "",
        sfx_tick       : noone
        ,
        // runtime bookkeeping (for new dispatcher API)
        _current_item      : noone,  // the queue item currently shown
        _on_close_callbacks: []       // callbacks requested to run when this dialog closes
    };
}

// ---------- Init ------------------------------------------------------------
function dialog2p_init(){
    global.DIALOG2P = [ __dlg_make_session(), __dlg_make_session() ];
    // Lightweight per-pid dialog queues managed by the dialog system itself.
    // Each item: { text: string, key: string, gate: string, ts: real }
    // Gates: "any" (default), "after-faint" (wait until faint_pending=false),
    //        "no-intro" (skip during transition/intro/switch phases)
    global.DIALOG2P_Q = [ [], [] ];
}

// ---------- Query -----------------------------------------------------------
function dialog2p_is_open(_pid){
    if (!variable_global_exists("DIALOG2P")) return false;
    var d = global.DIALOG2P[_pid];
    return (is_struct(d) && variable_struct_exists(d,"open")) ? d.open : false;
}

// ---------- Queue helpers (enqueue + gated drain) --------------------------
function __dlg_gate_allows_now(_pid, _gate){
    var gate = string_lower(string(_gate));
    if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles) || array_length(global.sys_battles) <= _pid) return true;
    var _B = global.sys_battles[_pid];
    if (!is_struct(_B)) return true;
    // Faint gating
    if (gate == "after-faint"){
        if (variable_struct_exists(_B, "_faint_pending") && variable_struct_get(_B, "_faint_pending")) return false;
    }
    // Intro gating (avoid during intro/switch)
    if (gate == "no-intro"){
        var _ph = (variable_struct_exists(_B, "phase") ? string(_B.phase) : "");
        if (_ph == "transition_in" || _ph == "intro_enemy" || _ph == "intro_call" || _ph == "intro_player" || _ph == "switch_in") return false;
    }
    return true;
}

function dialog2p_enqueue_text(_pid, _text, _key, _gate){
    // Backwards-compatible wrapper that delegates to dialog2p_enqueue(payload)
    var payload = { text: string(_text) };
    if (!is_undefined(_key) && _key != "") payload.key = string(_key);
    if (!is_undefined(_gate) && _gate != "") payload.gate = string_lower(string(_gate));
    return dialog2p_enqueue(_pid, payload);
}

// Convenience helper: prefer immediate show, fall back to enqueue (with gate)
function dialog2p_show(_pid, _text){
    var _gate = (array_length(argument) > 2 ? argument[2] : undefined);
    try {
        if (!is_undefined(dialog2p_show_now)){
            dialog2p_show_now(_pid, _text);
            return;
        }
        if (!is_undefined(dialog2p_enqueue_text)){
            var g = (is_undefined(_gate) || _gate == "" ) ? "any" : string_lower(string(_gate));
            dialog2p_enqueue_text(_pid, _text, _text, g);
            return;
        }
    } catch (e__) {}
}

function dialog2p_step(_pid){
    if (!variable_global_exists("DIALOG2P_Q")) return;
    if (dialog2p_is_open(_pid)) return;
    var q = global.DIALOG2P_Q[_pid];
    if (!is_array(q) || array_length(q) == 0) return;
    // Ensure faint messages remain high priority. If any faint item sits behind
    // the head entry, bring it forward so it can open before non-faint pages.
    var item = q[0];
    var item_is_faint = (is_struct(item) && variable_struct_exists(item, "is_faint") && item.is_faint);
    if (!item_is_faint){
        var faint_idx = -1;
        for (var search_i = 0; search_i < array_length(q); ++search_i){
            var cand = q[search_i];
            if (is_struct(cand) && variable_struct_exists(cand, "is_faint") && cand.is_faint){ faint_idx = search_i; break; }
        }
        if (faint_idx > 0){
            var prioritized = q[faint_idx];
            var reordered = [prioritized];
            for (var copy_i = 0; copy_i < array_length(q); ++copy_i){
                if (copy_i == faint_idx) continue;
                reordered[array_length(reordered)] = q[copy_i];
            }
            global.DIALOG2P_Q[_pid] = reordered;
            q = reordered;
        }
    }
    // Peek (possibly re-ordered head) and open if allowed by gate
    item = global.DIALOG2P_Q[_pid][0];
    if (!is_struct(item)){
        // Malformed; drop it
        var _new = []; for (var ii=1; ii<array_length(q); ++ii) _new[array_length(_new)] = q[ii];
        global.DIALOG2P_Q[_pid] = _new; return;
    }
    var gate = (variable_struct_exists(item, "gate") ? string(item.gate) : "any");
    if (__dlg_gate_allows_now(_pid, gate)){
        // Pop head
        var _new2 = []; for (var jj=1; jj<array_length(q); ++jj) _new2[array_length(_new2)] = q[jj];
        global.DIALOG2P_Q[_pid] = _new2;
        // Open text and record the originating item so callbacks/waiters can run
    dialog2p_open_text_impl(_pid, variable_struct_exists(item, "text") ? item.text : "", item);
    }
}

function dialog2p_queue_has_faint(_pid){
    if (!variable_global_exists("DIALOG2P_Q")) return false;
    if (!is_real(_pid) || _pid < 0) return false;
    if (!is_array(global.DIALOG2P_Q)) return false;
    if (array_length(global.DIALOG2P_Q) <= _pid) return false;
    var q = global.DIALOG2P_Q[_pid];
    if (!is_array(q)) return false;
    for (var qi = 0; qi < array_length(q); ++qi){
        var item = q[qi];
        if (is_struct(item) && variable_struct_exists(item, "is_faint") && item.is_faint) return true;
    }
    return false;
}

// ---------- Open text (wrap + reset) ---------------------------------------
function __dlg_wrap_text(_text, _box_w){
    var _col_w  = __dlg_font_w();
    var _maxcol = max(1, floor(_box_w / _col_w));

    var _out = [];
    var _src = string_split(_text, "\n");
    for (var li = 0; li < array_length(_src); li++){
        var _line = _src[li]; // changed from "ln" to "_line"
        var words = string_split(_line, " ");
        var cur = "";
        for (var wi = 0; wi < array_length(words); wi++){
            var w = words[wi];
            while (string_length(w) > _maxcol){
                array_push(_out, string_copy(w, 1, _maxcol));
                w = string_copy(w, _maxcol + 1, string_length(w) - _maxcol);
            }
            var tryln = (cur == "" ? w : cur + " " + w);
            if (string_length(tryln) <= _maxcol) cur = tryln;
            else { array_push(_out, cur); cur = w; }
        }
        if (cur != "") array_push(_out, cur);
        if (array_length(words) == 0) array_push(_out, "");
    }
    return _out;
}
// Internal implementation accepting optional originating item.
function dialog2p_open_text_impl(_pid, _text, _item){
    // Ensure dialog system is initialized before accessing the session array
    if (!variable_global_exists("DIALOG2P")) dialog2p_init();
    var d = global.DIALOG2P[_pid];

    // If a battle slot exists for this pid and a faint is pending, do not
    // immediately replace the dialog. Instead enqueue the text as a pending
    // status message so it will be shown after the faint dialog completes.
    try {
        if (variable_global_exists("sys_battles") && is_array(global.sys_battles) && array_length(global.sys_battles) > _pid){
            var _Bchk = global.sys_battles[_pid];
            if (is_struct(_Bchk) && variable_struct_exists(_Bchk, "_faint_pending") && variable_struct_get(_Bchk, "_faint_pending") == true){
                // If this originating item is itself a faint message, allow it to open
                // even when _faint_pending is set. Only non-faint messages should be
                // queued until the faint flow completes.
                var _origin_is_faint = false;
                try { if (!is_undefined(_item) && _item != noone && is_struct(_item) && variable_struct_exists(_item, "is_faint") && _item.is_faint) _origin_is_faint = true; } catch (e_oif) { _origin_is_faint = false; }
                if (!_origin_is_faint){
                    // Ensure pending array exists and avoid duplicates/runaway growth
                    var _ps = (variable_struct_exists(_Bchk, "_pending_status_msgs") ? variable_struct_get(_Bchk, "_pending_status_msgs") : []);
                    var _txt_s = string(_text);
                    var _already = false;
                    for (var _ii=0; _ii<array_length(_ps); ++_ii) if (string(_ps[_ii]) == _txt_s){ _already = true; break; }
                    if (!_already){
                        // Cap the pending queue to a reasonable size to avoid runaway loops
                        if (array_length(_ps) < 64) array_push(_ps, _txt_s);
                        else {
                            // If queue is full, drop the oldest and push the new one
                            var _tmpn = [];
                            for (var _jj = 1; _jj < array_length(_ps); ++_jj) _tmpn[array_length(_tmpn)] = _ps[_jj];
                            _tmpn[array_length(_tmpn)] = _txt_s;
                            _ps = _tmpn;
                        }
                        variable_struct_set(_Bchk, "_pending_status_msgs", _ps);
                    }
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[dialog][queue] queued pid=" + string(_pid) + ", preview='" + string_copy(string(_text),1,min(48,string_length(string(_text)))) + "'");
                    return;
                }
            }
        }
    } catch (e_q) { /* ignore queuing failures and fall through to open */ }

    // Hard duplicate suppression (scoped): after handling faint-queueing above, only
    // block if the same exact text was just opened extremely recently (same frame/beat),
    // to prevent back-to-back opens. Do NOT suppress across turns.
    try {
        // Determine whether a faint is pending; if so, don't suppress here—the text may need
        // to be queued (the queue logic above already handled that) and suppression here could
        // eat the rightful first display on the next frame.
        var _fp2 = false;
        try {
            if (variable_global_exists("sys_battles") && is_array(global.sys_battles) && array_length(global.sys_battles) > _pid){
                var _B2 = global.sys_battles[_pid];
                if (is_struct(_B2) && variable_struct_exists(_B2, "_faint_pending") && variable_struct_get(_B2, "_faint_pending")) _fp2 = true;
            }
        } catch (e_fp2) { _fp2 = false; }
        if (!_fp2){
            var _txt_s2 = string(_text);
            var _last_t2 = (variable_struct_exists(d, "_last_open_text") ? string(variable_struct_get(d, "_last_open_text")) : "");
            var _last_ms2 = (variable_struct_exists(d, "_last_open_ts") && is_real(variable_struct_get(d, "_last_open_ts")) ? variable_struct_get(d, "_last_open_ts") : -9999999);
            if (_last_t2 == _txt_s2 && is_real(current_time) && abs(current_time - _last_ms2) < 300){
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[dialog][suppress] duplicate within short window pid=" + string(_pid) + ", preview='" + string_copy(_txt_s2,1,min(48,string_length(_txt_s2))) + "'");
                return;
            }
        }
    } catch (e_ds) { /* ignore and continue */ }

    // Preserve previous content preview so we can avoid logging repeats
    var _prev_text = "";
    if (is_struct(d) && variable_struct_exists(d, "all_lines") && is_array(variable_struct_get(d, "all_lines"))){
        var _pl = variable_struct_get(d, "all_lines");
        for (var _pi=0; _pi<array_length(_pl); ++_pi) _prev_text += string(_pl[_pi]) + "\n";
        _prev_text = string_trim(_prev_text);
    }

    d._spd       = clamp(global.DIALOG_SPEED, 1, 3);
    d.all_lines  = __dlg_wrap_text(_text, d.box_w);
    d.page_idx   = 0;
    d.char_idx   = 0;
    d.tick       = 0;
    d.arrow_tick = 0;
    d.open       = true;

    // Record the originating queue item (if provided) so on_close and waiting
    // callbacks can be invoked when this session closes.
    try {
        if (!is_undefined(_item) && _item != noone) variable_struct_set(d, "_current_item", _item);
        else variable_struct_set(d, "_current_item", noone);
        // If the item carried cosmetic fields, apply them immediately
        if (!is_undefined(_item) && is_struct(_item)){
            if (variable_struct_exists(_item, "portrait")) variable_struct_set(d, "portrait", variable_struct_get(_item, "portrait"));
            if (variable_struct_exists(_item, "portrait_frame")) variable_struct_set(d, "portrait_frame", variable_struct_get(_item, "portrait_frame"));
            if (variable_struct_exists(_item, "name_label")) variable_struct_set(d, "name_label", string(variable_struct_get(_item, "name_label")));
            if (variable_struct_exists(_item, "sfx_tick")) variable_struct_set(d, "sfx_tick", variable_struct_get(_item, "sfx_tick"));
        }
    } catch (e_ci) { /* ignore bookkeeping failures */ }

    // Record last-open to support suppression on subsequent calls
    try { variable_struct_set(d, "_last_open_text", string(_text)); } catch (e_lo) {}
    try { if (is_real(current_time)) variable_struct_set(d, "_last_open_ts", current_time); } catch (e_lt) {}

    // Debug: log dialog opens to help trace timing issues
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        // Only log opened/session debug when the new wrapped text is different from previous content
        var _new_preview = string_copy(string(_text), 1, min(48, string_length(string(_text))));
        // Reconstruct the full new wrapped text for accurate comparison
        var _new_full = "";
        for (var _ni=0; _ni<array_length(d.all_lines); ++_ni) _new_full += string(d.all_lines[_ni]) + "\n";
        _new_full = string_trim(_new_full);
        if (_new_full != _prev_text){
            try { if (variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG) show_debug_message("[dialog][debug] opened pid=" + string(_pid) + ", preview='" + _new_preview + "'"); } catch (e){}
            // Dump session internals to help trace why dialogs might not render
            try {
                var _dbg = "[dialog][debug] sess open=" + string(d.open) + ", pages=" + string(array_length(d.all_lines)) + ", page_idx=" + string(d.page_idx) + ", char_idx=" + string(d.char_idx);
                try { if (variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG) show_debug_message(_dbg); } catch (e_dbg) { /* ignore */ }
            } catch (e_dbg) { /* ignore */ }
        }
    }
    // Small input-grace window: ignore presses that occurred to open the dialog
    // (e.g. selecting a Pokémon) so the dialog doesn't immediately advance.
    // Use a short ms window (120ms) to be forgiving across frame timing.
    if (is_real(current_time)) variable_struct_set(d, "_open_grace_until", current_time + 120);
}

// Backwards-compatible wrapper: callers may pass 2 args (pid, text) or 3 args (pid, text, item)
function dialog2p_open_text(){
    var _pid = (argument_count >= 1 ? argument[0] : 0);
    var _text = (argument_count >= 2 ? argument[1] : "");
    var _item = (argument_count >= 3 ? argument[2] : noone);
    return dialog2p_open_text_impl(_pid, _text, _item);
}

// ---------- Optional cosmetics ---------------------------------------------
// ---------- New dispatcher helpers (backward-compatible) -------------------
// payload may be a string (text) or a struct with fields:
// { text, key?, gate?, portrait?, portrait_frame?, name_label?, sfx_tick?, on_close? }
function dialog2p_enqueue(_pid, _payload){
    if (!variable_global_exists("DIALOG2P_Q")) dialog2p_init();
    var q = global.DIALOG2P_Q[_pid];
    var payload = _payload;
    if (is_string(payload)) payload = { text: string(payload) };
    if (!is_struct(payload)) return noone;
    var txt = (variable_struct_exists(payload, "text") ? string(variable_struct_get(payload, "text")) : "");
    var key = (variable_struct_exists(payload, "key") ? string(variable_struct_get(payload, "key")) : (txt == "" ? string(current_time) : txt));
    var gate = (variable_struct_exists(payload, "gate") ? string_lower(string(variable_struct_get(payload, "gate"))) : "any");
    var is_faint = (gate == "faint");
    if (!is_faint){ var _txt_s = string(txt); if (string_pos(" fainted!", _txt_s) > 0 || string_pos("fainted!", _txt_s) > 0) is_faint = true; }
    // dedupe by key
    var exists = false;
    for (var i=0; i<array_length(q); ++i){ var it = q[i]; if (is_struct(it) && variable_struct_exists(it, "key") && string(it.key) == key){ exists = true; break; } }
    var item = { text: txt, key: key, gate: gate, is_faint: is_faint, ts: (is_real(current_time)? current_time : 0) };
    // copy optional fields
    if (variable_struct_exists(payload, "portrait")) item.portrait = variable_struct_get(payload, "portrait");
    if (variable_struct_exists(payload, "portrait_frame")) item.portrait_frame = variable_struct_get(payload, "portrait_frame");
    if (variable_struct_exists(payload, "name_label")) item.name_label = string(variable_struct_get(payload, "name_label"));
    if (variable_struct_exists(payload, "sfx_tick")) item.sfx_tick = variable_struct_get(payload, "sfx_tick");
    if (variable_struct_exists(payload, "on_close")) item.on_close = variable_struct_get(payload, "on_close");

    if (!exists){
        if (is_faint){
            // Insert the faint dialog ahead of any non-faint items while
            // preserving existing faint ordering so simultaneous faints stay stable.
            var inserted = false;
            var reordered_q = [];
            if (is_array(q)){
                for (var qi = 0; qi < array_length(q); ++qi){
                    var qitem = q[qi];
                    if (!inserted){
                        var qitem_is_faint = (is_struct(qitem) && variable_struct_exists(qitem, "is_faint") && qitem.is_faint);
                        if (!qitem_is_faint){
                            reordered_q[array_length(reordered_q)] = item;
                            inserted = true;
                        }
                    }
                    reordered_q[array_length(reordered_q)] = qitem;
                }
            }
            if (!inserted) reordered_q[array_length(reordered_q)] = item;
            global.DIALOG2P_Q[_pid] = reordered_q;
        } else {
            array_push(q, item);
            global.DIALOG2P_Q[_pid] = q;
        }
    }
    return item;
}

function dialog2p_show_now(_pid, _payload){
    // Construct an item and open it immediately (dialog2p_open_text will still
    // enqueue to pending if faint pending behavior applies).
    var payload = _payload;
    if (is_string(payload)) payload = { text: string(payload) };
    if (!is_struct(payload)) return noone;
    var txt = (variable_struct_exists(payload, "text") ? string(variable_struct_get(payload, "text")) : "");
    var item = { text: txt };
    if (variable_struct_exists(payload, "portrait")) item.portrait = variable_struct_get(payload, "portrait");
    if (variable_struct_exists(payload, "portrait_frame")) item.portrait_frame = variable_struct_get(payload, "portrait_frame");
    if (variable_struct_exists(payload, "name_label")) item.name_label = string(variable_struct_get(payload, "name_label"));
    if (variable_struct_exists(payload, "sfx_tick")) item.sfx_tick = variable_struct_get(payload, "sfx_tick");
    if (variable_struct_exists(payload, "on_close")) item.on_close = variable_struct_get(payload, "on_close");
    dialog2p_open_text_impl(_pid, txt, item);
    return item;
}

function dialog2p_wait_closed(_pid, _callback){
    if (!variable_global_exists("DIALOG2P")) dialog2p_init();
    var d = global.DIALOG2P[_pid];
    if (!d.open){ // already closed
        try { if (!is_undefined(_callback) && _callback != noone) _callback(); } catch(e) {}
        return;
    }
    // push callback into session's waiter list
    try {
        var _list = (variable_struct_exists(d, "_on_close_callbacks") ? variable_struct_get(d, "_on_close_callbacks") : []);
        array_push(_list, _callback);
        variable_struct_set(d, "_on_close_callbacks", _list);
    } catch (e_wc) { /* ignore */ }
}

// Note: older code called a global `__battle_stub_dialog` script. We removed
// creating a stub here to avoid duplicate script/resource names in GameMaker.
// Callsites in the project have been migrated to use dialog2p_show_now or
// dialog2p_enqueue; if any legacy code still expects the global script, leave
// it defined in a dedicated resource rather than creating one dynamically.

function dialog2p_set_portrait(_pid, _spr, _subimg, _name){
    var d = global.DIALOG2P[_pid];
    d.portrait       = _spr;
    d.portrait_frame = _subimg;
    d.name_label     = string(_name);
}

// ---------- Update (advance/close, robust) ---------------------------------
function dialog2p_update(_pid){
    var d = global.DIALOG2P[_pid];
    if (!d.open) return;

    var i0 = d.page_idx*2, i1 = i0+1;
    var l0 = (i0 < array_length(d.all_lines)) ? d.all_lines[i0] : "";
    var l1 = (i1 < array_length(d.all_lines)) ? d.all_lines[i1] : "";
    d.lines = [l0, l1];

    var page_str = l0 + "\n" + l1;
    var page_len = string_length(page_str);
    var has_next = ((d.page_idx+1)*2) < array_length(d.all_lines);

    var advance = controls_pressed(_pid,"Interact") || controls_pressed(_pid,"Inventory");
    var cancel  = controls_pressed(_pid,"Run") || controls_pressed(_pid,"Pause");
    // DEVDEBUG: log input state for dialog advancement
    try { if (variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG){ var _ogr = (variable_struct_exists(d, "_open_grace_until") ? string(variable_struct_get(d, "_open_grace_until")) : "<nil>"); show_debug_message("[dialog][update] pid=" + string(_pid) + ", page_idx=" + string(d.page_idx) + ", char_idx=" + string(d.char_idx) + ", advance=" + string(advance) + ", cancel=" + string(cancel) + ", open_grace_until=" + _ogr); } } catch(e){}
    // respect a small input grace period set at open to avoid immediately
    // consuming the same 'Interact' press that opened the dialog (e.g. from
    // party selection). If present, suppress advance until the grace expires.
    var _now_time = (is_real(current_time) ? current_time : -1);
    if (is_struct(d) && variable_struct_exists(d, "_open_grace_until") && is_real(_now_time)){
        var _grace = variable_struct_get(d, "_open_grace_until");
        if (is_real(_grace) && _now_time <= _grace){
            advance = false;
        }
    }

    if (d.char_idx < page_len){
        if (advance){
            d.char_idx = page_len; // finish instantly
        } else {
            d.tick++;
            if (d.tick >= 1){
                d.tick = 0;
                var cps = d.cps_table[d._spd - 1];
                d.char_idx = clamp(d.char_idx + cps, 0, page_len);
                if (d.sfx_tick != noone) audio_play_sound(d.sfx_tick, 1, false);
            }
        }
    } else {
        if (advance || cancel){
            if (has_next){
                d.page_idx++;
                d.char_idx = 0;
                d.tick = 0;
            } else {
                // DEVDEBUG: log that dialog is closing and why
                try { if (variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG){ show_debug_message("[dialog][update] pid=" + string(_pid) + ", closing page_idx=" + string(d.page_idx) + ", advance=" + string(advance) + ", cancel=" + string(cancel)); } } catch(e){}
                d.open = false;
                var _cur_item = noone;
                try {
                    if (variable_struct_exists(d, "_current_item")) _cur_item = variable_struct_get(d, "_current_item");
                } catch (e_cur) { _cur_item = noone; }
                var _cur_is_faint = false;
                if (is_struct(_cur_item) && variable_struct_exists(_cur_item, "is_faint")){
                    try { _cur_is_faint = (variable_struct_get(_cur_item, "is_faint") == true); } catch (e_isf) { _cur_is_faint = false; }
                }
                if (is_struct(_cur_item) && variable_struct_exists(_cur_item, "on_close")){
                    try {
                        var _cb = variable_struct_get(_cur_item, "on_close");
                        if (!is_undefined(_cb) && _cb != noone) { _cb(); }
                    } catch (e_on) {}
                }
                try {
                    var _waiters = (variable_struct_exists(d, "_on_close_callbacks") ? variable_struct_get(d, "_on_close_callbacks") : []);
                    for (var _wi=0; _wi<array_length(_waiters); ++_wi){ try { var _f = _waiters[_wi]; if (!is_undefined(_f) && _f != noone) _f(); } catch(e_w){} }
                    variable_struct_set(d, "_on_close_callbacks", []);
                } catch (e_w2) {}
                if (_cur_is_faint){
                    try {
                        if (!is_undefined(__battle_ensure_slot)){
                            var _slot_fd = __battle_ensure_slot(_pid);
                            if (is_struct(_slot_fd)) variable_struct_set(_slot_fd, "_faint_dialog_active", false);
                        }
                    } catch (e_fdnotify) { /* ignore faint close notify failures */ }
                }
                try { variable_struct_set(d, "_current_item", noone); } catch (e_cl) {}
            }
        }
    }
    d.arrow_tick = (d.arrow_tick + 1) mod 60;
}

// ---------- Draw in WORLD space for a given camera (splitscreen-friendly) ---
function __dlg_type_color(_type_id){
    switch (floor(_type_id)){
        case 1: return make_color_rgb(176, 168, 120); // Normal
        case 2: return make_color_rgb(208, 88, 72);   // Fighting
        case 3: return make_color_rgb(120, 152, 240); // Flying
        case 4: return make_color_rgb(168, 96, 208);  // Poison
        case 5: return make_color_rgb(216, 184, 88);  // Ground
        case 6: return make_color_rgb(184, 160, 72);  // Rock
        case 7: return make_color_rgb(152, 184, 56);  // Bug
        case 8: return make_color_rgb(112, 88, 152);  // Ghost
        case 9: return make_color_rgb(184, 184, 208); // Steel
        case 10: return make_color_rgb(232, 112, 56); // Fire
        case 11: return make_color_rgb(72, 152, 232); // Water
        case 12: return make_color_rgb(104, 192, 88); // Grass
        case 13: return make_color_rgb(248, 208, 72); // Electric
        case 14: return make_color_rgb(248, 120, 184); // Psychic
        case 15: return make_color_rgb(136, 208, 240); // Ice
        case 16: return make_color_rgb(112, 88, 240); // Dragon
        case 17: return make_color_rgb(112, 88, 72);  // Dark
        case 18: return make_color_rgb(240, 152, 184); // Fairy
    }
    return c_white;
}

function __dlg_stat_delta_color(_positive){
    return (_positive ? make_color_rgb(72, 168, 96) : make_color_rgb(216, 88, 72));
}

function __dlg_line_is_word_char(_ch){
    if (!is_string(_ch) || string_length(_ch) <= 0) return false;
    var _ord = ord(_ch);
    if (_ord >= ord("0") && _ord <= ord("9")) return true;
    if (_ord >= ord("A") && _ord <= ord("Z")) return true;
    if (_ord >= ord("a") && _ord <= ord("z")) return true;
    return false;
}

function __dlg_line_has_term_boundaries(_line, _start, _len){
    var _before_ok = true;
    var _after_ok = true;
    if (_start > 1){
        var _before = string_char_at(_line, _start - 1);
        _before_ok = !__dlg_line_is_word_char(_before);
    }
    var _after_idx = _start + _len;
    if (_after_idx <= string_length(_line)){
        var _after = string_char_at(_line, _after_idx);
        _after_ok = !__dlg_line_is_word_char(_after);
    }
    return _before_ok && _after_ok;
}

function __dlg_find_move_match(_line){
    if (!is_string(_line) || string_length(_line) <= 0) return undefined;
    if (!(variable_global_exists("_moves") && is_array(global._moves))) return undefined;

    var _line_lower = string_lower(_line);
    var _best = undefined;
    for (var _mid = 1; _mid < array_length(global._moves); ++_mid){
        var _move_name = "";
        try {
            if (!is_undefined(scr_move_name_by_id)) _move_name = string(scr_move_name_by_id(_mid));
        } catch (e_move_name) { _move_name = ""; }
        if (string_length(_move_name) <= 0) continue;
        var _move_lower = string_lower(_move_name);
        var _pos = string_pos(_move_lower, _line_lower);
        if (_pos <= 0) continue;
        if (!__dlg_line_has_term_boundaries(_line, _pos, string_length(_move_name))) continue;

        var _take = false;
        if (!is_struct(_best)) _take = true;
        else if (string_length(_move_name) > variable_struct_get(_best, "len")) _take = true;
        else if (string_length(_move_name) == variable_struct_get(_best, "len") && _pos < variable_struct_get(_best, "pos")) _take = true;

        if (_take){
            var _type_id = -1;
            try {
                if (!is_undefined(scr_move_type_id_by_id)) _type_id = scr_move_type_id_by_id(_mid);
            } catch (e_move_type) { _type_id = -1; }
            _best = {
                pos: _pos,
                len: string_length(_move_name),
                text: string_copy(_line, _pos, string_length(_move_name)),
                color: __dlg_type_color(_type_id)
            };
        }
    }
    return _best;
}

function __dlg_find_stat_match(_line){
    if (!is_string(_line) || string_length(_line) <= 0) return undefined;
    var _stats = ["ACCURACY", "EVASION", "ATK", "DEF", "SPA", "SPD", "SPE"];
    var _line_upper = string_upper(_line);
    var _best = undefined;

    for (var _i = 0; _i < array_length(_stats); ++_i){
        var _token = _stats[_i];
        var _pos = string_pos(_token, _line_upper);
        if (_pos <= 0) continue;

        var _tail = string_copy(_line, _pos + string_length(_token), string_length(_line) - (_pos + string_length(_token)) + 1);
        var _trimmed = _tail;
        while (string_length(_trimmed) > 0){
            var _lead = string_char_at(_trimmed, 1);
            if (_lead != " " && _lead != "\n" && _lead != "\r" && _lead != "\t") break;
            _trimmed = string_delete(_trimmed, 1, 1);
        }
        if (string_length(_trimmed) <= 0) continue;

        var _sign = string_char_at(_trimmed, 1);
        if (_sign != "+" && _sign != "-") continue;

        var _digits_len = 0;
        for (var _di = 2; _di <= string_length(_trimmed); ++_di){
            var _ch = string_char_at(_trimmed, _di);
            var _ord = ord(_ch);
            if (_ord < ord("0") || _ord > ord("9")) break;
            _digits_len += 1;
        }
        if (_digits_len <= 0) continue;

        var _delta_text = string_copy(_trimmed, 1, 1 + _digits_len);
        _best = {
            token_pos: _pos,
            token_len: string_length(_token),
            delta_pos: string_pos(_delta_text, _line),
            delta_len: string_length(_delta_text),
            positive: (_sign == "+")
        };
        break;
    }
    return _best;
}

function __dlg_style_line_parts(_line, _base_color = c_white){
    var _parts = [];
    if (!is_string(_line) || string_length(_line) <= 0){
        array_push(_parts, { text: "", color: _base_color });
        return _parts;
    }

    var _stat = __dlg_find_stat_match(_line);
    if (is_struct(_stat)){
        var _color = __dlg_stat_delta_color(variable_struct_get(_stat, "positive"));
        var _token_pos = variable_struct_get(_stat, "token_pos");
        var _token_len = variable_struct_get(_stat, "token_len");
        var _delta_pos = variable_struct_get(_stat, "delta_pos");
        var _delta_len = variable_struct_get(_stat, "delta_len");

        if (_token_pos > 1) array_push(_parts, { text: string_copy(_line, 1, _token_pos - 1), color: _base_color });
        array_push(_parts, { text: string_copy(_line, _token_pos, _token_len), color: _color });
        if (_delta_pos > (_token_pos + _token_len)) array_push(_parts, { text: string_copy(_line, _token_pos + _token_len, _delta_pos - (_token_pos + _token_len)), color: _base_color });
        array_push(_parts, { text: string_copy(_line, _delta_pos, _delta_len), color: _color });

        var _suffix_start = _delta_pos + _delta_len;
        if (_suffix_start <= string_length(_line)) array_push(_parts, { text: string_copy(_line, _suffix_start, string_length(_line) - _suffix_start + 1), color: _base_color });
        return _parts;
    }

    var _move = __dlg_find_move_match(_line);
    if (is_struct(_move)){
        var _pos_move = variable_struct_get(_move, "pos");
        var _len_move = variable_struct_get(_move, "len");
        if (_pos_move > 1) array_push(_parts, { text: string_copy(_line, 1, _pos_move - 1), color: _base_color });
        array_push(_parts, { text: variable_struct_get(_move, "text"), color: variable_struct_get(_move, "color") });
        var _move_end = _pos_move + _len_move;
        if (_move_end <= string_length(_line)) array_push(_parts, { text: string_copy(_line, _move_end, string_length(_line) - _move_end + 1), color: _base_color });
        return _parts;
    }

    array_push(_parts, { text: _line, color: _base_color });
    return _parts;
}

function __dlg_draw_styled_text(_text, _x, _y, _base_color = c_white){
    var _parts = __dlg_style_line_parts(_text, _base_color);
    var _cursor_x = _x;
    var _cursor_y = _y;
    var _char_w = __dlg_font_w();
    var _char_h = __dlg_font_h() + 2;
    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
    for (var _i = 0; _i < array_length(_parts); ++_i){
        var _part = _parts[_i];
        if (!is_struct(_part) || !variable_struct_exists(_part, "text")) continue;
        var _part_text = string(variable_struct_get(_part, "text"));
        if (string_length(_part_text) <= 0) continue;
        var _color = (variable_struct_exists(_part, "color") ? variable_struct_get(_part, "color") : c_white);
        draw_set_color(_color);
        for (var _ci = 1; _ci <= string_length(_part_text); ++_ci){
            var _ch = string_char_at(_part_text, _ci);
            if (_ch == "\n"){
                _cursor_x = _x;
                _cursor_y += _char_h;
                continue;
            }
            draw_text(_cursor_x, _cursor_y, _ch);
            _cursor_x += _char_w;
        }
    }
    draw_set_color(c_white);
}

function __dlg_draw_lines_spritefont(_l0, _l1, _x, _y, _base_color = c_white){
    var _page_text = _l0;
    if (_l1 != "") _page_text += "\n" + _l1;
    __dlg_draw_styled_text(_page_text, _x, _y, _base_color);
}


function dialog2p_draw_world(_pid, _cam){
    // If a battle is active for this pid, prefer drawing inside the battle GUI
    // to avoid double-rendering and coordinate mismatches. The battle renderer
    // will call dialog2p_draw_gui_rect.
    if (!is_undefined(battle_is_open) && battle_is_open(_pid)) return;
    var d = global.DIALOG2P[_pid];
    if (!d.open) return;

    // Debug logging for dialog draw. Disabled by default; enable by setting
    // global.DIALOG_DEBUG = true (requires DATA_DEBUG to also be true).
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG && variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG){
        try {
            // Only log when the page index changes or at most once per second to avoid spam
            var _pages = array_length(d.all_lines);
            var _state = string(d.page_idx) + "/" + string(_pages);
            var _last = (variable_struct_exists(d, "_dbg_last_state") ? variable_struct_get(d, "_dbg_last_state") : "");
            var _last_time = (variable_struct_exists(d, "_dbg_last_time") ? variable_struct_get(d, "_dbg_last_time") : -999999);
            var _now = (is_real(current_time) ? current_time : 0);
            if (_state != _last || (_now - _last_time) > 1000){
                show_debug_message("[dialog][debug] draw pid=" + string(_pid) + ", page_idx=" + string(d.page_idx) + ", pages=" + string(_pages) );
                variable_struct_set(d, "_dbg_last_state", _state);
                variable_struct_set(d, "_dbg_last_time", _now);
            }
        } catch (e_dbg) {}
    }

    var vx = camera_get_view_x(_cam);
    var vy = camera_get_view_y(_cam);
    var vw = camera_get_view_width(_cam);
    var vh = camera_get_view_height(_cam);

    var pad = d.border_pad;
    var name_h = (d.name_label != "" ? 14 : 0);
    var bw = d.box_w + pad*2;
    var bh = d.box_h + pad*2 + name_h;

    // clamp to camera & anchor bottom-center, crisp pixels
    bw = max(32, min(bw, vw - 2*d.margin_h));
    bh = max(24, min(bh, vh - 2*d.margin_v));

    var px = round(vx + (vw - bw) * 0.5);
    var py = round(vy + vh - (bh + d.margin_v));

    // panel
    draw_set_color(make_color_rgb(30,34,46));
    draw_rectangle(px, py, px + bw, py + bh, false);
    draw_set_color(make_color_rgb(80,85,100));
    draw_roundrect(px, py, px + bw, py + bh, false);

    // name
    var y_off = 0;
    if (d.name_label != ""){
        draw_set_color(c_white);
        draw_set_halign(fa_left);
        draw_text(px + pad, py + 4, d.name_label);
        y_off = 14;
    }

    // portrait (optional)
    var text_left = pad;
    if (d.portrait != noone){
        var ph = sprite_get_height(d.portrait);
        var pw = sprite_get_width(d.portrait);
        var scale = min((d.box_h) / max(1, ph), 1);
        var pox = round(px + pad);
        var poy = round(py + pad + y_off + (d.box_h - ph*scale) * 0.5);
        draw_sprite_ext(d.portrait, d.portrait_frame, pox, poy, scale, scale, 0, c_white, 1);
        text_left += pw*scale + 6;
    }

    // visible text of this page
    var a = d.lines[0], b = d.lines[1];
    var page_str = a + "\n" + b;
    var page_len = string_length(page_str);
    var vis_str  = string_copy(page_str, 1, d.char_idx);

    var vis0 = vis_str, vis1 = "";
    var npos = string_pos("\n", vis_str);
    if (npos > 0){
        vis0 = string_copy(vis_str, 1, npos - 1);
        vis1 = string_copy(vis_str, npos + 1, string_length(vis_str));
    }

    var tx = round(px + text_left);
    var ty = round(py + pad + y_off);
    __dlg_draw_lines_spritefont(vis0, vis1, tx, ty);

    // next-page arrow
    var has_next = ((d.page_idx+1)*2) < array_length(d.all_lines);
    if (d.char_idx >= page_len && has_next){
        if ((d.arrow_tick div 30) == 0){
            var ax = round(px + bw - pad - 12);
            var ay = round(py + bh - pad - 10);
            draw_set_color(c_white);
            draw_triangle(ax, ay, ax+8, ay, ax+4, ay+6, false);
        }
    }
}

// ---------- Draw in GUI space within a rect (battle/letterbox-friendly) -----
/// dialog2p_draw_gui_rect(pid, rx, ry, rw, rh)
/// Draws the classic dialog box anchored to the bottom-center of the provided
/// GUI-space rectangle. Mirrors the look/behavior of dialog2p_draw_world.
function dialog2p_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!variable_global_exists("DIALOG2P")) dialog2p_init();
    var d = global.DIALOG2P[_pid];
    if (!is_struct(d) || !d.open) return;

    var pad = d.border_pad;
    var name_h = (d.name_label != "" ? 14 : 0);
    var bw = d.box_w + pad*2;
    var bh = d.box_h + pad*2 + name_h;

    // clamp to rect & anchor bottom-center, crisp pixels
    bw = max(32, min(bw, _rw - 2*d.margin_h));
    bh = max(24, min(bh, _rh - 2*d.margin_v));

    var px = round(_rx + (_rw - bw) * 0.5);
    var py = round(_ry + _rh - (bh + d.margin_v));

    // panel
    draw_set_color(make_color_rgb(30,34,46));
    draw_rectangle(px, py, px + bw, py + bh, false);
    draw_set_color(make_color_rgb(80,85,100));
    draw_roundrect(px, py, px + bw, py + bh, false);

    // name
    var y_off = 0;
    if (d.name_label != ""){
        draw_set_color(c_white);
        draw_set_halign(fa_left);
        draw_text(px + pad, py + 4, d.name_label);
        y_off = 14;
    }

    // portrait (optional)
    var text_left = pad;
    if (d.portrait != noone){
        var ph = sprite_get_height(d.portrait);
        var pw = sprite_get_width(d.portrait);
        var scale = min((d.box_h) / max(1, ph), 1);
        var pox = round(px + pad);
        var poy = round(py + pad + y_off + (d.box_h - ph*scale) * 0.5);
        draw_sprite_ext(d.portrait, d.portrait_frame, pox, poy, scale, scale, 0, c_white, 1);
        text_left += pw*scale + 6;
    }

    // visible text of this page
    var a = d.lines[0], b = d.lines[1];
    var page_str = a + "\n" + b;
    var page_len = string_length(page_str);
    var vis_str  = string_copy(page_str, 1, d.char_idx);

    var vis0 = vis_str, vis1 = "";
    var npos = string_pos("\n", vis_str);
    if (npos > 0){
        vis0 = string_copy(vis_str, 1, npos - 1);
        vis1 = string_copy(vis_str, npos + 1, string_length(vis_str));
    }

    var tx = round(px + text_left);
    var ty = round(py + pad + y_off);
    __dlg_draw_lines_spritefont(vis0, vis1, tx, ty);

    // next-page arrow
    var has_next = ((d.page_idx+1)*2) < array_length(d.all_lines);
    if (d.char_idx >= page_len && has_next){
        if ((d.arrow_tick div 30) == 0){
            var ax = round(px + bw - pad - 12);
            var ay = round(py + bh - pad - 10);
            draw_set_color(c_white);
            draw_triangle(ax, ay, ax+8, ay, ax+4, ay+6, false);
        }
    }
}
