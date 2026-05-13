# UI Agent

Responsibility: Tracks HUD, debug panels, score popups, callouts, cue presentation, and player-facing text.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Main.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/BallDropMeter.gd` - Vertical right-side HUD meter for progress toward the next score-earned ball drop.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.
- `scripts/DebugOverlay.gd` - Formats debug menu, performance overlay, toggles, and physics debug text.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and pocket-side score popup presentation.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.

## Current Notes

- Score popups are pocket-side arcade celebrations, not generic UI spam.
- Debug labels should stay clearly marked and not leak temporary test wording into player-facing strings.
- BallDropSystem.gd owns rotating score-earned drop-message selection; SpawnSystem/Table carry those messages to callouts.

## Risks Or TODOs

- Score popup readability can regress when many events happen at once.
- Debug overlay can become noisy as more counters are added.

## Questions

- Should ball drop callouts get themed variants now that the BallDropSystem spine exists?
- Which popup effects should degrade first on low-end machines?
