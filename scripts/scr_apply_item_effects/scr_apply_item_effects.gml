function __item_effects_push_unique(_arr, _value){
    if (!is_array(_arr)) return [_value];
    var found = false;
    for (var i = 0; i < array_length(_arr); ++i){ if (_arr[i] == _value){ found = true; break; } }
    if (!found) array_push(_arr, _value);
    return _arr;
}

function __item_effects_spec_from_raw(_raw){
    var s = string_lower(string(_raw));
    s = string_trim(s);
    s = string_replace_all(s, "_", "-");
    s = string_replace_all(s, " ", "-");
    if (string_length(s) == 0) return undefined;
    if (s == "a" || s == "an" || s == "any") return undefined;
    if (s == "freezing" || s == "frozen") s = "freeze";
    if (s == "burned") s = "burn";
    if (s == "paralyzed") s = "paralysis";
    if (s == "sleeping" || s == "drowsy") s = "sleep";
    if (s == "confused") s = "confusion";
    if (s == "infatuated" || s == "attract") s = "infatuation";
    if (s == "bad-poison") s = "toxic";
    var ids = [];
    var record = s;
    switch(s){
        case "poison":
        case "toxic":
            record = "poison";
            ids = ["poison","toxic"];
            break;
        case "burn":
            ids = ["burn"];
            break;
        case "freeze":
            ids = ["freeze"];
            break;
        case "paralysis":
        case "paralyze":
            record = "paralysis";
            ids = ["paralysis","paralyze"];
            break;
        case "sleep":
            ids = ["sleep","nightmare","yawn"];
            break;
        case "confusion":
            ids = ["confusion"];
            break;
        case "infatuation":
            ids = ["infatuation"];
            break;
        case "trap":
            ids = ["trap"];
            break;
        default:
            ids = [s];
            break;
    }
    return { record:record, ids:ids };
}

function __item_effects_merge_spec(_specs, _spec){
    if (!is_array(_specs) || !is_struct(_spec)) return;
    var idx = -1;
    for (var i = 0; i < array_length(_specs); ++i){
        var cur = _specs[i];
        if (!is_struct(cur) || !variable_struct_exists(cur, "record")) continue;
        if (cur.record == _spec.record){ idx = i; break; }
    }
    if (idx < 0){
        array_push(_specs, _spec);
        return;
    }
    var existing = _specs[idx];
    var combined = (is_struct(existing) && variable_struct_exists(existing, "ids") && is_array(existing.ids)) ? existing.ids : [];
    for (var j = 0; j < array_length(_spec.ids); ++j){
        var status_id = _spec.ids[j];
        var seen = false;
        for (var k = 0; k < array_length(combined); ++k){ if (combined[k] == status_id){ seen = true; break; } }
        if (!seen) array_push(combined, status_id);
    }
    existing.ids = combined;
    existing.record = _spec.record;
    _specs[idx] = existing;
}

function __item_effects_normalize_status_specs(_raw){
    var specs = [];
    if (is_array(_raw)){
        for (var i = 0; i < array_length(_raw); ++i){
            var spec = __item_effects_spec_from_raw(_raw[i]);
            if (is_struct(spec)) __item_effects_merge_spec(specs, spec);
        }
    } else if (!is_undefined(_raw)){
        var spec_single = __item_effects_spec_from_raw(_raw);
        if (is_struct(spec_single)) __item_effects_merge_spec(specs, spec_single);
    }
    return specs;
}

function __item_effects_specs_for_all(){
    var base = ["poison","toxic","burn","freeze","paralysis","sleep","confusion","infatuation","trap"];
    var specs = [];
    for (var i = 0; i < array_length(base); ++i){
        var spec = __item_effects_spec_from_raw(base[i]);
        if (is_struct(spec)) __item_effects_merge_spec(specs, spec);
    }
    return specs;
}

function __item_effects_status_display(_record){
    var s = string(_record);
    if (string_length(s) == 0) return "status";
    s = string_replace_all(s, "-", " ");
    s = string_lower(s);
    var first = string_copy(s, 1, 1);
    var rest = (string_length(s) > 1) ? string_copy(s, 2, string_length(s) - 1) : "";
    return string_upper(first) + rest;
}

function __item_effects_target_name(_actor, _mon){
    var _target = is_struct(_mon) ? _mon : _actor;
    var _name = "The Pokemon";
    try {
        if (is_struct(_target) && !is_undefined(mon_display_name)) _name = string(mon_display_name(_target));
        else if (is_struct(_target) && variable_struct_exists(_target, "name") && string_length(string(_target.name)) > 0) _name = string(_target.name);
        else if (is_struct(_actor) && variable_struct_exists(_actor, "name") && string_length(string(_actor.name)) > 0) _name = string(_actor.name);
    } catch (e_item_name) {
        _name = "The Pokemon";
    }
    return _name;
}

function __item_effects_battle_name(_name){
    var _s = string(_name);
    if (string_length(_s) <= 0) _s = "The Pokemon";
    return string_upper(_s);
}

function __item_effects_battle_possessive(_name){
    var _s = __item_effects_battle_name(_name);
    var _last = string_lower(string_copy(_s, string_length(_s), 1));
    return _s + ((_last == "s") ? "'" : "'s");
}

function __item_effects_status_recovery_message(_target_name, _record){
    var _status = string_lower(string(_record));
    switch (_status){
        case "poison": return __item_effects_battle_name(_target_name) + " was cured of its poisoning.";
        case "burn": return __item_effects_battle_name(_target_name) + "'s burn was healed.";
        case "freeze": return __item_effects_battle_name(_target_name) + " was defrosted.";
        case "paralysis": return __item_effects_battle_name(_target_name) + " was cured of paralysis.";
        case "sleep": return __item_effects_battle_name(_target_name) + " woke up.";
        case "confusion": return __item_effects_battle_name(_target_name) + " snapped out of confusion.";
        case "infatuation": return __item_effects_battle_name(_target_name) + " got over its infatuation.";
    }
    return __item_effects_battle_name(_target_name) + " became healthy.";
}

function __item_effects_possessive(_name){
    var _s = string(_name);
    if (string_length(_s) <= 0) return "The Pokemon's";
    var _last = string_lower(string_copy(_s, string_length(_s), 1));
    return _s + ((_last == "s") ? "'" : "'s");
}

function __item_effects_collect_targets(_actor, _mon){
    var targets = [];
    if (is_struct(_actor)) __item_effects_push_unique(targets, _actor);
    if (is_struct(_actor) && variable_struct_exists(_actor, "mon") && is_struct(_actor.mon)) __item_effects_push_unique(targets, _actor.mon);
    if (is_struct(_mon)){
        var add = true;
        for (var i = 0; i < array_length(targets); ++i){ if (targets[i] == _mon){ add = false; break; } }
        if (add) array_push(targets, _mon);
    }
    return targets;
}

