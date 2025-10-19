// Developer helper: assign a list of move IDs to the first Pokémon in a player's party
// Usage examples:
//   dev_assign_moves_to_first(0, [1,2,3,4]);
//   dev_assign_moves_to_first(0, [29,33]); // fills remaining slots with -1

function dev_assign_moves_to_first(_pid, _moves_array){
    // Normalise inputs
    var pid = (is_real(_pid) ? floor(_pid) : 0);
    var moves_in = (is_array(_moves_array) ? _moves_array : []);

    // Ensure party exists and has at least one slot
    var P = party_ensure(pid);
    if (!is_struct(P)){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[DEV] party_ensure failed for pid=" + string(pid));
        return false;
    }
    if (!is_array(P.mons) || array_length(P.mons) <= 0){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[DEV] No mons in party for pid=" + string(pid));
        return false;
    }

    var mon = P.mons[0];
    if (!is_struct(mon)){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[DEV] party["+string(pid)+"].mons[0] is not a mon struct");
        return false;
    }

    // Ensure move/pp arrays exist
    if (!is_array(mon.moves)) mon.moves = [-1,-1,-1,-1];
    if (!is_array(mon.pps))   mon.pps   = [0,0,0,0];

    // Fill up to 4 slots using provided move ids (fill remaining with -1)
    for (var i = 0; i < 4; i++){
        var mid = -1;
        if (i < array_length(moves_in) && is_real(moves_in[i]) && moves_in[i] > 0) mid = floor(moves_in[i]);
        mon.moves[i] = mid;
        mon.pps[i]   = (mid > 0) ? __pfc_move_pp(mid) : 0;
    }

    // Update seen_moves so the UI doesn't show these as "New" unless desired
    if (!variable_struct_exists(mon, "seen_moves") || !is_array(mon.seen_moves)) mon.seen_moves = [];
    for (var si = 0; si < array_length(mon.moves); si++){
        var mvv = mon.moves[si];
        if (mvv > 0){
            var already = false;
            for (var jj = 0; jj < array_length(mon.seen_moves); jj++) if (mon.seen_moves[jj] == mvv) { already = true; break; }
            if (!already) array_push(mon.seen_moves, mvv);
        }
    }

    // Persist changes back into party struct (party_ensure works on global.PARTY references but be explicit)
    P.mons[0] = mon;
    global.PARTY[pid] = P;

    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[DEV] Assigned moves to party["+string(pid)+"].mons[0]: " + string(mon.moves));
    return true;
}
