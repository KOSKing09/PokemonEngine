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
        return_room: noone,
        return_x: 0,
        return_y: 0,
        return_facing: 2,
        last_origin_tile_x: 99999999,
        last_origin_tile_y: 99999999,
        default_biome: "grassland",
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
    if (!variable_struct_exists(_R, "return_room")) _R.return_room = noone;
    if (!variable_struct_exists(_R, "return_x")) _R.return_x = 0;
    if (!variable_struct_exists(_R, "return_y")) _R.return_y = 0;
    if (!variable_struct_exists(_R, "return_facing")) _R.return_facing = 2;
    if (!variable_struct_exists(_R, "last_origin_tile_x")) _R.last_origin_tile_x = 99999999;
    if (!variable_struct_exists(_R, "last_origin_tile_y")) _R.last_origin_tile_y = 99999999;
    if (!variable_struct_exists(_R, "default_biome")) _R.default_biome = "grassland";
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
        variable_struct_set(_R.layer_roles, _role, variable_struct_get(_roles, _names[_i]));
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

function rogue_world_draw_transition(){
    if (!variable_global_exists("ROGUE_WORLD") || !is_struct(global.ROGUE_WORLD)) return false;
    var _R = global.ROGUE_WORLD;
    if (!variable_struct_exists(_R, "page_transition") || !is_struct(_R.page_transition)) return false;
    var _P = _R.page_transition;
    if (!variable_struct_exists(_P, "active") || _P.active != true) return false;
    var _dur = variable_struct_exists(_P, "duration_ms") ? max(1, real(_P.duration_ms)) : 320;
    var _elapsed = current_time - (variable_struct_exists(_P, "start_ms") ? real(_P.start_ms) : current_time);
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
    var _key = string_lower(string(_role_or_layer));
    if (_key == "solid") _key = "_solid";
    if (variable_struct_exists(_R.layer_roles, _key)) return string(variable_struct_get(_R.layer_roles, _key));
    return string(_role_or_layer);
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
    return _out;
}

