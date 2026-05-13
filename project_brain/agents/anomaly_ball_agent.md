# Anomaly Ball Agent

Responsibility: Tracks Wayfinder, Powder Keg, Anchor Ball, Cannon Ball, and future anomaly behavior boundaries.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles Anchor Ball cursed-tide pull, target rules, cooldowns, visuals, and debug counters.
- `scripts/Ball.gd` - Individual ball state, visuals, friction helpers, trails, and anomaly identity flags.
- `scripts/BallDropMeter.gd` - Vertical right-side HUD meter for progress toward the next score-earned ball drop.
- `scripts/BallDropSystem.gd` - Tracks Doubloon progress toward score-tied reward drops and cue/eight-ball sink penalties.
- `scripts/CannonBallSystem.gd` - Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/WayfinderSystem.gd` - Handles Wayfinder activation and temporary guided-ball redirects.

## Current Notes

- Wayfinder, Powder Keg, and Anchor are active anomaly systems; Cannon Ball has collision tuning, Powder Keg launch, heavy-impact shake, and high-speed heat presence.
- Anchor has independent priority spawn odds and object-ball-only pull.

## Risks Or TODOs

- Anchor behavior is tuned by feel and should be adjusted incrementally.
- Future anomalies should avoid hidden coupling through Table.gd.

## Questions

- Should future anomalies interact with Anchor fields, or stay independent?
- Should anomaly-touch scoring expand beyond current event rewards?
