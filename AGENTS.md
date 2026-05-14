# Kraken An Eight Ball

## Project Identity

Kraken An Eight Ball is a Godot 4 / GDScript pirate-eldritch systemic arcade-chaos billiards prototype.

The project is now a playable escalation sandbox with multiple interacting systems. The current core loop is:

better play -> more score/Doubloons -> more score-tied ball drops -> more interactions and chaos -> survive an escalating table state.

Core pillars:

- Drag-and-release 2D billiards with custom arcade physics.
- Pirate/kraken table presentation and in-engine charm.
- Doubloons scoring driven by trick-shot event history.
- Pocket-side score celebrations instead of generic center-screen scoring spam.
- Score-tied ball drops that turn successful play into rising table pressure.
- Active anomaly balls: Wayfinder Ball, Powder Keg, Anchor Ball, Cannon Ball, and Treasure Ball experiments.
- Presentation-only fake-3D impact and heat/scuttle effects that add juice without moving authoritative gameplay geometry.
- Fast iteration over broad systems while preserving shot feel.

Target platforms:

- Windows first.
- Android later.

## Architecture Ownership

### `scripts/Table.gd`

Owns high-level coordination, shot lifecycle, early cue-control reclaim gating, authoritative ball list, current main physics loop, run state, callout queue, and event routing between systems.

Early cue reclaim belongs here because it is shot-lifecycle coordination, not cue presentation. Reclaim requires the cue ball to be stopped and valid, avoids reset/drop states, waits a short post-shot delay, uses lightweight moving-ball counts/speed buckets, blocks likely imminent cue-ball collisions, and does not revoke cue control after it has already been granted.

Does not own large new feature systems unless there is no cleaner option. New gameplay clusters should usually become system scripts and be coordinated from `Table.gd`.

`BallPhysics` intentionally still lives here. It is high-risk because it controls shot feel, collision response, rail events, pocket timing, Wayfinder event timing, and performance counters.

### `scripts/Ball.gd`

Owns individual ball identity, velocity/friction state, generated ball visuals, spawn/drop presentation state, trails, draw-only anomaly presentation such as Cannon heat and Treasure legs, and minimal anomaly identity/state flags such as `is_wayfinder`, `is_powder_keg`, `is_anchor_ball`, `is_cannon_ball`, `is_treasure_ball`, and `wayfinder_active`.

Does not own table-wide gameplay rules, scoring, spawning decisions, pocket logic, or anomaly systems beyond per-ball state that must live on the ball.

### `scripts/DebugOverlay.gd`

Owns debug menu UI, debug toggles, physics debug display, performance overlay formatting, overlay dragging, and hotkey display text.

Does not own gameplay counters themselves. `Table.gd` and systems provide snapshots; `DebugOverlay.gd` presents them.

### `scripts/CueController.gd`

Owns cue sprite/pivot presentation, idle motion, cue grab-zone hit testing, pullback visuals, and strike/recoil/settle animation.

Does not own shot power, shot velocity, aim prediction, or real ball movement.

### `scripts/AimPreview.gd`

Owns polished cue-ball aim line presentation, shot-power color, swept cue-ball preview collision checks, AimPreview-only broad-phase filtering, ghost cue-ball prediction, one-bank preview, hit-ball prediction line presentation, hit-ball first-collision stopping against rails/balls/pockets, visual-only endpoint markers, read-only Treasure Ball perception snapshots, and predicted-vs-actual shot path debug visualization.

Does not mutate real gameplay state. Prediction must stay side-effect-free and should use shared boundary/pocket helpers so preview stays aligned with real movement.

Aim preview rebuilds should be coalesced by `Table.gd`: input events mark the preview dirty, and a single centralized update performs at most one rebuild per frame while dragging. Do not reintroduce coarse angle/power tolerance reuse; graze shots need reliable rebuilds when the visible aim changes.

