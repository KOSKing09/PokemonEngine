// [Pokémon Data]: pkicons_external — Build v2.11.0 — 2025-10-05
// Changes
// - Keeps split defaults:
//      * Missing 32×32 icon => spr_mon_icon_placeholder
//      * Missing 96×96 art  => spr_mon_placeholder
// - Restores pkicons_get_icon32_dir (used by _by_mon)
// - Restores pkicons_icon32_frame_ui (2‑frame UI animator)
// - Uses robust 8‑tile grid + centered scaling (from v2.8.x)
//
// Safe to drop-in over v2.9.0. No legacy pkicons_set_missing_sprite shim (you removed that call).

globalvar PKICONS;

function pkicons_init(){
    if (!variable_global_exists("PKICONS")){
        global.PKICONS = {
            debug: false,
            debug_items: false,
            ext: ".png",
            art96_base: "",
            icon32_base: "",
            cries_base: "",
            art_cache: {},
            art_meta: {}, // species -> {mode:"quad", layout:"grid2x2", w:frameW, h:frameH}
            icon_sheet_cache: {},
            icon_strip_cache: {},
            icon_dir_cache: {},
            item_icon_cache: {},
            item_icon_base: "",
            debug_crys: false,
            // Split placeholders (resolved immediately after init)
            missing_icon32: -1,
            missing_art96: -1,
            icon32_base_shiny: "", // auto‑derived by replacing /Normal/ with /Shiny/ unless overridden
            last_cry_loaded: "",
            last_cry_status: "",
            last_play_status: ""
        };
        // Resolve common built-in placeholders to numeric asset indices when available
        try {
            var _ph32 = asset_get_index("spr_mon_icon_placeholder");
            if (is_real(_ph32) && _ph32 != -1) global.PKICONS.missing_icon32 = _ph32;
        } catch (e) { /* ignore */ }
        try {
            var _ph96 = asset_get_index("spr_mon_placeholder");
            if (is_real(_ph96) && _ph96 != -1) global.PKICONS.missing_art96 = _ph96;
        } catch (e) { /* ignore */ }
    }
}

// Item-specific debug logger (separate switch so item scanning/loading can be quiet)
function pkicons__log_item(_m){
    if (variable_struct_exists(PKICONS, "debug_items") && PKICONS.debug_items) show_debug_message("[pkicons][items] " + string(_m));
}

function pkicons__log(_m){
    if (PKICONS.debug) show_debug_message("[pkicons] " + string(_m));
}

// Cry-specific debug: separate toggle so cry logging can be enabled independently
function pkicons__log_cry(_m){
    if (variable_struct_exists(PKICONS, "debug_crys") && PKICONS.debug_crys) show_debug_message("[pkicons] " + string(_m));
}

// Explicit setters for placeholders & bases
function pkicons_set_missing_icon(_spr){
    // Accept either a numeric sprite id or a symbol/string name and coerce to an asset index
    var _id = _spr;
    if (!is_real(_id)){
        // try to resolve by name
        try { _id = asset_get_index(string(_spr)); } catch (e) { _id = -1; }
    }
    if (!is_real(_id)) _id = -1;
    PKICONS.missing_icon32 = _id;
}

function pkicons_set_missing_art(_spr){
    var _id = _spr;
    if (!is_real(_id)){
        try { _id = asset_get_index(string(_spr)); } catch (e) { _id = -1; }
    }
    if (!is_real(_id)) _id = -1;
    PKICONS.missing_art96 = _id;
}

function pkicons_set_art96_base(_absDir){
    var p = string_replace_all(string(_absDir),"\\","/");
    if (string_length(p)>0 && string_copy(p,string_length(p),1)!="/") p+="/";
    PKICONS.art96_base = p;
}
function pkicons_set_icon32_base(_absDir){
    var p = string_replace_all(string(_absDir),"\\","/");
    if (string_length(p)>0 && string_copy(p,string_length(p),1)!="/") p+="/";
    PKICONS.icon32_base = p;
    // Auto derive shiny base: replace /Normal/ with /Shiny/ (case sensitive first), fallback simple append
    var shiny = string_replace_all(p,"/Normal/","/Shiny/");
    if (shiny == p) shiny = string_replace_all(p,"/normal/","/Shiny/");
    if (shiny == p){
        // no segment found; append Shiny/ sibling
        shiny = p + "Shiny/";
    }
    PKICONS.icon32_base_shiny = shiny;
}
function pkicons_set_icon32_shiny_base(_absDir){
    var p = string_replace_all(string(_absDir),"\\","/");
    if (string_length(p)>0 && string_copy(p,string_length(p),1)!="/") p+="/";
    PKICONS.icon32_base_shiny = p;
}

// ---------------- External item icons (by name) ----------------
// Base directory should point to the folder containing PNGs named after items
// Example: pkicons_set_item_icon_base("C:/Users/King2/Documents/Pokemon Engine/sprites/items/")
function pkicons_set_item_icon_base(_absDir){
    var p = string_replace_all(string(_absDir),"\\","/");
    if (string_length(p)>0 && string_copy(p,string_length(p),1)!="/") p+="/";
    pkicons_init();
    PKICONS.item_icon_base = p;
    // If debug is enabled, scan the base folder for known item files and attempt to load/cach them
    if (PKICONS.debug && variable_global_exists("_items") && is_array(global._items) && string_length(p) > 0){
        pkicons_scan_item_icon_base();
    }
}

// Scan the configured item_icon_base folder and attempt to load each item's icon file.
function pkicons_scan_item_icon_base(){
    var base = PKICONS.item_icon_base;
    if (string_length(base) <= 0) return;
    pkicons__log_item("pkicons_scan_item_icon_base: scanning base='" + string(base) + "' for " + string(array_length(global._items)) + " items");
    var ext = PKICONS.ext; if (string_length(ext) <= 0) ext = ".png";
    for (var i=0;i<array_length(global._items);i++){
        var it = global._items[i]; if (!is_struct(it)) continue;
        var idstr = undefined; if (variable_struct_exists(it, "identifier")) idstr = it.identifier; else if (variable_struct_exists(it, "name")) idstr = it.name;
        if (is_undefined(idstr)) continue;
        var cand = string(idstr);
        var fn = pkicons__join(base, cand + ext);
        var found = false;
        var ex = false; try { ex = file_exists(fn); } catch (e) { ex = false; }
    pkicons__log_item("pkicons_scan_item_icon_base: checking file='" + string(fn) + "' exists=" + string(ex));
        if (ex){
            var sp = -1; try { sp = sprite_add(fn,1,false,false,0,0); } catch (e) { sp = -1; }
            pkicons__log_item("pkicons_scan_item_icon_base: sprite_add('" + string(fn) + "') => " + string(sp));
            // Accept either numeric id or runtime reference if sprite_exists returns true
            var usable = false; try { if (sprite_exists(sp)) usable = true; } catch (e) { usable = false; }
            if (usable){
                variable_struct_set(PKICONS.item_icon_cache, "ITEM|" + string(cand), sp);
                variable_struct_set(PKICONS.item_icon_cache, "ITEMID|" + string(i), sp);
                pkicons__log_item("pkicons_scan_item_icon_base: cached item " + string(i) + " ('" + string(cand) + "') => sprite=" + string(sp));
                found = true;
            } else {
                // Try to coerce to an existing in-project asset
                var _co = pkicons__asset_try(cand);
                pkicons__log_item("pkicons_scan_item_icon_base: asset_try('" + string(cand) + "') => " + string(_co));
                if (is_real(_co) && sprite_exists(_co)){
                    variable_struct_set(PKICONS.item_icon_cache, "ITEM|" + string(cand), _co);
                    variable_struct_set(PKICONS.item_icon_cache, "ITEMID|" + string(i), _co);
                    pkicons__log_item("pkicons_scan_item_icon_base: coerced and cached item " + string(i) + " ('" + string(cand) + "') => asset=" + string(_co));
                    found = true;
                }
            }
        }
        if (!found){
            pkicons__log_item("pkicons_scan_item_icon_base: not found for item " + string(i) + " ('" + string(cand) + "')");
        }
    }
}

