# Kraken An Eight Ball

## Project Identity

Kraken An Eight Ball is a Godot 4 / GDScript pirate-eldritch systemic arcade-chaos billiards prototype.

The project is now a playable escalation sandbox with multiple interacting systems. The current core loop is:

better shots -> more Doubloons and scoring feats -> Passage reduction and Kraken Intervention Charges -> player-chosen Table Events / temporary Kraken Boons / Quartermaster tools / Oath-backed rerolls -> more balls/anomalies/chaos -> stronger scoring opportunities -> Sunken Spoils and Passage completion -> persistent Kraken Favor.

Core pillars:

- Drag-and-release 2D billiards with custom arcade physics.
- Pirate/kraken table presentation and in-engine charm.
- Doubloons scoring driven by trick-shot event history.
- Pocket-side score celebrations instead of generic center-screen scoring spam.
- Kraken Intervention, a shot-earned Charge economy that replaces automatic score-triggered BallDrop rewards with player-chosen chaos.
- Kraken Boons, temporary shot-duration upgrades purchased from the Intervention menu with Charges + Doubloons.
- Passage, the current run objective spine: earn enough wealth and satisfy Kraken Requests to bargain safe passage.
- Data-driven Oaths that can replace individual Kraken Intervention offers and temporarily impose risk/restriction.
- Sunken Spoils, a run-local object-ball sink milestone reward track with claim/reroll/cast-back choices.
- Pocket Streak scoring and localized pocket wake-up presentation for repeated same-pocket sinks in one shot.
- Rolling HudFeed captain's-log messages for readable scoring, penalty, anomaly, and intervention history.
- The Quartermaster tactical shop, rotating single/bundle offers, paid stock refresh, Back Room Deals, stacked reserve slots, and reusable ball placement flow.
- Current-run Run Stats, persistent Run History, persistent Kraken Favor, Cue Locker unlocks/equipment, and cue modifier plumbing.
- Active anomaly balls: Wayfinder Ball, Powder Keg, Anchor curse seeds, Cannon Ball, Treasure Ball, and Embezzler experiments.
- Expanded foundational, skilled, heroic, and legendary trick-shot event rewards.
- Authored wood debris obstacles with custom polygon collision support and debug placement controls.
- Atmospheric layered main menu presentation with lightweight draw-only motion.
- Pooled event-driven billiards collision audio that scales with chaos.
- Modular draggable debug panels with pause-safe interaction and hidden-work gating.
- Presentation-only fake-3D impact and heat/scuttle effects that add juice without moving authoritative gameplay geometry.
- Fast iteration over broad systems while preserving shot feel.

Target platforms:

- Windows downloadable build.
- Experimental Web / itch browser build.
- Android later.

## Architecture Ownership

### `scripts/Table.gd`

Owns high-level coordination, shot lifecycle, early cue-control reclaim gating, authoritative ball list, current main physics loop, run state, callout queue, and event routing between systems.

Early cue reclaim belongs here because it is shot-lifecycle coordination, not cue presentation. Reclaim requires the cue ball to be stopped and valid, avoids reset/drop states, waits a short post-shot delay, uses lightweight moving-ball counts/speed buckets, blocks likely imminent cue-ball collisions, and does not revoke cue control after it has already been granted.

Does not own large new feature systems unless there is no cleaner option. New gameplay clusters should usually become system scripts and be coordinated from `Table.gd`.

`BallPhysics` intentionally still lives here. It is high-risk because it controls shot feel, collision response, rail events, pocket timing, Wayfinder event timing, and performance counters.

### `scripts/Ball.gd`

Owns individual ball identity, velocity/friction state, generated ball visuals, spawn/drop presentation state, trails, draw-only anomaly presentation such as Cannon heat, Treasure legs, and Embezzler glow/legs, and minimal anomaly identity/state flags such as `is_wayfinder`, `is_powder_keg`, `is_anchor_ball`, `is_anchor_curse_seed`, `is_cannon_ball`, `is_treasure_ball`, `is_embezzler_ball`, and `wayfinder_active`.

Does not own table-wide gameplay rules, scoring, spawning decisions, pocket logic, or anomaly systems beyond per-ball state that must live on the ball.

### `scripts/DebugOverlay.gd`

Owns debug menu UI, debug toggles, physics debug display, full F3 performance overlay formatting, modular debug-panel creation/wiring, section-specific panel text formatting, hotkey display text, and hidden-panel performance gating.

Does not own gameplay counters themselves. `Table.gd` and systems provide snapshots; `DebugOverlay.gd` presents them. Hidden modular panels should not format text every frame, and `DebugOverlay.gd` should request only the snapshot sections needed by currently visible panels unless the full overlay is enabled.

### `scripts/DebugPanel.gd`

Owns the reusable draggable debug panel shell: header dragging, panel visibility, panel-local mouse consumption, pause-safe panel interaction, and lightweight text display.

Does not own debug counter meanings, snapshot generation, gameplay state, or pause rules. Empty HUD space should still pass through when unpaused, but panel/header input should not leak into cue grab/drag/release.

### `scripts/PauseMenu.gd`

Owns pause menu UI, tab presentation, resume/quit button wiring, legacy/hidden Quartermaster tab state, debug-panel toggles, and temporary Event Test Button checkboxes.

The active Quartermaster purchasing UI now lives in `QuartermasterHUD.gd`, not the pause-menu shop flow. Pause menu debug controls can reveal the right-side Wayfinder Current and Broadside test buttons, but those controls should remain debug-only and should not spend Doubloons or affect Kraken Intervention progress.

Does not own gameplay simulation, physics, scoring, shot math, Table Event execution, or anomaly updates. `get_tree().paused` freezes gameplay; pause menu, debug overlay, and debug panels are allowed to keep processing so the player can interact with UI while gameplay is frozen.

### `scripts/CueController.gd`

Owns cue sprite/pivot presentation, idle motion, cue grab-zone hit testing, pullback visuals, and strike/recoil/settle animation.

Does not own shot power, shot velocity, aim prediction, or real ball movement.

### `scripts/AimPreview.gd`

Owns polished cue-ball aim line presentation, shot-power color, swept cue-ball preview collision checks, AimPreview-only broad-phase filtering, ghost cue-ball prediction, one-bank preview, hit-ball prediction line presentation, Long Sight secondary chain-line prediction, hit-ball first-collision stopping against rails/balls/pockets, visual-only endpoint markers, read-only Treasure/Embezzler perception snapshots, and predicted-vs-actual shot path debug visualization.

Does not mutate real gameplay state. Prediction must stay side-effect-free and should use shared boundary/pocket helpers so preview stays aligned with real movement.

Aim preview rebuilds should be coalesced by `Table.gd`: input events mark the preview dirty, and a single centralized update performs at most one rebuild per frame while dragging. Do not reintroduce coarse angle/power tolerance reuse; graze shots need reliable rebuilds when the visible aim changes.

Long Sight is a Kraken Boon effect read from the generic boon effect snapshot. It adds faint secondary chain lines after the normal cue-ball preview, follows one likely next ball per chain step, and stops on no next hit, pocket, rail/end condition, stop/max distance, or the depth limit. Current base Long Sight chain depth is 5. It must remain side-effect-free prediction/presentation only.

AimPreview.gd must remain prediction/presentation only. It must not change real physics, shot power, cue feel, scoring, anomalies, or spawn systems.

### `scripts/SpawnSystem.gd`

Owns cue ball start/reset helpers, starting rack/object-ball creation, Table Event ball drops/launches, debug ball spawns, safe spawn search, drop animation coordination, spawn landing callbacks, spawn-related callouts, regular anomaly pool odds, and debug creation requests such as Anchor curse-seed transformation.

Does not own scoring, pocket consequences, shot lifecycle, physics tuning, Kraken Intervention thresholds/purchases, legacy automatic-drop decisions, or anomaly behavior after a ball exists.

### `scripts/BallPlacementSystem.gd`

Owns reusable item-agnostic placement mode: placement item state, ghost preview, valid/invalid presentation, safe-position validation through existing spawn helpers, confirm/cancel flow, and placement input ownership.

Does not own shop inventory, Reserve slot contents, Doubloon spending, score progress, or item-specific reward rules. It should remain reusable by Quartermaster, Reserve deployment, Treasure rewards, tutorials, debug tools, and future "place a ball" effects without becoming shop-specific.

### `scripts/QuartermasterSystem.gd`

Owns Quartermaster shop inventory, item IDs, prices, descriptions, affordability checks, purchase state, active rotating offer slots, paid deterministic/event-driven stock refresh, refresh cost scaling/shot decay, Quartermaster access blockers such as Oath of Isolation, and shop debug snapshots/counters.

Current economy flow is Quartermaster buy -> first open Reserve slot fills. Purchases are allowed only when the player can afford the item, Quartermaster is available, and Reserve has space. A successful purchase spends Doubloons, fills the first empty Reserve slot with a normalized payload, and refreshes only the purchased offer slot.

Current normal stock pool:

- Loose Object Ball x1: 10 Doubloons, weight 14.
- Loose Object Ball x3: 25 Doubloons, weight 3.
- Loose Object Ball x10: 75 Doubloons, weight 1.
- Wayfinder Ball x1: 35 Doubloons, weight 5.
- Wayfinder Ball x2: 60 Doubloons, weight 1.
- Powder Keg x1: 55 Doubloons, weight 4.
- Powder Keg x2: 95 Doubloons, weight 1.

Bundles use Reserve quantity fields and should feel less common than x1 stock. Cannon, Treasure, and Embezzler are not normal Quartermaster offers; they remain Back Room / Contraband / future special reward territory.

Quartermaster Refresh is run-local economic pressure: base cost 10 Doubloons, cost doubles after each refresh, and shot decay lowers the current refresh cost toward the base. Cue modifiers may alter the decay amount through generic modifier snapshots, not equipped-item checks.

