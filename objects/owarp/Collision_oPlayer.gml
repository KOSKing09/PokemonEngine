
if (_room != noone){
	var _warp_sound_res = warp_sound;
	if (is_undefined(_warp_sound_res) || _warp_sound_res == -1 || _warp_sound_res == noone){
		switch (string_lower(string(warp_kind))){
			case "door": _warp_sound_res = snd_Warp_Door; break;
			case "ladder": _warp_sound_res = snd_Warp_Ladder; break;
			default: _warp_sound_res = snd_Warp_Exit; break;
		}
	}
	if (!is_undefined(sfx_play_safe)) sfx_play_safe(_warp_sound_res, 1);
	world_warp_to(_room, _x, _y, {
		transition_style: trans_style
	});
}
