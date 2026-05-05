// Party input module: contains party_update (input/state transitions)
// separated from UI/draw/model.
//
// __party_impl_party_update responsibilities:
// - Handle per-player party UI input and state transitions.
// - Drive party-specific flows: list selection, per-mon menu, swapping,
//   item give/use, move learn/forget flows, and summary screens.
// - Coordinate with battle systems when the party was opened from a battle
//   (swap/forced-swap flows) and with the bag system for give/use actions.
//
// Inputs/Effects:
// - Reads global `PARTY`, bag state, and battle helpers.
// - Mutates `global.PARTY[pid]` fields (mode, sel, mons, locks, pending structs).
function __party_impl_party_update(){
    // Static-analysis aid: declare a dummy _P struct with expected fields inside
    // a dead branch so the runtime is unaffected but the analyzer recognizes
    // all commonly-used fields on `_P` (avoids many 'Undeclared symbol' warnings).
    if (false){
        var _P = { open:false, lock:0, mons:[], mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1,
                   sum_move_sel:0, sum_learn_sel:0, learn_pending:undefined,
                   summary_prev_mode:"", summary_anim:0, summary_anim_active:false,
                   summary_sprite_anim:0, summary_sprite_anim_active:false, summary_last_cry_sel:-1,
                   summary_sprite_anim_start_ms:-1, summary_cur_scale:1, summary_target_scale:0.6,
                   summary_spin_angle:0, summary_prev_sel:0 };
        // dummy bag struct for static analysis of bag references in this file
        var _b = { items: [], page:0, sel:0, scroll:0 };
        // dummy battle slot reference for static analysis of _B fields
        var _B = { actor:[], turn_queue:[], turn_action_player:undefined, turn_action_enemy:undefined, _pending_close:false };
    }
    if (!variable_global_exists("PARTY")) return;
    var _players = array_length(global.PARTY); if (_players <= 0) return;

    // keep lock synced

    for (var _pid = 0; _pid < _players; _pid++){
    var _P = party_ensure(_pid);
    // debug: remember previous selection to detect selection-driven overwrites
    var __dbg_prev_sel = (is_struct(_P) && variable_struct_exists(_P, "sel") ? variable_struct_get(_P, "sel") : -999);
        if (!_P.open) continue;
        if (_P.lock > 0) _P.lock--;

    var _mons = _P.mons, _n = array_length(_mons), _ROWS = 6;
    var _is_forced = (is_struct(_P) && variable_struct_exists(_P, "_battle_swap_mode_forced") && variable_struct_get(_P, "_battle_swap_mode_forced") == true);
    var _is_baton_mode = (is_struct(_P) && variable_struct_exists(_P, "_battle_baton_pass_mode") && variable_struct_get(_P, "_battle_baton_pass_mode") == true);

        if (_P.mode != "select" && _P.mode != "summary_profile" && _P.mode != "summary_moves" && _P.mode != "summary_forget"){
            if (controls_pressed(_pid,"Run") && _P.lock == 0 && !_is_forced && !_is_baton_mode){ _P.open = false; _P.lock = 2; continue; }
        }

        // Mode dispatch: each `case` handles input for a particular UI state.
        // - "list": main party list view (navigation, open menu, quick-close).
        // - "menu": per-mon menu (Summary / Swap/Switch / Item / Cancel).
        // - "select": target selection for swapping a mon (in/out of battle).
        // - "select_item": choosing a party target for a bag item (give/use).
        // - "summary_profile": Pokemon profile screen (sprite, cry, info).
        // - "summary_moves": moves panel with optional learn/forget interactions.
        // - "summary_forget": forget/replace flow when learning a new move.
        switch (_P.mode){
            // Main party list view. Navigation, open menu or handle forced
            // in-battle swap requests. `Interact` opens per-mon menu or
            // selects the incoming mon when in forced swap mode.
            case "list":
                if (controls_pressed(_pid,"MoveDown") && _n > 0) _P.sel = clamp(_P.sel + 1, 0, _n - 1);
                if (controls_pressed(_pid,"MoveUp")   && _n > 0) _P.sel = clamp(_P.sel - 1, 0, _n - 1);
                _P.scroll = clamp(_P.scroll, 0, max(0, _n - _ROWS));
                if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
                if (_P.sel >= _P.scroll + _ROWS) _P.scroll = max(0, _P.sel - _ROWS + 1);
                var _trainer_prompt_pick = (is_struct(_P) && variable_struct_exists(_P, "_trainer_prompt_pick_mode") && variable_struct_get(_P, "_trainer_prompt_pick_mode") == true);
                if (_trainer_prompt_pick){
                    if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                        var _pick_idx = _P.sel;
                        var _pick_mon = party_model_get_mon(_pid, _pick_idx);
                        var _pick_hp = __battle_hp_now(_pick_mon);
                        var _active_idx_pick = -1;
                        try {
                            var _Bpick = __battle_ensure_slot(_pid);
                            if (is_struct(_Bpick) && variable_struct_exists(_Bpick, "actor") && is_array(variable_struct_get(_Bpick, "actor")) && array_length(variable_struct_get(_Bpick, "actor")) > 0){
                                var _active_actor_pick = variable_struct_get(_Bpick, "actor")[0];
                                var _active_mon_pick = (is_struct(_active_actor_pick) && variable_struct_exists(_active_actor_pick, "mon") && is_struct(variable_struct_get(_active_actor_pick, "mon"))) ? variable_struct_get(_active_actor_pick, "mon") : _active_actor_pick;
                                for (var _pii = 0; _pii < _n; ++_pii){
                                    var _cand_pick = _P.mons[_pii];
                                    if (is_struct(_cand_pick) && (_cand_pick == _active_actor_pick || _cand_pick == _active_mon_pick)) { _active_idx_pick = _pii; break; }
                                }
                            }
                        } catch (e_pick_active) { _active_idx_pick = -1; }

                        if (!is_struct(_pick_mon) || !is_real(_pick_hp) || _pick_hp <= 0 || _pick_idx == _active_idx_pick){
                            _P.lock = 6;
                        } else {
                            try {
                                var _Bpick2 = __battle_ensure_slot(_pid);
                                if (is_struct(_Bpick2) && variable_struct_exists(_Bpick2, "_trainer_switch_prompt")){
                                    var _tpick = variable_struct_get(_Bpick2, "_trainer_switch_prompt");
                                    if (is_struct(_tpick)){
                                        variable_struct_set(_tpick, "player_choice", "yes");
                                        variable_struct_set(_tpick, "player_switch_idx", _pick_idx);
                                        variable_struct_set(_tpick, "phase", "queue_enemy_send");
                                        variable_struct_set(_Bpick2, "_trainer_switch_prompt", _tpick);
                                    }
                                }
                            } catch (e_pick_set) {}
                            variable_struct_set(_P, "_trainer_prompt_pick_mode", false);
                            _P.open = false;
                            _P.lock = 2;
                            continue;
                        }
                    }
                    if (controls_pressed(_pid,"Run") && _P.lock == 0){
                        try {
                            var _Bpick_cancel = __battle_ensure_slot(_pid);
                            if (is_struct(_Bpick_cancel) && variable_struct_exists(_Bpick_cancel, "_trainer_switch_prompt")){
                                var _tcancel = variable_struct_get(_Bpick_cancel, "_trainer_switch_prompt");
                                if (is_struct(_tcancel)){
                                    variable_struct_set(_tcancel, "player_choice", "no");
                                    variable_struct_set(_tcancel, "player_switch_idx", -1);
                                    variable_struct_set(_tcancel, "phase", "queue_enemy_send");
                                    variable_struct_set(_Bpick_cancel, "_trainer_switch_prompt", _tcancel);
                                }
                            }
                        } catch (e_pick_cancel) {}
                        variable_struct_set(_P, "_trainer_prompt_pick_mode", false);
                        _P.open = false;
                        _P.lock = 2;
                        continue;
                    }
                }
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    // List-mode Interact behavior:
                    // - If forced in-battle swap is active, Interact immediately selects the incoming mon.
                    // - Otherwise (normal swap or out of battle), open the submenu and let the player
                    //   choose "Swap In" explicitly.
                    var _PtmpChk = party_ensure(_pid);
                    var __frc_now = false;
                    var __baton_now = false;
                    if (is_struct(_PtmpChk) && !is_undefined(battle_is_open) && battle_is_open(_pid)){
                        __frc_now = (variable_struct_exists(_PtmpChk, "_battle_swap_mode_forced") && variable_struct_get(_PtmpChk, "_battle_swap_mode_forced") == true);
                        __baton_now = (variable_struct_exists(_PtmpChk, "_battle_baton_pass_mode") && variable_struct_get(_PtmpChk, "_battle_baton_pass_mode") == true);
                    }
                    if ((__frc_now || __baton_now) && (variable_global_exists("cutscene_switch_to") || variable_global_exists("battle_switch_to"))){
                        var _dst = _P.sel;
                        // Prevent selecting fainted mon
                        var _tmon = party_model_get_mon(_pid, _dst);
                        var _t_hp = 1;
                        if (is_struct(_tmon)){
                            if (variable_struct_exists(_tmon, "hp")) _t_hp = variable_struct_get(_tmon, "hp");
                            else if (variable_struct_exists(_tmon, "HP")) _t_hp = variable_struct_get(_tmon, "HP");
                        }
                        if (is_real(_t_hp) && _t_hp <= 0){
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][list] cannot swap to fainted idx=" + string(_dst));
                            _P.lock = 6;
                        } else {
                            // Determine if forced (replacement after faint)
                            var _forced = (is_struct(_PtmpChk) && variable_struct_exists(_PtmpChk, "_battle_swap_mode_forced") && variable_struct_get(_PtmpChk, "_battle_swap_mode_forced") == true);
                            var _baton_pass = (is_struct(_PtmpChk) && variable_struct_exists(_PtmpChk, "_battle_baton_pass_mode") && variable_struct_get(_PtmpChk, "_battle_baton_pass_mode") == true);
                            var _actor_index_swap = (is_struct(_PtmpChk) && variable_struct_exists(_PtmpChk, "_battle_swap_actor_index") && is_real(variable_struct_get(_PtmpChk, "_battle_swap_actor_index"))) ? floor(variable_struct_get(_PtmpChk, "_battle_swap_actor_index")) : -1;
                            var _consume = !_forced;
                            var ok = false;
                            if (variable_global_exists("cutscene_switch_to")){
                                var _fn_sw = variable_global_get("cutscene_switch_to");
                                if (!is_undefined(_fn_sw)) ok = _fn_sw(_pid, _dst, { auto_apply:true, consume_turn:_consume, forced:_forced, baton_pass:_baton_pass, actor_index:_actor_index_swap });
                            } else if (variable_global_exists("battle_switch_to")){
                                var _fn_sw2 = variable_global_get("battle_switch_to");
                                if (!is_undefined(_fn_sw2)) ok = _fn_sw2(_pid, _dst, { auto_apply:true, consume_turn:_consume, forced:_forced, baton_pass:_baton_pass, actor_index:_actor_index_swap });
                            }
                            if (ok){ if (!is_undefined(party_close)) party_close(_pid);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][input] party_close called after battle_switch_to ok pid=" + string(_pid) + ", dst=" + string(_dst));
                                try {
                                    var _Btmpg = __battle_ensure_slot(_pid);
                                    if (is_struct(_Btmpg)){
                                        var _dur = 220;
                                        var _is_forced_local = (is_struct(_PtmpChk) && variable_struct_exists(_PtmpChk, "_battle_swap_mode_forced") && variable_struct_get(_PtmpChk, "_battle_swap_mode_forced") == true);
                                        if (_is_forced_local) _dur = max(_dur, 700);
                                        variable_struct_set(_Btmpg, "_input_grace_until", current_time + _dur);
                                    }
                                } catch (e_ig) {}
                            }
                            else { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][list] battle_switch_to returned false; keep party open"); _P.lock = 6; }
                        }
                    } else {
                        // Default behavior: open menu (normal swap or out-of-battle)
                        _P.mode = "menu"; _P.menu_sel = 0; _P.lock = 2;
                    }
                }
            break;

            // Per-mon menu. Presents actions for the selected Pokemon:
            // Summary, Swap/Switch, Item, Cancel. Skips disabled entries
            // (e.g., blanked Swap when appropriate) and preserves labels
            // for in-battle swap contexts.
            case "menu":
                // Compute effective menu labels (mirror draw logic) so movement skips disabled entries
                var _swap_label_tmp = "Switch";
                try {
                    var _tmpP2 = party_ensure(_pid);
                    // Show "Swap In" when this party was opened for an in-battle swap
                    // (either normal swap mode or forced replacement after faint) and
                    // the battle is still open. This makes the intention clear to
                    // players even if the selected mon is fainted.
                    var _is_swap_mode = (is_struct(_tmpP2) && ((variable_struct_exists(_tmpP2, "_battle_swap_mode") && variable_struct_get(_tmpP2, "_battle_swap_mode")) || (variable_struct_exists(_tmpP2, "_battle_swap_mode_forced") && variable_struct_get(_tmpP2, "_battle_swap_mode_forced") == true)));
                    if (_is_swap_mode && !is_undefined(battle_is_open) && battle_is_open(_pid)) _swap_label_tmp = "Swap In";
                } catch (e_tmp) {}
                var _menu_items_tmp = ["Summary", _swap_label_tmp, "Item", "Cancel"];
                // Determine fainted state for the selected pokemon
                var _selMonTmp = undefined;
                if (variable_struct_exists(_P, "mons") && is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _selMonTmp = _P.mons[_P.sel];
                var _sel_mon_hp_tmp = 1;
                if (is_struct(_selMonTmp)){
                    if (variable_struct_exists(_selMonTmp, "hp")) _sel_mon_hp_tmp = variable_struct_get(_selMonTmp, "hp");
                    else if (variable_struct_exists(_selMonTmp, "HP")) _sel_mon_hp_tmp = variable_struct_get(_selMonTmp, "HP");
                }
                // If the party was opened for an in-battle swap and the battle is
                // open, preserve the Swap label even for fainted mons so the player
                // understands they're selecting an incoming Pokémon. However, when
                // OUT of battle we should keep the normal "Switch" label visible
                // even if the selected mon is fainted (the selection logic will
                // still prevent choosing a fainted mon). Only blank the entry when
                // we are in-battle AND not in swap mode.
                var _preserve_swap_label = false;
                try {
                    var _tmpPswap = party_ensure(_pid);
                    if (is_struct(_tmpPswap)){
                        var _psw = false;
                        if (variable_struct_exists(_tmpPswap, "_battle_swap_mode") && variable_struct_get(_tmpPswap, "_battle_swap_mode")) _psw = true;
                        if (variable_struct_exists(_tmpPswap, "_battle_swap_mode_forced") && variable_struct_get(_tmpPswap, "_battle_swap_mode_forced") == true) _psw = true;
                        if (_psw && !is_undefined(battle_is_open) && battle_is_open(_pid)) _preserve_swap_label = true;
                    }
                } catch (e_pres) { _preserve_swap_label = false; }
                // Only blank the Switch/Swap label when the battle is open AND we're
                // not preserving the swap label. This ensures out-of-battle party
                // menus still show "Switch" even if the selected mon is fainted.
                var _battle_still_open = (!is_undefined(battle_is_open) && battle_is_open(_pid));
                // Debugging aid: report why the Swap/Switch label may be blanked.
                try {
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG && is_real(_sel_mon_hp_tmp) && _sel_mon_hp_tmp <= 0){
                        show_debug_message("[party][menu-debug] swap_label_before='" + string(_swap_label_tmp) + "', preserve=" + string(_preserve_swap_label) + ", battle_open=" + string(_battle_still_open) + ", sel_hp=" + string(_sel_mon_hp_tmp));
                    }
                } catch (e_dbg) {}
                if (is_real(_sel_mon_hp_tmp) && _sel_mon_hp_tmp <= 0 && !_preserve_swap_label && _battle_still_open) {
                    _menu_items_tmp[1] = "";
                    try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu-debug] swap_label_blanked (menu[1] now empty)"); } catch (e_dbg2) {}
                }
                // Defensive fallback: if the computed label ended up empty but
                // the battle is closed, restore the out-of-battle default
                // so UI doesn't display a blank entry.
                try {
                    if ((!is_string(_menu_items_tmp[1]) || string_length(string(_menu_items_tmp[1])) == 0) && !_battle_still_open){
                        _menu_items_tmp[1] = "Switch";
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu-debug] restored menu[1] to 'Switch' because battle closed");
                    }
                } catch (e_fb) {}

                // Ensure current menu_sel targets a non-empty label
                // Defensive normalization: ensure the menu contains four valid
                // text entries so the UI draw code always has something to render.
                try {
                    if (!is_string(_menu_items_tmp[0]) || string_length(string(_menu_items_tmp[0])) == 0){ _menu_items_tmp[0] = "Summary"; if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu-debug] restored menu[0] to 'Summary'"); }
                    if (!is_string(_menu_items_tmp[1]) || string_length(string(_menu_items_tmp[1])) == 0){
                        // Prefer swap label when preserving swap state and battle is open
                        if (_preserve_swap_label && _battle_still_open) _menu_items_tmp[1] = "Swap In";
                        else _menu_items_tmp[1] = "Switch";
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu-debug] normalized menu[1] -> '" + string(_menu_items_tmp[1]) + "'");
                    }
                    if (!is_string(_menu_items_tmp[2]) || string_length(string(_menu_items_tmp[2])) == 0){ _menu_items_tmp[2] = "Item"; if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu-debug] restored menu[2] to 'Item'"); }
                    if (!is_string(_menu_items_tmp[3]) || string_length(string(_menu_items_tmp[3])) == 0){ _menu_items_tmp[3] = "Cancel"; if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu-debug] restored menu[3] to 'Cancel'"); }
                } catch (e_norm) {}

                if (!is_string(_menu_items_tmp[_P.menu_sel]) || string_length(string(_menu_items_tmp[_P.menu_sel])) == 0){
                    // Try to move up to find a valid entry, else move down
                    var _found = -1;
                    for (var __i = _P.menu_sel - 1; __i >= 0; __i--) if (is_string(_menu_items_tmp[__i]) && string_length(_menu_items_tmp[__i]) > 0){ _found = __i; break; }
                    if (_found == -1){ for (var __j = _P.menu_sel + 1; __j < array_length(_menu_items_tmp); __j++) if (is_string(_menu_items_tmp[__j]) && string_length(_menu_items_tmp[__j]) > 0){ _found = __j; break; } }
                    if (_found != -1) _P.menu_sel = _found; else _P.menu_sel = 0;
                }
                // Movement: step to next non-empty entry
                if (controls_pressed(_pid,"MoveDown")){
                    var _next = _P.menu_sel;
                    for (var _k = _P.menu_sel + 1; _k < array_length(_menu_items_tmp); _k++){
                        if (is_string(_menu_items_tmp[_k]) && string_length(_menu_items_tmp[_k]) > 0){ _next = _k; break; }
                    }
                    _P.menu_sel = _next;
                }
                if (controls_pressed(_pid,"MoveUp")){
                    var _prev = _P.menu_sel;
                    for (var _k2 = _P.menu_sel - 1; _k2 >= 0; _k2--){ if (is_string(_menu_items_tmp[_k2]) && string_length(_menu_items_tmp[_k2]) > 0){ _prev = _k2; break; } }
                    _P.menu_sel = _prev;
                }
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    switch (_P.menu_sel){
                        case 0: _P.mode="summary_profile"; _P.sum_move_sel=0; _P.sum_learn_sel=0; _P.lock=2; break;
            case 1:
                // If the selected mon is fainted, disable the Switch menu entry entirely.
                var _selMonChk = undefined;
                if (variable_struct_exists(_P, "mons") && is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _selMonChk = _P.mons[_P.sel];
                var _sel_hp_chk = 1;
                if (is_struct(_selMonChk)){
                    if (variable_struct_exists(_selMonChk, "hp")) _sel_hp_chk = variable_struct_get(_selMonChk, "hp");
                    else if (variable_struct_exists(_selMonChk, "HP")) _sel_hp_chk = variable_struct_get(_selMonChk, "HP");
                }
                if (is_real(_sel_hp_chk) && _sel_hp_chk <= 0){
                    // disabled: cannot Switch a fainted mon; give brief lock and ignore
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu] swap disabled for fainted mon sel=" + string(_P.sel));
                    _P.lock = 6;
                    break;
                }
                _P.swap_index = _P.sel;
                // If party open was requested from battle (swap mode), perform immediate swap
                var _Ptmp2 = party_ensure(_pid);
                var _inBattleSwap2 = false;
                if (is_struct(_Ptmp2) && !is_undefined(battle_is_open) && battle_is_open(_pid)){
                    var __swp2 = (variable_struct_exists(_Ptmp2, "_battle_swap_mode") && variable_struct_get(_Ptmp2, "_battle_swap_mode"));
                    var __frc2 = (variable_struct_exists(_Ptmp2, "_battle_swap_mode_forced") && variable_struct_get(_Ptmp2, "_battle_swap_mode_forced") == true);
                    _inBattleSwap2 = (__swp2 || __frc2);
                }
                if (_inBattleSwap2 && (variable_global_exists("cutscene_switch_to") || variable_global_exists("battle_switch_to"))){
                    var _dst2 = _P.swap_index;
                    // Prevent selecting fainted mon
                    var _tmon2 = party_model_get_mon(_pid, _dst2);
                    var _t_hp2 = 1;
                    if (is_struct(_tmon2)){
                        if (variable_struct_exists(_tmon2, "hp")) _t_hp2 = variable_struct_get(_tmon2, "hp");
                        else if (variable_struct_exists(_tmon2, "HP")) _t_hp2 = variable_struct_get(_tmon2, "HP");
                    }
                    if (is_real(_t_hp2) && _t_hp2 <= 0){
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu] cannot swap to fainted idx=" + string(_dst2));
                        _P.lock = 6;
                    } else {
                        var _forced2 = (is_struct(_Ptmp2) && variable_struct_exists(_Ptmp2, "_battle_swap_mode_forced") && variable_struct_get(_Ptmp2, "_battle_swap_mode_forced") == true);
                        var _actor_index_swap2 = (is_struct(_Ptmp2) && variable_struct_exists(_Ptmp2, "_battle_swap_actor_index") && is_real(variable_struct_get(_Ptmp2, "_battle_swap_actor_index"))) ? floor(variable_struct_get(_Ptmp2, "_battle_swap_actor_index")) : -1;
                        var _consume2 = !_forced2;
                        var ok2 = false;
                        if (variable_global_exists("cutscene_switch_to")){
                            var _fn_sw3 = variable_global_get("cutscene_switch_to");
                            if (!is_undefined(_fn_sw3)) ok2 = _fn_sw3(_pid, _dst2, { auto_apply:true, consume_turn:_consume2, forced:_forced2, actor_index:_actor_index_swap2 });
                        } else if (variable_global_exists("battle_switch_to")){
                            var _fn_sw4 = variable_global_get("battle_switch_to");
                            if (!is_undefined(_fn_sw4)) ok2 = _fn_sw4(_pid, _dst2, { auto_apply:true, consume_turn:_consume2, forced:_forced2, actor_index:_actor_index_swap2 });
                        }
                        if (ok2){ if (!is_undefined(party_close)) party_close(_pid);
                            try {
                                var _Btmpg2 = __battle_ensure_slot(_pid);
                                if (is_struct(_Btmpg2)){
                                    var _dur2 = 220;
                                    var _is_forced_local2 = (is_struct(_Ptmp2) && variable_struct_exists(_Ptmp2, "_battle_swap_mode_forced") && variable_struct_get(_Ptmp2, "_battle_swap_mode_forced") == true);
                                    if (_is_forced_local2) _dur2 = max(_dur2, 700);
                                    variable_struct_set(_Btmpg2, "_input_grace_until", current_time + _dur2);
                                }
                            } catch (e_ig2) {}
                        }
                        else { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu] battle_switch_to returned false; keep party open"); _P.lock = 6; }
                    }
                } else {
                    _P.mode="select"; _P.lock=2;
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu] pid=" + string(_pid) + ", swap_index=" + string(_P.swap_index));
                }
                break;
                        case 2:
                            // Enter item action submenu (Give / Take / Cancel)
                            _P.mode = "item_action";
                            show_debug_message("[party] Entered item_action mode (Item submenu)");
                            _P.item_menu_sel = 0;
                            _P.lock = 2;
                            break;
                        case 3:
                            // If party was opened as a forced swap, disallow cancel/back
                            var _Ptmp_cancel = party_ensure(_pid);
                            var _forced_cancel = (is_struct(_Ptmp_cancel) && variable_struct_exists(_Ptmp_cancel, "_battle_swap_mode_forced") && variable_struct_get(_Ptmp_cancel, "_battle_swap_mode_forced") == true);
                            // If the battle has already closed, clear the forced marker so the
                            // player can cancel/back out of the party UI normally.
                            var _battle_now_open = (is_undefined(battle_is_open) ? false : battle_is_open(_pid));
                            if (_forced_cancel && !_battle_now_open){
                                try {
                                    // Prefer helper to clear only the forced flag while preserving swap_mode
                                    var _cur_swap_val = (is_struct(_Ptmp_cancel) && variable_struct_exists(_Ptmp_cancel, "_battle_swap_mode") ? variable_struct_get(_Ptmp_cancel, "_battle_swap_mode") : false);
                                    if (!is_undefined(party_set_swap_mode)) party_set_swap_mode(_pid, _cur_swap_val, false);
                                    else variable_struct_set(_Ptmp_cancel, "_battle_swap_mode_forced", false);
                                } catch (e_rmc) {}
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][menu] cleared _battle_swap_mode_forced because battle closed pid=" + string(_pid));
                                _forced_cancel = false;
                            }
                            if (_forced_cancel){
                                // ignore cancel, keep menu visible briefly
                                _P.lock = 6;
                            } else {
                                _P.mode="list"; _P.lock=2;
                            }
                            break;
                    }
                }

                // If the menu switched into the item_action submenu, handle its input here.
                if (string(_P.mode) == "item_action"){
                    var _labels = ["Take","Cancel"];
                    var _shouldShowGive = false;
                    if (variable_struct_exists(_P, "give_pending")){
                        _shouldShowGive = true;
                    } else {
                        var _selMon = undefined;
                        if (variable_struct_exists(_P, "mons") && is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _selMon = _P.mons[_P.sel];
                        if (!is_undefined(_selMon) && is_struct(_selMon) && variable_struct_exists(_selMon, "held_item_id")){
                            var _hid_tmp = variable_struct_get(_selMon, "held_item_id");
                            if (is_real(_hid_tmp) && _hid_tmp > 0){ _shouldShowGive = false; } else { _shouldShowGive = true; }
                        } else {
                            _shouldShowGive = true;
                        }
                    }
                    // If the selected mon is fainted, do not show Give even if it would otherwise be shown.
                    var _selMon2 = undefined;
                    if (variable_struct_exists(_P, "mons") && is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _selMon2 = _P.mons[_P.sel];
                    var _sel_hp2 = 1;
                    if (is_struct(_selMon2)){
                        if (variable_struct_exists(_selMon2, "hp")) _sel_hp2 = variable_struct_get(_selMon2, "hp");
                        else if (variable_struct_exists(_selMon2, "HP")) _sel_hp2 = variable_struct_get(_selMon2, "HP");
                    }
                    if (is_real(_sel_hp2) && _sel_hp2 <= 0) _shouldShowGive = false;
                    if (_shouldShowGive) array_insert(_labels, 0, "Give");

                    var _maxIdx = array_length(_labels) - 1;
                    if (controls_pressed(_pid,"MoveDown")) _P.item_menu_sel = clamp(_P.item_menu_sel + 1, 0, _maxIdx);
                    if (controls_pressed(_pid,"MoveUp"))   _P.item_menu_sel = clamp(_P.item_menu_sel - 1, 0, _maxIdx);
                    if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                        var _action = _labels[clamp(_P.item_menu_sel, 0, _maxIdx)];
                        if (_action == "Give"){
                            var _b = bag_inventory_ensure(_pid);
                            // flag the bag to deliver selection to this party slot
                            _b.give_to_mon = _P.sel;
                            _b.give_from_party = true;
                            // close party so bag is visible (party is drawn on top of bag); bag will re-open the party after give
                            _P.lock = 4;
                            party_close(_pid);
                            bag_open(_pid);
                            // short lock on bag to avoid immediate input
                            _b.lock = 4;
                        } else if (_action == "Take"){
                            // Ensure target mon struct exists and attempt to read held item id
                            var target = _P.mons[_P.sel];
                            if (!is_struct(target)) target = _P.mons[_P.sel] = {};
                            var hid = (variable_struct_exists(target, "held_item_id") ? variable_struct_get(target, "held_item_id") : -1);
                            if (is_real(hid) && hid > 0){
                                // Add the held item back to the player's bag
                                bag_inventory_add_item(_pid, hid, 1);
                                // Clear held item id and canonical name on the mon
                                if (variable_struct_exists(target, "held_item_id")) variable_struct_set(target, "held_item_id", -1);
                                if (variable_struct_exists(target, "held_item_real_name")) variable_struct_set(target, "held_item_real_name", "");
                                bags_seed_from_items(_pid);
                                show_debug_message("[party] Took item " + string(hid) + " from mon index " + string(_P.sel));
                            } else {
                                show_debug_message("[party] No held item to take");
                            }
                            // return to party menu
                            _P.mode = "list"; _P.lock = 4; _P.give_pending = undefined;
                        } else if (_action == "Cancel"){
                            _P.mode = "menu"; _P.lock = 2;
                        }
                    }
                    if (controls_pressed(_pid,"Run") && _P.lock == 0 && !(is_struct(_P) && ((variable_struct_exists(_P, "_battle_swap_mode_forced") && variable_struct_get(_P, "_battle_swap_mode_forced") == true) || (variable_struct_exists(_P, "_battle_baton_pass_mode") && variable_struct_get(_P, "_battle_baton_pass_mode") == true)))){ _P.mode = "menu"; _P.lock = 2; }
                }
            break;

            // Selection mode: choose a replacement or swap target. Used
            // both for in-battle swaps and local party reordering.
            case "select":
                if (controls_pressed(_pid,"MoveDown") && _n > 0) _P.sel = clamp(_P.sel + 1, 0, _n - 1);
                if (controls_pressed(_pid,"MoveUp")   && _n > 0) _P.sel = clamp(_P.sel - 1, 0, _n - 1);
                _P.scroll = clamp(_P.scroll, 0, max(0, _n - _ROWS));
                if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
                if (_P.sel >= _P.scroll + _ROWS) _P.scroll = max(0, _P.sel - _ROWS + 1);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    var _src = _P.swap_index, _dst = _P.sel;
                    if (_n > 0 && _src >= 0 && _src < _n && _dst >= 0 && _dst < _n && _src != _dst){
                        // log moves before swap
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                            var __pre_src = (is_array(_P.mons) && _src >= 0 && _src < array_length(_P.mons)) ? _P.mons[_src] : undefined;
                            var __pre_dst = (is_array(_P.mons) && _dst >= 0 && _dst < array_length(_P.mons)) ? _P.mons[_dst] : undefined;
                            var __pre_src_moves = (is_struct(__pre_src) && variable_struct_exists(__pre_src, "moves")) ? variable_struct_get(__pre_src, "moves") : "[]";
                            var __pre_dst_moves = (is_struct(__pre_dst) && variable_struct_exists(__pre_dst, "moves")) ? variable_struct_get(__pre_dst, "moves") : "[]";
                            show_debug_message("[party][swap_before] pid=" + string(_pid) + ", src=" + string(_src) + ", dst=" + string(_dst) + ", src_moves=" + string(__pre_src_moves) + ", dst_moves=" + string(__pre_dst_moves));
                        }
                        // If we were opened from a battle for a swap, trigger battle_switch_to
                        var _Ptmp = party_ensure(_pid);
                        var _inBattleSwap = false;
                        if (is_struct(_Ptmp) && !is_undefined(battle_is_open) && battle_is_open(_pid)){
                            var __swp = (variable_struct_exists(_Ptmp, "_battle_swap_mode") && variable_struct_get(_Ptmp, "_battle_swap_mode"));
                            var __frc = (variable_struct_exists(_Ptmp, "_battle_swap_mode_forced") && variable_struct_get(_Ptmp, "_battle_swap_mode_forced") == true);
                            _inBattleSwap = (__swp || __frc);
                        }
                        if (_inBattleSwap && (variable_global_exists("cutscene_switch_to") || variable_global_exists("battle_switch_to"))){
                            // Determine whether this swap was opened due to a faint (forced)
                            var _forced = (is_struct(_Ptmp) && variable_struct_exists(_Ptmp, "_battle_swap_mode_forced") && variable_struct_get(_Ptmp, "_battle_swap_mode_forced") == true);
                            var _actor_index_swap3 = (is_struct(_Ptmp) && variable_struct_exists(_Ptmp, "_battle_swap_actor_index") && is_real(variable_struct_get(_Ptmp, "_battle_swap_actor_index"))) ? floor(variable_struct_get(_Ptmp, "_battle_swap_actor_index")) : -1;
                            // For forced swaps (replacement after faint) the player's turn should NOT be consumed.
                            var _consume = !_forced;
                            // Prevent selecting a fainted Pokémon as the incoming target
                            var _targetMon = party_model_get_mon(_pid, _dst);
                            var _t_hp = 1;
                            if (is_struct(_targetMon)){
                                if (variable_struct_exists(_targetMon, "hp")) _t_hp = variable_struct_get(_targetMon, "hp");
                                else if (variable_struct_exists(_targetMon, "HP")) _t_hp = variable_struct_get(_targetMon, "HP");
                            }
                            if (is_real(_t_hp) && _t_hp <= 0){
                                // invalid selection: cannot choose a fainted mon. Give feedback and ignore.
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][select] cannot swap to fainted mon idx=" + string(_dst));
                                // optional: play a negative sound if available (no-op if undefined)
                                if (!is_undefined(audio_play_sound) && false) audio_play_sound(-1, 0, false);
                            } else {
                                // Use battle API to animate switch_in; the battle will apply the model swap at midpoint
                                var ok = false;
                                if (variable_global_exists("cutscene_switch_to")){
                                    var _fn_sw5 = variable_global_get("cutscene_switch_to");
                                    if (!is_undefined(_fn_sw5)) ok = _fn_sw5(_pid, _dst, { auto_apply:true, consume_turn:_consume, forced:_forced, actor_index:_actor_index_swap3 });
                                } else if (variable_global_exists("battle_switch_to")){
                                    var _fn_sw6 = variable_global_get("battle_switch_to");
                                    if (!is_undefined(_fn_sw6)) ok = _fn_sw6(_pid, _dst, { auto_apply:true, consume_turn:_consume, forced:_forced, actor_index:_actor_index_swap3 });
                                }
                                // Only close the party if the battle accepted the switch request.
                                if (ok){
                                    if (!is_undefined(party_close)) party_close(_pid);
                                    // Give the battle a small input-grace so the switch animation/dialog isn't interrupted
                                    try {
                                        var _Btmpg = __battle_ensure_slot(_pid);
                                        if (is_struct(_Btmpg)){
                                            var _dur3 = 220;
                                            var _is_forced_local3 = (is_struct(_Ptmp) && variable_struct_exists(_Ptmp, "_battle_swap_mode_forced") && variable_struct_get(_Ptmp, "_battle_swap_mode_forced") == true);
                                            if (_is_forced_local3) _dur3 = max(_dur3, 700);
                                            variable_struct_set(_Btmpg, "_input_grace_until", current_time + _dur3);
                                        }
                                    } catch (e_ig) {}
                                } else {
                                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][select] battle_switch_to returned false; swap aborted (pid=" + string(_pid) + ", dst=" + string(_dst) + ")");
                                    // small lock to avoid immediate input spam
                                    _P.lock = 6;
                                }
                            }
                        } else {
                            // Local party swap outside of battle
                            party_model_swap(_pid, _src, _dst);
                            // Mirror any potential model changes
                            _P.sel = _dst;
                        }
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                            var __post_src = (is_array(_P.mons) && _src >= 0 && _src < array_length(_P.mons)) ? _P.mons[_src] : undefined;
                            var __post_dst = (is_array(_P.mons) && _dst >= 0 && _dst < array_length(_P.mons)) ? _P.mons[_dst] : undefined;
                            var __post_src_moves = (is_struct(__post_src) && variable_struct_exists(__post_src, "moves")) ? variable_struct_get(__post_src, "moves") : "[]";
                            var __post_dst_moves = (is_struct(__post_dst) && variable_struct_exists(__post_dst, "moves")) ? variable_struct_get(__post_dst, "moves") : "[]";
                            show_debug_message("[party][swap_after] pid=" + string(_pid) + ", src=" + string(_src) + ", dst=" + string(_dst) + ", src_moves=" + string(__post_src_moves) + ", dst_moves=" + string(__post_dst_moves));
                        }
                    }
                    _P.mode="list"; _P.swap_index=-1; _P.lock=2;
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0 && !(is_struct(_P) && ((variable_struct_exists(_P, "_battle_swap_mode_forced") && variable_struct_get(_P, "_battle_swap_mode_forced") == true) || (variable_struct_exists(_P, "_battle_baton_pass_mode") && variable_struct_get(_P, "_battle_baton_pass_mode") == true)))){ _P.mode="list"; _P.swap_index=-1; _P.lock=2; }
            break;

            // Select a party target for an item (triggered from the Bag).
            // Handles both `use_pending` (consumables) and `give_pending`
            // (holdable items). Applies items immediately out-of-battle or
            // delegates to battle handlers when used in-battle.
            case "select_item":
                // navigation for select_item
                if (controls_pressed(_pid,"MoveDown") && _n > 0) _P.sel = clamp(_P.sel + 1, 0, _n - 1);
                if (controls_pressed(_pid,"MoveUp")   && _n > 0) _P.sel = clamp(_P.sel - 1, 0, _n - 1);
                _P.scroll = clamp(_P.scroll, 0, max(0, _n - _ROWS));
                if (_P.sel <  _P.scroll) _P.scroll = _P.sel;
                if (_P.sel >= _P.scroll + _ROWS) _P.scroll = max(0, _P.sel - _ROWS + 1);

                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    var gp = (is_struct(_P) && variable_struct_exists(_P, "give_pending") ? _P.give_pending : undefined);
                    var up = (is_struct(_P) && variable_struct_exists(_P, "use_pending") ? _P.use_pending : undefined);
                    // First handle use_pending (consumable application)
                    if (!is_undefined(up) && is_struct(up)){
                        var bpid = variable_struct_exists(up, "bag_pid") ? variable_struct_get(up, "bag_pid") : -1;
                        var item_id = variable_struct_exists(up, "item_id") ? variable_struct_get(up, "item_id") : -1;
                        var _battle_open_for_item = (!is_undefined(battle_is_open) && battle_is_open(_pid));
                        // Ensure the bag data is present
                        if (bpid >= 0){
                            var _b = bag_inventory_ensure(bpid);
                            // Apply healing: simple default behavior mirrors bag__use_item_on_self default heal
                            var target = _P.mons[_P.sel]; if (!is_struct(target)) target = _P.mons[_P.sel] = {};
                            var target_mon = _P.mons[_P.sel]; if (!is_struct(target_mon)) target_mon = _P.mons[_P.sel] = {};
                            var A0 = undefined;
                            var res = undefined;
                            var _blocked_item_msg = "";
                            if (_battle_open_for_item && !is_undefined(bag__battle_item_target_block_reason)){
                                try { _blocked_item_msg = string(bag__battle_item_target_block_reason(_pid, target_mon, item_id)); } catch (e_item_block_reason) { _blocked_item_msg = ""; }
                            }
                            if (string_length(_blocked_item_msg) > 0){
                                if (!is_undefined(party_close)) party_close(_pid);
                                try { dialog2p_show_now(_pid, _blocked_item_msg); } catch (e_item_block_now) { try { dialog2p_enqueue(_pid, _blocked_item_msg); } catch (e_item_block_queue) {} }
                                _P.use_pending = undefined;
                                _P.mode = "list";
                                _P.lock = 2;
                                return;
                            }
                            // Find battle slot and actor to mirror HP if in battle
                            if (!is_undefined(__battle_ensure_slot) && _battle_open_for_item){
                                var _B = __battle_ensure_slot(_pid);
                                if (is_struct(_B)){
                                    A0 = (is_array(_B.actor) && array_length(_B.actor) > 0) ? _B.actor[0] : undefined;
                                    // Close the party UI so the dialog can appear unobstructed, then show the
                                    // standard "Trainer used an item" dialog (if provided by bag)
                                    if (!is_undefined(party_close)) party_close(_pid);
                                    if (variable_struct_exists(up, "out_prefix") && string_length(string(variable_struct_get(up, "out_prefix"))) > 0){
                                        var _dlg_txt = string(variable_struct_get(up, "out_prefix"));
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][debug] requesting dialog open: pid=" + string(_pid) + ", text_len=" + string(string_length(_dlg_txt)) + ", preview='" + string_copy(_dlg_txt,1,min(48,string_length(_dlg_txt))) + "'");
                                        try { dialog2p_show_now(_pid, _dlg_txt); } catch (e_dlg) { try { dialog2p_enqueue(_pid, _dlg_txt); } catch(e_e){} }
                                        // Probe whether dialog system reports open immediately after call (verbose only)
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){ if (!is_undefined(dialog2p_is_open)) show_debug_message("[party][debug] dialog2p_is_open(pid) -> " + string(dialog2p_is_open(_pid))); }
                                        // Debug: dump the dialog's all_lines so we can see what the dialog system will render
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                            if (variable_global_exists("DIALOG2P") && is_array(global.DIALOG2P) && array_length(global.DIALOG2P) > _pid){
                                                var _dref = global.DIALOG2P[_pid];
                                                if (is_struct(_dref) && variable_struct_exists(_dref, "all_lines")){
                                                    var _al = variable_struct_get(_dref, "all_lines");
                                                    var _max = min(8, array_length(_al));
                                                    var _pv = "";
                                                    for (var _li = 0; _li < _max; _li++){
                                                        var _ln = string(_al[_li]);
                                                        _pv += "[" + string(_li) + "]" + string_copy(_ln, 1, min(120, string_length(_ln))) + "; ";
                                                    }
                                                    show_debug_message("[dialog][debug] all_lines_preview pid=" + string(_pid) + ", count=" + string(array_length(_al)) + ", preview='" + _pv + "'");
                                                }
                                            }
                                        }
                                    }
                                    // Apply structured effects from data loaders
                                    if (!is_undefined(scr_apply_item_effects)) res = scr_apply_item_effects(item_id, target_mon, A0);
                                    else res = { applied:false };
                                }
                                // Reopen/close bag briefly so UI state remains consistent
                                bag_open(bpid); bag_close(bpid);
                            }

                            // Outside battle, the target selection flow still needs to apply the
                            // item here. Previously only the in-battle branch called the item-effect
                            // resolver, so out-of-battle use_pending silently cleared itself.
                            if (!_battle_open_for_item){
                                if (!is_undefined(scr_apply_item_effects)) res = scr_apply_item_effects(item_id, target_mon, undefined);
                                else res = { applied:false };
                                if (!is_undefined(party_close)) party_close(_pid);
                            }

                            if (is_struct(res) && res.applied){
                                // Remove item and refresh bag
                                bag_inventory_remove_item(bpid, item_id, 1);
                                bags_seed_from_items(bpid);
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                    var _healed_val = "0";
                                    if (is_struct(res) && variable_struct_exists(res, "healed")) _healed_val = string(variable_struct_get(res, "healed"));
                                    var _pp_val = "0";
                                    if (is_struct(res) && variable_struct_exists(res, "pp_restored")) _pp_val = string(variable_struct_get(res, "pp_restored"));
                                    show_debug_message("[party][debug] scr_apply_item_effects result: " + string((is_struct(res) && variable_struct_exists(res, "applied")) ? string(variable_struct_get(res, "applied")) : "false") + ", healed=" + _healed_val + ", pp=" + _pp_val);
                                }
                                // enqueue effect details if provided
                                if (is_struct(res) && variable_struct_exists(res, "messages") && is_array(variable_struct_get(res, "messages"))){
                                    var _msgs = variable_struct_get(res, "messages");
                                    var _detail = "";
                                    for (var _mi = 0; _mi < array_length(_msgs); ++_mi){
                                        var _msg = string_trim(string(_msgs[_mi]));
                                        if (string_length(_msg) == 0) continue;
                                        if (string_length(_detail) > 0) _detail += "\n";
                                        _detail += _msg;
                                    }
                                    if (string_length(_detail) > 0){
                                        var _enqueued = false;
                                        try { dialog2p_enqueue(_pid, _detail); _enqueued = true; } catch (e_msgq) {}
                                        if (!_enqueued){ try { dialog2p_show_now(_pid, _detail); } catch (e_msgn) {} }
                                    }
                                }
                            } else if (is_struct(res)){
                                var _no_effect = "But it had no effect!";
                                var _queued = false;
                                try { dialog2p_enqueue(_pid, _no_effect); _queued = true; } catch (e_noq) {}
                                if (!_queued){ try { dialog2p_show_now(_pid, _no_effect); } catch (e_non) {} }
                            }

                            // Debug: report that the use was applied and whether we queued an enemy action
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][debug] applied use_pending item_id=" + string(item_id) + " on mon_index=" + string(_P.sel));
                        }

                        // Clear pending and return to list
                        _P.use_pending = undefined;
                        _P.mode = "list"; _P.lock = 2;

                        // After consuming an item in battle, allow the enemy to take their turn.
                        if (_battle_open_for_item && !is_undefined(__battle_ensure_slot)){
                            var _B2 = __battle_ensure_slot(_pid);
                            if (is_struct(_B2)){
                                // No player action this turn (item use consumes player's action)
                                variable_struct_set(_B2, "turn_action_player", undefined);
                                // Defensive: clear any stale pending_close flags so the battle isn't closed
                                // immediately if another codepath set _pending_close earlier.
                                if (variable_struct_exists(_B2, "_pending_close") && variable_struct_get(_B2, "_pending_close")){
                                    show_debug_message("[party][debug] Clearing stale _pending_close due to in-battle item use (pid=" + string(_pid) + ")");
                                    variable_struct_set(_B2, "_pending_close", false);
                                }
                                // Choose a simple enemy action locally (avoid referencing external helpers)
                                var actE = undefined;
                                var _actor_arr = (variable_struct_exists(_B2, "actor") ? variable_struct_get(_B2, "actor") : undefined);
                                if (is_array(_actor_arr) && array_length(_actor_arr) > 1){
                                    var AE = _actor_arr[1];
                                    if (is_struct(AE)){
                                        var choices = [];
                                        for (var __i=0; __i<4; __i++){
                                            var mv = (is_array(AE.moves) && __i < array_length(AE.moves)) ? AE.moves[__i] : undefined;
                                            var pp = (is_array(AE.pps) && __i < array_length(AE.pps)) ? AE.pps[__i] : undefined;
                                            if (is_real(mv) && mv >= 0 && is_real(pp) && pp > 0) array_push(choices, __i);
                                        }
                                        if (array_length(choices) > 0){
                                            var slot = choices[irandom(array_length(choices)-1)];
                                            actE = { slot: slot, move_id: AE.moves[slot], actor_index: 1, target_index: 0 };
                                        }
                                    }
                                }
                                if (is_struct(actE)){
                                    // Queue the enemy action but DO NOT immediately switch to 'turn'.
                                    // Instead, set a defer flag so `battle_update` will begin the turn
                                    // only after any open dialog has fully closed.
                                    variable_struct_set(_B2, "turn_action_enemy", actE);
                                    variable_struct_set(_B2, "turn_queue", [ actE ]);
                                    // Mark action active so UI remains suppressed while this queued action runs
                                    try { variable_struct_set(_B2, "_action_active", true); } catch (e_actpi) {}
                                    variable_struct_set(_B2, "turn_i", 0);
                                    // Defer starting the turn until after dialog closes
                                    variable_struct_set(_B2, "_defer_turn_until_no_dialog", true);
                                    show_debug_message("[party][debug] queued enemy action (deferred) for pid=" + string(_pid) + ", slot=" + string(actE.slot));
                                }
                            }
                        }
                        return;
                    }

                    if (!is_undefined(gp) && is_struct(gp)){
                        var bpid = variable_struct_exists(gp, "bag_pid") ? variable_struct_get(gp, "bag_pid") : -1;
                        var page  = variable_struct_exists(gp, "page") ? variable_struct_get(gp, "page") : 0;
                        var brow  = variable_struct_exists(gp, "row") ? variable_struct_get(gp, "row") : 0;
                        var item_id = variable_struct_exists(gp, "item_id") ? variable_struct_get(gp, "item_id") : -1;

                        if (bpid >= 0){
                            var _b = bag_inventory_ensure(bpid);
                            if (array_length(_b.items) > page){
                                var pageArr = _b.items[page];
                                if (brow < array_length(pageArr)){
                                    var target = _P.mons[_P.sel]; if (!is_struct(target)) target = _P.mons[_P.sel] = {};
                                    // return existing held item to bag
                                    var prev = (variable_struct_exists(target, "held_item_id") ? variable_struct_get(target, "held_item_id") : -1);
                                    if (is_real(prev) && prev > 0) bag_inventory_add_item(bpid, prev, 1);

                                    // Safety: ensure the item is holdable before assigning
                                    var pending_holdable = true;
                                    if (!is_undefined(bag__item_is_holdable)){
                                        var _checkVal = undefined;
                                        if (variable_struct_exists(gp, "item_real_name")) _checkVal = variable_struct_get(gp, "item_real_name");
                                        else _checkVal = item_id;
                                        pending_holdable = bag__item_is_holdable(_checkVal);
                                    }

                                    if (!pending_holdable){
                                        show_debug_message("[party] Tried to give item but it is not holdable; action aborted.");
                                    } else {
                                        // assign new id and preserve canonical real name for rendering/lookup
                                        if (!is_undefined(item_id) && item_id > 0) variable_struct_set(target, "held_item_id", item_id);
                                        if (!is_undefined(gp) && is_struct(gp) && variable_struct_exists(gp, "item_real_name")){
                                            var _rn = variable_struct_get(gp, "item_real_name");
                                            if (!is_undefined(_rn) && string_length(string(_rn)) > 0) variable_struct_set(target, "held_item_real_name", string(_rn));
                                        } else {
                                            // fallback: try resolving from item_id via bag pages
                                            var _tryName = undefined;
                                            var _b_src = bag_inventory_ensure(bpid);
                                            if (is_struct(_b_src) && variable_struct_exists(_b_src, "items")){
                                                var __items_arr = variable_struct_get(_b_src, "items");
                                                if (is_array(__items_arr)){
                                                    for (var __p=0; __p<array_length(__items_arr); __p++){
                                                        var __arr = __items_arr[__p];
                                                        if (!is_array(__arr)) continue;
                                                        for (var __r=0; __r<array_length(__arr); __r++){
                                                            var __it = __arr[__r];
                                                            if (is_struct(__it) && variable_struct_exists(__it, "item_id") && variable_struct_get(__it, "item_id") == item_id){
                                                                if (variable_struct_exists(__it, "real_name")) { _tryName = string(variable_struct_get(__it, "real_name")); break; }
                                                            }
                                                        }
                                                        if (!is_undefined(_tryName)) break;
                                                    }
                                                }
                                            }
                                            if (!is_undefined(_tryName)) variable_struct_set(target, "held_item_real_name", _tryName);
                                        }

                                        // remove one from bag and refresh
                                        bag_inventory_remove_item(bpid, item_id, 1);
                                        bags_seed_from_items(bpid);
                                        show_debug_message("[party] Gave item " + string(item_id) + " to mon index " + string(_P.sel));

                                        // Close party UI and re-open the bag, restoring page/selection so player returns to bag menu
                                        if (!is_undefined(party_close)) party_close(_pid);
                                        if (!is_undefined(bag_open)) bag_open(bpid);
                                        var _b_after = bag_inventory_ensure(bpid);
                                        var _items_after = (is_struct(_b_after) && variable_struct_exists(_b_after, "items")) ? variable_struct_get(_b_after, "items") : [];
                                        _b_after.page = clamp(page, 0, max(0, array_length(_items_after) - 1));
                                        var _arrAfter = (is_array(_items_after) && _b_after.page >= 0 && _b_after.page < array_length(_items_after)) ? _items_after[_b_after.page] : [];
                                        var _maxSel = max(0, array_length(_arrAfter) - 1);
                                        _b_after.sel = clamp(brow, 0, _maxSel);
                                        var _rows = 8;
                                        _b_after.scroll = clamp(_b_after.scroll, 0, max(0, array_length(_arrAfter) - _rows));
                                        if (_b_after.sel < _b_after.scroll) _b_after.scroll = _b_after.sel;
                                        if (_b_after.sel >= _b_after.scroll + _rows) _b_after.scroll = max(0, _b_after.sel - _rows + 1);
                                        _b_after.lock = 4;
                                    }
                                }
                            }
                        }

                        // clear pending
                        _P.give_pending = undefined;
                    }

                    _P.mode = "list"; _P.lock = 2;
                }

                if (controls_pressed(_pid,"Run") && _P.lock == 0 && !_is_forced){ _P.mode = "list"; _P.lock = 2; _P.give_pending = undefined; }
            break;

            // Profile summary screen. Handles sprite intro, cry playback,
            // and description scrolling. `Run` returns to the list view.
            case "summary_profile":
                // If a learn flow is active, interpret MoveRight as 'close learn' instead of moving selection
                if (variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
                    if (controls_pressed(_pid, "MoveRight")){
                        variable_struct_set(_P, "learn_pending", undefined);
                        _P.lock = 2;
                    }
                } else if (controls_pressed(_pid,"MoveRight") && _n > 0){ _P.sel = clamp(_P.sel + 1, 0, _n - 1); _P.lock = 2; }
                if (controls_down(_pid,"Inventory")){
                    // Use repeat-aware scrolling for description when Inventory is held
                    if (controls_repeat(_pid, "MoveUp", 12, 4)){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                    }
                    if (controls_repeat(_pid, "MoveDown", 12, 4)){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    }
                }
                if (controls_pressed(_pid,"MoveLeft")  && _n > 0){ _P.sel = clamp(_P.sel - 1, 0, _n - 1); _P.lock = 2; }
                if (controls_pressed(_pid,"MoveDown")){
                    // If Inventory is held, scrolling is handled above via controls_repeat;
                    // otherwise pressing MoveDown should enter the moves summary.
                    if (!controls_down(_pid,"Inventory")){
                        _P.mode = "summary_moves"; _P.lock = 2;
                        // Aggressive hotfix: clear any existing learn_pending when entering
                        // the moves summary. This ensures stale state (e.g. step == "list")
                        // cannot cause the full learn list to render unexpectedly.
                        if (variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
                            variable_struct_set(_P, "learn_pending", undefined);
                        }
                    }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0 && !_is_forced){ _P.mode = "list"; _P.lock = 2; }
            break;

            // Moves summary: shows current moves and learnable moves.
            // Supports entering the learn/forget flow and blocks learning
            // while a battle is active when appropriate.
            case "summary_moves":
                var _M  = __party_mon_get(_P, _pid);
                var _mv = (is_struct(_M) && variable_struct_exists(_M,"moves")) ? variable_struct_get(_M, "moves") : [];
                // Use the filtered per-mon learnset helper so moves available for the species
                // are exposed here even when they weren't recently learned via level-up.
                var _lr = __party_get_learnset_for_mon(_M);
                var _nm = array_length(_mv), _nl = array_length(_lr);

                if (controls_pressed(_pid,"MoveRight") && _n > 0){ _P.sel = clamp(_P.sel + 1, 0, _n - 1); _P.lock = 2; }
                // Inventory-held description scrolling is handled further down
                if (controls_pressed(_pid,"MoveLeft")  && _n > 0){ _P.sel = clamp(_P.sel - 1, 0, _n - 1); _P.lock = 2; }

                var _invHeld = controls_down(_pid,"Inventory");
                if (_invHeld){
                    // Repeat-aware scrolling for description
                    if (controls_repeat(_pid, "MoveUp", 12, 4)){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                    }
                    if (controls_repeat(_pid, "MoveDown", 12, 4)){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    }
                    if (_nl > 0){
                        // When Inventory is held we treat Up/Down as description scrolling only.
                        // Do NOT change the learn-list selection while scrolling chat.
                        // To change the learn selection, release Inventory and use Up/Down normally.
                    } else _P.sum_learn_sel = 0;
                } else {
                    if (!controls_down(_pid,"Interact")){
                        // Allow navigating all 4 move slots (indices 0..3) so blank slots
                        // rendered as '-----' can be selected when learning a new move.
                        if (!variable_struct_exists(_P, "sum_move_sel")) _P.sum_move_sel = 0;
                        if (controls_pressed(_pid,"MoveDown")) _P.sum_move_sel = clamp(_P.sum_move_sel + 1, 0, 3);
                        if (controls_pressed(_pid,"MoveUp"))   _P.sum_move_sel = clamp(_P.sum_move_sel - 1, 0, 3);
                    }
                }

                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    // Block learning or swapping moves while in battle. The "LEARN" UI can
                    // still be shown, but pressing Interact to learn or replace a move is disabled.
                    var __battle_open_now = (!is_undefined(battle_is_open) && battle_is_open(_pid));
                    if (__battle_open_now){
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][learn] blocked learn/replace in battle (summary_moves)");
                        _P.lock = 6; // brief input lock to signal the block
                        return;
                    }
                    if (_nl > 0){
                        // Defensive: ensure sum_learn_sel exists and is in-bounds
                        if (!variable_struct_exists(_P, "sum_learn_sel")) _P.sum_learn_sel = 0;
                        _P.sum_learn_sel = clamp(_P.sum_learn_sel, 0, max(0, _nl - 1));
                        var _learnId = _lr[_P.sum_learn_sel];
                        if (_nm < 4){
                            // Ensure selection index exists
                            if (!variable_struct_exists(_P, "sum_move_sel")) _P.sum_move_sel = 0;
                            var _target_slot = clamp(_P.sum_move_sel, 0, 3);
                            // Prefer centralized learning logic if provided
                            if (!is_undefined(scr_move_learn_try)){
                                // debug removed
                                var _res = scr_move_learn_try(_M, _learnId);
                                // debug message removed
                                if (is_struct(_res) && variable_struct_exists(_res, "status")){
                                    var _st = variable_struct_get(_res, "status");
                                    if (_st == "learned"){
                                        var _slot = variable_struct_exists(_res, "slot") ? variable_struct_get(_res, "slot") : _target_slot;
                                        _P.sum_move_sel = clamp(_slot, 0, 3);
                                        // Ensure model persisted (scr_move_learn_try may have mutated _M.moves)
                                        if (!variable_struct_exists(_M, "moves")) variable_struct_set(_M, "moves", []);
                                        // Persist mutated mon back into party so changes stick
                                        if (is_real(_P.sel) && _P.sel >= 0){
                                            party_model_update_mon(_pid, _P.sel, _M);
                                            // Mirror persisted mon into the local party struct so the UI reflects the change immediately
                                            if (is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _P.mons[_P.sel] = _M;
                                        }
                                        _P.lock = 4;
                                    } else if (_st == "skipped"){
                                        // Already knows the move: inform player and do not insert
                                        var _msg = __party_move_name(_learnId) + " already known.";
                                        try { dialog2p_show_now(_pid, _msg); } catch (e_pmsg) { try { dialog2p_enqueue(_pid, _msg); } catch(e_) { show_debug_message("[party] " + _msg); } }
                                        _P.lock = 2;
                                    } else if (_st == "need_replace"){
                                        // Fall back to replace flow (enter summary_forget with learn_pending)
                                        var _lp_new = {};
                                        _lp_new.move_id = _learnId;
                                        _lp_new.step = "list";
                                        _lp_new.list_sel = 0;
                                        _lp_new.list_scroll = 0;
                                        var _mi_tmp = __party_get_learnset_for_mon(_M);
                                        if (is_array(_mi_tmp) && array_length(_mi_tmp) > 0){
                                            for (var __li = 0; __li < array_length(_mi_tmp); __li++){
                                                if (_mi_tmp[__li] == _learnId){ _lp_new.list_sel = __li; break; }
                                            }
                                            _lp_new.list_scroll = max(0, _lp_new.list_sel - 3);
                                        }
                                        variable_struct_set(_P, "learn_pending", _lp_new);
                                        var _ls = (variable_struct_exists(_lp_new, "list_sel") ? variable_struct_get(_lp_new, "list_sel") : 0);
                                        _P.sum_learn_sel = clamp(_ls, 0, max(0, array_length(__party_get_learnset_for_mon(_M)) - 1));
                                        _P.mode = "summary_forget"; _P.lock = 2;
                                    }
                                } else {
                                    // Unexpected res shape: fallback to safe insertion (below)
                                    ;
                                }
                            } else {
                                // No centralized helper: do a duplicate check and insert into target slot
                                var _known = false;
                                for (var __k=0; __k<array_length(_mv); __k++) if (_mv[__k] == _learnId) { _known = true; break; }
                                if (_known){
                                    var _msg2 = __party_move_name(_learnId) + " already known.";
                                    try { dialog2p_show_now(_pid, _msg2); } catch (e_pmsg2) { try { dialog2p_enqueue(_pid, _msg2); } catch(e_) { show_debug_message("[party] " + _msg2); } }
                                    _P.lock = 2;
                                } else {
                                    // insert into exact selected slot (pad with placeholders as needed)
                                    while (array_length(_mv) < _target_slot) array_push(_mv, -1);
                                    if (array_length(_mv) == _target_slot) array_push(_mv, _learnId);
                                    else _mv[_target_slot] = _learnId;
                                    variable_struct_set(_M, "moves", _mv);
                                    // Persist mutated mon back into party so changes stick
                                    if (is_real(_P.sel) && _P.sel >= 0){
                                        party_model_update_mon(_pid, _P.sel, _M);
                                        // Mirror persisted mon into the local party struct so the UI reflects the change immediately
                                        if (is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _P.mons[_P.sel] = _M;
                                    }
                                    _P.sum_move_sel = _target_slot;
                                    _P.lock = 4;
                                }
                            }
                        }
                        else {
                            // Enter forget flow: ensure a learn_pending wrapper exists so
                            // the right-panel learn LIST can render and receive input.
                            var _lp_new = {};
                            _lp_new.move_id = _learnId;
                            // Start directly on the selectable LIST so player can pick replacement
                            _lp_new.step = "list";
                            _lp_new.list_sel = 0;
                            _lp_new.list_scroll = 0;
                            // Try to focus selection on the chosen move inside the per-mon learnset
                            if (is_struct(_M)){
                                var _mi_tmp = __party_get_learnset_for_mon(_M);
                                if (is_array(_mi_tmp) && array_length(_mi_tmp) > 0){
                                    for (var __li = 0; __li < array_length(_mi_tmp); __li++){
                                        if (_mi_tmp[__li] == _learnId){ _lp_new.list_sel = __li; break; }
                                    }
                                    _lp_new.list_scroll = max(0, _lp_new.list_sel - 3);
                                }
                            }
                                variable_struct_set(_P, "learn_pending", _lp_new);
                                // Ensure the moves summary cursor for learn selection
                                // starts focused on the same item as the right-panel list
                                if (variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
                                    var _lp_sync = variable_struct_get(_P, "learn_pending");
                                    var _ls = (variable_struct_exists(_lp_sync, "list_sel") ? variable_struct_get(_lp_sync, "list_sel") : 0);
                                    _P.sum_learn_sel = clamp(_ls, 0, max(0, array_length(__party_get_learnset_for_mon(_M)) - 1));
                                    // debug removed
                                }
                                _P.mode = "summary_forget"; _P.lock = 2;
                        }
                    }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0 && !(is_struct(_P) && variable_struct_exists(_P, "_battle_swap_mode_forced") && variable_struct_get(_P, "_battle_swap_mode_forced") == true)){ _P.mode = "summary_profile"; _P.lock = 2; }
            break;

            // Forget/replace flow when learning a move. Presents the
            // current moves and lets the player pick a slot to forget.
            case "summary_forget":
                var _M2  = __party_mon_get(_P, _pid);
                var _mv2 = (is_struct(_M2) && variable_struct_exists(_M2,"moves")) ? variable_struct_get(_M2, "moves") : [];
                var _nm2 = array_length(_mv2);
                if (_nm2 <= 0){ 
                    _P.mode = "summary_moves";
                    if (variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
                        variable_struct_set(_P, "learn_pending", undefined);
                    }
                    break; }

                // --- Handle confirm (Interact) first so simultaneous Move+Interact
                // inputs don't accidentally change the selection right before apply.
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    // Block confirming a replacement while in battle
                    var __battle_open_now2 = (!is_undefined(battle_is_open) && battle_is_open(_pid));
                    if (__battle_open_now2){
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][learn] blocked learn/replace in battle (summary_forget)");
                        _P.lock = 6;
                        return;
                    }
                    // Ensure sum_move_sel exists and is in-bounds
                    if (!variable_struct_exists(_P, "sum_move_sel")) _P.sum_move_sel = 0;
                    _P.sum_move_sel = clamp(_P.sum_move_sel, 0, max(0, array_length(_mv2) - 1));
                    // Ensure sum_learn_sel exists and is in-bounds
                    if (!variable_struct_exists(_P, "sum_learn_sel")) _P.sum_learn_sel = 0;
                    var _lr_now = __party_get_learnset_for_mon(_M2);
                    var _nl_now = array_length(_lr_now);
                    _P.sum_learn_sel = clamp(_P.sum_learn_sel, 0, max(0, _nl_now - 1));
                    var _chosen_now = (_nl_now > 0) ? _lr_now[_P.sum_learn_sel] : -1;
                    // debug removed
                    if (_chosen_now != -1){
                        // Prevent replacing with a move that's already known in another slot
                        var _dup = false;
                        for (var __d = 0; __d < array_length(_mv2); __d++){
                            if (__d != _P.sum_move_sel && _mv2[__d] == _chosen_now){ _dup = true; break; }
                        }
                        if (_dup){
                            var _msg_dup = __party_move_name(_chosen_now) + " already known.";
                            try { dialog2p_show_now(_pid, _msg_dup); } catch (e_pmsg3) { try { dialog2p_enqueue(_pid, _msg_dup); } catch(e_) { show_debug_message("[party] " + _msg_dup); } }
                            // Keep learn_pending active and do not apply replacement
                            _P.lock = 2;
                            variable_struct_set(_P, "learn_pending", variable_struct_get(_P, "learn_pending"));
                            return;
                        }
                        // Apply replacement into the selected slot and return to moves summary
                        _mv2[_P.sum_move_sel] = _chosen_now; variable_struct_set(_M2, "moves", _mv2);
                        // Persist mutated mon back into party storage so replacement is saved
                        if (is_real(_P.sel) && _P.sel >= 0){
                            party_model_update_mon(_pid, _P.sel, _M2);
                            // Mirror persisted mon into the local party struct so the UI reflects the change immediately
                            if (is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _P.mons[_P.sel] = _M2;
                        }
                        // Clear the learn flow and return to moves view
                        if (variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
                            variable_struct_set(_P, "learn_pending", undefined);
                        }
                        _P.mode = "summary_moves"; _P.lock = 4;
                        // consume the frame so additional movement isn't processed
                        return;
                    } else {
                        _P.mode = "summary_moves"; _P.lock = 2;
                        if (variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
                            variable_struct_set(_P, "learn_pending", undefined);
                        }
                        return;
                    }
                }

                // If we didn't confirm, process navigation: allow Up/Down to move either
                // the left slot selector or the right learn-list selection depending on
                // whether the learn list is active.
                var _lp_tmp_f = (variable_struct_exists(_P, "learn_pending") ? variable_struct_get(_P, "learn_pending") : undefined);
                var _learn_list_active = false;
                if (is_struct(_lp_tmp_f)){
                    var _lp_step_f = (variable_struct_exists(_lp_tmp_f, "step") ? variable_struct_get(_lp_tmp_f, "step") : "desc");
                    _learn_list_active = (string(_lp_step_f) != "desc");
                }
                if (_learn_list_active){
                    var _invHeld_now = controls_down(_pid, "Inventory");
                    // If Inventory is held, Up/Down are reserved for description scrolling
                    if (!_invHeld_now){
                        // move list selection in learn_pending
                        if (controls_pressed(_pid,"MoveDown")){
                            if (!variable_struct_exists(_lp_tmp_f, "list_sel")) variable_struct_set(_lp_tmp_f, "list_sel", 0);
                            var _new = clamp(variable_struct_get(_lp_tmp_f, "list_sel") + 1, 0, max(0, array_length(__party_get_learnset_for_mon(_M2)) - 1));
                            variable_struct_set(_lp_tmp_f, "list_sel", _new);
                            variable_struct_set(_lp_tmp_f, "list_scroll", max(0, _new - 3));
                            variable_struct_set(_P, "learn_pending", _lp_tmp_f);
                            // mirror to sum_learn_sel so confirm uses expected index
                            _P.sum_learn_sel = _new;
                        }
                        if (controls_pressed(_pid,"MoveUp")){
                            if (!variable_struct_exists(_lp_tmp_f, "list_sel")) variable_struct_set(_lp_tmp_f, "list_sel", 0);
                            var _new2 = clamp(variable_struct_get(_lp_tmp_f, "list_sel") - 1, 0, max(0, array_length(__party_get_learnset_for_mon(_M2)) - 1));
                            variable_struct_set(_lp_tmp_f, "list_sel", _new2);
                            variable_struct_set(_lp_tmp_f, "list_scroll", max(0, _new2 - 3));
                            variable_struct_set(_P, "learn_pending", _lp_tmp_f);
                            _P.sum_learn_sel = _new2;
                        }
                    }
                } else {
                    if (!_learn_list_active && controls_pressed(_pid,"MoveDown")) _P.sum_move_sel = clamp(_P.sum_move_sel + 1, 0, _nm2 - 1);
                }
                if (controls_down(_pid,"Inventory")){
                    // Holding Inventory: Up/Down scrolls description
                    if (controls_pressed(_pid,"MoveUp")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party_input] summary_forget_press_up -> " + string(global.sys_party_desc_scroll_req));
                    }
                    if (controls_pressed(_pid,"MoveDown")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party_input] summary_forget_press_down -> " + string(global.sys_party_desc_scroll_req));
                    }
                    // Additionally, while in forget mode allow Left/Right (or Up/Down)
                    // to move the right-panel learn selection (sum_learn_sel) so the
                    // player can pick replacements while holding Inventory.
                    var _lr2 = __party_get_learnset_for_mon(_M2);
                    var _nl2 = array_length(_lr2);
                    if (_nl2 > 0){
                        // While Inventory is held, do not modify the learn-list selection here.
                        // Keep Up/Down reserved for description scrolling so chat doesn't move
                        // the learn-list. Release Inventory to adjust the selection.
                    }
                }
                if (!_learn_list_active && controls_pressed(_pid,"MoveUp"))   _P.sum_move_sel = clamp(_P.sum_move_sel - 1, 0, _nm2 - 1);
                // Use filtered learnset for forget flow as well so available replacements
                // are derived consistently from species data.
                var _lr2 = __party_get_learnset_for_mon(_M2);
                var _nl2 = array_length(_lr2);
                var _chosen = (_nl2 > 0) ? _lr2[_P.sum_learn_sel] : -1;
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    // Ensure sum_move_sel exists and is in-bounds
                    if (!variable_struct_exists(_P, "sum_move_sel")) _P.sum_move_sel = 0;
                    _P.sum_move_sel = clamp(_P.sum_move_sel, 0, max(0, array_length(_mv2) - 1));
                    // Ensure sum_learn_sel exists and is in-bounds
                    if (!variable_struct_exists(_P, "sum_learn_sel")) _P.sum_learn_sel = 0;
                    var _lr_now = __party_get_learnset_for_mon(_M2);
                    var _nl_now = array_length(_lr_now);
                    _P.sum_learn_sel = clamp(_P.sum_learn_sel, 0, max(0, _nl_now - 1));
                    var _chosen_now = (_nl_now > 0) ? _lr_now[_P.sum_learn_sel] : -1;
                    // debug removed
                    if (_chosen_now != -1){
                        // Apply replacement into the selected slot and return to moves summary
                        _mv2[_P.sum_move_sel] = _chosen_now; variable_struct_set(_M2, "moves", _mv2);
                        // Persist mutated mon back into party storage so replacement is saved
                        if (is_real(_P.sel) && _P.sel >= 0){
                            party_model_update_mon(_pid, _P.sel, _M2);
                            // Mirror persisted mon into the local party struct so the UI reflects the change immediately
                            if (is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _P.mons[_P.sel] = _M2;
                        }
                        // Clear the learn flow and return to moves view
                        if (variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
                            variable_struct_set(_P, "learn_pending", undefined);
                        }
                        _P.mode = "summary_moves"; _P.lock = 4;
                        // debug removed
                    } else {
                        // Nothing chosen: just return to moves summary
                        _P.mode = "summary_moves"; _P.lock = 2;
                        if (variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
                            variable_struct_set(_P, "learn_pending", undefined);
                        }
                    }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ 
                    _P.mode = "summary_moves"; _P.lock = 2;
                    if (variable_struct_exists(_P, "learn_pending") && is_struct(variable_struct_get(_P, "learn_pending"))){
                        variable_struct_set(_P, "learn_pending", undefined);
                    }
                }
            break;
        }

        // ---- Summary page animation (mode + selection driven) ----
        var _curMode = string(_P.mode);
        var _prevMode = string(_P.summary_prev_mode);
        var _isSummary_cur  = (_curMode == "summary_profile" || _curMode == "summary_moves" || _curMode == "summary_forget");
        var _isSummary_prev = (_prevMode == "summary_profile" || _prevMode == "summary_moves" || _prevMode == "summary_forget");
        if (_curMode != _prevMode){
            if (_isSummary_cur){
                _P.summary_cur_scale = 1;
                _P.summary_anim = 0;
                _P.summary_anim_active = true;
                _P.summary_spin_angle = 0;
                // If entering the profile summary page, also start the sprite intro + play cry
                if (_curMode == "summary_profile"){
                    _P.summary_sprite_anim = 0;
                    _P.summary_sprite_anim_active = true;
                    _P.summary_sprite_anim_start_ms = current_time;
                    // Play cry now (once per selection)
                    if (!is_undefined(pkicons_play_cry_by_mon)){
                        var __m_for_cry2 = __party_mon_get(_P, _pid);
                        if (is_struct(__m_for_cry2) && _P.summary_last_cry_sel != _P.sel){ pkicons_play_cry_by_mon(__m_for_cry2); _P.summary_last_cry_sel = _P.sel; }
                    }
                }
            } else if (_isSummary_prev && !_isSummary_cur){
                _P.summary_cur_scale = 1;
                _P.summary_anim_active = false;
                _P.summary_anim = 0;
                _P.summary_spin_angle = 0;
            }
            _P.summary_prev_mode = _curMode;
        }
        // Selection change inside summary triggers re-shrink
        if (_isSummary_cur){
                if (_P.sel != _P.summary_prev_sel){
                _P.summary_prev_sel = _P.sel;
                _P.summary_cur_scale = 1;
                _P.summary_anim = 0;
                _P.summary_anim_active = true;
                _P.summary_spin_angle = 0;
                // If on profile page, start sprite intro animation (time-based) and mark for cry
                if (_curMode == "summary_profile"){
                    _P.summary_sprite_anim = 0;
                    _P.summary_sprite_anim_active = true;
                    _P.summary_sprite_anim_start_ms = current_time;
                    // Play cry immediately (once per selection)
                    if (!is_undefined(pkicons_play_cry_by_mon)){
                        var __m_for_cry = __party_mon_get(_P, _pid);
                        if (is_struct(__m_for_cry) && _P.summary_last_cry_sel != _P.sel){ pkicons_play_cry_by_mon(__m_for_cry); _P.summary_last_cry_sel = _P.sel; }
                    }
                }
            }
        } else {
            _P.summary_prev_sel = _P.sel;
        }
        // Progress shrink animation (slowed & smoother)
        if (_P.summary_anim_active){
            var _DUR = 32; // slower animation (was 18)
            if (_P.summary_anim < _DUR){
                _P.summary_anim += 1;
                var _t = clamp(_P.summary_anim / _DUR, 0, 1);
                // Smoothstep easing (cubic Hermite) for gentle start/end
                var _ease = (_t * _t * (3 - 2 * _t));
                _P.summary_cur_scale = lerp(1, _P.summary_target_scale, _ease);
            } else {
                _P.summary_cur_scale = _P.summary_target_scale;
            }
        }
        // Keep a fallback old-style frame counter (not primary): cap if it grows
        if (_P.summary_sprite_anim_active){
            var _SP_DUR_FALLBACK = 60;
            if (_P.summary_sprite_anim < _SP_DUR_FALLBACK) _P.summary_sprite_anim += 1;
            else _P.summary_sprite_anim_active = false;
        }
        // Continuous spin while in summary (slower spin)
        if (_isSummary_cur){
            _P.summary_spin_angle = (_P.summary_spin_angle + 6) mod 360; // was 12
        }
    }
}
