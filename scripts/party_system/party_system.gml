// [Party System]: party_system — Build v4.39.0 — Updated 2025-10-05
// Notes:
// - Controller + Keyboard only (no mouse use)
// - Unified description box: Pokemon flavor text (summary_profile) or Move text (summary_moves/forget)
// - Inventory+Arrows to scroll description
// - "Run/B" navigation: list <-> profile <-> moves <-> forget (back one level)
// - Interact-hold no longer moves selection
// - Color highlighting (first occurrence only): damage class + effect words + all types
// - Tunable art position via macros below
// - Scrollbar: brown fill + thin black outline, shifted 6px to the right
//   Use false in your player/controller code to suppress movement.

globalvar PARTY;
globalvar sys_party_desc_scroll_req;

// Implementations for swap helpers (moved here so they are declared early).
function party_set_swap_mode_impl(_pid, _swap, _forced){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    try {
        if (!variable_struct_exists(_P, "_battle_swap_mode")) variable_struct_set(_P, "_battle_swap_mode", false);
        if (!variable_struct_exists(_P, "_battle_swap_mode_forced")) variable_struct_set(_P, "_battle_swap_mode_forced", false);
        // Coerce booleans safely without using '!!' which confuses the parser
        if (_swap) variable_struct_set(_P, "_battle_swap_mode", true); else variable_struct_set(_P, "_battle_swap_mode", false);
        if (_swap && _forced) variable_struct_set(_P, "_battle_swap_mode_forced", true); else variable_struct_set(_P, "_battle_swap_mode_forced", false);
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            show_debug_message("[party_swap_helpers] party_set_swap_mode pid=" + string(_pid) + ", swap=" + string(_swap == true) + ", forced=" + string((_forced == true) && (_swap == true)));
        }
    } catch (e) {}
}

function party_clear_swap_mode_impl(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    try {
        variable_struct_set(_P, "_battle_swap_mode", false);
        variable_struct_set(_P, "_battle_swap_mode_forced", false);
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            show_debug_message("[party_swap_helpers] party_clear_swap_mode pid=" + string(_pid));
        }
    } catch (e) {}
}

// Expose the canonical names expected by other scripts by aliasing to impls.
function party_set_swap_mode(_pid, _swap, _forced){ return party_set_swap_mode_impl(_pid, _swap, _forced); }
function party_clear_swap_mode(_pid){ return party_clear_swap_mode_impl(_pid); }

#macro PARTY_ICON_H_UI 20
#macro PARTY_ROW_PAD_UI 7
#macro PARTY_HILITE_COL make_color_rgb(255,255,255)
#macro PARTY_HILITE_EDGE make_color_rgb(136,100,36)
#macro PARTY_HILITE_ALPHA 0.20

// Summary art offsets inside left panel
#macro PARTY_SUMMARY_ART_OFFSET_Y  8   // +down, -up (tweak as needed)
#macro PARTY_SUMMARY_ART_OFFSET_X  0   // +right, -left
#macro PARTY_SUMMARY_ART_MARGIN    2   // min gap above description

// Shiny sparkle tuning (icon list)
#macro PARTY_SHINY_SPARKLE_BASE_R    4   // base radius in UI pixels (scaled by _S)
#macro PARTY_SHINY_SPARKLE_ROT_SPEED 180 // deg/sec
#macro PARTY_SHINY_SPARKLE_PULSE_HZ  5   // pulse frequency

function __party_draw_shiny_sparkle(_x,_y,_S,_seed){
    // Forward to modular draw helper
    if (!is_undefined(__party_impl_draw_shiny_sparkle)) __party_impl_draw_shiny_sparkle(_x,_y,_S,_seed);
}

// NOTE: concrete implementations live in `scripts/party_draw/party_draw.gml`
// Do not define implementation functions here to avoid duplicate script names.

// ---------- Input lock helpers ----------
// (removed) party__recompute_input_lock
// (removed) party_is_input_locked
// ---------- Basic queries / toggles ----------
function party_is_open(_pid){
    if (!variable_global_exists("PARTY")) return false;
    if (!is_array(global.PARTY)) return false;
    if (array_length(global.PARTY) <= _pid) return false;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return false;
    if (!variable_struct_exists(_P,"open")) return false;
    return _P.open;
}
function party_open(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    _P.open         = true;
    _P.mode         = "list";
    _P.menu_sel     = 0;
    _P.swap_index   = -1;
    _P.sum_move_sel = 0;
    _P.sum_learn_sel= 0;
    _P.lock         = 4;
    // Reorder fainted mons to bottom when opening the party so UI shows alive mons first.
    if (!is_undefined(party_model_reorder_fainted_to_bottom)){
        try { party_model_reorder_fainted_to_bottom(_pid); } catch (e_re) {}
    }
    // Ensure the battle-swap marker is false by default; callers (battle) may set it.
    try { party_set_swap_mode_impl(_pid, false, false); } catch (e_psi) {}
    // Debug: report initial swap flags when opening party
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        var _bm_val = (variable_struct_exists(_P, "_battle_swap_mode") ? variable_struct_get(_P, "_battle_swap_mode") : false);
        var _bf_val = (variable_struct_exists(_P, "_battle_swap_mode_forced") ? variable_struct_get(_P, "_battle_swap_mode_forced") : false);
        show_debug_message("[party_system] party_open pid=" + string(_pid) + ", _battle_swap_mode=" + string(_bm_val) + ", _battle_swap_mode_forced=" + string(_bf_val));
    }
}
function party_close(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    _P.open = false;
    // Clear battle swap marker when closing so next open is normal, but preserve
    // the marker if a battle is still active for this player. This prevents
    // the Swap label from disappearing when the party is closed while the
    // battle remains open (e.g., early close during faint handling).
    var _battle_still_open = (is_undefined(battle_is_open) ? false : battle_is_open(_pid));
    if (!_battle_still_open){
        // Centralised clearing helper (no-op if structures aren't present)
        try { party_clear_swap_mode(_pid); } catch (e) {}
        // Debug: report cleared swap flags when closing party (only if battle not open)
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            var _bm_c = (variable_struct_exists(_P, "_battle_swap_mode") ? variable_struct_get(_P, "_battle_swap_mode") : "undef");
            var _bf_c = (variable_struct_exists(_P, "_battle_swap_mode_forced") ? variable_struct_get(_P, "_battle_swap_mode_forced") : "undef");
            show_debug_message("[party_system] party_close pid=" + string(_pid) + ", cleared -> _battle_swap_mode=" + string(_bm_c) + ", _battle_swap_mode_forced=" + string(_bf_c));
        }
    }
}
function party_toggle(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    _P.open = !_P.open;
    if (_P.open){
        _P.mode         = "list";
        _P.menu_sel     = 0;
        _P.swap_index   = -1;
        _P.sum_move_sel = 0;
        _P.sum_learn_sel= 0;
        _P.lock         = 4;
    }
    // restore font state for caller (use -1 as safe no-op when toggle called from code)
    __party_restore_font(-1);
}

