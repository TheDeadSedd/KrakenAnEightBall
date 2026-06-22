# Project Notes

Kraken An Eight Ball is a pirate/eldritch arcade-chaos billiards prototype. It is now a systemic playtest bed for a Passage-centered run objective, chosen table chaos, readable anomaly balls, trick-shot celebration, tactical shop pressure, Oaths, persistent Kraken Favor, and early cue progression.

## Current Gameplay Loop

- Start from the atmospheric title screen.
- Optionally visit Cue Locker or Run History before a run.
- Shoot with drag-and-release arcade billiards controls.
- Sink object balls for Doubloons, shot-event rewards, Pocket Streak bonuses, pocket-side score stacks, and HudFeed log entries.
- Held Doubloons and completed Kraken Requests reduce the current run's Passage requirement.
- Doubloons earned during the current shot also fill the Kraken Intervention threshold meter.
- Reaching the threshold creates a pending intervention opportunity instead of automatically spawning balls.
- When cue control returns, the intervention icon becomes clickable and opens the event-choice menu.
- The player may spend Doubloons on a Table Event, swear an Oath to replace one offer, save for Quartermaster tools, refresh Quartermaster stock, or pursue a Back Room Deal.
- Table Events, Reserve items, and Back Room tools add balls/anomalies/chaos through existing spawn and anomaly systems.
- Completing Passage ends the run successfully, saves run history, and awards persistent Kraken Favor.

The old automatic score-triggered BallDrop reward loop is retired/gated in normal play. `BallDropSystem.gd` is now backstage support for cue/eight-ball penalties, legacy toggles, and debug drop plumbing. It is no longer the active progression spine.

Cue ball and eight ball sinks no longer end the game. Each currently costs 25 Doubloons; cue-ball sinks still remove one eligible object ball, while eight-ball sinks try to transform an eligible object ball into an Anchor curse seed.

## Passage And Kraken Requests

`PassageSystem.gd` owns the current-run objective.

- First-pass Passage requirement: 10000.
- Held Doubloons reduce remaining Passage, so spending still matters.
- Completed Kraken Requests reduce Passage by request reward values.
- Request rerolls add Passage pressure instead of spending Doubloons.
- Blackwood Cue can increase request Passage reduction through the cue modifier snapshot.
- Successful Passage triggers the completion summary and persistent Kraken Favor award flow.

Current request pool:

- `BANK`
- `DOUBLE_BANK`
- `LONG_HAUL`
- `POWER_SINK`
- `POCKET_STREAK_X3`
- `POWDER_ROUTE`
- `CANNON_CHAIN`
- `TREASURE_SNARE`

`EventMetadata.gd` centralizes event/request labels and descriptions for Passage tooltips and future encyclopedia/logbook-style reuse.

## Oaths

`OathSystem.gd` owns data-driven Oath definitions, active Oath state, shot counters, completion/failure lifecycle, penalties/restrictions, and debug helpers.

Current functional Oaths:

- Oath of Urgency: complete any Kraken Request within 3 shots or add Passage pressure.
- Oath of Isolation: Quartermaster purchases, refreshes, and Back Room Deals are unavailable for 5 shots.
- Oath of Humility: cue gameplay modifiers are silenced for 10 shots while equipment and cue visuals remain unchanged.

Oath of Sacrifice exists for debug/future use and can remove eligible object balls on manual/debug failure, but it is not part of the normal Intervention replacement choice pool.

The active Oath HUD indicator reads from `OathSystem.gd`. Oath tooltips should use the Oath definitions/snapshots, not duplicated UI strings.

## Kraken Intervention / Table Events

Kraken Intervention remains the chosen-chaos economy spine.

- `TableEventSystem.gd` tracks shot-earned Doubloons toward the intervention threshold.
- Current threshold: 30 Doubloons earned during one shot.
- Pending opportunities become ready only after cue control returns.
- `TableEventMeter.gd` presents the horizontal bottom-center `KRAKEN INTERVENTION` meter and ready icon.
- `TableEventMenu.gd` presents the compact `Request Kraken Intervention...` menu.
- Offers are weighted, rarity-labeled, unique per menu, and purchased with Doubloons.
- Spending on interventions does not count as scoring and must not refill the meter.
- Individual offers can be replaced by swearing a selectable Oath; only that slot rerolls.

Current intervention offers:

