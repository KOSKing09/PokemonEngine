// Apply item effects resolved by data_load_item_effects_structs
// Returns a struct: { applied:bool, healed:amount, revived:bool, cured:[status], messages:[str] }
function scr_apply_item_effects(_item_id, _mon, _actor){
    var out = { applied:false, healed:0, revived:false, cured:[], messages:[] };
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
    if (!is_array(effs) || array_length(effs) == 0) return out;

    // NOTE: _write_heal inlined below to avoid nested-function scoping issues

    // iterate effects
    var total_healed = 0;
    for (var ei = 0; ei < array_length(effs); ei++){
        var e = effs[ei];
        if (!is_struct(e) && !is_array(e)) continue;
        var t = (is_struct(e) && variable_struct_exists(e, "type") ? variable_struct_get(e, "type") : (is_array(e) && array_length(e) > 0 ? e[0] : undefined));
        var p = (is_struct(e) && variable_struct_exists(e, "params") ? variable_struct_get(e, "params") : {});

        if (t == "heal_flat"){
            var amt = (is_struct(p) && variable_struct_exists(p, "amount") ? floor(variable_struct_get(p, "amount")) : 0);
            if (amt > 0){
                var did = 0;
                // apply to actor if present
                    if (is_struct(_actor)){
                    var maxhp = (variable_struct_exists(_actor, "hp_max") ? variable_struct_get(_actor, "hp_max") : (variable_struct_exists(_actor, "maxhp") ? variable_struct_get(_actor, "maxhp") : 100));
                    var before = __battle_hp_now(_actor);
                    var actual = min(amt, max(0, maxhp - before));
                    if (actual > 0){
                        __battle_set_hp_now(_actor, min(maxhp, before + actual));
                        __battle_clear_fainted_if_healed(_actor);
                        did += actual;
                        // play heal SFX for items that actually heal (one-shot)
                        try { __battle_play_heal_once(snd_Heal); } catch (e_is) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] item heal SFX failed: " + string(e_is)); }
                    }
                    if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
                        var pm = variable_struct_get(_actor, "mon");
                        __battle_set_hp_now(pm, min(maxhp, __battle_hp_now(pm) + actual));
                        __battle_clear_fainted_if_healed(pm);
                    }
                }
                // apply to party mon as well
                if (is_struct(_mon)){
                    var mh = -1;
                    if (variable_struct_exists(_mon, "hp_max")) mh = variable_struct_get(_mon, "hp_max");
                    else if (variable_struct_exists(_mon, "maxhp")) mh = variable_struct_get(_mon, "maxhp");
                    else mh = 100;
                    var before_mon = __battle_hp_now(_mon);
                    var actual2 = min(amt, max(0, mh - before_mon));
                    if (actual2 > 0){
                        __battle_set_hp_now(_mon, min(mh, before_mon + actual2));
                        __battle_clear_fainted_if_healed(_mon);
                        did += actual2;
                        // play heal SFX for party mon heal (one-shot)
                        try { __battle_play_heal_once(snd_Heal); } catch (e_is2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] item heal SFX failed (party): " + string(e_is2)); }
                    }
                }
                total_healed += did; if (did>0) array_push(out.messages, "Healed " + string(did) + " HP");
            }
        } else if (t == "heal_full"){
            // compute maxhp and heal to full
            var mh = 100; if (is_struct(_actor) && variable_struct_exists(_actor, "hp_max")) mh = variable_struct_get(_actor, "hp_max");
            else if (is_struct(_mon) && variable_struct_exists(_mon, "hp_max")) mh = variable_struct_get(_mon, "hp_max");
            var didf = 0;
            // actor
            if (is_struct(_actor)){
                var before2 = __battle_hp_now(_actor);
                var add = max(0, mh - before2);
                if (add > 0){ __battle_set_hp_now(_actor, min(mh, before2 + add)); __battle_clear_fainted_if_healed(_actor); didf += add;
                    try { __battle_play_heal_once(snd_Heal); } catch (e_is3) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] full heal SFX failed: " + string(e_is3)); }
                }
                if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){ var pm3 = variable_struct_get(_actor, "mon"); __battle_set_hp_now(pm3, min(mh, __battle_hp_now(pm3) + add)); __battle_clear_fainted_if_healed(pm3); }
            }
            // party mon
            if (is_struct(_mon)){
                var curb = __battle_hp_now(_mon);
                var add2 = max(0, mh - curb);
                if (add2 > 0){ __battle_set_hp_now(_mon, min(mh, curb + add2)); __battle_clear_fainted_if_healed(_mon); didf += add2;
                    try { __battle_play_heal_once(snd_Heal); } catch (e_is4) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] full heal SFX failed (party): " + string(e_is4)); }
                }
            }
            if (didf > 0) array_push(out.messages, "Fully healed"); total_healed += didf;
        } else if (t == "revive" || t == "revive_half" || t == "revive_full"){
            // attempt revive: set hp to half or full if mon is fainted (hp==0)
            var mode = "half";
            if (t == "revive_full" || (is_struct(p) && variable_struct_exists(p, "mode") && string_lower(variable_struct_get(p, "mode")) == "full")) mode = "full";
            if (is_struct(_actor)){
                var cur = __battle_hp_now(_actor);
                var mh2 = (variable_struct_exists(_actor, "hp_max") ? variable_struct_get(_actor, "hp_max") : (variable_struct_exists(_actor, "maxhp") ? variable_struct_get(_actor, "maxhp") : 100));
                if (cur <= 0){ var newhp = (mode == "full" ? mh2 : max(1, floor(mh2/2))); __battle_set_hp_now(_actor, newhp); __battle_clear_fainted_if_healed(_actor);
                    out.revived = true; array_push(out.messages, "Revived");
                    // play heal SFX on revive (one-shot)
                    try { __battle_play_heal_once(snd_Heal); } catch (e_rev) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] revive SFX failed: " + string(e_rev)); }
                }
            }
            if (is_struct(_mon)){
                var mh3 = (variable_struct_exists(_mon, "hp_max") ? variable_struct_get(_mon, "hp_max") : (variable_struct_exists(_mon, "maxhp") ? variable_struct_get(_mon, "maxhp") : 100));
                var cur2 = (variable_struct_exists(_mon, "hp") ? variable_struct_get(_mon, "hp") : (variable_struct_exists(_mon, "hp_now") ? variable_struct_get(_mon, "hp_now") : 0));
                if (cur2 <= 0){ var new2 = (mode == "full" ? mh3 : max(1, floor(mh3/2))); __battle_set_hp_now(_mon, new2); __battle_clear_fainted_if_healed(_mon); out.revived = true; array_push(out.messages, "Revived");
                    try { __battle_play_heal_once(snd_Heal); } catch (e_rev2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[items][sound] revive SFX failed (party): " + string(e_rev2)); }
                }
            }
        } else if (t == "cure_status" || t == "cure_all"){
            // best-effort: clear common status fields if present
            var status = (is_struct(p) && variable_struct_exists(p, "status") ? variable_struct_get(p, "status") : (is_struct(p) && variable_struct_exists(p, "status_name") ? variable_struct_get(p, "status_name") : ""));
            if (is_struct(_actor) && variable_struct_exists(_actor, "status")){ variable_struct_set(_actor, "status", 0); array_push(out.cured, status); array_push(out.messages, "Cured status"); }
            if (is_struct(_mon) && variable_struct_exists(_mon, "status")){ variable_struct_set(_mon, "status", 0); array_push(out.cured, status); array_push(out.messages, "Cured status"); }
            // also try other common fields
            if (is_struct(_actor) && variable_struct_exists(_actor, "status_id")){ variable_struct_set(_actor, "status_id", 0); }
            if (is_struct(_mon) && variable_struct_exists(_mon, "status_id")){ variable_struct_set(_mon, "status_id", 0); }
        }
    }

    if (total_healed > 0) { out.applied = true; out.healed = total_healed; }
    if (out.revived) out.applied = true;
    if (array_length(out.cured) > 0) out.applied = true;

    return out;
}
