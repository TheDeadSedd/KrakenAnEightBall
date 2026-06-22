# Agent Report

Generated as a lightweight multi-role review. These are not autonomous agents; they are project lenses for future sessions.

Do not misuse: this report is not source of truth. Check real source files and `AGENTS.md` before changing gameplay behavior.

Reference media: check `project_brain/debug_media/` for relevant clips, captures, or comparison screenshots when investigating feel, prediction, anomaly, UI, or performance issues. Treat those files as evidence only, never as gameplay/source code.

## Mechanics Agent

Relevant files:
- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/TableObstacle.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/Ball.gd` - Individual ball state, visuals, friction helpers, trails, draw-only anomaly presentation such as Cannon heat and Treasure legs, and anomaly identity flags.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BallDropMeter.gd` - Retired/legacy vertical HUD meter for the old automatic BallDrop loop; current progression UI is TableEventMeter.
- `scripts/BallDropSystem.gd` - Backstage legacy/gated automatic reward-drop helpers plus active cue/eight-ball sink penalty handling and debug plumbing.
- `scripts/BallPlacementSystem.gd` - Reusable item-agnostic placement mode with ghost preview, safe-position validation, and confirm/cancel flow for shop, Reserve, debug, and future placement effects.
- `scripts/CannonBallSystem.gd` - Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.

What it appears to do:
- Tracks core play loops, shot lifecycle, scoring hooks, shot-event history, ball identity, and moment-to-moment billiards feel.
- Current loop: better shots create Doubloons, completed Kraken Requests, Passage reduction, Kraken Intervention opportunities, player-chosen Table Events, more balls/anomalies, more interactions, and successful Passage rewards.
- Passage is the current run objective; Kraken Intervention is the active chosen-chaos economy; automatic BallDrop rewards are retired/gated.
- Early cue reclaim is shot-lifecycle coordination in Table.gd and should stay lightweight.
- Cue/eight-ball sinks are penalties now, not run-ending conditions.
- ShotEventSystem.gd now tracks foundational, skilled, heroic, legendary, and sink-moment events through causal shot history.
- PocketStreakSystem.gd tracks same-pocket streak bonuses separately from MULTI_SINK.
- RunStatsSystem.gd tracks current-run stats only; RunHistorySystem.gd persists finalized records.
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
- Which Kraken Intervention costs/weights/thresholds and Passage request rewards need playtest tuning?

## Systems Agent

Relevant files:
- `AGENTS.md` - Project documentation or checkpoint notes.
- `scenes/Main.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/MainMenu.tscn` - Layered title-screen scene with background art, animated overlay passes, foreground art, fog, and menu UI.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/TableObstacle.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/AudioSettings.gd` - Audio settings owner for user://settings.cfg, Master/Music/SFX bus lookup, volume conversion, and runtime bus volume application.
- `scripts/BackRoomDealSystem.gd` - Back Room Deal data/economy owner for unlock threshold, cost, special-ball deal definitions, availability checks, spending, and Reserve insertion.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BallDropSystem.gd` - Backstage legacy/gated automatic reward-drop helpers plus active cue/eight-ball sink penalty handling and debug plumbing.
- `scripts/BallPlacementSystem.gd` - Reusable item-agnostic placement mode with ghost preview, safe-position validation, and confirm/cancel flow for shop, Reserve, debug, and future placement effects.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.

What it appears to do:
- Tracks module boundaries, ownership rules, scene wiring, and coordinator responsibilities.
- Table.gd should coordinate systems without absorbing new feature logic.
- Scene-authored geometry remains the source of truth.
- MainMenu.gd owns title-screen presentation and top-level panel orchestration; Run History and Cue Locker presentation live in focused panel scripts.
- OptionsMenu.gd and AudioSettings.gd own reusable options/audio settings instead of the former menu shell behavior.
- PassageSystem.gd owns current-run Passage and Kraken Requests; EventMetadata.gd owns reusable request/event descriptions.
- OathSystem.gd owns Oath definitions, timers, penalties, Quartermaster lock state, and cue modifier suppression.
- ProgressionSystem.gd owns persistent Kraken Favor; CueProgressionSystem.gd owns cue definitions/equipment/effect snapshots.
- TableEventSystem.gd owns Kraken Intervention thresholds, pending readiness, weighted offers, purchases, and event routing.
- Broadside Attack is the first authored staged intervention milestone and should remain a readable pirate artillery scenario.
- QuartermasterSystem.gd owns rotating offers and paid refresh; QuartermasterHUD.gd owns live side-rail shop presentation; BackRoomDealSystem.gd owns Back Room economy; ReserveSystem.gd owns slot data; BallPlacementSystem.gd owns item-agnostic placement.
- BallAudioSystem.gd owns pooled event-driven collision SFX instead of burying audio in physics.
- GameplayMusicSystem.gd owns low-volume looping gameplay music separate from SFX; music should support atmosphere without covering collision/event readability.
- TableImpactShakeSystem.gd owns presentation-only fake-3D table shake so gameplay geometry and HUD stay stable.
- TableObstacleSystem.gd owns debris spawning/debug and custom authored-polygon collision; it should not become general Table physics.
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
- `scripts/TreasureBallSystem.gd` - Treasure Ball system for identity tracking, AimPreview corridor perception grace, committed hide targets, corridor/pocket-aware fleeing, soft scuttle movement, self-braking, reduced self-steer shove, and draw-only leg reporting; payout/discovery live in scoring/event systems.