- Cheap Cargo: Common, weight 10, cost 20, drops 5 regular object balls.
- Loose Cargo: Common, weight 8, cost 40, drops 10 regular object balls.
- Wayfinder's Favor: Uncommon, weight 5, cost 55, drops 2 Wayfinder Balls.
- Powder Cache: Uncommon, weight 4, cost 75, drops 3 Powder Kegs.
- Cannon Warning: Rare, weight 2, cost 90, drops 1 Cannon Ball.
- Broadside Attack: Rare, weight 1, cost 140, drops staged Powder Kegs and then Cannon Balls.
- Wayfinder Current: Rare, weight 3, cost 120, drops 2 Wayfinders and triggers temporary current behavior.

## Cargo Discovery And Contraband

Treasure should be found, not bought as a direct Intervention or Quartermaster offer.

- Cheap Cargo can rarely replace one normal drop with Treasure.
- Loose Cargo has an event-level Contraband roll, not a per-ball roll.
- Base Loose Cargo Contraband chance is 1%.
- Lucky Chalk adds +1% absolute chance while cue modifiers are active.
- Contraband replaces at most one normal Loose Cargo ball.
- The weighted Contraband table is Wayfinder Ball 50, Powder Keg 30, Treasure Ball 15, Cannon Ball 4, Embezzler 1.
- Anchor curse seeds are not included in Contraband Cargo.
- Debug force controls must not alter normal odds when disabled.

## Signature Interventions

### Broadside Attack

Broadside Attack is the first authored staged Kraken Intervention milestone. It announces the incoming attack, waits briefly, drops Powder Kegs in readable lanes, then launches Cannon Balls after a short delay. It should feel like a pirate artillery scenario fired through the cursed table, not random table noise.

### Wayfinder Current

Wayfinder Current is the cursed-tide intervention: temporary possession with transferable guided momentum. Two Wayfinders drop, nearby eligible object balls receive a strong initial impulse and temporary Wayfinder/current guidance, and current carriers can transfer the effect on eligible collisions. Current-caused sinks have a focused scoring path. Nearby affected-ball count is intentionally uncapped for now; current lifetime and transfer depth remain safety boundaries.

## Quartermaster, Refresh, Reserve, And Back Room

- `QuartermasterSystem.gd` owns item IDs, prices, affordability, three active rotating offers, event-driven offer refresh, refresh cost scaling, shot decay, and Quartermaster availability blockers.
- `QuartermasterHUD.gd` presents the live gameplay-mounted right-side shop rail, refresh button, and Back Room button.
- Current normal purchasable items are Loose Object Ball, Wayfinder Ball, and Powder Keg.
- Quartermaster Refresh starts at 10 Doubloons, doubles after each refresh, and cools down after shots without refreshing.
- Wayfinder Wrap adds +1 refresh shot-decay through the cue modifier snapshot.
- Purchases spend Doubloons only on success and fill the first open `ReserveSystem.gd` slot.
- Reserve slots are visible as three icon-only mounts on the upper-right table frame.
- Clicking a filled slot starts deployment through `BallPlacementSystem.gd`.
- `ReserveDeploymentPresenter.gd` adds the cursor icon and dotted tether without changing placement rules.

`BackRoomDealSystem.gd` owns Back Room Deal economy/data. The first-pass Back Room unlocks when Quartermaster refresh cost reaches 80, costs 250 Doubloons, and can procure Wayfinder Ball, Powder Keg, Treasure Ball, Cannon Ball, or Embezzler if available. It respects Reserve space, affordability, Embezzler cap/pending state, and Oath of Isolation.

## Run Stats, Run History, And Progression

- `RunStatsSystem.gd` tracks current-run stats only.
- Money tracking is split into Doubloons Earned, Doubloons Spent, and Doubloons Lost to penalties.
- Run Stats also tracks balls sunk, active ball count, run time, shots taken, highest Pocket Streak, interventions triggered, Quartermaster refreshes, Back Room deals, request rerolls, Contraband found, Treasure claimed, Passage snapshot, active Oaths, cue loadout, and cue modifier readouts.
- `RunStatsHUD.gd` owns the live top-left ledger overlay.
- `RunLedgerHUD.gd` owns the compact lower-HUD BALLS/SUNK counter cluster.
- `RunHistorySystem.gd` persists finalized run records to `user://run_history.json`, keeps the most recent 25, and remains separate from current-run stats.
- `MainMenuRunHistoryPanel.gd` owns the Main Menu Run History panel UI.
- `ProgressionSystem.gd` persists Kraken Favor and cue progression data to `user://progression.json`.

