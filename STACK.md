# Tech Stack

## Engine

- Godot 4
- GDScript
- 2D `Node2D` scenes with custom arcade billiards physics
- Windows-first local prototype, Android later

## Scenes And App Shell

- `scenes/MainMenu.tscn` / `scripts/MainMenu.gd` owns the atmospheric title screen and top-level menu flow.
- `scripts/MainMenuRunHistoryPanel.gd` owns Main Menu Run History presentation.
- `scripts/MainMenuCueLockerPanel.gd` owns Cue Locker presentation.
- `scripts/OptionsMenu.gd` owns the reusable Options panel used by main menu and pause.
- `scenes/Main.tscn` remains the gameplay scene loaded by Start Run.
- `scripts/Main.gd` stays a small app shell for fullscreen toggling, high-level UI/system connections, run completion flow, and cue modifier snapshot distribution.
- Pause UI lives under the gameplay HUD/CanvasLayer and is separate from title-screen ownership.

## Physics And Geometry

- Real ball physics is custom/manual and currently lives in `scripts/Table.gd`.
- Balls are authored/presented as nodes, but gameplay movement and collision response are not driven by `RigidBody2D`.
- Ball-vs-ball broad-phase spatial partitioning supports high ball counts.
- Stopped-ball filtering keeps settled table states cheap.
- Boundaries and pockets are scene-authored source of truth, loaded by `BoundarySystem.gd` and `PocketSystem.gd`.
- `BallPlacementSystem.gd` uses existing safe placement helpers for Reserve/manual placement without changing physics or geometry rules.
- `TableObstacleSystem.gd` uses authored `CollisionPolygon2D` data from `TableObstacle.tscn` for custom ball-vs-debris collision, not Godot physics simulation.
- Obstacle collision caches transformed polygon data and uses broadphase rejection before detailed checks.

## Prediction, Cue, And Presentation

- `AimPreview.gd` owns side-effect-free prediction and polished aim presentation.
- Prediction uses swept checks and broad-phase filtering so the guide remains accurate without scanning every ball every step.
- `Table.gd` coalesces aim-preview rebuilds so input spam becomes one accurate rebuild per frame while dragging.
- Brass Tip's cue power modifier applies through the same effective shot-power multiplier used by actual launch and aim preview.
- `CueController.gd` owns cue presentation/animations and visual cue loadout accents, not shot math.
- `TableImpactShakeSystem.gd` owns presentation-only fake-3D table impact shake; gameplay positions and HUD/debug UI do not move.
- Draw-only anomaly visuals in `Ball.gd` include Cannon heat, Treasure/Embezzler legs, Wayfinder Current carrier tells, and the eight-ball sigil.
- `WayfinderCurrentPresenter.gd` owns draw-only initial current pulses and transfer flashes.
- `PocketStreakPresenter.gd` owns queued multiplier presentation, X4+ whirlpool/threat tells, and Pocket Streak audio.
- `MainMenuPresentationOverlay.gd` owns draw-only title-screen atmosphere.
- `ReserveDeploymentPresenter.gd` owns draw-only Reserve cursor icon/tether presentation.
- `QuartermasterOfferRefreshEffect.gd` owns the presentation-only fresh-stock glow/shimmer.

## UI, Debug, And Pause

- `PassageHUD.gd` owns compact live Passage / Kraken Wants presentation and request reroll forwarding.
- `OathHUD.gd` owns the active Oath indicator and tooltip.
- `TableEventMeter.gd` owns the horizontal bottom-center `KRAKEN INTERVENTION` meter and ready icon.
- `TableEventMenu.gd` owns the compact `Request Kraken Intervention...` offer menu and Oath choice panel for single-offer replacement.
- `HudFeed.gd` owns the bottom-left rolling captain's-log feed with hover review and multiline wrapping.
- `RunStatsHUD.gd` owns the live top-left Run Stats ledger overlay.
- `RunLedgerHUD.gd` owns the compact lower-HUD BALLS/SUNK counter cluster.
- `QuartermasterHUD.gd` owns the live right-side side-rail shop UI, refresh button, Back Room button, and hover tooltips.
- `BackRoomDealPanel.gd` owns Back Room Deal option presentation only.
- `PauseMenu.gd` owns pause-menu shell behavior, Resume/Options/End Run, Run Stats view, Dev Options, debug panel toggles, and temporary debug controls.
- `DebugOverlay.gd` owns the full F3 overlay, modular debug-panel wiring, and right-side debug test buttons.
- `DebugPanel.gd` provides the draggable pause-safe panel shell.
- UI panels, Reserve slots, Quartermaster slots, intervention icons, menus, and debug buttons consume their own intentional clicks without stealing an already active cue drag.
- Hover-only UI should respect shared cue-drag suppression while gameplay owns the mouse.