// ---------- Initialization / ensure ----------
function party_init(){
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    var _players = 1;
    if (variable_global_exists("PAUSE_PLAYERS_ACTIVE")) _players = max(1, global.PAUSE_PLAYERS_ACTIVE);
    array_resize(global.PARTY, _players);
    for (var _pid = 0; _pid < _players; _pid++){
        if (!is_struct(global.PARTY[_pid])){
            global.PARTY[_pid] = {
                open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0,
                mons:[], sum_move_sel:0, sum_learn_sel:0
            };
        }
    }
}
function party_ensure(_pid){
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    if (!is_array(global.PARTY)) global.PARTY = [];
    if (array_length(global.PARTY) <= _pid) array_resize(global.PARTY, _pid + 1);
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)){
        _P = { open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0, mons:[], sum_move_sel:0, sum_learn_sel:0 };
        global.PARTY[_pid] = _P;
    }
    if (!variable_struct_exists(_P,"open"))          _P.open         = false;
    if (!variable_struct_exists(_P,"mode"))          _P.mode         = "list";
    if (!variable_struct_exists(_P,"sel"))           _P.sel          = 0;
    if (!variable_struct_exists(_P,"scroll"))        _P.scroll       = 0;
    if (!variable_struct_exists(_P,"menu_sel"))      _P.menu_sel     = 0;
    if (!variable_struct_exists(_P,"swap_index"))    _P.swap_index   = -1;
    if (!variable_struct_exists(_P,"lock"))          _P.lock         = 0;
    if (!variable_struct_exists(_P,"mons") || !is_array(_P.mons)) _P.mons = [];
    if (!variable_struct_exists(_P,"sum_move_sel"))  _P.sum_move_sel = 0;
    if (!variable_struct_exists(_P,"sum_learn_sel")) _P.sum_learn_sel= 0;
    if (!variable_struct_exists(_P,"learn_pending")) _P.learn_pending = undefined;
    // New animation state vars (summary page circle intro)
        if (!variable_struct_exists(_P,"summary_anim"))        _P.summary_anim = 0;      // frame counter
        if (!variable_struct_exists(_P,"summary_anim_active"))  _P.summary_anim_active = false;
        if (!variable_struct_exists(_P,"summary_prev_mode"))    _P.summary_prev_mode = string(_P.mode);
        // Sprite cry/intro animation state (profile page)
        if (!variable_struct_exists(_P,"summary_sprite_anim"))         _P.summary_sprite_anim = 0;
        if (!variable_struct_exists(_P,"summary_sprite_anim_active"))  _P.summary_sprite_anim_active = false;
        if (!variable_struct_exists(_P,"summary_last_cry_sel"))        _P.summary_last_cry_sel = -1;
        if (!variable_struct_exists(_P,"summary_sprite_anim_start_ms")) _P.summary_sprite_anim_start_ms = -1;
    if (!variable_struct_exists(_P,"summary_cur_scale"))    _P.summary_cur_scale = 1;
    if (!variable_struct_exists(_P,"summary_target_scale")) _P.summary_target_scale = 0.6;
    if (!variable_struct_exists(_P,"summary_spin_angle"))   _P.summary_spin_angle = 0;
    if (!variable_struct_exists(_P,"summary_prev_sel"))     _P.summary_prev_sel = _P.sel;
        if (!variable_struct_exists(_P,"summary_cur_scale"))    _P.summary_cur_scale = 1;  // current scale of selected circle
        if (!variable_struct_exists(_P,"summary_target_scale")) _P.summary_target_scale = 0.6; // desired shrunk scale
        if (!variable_struct_exists(_P,"summary_spin_angle"))   _P.summary_spin_angle = 0;  // degrees

    // --- Ensure every mon has OT + IDNo (trainer ID) ---
    if (is_array(_P.mons)){
        for (var __mi = 0; __mi < array_length(_P.mons); __mi++){
            var __m = _P.mons[__mi];
            if (is_struct(__m)){
                if (!variable_struct_exists(__m, "ot")){
                    var __otName = "YOU";
                    if (variable_global_exists("PLAYER_NAME")) __otName = string(global.PLAYER_NAME);
                    if (_pid == 1 && variable_global_exists("PLAYER2_NAME")) __otName = string(global.PLAYER2_NAME);
                    __m.ot = __otName;
                }
                if (!variable_struct_exists(__m, "idno")){
                    // Deterministic-ish 5-digit ID based on species + slot + pid for stability across a run
                    var __sid_seed = -1;
                    if (variable_struct_exists(__m,"species_id")) __sid_seed = __m.species_id;
                    else if (variable_struct_exists(__m,"_id")) __sid_seed = __m._id; // fallback
                    if (!is_real(__sid_seed) || __sid_seed < 0) __sid_seed = __mi * 17 + _pid * 101;
                    var __raw = ( (__sid_seed * 7919) + (__mi * 271) + (_pid * 997) ) mod 90000; // 0..89999
                    __m.idno = 10000 + __raw; // 10000..99999
                }
            }
        }

            // Ensure per-mon "seen" bookkeeping exists so the UI can mark newly
            // learned moves as (New) until the player inspects the learn list.
            if (is_array(_P.mons)){
                for (var __mi2 = 0; __mi2 < array_length(_P.mons); __mi2++){
                    var __m2 = _P.mons[__mi2];
                    if (is_struct(__m2)){
                        // initialize seen_moves to include any existing moves so only
                        // newly-learned moves are treated as "New".
                        if (!variable_struct_exists(__m2, "seen_moves")){
                            if (variable_struct_exists(__m2, "moves") && is_array(__m2.moves)){
                                __m2.seen_moves = [];
                                for (var __si = 0; __si < array_length(__m2.moves); __si++) array_push(__m2.seen_moves, __m2.moves[__si]);
                            } else {
                                __m2.seen_moves = [];
                            }
                        }
                        // track whether the player has opened the learn LIST for this mon
                        if (!variable_struct_exists(__m2, "learn_seen")) __m2.learn_seen = false;
                    }
                }
            }
    }

    var _n = array_length(_P.mons), _rows = 6;
    if (_n <= 0){ _P.sel = 0; _P.scroll = 0; }
    else {
        if (_P.sel >= _n) _P.sel = _n - 1;
        if (_P.sel < 0)   _P.sel = 0;
        var _max_scroll = max(0, _n - _rows);
        if (_P.scroll < 0) _P.scroll = 0;
        if (_P.scroll > _max_scroll) _P.scroll = _max_scroll;
        if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
        if (_P.sel >= _P.scroll + _rows) _P.scroll = max(0, _P.sel - _rows + 1);
    }
    return _P;
}

// ---------- Helpers ----------
function __party_mons(_pid){
    return party_model_get_mons(_pid);
}

// Basic string wrap fallback used by the learn UI if higher-level helper missing
if (is_undefined(string_wrap)){
    function string_wrap(_s, _cols){
        var out = [];
        if (!is_string(_s)) _s = string(_s);
        var words = string_split(_s, " ");
        var cur = "";
        for (var i = 0; i < array_length(words); i++){
            var w = words[i];
            if (string_length(cur) + string_length(w) + 1 > _cols){ array_push(out, cur); cur = w; }
            else { if (string_length(cur) == 0) cur = w; else cur = cur + " " + w; }
        }
        if (string_length(cur) > 0) array_push(out, cur);
        return out;
    }
}

