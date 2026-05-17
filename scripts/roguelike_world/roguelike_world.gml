/// Roguelike infinite overworld runtime.
///
/// `rm_world` is treated as a reusable chunk viewport. The generator keeps an
/// infinite world coordinate origin, writes tiles into the room tilemaps, and
/// pages the chunk when the player crosses an edge.

function rogue_world_default_state(){
    return {
        active: false,
        room_id: rm_world,
        seed: 1337,
        chunk_tiles: 64,
        tile_size: 16,
        origin_tile_x: 0,
        origin_tile_y: 0,
        entry_origin_tile_x: 0,
        entry_origin_tile_y: 0,
        entry_spawn_x: 128,
        entry_spawn_y: 128,
        return_edge: "up",
        chunk_name: "Wild Frontier",
        return_room: noone,
        return_x: 0,
        return_y: 0,
        return_facing: 2,
        interior_return: undefined,
        last_origin_tile_x: 99999999,
        last_origin_tile_y: 99999999,
        default_biome: "grassland",
        biome_cell_tiles: 128,
        climate_cell_tiles: 192,
        temperature_band_tiles: 1024,
        biome_blend_enabled: false,
        biome_blend_distance_tiles: 4,
        biome_solids_enabled: false,
        path_tile: 9,
        path_tiles: [
            { role:"ground", tile:9 }
        ],
        path_width_tiles: 3,
        town_grid_chunks: 6,
        town_path_enabled: true,
        edge_warp_sound: snd_Warp_Exit,
        edge_warp_sound_enabled: true,
        edge_warp_sound_last_ms: -999999,
        edge_page_pending: undefined,
        layer_roles: {
            ground: "FLOOR",
            decor: "FLOOR_OBJECTS",
            _solid: "WALL",
            collision: "BLOCKS"
        },
        biomes: {},
        prefabs: [],
        prefabs_loaded: false,
        reserved_zones: [],
        chunk_cache: {},
        chunk_cache_order: [],
        chunk_cache_limit: 24,
        edge_page_generate_after_ms: 210,
        encounter_enabled: true,
        encounter_hidden_enabled: false,
        encounter_visible_enabled: true,
        encounter_visible_loose_spawns: false,
        encounter_default_chance: 1 / 18,
        encounter_default_level_min: 3,
        encounter_default_level_max: 8,
        encounter_cooldown_frames: 45,
        encounter_last_tiles: ["", ""],
        encounter_cooldowns: [0, 0],
        encounter_path_enabled: false,
        encounter_visible_owner: noone,
        encounter_visible_spawn_timer: 90,
        encounter_visible_spawn_min: 70,
        encounter_visible_spawn_max: 150,
        encounter_visible_max_active: 6,
        encounter_visible_patch_radius_tiles: 6,
        dynamic_layers: [],
        missing_tile_layer_warnings: {},
        missing_role_warnings: {},
        invalid_tile_warnings: {},
        generated_revision: 0
    };
}

function rogue_world_ensure(){
    if (!variable_global_exists("ROGUE_WORLD") || !is_struct(global.ROGUE_WORLD)){
        global.ROGUE_WORLD = rogue_world_default_state();
    }
    var _R = global.ROGUE_WORLD;
    if (!variable_struct_exists(_R, "biomes") || !is_struct(_R.biomes)) _R.biomes = {};
    if (!variable_struct_exists(_R, "prefabs") || !is_array(_R.prefabs)) _R.prefabs = [];
    if (!variable_struct_exists(_R, "prefabs_loaded")) _R.prefabs_loaded = false;
    if (!variable_struct_exists(_R, "reserved_zones") || !is_array(_R.reserved_zones)) _R.reserved_zones = [];
    if (!variable_struct_exists(_R, "chunk_cache") || !is_struct(_R.chunk_cache)) _R.chunk_cache = {};
    if (!variable_struct_exists(_R, "chunk_cache_order") || !is_array(_R.chunk_cache_order)) _R.chunk_cache_order = [];
    if (!variable_struct_exists(_R, "chunk_cache_limit") || !is_real(_R.chunk_cache_limit)) _R.chunk_cache_limit = 24;
    if (!variable_struct_exists(_R, "edge_page_generate_after_ms") || !is_real(_R.edge_page_generate_after_ms)) _R.edge_page_generate_after_ms = 210;
    if (!variable_struct_exists(_R, "encounter_enabled")) _R.encounter_enabled = true;
    if (!variable_struct_exists(_R, "encounter_hidden_enabled")) _R.encounter_hidden_enabled = false;
    if (!variable_struct_exists(_R, "encounter_visible_enabled")) _R.encounter_visible_enabled = true;
    if (!variable_struct_exists(_R, "encounter_visible_loose_spawns")) _R.encounter_visible_loose_spawns = false;
    if (!variable_struct_exists(_R, "encounter_default_chance") || !is_real(_R.encounter_default_chance)) _R.encounter_default_chance = 1 / 18;
    if (!variable_struct_exists(_R, "encounter_default_level_min") || !is_real(_R.encounter_default_level_min)) _R.encounter_default_level_min = 3;
    if (!variable_struct_exists(_R, "encounter_default_level_max") || !is_real(_R.encounter_default_level_max)) _R.encounter_default_level_max = 8;
    if (!variable_struct_exists(_R, "encounter_cooldown_frames") || !is_real(_R.encounter_cooldown_frames)) _R.encounter_cooldown_frames = 45;
    if (!variable_struct_exists(_R, "encounter_last_tiles") || !is_array(_R.encounter_last_tiles) || array_length(_R.encounter_last_tiles) < 2) _R.encounter_last_tiles = ["", ""];
    if (!variable_struct_exists(_R, "encounter_cooldowns") || !is_array(_R.encounter_cooldowns) || array_length(_R.encounter_cooldowns) < 2) _R.encounter_cooldowns = [0, 0];
    if (!variable_struct_exists(_R, "encounter_path_enabled")) _R.encounter_path_enabled = false;
    if (!variable_struct_exists(_R, "encounter_visible_owner")) _R.encounter_visible_owner = noone;
    if (!variable_struct_exists(_R, "encounter_visible_spawn_timer") || !is_real(_R.encounter_visible_spawn_timer)) _R.encounter_visible_spawn_timer = 90;
    if (!variable_struct_exists(_R, "encounter_visible_spawn_min") || !is_real(_R.encounter_visible_spawn_min)) _R.encounter_visible_spawn_min = 70;
    if (!variable_struct_exists(_R, "encounter_visible_spawn_max") || !is_real(_R.encounter_visible_spawn_max)) _R.encounter_visible_spawn_max = 150;
    if (!variable_struct_exists(_R, "encounter_visible_max_active") || !is_real(_R.encounter_visible_max_active)) _R.encounter_visible_max_active = 6;
    if (!variable_struct_exists(_R, "encounter_visible_patch_radius_tiles") || !is_real(_R.encounter_visible_patch_radius_tiles)) _R.encounter_visible_patch_radius_tiles = 6;
    if (!variable_struct_exists(_R, "dynamic_layers") || !is_array(_R.dynamic_layers)) _R.dynamic_layers = [];
    if (!variable_struct_exists(_R, "missing_tile_layer_warnings") || !is_struct(_R.missing_tile_layer_warnings)) _R.missing_tile_layer_warnings = {};
    if (!variable_struct_exists(_R, "missing_role_warnings") || !is_struct(_R.missing_role_warnings)) _R.missing_role_warnings = {};
    if (!variable_struct_exists(_R, "invalid_tile_warnings") || !is_struct(_R.invalid_tile_warnings)) _R.invalid_tile_warnings = {};
    if (!variable_struct_exists(_R, "chunk_tiles") || !is_real(_R.chunk_tiles)) _R.chunk_tiles = 64;
    if (!variable_struct_exists(_R, "tile_size") || !is_real(_R.tile_size)) _R.tile_size = 16;
    if (!variable_struct_exists(_R, "seed") || !is_real(_R.seed)) _R.seed = 1337;
    if (!variable_struct_exists(_R, "layer_roles") || !is_struct(_R.layer_roles)){
        _R.layer_roles = {
            ground: "FLOOR",
            decor: "FLOOR_OBJECTS",
            _solid: "WALL",
            collision: "BLOCKS"
        };
    }
    if (!variable_struct_exists(_R.layer_roles, "ground")) _R.layer_roles.ground = "FLOOR";
    if (!variable_struct_exists(_R.layer_roles, "decor")) _R.layer_roles.decor = "FLOOR_OBJECTS";
    if (!variable_struct_exists(_R.layer_roles, "_solid")){
        if (variable_struct_exists(_R.layer_roles, "solid")) _R.layer_roles._solid = variable_struct_get(_R.layer_roles, "solid");
        else _R.layer_roles._solid = "WALL";
    }
    if (!variable_struct_exists(_R.layer_roles, "collision")) _R.layer_roles.collision = "BLOCKS";
    if (!variable_struct_exists(_R, "origin_tile_x") || !is_real(_R.origin_tile_x)) _R.origin_tile_x = 0;
    if (!variable_struct_exists(_R, "origin_tile_y") || !is_real(_R.origin_tile_y)) _R.origin_tile_y = 0;
    if (!variable_struct_exists(_R, "entry_origin_tile_x")) _R.entry_origin_tile_x = _R.origin_tile_x;
    if (!variable_struct_exists(_R, "entry_origin_tile_y")) _R.entry_origin_tile_y = _R.origin_tile_y;
    if (!variable_struct_exists(_R, "entry_spawn_x")) _R.entry_spawn_x = 128;
    if (!variable_struct_exists(_R, "entry_spawn_y")) _R.entry_spawn_y = 128;
    if (!variable_struct_exists(_R, "return_edge")) _R.return_edge = "up";
    if (!variable_struct_exists(_R, "chunk_name")) _R.chunk_name = "Wild Frontier";
    if (!variable_struct_exists(_R, "return_room")) _R.return_room = noone;
    if (!variable_struct_exists(_R, "return_x")) _R.return_x = 0;
    if (!variable_struct_exists(_R, "return_y")) _R.return_y = 0;
    if (!variable_struct_exists(_R, "return_facing")) _R.return_facing = 2;
    if (!variable_struct_exists(_R, "interior_return")) _R.interior_return = undefined;
    if (!variable_struct_exists(_R, "last_origin_tile_x")) _R.last_origin_tile_x = 99999999;
    if (!variable_struct_exists(_R, "last_origin_tile_y")) _R.last_origin_tile_y = 99999999;
    if (!variable_struct_exists(_R, "default_biome")) _R.default_biome = "grassland";
    if (!variable_struct_exists(_R, "biome_cell_tiles") || !is_real(_R.biome_cell_tiles)) _R.biome_cell_tiles = 128;
    if (!variable_struct_exists(_R, "climate_cell_tiles") || !is_real(_R.climate_cell_tiles)) _R.climate_cell_tiles = 192;
    if (!variable_struct_exists(_R, "temperature_band_tiles") || !is_real(_R.temperature_band_tiles)) _R.temperature_band_tiles = 1024;
    if (!variable_struct_exists(_R, "biome_blend_enabled")) _R.biome_blend_enabled = false;
    if (!variable_struct_exists(_R, "biome_blend_distance_tiles") || !is_real(_R.biome_blend_distance_tiles)) _R.biome_blend_distance_tiles = 4;
    if (!variable_struct_exists(_R, "biome_solids_enabled")) _R.biome_solids_enabled = false;
    if (!variable_struct_exists(_R, "path_tile") || !is_real(_R.path_tile)) _R.path_tile = 9;
    if (!variable_struct_exists(_R, "path_tiles") || !is_array(_R.path_tiles)){
        _R.path_tiles = [
            { role:"ground", tile:_R.path_tile }
        ];
    }
    if (!variable_struct_exists(_R, "path_width_tiles") || !is_real(_R.path_width_tiles)) _R.path_width_tiles = 3;
    if (!variable_struct_exists(_R, "town_grid_chunks") || !is_real(_R.town_grid_chunks)) _R.town_grid_chunks = 6;
    if (!variable_struct_exists(_R, "town_path_enabled")) _R.town_path_enabled = true;
    if (!variable_struct_exists(_R, "edge_warp_sound")) _R.edge_warp_sound = snd_Warp_Exit;
    if (!variable_struct_exists(_R, "edge_warp_sound_enabled")) _R.edge_warp_sound_enabled = true;
    if (!variable_struct_exists(_R, "edge_warp_sound_last_ms") || !is_real(_R.edge_warp_sound_last_ms)) _R.edge_warp_sound_last_ms = -999999;
    if (!variable_struct_exists(_R, "edge_page_pending")) _R.edge_page_pending = undefined;
    global.ROGUE_WORLD = _R;
    return _R;
}

