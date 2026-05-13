# Cleanup Agent

Responsibility: Tracks stale comments, unclear names, ownership drift, temporary debug leftovers, and documentation freshness.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

## Files Watched

- `AGENTS.md` - Project documentation or checkpoint notes.
- `CHECKPOINT_EscalationLoopPlayable.md` - Project documentation or checkpoint notes.
- `CHECKPOINT_PrototypePhysicsPlayable.md` - Project documentation or checkpoint notes.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles Anchor Ball cursed-tide pull, target rules, cooldowns, visuals, and debug counters.
- `scripts/BallDropSystem.gd` - Tracks Doubloon progress toward score-tied reward drops and cue/eight-ball sink penalties.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/CannonBallSystem.gd` - Stage 3 Cannon Ball anomaly shell for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/DebugOverlay.gd` - Formats debug menu, performance overlay, toggles, and physics debug text.
- `scripts/PocketSystem.gd` - Loads authored pocket geometry and detects pocket captures.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and pocket-side score popup presentation.
- `scripts/ShotEventSystem.gd` - Tracks causal per-shot scoring events for sunk balls.
- `scripts/SpawnSystem.gd` - Creates balls, queues reward drops, performs safe spawn searches, and owns current anomaly spawn odds.
- `scripts/Table.gd` - High-level table coordinator and current home of authoritative arcade ball physics.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.
- `scripts/WayfinderSystem.gd` - Handles Wayfinder activation and temporary guided-ball redirects.

## Current Notes

- Cleanup should preserve gameplay behavior and avoid opportunistic physics retuning.
- AGENTS.md and project_brain should be refreshed after major playable milestones.

## Risks Or TODOs

- Generated reports can drift if not regenerated after major changes.
- Scanner classifications are heuristic until files add `# index:*` metadata.

## Questions

- Which debug toggles should remain long-term?
- Which generated reports are becoming noisy or stale?