What it appears to do:
- Tracks Wayfinder, Powder Keg, Anchor curse seeds, Cannon Ball, Treasure Ball, Embezzler, and future anomaly behavior boundaries.
- Wayfinder, Powder Keg, Anchor, Cannon, Treasure, and Embezzler all have focused system boundaries.
- Wayfinder Current is the cursed-tide extension of Wayfinder behavior: temporary possession, transferable guided momentum, transfer-on-hit propagation, and current-caused scoring support.
- Anchor's old continuous field identity is retired; current Anchor behavior is curse-seed selection, chains, cue-control-gated tightening, warning, spread, and collapse.
- Cannon Ball has debug/Table Event drop paths, collision tuning, Powder Keg launch, Broadside launch use, heavy-impact shake, and high-speed heat presence.
- Treasure Ball is a perception-grace/hiding/scuttle experiment that can appear through rare cargo/contraband discovery and awards a large Doubloon payout when sunk.
- Treasure should feel like a cautious sneaky thief, not a shortest-path optimizer, and remains separate from the Embezzler.
- Embezzler is capped and debug-spawnable; it copies Doubloon value, tracks a secret pocket, uses once-per-shot hide-or-run decisions, and resolves capture/escape.

Known risks or TODOs:
- Anchor curse-seed behavior is tuned by feel and should be adjusted incrementally without restoring continuous field pull.
- Future anomalies should avoid hidden coupling through Table.gd.
- Treasure payout and cargo/contraband discovery are implemented; keep Treasure distinct from Embezzler cashout/escape behavior.
- Embezzler is capped and can appear through debug/contraband paths; broader spawn odds and special interactions are still future work.
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
- `scenes/TableObstacle.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/BackRoomDealPanel.gd` - Compact Back Room Deal panel presenter for title/flavor, deal rows, unavailable reasons, close/cancel, and selected deal emission.
- `scripts/BallDropMeter.gd` - Retired/legacy vertical HUD meter for the old automatic BallDrop loop; current progression UI is TableEventMeter.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.
- `scripts/CueProgressionSystem.gd` - Owns cue part definitions, unlock/equip validation, equipped loadout snapshots, effect definitions, and active cue modifier snapshots.
- `scripts/DebugOverlay.gd` - Formats debug menu, modular visible debug panels, requested-section performance snapshots, full F3 overlay, toggles, and physics debug text.
- `scripts/DebugPanel.gd` - Reusable draggable debug panel shell with pause-safe input consumption and lightweight text display.

