// [Battle] Stat Overlay System — Build v1.1 — Updated 2025-10-27
// Provides queue-driven overlays for stat stage changes (Emerald-style icons).
// Frame order: 0=mixed, 1=Atk, 2=Def, 3=Spe, 4=SpA, 5=SpD, 6=Acc, 7=Eva.

/// @func __battle_stat_overlay_normalize_key(_raw)
/// @desc Convert incoming stat identifiers to canonical battle stage keys.
/// @return Canonical key string or "" if unsupported.
function __battle_stat_overlay_normalize_key(_raw)
{
    var _txt = string_lower(string(_raw));
    switch (_txt)
    {
        case "atk":
        case "attack":
        case "att":
            return "atk";
        case "def":
        case "defense":
            return "def";
        case "spe":
        case "speed":
        case "spd+":
            return "spe";
        case "spa":
        case "spatk":
        case "sp-atk":
        case "sp_atk":
        case "specialattack":
            return "spa";
        case "spd":
        case "spdef":
        case "sp-def":
        case "sp_def":
        case "specialdefense":
            return "spd";
        case "accuracy":
        case "acc":
            return "accuracy";
        case "evasion":
        case "eva":
            return "evasion";
    }
    return "";
}

/// @func __battle_stat_overlay_frame_for_key(_key)
/// @desc Map canonical stat keys to sprite frame indices.
function __battle_stat_overlay_frame_for_key(_key)
{
    switch (string_lower(string(_key)))
    {
        case "atk": return 1;
        case "def": return 2;
        case "spe": return 3;
        case "spa": return 4;
        case "spd": return 5;
        case "accuracy": return 6;
        case "evasion": return 7;
    }
    return 0;
}

/// @func __battle_stat_overlay_resolve_changes(_stats_struct)
/// @desc Build a compact description of the stat changes for overlay usage.
/// @return Struct { frame:int, darken:bool, keys:array, deltas:struct }
function __battle_stat_overlay_resolve_changes(_stats_struct)
{
    if (is_undefined(_stats_struct)) return undefined;

    var _changes = {};
    var _any_down = false;

    if (is_struct(_stats_struct))
    {
        var _names = variable_struct_get_names(_stats_struct);
        for (var _i = 0; _i < array_length(_names); ++_i)
        {
            var _name = _names[_i];
            var _canon = __battle_stat_overlay_normalize_key(_name);
            if (string_length(_canon) <= 0) continue;
            var _val = variable_struct_get(_stats_struct, _name);
            if (!is_real(_val))
            {
                if (is_string(_val))
                {
                    var _maybe = real(_val);
                    if (is_real(_maybe)) _val = _maybe;
                }
            }
            if (!is_real(_val) || _val == 0) continue;
            variable_struct_set(_changes, _canon, _val);
            if (_val < 0) _any_down = true;
        }
    }
    else if (is_array(_stats_struct))
    {
        for (var _j = 0; _j < array_length(_stats_struct); ++_j)
        {
            var _entry = _stats_struct[_j];
            if (!is_struct(_entry)) continue;
            var _raw_key = undefined;
            if (variable_struct_exists(_entry, "key")) _raw_key = variable_struct_get(_entry, "key");
            else if (variable_struct_exists(_entry, "stat")) _raw_key = variable_struct_get(_entry, "stat");
            var _canon2 = __battle_stat_overlay_normalize_key(_raw_key);
            if (string_length(_canon2) <= 0) continue;
            var _delta = undefined;
            if (variable_struct_exists(_entry, "delta")) _delta = variable_struct_get(_entry, "delta");
            else if (variable_struct_exists(_entry, "value")) _delta = variable_struct_get(_entry, "value");
            else if (variable_struct_exists(_entry, "change")) _delta = variable_struct_get(_entry, "change");
            if (!is_real(_delta) || _delta == 0) continue;
            variable_struct_set(_changes, _canon2, _delta);
            if (_delta < 0) _any_down = true;
        }
    }

    var _keys = variable_struct_get_names(_changes);
    if (!is_array(_keys) || array_length(_keys) <= 0) return undefined;

    var _frame = 0;
    if (array_length(_keys) == 1) _frame = __battle_stat_overlay_frame_for_key(_keys[0]);

    return { frame: _frame, darken: _any_down, keys: _keys, deltas: _changes };
}

/// @func __battle_trigger_stat_overlay(_pid, _target, _stats_struct[, _fallback_index])
/// @desc Queue a stat overlay animation via the battle animation system.
function __battle_trigger_stat_overlay(_pid, _target, _stats_struct, _fallback_index)
{
    var _info = __battle_stat_overlay_resolve_changes(_stats_struct);
    if (!is_struct(_info)) return;

    var _pid_final = _pid;
    if (!is_real(_pid_final))
    {
        if (is_struct(_target) && !is_undefined(__battle_resolve_pid_for_actor))
        {
            _pid_final = __battle_resolve_pid_for_actor(_target);
        }
        if (!is_real(_pid_final)) _pid_final = 0;
    }

    var _idx = undefined;
    if (is_real(_target))
    {
        _idx = clamp(floor(_target), 0, 1);
    }
    else if (is_struct(_target))
    {
        if (variable_struct_exists(_target, "actor_index") && is_real(variable_struct_get(_target, "actor_index")))
        {
            _idx = clamp(floor(variable_struct_get(_target, "actor_index")), 0, 1);
        }
        else if (!is_undefined(__battle_actor_index_of))
        {
            _idx = __battle_actor_index_of(_target);
        }
    }
    if (!is_real(_idx) && is_real(_fallback_index)) _idx = clamp(floor(_fallback_index), 0, 1);
    if (!is_real(_idx)) _idx = 0;

    if (is_undefined(battle_anim_queue_enqueue)) return;

    var _spec = {
        type: "stat_overlay",
        channel: "overlay",
        target_index: _idx,
        frame: _info.frame,
        darken: _info.darken,
        duration: 480,
        stat_keys: _info.keys,
        stat_deltas: _info.deltas
    };

    battle_anim_queue_enqueue(_pid_final, _spec);
}

try { variable_global_set("__battle_trigger_stat_overlay", __battle_trigger_stat_overlay); }
catch (e_set_bso) { global.__battle_trigger_stat_overlay = __battle_trigger_stat_overlay; }