// Fallback stub for move-learn logic (real implementations live in move_learn module)
if (is_undefined(scr_move_learn_try)){
    function scr_move_learn_try(_mon, _move_id){
        // Minimal conservative behavior: if mon has <4 moves, learn it; otherwise indicate need_replace
        if (!is_struct(_mon)) return { status: "skipped", slot:-1 };
        if (!variable_struct_exists(_mon, "moves") || !is_array(_mon.moves)) _mon.moves = [];
        for (var i = 0; i < array_length(_mon.moves); i++){
            if (_mon.moves[i] == _move_id) return { status: "skipped", slot:i };
        }
        if (array_length(_mon.moves) < 4){ array_push(_mon.moves, _move_id); return { status: "learned", slot: array_length(_mon.moves)-1 }; }
        return { status: "need_replace", slot: -1 };
    }
}
function __party_mon_get(_P, _pid){
    return party_model_get_mon(_pid, _P.sel);
}
function __party_move_name(_id){
    // Treat non-positive IDs as empty slots
    if (!is_real(_id) || _id <= 0) return "—";
    if (is_undefined(scr_move_name_by_id)) return "Move#" + string(_id);
    var _t = scr_move_name_by_id(_id);
    if (is_string(_t) && string_length(_t) > 0) return _t;
    return "Move#" + string(_id);
}

// Return an ordered array of move IDs this mon can currently learn.
// Filters out TM/HM entries and those with a required level higher than the mon's level.
function __party_get_learnset_for_mon(_mon){
    var _out = [];
    if (!is_struct(_mon)) return _out;
    var _level = undefined; if (variable_struct_exists(_mon, "level")) _level = variable_struct_get(_mon, "level");
    // Prefer structured per-mon learnset
    if (variable_struct_exists(_mon, "learnset") && is_array(variable_struct_get(_mon, "learnset"))){
        var _ls = variable_struct_get(_mon, "learnset");
    // debug message removed
        for (var i = 0; i < array_length(_ls); i++){
            var ent = _ls[i];
            var mid = undefined;
            var req_level = undefined;
            var _method = "";
            // Accept plain numeric move id
            if (is_real(ent)) { mid = ent; }
            else if (is_struct(ent)){
                if (variable_struct_exists(ent, "move")) mid = variable_struct_get(ent, "move");
                else if (variable_struct_exists(ent, "id")) mid = variable_struct_get(ent, "id");
                else if (variable_struct_exists(ent, "move_id")) mid = variable_struct_get(ent, "move_id");
                if (variable_struct_exists(ent, "level")) req_level = variable_struct_get(ent, "level");
                else if (variable_struct_exists(ent, "lvl")) req_level = variable_struct_get(ent, "lvl");
                if (variable_struct_exists(ent, "method")) _method = string(variable_struct_get(ent, "method"));
                else if (variable_struct_exists(ent, "by")) _method = string(variable_struct_get(ent, "by"));
                else if (variable_struct_exists(ent, "tm") && (variable_struct_get(ent, "tm") == true)) _method = "TM";
            } else if (is_string(ent)){
                // try to parse simple numeric string, otherwise skip if it mentions TM/HM
                var s = string_trim(ent);
                var su = string_upper(s);
                if (string_pos("TM", su) > 0 || string_pos("HM", su) > 0) { continue; }
                // attempt numeric parse
                var n = -1;
                try { n = real(s); } catch (e) { n = -1; }
                if (is_real(n) && n > 0) mid = n;
            }
            // Skip TM/HM methods
            if (string_length(string_trim(_method)) > 0){
                var mup = string_upper(string_trim(_method));
                if (string_pos("TM", mup) > 0 || string_pos("HM", mup) > 0) continue;
            }
            // Filter by required level
            if (is_real(req_level) && !is_undefined(_level)){
                if (req_level > _level) continue;
            }
            if (is_real(mid) && mid > 0) {
                // Include known moves in the learn list (they will be drawn darker by UI)
                // The UI draw code will visually de-emphasize moves present in _mon.moves.
                // If the move's flavor text explicitly states it "should be forgotten"
                // treat it as unlearnable and skip adding it to the learnset.
                var _skip_by_text = false;
                if (variable_global_exists("_move_text") && is_array(global._move_text) && mid < array_length(global._move_text)){
                    var _mvtxt = global._move_text[mid];
                    var _acc = "";
                    if (is_struct(_mvtxt)){
                        if (variable_struct_exists(_mvtxt, "short_desc")) _acc += string(variable_struct_get(_mvtxt, "short_desc")) + " ";
                        if (variable_struct_exists(_mvtxt, "effect")) _acc += string(variable_struct_get(_mvtxt, "effect"));
                    } else if (is_string(_mvtxt)) _acc = _mvtxt;
                    var _ld = string_lower(_acc);
                    if (string_pos("recommended that this move is forgotten", _ld) > 0
                        || string_pos("can't be remembered", _ld) > 0
                        || string_pos("cannot be remembered", _ld) > 0) {
                        _skip_by_text = true;
                    }
                }
                if (!_skip_by_text) array_push(_out, mid);
            }
        }
    // debug message removed
    }
    // Fallback: if no per-mon entries, return empty so caller can choose to fall back to global index
    return _out;
}

// Name helpers forwarded to modular implementation file
function mon_display_name(_mon){ if (!is_undefined(__party_impl_mon_display_name)) return __party_impl_mon_display_name(_mon); return "???"; }
function party_mon_ensure_name(_mon){ if (!is_undefined(__party_impl_party_mon_ensure_name)) return __party_impl_party_mon_ensure_name(_mon); return _mon; }
function party_apply_name_support(_pid){ if (!is_undefined(__party_impl_party_apply_name_support)) return __party_impl_party_apply_name_support(_pid); }
function party_set_nickname(_pid,_index,_nick){ if (!is_undefined(__party_impl_party_set_nickname)) return __party_impl_party_set_nickname(_pid,_index,_nick); return false; }
function party_ensure_named(_pid){ if (!is_undefined(__party_impl_party_ensure_named)) return __party_impl_party_ensure_named(_pid); return party_ensure(_pid); }
function battle_test_prepare_names(_pid){ if (!is_undefined(__party_impl_battle_test_prepare_names)) return __party_impl_battle_test_prepare_names(_pid); }