// Candidate filename generation for numeric item IDs
function pkicons__cands_item_by_id(_id){
    var out = [];
    if (!is_real(_id)) return out;
    var sid = floor(_id);
    var ext = PKICONS.ext; if (string_length(ext) <= 0) ext = ".png";
    // If item name/identifier is available in global._items, reuse name-based candidates first
    if (variable_global_exists("_items") && is_array(global._items) && sid >= 0 && sid < array_length(global._items)){
        var it = global._items[sid];
        if (is_struct(it)){
            // Prefer the canonical CSV `identifier` field for sprite lookups; fall back to `name` if identifier missing
            var iname = undefined;
            if (variable_struct_exists(it, "identifier")) iname = it.identifier; else if (variable_struct_exists(it, "name")) iname = it.name;
            if (!is_undefined(iname)){
                var nm = string(iname);
                // Build tight name-based candidates (no cleaning beyond these deterministic variants)
                array_push(out, nm + ext);
                array_push(out, string_lower(nm) + ext);
                // removed spr_ prefixed fallbacks (project resources don't use spr_ prefix)
                array_push(out, nm);
                array_push(out, string_lower(nm));
            }
        }
    }
    // Append numeric candidates (fallback)
    array_push(out, string(sid) + ext);
    // zero-padded (3 digits, 4 digits)
    var p3 = string_repeat("0", max(0, 3 - string_length(string(sid)))) + string(sid);
    array_push(out, p3 + ext);
    var p4 = string_repeat("0", max(0, 4 - string_length(string(sid)))) + string(sid);
    array_push(out, p4 + ext);
    // common prefixes
    array_push(out, "item_" + string(sid) + ext);
    array_push(out, "item" + string(sid) + ext);
    array_push(out, "itm" + string(sid) + ext);
    // de-duplicate while preserving order
    var seen = {}; var uniq = [];
    for (var i=0;i<array_length(out);i++){ var v = out[i]; if (variable_struct_exists(seen,v)) continue; variable_struct_set(seen,v,true); array_push(uniq,v); }
    return uniq;
}

// Helper: try to resolve an asset symbol for candidate strings (with/without extension)
function pkicons__asset_try(_cand){
    var out = -1;
    if (is_undefined(_cand) || string_length(string_trim(string(_cand)))==0) return -1;
    var ext = PKICONS.ext; if (string_length(ext) <= 0) ext = ".png";
    try { out = asset_get_index(string(_cand)); } catch (e) { out = -1; }
    
    if (is_real(out) && sprite_exists(out)) { pkicons__log_item("pkicons__asset_try: resolved sprite idx=" + string(out)); return out; }
    // try without extension
    var noext = string(_cand);
    if (string_length(noext) > string_length(ext)) noext = string_copy(noext,1,string_length(noext)-string_length(ext));
    try { out = asset_get_index(string(noext)); } catch (e) { out = -1; }
    
    if (is_real(out) && sprite_exists(out)) { pkicons__log_item("pkicons__asset_try: resolved sprite idx=" + string(out)); return out; }
    return -1;
}

