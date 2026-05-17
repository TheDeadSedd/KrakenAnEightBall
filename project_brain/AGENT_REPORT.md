# Agent Report

Generated as a lightweight multi-role review. These are not autonomous agents; they are project lenses for future sessions.

Do not misuse: this report is not source of truth. Check real source files and `AGENTS.md` before changing gameplay behavior.

Reference media: check `project_brain/debug_media/` for relevant clips, captures, or comparison screenshots when investigating feel, prediction, anomaly, UI, or performance issues. Treat those files as evidence only, never as gameplay/source code.

## Mechanics Agent

Relevant files:
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

What it appears to do:
- Tracks core play loops, shot lifecycle, scoring hooks, shot-event history, ball identity, and moment-to-moment billiards feel.
- Current loop: better shots create Doubloons, Kraken Intervention opportunities, player-chosen Table Events, more balls/anomalies, more interactions, and an escalating table state.
- Kraken Intervention is the active progression spine; automatic BallDrop rewards are retired/gated.
- Early cue reclaim is shot-lifecycle coordination in Table.gd and should stay lightweight.
- Cue/eight-ball sinks are penalties now, not run-ending conditions.
- ShotEventSystem.gd now tracks foundational, skilled, heroic, and legendary events through causal shot history.
- PocketStreakSystem.gd tracks same-pocket streak bonuses separately from MULTI_SINK.
- Preserve cue feel, shot feel, pocket feel, and scoring values during cleanup.
- Automatic score-triggered BallDrop rewards are retired/gated; BallDropSystem is mostly legacy/debug support plus cue/eight-ball penalty handling.

Known risks or TODOs:
- Kraken Intervention threshold/cost/weight tuning is first-pass and needs longer playtesting.
- Cue/eight-ball sink penalties should not accidentally feed Kraken Intervention or revive legacy BallDrop progress.
- Early cue reclaim must stay safe: cue-ball motion or reset/drop states should still block release.
- Expanded shot-event thresholds may need conservative tuning after longer chaos-table sessions.
- Pocket Streak bonuses should remain double-award safe when multiple same-pocket sinks resolve rapidly.

Questions for the developer:
- Which new shot-event thresholds need tuning after longer playtests?
- Which Kraken Intervention costs/weights/thresholds need playtest tuning?

## Systems Agent

Relevant files:
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

What it appears to do:
- Tracks module boundaries, ownership rules, scene wiring, and coordinator responsibilities.
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

Known risks or TODOs:
- Table.gd still owns BallPhysics; do not extract casually.
- Future Table Event logic could still bloat ScoreSystem or Table.gd if TableEventSystem ownership is not respected.
- Quartermaster, Reserve, and BallPlacement boundaries should stay separate as more purchasable/deployable effects are added.
- BallAudioSystem should stay event-driven and not become a physics-side concern.
- Broadside and Wayfinder Current should keep sequencing/routing in focused owners rather than duplicating logic in debug buttons.

Questions for the developer:
- Which future systems should reuse BallPlacementSystem.gd before adding new placement code?
- Which debug surfaces should graduate into permanent quality settings?

## Anomaly Ball Agent

Relevant files:
- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/Ball.gd` - Individual ball state, visuals, friction helpers, trails, draw-only anomaly presentation such as Cannon heat and Treasure legs, and anomaly identity flags.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BallDropMeter.gd` - Retired/legacy vertical HUD meter for the old automatic BallDrop loop; current progression UI is TableEventMeter.
- `scripts/BallDropSystem.gd` - Backstage legacy/gated automatic reward-drop helpers plus active cue/eight-ball sink penalty handling and debug plumbing.
- `scripts/BallPlacementSystem.gd` - Reusable item-agnostic placement mode with ghost preview, safe-position validation, and confirm/cancel flow for shop, Reserve, debug, and future placement effects.
- `scripts/CannonBallSystem.gd` - Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/EmbezzlerSystem.gd` - Embezzler anomaly system for copied Doubloon storage, secret target pocket, willingness, once-per-shot hide-or-run decisions, escape commitment, pocket roll, capture payout, escape cleanup, visuals, and debug counters.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/TreasureBallSystem.gd` - Treasure Ball system for debug-spawn identity tracking, AimPreview corridor perception grace, committed hide targets, corridor/pocket-aware fleeing, soft scuttle movement, self-braking, reduced self-steer shove, and draw-only leg reporting.

What it appears to do:
- Tracks Wayfinder, Powder Keg, Anchor curse seeds, Cannon Ball, Treasure Ball, Embezzler, and future anomaly behavior boundaries.
- Wayfinder, Powder Keg, Anchor, Cannon, Treasure, and Embezzler all have focused system boundaries.
- Wayfinder Current is the cursed-tide extension of Wayfinder behavior: temporary possession, transferable guided momentum, transfer-on-hit propagation, and current-caused scoring support.
- Anchor's old continuous field identity is retired; current Anchor behavior is curse-seed selection, chains, cue-control-gated tightening, warning, spread, and collapse.
- Cannon Ball has debug/Table Event drop paths, collision tuning, Powder Keg launch, Broadside launch use, heavy-impact shake, and high-speed heat presence.
- Treasure Ball is a debug-spawn perception-grace/hiding/scuttle experiment; it reacts to being watched, not just exact first-hit targeting.
- Treasure should feel like a cautious sneaky thief, not a shortest-path optimizer, and remains separate from the Embezzler.
- Embezzler is capped and debug-spawnable; it copies Doubloon value, tracks a secret pocket, uses once-per-shot hide-or-run decisions, and resolves capture/escape.