// ---------- Update ----------
function party_update(){
    // Prioritize learn UI input only when the learn LIST is active
    // (prevents a stale learn_pending struct from intercepting input when
    // the player merely navigates to the moves summary).
    if (!is_undefined(__party_input_learn)){
        if (party_is_open(0)){
            var _P = party_ensure(0);
            if (variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
                var _lp_tmp_check = variable_struct_get(_P, "learn_pending");
                var _lp_step_check = (variable_struct_exists(_lp_tmp_check, "step") ? variable_struct_get(_lp_tmp_check, "step") : "desc");
                // Only run the learn-list input handler when we're on the moves
                // summary page. If we're in summary_forget, let the main input
                // state machine handle replacement confirmation/navigation.
                if (string(_lp_step_check) == "list" && string(_P.mode) == "summary_moves"){
                    // Run the learn input handler when the learn LIST is active
                    // from the moves summary. Do NOT intercept during summary_forget
                    // so the replace-confirm code in the main state machine runs.
                    if (__party_input_learn(0)) {
                        return;
                    }
                }
            }
        }
    }
    // Forward to input module implementation (keeps API stable)
    if (!is_undefined(__party_impl_party_update)) __party_impl_party_update();
}

// ---------- Draw ----------
function party_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    // Forward to modular implementation in party_draw.gml when available.
    // Support either the canonical implementation name or the historical alias.
    if (!is_undefined(__party_impl_party_draw_gui_rect)) { __party_impl_party_draw_gui_rect(_pid, _rx, _ry, _rw, _rh); return; }
    // No implementation present: fallback is a no-op to avoid compile/runtime errors.
    return;
}

// ---------- Summary / Description ----------
function __party_draw_summary(_pid, _P, _OX, _OY, _S){
    if (!is_undefined(__party_impl_draw_summary)) { __party_impl_draw_summary(_pid, _P, _OX, _OY, _S); return; }
    // fallback: nothing to draw
}

// The actual implementation of __party_impl_draw_summary lives in
// `scripts/party_ui_helpers/party_ui_helpers.gml`. We forward to it from
// __party_draw_summary above; no fallback implementation is declared here to
// avoid duplicate script-name definitions.

// ---------- Summary helpers ----------
function __party_draw_profile_block(_M, _x, _y, _w, _h, _S){
    if (!is_undefined(__party_impl_draw_profile_block)) { __party_impl_draw_profile_block(_M,_x,_y,_w,_h,_S); return; }
}
function __party_draw_moves_block(_P, _M, _x, _y, _w, _h, _S, _highlightForget){
    if (!is_undefined(__party_impl_draw_moves_block)) return __party_impl_draw_moves_block(_P,_M,_x,_y,_w,_h,_S,_highlightForget);
    return "";
}

// Draw a secondary single-line help message across the bottom of the summary area.
function __party_draw_secondary_help(_text, _OX, _S, _leftInfo){
    if (!is_undefined(__party_impl_draw_secondary_help)) { __party_impl_draw_secondary_help(_text, _OX, _S, _leftInfo); return; }
}

// Draw the left panel (profile art + basic labels). Returns an object with desc geometry so parent can render text.
function __party_draw_left_panel(_P, _M, _OX, _OY, _S, _LEFT_X, _LEFT_Y, _LEFT_W, _LEFT_H){
    if (!is_undefined(__party_impl_draw_left_panel)) return __party_impl_draw_left_panel(_P,_M,_OX,_OY,_S,_LEFT_X,_LEFT_Y,_LEFT_W,_LEFT_H);
    return { descPad: 3*_S, descAreaH: 38*_S, descX: (_OX + _LEFT_X*_S) + 3*_S, descY: (_OY + _LEFT_Y*_S) + (_LEFT_H*_S) - 38*_S + 3*_S, descW: min((_LEFT_W + 10) * _S, (108 - _LEFT_X - 4) * _S) - 3*_S*2, descH: 38*_S - 3*_S*2 };
}

// Draw the right panel background and return x/y for content placement.
function __party_draw_right_frame(_OX, _OY, _S, _RIGHT_X, _RIGHT_Y, _RIGHT_W, _RIGHT_H){
    if (!is_undefined(__party_impl_draw_right_frame)) return __party_impl_draw_right_frame(_OX,_OY,_S,_RIGHT_X,_RIGHT_Y,_RIGHT_W,_RIGHT_H);
    var _rx1 = _OX + _RIGHT_X*_S, _ry1 = _OY + _RIGHT_Y*_S;
    var _rx2 = _OX + (_RIGHT_X + _RIGHT_W)*_S, _ry2 = _OY + (_RIGHT_Y + _RIGHT_H)*_S;
    return { rx1: _rx1, ry1: _ry1, rx2: _rx2, ry2: _ry2 };
}

// Return the appropriate description text for the summary page (species flavor or move text)
function __party_get_desc_text(_P, _M){
    var _descText = "";
    if (string(_P.mode) == "summary_profile") {
        // Resolve species id into a safe integer (accept real or numeric string)
        var _sid_desc_raw = -1;
        if (variable_struct_exists(_M,"species_id")) _sid_desc_raw = variable_struct_get(_M, "species_id");
        else if (variable_struct_exists(_M,"_id"))   _sid_desc_raw = variable_struct_get(_M, "_id");
        // coerce to integer safely
        var _sid_desc = -1;
        if (is_real(_sid_desc_raw)) _sid_desc = floor(_sid_desc_raw);
        else if (is_string(_sid_desc_raw)) {
            var _st = string_trim(_sid_desc_raw);
            if (string_length(_st) > 0) {
                // try to parse numeric content
                var _val = 0;
                try { _val = real(_st); } catch (ee) { _val = -1; }
                if (is_real(_val)) _sid_desc = floor(_val);
            }
        }

        if (_sid_desc >= 0 && variable_global_exists("_species_flavor_text")) {
            var _sarr = global._species_flavor_text;
            var _sv = undefined;
            // Array-backed lookup
            if (is_array(_sarr) && _sid_desc < array_length(_sarr)) {
                _sv = _sarr[_sid_desc];
            }
            // Struct-backed lookup (keys may be numeric strings)
            else if (is_struct(_sarr)) {
                var _k = string(_sid_desc);
                if (variable_struct_exists(_sarr, _k)) _sv = variable_struct_get(_sarr, _k);
            }
            // ds_map-backed lookup
            else if (is_real(_sarr) && ds_exists(_sarr, ds_type_map)) {
                var _k2 = string(_sid_desc);
                if (ds_map_exists(_sarr, _k2)) _sv = ds_map_find_value(_sarr, _k2);
            }

            // DEBUG: report what we found when DATA_DEBUG is set
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
                var _typeStr = is_string(_sv) ? "string" : (is_struct(_sv) ? "struct" : (is_real(_sv) ? "real" : "other"));
                var _rawPreview = "";
                if (is_string(_sv)) _rawPreview = string_trim(_sv);
                else if (is_real(_sv)) _rawPreview = string(_sv);
                else if (is_struct(_sv)) {
                    var _has_short = variable_struct_exists(_sv, "short_desc");
                    var _has_eff = variable_struct_exists(_sv, "effect");
                    var _sdv = _has_short ? string(variable_struct_get(_sv, "short_desc")) : "";
                    var _efv = _has_eff ? string(variable_struct_get(_sv, "effect")) : "";
                    _rawPreview = "short_len=" + string(string_length(string_trim(_sdv))) + ",eff_len=" + string(string_length(string_trim(_efv)));
                }
                // debug removed
            }

            // Accept if it's a non-empty string
            if (is_string(_sv) && string_length(string_trim(_sv)) > 0) {
                _descText = string_trim(string(_sv));
            }
            // Some loaders may store a struct with keys like short_desc/effect
            else if (is_struct(_sv)) {
                var _sd = variable_struct_exists(_sv, "short_desc") ? string(variable_struct_get(_sv, "short_desc")) : "";
                var _ef = variable_struct_exists(_sv, "effect") ? string(variable_struct_get(_sv, "effect")) : "";
                if (string_length(string_trim(_sd)) > 0) _descText = string_trim(_sd);
                else if (string_length(string_trim(_ef)) > 0) _descText = string_trim(_ef);
            }
            // otherwise ignore numeric 0 or undefined entries to avoid rendering "0"
        }
        // Fallback: if no flavor text, show the species display name if available
        if (string_length(string_trim(_descText)) == 0) {
            if (!is_undefined(scr_poke_name_by_id)) {
                var _nm = scr_poke_name_by_id(_sid_desc);
                if (is_string(_nm) && string_length(string_trim(_nm)) > 0) _descText = string_trim(_nm);
            }
        }
    } else {
        var _mid_show = -1;
        var _mv_arr = is_struct(_M) && variable_struct_exists(_M,"moves") ? _M.moves : [];
        if (array_length(_mv_arr) > 0) {
            if (_P.sum_move_sel >= 0 && _P.sum_move_sel < array_length(_mv_arr)) {
                _mid_show = _mv_arr[_P.sum_move_sel];
            }
        }
        if (_mid_show > 0 && variable_global_exists("_move_text")) {
                var _mt = global._move_text;
                if (is_array(_mt) && _mid_show >= 0 && _mid_show < array_length(_mt)) {
                    var _vv = _mt[_mid_show];
                if (is_struct(_vv)) {
                    var _sd = (!is_undefined(_vv.short_desc)) ? string(_vv.short_desc) : "";
                    var _ef = (!is_undefined(_vv.effect)) ? string(_vv.effect) : "";
                    _descText = (string_length(_sd) > 0) ? _sd : _ef;
                } else if (is_string(_vv)) {
                    _descText = _vv;
                }
            }
        }
    }
    return _descText;
}

