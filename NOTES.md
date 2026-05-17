# Project Notes

Kraken An Eight Ball is a pirate/eldritch arcade-chaos billiards prototype. It is now a systemic playtest bed for escalating table states, readable anomaly balls, trick-shot celebration, and player-chosen chaos through Kraken Intervention.

## Current Gameplay Loop

- Start from the atmospheric title screen, then load the playable table scene.
- Shoot with drag-and-release arcade billiards controls.
- Sink object balls for Doubloons, shot-event rewards, Pocket Streak bonuses, pocket-side score stacks, and HudFeed log entries.
- Doubloons earned during the current shot fill the Kraken Intervention threshold meter.
- Reaching the threshold creates a pending intervention opportunity instead of automatically spawning balls.
- When cue control returns, the intervention icon becomes clickable and opens the event-choice menu.
- The player chooses from three weighted/randomized offers and may spend Doubloons to reshape the table.
- Table Events add balls/anomalies/chaos through existing spawn and anomaly systems.
- The live Quartermaster side-rail shop and Reserve slots provide a separate tactical economy loop.
- The player survives and exploits escalating table state instead of simply clearing a rack.

The old automatic score-triggered BallDrop reward loop is retired/gated in normal play. `BallDropSystem.gd` is now mostly backstage support: cue/eight-ball penalties, legacy toggles, and debug drop plumbing. It is no longer the active progression spine.

Cue ball and eight ball sinks no longer end the game. Each currently costs 25 Doubloons; cue-ball sinks still remove one eligible object ball, while eight-ball sinks try to transform an eligible object ball into an Anchor curse seed.

## Kraken Intervention / Table Events

Kraken Intervention is the active progression/economy spine.

Design philosophy: Kraken Intervention replaces automatic reward spawning with player-chosen escalation. Strong shots earn dangerous opportunities, but the player chooses whether to spend Doubloons, save for Quartermaster/Reserve, or invite the cursed table to make things worse on purpose. This turns score into economic agency and chaos into a tactical bargain instead of an invisible reward drip.

- `TableEventSystem.gd` tracks shot-earned Doubloons toward the intervention threshold.
- Current threshold: 30 Doubloons earned during one shot.
- Pending opportunities become ready only after cue control returns.
- `TableEventMeter.gd` presents the horizontal bottom-center `KRAKEN INTERVENTION` meter and ready icon.
- `TableEventMenu.gd` presents the compact `Request Kraken Intervention...` menu.
- Offers are weighted, rarity-labeled, unique per menu, and purchased with Doubloons.
- Spending on interventions does not count as scoring and must not refill the meter.

Current intervention offers:

- Cheap Cargo: Common, weight 10, cost 20, drops 5 regular object balls.
- Loose Cargo: Common, weight 8, cost 40, drops 10 regular object balls.
- Wayfinder's Favor: Uncommon, weight 5, cost 55, drops 2 Wayfinder Balls.
- Powder Cache: Uncommon, weight 4, cost 75, drops 3 Powder Kegs.
- Cannon Warning: Rare, weight 2, cost 90, drops 1 Cannon Ball.
- Broadside Attack: Rare, weight 1, cost 140, drops staged Powder Kegs and then Cannon Balls.
- Wayfinder Current: Rare, weight 3, cost 120, drops 2 Wayfinders and triggers temporary current behavior.

## Signature Interventions

### Broadside Attack

Broadside Attack is the first authored staged Kraken Intervention milestone. It announces the incoming attack, waits briefly, drops Powder Kegs in readable lanes, then launches Cannon Balls after a short delay. It should feel like a pirate artillery scenario fired through the cursed table, not random table noise.

### Wayfinder Current

Wayfinder Current is the cursed-tide intervention: temporary possession with transferable guided momentum. Two Wayfinders drop, nearby eligible object balls receive a strong initial impulse and temporary Wayfinder/current guidance, and current carriers can transfer the effect on eligible collisions. Current-caused sinks have a focused scoring path. Nearby affected-ball count is intentionally uncapped for now; current lifetime and transfer depth remain safety boundaries.

## Pocket Streak

