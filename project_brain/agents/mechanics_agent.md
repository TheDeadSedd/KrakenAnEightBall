# Mechanics Agent

Responsibility: Tracks core play loops, shot lifecycle, scoring hooks, shot-event history, ball identity, and moment-to-moment billiards feel.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/Ball.gd` - Individual ball state, visuals, friction helpers, trails, draw-only anomaly presentation such as Cannon heat and Treasure legs, and anomaly identity flags.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BallDropMeter.gd` - Retired/legacy vertical HUD meter for the old automatic BallDrop loop; current progression UI is TableEventMeter.
- `scripts/BallDropSystem.gd` - Backstage legacy/gated automatic reward-drop helpers plus active cue/eight-ball sink penalty handling and debug plumbing.
- `scripts/BallPlacementSystem.gd` - Reusable item-agnostic placement mode with ghost preview, safe-position validation, and confirm/cancel flow for shop, Reserve, debug, and future placement effects.
- `scripts/CannonBallSystem.gd` - Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.
- `scripts/PocketStreakPresenter.gd` - Queued Pocket Streak multiplier presentation, fixed-pool audio/reverb, X4+ whirlpool visuals, and localized presentation-only threat tells.
- `scripts/PocketStreakSystem.gd` - Tracks same-pocket object-ball streaks per shot, same-pocket scoring subtotals, multiplier context, and double-award safety.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and evolving pocket-side score stack presentation.
- `scripts/ShotEventSystem.gd` - Tracks causal per-shot foundational, skilled, heroic, and legendary scoring events for sunk balls.
- `scripts/SpawnSystem.gd` - Creates balls, performs safe spawn searches, owns regular anomaly odds, executes Table Event drop/launch helpers, and routes debug Anchor requests into curse-seed transformation.
- `scripts/Table.gd` - High-level table coordinator, shot lifecycle owner, early cue-reclaim gate, and current home of authoritative arcade ball physics.
- `scripts/TableDecorRandomizer.gd` - Scanned project file; classification is best-effort.
- `scripts/TableEventMenu.gd` - Compact Request Kraken Intervention menu with three weighted offer cards, affordability, rarity display, hover, close, and purchase forwarding.
- `scripts/TableEventMeter.gd` - Horizontal bottom-center KRAKEN INTERVENTION meter with shot progress, percent text, pulse feedback, and ready icon.
- `scripts/TableEventSystem.gd` - Owns Kraken Intervention shot-earned threshold tracking, pending readiness, weighted offers, purchases, debug triggers, and player-chosen Table Event execution routing.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.
- `scripts/TreasureBallSystem.gd` - Treasure Ball system for debug-spawn identity tracking, AimPreview corridor perception grace, committed hide targets, corridor/pocket-aware fleeing, soft scuttle movement, self-braking, reduced self-steer shove, and draw-only leg reporting.

## Current Notes

- Current loop: better shots create Doubloons, Kraken Intervention opportunities, player-chosen Table Events, more balls/anomalies, more interactions, and an escalating table state.
- Kraken Intervention is the active progression spine; automatic BallDrop rewards are retired/gated.
- Early cue reclaim is shot-lifecycle coordination in Table.gd and should stay lightweight.
- Cue/eight-ball sinks are penalties now, not run-ending conditions.
- ShotEventSystem.gd now tracks foundational, skilled, heroic, and legendary events through causal shot history.
- PocketStreakSystem.gd tracks same-pocket streak bonuses separately from MULTI_SINK.
- Preserve cue feel, shot feel, pocket feel, and scoring values during cleanup.
- Automatic score-triggered BallDrop rewards are retired/gated; BallDropSystem is mostly legacy/debug support plus cue/eight-ball penalty handling.

## Risks Or TODOs

- Kraken Intervention threshold/cost/weight tuning is first-pass and needs longer playtesting.
- Cue/eight-ball sink penalties should not accidentally feed Kraken Intervention or revive legacy BallDrop progress.
- Early cue reclaim must stay safe: cue-ball motion or reset/drop states should still block release.
- Expanded shot-event thresholds may need conservative tuning after longer chaos-table sessions.
- Pocket Streak bonuses should remain double-award safe when multiple same-pocket sinks resolve rapidly.

## Questions

- Which new shot-event thresholds need tuning after longer playtests?
- Which Kraken Intervention costs/weights/thresholds need playtest tuning?