function __item_effects_apply_status_specs(_specs, _actor, _mon, _message_override, _suppress_individual, _target_name = "The Pokemon"){
    var result = { cleared:false, records:[], messages:[] };
    if (!is_array(_specs) || array_length(_specs) == 0) return result;
    var targets = __item_effects_collect_targets(_actor, _mon);
    for (var si = 0; si < array_length(_specs); ++si){
        var spec = _specs[si];
        if (!is_struct(spec) || !variable_struct_exists(spec, "ids")) continue;
        var ids = spec.ids;
        if (!is_array(ids) || array_length(ids) == 0) continue;
        var spec_cleared = false;
        for (var ti = 0; ti < array_length(targets); ++ti){
            var tgt = targets[ti];
            if (!is_struct(tgt)) continue;
            var cleared_target = false;
            for (var ii = 0; ii < array_length(ids); ++ii){
                var status_id = ids[ii];
                if (is_undefined(status_system_clear_status)) continue;
                try {
                    if (status_system_clear_status(tgt, status_id)){
                        cleared_target = true;
                    }
                } catch (e_ss) {}
            }
            if (cleared_target){
                if (variable_struct_exists(tgt, "status")) variable_struct_set(tgt, "status", 0);
                if (variable_struct_exists(tgt, "status_id")) variable_struct_set(tgt, "status_id", 0);
                spec_cleared = true;
            }
            if (!cleared_target){
                var legacy_cleared = false;
                if (variable_struct_exists(tgt, "status")){
                    var st_val = variable_struct_get(tgt, "status");
                    if (is_real(st_val) && st_val != 0){
                        variable_struct_set(tgt, "status", 0);
                        legacy_cleared = true;
                    }
                }
                if (variable_struct_exists(tgt, "status_id")){
                    var sid_val = variable_struct_get(tgt, "status_id");
                    if ((is_real(sid_val) && sid_val != 0) || (is_string(sid_val) && string_length(sid_val) > 0)){
                        variable_struct_set(tgt, "status_id", 0);
                        legacy_cleared = true;
                    }
                }
                if (legacy_cleared) spec_cleared = true;
            }
        }
        if (spec_cleared){
            result.cleared = true;
            result.records = __item_effects_push_unique(result.records, spec.record);
            if (!_suppress_individual){
                array_push(result.messages, __item_effects_status_recovery_message(_target_name, spec.record));
            }
        }
    }
    if (result.cleared && is_string(_message_override) && string_length(_message_override) > 0){
        array_push(result.messages, _message_override);
    }
    return result;
}

function __item_effects_move_name(_mid, _slot_index){
    if (is_undefined(_mid) || !is_real(_mid) || _mid <= 0){
        return "move slot " + string((_slot_index >= 0) ? (_slot_index + 1) : 1);
    }
    if (!is_undefined(scr_move_name_by_id)){
        try {
            var nm = scr_move_name_by_id(_mid);
            if (is_string(nm) && string_length(nm) > 0) return nm;
        } catch (e_mn) {}
    }
    return "move";
}

function __item_effects_move_pp_cap(_mid, _current){
    var cap = -1;
    if (!is_undefined(scr_move_pp_by_id)){
        try {
            cap = scr_move_pp_by_id(_mid);
        } catch (e_pp) { cap = -1; }
    }
    if (!is_real(cap) || cap <= 0){
        cap = (is_real(_current) && _current > 0) ? max(1, _current) : 10;
    }
    return max(0, cap);
}

function __item_effects_restore_pp_on_target(_target, _scope, _amount, _full, _sync_mon){
    var result = { restored:false, total:0, messages:[] };
    if (!is_struct(_target)) return result;
    var target_pp = undefined;
    var pp_source_self = false;
    if (variable_struct_exists(_target, "pps") && is_array(_target.pps)){ target_pp = _target.pps; pp_source_self = true; }
    if (!is_array(target_pp) && variable_struct_exists(_target, "mon") && is_struct(_target.mon) && variable_struct_exists(_target.mon, "pps") && is_array(_target.mon.pps)){
        target_pp = _target.mon.pps;
    }
    if (!is_array(target_pp) || array_length(target_pp) == 0) return result;
    var target_moves = undefined;
    if (variable_struct_exists(_target, "moves") && is_array(_target.moves)) target_moves = _target.moves;
    if (!is_array(target_moves) && variable_struct_exists(_target, "mon") && is_struct(_target.mon) && variable_struct_exists(_target.mon, "moves") && is_array(_target.mon.moves)) target_moves = _target.mon.moves;
    var len = array_length(target_pp);
    var scope_all = (_scope == "all");
    var total_added = 0;
    var restored_slots = [];
    if (scope_all){
        for (var i = 0; i < len; ++i){
            var cur = (is_real(target_pp[i]) ? target_pp[i] : 0);
            var mid = (is_array(target_moves) && i < array_length(target_moves)) ? target_moves[i] : -1;
            var cap = __item_effects_move_pp_cap(mid, cur);
            var missing = max(0, cap - cur);
            var add = 0;
            if (_full) add = missing;
            else add = min(_amount, missing);
            if (add > 0){
                cur = min(cap, cur + add);
                target_pp[i] = cur;
                total_added += add;
                array_push(restored_slots, { slot:i, add:add, mid:mid });
            }
        }
        if (array_length(restored_slots) > 0){
            result.restored = true;
            result.total = total_added;
            if (_full) array_push(result.messages, "PP was restored for all moves.");
            else array_push(result.messages, "PP was restored by " + string(total_added) + " point" + ((total_added == 1) ? "." : "s."));
        }
    } else {
        var best_idx = -1;
        var best_missing = 0;
        var best_cap = 0;
        for (var j = 0; j < len; ++j){
            var cur_pp = (is_real(target_pp[j]) ? target_pp[j] : 0);
            var mid2 = (is_array(target_moves) && j < array_length(target_moves)) ? target_moves[j] : -1;
            var cap2 = __item_effects_move_pp_cap(mid2, cur_pp);
            var missing2 = max(0, cap2 - cur_pp);
            if (missing2 <= 0) continue;
            if (best_idx < 0 || missing2 > best_missing){
                best_idx = j;
                best_missing = missing2;
                best_cap = cap2;
            }
        }
        if (best_idx >= 0){
            var cur_best = (is_real(target_pp[best_idx]) ? target_pp[best_idx] : 0);
            var mid_best = (is_array(target_moves) && best_idx < array_length(target_moves)) ? target_moves[best_idx] : -1;
            var add_best = _full ? best_missing : min(_amount, best_missing);
            if (add_best > 0){
                target_pp[best_idx] = min(best_cap, cur_best + add_best);
                result.restored = true;
                result.total = add_best;
                var move_label = __item_effects_move_name(mid_best, best_idx);
                if (_full) array_push(result.messages, move_label + "'s PP was restored.");
                else array_push(result.messages, move_label + "'s PP was restored by " + string(add_best) + " point" + ((add_best == 1) ? "." : "s."));
            }
        }
    }
    if (result.restored){
        if (pp_source_self) variable_struct_set(_target, "pps", target_pp);
        if (_sync_mon && variable_struct_exists(_target, "mon") && is_struct(_target.mon)){
            var inner = _target.mon;
            variable_struct_set(inner, "pps", target_pp);
            variable_struct_set(_target, "mon", inner);
        }
    }
    return result;
}