Does not place balls directly, emit `doubloons_awarded`, advance Kraken Intervention or legacy BallDrop progress, own Back Room Deal purchase validation, own placement validation, or own Reserve deployment presentation. No passive stock timers should be introduced unless explicitly requested; offer refresh should stay event-driven.

### `scripts/BackRoomDealSystem.gd`

Owns Back Room Deal data/economy: unlock threshold, deal cost, selectable special-ball definitions, affordability/availability checks, Embezzler cap checks, Reserve-full checks, purchase validation, spending, and Reserve insertion.

Current first-pass deals unlock when Quartermaster refresh cost reaches 80, cost 250 Doubloons, and can procure Wayfinder Ball, Powder Keg, Treasure Ball, Cannon Ball, or Embezzler when available. Oath of Isolation blocks Back Room use because it makes Quartermaster unavailable; it does not erase unlock progress.

Does not own Back Room panel presentation, normal Quartermaster stock generation, normal stock refresh math, scoring, Kraken Intervention progress, placement validation, or spawned-ball behavior.

### `scripts/BackRoomDealPanel.gd`

Owns the compact Back Room Deal panel presentation: title/flavor, option rows, cost/unavailable text, dimmed states, close/cancel behavior, and selected deal ID emission.

Does not own deal definitions, costs, spending, Reserve insertion, Embezzler cap logic, or Quartermaster refresh behavior. `BackRoomDealSystem.gd` remains the data/economy owner.

### `scripts/QuartermasterOfferRefreshEffect.gd`

Owns the presentation-only fresh-stock cue for a changed Quartermaster offer: soft gold glow, quick shimmer sweep, and fade/pop settling.

Does not own stock selection, prices, affordability, Reserve behavior, spending, or gameplay state. It should remain lightweight UI tween/draw work and process while paused.

### `scripts/QuartermasterHUD.gd`

Owns the active live-gameplay Quartermaster side-rail shop presentation: compact right-side square item slots, cost text, refresh button/cost state, Back Room entry button, hover tooltip content, affordability tinting, refresh shimmer, bundle xN badges, bundle rotating glow/aura tier presentation, shared item icon drawing, and cue-input-safe click routing into `QuartermasterSystem.gd`.

This replaces the old active shop purchasing presentation that once lived in `PauseMenu.gd`. Tooltips should stay lightweight and only appear on hover; item descriptions should not become permanent inventory-panel text again. Empty HUD space should pass through to gameplay, hover should not interrupt an active cue drag, and clicks on actual item slots should intentionally consume UI input.

Does not own offer inventory, prices, stock refresh math, Back Room definitions/purchases, Doubloon spending, Reserve slot mutation, placement validation, or event economy. `QuartermasterSystem.gd` remains the shop/economy owner, and `BackRoomDealSystem.gd` remains the Back Room economy owner.

### `scripts/ItemIconDraw.gd`

Owns shared presentation-only drawing helpers for compact item/ball previews used by Quartermaster, Reserve, Back Room, and related HUD surfaces.

Does not own item definitions, prices, spawn behavior, Reserve contents, or gameplay identity. It should stay visual-only and small.

### `scripts/ReserveSystem.gd`

Owns the tactical Reserve data model: three slot contents, stacked placeable payload fields (`quantity`, `quantity_total`, `display_name`, `spawn_type`), selected/deploying slot index, deployment start/confirm/cancel state, snapshots, and simple debug counters.

Does not own visual slot drawing, cursor tether presentation, placement validation, ball spawning, Doubloon spending, or Quartermaster offer generation. Confirming a valid Reserve deployment places exactly one ball and decrements quantity by 1; the slot clears only when quantity reaches 0. Canceling or invalid placement does not decrement quantity. No multi-placement exists yet; if it is added later, it should require an explicit hotkey/modifier and never be the default behavior.

### `scripts/ReserveSlotsUI.gd`

Owns the visible icon-only Reserve slots mounted on the upper-right table frame, stack quantity badges, hover glow/outline, slot click input, and forwarding filled-slot deployment requests.

Slot UI consumes click input when starting Reserve interaction, but it should not steal an already active cue drag through hover/mouse motion. It does not own slot contents, placement validation, or ball spawning.

### `scripts/ReserveDeploymentPresenter.gd`

Owns Reserve deployment presentation only: cursor-attached item icon and curved dotted tether from the original Reserve slot to the cursor during placement.

Does not own placement rules, deployment state, safe-position checks, spawning, or Reserve slot mutation. It should be draw-only/lightweight and work while paused.

### `scripts/WayfinderSystem.gd`

Owns Wayfinder activation/deactivation, guided-ball tracking, pocket cone selection, timed guidance, redirect cooldowns, temporary Wayfinder Current carriers, transfer-on-hit current propagation, current-caused scoring snapshots, and Wayfinder debug logging.

Wayfinder Current is the rare Kraken Intervention extension of this system: temporary possession with transferable guided momentum, like a cursed tide grabbing loose cargo and passing through collisions. It reuses existing Wayfinder guidance rather than creating a second steering system. Two dropped Wayfinders trigger localized current pulses; eligible regular object balls receive a strong initial impulse, become temporary current carriers, transfer on eligible collisions, and expire after a short lifetime or transfer-depth limit. Nearby affected-ball count is intentionally uncapped for now, but cue ball, eight ball, sinking/invalid balls, and unsafe anomaly balls remain excluded.

Does not own ball-to-ball collision response, pocket geometry, spawn chance, Table Event offer rules, or general anomaly architecture. Base Wayfinder cue-contact behavior should remain separate from temporary current support.

### `scripts/PowderKegSystem.gd`

Owns Powder Keg cue-ball/Cannon contact explosions, radial push falloff, explosion particle bursts, one-shot explosion state, and Powder Keg debug/performance toggles.

Does not own ball-to-ball collision response, spawn chance, scoring values, pocket geometry, or general physics feel.

### `scripts/AnchorBallSystem.gd`

Owns the current Anchor curse-seed identity: eight-ball sink penalty replacement, eligible seed selection/scoring, curse-seed transformation, stationary seed state, 1-3 chained-ball acquisition, draw-only chain/tether presentation, leash constraints, cue-control-gated chain tightening, deconfliction/lane-finding during tightening, warning countdowns, spread propagation, collapse/counterplay, and Anchor debug counters.

Anchor curse seeds are state/event-driven. The retired continuous pull/field identity is hard-disabled and should not run during normal play or debug testing. Debug Anchor creation should create the new curse-seed style Anchor by transforming an eligible existing object ball, not by spawning an old field source.

Does not own broad ball-to-ball collision response, cue input, scoring values, prediction, pocket geometry, normal reward-spawn odds, or score rewards. Chain visuals are presentation-only; leash constraints/tightening operate only on stored chain links and should not become a table-wide continuous force.

### `scripts/CannonBallSystem.gd`

Owns the Cannon Ball anomaly boundary, Cannon-specific collision tuning, Powder Keg launch tuning, Cannon heavy-impact shake eligibility/cooldown, and moving Cannon heat-presence thresholds. Cannon Ball is currently debug-spawnable, visually heavy, harder to accelerate from normal/cue impacts, more forceful/persistent when it hits non-anomaly balls, amplified when launched by Powder Keg explosions, able to request subtle table thumps on qualifying heavy impacts, and visually marked by a draw-only red/orange heat glow and ember trail at high speed.

Future Cannon Ball passes may own Anchor curse-seed interaction polish, Wayfinder guidance safeguards, regular spawn odds, and additional heat-presence polish, but those are not active yet.

Does not own global ball-to-ball collision constants, spawn odds, scoring values, cue input, prediction, pocket geometry, screen shake, or interactions with Anchor or Wayfinder.

### `scripts/TreasureBallSystem.gd`

Owns Treasure Ball tracking, read-only AimPreview perception state, committed hide target selection, aim-corridor crossing avoidance, pocket-aware hide/flee target filtering, and threat-scaled self-steering while Treasure is actively perceived by the aim-line corridor. Treasure Ball is currently debug-spawnable, visually distinct, uses capped soft-body/scuttle steering toward cover or a fallback flee target without overriding normal collisions, and can request draw-only fleeing-leg presentation from `Ball.gd`.

Does not own rewards, scoring values, spawn odds, pocket behavior, cue input, prediction math, broad physics, or procedural leg drawing. Future Treasure passes may add reward variants, but current Treasure behavior is identity/perception/committed hide-target/threat-scaled hiding movement, soft outgoing self-propelled collision nudges, quick self-braking when calm, and visual fleeing-state reporting only.

Treasure remains its own cautious aim-line/hiding experiment. It is not the Embezzler: Treasure does not skim Doubloons, pick a secret escape pocket, roll hide-or-run decisions, or cash out stored value.

### `scripts/EmbezzlerSystem.gd`

Owns the Embezzler anomaly identity as a living greed mechanic separate from Treasure: capped active tracking, debug-spawn eligibility, copied Doubloon skim/storage, secret target pocket assignment, willingness/desperation from stored value plus aim pressure, once-per-shot hide-or-run decision, Treasure-like hiding/scuttle targets when it does not run, escape commitment toward the secret pocket, target-pocket escape roll, panic retreat on failed pocket roll, capture payout, escape cleanup, visual state reporting, and Embezzler debug counters.

The Embezzler copies a percentage of positive Doubloons awarded while alive; it does not reduce the player's original score. Capturing/pocketing it pays out stored value through the normal award flow so the recovered loot feels like real scoring. Escaping removes/despawns it and clears state without subtracting player score in the current first pass.

Does not own Treasure behavior, scoring values, Kraken Intervention/BallDrop rules beyond using existing award flow on capture payout, pocket geometry, cue feel, physics, Quartermaster/Reserve behavior, spawn odds, or anomaly special interactions. Aim pressure may raise future willingness, but it must not spam escape rolls; the primary escape decision should happen once per cue-ball hit/shot cycle.

### `scripts/PocketSystem.gd`

Owns scene-authored pocket loading from `Table/Pockets`, pocket centers from `CollisionShape2D.global_position`, pocket radii from `CircleShape2D.radius`, pocket capture checks, pocket safety checks for spawning, and pocket performance counters.

