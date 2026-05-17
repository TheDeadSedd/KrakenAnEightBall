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
- `scripts/BallDropMeter.gd` - Retired/legacy vertical HUD meter for the old automatic BallDrop loop; current progression UI is TableEventMeter.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.
- `scripts/DebugOverlay.gd` - Formats debug menu, modular visible debug panels, requested-section performance snapshots, full F3 overlay, toggles, and physics debug text.
- `scripts/DebugPanel.gd` - Reusable draggable debug panel shell with pause-safe input consumption and lightweight text display.
- `scripts/HudFeed.gd` - Bottom-left rolling captain's-log feed with fading stack, hover-scroll review, history, and multiline wrapped entries.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
- `scripts/MainMenu.gd` - Title-screen shell, layered menu presentation, button input, and transition into the gameplay scene.
- `scripts/MainMenuPresentationOverlay.gd` - Draw-only layered title-screen atmosphere for moon glow, stars, ocean shimmer, and fog.
- `scripts/PauseMenu.gd` - Pause menu shell, resume/quit wiring, legacy/hidden Quartermaster tab state, debug panel toggles, and temporary Event Test Button checkboxes.
- `scripts/PocketStreakPresenter.gd` - Queued Pocket Streak multiplier presentation, fixed-pool audio/reverb, X4+ whirlpool visuals, and localized presentation-only threat tells.
- `scripts/PocketStreakSystem.gd` - Tracks same-pocket object-ball streaks per shot, same-pocket scoring subtotals, multiplier context, and double-award safety.
- `scripts/QuartermasterHUD.gd` - Live right-side Quartermaster side-rail shop presentation with item slots, costs, hover tooltips, affordability tinting, and cue-safe clicks.
- `scripts/QuartermasterOfferRefreshEffect.gd` - Presentation-only fresh-stock glow/shimmer effect for newly refreshed Quartermaster offers.
- `scripts/QuartermasterSystem.gd` - Owns Quartermaster inventory, prices, affordability, active rotating offers, event-driven offer refresh, and purchase-to-Reserve state.
- `scripts/ReserveDeploymentPresenter.gd` - Draw-only cursor icon and dotted tether presentation while deploying a reserved item.
- `scripts/ReserveSlotsUI.gd` - Icon-only upper table-frame Reserve slot UI with hover glow, click consumption, and deployment request wiring.
- `scripts/ReserveSystem.gd` - Owns three Reserve slot contents, selected/deploying state, deployment confirm/cancel bookkeeping, snapshots, and simple debug counters.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and evolving pocket-side score stack presentation.
- `scripts/TableEventMenu.gd` - Compact Request Kraken Intervention menu with three weighted offer cards, affordability, rarity display, hover, close, and purchase forwarding.
- `scripts/TableEventMeter.gd` - Horizontal bottom-center KRAKEN INTERVENTION meter with shot progress, percent text, pulse feedback, and ready icon.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.
- `scripts/WayfinderCurrentPresenter.gd` - Draw-only Wayfinder Current readability presentation for initial teal/gold pulses and transfer flashes.

## Current Notes

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
