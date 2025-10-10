// [Pokémon Data]: PokemonDataLoaders_Debug — Build v1.1.0 — Updated 2025-10-08
// Purpose: Profile per-loader CSV ingestion times without modifying existing systems.
// v1.1.0:
//  - Adds item-related loaders to the profile pass (items, names, text, categories, machines, bag mapping).
//  - Adds orchestrator 'data_load_all_structs_ext' if present (runs after base orchestrator).
//  - Adds per-phase subtotal groups and a final sorted summary by duration.
//  - Safer file/dir creation (avoids invalid handles), clearer debug lines, zero-allocation push helper.
//  - Keeps: No function renames. Uses asset_get_index + script_execute (no function_exists).
//
// Behavior: Attempts to resolve common loader scripts via asset_get_index + script_execute.
//           Logs individual durations and totals to the output (show_debug_message) and
//           writes a CSV log to Documents/Pokemon Engine/logs/.
//
// Safety:   Adds NEW functions only. No renames, no deletions.
// Naming:   Local vars `_camelCase`; system fields `sys_*` / `engine_*`; avoid reserved names.
//
// How to use (example from oGame.Create):
//   var _metrics = data_load_profile_run();
//   // Inspect _metrics.sys_items: array of { label, ok, ms }
//   // Debug output prints each step and subtotal groups.
//
// Returned struct fields:
//   metrics.sys_total_ms       (real)
//   metrics.sys_items          (array of structs: { label, ok, ms })
//   metrics.sys_entries        (count of attempted targets)
//   metrics.sys_log_path       (CSV path written)
//   metrics.sys_sorted_indices (array of indices into sys_items sorted by descending ms)
//
// ------------------------------------------------------------
// INTERNAL CONSTANTS
#macro DLP_MAGIC          0xD1CEBEEF
#macro DLP_VERSION        110  // 1.1.0
#macro DLP_LOG_HEADER     "timestamp,label,ok,ms"
#macro DLP_DIR_LOGS_WIN   "\\Documents\\Pokemon Engine\\logs\\"
#macro DLP_DIR_LOGS_UNIX  "/Documents/Pokemon Engine/logs/"
#macro DLP_FILE_PREFIX    "load_profile_"

// ------------------------------------------------------------
// Public entry point
/// data_load_profile_run()
/// @return struct metrics
function data_load_profile_run() {    
    var _metrics = {
        sys_magic          : DLP_MAGIC,
        sys_version        : DLP_VERSION,
        sys_entries        : 0,
        sys_total_ms       : 0.0,
        sys_log_path       : "",
        sys_items          : [],
        sys_sorted_indices : []
    };

    var _logDir = __dlp_logs_dir();
    __dlp_ensure_dir(_logDir);
    var _logPath = __dlp_new_log_path(_logDir);
    _metrics.sys_log_path = _logPath;

    // Ensure header
    __dlp_write_line(_logPath, DLP_LOG_HEADER);

    // ---------------- Target sets (subtotals) ----------------
    // Base Pokémon data
    var _targets_base = [
        "data_load_pokemon_csv",
        "data_load_stats_csv",
        "data_load_type_eff_csv",
        "data_load_species_evo_csv"
    ];
    // Moves + abilities
    var _targets_moves = [
        "data_load_moves_structs",
        "data_load_move_text_structs",
        "data_load_abilities_structs",
        "data_load_ability_text_structs"
    ];
    // Items (NEW in v1.1.0)
    var _targets_items = [
        "data_load_items_structs",
        "data_load_item_names_structs",
        "data_load_item_text_structs",
        "data_load_item_categories_structs",
        "data_load_machines_structs",
        "data_compute_item_bag_pages"
    ];
    // Orchestrators (run last if present)
    var _targets_orchestrators = [
        "data_load_all_structs",
        "data_load_all_structs_ext"
    ];

    var _grandStart = __dlp_now();
    var _subtotal;

    // Run groups with subtotals
    _subtotal = __dlp_run_group(_metrics, _logPath, "BASE", _targets_base);
    show_debug_message("[DLP] SUBTOTAL BASE ms=" + string(_subtotal));
    __dlp_write_line(_logPath, __dlp_timestamp() + ",SUBTOTAL_BASE,1," + string(_subtotal));

    _subtotal = __dlp_run_group(_metrics, _logPath, "MOVES_ABIL", _targets_moves);
    show_debug_message("[DLP] SUBTOTAL MOVES_ABIL ms=" + string(_subtotal));
    __dlp_write_line(_logPath, __dlp_timestamp() + ",SUBTOTAL_MOVES_ABIL,1," + string(_subtotal));

    _subtotal = __dlp_run_group(_metrics, _logPath, "ITEMS", _targets_items);
    show_debug_message("[DLP] SUBTOTAL ITEMS ms=" + string(_subtotal));
    __dlp_write_line(_logPath, __dlp_timestamp() + ",SUBTOTAL_ITEMS,1," + string(_subtotal));

    _subtotal = __dlp_run_group(_metrics, _logPath, "ORCH", _targets_orchestrators);
    show_debug_message("[DLP] SUBTOTAL ORCH ms=" + string(_subtotal));
    __dlp_write_line(_logPath, __dlp_timestamp() + ",SUBTOTAL_ORCH,1," + string(_subtotal));

    var _grandEnd = __dlp_now();
    _metrics.sys_total_ms = __dlp_ms(_grandStart, _grandEnd);
    show_debug_message("[DLP] TOTAL ms=" + string(_metrics.sys_total_ms));
    __dlp_write_line(_logPath, __dlp_timestamp() + ",TOTAL,1," + string(_metrics.sys_total_ms));

    // Sorted summary (descending by ms)
    _metrics.sys_sorted_indices = __dlp_sort_indices_desc(_metrics.sys_items);

    show_debug_message("----------------------------------------");
    show_debug_message("[DLP] Sorted summary (desc ms):");
    for (var _i = 0; _i < array_length(_metrics.sys_sorted_indices); _i++) {
        var _idx = _metrics.sys_sorted_indices[_i];
        var _e = _metrics.sys_items[_idx];
        if (is_struct(_e)) {
            show_debug_message("   " + _e.label + " → ok=" + string(_e.ok) + " ms=" + string(_e.ms));
        }
    }
    show_debug_message("----------------------------------------");

    return _metrics;
}

