#!/usr/bin/env python3
"""
Pokemon Engine — Party Empty Slot / PC Transfer Safety Patcher v2

Purpose:
  Fix crash + "???" display when party slot 0 becomes undefined after moving
  a Pokemon into PC storage.

Target branch:
  chat-update-branch

Why v2:
  v1 assumed exact owning files and exact "function name(" formatting.
  This version scans all scripts/*.gml, locates the live function owners,
  and patches those live files.

Output:
  Terminal PASS/FAIL only.
  No patched .gml copy.
  No verification report file.
"""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path


EXPECTED_BRANCH = "chat-update-branch"
SCRIPT_ROOT = Path("scripts")

TARGET_FUNCTIONS = [
    "party_model_get_mons",
    "party_model_update_mon",
    "__party_get_desc_text",
    "__party_impl_draw_summary",
]


PARTY_MODEL_GET_MONS_NEW = 'function party_model_get_mons(_pid){\n    if (variable_global_exists("PARTY") && is_array(global.PARTY) && array_length(global.PARTY) > _pid){\n        var _p = global.PARTY[_pid];\n        if (is_struct(_p) && variable_struct_exists(_p,"mons") && is_array(_p.mons)){\n            var _mons = _p.mons;\n            var _cleanMons = [];\n            var _hadHole = false;\n            for (var _pm = 0; _pm < array_length(_mons); _pm++){\n                var _partyMon = _mons[_pm];\n                if (is_struct(_partyMon)){\n                    array_push(_cleanMons, _partyMon);\n                } else {\n                    _hadHole = true;\n                }\n            }\n            if (_hadHole){\n                _p.mons = _cleanMons;\n                global.PARTY[_pid] = _p;\n                return _cleanMons;\n            }\n            return _mons;\n        }\n    }\n    return [];\n}'
DRAW_SUMMARY_GUARD = '    if (!is_struct(_M)){\n        var _firstValidIndex = -1;\n        for (var _validMonIndex = 0; _validMonIndex < _n; _validMonIndex++){\n            if (is_struct(_mons[_validMonIndex])){\n                _firstValidIndex = _validMonIndex;\n                break;\n            }\n        }\n\n        if (_firstValidIndex >= 0){\n            _P.sel = _firstValidIndex;\n            _M = _mons[_firstValidIndex];\n        } else {\n            return;\n        }\n    }\n'
DESC_TEXT_GUARD = '    if (!is_struct(_M)) return "";\n'
UPDATE_MON_UNDEFINED_GUARD = "    if (is_undefined(_mon)) return party_model_remove_mon(_pid, _index);\n"


