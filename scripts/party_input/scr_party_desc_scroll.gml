// Centralized helper to update the party description scroll request
function scr_party_desc_scroll(_delta, _src){
    if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
    global.sys_party_desc_scroll_req += _delta;
    // Optional debug logging to trace double inputs
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        var _s = (is_undefined(_src) ? "unknown" : string(_src));
        show_debug_message("[scr_party_desc_scroll] src=" + _s + ", delta=" + string(_delta) + ", total=" + string(global.sys_party_desc_scroll_req));
    }
}
