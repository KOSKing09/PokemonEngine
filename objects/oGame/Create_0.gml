// --- POKÉ FONT / GUI --------------------------------------------------------
var ORDER =
    "0123456789" +
    "!?“”‘’♂♀$*/.-:,_" +
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
    "abcdefghijklmnopqrstuvwxyz" +
    ">" +
    "" +
    "…" +
    "“”‘’" +
    "♪▶";

randomize();
global.FNT_POKEMON = font_add_sprite_ext(spr_font_pokemon_new, ORDER, false, 0);
global.FNT_POKEMON_SMALL = font_add_sprite_ext(spr_font_pokemon_new, ORDER, false, -1);
var spr = spr_font_pokemon_new;
global.FONT_CHAR_W = sprite_get_width(spr);
global.FONT_CHAR_H = sprite_get_height(spr);

// If your GUI isn’t already 240x160, this locks the bag/party layout scale.
display_set_gui_size(240, 160);

// Central debug master switch. False by default in production builds.
globalvar DEBUG;
global.DEBUG = false;

// --- DATA: ensure globals exist BEFORE loading ------------------------------
// Make sure a DS map object exists and pokemon/_pokemon point to the SAME id.
if (!(variable_global_exists("_pokemon") && is_real(global._pokemon))) {
    if (variable_global_exists("pokemon") && is_real(global.pokemon) && ds_exists(global.pokemon, ds_type_map)) {
        global._pokemon = global.pokemon;           // alias existing
    } else {
        global._pokemon = ds_map_create();          // create empty
        global.pokemon  = global._pokemon;          // alias legacy name
    }
}

// --- LOAD ALL CSVs ----------------------------------------------------------
// --- DATA (structs) ---
//data_load_all_structs();                // fills global._pokemon + global._poke_stats
// PROFILE RUN
var _metrics = data_load_profile_run();

// after profiling, continue normal boot
// (your loader orchestrator will run again inside the profiler)
if (variable_global_exists("DEBUG") && global.DEBUG) {
    show_debug_message("=== DATA LOAD PROFILE COMPLETE ===");
    show_debug_message("Total ms: " + string(_metrics.sys_total_ms));
}

// --- BUILD SIMPLE INDEX (name <-> id) --------------------------------------
scr_poke_index_build_simple_structs();  // builds global._name_by_id/_name_list/_id_list
pkicons_init();
pkicons_set_art96_base("C:/Users/King2/Documents/Pokemon Engine/sprites/pokemon/");
pkicons_set_icon32_base("C:/Users/King2/Documents/Pokemon Engine/sprites/Overworld/Normal/");
pkicons_set_cries_base("C:/Users/King2/Documents/Pokemon Engine/cries/");
pkicons_set_item_icon_base("C:/Users/King2/Documents/Pokemon Engine/sprites/items/")
// Centralized debug flag initializations (default OFF for production)
// Ensure PKICONS exists before setting its debug flag
if (variable_global_exists("PKICONS")){
    if (variable_struct_exists(global.PKICONS, "debug")) global.PKICONS.debug = false;
    else variable_struct_set(global.PKICONS, "debug", false);
} else {
    global.PKICONS = { debug: false };
}

// World collision debug (module-level struct WC)
if (variable_global_exists("WC")){
    if (variable_struct_exists(global.WC, "debug")) global.WC.debug = false;
    else variable_struct_set(global.WC, "debug", false);
} else {
    global.WC = { tilemaps: [], tile_size: 16, solids: [], debug: false };
}

// Master switches
global.DEBUG_BATTLE_SPRITES = false;


global.PARTY_ASSETS = {
    selector: "spr_selector",
    placeholder: "spr_mon_icon_placeholder",
    ball: "spr_bag_pokeball_small"
};

// --- PARTY / BAGS / PLAYERS -------------------------------------------------
party_init();               // must be before demo seed (party_ensure uses it)
scr_poke_runtime_demo_init_random(6);           // seeds PARTY[0] (and [1] if present)

