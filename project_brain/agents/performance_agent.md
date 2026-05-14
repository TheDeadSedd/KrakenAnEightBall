# Performance Agent

Responsibility: Tracks visual cost, broad-phase health, trail redraws, particle load, and stress-test readiness.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

- `scripts/AimPreview.gd` - Draws polished aim lines, swept cue/target prediction, pocket stopping, endpoint markers, Treasure perception snapshots, and AimPreview broad-phase counters.
- `scripts/AnchorBallSystem.gd` - Handles Anchor Ball cursed-tide pull, one-current-per-target selection, cooldowns, visuals, and debug counters.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/DebugOverlay.gd` - Formats debug menu, performance overlay, toggles, and physics debug text.
- `scripts/PocketSystem.gd` - Loads authored pocket geometry and detects pocket captures.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.
- `scripts/TreasureBallSystem.gd` - Treasure Ball system for debug-spawn identity tracking, read-only AimPreview corridor perception, committed hide target selection, soft scuttle movement, and fleeing-leg visual reporting.

## Current Notes

- Do not solve chaos by preventing chaos; degrade visuals first.
- High ball counts and large earned chain reactions are intended.
- Coalesce repeated work before reducing gameplay ambition; avoid unnecessary redraws and reuse/pool temporary visuals where practical.
- Optimization should preserve readability as well as performance.
- BallDropSystem.gd exists as the score-tied drop spine and should be watched for high-count visual scaling pressure.
- AimPreview.gd uses broad-phase filtering, rebuild coalescing, and debug counters to keep swept prediction affordable without lying about grazes.

## Risks Or TODOs

- Visual effects should degrade before gameplay chaos is limited.
- Pooling/reuse is not broadly implemented for temporary visuals yet.
- AimPreview rebuild coalescing should preserve reliable graze behavior and avoid tolerance-based lies.

## Questions

- What visual-quality tiers should exist for trails, particles, aura effects, and score labels?
- When should pooling replace ad hoc temporary visual nodes?
