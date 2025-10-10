

function skin_set(skinName){
	switch(skinName){
		case "brendan":
			spriteLeft = sbrendanleft;
			spriteUp = sbrendanup;
			spriteDown = sbrendandown;
			spriteRight = sbrendanright;
			sprite_index = spriteDown
		break;
		
		default://default to brendan
			spriteLeft = sbrendanleft;
			spriteUp = sbrendanup;
			spriteDown = sbrendandown;
			spriteRight = sbrendanright;
			sprite_index = spriteDown
		break;
	}
}