// [Battle] Stat Overlay System — Build v1.0 — Updated 2025-10-27
// Recreates Pokémon Emerald-style stat-change overlays using spr_stateffects.
// Frame order: 0=mixed, 1=Atk, 2=Def, 3=Spe, 4=SpA, 5=SpD, 6=Acc, 7=Eva.

/// @func __battle_trigger_stat_overlay(_ent, _stats_struct)
/// @desc Trigger a floating 32×32 additive overlay when stats change.
/// @param _ent            Battler struct or instance
/// @param _stats_struct   Struct or array listing which stats changed (+1/-1 values)

function __battle_trigger_stat_overlay(_ent, _stats_struct)
{
    if (is_undefined(_ent)) return;

    // Determine which stats were changed
    var _changedStats = [];
    var _keys = variable_struct_get_names(_stats_struct);
    for (var _i = 0; _i < array_length(_keys); _i++)
    {
        var _k = _keys[_i];
        if (_stats_struct[_k] != 0) array_push(_changedStats, _k);
    }

    // Choose correct frame
    var _frame = 0;
    if (array_length(_changedStats) == 1)
    {
        switch(_changedStats[0])
        {
            case "attack":    _frame = 1; break;
            case "defense":   _frame = 2; break;
            case "speed":     _frame = 3; break;
            case "spatk":     _frame = 4; break;
            case "spdef":     _frame = 5; break;
            case "accuracy":  _frame = 6; break;
            case "evasion":   _frame = 7; break;
        }
    }
    else
    {
        _frame = 0; // Mixed multi-stat
    }

    _ent.overlay_sprite  = spr_stateffects;
    _ent.overlay_frame   = _frame;
    _ent.overlay_timer   = 20;   // lifetime
    _ent.overlay_yoffset = 0;
    _ent.overlay_fade    = 1;
    _ent.overlay_darken  = false;

    // If any stat went down, darken overlay
    for (var _j = 0; _j < array_length(_changedStats); _j++)
    {
        if (_stats_struct[_changedStats[_j]] < 0)
        {
            _ent.overlay_darken = true;
            break;
        }
    }
}

/// Update snippet — call each Step or Update
/// Handles float-up motion and fade-out.
function __battle_stat_overlay_update(_ent)
{
    if (is_undefined(_ent.overlay_timer)) return;
    if (_ent.overlay_timer <= 0) return;

    _ent.overlay_timer--;
    _ent.overlay_yoffset = -lerp(0, 16, (20 - _ent.overlay_timer) / 20);
    _ent.overlay_fade = _ent.overlay_timer / 20;
}

/// Draw snippet — call inside battler draw function (after Pokémon sprite)
function __battle_stat_overlay_draw(_ent)
{
    if (is_undefined(_ent.overlay_timer)) return;
    if (_ent.overlay_timer <= 0) return;
    if (is_undefined(_ent.overlay_sprite)) return;

    gpu_set_blendmode(bm_add);

    var _col = c_white;
    if (_ent.overlay_darken) _col = make_color_rgb(96,96,96);

    draw_sprite_ext(
        _ent.overlay_sprite,
        _ent.overlay_frame,
        _ent.x,
        _ent.y + _ent.overlay_yoffset,
        1, 1, 0,
        _col,
        _ent.overlay_fade
    );

    gpu_set_blendmode(bm_normal);
}