// Draw top hints and the six selection circles used on the summary page.
function __party_draw_header_and_circles(_P, _OX, _OY, _S, _n, _C_ACC, _C_PAPER){
    if (!is_undefined(__party_impl_draw_header_and_circles)) { __party_impl_draw_header_and_circles(_P,_OX,_OY,_S,_n,_C_ACC,_C_PAPER); return; }
}

// ---------- Text helpers ----------
function __party_desc_clean_local(_s){
    if (!is_undefined(__party_impl_desc_clean_local)) return __party_impl_desc_clean_local(_s);
    // fallback
    var _t = string(_s);
    _t = string_replace_all(_t, "\n", " ");
    _t = string_replace_all(_t, "\r", " ");
    _t = string_replace_all(_t, "\f", " ");
    while (string_pos("  ", _t) > 0) _t = string_replace_all(_t, "  ", " ");
    return string_trim(_t);
}

// --- Scrollable & colored text renderer (first occurrence highlight) ---
function __party_desc_draw_scrollable_colored(_x, _y, _w, _h, _text) {
    // Forward to modular implementation
    if (!is_undefined(__party_impl_desc_draw_scrollable_colored)) __party_impl_desc_draw_scrollable_colored(_x, _y, _w, _h, _text);
}

// --- Move learn UI helpers (Emerald-style) ---
// Open the learn flow for a party mon: opens summary and sets learn_pending
function __party_learn_open(_pid, _mon_index, _move_id){
    var P = party_ensure(_pid);
    if (!is_struct(P)) return;
    // Ensure the party UI is open so the learn summary will be drawn
    P.open = true;
    P.mode = "summary_moves";
    P.lock = 6;
    P.sum_move_sel = 0;
    P.sum_learn_sel = 0;
    P.sel = _mon_index;
    // learn_pending holds move to teach and UI state
    var _lp = {};
    _lp.move_id = _move_id;
    // Start on the description page by default; player must press Interact to open the list
    _lp.step = "desc";
    _lp.scroll = 0;
    _lp.list_scroll = 0;
    variable_struct_set(P, "learn_pending", _lp);
}

// Draw top-left learn badge if there are moves to learn pending
function __party_draw_learn_badge(_P, _OX, _OY, _S){
    if (!is_struct(_P) || !variable_struct_exists(_P, "learn_pending")) return;
    var lp = _P.learn_pending;
    if (!is_struct(lp)) return;
    // Badge drawing is handled by the party UI helpers so it can be
    // positioned relative to the right description panel (avoid overlap).
    return;
}

// Draw the learn-desc page (move description with scrolling). Right button switches to learn list.
function __party_draw_learn_desc(_pid, _P, _OX, _OY, _S, _descX, _descY, _descW, _descH){
    if (!is_struct(_P) || !variable_struct_exists(_P, "learn_pending")) return;
    var lp = _P.learn_pending;
    if (!is_struct(lp)) return;
    var move_id = (variable_struct_exists(lp, "move_id") ? lp.move_id : -1);
    var mname = __party_move_name(move_id);
    // header (no "Right to list" hint — we're already in the learn flow)
    draw_set_color(c_white);
    __party_text_white(_descX, _descY - 12*_S, mname + "?");
    // description text
    var desc = "";
    if (is_real(move_id) && move_id >= 0 && variable_global_exists("_move_text") && is_array(global._move_text) && move_id < array_length(global._move_text)){
        var mv = global._move_text[move_id];
        if (is_string(mv)) desc = mv; else if (is_struct(mv) && variable_struct_exists(mv, "short_desc")) desc = variable_struct_get(mv, "short_desc");
    }
    if (string_length(string_trim(desc)) == 0) desc = "No description available.";
    // Use the existing scrollable renderer if available
    if (!is_undefined(__party_impl_desc_draw_scrollable_colored)){
        __party_impl_desc_draw_scrollable_colored(_descX, _descY, _descW, _descH, desc);
    } else {
        // fallback: simple clipped draw with manual wrapping
        var lines = string_wrap(desc, floor(_descW / (6*_S)));
        var maxLines = floor(_descH / (10*_S));
        var start = lp.scroll;
        for (var i = 0; i < maxLines; i++){
            var li = start + i;
            if (li >= array_length(lines)) break;
            draw_text(_descX, _descY + i * (10*_S), lines[li]);
        }
    }
}