// Public: get item icon by numeric item id. Returns the same types as pkicons_get_item_icon_by_name
function pkicons_get_item_icon_by_id(_id){
    pkicons_init();
    var key = "ITEMID|" + string(_id);
    pkicons__log_item("pkicons_get_item_icon_by_id: enter id=" + string(_id) + " key=" + key);
    // Check cache first
    if (variable_struct_exists(PKICONS.item_icon_cache,key)){
        var cached = variable_struct_get(PKICONS.item_icon_cache,key);
    pkicons__log_item("pkicons_get_item_icon_by_id: cache entry found for " + key + " => " + string(cached));
        // Try to coerce cached to numeric id if possible
        if (is_real(cached) && sprite_exists(cached)) return cached;
        if (!is_real(cached)){
            var _tryIdx = -1; try { _tryIdx = asset_get_index(string(cached)); } catch (e) { _tryIdx = -1; }
            pkicons__log_item("pkicons_get_item_icon_by_id: coerced cached via asset_get_index => " + string(_tryIdx));
            if (is_real(_tryIdx) && sprite_exists(_tryIdx)) return _tryIdx;
            // if raw runtime ref works with sprite_exists, return it
            try { if (sprite_exists(cached)) return cached; } catch (e) { /* ignore */ }
        }
    }

    // Attempt to resolve via item name if available
    if (variable_global_exists("_items") && is_array(global._items) && _id >= 0 && _id < array_length(global._items)){
        var it = global._items[_id];
        if (is_struct(it)){
            // Prefer identifier as canonical lookup string, falling back to name
            var iname = undefined;
            if (variable_struct_exists(it, "identifier")) iname = it.identifier; else if (variable_struct_exists(it, "name")) iname = it.name;
            if (!is_undefined(iname)){
                pkicons__log_item("pkicons_get_item_icon_by_id: resolve by identifier/name='" + string(iname) + "'");
                // Build a tight list of candidates directly from the canonical item identifier (no cleaning)
                var nameCandidates = [];
                var nm = string(iname);
                array_push(nameCandidates, nm + PKICONS.ext);
                array_push(nameCandidates, string_lower(nm) + PKICONS.ext);
                // spr_ prefixed fallbacks removed
                // also try raw name without ext
                array_push(nameCandidates, nm);
                array_push(nameCandidates, string_lower(nm));

                // First try in-project assets (fast)
                for (var nc=0; nc<array_length(nameCandidates); nc++){
                    var cand = nameCandidates[nc];
                    pkicons__log_item("pkicons_get_item_icon_by_id: trying asset candidate='" + string(cand) + "'");
                    var idx = pkicons__asset_try(cand);
                    if (is_real(idx) && sprite_exists(idx)){
                        pkicons__log_item("pkicons_get_item_icon_by_id: asset resolved candidate='" + string(cand) + "' => idx=" + string(idx));
                        variable_struct_set(PKICONS.item_icon_cache,key,idx);
                        variable_struct_set(PKICONS.item_icon_cache,"ITEM|"+string(iname),idx);
                        return idx;
                    }
                }
                // Then try external files under base (if configured)
                var base = PKICONS.item_icon_base;
                if (string_length(base) > 0){
                    for (var nc2=0; nc2<array_length(nameCandidates); nc2++){
                        var fn = pkicons__join(base, nameCandidates[nc2]);
                        var ex = false; try { ex = file_exists(fn); } catch (e) { ex = false; }
                        pkicons__log_item("pkicons_get_item_icon_by_id: checking file '" + string(fn) + "' exists=" + string(ex));
                        if (ex){
                            var _raw = -1; try { _raw = sprite_add(fn,1,false,false,0,0); } catch (e) { _raw = -1; }
                            pkicons__log_item("pkicons_get_item_icon_by_id: sprite_add('" + string(fn) + "') => " + string(_raw));
                            if (is_real(_raw) && sprite_exists(_raw)){
                                pkicons__log_item("pkicons_get_item_icon_by_id: sprite_add produced usable sprite idx=" + string(_raw));
                                variable_struct_set(PKICONS.item_icon_cache,key,_raw);
                                variable_struct_set(PKICONS.item_icon_cache,"ITEM|"+string(iname),_raw);
                                return _raw;
                            }
                            // try to coerce to asset index by basename
                            var bn = nameCandidates[nc2];
                            var _co = pkicons__asset_try(bn);
                            pkicons__log_item("pkicons_get_item_icon_by_id: post-file asset_try basename='" + string(bn) + "' => " + string(_co));
                            if (is_real(_co) && sprite_exists(_co)){ pkicons__log("pkicons_get_item_icon_by_id: coerced to asset idx=" + string(_co)); variable_struct_set(PKICONS.item_icon_cache,key,_co); variable_struct_set(PKICONS.item_icon_cache,"ITEM|"+string(iname),_co); return _co; }
                        }
                    }
                }
            }
        }
    }

    // Try numeric filename candidates
    var base = PKICONS.item_icon_base;
    if (PKICONS.debug_items) pkicons__log_item("pkicons_get_item_icon_by_id: base='" + string(base) + "' id='" + string(_id) + "'");
    if (string_length(base) <= 0){
        // No external base configured — attempt to resolve against project assets by name or numeric candidates
        pkicons__log("item icon base not set; trying asset symbols for id: " + string(_id));
        // Try resolving by item name first (if available)
        if (variable_global_exists("_items") && is_array(global._items) && _id >= 0 && _id < array_length(global._items)){
            var itn = global._items[_id];
            if (is_struct(itn)){
                var iname = undefined;
                if (variable_struct_exists(itn, "name")) iname = itn.name; else if (variable_struct_exists(itn, "identifier")) iname = itn.identifier;
                if (!is_undefined(iname)){
                    var tryByName = pkicons_get_item_icon_by_name(string(iname));
                    if (is_real(tryByName) && sprite_exists(tryByName)){ variable_struct_set(PKICONS.item_icon_cache,key,tryByName); return tryByName; }
                }
            }
        }
        // Try numeric candidate filenames as asset symbols
        var cands_try = pkicons__cands_item_by_id(_id);
        var extLocal = PKICONS.ext; if (string_length(extLocal) <= 0) extLocal = ".png";
        for (var ti=0; ti<array_length(cands_try); ti++){
            var cand = cands_try[ti];
            var idx = -1; try { idx = asset_get_index(string(cand)); } catch (ee) { idx = -1; }
            pkicons__log_item("pkicons_get_item_icon_by_id: trying numeric asset candidate='" + string(cand) + "' => idx=" + string(idx));
            if (is_real(idx) && sprite_exists(idx)){ pkicons__log("pkicons_get_item_icon_by_id: numeric candidate resolved idx=" + string(idx)); variable_struct_set(PKICONS.item_icon_cache,key,idx); return idx; }
            var noext = cand; if (string_length(noext) > string_length(extLocal)) noext = string_copy(noext,1,string_length(noext)-string_length(extLocal));
            idx = -1; try { idx = asset_get_index(string(noext)); } catch (ee) { idx = -1; }
            pkicons__log_item("pkicons_get_item_icon_by_id: trying numeric asset candidate noext='" + string(noext) + "' => idx=" + string(idx));
            if (is_real(idx) && sprite_exists(idx)){ pkicons__log("pkicons_get_item_icon_by_id: numeric candidate noext resolved idx=" + string(idx)); variable_struct_set(PKICONS.item_icon_cache,key,idx); return idx; }
        }
        var miss = (variable_struct_exists(PKICONS,"missing_icon32")?variable_struct_get(PKICONS,"missing_icon32"):-1);
        variable_struct_set(PKICONS.item_icon_cache,key,miss);
        return miss;
    }

    var cands = pkicons__cands_item_by_id(_id);
    var spr = -1; var last_raw = undefined;
    var ext = PKICONS.ext; if (string_length(ext) <= 0) ext = ".png";
    for (var i=0;i<array_length(cands);i++){
        var fn = pkicons__join(base, cands[i]);
        var ex = false; try { ex = file_exists(fn); } catch (e) { ex = false; }
            pkicons__log_item("pkicons_get_item_icon_by_id: checking file '" + string(fn) + "' exists=" + string(ex));
            if (ex){
                var _raw = -1;
                try { _raw = sprite_add(fn,1,false,false,0,0); } catch (e) { _raw = -1; }
                last_raw = _raw;
                pkicons__log_item("pkicons_get_item_icon_by_id: sprite_add('" + string(fn) + "') => " + string(_raw));
                if (is_real(_raw) && sprite_exists(_raw)){ spr = _raw; pkicons__log_item("pkicons_get_item_icon_by_id: sprite_add produced sprite idx=" + string(_raw)); break; }
                // try candidate filename as asset symbol
                var _tryIdx = -1;
                try { _tryIdx = asset_get_index(string(cands[i])); } catch (e) { _tryIdx = -1; }
                pkicons__log_item("pkicons_get_item_icon_by_id: asset_get_index(candidate='" + string(cands[i]) + "') => " + string(_tryIdx));
                if (!is_real(_tryIdx)){
                    var _withoutExt = cands[i]; if (string_length(_withoutExt) > string_length(ext)) _withoutExt = string_copy(_withoutExt,1,string_length(_withoutExt)-string_length(ext));
                    try { _tryIdx = asset_get_index(string(_withoutExt)); } catch (e) { _tryIdx = -1; }
                    pkicons__log_item("pkicons_get_item_icon_by_id: asset_get_index(noext='" + string(_withoutExt) + "') => " + string(_tryIdx));
                }
                if (is_real(_tryIdx) && sprite_exists(_tryIdx)){ spr = _tryIdx; pkicons__log("pkicons_get_item_icon_by_id: resolved from asset idx=" + string(_tryIdx)); break; }
                try { if (sprite_exists(_raw)){ spr = _raw; pkicons__log_item("pkicons_get_item_icon_by_id: accepting raw sprite ref=" + string(_raw)); break; } } catch (e) { }
    }
    }
    if (!is_real(spr) || !sprite_exists(spr)) spr = (variable_struct_exists(PKICONS,"missing_icon32")?variable_struct_get(PKICONS,"missing_icon32"):-1);
    pkicons__log_item("pkicons_get_item_icon_by_id: final resolved sprite for id=" + string(_id) + " => " + string(spr));
    variable_struct_set(PKICONS.item_icon_cache,key,spr);
    return spr;
}