function __item_effects_restore_pp(_actor, _mon, _params){
    var result = { restored:false, total:0, messages:[] };
    var scope = "single";
    if (is_struct(_params) && variable_struct_exists(_params, "scope")) scope = string_lower(string(variable_struct_get(_params, "scope")));
    if (scope != "all") scope = "single";
    var amount = (is_struct(_params) && variable_struct_exists(_params, "amount") ? floor(variable_struct_get(_params, "amount")) : 0);
    var full = (is_struct(_params) && variable_struct_exists(_params, "full") && variable_struct_get(_params, "full"));
    if (!full && amount <= 0) return result;
    var actor_res = __item_effects_restore_pp_on_target(_actor, scope, amount, full, true);
    var actor_mon_ref = undefined;
    if (is_struct(_actor) && variable_struct_exists(_actor, "mon") && is_struct(_actor.mon)) actor_mon_ref = _actor.mon;
    if (actor_res.restored){
        result.restored = true;
        result.total += actor_res.total;
        for (var ai = 0; ai < array_length(actor_res.messages); ++ai) array_push(result.messages, actor_res.messages[ai]);
    }
    if (is_struct(_mon) && _mon != actor_mon_ref){
        var mon_res = __item_effects_restore_pp_on_target(_mon, scope, amount, full, false);
        if (mon_res.restored){
            result.restored = true;
            result.total += mon_res.total;
            for (var mi = 0; mi < array_length(mon_res.messages); ++mi) array_push(result.messages, mon_res.messages[mi]);
        }
    }
    return result;
}

function __item_effects_mon_maxhp(_mon){
    if (!is_struct(_mon)) return 1;
    if (variable_struct_exists(_mon, "hp_max") && is_real(_mon.hp_max)) return max(1, floor(_mon.hp_max));
    if (variable_struct_exists(_mon, "maxhp") && is_real(_mon.maxhp)) return max(1, floor(_mon.maxhp));
    if (variable_struct_exists(_mon, "hp") && is_real(_mon.hp)) return max(1, floor(_mon.hp));
    return 1;
}

function __item_effects_recalc_mon_stats(_mon){
    if (!is_struct(_mon) || is_undefined(scr_poke_stats) || is_undefined(scr_compute_stat)) return;
    var sid = -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(_mon.species_id)) sid = floor(_mon.species_id);
    else if (variable_struct_exists(_mon, "id") && is_real(_mon.id)) sid = floor(_mon.id);
    if (sid <= 0) return;
    var level = (variable_struct_exists(_mon, "level") && is_real(_mon.level)) ? floor(_mon.level) : 1;
    var st = scr_poke_stats(sid);
    if (!is_struct(st)) return;
    if (!variable_struct_exists(_mon, "iv") || !is_struct(_mon.iv)){
        if (!is_undefined(scr_init_mon_iv_ev)) scr_init_mon_iv_ev(_mon);
    }
    if (!variable_struct_exists(_mon, "ev") || !is_struct(_mon.ev)){
        if (!is_undefined(scr_init_mon_iv_ev)) scr_init_mon_iv_ev(_mon);
    }
    var iv = variable_struct_exists(_mon, "iv") && is_struct(_mon.iv) ? _mon.iv : {};
    var ev = variable_struct_exists(_mon, "ev") && is_struct(_mon.ev) ? _mon.ev : {};
    var old_max = __item_effects_mon_maxhp(_mon);
    var old_hp = __battle_hp_now(_mon);
    var hpv = scr_compute_stat(st.hp, variable_struct_exists(iv, "hp") ? iv.hp : 0, variable_struct_exists(ev, "hp") ? ev.hp : 0, level, true);
    var atkv = scr_compute_stat(st.atk, variable_struct_exists(iv, "atk") ? iv.atk : 0, variable_struct_exists(ev, "atk") ? ev.atk : 0, level, false);
    var defv = scr_compute_stat(st.def, variable_struct_exists(iv, "def") ? iv.def : 0, variable_struct_exists(ev, "def") ? ev.def : 0, level, false);
    var spav = scr_compute_stat(st.spa, variable_struct_exists(iv, "spa") ? iv.spa : 0, variable_struct_exists(ev, "spa") ? ev.spa : 0, level, false);
    var spdv = scr_compute_stat(st.spd, variable_struct_exists(iv, "spd") ? iv.spd : 0, variable_struct_exists(ev, "spd") ? ev.spd : 0, level, false);
    var spev = scr_compute_stat(st.spe, variable_struct_exists(iv, "spe") ? iv.spe : 0, variable_struct_exists(ev, "spe") ? ev.spe : 0, level, false);
    if (!is_undefined(scr_nature_multiplier)){
        var nat = variable_struct_exists(_mon, "nature") ? variable_struct_get(_mon, "nature") : "";
        atkv = max(1, floor(atkv * scr_nature_multiplier(nat, "atk")));
        defv = max(1, floor(defv * scr_nature_multiplier(nat, "def")));
        spav = max(1, floor(spav * scr_nature_multiplier(nat, "spa")));
        spdv = max(1, floor(spdv * scr_nature_multiplier(nat, "spd")));
        spev = max(1, floor(spev * scr_nature_multiplier(nat, "spe")));
    }
    if (variable_struct_exists(_mon, "stat_candy_bonus") && is_struct(_mon.stat_candy_bonus)){
        var cb = _mon.stat_candy_bonus;
        hpv += (variable_struct_exists(cb, "hp") && is_real(cb.hp)) ? floor(cb.hp) : 0;
        atkv += (variable_struct_exists(cb, "atk") && is_real(cb.atk)) ? floor(cb.atk) : 0;
        defv += (variable_struct_exists(cb, "def") && is_real(cb.def)) ? floor(cb.def) : 0;
        spav += (variable_struct_exists(cb, "spa") && is_real(cb.spa)) ? floor(cb.spa) : 0;
        spdv += (variable_struct_exists(cb, "spd") && is_real(cb.spd)) ? floor(cb.spd) : 0;
        spev += (variable_struct_exists(cb, "spe") && is_real(cb.spe)) ? floor(cb.spe) : 0;
    }
    _mon.hp_max = hpv;
    _mon.maxhp = hpv;
    _mon.atk = atkv;
    _mon.def = defv;
    _mon.spa = spav;
    _mon.spd = spdv;
    _mon.spe = spev;
    var delta = hpv - old_max;
    __battle_set_hp_now(_mon, clamp(old_hp + delta, 1, hpv));
}

function __item_effects_adjust_ev(_mon, _stat, _amount){
    if (!is_struct(_mon) || !is_string(_stat) || !is_real(_amount)) return 0;
    if (!variable_struct_exists(_mon, "ev") || !is_struct(_mon.ev)){
        if (!is_undefined(scr_init_mon_iv_ev)) scr_init_mon_iv_ev(_mon);
        if (!variable_struct_exists(_mon, "ev") || !is_struct(_mon.ev)) _mon.ev = { hp:0, atk:0, def:0, spa:0, spd:0, spe:0 };
    }
    if (!variable_struct_exists(_mon, "ev_total") || !is_real(_mon.ev_total)) _mon.ev_total = 0;
    var ev = _mon.ev;
    var cur = (variable_struct_exists(ev, _stat) && is_real(variable_struct_get(ev, _stat))) ? floor(variable_struct_get(ev, _stat)) : 0;
    var total = max(0, floor(_mon.ev_total));
    var changed = 0;
    if (_amount > 0){
        changed = min(floor(_amount), max(0, 252 - cur), max(0, 510 - total));
    } else if (_amount < 0){
        changed = -min(abs(floor(_amount)), max(0, cur));
    }
    if (changed == 0) return 0;
    variable_struct_set(ev, _stat, cur + changed);
    _mon.ev = ev;
    _mon.ev_total = clamp(total + changed, 0, 510);
    __item_effects_recalc_mon_stats(_mon);
    return changed;
}

