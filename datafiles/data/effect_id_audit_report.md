# Effect ID Audit Report

This report summarizes effect/move IDs that have been implemented or explicitly handled in the codebase. It complements `effect_id_audit_report.csv` and highlights entries recently verified during the battle-system audit on 2025-10-22.

## Recently verified (explicit)

- 69 — Seismic Toss: explicit damage handling implemented in `scripts/battle_actions/battle_actions.gml` (damage = attacker's level).
- 82 — Dragon Rage: explicit damage handling implemented in `scripts/battle_actions/battle_actions.gml` (flat 40 HP damage).
- 101 — Night Shade: explicit damage handling implemented in `scripts/battle_actions/battle_actions.gml` (damage = attacker's level).
 - 32 — Horn Drill: OHKO handling implemented in `scripts/battle_actions/battle_actions.gml` (OHKO accuracy/level logic).
 - 162 — Super Fang: explicit handling implemented in `scripts/battle_actions/battle_actions.gml` (half-target-HP damage).

## Notes

- The CSV `datafiles/data/effect_id_audit_report.csv` was updated to mark the above entries as `explicit` and reference the implementing file.
- Sonic Boom (49) was already marked `explicit`.
- This Markdown file is a lightweight human-readable companion to the CSV; keep it in-sync when marking additional effect IDs as implemented.

Generated: 2025-10-22