AimPreview.gd must remain prediction/presentation only. It must not change real physics, shot power, cue feel, scoring, anomalies, or spawn systems.

### `scripts/SpawnSystem.gd`

Owns cue ball start/reset helpers, starting rack/object-ball creation, reward spawns, debug ball spawns, safe spawn search, drop animation coordination, spawn-related callouts, regular anomaly pool odds, and Anchor priority spawn odds.

Does not own scoring, pocket consequences, shot lifecycle, physics tuning, score-tied reward decisions, or anomaly behavior after a ball exists.

### `scripts/WayfinderSystem.gd`

Owns Wayfinder activation/deactivation, guided-ball tracking, pocket cone selection, timed guidance, redirect cooldowns, and Wayfinder debug logging.

Does not own ball-to-ball collision response, pocket geometry, spawn chance, or general anomaly architecture.

### `scripts/PowderKegSystem.gd`

Owns Powder Keg cue-ball/Cannon contact explosions, radial push falloff, explosion particle bursts, one-shot explosion state, and Powder Keg debug/performance toggles.

Does not own ball-to-ball collision response, spawn chance, scoring values, pocket geometry, or general physics feel.

### `scripts/AnchorBallSystem.gd`

Owns Anchor Ball cursed-tide pull behavior, Anchor source/target rules, single strongest-current-per-target selection, contact-loop cooldowns, affected-ball marker reporting, Anchor debug visuals, visual aura caps, and Anchor performance counters.

Does not own ball-to-ball collision response, cue input, scoring values, prediction, pocket geometry, or SpawnSystem's reward-roll decisions.

### `scripts/CannonBallSystem.gd`

Owns the Cannon Ball anomaly boundary, Cannon-specific collision tuning, Powder Keg launch tuning, Cannon heavy-impact shake eligibility/cooldown, and moving Cannon heat-presence thresholds. Cannon Ball is currently debug-spawnable, visually heavy, harder to accelerate from normal/cue impacts, more forceful/persistent when it hits non-anomaly balls, amplified when launched by Powder Keg explosions, able to request subtle table thumps on qualifying heavy impacts, and visually marked by a draw-only red/orange heat glow and ember trail at high speed.

Future Cannon Ball passes may own Anchor pull tuning, Wayfinder guidance safeguards, regular spawn odds, and additional heat-presence polish, but those are not active yet.

Does not own global ball-to-ball collision constants, spawn odds, scoring values, cue input, prediction, pocket geometry, screen shake, or interactions with Anchor or Wayfinder.

### `scripts/TreasureBallSystem.gd`

Owns Treasure Ball tracking, read-only AimPreview perception state, committed hide target selection, aim-corridor crossing avoidance, pocket-aware hide/flee target filtering, and threat-scaled self-steering while Treasure is actively perceived by the aim-line corridor. Treasure Ball is currently debug-spawnable, visually distinct, uses capped soft-body/scuttle steering toward cover or a fallback flee target without overriding normal collisions, and can request draw-only fleeing-leg presentation from `Ball.gd`.

Does not own rewards, scoring values, spawn odds, pocket behavior, cue input, prediction math, broad physics, or procedural leg drawing. Future Treasure passes may add reward variants, but current Treasure behavior is identity/perception/committed hide-target/threat-scaled hiding movement, soft outgoing self-propelled collision nudges, quick self-braking when calm, and visual fleeing-state reporting only.

### `scripts/PocketSystem.gd`

Owns scene-authored pocket loading from `Table/Pockets`, pocket centers from `CollisionShape2D.global_position`, pocket radii from `CircleShape2D.radius`, pocket capture checks, pocket safety checks for spawning, and pocket performance counters.

Does not own scoring, rewards, ball removal consequences, or procedural/fallback pocket geometry.

### `scripts/BoundarySystem.gd`

Owns scene-authored boundary loading from `Table/Boundaries`, cached rail/jaw `CollisionShape2D` rectangles, boundary collision helpers, side-effect-free prediction helpers, reference rects, and boundary performance counters.

