
audio_play_sound(snd_Littleroot_Town, 0, 1);

// Room1 NPC implementation sample: a non-trainer bug catcher that starts an
// overworld cutscene on interact. Copy this block and change id/position/text.
var _cutscene_npc = instance_create_layer(208, 240, "Instances", oNpc);
if (_cutscene_npc != noone){
    _cutscene_npc.npc_id = "room1_bugcatcher_cutscene_test";
    _cutscene_npc.npc_sprite_base = "spr_bugcatcher";
    _cutscene_npc.npc_facing_dir = 2;
    _cutscene_npc.trainer_enabled = false;
    _cutscene_npc.cutscene_on_interact = true;
    _cutscene_npc.cutscene_shared = true;
    _cutscene_npc.cutscene_lines = [
        "This is an overworld cutscene test.",
        "If player two is joined, both players are locked until I finish talking."
    ];
    _cutscene_npc.dialog_text = "Talk to me to test overworld cutscenes.";
}
