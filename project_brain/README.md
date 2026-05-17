# Project Brain

This folder is generated/reference-only.

It exists to help future AI/Codex sessions understand Kraken An Eight Ball quickly without rereading the whole project from zero.

Current snapshot:

- Kraken An Eight Ball is a systemic arcade-chaos billiards prototype.
- The current loop is better shots -> more Doubloons -> Kraken Intervention opportunities -> player-chosen Table Events -> more balls/anomalies/chaos -> survive the escalating table.
- Kraken Intervention is the active progression spine; automatic score-triggered BallDrop rewards are retired/gated.
- BallDropSystem is mostly penalty handling, legacy support, and debug plumbing.
- Main Menu, pooled collision audio, gameplay music, live Quartermaster HUD, Reserve slots/deployment, HudFeed, modular debug panels, evolving score stacks, Pocket Streaks, Anchor curse seeds, Embezzler, Broadside Attack, Wayfinder Current, and expanded shot-event tiers are active modern systems.
- Early cue reclaim, fake-3D presentation, Cannon heat/impact presence, Treasure perception grace/hiding, Embezzler hide-or-run pressure, Pocket Streak whirlpools, and Wayfinder Current readability pulses remain important active systems.
- Generated reports are a project map only; `AGENTS.md` and the real scripts/scenes remain authoritative.

Important rules:

- Gameplay source of truth remains the real scripts, scenes, and `AGENTS.md`.
- Generated reports may be imperfect and should not override code review.
- `project_brain/debug_media/` is reference-only visual evidence, not gameplay/source code.
- The scanner is local-only and should only generate/update files inside `project_brain/`.
- No autonomous agents live here. These are role maps and reports only.

## Do Not Misuse

- `project_brain/` is not source of truth.
- Do not make gameplay changes based only on generated reports.
- Always check real source files and `AGENTS.md` before editing behavior.

## Debug Media

`project_brain/debug_media/` is for visual debugging references, performance captures, feel/polish references, reproduction clips, and comparison screenshots/videos.

- Check relevant debug media when investigating feel, prediction, anomaly, UI, or performance issues.
- Treat debug media as reference material only; never as gameplay/source code or authoritative behavior.

Regenerate with:

```powershell
python tools/build_project_brain.py
```