function rogue_hash01(_x, _y, _salt){
    var _R = rogue_world_ensure();
    var _n = sin((_x * 12.9898) + (_y * 78.233) + (_salt * 37.719) + (_R.seed * 0.0137)) * 43758.5453;
    return _n - floor(_n);
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

function rogue_tilemap_set_layer(_layer_name, _tx, _ty, _tile_index){
    var _tm = rogue_tilemap_for_layer(_layer_name);
    if (_tm == -1) return false;
    try { tilemap_set(_tm, rogue_tiledata(_tile_index), floor(_tx), floor(_ty)); return true; } catch (e_set_tile) {}
    return false;
}

function rogue_tilemap_set_role(_role, _tx, _ty, _tile_index){
    return rogue_tilemap_set_layer(rogue_world_layer_name(_role), _tx, _ty, _tile_index);
}

function rogue_tilemap_set_data_layer(_layer_name, _tx, _ty, _tile_data){
    var _tm = rogue_tilemap_for_layer(_layer_name);
    if (_tm == -1) return false;
    try { tilemap_set(_tm, _tile_data, floor(_tx), floor(_ty)); return true; } catch (e_set_data) {}
    return false;
}

function rogue_world_data_path(_file_name){
    var _name = string(_file_name);
    if (string_pos(":", _name) > 0 || string_copy(_name, 1, 1) == "/" || string_copy(_name, 1, 1) == "\\") return _name;
    if (string_pos(".json", string_lower(_name)) <= 0) _name += ".json";
    return working_directory + "/data/rogue_prefabs/" + _name;
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

function rogue_world_export_current_room_prefab(_id, _file_name = undefined, _opts = undefined){
    rogue_world_ensure();
    if (is_undefined(_opts) || !is_struct(_opts)) _opts = {};

    var _layers = variable_struct_exists(_opts, "layers") && is_array(_opts.layers) ? _opts.layers : rogue_world_layer_names();
    var _tile_size = variable_struct_exists(_opts, "tile_size") ? max(1, real(_opts.tile_size)) : 16;
    var _min_x = 999999;
    var _min_y = 999999;
    var _max_x = -999999;
    var _max_y = -999999;
    var _layer_tiles = [];

    for (var _li = 0; _li < array_length(_layers); ++_li){
        var _layer_name = rogue_world_layer_name(_layers[_li]);
        var _tm = rogue_tilemap_for_layer(_layer_name);
        if (_tm == -1) continue;
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
            vars: rogue_world_export_instance_vars(_inst)
        });
    }

    if (_max_x < _min_x || _max_y < _min_y){
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
        w: max(1, (_max_x - _min_x) + 1),
        h: max(1, (_max_y - _min_y) + 1),
        origin_tile_x: _min_x,
        origin_tile_y: _min_y,
        weight: variable_struct_exists(_opts, "weight") ? _opts.weight : 1,
        biomes: variable_struct_exists(_opts, "biomes") && is_array(_opts.biomes) ? _opts.biomes : [],
        tiles: _tiles_out,
        objects: _objects
    };

    if (!is_undefined(_file_name)){
        var _path = rogue_world_data_path(_file_name);
        try { directory_create(working_directory + "/data"); } catch (e_dir_data) {}
        try { directory_create(working_directory + "/data/rogue_prefabs"); } catch (e_dir_prefab) {}
        var _fh = file_text_open_write(_path);
        file_text_write_string(_fh, json_stringify(_prefab));
        file_text_close(_fh);
        show_debug_message("[ROGUE][prefab] exported " + string(_prefab.id) + " -> " + _path);
    }

    return _prefab;
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

function rogue_world_register_biome(_id, _def){
    var _R = rogue_world_ensure();
    if (!is_struct(_def)) _def = {};
    var _key = string_lower(string(_id));
    variable_struct_set(_def, "id", _key);
    variable_struct_set(_R.biomes, _key, _def);
    global.ROGUE_WORLD = _R;
    return _def;
}

function rogue_world_biome(_id){
    var _R = rogue_world_ensure();
    var _key = string_lower(string(_id));
    if (variable_struct_exists(_R.biomes, _key)) return variable_struct_get(_R.biomes, _key);
    if (variable_struct_exists(_R.biomes, string(_R.default_biome))) return variable_struct_get(_R.biomes, string(_R.default_biome));
    return { id:"grassland", floor_tile:0, wall_tile:1, solid_chance:0.05, decor:[] };
}

function rogue_world_register_prefab(_def){
    var _R = rogue_world_ensure();
    if (!is_struct(_def)) return false;
    if (!variable_struct_exists(_def, "id")) _def.id = "prefab_" + string(array_length(_R.prefabs));
    if (!variable_struct_exists(_def, "w")) _def.w = 4;
    if (!variable_struct_exists(_def, "h")) _def.h = 4;
    if (!variable_struct_exists(_def, "weight")) _def.weight = 1;
    if (!variable_struct_exists(_def, "biomes")) _def.biomes = [];
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
}

function rogue_world_clear_tilemaps(){
    var _R = rogue_world_ensure();
    var _layers = rogue_world_layer_names();
    for (var _li = 0; _li < array_length(_layers); ++_li){
        var _tm = rogue_tilemap_for_layer(_layers[_li]);
        if (_tm == -1) continue;
        for (var _y = 0; _y < _R.chunk_tiles; ++_y){
            for (var _x = 0; _x < _R.chunk_tiles; ++_x){
                tilemap_set(_tm, 0, _x, _y);
            }
        }
    }
}

function rogue_world_default_biomes(){
    var _R = rogue_world_ensure();
    if (variable_struct_exists(_R.biomes, "grassland")) return;

    // Placeholder tile numbers. Replace these once the final tileset ids are known.
    rogue_world_register_biome("grassland", {
        floor_tile: 9,
        solid_tile: 1,
        solid_chance: 0.035,
        decor: [
            { role:"decor", tile:0, chance:0.045 },
            { role:"decor", tile:0, chance:0.025 }
        ],
        battle_area_type: "grassy"
    });
    rogue_world_register_biome("forest", {
        floor_tile: 0,
        solid_tile: 1,
        solid_chance: 0.12,
        decor: [
            { role:"decor", tile:0, chance:0.08 }
        ],
        battle_area_type: "forest"
    });
    rogue_world_register_biome("river", {
        floor_tile: 0,
        solid_tile: 1,
        solid_chance: 0.06,
        water_tile: 0,
        water_chance: 0.18,
        battle_area_type: "river"
    });
}

function rogue_world_biome_id_at(_world_tx, _world_ty){
    var _cell_x = floor(_world_tx / 24);
    var _cell_y = floor(_world_ty / 24);
    var _v = rogue_hash01(_cell_x, _cell_y, 11);
    if (_v < 0.28) return "forest";
    if (_v > 0.78) return "river";
    return "grassland";
}

function rogue_world_should_path(_world_tx, _world_ty){
    var _rx = abs(_world_tx) mod 18;
    var _ry = abs(_world_ty) mod 18;
    return (_rx == 0 || _rx == 1 || _ry == 0 || _ry == 1);
}

function rogue_world_apply_prefab(_prefab, _base_x, _base_y){
    if (!is_struct(_prefab)) return false;
    var _tiles = variable_struct_exists(_prefab, "tiles") && is_array(_prefab.tiles) ? _prefab.tiles : [];
    for (var _i = 0; _i < array_length(_tiles); ++_i){
        var _t = _tiles[_i];
        if (!is_struct(_t)) continue;
        var _layer = variable_struct_exists(_t, "role") ? rogue_world_layer_name(_t.role) : (variable_struct_exists(_t, "layer") ? string(_t.layer) : rogue_world_layer_name("decor"));
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
            if (variable_struct_exists(_o, "vars") && is_struct(_o.vars)){
                var _names = variable_struct_get_names(_o.vars);
                for (var _vi = 0; _vi < array_length(_names); ++_vi){
                    var _name = _names[_vi];
                    variable_instance_set(_inst, _name, variable_struct_get(_o.vars, _name));
                }
            }
        }
    }
    return true;
}

