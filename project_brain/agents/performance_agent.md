# Performance Agent

Responsibility: Tracks visual cost, broad-phase health, trail redraws, particle load, and stress-test readiness.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

- `scenes/MainMenu.tscn` - Layered title-screen scene with background art, animated overlay passes, foreground art, fog, and menu UI.
- `scripts/AimPreview.gd` - Draws polished aim lines, swept cue/target prediction, pocket stopping, endpoint markers, Treasure/Embezzler perception snapshots, and AimPreview broad-phase counters.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/DebugOverlay.gd` - Formats debug menu, modular visible debug panels, requested-section performance snapshots, full F3 overlay, toggles, and physics debug text.
- `scripts/DebugPanel.gd` - Reusable draggable debug panel shell with pause-safe input consumption and lightweight text display.
- `scripts/EmbezzlerSystem.gd` - Embezzler anomaly system for copied Doubloon storage, secret target pocket, willingness, once-per-shot hide-or-run decisions, escape commitment, pocket roll, capture payout, escape cleanup, visuals, and debug counters.
- `scripts/HudFeed.gd` - Bottom-left rolling captain's-log feed with fading stack, hover-scroll review, history, and multiline wrapped entries.
- `scripts/MainMenu.gd` - Title-screen shell, layered menu presentation, button input, and transition into the gameplay scene.
- `scripts/MainMenuPresentationOverlay.gd` - Draw-only layered title-screen atmosphere for moon glow, stars, ocean shimmer, and fog.
- `scripts/PauseMenu.gd` - Pause menu shell, resume/quit wiring, legacy/hidden Quartermaster tab state, debug panel toggles, and temporary Event Test Button checkboxes.
- `scripts/PocketStreakPresenter.gd` - Queued Pocket Streak multiplier presentation, fixed-pool audio/reverb, X4+ whirlpool visuals, and localized presentation-only threat tells.
- `scripts/PocketStreakSystem.gd` - Tracks same-pocket object-ball streaks per shot, same-pocket scoring subtotals, multiplier context, and double-award safety.
- `scripts/PocketSystem.gd` - Loads authored pocket geometry and detects pocket captures.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/QuartermasterHUD.gd` - Live right-side Quartermaster side-rail shop presentation with item slots, costs, hover tooltips, affordability tinting, and cue-safe clicks.
- `scripts/QuartermasterOfferRefreshEffect.gd` - Presentation-only fresh-stock glow/shimmer effect for newly refreshed Quartermaster offers.
- `scripts/QuartermasterSystem.gd` - Owns Quartermaster inventory, prices, affordability, active rotating offers, event-driven offer refresh, and purchase-to-Reserve state.
- `scripts/ReserveDeploymentPresenter.gd` - Draw-only cursor icon and dotted tether presentation while deploying a reserved item.
- `scripts/ReserveSlotsUI.gd` - Icon-only upper table-frame Reserve slot UI with hover glow, click consumption, and deployment request wiring.
- `scripts/ReserveSystem.gd` - Owns three Reserve slot contents, selected/deploying state, deployment confirm/cancel bookkeeping, snapshots, and simple debug counters.
- `scripts/TableEventMenu.gd` - Compact Request Kraken Intervention menu with three weighted offer cards, affordability, rarity display, hover, close, and purchase forwarding.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.
- `scripts/TreasureBallSystem.gd` - Treasure Ball system for debug-spawn identity tracking, AimPreview corridor perception grace, committed hide targets, corridor/pocket-aware fleeing, soft scuttle movement, self-braking, reduced self-steer shove, and draw-only leg reporting.
- `scripts/WayfinderCurrentPresenter.gd` - Draw-only Wayfinder Current readability presentation for initial teal/gold pulses and transfer flashes.

## Current Notes

- Do not solve chaos by preventing chaos; degrade visuals first.
- High ball counts and large earned chain reactions are intended.
- Coalesce repeated work before reducing gameplay ambition; avoid unnecessary redraws and reuse/pool temporary visuals where practical.
- Optimization should preserve readability as well as performance.
- Hidden debug panels/overlays should not keep formatting strings or requesting broad snapshots every frame.
- BallAudioSystem.gd uses pooled players, thresholds, and cooldowns so collision SFX scales with chaos.
- Pocket Streak audio uses a finite clip, fixed pool, cooldowns, caps, and a dedicated reverb bus; do not reintroduce AudioStreamGenerator.
- Anchor is now state/event-driven curse-seed gameplay, not continuous force-field simulation.
- Embezzler is capped and event-driven around score gain, aim pressure, once-per-shot decisions, capture, and escape.
- Score stack coalescing reduces independent label/tween pressure during high-chaos scoring.
- Kraken Intervention is shot/event-driven; old automatic BallDrop reward spawning should remain gated and backstage.
- Wayfinder Current is intentionally uncapped in affected-ball count for now, but keeps radius, lifetime, transfer-depth, and eligibility safeguards.
- Pocket Streak whirlpool/threat tells are localized presentation-only effects with no suction/pull by deliberate design.
- Quartermaster stock refresh is event-driven; Reserve and placement presentation should avoid continuous scans.
- Main menu atmosphere is draw-only/lightweight and should stay presentation-only.
- AimPreview.gd uses broad-phase filtering, rebuild coalescing, and debug counters to keep swept prediction affordable without lying about grazes.

## Risks Or TODOs

- Visual effects should degrade before gameplay chaos is limited.
- Pooling/reuse is not broadly implemented for temporary visuals yet.
- AimPreview rebuild coalescing should preserve reliable graze behavior and avoid tolerance-based lies.
- Hidden debug UI should remain logically cheap, not merely invisible.
- Collision audio cooldowns should prevent spam without making meaningful impacts feel late.
- Anchor should stay event/state-driven; avoid reintroducing continuous force scans.
- Embezzler should stay capped and avoid same-shot escape-roll spam.
- Score stacks should coalesce celebration before any visual suppression is considered.
- Kraken Intervention and HudFeed should remain event/message-driven rather than becoming per-frame scanners.

## Questions

- What visual-quality tiers should exist for trails, particles, aura effects, and score labels?
- When should pooling replace ad hoc temporary visual nodes?
