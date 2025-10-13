// Party input module: contains party_update (input/state transitions) separated from UI/draw/model.
// Implementation function is named __party_impl_party_update and is invoked by the public party_update()

function __party_impl_party_update(){
    if (!variable_global_exists("PARTY")) return;
    var _players = array_length(global.PARTY); if (_players <= 0) return;

    // keep lock synced

    for (var _pid = 0; _pid < _players; _pid++){
        var _P = party_ensure(_pid);
        if (!_P.open) continue;
        if (_P.lock > 0) _P.lock--;

        var _mons = _P.mons, _n = array_length(_mons), _ROWS = 6;

        if (_P.mode != "select" && _P.mode != "summary_profile" && _P.mode != "summary_moves" && _P.mode != "summary_forget"){
            if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.open = false; _P.lock = 2; continue; }
        }

        switch (_P.mode){
            case "list":
                if (controls_pressed(_pid,"MoveDown") && _n > 0) _P.sel = clamp(_P.sel + 1, 0, _n - 1);
                if (controls_pressed(_pid,"MoveUp")   && _n > 0) _P.sel = clamp(_P.sel - 1, 0, _n - 1);
                _P.scroll = clamp(_P.scroll, 0, max(0, _n - _ROWS));
                if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
                if (_P.sel >= _P.scroll + _ROWS) _P.scroll = max(0, _P.sel - _ROWS + 1);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){ _P.mode="menu"; _P.menu_sel=0; _P.lock=2; }
            break;

            case "menu":
                if (controls_pressed(_pid,"MoveDown")) _P.menu_sel = clamp(_P.menu_sel + 1, 0, 3);
                if (controls_pressed(_pid,"MoveUp"))   _P.menu_sel = clamp(_P.menu_sel - 1, 0, 3);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    switch (_P.menu_sel){
                        case 0: _P.mode="summary_profile"; _P.sum_move_sel=0; _P.sum_learn_sel=0; _P.lock=2; break;
                        case 1: _P.swap_index = _P.sel; _P.mode="select"; _P.lock=2; break;
                        case 2:
                            // Enter item action submenu (Give / Take / Cancel)
                            _P.mode = "item_action";
                            show_debug_message("[party] Entered item_action mode (Item submenu)");
                            _P.item_menu_sel = 0;
                            _P.lock = 2;
                            break;
                        case 3: _P.mode="list"; _P.lock=2; break;
                    }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode="list"; _P.lock=2; }
            break;

            case "item_action":
                // Build labels the same way the party draw does so indices line up with actions
                var _labels = ["Take","Cancel"];
                var _shouldShowGive = false;
                if (variable_struct_exists(_P, "give_pending")){
                    _shouldShowGive = true;
                } else {
                    var _selMon = undefined;
                    if (variable_struct_exists(_P, "mons") && is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _selMon = _P.mons[_P.sel];
                    if (!is_undefined(_selMon) && is_struct(_selMon) && variable_struct_exists(_selMon, "held_item_id")){
                        var _hid_tmp = variable_struct_get(_selMon, "held_item_id");
                        if (is_real(_hid_tmp) && _hid_tmp > 0) _shouldShowGive = false; else _shouldShowGive = true;
                    } else {
                        _shouldShowGive = true;
                    }
                }
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
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "menu"; _P.lock = 2; }
            break;

            case "select":
                if (controls_pressed(_pid,"MoveDown") && _n > 0) _P.sel = clamp(_P.sel + 1, 0, _n - 1);
                if (controls_pressed(_pid,"MoveUp")   && _n > 0) _P.sel = clamp(_P.sel - 1, 0, _n - 1);
                _P.scroll = clamp(_P.scroll, 0, max(0, _n - _ROWS));
                if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
                if (_P.sel >= _P.scroll + _ROWS) _P.scroll = max(0, _P.sel - _ROWS + 1);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    var _src = _P.swap_index, _dst = _P.sel;
                    if (_n > 0 && _src >= 0 && _src < _n && _dst >= 0 && _dst < _n && _src != _dst){
                        party_model_swap(_pid, _src, _dst);
                        _P.sel = _dst;
                    }
                    _P.mode="list"; _P.swap_index=-1; _P.lock=2;
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode="list"; _P.swap_index=-1; _P.lock=2; }
            break;

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
                        // Ensure the bag data is present
                        if (bpid >= 0){
                            var _b = bag_inventory_ensure(bpid);
                            // Apply healing: simple default behavior mirrors bag__use_item_on_self default heal
                            var target = _P.mons[_P.sel]; if (!is_struct(target)) target = _P.mons[_P.sel] = {};
                            // Find battle slot and actor to mirror HP if in battle
                            if (!is_undefined(__battle_ensure_slot) && !is_undefined(battle_is_open) && battle_is_open(_pid)){
                                var _B = __battle_ensure_slot(_pid);
                                if (is_struct(_B)){
                                    var A0 = (is_array(_B.actor) && array_length(_B.actor) > 0) ? _B.actor[0] : undefined;
                                    // Close the party UI so the dialog can appear unobstructed, then show the
                                    // standard "Trainer used an item" dialog (if provided by bag)
                                    if (!is_undefined(party_close)) party_close(_pid);
                                    if (variable_struct_exists(up, "out_prefix") && string_length(string(variable_struct_get(up, "out_prefix"))) > 0){
                                        var _dlg_txt = string(variable_struct_get(up, "out_prefix"));
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][debug] requesting dialog open: pid=" + string(_pid) + ", text_len=" + string(string_length(_dlg_txt)) + ", preview='" + string_copy(_dlg_txt,1,min(48,string_length(_dlg_txt))) + "'");
                                        if (!is_undefined(__battle_stub_dialog)) __battle_stub_dialog(_pid, _dlg_txt);
                                        else if (!is_undefined(dialog2p_open_text)) dialog2p_open_text(_pid, _dlg_txt);
                                        // Probe whether dialog system reports open immediately after call (verbose only)
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){ if (!is_undefined(dialog2p_is_open)) show_debug_message("[party][debug] dialog2p_is_open(pid) -> " + string(dialog2p_is_open(_pid))); }
                                        // Debug: dump the dialog's all_lines so we can see what the dialog system will render
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                            if (variable_global_exists("DIALOG2P") && is_array(global.DIALOG2P) && array_length(global.DIALOG2P) > _pid){
                                                var _dref = global.DIALOG2P[_pid];
                                                if (is_struct(_dref) && variable_struct_exists(_dref, "all_lines")){
                                                    var _max = min(8, array_length(_dref.all_lines));
                                                    var _pv = "";
                                                    for (var _li = 0; _li < _max; _li++){
                                                        var _ln = string(_dref.all_lines[_li]);
                                                        _pv += "[" + string(_li) + "]" + string_copy(_ln, 1, min(120, string_length(_ln))) + "; ";
                                                    }
                                                    show_debug_message("[dialog][debug] all_lines_preview pid=" + string(_pid) + ", count=" + string(array_length(_dref.all_lines)) + ", preview='" + _pv + "'");
                                                }
                                            }
                                        }
                                    }
                                    // Apply structured effects from data loaders
                                    var target_mon = _P.mons[_P.sel]; if (!is_struct(target_mon)) target_mon = _P.mons[_P.sel] = {};
                                    var res = undefined;
                                    if (!is_undefined(scr_apply_item_effects)) res = scr_apply_item_effects(item_id, target_mon, A0);
                                    else res = { applied:false };
                                    if (is_struct(res) && res.applied){
                                        // Remove item and refresh bag
                                        bag_inventory_remove_item(bpid, item_id, 1);
                                        bags_seed_from_items(bpid);
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                            var _healed_val = "0";
                                            if (is_struct(res) && variable_struct_exists(res, "healed")) _healed_val = string(variable_struct_get(res, "healed"));
                                            show_debug_message("[party][debug] scr_apply_item_effects result: " + string((is_struct(res) && variable_struct_exists(res, "applied")) ? string(variable_struct_get(res, "applied")) : "false") + ", healed=" + _healed_val);
                                        }
                                        // No extra dialog about effect details — dialog was already opened earlier via out_prefix
                                    }
                                }
                                // Reopen/close bag briefly so UI state remains consistent
                                bag_open(bpid); bag_close(bpid);
                            }

                            // Debug: report that the use was applied and whether we queued an enemy action
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[party][debug] applied use_pending item_id=" + string(item_id) + " on mon_index=" + string(_P.sel));
                        }

                        // Clear pending and return to list
                        _P.use_pending = undefined;
                        _P.mode = "list"; _P.lock = 2;

                        // After consuming an item in battle, allow the enemy to take their turn.
                        if (!is_undefined(__battle_ensure_slot)){
                            var _B2 = __battle_ensure_slot(_pid);
                            if (is_struct(_B2)){
                                // No player action this turn (item use consumes player's action)
                                _B2.turn_action_player = undefined;
                                // Defensive: clear any stale pending_close flags so the battle isn't closed
                                // immediately if another codepath set _pending_close earlier.
                                if (variable_struct_exists(_B2, "_pending_close") && _B2._pending_close){
                                    show_debug_message("[party][debug] Clearing stale _pending_close due to in-battle item use (pid=" + string(_pid) + ")");
                                    _B2._pending_close = false;
                                }
                                // Choose a simple enemy action locally (avoid referencing external helpers)
                                var actE = undefined;
                                if (is_array(_B2.actor) && array_length(_B2.actor) > 1){
                                    var AE = _B2.actor[1];
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
                                    _B2.turn_action_enemy = actE;
                                    _B2.turn_queue = [ actE ];
                                    _B2.turn_i = 0;
                                    // Defer starting the turn until after dialog closes
                                    _B2._defer_turn_until_no_dialog = true;
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
                                            if (is_struct(_b_src)){
                                                for (var __p=0; __p<array_length(_b_src.items); __p++){
                                                    var __arr = _b_src.items[__p];
                                                    for (var __r=0; __r<array_length(__arr); __r++){
                                                        var __it = __arr[__r];
                                                        if (is_struct(__it) && variable_struct_exists(__it, "item_id") && __it.item_id == item_id){
                                                            if (variable_struct_exists(__it, "real_name")) { _tryName = string(__it.real_name); break; }
                                                        }
                                                    }
                                                    if (!is_undefined(_tryName)) break;
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
                                        _b_after.page = clamp(page, 0, max(0, array_length(_b_after.items) - 1));
                                        var _arrAfter = _b_after.items[_b_after.page];
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

                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "list"; _P.lock = 2; _P.give_pending = undefined; }
            break;

            case "summary_profile":
                if (controls_pressed(_pid,"MoveRight") && _n > 0){ _P.sel = clamp(_P.sel + 1, 0, _n - 1); _P.lock = 2; }
                if (controls_down(_pid,"Inventory")){
                    if (controls_pressed(_pid,"MoveLeft")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                    }
                    if (controls_pressed(_pid,"MoveRight")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    }
                }
                if (controls_pressed(_pid,"MoveLeft")  && _n > 0){ _P.sel = clamp(_P.sel - 1, 0, _n - 1); _P.lock = 2; }
                if (controls_pressed(_pid,"MoveDown")){
                    if (controls_down(_pid,"Inventory")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    } else {
                        _P.mode = "summary_moves"; _P.lock = 2;
                    }
                }
                if (controls_down(_pid,"Inventory") && controls_pressed(_pid,"MoveUp")){
                    if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                    global.sys_party_desc_scroll_req -= 28;
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "list"; _P.lock = 2; }
            break;

            case "summary_moves":
                var _M  = __party_mon_get(_P, _pid);
                var _mv = (is_struct(_M) && variable_struct_exists(_M,"moves")) ? variable_struct_get(_M, "moves") : [];
                var _lr = (is_struct(_M) && variable_struct_exists(_M,"learnset")) ? variable_struct_get(_M, "learnset") : [];
                var _nm = array_length(_mv), _nl = array_length(_lr);

                if (controls_pressed(_pid,"MoveRight") && _n > 0){ _P.sel = clamp(_P.sel + 1, 0, _n - 1); _P.lock = 2; }
                if (controls_down(_pid,"Inventory")){
                    if (controls_pressed(_pid,"MoveLeft")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                    }
                    if (controls_pressed(_pid,"MoveRight")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    }
                }
                if (controls_pressed(_pid,"MoveLeft")  && _n > 0){ _P.sel = clamp(_P.sel - 1, 0, _n - 1); _P.lock = 2; }

                var _invHeld = controls_down(_pid,"Inventory");
                if (_invHeld){
                    if (controls_pressed(_pid,"MoveUp")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                    }
                    if (controls_pressed(_pid,"MoveDown")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    }
                    if (_nl > 0){
                        if (controls_pressed(_pid,"MoveDown")) _P.sum_learn_sel = clamp(_P.sum_learn_sel + 1, 0, _nl - 1);
                        if (controls_pressed(_pid,"MoveUp"))   _P.sum_learn_sel = clamp(_P.sum_learn_sel - 1, 0, _nl - 1);
                    } else _P.sum_learn_sel = 0;
                } else {
                    if (!controls_down(_pid,"Interact")){
                        if (_nm > 0){
                            if (controls_pressed(_pid,"MoveDown")) _P.sum_move_sel = clamp(_P.sum_move_sel + 1, 0, _nm - 1);
                            if (controls_pressed(_pid,"MoveUp"))   _P.sum_move_sel = clamp(_P.sum_move_sel - 1, 0, _nm - 1);
                        } else _P.sum_move_sel = 0;
                    }
                }

                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    if (_nl > 0){
                        var _learnId = _lr[_P.sum_learn_sel];
                        if (_nm < 4){ array_push(_mv, _learnId); variable_struct_set(_M, "moves", _mv); _P.sum_move_sel = array_length(_mv) - 1; _P.lock = 4; }
                        else { _P.mode = "summary_forget"; _P.lock = 2; }
                    }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "summary_profile"; _P.lock = 2; }
            break;

            case "summary_forget":
                var _M2  = __party_mon_get(_P, _pid);
                var _mv2 = (is_struct(_M2) && variable_struct_exists(_M2,"moves")) ? variable_struct_get(_M2, "moves") : [];
                var _nm2 = array_length(_mv2);
                if (_nm2 <= 0){ _P.mode = "summary_moves"; break; }
                if (controls_pressed(_pid,"MoveDown")) _P.sum_move_sel = clamp(_P.sum_move_sel + 1, 0, _nm2 - 1);
                if (controls_down(_pid,"Inventory")){
                    if (controls_pressed(_pid,"MoveLeft")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                    }
                    if (controls_pressed(_pid,"MoveRight")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    }
                }
                if (controls_pressed(_pid,"MoveUp"))   _P.sum_move_sel = clamp(_P.sum_move_sel - 1, 0, _nm2 - 1);
                var _lr2 = (is_struct(_M2) && variable_struct_exists(_M2,"learnset")) ? variable_struct_get(_M2, "learnset") : [];
                var _nl2 = array_length(_lr2);
                var _chosen = (_nl2 > 0) ? _lr2[_P.sum_learn_sel] : -1;
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    if (_chosen != -1){ _mv2[_P.sum_move_sel] = _chosen; variable_struct_set(_M2, "moves", _mv2); _P.mode = "summary_moves"; _P.lock = 4; }
                    else { _P.mode = "summary_moves"; _P.lock = 2; }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "summary_moves"; _P.lock = 2; }
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