Does not own scoring, rewards, ball removal consequences, or procedural/fallback pocket geometry.

### `scripts/BoundarySystem.gd`

Owns scene-authored boundary loading from `Table/Boundaries`, cached rail/jaw `CollisionShape2D` rectangles, boundary collision helpers, side-effect-free prediction helpers, reference rects, and boundary performance counters.

Does not own ball physics tuning, authored node placement, pocket checks, or procedural/fallback table geometry.

### `scripts/TableObstacleSystem.gd`

Owns first-pass table obstacle/debris support: the `Table/Obstacles` holder, `TableObstacle.tscn` spawning/clearing, debug placement across the playable felt, authored `CollisionPolygon2D` extraction, cached transformed polygon collision data, broadphase rejection, custom ball-vs-polygon bounce resolution, collision debug drawing, and obstacle performance counters.

Obstacle collision uses custom billiards physics data, not Godot physics simulation. Collision polygons are read from authored obstacle scenes, transformed/cached, and checked against moving balls only.

Does not own Table Event spawning rules, score rewards, general ball physics constants, rail/pocket behavior, cue feel, or obstacle lifetimes/events beyond debug spawn/clear.

### `scripts/ShotEventSystem.gd`

Owns passive per-shot event history and causal scoring context.

Current implemented event tiers:

- Foundational: `BANK`, `CHAIN`, `MULTI_CHAIN`, `ANOMALY_TOUCH`, `MULTI_SINK`.
- Skilled: `KRAKEN_KICK`, `DOUBLE_BANK`, `THIN_CUT`, `CLUSTER_BREAK`, `LAST_GASP`, `POWER_SINK`, `SPLIT_THE_LOOT`.
- Heroic: `CROSS_CORNER_BANK`, `FULL_TABLE_KICK`, `POWDER_ROUTE`, `KRAKEN_CURRENT`, `LONG_HAUL`.
- Legendary: `TRIPLE_BANK`, `CANNON_CHAIN`, `TREASURE_SNARE`.

`DEAD_MANS_BANK` and other named future events are not implemented yet.

Does not award Doubloons, show UI, change gameplay outcomes, or alter physics. It stores causal shot history per ball so sunk-ball scoring can consume it later. Detection should remain event-driven through shot lifecycle, rail/contact/pocket events, and anomaly reports rather than full-table frame-loop scans.

### `scripts/ScoreSystem.gd`

Owns Doubloons reward values for all implemented shot-event tiers, Treasure claim payout routing, running Doubloons total, scoring breakdown debug logs, HUD total signal, and pocket-side score popup presentation.

Does not own shot event tracking, pocket capture, physics, anomaly behavior, reward spawning, Kraken Intervention/Table Event economy, shops, progression, or heavy VFX.

Current score presentation notes:

- Score presentation now centers on evolving pocket-side score stacks instead of repeatedly spawning itemized labels.
- Foundational, Skilled, Heroic, and Legendary reward tiers each route into tier-specific stack classes when possible.
- Stack numbers count upward (`+5 -> +10 -> +15`) and compact subtitles summarize the latest/combined event names.
- Tier presentation should preserve hierarchy: Foundational is lightweight, Skilled is blue/glowy, Heroic is purple/dramatic, and Legendary is gold/yellow centerpiece celebration.
- Lane management keeps tiers separated near pockets, allows lower-priority/older stacks to yield or fade early, and preserves pocket-side identity.
- The old special popup path should be reserved only for unknown/future rewards or cases still intentionally outside the stack system.
- Score values should not change during presentation-only passes.

Treasure claim payout currently uses the normal Doubloon award path so HUD totals, HudFeed, Run Stats, Passage contribution, and other earned-score listeners stay consistent. Avoid double-awarding Treasure sink rewards.

### `scripts/BallDropSystem.gd`

Owns a small legacy/gated automatic reward-drop surface plus active cue/eight-ball sink penalty amount/message selection.

The old automatic score-triggered BallDrop reward loop is history, not the current spine. `TableEventSystem.gd` gates automatic BallDrop reward spawning by default and replaces it with Kraken Intervention opportunities and player-chosen Table Events. Treat BallDrop reward logic as backstage legacy/debug plumbing unless explicitly asked to revive it.

Current active responsibilities:

- Cue-ball and eight-ball sinks apply a 25 Doubloon penalty through `BallDropSystem.gd` / `ScoreSystem.gd` without adding to drop progress.
- Cue-ball sinks still remove one eligible object ball as the physical penalty.
- Eight-ball sinks now try to transform one eligible existing object ball into an Anchor curse seed instead of using the old remove-ball-only penalty path.
- Legacy score-progress/drop helpers should not emit normal gameplay callouts such as `+1 Ball Dropped` while Kraken Intervention is active.

Does not own object-ball scoring values, score popup presentation, Kraken Intervention thresholds, Table Event offer selection, actual ball creation, spawn placement, drop animation, physics, cue-ball penalty removal animation, or Anchor curse-seed penalty selection.

### `scripts/TableEventSystem.gd`

Owns the active Kraken Intervention / Table Event economy: per-shot Doubloon-to-meter tracking, multi-charge banking, pending intervention state, cue-control-gated readiness, weighted/rarity-based offer selection, single-offer replacement/reroll, charge-cost purchase validation, Boon offer routing, event execution routing, cargo Treasure/Contraband discovery decisions, debug event triggers, Table Event debug snapshots, and the default gate that disables old automatic BallDrop reward spawning.

This is the chosen-chaos spine: strong shots earn a paid opportunity instead of invisible score-to-spawn plumbing. Keep the fuller design philosophy in the Kraken Intervention boundary below as the canonical wording.

Current flow:

- Scoring still awards Doubloons immediately through `ScoreSystem.gd`.
- Only Doubloons earned during an active shot advance the Kraken Intervention meter.
- The first segment goal is 30 shot-earned Doubloons, then goals scale upward: 50, 75, 105, 140, 180...
- Completing a segment banks one pending Kraken Intervention Charge.
- Multiple charges can be earned from one big shot.
- The next segment goal is based on current banked charge count.
- The opportunity becomes clickable only after cue control returns / the player has a decision window.
- The player opens the intervention menu manually and chooses one normal Intervention offer or a separate Kraken Boon, or closes/cancels and keeps the opportunity.
- Core Intervention offers cost Kraken Intervention Charges only, not Doubloons.
- Kraken Boons cost Charges + Doubloons.
- Replacing one offer swears a selectable Oath and rerolls only that slot without spending Doubloons, executing the offer, or refilling the meter.

Current offer pool:

- Cheap Cargo: Common, weight 10, cost 1 Charge, drops 5 regular object balls.
- Loose Cargo: Common, weight 8, cost 2 Charges, drops 10 regular object balls.
- Wayfinder's Favor: Uncommon, weight 5, cost 2 Charges, drops 2 Wayfinder Balls.
- Powder Cache: Uncommon, weight 4, cost 2 Charges, drops 3 Powder Kegs.
- Cannon Warning: Rare, weight 2, cost 3 Charges, drops 1 Cannon Ball.
- Wayfinder Current: Rare, weight 3, cost 4 Charges, drops 2 Wayfinders and triggers temporary current behavior.
- Broadside Attack: Rare, weight 1, cost 5 Charges, drops staged Powder Kegs first, then delayed Cannon Balls.

Signature intervention notes:

- Broadside Attack is the first authored staged Kraken Intervention milestone: a readable pirate artillery scenario with a warning beat, Powder Kegs falling in lanes, and delayed Cannon Balls following through. It should feel like the table has opened a gun deck, not like random spawn noise.
- Wayfinder Current is the rare Wayfinder-themed intervention. Its cursed-tide carrier behavior is owned by `WayfinderSystem.gd`; this system should only route the event and its purchase/debug triggers.

Broadside sequencing lives here, while `SpawnSystem.gd`, `PowderKegSystem.gd`, and `CannonBallSystem.gd` still own creation/drop helpers and post-spawn behavior.

Wayfinder Current is also routed from here, but temporary carrier/guidance behavior lives in `WayfinderSystem.gd`. Table Event debug triggers for Broadside and Wayfinder Current may bypass cost/readiness only; they should call the same event behavior and must not refill Kraken Intervention.

Cargo discovery notes:

- Cheap Cargo has a rare Treasure replacement chance.
- Loose Cargo has one event-level Contraband roll; on success exactly one regular cargo ball is replaced through the weighted Contraband Cargo table.
- Base Loose Cargo Contraband chance is 20%.
- Lucky Chalk adds +1% absolute chance while cue modifiers are active, making it 21%.
- Current Contraband table: Wayfinder Ball 50, Powder Keg 30, Treasure Ball 15, Cannon Ball 4, Embezzler 1.
- Anchor curse seeds are not Contraband Cargo.
- Cargo RNG should be randomized for normal runs, not fixed-seeded. Cheap Cargo Treasure replacement, Loose Cargo Treasure fallback, and true Contraband result sources should stay distinct in debug/logging.
- Debug force controls must not change normal Contraband odds when disabled.

Does not own scoring values, pocket capture, physics, cue feel, anomaly behavior after spawn, Reserve/Quartermaster inventory, or UI drawing. `Table.gd` should coordinate wiring only.

### `scripts/TableEventMeter.gd`

Owns the horizontal bottom-center Kraken Intervention meter presentation: `KRAKEN INTERVENTION` label, multi-charge segment display, shot-earned progress text, percentage text, theatrical tally-up animation, short bass tick presentation where supported, authored ready button texture (`res://assets/ui/kraken_intervention_button.png`), pending charge badge (`x2`, `x3`, etc.), smooth bar fill, pending/ready pulse feedback, and the clickable ready icon.

Does not own threshold math, offer generation, spending, event execution, scoring, cue control, or old BallDrop progress. Empty meter space should not steal cue input; the ready icon should consume only intentional clicks.

### `scripts/TableEventMenu.gd`