## Scoring And Shot Events

- `ShotEventSystem.gd` owns causal shot history and never awards Doubloons directly.
- `ScoreSystem.gd` owns Doubloon values, total updates, scoring breakdowns, Treasure claim payout routing, and evolving pocket-side score stacks.
- Implemented foundational events: `BANK`, `CHAIN`, `MULTI_CHAIN`, `ANOMALY_TOUCH`, `MULTI_SINK`.
- Implemented skilled events: `KRAKEN_KICK`, `DOUBLE_BANK`, `THIN_CUT`, `CLUSTER_BREAK`, `LAST_GASP`, `POWER_SINK`, `SPLIT_THE_LOOT`.
- Implemented heroic events: `CROSS_CORNER_BANK`, `FULL_TABLE_KICK`, `POWDER_ROUTE`, `KRAKEN_CURRENT`, `LONG_HAUL`.
- Implemented legendary events: `TRIPLE_BANK`, `CANNON_CHAIN`, `TREASURE_SNARE`.
- Foundational/Skilled/Heroic/Legendary rewards coalesce into tier-specific pocket-side stacks with count-up totals, subtitles, colored glow identity, lane management, and low-priority yield/fade behavior.
- `PocketStreakSystem.gd` tracks same-pocket object-ball streaks during a shot and awards X2/X3/X4+ bonuses separately from `MULTI_SINK`.
- `PocketStreakPresenter.gd` queues multiplier notifications and owns all whirlpool/threat-tell presentation; there is deliberately no suction/pull gameplay yet.
- The old score popup path is retained only for future/unknown rewards or explicitly non-stack presentation cases.

## Passage, Oaths, And Progression

- `PassageSystem.gd` owns current-run Passage requirement, remaining Passage math, active Kraken Request, request rewards, request completion, request reroll pressure, and successful run completion state.
- First-pass Passage requirement is 10000.
- `EventMetadata.gd` centralizes event/request labels and descriptions.
- `OathSystem.gd` owns Oath definitions, active state, timers, completion/failure, Quartermaster lock state, cue modifier suppression state, and Oath debug helpers.
- Current normal Oath choice pool for Intervention replacement is Oath of Urgency, Oath of Isolation, and Oath of Humility.
- `RunStatsSystem.gd` owns current-run aggregate stats and shared row metadata. It does not persist history.
- `RunHistorySystem.gd` persists finalized run records to `user://run_history.json` and keeps the most recent 25.
- `ProgressionSystem.gd` persists Kraken Favor and cue progression data to `user://progression.json`.
- Successful Passage awards Kraken Favor; abandoned End Run does not.

## Economy And Intervention

- `ScoreSystem.gd` awards Doubloons from sunk-ball shot histories and emits award amounts.
- `RunStatsSystem.gd` splits Doubloons Earned, Doubloons Spent, and Doubloons Lost to penalties.
- `TableEventSystem.gd` tracks shot-earned Doubloons toward Kraken Intervention.
- Kraken Intervention is an active chosen-chaos economy spine, not an automatic score-to-spawn reward drip.
- Current Kraken Intervention threshold is 30 Doubloons earned during a shot.
- Reaching threshold creates a pending intervention; readiness is gated until cue control returns.
- The event menu shows up to three unique weighted offers.
- Purchases spend Doubloons through the safe spend path and do not refill the intervention meter.
- Single-offer replacement swears an Oath and rerolls only the selected slot without spending Doubloons or executing the offer.
- `SpawnSystem.gd` performs actual drops/launch setup for event consequences.
- `BallDropSystem.gd` is backstage legacy/gated support for automatic reward drops, plus active cue/eight-ball penalty handling and debug plumbing.

Current intervention pool:

- Cheap Cargo: Common, weight 10, cost 20, drops 5 regular object balls.
- Loose Cargo: Common, weight 8, cost 40, drops 10 regular object balls.
- Wayfinder's Favor: Uncommon, weight 5, cost 55, drops 2 Wayfinder Balls.
- Powder Cache: Uncommon, weight 4, cost 75, drops 3 Powder Kegs.
- Cannon Warning: Rare, weight 2, cost 90, drops 1 Cannon Ball.
- Broadside Attack: Rare, weight 1, cost 140, the first authored staged intervention milestone, dropping Powder Kegs in lanes and then Cannon Balls after a delay.
- Wayfinder Current: Rare, weight 3, cost 120, drops 2 Wayfinders and triggers temporary current behavior.

