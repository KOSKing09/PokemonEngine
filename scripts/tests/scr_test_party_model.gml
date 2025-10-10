// Test harness: scr_test_party_model()
// Call this from a debug keyboard event or init to validate party model functions.
function scr_test_party_model(){
    show_debug_message("[TEST] Starting party model tests...");
    var pid = 0;
    // Ensure clean party
    party_init();
    var P = party_ensure(pid);
    // Clear existing mons
    var mons_before = party_model_get_mons(pid);
    if (is_array(mons_before)) {
        array_resize(mons_before, 0);
        var _Pt = party_ensure(pid); _Pt.mons = mons_before;
    }

    // Create two minimal mon structs
    var m1 = { species_id: 1, name: scr_poke_name_by_id(1), level: 5 };
    var m2 = { species_id: 4, name: scr_poke_name_by_id(4), level: 5 };

    var i1 = party_model_add_mon(pid, m1);
    var i2 = party_model_add_mon(pid, m2);
    var arr = party_model_get_mons(pid);
    show_debug_message("[TEST] After adds: count=" + string(array_length(arr)) + ", i1=" + string(i1) + ", i2=" + string(i2));

    // Swap them
    var okSwap = party_model_swap(pid, 0, 1);
    show_debug_message("[TEST] Swap result: " + string(okSwap));
    arr = party_model_get_mons(pid);
    if (array_length(arr) >= 2) show_debug_message("[TEST] After swap: idx0 species=" + string(arr[0].species_id) + ", idx1=" + string(arr[1].species_id));

    // Remove index 0
    var okRem = party_model_remove_mon(pid, 0);
    arr = party_model_get_mons(pid);
    show_debug_message("[TEST] Remove result: " + string(okRem) + ", remaining=" + string(array_length(arr)));

    show_debug_message("[TEST] party_model tests complete.");
}
