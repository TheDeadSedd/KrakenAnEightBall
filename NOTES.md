# Project Notes

Kraken An Eight Ball is currently a pirate/eldritch arcade-chaos billiards prototype. It has grown into a systemic playtest bed for escalating table states, readable anomaly balls, and trick-shot celebration.

## Current Gameplay Loop

- Start from a lightweight atmospheric title screen, then load the playable table scene.
- Shoot with drag-and-release arcade billiards controls.
- Sink object balls for Doubloons and trick-shot event bonuses.
- Score feeds `BallDropSystem.gd` progress.
- Earned drops add more balls to the table.
- More balls create more chains, anomalies, risk, and score opportunities.
- Early cue reclaim lets the player aim again once the cue ball is safely stopped, even while some table motion continues.
- Spend Doubloons at the Quartermaster when paused, buying rotating tactical offers into Reserve slots.
- Deploy reserved balls later through the reusable placement flow.
- The player survives and exploits the escalating table state instead of simply clearing a rack.

Cue ball and eight ball sinks no longer end the game. Each currently costs 25 Doubloons; cue-ball sinks still remove one eligible object ball, while eight-ball sinks now try to transform an eligible object ball into an Anchor curse seed.

## Current Special Balls

- Wayfinder Ball: cue-contact anomaly that can guide eligible balls toward pockets.
- Powder Keg: explodes on cue-ball or Cannon Ball contact, pushes nearby balls, removes itself, and requests fake-3D table impact shake.
- Anchor Ball: now uses the curse-seed model. Eight-ball sink transforms an eligible existing object ball into a stationary curse seed, chains 1-3 nearby balls, tightens leashes only during cue-control/turn windows, warns before spread, and can collapse through cue hit, Powder Keg, Cannon Ball, or pocketing a chained ball. The old continuous pull field is retired/disabled.
- Cannon Ball: heavy iron debug-spawn anomaly built around delayed-chaos "future problem" identity: hard to start, hard to stop, dangerous once moving, and visually marked by red/orange heat presence.
- Treasure Ball: debug-spawn experiment that notices the aim-line corridor, chooses cover, avoids being watched too closely, scuttles away while perceived, and uses draw-only legs.
- Embezzler: debug-spawn/capped living greed anomaly that copies a share of Doubloons while alive, hides or runs once per shot based on stored value/willingness, wants one secret pocket, can escape after a pocket roll, and pays out stored value if caught first.

Treasure and Embezzler are separate identities. Treasure is the cautious aim-line/hiding experiment; Embezzler is the greed, panic, secret-pocket, and cashout/escape mechanic.

## Current Shop And Reserve Loop

- `QuartermasterSystem.gd` owns item IDs, prices, affordability, three active rotating offers, and event-driven offer refresh.
- Current purchasable items are Loose Object Ball, Wayfinder Ball, and Powder Keg.
- Purchases spend Doubloons only on success and fill the first open `ReserveSystem.gd` slot.
- Reserve slots are visible as three icon-only mounts on the upper-right table frame.
- Clicking a filled slot starts deployment through `BallPlacementSystem.gd`; valid confirm places the ball and clears the slot, while cancel keeps the item.
- `ReserveDeploymentPresenter.gd` adds the cursor icon and dotted tether so deployment feels like pulling a ball from storage without changing placement rules.

## Current Tactical Economy Loop

Quartermaster rotating offers -> buy into Reserve -> deploy tactically later -> create better scoring opportunities -> earn more Doubloons -> survive escalating chaos.

This loop is now a major identity pillar: Doubloons are not just score, they are tactical fuel for shaping the next wave of table chaos.

## Current Shot Event Tiers

- Foundational: `BANK`, `CHAIN`, `MULTI_CHAIN`, `ANOMALY_TOUCH`, `MULTI_SINK`.
- Skilled: `KRAKEN_KICK`, `DOUBLE_BANK`, `THIN_CUT`, `CLUSTER_BREAK`.
- Heroic: `CROSS_CORNER_BANK`, `FULL_TABLE_KICK`, `POWDER_ROUTE`, `KRAKEN_CURRENT`.
- Legendary: `TRIPLE_BANK`, `CANNON_CHAIN`, `TREASURE_SNARE`.

`ShotEventSystem.gd` records causal history; `ScoreSystem.gd` converts that history into Doubloons and pocket-side popups.

## Current Score Presentation

- Score celebration now uses evolving pocket-side score stacks rather than endless independent labels.
- Foundational, Skilled, Heroic, and Legendary rewards each have tier-specific stack presentation.
- Stack totals count upward (`+5 -> +10 -> +15`) while compact subtitles summarize the latest/combined event names.
- Skilled stacks glow blue, Heroic stacks glow purple, and Legendary stacks glow gold/yellow.
- Lane management separates tiers around pockets, lets older/lower-priority stacks yield or fade early, and keeps Legendary moments prominent.
- The old popup path is reserved for future/unknown rewards or any intentionally non-stack event presentation still left outside the tier stack system.

## Shot Event Philosophy

Shot events should reward recovery, geometry, improvisation, chaos control, anomaly-assisted creativity, and legendary moments. Kraken An Eight Ball is not chasing strict billiards simulation realism; it is building readable arcade billiards mythology where clever messes, desperate saves, and impossible-looking routes feel worth celebrating.

## Presentation Notes

- `MainMenu.tscn` / `MainMenu.gd` owns the title screen shell.
- The main menu uses `assets/ui/mainmenu_bg.png`, animated overlay passes, `assets/ui/mainmenu_fg.png`, fog, then menu UI.
- Title overlays include moon glow, star twinkles, ocean shimmer, and broad drifting mist; they are lightweight and presentation-only.
- Fake-3D presentation systems add impact and table feel without moving authoritative gameplay positions.
- Powder Keg explosions and Cannon heavy impacts can shake table art and visually shimmy balls while HUD/debug UI stays stable.
- `BallAudioSystem.gd` owns pooled ball-to-ball clack sounds with random stream/pitch variation, impact-scaled volume, and cooldown filtering.
- Presentation should stay readable and degrade before gameplay ambition is reduced.

## Debug Notes

- `DebugOverlay.gd` now supports modular draggable debug panels plus the old full F3 overlay.
- `DebugPanel.gd` owns panel shell behavior and consumes panel-local input so cue drag/release is protected.
- Debug panels remain interactive while paused, and hidden panels should not refresh text or request unnecessary snapshot sections.
- Snapshot/counter meanings should remain stable; debug gating should reduce hidden work without hiding behavior.

## Optimization Notes

- Anchor is now state/event-driven curse-seed gameplay rather than a continuous force-field simulation.
- Embezzler is capped and event-driven around score gain, aim pressure, once-per-shot decisions, capture, and escape resolution.
- Score popups coalesce into tiered score stacks to reduce label/tween pressure during high-chaos scoring.
- Project Brain and debug media are reference-only. Always verify behavior against `AGENTS.md`, real scripts, and scenes before changing gameplay.

## Tone

The tone is arcade chaos plus pirate/eldritch personality: readable, punchy, a little ridiculous, and celebratory. Doubloons belong to this project. Insight remains reserved for the larger future Cuethulhu direction.

## Architecture Reminder

`AGENTS.md` is the authoritative development/process document. Project Brain reports are reference-only and should be checked against real scripts/scenes before changing behavior.