function __item_effects_reset_evs(_mon){
    if (!is_struct(_mon)) return false;
    var had = false;
    if (variable_struct_exists(_mon, "ev") && is_struct(_mon.ev)){
        var ev = _mon.ev;
        var keys = ["hp","atk","def","spa","spd","spe"];
        for (var i = 0; i < array_length(keys); ++i){
            var k = keys[i];
            if (variable_struct_exists(ev, k) && is_real(variable_struct_get(ev, k)) && variable_struct_get(ev, k) > 0) had = true;
            variable_struct_set(ev, k, 0);
        }
        _mon.ev = ev;
    } else {
        _mon.ev = { hp:0, atk:0, def:0, spa:0, spd:0, spe:0 };
    }
    _mon.ev_total = 0;
    __item_effects_recalc_mon_stats(_mon);
    return had;
}

function __item_effects_change_ability(_mon, _mode){
    if (!is_struct(_mon) || is_undefined(scr_poke_abilities_by_id)) return false;
    var sid = -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(_mon.species_id)) sid = floor(_mon.species_id);
    else if (variable_struct_exists(_mon, "id") && is_real(_mon.id)) sid = floor(_mon.id);
    else if (variable_struct_exists(_mon, "species") && is_real(_mon.species)) sid = floor(_mon.species);
    if (sid <= 0) return false;
    var abilities = scr_poke_abilities_by_id(sid);
    if (!is_array(abilities) || array_length(abilities) <= 0) return false;

    var unique = [];
    for (var i = 0; i < array_length(abilities); ++i){
        var aid = abilities[i];
        if (!is_real(aid) || aid <= 0) continue;
        var exists = false;
        for (var j = 0; j < array_length(unique); ++j){ if (unique[j] == aid){ exists = true; break; } }
        if (!exists) array_push(unique, aid);
    }
    if (array_length(unique) <= 0) return false;

    var current = (variable_struct_exists(_mon, "ability_id") && is_real(_mon.ability_id)) ? floor(_mon.ability_id) : 0;
    var target = current;
    var mode = string_lower(string(_mode));
    if (mode == "hidden"){
        target = unique[array_length(unique) - 1];
    } else {
        var regular_count = min(2, array_length(unique));
        if (regular_count <= 1) return false;
        target = unique[0];
        if (current == unique[0]) target = unique[1];
    }
    if (!is_real(target) || target <= 0 || target == current) return false;
    _mon.ability_id = target;
    if (!is_undefined(scr_ability_name_by_id)) _mon.ability = scr_ability_name_by_id(target);
    return true;
}

function __item_effects_adjust_stat_candy(_mon, _stat, _amount){
    if (!is_struct(_mon) || !is_string(_stat) || !is_real(_amount) || _amount <= 0) return 0;
    if (!variable_struct_exists(_mon, "stat_candy_bonus") || !is_struct(_mon.stat_candy_bonus)){
        _mon.stat_candy_bonus = { hp:0, atk:0, def:0, spa:0, spd:0, spe:0 };
    }
    var bonus = _mon.stat_candy_bonus;
    var cur = (variable_struct_exists(bonus, _stat) && is_real(variable_struct_get(bonus, _stat))) ? floor(variable_struct_get(bonus, _stat)) : 0;
    var add = max(1, floor(_amount));
    variable_struct_set(bonus, _stat, cur + add);
    _mon.stat_candy_bonus = bonus;
    __item_effects_recalc_mon_stats(_mon);
    return add;
}

function __item_effects_species_identifier(_mon){
    if (!is_struct(_mon)) return "";
    var sid = -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(_mon.species_id)) sid = floor(_mon.species_id);
    else if (variable_struct_exists(_mon, "id") && is_real(_mon.id)) sid = floor(_mon.id);
    else if (variable_struct_exists(_mon, "species") && is_real(_mon.species)) sid = floor(_mon.species);
    if (sid > 0 && variable_global_exists("_pokemon") && is_array(global._pokemon) && sid < array_length(global._pokemon)){
        var rec = global._pokemon[sid];
        if (is_struct(rec) && variable_struct_exists(rec, "identifier")) return string_lower(string(variable_struct_get(rec, "identifier")));
    }
    if (variable_struct_exists(_mon, "species_identifier")) return string_lower(string(variable_struct_get(_mon, "species_identifier")));
    if (variable_struct_exists(_mon, "identifier")) return string_lower(string(variable_struct_get(_mon, "identifier")));
    return "";
}

function __item_effects_apply_exp_gain(_mon, _amount){
    if (!is_struct(_mon) || !is_real(_amount) || _amount <= 0) return 0;
    if (!variable_struct_exists(_mon, "level") || !is_real(_mon.level)) _mon.level = 1;
    if (_mon.level >= 100) return 0;
    if (!variable_struct_exists(_mon, "exp") || !is_real(_mon.exp)) _mon.exp = 0;
    _mon.exp += max(1, floor(_amount));
    var gained_levels = 0;
    while (gained_levels < 10 && _mon.level < 100){
        var next_exp = -1;
        var gid = -1;
        if (variable_struct_exists(_mon, "growth_id") && is_real(_mon.growth_id)) gid = _mon.growth_id;
        else if (variable_struct_exists(_mon, "growth") && is_real(_mon.growth)) gid = _mon.growth;
        else if (variable_struct_exists(_mon, "growth_rate_id") && is_real(_mon.growth_rate_id)) gid = _mon.growth_rate_id;
        if (gid >= 0 && !is_undefined(scr_get_exp_for_level)) next_exp = scr_get_exp_for_level(gid, _mon.level + 1);
        if (!is_real(next_exp) || next_exp <= 0) next_exp = max(20, (_mon.level + 1) * (_mon.level + 1) * 2);
        _mon.exp_next = next_exp;
        if (_mon.exp < next_exp) break;
        _mon.exp -= next_exp;
        _mon.level += 1;
        gained_levels += 1;
        __item_effects_recalc_mon_stats(_mon);
    }
    if (_mon.level >= 100) _mon.exp_next = $1e12;
    return gained_levels;
}

function __item_effects_apply_pp_up(_mon, _amount){
    if (!is_struct(_mon) || !is_real(_amount) || _amount <= 0) return false;
    if (!variable_struct_exists(_mon, "moves") || !is_array(_mon.moves)) return false;
    if (!variable_struct_exists(_mon, "pp_ups") || !is_array(_mon.pp_ups)) _mon.pp_ups = [0,0,0,0];
    if (!variable_struct_exists(_mon, "pps") || !is_array(_mon.pps)) _mon.pps = [0,0,0,0];
    var best = -1;
    for (var i = 0; i < min(4, array_length(_mon.moves)); i++){
        var mid = _mon.moves[i];
        if (!is_real(mid) || mid <= 0) continue;
        var ups = (i < array_length(_mon.pp_ups) && is_real(_mon.pp_ups[i])) ? floor(_mon.pp_ups[i]) : 0;
        if (ups < 3){ best = i; break; }
    }
    if (best < 0) return false;
    while (array_length(_mon.pp_ups) < 4) array_push(_mon.pp_ups, 0);
    while (array_length(_mon.pps) < 4) array_push(_mon.pps, 0);
    var before = is_real(_mon.pp_ups[best]) ? floor(_mon.pp_ups[best]) : 0;
    var after = clamp(before + floor(_amount), 0, 3);
    if (after <= before) return false;
    _mon.pp_ups[best] = after;
    var mid2 = _mon.moves[best];
    var base_pp = __item_effects_move_pp_cap(mid2, 1);
    var add_pp = max(1, floor(base_pp * 0.2)) * (after - before);
    _mon.pps[best] = (is_real(_mon.pps[best]) ? _mon.pps[best] : 0) + add_pp;
    return true;
}

