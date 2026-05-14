# Mechanics Agent

Responsibility: Tracks core play loops, shot lifecycle, scoring hooks, ball identity, and moment-to-moment billiards feel.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles Anchor Ball cursed-tide pull, one-current-per-target selection, cooldowns, visuals, and debug counters.
- `scripts/Ball.gd` - Individual ball state, visuals, friction helpers, trails, draw-only anomaly presentation such as Cannon heat and Treasure legs, and anomaly identity flags.
- `scripts/BallDropMeter.gd` - Vertical right-side HUD meter for progress toward the next score-earned ball drop.
- `scripts/BallDropSystem.gd` - Tracks Doubloon progress toward score-tied reward drops and cue/eight-ball sink penalties.
- `scripts/CannonBallSystem.gd` - Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and pocket-side score popup presentation.
- `scripts/ShotEventSystem.gd` - Tracks causal per-shot scoring events for sunk balls.
- `scripts/SpawnSystem.gd` - Creates balls, queues reward drops, performs safe spawn searches, and owns regular anomaly plus Anchor priority spawn odds.
- `scripts/Table.gd` - High-level table coordinator, shot lifecycle owner, early cue-reclaim gate, and current home of authoritative arcade ball physics.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.
- `scripts/TreasureBallSystem.gd` - Treasure Ball system for debug-spawn identity tracking, AimPreview corridor perception grace, committed hide targets, corridor/pocket-aware fleeing, soft scuttle movement, self-braking, reduced self-steer shove, and draw-only leg reporting.

## Current Notes

- Current loop: better play creates more Doubloons, score-tied drops, more balls, more interactions, and an escalating table state.
- Early cue reclaim is shot-lifecycle coordination in Table.gd and should stay lightweight.
- Cue/eight-ball sinks are penalties now, not run-ending conditions.
- Preserve cue feel, shot feel, pocket feel, and scoring values during cleanup.
- Score-tied ball drops and cue/eight-ball sink penalties now flow through BallDropSystem.gd boundaries.

## Risks Or TODOs

- BallDropSystem.gd is first-pass playable; drop tuning and penalty presentation still need playtesting.
- Cue/eight-ball sink penalties should not accidentally feed score-tied drop progress.
- Early cue reclaim must stay safe: cue-ball motion or reset/drop states should still block release.

## Questions

- How many extra balls should different score-event tiers award?
- When should a crowded table stop escalating and start resolving?
