# Performance Agent

Responsibility: Tracks visual cost, broad-phase health, trail redraws, particle load, and stress-test readiness.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

## Files Watched

- `scripts/AimPreview.gd` - Draws aim preview and side-effect-free cue-ball prediction.
- `scripts/AnchorBallSystem.gd` - Handles Anchor Ball cursed-tide pull, target rules, cooldowns, visuals, and debug counters.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/DebugOverlay.gd` - Formats debug menu, performance overlay, toggles, and physics debug text.
- `scripts/PocketSystem.gd` - Loads authored pocket geometry and detects pocket captures.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue-contact explosions, radial pushes, and particle bursts.

## Current Notes

- Do not solve chaos by preventing chaos; degrade visuals first.
- High ball counts and large earned chain reactions are intended.
- BallDropSystem.gd exists as the score-tied drop spine and should be watched for high-count visual scaling pressure.

## Risks Or TODOs

- Visual effects should degrade before gameplay chaos is limited.
- Pooling/reuse is not broadly implemented for temporary visuals yet.

## Questions

- What visual-quality tiers should exist for trails, particles, aura effects, and score labels?
- When should pooling replace ad hoc temporary visual nodes?