// Draw the learn list (long list scrolling). Selecting a move will attempt to learn it.
function __party_draw_learn_list(_pid, _P, _OX, _OY, _S, _rx, _ry, _rw, _rh, _descX, _descY, _descW, _descH){
    if (!is_struct(_P) || !variable_struct_exists(_P, "learn_pending")) return;
    var lp = _P.learn_pending;
    if (!is_struct(lp)) return;
    // Prefer a filtered per-mon learnset (level appropriate, non-TM/HM),
    // fall back to global move index or a small dummy list
    var move_index = [];
    var mon = (is_array(_P.mons) && _P.sel < array_length(_P.mons)) ? _P.mons[_P.sel] : undefined;
    if (is_struct(mon)){
        move_index = __party_get_learnset_for_mon(mon);
    }
    if (!is_array(move_index) || array_length(move_index) == 0){
        if (variable_global_exists("_move_index") && is_array(global._move_index)) move_index = global._move_index;
        else { move_index = []; for (var ii = 1; ii <= 50; ii++) array_push(move_index, ii); }
    }
    var total = array_length(move_index);
    // Layout tuning: compute line height and padding so spacing is consistent across scales
    var _line_h = 10 * _S;
    var _pad = 3 * _S;
    // Reserve a small header area at the top of the right box for the page counter
    var _header_h = _line_h;
    // Compute list top/bottom inside the right box so the list starts below the header
    var _list_top = _ry + _pad + _header_h;
    var _list_bottom = _ry + _rh - _pad;
    if (_list_bottom < _list_top) _list_bottom = _list_top;
    var _list_area_h = max(0, _list_bottom - _list_top);
    var perPage = max(4, floor(_list_area_h / _line_h));
    if (!variable_struct_exists(lp, "list_sel")) lp.list_sel = 0;
    if (!variable_struct_exists(lp, "list_scroll")) lp.list_scroll = 0;
    // Clamp selection
    lp.list_sel = clamp(lp.list_sel, 0, max(0, total - 1));
    // Ensure scroll keeps selection visible
    if (lp.list_sel < lp.list_scroll) lp.list_scroll = lp.list_sel;
    if (lp.list_sel >= lp.list_scroll + perPage) lp.list_scroll = lp.list_sel - perPage + 1;
    var start = clamp(lp.list_scroll, 0, max(0, total - perPage));

    // title and paging info are drawn in the reserved bottom area (above the list padding)

    // Compute selected move description text early so the right-side description can be rendered later
    var _sel_idx2 = (variable_struct_exists(lp, "list_sel") ? lp.list_sel : 0);
    var _sel_mid = -1;
    if (is_array(move_index) && _sel_idx2 >= 0 && _sel_idx2 < array_length(move_index)) _sel_mid = move_index[_sel_idx2];
    if (_sel_mid < 0 && variable_struct_exists(lp, "move_id")) _sel_mid = lp.move_id;
    var _desc_bot = "";
    if (is_real(_sel_mid) && _sel_mid >= 0 && variable_global_exists("_move_text") && is_array(global._move_text) && _sel_mid < array_length(global._move_text)){
        var _mvt = global._move_text[_sel_mid];
        if (is_string(_mvt)) _desc_bot = _mvt;
        else if (is_struct(_mvt) && variable_struct_exists(_mvt, "short_desc")) _desc_bot = variable_struct_get(_mvt, "short_desc");
    }

    // draw entries into the RIGHT panel area (fill the right box above the footer)
    var _known = [];
    if (is_struct(mon) && variable_struct_exists(mon, "moves")){
        var _tmpmoves2 = variable_struct_get(mon, "moves");
        if (is_array(_tmpmoves2)) _known = _tmpmoves2;
    }
    // If the player is hovering/selecting a move in the list, mark that move
    // as seen for this mon so the '(New)' marker disappears immediately.
    if (is_struct(mon) && is_real(_sel_mid) && _sel_mid >= 0){
        var _smarr = (variable_struct_exists(mon, "seen_moves") ? variable_struct_get(mon, "seen_moves") : undefined);
        if (!is_array(_smarr)) _smarr = [];
        var _already = false;
        for (var __zz = 0; __zz < array_length(_smarr); __zz++) if (_smarr[__zz] == _sel_mid) { _already = true; break; }
        // Only add if not already known (we want known to remain known) and not present in seen
        var _isKnownForSel = false;
        for (var __k2 = 0; __k2 < array_length(_known); __k2++) if (_known[__k2] == _sel_mid) { _isKnownForSel = true; break; }
        if (!_already && !_isKnownForSel){ array_push(_smarr, _sel_mid); variable_struct_set(mon, "seen_moves", _smarr); }
    }
    var _list_x = _rx + _pad;
    var _list_y = _list_top;
    var _list_w = max(0, _rw - _pad*2);
    // Let the list fill the right-box area below the header
    var _list_h = max(0, _list_bottom - _list_top);
    // recompute perPage from right-box available height so the list fills it
    perPage = max(4, floor(_list_h / _line_h));
    for (var jj = 0; jj < perPage; jj++){
        var idx = start + jj; if (idx >= total) break;
        var mid = move_index[idx];
        var txt = __party_move_name(mid);
        var yy = _list_y + jj * _line_h;
        // Safety: stop drawing entries if they'd exceed the right-box list area
        if (yy + _line_h > _list_y + _list_h) break;
        var isKnown = false;
        for (var k = 0; k < array_length(_known); k++) if (_known[k] == mid) { isKnown = true; break; }

        // Determine if this move is 'New' for this mon (not in seen_moves and not known)
        var _is_new = false;
        if (is_struct(mon) && variable_struct_exists(mon, "seen_moves") && is_array(variable_struct_get(mon, "seen_moves"))){
            var _sm_tmp = variable_struct_get(mon, "seen_moves");
            var _found_new = true;
            for (var _zz = 0; _zz < array_length(_sm_tmp); _zz++) if (_sm_tmp[_zz] == mid) { _found_new = false; break; }
            _is_new = _found_new && !isKnown;
        }

        if (idx == lp.list_sel){
            draw_set_color(c_white);
            __party_text_white(_list_x, yy, "> " + txt + (isKnown ? " (known)" : ""));
            if (_is_new){ draw_set_color(make_color_rgb(220,40,40)); draw_text(_list_x + string_width("> " + txt + (isKnown ? " (known)" : "")) + 6*_S, yy, "(New)"); draw_set_color(c_white); }
        } else {
            if (isKnown) draw_set_color(make_color_rgb(160,160,160)); else draw_set_color(make_color_rgb(220,220,220));
            draw_text(_list_x, yy, "  " + txt + (isKnown ? " (known)" : ""));
            if (_is_new){ draw_set_color(make_color_rgb(220,40,40)); draw_text(_list_x + string_width("  " + txt + (isKnown ? " (known)" : "")) + 6*_S, yy, "(New)"); draw_set_color(c_white); }
        }
    }
    // persist updated scroll/sel
    lp.list_scroll = start;
    variable_struct_set(_P, "learn_pending", lp);
    // Draw the selected-move description into the LEFT description box (user wanted list in right panel)
    if (string_length(string_trim(_desc_bot)) > 0){
        if (!is_undefined(__party_impl_desc_draw_scrollable_colored)){
            __party_impl_desc_draw_scrollable_colored(_descX + _pad, _descY + _pad, _descW - _pad*2, _descH - _pad*2, _desc_bot);
        } else {
            var _lines = string_wrap(_desc_bot, floor((_descW - _pad*2) / (6*_S)));
            var _max = floor((_descH - _pad*2) / _line_h);
            for (var li=0; li<min(array_length(_lines), _max); li++) draw_text(_descX + _pad, _descY + _pad + li * _line_h, _lines[li]);
        }
    }
    // Draw the page counter in the top-right header area of the right box
    if (total > perPage){
        var pageStr = string(start+1) + "-" + string(min(total, start+perPage)) + " of " + string(total);
        var _page_x = _rx + _rw - _pad - (string_length(pageStr) * 6 * _S);
        var _page_y = _ry + _pad; // inside header at top-right
        draw_set_color(make_color_rgb(200,200,200)); __party_text_white(_page_x, _page_y, pageStr);
    }
    // Draw footer title (selection instruction) centered under both boxes (full 240*_S UI)
    var _footer_y = _ry + _rh + _pad + 6 * _S; // small gap below the right box; nudge down 6 UI px
    var _footerTxt = "Select move to teach:";
    // Temporarily ensure font used for width measurement is the party font
    var _oldFont = draw_get_font();
    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
    draw_set_color(c_white);
    var _textW = string_width(_footerTxt);
    var _center_x = _OX + (120 * _S) - (_textW / 2);
    draw_text(_center_x, _footer_y, _footerTxt);
    // restore font
    draw_set_font(_oldFont);
}