function rogue_world_try_prefabs(_chunk_x, _chunk_y){
    var _R = rogue_world_ensure();
    if (array_length(_R.prefabs) <= 0) return false;
    if (rogue_hash01(_chunk_x, _chunk_y, 52) > 0.22) return false;

    var _pick = floor(rogue_hash01(_chunk_x, _chunk_y, 53) * array_length(_R.prefabs));
    _pick = clamp(_pick, 0, array_length(_R.prefabs) - 1);
    var _prefab = _R.prefabs[_pick];
    if (!is_struct(_prefab)) return false;
    var _w = max(1, floor(_prefab.w));
    var _h = max(1, floor(_prefab.h));
    var _px = 8 + floor(rogue_hash01(_chunk_x, _chunk_y, 54) * max(1, _R.chunk_tiles - _w - 16));
    var _py = 8 + floor(rogue_hash01(_chunk_x, _chunk_y, 55) * max(1, _R.chunk_tiles - _h - 16));
    return rogue_world_apply_prefab(_prefab, _px, _py);
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

    for (var _ty = 0; _ty < _R.chunk_tiles; ++_ty){
        for (var _tx = 0; _tx < _R.chunk_tiles; ++_tx){
            var _world_tx = _R.origin_tile_x + _tx;
            var _world_ty = _R.origin_tile_y + _ty;
            var _biome_id = _reserved ? "grassland" : rogue_world_biome_id_at(_world_tx, _world_ty);
            var _biome = rogue_world_biome(_biome_id);

            var _floor_tile = variable_struct_exists(_biome, "floor_tile") ? _biome.floor_tile : 0;
            rogue_tilemap_set_role("ground", _tx, _ty, _floor_tile);

            var _path = rogue_world_should_path(_world_tx, _world_ty);
            var _solid_chance = variable_struct_exists(_biome, "solid_chance") ? real(_biome.solid_chance) : 0;
            var _edge_tile = (_tx == 0 || _ty == 0 || _tx == _R.chunk_tiles - 1 || _ty == _R.chunk_tiles - 1);
            var _solid = (!_edge_tile && !_path && !_reserved && rogue_hash01(_world_tx, _world_ty, 21) < _solid_chance);
            if (_solid){
                var _wall_tile = variable_struct_exists(_biome, "solid_tile") ? _biome.solid_tile : (variable_struct_exists(_biome, "wall_tile") ? _biome.wall_tile : 1);
                rogue_tilemap_set_role("_solid", _tx, _ty, _wall_tile);
                rogue_tilemap_set_role("collision", _tx, _ty, 1);
            } else if (!_path && variable_struct_exists(_biome, "decor") && is_array(_biome.decor)){
                for (var _di = 0; _di < array_length(_biome.decor); ++_di){
                    var _d = _biome.decor[_di];
                    if (!is_struct(_d)) continue;
                    var _chance = variable_struct_exists(_d, "chance") ? real(_d.chance) : 0;
                    if (rogue_hash01(_world_tx, _world_ty, 100 + _di) < _chance){
                        var _decor_layer = variable_struct_exists(_d, "role") ? rogue_world_layer_name(_d.role) : (variable_struct_exists(_d, "layer") ? _d.layer : rogue_world_layer_name("decor"));
                        rogue_tilemap_set_layer(_decor_layer, _tx, _ty, variable_struct_exists(_d, "tile") ? _d.tile : 0);
                        break;
                    }
                }
            }
        }
    }

    if (!_reserved) rogue_world_try_prefabs(_chunk_x, _chunk_y);
    _R.last_origin_tile_x = _R.origin_tile_x;
    _R.last_origin_tile_y = _R.origin_tile_y;
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
    global.ROGUE_WORLD = _R;
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
    global.ROGUE_WORLD = _R;
    world_place_player_after_warp(_pid, _nx, _ny, variable_instance_exists(_pl, "facing_dir") ? variable_instance_get(_pl, "facing_dir") : undefined);
    if (_pid == 0 && multiplayer_player_joined(1)){
        var _p2 = player_by_pid(1);
        if (_p2 != noone) world_place_player_after_warp(1, _nx + 16, _ny, variable_instance_exists(_p2, "facing_dir") ? variable_instance_get(_p2, "facing_dir") : undefined);
    }
    rogue_world_generate_chunk();
    rogue_world_start_page_transition("emerald_fade_black", 320);
    if (!is_undefined(world_show_route_bar)){
        var _cx = floor(_R.origin_tile_x / _R.chunk_tiles);
        var _cy = floor(_R.origin_tile_y / _R.chunk_tiles);
        world_show_route_bar("Wild Frontier " + string(_cx) + "," + string(_cy), 1400);
    }
    return true;
}

function rogue_world_update_all(){
    var _R = rogue_world_ensure();
    if (room != _R.room_id || !_R.active) return false;
    if (_R.last_origin_tile_x != _R.origin_tile_x || _R.last_origin_tile_y != _R.origin_tile_y) rogue_world_generate_chunk();
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
