# Cleanup Agent

Responsibility: Tracks stale comments, unclear names, ownership drift, temporary debug leftovers, and documentation freshness.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

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
- `scripts/CannonBallSystem.gd` - Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.
- `scripts/CueProgressionSystem.gd` - Owns cue part definitions, unlock/equip validation, equipped loadout snapshots, effect definitions, and active cue modifier snapshots.
- `scripts/DebugOverlay.gd` - Formats debug menu, modular visible debug panels, requested-section performance snapshots, full F3 overlay, toggles, and physics debug text.
- `scripts/DebugPanel.gd` - Reusable draggable debug panel shell with pause-safe input consumption and lightweight text display.
- `scripts/EmbezzlerSystem.gd` - Embezzler anomaly system for copied Doubloon storage, secret target pocket, willingness, once-per-shot hide-or-run decisions, escape commitment, pocket roll, capture payout, escape cleanup, visuals, and debug counters.
- `scripts/GameplayMusicSystem.gd` - Low-volume looping gameplay music owner, separate from collision, UI, Pocket Streak, and anomaly SFX.
- `scripts/MainMenu.gd` - Title-screen shell, layered menu presentation, button input, and transition into the gameplay scene.
- `scripts/MainMenuCueLockerPanel.gd` - Main Menu Cue Locker panel UI presenter for Favor, equipped loadout, grouped cue parts, unlock/equip controls, and Back.
- `scripts/MainMenuPresentationOverlay.gd` - Draw-only layered title-screen atmosphere for moon glow, stars, ocean shimmer, and fog.
- `scripts/MainMenuRunHistoryPanel.gd` - Main Menu Run History panel UI presenter for list rows, empty state, Back, Clear History, and confirmation.
- `scripts/OathHUD.gd` - Compact active-Oath HUD indicator and tooltip presenter using OathSystem snapshots.
- `scripts/OathSystem.gd` - Owns data-driven Oath definitions, active Oath state, shot timers, completion/failure, Quartermaster lock state, cue modifier suppression, and debug helpers.
- `scripts/OptionsMenu.gd` - Reusable Options panel presenter with Audio sliders and context-aware Back behavior for main menu and pause menu.
- `scripts/PassageHUD.gd` - Compact live Passage/Kraken Wants HUD presenter with request tooltip and request reroll forwarding.
- `scripts/PassageSystem.gd` - Owns current-run Passage requirement, active Kraken Request, request rewards/completion, request rerolls, Passage pressure, and successful-run completion state.
- `scripts/PauseMenu.gd` - Pause menu shell, resume/quit wiring, legacy/hidden Quartermaster tab state, debug panel toggles, and temporary Event Test Button checkboxes.
- `scripts/PocketStreakSystem.gd` - Tracks same-pocket object-ball streaks per shot, same-pocket scoring subtotals, multiplier context, and double-award safety.
- `scripts/PocketSystem.gd` - Loads authored pocket geometry and detects pocket captures.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/ProgressionSystem.gd` - Persistent Kraken Favor owner for user://progression.json, successful-Passage reward calculation, safe Favor spending/adding, and cue progression data storage.
- `scripts/QuartermasterHUD.gd` - Live right-side Quartermaster side-rail shop presentation with item slots, refresh/Back Room buttons, costs, hover tooltips, affordability tinting, and cue-safe clicks.
- `scripts/QuartermasterOfferRefreshEffect.gd` - Presentation-only fresh-stock glow/shimmer effect for newly refreshed Quartermaster offers.
- `scripts/QuartermasterSystem.gd` - Owns Quartermaster inventory, prices, affordability, active rotating offers, paid event-driven refresh scaling/shot decay, access blockers, and purchase-to-Reserve state.
- `scripts/ReserveDeploymentPresenter.gd` - Draw-only cursor icon and dotted tether presentation while deploying a reserved item.
- `scripts/ReserveSlotsUI.gd` - Icon-only upper table-frame Reserve slot UI with hover glow, click consumption, and deployment request wiring.
- `scripts/ReserveSystem.gd` - Owns three Reserve slot contents, selected/deploying state, deployment confirm/cancel bookkeeping, snapshots, and simple debug counters.
- `scripts/RunHistorySystem.gd` - Persistent finalized run history owner for user://run_history.json, record normalization, duplicate-save prevention, clearing, and 25-record retention.
- `scripts/RunStatsSystem.gd` - Current-run ledger system for money split, sunk/active counts, run time, Passage/Oath/cue snapshots, economy counters, and shared Run Stats row metadata.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons, Treasure/Embezzler payout awards, and evolving pocket-side score stack presentation.
- `scripts/ShotEventSystem.gd` - Tracks causal per-shot foundational, skilled, heroic, legendary, and sink-moment scoring events for sunk balls.
- `scripts/SpawnSystem.gd` - Creates balls, performs safe spawn searches, owns regular anomaly odds, executes Table Event drop/launch helpers, and routes debug Anchor requests into curse-seed transformation.
- `scripts/Table.gd` - High-level table coordinator, shot lifecycle owner, early cue-reclaim gate, and current home of authoritative arcade ball physics.
- `scripts/TableDecorRandomizer.gd` - Presentation-only table decor variant randomizer for authored prop visuals.
- `scripts/TableEventMenu.gd` - Compact Request Kraken Intervention menu with weighted offer cards, Oath choice replacement panel, affordability, rarity display, hover, close, and purchase/replacement forwarding.
- `scripts/TableEventMeter.gd` - Horizontal bottom-center KRAKEN INTERVENTION meter with shot progress, percent text, pulse feedback, and ready icon.
- `scripts/TableEventSystem.gd` - Owns Kraken Intervention shot-earned threshold tracking, pending readiness, weighted offers, Oath-backed single-slot replacement, purchases, cargo discovery, debug triggers, and player-chosen Table Event execution routing.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.
- `scripts/TableObstacleSystem.gd` - Owns TableObstacle spawning/clearing, debug placement, authored collision polygon extraction/cache, broadphase, custom ball collision, debug draw, and counters.
- `scripts/TreasureBallSystem.gd` - Treasure Ball system for identity tracking, AimPreview corridor perception grace, committed hide targets, corridor/pocket-aware fleeing, soft scuttle movement, self-braking, reduced self-steer shove, and draw-only leg reporting; payout/discovery live in scoring/event systems.
- `scripts/WayfinderSystem.gd` - Handles Wayfinder activation, guided redirects, temporary Wayfinder Current carriers, transfer-on-hit guided momentum, and current-caused scoring snapshots.

## Current Notes

- Cleanup should preserve gameplay behavior and avoid opportunistic physics retuning.
- AGENTS.md, NOTES.md, STACK.md, and project_brain should be refreshed after major playable milestones.
- Generated docs should reflect Passage, Oaths, Kraken Intervention/Table Events, Quartermaster Refresh, Back Room Deals, Run Stats/History, Kraken Favor, Cue Locker/modifiers, debris, Broadside Attack, Wayfinder Current, Pocket Streak, HudFeed, live Quartermaster HUD, gameplay music, Anchor curse seeds, Treasure payout/discovery, Embezzler, score stacks, and expanded shot events.

## Risks Or TODOs

- Generated reports can drift if not regenerated after major changes.
- Scanner classifications are heuristic until files add `# index:*` metadata.

## Questions

- Which debug toggles should remain long-term?
- Which generated reports are becoming noisy or stale?