function pkicons_get_item_icon_by_name(_name){
    pkicons_init();
    var key = "ITEM|" + string(_name);
    pkicons__log_item("pkicons_get_item_icon_by_name: enter name='" + string(_name) + "' key='" + key + "'");
    // Ensure the configured missing placeholder is a numeric asset index
    if (variable_struct_exists(PKICONS,"missing_icon32")){
        var _ph_raw = variable_struct_get(PKICONS,"missing_icon32");
        if (!is_real(_ph_raw)){
            // Attempt to resolve symbol/string to asset index
            var _resolved = -1;
            try { _resolved = asset_get_index(string(_ph_raw)); } catch (e) { _resolved = -1; }
            if (is_real(_resolved)) variable_struct_set(PKICONS, "missing_icon32", _resolved);
        }
    }

    // Use exact name candidates (no further text cleaning)
    if (variable_struct_exists(PKICONS.item_icon_cache,key)){
        var cached = variable_struct_get(PKICONS.item_icon_cache,key);
    pkicons__log_item("pkicons_get_item_icon_by_name: cache entry for " + key + " => " + string(cached));
        if (!is_real(cached)){
            var _tryIdx = -1; try { _tryIdx = asset_get_index(string(cached)); } catch (e) { _tryIdx = -1; }
            pkicons__log_item("pkicons_get_item_icon_by_name: coercion asset_get_index(cached) => " + string(_tryIdx));
            if (is_real(_tryIdx)) cached = _tryIdx;
        }
    if (!is_undefined(cached) && sprite_exists(cached)) { pkicons__log_item("pkicons_get_item_icon_by_name: returning cached sprite idx=" + string(cached)); return cached; }
    }
    // If the provided _name matches an entry in global._items, prefer that item's `identifier` as the canonical lookup string
    var canonical = string_trim(string(_name));
    if (variable_global_exists("_items") && is_array(global._items)){
        for (var mi=0; mi<array_length(global._items); mi++){
            var mit = global._items[mi];
            if (!is_struct(mit)) continue;
            var mid = undefined; if (variable_struct_exists(mit, "identifier")) mid = mit.identifier;
            var mname = undefined; if (variable_struct_exists(mit, "name")) mname = mit.name;
            if (!is_undefined(mname) && string_lower(string(mname)) == string_lower(string(_name))){ if (!is_undefined(mid)) { canonical = mid; } else { canonical = mname; } break; }
            if (!is_undefined(mid) && string_lower(string(mid)) == string_lower(string(_name))){ canonical = mid; break; }
        }
    }
    var ext = PKICONS.ext; if (string_length(ext) <= 0) ext = ".png";
    var candidates = [];
    var nm = canonical;
    array_push(candidates, nm);
    array_push(candidates, string_lower(nm));
    array_push(candidates, nm + ext);
    array_push(candidates, string_lower(nm) + ext);
    // spr_ prefixed fallbacks removed

    // Try in-project assets first
    for (var ci=0; ci<array_length(candidates); ci++){
        var cand = candidates[ci];
    pkicons__log_item("pkicons_get_item_icon_by_name: trying candidate='" + string(cand) + "'");
    var idx = pkicons__asset_try(cand);
    pkicons__log_item("pkicons_get_item_icon_by_name: asset_try('" + string(cand) + "') => " + string(idx));
        if (is_real(idx) && sprite_exists(idx)){
            pkicons__log_item("pkicons_get_item_icon_by_name: resolved candidate='" + string(cand) + "' => idx=" + string(idx));
            variable_struct_set(PKICONS.item_icon_cache,key,idx);
            // cache under ITEMID if possible
            if (variable_global_exists("_items") && is_array(global._items)){
                for (var ii=0; ii<array_length(global._items); ii++){
                    var it = global._items[ii]; if (!is_struct(it)) continue;
                    var iname = undefined; if (variable_struct_exists(it, "name")) iname = it.name; else if (variable_struct_exists(it, "identifier")) iname = it.identifier;
                    if (!is_undefined(iname) && string_lower(string(iname)) == string_lower(nm)) { variable_struct_set(PKICONS.item_icon_cache, "ITEMID|" + string(ii), idx); break; }
                }
            }
            return idx;
        }
    }

    // If item_icon_base is configured, try file-based candidates (with extension)
    var base = PKICONS.item_icon_base;
    if (string_length(base) > 0){
        for (var ci2=0; ci2<array_length(candidates); ci2++){
            var cand2 = candidates[ci2];
            var fn = pkicons__join(base, (string_length(cand2) > string_length(ext) && string_copy(cand2, string_length(cand2)-string_length(ext)+1, string_length(ext)) == ext) ? cand2 : cand2 + ext);
            var ex = false; try { ex = file_exists(fn); } catch (e) { ex = false; }
            pkicons__log_item("pkicons_get_item_icon_by_name: checking file '" + string(fn) + "' exists=" + string(ex));
            if (ex){
                var _raw = -1; try { _raw = sprite_add(fn,1,false,false,0,0); } catch (e) { _raw = -1; }
                pkicons__log_item("pkicons_get_item_icon_by_name: sprite_add('" + string(fn) + "') => " + string(_raw));
                // Accept runtime refs too if sprite_exists reports true
                var _usable = false; try { if (sprite_exists(_raw)) _usable = true; } catch (e) { _usable = false; }
                if (_usable){
                    pkicons__log_item("pkicons_get_item_icon_by_name: sprite_add produced usable sprite (runtime ref allowed)='" + string(_raw) + "'");
                    variable_struct_set(PKICONS.item_icon_cache,key,_raw);
                    // also cache under ITEMID if possible (find matching id)
                    if (variable_global_exists("_items") && is_array(global._items)){
                        for (var _ii=0; _ii<array_length(global._items); _ii++){
                            var _itx = global._items[_ii]; if (!is_struct(_itx)) continue;
                            var _ident = undefined; if (variable_struct_exists(_itx, "identifier")) _ident = _itx.identifier; else if (variable_struct_exists(_itx, "name")) _ident = _itx.name;
                            if (!is_undefined(_ident) && string_lower(string(_ident)) == string_lower(nm)) { variable_struct_set(PKICONS.item_icon_cache, "ITEMID|" + string(_ii), _raw); break; }
                        }
                    }
                    return _raw;
                }
                // try to coerce via asset name
                var bn = cand2; var _co = pkicons__asset_try(bn);
                pkicons__log_item("pkicons_get_item_icon_by_name: post-file asset_try basename='" + string(bn) + "' => " + string(_co));
                if (is_real(_co) && sprite_exists(_co)){ pkicons__log_item("pkicons_get_item_icon_by_name: coerced to asset idx=" + string(_co)); variable_struct_set(PKICONS.item_icon_cache,key,_co); return _co; }
            }
        }
    }

    var miss = (variable_struct_exists(PKICONS,"missing_icon32") ? variable_struct_get(PKICONS,"missing_icon32") : -1);
    if (!is_real(miss)) miss = -1;
    variable_struct_set(PKICONS.item_icon_cache,key,miss);
    return miss;
}


// ---------- Cry (sound) loader (per-species OGG streaming) ----------
function pkicons_set_cries_base(_absDir){
    var p = string_replace_all(string(_absDir),"\\","/");
    if (string_length(p)>0 && string_copy(p,string_length(p),1)!="/") p+="/";
    pkicons_init();
    PKICONS.cries_base = p;
}

function pkicons__cands_cries(_species){
    var ret=[];
    if (is_real(_species)){
        var sid_val = floor(_species);
        // Only use the plain species id (no zero-padding) per user preference
        array_push(ret, string(floor(sid_val)));
    } else {
        var s = string_trim(string(_species));
        array_push(ret, s);
    }
    return ret;
}

function pkicons_get_cry(_species){
    pkicons_init();
    var key = "CRY|"+string(_species);
    if (variable_struct_exists(PKICONS.art_cache,key)){
        var c = variable_struct_get(PKICONS.art_cache,key);
        // If cached and valid (non -1), return it. If cached -1 (not found) continue so loader will retry.
        if (!is_undefined(c) && c != -1) return c;
    }
    var base = (variable_struct_exists(PKICONS,"cries_base") ? PKICONS.cries_base : "");
    if (string_length(base) <= 0){
        pkicons__log("cry base not set; cannot load cries (species="+string(_species)+")");
        return -1;
    }
    var cands = pkicons__cands_cries(_species);
    var exts = [".ogg"]; // prefer .ogg (streaming)
    var fn = ""; var snd = -1;
    // reset simple debug tracking
    if (variable_struct_exists(PKICONS,"last_cry_loaded")) variable_struct_set(PKICONS,"last_cry_loaded","");
    if (variable_struct_exists(PKICONS,"last_cry_status")) variable_struct_set(PKICONS,"last_cry_status","");
    for (var i=0;i<array_length(cands);i++){
        for (var ei=0; ei<array_length(exts); ei++){
            fn = pkicons__join(base, cands[i] + exts[ei]);
            var _exists = file_exists(fn);
            if (PKICONS.debug_crys) pkicons__log_cry("trying cry file: " + fn + " exists=" + string(_exists));
            // only attempt load if file exists
            if (_exists){
                // Use streaming loader (OGG files need streaming in many runtimes)
                snd = -1;
                try {
                    snd = audio_create_stream(fn);
                    if (!is_undefined(snd) && snd != -1){
                        if (PKICONS.debug_crys) pkicons__log_cry("cry loaded (audio_create_stream): "+fn+" -> id="+string(snd));
                    }
                } catch (e) {
                    snd = -1;
                }
                // If we obtained an id, additionally log whether sound_exists thinks it's a sound asset
                if (!is_undefined(snd) && snd != -1){
                    var _se = false;
                    try { _se = sound_exists(snd); } catch (ee) { _se = false; }
                    if (PKICONS.debug_crys) pkicons__log_cry(" cry load check: sound_exists("+string(snd)+")="+string(_se));
                    if (!is_undefined(snd) && snd != -1) break;
                }
            }
        }
        if (!is_undefined(snd) && snd != -1) break;
    }
    if (snd == -1) snd = -1;
    if (snd == -1) {
        if (variable_struct_exists(PKICONS,"last_cry_status")) variable_struct_set(PKICONS,"last_cry_status","not_found");
    } else {
        if (variable_struct_exists(PKICONS,"last_cry_loaded")) variable_struct_set(PKICONS,"last_cry_loaded",fn);
        if (variable_struct_exists(PKICONS,"last_cry_status")) variable_struct_set(PKICONS,"last_cry_status","loaded");
    }
    variable_struct_set(PKICONS.art_cache, key, snd);
    return snd;
}