Owns the compact `Request Kraken Intervention...` choice menu: modal presentation, three weighted unique normal Intervention offer cards, a separate compact Kraken Boons row, custom boon tooltip styling matching the game UI, cost/rarity/description/status text, affordability state, hover highlighting, close/cancel behavior, per-offer Replace controls only on normal Intervention cards, the compact Oath choice panel for replacement, and forwarding selected offer/boon indexes / replacement choices to `TableEventSystem.gd`.

Does not own offer pool contents, weights, costs, purchase rules, Oath state, event execution, scoring, physics, or HUD meters. The menu should feel like a tactical ritual/omen choice, not a debug panel or full-screen RPG inventory.

### `scripts/KrakenBoonSystem.gd`

Owns data-driven Kraken Boon definitions, active Boon state, shot countdowns, activation/refresh tracking, active effect snapshots, debug activation/expiry helpers, and Boon-specific blocker/status data.

Boons appear in a separate compact row below the three normal Kraken Intervention cards. They cost Kraken Intervention Charges + Doubloons, are temporary shot-duration upgrades, refresh back to their base duration when repurchased while active, and do not stack duration above their base value. Gameplay systems should consume generic effect keys from the active Boon snapshot, not hardcode Boon IDs.

Current Boons:

- Long Sight: costs 1 Charge + 60 Doubloons, lasts 5 shots, exposes `aim_preview_long_sight_enabled = true` and `aim_preview_chain_depth = 5`, and lets AimPreview draw a side-effect-free predictive chain of likely future hit-ball paths.
- Kraken's Patience: costs 2 Charges + 100 Doubloons, lasts 3 shots, exposes `intervention_partial_progress_carry_enabled = true`, and lets partial Kraken Intervention meter progress carry between shots.
- Deep Ledger: costs 1 Charge + 80 Doubloons, lasts 3 shots, exposes `intervention_meter_gain_multiplier = 1.5`, and makes earned Doubloons fill the Intervention meter 50% faster without changing actual Doubloons earned, Run Stats, or Passage contribution.
- Iron Wake: costs 2 Charges + 125 Doubloons, lasts 3 shots, exposes cue-ball Cannon-wake style effect keys, and gives cue-ball impacts temporary Cannon-like authority. It does not mark the cue ball as an actual Cannon Ball and must not make it pass Cannon Ball identity checks.

Does not own the Intervention menu UI, right-side Boon HUD drawing, scoring, cue equipment, or raw progression save data.

### `scripts/KrakenBoonHUD.gd`

Owns the right-side active Kraken Boons HUD indicator. It is display-only, supports multiple active Boon rows, pulses when a Boon is activated/refreshed, and should not be clickable or own purchase/refresh behavior.

Does not own Boon activation, costs, shot countdowns, effect snapshots, or Intervention menu purchasing.

### `scripts/SunkenSpoilsSystem.gd`

Owns the current-run Sunken Spoils reward track based on qualifying object balls sunk. Milestones are `1, 3, 7, 12, 18, 25, 35, 50`; after the final listed milestone, the 50 requirement repeats. Progress is milestone-local. Cue ball and eight ball do not count.

When a milestone fills, a pending Spoils reward becomes ready after shot resolution. Passage completion has priority over Sunken Spoils if both happen from the same shot. Claiming a reward applies it, advances to the next milestone, and resets progress to 0.

Current safe reward categories are Doubloons, Kraken Intervention Charge, Reserve stack payloads, Passage reduction, and Free Quartermaster Refresh. Treasure, Cannon, and Embezzler are intentionally not Sunken Spoils rewards yet.

Reroll rules:

- Doubloon reroll first cost is `round(15 * pow(1.6, current_milestone_index))`.
- Additional Doubloon rerolls in the same panel double the current cost.
- Reroll cost resets every time a new Spoils menu is earned.
- Spending uses the normal safe Doubloon spend path, counts as Doubloons Spent, does not count as Doubloons Lost, and does not refill Kraken Intervention.
- Cast Back costs no Doubloons, closes the panel, does not claim a reward, does not advance the milestone, resets current milestone progress to 0, and keeps the same milestone requirement active.

Reward cards use rarity metadata (`common`, `uncommon`, `rare`) and flavorful display labels while still showing the real effect. The first milestone guarantees at least one obvious satisfying reward option from +25 Doubloons, +50 Doubloons, +1 Intervention Charge, or Object Ball x3.

Does not own UI panel drawing, HUD drawing, scoring values, Reserve deployment, Quartermaster refresh math, Passage core values, or Intervention meter rules.

### `scripts/SunkenSpoilsPanel.gd`

Owns the modal Sunken Spoils reward-choice panel: three reward cards, rarity styling, flavorful/effect text, claim forwarding, Doubloon reroll forwarding, Cast Back forwarding, close behavior, and cue-hover suppression.

Does not own reward generation, reward application, reroll costs, Reserve mutation, Passage reduction, or Doubloon spending.

### `scripts/SunkenSpoilsHUD.gd`

Owns the compact Sunken Spoils live HUD progress indicator. It displays current milestone progress/requirement and pending reward state.

Does not own milestone math, reward state, claim/reroll behavior, or gameplay state.

### `scripts/EventMetadata.gd`

Owns centralized display metadata for scoring/request events: stable IDs, labels, and short descriptions used by Passage tooltips and future reusable event references.

Does not detect events, award score, or own request rewards. `PassageSystem.gd` owns request definitions/rewards, while `ShotEventSystem.gd` owns event detection history.

### `scripts/PassageSystem.gd`

Owns the current-run Passage objective: required Passage amount, remaining Passage math, held Doubloons contribution, active Kraken Request selection, request definitions/rewards, request completion detection, request reroll cost/scaling/decay, Passage pressure from Oaths/rerolls, and successful-run completion state.

Current first-pass Passage requirement is 10000. Positive held Doubloons contribute to satisfying Passage, spending still matters because held Doubloons can drop, and completed Kraken Requests reduce Passage by their request reward amount. Blackwood Cue modifies request reward reduction through the generic cue modifier snapshot.

Current request pool: `BANK`, `DOUBLE_BANK`, `LONG_HAUL`, `POWER_SINK`, `POCKET_STREAK_X3`, `POWDER_ROUTE`, `CANNON_CHAIN`, and `TREASURE_SNARE`.

Does not own Doubloon scoring, cue upgrades, persistent progression currency, Run History persistence, scoring event detection, or UI drawing.

### `scripts/PassageHUD.gd`

Owns the compact live Passage / Kraken Wants HUD presentation, active request tooltip, request reward display, and request reroll button forwarding.

Does not own request definitions, reward values, reroll math, Passage completion, scoring detection, or persistent progression.

### `scripts/OathSystem.gd`

Owns data-driven Oath definitions, active Oath state, shot counters, completion/failure lifecycle, Oath penalties/restrictions, Quartermaster access blocker state, cue-modifier suppression state, and debug helpers for Oath testing.

Current functional first-pass Oaths:

- Oath of Urgency: complete any Kraken Request within 3 shots or add Passage pressure.
- Oath of Isolation: Quartermaster and Back Room access are unavailable for 5 shots.
- Oath of Humility: cue gameplay modifiers are silenced for 10 shots while cue visuals/equipment remain unchanged.

Oath of Sacrifice exists for debug/future use and can remove eligible object balls when manually failed, but it is not in the normal Intervention replacement choice pool.

Does not own Intervention offer replacement UI, Quartermaster purchase logic, cue equipment persistence, or raw progression save data.

### `scripts/OathHUD.gd`

Owns the compact active-Oath live HUD indicator and tooltip presentation using `OathSystem.gd` snapshots.

Does not own Oath activation, penalties, timers, cue modifier suppression, or Quartermaster access rules. Hover UI must stay silent while cue dragging is active.

### `scripts/RunStatsSystem.gd`

Owns current-run aggregate stats only: Doubloons earned/spent/lost-to-penalties, balls sunk, active ball count, run time, shots taken, highest Pocket Streak, interventions triggered, request completions/rerolls, Quartermaster refreshes, Back Room deals, Contraband found, Treasure claimed, active Oath snapshot, Passage snapshot, cue loadout snapshot, cue modifier readouts, and shared row definitions for Run Stats views.

Does not own persistence, scoring values, UI layout, or run-history saving. `RunHistorySystem.gd` persists finalized run records.

### `scripts/RunStatsHUD.gd`

Owns the live top-left Run Stats button and compact ledger overlay during gameplay.

Does not track stats itself, pause gameplay, mutate run state, or own cue modifier calculations. It reads `RunStatsSystem.gd` snapshots/row metadata.

### `scripts/RunLedgerHUD.gd`

Owns the compact BALLS/SUNK lower-HUD counter cluster presentation.

Does not track active ball count or sunk count itself. It reads lightweight current-run/table snapshots and should remain viewport/HUD anchored rather than moving table geometry.

### `scripts/RunHistorySystem.gd`

Owns persistent finalized run history records in `user://run_history.json`, loading/saving, duplicate finalization protection, backward-compatible record normalization, clearing history, and keeping the most recent 25 runs.

Does not own current-run stats, active gameplay state, Kraken Favor, cue progression, or Run History panel presentation.

### `scripts/MainMenuRunHistoryPanel.gd`

Owns the Main Menu Run History panel presentation: scroll list, row formatting, empty state, Back button, Clear History button, and clear confirmation UI.

Does not read/write raw files directly. It calls `RunHistorySystem.gd`, which remains the persistence owner.

### `scripts/ProgressionSystem.gd`

Owns persistent Kraken Favor in `user://progression.json`, versioned progression save data, safe Favor add/spend operations, successful-Passage reward calculation, duplicate reward prevention, and the stored cue progression data subtree.

Current successful-Passage reward formula starts at 1 Kraken Favor, can add bonuses for 5000+ Doubloons earned, 3+ Kraken Requests completed, 1+ legendary event, and Treasure claimed, and is capped at 5 Favor per run.