// Input helper: handle right to switch from description to learn list, and scrolling/select in list
function __party_input_learn(_pid){
    var P = party_ensure(_pid);
    if (!is_struct(P) || !variable_struct_exists(P, "learn_pending")) return false;
    // Debug: report that input handler was entered and current step
    var _lp_dbg_in = variable_struct_get(P, "learn_pending");
    var _lp_dbg_step = (variable_struct_exists(_lp_dbg_in, "step") ? variable_struct_get(_lp_dbg_in, "step") : "desc");
    // debug removed
    var lp = variable_struct_get(P, "learn_pending");
    // If on desc page: Right -> go to list
    var _step = (variable_struct_exists(lp, "step") ? variable_struct_get(lp, "step") : "desc");
    if (_step == "desc"){
        // In the DESCRIPTION page: do NOT open the move list on Interact.
        // Interact should only be meaningful when the user is actively
        // selecting moves in the LIST view.
        // Allow closing the learn module with MoveRight (user requested behavior: Right closes when on description)
        if (controls_pressed(_pid, "MoveRight")){
            // Switch from description to the selectable learn LIST.
            // Initialize list selection to the pending move_id if possible.
            var _lp2 = lp;
            // Build move_index the same way the list rendering/input uses it
            var _move_index_tmp = [];
            var _mon_tmp = (is_array(P.mons) && P.sel < array_length(P.mons)) ? P.mons[P.sel] : undefined;
            if (is_struct(_mon_tmp)) _move_index_tmp = __party_get_learnset_for_mon(_mon_tmp);
            if (!is_array(_move_index_tmp) || array_length(_move_index_tmp) == 0){
                if (variable_global_exists("_move_index") && is_array(global._move_index)) _move_index_tmp = global._move_index;
                else { _move_index_tmp = []; for (var __ii = 1; __ii <= 50; __ii++) array_push(_move_index_tmp, __ii); }
            }
            var _total_tmp = array_length(_move_index_tmp);
            if (_total_tmp <= 0){
                // nothing to show, remain on description
                variable_struct_set(P, "learn_pending", _lp2);
                return true;
            }
            // find the pending move_id in the index if provided
            var _preferred = -1;
            if (variable_struct_exists(_lp2, "move_id")) _preferred = _lp2.move_id;
            var _start_sel = 0;
            if (is_real(_preferred) && _preferred >= 0){
                for (var __j = 0; __j < _total_tmp; __j++){
                    if (_move_index_tmp[__j] == _preferred){ _start_sel = __j; break; }
                }
            }
            variable_struct_set(_lp2, "step", "list");
            variable_struct_set(_lp2, "list_sel", _start_sel);
            variable_struct_set(_lp2, "list_scroll", max(0, _start_sel - 3));
            // Mark this mon's learn list as viewed and record seen learnset entries
            if (is_struct(_mon_tmp)){
                // set learn_seen flag
                if (!variable_struct_exists(_mon_tmp, "learn_seen")) variable_struct_set(_mon_tmp, "learn_seen", true);
                else variable_struct_set(_mon_tmp, "learn_seen", true);
                // ensure seen_moves is an array
                if (!variable_struct_exists(_mon_tmp, "seen_moves") || !is_array(variable_struct_get(_mon_tmp, "seen_moves"))) variable_struct_set(_mon_tmp, "seen_moves", []);
                // Add all entries from the computed move_index_tmp to seen_moves
                var _seen_arr = variable_struct_get(_mon_tmp, "seen_moves");
                if (!is_array(_seen_arr)) { _seen_arr = []; variable_struct_set(_mon_tmp, "seen_moves", _seen_arr); }
                for (var __a = 0; __a < array_length(_move_index_tmp); __a++){
                    var __mid = _move_index_tmp[__a];
                    var __found = false;
                    for (var __b = 0; __b < array_length(_seen_arr); __b++) if (_seen_arr[__b] == __mid) { __found = true; break; }
                    if (!__found) array_push(_seen_arr, __mid);
                }
                variable_struct_set(_mon_tmp, "seen_moves", _seen_arr);
            }
            variable_struct_set(P, "learn_pending", _lp2);
            return true;
        }
    } else if (_step == "list"){
        // Allow the player to hold Inventory and use Up/Down to scroll the
        // description even while the learn LIST is active. This was previously
        // handled in the general input path which we skip when the learn input
        // handler runs, so add the behavior here.
        if (controls_down(_pid, "Inventory")){
            // Description scrolling while the learn LIST is active is handled by
            // the dedicated input logic in `party_input`. Consume the Inventory
            // input here to avoid duplicate updates to
            // `global.sys_party_desc_scroll_req` which caused jumpy behavior.
            return true;
        }
        // (input diagnostics removed)

        // Prefer per-mon filtered learnset for input navigation as well
        var move_index = [];
        var mon = (is_array(P.mons) && P.sel < array_length(P.mons)) ? P.mons[P.sel] : undefined;
        if (is_struct(mon)) move_index = __party_get_learnset_for_mon(mon);
        if (!is_array(move_index) || array_length(move_index) == 0){
            if (variable_global_exists("_move_index") && is_array(global._move_index)) move_index = global._move_index;
            else { move_index = []; for (var ii = 1; ii <= 50; ii++) array_push(move_index, ii); }
        }
        var total = array_length(move_index);
        if (total <= 0) return false;
        if (!variable_struct_exists(lp, "list_sel")) variable_struct_set(lp, "list_sel", 0);
        if (!variable_struct_exists(lp, "list_scroll")) variable_struct_set(lp, "list_scroll", 0);
    var perPage = 6;
        // navigation: up/down
        if (controls_pressed(_pid, "MoveDown")) { var _cur = variable_struct_get(lp, "list_sel"); _cur = min(total-1, _cur + 1); variable_struct_set(lp, "list_sel", _cur); if (_cur - variable_struct_get(lp, "list_scroll") >= perPage) variable_struct_set(lp, "list_scroll", _cur - perPage + 1); variable_struct_set(P, "learn_pending", lp); return true; }
        if (controls_pressed(_pid, "MoveUp")) { var _cur = variable_struct_get(lp, "list_sel"); _cur = max(0, _cur - 1); variable_struct_set(lp, "list_sel", _cur); if (_cur < variable_struct_get(lp, "list_scroll")) variable_struct_set(lp, "list_scroll", _cur); variable_struct_set(P, "learn_pending", lp); return true; }
        // page up/down (if you have bindings)
        if (controls_pressed(_pid, "PageDown")) { var _cur = variable_struct_get(lp, "list_sel"); _cur = min(total-1, _cur + perPage); variable_struct_set(lp, "list_sel", _cur); variable_struct_set(lp, "list_scroll", min(max(0, total-perPage), _cur)); variable_struct_set(P, "learn_pending", lp); return true; }
        if (controls_pressed(_pid, "PageUp")) { var _cur = variable_struct_get(lp, "list_sel"); _cur = max(0, _cur - perPage); variable_struct_set(lp, "list_sel", _cur); if (_cur < variable_struct_get(lp, "list_scroll")) variable_struct_set(lp, "list_scroll", _cur); variable_struct_set(P, "learn_pending", lp); return true; }
        // confirm: teach selected move
        if (controls_pressed(_pid, "Interact")){
            // Use the per-mon filtered move_index computed above for selection.
            // If it's empty, fall back to global._move_index or a dummy range.
            if (!is_array(move_index) || array_length(move_index) == 0){
                if (variable_global_exists("_move_index") && is_array(global._move_index)) move_index = global._move_index;
                else { move_index = []; for (var __ii = 1; __ii <= 50; __ii++) array_push(move_index, __ii); }
            }
            var chosen_mid = (lp.list_sel >= 0 && lp.list_sel < array_length(move_index)) ? move_index[lp.list_sel] : -1;
            if (chosen_mid <= 0) return false;
            // Prevent teaching a move the mon already knows
            var _already_known = false;
            if (is_struct(mon) && variable_struct_exists(mon, "moves") && is_array(variable_struct_get(mon, "moves"))){
                var _mm = variable_struct_get(mon, "moves");
                for (var __kk = 0; __kk < array_length(_mm); __kk++) if (_mm[__kk] == chosen_mid){ _already_known = true; break; }
            }
            if (_already_known){
                try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, __party_move_name(chosen_mid) + " is already known."); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, __party_move_name(chosen_mid) + " is already known.", __party_move_name(chosen_mid) + " is already known.", "any"); } catch(e_){}
                // keep learn_pending active and remain on list
                variable_struct_set(P, "learn_pending", lp);
                return true;
            }
            // attempt teach using scr_move_learn_try if available
            var mon_idx = P.sel;
            var mon = (is_array(P.mons) && mon_idx < array_length(P.mons)) ? P.mons[mon_idx] : undefined;
            // debug removed
            var res = scr_move_learn_try(mon, chosen_mid);
            // debug removed
            if (is_struct(res) && string(res.status) == "learned"){
                // persist mon changes back into party structure if our stub altered it
                if (is_struct(mon) && is_array(P.mons) && mon_idx >= 0 && mon_idx < array_length(P.mons)) P.mons[mon_idx] = mon;
                // show learned dialog (use dialog helper if present)
                try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, __party_move_name(chosen_mid) + " learned!"); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, __party_move_name(chosen_mid) + " learned!", __party_move_name(chosen_mid) + " learned!", "any"); } catch(e_){}
                // clear pending
                variable_struct_set(P, "learn_pending", undefined);
                return true;
            } else if (is_struct(res) && string(res.status) == "need_replace"){
                // Transition: show replace flow and present the full learn LIST
                try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Need to forget a move — please pick which to replace in the moves screen."); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, "Need to forget a move — please pick which to replace in the moves screen.", "Need to forget a move — please pick which to replace in the moves screen.", "any"); } catch(e_){}
                // Enter forget mode
                P.mode = "summary_forget";
                // Ensure the learn list wrapper is visible while forgetting so the
                // player can choose the replacement. Initialize selection/scroll.
                if (is_struct(lp)){
                    variable_struct_set(lp, "step", "list");
                    if (!variable_struct_exists(lp, "list_sel")) variable_struct_set(lp, "list_sel", 0);
                    if (!variable_struct_exists(lp, "list_scroll")) variable_struct_set(lp, "list_scroll", 0);
                }
                variable_struct_set(P, "learn_pending", lp);
                return true;
            } else {
                try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, __party_move_name(chosen_mid) + " not learned."); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, __party_move_name(chosen_mid) + " not learned.", __party_move_name(chosen_mid) + " not learned.", "any"); } catch(e_){}
                variable_struct_set(P, "learn_pending", undefined);
                return true;
            }
        }
        // cancel/back
        if (controls_pressed(_pid, "Run") || controls_pressed(_pid, "Back")){
            lp.step = "desc";
            variable_struct_set(P, "learn_pending", lp);
            return true;
        }
    }
    return false;
}