// Verbose debug helpers (tied to PKICONS.debug). These are safe to call at runtime
// but only emit diagnostic messages when PKICONS.debug is true.
function pkicons_get_cry_debug(_species){
    pkicons_init();
    var base = (variable_struct_exists(PKICONS,"cries_base") ? PKICONS.cries_base : "");
    if (string_length(base) <= 0){ if (PKICONS.debug_crys) pkicons__log_cry("pkicons_get_cry_debug: cries_base not set"); return -1; }
    var cands = pkicons__cands_cries(_species);
    var exts = [".ogg"]; // OGG streaming only
    if (PKICONS.debug_crys) pkicons__log_cry("pkicons_get_cry_debug: species="+string(_species)+" base="+base);
    var fn = ""; var snd = -1;
    for (var i=0;i<array_length(cands);i++){
        for (var ei=0; ei<array_length(exts); ei++){
            fn = pkicons__join(base, cands[i] + exts[ei]);
            var ex = false;
            try { ex = file_exists(fn); } catch (ee) { ex = false; }
            if (PKICONS.debug_crys) pkicons__log_cry("  candidate: "+fn+" exists="+string(ex));
            if (ex){
                try {
                    snd = audio_create_stream(fn);
                    if (!is_undefined(snd) && snd != -1){ if (PKICONS.debug_crys) pkicons__log_cry("  loaded with audio_create_stream id="+string(snd)); }
                } catch (e) { snd = -1; }
                if (!is_undefined(snd) && snd != -1){
                    var key = "CRY|"+string(_species);
                    variable_struct_set(PKICONS.art_cache, key, snd);
                    variable_struct_set(PKICONS,"last_cry_loaded",fn);
                    variable_struct_set(PKICONS,"last_cry_status","loaded");
                    return snd;
                } else {
                    if (PKICONS.debug_crys) pkicons__log_cry("  candidate found but failed to load: "+fn);
                }
            }
        }
    }
    if (PKICONS.debug_crys) pkicons__log_cry("pkicons_get_cry_debug: no matching cry found for species="+string(_species));
    variable_struct_set(PKICONS,"last_cry_status","not_found");
    return -1;
}

// Quick OGG inspector: returns info about a path or species-number. Logs only when debug enabled.
function pkicons_inspect_ogg(_pathOrSpecies){
    pkicons_init();
    var base = (variable_struct_exists(PKICONS,"cries_base") ? PKICONS.cries_base : "");
    var fn = "";
    if (is_real(_pathOrSpecies)){
    if (string_length(base) <= 0){ if (PKICONS.debug_crys) pkicons__log_cry("pkicons_inspect_ogg: cries_base not set"); return { path:"", exists:false }; }
        fn = pkicons__join(base, string(floor(_pathOrSpecies)) + ".ogg");
    } else {
        fn = string(_pathOrSpecies);
    }

    var info = { path: fn, exists: false, size: 0, audio_create_ok: false, audio_create_id: -1, notes: "" };
    try { info.exists = file_exists(fn); } catch (e) { info.exists = false; }
    if (!info.exists){ if (PKICONS.debug_crys) pkicons__log_cry("pkicons_inspect_ogg: not found: " + fn); return info; }
    try { info.size = file_size(fn); } catch (e) { info.size = 0; }

    try {
        var s = audio_create_stream(fn);
        if (!is_undefined(s) && s != -1){
            info.audio_create_ok = true;
            info.audio_create_id = s;
            if (PKICONS.debug_crys) pkicons__log_cry("pkicons_inspect_ogg: audio_create_stream succeeded id=" + string(s) + " for " + fn);
        } else {
            info.audio_create_ok = false;
            pkicons__log("pkicons_inspect_ogg: audio_create_stream returned -1 for " + fn);
        }
    } catch (e2) {
        info.audio_create_ok = false;
        pkicons__log("pkicons_inspect_ogg: audio_create_stream threw an error for " + fn + " (likely unsupported encoding or runtime limitation)");
    }

    if (variable_struct_exists(PKICONS,"last_cry_loaded") && info.audio_create_ok) variable_struct_set(PKICONS,"last_cry_loaded",info.path);
    if (variable_struct_exists(PKICONS,"last_cry_status")) variable_struct_set(PKICONS,"last_cry_status", info.audio_create_ok ? "loaded" : "not_found");

    return info;
}

// Small debug overlay that writes state to debug log (kept but quiet unless PKICONS.debug is true)
function pkicons_draw_debug_overlay(_x,_y){
    if (!variable_struct_exists(PKICONS,"debug") || !PKICONS.debug) return;
    pkicons__log("---- pkicons cry debug ----");
    if (variable_struct_exists(PKICONS,"last_cry_loaded") && string_length(variable_struct_get(PKICONS,"last_cry_loaded"))>0) pkicons__log("loaded: " + variable_struct_get(PKICONS,"last_cry_loaded"));
    if (variable_struct_exists(PKICONS,"last_cry_status")) pkicons__log("status: " + variable_struct_get(PKICONS,"last_cry_status"));
    if (variable_struct_exists(PKICONS,"last_play_status")) pkicons__log("play: " + variable_struct_get(PKICONS,"last_play_status"));
    if (variable_struct_exists(PKICONS,"last_play_channel")) pkicons__log("play_channel: " + string(variable_struct_get(PKICONS,"last_play_channel")));
    pkicons__log("--------------------------");
}

function pkicons_play_cry_by_mon(_mon){
    if (!is_struct(_mon)) return;
    pkicons_init();
    var sid = -1;
    if (variable_struct_exists(_mon,"species_id") && is_real(_mon.species_id)) sid = _mon.species_id; else if (variable_struct_exists(_mon,"species")) sid = _mon.species;
    if (sid < 0) return;
    if (PKICONS.debug_crys) pkicons__log_cry("play cry requested for species="+string(sid));
    var s = pkicons_get_cry(sid);
    // Report what we have loaded so far
    var loadedFn = (variable_struct_exists(PKICONS,"last_cry_loaded") ? variable_struct_get(PKICONS,"last_cry_loaded") : "");
    var loadedStatus = (variable_struct_exists(PKICONS,"last_cry_status") ? variable_struct_get(PKICONS,"last_cry_status") : "");
    if (PKICONS.debug_crys) pkicons__log_cry(" pkicons_play_cry_by_mon: got cry id="+string(s)+" last_loaded="+string(loadedFn)+" status="+string(loadedStatus));

    if (s == -1){
        pkicons__log("no cry available for species="+string(sid));
        if (variable_struct_exists(PKICONS,"last_play_status")) variable_struct_set(PKICONS,"last_play_status","no_cry");
        return;
    }

    // Try playing the sound. Record the playback result and any returned channel/id so we can inspect.
    var _played = false;
    var _play_id = -1;

    // Try modern audio_play_sound first (wrap in try to handle runtimes without it)
    try {
        // Try to lower the playback level to ~0.8. Use per-sound gain if available, else try per-channel after play.
        try {
            audio_sound_gain(s, 0.8, 0);
        } catch (e_gain) {
            // audio_sound_gain not available on this runtime; we'll try channel gain after play
        }
        // audio_play_sound may return an audio channel id in newer runtimes; capture it if provided
        var _ret = audio_play_sound(s, 1, false);
        // If channel gain is supported, try to set it on the returned channel id
        try {
            audio_channel_gain(_ret, 0.8, 0);
        } catch (e_ch) {
            // ignore if not supported
        }
        _played = true;
        _play_id = _ret;
    if (PKICONS.debug_crys) pkicons__log_cry("audio_play_sound called for species="+string(sid)+" sound="+string(s)+" ret="+string(_ret));
    } catch (e) {
        // audio_play_sound not available or errored
        _played = false;
        _play_id = -1;
    }

    if (!_played) {
        if (PKICONS.debug_crys) pkicons__log_cry("pkicons_play_cry_by_mon: failed to play cry for species="+string(sid)+" id="+string(s));
        if (variable_struct_exists(PKICONS,"last_play_status")) variable_struct_set(PKICONS,"last_play_status","no_api_or_failed");
    } else {
        // Save last_play_status + channel/id for debug
        if (variable_struct_exists(PKICONS,"last_play_status")) variable_struct_set(PKICONS,"last_play_status","played");
        if (variable_struct_exists(PKICONS,"last_play_channel")) variable_struct_set(PKICONS,"last_play_channel",_play_id);
        else variable_struct_set(PKICONS,"last_play_channel",_play_id);
    }
}