Does not own current-run stats, run history, cue part definitions, cue equipment validation, or gameplay modifiers directly.

### `scripts/CueProgressionSystem.gd`

Owns cue part definitions, unlock state, equipped cue loadout, unlock/equip validation, cue progression snapshots, cue visual loadout snapshots, and data-driven cue effect definitions/modifier snapshots.

Current slots: body, tip, grip, ferrule, chalk. Default unlocked loadout is Weathered Cue, Plain Tip, Sailcloth Grip, Plain Ferrule, and Plain Chalk. First unlockables are Blackwood Cue, Brass Tip, Wayfinder Wrap, Bone Ferrule, and Lucky Chalk.

Current cue modifier effects:

- Lucky Chalk: +1% absolute Loose Cargo Contraband chance.
- Wayfinder Wrap: +1 Quartermaster refresh shot-decay.
- Bone Ferrule: -25 flat Passage penalty from failed Passage-adding Oaths.
- Blackwood Cue: +10% Kraken Request Passage reduction.
- Brass Tip: +5% cue shot launch power, with aim preview using the same effective multiplier.

Oath of Humility suppresses gameplay modifiers through the final active modifier snapshot without changing equipped cue parts or save data.

Does not apply physics, scoring, economy, or Oath behavior directly. Gameplay systems consume generic modifier keys/snapshots and must not hardcode equipped cue part IDs.

### `scripts/MainMenuCueLockerPanel.gd`

Owns the Cue Locker panel presentation: Kraken Favor display, equipped loadout display, grouped cue part sections, lock/unlock/equip states, costs, buttons, and Back signal.

Does not own Kraken Favor persistence, cue definitions, unlock/equip validation, cue effect definitions, or raw save files. It calls `ProgressionSystem.gd` and `CueProgressionSystem.gd`.

### `scripts/PocketStreakSystem.gd`

Owns same-pocket streak tracking for the current shot: per-pocket object-ball sink counts, same-pocket score subtotals, X2/X3/X4+ multiplier context, duplicate/double-award safety, and debug counters.

Pocket Streak is separate from `MULTI_SINK`: `MULTI_SINK` rewards multiple balls in one shot generally, while Pocket Streak rewards repeated object-ball sinks into the same pocket during that shot. Streak bonuses use same-pocket scoring context rather than the old flat per-step bonus.

Does not own pocket capture, normal sunk-ball score values, score stack presentation, X2/X3 visuals, audio, whirlpool VFX, suction, or pocket physics.

### `scripts/PocketStreakPresenter.gd`

Owns Pocket Streak presentation only: queued X2/X3/X4+ multiplier notifications, gold/arcade glow, localized X4+ whirlpool visuals, threat-tell dust/ripple/glints, fixed-pool Pocket Streak audio playback, cooldown counters, pitch/volume escalation, and the dedicated Pocket Streak reverb bus.

Presentation is intentionally queued so rapid X2 -> X3 -> X4 events are seen/heard as escalation while scoring happens immediately. The current whirlpool/threat-tell system is deliberately presentation-only: it is a psychological "hungry pocket" tell, not unfinished suction. Real pocket pull, suction, radius changes, or force behavior belong only in a future explicit gameplay pass.

Does not own scoring math, pocket capture, physics, cue feel, collision audio, or HudFeed wording.

### `scripts/HudFeed.gd`

Owns the bottom-left rolling captain's-log feed: message history, newest-at-bottom stacking, progressive age fading, hover-to-review full-opacity reveal, mouse-wheel scrolling, multiline wrapped entries with hanging indentation, and compact atmospheric text presentation.

The feed is a readable history/log for scoring, penalties, anomalies, Pocket Streaks, Table Events, and shop/event feedback. It must not replace pocket-side score celebrations or become a gameplay system. Empty feed space should pass through to gameplay unless the player is intentionally hovering/scrolling the feed.

### `scripts/Main.gd`

Owns small app-shell behavior such as fullscreen toggling, top-level UI/system wiring, run completion/return-to-menu coordination, and distribution of current cue modifier snapshots to systems that consume generic modifier keys.

Does not own table gameplay systems, scoring values, cue part definitions, Oath definitions, Passage values, or persistence schemas.

### `scripts/MainMenu.gd`

Owns title-screen presentation, main menu input, button wiring, and safe transition into the existing gameplay scene.

Current main menu uses layered UI over authored art: `assets/ui/mainmenu_bg.png` for sky/moon/ocean/distant scenery, lightweight animated overlay passes, then `assets/ui/mainmenu_fg.png` for ship/tentacles/foreground waves, then fog and menu UI. Start Run loads `Main.tscn`, Options opens the shared first-pass Options menu with audio sliders, Cue Locker and Run History open focused progression/history panels, and Quit exits the game. The same Options menu is also reachable from the in-game pause menu.

The public itch build exists. The main menu includes a small bottom-left Credits block:

- Background music by: Little Robot Sound Factory.
- Some SFX by: Vrymaa.
- Font by: Not Jam (Old Style 11).
- Placeholder art: ChatGPT.
- Looking for artists to work with for final release.

Does not own gameplay systems, pause menu state, debug systems, physics, scoring, Kraken Intervention/BallDrop systems, Quartermaster/Reserve behavior, raw run-history persistence, raw progression persistence, cue definitions, or audio settings storage.

### `scripts/OptionsMenu.gd`

Owns the reusable first-pass Options menu/panel presentation, including the Audio tab, Master/Music/SFX sliders, percentage labels, and context-aware Back behavior for main menu vs pause menu.

Does not own gameplay audio playback logic, scoring, pause state, or raw bus definitions beyond calling the settings owner.

### `scripts/AudioSettings.gd`

Owns first-pass audio settings persistence in `user://settings.cfg`, audio bus lookups, linear/decibel conversion, and applying Master/Music/SFX slider values to Godot audio buses.

Current public/export targets include a Windows downloadable build and an experimental Web / itch browser build. Web audio has compatibility fallbacks: unsupported or effect-heavy audio paths may be simplified on Web, procedural Intervention tally tick audio may be disabled there, and Pocket Streak reverb/effects may be disabled while preserving base audio. `default_bus_layout.tres` defines editor buses: Master, Music, SFX, and PocketStreakSFX. Windows audio should remain richer where supported.

Does not own collision audio behavior, Pocket Streak audio behavior, gameplay music playback, UI layout, export presets, or gameplay state.

### `scripts/MainMenuPresentationOverlay.gd`

Owns draw-only/lightweight title-screen atmosphere overlays: moon glow pulse, star twinkles, ocean shimmer lines, and broad drifting fog bands. It supports layered draw passes so twinkles/shimmer can sit behind foreground silhouettes while fog can sit above them.

Does not own menu buttons, scene loading, gameplay state, shaders, particles, or asset pipelines. Effects should remain cheap, tweakable through exported values, and presentation-only.

### `scripts/TableDecorRandomizer.gd`

Owns presentation-only table decor randomization and should reference only existing decor assets.

Decor should sit above the floor/background but below gameplay/UI readability layers as appropriate. It must not affect collisions, pockets, rails, cue input, scoring, spawn safety, or gameplay logic.

### `scripts/BallDropMeter.gd`

Owns the retired/legacy vertical right-side progress presentation for the old automatic BallDrop loop.

The active player-facing progression meter is now `TableEventMeter.gd` / Kraken Intervention. Do not present `BallDropMeter.gd` as the main progression UI unless the legacy BallDrop loop is explicitly re-enabled for testing.

Does not own drop rules, scoring, spawn timing, debug overlay counters, or gameplay state.

### `scripts/TableImpactShakeSystem.gd`

Owns presentation-only fake-3D table impact shake for Powder Keg explosions and Cannon Ball heavy impacts, including table-art draw offsets and temporary ball shimmy offsets.

Does not own gameplay positions, physics velocities, camera movement, HUD/debug UI, scoring, spawn timing, or anomaly force tuning. It should stay inactive when no shake is playing and must never move authoritative ball/table geometry.

Fake-3D presentation systems should move only drawn presentation layers or draw offsets. HUD/debug UI should remain readable, floor/background should stay still or barely move, and any ball shimmy must be visual-only.

### `scripts/BallAudioSystem.gd`

Owns pooled event-driven billiards collision audio: random hit selection, pitch variation, intensity scaling, cooldown filtering, and collision SFX playback routing.

Does not own collision math, physics timing, scoring, anomaly logic, or gameplay state. Audio should remain event-driven and lightweight rather than becoming a physics-side concern.

### `scripts/GameplayMusicSystem.gd`

Owns low-volume looping gameplay background music and keeps music separate from collision, Pocket Streak, UI, and anomaly SFX.

Gameplay music should support the cursed-table atmosphere without becoming the loudest thing in the room. Collision clacks, Pocket Streaks, Table Events, scoring feedback, and anomaly tells have priority over music readability.

Does not own game state, scoring, physics, Pocket Streak audio, collision audio, or menu music transitions beyond clean gameplay-scene start/stop behavior.

### `scripts/WayfinderCurrentPresenter.gd`

Owns draw-only Wayfinder Current readability: expanding teal/gold initial pulses from dropped Wayfinders and small transfer flashes when current jumps between balls.

Does not own current eligibility, impulses, guidance, scoring, lifetime, transfer limits, or any ball movement.

## Physics Rules

- Preserve shot feel, pocket feel, rail feel, cue feel, and collision liveliness unless explicitly asked to tune them.
- Do not tune physics during cleanup, extraction, UI, art, scoring presentation, or documentation passes.
- Do not casually rewrite `_physics_process`, `_resolve_ball_collisions`, `_apply_ball_collision_response`, rail response, friction, or shot-power math.
- `BALL_COLLISION_RESTITUTION`, `BALL_VELOCITY_TRANSFER`, `BALL_COLLISION_SKIN`, `RAIL_RESTITUTION`, `PHYSICS_SUBSTEPS`, and broad-phase cell size are current feel/performance tuning values.
- If physics must change, make it a focused pass with before/after explanation and preserve debug counters.