Does not own ball physics tuning, authored node placement, pocket checks, or procedural/fallback table geometry.

### `scripts/ShotEventSystem.gd`

Owns passive per-shot event history: `BANK`, `CHAIN`, `MULTI_CHAIN`, `ANOMALY_TOUCH`, and `MULTI_SINK`.

Does not award Doubloons, show UI, change gameplay outcomes, or alter physics. It stores causal shot history per ball so sunk-ball scoring can consume it later.

### `scripts/ScoreSystem.gd`

Owns Doubloons reward values, running Doubloons total, scoring breakdown debug logs, HUD total signal, and pocket-side score popup presentation.

Does not own shot event tracking, pocket capture, physics, anomaly behavior, reward spawning, score-tied ball drop decisions, shops, progression, or heavy VFX.

Current score presentation notes:

- Side-pocket score popup behavior is considered good and should be preserved unless specifically requested.
- Corner-pocket score popup layout is still under active refinement.
- Popups are pocket-centered and consume sink context from `PocketSystem`.
- Score values should not change during presentation-only passes.

### `scripts/BallDropSystem.gd`

Owns the score-tied ball drop architecture spine: enabled state, Doubloon progress toward earned drops, threshold tuning, deciding how many earned drops to queue after ScoreSystem reports awarded Doubloons, and cue/eight-ball sink penalty amount/message selection.

Does not own object-ball scoring values, score popup presentation, actual ball creation, spawn placement, drop animation, physics, or penalty removal animation. `SpawnSystem.gd` still performs actual drops, and `Table.gd` only coordinates pocket consequences and the placeholder penalty removal.

Current first-pass behavior:

- `ScoreSystem.gd` emits awarded Doubloon amounts.
- `BallDropSystem.gd` adds those amounts to `drop_progress`.
- When progress reaches `doubloons_per_drop`, it queues drops through `SpawnSystem.gd`.
- Leftover progress is preserved.
- Large scoring events can queue multiple drops.
- Legacy non-score gameplay reward drops are disabled by default so normal reward drops come from `BallDropSystem.gd`.
- Score-earned drops choose rotating themed callout messages from `BallDropSystem.gd`; debug/manual spawns can keep direct spawn labels.
- Cue-ball and eight-ball sinks apply a 25 Doubloon penalty through `BallDropSystem.gd` / `ScoreSystem.gd` without adding to drop progress.
- Cue-ball and eight-ball sinks reset those special balls, then `Table.gd` removes one eligible object ball as the penalty.

### `scripts/Main.gd`

Owns small app-shell behavior such as fullscreen toggling and top-level UI wiring.

Does not own table gameplay systems.

### `scripts/BallDropMeter.gd`

Owns player-facing progress presentation for the next score-earned ball drop.

Reads BallDropSystem progress signals/snapshots and renders a vertical right-side HUD meter with lightweight pulse/flash feedback.

Does not own drop rules, scoring, spawn timing, debug overlay counters, or gameplay state.

### `scripts/TableImpactShakeSystem.gd`

Owns presentation-only fake-3D table impact shake for Powder Keg explosions and Cannon Ball heavy impacts, including table-art draw offsets and temporary ball shimmy offsets.

Does not own gameplay positions, physics velocities, camera movement, HUD/debug UI, scoring, spawn timing, or anomaly force tuning. It should stay inactive when no shake is playing and must never move authoritative ball/table geometry.

Fake-3D presentation systems should move only drawn presentation layers or draw offsets. HUD/debug UI should remain readable, floor/background should stay still or barely move, and any ball shimmy must be visual-only.

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
- `CannonBallSystem.gd` currently owns debug-spawnable Cannon identity, collision tuning, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat-presence thresholds.
- `TreasureBallSystem.gd` currently owns debug-spawnable Treasure identity tracking, AimPreview perception reporting, committed hide target selection, gentle hiding movement while perceived, and visual fleeing-state reporting.