Successful Passage awards Kraken Favor. First-pass reward starts at 1, can add bonuses for 5000+ Doubloons earned, 3+ Kraken Requests completed, 1+ legendary event, and Treasure claimed, and is capped at 5 per run. Abandoned runs do not award Favor.

## Cue Locker And Cue Modifiers

`CueProgressionSystem.gd` owns cue part definitions, unlock state, equipped loadout, cue snapshots, effect definitions, and active modifier snapshots. `MainMenuCueLockerPanel.gd` owns Cue Locker UI.

Default unlocked loadout:

- Weathered Cue
- Plain Tip
- Sailcloth Grip
- Plain Ferrule
- Plain Chalk

Current unlockable parts:

- Blackwood Cue: costs 3 Favor, +10% Kraken Request Passage reduction.
- Brass Tip: costs 2 Favor, +5% initial cue shot power. Aim preview uses the same effective multiplier.
- Wayfinder Wrap: costs 2 Favor, +1 Quartermaster refresh shot-decay.
- Bone Ferrule: costs 2 Favor, -25 flat Passage penalty from failed Passage-adding Oaths.
- Lucky Chalk: costs 1 Favor, +1% absolute Loose Cargo Contraband chance.

Cue effects are data-driven through modifier keys. Gameplay systems consume generic modifier snapshots; they should not read raw progression JSON or hardcode equipped cue part IDs. Oath of Humility suppresses gameplay modifiers without changing equipment, visuals, or save data.

## Current Special Balls

- Wayfinder Ball: cue-contact anomaly that can guide eligible balls toward pockets and supports temporary Wayfinder Current carriers.
- Powder Keg: explodes on cue-ball or Cannon Ball contact, pushes nearby balls, removes itself, and requests fake-3D table impact shake.
- Anchor Ball: curse-seed model. Eight-ball sink transforms an eligible existing object ball into a stationary seed, chains 1-3 balls, tightens leashes only during cue-control windows, warns before spread, and collapses through cue hit, Powder Keg, Cannon Ball, or pocketing a chained ball. The old continuous pull field is retired/disabled.
- Cannon Ball: heavy iron anomaly that can be debug-spawned or dropped/launched by Table Events; it is hard to start, hard to stop, dangerous once moving, and visually marked by heat presence.
- Treasure Ball: cautious aim-line/hiding anomaly that can appear through rare cargo/contraband paths and awards a large Doubloon payout when sunk.
- Embezzler: capped living greed anomaly that copies a share of Doubloons while alive, hides or runs once per shot based on stored value/willingness, wants one secret pocket, can escape after a pocket roll, and pays out stored value if caught first.

Treasure and Embezzler are separate identities. Treasure is the cautious aim-line/hiding and reward discovery experiment; Embezzler is the greed, panic, secret-pocket, and cashout/escape mechanic.

## Current Shot Event Tiers

- Foundational: `BANK`, `CHAIN`, `MULTI_CHAIN`, `ANOMALY_TOUCH`, `MULTI_SINK`.
- Skilled: `KRAKEN_KICK`, `DOUBLE_BANK`, `THIN_CUT`, `CLUSTER_BREAK`, `LAST_GASP`, `POWER_SINK`, `SPLIT_THE_LOOT`.
- Heroic: `CROSS_CORNER_BANK`, `FULL_TABLE_KICK`, `POWDER_ROUTE`, `KRAKEN_CURRENT`, `LONG_HAUL`.
- Legendary: `TRIPLE_BANK`, `CANNON_CHAIN`, `TREASURE_SNARE`.

Shot events reward recovery, geometry, improvisation, chaos control, anomaly-assisted creativity, and legendary moments. Kraken An Eight Ball is not strict billiards simulation realism; it is readable arcade billiards mythology.

## Current Score Presentation

- Score celebration uses evolving pocket-side score stacks rather than endless independent labels.
- Foundational, Skilled, Heroic, and Legendary rewards each have tier-specific stack presentation.
- Stack totals count upward while compact subtitles summarize latest/combined event names.
- Skilled stacks glow blue, Heroic stacks glow purple, and Legendary stacks glow gold/yellow.
- Lane management separates tiers around pockets and lets older/lower-priority stacks yield or fade early.
- Treasure claim payout and Embezzler capture payout use the normal Doubloon award flow.
- The old popup path is reserved for future/unknown rewards or any intentionally non-stack event presentation.

## Pocket Streak

Pocket Streak rewards repeated object-ball sinks into the same pocket during one shot.

