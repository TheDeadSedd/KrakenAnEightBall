# Anomaly Ball Agent

Responsibility: Tracks Wayfinder, Powder Keg, Anchor curse seeds, Cannon Ball, Treasure Ball, Embezzler, and future anomaly behavior boundaries.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/Ball.gd` - Individual ball state, visuals, friction helpers, trails, draw-only anomaly presentation such as Cannon heat and Treasure legs, and anomaly identity flags.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BallDropMeter.gd` - Vertical right-side HUD meter for progress toward the next score-earned ball drop.
- `scripts/BallDropSystem.gd` - Tracks Doubloon progress toward score-tied reward drops and cue/eight-ball sink penalties.
- `scripts/BallPlacementSystem.gd` - Reusable item-agnostic placement mode with ghost preview, safe-position validation, and confirm/cancel flow for shop, Reserve, debug, and future placement effects.
- `scripts/CannonBallSystem.gd` - Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/EmbezzlerSystem.gd` - Embezzler anomaly system for copied Doubloon storage, secret target pocket, willingness, once-per-shot hide-or-run decisions, escape commitment, pocket roll, capture payout, escape cleanup, visuals, and debug counters.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/TreasureBallSystem.gd` - Treasure Ball system for debug-spawn identity tracking, AimPreview corridor perception grace, committed hide targets, corridor/pocket-aware fleeing, soft scuttle movement, self-braking, reduced self-steer shove, and draw-only leg reporting.
- `scripts/WayfinderSystem.gd` - Handles Wayfinder activation and temporary guided-ball redirects.

## Current Notes

- Wayfinder, Powder Keg, Anchor, Cannon, Treasure, and Embezzler all have focused system boundaries.
- Anchor's old continuous field identity is retired; current Anchor behavior is curse-seed selection, chains, cue-control-gated tightening, warning, spread, and collapse.
- Cannon Ball has collision tuning, Powder Keg launch, heavy-impact shake, and high-speed heat presence.
- Treasure Ball is a debug-spawn perception-grace/hiding/scuttle experiment; it reacts to being watched, not just exact first-hit targeting.
- Treasure should feel like a cautious sneaky thief, not a shortest-path optimizer, and remains separate from the Embezzler.
- Embezzler is capped and debug-spawnable; it copies Doubloon value, tracks a secret pocket, uses once-per-shot hide-or-run decisions, and resolves capture/escape.

## Risks Or TODOs

- Anchor curse-seed behavior is tuned by feel and should be adjusted incrementally without restoring continuous field pull.
- Future anomalies should avoid hidden coupling through Table.gd.
- Treasure rewards and regular spawn odds are not implemented yet.
- Embezzler spawn odds and anomaly special interactions are not implemented yet.

## Questions

- Which future anomalies should interact with Anchor curse chains or Embezzler escape pressure?
- Should anomaly-touch scoring expand beyond current event rewards?
