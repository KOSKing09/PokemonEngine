
// Drain any queued dialog first (opens next item if allowed), then advance if open
if (!is_undefined(dialog2p_step)) dialog2p_step(pid);
if (!is_undefined(multiplayer_update_versus_request)) multiplayer_update_versus_request(pid);
if (!is_undefined(cutscene_blocks_player) && cutscene_blocks_player(pid)) exit;

if (keyboard_check_pressed(vk_f1)){
    if (!battle_is_open(pid)){
    /* 
        var trainer_party = [];
        if (!is_undefined(pokemon_factory_create)){
            trainer_party = [
                pokemon_factory_create(133, 5, {}),
                pokemon_factory_create(10, 5, {}),
                pokemon_factory_create(252, 5, {})
            ];
        }
        var trainer_payload = {
            trainer_name: "Bug Catcher Rick",
            sprite: spr_PokemonEmeraldTrainers,
            sprite_index: 12,
            party: trainer_party,
            area_type: "forest"
            
        };
        battle_open_trainer(0, trainer_payload);
       */
        var _debug_party = party_ensure(pid);
        if (is_struct(_debug_party) && variable_struct_exists(_debug_party, "mons") && is_array(_debug_party.mons)){
            var _revived = 0;
            for (var _pi = 0; _pi < array_length(_debug_party.mons) && _revived < 2; ++_pi){
                var _mon = _debug_party.mons[_pi];
                if (!is_struct(_mon)) continue;
                var _max_hp = 1;
                if (variable_struct_exists(_mon, "hp_max") && is_real(variable_struct_get(_mon, "hp_max"))) _max_hp = max(1, floor(variable_struct_get(_mon, "hp_max")));
                else if (variable_struct_exists(_mon, "maxhp") && is_real(variable_struct_get(_mon, "maxhp"))) _max_hp = max(1, floor(variable_struct_get(_mon, "maxhp")));
                else if (variable_struct_exists(_mon, "hp") && is_real(variable_struct_get(_mon, "hp"))) _max_hp = max(1, floor(variable_struct_get(_mon, "hp")));
                variable_struct_set(_mon, "hp", _max_hp);
                variable_struct_set(_mon, "hp_now", _max_hp);
                if (!variable_struct_exists(_mon, "hp_max") || !is_real(variable_struct_get(_mon, "hp_max"))) variable_struct_set(_mon, "hp_max", _max_hp);
                if (!variable_struct_exists(_mon, "maxhp") || !is_real(variable_struct_get(_mon, "maxhp"))) variable_struct_set(_mon, "maxhp", _max_hp);
                _revived += 1;
            }
        }
        battle_open(
            pid,
            irandom_range(10,10),
            choose("dark water", "rocks a", "light", "grassy", "rocks b", "dirt", "river", "snowy", "grassy snow", "ice", "forest", "ugly grass", "wood bridge", "man made paths"),
            {
                battle_type: "wild",
                battle_format: "singles"
            }
        );
	}else{
		battle_close(pid);
	}
}