Pocket Streak rewards repeated object-ball sinks into the same pocket during one shot.

- Second same-pocket sink triggers X2, third triggers X3, fourth and higher escalate further.
- It is separate from `MULTI_SINK`.
- Streak bonus scoring uses same-pocket scoring context rather than the old flat bonus.
- Presentation is queued so rapid X2/X3/X4 events are readable.
- X4+ adds localized whirlpool/threat-tell visuals.
- Pocket Streak audio uses a fixed pool, cooldowns, multiplier pitch/volume scaling, and a dedicated reverb bus.
- This is still presentation/scoring only by deliberate design. There is no suction, altered pocket radius, velocity pull, or gameplay force.
- The X4+ whirlpool/threat tell is a psychological "hungry pocket" cue, not unfinished required gameplay. Real pull mechanics are reserved for a future explicit gameplay pass.

## HudFeed

`HudFeed.gd` is the bottom-left rolling captain's-log feed.

- New messages enter at the bottom and push older messages upward.
- Older messages fade progressively.
- Hovering makes visible entries fully readable and enables scroll review.
- Long entries wrap with hanging indentation instead of truncating.
- It logs scoring summaries, sink notes, penalties, Pocket Streaks, Table Events, Quartermaster/Reserve feedback, and anomaly messages.
- It is a readable history layer, not a replacement for pocket-side score celebration.

## Current Shop And Reserve Loop

- `QuartermasterSystem.gd` owns item IDs, prices, affordability, three active rotating offers, and event-driven offer refresh.
- `QuartermasterHUD.gd` presents the live gameplay-mounted right-side shop rail.
- Descriptions live in hover tooltips instead of permanent pause-menu text.
- Current purchasable items are Loose Object Ball, Wayfinder Ball, and Powder Keg.
- Purchases spend Doubloons only on success and fill the first open `ReserveSystem.gd` slot.
- Reserve slots are visible as three icon-only mounts on the upper-right table frame.
- Clicking a filled slot starts deployment through `BallPlacementSystem.gd`.
- `ReserveDeploymentPresenter.gd` adds the cursor icon and dotted tether without changing placement rules.

Current tactical economy loop:

Kraken Intervention opportunities, Quartermaster offers, and Reserve deployment all compete for Doubloons. The player chooses whether to save, buy tactical tools, or invite table chaos.

## Current Special Balls

- Wayfinder Ball: cue-contact anomaly that can guide eligible balls toward pockets and now supports temporary Wayfinder Current carriers.
- Powder Keg: explodes on cue-ball or Cannon Ball contact, pushes nearby balls, removes itself, and requests fake-3D table impact shake.
- Anchor Ball: curse-seed model. Eight-ball sink transforms an eligible existing object ball into a stationary seed, chains 1-3 balls, tightens leashes only during cue-control windows, warns before spread, and collapses through cue hit, Powder Keg, Cannon Ball, or pocketing a chained ball. The old continuous pull field is retired/disabled.
- Cannon Ball: heavy iron anomaly that can be debug-spawned or dropped/launched by Table Events; it is hard to start, hard to stop, dangerous once moving, and visually marked by heat presence.
- Treasure Ball: debug-spawn experiment that notices the aim-line corridor, chooses cover, avoids being watched too closely, scuttles away while perceived, and uses draw-only legs.
- Embezzler: debug-spawn/capped living greed anomaly that copies a share of Doubloons while alive, hides or runs once per shot based on stored value/willingness, wants one secret pocket, can escape after a pocket roll, and pays out stored value if caught first.

Treasure and Embezzler are separate identities. Treasure is the cautious aim-line/hiding experiment; Embezzler is the greed, panic, secret-pocket, and cashout/escape mechanic.

## Current Shot Event Tiers

- Foundational: `BANK`, `CHAIN`, `MULTI_CHAIN`, `ANOMALY_TOUCH`, `MULTI_SINK`.
- Skilled: `KRAKEN_KICK`, `DOUBLE_BANK`, `THIN_CUT`, `CLUSTER_BREAK`.
- Heroic: `CROSS_CORNER_BANK`, `FULL_TABLE_KICK`, `POWDER_ROUTE`, `KRAKEN_CURRENT`.
- Legendary: `TRIPLE_BANK`, `CANNON_CHAIN`, `TREASURE_SNARE`.

