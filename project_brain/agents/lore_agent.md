# Lore/Theme Agent

Responsibility: Tracks pirate/kraken tone, anomaly fantasy, callout language, and presentation consistency.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.

## Files Watched

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
- `scripts/ReserveDeploymentPresenter.gd` - Draw-only cursor icon and dotted tether presentation while deploying a reserved item.
- `scripts/ReserveSlotsUI.gd` - Icon-only upper table-frame Reserve slot UI with hover glow, click consumption, and deployment request wiring.
- `scripts/ReserveSystem.gd` - Owns three Reserve slot contents, selected/deploying state, deployment confirm/cancel bookkeeping, snapshots, and simple debug counters.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and evolving pocket-side score stack presentation.
- `scripts/SpawnSystem.gd` - Creates balls, performs safe spawn searches, owns regular anomaly odds, executes Table Event drop/launch helpers, and routes debug Anchor requests into curse-seed transformation.
- `scripts/TableEventMenu.gd` - Compact Request Kraken Intervention menu with three weighted offer cards, affordability, rarity display, hover, close, and purchase forwarding.

## Current Notes

- Tone is pirate arcade chaos with readable eldritch flair and a little mischievous weirdness.
- The title screen leans pirate arcade adventure and dangerous ocean night, not oppressive cosmic horror.
- Kraken Intervention should feel like bargaining with the table for dangerous aid and choosing intentional chaos.
- Broadside Attack should feel authored and nautical: warning beat, Powder Keg lanes, then Cannon Balls from a cursed gun deck.
- Wayfinder Current should feel like a cursed tide possessing nearby balls with transferable guided momentum.
- Pocket Streak X4+ should feel like a hungry pocket waking up without adding real suction yet.
- The Quartermaster/Reserve loop should feel like mounted tactical table hardware rather than a debug catalog.
- Doubloons belong to this game; Insight is reserved for the larger future Cuethulhu direction.

## Risks Or TODOs

- Kraken Intervention language should feel like bargaining with the table, not a generic upgrade menu.
- Pocket Streak HudFeed lines should stay compact while preserving kraken/pocket-hunger flavor.
- Quartermaster wording should stay pirate-tactical and not feel like a debug catalog.
- Keep Doubloons language here; do not import Insight terminology from future Cuethulhu work.

## Questions

- How weird should Kraken Intervention and HudFeed language get as chaos escalates?
- Should each anomaly get a unique drop callout pool?