// ------------------------------------------------------------
// Group runner
function __dlp_run_group(_metrics, _logPath, _groupLabel, _targetsArr) {
    var _n = array_length(_targetsArr);
    var _t0 = __dlp_now();
    for (var _i = 0; _i < _n; _i++) {
        var _label = _targetsArr[_i];
        __dlp_run_one(_metrics, _logPath, _label);
    }
    var _t1 = __dlp_now();
    return __dlp_ms(_t0, _t1);
}

// Single target
function __dlp_run_one(_metrics, _logPath, _label) {
    var _asset = asset_get_index(_label);
    var _ok = false;
    var _ms = 0.0;

    if (_asset != -1) {
        var _t0 = __dlp_now();
        _ok = script_execute(_asset);
        var _t1 = __dlp_now();
        _ms = __dlp_ms(_t0, _t1);
    } else {
        _ok = false;
        _ms = 0.0;
    }

    var _entry = { label: _label, ok: _ok, ms: _ms };
    _metrics.sys_items = __dlp_array_push(_metrics.sys_items, _entry);
    _metrics.sys_entries += 1;

    var _stamp = __dlp_timestamp();
    var _okStr = _ok ? "1" : "0";
    var _line = _stamp + "," + _label + "," + _okStr + "," + string(_ms);
    __dlp_write_line(_logPath, _line);

    show_debug_message("[DLP] " + _label + " → ok=" + string(_ok) + " ms=" + string(_ms));
}

// ------------------------------------------------------------
// Helpers
function __dlp_array_push(_arr, _val) {
    var _len = array_length(_arr);
    _arr[_len] = _val;
    return _arr;
}

function __dlp_now() {
    return get_timer(); // microseconds
}

function __dlp_ms(_t0, _t1) {
    var _us = _t1 - _t0;
    return _us / 1000.0;
}

function __dlp_timestamp() {
    var _dt = date_current_datetime();
    var _yy = string_format(date_get_year(_dt), 4, 0);
    var _mm = string_format(date_get_month(_dt), 2, 0);
    var _dd = string_format(date_get_day(_dt), 2, 0);
    var _hh = string_format(date_get_hour(_dt), 2, 0);
    var _mi = string_format(date_get_minute(_dt), 2, 0);
    var _ss = string_format(date_get_second(_dt), 2, 0);
    return _yy + _mm + _dd + "_" + _hh + _mi + _ss;
}

// Return the absolute logs directory in Documents
function __dlp_logs_dir() {
    var _userProf = environment_get_variable("USERPROFILE");
    var _home = environment_get_variable("HOME");
    if (!is_undefined(_userProf) && string_length(_userProf) > 0) {
        return _userProf + DLP_DIR_LOGS_WIN;
    } else if (!is_undefined(_home) && string_length(_home) > 0) {
        return _home + DLP_DIR_LOGS_UNIX;
    } else {
        return working_directory + "Pokemon_Engine/logs/";
    }
}

function __dlp_ensure_dir(_absDir) {
    if (!directory_exists(_absDir)) {
        directory_create(_absDir);
    }
}

function __dlp_new_log_path(_absDir) {
    var _ts = __dlp_timestamp();
    return _absDir + DLP_FILE_PREFIX + _ts + ".csv";
}

function __dlp_write_line(_absPath, _text) {
    // Safe file open helpers
    var _fh = -1;
    if (file_exists(_absPath)) {
        _fh = file_text_open_append(_absPath);
    } else {
        // make sure parent dir exists (already ensured at start)
        _fh = file_text_open_write(_absPath);
    }
    if (_fh >= 0) {
        file_text_write_string(_fh, _text);
        file_text_writeln(_fh);
        file_text_close(_fh);
    }
}

// Simple selection sort of indices by descending ms
function __dlp_sort_indices_desc(_arr) {
    var _n = array_length(_arr);
    var _idx = [];
    array_resize(_idx, _n);
    for (var _i = 0; _i < _n; _i++) _idx[_i] = _i;

    for (var _a = 0; _a < _n - 1; _a++) {
        var _maxI = _a;
        var _maxV = (is_struct(_arr[_idx[_a]]) ? _arr[_idx[_a]].ms : 0);
        for (var _b = _a + 1; _b < _n; _b++) {
            var _v = (is_struct(_arr[_idx[_b]]) ? _arr[_idx[_b]].ms : 0);
            if (_v > _maxV) {
                _maxV = _v;
                _maxI = _b;
            }
        }
        if (_maxI != _a) {
            var _tmp = _idx[_a];
            _idx[_a] = _idx[_maxI];
            _idx[_maxI] = _tmp;
        }
    }
    return _idx;
}
