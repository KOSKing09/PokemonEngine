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
global.DEBUG = true;

// Data loaders debug gate (opt-in)
globalvar DATA_DEBUG;
global.DATA_DEBUG = true;

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
if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
    show_debug_message("=== DATA LOAD PROFILE COMPLETE ===");
    show_debug_message("Total ms: " + string(_metrics.sys_total_ms));
}

// --- BUILD SIMPLE INDEX (name <-> id) --------------------------------------
scr_poke_index_build_simple_structs();  // builds global._name_by_id/_name_list/_id_list
pkicons_init();
// Ensure pkicons exists and enable debug so item base scan logs will run
if (variable_global_exists("PKICONS")){
    if (variable_struct_exists(global.PKICONS, "debug")) global.PKICONS.debug = true;
    else variable_struct_set(global.PKICONS, "debug", true);
} else {
    global.PKICONS = { debug: true };
}
pkicons_set_art96_base("C:/Users/King2/Documents/Pokemon Engine/sprites/pokemon/");
pkicons_set_icon32_base("C:/Users/King2/Documents/Pokemon Engine/sprites/Overworld/Normal/");
pkicons_set_cries_base("C:/Users/King2/Documents/Pokemon Engine/cries/");
pkicons_set_item_icon_base("C:/Users/King2/Documents/Pokemon Engine/sprites/items/")
// Centralized debug flag initializations (preserve existing PKICONS.debug if already set)
// Ensure PKICONS exists before setting its debug flag
if (variable_global_exists("PKICONS")){
    if (!variable_struct_exists(global.PKICONS, "debug")) variable_struct_set(global.PKICONS, "debug", false);
    if (!variable_struct_exists(global.PKICONS, "debug_crys")) variable_struct_set(global.PKICONS, "debug_crys", false);
} else {
    global.PKICONS = { debug: false, debug_item : false };
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



// Bags after party is fine
bags_init(1);
bag_inventory_add_item(0, 4, 10);
bag_inventory_add_item(0, 1, 10);
bag_inventory_add_item(0, 17, 5);
bag_inventory_add_item(0, 18, 5);
bag_inventory_add_item(0, 182, 10);
bags_seed_from_items(0); // refresh once, not every step
// (item loader diagnostic removed)
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