function rogue_world_configure_layers(_roles){
    var _R = rogue_world_ensure();
    if (!is_struct(_roles)) return false;
    var _names = variable_struct_get_names(_roles);
    for (var _i = 0; _i < array_length(_names); ++_i){
        var _role = string_lower(string(_names[_i]));
        if (_role == "solid") _role = "_solid";
        var _layer_name = string(variable_struct_get(_roles, _names[_i]));
        variable_struct_set(_R.layer_roles, _role, _layer_name);
        if (!is_undefined(rogue_world_ensure_tile_layer)) rogue_world_ensure_tile_layer(_layer_name);
    }
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_fit_chunk_to_room(){
    var _R = rogue_world_ensure();
    var _tile = max(1, real(_R.tile_size));
    var _room_tw = max(1, floor(room_width / _tile));
    var _room_th = max(1, floor(room_height / _tile));
    var _fit = max(1, min(_room_tw, _room_th));
    if (!is_real(_R.chunk_tiles) || _R.chunk_tiles <= 0) _R.chunk_tiles = _fit;
    if (floor(_R.chunk_tiles) != _fit){
        if (floor(_R.chunk_tiles) > _fit){
            show_debug_message("[ROGUE][chunk] chunk_tiles " + string(_R.chunk_tiles) + " is larger than rm_world (" + string(_fit) + " tiles). Using the room-sized chunk so edge transitions stay visible.");
        }
        _R.chunk_tiles = _fit;
    }
    global.ROGUE_WORLD = _R;
    return _fit;
}

function rogue_world_role_key(_role){
    var _key = string_lower(string(_role));
    if (_key == "solid") _key = "_solid";
    return _key;
}

function rogue_world_role_exists(_role){
    var _R = rogue_world_ensure();
    return variable_struct_exists(_R.layer_roles, rogue_world_role_key(_role));
}

function rogue_world_configured_roles(){
    var _R = rogue_world_ensure();
    return variable_struct_get_names(_R.layer_roles);
}

function rogue_world_configure_path_tiles(_rules){
    var _R = rogue_world_ensure();
    if (!is_array(_rules)) return false;
    _R.path_tiles = _rules;
    if (array_length(_rules) > 0){
        var _first = _rules[0];
        if (is_struct(_first) && variable_struct_exists(_first, "tile") && is_real(_first.tile)) _R.path_tile = _first.tile;
    }
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_normalize_edge(_edge, _fallback = "up"){
    var _e = string_lower(string(_edge));
    if (_e == "left" || _e == "right" || _e == "up" || _e == "down" || _e == "any" || _e == "auto") return _e;
    return string(_fallback);
}

function rogue_world_set_return(_room_id, _x, _y, _facing = 2, _edge = "auto"){
    var _R = rogue_world_ensure();
    _R.return_room = _room_id;
    _R.return_x = real(_x);
    _R.return_y = real(_y);
    _R.return_facing = is_real(_facing) ? floor(_facing) mod 4 : 2;
    var _edge_norm = rogue_world_normalize_edge(_edge, "auto");
    _R.return_edge = (_edge_norm == "auto") ? rogue_world_return_edge_from_facing(_R.return_facing) : _edge_norm;
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_store_interior_return(_x, _y, _facing = 2){
    var _R = rogue_world_ensure();
    if (room != _R.room_id || !_R.active) return false;
    _R.interior_return = {
        origin_tile_x: _R.origin_tile_x,
        origin_tile_y: _R.origin_tile_y,
        x: real(_x),
        y: real(_y),
        facing: is_real(_facing) ? floor(_facing) mod 4 : 2,
        chunk_name: variable_struct_exists(_R, "chunk_name") ? string(_R.chunk_name) : "Wild Frontier"
    };
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_return_from_interior(){
    var _R = rogue_world_ensure();
    if (!is_struct(_R.interior_return)) return false;
    var _ret = _R.interior_return;
    _R.active = true;
    _R.room_id = rm_world;
    _R.origin_tile_x = floor(_ret.origin_tile_x);
    _R.origin_tile_y = floor(_ret.origin_tile_y);
    _R.last_origin_tile_x = 99999999;
    _R.last_origin_tile_y = 99999999;
    _R.chunk_name = variable_struct_exists(_ret, "chunk_name") ? string(_ret.chunk_name) : "Wild Frontier";
    global.ROGUE_WORLD = _R;
    return world_warp_to(rm_world, real(_ret.x), real(_ret.y), {
        transition_style: "emerald_fade_black",
        show_route: true,
        facing: variable_struct_exists(_ret, "facing") ? _ret.facing : 2
    });
}

function rogue_world_return_edge_from_facing(_facing){
    switch (floor(_facing) mod 4){
        case 0: return "down";
        case 1: return "left";
        case 2: return "up";
        case 3: return "right";
    }
    return "up";
}

function rogue_world_start_page_transition(_style = "emerald_fade_black", _duration_ms = 320){
    var _R = rogue_world_ensure();
    _R.page_transition = {
        active: true,
        style: string(_style),
        start_ms: current_time,
        duration_ms: max(1, real(_duration_ms))
    };
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_play_edge_warp_sound(){
    var _R = rogue_world_ensure();
    if (variable_struct_exists(_R, "edge_warp_sound_enabled") && _R.edge_warp_sound_enabled != true) return false;
    if (current_time - real(_R.edge_warp_sound_last_ms) < 250) return false;
    var _sound = variable_struct_exists(_R, "edge_warp_sound") ? _R.edge_warp_sound : snd_Warp_Exit;
    _R.edge_warp_sound_last_ms = current_time;
    global.ROGUE_WORLD = _R;
    if (!is_undefined(sfx_play_safe)) return sfx_play_safe(_sound, 1);
    try {
        if (!is_undefined(audio_play_sound)){
            audio_play_sound(_sound, 1, false);
            return true;
        }
    } catch (e_rogue_edge_sfx) {}
    return false;
}

function rogue_world_draw_transition(){
    if (!variable_global_exists("ROGUE_WORLD") || !is_struct(global.ROGUE_WORLD)) return false;
    var _R = global.ROGUE_WORLD;
    if (!variable_struct_exists(_R, "page_transition") || !is_struct(_R.page_transition)) return false;
    var _P = _R.page_transition;
    if (!variable_struct_exists(_P, "active") || _P.active != true) return false;
    var _dur = variable_struct_exists(_P, "duration_ms") ? max(1, real(_P.duration_ms)) : 320;
    var _elapsed = current_time - (variable_struct_exists(_P, "start_ms") ? real(_P.start_ms) : current_time);
    if (_elapsed > _dur + 1500){
        _P.active = false;
        _R.page_transition = _P;
        if (variable_struct_exists(_R, "edge_page_pending") && is_struct(_R.edge_page_pending)) _R.edge_page_pending = undefined;
        global.ROGUE_WORLD = _R;
        show_debug_message("[ROGUE][transition] page transition timed out and was cleared.");
        return false;
    }
    var _p = clamp(_elapsed / _dur, 0, 1);
    var _cover = 1 - abs((_p * 2) - 1);
    if (!is_undefined(transition_draw_cover_rect)){
        transition_draw_cover_rect(variable_struct_exists(_P, "style") ? _P.style : "emerald_fade_black", _cover, 0, 0, display_get_gui_width(), display_get_gui_height());
    }
    if (_p >= 1){
        _P.active = false;
        _R.page_transition = _P;
        global.ROGUE_WORLD = _R;
    }
    return true;
}

function rogue_world_layer_name(_role_or_layer){
    var _R = rogue_world_ensure();
    var _key = rogue_world_role_key(_role_or_layer);
    if (variable_struct_exists(_R.layer_roles, _key)) return string(variable_struct_get(_R.layer_roles, _key));
    return string(_role_or_layer);
}

function rogue_world_tile_rule_layer(_rule, _fallback_role = "decor"){
    if (!is_struct(_rule)) return rogue_world_layer_name(_fallback_role);
    if (variable_struct_exists(_rule, "layer")) return string(_rule.layer);
    if (variable_struct_exists(_rule, "role")){
        var _role = _rule.role;
        if (!rogue_world_role_exists(_role)){
            var _R = rogue_world_ensure();
            var _role_key = rogue_world_role_key(_role);
            if (!variable_struct_exists(_R.missing_role_warnings, _role_key)){
                variable_struct_set(_R.missing_role_warnings, _role_key, true);
                show_debug_message("[ROGUE][role] role " + string(_role) + " is not configured; using layer name " + string(_role) + " directly.");
            }
        }
        return rogue_world_layer_name(_role);
    }
    return rogue_world_layer_name(_fallback_role);
}

function rogue_world_layer_names(){
    var _R = rogue_world_ensure();
    var _out = [];
    var _roles = variable_struct_get_names(_R.layer_roles);
    for (var _i = 0; _i < array_length(_roles); ++_i){
        var _layer = string(variable_struct_get(_R.layer_roles, _roles[_i]));
        var _exists = false;
        for (var _j = 0; _j < array_length(_out); ++_j){
            if (_out[_j] == _layer){
                _exists = true;
                break;
            }
        }
        if (!_exists) array_push(_out, _layer);
    }
    if (variable_struct_exists(_R, "dynamic_layers") && is_array(_R.dynamic_layers)){
        for (var _d = 0; _d < array_length(_R.dynamic_layers); ++_d){
            var _dyn = string(_R.dynamic_layers[_d]);
            var _dyn_exists = false;
            for (var _k = 0; _k < array_length(_out); ++_k){
                if (_out[_k] == _dyn){
                    _dyn_exists = true;
                    break;
                }
            }
            if (!_dyn_exists) array_push(_out, _dyn);
        }
    }
    return _out;
}

function rogue_world_all_tile_layer_names(){
    var _out = [];
    var _layers = [];
    try { _layers = layer_get_all(); } catch (e_all_layers) { _layers = []; }
    for (var _i = 0; _i < array_length(_layers); ++_i){
        var _lid = _layers[_i];
        var _tm = -1;
        try { _tm = layer_tilemap_get_id(_lid); } catch (e_all_tilemap) { _tm = -1; }
        if (_tm == -1) continue;
        var _name = "";
        try { _name = layer_get_name(_lid); } catch (e_all_layer_name) { _name = ""; }
        if (string_length(_name) > 0) array_push(_out, _name);
    }
    return _out;
}

function rogue_hash01(_x, _y, _salt){
    var _R = rogue_world_ensure();
    var _n = sin((_x * 12.9898) + (_y * 78.233) + (_salt * 37.719) + (_R.seed * 0.0137)) * 43758.5453;
    return _n - floor(_n);
}

function rogue_lerp(_a, _b, _t){
    return _a + ((_b - _a) * clamp(_t, 0, 1));
}

function rogue_smoothstep(_t){
    _t = clamp(_t, 0, 1);
    return _t * _t * (3 - (2 * _t));
}

function rogue_value_noise01(_x, _y, _scale, _salt){
    var _s = max(1, real(_scale));
    var _fx = real(_x) / _s;
    var _fy = real(_y) / _s;
    var _x0 = floor(_fx);
    var _y0 = floor(_fy);
    var _tx = rogue_smoothstep(_fx - _x0);
    var _ty = rogue_smoothstep(_fy - _y0);
    var _a = rogue_hash01(_x0, _y0, _salt);
    var _b = rogue_hash01(_x0 + 1, _y0, _salt);
    var _c = rogue_hash01(_x0, _y0 + 1, _salt);
    var _d = rogue_hash01(_x0 + 1, _y0 + 1, _salt);
    return rogue_lerp(rogue_lerp(_a, _b, _tx), rogue_lerp(_c, _d, _tx), _ty);
}

function rogue_tiledata(_tile_index){
    if (!is_real(_tile_index) || _tile_index < 0) return 0;
    var _td = floor(_tile_index);
    try { _td = tile_set_index(0, floor(_tile_index)); } catch (e_tile_index) {}
    return _td;
}

function rogue_tilemap_for_layer(_layer_name){
    var _lid = layer_get_id(rogue_world_layer_name(_layer_name));
    if (_lid == -1) return -1;
    try { return layer_tilemap_get_id(_lid); } catch (e_tilemap_get) {}
    return -1;
}

function rogue_world_tileset_name_for_tilemap(_tm){
    var _tileset = -1;
    try { _tileset = tilemap_get_tileset(_tm); } catch (e_tileset_get) { _tileset = -1; }
    return rogue_world_tileset_name_from_ref(_tileset);
}

function rogue_world_tileset_is_valid(_tileset){
    if (is_undefined(_tileset)) return false;
    if (is_real(_tileset)) return (_tileset >= 0);
    try {
        var _asset_name = asset_get_name(_tileset);
        if (is_string(_asset_name) && string_length(_asset_name) > 0) return true;
    } catch (e_tileset_valid_asset) {}
    var _text = string(_tileset);
    if (string_pos("@ref tileset(", _text) == 1) return true;
    if (string_pos("ref tileset ", _text) == 1) return true;
    return false;
}

function rogue_world_tileset_name_from_ref(_tileset_ref){
    if (is_undefined(_tileset_ref)) return "";
    try {
        var _asset_name = asset_get_name(_tileset_ref);
        if (is_string(_asset_name) && string_length(_asset_name) > 0) return _asset_name;
    } catch (e_tileset_name_from_asset) {}
    var _s = string(_tileset_ref);
    var _prefix = "@ref tileset(";
    if (string_pos(_prefix, _s) == 1){
        var _start = string_length(_prefix) + 1;
        var _len = max(0, string_length(_s) - string_length(_prefix) - 1);
        return string_copy(_s, _start, _len);
    }
    _prefix = "ref tileset ";
    if (string_pos(_prefix, _s) == 1){
        return string_copy(_s, string_length(_prefix) + 1, string_length(_s));
    }
    return _s;
}

function rogue_world_tileset_asset(_tileset_name){
    var _name = rogue_world_tileset_name_from_ref(_tileset_name);
    var _idx = -1;
    if (string_length(_name) > 0){
        try { _idx = asset_get_index(_name); } catch (e_tileset_asset_get_index) { _idx = -1; }
        if (rogue_world_tileset_is_valid(_idx)) return _idx;
    }
    switch (_name){
        case "TileSet2": return TileSet2;
        case "TileSet3": return TileSet3;
        case "test_set": return test_set;
        case "t_kanto": return t_kanto;
        case "t_newbarktown": return t_newbarktown;
    }
    return -1;
}

function rogue_world_default_tileset(){
    var _names = rogue_world_layer_names();
    for (var _i = 0; _i < array_length(_names); ++_i){
        var _tm = rogue_tilemap_for_layer(_names[_i]);
        if (_tm == -1) continue;
        try {
            var _ts = tilemap_get_tileset(_tm);
            if (rogue_world_tileset_is_valid(_ts)) return _ts;
        } catch (e_default_tileset) {}
    }
    var _fallback = -1;
    _fallback = rogue_world_tileset_asset("test_set");
    return _fallback;
}

function rogue_world_register_dynamic_layer(_layer_name){
    var _R = rogue_world_ensure();
    var _name = string(_layer_name);
    for (var _i = 0; _i < array_length(_R.dynamic_layers); ++_i){
        if (string(_R.dynamic_layers[_i]) == _name) return true;
    }
    array_push(_R.dynamic_layers, _name);
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_ensure_tile_layer(_layer_name, _tileset_name = "", _depth = 350, _w_tiles = undefined, _h_tiles = undefined, _order = undefined, _tileset_asset = undefined){
    var _name = string(_layer_name);
    if (layer_get_id(_name) != -1 && rogue_tilemap_for_layer(_name) != -1){
        rogue_world_register_dynamic_layer(_name);
        return true;
    }

    var _tileset = -1;
    if (rogue_world_tileset_is_valid(_tileset_asset)){
        _tileset = rogue_world_tileset_asset(_tileset_asset);
        if (!rogue_world_tileset_is_valid(_tileset)) _tileset = _tileset_asset;
    }
    if (!rogue_world_tileset_is_valid(_tileset) && is_string(_tileset_name) && string_length(_tileset_name) > 0){
        _tileset = rogue_world_tileset_asset(_tileset_name);
    }
    if (!rogue_world_tileset_is_valid(_tileset) && !is_undefined(_tileset_asset)){
        _tileset = rogue_world_tileset_asset(rogue_world_tileset_name_from_ref(_tileset_asset));
    }
    if (!rogue_world_tileset_is_valid(_tileset)) _tileset = rogue_world_default_tileset();
    if (!rogue_world_tileset_is_valid(_tileset)){
        show_debug_message("[ROGUE][layer] could not create missing tile layer " + _name + " because no tileset was available.");
        return false;
    }

    var _create_depth = real(_depth);
    if (is_real(_order)) _create_depth = _create_depth + (real(_order) * 0.001);

    var _lid = layer_get_id(_name);
    if (_lid == -1){
        try { _lid = layer_create(_create_depth, _name); } catch (e_layer_create) { _lid = -1; }
    }
    if (_lid == -1) return false;

    var _R = rogue_world_ensure();
    var _room_tw = max(1, ceil(room_width / max(1, real(_R.tile_size))));
    var _room_th = max(1, ceil(room_height / max(1, real(_R.tile_size))));
    if (room == _R.room_id){
        _room_tw = max(_room_tw, floor(_R.chunk_tiles));
        _room_th = max(_room_th, floor(_R.chunk_tiles));
    }
    var _tw = max(_room_tw, is_real(_w_tiles) ? floor(_w_tiles) : 1);
    var _th = max(_room_th, is_real(_h_tiles) ? floor(_h_tiles) : 1);
    try {
        layer_tilemap_create(_lid, 0, 0, _tileset, _tw, _th);
        try { layer_set_visible(_lid, true); } catch (e_layer_visible) {}
        rogue_world_register_dynamic_layer(_name);
        show_debug_message("[ROGUE][layer] created missing tile layer " + _name + " using tileset " + rogue_world_tileset_name_from_ref(_tileset));
        return true;
    } catch (e_tilemap_create) {
        show_debug_message("[ROGUE][layer] failed to create missing tilemap for " + _name);
    }
    return false;
}

function rogue_world_ensure_exported_layers(_data){
    if (!is_struct(_data) || !variable_struct_exists(_data, "layer_meta") || !is_array(_data.layer_meta)) return false;
    var _tile_size = variable_struct_exists(_data, "tile_size") ? max(1, real(_data.tile_size)) : 16;
    var _w = variable_struct_exists(_data, "w") ? max(1, floor(_data.w)) : max(1, ceil(room_width / _tile_size));
    var _h = variable_struct_exists(_data, "h") ? max(1, floor(_data.h)) : max(1, ceil(room_height / _tile_size));
    var _meta = _data.layer_meta;
    for (var _i = 0; _i < array_length(_meta); ++_i){
        var _m = _meta[_i];
        if (!is_struct(_m) || !variable_struct_exists(_m, "layer")) continue;
        var _layer = string(_m.layer);
        var _tileset_name = variable_struct_exists(_m, "tileset") ? string(_m.tileset) : "";
        var _tileset_asset = variable_struct_exists(_m, "tileset_asset") ? _m.tileset_asset : undefined;
        var _depth = variable_struct_exists(_m, "depth") && is_real(_m.depth) ? real(_m.depth) : 350;
        var _order = variable_struct_exists(_m, "order") && is_real(_m.order) ? real(_m.order) : undefined;
        rogue_world_ensure_tile_layer(_layer, _tileset_name, _depth, _w, _h, _order, _tileset_asset);
    }
    return true;
}

function rogue_tilemap_set_layer(_layer_name, _tx, _ty, _tile_index){
    var _tm = rogue_tilemap_for_layer(_layer_name);
    if (_tm == -1){
        if (rogue_world_ensure_tile_layer(_layer_name)){
            _tm = rogue_tilemap_for_layer(_layer_name);
        }
        if (_tm == -1){
            var _R = rogue_world_ensure();
            var _warn_key = string(_layer_name);
            if (!variable_struct_exists(_R.missing_tile_layer_warnings, _warn_key)){
                variable_struct_set(_R.missing_tile_layer_warnings, _warn_key, true);
                show_debug_message("[ROGUE][tile] missing tile layer " + _warn_key + "; tile " + string(_tile_index) + " could not draw.");
            }
            return false;
        }
    }
    if (!rogue_world_tile_index_valid_for_tilemap(_tm, _tile_index)){
        var _R_invalid = rogue_world_ensure();
        var _invalid_key = string(_layer_name) + ":" + string(_tile_index);
        if (!variable_struct_exists(_R_invalid.invalid_tile_warnings, _invalid_key)){
            variable_struct_set(_R_invalid.invalid_tile_warnings, _invalid_key, true);
            show_debug_message("[ROGUE][tile] tile " + string(_tile_index) + " is outside the tileset used by layer " + string(_layer_name) + ".");
        }
        return false;
    }
    try { tilemap_set(_tm, rogue_tiledata(_tile_index), floor(_tx), floor(_ty)); return true; } catch (e_set_tile) {}
    return false;
}

function rogue_world_tile_index_valid_for_tilemap(_tm, _tile_index){
    if (!is_real(_tile_index)) return false;
    var _idx = floor(_tile_index);
    if (_idx < 0) return true;
    var _tileset = -1;
    try { _tileset = tilemap_get_tileset(_tm); } catch (e_tile_index_tileset) { _tileset = -1; }
    if (!rogue_world_tileset_is_valid(_tileset)) return true;
    try {
        var _info = tileset_get_info(_tileset);
        if (is_struct(_info) && variable_struct_exists(_info, "tile_count")){
            return (_idx < real(_info.tile_count));
        }
    } catch (e_tile_index_info) {}
    return true;
}

function rogue_tilemap_set_role(_role, _tx, _ty, _tile_index){
    return rogue_tilemap_set_layer(rogue_world_layer_name(_role), _tx, _ty, _tile_index);
}

function rogue_tilemap_set_data_layer(_layer_name, _tx, _ty, _tile_data){
    var _tm = rogue_tilemap_for_layer(_layer_name);
    if (_tm == -1){
        if (rogue_world_ensure_tile_layer(_layer_name)){
            _tm = rogue_tilemap_for_layer(_layer_name);
        }
        if (_tm == -1) return false;
    }
    try {
        var _w = tilemap_get_width(_tm);
        var _h = tilemap_get_height(_tm);
        var _need_w = floor(_tx) + 1;
        var _need_h = floor(_ty) + 1;
        if (_need_w > _w || _need_h > _h){
            tilemap_resize(_tm, max(_w, _need_w), max(_h, _need_h));
        }
    } catch (e_resize_data_layer) {}
    try { tilemap_set(_tm, _tile_data, floor(_tx), floor(_ty)); return true; } catch (e_set_data) {}
    return false;
}

function rogue_tilemap_data_at_layer(_layer_name, _tx, _ty){
    var _tm = rogue_tilemap_for_layer(_layer_name);
    if (_tm == -1) return 0;
    try { return tilemap_get(_tm, floor(_tx), floor(_ty)); } catch (e_get_tile) {}
    return 0;
}

function rogue_tilemap_data_at_role(_role, _tx, _ty){
    return rogue_tilemap_data_at_layer(rogue_world_layer_name(_role), _tx, _ty);
}

function rogue_world_point_is_blocked(_x, _y){
    var _R = rogue_world_ensure();
    if (room != _R.room_id || !_R.active) return false;
    var _tx = floor(real(_x) / max(1, real(_R.tile_size)));
    var _ty = floor(real(_y) / max(1, real(_R.tile_size)));
    if (_tx < 0 || _ty < 0 || _tx >= _R.chunk_tiles || _ty >= _R.chunk_tiles) return true;
    if (rogue_tilemap_data_at_role("collision", _tx, _ty) != 0) return true;
    if (rogue_tilemap_data_at_role("_solid", _tx, _ty) != 0) return true;
    return false;
}

function rogue_world_data_path(_file_name){
    var _name = string(_file_name);
    if (string_pos(":", _name) > 0 || string_copy(_name, 1, 1) == "/" || string_copy(_name, 1, 1) == "\\") return _name;
    if (string_pos(".json", string_lower(_name)) <= 0) _name += ".json";
    return working_directory + "/data/rogue_prefabs/" + _name;
}

function rogue_room_data_path(_file_name){
    var _name = string(_file_name);
    if (string_pos(":", _name) > 0 || string_copy(_name, 1, 1) == "/" || string_copy(_name, 1, 1) == "\\") return _name;
    if (string_pos(".json", string_lower(_name)) <= 0) _name += ".json";
    return working_directory + "/data/rogue_rooms/" + _name;
}

function rogue_write_json_file(_path, _data){
    try {
        directory_create(working_directory + "/data");
        directory_create(working_directory + "/data/rogue_prefabs");
        directory_create(working_directory + "/data/rogue_rooms");
    } catch (e_rogue_write_dirs) {}
    var _fh = file_text_open_write(string(_path));
    file_text_write_string(_fh, json_stringify(_data));
    file_text_close(_fh);
    return true;
}

function rogue_world_file_stem(_path){
    var _s = string(_path);
    var _start = 1;
    for (var _i = string_length(_s); _i >= 1; --_i){
        var _ch = string_char_at(_s, _i);
        if (_ch == "/" || _ch == "\\"){
            _start = _i + 1;
            break;
        }
    }
    var _file = string_copy(_s, _start, string_length(_s) - _start + 1);
    var _dot = 0;
    for (var _j = string_length(_file); _j >= 1; --_j){
        if (string_char_at(_file, _j) == "."){
            _dot = _j;
            break;
        }
    }
    if (_dot > 1) return string_copy(_file, 1, _dot - 1);
    return _file;
}

function rogue_world_export_current_room_prefab_dialog(_default_file = "rogue_prefab.json", _opts = undefined){
    var _path = "";
    try {
        _path = get_save_filename("Rogue Prefab JSON|*.json", string(_default_file));
    } catch (e_save_dialog) {
        _path = rogue_world_data_path(_default_file);
    }
    if (string_length(string(_path)) <= 0){
        show_debug_message("[ROGUE][prefab] export cancelled.");
        return undefined;
    }
    if (string_pos(".json", string_lower(string(_path))) <= 0) _path = string(_path) + ".json";
    var _id = rogue_world_file_stem(_path);
    return rogue_world_export_current_room_prefab(_id, _path, _opts);
}

function rogue_world_prefab_object_name(_object_index){
    try { return object_get_name(_object_index); } catch (e_obj_name) {}
    return "";
}

function rogue_world_prefab_object_index(_object_name){
    var _idx = -1;
    try { _idx = asset_get_index(string(_object_name)); } catch (e_obj_index) { _idx = -1; }
    return _idx;
}

function rogue_world_prefab_value_is_exportable(_value, _depth = 0){
    if (is_undefined(_value)) return false;
    if (is_real(_value) || is_string(_value) || is_bool(_value)) return true;
    if (_depth > 2) return false;
    if (is_array(_value)){
        for (var _i = 0; _i < array_length(_value); ++_i){
            if (!rogue_world_prefab_value_is_exportable(_value[_i], _depth + 1)) return false;
        }
        return true;
    }
    if (is_struct(_value)){
        var _names = variable_struct_get_names(_value);
        for (var _j = 0; _j < array_length(_names); ++_j){
            if (!rogue_world_prefab_value_is_exportable(variable_struct_get(_value, _names[_j]), _depth + 1)) return false;
        }
        return true;
    }
    return false;
}

function rogue_world_prefab_export_object_allowed(_inst, _opts){
    if (!instance_exists(_inst)) return false;
    if (_inst.object_index == oPlayer || _inst.object_index == oGame || _inst.object_index == oCamera) return false;
    if (variable_instance_exists(_inst, "rogue_prefab_export") && variable_instance_get(_inst, "rogue_prefab_export") == false) return false;
    if (is_struct(_opts) && variable_struct_exists(_opts, "exclude_objects") && is_array(_opts.exclude_objects)){
        var _exclude = _opts.exclude_objects;
        for (var _i = 0; _i < array_length(_exclude); ++_i){
            var _obj = _exclude[_i];
            if (is_string(_obj)) _obj = rogue_world_prefab_object_index(_obj);
            if (_inst.object_index == _obj) return false;
        }
    }
    if (is_struct(_opts) && variable_struct_exists(_opts, "include_objects") && is_array(_opts.include_objects)){
        var _include = _opts.include_objects;
        for (var _j = 0; _j < array_length(_include); ++_j){
            var _inc = _include[_j];
            if (is_string(_inc)) _inc = rogue_world_prefab_object_index(_inc);
            if (_inst.object_index == _inc) return true;
        }
        return false;
    }
    return true;
}

function rogue_world_export_instance_vars(_inst){
    var _vars = {};
    var _skip = [
        "id", "object_index", "sprite_index", "mask_index", "x", "y", "xstart", "ystart",
        "xprevious", "yprevious", "xscale", "yscale", "image_index", "image_speed",
        "image_xscale", "image_yscale", "image_angle", "image_alpha", "image_blend",
        "bbox_left", "bbox_right", "bbox_top", "bbox_bottom", "depth", "visible", "persistent"
    ];
    var _names = [];
    try { _names = variable_instance_get_names(_inst); } catch (e_inst_names) { _names = []; }
    for (var _i = 0; _i < array_length(_names); ++_i){
        var _name = string(_names[_i]);
        var _blocked = false;
        for (var _s = 0; _s < array_length(_skip); ++_s){
            if (_name == _skip[_s]){
                _blocked = true;
                break;
            }
        }
        if (_blocked) continue;
        var _value = variable_instance_get(_inst, _name);
        if (rogue_world_prefab_value_is_exportable(_value)) variable_struct_set(_vars, _name, _value);
    }
    return _vars;
}

function rogue_world_export_instance_props(_inst){
    if (!instance_exists(_inst)) return {};
    return {
        image_index: _inst.image_index,
        image_speed: _inst.image_speed,
        image_xscale: _inst.image_xscale,
        image_yscale: _inst.image_yscale,
        image_angle: _inst.image_angle,
        image_alpha: _inst.image_alpha,
        image_blend: _inst.image_blend,
        visible: _inst.visible
    };
}

function rogue_world_apply_instance_snapshot(_inst, _object_data){
    if (_inst == noone || !is_struct(_object_data)) return false;

    if (variable_struct_exists(_object_data, "vars") && is_struct(_object_data.vars)){
        var _names = variable_struct_get_names(_object_data.vars);
        for (var _vi = 0; _vi < array_length(_names); ++_vi){
            var _name = _names[_vi];
            variable_instance_set(_inst, _name, variable_struct_get(_object_data.vars, _name));
        }
    }

    if (variable_struct_exists(_object_data, "props") && is_struct(_object_data.props)){
        var _props = _object_data.props;
        if (variable_struct_exists(_props, "image_index")) _inst.image_index = _props.image_index;
        if (variable_struct_exists(_props, "image_speed")) _inst.image_speed = _props.image_speed;
        if (variable_struct_exists(_props, "image_xscale")) _inst.image_xscale = _props.image_xscale;
        if (variable_struct_exists(_props, "image_yscale")) _inst.image_yscale = _props.image_yscale;
        if (variable_struct_exists(_props, "image_angle")) _inst.image_angle = _props.image_angle;
        if (variable_struct_exists(_props, "image_alpha")) _inst.image_alpha = _props.image_alpha;
        if (variable_struct_exists(_props, "image_blend")) _inst.image_blend = _props.image_blend;
        if (variable_struct_exists(_props, "visible")) _inst.visible = _props.visible;
    }

    if (!is_undefined(rogue_world_finalize_loaded_instance)) rogue_world_finalize_loaded_instance(_inst);
    return true;
}

function rogue_world_finalize_loaded_instance(_inst){
    if (_inst == noone) return false;
    if (_inst.object_index == oNpc && !is_undefined(overworld_npc_init)){
        overworld_npc_init(_inst);
        if (variable_instance_exists(_inst, "pokemon_center_nurse") && variable_instance_get(_inst, "pokemon_center_nurse") == true && !is_undefined(pokemon_center_set_nurse_pose)){
            pokemon_center_set_nurse_pose(_inst, "down");
        }
    }
    if (_inst.object_index == oFieldMoveProp && !is_undefined(field_move_prop_setup)){
        var _move = variable_instance_exists(_inst, "field_move_required") ? variable_instance_get(_inst, "field_move_required") : "rock smash";
        var _kind = variable_instance_exists(_inst, "field_move_kind") ? variable_instance_get(_inst, "field_move_kind") : "generic";
        field_move_prop_setup(_inst, _move, _kind);
    }
    return true;
}

function rogue_world_export_current_room_prefab(_id, _file_name = undefined, _opts = undefined){
    rogue_world_ensure();
    if (is_undefined(_opts) || !is_struct(_opts)) _opts = {};

    var _export_all_layers = variable_struct_exists(_opts, "export_all_tile_layers") && _opts.export_all_tile_layers == true;
    var _layers = _export_all_layers ? rogue_world_all_tile_layer_names() : (variable_struct_exists(_opts, "layers") && is_array(_opts.layers) ? _opts.layers : rogue_world_layer_names());
    var _room_layer_order = [];
    try { _room_layer_order = layer_get_all(); } catch (e_layer_get_all) { _room_layer_order = []; }
    var _tile_size = variable_struct_exists(_opts, "tile_size") ? max(1, real(_opts.tile_size)) : 16;
    var _min_x = 999999;
    var _min_y = 999999;
    var _max_x = -999999;
    var _max_y = -999999;
    var _layer_tiles = [];
    var _layer_meta = [];

    for (var _li = 0; _li < array_length(_layers); ++_li){
        var _layer_name = rogue_world_layer_name(_layers[_li]);
        var _tm = rogue_tilemap_for_layer(_layer_name);
        if (_tm == -1) continue;
        var _tileset_asset = -1;
        try { _tileset_asset = tilemap_get_tileset(_tm); } catch (e_layer_tileset_asset) { _tileset_asset = -1; }
        var _layer_id = layer_get_id(_layer_name);
        var _layer_depth = 350;
        try { _layer_depth = layer_get_depth(_layer_id); } catch (e_layer_depth) {}
        var _layer_order = _li;
        for (var _ord = 0; _ord < array_length(_room_layer_order); ++_ord){
            if (_room_layer_order[_ord] == _layer_id){
                _layer_order = _ord;
                break;
            }
        }
        var _tileset_name = rogue_world_tileset_name_for_tilemap(_tm);
        if (variable_struct_exists(_opts, "layer_tilesets") && is_struct(_opts.layer_tilesets) && variable_struct_exists(_opts.layer_tilesets, _layer_name)){
            _tileset_name = string(variable_struct_get(_opts.layer_tilesets, _layer_name));
        }
        array_push(_layer_meta, {
            layer: _layer_name,
            tileset: _tileset_name,
            tileset_asset: _tileset_asset,
            depth: _layer_depth,
            order: _layer_order
        });
        var _tw = max(1, floor(room_width / _tile_size));
        var _th = max(1, floor(room_height / _tile_size));
        try { _tw = tilemap_get_width(_tm); } catch (e_tw) {}
        try { _th = tilemap_get_height(_tm); } catch (e_th) {}
        var _tiles = [];
        for (var _y = 0; _y < _th; ++_y){
            for (var _x = 0; _x < _tw; ++_x){
                var _data = 0;
                try { _data = tilemap_get(_tm, _x, _y); } catch (e_tget) { _data = 0; }
                if (_data == 0) continue;
                array_push(_tiles, { x:_x, y:_y, data:_data });
                _min_x = min(_min_x, _x);
                _min_y = min(_min_y, _y);
                _max_x = max(_max_x, _x);
                _max_y = max(_max_y, _y);
            }
        }
        array_push(_layer_tiles, { layer:_layer_name, tiles:_tiles });
    }

    var _objects = [];
    for (var _ii = instance_number(all) - 1; _ii >= 0; --_ii){
        var _inst = instance_find(all, _ii);
        if (!rogue_world_prefab_export_object_allowed(_inst, _opts)) continue;
        var _tx = floor(_inst.x / _tile_size);
        var _ty = floor(_inst.y / _tile_size);
        _min_x = min(_min_x, _tx);
        _min_y = min(_min_y, _ty);
        _max_x = max(_max_x, _tx);
        _max_y = max(_max_y, _ty);
        array_push(_objects, {
            object_name: rogue_world_prefab_object_name(_inst.object_index),
            x: _inst.x,
            y: _inst.y,
            layer: variable_instance_exists(_inst, "prefab_layer") ? variable_instance_get(_inst, "prefab_layer") : "Instances",
            props: rogue_world_export_instance_props(_inst),
            vars: rogue_world_export_instance_vars(_inst)
        });
    }

    var _crop = !(variable_struct_exists(_opts, "crop") && _opts.crop == false);
    if (!_crop){
        _min_x = 0;
        _min_y = 0;
        _max_x = max(0, ceil(room_width / _tile_size) - 1);
        _max_y = max(0, ceil(room_height / _tile_size) - 1);
    } else if (_max_x < _min_x || _max_y < _min_y){
        _min_x = 0;
        _min_y = 0;
        _max_x = 0;
        _max_y = 0;
    }

    var _tiles_out = [];
    for (var _lo = 0; _lo < array_length(_layer_tiles); ++_lo){
        var _lt = _layer_tiles[_lo];
        var _src_tiles = _lt.tiles;
        for (var _ti = 0; _ti < array_length(_src_tiles); ++_ti){
            var _t = _src_tiles[_ti];
            array_push(_tiles_out, {
                layer: _lt.layer,
                x: _t.x - _min_x,
                y: _t.y - _min_y,
                data: _t.data
            });
        }
    }

    for (var _oo = 0; _oo < array_length(_objects); ++_oo){
        _objects[_oo].x -= _min_x * _tile_size;
        _objects[_oo].y -= _min_y * _tile_size;
    }

    var _prefab = {
        format: "pokemon_rogue_prefab_v1",
        id: string(_id),
        source_room: room_get_name(room),
        tile_size: _tile_size,
        room_width_px: room_width,
        room_height_px: room_height,
        w: max(1, (_max_x - _min_x) + 1),
        h: max(1, (_max_y - _min_y) + 1),
        origin_tile_x: _min_x,
        origin_tile_y: _min_y,
        layer_meta: _layer_meta,
        type: variable_struct_exists(_opts, "type") ? string(_opts.type) : (variable_struct_exists(_opts, "kind") ? string(_opts.kind) : "nature"),
        tags: variable_struct_exists(_opts, "tags") && is_array(_opts.tags) ? _opts.tags : [],
        weight: variable_struct_exists(_opts, "weight") ? _opts.weight : 1,
        biomes: variable_struct_exists(_opts, "biomes") && is_array(_opts.biomes) ? _opts.biomes : [],
        spawn_chance: variable_struct_exists(_opts, "spawn_chance") ? real(_opts.spawn_chance) : 0.22,
        min_per_chunk: variable_struct_exists(_opts, "min_per_chunk") ? max(0, floor(_opts.min_per_chunk)) : 0,
        max_per_chunk: variable_struct_exists(_opts, "max_per_chunk") ? max(1, floor(_opts.max_per_chunk)) : 1,
        tiles: _tiles_out,
        objects: _objects
    };

    if (!is_undefined(_file_name)){
        var _path = rogue_world_data_path(_file_name);
        rogue_write_json_file(_path, _prefab);
        show_debug_message("[ROGUE][prefab] exported " + string(_prefab.id) + " -> " + _path);
    }

    return _prefab;
}

function rogue_room_export_current_room(_id, _file_name = undefined, _opts = undefined){
    if (is_undefined(_opts) || !is_struct(_opts)) _opts = {};
    if (!variable_struct_exists(_opts, "crop")) _opts.crop = false;
    if (!variable_struct_exists(_opts, "layers") && !variable_struct_exists(_opts, "export_all_tile_layers")) _opts.export_all_tile_layers = true;
    var _room_data = rogue_world_export_current_room_prefab(_id, undefined, _opts);
    if (!is_struct(_room_data)) return undefined;
    _room_data.format = "pokemon_rogue_room_v1";
    _room_data.display_name = variable_struct_exists(_opts, "display_name") ? string(_opts.display_name) : string(_id);
    _room_data.spawn_x = variable_struct_exists(_opts, "spawn_x") ? real(_opts.spawn_x) : 128;
    _room_data.spawn_y = variable_struct_exists(_opts, "spawn_y") ? real(_opts.spawn_y) : 128;
    _room_data.indoor = variable_struct_exists(_opts, "indoor") ? (_opts.indoor == true) : true;

    if (!is_undefined(_file_name)){
        var _path = rogue_room_data_path(_file_name);
        rogue_write_json_file(_path, _room_data);
        show_debug_message("[ROGUE][room] exported " + string(_room_data.id) + " -> " + _path);
    }
    return _room_data;
}

function rogue_room_export_current_room_dialog(_default_file = "rogue_room.json", _opts = undefined){
    var _path = "";
    try {
        _path = get_save_filename("Rogue Room JSON|*.json", string(_default_file));
    } catch (e_save_room_dialog) {
        _path = rogue_room_data_path(_default_file);
    }
    if (string_length(string(_path)) <= 0){
        show_debug_message("[ROGUE][room] export cancelled.");
        return undefined;
    }
    if (string_pos(".json", string_lower(string(_path))) <= 0) _path = string(_path) + ".json";
    var _id = rogue_world_file_stem(_path);
    return rogue_room_export_current_room(_id, _path, _opts);
}

function rogue_world_prefab_from_json(_json_text){
    var _data = json_parse(_json_text);
    if (!is_struct(_data)) return undefined;
    if (!variable_struct_exists(_data, "id")) _data.id = "loaded_prefab";
    if (!variable_struct_exists(_data, "tiles") || !is_array(_data.tiles)) _data.tiles = [];
    if (!variable_struct_exists(_data, "objects") || !is_array(_data.objects)) _data.objects = [];
    if (!variable_struct_exists(_data, "w")) _data.w = 4;
    if (!variable_struct_exists(_data, "h")) _data.h = 4;
    return _data;
}

function rogue_world_load_prefab_file(_file_name, _register = true){
    var _path = rogue_world_data_path(_file_name);
    if (!file_exists(_path)){
        show_debug_message("[ROGUE][prefab] missing file: " + _path);
        return undefined;
    }
    var _fh = file_text_open_read(_path);
    var _json = "";
    while (!file_text_eof(_fh)){
        _json += file_text_read_string(_fh);
        file_text_readln(_fh);
    }
    file_text_close(_fh);
    var _prefab = rogue_world_prefab_from_json(_json);
    if (_register && is_struct(_prefab)) rogue_world_register_prefab(_prefab);
    return _prefab;
}

function rogue_world_load_prefab_folder(_folder = "data/rogue_prefabs"){
    var _root = string(_folder);
    if (string_pos(":", _root) <= 0 && string_copy(_root, 1, 1) != "/" && string_copy(_root, 1, 1) != "\\"){
        _root = working_directory + "/" + _root;
    }
    var _count = 0;
    var _file = file_find_first(_root + "/*.json", 0);
    while (_file != ""){
        var _prefab = rogue_world_load_prefab_file(_root + "/" + _file, true);
        if (is_struct(_prefab)) _count += 1;
        _file = file_find_next();
    }
    file_find_close();
    show_debug_message("[ROGUE][prefab] loaded " + string(_count) + " prefab file(s) from " + _root);
    return _count;
}

function rogue_room_from_json(_json_text){
    var _data = json_parse(_json_text);
    if (!is_struct(_data)) return undefined;
    if (!variable_struct_exists(_data, "id")) _data.id = "rogue_room";
    if (!variable_struct_exists(_data, "tiles") || !is_array(_data.tiles)) _data.tiles = [];
    if (!variable_struct_exists(_data, "objects") || !is_array(_data.objects)) _data.objects = [];
    if (!variable_struct_exists(_data, "tile_size")) _data.tile_size = 16;
    if (!variable_struct_exists(_data, "w")) _data.w = max(1, ceil((variable_struct_exists(_data, "room_width_px") ? real(_data.room_width_px) : 256) / real(_data.tile_size)));
    if (!variable_struct_exists(_data, "h")) _data.h = max(1, ceil((variable_struct_exists(_data, "room_height_px") ? real(_data.room_height_px) : 256) / real(_data.tile_size)));
    if (!variable_struct_exists(_data, "room_width_px")) _data.room_width_px = real(_data.w) * real(_data.tile_size);
    if (!variable_struct_exists(_data, "room_height_px")) _data.room_height_px = real(_data.h) * real(_data.tile_size);
    if (!variable_struct_exists(_data, "display_name")) _data.display_name = string(_data.id);
    if (!variable_struct_exists(_data, "spawn_x")) _data.spawn_x = 128;
    if (!variable_struct_exists(_data, "spawn_y")) _data.spawn_y = 128;
    return _data;
}

function rogue_room_load_file(_file_name){
    var _path = rogue_room_data_path(_file_name);
    if (!file_exists(_path)){
        show_debug_message("[ROGUE][room] missing file: " + _path);
        return undefined;
    }
    var _fh = file_text_open_read(_path);
    var _json = "";
    while (!file_text_eof(_fh)){
        _json += file_text_read_string(_fh);
        file_text_readln(_fh);
    }
    file_text_close(_fh);
    return rogue_room_from_json(_json);
}

function rogue_room_prepare(_file_name, _spawn_x = undefined, _spawn_y = undefined){
    var _data = rogue_room_load_file(_file_name);
    if (!is_struct(_data)) return undefined;
    if (!is_undefined(_spawn_x) && is_real(_spawn_x)) _data.spawn_x = real(_spawn_x);
    if (!is_undefined(_spawn_y) && is_real(_spawn_y)) _data.spawn_y = real(_spawn_y);
    global.ROGUE_ROOM_PENDING = _data;
    return _data;
}

function rogue_room_clear_runtime(){
    var _layers = rogue_world_layer_names();
    for (var _li = 0; _li < array_length(_layers); ++_li){
        var _tm = rogue_tilemap_for_layer(_layers[_li]);
        if (_tm == -1) continue;
        var _tw = max(1, floor(room_width / 16));
        var _th = max(1, floor(room_height / 16));
        try { _tw = tilemap_get_width(_tm); } catch (e_room_clear_w) {}
        try { _th = tilemap_get_height(_tm); } catch (e_room_clear_h) {}
        for (var _y = 0; _y < _th; ++_y){
            for (var _x = 0; _x < _tw; ++_x){
                tilemap_set(_tm, 0, _x, _y);
            }
        }
    }

    for (var _i = instance_number(all) - 1; _i >= 0; --_i){
        var _inst = instance_find(all, _i);
        if (_inst == noone) continue;
        if (variable_instance_exists(_inst, "rogue_room_generated") && variable_instance_get(_inst, "rogue_room_generated") == true) instance_destroy(_inst);
    }
}

function rogue_room_apply(_data){
    if (!is_struct(_data)) return false;
    rogue_world_ensure_exported_layers(_data);
    rogue_room_clear_runtime();

    var _tiles = variable_struct_exists(_data, "tiles") && is_array(_data.tiles) ? _data.tiles : [];
    for (var _ti = 0; _ti < array_length(_tiles); ++_ti){
        var _t = _tiles[_ti];
        if (!is_struct(_t)) continue;
        var _layer = variable_struct_exists(_t, "role") ? rogue_world_layer_name(_t.role) : (variable_struct_exists(_t, "layer") ? string(_t.layer) : rogue_world_layer_name("ground"));
        var _tx = variable_struct_exists(_t, "x") ? floor(_t.x) : 0;
        var _ty = variable_struct_exists(_t, "y") ? floor(_t.y) : 0;
        if (variable_struct_exists(_t, "data")) rogue_tilemap_set_data_layer(_layer, _tx, _ty, _t.data);
        else rogue_tilemap_set_layer(_layer, _tx, _ty, variable_struct_exists(_t, "tile") ? _t.tile : 0);
        if (variable_struct_exists(_t, "solid") && _t.solid == true) rogue_tilemap_set_role("collision", _tx, _ty, 1);
    }

    var _objs = variable_struct_exists(_data, "objects") && is_array(_data.objects) ? _data.objects : [];
    for (var _oi = 0; _oi < array_length(_objs); ++_oi){
        var _o = _objs[_oi];
        if (!is_struct(_o)) continue;
        var _object_index = variable_struct_exists(_o, "object") ? _o.object : -1;
        if (is_string(_object_index)) _object_index = rogue_world_prefab_object_index(_object_index);
        if (_object_index == -1 && variable_struct_exists(_o, "object_name")) _object_index = rogue_world_prefab_object_index(_o.object_name);
        if (_object_index == -1) continue;
        var _inst_layer = variable_struct_exists(_o, "layer") ? string(_o.layer) : "Instances";
        var _inst = instance_create_layer(variable_struct_exists(_o, "x") ? real(_o.x) : 0, variable_struct_exists(_o, "y") ? real(_o.y) : 0, _inst_layer, _object_index);
        if (_inst != noone){
            variable_instance_set(_inst, "rogue_room_generated", true);
            rogue_world_apply_instance_snapshot(_inst, _o);
        }
    }

    global.ROGUE_ROOM_BOUNDS = {
        active: true,
        room: room,
        w: max(16, real(_data.room_width_px)),
        h: max(16, real(_data.room_height_px)),
        display_name: string(_data.display_name)
    };
    if (!is_undefined(world_room_register)) world_room_register(room, string(_data.display_name), variable_global_exists("_REGIONMUSIC") ? global._REGIONMUSIC : noone, true);
    if (!is_undefined(wc_bind_layers)){
        wc_bind_layers([rogue_world_layer_name("_solid"), rogue_world_layer_name("collision")]);
        wc_set_solids([oNpc, oFieldMoveProp, oitem]);
    }
    return true;
}

function rogue_room_runtime_start(){
    if (!variable_global_exists("ROGUE_ROOM_PENDING") || !is_struct(global.ROGUE_ROOM_PENDING)){
        global.ROGUE_ROOM_BOUNDS = { active:true, room:room, w:room_width, h:room_height, display_name:"Rogue Room" };
        return false;
    }
    return rogue_room_apply(global.ROGUE_ROOM_PENDING);
}

function rogue_room_enter(_file_name, _spawn_x = undefined, _spawn_y = undefined){
    var _data = rogue_room_prepare(_file_name, _spawn_x, _spawn_y);
    if (!is_struct(_data)) return false;
    return world_warp_to(rm_rogue_building, real(_data.spawn_x), real(_data.spawn_y), {
        transition_style: "emerald_fade_black",
        show_route: true,
        facing: 2
    });
}

function rogue_world_register_biome(_id, _def){
    var _R = rogue_world_ensure();
    if (!is_struct(_def)) _def = {};
    var _key = string_lower(string(_id));
    variable_struct_set(_def, "id", _key);
    if (!variable_struct_exists(_def, "weight")) _def.weight = 1;
    if (!variable_struct_exists(_def, "temperature_min")) _def.temperature_min = 0;
    if (!variable_struct_exists(_def, "temperature_max")) _def.temperature_max = 1;
    if (!variable_struct_exists(_def, "moisture_min")) _def.moisture_min = 0;
    if (!variable_struct_exists(_def, "moisture_max")) _def.moisture_max = 1;
    variable_struct_set(_R.biomes, _key, _def);
    global.ROGUE_WORLD = _R;
    return _def;
}

function rogue_world_biome(_id){
    var _R = rogue_world_ensure();
    var _key = string_lower(string(_id));
    if (variable_struct_exists(_R.biomes, _key)) return variable_struct_get(_R.biomes, _key);
    if (variable_struct_exists(_R.biomes, string(_R.default_biome))) return variable_struct_get(_R.biomes, string(_R.default_biome));
    return { id:"grassland", floor_tile:0, wall_tile:0, solid_tile:0, solid_chance:0, decor:[] };
}

function rogue_world_biome_encounter_region(_biome_id, _def = undefined){
    var _key = string_lower(string(_biome_id));
    if (is_struct(_def) && variable_struct_exists(_def, "encounter_region_key")) return string_lower(string(_def.encounter_region_key));
    return "rogue_" + _key;
}

function rogue_world_biome_encounter_habitat(_biome_id, _def = undefined){
    if (is_struct(_def) && variable_struct_exists(_def, "encounter_habitat")) return string_lower(string(_def.encounter_habitat));
    return string_lower(string(_biome_id));
}

function rogue_world_biome_encounter_area(_biome_id, _def = undefined){
    if (is_struct(_def) && variable_struct_exists(_def, "battle_area_type")) return string(_def.battle_area_type);
    if (is_struct(_def) && variable_struct_exists(_def, "encounter_area_type")) return string(_def.encounter_area_type);
    return "grassy";
}

function rogue_world_encounter_roll_from_table(_table, _battle_format, _level_min, _level_max){
    if (is_undefined(__overworld_encounter_pick_from_table)) return undefined;
    if (!is_array(_table) || array_length(_table) <= 0) return undefined;

    var _count = (string_lower(string(_battle_format)) == "double") ? 2 : 1;
    var _species = [];
    var _levels = [];
    for (var _i = 0; _i < _count; ++_i){
        var _pick = __overworld_encounter_pick_from_table(_table, _level_min, _level_max);
        if (!is_struct(_pick)) return undefined;
        array_push(_species, variable_struct_get(_pick, "species_id"));
        array_push(_levels, variable_struct_get(_pick, "level"));
    }

    return {
        species: (_count == 1) ? _species[0] : _species,
        levels: (_count == 1) ? _levels[0] : _levels
    };
}

function rogue_world_apply_encounter_field_effects(_pid, _chance){
    var _out = { blocked:false, chance:real(_chance) };
    if (!variable_global_exists("BAG_FIELD_EFFECTS") || !is_array(global.BAG_FIELD_EFFECTS)) return _out;
    if (_pid < 0 || _pid >= array_length(global.BAG_FIELD_EFFECTS)) return _out;
    var _field_fx = global.BAG_FIELD_EFFECTS[_pid];
    if (!is_struct(_field_fx)) return _out;

    if (variable_struct_exists(_field_fx, "repel_steps") && is_real(variable_struct_get(_field_fx, "repel_steps")) && variable_struct_get(_field_fx, "repel_steps") > 0){
        variable_struct_set(_field_fx, "repel_steps", max(0, floor(variable_struct_get(_field_fx, "repel_steps")) - 1));
        global.BAG_FIELD_EFFECTS[_pid] = _field_fx;
        _out.blocked = true;
        return _out;
    }

    if (variable_struct_exists(_field_fx, "encounter_rate_steps") && is_real(variable_struct_get(_field_fx, "encounter_rate_steps")) && variable_struct_get(_field_fx, "encounter_rate_steps") > 0){
        var _mult = (variable_struct_exists(_field_fx, "encounter_rate_multiplier") && is_real(variable_struct_get(_field_fx, "encounter_rate_multiplier"))) ? real(variable_struct_get(_field_fx, "encounter_rate_multiplier")) : 1;
        _out.chance *= max(0, _mult);
        variable_struct_set(_field_fx, "encounter_rate_steps", max(0, floor(variable_struct_get(_field_fx, "encounter_rate_steps")) - 1));
        global.BAG_FIELD_EFFECTS[_pid] = _field_fx;
    }
    return _out;
}

function rogue_world_encounter_visible_owner(){
    var _R = rogue_world_ensure();
    if (instance_exists(_R.encounter_visible_owner)) return _R.encounter_visible_owner;
    if (room != _R.room_id) return noone;

    var _owner = instance_create_layer(0, 0, "Instances", obush);
    if (_owner == noone) return noone;
    variable_instance_set(_owner, "rogue_generated", true);
    variable_instance_set(_owner, "visible", false);
    variable_instance_set(_owner, "encounter_enabled", false);
    variable_instance_set(_owner, "encounter_mode", "new");
    variable_instance_set(_owner, "encounter_region_key", "rogue_grassland");
    variable_instance_set(_owner, "encounter_habitat", "grass");
    variable_instance_set(_owner, "encounter_area_type", "grassy");
    variable_instance_set(_owner, "encounter_battle_format", "single");
    variable_instance_set(_owner, "encounter_double_chance", 0);
    variable_instance_set(_owner, "encounter_level_min", max(1, floor(_R.encounter_default_level_min)));
    variable_instance_set(_owner, "encounter_level_max", max(1, floor(_R.encounter_default_level_max)));
    variable_instance_set(_owner, "encounter_visible_camera_only", false);
    variable_instance_set(_owner, "encounter_visible_grid_size", max(1, floor(_R.tile_size)));
    variable_instance_set(_owner, "_encounter_visible_npc", noone);
    variable_instance_set(_owner, "_encounter_visible_npcs", []);
    variable_instance_set(_owner, "_encounter_visible", undefined);

    var _chunk_px = _R.chunk_tiles * _R.tile_size;
    variable_instance_set(_owner, "bbox_left", 0);
    variable_instance_set(_owner, "bbox_top", 0);
    variable_instance_set(_owner, "bbox_right", _chunk_px);
    variable_instance_set(_owner, "bbox_bottom", _chunk_px);

    _R.encounter_visible_owner = _owner;
    global.ROGUE_WORLD = _R;
    return _owner;
}

function rogue_world_visible_owner_count(_owner){
    if (!instance_exists(_owner)) return 0;
    if (!is_undefined(__overworld_encounter_visible_npc_count)) return __overworld_encounter_visible_npc_count(_owner);
    var _live = [];
    if (variable_instance_exists(_owner, "_encounter_visible_npcs") && is_array(variable_instance_get(_owner, "_encounter_visible_npcs"))){
        var _arr = variable_instance_get(_owner, "_encounter_visible_npcs");
        for (var _i = 0; _i < array_length(_arr); ++_i){
            if (_arr[_i] != noone && instance_exists(_arr[_i])) array_push(_live, _arr[_i]);
        }
    }
    variable_instance_set(_owner, "_encounter_visible_npcs", _live);
    variable_instance_set(_owner, "_encounter_visible_npc", array_length(_live) > 0 ? _live[0] : noone);
    return array_length(_live);
}

function rogue_world_visible_spawn_reset_timer(){
    var _R = rogue_world_ensure();
    var _min = max(1, floor(_R.encounter_visible_spawn_min));
    var _max = max(_min, floor(_R.encounter_visible_spawn_max));
    _R.encounter_visible_spawn_timer = irandom_range(_min, _max);
    global.ROGUE_WORLD = _R;
}

function rogue_world_visible_tile_data(_tx, _ty){
    var _R = rogue_world_ensure();
    var _world_tx = floor(_R.origin_tile_x) + floor(_tx);
    var _world_ty = floor(_R.origin_tile_y) + floor(_ty);
    var _biome_id = rogue_world_biome_id_at(_world_tx, _world_ty);
    var _biome = rogue_world_biome(_biome_id);
    if (is_struct(_biome) && variable_struct_exists(_biome, "encounter_enabled") && _biome.encounter_enabled != true) return undefined;
    var _path_ok = variable_struct_exists(_R, "encounter_path_enabled") && _R.encounter_path_enabled == true;
    if (is_struct(_biome) && variable_struct_exists(_biome, "encounter_path_enabled")) _path_ok = (_biome.encounter_path_enabled == true);
    if (!_path_ok && rogue_world_should_path(_world_tx, _world_ty)) return undefined;
    if (rogue_world_point_is_blocked((floor(_tx) + 0.5) * _R.tile_size, (floor(_ty) + 0.5) * _R.tile_size)) return undefined;

    var _region_key = rogue_world_biome_encounter_region(_biome_id, _biome);
    var _habitat = rogue_world_biome_encounter_habitat(_biome_id, _biome);
    var _table = __overworld_encounter_table_for(_region_key, _habitat);
    if (!is_array(_table) || array_length(_table) <= 0) return undefined;

    return {
        biome_id: _biome_id,
        biome: _biome,
        region_key: _region_key,
        habitat: _habitat,
        table: _table,
        area_type: rogue_world_biome_encounter_area(_biome_id, _biome),
        level_min: is_struct(_biome) && variable_struct_exists(_biome, "encounter_level_min") ? max(1, floor(_biome.encounter_level_min)) : max(1, floor(_R.encounter_default_level_min)),
        level_max: is_struct(_biome) && variable_struct_exists(_biome, "encounter_level_max") ? max(1, floor(_biome.encounter_level_max)) : max(1, floor(_R.encounter_default_level_max)),
        battle_format: is_struct(_biome) && variable_struct_exists(_biome, "encounter_battle_format") ? string(_biome.encounter_battle_format) : "single",
        double_chance: is_struct(_biome) && variable_struct_exists(_biome, "encounter_double_chance") ? real(_biome.encounter_double_chance) : 0,
        shiny_chance: is_struct(_biome) && variable_struct_exists(_biome, "encounter_shiny_chance") ? real(_biome.encounter_shiny_chance) : (variable_global_exists("OVERWORLD_SHINY_CHANCE") ? real(global.OVERWORLD_SHINY_CHANCE) : 1 / 4096)
    };
}

function rogue_world_configure_bush_encounter(_bush){
    if (!instance_exists(_bush)) return false;
    var _R = rogue_world_ensure();
    var _tx = floor(real(variable_instance_get(_bush, "x")) / max(1, real(_R.tile_size)));
    var _ty = floor(real(variable_instance_get(_bush, "y")) / max(1, real(_R.tile_size)));
    var _data = rogue_world_visible_tile_data(_tx, _ty);
    if (!is_struct(_data)){
        variable_instance_set(_bush, "encounter_enabled", false);
        return false;
    }

    variable_instance_set(_bush, "encounter_enabled", true);
    variable_instance_set(_bush, "encounter_mode", "new");
    variable_instance_set(_bush, "encounter_region_key", string(_data.region_key));
    variable_instance_set(_bush, "encounter_habitat", string(_data.habitat));
    variable_instance_set(_bush, "encounter_area_type", string(_data.area_type));
    variable_instance_set(_bush, "encounter_level_min", floor(_data.level_min));
    variable_instance_set(_bush, "encounter_level_max", floor(_data.level_max));
    variable_instance_set(_bush, "encounter_battle_format", string(_data.battle_format));
    variable_instance_set(_bush, "encounter_double_chance", real(_data.double_chance));
    variable_instance_set(_bush, "encounter_shiny_chance", real(_data.shiny_chance));
    variable_instance_set(_bush, "encounter_table", _data.table);
    variable_instance_set(_bush, "rogue_biome", string(_data.biome_id));
    return true;
}

function rogue_world_camera_rect(_pad_tiles = 5){
    var _R = rogue_world_ensure();
    var _view_left = 0;
    var _view_top = 0;
    var _view_right = _R.chunk_tiles * _R.tile_size;
    var _view_bottom = _R.chunk_tiles * _R.tile_size;
    var _cam = (view_enabled && view_visible[0]) ? view_camera[0] : -1;
    if (_cam != -1){
        _view_left = camera_get_view_x(_cam);
        _view_top = camera_get_view_y(_cam);
        _view_right = _view_left + camera_get_view_width(_cam);
        _view_bottom = _view_top + camera_get_view_height(_cam);
    } else {
        var _p0 = player_by_pid(0);
        if (_p0 != noone){
            _view_left = _p0.x - 160;
            _view_top = _p0.y - 120;
            _view_right = _p0.x + 160;
            _view_bottom = _p0.y + 120;
        }
    }
    var _pad = max(0, floor(_pad_tiles)) * _R.tile_size;
    return { left:_view_left - _pad, top:_view_top - _pad, right:_view_right + _pad, bottom:_view_bottom + _pad };
}

function rogue_world_try_visible_bush_spawn(){
    if (is_undefined(__overworld_encounter_visible_spawn)) return false;
    var _rect = rogue_world_camera_rect(5);
    var _candidates = [];
    var _count = instance_number(obush);
    for (var _i = 0; _i < _count; ++_i){
        var _bush = instance_find(obush, _i);
        if (_bush == noone) continue;
        if (variable_instance_exists(_bush, "rogue_generated") && variable_instance_get(_bush, "rogue_generated") == true) continue;
        var _bx = variable_instance_get(_bush, "x");
        var _by = variable_instance_get(_bush, "y");
        if (_bx < _rect.left || _bx > _rect.right || _by < _rect.top || _by > _rect.bottom) continue;
        if (rogue_world_configure_bush_encounter(_bush)) array_push(_candidates, _bush);
    }
    if (array_length(_candidates) <= 0) return false;
    var _pick = _candidates[irandom(array_length(_candidates) - 1)];
    return __overworld_encounter_visible_spawn(_pick);
}

function rogue_world_try_visible_spawn(){
    var _R = rogue_world_ensure();
    if (!variable_struct_exists(_R, "encounter_enabled") || _R.encounter_enabled != true) return false;
    if (!variable_struct_exists(_R, "encounter_visible_enabled") || _R.encounter_visible_enabled != true) return false;
    if (is_undefined(__overworld_encounter_pick_from_table) || is_undefined(__overworld_encounter_pokemon_npc_pick_target) || is_undefined(__overworld_encounter_pokemon_npc_sprite_update)) return false;

    if (!variable_struct_exists(_R, "encounter_visible_loose_spawns") || _R.encounter_visible_loose_spawns != true){
        return rogue_world_try_visible_bush_spawn();
    }

    var _owner = rogue_world_encounter_visible_owner();
    if (!instance_exists(_owner)) return false;
    if (rogue_world_visible_owner_count(_owner) >= max(0, floor(_R.encounter_visible_max_active))) return false;

    var _data = undefined;
    var _tx = 0;
    var _ty = 0;
    var _view_left = 0;
    var _view_top = 0;
    var _view_right = _R.chunk_tiles * _R.tile_size;
    var _view_bottom = _R.chunk_tiles * _R.tile_size;
    var _cam = (view_enabled && view_visible[0]) ? view_camera[0] : -1;
    if (_cam != -1){
        _view_left = camera_get_view_x(_cam);
        _view_top = camera_get_view_y(_cam);
        _view_right = _view_left + camera_get_view_width(_cam);
        _view_bottom = _view_top + camera_get_view_height(_cam);
    } else {
        var _p0 = player_by_pid(0);
        if (_p0 != noone){
            _view_left = _p0.x - 160;
            _view_top = _p0.y - 120;
            _view_right = _p0.x + 160;
            _view_bottom = _p0.y + 120;
        }
    }
    var _pad = _R.tile_size * 5;
    var _min_tx = clamp(floor((_view_left - _pad) / _R.tile_size), 2, max(2, floor(_R.chunk_tiles) - 3));
    var _max_tx = clamp(floor((_view_right + _pad) / _R.tile_size), _min_tx, max(2, floor(_R.chunk_tiles) - 3));
    var _min_ty = clamp(floor((_view_top - _pad) / _R.tile_size), 2, max(2, floor(_R.chunk_tiles) - 3));
    var _max_ty = clamp(floor((_view_bottom + _pad) / _R.tile_size), _min_ty, max(2, floor(_R.chunk_tiles) - 3));
    for (var _try = 0; _try < 32; ++_try){
        _tx = irandom_range(_min_tx, _max_tx);
        _ty = irandom_range(_min_ty, _max_ty);
        _data = rogue_world_visible_tile_data(_tx, _ty);
        if (is_struct(_data)) break;
    }
    if (!is_struct(_data)) return false;

    var _level_min = max(1, floor(_data.level_min));
    var _level_max = max(_level_min, floor(_data.level_max));
    var _pick = __overworld_encounter_pick_from_table(_data.table, _level_min, _level_max);
    if (!is_struct(_pick)) return false;

    var _x = (_tx + 0.5) * _R.tile_size;
    var _y = (_ty + 0.5) * _R.tile_size;
    var _npc = instance_create_layer(_x, _y, "Instances", oNpc);
    if (_npc == noone) return false;

    var _radius_px = max(1, floor(_R.encounter_visible_patch_radius_tiles)) * _R.tile_size;
    var _chunk_px = _R.chunk_tiles * _R.tile_size;
    variable_instance_set(_npc, "rogue_generated", true);
    variable_instance_set(_npc, "encounter_pokemon", true);
    variable_instance_set(_npc, "world_solid", false);
    variable_instance_set(_npc, "encounter_owner", _owner);
    variable_instance_set(_npc, "encounter_source", "rogue_visible_bush_npc");
    variable_instance_set(_npc, "encounter_species_id", variable_struct_get(_pick, "species_id"));
    variable_instance_set(_npc, "encounter_level", variable_struct_get(_pick, "level"));
    variable_instance_set(_npc, "encounter_shiny", random(1) < real(_data.shiny_chance));
    variable_instance_set(_npc, "encounter_region_key", string(_data.region_key));
    variable_instance_set(_npc, "encounter_habitat", string(_data.habitat));
    variable_instance_set(_npc, "encounter_area_type", string(_data.area_type));
    variable_instance_set(_npc, "encounter_level_min", _level_min);
    variable_instance_set(_npc, "encounter_level_max", _level_max);
    variable_instance_set(_npc, "encounter_battle_format", string(_data.battle_format));
    variable_instance_set(_npc, "encounter_double_chance", real(_data.double_chance));
    variable_instance_set(_npc, "encounter_shiny_chance", real(_data.shiny_chance));
    variable_instance_set(_npc, "encounter_table", _data.table);
    variable_instance_set(_npc, "rogue_biome", string(_data.biome_id));
    variable_instance_set(_npc, "encounter_lifetime", irandom_range(540, 980));
    variable_instance_set(_npc, "encounter_fade_frames", 45);
    variable_instance_set(_npc, "encounter_dir", "DOWN");
    variable_instance_set(_npc, "encounter_bounds_left", clamp(_x - _radius_px, 0, _chunk_px));
    variable_instance_set(_npc, "encounter_bounds_top", clamp(_y - _radius_px, 0, _chunk_px));
    variable_instance_set(_npc, "encounter_bounds_right", clamp(_x + _radius_px, 0, _chunk_px - 32));
    variable_instance_set(_npc, "encounter_bounds_bottom", clamp(_y + _radius_px, 0, _chunk_px - 32));
    variable_instance_set(_npc, "encounter_grid_size", max(1, floor(_R.tile_size)));
    variable_instance_set(_npc, "wander_enabled", true);
    variable_instance_set(_npc, "wander_speed", 0.85);
    variable_instance_set(_npc, "wander_pause_min", 20);
    variable_instance_set(_npc, "wander_pause_max", 70);
    variable_instance_set(_npc, "wander_pause", 0);
    variable_instance_set(_npc, "wander_target_x", _x);
    variable_instance_set(_npc, "wander_target_y", _y);
    variable_instance_set(_npc, "interact_radius", 0);
    variable_instance_set(_npc, "dialog_text", "");
    variable_instance_set(_npc, "image_speed", 0);
    variable_instance_set(_npc, "image_alpha", 1);
    variable_instance_set(_npc, "image_xscale", 0.67);
    variable_instance_set(_npc, "image_yscale", 0.67);
    variable_instance_set(_npc, "depth", -(_y + 16));

    var _live = variable_instance_exists(_owner, "_encounter_visible_npcs") && is_array(variable_instance_get(_owner, "_encounter_visible_npcs")) ? variable_instance_get(_owner, "_encounter_visible_npcs") : [];
    array_push(_live, _npc);
    variable_instance_set(_owner, "_encounter_visible_npcs", _live);
    variable_instance_set(_owner, "_encounter_visible_npc", _live[0]);
    __overworld_encounter_pokemon_npc_pick_target(_npc);
    __overworld_encounter_pokemon_npc_sprite_update(_npc, false);
    return true;
}

function rogue_world_try_encounter_for_player(_pid){
    var _R = rogue_world_ensure();
    if (!variable_struct_exists(_R, "encounter_hidden_enabled") || _R.encounter_hidden_enabled != true) return false;
    if (!variable_struct_exists(_R, "encounter_enabled") || _R.encounter_enabled != true) return false;
    if (is_undefined(overworld_encounter_can_start) || is_undefined(__overworld_encounter_table_for) || is_undefined(battle_open)) return false;
    if (!overworld_encounter_can_start(_pid)) return false;

    var _pl = player_by_pid(_pid);
    if (_pl == noone) return false;
    if (variable_instance_exists(_pl, "grid") && is_struct(variable_instance_get(_pl, "grid"))){
        var _grid = variable_instance_get(_pl, "grid");
        if (variable_struct_exists(_grid, "state") && string(variable_struct_get(_grid, "state")) != "move") return false;
    }

    var _tile_x = floor(real(_pl.x) / max(1, real(_R.tile_size)));
    var _tile_y = floor(real(_pl.y) / max(1, real(_R.tile_size)));
    var _world_tx = floor(_R.origin_tile_x) + _tile_x;
    var _world_ty = floor(_R.origin_tile_y) + _tile_y;
    var _tile_key = string(_world_tx) + "," + string(_world_ty);
    if (!is_array(_R.encounter_last_tiles) || array_length(_R.encounter_last_tiles) < 2) _R.encounter_last_tiles = ["", ""];
    var _last_key = _R.encounter_last_tiles[_pid];
    _R.encounter_last_tiles[_pid] = _tile_key;
    global.ROGUE_WORLD = _R;
    if (_last_key == "" || _last_key == _tile_key) return false;

    var _biome_id = rogue_world_biome_id_at(_world_tx, _world_ty);
    var _biome = rogue_world_biome(_biome_id);
    if (is_struct(_biome) && variable_struct_exists(_biome, "encounter_enabled") && _biome.encounter_enabled != true) return false;
    var _path_ok = variable_struct_exists(_R, "encounter_path_enabled") && _R.encounter_path_enabled == true;
    if (is_struct(_biome) && variable_struct_exists(_biome, "encounter_path_enabled")) _path_ok = (_biome.encounter_path_enabled == true);
    if (!_path_ok && rogue_world_should_path(_world_tx, _world_ty)) return false;

    var _region_key = rogue_world_biome_encounter_region(_biome_id, _biome);
    var _habitat = rogue_world_biome_encounter_habitat(_biome_id, _biome);
    var _table = __overworld_encounter_table_for(_region_key, _habitat);
    if (!is_array(_table) || array_length(_table) <= 0) return false;

    var _chance = is_struct(_biome) && variable_struct_exists(_biome, "encounter_chance") ? real(_biome.encounter_chance) : real(_R.encounter_default_chance);
    var _field = rogue_world_apply_encounter_field_effects(_pid, _chance);
    if (variable_struct_get(_field, "blocked") == true) return false;
    _chance = real(variable_struct_get(_field, "chance"));
    if (_chance <= 0 || random(1) > _chance) return false;

    var _level_min = is_struct(_biome) && variable_struct_exists(_biome, "encounter_level_min") ? max(1, floor(_biome.encounter_level_min)) : max(1, floor(_R.encounter_default_level_min));
    var _level_max = is_struct(_biome) && variable_struct_exists(_biome, "encounter_level_max") ? max(_level_min, floor(_biome.encounter_level_max)) : max(_level_min, floor(_R.encounter_default_level_max));
    var _battle_format = is_struct(_biome) && variable_struct_exists(_biome, "encounter_battle_format") ? string(_biome.encounter_battle_format) : "single";
    var _double_chance = is_struct(_biome) && variable_struct_exists(_biome, "encounter_double_chance") ? real(_biome.encounter_double_chance) : 0;
    if (_battle_format != "double" && _double_chance > 0 && random(1) < _double_chance) _battle_format = "double";

    var _coop_requested = (multiplayer_queue_mode() == "coop");
    var _assist_pid = _coop_requested ? multiplayer_find_nearby_assist_pid(_pid) : -1;
    var _coop = (_assist_pid >= 0);
    if (_coop_requested) _battle_format = _coop ? "double" : "single";

    var _encounter_roll = rogue_world_encounter_roll_from_table(_table, _battle_format, _level_min, _level_max);
    if (!is_struct(_encounter_roll)) return false;

    var _E_lock = overworld_encounter_tables_init();
    variable_struct_set(_E_lock, "pending", true);
    global.OVERWORLD_ENCOUNTERS = _E_lock;

    var _opts = {
        battle_type: "wild",
        battle_format: _battle_format,
        encounter_source: "rogue_world",
        encounter_region_key: _region_key,
        encounter_habitat: _habitat,
        rogue_biome: string(_biome_id)
    };
    variable_struct_set(_opts, "enemy_species", variable_struct_get(_encounter_roll, "species"));
    variable_struct_set(_opts, "enemy_levels", variable_struct_get(_encounter_roll, "levels"));

    var _shiny_chance = variable_global_exists("OVERWORLD_SHINY_CHANCE") ? real(global.OVERWORLD_SHINY_CHANCE) : 1 / 4096;
    if (is_struct(_biome) && variable_struct_exists(_biome, "encounter_shiny_chance")) _shiny_chance = real(_biome.encounter_shiny_chance);
    if (_shiny_chance > 0){
        var _species_roll = variable_struct_get(_encounter_roll, "species");
        if (is_array(_species_roll)){
            var _shinies = [];
            for (var _si = 0; _si < array_length(_species_roll); ++_si) array_push(_shinies, random(1) < _shiny_chance);
            variable_struct_set(_opts, "enemy_shiny", _shinies);
        } else {
            variable_struct_set(_opts, "enemy_shiny", random(1) < _shiny_chance);
        }
    }

    var _open_level = irandom_range(_level_min, _level_max);
    var _levels_roll = variable_struct_get(_encounter_roll, "levels");
    if (!is_array(_levels_roll) && is_real(_levels_roll)) _open_level = max(1, floor(_levels_roll));

    var _opts_single = {
        battle_type: "wild",
        battle_format: "single",
        encounter_source: "rogue_world",
        encounter_region_key: _region_key,
        encounter_habitat: _habitat,
        rogue_biome: string(_biome_id)
    };
    var _single_species = variable_struct_get(_encounter_roll, "species");
    if (is_array(_single_species) && array_length(_single_species) > 0) _single_species = _single_species[0];
    var _single_levels = variable_struct_get(_encounter_roll, "levels");
    if (is_array(_single_levels) && array_length(_single_levels) > 0) _single_levels = _single_levels[0];
    variable_struct_set(_opts_single, "enemy_species", _single_species);
    variable_struct_set(_opts_single, "enemy_levels", _single_levels);
    if (variable_struct_exists(_opts, "enemy_shiny")){
        var _single_shiny = variable_struct_get(_opts, "enemy_shiny");
        if (is_array(_single_shiny) && array_length(_single_shiny) > 0) _single_shiny = _single_shiny[0];
        variable_struct_set(_opts_single, "enemy_shiny", _single_shiny);
    }
    if (is_real(_single_levels)) _open_level = max(1, floor(_single_levels));

    if (_coop){
        _opts.coop_enabled = true;
        _opts.player_pids = [_pid, _assist_pid];
    }

    if (_pl != noone && !is_undefined(player_force_stand_still)) player_force_stand_still(_pl);
    var _area_type = rogue_world_biome_encounter_area(_biome_id, _biome);
    if (_coop){
        var _assist_player = player_by_pid(_assist_pid);
        if (_assist_player != noone && !is_undefined(player_force_stand_still)) player_force_stand_still(_assist_player);
        if (multiplayer_request_wild_assist_battle(_pid, _assist_pid, _open_level, _area_type, _opts_single, _opts)) return true;
        _opts = _opts_single;
        _battle_format = "single";
    }

    battle_open(_pid, _open_level, _area_type, _opts);
    if (!is_undefined(battle_is_open) && battle_is_open(_pid)) return true;

    var _E_unlock = overworld_encounter_tables_init();
    variable_struct_set(_E_unlock, "pending", false);
    global.OVERWORLD_ENCOUNTERS = _E_unlock;
    return false;
}

function rogue_world_update_encounters(){
    var _R = rogue_world_ensure();
    if (room != _R.room_id || !_R.active) return false;
    if (!variable_struct_exists(_R, "encounter_enabled") || _R.encounter_enabled != true) return false;
    if (!is_array(_R.encounter_cooldowns) || array_length(_R.encounter_cooldowns) < 2) _R.encounter_cooldowns = [0, 0];

    if (variable_struct_exists(_R, "encounter_visible_enabled") && _R.encounter_visible_enabled == true){
        if (_R.encounter_visible_spawn_timer > 0){
            _R.encounter_visible_spawn_timer -= 1;
            global.ROGUE_WORLD = _R;
        } else {
            if (rogue_world_try_visible_spawn()) rogue_world_visible_spawn_reset_timer();
            else {
                _R = rogue_world_ensure();
                _R.encounter_visible_spawn_timer = max(15, floor(_R.encounter_visible_spawn_min / 2));
                global.ROGUE_WORLD = _R;
            }
        }
    }

    if (!variable_struct_exists(_R, "encounter_hidden_enabled") || _R.encounter_hidden_enabled != true) return false;

    var _pids = [0, 1];
    for (var _i = 0; _i < array_length(_pids); ++_i){
        var _pid = _pids[_i];
        if (_pid == 1 && !multiplayer_player_joined(1)) continue;
        if (!is_real(_R.encounter_cooldowns[_pid])) _R.encounter_cooldowns[_pid] = 0;
        if (_R.encounter_cooldowns[_pid] > 0){
            _R.encounter_cooldowns[_pid] -= 1;
            global.ROGUE_WORLD = _R;
            continue;
        }
        if (rogue_world_try_encounter_for_player(_pid)){
            _R = rogue_world_ensure();
            _R.encounter_cooldowns[_pid] = max(1, floor(_R.encounter_cooldown_frames));
            global.ROGUE_WORLD = _R;
            return true;
        }
        _R = rogue_world_ensure();
    }

    global.ROGUE_WORLD = _R;
    return false;
}

function rogue_world_register_prefab(_def){
    var _R = rogue_world_ensure();
    if (!is_struct(_def)) return false;
    if (!variable_struct_exists(_def, "id")) _def.id = "prefab_" + string(array_length(_R.prefabs));
    if (!variable_struct_exists(_def, "type")) _def.type = variable_struct_exists(_def, "kind") ? string(_def.kind) : "nature";
    if (!variable_struct_exists(_def, "tags") || !is_array(_def.tags)) _def.tags = [];
    if (!variable_struct_exists(_def, "w")) _def.w = 4;
    if (!variable_struct_exists(_def, "h")) _def.h = 4;
    if (!variable_struct_exists(_def, "weight")) _def.weight = 1;
    if (!variable_struct_exists(_def, "biomes")) _def.biomes = [];
    if (!variable_struct_exists(_def, "spawn_chance")) _def.spawn_chance = 0.22;
    if (!variable_struct_exists(_def, "min_per_chunk")) _def.min_per_chunk = 0;
    if (!variable_struct_exists(_def, "max_per_chunk")) _def.max_per_chunk = 1;
    if (!variable_struct_exists(_def, "tiles")) _def.tiles = [];
    if (!variable_struct_exists(_def, "objects")) _def.objects = [];
    for (var _i = 0; _i < array_length(_R.prefabs); ++_i){
        var _existing = _R.prefabs[_i];
        if (is_struct(_existing) && variable_struct_exists(_existing, "id") && string(_existing.id) == string(_def.id)){
            _R.prefabs[_i] = _def;
            global.ROGUE_WORLD = _R;
            return true;
        }
    }
    array_push(_R.prefabs, _def);
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_register_reserved_zone(_chunk_x, _chunk_y, _w_chunks, _h_chunks, _id = ""){
    var _R = rogue_world_ensure();
    array_push(_R.reserved_zones, {
        id: string(_id),
        chunk_x: floor(_chunk_x),
        chunk_y: floor(_chunk_y),
        w: max(1, floor(_w_chunks)),
        h: max(1, floor(_h_chunks))
    });
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_chunk_reserved(_chunk_x, _chunk_y){
    var _R = rogue_world_ensure();
    for (var _i = 0; _i < array_length(_R.reserved_zones); ++_i){
        var _z = _R.reserved_zones[_i];
        if (!is_struct(_z)) continue;
        if (_chunk_x >= _z.chunk_x && _chunk_y >= _z.chunk_y && _chunk_x < _z.chunk_x + _z.w && _chunk_y < _z.chunk_y + _z.h) return true;
    }
    return false;
}

function rogue_world_clear_generated_instances(){
    for (var _p = instance_number(oFieldMoveProp) - 1; _p >= 0; --_p){
        var _prop = instance_find(oFieldMoveProp, _p);
        if (_prop != noone && variable_instance_exists(_prop, "rogue_generated") && variable_instance_get(_prop, "rogue_generated") == true) instance_destroy(_prop);
    }
    for (var _w = instance_number(oroguewarp) - 1; _w >= 0; --_w){
        var _warp = instance_find(oroguewarp, _w);
        if (_warp != noone && variable_instance_exists(_warp, "rogue_generated") && variable_instance_get(_warp, "rogue_generated") == true) instance_destroy(_warp);
    }
    for (var _i = instance_number(oNpc) - 1; _i >= 0; --_i){
        var _npc = instance_find(oNpc, _i);
        if (_npc != noone && variable_instance_exists(_npc, "rogue_generated") && variable_instance_get(_npc, "rogue_generated") == true) instance_destroy(_npc);
    }
    for (var _j = instance_number(oitem) - 1; _j >= 0; --_j){
        var _it = instance_find(oitem, _j);
        if (_it != noone && variable_instance_exists(_it, "rogue_generated") && variable_instance_get(_it, "rogue_generated") == true) instance_destroy(_it);
    }
    for (var _b = instance_number(obush) - 1; _b >= 0; --_b){
        var _bush = instance_find(obush, _b);
        if (_bush != noone && variable_instance_exists(_bush, "rogue_generated") && variable_instance_get(_bush, "rogue_generated") == true) instance_destroy(_bush);
    }
    var _R = rogue_world_ensure();
    _R.encounter_visible_owner = noone;
    global.ROGUE_WORLD = _R;
}

function rogue_world_clear_tilemaps(){
    var _R = rogue_world_ensure();
    var _layers = rogue_world_layer_names();
    for (var _li = 0; _li < array_length(_layers); ++_li){
        var _tm = rogue_tilemap_for_layer(_layers[_li]);
        if (_tm == -1) continue;
        try {
            tilemap_clear(_tm, 0);
            continue;
        } catch (e_rogue_tilemap_clear) {}
        for (var _y = 0; _y < _R.chunk_tiles; ++_y){
            for (var _x = 0; _x < _R.chunk_tiles; ++_x){
                tilemap_set(_tm, 0, _x, _y);
            }
        }
    }
}

function rogue_world_chunk_cache_key(_chunk_x, _chunk_y){
    return string(floor(_chunk_x)) + "_" + string(floor(_chunk_y));
}

function rogue_world_chunk_cache_get(_chunk_x, _chunk_y){
    var _R = rogue_world_ensure();
    var _key = rogue_world_chunk_cache_key(_chunk_x, _chunk_y);
    if (variable_struct_exists(_R.chunk_cache, _key)) return variable_struct_get(_R.chunk_cache, _key);
    return undefined;
}

function rogue_world_chunk_cache_put(_chunk_x, _chunk_y, _chunk_data){
    var _R = rogue_world_ensure();
    if (!is_struct(_chunk_data)) return false;
    var _key = rogue_world_chunk_cache_key(_chunk_x, _chunk_y);
    var _exists = variable_struct_exists(_R.chunk_cache, _key);
    variable_struct_set(_R.chunk_cache, _key, _chunk_data);
    if (!_exists) array_push(_R.chunk_cache_order, _key);

    var _limit = max(1, floor(_R.chunk_cache_limit));
    while (array_length(_R.chunk_cache_order) > _limit){
        var _drop = _R.chunk_cache_order[0];
        array_delete(_R.chunk_cache_order, 0, 1);
        if (variable_struct_exists(_R.chunk_cache, _drop)) variable_struct_remove(_R.chunk_cache, _drop);
    }
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_record_tile_write(_chunk_data, _layer, _tx, _ty, _tile, _data = undefined){
    if (!is_struct(_chunk_data)) return false;
    var _writes = variable_struct_exists(_chunk_data, "writes") && is_array(_chunk_data.writes) ? _chunk_data.writes : [];
    array_push(_writes, {
        layer: string(_layer),
        x: floor(_tx),
        y: floor(_ty),
        tile: _tile,
        data: _data
    });
    _chunk_data.writes = _writes;
    return true;
}

function rogue_world_replay_chunk_data(_chunk_data){
    if (!is_struct(_chunk_data)) return false;
    var _writes = variable_struct_exists(_chunk_data, "writes") && is_array(_chunk_data.writes) ? _chunk_data.writes : [];
    for (var _i = 0; _i < array_length(_writes); ++_i){
        var _w = _writes[_i];
        if (!is_struct(_w)) continue;
        var _layer = variable_struct_exists(_w, "layer") ? string(_w.layer) : "";
        var _tx = variable_struct_exists(_w, "x") ? floor(_w.x) : 0;
        var _ty = variable_struct_exists(_w, "y") ? floor(_w.y) : 0;
        if (variable_struct_exists(_w, "data") && !is_undefined(_w.data)) rogue_tilemap_set_data_layer(_layer, _tx, _ty, _w.data);
        else rogue_tilemap_set_layer(_layer, _tx, _ty, variable_struct_exists(_w, "tile") ? _w.tile : 0);
    }
    return true;
}

function rogue_tilemap_set_layer_record(_chunk_data, _layer_name, _tx, _ty, _tile_index){
    if (rogue_tilemap_set_layer(_layer_name, _tx, _ty, _tile_index)){
        rogue_world_record_tile_write(_chunk_data, _layer_name, _tx, _ty, _tile_index);
        return true;
    }
    return false;
}

function rogue_tilemap_set_role_record(_chunk_data, _role, _tx, _ty, _tile_index){
    return rogue_tilemap_set_layer_record(_chunk_data, rogue_world_layer_name(_role), _tx, _ty, _tile_index);
}

function rogue_world_default_biomes(){
    var _R = rogue_world_ensure();
    if (array_length(variable_struct_get_names(_R.biomes)) > 0) return;

    // Fallback only. Real biome availability comes from room/setup code.
    rogue_world_register_biome("grassland", {
        floor_tile: 9,
        solid_tile: 0,
        solid_chance: 0,
        weight: 6,
        temperature_min: 0,
        temperature_max: 1,
        moisture_min: 0,
        moisture_max: 1,
        decor: [],
        battle_area_type: "grassy"
    });
}

function rogue_world_climate_at(_world_tx, _world_ty){
    var _R = rogue_world_ensure();
    var _scale = max(1, real(_R.climate_cell_tiles));
    var _band = max(1, real(_R.temperature_band_tiles));
    var _noise_temp = rogue_value_noise01(_world_tx, _world_ty, _scale, 211);
    var _noise_moist = rogue_value_noise01(_world_tx, _world_ty, _scale, 307);
    var _latitude_wave = (sin(real(_world_ty) / _band) + 1) * 0.5;
    var _temperature = clamp((_latitude_wave * 0.55) + (_noise_temp * 0.45), 0, 1);
    var _moisture = clamp((_noise_moist * 0.82) + (rogue_value_noise01(_world_tx, _world_ty, _scale * 0.45, 419) * 0.18), 0, 1);
    return {
        temperature: _temperature,
        moisture: _moisture
    };
}

function rogue_world_biome_climate_distance(_def, _temperature, _moisture){
    var _tmin = variable_struct_exists(_def, "temperature_min") ? real(_def.temperature_min) : 0;
    var _tmax = variable_struct_exists(_def, "temperature_max") ? real(_def.temperature_max) : 1;
    var _mmin = variable_struct_exists(_def, "moisture_min") ? real(_def.moisture_min) : 0;
    var _mmax = variable_struct_exists(_def, "moisture_max") ? real(_def.moisture_max) : 1;
    var _dt = (_temperature < _tmin) ? (_tmin - _temperature) : ((_temperature > _tmax) ? (_temperature - _tmax) : 0);
    var _dm = (_moisture < _mmin) ? (_mmin - _moisture) : ((_moisture > _mmax) ? (_moisture - _mmax) : 0);
    return (_dt * _dt) + (_dm * _dm);
}

function rogue_world_biome_id_at(_world_tx, _world_ty){
    var _R = rogue_world_ensure();
    rogue_world_default_biomes();
    var _climate = rogue_world_climate_at(_world_tx, _world_ty);
    var _temperature = real(_climate.temperature);
    var _moisture = real(_climate.moisture);
    var _names = variable_struct_get_names(_R.biomes);
    if (array_length(_names) <= 0) return string(_R.default_biome);

    var _total = 0;
    var _matches = [];
    var _best_name = string(_R.default_biome);
    var _best_dist = 999999;
    for (var _i = 0; _i < array_length(_names); ++_i){
        var _name = string(_names[_i]);
        var _def = variable_struct_get(_R.biomes, _name);
        if (!is_struct(_def)) continue;
        var _dist = rogue_world_biome_climate_distance(_def, _temperature, _moisture);
        if (_dist < _best_dist){
            _best_dist = _dist;
            _best_name = _name;
        }
        if (_dist > 0) continue;
        var _weight = variable_struct_exists(_def, "weight") ? max(0, real(_def.weight)) : 1;
        if (_weight <= 0) continue;
        _total += _weight;
        array_push(_matches, { id:_name, weight:_weight });
    }

    if (_total <= 0) return _best_name;

    var _cell = max(1, floor(_R.biome_cell_tiles));
    var _cell_x = floor(_world_tx / _cell);
    var _cell_y = floor(_world_ty / _cell);
    var _pick = rogue_hash01(_cell_x, _cell_y, 11) * _total;
    var _running = 0;
    for (var _j = 0; _j < array_length(_matches); ++_j){
        _running += real(_matches[_j].weight);
        if (_pick <= _running) return string(_matches[_j].id);
    }
    return string(_matches[array_length(_matches) - 1].id);
}

function rogue_world_chunk_name_from_stats(_stats){
    if (!is_struct(_stats)) return "Wild Frontier";
    var _total = max(1, variable_struct_exists(_stats, "total") ? real(_stats.total) : 1);
    var _town = variable_struct_exists(_stats, "town") ? real(_stats.town) / _total : 0;
    var _forest = variable_struct_exists(_stats, "forest") ? real(_stats.forest) / _total : 0;
    var _river = variable_struct_exists(_stats, "river") ? real(_stats.river) / _total : 0;
    var _ocean = variable_struct_exists(_stats, "ocean") ? real(_stats.ocean) / _total : 0;
    var _grass = variable_struct_exists(_stats, "grassland") ? real(_stats.grassland) / _total : 0;
    var _desert = variable_struct_exists(_stats, "desert") ? real(_stats.desert) / _total : 0;
    var _tundra = variable_struct_exists(_stats, "tundra") ? real(_stats.tundra) / _total : 0;
    var _swamp = variable_struct_exists(_stats, "swamp") ? real(_stats.swamp) / _total : 0;
    var _mountain = variable_struct_exists(_stats, "mountain") ? real(_stats.mountain) / _total : 0;
    var _solid = variable_struct_exists(_stats, "solid") ? real(_stats.solid) / _total : 0;
    var _decor = variable_struct_exists(_stats, "decor") ? real(_stats.decor) / _total : 0;

    if (_town > 0) return "Rogue Town";
    if (_ocean >= 0.48) return "Open Sea";
    if (_desert >= 0.48) return "Sunbaked Expanse";
    if (_tundra >= 0.48) return "Frostwilds";
    if (_swamp >= 0.42) return "Murkfen";
    if (_mountain >= 0.45) return "Stoneback Pass";
    if (_forest >= 0.45 && _solid >= 0.08) return "Haunted Forest";
    if (_forest >= 0.45) return "Deep Forest";
    if (_river >= 0.34) return "River Wilds";
    if (_grass >= 0.62 && _decor >= 0.04) return "Flowering Fields";
    if (_grass >= 0.55) return "Wild Grasslands";
    return "Wild Frontier";
}

function rogue_world_town_cell_for_chunk(_chunk_x, _chunk_y){
    var _R = rogue_world_ensure();
    var _grid = max(1, floor(_R.town_grid_chunks));
    return {
        x: floor(_chunk_x / _grid),
        y: floor(_chunk_y / _grid)
    };
}

function rogue_world_town_anchor_for_cell(_cell_x, _cell_y){
    var _R = rogue_world_ensure();
    var _grid = max(1, floor(_R.town_grid_chunks));
    var _chunk_x = floor(_cell_x) * _grid + floor(_grid * 0.5);
    var _chunk_y = floor(_cell_y) * _grid + floor(_grid * 0.5);
    return {
        chunk_x: _chunk_x,
        chunk_y: _chunk_y,
        world_tx: (_chunk_x * _R.chunk_tiles) + floor(_R.chunk_tiles * 0.5),
        world_ty: (_chunk_y * _R.chunk_tiles) + floor(_R.chunk_tiles * 0.5)
    };
}

function rogue_world_town_anchor_for_chunk(_chunk_x, _chunk_y){
    var _cell = rogue_world_town_cell_for_chunk(_chunk_x, _chunk_y);
    return rogue_world_town_anchor_for_cell(_cell.x, _cell.y);
}

function rogue_world_chunk_is_town(_chunk_x, _chunk_y){
    var _town = rogue_world_town_anchor_for_chunk(_chunk_x, _chunk_y);
    return (floor(_chunk_x) == floor(_town.chunk_x) && floor(_chunk_y) == floor(_town.chunk_y));
}

function rogue_world_tile_near_segment(_tx, _ty, _ax, _ay, _bx, _by, _radius){
    var _r = max(0, real(_radius));
    if (_ay == _by){
        return (abs(real(_ty) - real(_ay)) <= _r && real(_tx) >= min(_ax, _bx) - _r && real(_tx) <= max(_ax, _bx) + _r);
    }
    if (_ax == _bx){
        return (abs(real(_tx) - real(_ax)) <= _r && real(_ty) >= min(_ay, _by) - _r && real(_ty) <= max(_ay, _by) + _r);
    }
    return false;
}

function rogue_world_should_path(_world_tx, _world_ty){
    var _R = rogue_world_ensure();
    if (!variable_struct_exists(_R, "town_path_enabled") || _R.town_path_enabled != true) return false;
    var _chunk_x = floor(real(_world_tx) / _R.chunk_tiles);
    var _chunk_y = floor(real(_world_ty) / _R.chunk_tiles);
    var _cell = rogue_world_town_cell_for_chunk(_chunk_x, _chunk_y);
    var _w = max(0, floor(_R.path_width_tiles));

    for (var _cy = _cell.y - 1; _cy <= _cell.y + 1; ++_cy){
        for (var _cx = _cell.x - 1; _cx <= _cell.x + 1; ++_cx){
            var _a = rogue_world_town_anchor_for_cell(_cx, _cy);
            var _right = rogue_world_town_anchor_for_cell(_cx + 1, _cy);
            var _down = rogue_world_town_anchor_for_cell(_cx, _cy + 1);
            if (rogue_world_tile_near_segment(_world_tx, _world_ty, _a.world_tx, _a.world_ty, _right.world_tx, _a.world_ty, _w)) return true;
            if (rogue_world_tile_near_segment(_world_tx, _world_ty, _right.world_tx, _a.world_ty, _right.world_tx, _right.world_ty, _w)) return true;
            if (rogue_world_tile_near_segment(_world_tx, _world_ty, _a.world_tx, _a.world_ty, _a.world_tx, _down.world_ty, _w)) return true;
            if (rogue_world_tile_near_segment(_world_tx, _world_ty, _a.world_tx, _down.world_ty, _down.world_tx, _down.world_ty, _w)) return true;
        }
    }
    return false;
}

function rogue_world_apply_path_tiles(_tx, _ty, _chunk_data = undefined){
    var _R = rogue_world_ensure();
    var _rules = variable_struct_exists(_R, "path_tiles") && is_array(_R.path_tiles) ? _R.path_tiles : [];
    if (array_length(_rules) <= 0){
        if (is_struct(_chunk_data)) rogue_tilemap_set_role_record(_chunk_data, "ground", _tx, _ty, variable_struct_exists(_R, "path_tile") ? _R.path_tile : 9);
        else rogue_tilemap_set_role("ground", _tx, _ty, variable_struct_exists(_R, "path_tile") ? _R.path_tile : 9);
        return true;
    }

    for (var _i = 0; _i < array_length(_rules); ++_i){
        var _rule = _rules[_i];
        if (!is_struct(_rule)) continue;
        var _layer = rogue_world_tile_rule_layer(_rule, "ground");
        var _ox = variable_struct_exists(_rule, "x_offset") ? floor(_rule.x_offset) : 0;
        var _oy = variable_struct_exists(_rule, "y_offset") ? floor(_rule.y_offset) : 0;
        if (variable_struct_exists(_rule, "data")){
            if (rogue_tilemap_set_data_layer(_layer, _tx + _ox, _ty + _oy, _rule.data) && is_struct(_chunk_data)){
                rogue_world_record_tile_write(_chunk_data, _layer, _tx + _ox, _ty + _oy, 0, _rule.data);
            }
        }
        else {
            var _tile = variable_struct_exists(_rule, "tile") ? _rule.tile : 0;
            if (is_struct(_chunk_data)) rogue_tilemap_set_layer_record(_chunk_data, _layer, _tx + _ox, _ty + _oy, _tile);
            else rogue_tilemap_set_layer(_layer, _tx + _ox, _ty + _oy, _tile);
        }
    }
    return true;
}

function rogue_world_biome_transition_info(_biome_id, _world_tx, _world_ty){
    var _R = rogue_world_ensure();
    if (!variable_struct_exists(_R, "biome_blend_enabled") || _R.biome_blend_enabled != true) return undefined;
    var _max_dist = max(1, floor(_R.biome_blend_distance_tiles));
    var _cell = max(1, floor(_R.biome_cell_tiles));
    var _lx = ((floor(_world_tx) mod _cell) + _cell) mod _cell;
    var _ly = ((floor(_world_ty) mod _cell) + _cell) mod _cell;
    var _edge_dist = min(min(_lx, _cell - 1 - _lx), min(_ly, _cell - 1 - _ly));
    if (_edge_dist > _max_dist) return undefined;
    var _current = string_lower(string(_biome_id));
    var _dirs = [
        { x:1, y:0, name:"right" },
        { x:-1, y:0, name:"left" },
        { x:0, y:1, name:"down" },
        { x:0, y:-1, name:"up" },
        { x:1, y:1, name:"down_right" },
        { x:-1, y:1, name:"down_left" },
        { x:1, y:-1, name:"up_right" },
        { x:-1, y:-1, name:"up_left" }
    ];
    for (var _d = 1; _d <= _max_dist; ++_d){
        for (var _i = 0; _i < array_length(_dirs); ++_i){
            var _dir = _dirs[_i];
            var _other = string_lower(string(rogue_world_biome_id_at(_world_tx + (_dir.x * _d), _world_ty + (_dir.y * _d))));
            if (_other != _current){
                return {
                    target: _other,
                    distance: _d,
                    max_distance: _max_dist,
                    direction: string(_dir.name)
                };
            }
        }
    }
    return undefined;
}

function rogue_world_blend_rule_matches(_rule, _target, _direction){
    if (!is_struct(_rule)) return false;
    if (variable_struct_exists(_rule, "toward")){
        var _toward = string_lower(string(_rule.toward));
        if (_toward != "*" && _toward != string_lower(string(_target))) return false;
    }
    if (variable_struct_exists(_rule, "direction")){
        var _dir = string_lower(string(_rule.direction));
        if (_dir != "*" && _dir != string_lower(string(_direction))) return false;
    }
    return true;
}

function rogue_world_apply_biome_blend(_chunk_data, _tx, _ty, _world_tx, _world_ty, _biome_id, _biome, _path){
    var _R = rogue_world_ensure();
    if (_path || !is_struct(_biome)) return false;
    var _rules = [];
    if (variable_struct_exists(_biome, "blend") && is_array(_biome.blend)) _rules = _biome.blend;
    else if (variable_struct_exists(_biome, "blend_tile")){
        _rules = [{ role:(variable_struct_exists(_biome, "blend_role") ? _biome.blend_role : "decor"), tile:_biome.blend_tile, chance:0.65, toward:"*" }];
    }
    if (array_length(_rules) <= 0) return false;

    var _info = rogue_world_biome_transition_info(_biome_id, _world_tx, _world_ty);
    if (!is_struct(_info)) return false;
    var _target = string(_info.target);
    var _distance = max(1, floor(_info.distance));
    var _max_dist = max(1, floor(_info.max_distance));
    var _falloff = 1 - ((_distance - 1) / _max_dist);
    var _placed = false;

    for (var _i = 0; _i < array_length(_rules); ++_i){
        var _rule = _rules[_i];
        if (!rogue_world_blend_rule_matches(_rule, _target, string(_info.direction))) continue;
        var _chance = variable_struct_exists(_rule, "chance") ? real(_rule.chance) : 1;
        _chance = clamp(_chance * _falloff, 0, 1);
        if (rogue_hash01(_world_tx, _world_ty, 700 + _i) > _chance) continue;
        var _layer = rogue_world_tile_rule_layer(_rule, "decor");
        var _tile = variable_struct_exists(_rule, "tile") ? _rule.tile : 0;
        if (variable_struct_exists(_rule, "data")){
            if (rogue_tilemap_set_data_layer(_layer, _tx, _ty, _rule.data) && is_struct(_chunk_data)) rogue_world_record_tile_write(_chunk_data, _layer, _tx, _ty, 0, _rule.data);
        } else {
            if (is_struct(_chunk_data)) rogue_tilemap_set_layer_record(_chunk_data, _layer, _tx, _ty, _tile);
            else rogue_tilemap_set_layer(_layer, _tx, _ty, _tile);
        }
        _placed = true;
        var _keep = (variable_struct_exists(_rule, "overlay") && _rule.overlay == true) || (variable_struct_exists(_rule, "stack") && _rule.stack == true);
        if (!_keep) break;
    }
    return _placed;
}

function rogue_world_apply_prefab(_prefab, _base_x, _base_y){
    if (!is_struct(_prefab)) return false;
    rogue_world_ensure_exported_layers(_prefab);
    var _tiles = variable_struct_exists(_prefab, "tiles") && is_array(_prefab.tiles) ? _prefab.tiles : [];
    for (var _i = 0; _i < array_length(_tiles); ++_i){
        var _t = _tiles[_i];
        if (!is_struct(_t)) continue;
        var _layer = rogue_world_tile_rule_layer(_t, "decor");
        var _tx = variable_struct_exists(_t, "x") ? floor(_t.x) : 0;
        var _ty = variable_struct_exists(_t, "y") ? floor(_t.y) : 0;
        if (variable_struct_exists(_t, "data")){
            rogue_tilemap_set_data_layer(_layer, _base_x + _tx, _base_y + _ty, _t.data);
        } else {
            var _tile = variable_struct_exists(_t, "tile") ? _t.tile : 0;
            rogue_tilemap_set_layer(_layer, _base_x + _tx, _base_y + _ty, _tile);
        }
        if (variable_struct_exists(_t, "solid") && _t.solid == true) rogue_tilemap_set_role("collision", _base_x + _tx, _base_y + _ty, 1);
    }

    var _objs = variable_struct_exists(_prefab, "objects") && is_array(_prefab.objects) ? _prefab.objects : [];
    for (var _j = 0; _j < array_length(_objs); ++_j){
        var _o = _objs[_j];
        if (!is_struct(_o)) continue;
        var _object_index = variable_struct_exists(_o, "object") ? _o.object : -1;
        if (is_string(_object_index)) _object_index = rogue_world_prefab_object_index(_object_index);
        if (_object_index == -1 && variable_struct_exists(_o, "object_name")) _object_index = rogue_world_prefab_object_index(_o.object_name);
        if (_object_index == -1) continue;
        var _ox = (variable_struct_exists(_o, "x") ? real(_o.x) : 0) + (_base_x * 16);
        var _oy = (variable_struct_exists(_o, "y") ? real(_o.y) : 0) + (_base_y * 16);
        var _inst_layer = variable_struct_exists(_o, "layer") ? string(_o.layer) : "Instances";
        var _inst = instance_create_layer(_ox, _oy, _inst_layer, _object_index);
        if (_inst != noone){
            variable_instance_set(_inst, "rogue_generated", true);
            rogue_world_apply_instance_snapshot(_inst, _o);
        }
    }
    return true;
}

function rogue_world_prefab_matches_biome(_prefab, _dominant_biome){
    if (!is_struct(_prefab)) return false;
    if (!variable_struct_exists(_prefab, "biomes") || !is_array(_prefab.biomes) || array_length(_prefab.biomes) <= 0) return true;
    var _want = string_lower(string(_dominant_biome));
    for (var _i = 0; _i < array_length(_prefab.biomes); ++_i){
        if (string_lower(string(_prefab.biomes[_i])) == _want) return true;
    }
    return false;
}

function rogue_world_prefab_has_tag(_prefab, _tag){
    if (!is_struct(_prefab) || !variable_struct_exists(_prefab, "tags") || !is_array(_prefab.tags)) return false;
    var _want = string_lower(string(_tag));
    for (var _i = 0; _i < array_length(_prefab.tags); ++_i){
        if (string_lower(string(_prefab.tags[_i])) == _want) return true;
    }
    return false;
}

function rogue_world_prefab_is_town(_prefab){
    if (!is_struct(_prefab)) return false;
    if (variable_struct_exists(_prefab, "type") && string_lower(string(_prefab.type)) == "town") return true;
    if (variable_struct_exists(_prefab, "kind") && string_lower(string(_prefab.kind)) == "town") return true;
    return rogue_world_prefab_has_tag(_prefab, "town");
}

function rogue_world_stats_dominant_biome(_stats){
    if (!is_struct(_stats)) return "grassland";
    var _best = "grassland";
    var _best_count = -1;
    var _skip = ["total", "solid", "decor", "temperature_sum", "moisture_sum", "chunk_x", "chunk_y", "town"];
    var _names = variable_struct_get_names(_stats);
    for (var _i = 0; _i < array_length(_names); ++_i){
        var _n = _names[_i];
        var _blocked = false;
        for (var _s = 0; _s < array_length(_skip); ++_s){
            if (_n == _skip[_s]){
                _blocked = true;
                break;
            }
        }
        if (_blocked) continue;
        var _v = variable_struct_exists(_stats, _n) ? real(variable_struct_get(_stats, _n)) : 0;
        if (_v > _best_count){
            _best_count = _v;
            _best = _n;
        }
    }
    return _best;
}

function rogue_world_weighted_prefab_pick(_candidates, _chunk_x, _chunk_y, _salt){
    var _total = 0;
    for (var _i = 0; _i < array_length(_candidates); ++_i){
        var _prefab = _candidates[_i];
        if (!is_struct(_prefab)) continue;
        _total += variable_struct_exists(_prefab, "weight") ? max(0, real(_prefab.weight)) : 1;
    }
    if (_total <= 0) return undefined;
    var _pick = rogue_hash01(_chunk_x, _chunk_y, _salt) * _total;
    var _running = 0;
    for (var _j = 0; _j < array_length(_candidates); ++_j){
        var _p = _candidates[_j];
        if (!is_struct(_p)) continue;
        _running += variable_struct_exists(_p, "weight") ? max(0, real(_p.weight)) : 1;
        if (_pick <= _running) return _p;
    }
    return _candidates[array_length(_candidates) - 1];
}

function rogue_world_try_prefabs(_chunk_x, _chunk_y, _dominant_biome = "grassland"){
    var _R = rogue_world_ensure();
    if (array_length(_R.prefabs) <= 0) return false;
    var _placed = 0;
    var _candidates = [];

    for (var _i = 0; _i < array_length(_R.prefabs); ++_i){
        var _prefab = _R.prefabs[_i];
        if (!is_struct(_prefab)) continue;
        if (rogue_world_prefab_is_town(_prefab)) continue;
        if (!rogue_world_prefab_matches_biome(_prefab, _dominant_biome)) continue;
        array_push(_candidates, _prefab);
    }

    if (array_length(_candidates) <= 0) return false;

    for (var _ci = 0; _ci < array_length(_candidates); ++_ci){
        var _prefab = _candidates[_ci];
        if (!is_struct(_prefab)) continue;

        var _chance = variable_struct_exists(_prefab, "spawn_chance") ? clamp(real(_prefab.spawn_chance), 0, 1) : 0.22;
        var _min = variable_struct_exists(_prefab, "min_per_chunk") ? max(0, floor(_prefab.min_per_chunk)) : 0;
        var _max = variable_struct_exists(_prefab, "max_per_chunk") ? max(_min, floor(_prefab.max_per_chunk)) : max(_min, 1);
        var _count = _min;
        for (var _roll = _min; _roll < _max; ++_roll){
            if (rogue_hash01(_chunk_x + _i, _chunk_y + _roll, 520 + _i) < _chance) _count += 1;
        }

        var _w = max(1, floor(_prefab.w));
        var _h = max(1, floor(_prefab.h));
        for (var _n = 0; _n < _count; ++_n){
            var _px = 8 + floor(rogue_hash01(_chunk_x + _ci, _chunk_y + _n, 540 + _ci) * max(1, _R.chunk_tiles - _w - 16));
            var _py = 8 + floor(rogue_hash01(_chunk_x + _ci, _chunk_y + _n, 560 + _ci) * max(1, _R.chunk_tiles - _h - 16));
            if (rogue_world_apply_prefab(_prefab, _px, _py)) _placed += 1;
        }
    }

    var _bonus_pick = rogue_world_weighted_prefab_pick(_candidates, _chunk_x, _chunk_y, 715);
    if (is_struct(_bonus_pick) && rogue_hash01(_chunk_x, _chunk_y, 716) < 0.20){
        var _bw = max(1, floor(_bonus_pick.w));
        var _bh = max(1, floor(_bonus_pick.h));
        var _bx = 8 + floor(rogue_hash01(_chunk_x, _chunk_y, 717) * max(1, _R.chunk_tiles - _bw - 16));
        var _by = 8 + floor(rogue_hash01(_chunk_x, _chunk_y, 718) * max(1, _R.chunk_tiles - _bh - 16));
        if (rogue_world_apply_prefab(_bonus_pick, _bx, _by)) _placed += 1;
    }
    return (_placed > 0);
}

function rogue_world_try_town_prefab(_chunk_x, _chunk_y){
    var _R = rogue_world_ensure();
    if (!rogue_world_chunk_is_town(_chunk_x, _chunk_y)) return false;
    var _candidates = [];
    for (var _i = 0; _i < array_length(_R.prefabs); ++_i){
        var _prefab = _R.prefabs[_i];
        if (!rogue_world_prefab_is_town(_prefab)) continue;
        array_push(_candidates, _prefab);
    }
    if (array_length(_candidates) <= 0) return false;
    var _pick = rogue_world_weighted_prefab_pick(_candidates, _chunk_x, _chunk_y, 811);
    if (!is_struct(_pick)) return false;
    var _w = max(1, floor(_pick.w));
    var _h = max(1, floor(_pick.h));
    var _px_max = max(0, _R.chunk_tiles - _w);
    var _py_max = max(0, _R.chunk_tiles - _h);
    var _px = clamp(floor((_R.chunk_tiles - _w) * 0.5), min(4, _px_max), _px_max);
    var _py = clamp(floor((_R.chunk_tiles - _h) * 0.5), min(4, _py_max), _py_max);
    return rogue_world_apply_prefab(_pick, _px, _py);
}

function rogue_world_clear_generated_tile(_tx, _ty){
    rogue_tilemap_set_role("_solid", _tx, _ty, -1);
    rogue_tilemap_set_role("collision", _tx, _ty, -1);
}

function rogue_world_clear_safe_rect(_cx, _cy, _radius){
    var _R = rogue_world_ensure();
    var _r = max(0, floor(_radius));
    for (var _yy = floor(_cy) - _r; _yy <= floor(_cy) + _r; ++_yy){
        for (var _xx = floor(_cx) - _r; _xx <= floor(_cx) + _r; ++_xx){
            if (_xx < 0 || _yy < 0 || _xx >= _R.chunk_tiles || _yy >= _R.chunk_tiles) continue;
            rogue_world_clear_generated_tile(_xx, _yy);
        }
    }
}

function rogue_world_clear_safe_landing_areas(){
    var _R = rogue_world_ensure();
    var _ct = _R.chunk_tiles;

    // Edge travel lands two tiles inside the next chunk. Keep those lanes clear
    // so the new chunk never generates under the player's feet.
    for (var _i = 0; _i < _ct; ++_i){
        rogue_world_clear_generated_tile(0, _i);
        rogue_world_clear_generated_tile(1, _i);
        rogue_world_clear_generated_tile(2, _i);
        rogue_world_clear_generated_tile(_ct - 1, _i);
        rogue_world_clear_generated_tile(_ct - 2, _i);
        rogue_world_clear_generated_tile(_ct - 3, _i);
        rogue_world_clear_generated_tile(_i, 0);
        rogue_world_clear_generated_tile(_i, 1);
        rogue_world_clear_generated_tile(_i, 2);
        rogue_world_clear_generated_tile(_i, _ct - 1);
        rogue_world_clear_generated_tile(_i, _ct - 2);
        rogue_world_clear_generated_tile(_i, _ct - 3);
    }

    if (_R.origin_tile_x == _R.entry_origin_tile_x && _R.origin_tile_y == _R.entry_origin_tile_y){
        rogue_world_clear_safe_rect(floor(_R.entry_spawn_x / _R.tile_size), floor(_R.entry_spawn_y / _R.tile_size), 2);
    }
}

function rogue_world_generate_chunk(){
    var _R = rogue_world_ensure();
    if (room != _R.room_id) return false;
    rogue_world_default_biomes();
    rogue_world_clear_generated_instances();
    rogue_world_clear_tilemaps();

    var _chunk_x = floor(_R.origin_tile_x / _R.chunk_tiles);
    var _chunk_y = floor(_R.origin_tile_y / _R.chunk_tiles);
    var _reserved = rogue_world_chunk_reserved(_chunk_x, _chunk_y);
    var _is_town_chunk = (!_reserved && rogue_world_chunk_is_town(_chunk_x, _chunk_y));
    var _cached_chunk = rogue_world_chunk_cache_get(_chunk_x, _chunk_y);
    if (is_struct(_cached_chunk)){
        rogue_world_replay_chunk_data(_cached_chunk);
        var _cached_dominant = variable_struct_exists(_cached_chunk, "dominant_biome") ? string(_cached_chunk.dominant_biome) : "grassland";
        if (!_reserved){
            if (_is_town_chunk) rogue_world_try_town_prefab(_chunk_x, _chunk_y);
            else rogue_world_try_prefabs(_chunk_x, _chunk_y, _cached_dominant);
        }
        rogue_world_clear_safe_landing_areas();
        if (!is_undefined(overworld_environment_apply_rogue_chunk) && variable_struct_exists(_cached_chunk, "stats")) overworld_environment_apply_rogue_chunk(_cached_chunk.stats, _cached_dominant);
        _R = rogue_world_ensure();
        _R.chunk_name = variable_struct_exists(_cached_chunk, "chunk_name") ? string(_cached_chunk.chunk_name) : rogue_world_chunk_name_from_stats(variable_struct_exists(_cached_chunk, "stats") ? _cached_chunk.stats : undefined);
        _R.last_origin_tile_x = _R.origin_tile_x;
        _R.last_origin_tile_y = _R.origin_tile_y;
        _R.encounter_last_tiles = ["", ""];
        _R.generated_revision += 1;
        global.ROGUE_WORLD = _R;

        if (!is_undefined(wc_bind_layers)){
            wc_bind_layers([rogue_world_layer_name("_solid"), rogue_world_layer_name("collision")]);
            wc_set_solids([oNpc, oFieldMoveProp, oitem]);
        }
        return true;
    }

    var _chunk_data = {
        chunk_x: _chunk_x,
        chunk_y: _chunk_y,
        writes: []
    };
    var _stats = { total:0, solid:0, decor:0, temperature_sum:0, moisture_sum:0 };
    _stats.chunk_x = _chunk_x;
    _stats.chunk_y = _chunk_y;
    if (_is_town_chunk) _stats.town = _R.chunk_tiles * _R.chunk_tiles;

    for (var _ty = 0; _ty < _R.chunk_tiles; ++_ty){
        for (var _tx = 0; _tx < _R.chunk_tiles; ++_tx){
            var _world_tx = _R.origin_tile_x + _tx;
            var _world_ty = _R.origin_tile_y + _ty;
            var _biome_id = _reserved ? "grassland" : rogue_world_biome_id_at(_world_tx, _world_ty);
            var _biome = rogue_world_biome(_biome_id);
            var _climate = rogue_world_climate_at(_world_tx, _world_ty);
            _stats.total += 1;
            _stats.temperature_sum += real(_climate.temperature);
            _stats.moisture_sum += real(_climate.moisture);
            if (!variable_struct_exists(_stats, _biome_id)) variable_struct_set(_stats, _biome_id, 0);
            variable_struct_set(_stats, _biome_id, variable_struct_get(_stats, _biome_id) + 1);

            var _path = rogue_world_should_path(_world_tx, _world_ty);
            var _floor_tile = variable_struct_exists(_biome, "floor_tile") ? _biome.floor_tile : 0;
            rogue_tilemap_set_role_record(_chunk_data, "ground", _tx, _ty, _floor_tile);
            if (_path) rogue_world_apply_path_tiles(_tx, _ty, _chunk_data);

            var _solid_chance = variable_struct_exists(_biome, "solid_chance") ? real(_biome.solid_chance) : 0;
            var _edge_tile = (_tx == 0 || _ty == 0 || _tx == _R.chunk_tiles - 1 || _ty == _R.chunk_tiles - 1);
            var _biome_solids_enabled = variable_struct_exists(_R, "biome_solids_enabled") && _R.biome_solids_enabled == true;
            var _solid = (_biome_solids_enabled && !_edge_tile && !_path && !_reserved && rogue_hash01(_world_tx, _world_ty, 21) < _solid_chance);
            if (_solid){
                _stats.solid += 1;
                var _wall_tile = variable_struct_exists(_biome, "solid_tile") ? _biome.solid_tile : (variable_struct_exists(_biome, "wall_tile") ? _biome.wall_tile : 1);
                rogue_tilemap_set_role_record(_chunk_data, "_solid", _tx, _ty, _wall_tile);
                rogue_tilemap_set_role_record(_chunk_data, "collision", _tx, _ty, 1);
            } else if (!_path && variable_struct_exists(_biome, "decor") && is_array(_biome.decor)){
                for (var _di = 0; _di < array_length(_biome.decor); ++_di){
                    var _d = _biome.decor[_di];
                    if (!is_struct(_d)) continue;
                    var _chance = variable_struct_exists(_d, "chance") ? real(_d.chance) : 0;
                    if (rogue_hash01(_world_tx, _world_ty, 100 + _di) < _chance){
                        _stats.decor += 1;
                        var _decor_layer = rogue_world_tile_rule_layer(_d, "decor");
                        rogue_tilemap_set_layer_record(_chunk_data, _decor_layer, _tx, _ty, variable_struct_exists(_d, "tile") ? _d.tile : 0);
                        var _keep_decor_pass = (variable_struct_exists(_d, "overlay") && _d.overlay == true) || (variable_struct_exists(_d, "stack") && _d.stack == true);
                        if (!_keep_decor_pass) break;
                    }
                }
            }
            if (!_reserved && !_solid) {
                if (rogue_world_apply_biome_blend(_chunk_data, _tx, _ty, _world_tx, _world_ty, _biome_id, _biome, _path)) _stats.decor += 1;
            }
        }
    }

    var _dominant_biome = rogue_world_stats_dominant_biome(_stats);
    _chunk_data.stats = _stats;
    _chunk_data.dominant_biome = _dominant_biome;
    _chunk_data.chunk_name = rogue_world_chunk_name_from_stats(_stats);
    rogue_world_chunk_cache_put(_chunk_x, _chunk_y, _chunk_data);
    if (!_reserved){
        if (_is_town_chunk) rogue_world_try_town_prefab(_chunk_x, _chunk_y);
        else rogue_world_try_prefabs(_chunk_x, _chunk_y, _dominant_biome);
    }
    rogue_world_clear_safe_landing_areas();
    if (!is_undefined(overworld_environment_apply_rogue_chunk)) overworld_environment_apply_rogue_chunk(_stats, _dominant_biome);
    _R = rogue_world_ensure();
    _R.chunk_name = _chunk_data.chunk_name;
    _R.last_origin_tile_x = _R.origin_tile_x;
    _R.last_origin_tile_y = _R.origin_tile_y;
    _R.encounter_last_tiles = ["", ""];
    _R.generated_revision += 1;
    global.ROGUE_WORLD = _R;

    if (!is_undefined(wc_bind_layers)){
        wc_bind_layers([rogue_world_layer_name("_solid"), rogue_world_layer_name("collision")]);
        wc_set_solids([oNpc, oFieldMoveProp, oitem]);
    }
    return true;
}

function rogue_world_spawn_return_warp(){
    var _R = rogue_world_ensure();
    if (room != _R.room_id || _R.return_room == noone) return false;
    if (_R.origin_tile_x != _R.entry_origin_tile_x || _R.origin_tile_y != _R.entry_origin_tile_y) return false;
    var _rx = real(_R.entry_spawn_x);
    var _ry = real(_R.entry_spawn_y) + (_R.tile_size * 2);
    var _warp = instance_create_layer(_rx, _ry, "Instances", oroguewarp);
    if (_warp == noone) return false;
    variable_instance_set(_warp, "rogue_generated", true);
    variable_instance_set(_warp, "rogue_prefab_export", false);
    variable_instance_set(_warp, "rogue_return_warp", true);
    variable_instance_set(_warp, "warp_kind", "exit");
    variable_instance_set(_warp, "visible", true);
    return true;
}

function rogue_world_prepare_enter(_seed = undefined, _chunk_x = 0, _chunk_y = 0, _spawn_x = 128, _spawn_y = 128, _entry_facing = 2, _return_edge = "auto"){
    var _R = rogue_world_ensure();
    _R.active = true;
    if (is_real(_seed)) _R.seed = floor(_seed);
    _R.origin_tile_x = floor(_chunk_x) * _R.chunk_tiles;
    _R.origin_tile_y = floor(_chunk_y) * _R.chunk_tiles;
    _R.entry_origin_tile_x = _R.origin_tile_x;
    _R.entry_origin_tile_y = _R.origin_tile_y;
    _R.entry_spawn_x = real(_spawn_x);
    _R.entry_spawn_y = real(_spawn_y);
    var _edge_norm = rogue_world_normalize_edge(_return_edge, "auto");
    _R.return_edge = (_edge_norm == "auto") ? rogue_world_return_edge_from_facing(_entry_facing) : _edge_norm;
    _R.last_origin_tile_x = 99999999;
    _R.last_origin_tile_y = 99999999;
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_return_to_previous(){
    var _R = rogue_world_ensure();
    if (_R.return_room == noone) return false;
    _R.active = false;
    global.ROGUE_WORLD = _R;
    return world_warp_to(_R.return_room, _R.return_x, _R.return_y, {
        transition_style: "emerald_fade_black",
        show_route: true,
        facing: _R.return_facing
    });
}

function rogue_world_edge_is_return(_R, _edge_side){
    if (!is_struct(_R) || _R.return_room == noone) return false;
    if (_R.origin_tile_x != _R.entry_origin_tile_x || _R.origin_tile_y != _R.entry_origin_tile_y) return false;
    var _return_edge = rogue_world_normalize_edge(variable_struct_exists(_R, "return_edge") ? _R.return_edge : "up", "up");
    return (_return_edge == "any" || _return_edge == string(_edge_side));
}

function rogue_world_room_start(){
    var _R = rogue_world_ensure();
    _R.active = true;
    _R.room_id = rm_world;
    _R.page_transition = undefined;
    _R.edge_page_pending = undefined;
    global.ROGUE_WORLD = _R;
    rogue_world_fit_chunk_to_room();
    _R = rogue_world_ensure();
    if (!_R.prefabs_loaded){
        rogue_world_load_prefab_folder("data/rogue_prefabs");
        _R = rogue_world_ensure();
        _R.prefabs_loaded = true;
        global.ROGUE_WORLD = _R;
    }
    if (!is_undefined(world_room_register)) world_room_register(rm_world, "Wild Frontier", variable_global_exists("_REGIONMUSIC") ? global._REGIONMUSIC : noone, false);
    return rogue_world_generate_chunk();
}

function rogue_world_edge_page_for_player(_pid){
    var _R = rogue_world_ensure();
    if (room != _R.room_id || !_R.active) return false;
    if (is_struct(_R.edge_page_pending)) return false;
    var _pl = player_by_pid(_pid);
    if (_pl == noone) return false;
    var _edge = 16;
    var _chunk_px = _R.chunk_tiles * _R.tile_size;
    var _changed = false;
    var _edge_side = "";
    var _nx = _pl.x;
    var _ny = _pl.y;

    if (_pl.x <= _edge){
        _edge_side = "left";
        if (rogue_world_edge_is_return(_R, _edge_side)) return rogue_world_return_to_previous();
        _R.origin_tile_x -= _R.chunk_tiles;
        _nx = _chunk_px - (_edge * 2);
        _changed = true;
    } else if (_pl.x >= _chunk_px - _edge){
        _edge_side = "right";
        if (rogue_world_edge_is_return(_R, _edge_side)) return rogue_world_return_to_previous();
        _R.origin_tile_x += _R.chunk_tiles;
        _nx = _edge * 2;
        _changed = true;
    }
    if (_pl.y <= _edge){
        _edge_side = "up";
        if (rogue_world_edge_is_return(_R, _edge_side)) return rogue_world_return_to_previous();
        _R.origin_tile_y -= _R.chunk_tiles;
        _ny = _chunk_px - (_edge * 2);
        _changed = true;
    } else if (_pl.y >= _chunk_px - _edge){
        _edge_side = "down";
        if (rogue_world_edge_is_return(_R, _edge_side)) return rogue_world_return_to_previous();
        _R.origin_tile_y += _R.chunk_tiles;
        _ny = _edge * 2;
        _changed = true;
    }

    if (!_changed) return false;
    rogue_world_play_edge_warp_sound();
    var _transition_ms = 420;
    rogue_world_start_page_transition("emerald_fade_black", _transition_ms);
    _R.edge_page_pending = {
        pid: _pid,
        origin_tile_x: _R.origin_tile_x,
        origin_tile_y: _R.origin_tile_y,
        x: _nx,
        y: _ny,
        facing: variable_instance_exists(_pl, "facing_dir") ? variable_instance_get(_pl, "facing_dir") : undefined,
        start_ms: current_time,
        generate_after_ms: variable_struct_exists(_R, "edge_page_generate_after_ms") ? real(_R.edge_page_generate_after_ms) : (_transition_ms * 0.5)
    };
    global.ROGUE_WORLD = _R;
    return true;
}

function rogue_world_process_edge_page_pending(){
    var _R = rogue_world_ensure();
    if (room != _R.room_id || !_R.active || !is_struct(_R.edge_page_pending)) return false;
    var _P = _R.edge_page_pending;
    var _delay = variable_struct_exists(_P, "generate_after_ms") ? max(0, real(_P.generate_after_ms)) : 150;
    var _start = variable_struct_exists(_P, "start_ms") ? real(_P.start_ms) : current_time;
    if (current_time - _start < _delay) return false;

    _R.origin_tile_x = floor(_P.origin_tile_x);
    _R.origin_tile_y = floor(_P.origin_tile_y);
    _R.edge_page_pending = undefined;
    global.ROGUE_WORLD = _R;

    rogue_world_generate_chunk();

    var _pid = variable_struct_exists(_P, "pid") ? floor(_P.pid) : 0;
    world_place_player_after_warp(_pid, real(_P.x), real(_P.y), variable_struct_exists(_P, "facing") ? _P.facing : undefined);
    if (_pid == 0 && multiplayer_player_joined(1)){
        var _p2 = player_by_pid(1);
        if (_p2 != noone) world_place_player_after_warp(1, real(_P.x) + 16, real(_P.y), variable_instance_exists(_p2, "facing_dir") ? variable_instance_get(_p2, "facing_dir") : undefined);
    }

    if (!is_undefined(world_show_route_bar)){
        _R = rogue_world_ensure();
        var _cx = floor(_R.origin_tile_x / _R.chunk_tiles);
        var _cy = floor(_R.origin_tile_y / _R.chunk_tiles);
        world_show_route_bar(string(_R.chunk_name) + " " + string(_cx) + "," + string(_cy), 1400, {
            style: "rogue",
            chunk_name: string(_R.chunk_name)
        });
    }
    return true;
}

function rogue_world_update_all(){
    var _R = rogue_world_ensure();
    if (room != _R.room_id || !_R.active) return false;
    if (!is_undefined(transition_is_blocking) && transition_is_blocking()) return false;
    if (rogue_world_process_edge_page_pending()) return true;
    _R = rogue_world_ensure();
    if (is_struct(_R.edge_page_pending)) return true;
    if (_R.last_origin_tile_x != _R.origin_tile_x || _R.last_origin_tile_y != _R.origin_tile_y) rogue_world_generate_chunk();
    if (rogue_world_update_encounters()) return true;
    rogue_world_edge_page_for_player(0);
    if (multiplayer_player_joined(1)) rogue_world_edge_page_for_player(1);
    return true;
}

function rogue_world_warp_to(_seed = undefined, _chunk_x = 0, _chunk_y = 0, _spawn_x = 128, _spawn_y = 128){
    rogue_world_prepare_enter(_seed, _chunk_x, _chunk_y, _spawn_x, _spawn_y, 2);
    return world_warp_to(rm_world, _spawn_x, _spawn_y, {
        transition_style: "emerald_fade_black",
        show_route: true,
        facing: 2
    });
}
