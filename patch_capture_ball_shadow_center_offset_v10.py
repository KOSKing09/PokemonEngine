#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

EXPECTED_BRANCH = "chat-update-branch"
MARKER_V7 = "CAPTURE_BALL_SHADOW_TUNE_V7"
MARKER_V10 = "CAPTURE_BALL_SHADOW_CENTER_OFFSET_V10"

def run_git(root, args):
    try:
        r = subprocess.run(["git", *args], cwd=str(root), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception:
        return None

def is_git(root): return bool(run_git(root, ["rev-parse", "--git-dir"]))
def branch(root): return run_git(root, ["branch", "--show-current"])

def root_from(start):
    start = Path(start).resolve()
    for c in [start, *start.parents]:
        if (c / "scripts").exists():
            return c
    raise FileNotFoundError("Could not find scripts/ folder.")

def read(path): return path.read_text(encoding="utf-8")
def write(path, text): path.write_text(text, encoding="utf-8", newline="\n")

def locate(root):
    for path in sorted((root / "scripts").glob("**/*.gml")):
        try: text = read(path)
        except Exception: continue
        if MARKER_V7 in text or MARKER_V10 in text:
            return path
    return None

def patch(text):
    changed = False
    if MARKER_V10 not in text:
        text2 = text.replace(MARKER_V7, MARKER_V10)
        if text2 != text:
            text, changed = text2, True

    replacements = {
        "var _captureBallShadowOffsetY = 4;": "var _captureBallShadowOffsetY = 16;",
        "var _captureBallShadowGroundY = by_draw + _captureBallShadowRadiusY + _captureBallShadowOffsetY;": "var _captureBallShadowGroundY = by_draw + _captureBallShadowOffsetY;",
        "var _captureBallShadowGroundY = ball_to_draw.y + _captureBallShadowRadiusY + _captureBallShadowOffsetY;": "var _captureBallShadowGroundY = ball_to_draw.y + _captureBallShadowOffsetY;",
    }
    for old, new in replacements.items():
        text2 = text.replace(old, new)
        if text2 != text:
            text, changed = text2, True

    errors = []
    if "var _captureBallShadowOffsetY = 16;" not in text:
        errors.append("Could not tune shadow Y offset to 16.")
    if "_captureBallShadowRadiusY + _captureBallShadowOffsetY" in text:
        errors.append("Old radius-based shadow Y still remains.")
    return text, changed, errors

def verify(root, path, strict):
    text = read(path) if path and path.exists() else ""
    branch_ok, note = True, "No .git checkout found; branch check skipped."
    if is_git(root):
        br = branch(root)
        branch_ok = br == EXPECTED_BRANCH
        note = f"Git branch is '{br}', expected '{EXPECTED_BRANCH}'."
    elif strict:
        branch_ok = False
        note = "No .git checkout found and --strict-branch was used."

    checks = [
        ("Expected branch chat-update-branch", branch_ok, note),
        ("Target file located", path is not None, "Could not locate capture shadow file."),
        ("Target file readable", bool(text), "Target file missing or empty."),
        ("v10 marker present", MARKER_V10 in text, "Missing v10 marker."),
        ("Y offset tuned to 16", "var _captureBallShadowOffsetY = 16;" in text, "Shadow Y offset is not 16."),
        ("Shadow Y uses center plus offset", "var _captureBallShadowGroundY = by_draw + _captureBallShadowOffsetY;" in text or "var _captureBallShadowGroundY = ball_to_draw.y + _captureBallShadowOffsetY;" in text, "Shadow Y does not use center + offset."),
        ("Old radius-based Y removed", "_captureBallShadowRadiusY + _captureBallShadowOffsetY" not in text, "Old radius-based Y remains."),
        ("Shadow X still uses current draw point", "var _captureBallShadowX = bx_draw + _captureBallShadowOffsetX;" in text or "var _captureBallShadowX = ball_to_draw.x + _captureBallShadowOffsetX;" in text, "Shadow X not using current draw point."),
        ("No early _u formula", "_u * 0.34" not in text, "Unsafe _u formula remains."),
        ("No function_exists usage introduced", "function_exists(" not in text, "Unsupported function_exists() found."),
    ]
    passed = sum(1 for _, ok, _ in checks if ok)
    score = int(round((passed / len(checks)) * 100))
    print(f"Expected branch: {EXPECTED_BRANCH}")
    print(f"Target file: {path.relative_to(root) if path else 'NOT FOUND'}")
    print(f"Verification: {score}/100")
    fails = []
    for name, ok, reason in checks:
        print(f"[{'PASS' if ok else 'FAIL'}] {name} — {reason}")
        if not ok:
            fails.append(f"{name}: {reason}")
    return score, fails

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--strict-branch", action="store_true")
    args = ap.parse_args()
    try:
        root = root_from(args.root)
        if is_git(root):
            br = branch(root)
            if br != EXPECTED_BRANCH:
                print("PATCH FAILED BEFORE WRITE")
                print(f"- Wrong branch: '{br}', expected '{EXPECTED_BRANCH}'.")
                t = locate(root)
                verify(root, t, args.strict_branch)
                return 1
        t = locate(root)
        if t is None:
            print("PATCH FAILED BEFORE WRITE")
            print("- Could not locate v7/v10 capture shadow block.")
            verify(root, None, args.strict_branch)
            return 1
        text, changed, errors = patch(read(t))
        if errors:
            print("PATCH FAILED BEFORE WRITE")
            for e in errors: print(f"- {e}")
            verify(root, t, args.strict_branch)
            return 1
        if changed:
            write(t, text)
        print(f"Patch changed file: {'yes' if changed else 'no; already patched'}")
        print(f"- {t.relative_to(root)}")
        score, fails = verify(root, t, args.strict_branch)
        if score < 100:
            print("\nPATCH FAILED: verification under 100.")
            for f in fails: print(f"- {f}")
            return 1
        print("\nPATCH SUCCESS: verification 100/100.")
        return 0
    except Exception as exc:
        print(f"PATCH FAILED: {exc}")
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