function pkicons__join(_a,_b){
    var A=string(_a),B=string(_b);
    if (string_length(A)<=0) return B;
    if (string_copy(A,string_length(A),1)!="/") A+="/";
    return A+B;
}

// Helper: check a single species cry file (OGG streaming only) and log result
function pkicons_check_cry(_species){
    pkicons_init();
    var base = (variable_struct_exists(PKICONS,"cries_base") ? PKICONS.cries_base : "");
    if (string_length(base) <= 0){ pkicons__log("pkicons_check_cry: cries_base not set"); return ""; }
    var sid = floor(_species);
    var fnO = pkicons__join(base, string(sid) + ".ogg");
    var exO = false;
    try { exO = file_exists(fnO); } catch (e) { exO = false; }
    if (exO){ pkicons__log("pkicons_check_cry: check species="+string(sid)+" path="+fnO+" exists=1 (ogg)"); return fnO; }
    pkicons__log("pkicons_check_cry: check species="+string(sid)+" not found (ogg)");
    return "";
}

// Helper: scan species 1.._max and return array of found species ids (quiet except logs)
function pkicons_test_all_cries(_max){
    pkicons_init();
    var base = (variable_struct_exists(PKICONS,"cries_base") ? PKICONS.cries_base : "");
    var found = [];
    if (string_length(base) <= 0){ pkicons__log("pkicons_test_all_cries: cries_base not set"); return found; }
    var m = max(1, floor(_max));
    for (var i=1; i<=m; i++){
        var fnO = pkicons__join(base, string(i) + ".ogg");
        if (file_exists(fnO)) array_push(found, i);
    }
    pkicons__log("pkicons_test_all_cries: found="+string(array_length(found))+" up to="+string(m));
    return found;
}

// (pkicons_scan_cries removed — single-file inspector `pkicons_inspect_ogg` is available)

// (debug overlay removed)

function pkicons__cands(_species){
    var ret=[];
    if (is_real(_species)){
        var sid_val=floor(_species);
        array_push(ret,string(sid_val)+PKICONS.ext);
        array_push(ret,string_format(sid_val,3,0)+PKICONS.ext);
        array_push(ret,string_format(sid_val,4,0)+PKICONS.ext);
    } else {
        var s=string(_species);
        array_push(ret,s+PKICONS.ext);
        array_push(ret,string_upper(s)+PKICONS.ext);
        array_push(ret,string_lower(s)+PKICONS.ext);
    }
    return ret;
}

// Check whether a 32x32 icon file exists for a species (optionally shiny).
// Returns true if a candidate file exists on disk under the configured base.
function pkicons_has_icon32(_species, _shiny){
    pkicons_init();
    var base = _shiny ? PKICONS.icon32_base_shiny : PKICONS.icon32_base;
    if (string_length(base) <= 0) return false;
    var cands = pkicons__cands(_species);
    for (var i=0; i<array_length(cands); i++){
        var fn = pkicons__join(base, cands[i]);
        var ex = false;
        try { ex = file_exists(fn); } catch (e) { ex = false; }
        if (ex) return true;
    }
    return false;
}

// Preload cries for a numeric range (inclusive). Returns a struct { loaded:[], missing:[] }
function pkicons_preload_cries(_start, _end){
    pkicons_init();
    var s = floor(_start); var e = floor(_end);
    if (e < s){ var t = s; s = e; e = t; }
    var loaded = [];
    var missing = [];
    var total = max(0, e - s + 1);
    var cnt = 0;
    for (var i = s; i <= e; i++){
        // Call the loader which will cache results
        var snd = -1;
        try { snd = pkicons_get_cry(i); } catch (err) { snd = -1; }
        if (!is_undefined(snd) && snd != -1) array_push(loaded, i);
        else array_push(missing, i);
        cnt += 1;
        // Log occasional progress if debug enabled
        if (PKICONS.debug && (cnt mod 50) == 0) pkicons__log("pkicons_preload_cries: progress " + string(cnt) + "/" + string(total));
    }
    pkicons__log("pkicons_preload_cries: done. loaded="+string(array_length(loaded))+" missing="+string(array_length(missing))+" range="+string(s)+".."+string(e));
    return { loaded: loaded, missing: missing };
}

// Convenience loader: preload species 0..901 (inclusive) — call this in your game's init before start
function pkicons_preload_all_cries(){
    return pkicons_preload_cries(0, 901);
}