function __item_effects_find_item_evolution(_mon, _item_id){
    if (!is_struct(_mon) || !is_real(_item_id) || !variable_global_exists("_pokemon_evolutions") || !is_array(global._pokemon_evolutions)) return undefined;
    var sid = -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(_mon.species_id)) sid = floor(_mon.species_id);
    else if (variable_struct_exists(_mon, "id") && is_real(_mon.id)) sid = floor(_mon.id);
    if (sid <= 0) return undefined;
    for (var i = 0; i < array_length(global._pokemon_evolutions); i++){
        var row = global._pokemon_evolutions[i];
        if (!is_struct(row)) continue;
        if (!variable_struct_exists(row, "source_species_id") || row.source_species_id != sid) continue;
        if (!variable_struct_exists(row, "trigger_item_id") || row.trigger_item_id != _item_id) continue;
        if (variable_struct_exists(row, "gender_id") && is_real(row.gender_id) && row.gender_id > 0 && variable_struct_exists(_mon, "gender_id") && is_real(_mon.gender_id) && _mon.gender_id != row.gender_id) continue;
        return row;
    }
    return undefined;
}

function __item_effects_find_battle_context(_actor){
    var _ctx = { pid:-1, actor_index:-1 };
    if (!is_struct(_actor)) return _ctx;
    try {
        if (!is_undefined(__battle_resolve_pid_for_actor)){
            var _pid = __battle_resolve_pid_for_actor(_actor);
            if (is_real(_pid)) {
                _ctx.pid = floor(_pid);
                var _B = __battle_ensure_slot(_ctx.pid);
                if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                    var _actors = variable_struct_get(_B, "actor");
                    for (var _ai = 0; _ai < array_length(_actors); ++_ai){
                        if (_actors[_ai] == _actor){
                            _ctx.actor_index = _ai;
                            break;
                        }
                    }
                }
            }
        }
    } catch (e_item_battle_ctx) {}
    return _ctx;
}

function __item_effects_clear_held_item(_actor, _mon){
    var _cleared = false;
    if (is_struct(_actor)){
        if (variable_struct_exists(_actor, "held_item_id") && is_real(variable_struct_get(_actor, "held_item_id")) && variable_struct_get(_actor, "held_item_id") > 0) _cleared = true;
        variable_struct_set(_actor, "held_item_id", -1);
        variable_struct_set(_actor, "held_item", -1);
        variable_struct_set(_actor, "item", -1);
    }
    if (is_struct(_mon)){
        if (variable_struct_exists(_mon, "held_item_id") && is_real(variable_struct_get(_mon, "held_item_id")) && variable_struct_get(_mon, "held_item_id") > 0) _cleared = true;
        variable_struct_set(_mon, "held_item_id", -1);
        variable_struct_set(_mon, "held_item", -1);
        variable_struct_set(_mon, "item", -1);
    }
    return _cleared;
}

