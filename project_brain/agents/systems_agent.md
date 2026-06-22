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
- `scenes/TableObstacle.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters.
- `scripts/AudioSettings.gd` - Audio settings owner for user://settings.cfg, Master/Music/SFX bus lookup, volume conversion, and runtime bus volume application.
- `scripts/BackRoomDealSystem.gd` - Back Room Deal data/economy owner for unlock threshold, cost, special-ball deal definitions, availability checks, spending, and Reserve insertion.
- `scripts/BallAudioSystem.gd` - Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering.
- `scripts/BallDropSystem.gd` - Backstage legacy/gated automatic reward-drop helpers plus active cue/eight-ball sink penalty handling and debug plumbing.
- `scripts/BallPlacementSystem.gd` - Reusable item-agnostic placement mode with ghost preview, safe-position validation, and confirm/cancel flow for shop, Reserve, debug, and future placement effects.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/CannonBallSystem.gd` - Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/CueProgressionSystem.gd` - Owns cue part definitions, unlock/equip validation, equipped loadout snapshots, effect definitions, and active cue modifier snapshots.
- `scripts/EmbezzlerSystem.gd` - Embezzler anomaly system for copied Doubloon storage, secret target pocket, willingness, once-per-shot hide-or-run decisions, escape commitment, pocket roll, capture payout, escape cleanup, visuals, and debug counters.
- `scripts/EventMetadata.gd` - Central event/request metadata registry for labels and descriptions used by Passage tooltips and future reusable references.
- `scripts/GameplayMusicSystem.gd` - Low-volume looping gameplay music owner, separate from collision, UI, Pocket Streak, and anomaly SFX.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
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
- `scripts/PocketStreakPresenter.gd` - Queued Pocket Streak multiplier presentation, fixed-pool audio/reverb, X4+ whirlpool visuals, and localized presentation-only threat tells.
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
- `scripts/WayfinderCurrentPresenter.gd` - Draw-only Wayfinder Current readability presentation for initial teal/gold pulses and transfer flashes.
- `scripts/WayfinderSystem.gd` - Handles Wayfinder activation, guided redirects, temporary Wayfinder Current carriers, transfer-on-hit guided momentum, and current-caused scoring snapshots.

## Current Notes

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

## Risks Or TODOs

- Table.gd still owns BallPhysics; do not extract casually.
- Future Table Event logic could still bloat ScoreSystem or Table.gd if TableEventSystem ownership is not respected.
- Quartermaster, Reserve, and BallPlacement boundaries should stay separate as more purchasable/deployable effects are added.
- BallAudioSystem should stay event-driven and not become a physics-side concern.
- Broadside and Wayfinder Current should keep sequencing/routing in focused owners rather than duplicating logic in debug buttons.

## Questions

- Which future systems should reuse BallPlacementSystem.gd before adding new placement code?
- Which debug surfaces should graduate into permanent quality settings?