// ---------------- 96×96 Summary Art ----------------
function pkicons_get_art96(_species){
    // Load a 2x2 grid sheet (front/back normal on top row; front/back shiny on bottom row)
    pkicons_init();
    var key = "ART|"+string(_species);
    if (variable_struct_exists(PKICONS.art_cache,key)){
        var cached = variable_struct_get(PKICONS.art_cache,key);
        if (sprite_exists(cached)) return cached;
    }
    var base=PKICONS.art96_base; if (string_length(base)<=0) return PKICONS.missing_art96;
    var sheet=-1; var cands=pkicons__cands(_species); var fn="";
    for (var i=0;i<array_length(cands); i++){
        fn = pkicons__join(base,cands[i]);
        if (file_exists(fn)){
            sheet = sprite_add(fn,1,false,false,0,0);
            if (sprite_exists(sheet)) break;
        }
    }
    if (!sprite_exists(sheet)){
        variable_struct_set(PKICONS.art_cache,key,PKICONS.missing_art96);
        variable_struct_set(PKICONS.art_meta,key,{ mode:"missing"});
        return PKICONS.missing_art96;
    }

    var fullW = sprite_get_width(sheet);
    var fullH = sprite_get_height(sheet);
    // Expect exact 2 columns, 2 rows => each frame square
    if ((fullW mod 2) != 0 || (fullH mod 2) != 0){
        pkicons__log("art96 invalid dims (need even/2x2) species="+string(_species)+" w="+string(fullW)+" h="+string(fullH));
        variable_struct_set(PKICONS.art_cache,key,PKICONS.missing_art96);
        variable_struct_set(PKICONS.art_meta,key,{ mode:"invalid"});
        if (sheet != PKICONS.missing_art96) sprite_delete(sheet);
        return PKICONS.missing_art96;
    }
    var frameW = fullW div 2;
    var frameH = fullH div 2;
    if (frameW <=0 || frameH <=0){
        variable_struct_set(PKICONS.art_cache,key,PKICONS.missing_art96);
        variable_struct_set(PKICONS.art_meta,key,{ mode:"invalid"});
        if (sheet != PKICONS.missing_art96) sprite_delete(sheet);
        return PKICONS.missing_art96;
    }

    var surf = surface_create(frameW, frameH);
    if (!surface_exists(surf)){
        variable_struct_set(PKICONS.art_cache,key,PKICONS.missing_art96);
        variable_struct_set(PKICONS.art_meta,key,{ mode:"error"});
        if (sheet != PKICONS.missing_art96) sprite_delete(sheet);
        return PKICONS.missing_art96;
    }

    var quad = -1; // resulting 4-frame sprite
    for (var f=0; f<4; f++){
        var sx = (f % 2) * frameW;
        var sy = (f div 2) * frameH;
        surface_set_target(surf);
        draw_clear_alpha(c_black,0);
        draw_sprite_part_ext(sheet,0,sx,sy,frameW,frameH,0,0,1,1,c_white,1);
        surface_reset_target();
        if (f==0) quad = sprite_create_from_surface(surf,0,0,frameW,frameH,false,false,0,0);
        else if (sprite_exists(quad)) sprite_add_from_surface(quad,surf,0,0,frameW,frameH,false,false);
    }
    surface_free(surf);
    if (sheet != PKICONS.missing_art96) sprite_delete(sheet);
    if (!sprite_exists(quad)){
        variable_struct_set(PKICONS.art_cache,key,PKICONS.missing_art96);
        variable_struct_set(PKICONS.art_meta,key,{ mode:"fail"});
        return PKICONS.missing_art96;
    }

    variable_struct_set(PKICONS.art_cache,key,quad);
    variable_struct_set(PKICONS.art_meta,key,{ mode:"quad", layout:"grid2x2", w:frameW, h:frameH });
    if (PKICONS.debug_crys) pkicons__log_cry("art96 sliced species="+string(_species)+" frame="+string(frameW)+"x"+string(frameH));
    return quad;
}
function pkicons_get_art96_by_mon(_mon){
    if (!is_struct(_mon)) return PKICONS.missing_art96;
    if (variable_struct_exists(_mon,"species_id") && is_real(_mon.species_id)) return pkicons_get_art96(_mon.species_id);
    if (variable_struct_exists(_mon,"species")) return pkicons_get_art96(_mon.species);
    return PKICONS.missing_art96;
}

// Subimage helpers (0 front normal, 1 back normal, 2 front shiny, 3 back shiny)
function pkicons_get_art96_subimg(_species,_shiny,_back){
    pkicons_init();
    var key="ART|"+string(_species);
    if (!variable_struct_exists(PKICONS.art_meta,key)) return 0;
    var meta = variable_struct_get(PKICONS.art_meta,key);
    if (!is_struct(meta)) return 0;
    if (meta.mode != "quad") return 0;
    if (_shiny){ return _back ? 3 : 2; } else { return _back ? 1 : 0; }
}
function pkicons_get_art96_subimg_by_mon(_mon,_back){
    if (!is_struct(_mon)) return 0;
    var shiny = false; if (variable_struct_exists(_mon,"shiny")) shiny = (_mon.shiny == true);
    var sid = -1;
    if (variable_struct_exists(_mon,"species_id") && is_real(_mon.species_id)) sid = _mon.species_id; else if (variable_struct_exists(_mon,"species")) sid = _mon.species;
    if (sid < 0) return 0;
    return pkicons_get_art96_subimg(sid, shiny, _back);
}

// ---------------- 32×32 Overworld Icons ----------------
// NORMAL variant sheet loader
function pkicons__load_icon32_sheet(_species){
    pkicons_init();
    var key="SHEET|"+string(_species);
    if (variable_struct_exists(PKICONS.icon_sheet_cache,key)){
        var c=variable_struct_get(PKICONS.icon_sheet_cache,key);
        if (sprite_exists(c)) return c;
    }
    var base=PKICONS.icon32_base; if (string_length(base)<=0) return PKICONS.missing_icon32;
    var spr=-1,cands=pkicons__cands(_species);
    for (var i=0;i<array_length(cands);i++){
        var fn=pkicons__join(base,cands[i]);
        if (file_exists(fn)){
            spr=sprite_add(fn,1,false,false,0,0);
            if (sprite_exists(spr)) break;
        }
    }
    if (!sprite_exists(spr)) spr=PKICONS.missing_icon32;
    variable_struct_set(PKICONS.icon_sheet_cache,key,spr);
    return spr;
}

// SHINY variant sheet loader (separate cache key)
function pkicons__load_icon32_sheet_shiny(_species){
    pkicons_init();
    var key="SHEET|S|"+string(_species);
    if (variable_struct_exists(PKICONS.icon_sheet_cache,key)){
        var c=variable_struct_get(PKICONS.icon_sheet_cache,key);
        if (sprite_exists(c)) return c;
    }
    var base=PKICONS.icon32_base_shiny; if (string_length(base)<=0) return PKICONS.missing_icon32;
    var spr=-1,cands=pkicons__cands(_species);
    for (var i=0;i<array_length(cands);i++){
        var fn=pkicons__join(base,cands[i]);
        if (file_exists(fn)){
            spr=sprite_add(fn,1,false,false,0,0);
            if (sprite_exists(spr)) break;
        }
    }
    if (!sprite_exists(spr)) spr=PKICONS.missing_icon32;
    variable_struct_set(PKICONS.icon_sheet_cache,key,spr);
    return spr;
}

// Grid helpers (robust 8‑tile inference)
function pkicons__best_grid8(_w,_h){
    var bestCols=4, bestRows=2, bestTw=_w div 4, bestTh=_h div 2;
    var bestScore=$1e30;
    var found=false;

    var pairs=[ [4,2], [2,4], [8,1], [1,8] ];
    for (var i=0; i<array_length(pairs); i++){
        var c = pairs[i][0];
        var r = pairs[i][1];
        if ((_w mod c)==0 && (_h mod r)==0){
            var tw = _w div c;
            var th = _h div r;
            var ratio = (th>0) ? (tw/th) : 999999;
            var fit_score = abs(ratio - 1); // closer to 1 => more square
            if (fit_score < bestScore){
                bestScore = fit_score;
                bestCols = c; bestRows = r; bestTw = tw; bestTh = th;
                found = true;
            }
        }
    }
    return [bestCols, bestRows, bestTw, bestTh, found];
}
function pkicons__infer_grid(_w,_h){
    if (_w mod 32==0 && _h mod 32==0){
        return [_w div 32, _h div 32, 32, 32];
    }
    var best = pkicons__best_grid8(_w, _h);
    if (best[4]) return [best[0], best[1], best[2], best[3]];
    return [4, 2, _w div 4, _h div 2];
}

// Build 8‑frame strip, centered in 32×32
function pkicons__get_icon32_strip(_species){
    var key="STRIP|"+string(_species);
    if (variable_struct_exists(PKICONS.icon_strip_cache,key)){
        var c=variable_struct_get(PKICONS.icon_strip_cache,key);
        if (sprite_exists(c)) return c;
    }

    var sheet=pkicons__load_icon32_sheet(_species);
    if (!sprite_exists(sheet)) return PKICONS.missing_icon32;

    var fullW=sprite_get_width(sheet);
    var fullH=sprite_get_height(sheet);
    var info=pkicons__infer_grid(fullW,fullH);
    var cols=info[0],rows=info[1],tileW=max(1,info[2]),tileH=max(1,info[3]);

    var total=cols*rows;
    var sc=min(32/tileW,32/tileH);
    var surf=surface_create(32,32);
    if (!surface_exists(surf)) return PKICONS.missing_icon32;

    var strip=-1;
    for (var i=0;i<8;i++){
        var ii=(i<total)?i:(total-1);
        var sx=(ii mod cols)*tileW;
        var sy=(ii div cols)*tileH;

        surface_set_target(surf);
        draw_clear_alpha(c_black,0);

        var offX=(32 - tileW*sc) * 0.5;
        var offY=(32 - tileH*sc) * 0.5;
        draw_sprite_part_ext(sheet,0,sx,sy,tileW,tileH,offX,offY,sc,sc,c_white,1);

        surface_reset_target();

        if (i==0){
            strip=sprite_create_from_surface(surf,0,0,32,32,false,false,0,0);
        } else if (sprite_exists(strip)){
            sprite_add_from_surface(strip,surf,0,0,32,32,false,false);
        }
    }
    surface_free(surf);
    if (!sprite_exists(strip)) strip=PKICONS.missing_icon32;
    variable_struct_set(PKICONS.icon_strip_cache,key,strip);
    return strip;
}

