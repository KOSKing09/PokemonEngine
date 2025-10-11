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
                // simple two-option submenu for Item: Give / Take / Cancel
                if (controls_pressed(_pid,"MoveDown")) _P.item_menu_sel = clamp(_P.item_menu_sel + 1, 0, 2);
                if (controls_pressed(_pid,"MoveUp"))   _P.item_menu_sel = clamp(_P.item_menu_sel - 1, 0, 2);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    switch (_P.item_menu_sel){
                        case 0: // Give: open bag and mark for giving to this mon
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
                            break;
                        case 1: // Take: move held item from mon into bag (if present)
                            var target = _P.mons[_P.sel];
                            if (is_struct(target) && variable_struct_exists(target, "held_item_id")){
                                var hid = variable_struct_get(target, "held_item_id");
                                if (is_real(hid) && hid > 0){
                                    bag_inventory_add_item(_pid, hid, 1);
                                    // clear held item
                                    variable_struct_set(target, "held_item_id", -1);
                                    bags_seed_from_items(_pid);
                                    show_debug_message("[party] Took item " + string(hid) + " from mon index " + string(_P.sel));
                                } else { show_debug_message("[party] No held item to take"); }
                            } else { show_debug_message("[party] No held item structure"); }
                            // return to party menu
                            _P.mode = "list"; _P.lock = 4; _P.give_pending = undefined;
                            break;
                        case 2: // Cancel
                            _P.mode = "menu"; _P.lock = 2;
                            break;
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
                if (controls_pressed(_pid,"MoveDown") && _n > 0) _P.sel = clamp(_P.sel + 1, 0, _n - 1);
                if (controls_pressed(_pid,"MoveUp")   && _n > 0) _P.sel = clamp(_P.sel - 1, 0, _n - 1);
                _P.scroll = clamp(_P.scroll, 0, max(0, _n - _ROWS));
                if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
                if (_P.sel >= _P.scroll + _ROWS) _P.scroll = max(0, _P.sel - _ROWS + 1);

                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    var gp = (is_struct(_P) && variable_struct_exists(_P, "give_pending") ? _P.give_pending : undefined);
                    if (!is_undefined(gp) && is_struct(gp)){
                        var bpid = variable_struct_exists(gp, "bag_pid") ? variable_struct_get(gp, "bag_pid") : -1;
                        var page  = variable_struct_exists(gp, "page") ? variable_struct_get(gp, "page") : 0;
                        var brow  = variable_struct_exists(gp, "row") ? variable_struct_get(gp, "row") : 0;
                        var item_id = variable_struct_exists(gp, "item_id") ? variable_struct_get(gp, "item_id") : -1;

                        if (bpid >= 0){
                            var _b = bag_inventory_ensure(bpid);
                            if (array_length(_b.items) > page){ var pageArr = _b.items[page]; if (brow < array_length(pageArr)){
                                var target = _P.mons[_P.sel]; if (!is_struct(target)) target = _P.mons[_P.sel] = {};
                                // swap behavior: return existing held item to bag
                                var prev = (variable_struct_exists(target, "held_item_id") ? variable_struct_get(target, "held_item_id") : -1);
                                if (is_real(prev) && prev > 0){ bag_inventory_add_item(bpid, prev, 1); }
                                // assign new
                                if (!is_undefined(item_id) && item_id > 0) variable_struct_set(target, "held_item_id", item_id);
                                // remove one from bag
                                bag_inventory_remove_item(bpid, item_id, 1);
                                // refresh bag pages from sys_qty
                                bags_seed_from_items(bpid);
                                show_debug_message("[party] Gave item " + string(item_id) + " to mon index " + string(_P.sel));

                                // Close party UI and re-open the bag, restoring page/selection so player returns to bag menu
                                if (!is_undefined(party_close)) party_close(_pid);
                                if (!is_undefined(bag_open)) bag_open(bpid);
                                var _b_after = bag_inventory_ensure(bpid);
                                // restore page (clamp) and sel (clamp to available rows)
                                _b_after.page = clamp(page, 0, max(0, array_length(_b_after.items) - 1));
                                var _arrAfter = _b_after.items[_b_after.page];
                                var _maxSel = max(0, array_length(_arrAfter) - 1);
                                _b_after.sel = clamp(brow, 0, _maxSel);
                                // ensure scroll covers sel (rows = 8)
                                var _rows = 8;
                                _b_after.scroll = clamp(_b_after.scroll, 0, max(0, array_length(_arrAfter) - _rows));
                                if (_b_after.sel < _b_after.scroll) _b_after.scroll = _b_after.sel;
                                if (_b_after.sel >= _b_after.scroll + _rows) _b_after.scroll = max(0, _b_after.sel - _rows + 1);
                                // short lock to avoid immediate input carryover
                                _b_after.lock = 4;
                            }}
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