// (Optional) sanity prints
// --- DEBUG: verify data / index / demo (structs version) --------------------
if (variable_global_exists("DEBUG") && global.DEBUG) {
    /*
    // 1) DATA: _pokemon array exists + basic counts
    var has_poke  = variable_global_exists("_pokemon") && is_array(global._pokemon);
    var poke_len  = has_poke ? array_length(global._pokemon) : -1;

    var poke_count = 0;
    if (has_poke){
        for (var i = 0; i < poke_len; i++){
            if (is_struct(global._pokemon[i])) poke_count++;
        }
    }
    show_debug_message("[CHECK] _pokemon exists=" + string(has_poke)
        + "  len=" + string(poke_len) + "  structs=" + string(poke_count));

    // 2) INDEX: arrays exist + sizes
    var has_name_by_id = variable_global_exists("_name_by_id") && is_array(global._name_by_id);
    var has_name_list  = variable_global_exists("_name_list")  && is_array(global._name_list);
    var has_id_list    = variable_global_exists("_id_list")    && is_array(global._id_list);

    var nbi_len = has_name_by_id ? array_length(global._name_by_id) : -1;
    var nl_len  = has_name_list  ? array_length(global._name_list)  : -1;
    var il_len  = has_id_list    ? array_length(global._id_list)    : -1;

    show_debug_message("[CHECK] index: _name_by_id.len=" + string(nbi_len)
        + "  _name_list.len=" + string(nl_len)
        + "  _id_list.len=" + string(il_len));

    // 3) SAMPLE LOOKUP: bulbasaur
    var test_id = scr_poke_index_by_name("bulbasaur");
    var test_nm = (test_id >= 0) ? scr_poke_name_by_id(test_id) : "";
    show_debug_message("[CHECK] lookup 'bulbasaur' -> id=" + string(test_id)
        + "  name_by_id(id)=" + test_nm);

    // 4) STATS access sanity
    if (test_id >= 0){
        var st = scr_poke_stats(test_id);
        show_debug_message("[CHECK] stats id=" + string(test_id)
            + " hp=" + string(st.hp) + " atk=" + string(st.atk)
            + " def=" + string(st.def) + " spa=" + string(st.spa)
            + " spd=" + string(st.spd) + " spe=" + string(st.spe));
    }

    // 5) DEMO PARTY seeded?
    var party_ok = variable_global_exists("PARTY") && is_array(global.PARTY) && array_length(global.PARTY) > 0;
    show_debug_message("[CHECK] PARTY exists=" + string(party_ok));

    if (party_ok){
        var P0 = global.PARTY[0];
        var has_mons = is_struct(P0) && variable_struct_exists(P0, "mons") && is_array(P0.mons);
        var n0 = has_mons ? array_length(P0.mons) : -1;
        show_debug_message("[CHECK] PARTY[0] mons=" + string(n0));

        if (has_mons && n0 > 0){
			var m0   = (is_array(global.PARTY[0].mons) && array_length(global.PARTY[0].mons) > 0) ? global.PARTY[0].mons[0] : undefined;
			var nm0  = is_undefined(m0) ? "?" : scr_poke_name_by_id(m0.species_id);
			var lvl0 = is_undefined(m0) ? -1  : (!is_undefined(m0.level) ? m0.level : (!is_undefined(m0.lvl) ? m0.lvl : -1));
			show_debug_message("[CHECK] first mon: id=" + string(is_undefined(m0) ? -1 : m0.species_id) + " name=" + nm0 + " lvl=" + string(lvl0));
        }
    }
    */
}

if (variable_global_exists("DEBUG") && global.DEBUG) {
    var _pid = 0; var _idx = 0; var _P = party_ensure(_pid); var _M = (_idx < array_length(_P.mons)) ? _P.mons[_idx] : undefined;
    show_debug_message("party: slot="+string(_idx)+" mon_struct_exists="+string(is_struct(_M)));
    var _sid = -1;
    if (is_struct(_M)){
        if (variable_struct_exists(_M,"species_id") && is_real(_M.species_id)) _sid = _M.species_id;
        else if (variable_struct_exists(_M,"species")) _sid = _M.species;
    }
    show_debug_message("party: slot="+string(_idx)+" species_field="+string(_sid));
    show_debug_message("party: pkicons_has_icon32(" + string(_sid) + ") = " + string(pkicons_has_icon32(_sid,false)));
    var _r_mon = -1; try { _r_mon = pkicons_get_icon32_for_mon(_M, "down"); } catch(e) { _r_mon = -1; }
    var _r_spc = -1; try { _r_spc = pkicons_get_icon32_for_species(_sid, "down"); } catch(e) { _r_spc = -1; }
    var _strip = -1; try { _strip = pkicons__get_icon32_strip(_sid); } catch(e) { _strip = -1; }
    show_debug_message("party: pkicons_get_icon32_for_mon -> id=" + string(_r_mon) + " exists=" + string(sprite_exists(_r_mon)) + " frames=" + (sprite_exists(_r_mon)?string(sprite_get_number(_r_mon)):"?"));
    show_debug_message("party: pkicons_get_icon32_for_species -> id=" + string(_r_spc) + " exists=" + string(sprite_exists(_r_spc)) + " frames=" + (sprite_exists(_r_spc)?string(sprite_get_number(_r_spc)):"?"));
    show_debug_message("party: pkicons__get_icon32_strip -> id=" + string(_strip) + " exists=" + string(sprite_exists(_strip)) + " frames=" + (sprite_exists(_strip)?string(sprite_get_number(_strip)):"?"));
}