## Geometry Rules

- Scene-authored boundaries and pockets are the source of truth.
- Boundaries come from `Table/Boundaries`.
- Pockets come from `Table/Pockets`.
- Pocket centers are read from the pocket `CollisionShape2D.global_position`.
- Pocket radii are read from each `CircleShape2D.radius`.
- Do not reintroduce procedural/fallback table geometry.
- Do not move or resize authored rail, jaw, or pocket nodes from code unless explicitly requested.
- Presentation art can move visually only when requested; gameplay geometry must remain scene-authored.

## Anomaly Architecture

Anomaly balls should generally get their own system scripts. Current active anomaly systems are:

- `WayfinderSystem.gd`
- `PowderKegSystem.gd`
- `AnchorBallSystem.gd`
- `CannonBallSystem.gd` currently owns debug-spawnable/Table Event Cannon identity, collision tuning, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat-presence thresholds.
- `TreasureBallSystem.gd` currently owns debug-spawnable Treasure identity tracking, AimPreview perception reporting, committed hide target selection, gentle hiding movement while perceived, and visual fleeing-state reporting.
- `EmbezzlerSystem.gd` currently owns debug-spawnable/capped Embezzler identity, copied Doubloon storage, willingness, once-per-shot hide-or-run decisions, escape/capture resolution, and visual state reporting.

Pattern:

- `Table.gd` reports physics/gameplay events.
- Anomaly systems react to those events.
- `Ball.gd` stores only identity/state that must live on the ball instance.
- Spawn odds and creation remain in `SpawnSystem.gd`.
- Avoid hardcoding new anomaly behavior directly into `Table.gd`.
- Do not create a broad abstract anomaly framework until multiple anomalies prove the need.

Current anomaly rules:

- Wayfinder activates from cue-ball contact, then can guide eligible object balls toward reachable pockets during collision-driven redirects.
- Wayfinder Current is the Kraken Intervention expression of Wayfinder behavior: temporary possession with transferable guided momentum, localized impulses, carrier transfers, current-caused scoring, and draw-only pulse/transfer-flash presentation.
- Wayfinder Current currently uses conservative eligibility, short lifetime, and transfer-depth safety. Nearby affected-ball count is intentionally uncapped for now, so future optimization should tune radius/readability before adding hard caps.
- Powder Keg explodes on cue-ball or Cannon Ball contact only; normal balls still do not trigger it.
- Powder Keg pushes nearby balls outward with falloff, then removes itself from the table.
- Powder Keg launches Cannon Balls with Cannon-owned impulse amplification and a conservative Cannon launch speed cap.
- Powder Keg requests a short presentation-only table impact shake; table art shakes most, balls receive draw-only shimmy, and HUD/debug UI stays still.
- Powder Keg particle bursts should look juicy and readable, but debug/quality controls should allow particles to degrade safely under load.
- Anchor's old continuous cursed-tide pull/field gameplay is retired and disabled.
- Anchor enters play when the eight ball is sunk: one eligible existing object ball is transformed into a stationary Anchor curse seed.
- Cue ball and eight ball are not valid curse-seed transform targets.
- Curse-seed candidate selection is event-time and prefers difficult/problematic positions such as near rails, clutter, shielded angles, opposite-side pressure, and non-central locations while avoiding easy direct lines and pocket-trivial placements.
- Each curse seed claims 1-3 eligible nearby chained balls, excluding cue ball, eight ball, other curse seeds/Anchors, invalid balls, and sinking balls.
- Chain links store max length. Chained balls can move within the leash but are clamped/projected back when they try to exceed the current max chain length.
- Chain tightening is cue-control/turn gated: when the player regains a decision window, chain lengths shorten and balls slide/tug inward without adding real rolling velocity.
- Deconfliction/lane-finding during tightening lets same-seed chained balls shimmy around one another toward separate contact positions.
- When all valid chained balls touch the seed, a visible warning timer starts. The timer counts down only while the player can act and pauses during unresolved table motion.
- If the warning completes, corruption spreads from the touching chained balls into new curse seeds; spread is event-driven and newly created seeds have a short grace window to avoid same-frame recursive spread.
- Anchor curse seeds can collapse through direct cue-ball hit, Powder Keg, strong Cannon Ball hit, or pocketing a chained ball. Collapse releases chains, clears warning/spread state, and restores the seed to a normal object ball.
- Cannon Ball is currently debug-spawnable and Table Event/drop-only. It visually reads as dark heavy iron with ember detail.
- Cannon Ball has collision modifiers against non-anomaly balls only: it gains reduced velocity when hit, retains more velocity when driving into a ball, and transfers stronger force above a minimum impact speed.
- Cannon Ball can trigger Powder Keg explosions and receives amplified Powder Keg launch impulse.
- Cannon Ball qualifying heavy impacts can request short, subtle table-impact shake through `TableImpactShakeSystem.gd`, with cooldown to prevent shake spam.
- Cannon Ball high-speed heat presence is draw-only in `Ball.gd`, tuned by `CannonBallSystem.gd`, and visually capped so chaos degrades presentation before gameplay.
- Cannon Ball currently has no regular spawn odds and no Cannon-specific special interactions with Anchor or Wayfinder beyond existing Powder Keg and Table Event drop/launch paths.
- Treasure Ball is debug-spawnable and can appear through rare cargo/contraband discovery paths while behaving physically like a normal object ball.
- Treasure Ball uses AimPreview's existing prediction/spatial-grid work to report when Treasure is inside the aim-line perception corridor and not occluded by a closer ball.
- Treasure perception is emotional/perceptual, not merely exact first-hit targeting. Treasure should react to being watched by the aim guide or aimed at too closely, even when it is not the first predicted collision target.
- Treasure Ball can choose a committed hide target behind nearby cover, or a fallback perpendicular flee target when no cover is available.
- Treasure Ball should prefer cover that moves it away from the cue/aim origin and should not willingly cross the active aim corridor if another valid hide option exists.
- Treasure Ball should behave like a cautious sneaky thief, not a shortest-path optimizer.
- Treasure Ball avoids hide/flee targets too close to pockets, though it can still be pocketed by normal hits or table motion.
- Treasure Ball gently steers toward its target only while perceived by the aim line, with stronger panic movement when the aim line is close to its center. This is capped self-steering; normal collisions, pockets, hits, and blocking still use regular ball physics.
- Treasure Ball self-propelled movement should feel like a soft-body scuttle: gentle squeezing/nudging is allowed, but self-steering should not build full billiards momentum, shove clusters hard, or coast into pockets after it calms down. External hits still use normal ball physics.
- Treasure Ball should avoid target-thrashing through short commitment windows and meaningful switch thresholds.
- Treasure Ball procedural legs are draw-only in `Ball.gd`. They appear only while Treasure is actively fleeing/steering, then fade/retract without adding collision or gameplay effects.
- Treasure Ball awards a large Doubloon payout when sunk, can appear through rare cargo/contraband discovery paths, and remains a distinct cautious aim-line/hiding identity rather than the Embezzler greed/escape mechanic.
- Embezzler is currently debug-spawnable and capped at one active Embezzler.
- Embezzler copies/skims a percentage of positive Doubloons awarded while alive, storing value without reducing the player's awarded score.
- Embezzler has a secret target pocket visible only through debug information.
- Embezzler willingness/desperation combines stored-value baseline and short-term aim pressure; aim pressure should raise future risk without causing repeated same-shot escape-roll spam.
- Once per cue-ball hit/shot cycle, Embezzler decides whether to hide or run. Failed/low-value decisions seek cover or flee away from center/target-pocket drift; successful decisions commit it toward its secret pocket.
- When an escape-committed Embezzler reaches its target pocket area, it performs the existing second pocket roll: success escapes/despawns it, failure triggers panic retreat.
- If the player pockets/captures the Embezzler before escape, the player receives its stored value through normal Doubloon award flow; capture payout should remain double-award safe.
- Embezzler visual polish is lightweight/draw-driven: stored value and willingness increase gold glow/urgency, and committed escape reads as frantic/running.

Possible future anomaly systems:

- `EtherealSystem.gd`

## Kraken Intervention / Table Event Boundary

The active progression/economy loop is Kraken Intervention, not automatic score-triggered BallDrop rewards.

Canonical design philosophy: automatic BallDrops made score feel like hidden table plumbing. Kraken Intervention makes escalation legible and chosen: the player earns a dangerous opportunity, decides whether to pay for it, and knowingly invites the cursed table to reshape itself.

Preferred flow:

- `ShotEventSystem.gd` records causal shot history.
- `ScoreSystem.gd` awards Doubloons immediately and emits award amounts.
- `TableEventSystem.gd` tracks only shot-active earned Doubloons toward the Kraken Intervention meter.
- The first segment goal is 30 shot-earned Doubloons, then goals scale upward: 50, 75, 105, 140, 180...
- Completing a segment banks one pending Kraken Intervention Charge; a big shot can bank multiple charges.
- Reaching at least one banked Charge creates a pending intervention opportunity, not an automatic spawn.
- Cue-control regain marks the pending intervention ready and makes the icon clickable.
- `TableEventMenu.gd` presents three weighted unique normal Intervention offers plus a separate compact Boon row.
- `TableEventSystem.gd` validates Charge costs, spends Doubloons only for Boons where required, and routes event execution or Boon activation to the owning systems.
- `SpawnSystem.gd` performs actual ball drops/launch setup, while anomaly systems own behavior after balls exist.
- `Table.gd` coordinates wiring and shot lifecycle only.

Core Interventions are purchased with Kraken Intervention Charges, not Doubloons. Boons are purchased with Charges + Doubloons. Spending Doubloons on Boons, Quartermaster, Back Room, or Sunken Spoils rerolls is not scoring and must not refill Kraken Intervention. Automatic score-triggered BallDrop spawning is gated/disabled by default and should stay retired unless explicitly requested; it is not a parallel active economy.

Do not bury Table Event choice/economy decisions inside `ScoreSystem.gd`, and do not add large event logic directly to `Table.gd`.