- Second same-pocket sink triggers X2, third triggers X3, fourth and higher escalate further.
- It is separate from `MULTI_SINK`.
- Streak bonus scoring uses same-pocket scoring context rather than the old flat bonus.
- Presentation is queued so rapid X2/X3/X4 events are readable.
- X4+ adds localized whirlpool/threat-tell visuals.
- Pocket Streak audio uses a fixed pool, cooldowns, multiplier pitch/volume scaling, and a dedicated reverb bus.
- This is still presentation/scoring only by deliberate design. There is no suction, altered pocket radius, velocity pull, or gameplay force.

## Table Obstacles / Debris

`TableObstacleSystem.gd` owns first-pass wood debris support.

- Obstacles live under `Table/Obstacles`.
- Debug controls can spawn/clear debris.
- Spawn placement uses random playable-felt positions with margin and simple overlap avoidance.
- Collision reads authored `CollisionPolygon2D` points from `TableObstacle.tscn`.
- Transformed polygon points, AABB, bounding radius, and edge normals are cached.
- Moving balls only are checked against obstacles.
- Broadphase rejection runs before detailed circle-vs-polygon checks.
- Collision is custom billiards resolution, not Godot physics simulation.

## Presentation Notes

- `MainMenu.tscn` / `MainMenu.gd` owns the title screen shell.
- The main menu uses layered authored art, lightweight animated overlays, fog, and menu UI.
- Options is a real reusable menu with Audio sliders and is available from main menu and pause.
- Run History and Cue Locker are focused Main Menu panels with their own presenter scripts.
- The gameplay floor/background uses full ship-floor art behind the table and decor.
- Remaining table decor is randomized as presentation-only dressing and must not affect collisions or input.
- Standard object balls are solid colored and numberless; the palette is moodier but still readability-first.
- The eight ball remains gameplay-identical to regular balls and is distinguished through an obsidian body plus draw-only floating ethereal sigil.
- The project UI broadly uses `NotJamOldStyle11.ttf`, tuned per UI category.
- Fake-3D table shake, Cannon heat, Treasure/Embezzler legs, Reserve tethering, Pocket Streak whirlpools, Wayfinder Current pulses, and cue part accents are presentation-only.

## Audio Notes

- `AudioSettings.gd` owns Master/Music/SFX bus volume settings and persists them in `user://settings.cfg`.
- `BallAudioSystem.gd` owns pooled collision audio with random stream/pitch variation, impact-scaled volume, and cooldown filtering.
- Pocket Streak audio uses `namedpoocket_multi.wav`, a fixed audio pool, cooldown protection, multiplier scaling, and a dedicated reverb bus.
- Gameplay music loops at low volume through a separate music owner/bus.
- Collision audio, Pocket Streak audio, UI audio, anomaly audio, and music should remain separated.
- Do not reintroduce `AudioStreamGenerator` for Pocket Streak audio.

## Debug Notes

- `DebugOverlay.gd` supports modular draggable debug panels plus the full F3 overlay.
- Hidden panels should not refresh text or request unnecessary snapshot sections.
- Pause menu debug controls live behind Dev Options, and Dev Options content is scrollable.
- Debug controls include Event Test buttons, Contraband force controls, debris controls, Oath Testing controls, and cue modifier/oath suppression readouts.
- Debug event buttons bypass only cost/readiness and must not refill Kraken Intervention or duplicate event logic.
- Cue-drag mouse ownership suppresses hover tooltips while the cue is actively being dragged.

## Optimization Notes

- Support chaos gracefully instead of preventing chaos.
- Kraken Intervention is shot/event-driven, not continuous score-spawn churn.
- Anchor is state/event-driven curse-seed gameplay rather than continuous force-field simulation.
- Embezzler is capped and event-driven around score gain, aim pressure, once-per-shot decisions, capture, and escape.
- Table obstacle collision uses moving-ball filtering, cached authored polygon data, and broadphase rejection.
- Score popups coalesce into tiered score stacks to reduce label/tween pressure during high-chaos scoring.
- Pocket Streak visuals are localized and presentation-only.
- Wayfinder Current is intentionally uncapped in affected-ball count for now, but uses radius, lifetime, transfer depth, and conservative eligibility as safety boundaries.
- Project Brain and debug media are reference-only. Always verify behavior against `AGENTS.md`, real scripts, and scenes before changing gameplay.

## Architecture Reminder

`AGENTS.md` is the authoritative development/process document. Project Brain reports are generated reference material and should be checked against real scripts/scenes before changing behavior.