// Bags after party is fine
bags_init(1);
bag_inventory_add_item(0, 4, 10);
bag_inventory_add_item(0, 1, 10);
bag_inventory_add_item(0, 17, 5);
bag_inventory_add_item(0, 18, 5);
bag_inventory_add_item(0, 182, 10);
bags_seed_from_items(0); // refresh once, not every step

// Quick bag/item loader diagnostic
var ids = [1,4,17,18];
if (variable_global_exists("DEBUG") && global.DEBUG) {
    show_debug_message("==== ITEMS LOADER CHECK ====");

    // _items existence / length
    var items_ok = (variable_global_exists("_items") && is_array(global._items));
    show_debug_message("global._items exists=" + string(items_ok));
    if (items_ok) show_debug_message("global._items length=" + string(array_length(global._items)));

    // _item_text existence / length
    var itext_ok = (variable_global_exists("_item_text") && is_array(global._item_text));
    show_debug_message("global._item_text exists=" + string(itext_ok));
    if (itext_ok) show_debug_message("global._item_text length=" + string(array_length(global._item_text)));

    for (var ii = 0; ii < array_length(ids); ii++) {
        var _id = ids[ii];
        var has_item_struct = (items_ok && _id < array_length(global._items) && is_struct(global._items[_id]));
        show_debug_message("global._items[" + string(_id) + "] struct=" + string(has_item_struct));
        if (has_item_struct) {
            var nm = (variable_struct_exists(global._items[_id], "name")) ? string(global._items[_id].name) : "<no name field>";
            show_debug_message("  name: " + nm);
        }
        var has_text = (itext_ok && _id < array_length(global._item_text) && is_struct(global._item_text[_id]));
        show_debug_message("global._item_text[" + string(_id) + "] exists=" + string(has_text));
        if (has_text) show_debug_message("  flavor_text: " + string(global._item_text[_id].flavor_text));
    }

    // Do we have the loader scripts available?
    var asset_idx_items = asset_get_index("data_load_items_structs");
    show_debug_message("asset_get_index(\"data_load_items_structs\") = " + string(asset_idx_items));
    show_debug_message("function data_load_items_structs defined? " + string(!is_undefined(data_load_items_structs)));
    show_debug_message("function data_load_profile_run defined? " + string(!is_undefined(data_load_profile_run)));

    show_debug_message("==== END ITEMS LOADER CHECK ====");
}
// ... keep inv around for gameplay; destroy when appropriate

// --- PLAYER SPAWN -----------------------------------------------------------
global.p1 = instance_create_layer(ospawn.x, ospawn.y, "Instances", oPlayer);
global.p1.pid = 0;
global.p1._speed = 2;

// If you use this elsewhere, keep it up to date
var players_active = max(1, (variable_global_exists("PAUSE_PLAYERS_ACTIVE") ? global.PAUSE_PLAYERS_ACTIVE : 1));

// --- SYSTEMS (controls, pause, dialog) -------------------------------------
scr_controls();          // creates global CTRL, loads options.ini
pause_init();            // pause system
dialog2p_init();         // dialog system (if you’re using it)

// Controls tweak (optional)
CTRL.deadzone  = 0.25;
CTRL.pad_index = [0,1];

// --- WORLD COLLISION SETUP --------------------------------------------------
wc_reset();
wc_bind_layers(["WALL"]);
wc_set_solids([noone]);  // add object ids here if you have solid instances