What it appears to do:
- Tracks HUD, title screen, pause menu, modular debug panels, score popups, callouts, cue presentation, shop/reserve UI, and player-facing text.
- MainMenu.tscn uses layered artwork with lightweight moon glow, star, shimmer, and fog overlays.
- MainMenu.gd now orchestrates focused Options, Run History, and Cue Locker panels rather than owning all row/card logic.
- OptionsMenu.gd is real UI with Master/Music/SFX sliders and pause/main-menu return contexts.
- PassageHUD.gd owns Passage/Kraken Wants presentation and request tooltip/reroll UI.
- OathHUD.gd owns compact active-Oath indicator/tooltip presentation.
- RunStatsHUD.gd owns the live ledger overlay; RunLedgerHUD.gd owns the BALLS/SUNK HUD cluster.
- TableEventMeter.gd owns the horizontal bottom-center Kraken Intervention meter and ready icon.
- TableEventMenu.gd owns the compact Request Kraken Intervention menu, offer cards, and Oath choice panel for single-offer replacement.
- HudFeed.gd owns the bottom-left rolling captain's-log feed with hover review and multiline wrapping.
- QuartermasterHUD.gd owns the live right-side side-rail shop; BackRoomDealPanel.gd owns Back Room option presentation; PauseMenu.gd no longer owns the active shop purchasing flow.
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
- `scenes/TableObstacle.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AimPreview.gd` - Draws polished aim lines, swept cue/target prediction, pocket stopping, endpoint markers, Treasure/Embezzler perception snapshots, and AimPreview broad-phase counters.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/AudioSettings.gd` - Audio settings owner for user://settings.cfg, Master/Music/SFX bus lookup, volume conversion, and runtime bus volume application.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/DebugOverlay.gd` - Formats debug menu, modular visible debug panels, requested-section performance snapshots, full F3 overlay, toggles, and physics debug text.
- `scripts/DebugPanel.gd` - Reusable draggable debug panel shell with pause-safe input consumption and lightweight text display.
- `scripts/EmbezzlerSystem.gd` - Embezzler anomaly system for copied Doubloon storage, secret target pocket, willingness, once-per-shot hide-or-run decisions, escape commitment, pocket roll, capture payout, escape cleanup, visuals, and debug counters.
- `scripts/HudFeed.gd` - Bottom-left rolling captain's-log feed with fading stack, hover-scroll review, history, and multiline wrapped entries.
- `scripts/MainMenu.gd` - Title-screen shell, layered menu presentation, button input, and transition into the gameplay scene.

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
- TableObstacleSystem.gd should keep authored-polygon collision cheap through moving-ball filtering, cached transforms, and broadphase rejection.
- Hover-only HUD/UI should respect cue-drag suppression so active aiming owns mouse hover behavior.
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
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Main.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/MainMenu.tscn` - Layered title-screen scene with background art, animated overlay passes, foreground art, fog, and menu UI.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.
- `scripts/CueProgressionSystem.gd` - Owns cue part definitions, unlock/equip validation, equipped loadout snapshots, effect definitions, and active cue modifier snapshots.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
- `scripts/MainMenu.gd` - Title-screen shell, layered menu presentation, button input, and transition into the gameplay scene.
- `scripts/MainMenuCueLockerPanel.gd` - Main Menu Cue Locker panel UI presenter for Favor, equipped loadout, grouped cue parts, unlock/equip controls, and Back.
- `scripts/MainMenuPresentationOverlay.gd` - Draw-only layered title-screen atmosphere for moon glow, stars, ocean shimmer, and fog.

What it appears to do:
- Tracks pirate/kraken tone, anomaly fantasy, callout language, and presentation consistency.
- Tone is pirate arcade chaos with readable eldritch flair and a little mischievous weirdness.
- The title screen leans pirate arcade adventure and dangerous ocean night, not oppressive cosmic horror.
- Passage fantasy: the Kraken intends to take the ship, and the player bargains for safe passage with wealth and skill.
- Kraken Intervention should feel like bargaining with the table for dangerous aid and choosing intentional chaos.
- Oaths should feel like risky promises sworn to the Kraken, not ordinary UI reroll buttons.
- Kraken Favor is the persistent proof that the Kraken remembers successful voyages.
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
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/MainMenu.tscn` - Layered title-screen scene with background art, animated overlay passes, foreground art, fog, and menu UI.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/TableObstacle.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/AudioSettings.gd` - Audio settings owner for user://settings.cfg, Master/Music/SFX bus lookup, volume conversion, and runtime bus volume application.
- `scripts/BackRoomDealSystem.gd` - Back Room Deal data/economy owner for unlock threshold, cost, special-ball deal definitions, availability checks, spending, and Reserve insertion.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BallDropSystem.gd` - Backstage legacy/gated automatic reward-drop helpers plus active cue/eight-ball sink penalty handling and debug plumbing.
- `scripts/BallPlacementSystem.gd` - Reusable item-agnostic placement mode with ghost preview, safe-position validation, and confirm/cancel flow for shop, Reserve, debug, and future placement effects.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.

What it appears to do:
- Tracks stale comments, unclear names, ownership drift, temporary debug leftovers, and documentation freshness.
- Cleanup should preserve gameplay behavior and avoid opportunistic physics retuning.
- AGENTS.md, NOTES.md, STACK.md, and project_brain should be refreshed after major playable milestones.
- Generated docs should reflect Passage, Oaths, Kraken Intervention/Table Events, Quartermaster Refresh, Back Room Deals, Run Stats/History, Kraken Favor, Cue Locker/modifiers, debris, Broadside Attack, Wayfinder Current, Pocket Streak, HudFeed, live Quartermaster HUD, gameplay music, Anchor curse seeds, Treasure payout/discovery, Embezzler, score stacks, and expanded shot events.

Known risks or TODOs:
- Generated reports can drift if not regenerated after major changes.
- Scanner classifications are heuristic until files add `# index:*` metadata.

Questions for the developer:
- Which debug toggles should remain long-term?
- Which generated reports are becoming noisy or stale?