Loose Cargo Contraband uses one event-level roll. Base chance is 1%, Lucky Chalk can raise it to 2% while active, and the weighted table is Wayfinder Ball 50, Powder Keg 30, Treasure Ball 15, Cannon Ball 4, Embezzler 1.

## Quartermaster, Reserve, And Back Room

- `QuartermasterSystem.gd` owns inventory, prices, affordability, active rotating offers, paid refresh scaling, shot-decay cooldown, and Quartermaster access blockers.
- `QuartermasterHUD.gd` presents those offers as a compact gameplay side-rail shop, not a pause-menu shop.
- Current active normal offers are drawn from Loose Object Ball, Wayfinder Ball, and Powder Keg.
- Successful purchases spend Doubloons and fill the first empty `ReserveSystem.gd` slot.
- `ReserveSystem.gd` owns three slot contents and deployment state.
- Reserve deployment uses `BallPlacementSystem.gd`; confirm places and clears the slot, cancel keeps the item.
- Quartermaster Refresh starts at 10 Doubloons, doubles after refreshes, and cools down after shots.
- `BackRoomDealSystem.gd` unlocks Back Room Deal at refresh cost 80 and owns 250-Doubloon specific-item procurement into Reserve.
- Back Room selectable pool is Wayfinder Ball, Powder Keg, Treasure Ball, Cannon Ball, and Embezzler when available.
- Quartermaster, Back Room, and Reserve spending must not emit score-award signals or advance Kraken Intervention/BallDrop progress.

## Cue Locker And Cue Modifiers

- `CueProgressionSystem.gd` owns cue part definitions, unlock/equip validation, equipped loadout, cue snapshots, effect definitions, and active modifier snapshots.
- Cue parts are grouped by Body, Tip, Grip, Ferrule, and Chalk.
- Default unlocked loadout is Weathered Cue, Plain Tip, Sailcloth Grip, Plain Ferrule, and Plain Chalk.
- First unlockables are Blackwood Cue, Brass Tip, Wayfinder Wrap, Bone Ferrule, and Lucky Chalk.
- Current cue gameplay modifiers are generic modifier keys, not hardcoded item checks.
- Lucky Chalk modifies Loose Cargo Contraband chance.
- Wayfinder Wrap modifies Quartermaster refresh shot-decay.
- Bone Ferrule modifies Passage-adding failed Oath penalties.
- Blackwood Cue modifies Kraken Request Passage reduction.
- Brass Tip modifies initial cue shot power and aim preview through the same multiplier.
- Oath of Humility suppresses gameplay modifiers without changing equipment, visuals, or save data.

## Anomaly Systems

- `WayfinderSystem.gd` owns Wayfinder activation, guided redirects, and temporary Wayfinder Current carriers/transfers/scoring snapshots.
- `PowderKegSystem.gd` owns cue/Cannon-triggered Powder Keg explosions and particle bursts.
- `AnchorBallSystem.gd` owns the curse-seed Anchor rewrite: eight-ball sink seed creation, 1-3 chain links, leash constraints, cue-control-gated tightening, warning timer, spread, and collapse/counterplay. The retired continuous pull field is disabled.
- `CannonBallSystem.gd` owns Cannon Ball collision tuning, Powder Keg launch amplification, heavy-impact shake requests, and heat presence.
- `TreasureBallSystem.gd` owns Treasure's cautious aim-line perception, committed hide targets, soft scuttle behavior, and draw-only legs.
- Treasure scoring payout is handled through the normal ScoreSystem award flow when Treasure is sunk.
- `EmbezzlerSystem.gd` is separate from Treasure and owns one capped greed/thief anomaly: copied Doubloon storage, secret pocket, willingness from stored value plus aim pressure, once-per-shot hide-or-run decision, escape commitment, pocket roll, capture payout, and escape cleanup.

## Audio

