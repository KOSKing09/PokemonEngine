// Jaw Lock helpers extracted from battle_system.gml to keep the main script lean.

if (is_undefined(__battle_jaw_lock_release)){
    function __battle_jaw_lock_release(_actor){
        if (!is_struct(_actor)) return false;
        var partner = undefined;
        if (variable_struct_exists(_actor, "_jaw_lock_partner")) partner = variable_struct_get(_actor, "_jaw_lock_partner");
        try { variable_struct_set(_actor, "_jaw_lock_partner", undefined); } catch (e_clr1) {}
        try { variable_struct_set(_actor, "_jaw_lock_active", false); } catch (e_clr2) {}
        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
            var inner = variable_struct_get(_actor, "mon");
            try { variable_struct_set(inner, "_jaw_lock_partner", undefined); } catch (e_cmi1) {}
            try { variable_struct_set(inner, "_jaw_lock_active", false); } catch (e_cmi2) {}
        }
        if (is_struct(partner)){
            try {
                if (variable_struct_exists(partner, "_jaw_lock_partner") && variable_struct_get(partner, "_jaw_lock_partner") == _actor) variable_struct_set(partner, "_jaw_lock_partner", undefined);
                if (variable_struct_exists(partner, "_jaw_lock_active")) variable_struct_set(partner, "_jaw_lock_active", false);
                if (variable_struct_exists(partner, "mon") && is_struct(variable_struct_get(partner, "mon"))){
                    var inner2 = variable_struct_get(partner, "mon");
                    if (variable_struct_exists(inner2, "_jaw_lock_partner") && variable_struct_get(inner2, "_jaw_lock_partner") == _actor) variable_struct_set(inner2, "_jaw_lock_partner", undefined);
                    if (variable_struct_exists(inner2, "_jaw_lock_active")) variable_struct_set(inner2, "_jaw_lock_active", false);
                }
            } catch (e_clrp) {}
        }
        return true;
    }
    try { variable_global_set("__battle_jaw_lock_release", __battle_jaw_lock_release); } catch (e_set_jaw_release) { global.__battle_jaw_lock_release = __battle_jaw_lock_release; }
}

if (is_undefined(__battle_jaw_lock_bind)){
    function __battle_jaw_lock_bind(_pid, _attacker, _defender){
        if (!is_struct(_attacker) || !is_struct(_defender)) return false;
        __battle_jaw_lock_release(_attacker);
        __battle_jaw_lock_release(_defender);
        try { variable_struct_set(_attacker, "_jaw_lock_partner", _defender); } catch (e1) {}
        try { variable_struct_set(_attacker, "_jaw_lock_active", true); } catch (e2) {}
        try { variable_struct_set(_defender, "_jaw_lock_partner", _attacker); } catch (e3) {}
        try { variable_struct_set(_defender, "_jaw_lock_active", true); } catch (e4) {}
        if (variable_struct_exists(_attacker, "mon") && is_struct(variable_struct_get(_attacker, "mon"))){
            var _innerA = variable_struct_get(_attacker, "mon");
            try { variable_struct_set(_innerA, "_jaw_lock_partner", (variable_struct_exists(_defender, "mon") && is_struct(variable_struct_get(_defender, "mon"))) ? variable_struct_get(_defender, "mon") : _defender); } catch (e5) {}
            try { variable_struct_set(_innerA, "_jaw_lock_active", true); } catch (e6) {}
        }
        if (variable_struct_exists(_defender, "mon") && is_struct(variable_struct_get(_defender, "mon"))){
            var _innerD = variable_struct_get(_defender, "mon");
            try { variable_struct_set(_innerD, "_jaw_lock_partner", (variable_struct_exists(_attacker, "mon") && is_struct(variable_struct_get(_attacker, "mon"))) ? variable_struct_get(_attacker, "mon") : _attacker); } catch (e7) {}
            try { variable_struct_set(_innerD, "_jaw_lock_active", true); } catch (e8) {}
        }
        try {
            var _Bjl = __battle_ensure_slot(_pid);
            if (is_struct(_Bjl)){
                if (!variable_struct_exists(_Bjl, "_jaw_lock_pairs") || !is_array(variable_struct_get(_Bjl, "_jaw_lock_pairs"))){
                    variable_struct_set(_Bjl, "_jaw_lock_pairs", []);
                }
                var arr = variable_struct_get(_Bjl, "_jaw_lock_pairs");
                var found = false;
                for (var j = 0; j < array_length(arr); ++j){
                    var pr = arr[j];
                    if (!is_struct(pr)) continue;
                    if ((variable_struct_exists(pr, "a") && variable_struct_get(pr, "a") == _attacker) || (variable_struct_exists(pr, "d") && variable_struct_get(pr, "d") == _attacker)){
                        arr[j] = { a: _attacker, d: _defender };
                        found = true;
                        break;
                    }
                }
                if (!found) array_push(arr, { a: _attacker, d: _defender });
                variable_struct_set(_Bjl, "_jaw_lock_pairs", arr);
            }
        } catch (e_arr) {}
        return true;
    }
    try { variable_global_set("__battle_jaw_lock_bind", __battle_jaw_lock_bind); } catch (e_set_jaw_bind) { global.__battle_jaw_lock_bind = __battle_jaw_lock_bind; }
}

if (is_undefined(__battle_jaw_lock_is_blocked)){
    function __battle_jaw_lock_is_blocked(_actor){
        if (!is_struct(_actor)) return false;
        if (!variable_struct_exists(_actor, "_jaw_lock_active") || variable_struct_get(_actor, "_jaw_lock_active") != true) return false;
        var partner = undefined;
        if (variable_struct_exists(_actor, "_jaw_lock_partner")) partner = variable_struct_get(_actor, "_jaw_lock_partner");
        if (!is_struct(partner)){
            __battle_jaw_lock_release(_actor);
            return false;
        }
        var hp_partner = __battle_hp_now(partner);
        if (is_real(hp_partner) && hp_partner <= 0){
            __battle_jaw_lock_release(_actor);
            return false;
        }
        if (variable_struct_exists(partner, "_fainted") && variable_struct_get(partner, "_fainted") == true){
            __battle_jaw_lock_release(_actor);
            return false;
        }
        return true;
    }
    try { variable_global_set("__battle_jaw_lock_is_blocked", __battle_jaw_lock_is_blocked); } catch (e_set_jaw_block) { global.__battle_jaw_lock_is_blocked = __battle_jaw_lock_is_blocked; }
}
