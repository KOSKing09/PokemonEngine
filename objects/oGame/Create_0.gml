// --- GUI / FONT -----------------------------------------------------------
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

// --- DEBUG FLAGS ---------------------------------------------------------
// Central debug master switch. False by default in production builds.
globalvar DEBUG;
global.DEBUG = true;

// Data loaders debug gate (opt-in). Default OFF for normal play; set true for troubleshooting.
globalvar DATA_DEBUG;
global.DATA_DEBUG = true;

global.CUTSCENE_DEBUG = true;
global.DATA_DEBUG_TRAINER = false;

// Very verbose data debug (opt-in). Default OFF.
globalvar DATA_DEBUG_VERBOSE;
global.DATA_DEBUG_VERBOSE = false;

// MOVES_DEBUG is noisy; default to false. Set to true when actively debugging moves.
global.MOVES_DEBUG = true;
// Developer-only move-report runner (disabled by default). Enable to run
// `dev_moves_impl_report()` at boot for a one-time diagnostics print.
global.DEV_REPORT_MOVES = true;

// run once (debug boot or in a quick test script)
if (variable_global_exists("_battle_impls") && is_struct(global._battle_impls)){
    show_debug_message("[reg] __battle_perform_action_impl present? " + string(variable_struct_exists(global._battle_impls, "__battle_perform_action_impl")));
} else show_debug_message("[reg] _battle_impls missing");



// --- DATA: ensure globals exist BEFORE loading ----------------------------
// Ensure `global._pokemon` exists (alias older `global.pokemon` if present).
if (!(variable_global_exists("_pokemon") && is_real(global._pokemon))) {
    if (variable_global_exists("pokemon") && is_real(global.pokemon) && ds_exists(global.pokemon, ds_type_map)) {
        global._pokemon = global.pokemon; // alias existing
    } else {
        global._pokemon = ds_map_create();  // create empty
        global.pokemon  = global._pokemon;  // alias legacy name
    }
}

// --- CSV LOAD / PROFILE --------------------------------------------------
//data_load_all_structs(); // fills global._pokemon + global._poke_stats
var _metrics = data_load_profile_run();
if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
    show_debug_message("=== DATA LOAD PROFILE COMPLETE ===");
    show_debug_message("Total ms: " + string(_metrics.sys_total_ms));
}

// Normalize numeric IDs to textual keys for downstream code that expects prose keys
if (!is_undefined(data_normalize_item_flag_map)) data_normalize_item_flag_map();

// --- POKÉMON INDEX & ASSET BASES -----------------------------------------
scr_poke_index_build_simple_structs(); // builds global._name_by_id / _name_list / _id_list
pkicons_init();

// Ensure PKICONS debug flags exist (preserve pre-existing settings when possible)
    if (variable_global_exists("PKICONS")){
        if (variable_struct_exists(global.PKICONS, "debug")) global.PKICONS.debug = false;
        else variable_struct_set(global.PKICONS, "debug", false);
    } else {
        global.PKICONS = { debug: false, data_debug: false };
    }

// Configure external asset bases (adjust paths as needed on your machine)
pkicons_set_art96_base("C:/Users/King2/Documents/Pokemon Engine/sprites/pokemon/");
pkicons_set_icon32_base("C:/Users/King2/Documents/Pokemon Engine/sprites/Overworld/Normal/");
pkicons_set_cries_base("C:/Users/King2/Documents/Pokemon Engine/cries/");
pkicons_set_item_icon_base("C:/Users/King2/Documents/Pokemon Engine/sprites/items/");

// Ensure per-module debug keys exist (quiet by default)
if (variable_global_exists("PKICONS")){
    if (!variable_struct_exists(global.PKICONS, "debug")) variable_struct_set(global.PKICONS, "debug", false);
    if (!variable_struct_exists(global.PKICONS, "debug_crys")) variable_struct_set(global.PKICONS, "debug_crys", false);
} else {
    global.PKICONS = { debug: false, debug_item: false };
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

// Asset shortcuts used by party UI
global.PARTY_ASSETS = {
    selector: "spr_selector",
    placeholder: "spr_mon_icon_placeholder",
    ball: "spr_bag_pokeball_small"
};

// Region music default (used by battle system to restore pre-battle music)
global._REGIONMUSIC = snd_Littleroot_Town;

// --- PARTY / BAGS / PLAYERS -----------------------------------------------
party_init(); // must be before demo seed (party_ensure uses it)
// global.DEMO_FORCE_SPECIES = [250, 249]; // optional override
global.DEMO_FORCE_SPECIES = [188, 268, 471, 559, 17];
scr_poke_runtime_demo_init_random(6); // seeds PARTY[0] (and [1] if present)
dev_assign_moves_to_first(0, [240, 91, 340, 507]);

global.DEV_FORCE_FLINCH_CHANCE = -1;

// Initialize bags (seed with some items for demo/dev)
bags_init(1);
bag_inventory_add_item(0, 4, 10);
bag_inventory_add_item(0, 1, 10);
bag_inventory_add_item(0, 17, 25);
bag_inventory_add_item(0, 26, 25);
bag_inventory_add_item(0, 25, 25);
bag_inventory_add_item(0, 24, 25);
bag_inventory_add_item(0, 23, 25);
bag_inventory_add_item(0, 18, 25);
bag_inventory_add_item(0, 182, 10);
bags_seed_from_items(0); // refresh once

// NOTE: startup debug simulation for move-learn/leveling removed.
// To re-enable for debugging, reintroduce the DEBUG_SIMULATE_LEARN_ON_START guard and block here.

// --- PLAYER SPAWN ---------------------------------------------------------
global.p1 = instance_create_layer(ospawn.x, ospawn.y, "Instances", oPlayer);
// Assign instance fields in a guarded way to satisfy static analyzers/runtime differences
try { variable_instance_set(global.p1, "pid", 0); } catch (e_var) { /* ignore */ }
try { variable_instance_set(global.p1, "_speed", 2); } catch (e_var2) { /* ignore */ }

// Active player count (used by pause system)
var players_active = max(1, (variable_global_exists("PAUSE_PLAYERS_ACTIVE") ? global.PAUSE_PLAYERS_ACTIVE : 1));

// --- SYSTEMS (controls, pause, dialog) -----------------------------------
scr_controls();   // creates global CTRL, loads options.ini
pause_init();     // pause system
dialog2p_init();  // dialog system (if you’re using it)

// Controls tweak (optional)
CTRL.deadzone = 0.25;
CTRL.pad_index = [0,1];

// --- WORLD COLLISION SETUP ------------------------------------------------
wc_reset();
wc_bind_layers(["WALL", "BLOCKS"]);
wc_set_solids([noone]); // add object ids here if you have solid instances

show_debug_message(global._move_meta[79]);