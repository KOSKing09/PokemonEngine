# apply_pc_swap_exact_held_state_patch.py
# Pokemon Engine / PC exact held-state swap patch.
# Run from repo root:
#   py -3.11 apply_pc_swap_exact_held_state_patch.py
#
# Fixes:
# - Holding Pokemon A then selecting Pokemon B should place A into B's slot and hold B.
# - Prevents B from becoming "---" due to stale held-origin fields / copied target state.
# - Uses actual PC state fields from your uploaded script:
#     sys_held_from_area, sys_held_from_box, sys_held_from_index
#
# Focused validation only for current PC held swap issue.

from pathlib import Path
import sys

PC_PATH = Path("scripts") / "pc_system" / "pc_system.gml"

SET_CURSOR = '\nfunction pc__set_cursor_mon(_pid, _mon){\n    var _pc = pc__ensure_state(_pid);\n    if (_mon != undefined) _mon = pc__normalize_mon(_mon);\n\n    if (_pc.sys_cursor_area == "party"){\n        return pc__write_party_slot(_pid, _pc.sys_cursor_index, _mon);\n    }\n\n    var _box = pc__get_active_box(_pid);\n    if (!is_struct(_box)) return false;\n    if (!variable_struct_exists(_box, "sys_mons") || !is_array(_box.sys_mons)) _box.sys_mons = [];\n\n    var _idx = floor(_pc.sys_cursor_index);\n    if (_idx < 0) return false;\n    if (_idx >= array_length(_box.sys_mons)) array_resize(_box.sys_mons, _idx + 1);\n\n    _box.sys_mons[_idx] = _mon;\n    return true;\n}\n'
PICKUP = '\nfunction pc__pickup_or_place(_pid){\n    var _pc = pc__ensure_state(_pid);\n\n    var _cursor_area = _pc.sys_cursor_area;\n    var _cursor_index = floor(_pc.sys_cursor_index);\n    var _cursor_box = -1;\n    if (_cursor_area == "box"){\n        _cursor_box = 0;\n        if (variable_struct_exists(_pc, "sys_active_box") && is_real(_pc.sys_active_box)) _cursor_box = floor(_pc.sys_active_box);\n    }\n\n    var _cursor_mon = pc__get_cursor_mon(_pid);\n\n    // PICK UP\n    if (_pc.sys_held_mon == undefined){\n        if (_cursor_mon == undefined){\n            _pc.sys_status_text = "No Pokemon here.";\n            return false;\n        }\n\n        // Hold the exact Pokemon from this slot, then clear that exact slot.\n        _pc.sys_held_mon = _cursor_mon;\n        _pc.sys_held_from_area = _cursor_area;\n        _pc.sys_held_from_box = _cursor_box;\n        _pc.sys_held_from_index = _cursor_index;\n\n        // Clear stale legacy fields from older patch attempts.\n        _pc.sys_held_origin_area = "";\n        _pc.sys_held_origin_box = -1;\n        _pc.sys_held_origin_index = -1;\n\n        if (!pc__set_cursor_mon(_pid, undefined)){\n            _pc.sys_status_text = "Could not pick up Pokemon.";\n            _pc.sys_held_mon = undefined;\n            _pc.sys_held_from_area = "";\n            _pc.sys_held_from_box = -1;\n            _pc.sys_held_from_index = -1;\n            return false;\n        }\n\n        _pc.sys_status_text = "Holding " + pc__mon_display_name(_pc.sys_held_mon);\n        return true;\n    }\n\n    // PLACE / SWAP\n    // Important: capture the target BEFORE writing held into the slot.\n    // If target exists, it becomes the new held Pokemon.\n    var _held = _pc.sys_held_mon;\n    var _target = _cursor_mon;\n\n    if (!pc__set_cursor_mon(_pid, _held)){\n        _pc.sys_status_text = "Could not place Pokemon.";\n        return false;\n    }\n\n    if (_target != undefined){\n        _pc.sys_held_mon = _target;\n        _pc.sys_held_from_area = _cursor_area;\n        _pc.sys_held_from_box = _cursor_box;\n        _pc.sys_held_from_index = _cursor_index;\n\n        _pc.sys_held_origin_area = "";\n        _pc.sys_held_origin_box = -1;\n        _pc.sys_held_origin_index = -1;\n\n        _pc.sys_status_text = "Swapped. Holding " + pc__mon_display_name(_pc.sys_held_mon);\n        return true;\n    }\n\n    _pc.sys_status_text = "Placed " + pc__mon_display_name(_held);\n    _pc.sys_held_mon = undefined;\n    _pc.sys_held_from_area = "";\n    _pc.sys_held_from_box = -1;\n    _pc.sys_held_from_index = -1;\n    _pc.sys_held_origin_area = "";\n    _pc.sys_held_origin_box = -1;\n    _pc.sys_held_origin_index = -1;\n    return true;\n}\n'
RETURN_HELD = '\nfunction pc__return_held_to_origin(_pid){\n    var _pc = pc__ensure_state(_pid);\n    if (_pc.sys_held_mon == undefined) return false;\n\n    var _restore_mon = _pc.sys_held_mon;\n    var _restore_area = _pc.sys_held_from_area;\n    var _restore_box = _pc.sys_held_from_box;\n    var _restore_index = _pc.sys_held_from_index;\n\n    var _returned = false;\n\n    if (_restore_area == "party" && _restore_index >= 0){\n        var _party = pc__get_party_array(_pid);\n        if (_restore_index < array_length(_party) && _party[_restore_index] == undefined){\n            _returned = pc__write_party_slot(_pid, _restore_index, _restore_mon);\n        }\n    } else if (_restore_area == "box" && _restore_box >= 0 && _restore_index >= 0){\n        var _boxes = _pc.sys_boxes;\n        if (_restore_box < array_length(_boxes)){\n            var _box = _boxes[_restore_box];\n            if (is_struct(_box) && variable_struct_exists(_box, "sys_mons") && is_array(_box.sys_mons)){\n                if (_restore_index >= array_length(_box.sys_mons)) array_resize(_box.sys_mons, _restore_index + 1);\n                if (_box.sys_mons[_restore_index] == undefined){\n                    _box.sys_mons[_restore_index] = _restore_mon;\n                    _pc.sys_boxes[_restore_box] = _box;\n                    _returned = true;\n                }\n            }\n        }\n    }\n\n    if (!_returned){\n        _returned = pc__set_first_available(_pid, _restore_mon);\n    }\n\n    if (_returned){\n        _pc.sys_held_mon = undefined;\n        _pc.sys_held_from_area = "";\n        _pc.sys_held_from_box = -1;\n        _pc.sys_held_from_index = -1;\n        _pc.sys_held_origin_area = "";\n        _pc.sys_held_origin_box = -1;\n        _pc.sys_held_origin_index = -1;\n        return true;\n    }\n\n    _pc.sys_status_text = "No room to return Pokemon";\n    return false;\n}\n'