Pattern:

- `Table.gd` reports physics/gameplay events.
- Anomaly systems react to those events.
- `Ball.gd` stores only identity/state that must live on the ball instance.
- Spawn odds and creation remain in `SpawnSystem.gd`.
- Avoid hardcoding new anomaly behavior directly into `Table.gd`.
- Do not create a broad abstract anomaly framework until multiple anomalies prove the need.

Current anomaly rules:

- Wayfinder activates from cue-ball contact, then can guide eligible object balls toward reachable pockets during collision-driven redirects.
- Powder Keg explodes on cue-ball or Cannon Ball contact only; normal balls still do not trigger it.
- Powder Keg pushes nearby balls outward with falloff, then removes itself from the table.
- Powder Keg launches Cannon Balls with Cannon-owned impulse amplification and a conservative Cannon launch speed cap.
- Powder Keg requests a short presentation-only table impact shake; table art shakes most, balls receive draw-only shimmy, and HUD/debug UI stays still.
- Powder Keg particle bursts should look juicy and readable, but debug/quality controls should allow particles to degrade safely under load.
- Anchor pulls object balls only. It does not affect the cue ball.
- Anchor does not pull other Anchor balls, though Anchor balls still physically collide normally.
- Overlapping Anchor fields do not stack on the same target. Each target ball follows one strongest effective Anchor current per update/substep, with nearest Anchor as the tie-breaker. Anchor overlap debug counters should report skipped overlaps, max Anchors considered per target, and targets with overlap candidates.
- Moving Anchor balls use full pull strength.
- Stationary Anchor balls remain active field sources but use half pull strength.
- Anchor has an inner dead zone and a per Anchor/target post-collision pull cooldown to prevent gravity-loop chase bumps.
- Anchor uses independent reward spawn logic before the regular anomaly pool: 3% when the table has 40 or fewer balls, and 30% when the table has more than 40 balls.
- Cannon Ball is currently debug-spawn only and visually reads as dark heavy iron with ember detail.
- Cannon Ball has collision modifiers against non-anomaly balls only: it gains reduced velocity when hit, retains more velocity when driving into a ball, and transfers stronger force above a minimum impact speed.
- Cannon Ball can trigger Powder Keg explosions and receives amplified Powder Keg launch impulse.
- Cannon Ball qualifying heavy impacts can request short, subtle table-impact shake through `TableImpactShakeSystem.gd`, with cooldown to prevent shake spam.
- Cannon Ball high-speed heat presence is draw-only in `Ball.gd`, tuned by `CannonBallSystem.gd`, and visually capped so chaos degrades presentation before gameplay.
- Cannon Ball currently has no regular spawn odds and no Cannon-specific special interactions with Anchor or Wayfinder.
- Treasure Ball is currently debug-spawn only and behaves physically like a normal object ball.
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
- Treasure Ball currently has no special scoring, reward payout, or regular spawn odds.

Possible future anomaly systems:

- `EtherealSystem.gd`

## Ball Drop System Boundary

The score-tied ball drop loop should stay in its own focused system, `BallDropSystem.gd`, instead of expanding `ScoreSystem.gd` or `Table.gd`.

Preferred flow:

- `ShotEventSystem.gd` / `ScoreSystem.gd` report score events.
- `BallDropSystem.gd` decides drop rewards from those score events.
- `SpawnSystem.gd` performs the actual drops and safe placement.
- `Table.gd` coordinates only.

Do not bury score-tied reward decisions inside `ScoreSystem.gd`, and do not add another large reward subsystem directly to `Table.gd`.

## Score And Doubloons Rules