Known risks or TODOs:
- Anchor curse-seed behavior is tuned by feel and should be adjusted incrementally without restoring continuous field pull.
- Future anomalies should avoid hidden coupling through Table.gd.
- Treasure rewards and regular spawn odds are not implemented yet.
- Embezzler spawn odds and anomaly special interactions are not implemented yet.
- Wayfinder Current affected-ball count is intentionally uncapped for now; tune radius/readability before adding hard caps.

Questions for the developer:
- Which future anomalies should interact with Anchor curse chains or Embezzler escape pressure?
- Should anomaly-touch scoring expand beyond current event rewards?

## UI Agent

Relevant files:
- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Main.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/MainMenu.tscn` - Layered title-screen scene with background art, animated overlay passes, foreground art, fog, and menu UI.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/BallDropMeter.gd` - Retired/legacy vertical HUD meter for the old automatic BallDrop loop; current progression UI is TableEventMeter.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.
- `scripts/DebugOverlay.gd` - Formats debug menu, modular visible debug panels, requested-section performance snapshots, full F3 overlay, toggles, and physics debug text.
- `scripts/DebugPanel.gd` - Reusable draggable debug panel shell with pause-safe input consumption and lightweight text display.
- `scripts/HudFeed.gd` - Bottom-left rolling captain's-log feed with fading stack, hover-scroll review, history, and multiline wrapped entries.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
- `scripts/MainMenu.gd` - Title-screen shell, layered menu presentation, button input, and transition into the gameplay scene.

What it appears to do:
- Tracks HUD, title screen, pause menu, modular debug panels, score popups, callouts, cue presentation, shop/reserve UI, and player-facing text.
- MainMenu.tscn uses layered artwork with lightweight moon glow, star, shimmer, and fog overlays.
- TableEventMeter.gd owns the horizontal bottom-center Kraken Intervention meter and ready icon.
- TableEventMenu.gd owns the compact Request Kraken Intervention menu and offer cards.
- HudFeed.gd owns the bottom-left rolling captain's-log feed with hover review and multiline wrapping.
- QuartermasterHUD.gd owns the live right-side side-rail shop; PauseMenu.gd no longer owns the active shop purchasing flow.
- PauseMenu.gd owns menu shell behavior, modular debug-panel toggles, and temporary Event Test Button checkboxes while gameplay is paused.
- DebugPanel.gd owns draggable pause-safe panel shells; DebugOverlay.gd formats visible panel content and the full F3 overlay.
- ReserveSlotsUI.gd owns icon-only table-frame slots; ReserveDeploymentPresenter.gd owns cursor icon/tether presentation.
- Score presentation now uses evolving pocket-side score stacks with Foundational/Skilled/Heroic/Legendary tier identity, count-up totals, and lane/yield behavior.
- PocketStreakPresenter.gd queues X2/X3/X4+ presentation, audio, and localized whirlpool/threat tells. These are deliberately psychological tells, not unfinished suction gameplay.
- Debug labels and test buttons should stay clearly marked and not leak temporary test wording into player-facing strings.
- TableImpactShakeSystem.gd owns fake-3D table impact shake and draw-only ball shimmy presentation.

Known risks or TODOs:
- Score stack lane/readability can regress when many high-tier events happen near the same pocket.
- Pocket Streak whirlpool/threat tells should remain readable without implying real suction until a gameplay pass adds it explicitly.
- Kraken Intervention menu and meter should stay cue-input safe and centered as UI art evolves.
- Modular debug panels can become noisy as more sections are added; keep hidden-panel gating intact.
- Main menu atmosphere should remain lightweight and layered correctly behind foreground silhouettes.
- Quartermaster and Reserve UI should not steal active cue drag/release input.

Questions for the developer:
- Which debug panels should become default-on for regular playtesting?
- Which popup effects should degrade first on low-end machines?

## Performance Agent

Relevant files:
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

What it appears to do:
- Tracks visual cost, broad-phase health, trail redraws, particle load, and stress-test readiness.
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

Known risks or TODOs:
- Visual effects should degrade before gameplay chaos is limited.
- Pooling/reuse is not broadly implemented for temporary visuals yet.
- AimPreview rebuild coalescing should preserve reliable graze behavior and avoid tolerance-based lies.
- Hidden debug UI should remain logically cheap, not merely invisible.
- Collision audio cooldowns should prevent spam without making meaningful impacts feel late.
- Anchor should stay event/state-driven; avoid reintroducing continuous force scans.
- Embezzler should stay capped and avoid same-shot escape-roll spam.
- Score stacks should coalesce celebration before any visual suppression is considered.
- Kraken Intervention and HudFeed should remain event/message-driven rather than becoming per-frame scanners.

