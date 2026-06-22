# UI Agent

Responsibility: Tracks HUD, title screen, pause menu, modular debug panels, score popups, callouts, cue presentation, shop/reserve UI, and player-facing text.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

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
- `scripts/HudFeed.gd` - Bottom-left rolling captain's-log feed with fading stack, hover-scroll review, history, and multiline wrapped entries.
- `scripts/ItemIconDraw.gd` - Shared presentation-only compact item/ball preview drawing helpers for shop, Reserve, Back Room, and related HUD surfaces.
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
- `scripts/QuartermasterHUD.gd` - Live right-side Quartermaster side-rail shop presentation with item slots, refresh/Back Room buttons, costs, hover tooltips, affordability tinting, and cue-safe clicks.
- `scripts/QuartermasterOfferRefreshEffect.gd` - Presentation-only fresh-stock glow/shimmer effect for newly refreshed Quartermaster offers.
- `scripts/QuartermasterSystem.gd` - Owns Quartermaster inventory, prices, affordability, active rotating offers, paid event-driven refresh scaling/shot decay, access blockers, and purchase-to-Reserve state.
- `scripts/ReserveDeploymentPresenter.gd` - Draw-only cursor icon and dotted tether presentation while deploying a reserved item.
- `scripts/ReserveSlotsUI.gd` - Icon-only upper table-frame Reserve slot UI with hover glow, click consumption, and deployment request wiring.
- `scripts/ReserveSystem.gd` - Owns three Reserve slot contents, selected/deploying state, deployment confirm/cancel bookkeeping, snapshots, and simple debug counters.
- `scripts/RunHistorySystem.gd` - Persistent finalized run history owner for user://run_history.json, record normalization, duplicate-save prevention, clearing, and 25-record retention.
- `scripts/RunLedgerHUD.gd` - Compact lower-HUD BALLS/SUNK counter cluster presenter.
- `scripts/RunStatsHUD.gd` - Live top-left Run Stats button and compact ledger overlay presenter.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons, Treasure/Embezzler payout awards, and evolving pocket-side score stack presentation.
- `scripts/TableDecorRandomizer.gd` - Presentation-only table decor variant randomizer for authored prop visuals.
- `scripts/TableEventMenu.gd` - Compact Request Kraken Intervention menu with weighted offer cards, Oath choice replacement panel, affordability, rarity display, hover, close, and purchase/replacement forwarding.
- `scripts/TableEventMeter.gd` - Horizontal bottom-center KRAKEN INTERVENTION meter with shot progress, percent text, pulse feedback, and ready icon.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.
- `scripts/WayfinderCurrentPresenter.gd` - Draw-only Wayfinder Current readability presentation for initial teal/gold pulses and transfer flashes.

## Current Notes

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

## Risks Or TODOs

- Score stack lane/readability can regress when many high-tier events happen near the same pocket.
- Pocket Streak whirlpool/threat tells should remain readable without implying real suction until a gameplay pass adds it explicitly.
- Kraken Intervention menu and meter should stay cue-input safe and centered as UI art evolves.
- Modular debug panels can become noisy as more sections are added; keep hidden-panel gating intact.
- Main menu atmosphere should remain lightweight and layered correctly behind foreground silhouettes.
- Quartermaster and Reserve UI should not steal active cue drag/release input.

## Questions

- Which debug panels should become default-on for regular playtesting?
- Which popup effects should degrade first on low-end machines?