if (variable_global_exists("DEV_AUTO_STATUS_SMOKE") && global.DEV_AUTO_STATUS_SMOKE) {
    global.DEV_AUTO_STATUS_SMOKE = false;
    test_battle_status_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_HEAL_BLOCK_SMOKE") && global.DEV_AUTO_HEAL_BLOCK_SMOKE) {
    global.DEV_AUTO_HEAL_BLOCK_SMOKE = false;
    test_battle_heal_block_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_EMBARGO_SMOKE") && global.DEV_AUTO_EMBARGO_SMOKE) {
    global.DEV_AUTO_EMBARGO_SMOKE = false;
    test_battle_embargo_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_PERISH_SONG_SMOKE") && global.DEV_AUTO_PERISH_SONG_SMOKE) {
    global.DEV_AUTO_PERISH_SONG_SMOKE = false;
    test_battle_perish_song_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_ENDURE_SMOKE") && global.DEV_AUTO_ENDURE_SMOKE) {
    global.DEV_AUTO_ENDURE_SMOKE = false;
    test_battle_endure_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_ROLLOUT_SMOKE") && global.DEV_AUTO_ROLLOUT_SMOKE) {
    global.DEV_AUTO_ROLLOUT_SMOKE = false;
    test_battle_rollout_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_FURY_CUTTER_SMOKE") && global.DEV_AUTO_FURY_CUTTER_SMOKE) {
    global.DEV_AUTO_FURY_CUTTER_SMOKE = false;
    test_battle_fury_cutter_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_LOVE_GIFT_SMOKE") && global.DEV_AUTO_LOVE_GIFT_SMOKE) {
    global.DEV_AUTO_LOVE_GIFT_SMOKE = false;
    test_battle_love_gift_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_FIELD_SWITCH_SMOKE") && global.DEV_AUTO_FIELD_SWITCH_SMOKE) {
    global.DEV_AUTO_FIELD_SWITCH_SMOKE = false;
    test_battle_field_switch_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_FORCED_PLAYER_SWITCH_SMOKE") && global.DEV_AUTO_FORCED_PLAYER_SWITCH_SMOKE) {
    global.DEV_AUTO_FORCED_PLAYER_SWITCH_SMOKE = false;
    test_battle_doubles_forced_player_switch_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_DOUBLES_ENEMY_FAINT_SEND_SMOKE") && global.DEV_AUTO_DOUBLES_ENEMY_FAINT_SEND_SMOKE) {
    global.DEV_AUTO_DOUBLES_ENEMY_FAINT_SEND_SMOKE = false;
    test_battle_doubles_enemy_faint_auto_send_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_COOP_DOUBLE_WILD_SMOKE") && global.DEV_AUTO_COOP_DOUBLE_WILD_SMOKE) {
    global.DEV_AUTO_COOP_DOUBLE_WILD_SMOKE = false;
    test_battle_coop_double_wild_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_COOP_DOUBLE_TRAINER_SMOKE") && global.DEV_AUTO_COOP_DOUBLE_TRAINER_SMOKE) {
    global.DEV_AUTO_COOP_DOUBLE_TRAINER_SMOKE = false;
    test_battle_coop_double_trainer_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_BURN_POISON_RESIDUAL_SMOKE") && global.DEV_AUTO_BURN_POISON_RESIDUAL_SMOKE) {
    global.DEV_AUTO_BURN_POISON_RESIDUAL_SMOKE = false;
    test_battle_burn_poison_residual_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_VISUAL_TARGET_SMOKE") && global.DEV_AUTO_VISUAL_TARGET_SMOKE) {
    global.DEV_AUTO_VISUAL_TARGET_SMOKE = false;
    test_battle_visual_target_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_CONFUSION_VISUAL_SMOKE") && global.DEV_AUTO_CONFUSION_VISUAL_SMOKE) {
    global.DEV_AUTO_CONFUSION_VISUAL_SMOKE = false;
    test_battle_confusion_visual_smoke_start(true);
}

if (variable_global_exists("DEV_AUTO_EFFECT_131_155_SMOKE") && global.DEV_AUTO_EFFECT_131_155_SMOKE) {
    global.DEV_AUTO_EFFECT_131_155_SMOKE = false;
    test_battle_effect_131_155_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_159_176_SMOKE") && global.DEV_AUTO_EFFECT_159_176_SMOKE) {
    global.DEV_AUTO_EFFECT_159_176_SMOKE = false;
    test_battle_effect_159_176_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_27_42_SMOKE") && global.DEV_AUTO_EFFECT_27_42_SMOKE) {
    global.DEV_AUTO_EFFECT_27_42_SMOKE = false;
    test_battle_effect_27_42_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_76_94_SMOKE") && global.DEV_AUTO_EFFECT_76_94_SMOKE) {
    global.DEV_AUTO_EFFECT_76_94_SMOKE = false;
    test_battle_effect_76_94_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_9_112_SMOKE") && global.DEV_AUTO_EFFECT_9_112_SMOKE) {
    global.DEV_AUTO_EFFECT_9_112_SMOKE = false;
    test_battle_effect_9_112_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_ITEM_ABILITY_SMOKE") && global.DEV_AUTO_EFFECT_ITEM_ABILITY_SMOKE) {
    global.DEV_AUTO_EFFECT_ITEM_ABILITY_SMOKE = false;
    test_battle_effect_item_ability_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_200_204_SMOKE") && global.DEV_AUTO_EFFECT_200_204_SMOKE) {
    global.DEV_AUTO_EFFECT_200_204_SMOKE = false;
    test_battle_effect_200_204_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_173_177_224_SMOKE") && global.DEV_AUTO_EFFECT_173_177_224_SMOKE) {
    global.DEV_AUTO_EFFECT_173_177_224_SMOKE = false;
    test_battle_effect_173_177_224_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_174_198_SMOKE") && global.DEV_AUTO_EFFECT_174_198_SMOKE) {
    global.DEV_AUTO_EFFECT_174_198_SMOKE = false;
    test_battle_effect_174_198_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_215_SMOKE") && global.DEV_AUTO_EFFECT_215_SMOKE) {
    global.DEV_AUTO_EFFECT_215_SMOKE = false;
    test_battle_effect_215_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_216_SMOKE") && global.DEV_AUTO_EFFECT_216_SMOKE) {
    global.DEV_AUTO_EFFECT_216_SMOKE = false;
    test_battle_effect_216_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_225_SMOKE") && global.DEV_AUTO_EFFECT_225_SMOKE) {
    global.DEV_AUTO_EFFECT_225_SMOKE = false;
    test_battle_effect_225_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_221_SMOKE") && global.DEV_AUTO_EFFECT_221_SMOKE) {
    global.DEV_AUTO_EFFECT_221_SMOKE = false;
    test_battle_effect_221_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_217_SMOKE") && global.DEV_AUTO_EFFECT_217_SMOKE) {
    global.DEV_AUTO_EFFECT_217_SMOKE = false;
    test_battle_effect_217_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_ACCURACY_SMOKE") && global.DEV_AUTO_ACCURACY_SMOKE) {
    global.DEV_AUTO_ACCURACY_SMOKE = false;
    test_battle_accuracy_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_195_SMOKE") && global.DEV_AUTO_EFFECT_195_SMOKE) {
    global.DEV_AUTO_EFFECT_195_SMOKE = false;
    test_battle_effect_195_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_210_SMOKE") && global.DEV_AUTO_EFFECT_210_SMOKE) {
    global.DEV_AUTO_EFFECT_210_SMOKE = false;
    test_battle_effect_210_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EFFECT_211_229_SMOKE") && global.DEV_AUTO_EFFECT_211_229_SMOKE) {
    global.DEV_AUTO_EFFECT_211_229_SMOKE = false;
    test_battle_effect_211_229_smoke_start(true);
}
if (variable_global_exists("DEV_AUTO_EVOLUTION_SMOKE") && global.DEV_AUTO_EVOLUTION_SMOKE) {
    global.DEV_AUTO_EVOLUTION_SMOKE = false;
    test_battle_evolution_smoke_start(true);
}

