# Systems Agent

Responsibility: Tracks module boundaries, ownership rules, scene wiring, and coordinator responsibilities.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

- `AGENTS.md` - Project documentation or checkpoint notes.
- `scenes/Main.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/MainMenu.tscn` - Layered title-screen scene with background art, animated overlay passes, foreground art, fog, and menu UI.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BallDropSystem.gd` - Backstage legacy/gated automatic reward-drop helpers plus active cue/eight-ball sink penalty handling and debug plumbing.
- `scripts/BallPlacementSystem.gd` - Reusable item-agnostic placement mode with ghost preview, safe-position validation, and confirm/cancel flow for shop, Reserve, debug, and future placement effects.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/CannonBallSystem.gd` - Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/EmbezzlerSystem.gd` - Embezzler anomaly system for copied Doubloon storage, secret target pocket, willingness, once-per-shot hide-or-run decisions, escape commitment, pocket roll, capture payout, escape cleanup, visuals, and debug counters.
- `scripts/GameplayMusicSystem.gd` - Low-volume looping gameplay music owner, separate from collision, UI, Pocket Streak, and anomaly SFX.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
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
- `scripts/WayfinderCurrentPresenter.gd` - Draw-only Wayfinder Current readability presentation for initial teal/gold pulses and transfer flashes.
- `scripts/WayfinderSystem.gd` - Handles Wayfinder activation, guided redirects, temporary Wayfinder Current carriers, transfer-on-hit guided momentum, and current-caused scoring snapshots.

## Current Notes

- Table.gd should coordinate systems without absorbing new feature logic.
- Scene-authored geometry remains the source of truth.
- MainMenu.gd owns title-screen presentation and scene transition without becoming a gameplay app shell.
- TableEventSystem.gd owns Kraken Intervention thresholds, pending readiness, weighted offers, purchases, and event routing.
- Broadside Attack is the first authored staged intervention milestone and should remain a readable pirate artillery scenario.
- QuartermasterSystem.gd owns rotating offers; QuartermasterHUD.gd owns live side-rail shop presentation; ReserveSystem.gd owns slot data; BallPlacementSystem.gd owns item-agnostic placement.
- BallAudioSystem.gd owns pooled event-driven collision SFX instead of burying audio in physics.
- GameplayMusicSystem.gd owns low-volume looping gameplay music separate from SFX; music should support atmosphere without covering collision/event readability.
- TableImpactShakeSystem.gd owns presentation-only fake-3D table shake so gameplay geometry and HUD stay stable.
- Coalesce repeated input/event work in the owning coordinator instead of letting systems rebuild many times per frame.
- Prefer event/state-driven updates over continuous rescans when systems can track meaningful changes safely.

## Risks Or TODOs

- Table.gd still owns BallPhysics; do not extract casually.
- Future Table Event logic could still bloat ScoreSystem or Table.gd if TableEventSystem ownership is not respected.
- Quartermaster, Reserve, and BallPlacement boundaries should stay separate as more purchasable/deployable effects are added.
- BallAudioSystem should stay event-driven and not become a physics-side concern.
- Broadside and Wayfinder Current should keep sequencing/routing in focused owners rather than duplicating logic in debug buttons.

## Questions

- Which future systems should reuse BallPlacementSystem.gd before adding new placement code?
- Which debug surfaces should graduate into permanent quality settings?