def read_text(path):
    return path.read_text(encoding="utf-8")

def write_text(path, text):
    path.write_text(text, encoding="utf-8")

def find_function_span(text, func_name):
    marker = f"function {func_name}("
    start = text.find(marker)
    if start < 0:
        return (-1, -1)
    brace = text.find("{", start)
    if brace < 0:
        return (-1, -1)
    depth = 0
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return (start, i + 1)
    return (-1, -1)

def replace_function(text, func_name, body):
    start, end = find_function_span(text, func_name)
    if start < 0:
        raise RuntimeError("Missing required function: " + func_name)
    return text[:start] + body.strip() + text[end:]

def fail(reason, checks):
    print("PATCH FAILED")
    passed = sum(1 for _, ok, _ in checks if ok)
    total = len(checks)
    rate = int(round((passed / total) * 100)) if total else 0
    print(f"SUCCESS RATE: {rate}%")
    print("Reason:")
    print(f"- {reason}")
    for name, ok, detail in checks:
        print(f"{'PASS' if ok else 'FAIL'}: {name}" + (f" — {detail}" if detail else ""))
    raise SystemExit(1)

def main():
    checks = []
    def check(name, ok, detail=""):
        checks.append((name, bool(ok), detail))

    print("PC Exact Held-State Swap Patch")
    print("Target: scripts/pc_system/pc_system.gml")
    print("NOTE: based on your uploaded pc_system.gml held-state fields.")

    check("pc_system.gml exists", PC_PATH.exists(), PC_PATH.as_posix())
    if not all(ok for _, ok, _ in checks):
        fail("Required file missing. Run from repo root.", checks)

    before = read_text(PC_PATH)

    check("pc__pickup_or_place exists", "function pc__pickup_or_place" in before)
    check("pc__set_cursor_mon exists", "function pc__set_cursor_mon" in before)
    check("pc__return_held_to_origin exists", "function pc__return_held_to_origin" in before)
    check("actual held-from fields exist", "sys_held_from_area" in before and "sys_held_from_box" in before and "sys_held_from_index" in before)
    check("pc display helper exists", "function pc__mon_display_name" in before)
    check("pc active box field exists", "sys_active_box" in before)

    if not all(ok for _, ok, _ in checks):
        fail("Pre-patch verification failed.", checks)

    try:
        after = before
        after = replace_function(after, "pc__set_cursor_mon", SET_CURSOR)
        after = replace_function(after, "pc__pickup_or_place", PICKUP)
        after = replace_function(after, "pc__return_held_to_origin", RETURN_HELD)
        write_text(PC_PATH, after)
    except Exception as exc:
        fail(str(exc), checks)

    final = read_text(PC_PATH)

    pickup_start, pickup_end = find_function_span(final, "pc__pickup_or_place")
    pickup_text = final[pickup_start:pickup_end] if pickup_start >= 0 else ""
    set_start, set_end = find_function_span(final, "pc__set_cursor_mon")
    set_text = final[set_start:set_end] if set_start >= 0 else ""
    ret_start, ret_end = find_function_span(final, "pc__return_held_to_origin")
    ret_text = final[ret_start:ret_end] if ret_start >= 0 else ""

    check("set_cursor returns success bool", "return true;" in set_text and "return false;" in set_text)
    check("set_cursor resizes box slots safely", "array_resize(_box.sys_mons, _idx + 1)" in set_text)
    check("pickup holds exact cursor mon", "_pc.sys_held_mon = _cursor_mon;" in pickup_text)
    check("pickup writes held-from fields", "_pc.sys_held_from_area = _cursor_area;" in pickup_text and "_pc.sys_held_from_box = _cursor_box;" in pickup_text and "_pc.sys_held_from_index = _cursor_index;" in pickup_text)
    check("pickup clears source slot", "pc__set_cursor_mon(_pid, undefined)" in pickup_text)
    check("swap captures target before writing held", "var _target = _cursor_mon;" in pickup_text and "pc__set_cursor_mon(_pid, _held)" in pickup_text)
    check("swap target becomes held", "_pc.sys_held_mon = _target;" in pickup_text)
    check("swap no global duplicate cleanup", "pc__remove_exact_mon_reference_except" not in pickup_text)
    check("status uses pc__mon_display_name", "pc__mon_display_name(_pc.sys_held_mon)" in pickup_text)
    check("return uses held-from fields", "_pc.sys_held_from_area" in ret_text and "_pc.sys_held_from_box" in ret_text and "_pc.sys_held_from_index" in ret_text)
    check("return clears stale origin fields", "_pc.sys_held_origin_area = \"\";" in ret_text)
    check("no function_exists introduced", "function_exists" not in final)

    passed = sum(1 for _, ok, _ in checks if ok)
    total = len(checks)
    rate = int(round((passed / total) * 100)) if total else 0

    for name, ok, detail in checks:
        print(f"{'PASS' if ok else 'FAIL'}: {name}" + (f" — {detail}" if detail else ""))

    if rate < 100:
        print("PATCH FAILED")
        print(f"SUCCESS RATE: {rate}%")
        print("Reason:")
        for name, ok, detail in checks:
            if not ok:
                print(f"- {name}" + (f": {detail}" if detail else ""))
        raise SystemExit(1)

    print("SUCCESS RATE: 100%")
    print("Changed files:")
    print(f"- {PC_PATH.as_posix()}")

if __name__ == "__main__":
    main()