## Score And Doubloons Rules

- `ShotEventSystem.gd` tracks ordered per-ball shot history.
- `ScoreSystem.gd` converts sunk-ball histories into Doubloon rewards.
- Current event tiers are foundational (`BANK`, `CHAIN`, `MULTI_CHAIN`, `ANOMALY_TOUCH`, `MULTI_SINK`), skilled (`KRAKEN_KICK`, `DOUBLE_BANK`, `THIN_CUT`, `CLUSTER_BREAK`, `LAST_GASP`, `POWER_SINK`, `SPLIT_THE_LOOT`), heroic (`CROSS_CORNER_BANK`, `FULL_TABLE_KICK`, `POWDER_ROUTE`, `KRAKEN_CURRENT`, `LONG_HAUL`), and legendary (`TRIPLE_BANK`, `CANNON_CHAIN`, `TREASURE_SNARE`).
- Sunk-ball scoring should use the ball's own event history, not unrelated global shot events.
- `MULTI_SINK` applies to the second and later object balls sunk in the same shot, not retroactively to earlier popups.
- `MULTI_CHAIN` is repeatable and represents additional causal chain depth beyond the first `CHAIN`.
- Score popups should remain pocket-side, arcade-readable, and tied to the captured pocket.
- Foundational, Skilled, Heroic, and Legendary rewards should route into evolving pocket-side score stacks instead of noisy repeated itemized labels.
- Stack totals count upward rather than using multiplier text. Tier identity comes from stack styling, color, glow, subtitle text, lane placement, and yield rules.
- Lower-priority stacks may fade/yield when stronger tier moments appear nearby; Legendary should remain the most prominent and least likely to yield.
- The old popup path should not be used for implemented tier events unless a future/unknown reward intentionally stays outside the stack architecture.
- Drop/spawn notifications may still use top/center callouts; scoring feedback should not return there unless explicitly requested.
- Pocket Streak tracks repeated object-ball sinks into the same pocket during one shot. It is separate from `MULTI_SINK`, uses same-pocket scoring context, awards immediately through normal Doubloon flow, and logs compact HudFeed flavor lines.
- Wayfinder Current can score eligible current-caused sinks through a focused current snapshot path without pretending a normal cue shot is active.
- Treasure claims award a large Doubloon payout through the normal award flow while preserving double-award safety.
- Quartermaster, Kraken Boon, and Sunken Spoils reroll spending are not score awarding. Core Kraken Interventions spend banked Charges. Purchases should not emit `doubloons_awarded`, feed Kraken Intervention progress, revive BallDrop progress, or appear as sink-score rewards.
- Run Stats tracks positive Doubloons earned separately from Doubloons spent and Doubloons lost to penalties. Purchases are spending, not "lost" score.
- Do not add coin sprays, progression, or large score VFX without permission.
- Normal gameplay reward drops should come from player-chosen Kraken Intervention/Table Event purchases, not automatic score-triggered BallDrop progress.

## Shot Event Philosophy

Shot events reward recovery, geometry, improvisation, chaos control, anomaly-assisted creativity, and legendary moments. The goal is not strict billiards simulation realism; the goal is readable arcade billiards mythology where the player understands why a wild shot mattered and why the table celebrated it.

## Quartermaster, Reserve, And Placement Rules

- Quartermaster currently presents three rotating tactical offers selected from the purchasable item pool through the live gameplay-mounted `QuartermasterHUD.gd` side rail.
- Current normal purchasable stock is Loose Object Ball x1/x3/x10, Wayfinder Ball x1/x2, and Powder Keg x1/x2.
- Quartermaster Refresh is a paid live-HUD action. It rerolls current offers, scales from 10 Doubloons upward by doubling, and cools down after shots without refreshing.
- Back Room Deal unlocks from high refresh pressure, is presented separately from normal stock, costs 250 Doubloons, and adds a chosen special item to Reserve when valid.
- Oath of Isolation makes Quartermaster purchases, refreshes, and Back Room Deals unavailable while active.
- Buying an offer fills the first empty Reserve slot instead of immediately entering placement mode.
- The old active shop purchasing flow inside `PauseMenu.gd` is retired/hidden; the pause menu only owns shell/debug UI around it.
- Quartermaster tooltips appear on hover and should stay compact. Permanent item-description panels should not return unless specifically requested.
- Reserve has exactly three slots in the current implementation.
- Reserve deployment clicks a filled slot, pauses gameplay if needed, enters `BallPlacementSystem.gd`, and keeps the item in the slot until valid confirm.
- Confirming a valid deployment places one ball and decrements quantity; the Reserve slot clears only when quantity reaches 0.
- Canceling deployment keeps the item and restores the previous pause state.
- Ball placement must use existing safe placement helpers and must not fight cue drag/release input.
- Cursor-attached Reserve icons and dotted tethers are presentation-only and should not affect placement validity.
- Do not bury future reward placement, tutorials, debug placement, or Treasure reward deployment inside Quartermaster; use `BallPlacementSystem.gd` and focused owners.

## Main Menu And Title Screen Rules

- `MainMenu.tscn` / `MainMenu.gd` are separate from gameplay scenes and own title-screen presentation and menu input only.
- The title screen uses layered authored art: background image, animated overlay passes, foreground image, fog, then menu UI.
- Star twinkles and ocean shimmer should render behind ship/tentacle foreground silhouettes; fog can remain above the foreground if it reads naturally.
- Title-screen overlays must remain lightweight and presentation-only: draw code or simple UI nodes, no heavy shaders or particle systems unless explicitly requested.
- Start Run should load the existing gameplay scene without turning `Main.gd` into a large app shell.
- Options is a real reusable menu with Audio sliders and is reachable from main menu and pause.
- Run History and Cue Locker are focused Main Menu panels with their own presenter scripts.
- Menu polish should not touch gameplay, pause/debug architecture, scoring, Kraken Intervention, Quartermaster, Reserve, or anomalies.

## Presentation And HUD Rules

- The player-facing intervention meter is the horizontal bottom-center `KRAKEN INTERVENTION` meter, with multi-charge segment progress, progress count below/left, percentage to the right, theatrical tally-up, and a nearby authored ready button using `assets/ui/kraken_intervention_button.png`.
- Passage and Kraken Request information should remain compact and atmospheric, with tooltips sourced from event/request metadata rather than hardcoded HUD text.
- Active Oaths should show a compact HUD indicator while active, with tooltip details from `OathSystem.gd`.
- Active Kraken Boons should show in the right-side display-only Boon HUD, not as clickable purchase controls.
- Sunken Spoils should show compact live progress and use its modal reward panel only when a reward is ready after shot resolution.
- Run Stats can be opened from a small top-left ledger button without pausing gameplay.
- The BALLS/SUNK run ledger cluster belongs with the lower Kraken Intervention HUD group, not with table geometry.
- The intervention menu title is `Request Kraken Intervention...`; keep it compact, centered over the playfield, and styled as an ominous tactical choice rather than a full-screen shop.
- `HudFeed.gd` owns the borderless bottom-left rolling feed. It should read like a captain's log/ship chatter, support multiline wrapping, fade older entries, and allow hover-scroll review.
- Quartermaster shop presentation is mounted live on the right-side gameplay rail. It should visually match Reserve slot icon language and use hover tooltips instead of permanent descriptions.
- Standard object balls use solid, readable, moodier arcade colors rather than visible numbers or stripe-state rolling experiments.
- The eight ball should remain gameplay-identical to regular object balls but visually distinct through the obsidian body and draw-only floating ethereal sigil.
- The ship-floor background and table decor are presentation-only. Floor/decor art must sit behind gameplay/HUD layers and must never affect collision, pockets, rails, cue input, scoring, or spawn safety.
- Table decor randomization should reference only assets that still exist; removed top-left/top-right prop variants should not be revived without restoring the assets.
- Keep UI font changes shared where practical, but tune per UI category for clipping/readability. Do not force HudFeed's small captain-log sizing onto larger menu/card text.

## Debug And Test Controls

- Modular debug panels should remain draggable, pause-safe, and hidden-work gated.
- The pause menu keeps debug controls hidden behind Dev Options. Dev Options content is scrollable so all controls remain reachable.
- The pause/debug menu exposes temporary Event Test Button checkboxes for Wayfinder Current and Broadside Attack. They should be off by default and debug-only.
- The right-side `Current` / `Broadside` test buttons call the same event behavior as real Table Events while bypassing only cost/readiness. They must not spend Doubloons, refill Kraken Intervention, alter offer state, or duplicate event logic.
- Useful current debug surfaces include Table Event Charges/segment index/goal/progress/pending/readiness/offers, Contraband odds/roll/source force controls, Boon activation/expiry controls, Reserve stack tests, Sunken Spoils progress/reward/reset controls, table debris spawn/collision controls, Oath Testing controls, Pocket Streak multiplier/queue/audio/whirlpool counters, Wayfinder Current carriers/affected/transfers/current-caused sinks, cue modifier suppression readouts, and Pocket Streak audio cooldown/player-pool state.
- Boon Dev Options include Activate Long Sight, Activate Kraken's Patience, Activate Deep Ledger, Activate Iron Wake, and Expire All Boons.
- Reserve stack Dev Options include Add Object Ball x3, Add Object Ball x10, Add Wayfinder x2, Add Powder Keg x2, and Add Cannon Ball x2.
- Sunken Spoils Dev Options include Advance Spoils Progress +1, Trigger Spoils Reward, and Reset Spoils.
- Debug buttons and panels must consume their own intentional clicks without stealing cue dragging outside their active rectangles.

## Audio Rules