def run_git(root: Path, args: list[str]) -> str | None:
    try:
        result = subprocess.run(
            ["git", *args],
            cwd=str(root),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except Exception:
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def is_git_checkout(root: Path) -> bool:
    return bool(run_git(root, ["rev-parse", "--git-dir"]))


def current_branch(root: Path) -> str | None:
    return run_git(root, ["branch", "--show-current"])


def find_project_root(start: Path) -> Path:
    start = start.resolve()
    for candidate in [start, *start.parents]:
        if (candidate / SCRIPT_ROOT).exists():
            return candidate
    raise FileNotFoundError("Could not find scripts/ folder. Run from project root or pass --root.")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8", newline="\n")


def list_gml_files(root: Path) -> list[Path]:
    return sorted((root / SCRIPT_ROOT).glob("**/*.gml"))


def find_function_start(content: str, function_name: str) -> int:
    pattern = re.compile(r"(?m)^[ \t]*function[ \t]+" + re.escape(function_name) + r"[ \t]*\(")
    match = pattern.search(content)
    return -1 if not match else match.start()


def find_function_span(content: str, function_name: str) -> tuple[int, int]:
    start = find_function_start(content, function_name)
    if start < 0:
        return -1, -1

    brace_start = content.find("{", start)
    if brace_start < 0:
        return -1, -1

    depth = 0
    in_string = False
    string_char = ""
    escaped = False
    in_line_comment = False
    in_block_comment = False

    index = brace_start
    while index < len(content):
        char = content[index]
        nxt = content[index + 1] if index + 1 < len(content) else ""

        if in_line_comment:
            if char == "\n":
                in_line_comment = False
            index += 1
            continue

        if in_block_comment:
            if char == "*" and nxt == "/":
                in_block_comment = False
                index += 2
                continue
            index += 1
            continue

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == string_char:
                in_string = False
            index += 1
            continue

        if char == "/" and nxt == "/":
            in_line_comment = True
            index += 2
            continue
        if char == "/" and nxt == "*":
            in_block_comment = True
            index += 2
            continue

        if char == '"' or char == "'":
            in_string = True
            string_char = char
            index += 1
            continue

        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return start, index + 1

        index += 1

    return -1, -1


def locate_function_files(root: Path) -> dict[str, Path]:
    found: dict[str, Path] = {}
    for path in list_gml_files(root):
        try:
            content = read_text(path)
        except Exception:
            continue
        for fn in TARGET_FUNCTIONS:
            if fn not in found and find_function_span(content, fn)[0] >= 0:
                found[fn] = path
    return found


def replace_function(content: str, function_name: str, new_function: str) -> tuple[str, bool, str]:
    start, end = find_function_span(content, function_name)
    if start < 0 or end < 0:
        return content, False, f"Missing function {function_name}()."

    old_func = content[start:end]
    if old_func == new_function:
        return content, False, ""

    return content[:start] + new_function + content[end:], True, ""


def insert_after_function_open(content: str, function_name: str, insert_text: str, marker: str) -> tuple[str, bool, str]:
    if marker in content:
        return content, False, ""

    start, end = find_function_span(content, function_name)
    if start < 0 or end < 0:
        return content, False, f"Missing function {function_name}()."

    brace_start = content.find("{", start, end)
    if brace_start < 0:
        return content, False, f"Malformed function {function_name}()."

    content = content[:brace_start + 1] + "\n" + insert_text + content[brace_start + 1:]
    return content, True, ""


def patch_draw_summary(content: str) -> tuple[str, bool, list[str]]:
    if "var _firstValidIndex = -1;" in content:
        return content, False, []

    pattern = re.compile(r"(?m)^([ \t]*var[ \t]+_M[ \t]*=[ \t]*__party_mon_get[ \t]*\([ \t]*_P[ \t]*,[ \t]*_pid[ \t]*\)[ \t]*;[ \t]*\n)")
    match = pattern.search(content)
    if not match:
        return content, False, ["Missing __party_impl_draw_summary _M assignment anchor."]

    content = content[:match.end()] + DRAW_SUMMARY_GUARD + content[match.end():]
    return content, True, []


def apply_patch(root: Path) -> tuple[bool, list[str], list[Path]]:
    function_files = locate_function_files(root)
    errors: list[str] = []
    changed_paths: list[Path] = []

    for fn in TARGET_FUNCTIONS:
        if fn not in function_files:
            errors.append(f"Could not locate live function {fn}() under scripts/.")
    if errors:
        return False, errors, changed_paths

    by_file: dict[Path, str] = {}
    for path in set(function_files.values()):
        by_file[path] = read_text(path)

    path_get = function_files["party_model_get_mons"]
    content, changed, error = replace_function(by_file[path_get], "party_model_get_mons", PARTY_MODEL_GET_MONS_NEW)
    if error:
        errors.append(error)
    else:
        by_file[path_get] = content
        if changed:
            changed_paths.append(path_get)

    path_update = function_files["party_model_update_mon"]
    content, changed, error = insert_after_function_open(
        by_file[path_update],
        "party_model_update_mon",
        UPDATE_MON_UNDEFINED_GUARD,
        "return party_model_remove_mon(_pid, _index);",
    )
    if error:
        errors.append(error)
    else:
        by_file[path_update] = content
        if changed and path_update not in changed_paths:
            changed_paths.append(path_update)

    path_desc = function_files["__party_get_desc_text"]
    content, changed, error = insert_after_function_open(
        by_file[path_desc],
        "__party_get_desc_text",
        DESC_TEXT_GUARD,
        'if (!is_struct(_M)) return "";',
    )
    if error:
        errors.append(error)
    else:
        by_file[path_desc] = content
        if changed and path_desc not in changed_paths:
            changed_paths.append(path_desc)

    path_summary = function_files["__party_impl_draw_summary"]
    content, changed, summary_errors = patch_draw_summary(by_file[path_summary])
    errors.extend(summary_errors)
    by_file[path_summary] = content
    if changed and path_summary not in changed_paths:
        changed_paths.append(path_summary)

    if errors:
        return False, errors, changed_paths

    for path in changed_paths:
        write_text(path, by_file[path])

    return bool(changed_paths), [], changed_paths


def collect_all_target_text(root: Path) -> tuple[str, dict[str, Path]]:
    function_files = locate_function_files(root)
    pieces: list[str] = []
    seen: set[Path] = set()
    for path in function_files.values():
        if path not in seen:
            seen.add(path)
            pieces.append(read_text(path))
    return "\n".join(pieces), function_files


def verify(root: Path, strict_branch: bool) -> tuple[int, list[str]]:
    all_text, function_files = collect_all_target_text(root)

    branch_ok = True
    branch_note = "No .git checkout found; branch check skipped for non-git baseline."
    if is_git_checkout(root):
        branch_name = current_branch(root)
        branch_ok = branch_name == EXPECTED_BRANCH
        branch_note = f"Git branch is '{branch_name}', expected '{EXPECTED_BRANCH}'."
    elif strict_branch:
        branch_ok = False
        branch_note = "No .git checkout found and --strict-branch was used."

    checks: list[tuple[str, bool, str]] = [
        ("Expected branch chat-update-branch", branch_ok, branch_note),
        ("party_model_get_mons located", "party_model_get_mons" in function_files, "party_model_get_mons not found."),
        ("party_model_update_mon located", "party_model_update_mon" in function_files, "party_model_update_mon not found."),
        ("__party_get_desc_text located", "__party_get_desc_text" in function_files, "__party_get_desc_text not found."),
        ("__party_impl_draw_summary located", "__party_impl_draw_summary" in function_files, "__party_impl_draw_summary not found."),

        ("party_model_get_mons compacts holes", "var _cleanMons = [];" in all_text and "if (_hadHole)" in all_text, "party_model_get_mons does not compact undefined/non-struct holes."),
        ("party_model_get_mons writes clean party back", "_p.mons = _cleanMons;" in all_text and "global.PARTY[_pid] = _p;" in all_text, "Cleaned party array is not written back."),
        ("party_model_get_mons only preserves structs", "if (is_struct(_partyMon))" in all_text, "party_model_get_mons does not filter to valid mon structs."),
        ("party_model_update_mon undefined removes instead of storing hole", "if (is_undefined(_mon)) return party_model_remove_mon(_pid, _index);" in all_text, "party_model_update_mon does not route undefined to remove."),

        ("summary draw scans first valid mon", "var _firstValidIndex = -1;" in all_text and "for (var _validMonIndex = 0;" in all_text, "Summary draw does not scan for first valid mon."),
        ("summary draw corrects selection", "_P.sel = _firstValidIndex;" in all_text and "_M = _mons[_firstValidIndex];" in all_text, "Summary draw does not correct selection to valid mon."),
        ("summary draw exits when no valid mon", "_firstValidIndex >= 0" in all_text and "return;" in all_text, "Summary draw does not safely exit empty party."),
        ("desc text guards non-struct mon", 'if (!is_struct(_M)) return "";' in all_text, "__party_get_desc_text does not guard non-struct _M."),
        ("No function_exists usage introduced", "function_exists(" not in all_text, "Unsupported function_exists() found."),
    ]

    passed = sum(1 for _name, ok, _reason in checks if ok)
    score = int(round((passed / len(checks)) * 100)) if checks else 0

    print(f"Expected branch: {EXPECTED_BRANCH}")
    print("Located target functions:")
    for fn in TARGET_FUNCTIONS:
        located = function_files.get(fn)
        print(f"- {fn}: {located.relative_to(root) if located else 'NOT FOUND'}")
    print(f"Verification: {score}/100")

    failures: list[str] = []
    for name, ok, reason in checks:
        status = "PASS" if ok else "FAIL"
        print(f"[{status}] {name} — {reason}")
        if not ok:
            failures.append(f"{name}: {reason}")

    return score, failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Patch party empty slot / PC transfer safety.")
    parser.add_argument("--root", default=".", help="Project root. Defaults to current directory.")
    parser.add_argument("--strict-branch", action="store_true", help="Require actual git checkout on chat-update-branch.")
    args = parser.parse_args()

    try:
        root = find_project_root(Path(args.root))

        if is_git_checkout(root):
            branch_name = current_branch(root)
            if branch_name != EXPECTED_BRANCH:
                print("PATCH FAILED BEFORE WRITE")
                print(f"- Wrong branch: '{branch_name}', expected '{EXPECTED_BRANCH}'.")
                verify(root, args.strict_branch)
                return 1

        changed, errors, changed_paths = apply_patch(root)

        if errors:
            print("PATCH FAILED BEFORE WRITE")
            for error in errors:
                print(f"- {error}")
            verify(root, args.strict_branch)
            return 1

        print(f"Patch changed files: {'yes' if changed else 'no; already patched'}")
        for path in changed_paths:
            print(f"- {path.relative_to(root)}")

        score, failures = verify(root, args.strict_branch)
        if score < 100:
            print("\nPATCH FAILED: verification under 100.")
            for failure in failures:
                print(f"- {failure}")
            return 1

        print("\nPATCH SUCCESS: verification 100/100.")
        return 0

    except Exception as exc:
        print(f"PATCH FAILED: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