function pkicons__get_icon32_strip_shiny(_species){
    var key="STRIP|S|"+string(_species);
    if (variable_struct_exists(PKICONS.icon_strip_cache,key)){
        var c=variable_struct_get(PKICONS.icon_strip_cache,key);
        if (sprite_exists(c)) return c;
    }
    var sheet=pkicons__load_icon32_sheet_shiny(_species);
    if (!sprite_exists(sheet)) return PKICONS.missing_icon32;
    var fullW=sprite_get_width(sheet);
    var fullH=sprite_get_height(sheet);
    var info=pkicons__infer_grid(fullW,fullH);
    var cols=info[0],rows=info[1],tileW=max(1,info[2]),tileH=max(1,info[3]);
    var total=cols*rows;
    var sc=min(32/tileW,32/tileH);
    var surf=surface_create(32,32); if (!surface_exists(surf)) return PKICONS.missing_icon32;
    var strip=-1;
    for (var i=0;i<8;i++){
        var ii=(i<total)?i:(total-1);
        var sx=(ii mod cols)*tileW;
        var sy=(ii div cols)*tileH;
        surface_set_target(surf); draw_clear_alpha(c_black,0);
        var offX=(32 - tileW*sc) * 0.5; var offY=(32 - tileH*sc) * 0.5;
        draw_sprite_part_ext(sheet,0,sx,sy,tileW,tileH,offX,offY,sc,sc,c_white,1); surface_reset_target();
        if (i==0) strip=sprite_create_from_surface(surf,0,0,32,32,false,false,0,0); else if (sprite_exists(strip)) sprite_add_from_surface(strip,surf,0,0,32,32,false,false);
    }
    surface_free(surf); if (!sprite_exists(strip)) strip=PKICONS.missing_icon32;
    variable_struct_set(PKICONS.icon_strip_cache,key,strip);
    return strip;
}

function pkicons__make_dir_from_strip(_sprStrip,_sub0,_sub1){
    if (!sprite_exists(_sprStrip)) return PKICONS.missing_icon32;
    var surf=surface_create(32,32);
    if (!surface_exists(surf)) return PKICONS.missing_icon32;

    surface_set_target(surf);
    draw_clear_alpha(c_black,0);
    draw_sprite_ext(_sprStrip,_sub0,0,0,1,1,0,c_white,1);
    surface_reset_target();
    var spr_dir=sprite_create_from_surface(surf,0,0,32,32,false,false,0,0);

    surface_set_target(surf);
    draw_clear_alpha(c_black,0);
    draw_sprite_ext(_sprStrip,_sub1,0,0,1,1,0,c_white,1);
    surface_reset_target();
    if (sprite_exists(spr_dir)) sprite_add_from_surface(spr_dir,surf,0,0,32,32,false,false);

    surface_free(surf);
    return spr_dir;
}

// 32×32 directional icon resolver (restored)
function pkicons_get_icon32_dir(_species,_dir){
    pkicons_init();
    var d=string_upper(string(_dir));
    if (d!="UP" && d!="DOWN" && d!="LEFT" && d!="RIGHT") d="DOWN";
    var key="DIR|"+string(_species)+"|"+d;
    if (variable_struct_exists(PKICONS.icon_dir_cache,key)){
        var c=variable_struct_get(PKICONS.icon_dir_cache,key);
        if (sprite_exists(c)) return c;
    }
    var strip=pkicons__get_icon32_strip(_species);
    if (!sprite_exists(strip)) return PKICONS.missing_icon32;

    var sub0=4,sub1=5;
    if (d=="UP"){sub0=0;sub1=1;}
    if (d=="LEFT"){sub0=2;sub1=3;}
    if (d=="DOWN"){sub0=4;sub1=5;}
    if (d=="RIGHT"){sub0=6;sub1=7;}

    var spr_dir=pkicons__make_dir_from_strip(strip,sub0,sub1);
    variable_struct_set(PKICONS.icon_dir_cache,key,spr_dir);
    return spr_dir;
}

function pkicons_get_icon32_dir_by_mon(_mon,_dir){
    if (!is_struct(_mon)) return PKICONS.missing_icon32;
    var shiny = false; if (variable_struct_exists(_mon,"shiny")) shiny = (_mon.shiny == true);
    var sid = -1;
    if (variable_struct_exists(_mon,"species_id") && is_real(_mon.species_id)) sid = _mon.species_id; else if (variable_struct_exists(_mon,"species")) sid = _mon.species;
    if (sid == -1) return PKICONS.missing_icon32;
    if (shiny){
        // Attempt shiny directional icon (log at most once per species to avoid spam)
        if (!variable_struct_exists(PKICONS,"shiny_log_map")) variable_struct_set(PKICONS,"shiny_log_map", {});
        var __shm = variable_struct_get(PKICONS,"shiny_log_map");
        var __k = string(sid);
        if (!variable_struct_exists(__shm,__k)){
            pkicons__log("attempting shiny icon dir for species="+string(sid));
            variable_struct_set(__shm,__k,"attempted");
        }
        var d=string_upper(string(_dir)); if (d!="UP" && d!="DOWN" && d!="LEFT" && d!="RIGHT") d="DOWN";
        var key="DIR|S|"+string(sid)+"|"+d;
        if (variable_struct_exists(PKICONS.icon_dir_cache,key)){
            var c=variable_struct_get(PKICONS.icon_dir_cache,key); if (sprite_exists(c)) return c;
        }
        var strip=pkicons__get_icon32_strip_shiny(sid);
        if (sprite_exists(strip)){
            var sub0=4,sub1=5; if (d=="UP"){sub0=0;sub1=1;} if (d=="LEFT"){sub0=2;sub1=3;} if (d=="DOWN"){sub0=4;sub1=5;} if (d=="RIGHT"){sub0=6;sub1=7;}
            var spr_dir=pkicons__make_dir_from_strip(strip,sub0,sub1);
            variable_struct_set(PKICONS.icon_dir_cache,key,spr_dir);
            if (sprite_exists(spr_dir)) return spr_dir;
        }
            // fallback to normal icons if shiny sheet missing (log missing once)
            if (!variable_struct_exists(__shm,__k) || variable_struct_get(__shm,__k) != "missing"){
                pkicons__log("shiny icon missing; falling back to normal for species="+string(sid));
                variable_struct_set(__shm,__k,"missing");
            }
    }
    return pkicons_get_icon32_dir(sid,_dir);
}

// Simple 2‑frame animator for UI icons (as expected by party system)
function pkicons_icon32_frame_ui(){
    return (current_time div 166) mod 2;
}

// Init (bases left to your Create event or dev setup)
// pkicons_init();
// pkicons_set_art96_base("C:/.../sprites/pokemon/");
// pkicons_set_icon32_base("C:/.../sprites/Overworld/Normal/");
// (Shiny path auto: replaces /Normal/ with /Shiny/, or set explicitly with pkicons_set_icon32_shiny_base(path))
// To display shiny icons: ensure each mon struct has .shiny = true, party system already calls pkicons_get_icon32_dir_by_mon which now auto-selects shiny variant if available.
