# Project Brain

This folder is generated/reference-only.

It exists to help future AI/Codex sessions understand Kraken An Eight Ball quickly without rereading the whole project from zero.

Important rules:

- Gameplay source of truth remains the real scripts, scenes, and `AGENTS.md`.
- Generated reports may be imperfect and should not override code review.
- The scanner is local-only and should only generate/update files inside `project_brain/`.
- No autonomous agents live here. These are role maps and reports only.

## Do Not Misuse

- `project_brain/` is not source of truth.
- Do not make gameplay changes based only on generated reports.
- Always check real source files and `AGENTS.md` before editing behavior.

Regenerate with:

```powershell
python tools/build_project_brain.py
```