// ---------- Entrypoint ----------
function party_draw_gui(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    party_draw_gui_rect(_pid, 0, 0, _gw, _gh);
}

// Ensure draw alpha restored after party GUI draw (safety net)
draw_set_alpha(1);

// [Party UI]: party__draw_scrollbar — Build v1.3 — 2025-10-05
function party__draw_scrollbar(_rx, _ry, _rw, _rh, _scroll, _pageSize, _totalItems) {
    if (!is_undefined(__party_impl_draw_scrollbar)) __party_impl_draw_scrollbar(_rx,_ry,_rw,_rh,_scroll,_pageSize,_totalItems);
}

// Draw the right-side content based on current mode and return the secondary help line (string).
function __party_draw_right_content(_P, _M, _rightInfo, _RIGHT_W, _RIGHT_H, _S){
    if (!is_undefined(__party_impl_draw_right_content)) return __party_impl_draw_right_content(_P,_M,_rightInfo,_RIGHT_W,_RIGHT_H,_S);
    return "";
}

// --- Local font helpers for consistent font state ---
function __party_use_font(){
    if (!is_undefined(__party_impl_use_font)) return __party_impl_use_font();
    var _old = -1;
    if (variable_global_exists("FNT_POKEMON")){
        _old = draw_get_font();
        draw_set_font(global.FNT_POKEMON);
    }
    return _old;
}
function __party_restore_font(_old){
    if (!is_undefined(__party_impl_restore_font)) { __party_impl_restore_font(_old); return; }
    if (_old != -1) draw_set_font(_old);
}

// Draw white text using canonical party font (if present) and keep color set
function __party_text_white(_x,_y,_txt){
    if (!is_undefined(__party_impl_text_white)) { __party_impl_text_white(_x,_y,_txt); return; }
    var _old = __party_use_font();
    draw_set_color(c_white);
    draw_text(_x, _y, _txt);
    __party_restore_font(_old);
}