Shot events reward recovery, geometry, improvisation, chaos control, anomaly-assisted creativity, and legendary moments. Kraken An Eight Ball is not strict billiards simulation realism; it is readable arcade billiards mythology.

## Current Score Presentation

- Score celebration uses evolving pocket-side score stacks rather than endless independent labels.
- Foundational, Skilled, Heroic, and Legendary rewards each have tier-specific stack presentation.
- Stack totals count upward while compact subtitles summarize latest/combined event names.
- Skilled stacks glow blue, Heroic stacks glow purple, and Legendary stacks glow gold/yellow.
- Lane management separates tiers around pockets and lets older/lower-priority stacks yield or fade early.
- The old popup path is reserved for future/unknown rewards or any intentionally non-stack event presentation.

## Presentation Notes

- `MainMenu.tscn` / `MainMenu.gd` owns the title screen shell.
- The main menu uses layered authored art, lightweight animated overlays, fog, and menu UI.
- The gameplay floor/background uses full ship-floor art behind the table and decor.
- Remaining table decor is randomized as presentation-only dressing and must not affect collisions or input.
- Standard object balls are solid colored and numberless; the palette is moodier but still readability-first.
- The eight ball remains gameplay-identical to regular balls and is distinguished through an obsidian body plus draw-only floating ethereal sigil.
- The project UI now broadly uses `NotJamOldStyle11.ttf`, tuned per UI category.
- Fake-3D table shake, Cannon heat, Treasure/Embezzler legs, Reserve tethering, Pocket Streak whirlpools, and Wayfinder Current pulses are presentation-only.

## Audio Notes

- `BallAudioSystem.gd` owns pooled collision audio with random stream/pitch variation, impact-scaled volume, and cooldown filtering.
- Pocket Streak audio uses `namedpoocket_multi.wav`, a fixed audio pool, cooldown protection, multiplier scaling, and a dedicated reverb bus.
- Gameplay music loops at low volume through a separate music owner/bus.
- Gameplay music is ambient table atmosphere first. It should add cursed momentum without covering collision clacks, intervention cues, Pocket Streak audio, scoring feedback, or anomaly tells.
- Collision audio, Pocket Streak audio, UI audio, anomaly audio, and music should remain separated.
- Do not reintroduce `AudioStreamGenerator` for Pocket Streak audio.

## Debug Notes

- `DebugOverlay.gd` supports modular draggable debug panels plus the full F3 overlay.
- Hidden panels should not refresh text or request unnecessary snapshot sections.
- Pause/debug controls can show right-side `Current` and `Broadside` test buttons for Wayfinder Current and Broadside Attack.
- Debug test buttons bypass only cost/readiness and must not refill Kraken Intervention or duplicate event logic.
- Useful counters include Table Event progress/offers/purchases, Pocket Streak multiplier/queue/audio/whirlpool state, Wayfinder Current carriers/transfers/current-caused sinks, and audio pool/cooldown state.

## Optimization Notes

- Support chaos gracefully instead of preventing chaos.
- Kraken Intervention is shot/event-driven, not continuous score-spawn churn.
- Anchor is state/event-driven curse-seed gameplay rather than continuous force-field simulation.
- Embezzler is capped and event-driven around score gain, aim pressure, once-per-shot decisions, capture, and escape.
- Score popups coalesce into tiered score stacks to reduce label/tween pressure during high-chaos scoring.
- Pocket Streak visuals are localized and presentation-only.
- Wayfinder Current is intentionally uncapped in affected-ball count for now, but uses radius, lifetime, transfer depth, and conservative eligibility as safety boundaries.
- Project Brain and debug media are reference-only. Always verify behavior against `AGENTS.md`, real scripts, and scenes before changing gameplay.

## Architecture Reminder

`AGENTS.md` is the authoritative development/process document. Project Brain reports are reference-only and should be checked against real scripts/scenes before changing behavior.