- `ShotEventSystem.gd` tracks ordered per-ball shot history.
- `ScoreSystem.gd` converts sunk-ball histories into Doubloon rewards.
- Sunk-ball scoring should use the ball's own event history, not unrelated global shot events.
- `MULTI_SINK` applies to the second and later object balls sunk in the same shot, not retroactively to earlier popups.
- `MULTI_CHAIN` is repeatable and represents additional causal chain depth beyond the first `CHAIN`.
- Score popups should remain pocket-side, arcade-readable, and tied to the captured pocket.
- Drop/spawn notifications may still use top/center callouts; scoring feedback should not return there unless explicitly requested.
- Do not add coin sprays, shops, progression, or large score VFX without permission.
- Normal gameplay reward drops should come from score-tied `BallDropSystem.gd` progress, not legacy pocket-count, bank, or multi-pocket reward paths.

## Performance Rules

- Stopped-ball filtering exists and should be preserved.
- Ball-vs-ball broad-phase spatial grid exists and should be preserved.
- Rail checks and pocket checks should run only for moving gameplay-active balls.
- Performance overlay/debug tools exist in `DebugOverlay.gd` and use snapshots from `Table.gd`, `BoundarySystem.gd`, `PocketSystem.gd`, `AimPreview.gd`, `WayfinderSystem.gd`, `PowderKegSystem.gd`, `AnchorBallSystem.gd`, `CannonBallSystem.gd`, `TreasureBallSystem.gd`, and `BallDropSystem.gd`.
- Do not remove counters or make them misleading during optimization.
- Do not add spatial partition rewrites or alternate physics engines without a focused request.
- Do not solve chaos by preventing chaos. Large earned chain reactions and high ball counts are intended.
- Do not hard-cap normal gameplay ball counts as the primary optimization strategy unless explicitly requested.
- Keep physics/gameplay authoritative and correct. Degrade visual effects first under load.
- Prefer event/state-driven updates over continuous rescanning. Systems should track meaningful state changes when practical instead of rebuilding full-table answers every frame.
- Coalesce repeated work before reducing gameplay ambition or visual fidelity. Input/event spam should mark systems dirty, then a single owner should process the newest state once per frame or once per relevant physics step.
- Optimization should preserve readability as well as raw performance; a faster effect that hides cause/effect relationships is usually not a good trade.
- AimPreview rebuilds are the canonical example: mouse/input events should not trigger dozens of same-frame prediction rebuilds; `Table.gd` should collapse them into one accurate rebuild without tolerance caching that lies about grazes.
- Good first optimization targets include particles, trails, aura effects, popup labels, redraw frequency, prediction rebuild frequency, pooling/reuse, and offscreen or low-priority visual simplification.
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

Continue stabilizing score-tied ball drops:

better play -> more score events/Doubloons -> more balls -> more interactions -> higher score before the table empties.

The first playable loop now exists in `BallDropSystem.gd`. Next passes should focus on presentation polish, tuning, and placeholder removal-animation replacement without moving reward decisions into `ScoreSystem.gd` or `Table.gd`.

Ball drop messaging now rotates for score-earned drops. Current lines include:

- "The Kraken provides..."
- "There's another one here somewhere..."
- "Austin's got it going on!"

The first player-facing Ball Drop progress meter exists in `BallDropMeter.gd` as a vertical right-side rising gauge. It should remain a lightweight UI reader of `BallDropSystem.gd`, not a gameplay decision-maker.

Cue ball and eight ball sinking no longer end the game as this loop comes online:

- Each costs 25 Doubloons.
- Each removes one eligible object ball from the table as the penalty.
- Current first pass uses a simple scale/fade removal animation; a true reversed ball-drop animation can replace it later.

## Current Architecture Direction

`Table.gd` should continue shrinking into a coordinator, but not at the cost of shot feel.

Lowest-risk future extractions are UI/presentation helpers or clearly bounded gameplay systems. Highest-risk extraction remains `BallPhysics`; leave it in `Table.gd` until there is a focused plan, a stable checkpoint, and a verification pass.

When adding a feature, first ask: which existing system owns this? If no system owns it cleanly, create a small focused system instead of expanding `Table.gd`.