- Ball-to-ball collision audio is event-driven from meaningful collision reports, not continuous scanning.
- `BallAudioSystem.gd` owns pooling, stream selection, pitch variation, volume scaling, and cooldown/spam filtering.
- Tiny settling contacts should remain filtered so high ball counts do not become machine-gun audio.
- Gameplay music uses a dedicated low-volume loop owner and must stay separate from SFX.
- Music's job is atmosphere and momentum, not dominance. Keep it low enough that collisions, Pocket Streaks, intervention cues, scoring feedback, and anomaly tells stay readable.
- Pocket Streak audio uses its own finite audio clip, fixed player pool, cooldown safeguards, pitch/volume caps, and dedicated reverb bus. It must not use `AudioStreamGenerator`, create unmanaged players, or route through collision audio.
- Collision audio, Pocket Streak audio, UI/menu audio, and music should remain separate enough that one system cannot exhaust or destabilize another.
- Audio should feel responsive to visible impact timing, but must not change collision math, cue feel, shot velocity, scoring, or anomaly behavior.
- Add rail, pocket, UI, or anomaly-specific audio only in focused future passes.
- `AudioSettings.gd` may change bus volumes from Options; it should not change playback logic or route-specific audio ownership.
- Web export audio should prioritize basic music/SFX compatibility. Web-specific fallbacks may disable or simplify unsupported paths; procedural Intervention tally tick audio and Pocket Streak reverb/effects may be disabled on Web while base audio remains. Windows can keep richer audio where supported.
- Browser/mobile web currently runs, but mobile control polish is not an official target yet. Future web/mobile QoL may need an on-screen pause/menu button.

## Performance Rules

- Stopped-ball filtering exists and should be preserved.
- Ball-vs-ball broad-phase spatial grid exists and should be preserved.
- Rail checks and pocket checks should run only for moving gameplay-active balls.
- Performance overlay/debug tools exist in `DebugOverlay.gd` and use requested-section snapshots from `Table.gd`, `BoundarySystem.gd`, `PocketSystem.gd`, `AimPreview.gd`, `WayfinderSystem.gd`, `PowderKegSystem.gd`, `AnchorBallSystem.gd`, `CannonBallSystem.gd`, `TreasureBallSystem.gd`, `EmbezzlerSystem.gd`, `BallDropSystem.gd`, `TableEventSystem.gd`, `PocketStreakSystem.gd`, `PocketStreakPresenter.gd`, `QuartermasterSystem.gd`, `ReserveSystem.gd`, `OathSystem.gd`, `RunStatsSystem.gd`, and `TableObstacleSystem.gd` when relevant.
- Kraken Intervention should stay shot/event-driven. Do not reintroduce automatic score-triggered drop spawning as hidden per-award churn.
- Table Event offer generation is weighted/unique and happens at decision moments, not continuously.
- Wayfinder Current is intentionally chaotic, but still uses localized event triggers, lifetime/transfer-depth safety, conservative eligibility, and draw-only readability hooks.
- Pocket Streak whirlpool/threat tells are localized presentation only and must not become hidden suction/force updates. No gameplay pull exists yet by design; if that ever changes, it needs a named gameplay pass with physics/pocket validation.
- HudFeed should keep message history and wrapping lightweight; it is a readable log, not a gameplay scanner.
- Anchor is now state/event-driven curse-seed gameplay, not a continuous force-field simulation. Do not reintroduce per-frame broad pull scans as Anchor's identity.
- Embezzler is capped and decision/event-driven: it may track aim pressure and reposition while active, but escape decisions should remain once-per-shot and not become frame-loop random roll spam.
- Score celebrations should coalesce through evolving stack presentation so high-chaos scoring creates fewer independent UI labels/tweens.
- Hidden debug panels/overlays should not format text or refresh panel content every frame. If no modular panels and no full overlay are visible, debug formatting work should be minimal.
- Do not remove counters or make them misleading during optimization.
- Do not add spatial partition rewrites or alternate physics engines without a focused request.
- Do not solve chaos by preventing chaos. Large earned chain reactions and high ball counts are intended.
- Do not hard-cap normal gameplay ball counts as the primary optimization strategy unless explicitly requested.
- Keep physics/gameplay authoritative and correct. Degrade visual effects first under load.
- Prefer event/state-driven updates over continuous rescanning. Systems should track meaningful state changes when practical instead of rebuilding full-table answers every frame.
- Quartermaster stock refresh should be deterministic/event-driven rather than timer-driven frame churn.
- Table obstacle collision should use cached authored polygon data, moving-ball checks, and broadphase rejection before detailed circle-vs-polygon work.
- Reserve deployment presentation, title-screen atmosphere, fake-3D shake, Treasure legs, Cannon heat, and Quartermaster refresh glow should stay draw-only/lightweight.
- Hover tooltips and hover-only UI should respect the shared cue-drag suppression state so active cue dragging keeps gameplay mouse ownership.
- Collision audio should reuse pooled players and filter micro-collisions so SFX scales with chaos.
- Coalesce repeated work before reducing gameplay ambition or visual fidelity. Input/event spam should mark systems dirty, then a single owner should process the newest state once per frame or once per relevant physics step.
- Optimization should preserve readability as well as raw performance; a faster effect that hides cause/effect relationships is usually not a good trade.
- AimPreview rebuilds are the canonical example: mouse/input events should not trigger dozens of same-frame prediction rebuilds; `Table.gd` should collapse them into one accurate rebuild without tolerance caching that lies about grazes.
- Good first optimization targets include hidden debug formatting, particles, trails, aura effects, popup labels, redraw frequency, prediction rebuild frequency, pooled audio, pooled/reused UI effects, and offscreen or low-priority visual simplification.
- Debug/stress testing should continue to support 100+ balls.

## Project Brain And Debug Media

- `project_brain/` is generated/reference-only and is not gameplay source of truth.
- `project_brain/debug_media/` stores visual debugging references, performance captures, feel/polish references, reproduction clips, and comparison screenshots/videos.
- Future sessions should check relevant `debug_media` clips or screenshots when investigating feel, prediction, anomaly, UI, or performance issues.
- `debug_media` is reference material only. Do not treat it as gameplay code, scene data, or authoritative behavior.
- Always verify conclusions from Project Brain or debug media against real source files, scenes, and `AGENTS.md` before changing behavior.

## Development Rules

- Keep the project small, playable, and polished.
- Prefer simple, beginner-readable GDScript.
- Keep scripts modular; avoid dumping new systems into `Table.gd`.
- Prefer functions under 60 lines.
- Add short comments for important ownership boundaries and non-obvious math.
- No major rewrites without explicit permission.
- No cleanup/refactor pass should intentionally alter gameplay feel.
- Avoid broad architecture abstractions until repeated patterns prove they are needed.
- Keep exports, APKs, zips, and generated builds out of Git.
- Commit after stable milestones, especially after playable checkpoints, extractions, and successful tuning passes.

## Implementation Review Expectations

For meaningful gameplay or system changes, include a short implementation review after the change summary. Keep it concise and focused on architecture ownership, feel preservation, scalability, and validation. Prefer explaining why a system owns behavior, not only what changed.

Suggested review structure:

1. Ownership / boundaries
- List which systems/files were touched.
- Explain why those systems were the correct owners.
- Name systems intentionally not expanded, especially `Table.gd`, `ScoreSystem.gd`, physics, cue, prediction, pockets, or anomaly systems when relevant.

2. Behavior changes
- State what gameplay/player-visible behavior changed.
- State what behavior was intentionally preserved.

3. Performance implications
- Note any new counters/debug info added.
- State whether the change adds continuous per-frame work.
- State whether the change degrades gracefully under chaos/high ball counts.

4. Risks / future watch items
- Call out possible edge cases.
- Call out scalability concerns.
- Name areas likely to need future tuning.

5. Validation
- Report static validation.
- Report gameplay validation.
- Report overlay/debug observations when available.
- State whether Godot was actually launched.

Avoid generic filler summaries. The review should reinforce Kraken An Eight Ball's ownership boundaries, preservation rules, and "support chaos gracefully" performance philosophy.

## Next Major Goal

Continue stabilizing the Passage-centered run loop and its supporting economy:

better shots -> more Doubloons and completed Kraken Requests -> Passage reduction -> earned intervention opportunities and table tools -> player-chosen chaos -> stronger scoring opportunities -> successful Passage completion -> Kraken Favor and cue progression.

The first playable Passage, Oath, Quartermaster Refresh, Back Room, Run History, Kraken Favor, Cue Locker, and cue modifier foundations now exist. Next passes should focus on playtest clarity, balance feel, readable progression, and keeping feature logic in focused systems instead of `Table.gd`.

Current Kraken Intervention offers are:

- Cheap Cargo: 1 Charge
- Loose Cargo: 2 Charges
- Wayfinder's Favor: 2 Charges
- Powder Cache: 2 Charges
- Cannon Warning: 3 Charges
- Wayfinder Current: 4 Charges
- Broadside Attack: 5 Charges

Current Kraken Boons are Long Sight, Kraken's Patience, Deep Ledger, and Iron Wake. They appear in the separate Boon row below the three normal Intervention cards and cost Charges + Doubloons.

The player-facing intervention meter is the horizontal bottom-center `KRAKEN INTERVENTION` meter, while Passage/Kraken Request state is the run-objective HUD. The old vertical BallDrop meter and automatic reward spawning are retired/gated legacy support unless explicitly re-enabled for a focused test.

Cue ball and eight ball sinking no longer end the game as this loop comes online:

- Each costs 25 Doubloons.
- Cue-ball sinks still remove one eligible object ball from the table as the physical penalty.
- Eight-ball sinks now try to transform one eligible existing object ball into an Anchor curse seed instead of using the old remove-ball-only penalty path.
- Cue-ball penalty removal still uses a simple scale/fade animation; a true reversed ball-drop animation can replace it later.

## Current Architecture Direction

`Table.gd` should continue shrinking into a coordinator, but not at the cost of shot feel.

Lowest-risk future extractions are UI/presentation helpers or clearly bounded gameplay systems. Highest-risk extraction remains `BallPhysics`; leave it in `Table.gd` until there is a focused plan, a stable checkpoint, and a verification pass.

When adding a feature, first ask: which existing system owns this? If no system owns it cleanly, create a small focused system instead of expanding `Table.gd`.
