// ============================================================================
// DataVerify.gml (v1.0)
// End-to-end verification + optional seeding of party demos
// Call data_verify_and_seed() once after data_load_all() + index_build_all()
// ============================================================================

globalvar DATA_STATUS;
if (!variable_global_exists("DATA_STATUS")) DATA_STATUS = { ok:false, steps:[], errors:[] };

/// data_verify_and_seed(debug_seed = true)
function data_verify_and_seed(_debug_seed){
    // reset status
    DATA_STATUS = { ok:false, steps:[], errors:[] };

    var _ok_all = true;

    // ---- check species map ----
    var _species_ok = (variable_global_exists("POKEMON_SPECIES") && ds_exists(POKEMON_SPECIES, ds_type_map));
    array_push(DATA_STATUS.steps, "POKEMON_SPECIES map " + string(_species_ok));
    if (!_species_ok){ _ok_all = false; array_push(DATA_STATUS.errors, "POKEMON_SPECIES missing or not a map"); }

    // ---- check moves map ----
    var _moves_ok = (variable_global_exists("POKEMON_MOVES") && ds_exists(POKEMON_MOVES, ds_type_map));
    array_push(DATA_STATUS.steps, "POKEMON_MOVES map " + string(_moves_ok));
    if (!_moves_ok){ _ok_all = false; array_push(DATA_STATUS.errors, "POKEMON_MOVES missing or not a map"); }

    // ---- check types map ----
    var _types_ok = (variable_global_exists("BATTLE_TYPES") && ds_exists(BATTLE_TYPES, ds_type_map));
    array_push(DATA_STATUS.steps, "BATTLE_TYPES map " + string(_types_ok));
    if (!_types_ok){ _ok_all = false; array_push(DATA_STATUS.errors, "BATTLE_TYPES missing or not a map"); }

    // ---- check type efficacy map ----
    var _eff_ok = (variable_global_exists("BATTLE_TYPE_EFFICACY") && ds_exists(BATTLE_TYPE_EFFICACY, ds_type_map));
    array_push(DATA_STATUS.steps, "BATTLE_TYPE_EFFICACY map " + string(_eff_ok));
    if (!_eff_ok){ _ok_all = false; array_push(DATA_STATUS.errors, "BATTLE_TYPE_EFFICACY missing or not a map"); }

    // ---- indices ----
    var _idx_species_ok = (variable_global_exists("POKEMON_ID_BY_NAME") && ds_exists(POKEMON_ID_BY_NAME, ds_type_map));
    var _idx_moves_ok   = (variable_global_exists("MOVE_ID_BY_NAME")    && ds_exists(MOVE_ID_BY_NAME, ds_type_map));
    var _idx_types_ok   = (variable_global_exists("TYPE_ID_BY_NAME")    && ds_exists(TYPE_ID_BY_NAME, ds_type_map));

    array_push(DATA_STATUS.steps, "POKEMON_ID_BY_NAME " + string(_idx_species_ok));
    array_push(DATA_STATUS.steps, "MOVE_ID_BY_NAME "    + string(_idx_moves_ok));
    array_push(DATA_STATUS.steps, "TYPE_ID_BY_NAME "    + string(_idx_types_ok));

    if (!_idx_species_ok){ _ok_all = false; array_push(DATA_STATUS.errors, "Index POKEMON_ID_BY_NAME missing"); }
    if (!_idx_moves_ok){   _ok_all = false; array_push(DATA_STATUS.errors, "Index MOVE_ID_BY_NAME missing"); }
    if (!_idx_types_ok){   _ok_all = false; array_push(DATA_STATUS.errors, "Index TYPE_ID_BY_NAME missing"); }

    // ---- quick functional probes (only if maps exist) ----
    if (_species_ok && _idx_species_ok){
        var _probe_sid = poke_id_by_name("Bulbasaur");
        array_push(DATA_STATUS.steps, "poke_id_by_name('Bulbasaur') = " + string(_probe_sid));
        if (_probe_sid < 0){ _ok_all = false; array_push(DATA_STATUS.errors, "Index probe failed: Bulbasaur not found"); }
    }
    if (_moves_ok && _idx_moves_ok){
        var _probe_mid = move_id_by_name("Tackle");
        array_push(DATA_STATUS.steps, "move_id_by_name('Tackle') = " + string(_probe_mid));
        if (_probe_mid < 0){ _ok_all = false; array_push(DATA_STATUS.errors, "Index probe failed: Tackle not found"); }
    }
    if (_types_ok && _eff_ok){
        var _probe_eff = type_effectiveness("Fire","Grass");
        array_push(DATA_STATUS.steps, "type_effectiveness(Fire->Grass) = " + string(_probe_eff));
        if (_probe_eff <= 0){ _ok_all = false; array_push(DATA_STATUS.errors, "Efficacy probe failed: Fire vs Grass"); }
    }

    // ---- optional demo seeding for party[0] so UI shows something ----
    if (_ok_all && _debug_seed){
        party_seed_demo(0);
        // (Uncomment for P2 demo)
        // party_seed_demo(1);
        array_push(DATA_STATUS.steps, "party_seed_demo(0) done");
    }

    DATA_STATUS.ok = _ok_all;
    return DATA_STATUS.ok;
}

/// debug_draw_data_status(x, y) — small overlay in GUI for sanity
function debug_draw_data_status(_x, _y){
    if (!variable_global_exists("DATA_STATUS")) return;
    var _sx = _x, _sy = _y;

    draw_set_color(DATA_STATUS.ok ? c_lime : c_red);
    draw_text(_sx, _sy, "DATA OK: " + string(DATA_STATUS.ok));
    _sy += 16;

    draw_set_color(c_white);
    for (var _i = 0; _i < array_length(DATA_STATUS.steps); _i++){
        draw_text(_sx, _sy, "- " + string(DATA_STATUS.steps[_i]));
        _sy += 14;
    }

    if (array_length(DATA_STATUS.errors) > 0){
        draw_set_color(c_yellow);
        draw_text(_sx, _sy, "Errors:");
        _sy += 16;
        draw_set_color(c_red);
        for (var _j = 0; _j < array_length(DATA_STATUS.errors); _j++){
            draw_text(_sx, _sy, "* " + string(DATA_STATUS.errors[_j]));
            _sy += 14;
        }
    }
}