test_battle_status_smoke_update(0);
test_battle_heal_block_smoke_update(0);
test_battle_embargo_smoke_update(0);
test_battle_perish_song_smoke_update(0);
test_battle_endure_smoke_update(0);
test_battle_rollout_smoke_update(0);
test_battle_fury_cutter_smoke_update(0);
test_battle_love_gift_smoke_update(0);
test_battle_field_switch_smoke_update(0);
test_battle_doubles_forced_player_switch_smoke_update(0);
test_battle_doubles_enemy_faint_auto_send_smoke_update(0);
test_battle_coop_double_wild_smoke_update(0);
test_battle_coop_double_trainer_smoke_update(0);
test_battle_burn_poison_residual_smoke_update(0);
test_battle_visual_target_smoke_update(0);
test_battle_confusion_visual_smoke_update(0);
test_battle_effect_131_155_smoke_update(0);
test_battle_effect_159_176_smoke_update(0);
test_battle_effect_27_42_smoke_update(0);
test_battle_effect_76_94_smoke_update(0);
test_battle_effect_9_112_smoke_update(0);
test_battle_effect_item_ability_smoke_update(0);
test_battle_effect_200_204_smoke_update(0);
test_battle_effect_173_177_224_smoke_update(0);
test_battle_effect_174_198_smoke_update(0);
test_battle_effect_215_smoke_update(0);
test_battle_effect_216_smoke_update(0);
test_battle_effect_225_smoke_update(0);
test_battle_effect_221_smoke_update(0);
test_battle_effect_217_smoke_update(0);
test_battle_accuracy_smoke_update(0);
test_battle_effect_210_smoke_update(0);
test_battle_effect_211_229_smoke_update(0);
test_battle_evolution_smoke_update(0);

// detect closing edge: if it was open last frame and now not
if (!variable_instance_exists(id,"_dlg_was")) _dlg_was = false;
var _now = dialog2p_is_open(pid);
if (_dlg_was && !_now) talk_cd = max(talk_cd, ceil(game_get_speed(gamespeed_fps) * 0.20)); // ~0.2s
_dlg_was = _now;

if (talk_cd > 0) talk_cd--;

// open when close to a box, but respect cooldown

if (!is_undefined(dialog2p_is_open) && !dialog2p_is_open(pid)) {
    if (controls_pressed(pid,"Interact") && talk_cd <= 0) {
        var _handled_interact = false;
        if (!is_undefined(overworld_find_interactable_npc) && !is_undefined(overworld_npc_interact)) {
            var _npc = overworld_find_interactable_npc(id, 18);
            if (_npc != noone) _handled_interact = overworld_npc_interact(_npc, pid);
        }

        if (!_handled_interact) {
            var box = instance_nearest(x, y, oDialogBox);
            if (box != noone && point_distance(x, y, box.x, box.y) <= 16) {
                if (!variable_global_exists("DIALOG_SPEED")) global.DIALOG_SPEED = 2;
                var box_text = "";
                if (instance_exists(box) && variable_instance_exists(box, "text")) {
                    box_text = string(variable_instance_get(box, "text"));
                }
                try {
                    if (!is_undefined(dialog2p_show_now)) {
                        dialog2p_show_now(pid, box_text);
                        _handled_interact = true;
                    } else if (!is_undefined(dialog2p_enqueue_text)) {
                        dialog2p_enqueue_text(pid, box_text, box_text, "any");
                        _handled_interact = true;
                    }
                } catch (e_) {}
            }
        }

        if (_handled_interact) talk_cd = ceil(game_get_speed(gamespeed_fps) * 0.25); // ~0.25s lockout
    }
}