// Apply item effects resolved by data_load_item_effects_structs
// Returns a struct: { applied:bool, healed:amount, revived:bool, cured:[status], messages:[str], pp_restored:real }
function scr_apply_item_effects(_item_id, _mon, _actor){
    var out = { applied:false, healed:0, revived:false, cured:[], messages:[], pp_restored:0 };
    if (!is_real(_item_id) || _item_id <= 0) return out;

    // find effects from loader
    var effs = undefined;
    if (variable_global_exists("_item_effects") && is_array(global._item_effects) && _item_id < array_length(global._item_effects)) effs = global._item_effects[_item_id];
    if (!is_array(effs) || array_length(effs) == 0){
        // no structured effects parsed; fallback: attempt to parse numeric heal from prose (best-effort)
        if (variable_global_exists("_item_prose") && is_array(global._item_prose) && _item_id < array_length(global._item_prose)){
            var pp = global._item_prose[_item_id];
            if (is_struct(pp) && is_string(pp.short_effect) && string_length(pp.short_effect) > 0){
                var s = pp.short_effect;
                // try simple numeric extract: 'Restores N HP'
                var toks = string_split(s, " ");
                for (var ti = 0; ti < array_length(toks); ti++){
                    var t = string_replace_all(toks[ti], ",", "");
                    var digs = true;
                    for (var c = 1; c <= string_length(t); c++){ var ch = string_copy(t, c, 1); if (ch < "0" || ch > "9") { digs = false; break; } }
                    if (digs && string_length(t) > 0){ var n = __to_int_safe(t,0); if (n > 0){ effs = [ { type:"heal_flat", params:{ amount:n } } ]; break; } }
                }
            }
        }
    }
    try {
        if (!is_undefined(item_runtime_actions)){
            var _battle_actions = item_runtime_actions(_item_id, "battle_use");
            for (var _bai = 0; _bai < array_length(_battle_actions); ++_bai){
                var _ba = _battle_actions[_bai];
                if (!is_struct(_ba)) continue;
                var _kind = variable_struct_exists(_ba, "kind") ? string_lower(string(variable_struct_get(_ba, "kind"))) : "";
                if (_kind == "activate_ally_ability" || _kind == "drop_ally_held_item" || _kind == "activate_ally_held_item" || _kind == "reset_ally_stat_stages"){
                    if (!is_array(effs)) effs = [];
                    array_push(effs, { type:_kind, params:(variable_struct_exists(_ba, "data") ? variable_struct_get(_ba, "data") : {}) });
                }
            }
        }
    } catch (e_runtime_battle_use_item) {}
    if (!is_array(effs) || array_length(effs) == 0) return out;

    var total_healed = 0;
    var total_pp_restored = 0;
    var revived_any = false;
    var target_name = __item_effects_target_name(_actor, _mon);
    var target_possessive = __item_effects_possessive(target_name);
    var target_battle_name = __item_effects_battle_name(target_name);
    var target_battle_possessive = __item_effects_battle_possessive(target_name);
    var mon_is_actor_mon = (is_struct(_actor) && is_struct(_mon) && variable_struct_exists(_actor, "mon") && is_struct(_actor.mon) && _actor.mon == _mon);
    var mon_is_actor = (is_struct(_actor) && is_struct(_mon) && _actor == _mon);
    if (!is_undefined(__battle_ability_item_blocked_by_opponent) && __battle_ability_item_blocked_by_opponent((is_struct(_actor) ? _actor : _mon), _item_id)){
        array_push(out.messages, target_name + " couldn't eat the Berry!");
        return out;
    }
    var _ability_item_mult = 1.0;
    try {
        if (!is_undefined(__battle_ability_item_effect_multiplier)) _ability_item_mult = __battle_ability_item_effect_multiplier((is_struct(_actor) ? _actor : _mon), _item_id);
    } catch (e_item_mult) { _ability_item_mult = 1.0; }

    for (var ei = 0; ei < array_length(effs); ei++){
        var e = effs[ei];
        if (!is_struct(e) && !is_array(e)) continue;
        var t = (is_struct(e) && variable_struct_exists(e, "type") ? variable_struct_get(e, "type") : (is_array(e) && array_length(e) > 0 ? e[0] : undefined));
        var p = (is_struct(e) && variable_struct_exists(e, "params") ? variable_struct_get(e, "params") : {});

        if (t == "heal_flat"){
            var amt = (is_struct(p) && variable_struct_exists(p, "amount") ? floor(variable_struct_get(p, "amount")) : 0);
            if (is_real(_ability_item_mult) && _ability_item_mult != 1) amt = max(1, floor(amt * _ability_item_mult));
            if (amt > 0){
                var healed = 0;
                if (is_struct(_actor)){
                    var maxhp_actor = (variable_struct_exists(_actor, "hp_max") ? variable_struct_get(_actor, "hp_max") : (variable_struct_exists(_actor, "maxhp") ? variable_struct_get(_actor, "maxhp") : 100));
                    var before_actor = __battle_hp_now(_actor);
                    var add_actor = min(amt, max(0, maxhp_actor - before_actor));
                    if (add_actor > 0){
                        __battle_set_hp_now(_actor, min(maxhp_actor, before_actor + add_actor));
                        __battle_clear_fainted_if_healed(_actor);
                        healed += add_actor;
                        try { __battle_play_heal_once(snd_Heal); } catch (e_hflat_a) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] heal_flat actor failed: " + string(e_hflat_a)); }
                    }
                    if (variable_struct_exists(_actor, "mon") && is_struct(_actor.mon)){
                        var mon_ref = _actor.mon;
                        __battle_set_hp_now(mon_ref, min(maxhp_actor, __battle_hp_now(mon_ref) + add_actor));
                        __battle_clear_fainted_if_healed(mon_ref);
                    }
                }
                if (is_struct(_mon) && !mon_is_actor && !mon_is_actor_mon){
                    var maxhp_mon = 100;
                    if (variable_struct_exists(_mon, "hp_max")) maxhp_mon = variable_struct_get(_mon, "hp_max");
                    else if (variable_struct_exists(_mon, "maxhp")) maxhp_mon = variable_struct_get(_mon, "maxhp");
                    var before_mon = __battle_hp_now(_mon);
                    var add_mon = min(amt, max(0, maxhp_mon - before_mon));
                    if (add_mon > 0){
                        __battle_set_hp_now(_mon, min(maxhp_mon, before_mon + add_mon));
                        __battle_clear_fainted_if_healed(_mon);
                        healed += add_mon;
                        try { __battle_play_heal_once(snd_Heal); } catch (e_hflat_m) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] heal_flat mon failed: " + string(e_hflat_m)); }
                    }
                }
                if (healed > 0){
                    total_healed += healed;
                    array_push(out.messages, target_battle_possessive + " HP was restored.");
                }
            }
        } else if (t == "heal_full" || t == "full_restore"){
            var maxhp_common = 100;
            if (is_struct(_actor) && variable_struct_exists(_actor, "hp_max")) maxhp_common = variable_struct_get(_actor, "hp_max");
            else if (is_struct(_mon) && variable_struct_exists(_mon, "hp_max")) maxhp_common = variable_struct_get(_mon, "hp_max");
            var healed_full = 0;
            if (is_struct(_actor)){
                var before_full_actor = __battle_hp_now(_actor);
                var add_full_actor = max(0, maxhp_common - before_full_actor);
                if (add_full_actor > 0){
                    __battle_set_hp_now(_actor, min(maxhp_common, before_full_actor + add_full_actor));
                    __battle_clear_fainted_if_healed(_actor);
                    healed_full += add_full_actor;
                    try { __battle_play_heal_once(snd_Heal); } catch (e_hfull_a) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] heal_full actor failed: " + string(e_hfull_a)); }
                }
                if (variable_struct_exists(_actor, "mon") && is_struct(_actor.mon)){
                    var mon_ref_full = _actor.mon;
                    __battle_set_hp_now(mon_ref_full, min(maxhp_common, __battle_hp_now(mon_ref_full) + add_full_actor));
                    __battle_clear_fainted_if_healed(mon_ref_full);
                }
            }
            if (is_struct(_mon) && !mon_is_actor && !mon_is_actor_mon){
                var before_full_mon = __battle_hp_now(_mon);
                var add_full_mon = max(0, maxhp_common - before_full_mon);
                if (add_full_mon > 0){
                    __battle_set_hp_now(_mon, min(maxhp_common, before_full_mon + add_full_mon));
                    __battle_clear_fainted_if_healed(_mon);
                    healed_full += add_full_mon;
                    try { __battle_play_heal_once(snd_Heal); } catch (e_hfull_m) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] heal_full mon failed: " + string(e_hfull_m)); }
                }
            }
            if (healed_full > 0) array_push(out.messages, target_battle_possessive + " HP was restored.");
            total_healed += healed_full;

            if (t == "full_restore"){
                var specs_full = __item_effects_specs_for_all();
                var status_res_full = __item_effects_apply_status_specs(specs_full, _actor, _mon, target_battle_name + " became healthy.", true, target_name);
                if (status_res_full.cleared){
                    for (var crf = 0; crf < array_length(status_res_full.records); ++crf){
                        out.cured = __item_effects_push_unique(out.cured, status_res_full.records[crf]);
                    }
                    for (var mrf = 0; mrf < array_length(status_res_full.messages); ++mrf) array_push(out.messages, status_res_full.messages[mrf]);
                }
            }
        } else if (t == "revive" || t == "revive_half" || t == "revive_full" || t == "revive_all"){
            var mode = "half";
            if (t == "revive_full" || t == "revive_all" || (is_struct(p) && variable_struct_exists(p, "mode") && string_lower(string(variable_struct_get(p, "mode"))) == "full")) mode = "full";
            if (is_struct(_actor)){
                var current_actor = __battle_hp_now(_actor);
                var maxhp_actor_rev = (variable_struct_exists(_actor, "hp_max") ? variable_struct_get(_actor, "hp_max") : (variable_struct_exists(_actor, "maxhp") ? variable_struct_get(_actor, "maxhp") : 100));
                if (current_actor <= 0){
                    var newhp_actor = (mode == "full") ? maxhp_actor_rev : max(1, floor(maxhp_actor_rev / 2));
                    __battle_set_hp_now(_actor, newhp_actor);
                    __battle_clear_fainted_if_healed(_actor);
                    revived_any = true;
                    array_push(out.messages, target_battle_name + " recovered from fainting!");
                    try { __battle_play_heal_once(snd_Heal); } catch (e_rev_a) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] revive actor failed: " + string(e_rev_a)); }
                }
            }
            if (is_struct(_mon) && !mon_is_actor && !mon_is_actor_mon){
                var maxhp_mon_rev = (variable_struct_exists(_mon, "hp_max") ? variable_struct_get(_mon, "hp_max") : (variable_struct_exists(_mon, "maxhp") ? variable_struct_get(_mon, "maxhp") : 100));
                var current_mon = (variable_struct_exists(_mon, "hp") ? variable_struct_get(_mon, "hp") : (variable_struct_exists(_mon, "hp_now") ? variable_struct_get(_mon, "hp_now") : __battle_hp_now(_mon)));
                if (current_mon <= 0){
                    var newhp_mon = (mode == "full") ? maxhp_mon_rev : max(1, floor(maxhp_mon_rev / 2));
                    __battle_set_hp_now(_mon, newhp_mon);
                    __battle_clear_fainted_if_healed(_mon);
                    revived_any = true;
                    array_push(out.messages, target_battle_name + " recovered from fainting!");
                    try { __battle_play_heal_once(snd_Heal); } catch (e_rev_m) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] revive mon failed: " + string(e_rev_m)); }
                }
            }
        } else if (t == "cure_status"){
            var raw_status = undefined;
            if (is_struct(p) && variable_struct_exists(p, "status")) raw_status = variable_struct_get(p, "status");
            else if (is_struct(p) && variable_struct_exists(p, "status_name")) raw_status = variable_struct_get(p, "status_name");
            var specs_single = __item_effects_normalize_status_specs(raw_status);
            if (array_length(specs_single) == 0 && !is_undefined(raw_status)) specs_single = __item_effects_normalize_status_specs([raw_status]);
            var status_res_single = __item_effects_apply_status_specs(specs_single, _actor, _mon, undefined, false, target_name);
            if (status_res_single.cleared){
                for (var csr = 0; csr < array_length(status_res_single.records); ++csr){ out.cured = __item_effects_push_unique(out.cured, status_res_single.records[csr]); }
                for (var csm = 0; csm < array_length(status_res_single.messages); ++csm) array_push(out.messages, status_res_single.messages[csm]);
            }
        } else if (t == "cure_all"){
            var specs_all = __item_effects_specs_for_all();
            var status_res_all = __item_effects_apply_status_specs(specs_all, _actor, _mon, target_battle_name + " became healthy.", true, target_name);
            if (status_res_all.cleared){
                for (var car = 0; car < array_length(status_res_all.records); ++car){ out.cured = __item_effects_push_unique(out.cured, status_res_all.records[car]); }
                for (var cam = 0; cam < array_length(status_res_all.messages); ++cam) array_push(out.messages, status_res_all.messages[cam]);
            }
        } else if (t == "restore_pp"){
            var pp_res = __item_effects_restore_pp(_actor, _mon, p);
            if (pp_res.restored){
                total_pp_restored += pp_res.total;
                for (var rpm = 0; rpm < array_length(pp_res.messages); ++rpm) array_push(out.messages, pp_res.messages[rpm]);
            }
        } else if (t == "ev_raise" || t == "ev_drop"){
            var ev_stat = (is_struct(p) && variable_struct_exists(p, "stat")) ? string(variable_struct_get(p, "stat")) : "";
            var ev_amt = (is_struct(p) && variable_struct_exists(p, "amount") && is_real(variable_struct_get(p, "amount"))) ? floor(variable_struct_get(p, "amount")) : 10;
            if (t == "ev_drop") ev_amt = -abs(ev_amt);
            var ev_changed = __item_effects_adjust_ev(_mon, ev_stat, ev_amt);
            if (ev_changed != 0){
                out.applied = true;
                array_push(out.messages, target_battle_possessive + " base " + string_upper(ev_stat) + (ev_changed > 0 ? " rose." : " fell."));
            }
        } else if (t == "level_up"){
            if (is_struct(_mon) && (!variable_struct_exists(_mon, "level") || _mon.level < 100)){
                var cur_lv = (variable_struct_exists(_mon, "level") && is_real(_mon.level)) ? floor(_mon.level) : 1;
                _mon.level = min(100, cur_lv + 1);
                if (!is_undefined(scr_get_exp_for_level)){
                    var gid = variable_struct_exists(_mon, "growth_id") && is_real(_mon.growth_id) ? _mon.growth_id : -1;
                    var exp_cur = scr_get_exp_for_level(gid, _mon.level);
                    var exp_next = scr_get_exp_for_level(gid, min(100, _mon.level + 1));
                    if (is_real(exp_cur) && exp_cur >= 0) _mon.exp = exp_cur;
                    if (is_real(exp_next) && exp_next > 0) _mon.exp_next = exp_next;
                }
                __item_effects_recalc_mon_stats(_mon);
                out.applied = true;
                array_push(out.messages, target_battle_name + " grew to Lv. " + string(_mon.level) + "!");
            }
        } else if (t == "exp_gain"){
            var exp_amt = (is_struct(p) && variable_struct_exists(p, "amount") && is_real(variable_struct_get(p, "amount"))) ? floor(variable_struct_get(p, "amount")) : 0;
            if (exp_amt > 0 && is_struct(_mon) && (!variable_struct_exists(_mon, "level") || _mon.level < 100)){
                var levels_gained = __item_effects_apply_exp_gain(_mon, exp_amt);
                out.applied = true;
                if (levels_gained > 0) array_push(out.messages, target_battle_name + " grew to Lv. " + string(_mon.level) + "!");
                else array_push(out.messages, target_battle_name + " gained Exp. Points!");
            }
        } else if (t == "stat_candy"){
            var candy_stat = (is_struct(p) && variable_struct_exists(p, "stat")) ? string(variable_struct_get(p, "stat")) : "";
            var candy_amt = (is_struct(p) && variable_struct_exists(p, "amount") && is_real(variable_struct_get(p, "amount"))) ? floor(variable_struct_get(p, "amount")) : 1;
            if (__item_effects_adjust_stat_candy(_mon, candy_stat, candy_amt) > 0){
                out.applied = true;
                array_push(out.messages, target_battle_possessive + " " + string_upper(candy_stat) + " rose.");
            }
        } else if (t == "ev_reset"){
            if (__item_effects_reset_evs(_mon)){
                out.applied = true;
                array_push(out.messages, target_battle_possessive + " base points were reset.");
            }
        } else if (t == "ability_change"){
            var ability_mode = (is_struct(p) && variable_struct_exists(p, "mode")) ? string(variable_struct_get(p, "mode")) : "regular";
            if (__item_effects_change_ability(_mon, ability_mode)){
                out.applied = true;
                array_push(out.messages, target_battle_possessive + " Ability changed!");
            }
        } else if (t == "species_candy"){
            var candy_species = (is_struct(p) && variable_struct_exists(p, "species_identifier")) ? string_lower(string(variable_struct_get(p, "species_identifier"))) : "";
            var mon_species = __item_effects_species_identifier(_mon);
            if (string_length(candy_species) > 0 && candy_species == mon_species){
                var sc_amt = (is_struct(p) && variable_struct_exists(p, "amount") && is_real(variable_struct_get(p, "amount"))) ? floor(variable_struct_get(p, "amount")) : 1;
                var sc_total = 0;
                sc_total += __item_effects_adjust_stat_candy(_mon, "hp", sc_amt);
                sc_total += __item_effects_adjust_stat_candy(_mon, "atk", sc_amt);
                sc_total += __item_effects_adjust_stat_candy(_mon, "def", sc_amt);
                sc_total += __item_effects_adjust_stat_candy(_mon, "spa", sc_amt);
                sc_total += __item_effects_adjust_stat_candy(_mon, "spd", sc_amt);
                sc_total += __item_effects_adjust_stat_candy(_mon, "spe", sc_amt);
                if (sc_total > 0){
                    out.applied = true;
                    array_push(out.messages, target_battle_name + " became stronger!");
                }
            }
        } else if (t == "nature_mint"){
            var mint_nature = (is_struct(p) && variable_struct_exists(p, "nature")) ? string_lower(string(variable_struct_get(p, "nature"))) : "";
            if (is_struct(_mon) && string_length(mint_nature) > 0){
                var old_nature = (variable_struct_exists(_mon, "nature") && is_string(_mon.nature)) ? string_lower(_mon.nature) : "";
                if (old_nature != mint_nature){
                    _mon.nature = mint_nature;
                    __item_effects_recalc_mon_stats(_mon);
                    out.applied = true;
                    array_push(out.messages, target_battle_name + "'s stats changed!");
                }
            }
        } else if (t == "dynamax_level"){
            if (is_struct(_mon)){
                var dmax_amt = (is_struct(p) && variable_struct_exists(p, "amount") && is_real(variable_struct_get(p, "amount"))) ? floor(variable_struct_get(p, "amount")) : 1;
                var dmax_cap = (is_struct(p) && variable_struct_exists(p, "max") && is_real(variable_struct_get(p, "max"))) ? floor(variable_struct_get(p, "max")) : 10;
                var dmax_before = (variable_struct_exists(_mon, "dynamax_level") && is_real(_mon.dynamax_level)) ? floor(_mon.dynamax_level) : 0;
                var dmax_after = clamp(dmax_before + max(1, dmax_amt), 0, max(1, dmax_cap));
                if (dmax_after > dmax_before){
                    _mon.dynamax_level = dmax_after;
                    out.applied = true;
                    array_push(out.messages, target_battle_possessive + " Dynamax Level rose!");
                }
            }
        } else if (t == "tera_type_change"){
            var tera_type = (is_struct(p) && variable_struct_exists(p, "type")) ? string_lower(string(variable_struct_get(p, "type"))) : "";
            if (is_struct(_mon) && string_length(tera_type) > 0){
                var old_tera = (variable_struct_exists(_mon, "tera_type") && is_string(_mon.tera_type)) ? string_lower(_mon.tera_type) : "";
                if (old_tera != tera_type){
                    _mon.tera_type = tera_type;
                    out.applied = true;
                    array_push(out.messages, target_battle_possessive + " Tera Type changed to " + string_upper(tera_type) + "!");
                }
            }
        } else if (t == "pp_up"){
            var pp_amt = (is_struct(p) && variable_struct_exists(p, "amount") && is_real(variable_struct_get(p, "amount"))) ? floor(variable_struct_get(p, "amount")) : 1;
            if (__item_effects_apply_pp_up(_mon, pp_amt)){
                out.applied = true;
                array_push(out.messages, "The move's PP increased.");
            }
        } else if (t == "evolve_item"){
            var evo_row = __item_effects_find_item_evolution(_mon, _item_id);
            if (is_struct(evo_row)){
                var target_species = variable_struct_get(evo_row, "evolved_species_id");
                var did_evolve = false;
                if (!is_undefined(__evolution_apply_to_mon)) did_evolve = __evolution_apply_to_mon(_mon, target_species);
                if (did_evolve){
                    out.applied = true;
                    array_push(out.messages, target_name + " is evolving!");
                }
            }
        } else if (t == "battle_stage"){
            if (is_struct(_actor)){
                var bs_stat = (is_struct(p) && variable_struct_exists(p, "stat")) ? string(variable_struct_get(p, "stat")) : "";
                var bs_amt = (is_struct(p) && variable_struct_exists(p, "amount") && is_real(variable_struct_get(p, "amount"))) ? floor(variable_struct_get(p, "amount")) : 1;
                if (string_length(bs_stat) > 0){
                    var _stage_applied = false;
                    if (!is_undefined(__battle_ability_change_stage)) _stage_applied = __battle_ability_change_stage(_actor, bs_stat, bs_amt);
                    else {
                        if (!variable_struct_exists(_actor, "_stages") || !is_struct(_actor._stages)) _actor._stages = {};
                        var stg = _actor._stages;
                        var prev_stage = (variable_struct_exists(stg, bs_stat) && is_real(variable_struct_get(stg, bs_stat))) ? variable_struct_get(stg, bs_stat) : 0;
                        var next_stage = clamp(prev_stage + bs_amt, -6, 6);
                        if (next_stage != prev_stage){
                            variable_struct_set(stg, bs_stat, next_stage);
                            _actor._stages = stg;
                            _stage_applied = true;
                        }
                    }
                    if (_stage_applied){
                        out.applied = true;
                        array_push(out.messages, target_battle_possessive + " " + string_upper(bs_stat) + " rose!");
                    }
                }
            }
        } else if (t == "dire_hit"){
            if (is_struct(_actor)){
                var crit_add = (is_struct(p) && variable_struct_exists(p, "stages") && is_real(variable_struct_get(p, "stages"))) ? floor(variable_struct_get(p, "stages")) : 1;
                var prev_crit = (variable_struct_exists(_actor, "_focus_energy_level") && is_real(_actor._focus_energy_level)) ? floor(_actor._focus_energy_level) : 0;
                _actor._focus_energy_level = clamp(prev_crit + crit_add, 0, 3);
                out.applied = true;
                array_push(out.messages, target_battle_name + " is getting pumped!");
            }
        } else if (t == "guard_spec"){
            if (is_struct(_actor)){
                var turns = (is_struct(p) && variable_struct_exists(p, "turns") && is_real(variable_struct_get(p, "turns"))) ? floor(variable_struct_get(p, "turns")) : 5;
                _actor._guard_spec_turns = max(turns, 1);
                out.applied = true;
                array_push(out.messages, target_battle_name + " is protected from stat reductions!");
            }
        } else if (t == "activate_ally_ability"){
            var _ctx_ability = __item_effects_find_battle_context(_actor);
            if (is_real(_ctx_ability.pid) && _ctx_ability.pid >= 0 && is_real(_ctx_ability.actor_index) && _ctx_ability.actor_index >= 0 && !is_undefined(__battle_apply_entry_abilities)){
                try {
                    __battle_apply_entry_abilities(_ctx_ability.pid, _ctx_ability.actor_index);
                    out.applied = true;
                    array_push(out.messages, target_battle_possessive + " Ability was activated!");
                } catch (e_item_ability_urge) {}
            }
        } else if (t == "drop_ally_held_item"){
            if (__item_effects_clear_held_item(_actor, _mon)){
                out.applied = true;
                array_push(out.messages, target_battle_name + " dropped its held item!");
            }
        } else if (t == "activate_ally_held_item"){
            var _ctx_item_urge = __item_effects_find_battle_context(_actor);
            if (is_real(_ctx_item_urge.pid) && _ctx_item_urge.pid >= 0 && is_real(_ctx_item_urge.actor_index) && _ctx_item_urge.actor_index >= 0 && !is_undefined(__battle_try_auto_use_held_berry)){
                if (__battle_try_auto_use_held_berry(_ctx_item_urge.pid, _ctx_item_urge.actor_index, _actor, undefined, undefined, undefined, 1.0, "item_urge")){
                    out.applied = true;
                    array_push(out.messages, target_battle_name + " used its held item!");
                }
            }
        } else if (t == "reset_ally_stat_stages"){
            if (is_struct(_actor)){
                variable_struct_set(_actor, "_stages", {});
                if (is_struct(_mon)) variable_struct_set(_mon, "_stages", {});
                out.applied = true;
                array_push(out.messages, target_battle_possessive + " stat changes were reset!");
            }
        }
    }

    if (total_healed > 0){ out.applied = true; out.healed += total_healed; }
    if (revived_any){ out.applied = true; out.revived = true; }
    if (array_length(out.cured) > 0) out.applied = true;
    if (total_pp_restored > 0){ out.applied = true; out.pp_restored += total_pp_restored; }
    if (out.applied && !is_undefined(__battle_apply_after_item_consumed_ability)){
        try { __battle_apply_after_item_consumed_ability((is_struct(_actor) ? _actor : _mon), _item_id); } catch (e_after_item_ability) {}
    }

    return out;
}
