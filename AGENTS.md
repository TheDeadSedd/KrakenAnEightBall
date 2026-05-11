# Kraken An Eight Ball

## Project Identity

Kraken An Eight Ball is a Godot 4 / GDScript pirate-eldritch arcade billiards prototype.

The project is currently a "baby Cuethulhu" proof-of-interest build: small, punchy, readable, and focused on testing whether billiards plus roguelike escalation, special balls, and arcade trick-shot celebration are fun.

Core pillars:

- Drag-and-release 2D billiards with custom arcade physics.
- Pirate/kraken table presentation and in-engine charm.
- Doubloons scoring driven by trick-shot event history.
- Pocket-side score celebrations instead of generic center-screen scoring spam.
- Occasional anomaly balls, starting with the Wayfinder Ball.
- Fast iteration over broad systems.

Target platforms:

- Windows first.
- Android later.

## Architecture Ownership

### `scripts/Table.gd`

Owns high-level coordination, shot lifecycle, authoritative ball list, current main physics loop, run state, callout queue, and event routing between systems.

Does not own large new feature systems unless there is no cleaner option. New gameplay clusters should usually become system scripts and be coordinated from `Table.gd`.

`BallPhysics` intentionally still lives here. It is high-risk because it controls shot feel, collision response, rail events, pocket timing, Wayfinder event timing, and performance counters.

### `scripts/Ball.gd`

Owns individual ball identity, velocity/friction state, generated ball visuals, spawn/drop presentation state, trails, and minimal anomaly flags such as `is_wayfinder` / `wayfinder_active`.

Does not own table-wide gameplay rules, scoring, spawning decisions, pocket logic, or anomaly systems beyond per-ball state that must live on the ball.

### `scripts/DebugOverlay.gd`

Owns debug menu UI, debug toggles, physics debug display, performance overlay formatting, overlay dragging, and hotkey display text.

Does not own gameplay counters themselves. `Table.gd` and systems provide snapshots; `DebugOverlay.gd` presents them.

### `scripts/CueController.gd`

Owns cue sprite/pivot presentation, idle motion, cue grab-zone hit testing, pullback visuals, and strike/recoil/settle animation.

Does not own shot power, shot velocity, aim prediction, or real ball movement.

### `scripts/AimPreview.gd`

Owns aim line rendering, shot-power color, ghost cue-ball prediction, one-bank preview, and predicted-vs-actual shot path debug visualization.

Does not mutate real gameplay state. Prediction must stay side-effect-free and should use shared boundary helpers so preview stays aligned with real movement.

### `scripts/SpawnSystem.gd`

Owns cue ball start/reset helpers, starting rack/object-ball creation, reward spawns, debug ball spawns, safe spawn search, drop animation coordination, and spawn-related callouts.

Does not own scoring, pocket consequences, shot lifecycle, physics tuning, or anomaly behavior after a ball exists.

### `scripts/WayfinderSystem.gd`

Owns Wayfinder activation/deactivation, guided-ball tracking, pocket cone selection, timed guidance, redirect cooldowns, and Wayfinder debug logging.

Does not own ball-to-ball collision response, pocket geometry, spawn chance, or general anomaly architecture.

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

Does not own shot event tracking, pocket capture, physics, anomaly behavior, reward spawning, shops, progression, or heavy VFX.

Current score presentation notes:

- Side-pocket score popup behavior is considered good and should be preserved unless specifically requested.
- Corner-pocket score popup layout is still under active refinement.
- Popups are pocket-centered and consume sink context from `PocketSystem`.
- Score values should not change during presentation-only passes.

### `scripts/Main.gd`

Owns small app-shell behavior such as fullscreen toggling and top-level UI wiring.

Does not own table gameplay systems.

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

Future anomaly balls should generally get their own system scripts. `WayfinderSystem.gd` is the first example.

Pattern:

- `Table.gd` reports physics/gameplay events.
- Anomaly systems react to those events.
- `Ball.gd` stores only identity/state that must live on the ball instance.
- Spawn odds and creation remain in `SpawnSystem.gd`.
- Avoid hardcoding new anomaly behavior directly into `Table.gd`.
- Do not create a broad abstract anomaly framework until multiple anomalies prove the need.

Possible future systems:

- `PowderKegSystem.gd`
- `EtherealSystem.gd`
- `AnchorBallSystem.gd`

## Score And Doubloons Rules

- `ShotEventSystem.gd` tracks ordered per-ball shot history.
- `ScoreSystem.gd` converts sunk-ball histories into Doubloon rewards.
- Sunk-ball scoring should use the ball's own event history, not unrelated global shot events.
- `MULTI_SINK` applies to the second and later object balls sunk in the same shot, not retroactively to earlier popups.
- `MULTI_CHAIN` is repeatable and represents additional causal chain depth beyond the first `CHAIN`.
- Score popups should remain pocket-side, arcade-readable, and tied to the captured pocket.
- Drop/spawn notifications may still use top/center callouts; scoring feedback should not return there unless explicitly requested.
- Do not add coin sprays, shops, progression, or large score VFX without permission.

## Performance Rules

- Stopped-ball filtering exists and should be preserved.
- Ball-vs-ball broad-phase spatial grid exists and should be preserved.
- Rail checks and pocket checks should run only for moving gameplay-active balls.
- Performance overlay/debug tools exist in `DebugOverlay.gd` and use snapshots from `Table.gd`, `BoundarySystem.gd`, `PocketSystem.gd`, `AimPreview.gd`, and `WayfinderSystem.gd`.
- Do not remove counters or make them misleading during optimization.
- Do not add spatial partition rewrites or alternate physics engines without a focused request.

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

## Current Architecture Direction

`Table.gd` should continue shrinking into a coordinator, but not at the cost of shot feel.

Lowest-risk future extractions are UI/presentation helpers or clearly bounded gameplay systems. Highest-risk extraction remains `BallPhysics`; leave it in `Table.gd` until there is a focused plan, a stable checkpoint, and a verification pass.

When adding a feature, first ask: which existing system owns this? If no system owns it cleanly, create a small focused system instead of expanding `Table.gd`.