- `AudioSettings.gd` owns Master/Music/SFX volume settings and `user://settings.cfg` persistence.
- `BallAudioSystem.gd` owns ball-to-ball collision sounds.
- Collision audio is event-driven from meaningful impact reports rather than scanned continuously.
- Audio playback uses a small pool of `AudioStreamPlayer` nodes, randomized hit streams, pitch variation, impact-scaled volume, and cooldown/spam filtering.
- `PocketStreakPresenter.gd` owns Pocket Streak audio with a finite clip, fixed pool, cooldowns, pitch/volume caps, and a dedicated reverb bus.
- `GameplayMusicSystem.gd` owns low-volume looping gameplay music and keeps music separate from SFX systems.
- Gameplay music should sit under the table action; collisions, intervention cues, Pocket Streaks, scoring, and anomaly tells remain more important than music loudness.
- Do not reintroduce `AudioStreamGenerator` for Pocket Streak audio.
- Audio should never change physics, collision math, cue feel, scoring, or anomaly behavior.

## Art And UI Assets

- The project uses `NotJamOldStyle11.ttf` broadly for player-facing UI, tuned per UI category.
- Gameplay uses the full ship-floor background behind table and props.
- Remaining table decor randomizes as presentation-only dressing.
- Standard object balls are numberless solid colors with a readability-first moody palette.
- The eight ball has draw-only obsidian/ethereal-sigil presentation while keeping identical gameplay behavior.
- Main menu visuals are layered authored art plus lightweight draw-only atmosphere.
- Cue equipment can add draw-only cue accents, but cue visuals do not imply gameplay effects unless a cue modifier explicitly owns one.

## Debug

- Debug panels expose performance, physics, anomaly, Table Event, Contraband, debris, Oath, cue modifier, Pocket Streak, Wayfinder Current, audio, Quartermaster, and Reserve snapshots.
- Dev Options is scrollable and hidden behind the normal pause menu.
- Pause/debug controls can reveal Wayfinder Current and Broadside debug test buttons.
- Debug event buttons bypass only cost/readiness and call the same event behavior as real Table Events.
- Oath Testing controls call focused `OathSystem.gd` debug helpers and should not trigger full shot systems.
- Debug test controls must not refill Kraken Intervention, spend Doubloons, or duplicate event logic.

## Optimization Philosophy

- Support chaos gracefully instead of preventing chaos.
- Large earned chain reactions and 100+ ball stress tests are intended.
- Coalesce repeated work, avoid unnecessary redraws, and use broad-phase/spatial filtering before reducing gameplay ambition.
- Gate hidden debug work; invisible panels should be logically cheap, not merely transparent.
- Prefer event-driven intervention readiness, stock refresh, collision audio, shot-event recording, Oath timers, and placement state changes over passive per-frame scans.
- Anchor should remain state/event-driven curse-seed gameplay rather than returning to continuous pull scans.
- Embezzler should stay capped and decision/event-driven; aim pressure and score gain should influence future willingness without triggering repeated same-shot roll spam.
- Obstacle collision should use cached authored polygon data and broadphase rejection, not repeated per-ball polygon rebuilding.
- Score presentation should coalesce label/tween work through stack updates before considering visual suppression.
- Pocket Streak whirlpool and threat tells should stay localized/presentation-only until a future explicit suction design pass. Do not treat the lack of pull as a bug.
- Degrade visuals first under load: particles, trails, aura effects, popup labels, fake-3D shake, whirlpool tells, and other presentation layers.
- Preserve readability as well as FPS; faster effects that hide cause/effect relationships are usually the wrong trade.
- Keep gameplay/physics authoritative and correct.

## Do Not

- Do not use C# unless the project explicitly changes direction.
- Do not reintroduce procedural/fallback pocket or rail geometry.
- Do not move core physics out of `Table.gd` without a focused extraction plan and validation pass.
- Do not revive automatic score-triggered BallDrop progression unless explicitly requested; Kraken Intervention is the active chosen-chaos economy and Passage is the current run objective.
- Do not add Pocket Streak suction, pocket-radius changes, or velocity pull without an explicit gameplay pass.
- Do not use gameplay ball-count caps as the primary performance fix unless explicitly requested.
- Do not route shop/intervention/Back Room/refresh spending through score-award/progress signals.
- Do not put Reserve-specific visuals or Quartermaster-specific logic into `BallPlacementSystem.gd`.
- Do not let title-screen, debug UI, Options, Run History, Cue Locker, or decor changes touch gameplay systems.
- Do not let gameplay systems read raw progression save data or hardcode equipped cue item IDs.
- Do not commit exported builds, APKs, zips, or large generated artifacts.