Questions for the developer:
- What visual-quality tiers should exist for trails, particles, aura effects, and score labels?
- When should pooling replace ad hoc temporary visual nodes?

## Lore/Theme Agent

Relevant files:
- `AGENTS.md` - Project documentation or checkpoint notes.
- `NOTES.md` - Project documentation or checkpoint notes.
- `STACK.md` - Project documentation or checkpoint notes.
- `scenes/Main.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/MainMenu.tscn` - Layered title-screen scene with background art, animated overlay passes, foreground art, fog, and menu UI.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
- `scripts/MainMenu.gd` - Title-screen shell, layered menu presentation, button input, and transition into the gameplay scene.
- `scripts/MainMenuPresentationOverlay.gd` - Draw-only layered title-screen atmosphere for moon glow, stars, ocean shimmer, and fog.
- `scripts/PauseMenu.gd` - Pause menu shell, resume/quit wiring, legacy/hidden Quartermaster tab state, debug panel toggles, and temporary Event Test Button checkboxes.
- `scripts/QuartermasterHUD.gd` - Live right-side Quartermaster side-rail shop presentation with item slots, costs, hover tooltips, affordability tinting, and cue-safe clicks.
- `scripts/QuartermasterOfferRefreshEffect.gd` - Presentation-only fresh-stock glow/shimmer effect for newly refreshed Quartermaster offers.
- `scripts/QuartermasterSystem.gd` - Owns Quartermaster inventory, prices, affordability, active rotating offers, event-driven offer refresh, and purchase-to-Reserve state.

What it appears to do:
- Tracks pirate/kraken tone, anomaly fantasy, callout language, and presentation consistency.
- Tone is pirate arcade chaos with readable eldritch flair and a little mischievous weirdness.
- The title screen leans pirate arcade adventure and dangerous ocean night, not oppressive cosmic horror.
- Kraken Intervention should feel like bargaining with the table for dangerous aid and choosing intentional chaos.
- Broadside Attack should feel authored and nautical: warning beat, Powder Keg lanes, then Cannon Balls from a cursed gun deck.
- Wayfinder Current should feel like a cursed tide possessing nearby balls with transferable guided momentum.
- Pocket Streak X4+ should feel like a hungry pocket waking up without adding real suction yet.
- The Quartermaster/Reserve loop should feel like mounted tactical table hardware rather than a debug catalog.
- Doubloons belong to this game; Insight is reserved for the larger future Cuethulhu direction.

Known risks or TODOs:
- Kraken Intervention language should feel like bargaining with the table, not a generic upgrade menu.
- Pocket Streak HudFeed lines should stay compact while preserving kraken/pocket-hunger flavor.
- Quartermaster wording should stay pirate-tactical and not feel like a debug catalog.
- Keep Doubloons language here; do not import Insight terminology from future Cuethulhu work.

Questions for the developer:
- How weird should Kraken Intervention and HudFeed language get as chaos escalates?
- Should each anomaly get a unique drop callout pool?

## Cleanup Agent

Relevant files:
- `AGENTS.md` - Project documentation or checkpoint notes.
- `scenes/MainMenu.tscn` - Layered title-screen scene with background art, animated overlay passes, foreground art, fog, and menu UI.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BallDropSystem.gd` - Backstage legacy/gated automatic reward-drop helpers plus active cue/eight-ball sink penalty handling and debug plumbing.
- `scripts/BallPlacementSystem.gd` - Reusable item-agnostic placement mode with ghost preview, safe-position validation, and confirm/cancel flow for shop, Reserve, debug, and future placement effects.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/CannonBallSystem.gd` - Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/DebugOverlay.gd` - Formats debug menu, modular visible debug panels, requested-section performance snapshots, full F3 overlay, toggles, and physics debug text.
- `scripts/DebugPanel.gd` - Reusable draggable debug panel shell with pause-safe input consumption and lightweight text display.
- `scripts/EmbezzlerSystem.gd` - Embezzler anomaly system for copied Doubloon storage, secret target pocket, willingness, once-per-shot hide-or-run decisions, escape commitment, pocket roll, capture payout, escape cleanup, visuals, and debug counters.

What it appears to do:
- Tracks stale comments, unclear names, ownership drift, temporary debug leftovers, and documentation freshness.
- Cleanup should preserve gameplay behavior and avoid opportunistic physics retuning.
- AGENTS.md, NOTES.md, STACK.md, and project_brain should be refreshed after major playable milestones.
- Generated docs should reflect Kraken Intervention/Table Events, Broadside Attack, Wayfinder Current, Pocket Streak, HudFeed, live Quartermaster HUD, gameplay music, Anchor curse seeds, Embezzler, score stacks, and expanded shot events.

Known risks or TODOs:
- Generated reports can drift if not regenerated after major changes.
- Scanner classifications are heuristic until files add `# index:*` metadata.

Questions for the developer:
- Which debug toggles should remain long-term?
- Which generated reports are becoming noisy or stale?
