# Project Brain

This folder is generated/reference-only.

It exists to help future AI/Codex sessions understand Kraken An Eight Ball quickly without rereading the whole project from zero.

Current snapshot:

- Kraken An Eight Ball is a systemic arcade-chaos billiards prototype.
- The current loop is better play -> more score -> more balls -> more chaos -> survive the escalating table.
- Early cue reclaim, fake-3D presentation, Cannon heat/impact presence, and Treasure perception/hiding are active modern systems.
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
