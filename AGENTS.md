# Kraken An Eight Ball

## Project Overview

Kraken An Eight Ball is a small pirate/kraken themed billiards roguelike prototype made in Godot 4 with GDScript.

The prototype currently focuses on custom 2D arcade billiards physics, authored table geometry, drag-to-shoot controls, escalating ball spawns, and anomaly balls. The goal is to test whether billiards plus roguelike escalation can feel fun, readable, chaotic, and charming without growing into a large simulation.

Keep the scope intentionally small and polished. Prioritize playable feel, readable code, and quick iteration over broad systems.

Target platforms:

- Windows first.
- Android later.

## Architecture Ownership

### `scripts/Table.gd`

`Table.gd` is the high-level table coordinator.

Responsibilities:

- Owns shot lifecycle and shot result state.
- Owns the authoritative ball list through the `Balls` node.
- Owns the current main physics loop and update order.
- Coordinates extracted systems.
- Reports gameplay/physics events to systems that need them.

Rules:

- Do not dump large new feature systems back into `Table.gd`.
- Keep `Table.gd` as orchestration glue when possible.
- Small event routing and temporary coordination are acceptable.
- Large behavior clusters should become their own system script.

### `scripts/Ball.gd`

`Ball.gd` owns individual ball behavior.

Responsibilities:

- Ball identity and state.
- Ball visuals and generated in-engine drawing.
- Movement, friction, trails, and spawn/drop presentation state.
- Per-ball anomaly flags/state only when the ball itself must carry that state.

Rules:

- Avoid placing table-wide gameplay systems here.
- Keep ball state easy to inspect and beginner-readable.

### `scripts/DebugOverlay.gd`

`DebugOverlay.gd` owns debug UI.

Responsibilities:

- Debug menu.
- Performance overlay.
- Debug toggles.
- Movable overlay behavior.
- Debug display formatting.

Rules:

- Debug UI should stay out of gameplay scripts when possible.
- Debug tools should be hidden or opt-in by default unless explicitly requested.

### `scripts/CueController.gd`

`CueController.gd` owns cue presentation and cue-specific hit testing.

Responsibilities:

- Cue sprite/pivot visuals.
- Cue idle motion.
- Cue grab zone.
- Pullback presentation.
- Strike/recoil/settle presentation.

Rules:

- Do not change shot physics here.
- Table remains responsible for actual shot state and velocity application.

### `scripts/AimPreview.gd`

`AimPreview.gd` owns aim visualization and prediction-only simulation.

Responsibilities:

- Aim line drawing.
- Shot power aim coloring.
- Ghost cue-ball prediction.
- One-bank preview behavior.
- Shot-path comparison debug overlay data.
- Prediction-only boundary interactions through `BoundarySystem`.

Rules:

- Prediction must not mutate real gameplay state.
- Prediction should use shared helpers where possible so it matches real movement.

### `scripts/SpawnSystem.gd`

`SpawnSystem.gd` owns spawning and drop-flow coordination.

Responsibilities:

- Cue ball start/reset position helpers.
- Initial rack/object ball spawning.
- Reward spawns.
- Debug normal ball and Wayfinder spawns.
- Safe spawn search.
- Spawn/drop animation coordination.
- Spawn-related callout coordination.

Rules:

- Do not change reward pacing or spawn odds during cleanup/refactor passes.
- Keep ball creation paths centralized here when possible.

### `scripts/ShotEventSystem.gd`

`ShotEventSystem.gd` owns per-shot event history for future Doubloons scoring.

Responsibilities:

- Start/reset shot event tracking.
- Store ordered per-ball shot events.
- Track foundation events like `BANK`, `CHAIN`, `ANOMALY_TOUCH`, and `MULTI_SINK`.
- Report event history when balls sink.

Rules:

- Do not add Doubloons scoring, coin UI, or reward math here until explicitly requested.
- `Table.gd` should report gameplay events; `ShotEventSystem.gd` should store history.
- Keep this system passive so event tracking never changes gameplay feel.

### `scripts/ScoreSystem.gd`

`ScoreSystem.gd` owns Doubloons scoring math and first-pass score presentation.

Responsibilities:

- Convert `ShotEventSystem.gd` histories into Doubloon rewards.
- Track the running Doubloons total.
- Print/debug scoring breakdowns.
- Emit HUD total changes.
- Show lightweight pocket-side score popups.

Rules:

- Do not track shot events here; consume histories from `ShotEventSystem.gd`.
- Do not add coin sprays, heavy VFX, or reward-shop logic here unless explicitly requested.
- Keep scoring changes separate from physics, pockets, and anomaly behavior.

### `scripts/WayfinderSystem.gd`

`WayfinderSystem.gd` owns the Wayfinder anomaly.

Responsibilities:

- Wayfinder activation/deactivation coordination.
- Guided-ball tracking.
- Pocket cone selection for guidance.
- Timed guidance updates.
- Wayfinder debug logging.

Rules:

- Keep Wayfinder behavior here instead of spreading it through `Table.gd`.
- Future anomaly systems should follow this pattern.

### `scripts/PocketSystem.gd`

`PocketSystem.gd` owns scene-authored pockets.

Responsibilities:

- Loading `Table/Pockets`.
- Reading pocket centers from `CollisionShape2D.global_position`.
- Reading pocket radii from `CircleShape2D.radius`.
- Pocket capture checks.
- Pocket safety checks used by spawning.
- Pocket performance counters.

Rules:

- Scene-authored pocket nodes are the source of truth.
- Do not reintroduce procedural or fallback pocket geometry.

### `scripts/BoundarySystem.gd`

`BoundarySystem.gd` owns scene-authored rail and boundary geometry.

Responsibilities:

- Loading `Table/Boundaries`.
- Caching authored `CollisionShape2D` rectangle boundaries.
- Boundary reference rects.
- Rail/boundary collision helpers.
- Shared side-effect-free boundary response used by aim prediction.
- Boundary performance counters.

Rules:

- Scene-authored boundary nodes are the source of truth.
- Do not reintroduce procedural or fallback table geometry.
- Do not move or resize authored boundary nodes from code.

## Anomaly Architecture

Future anomaly balls should generally get their own system scripts. Use `WayfinderSystem.gd` as the first example.

Possible future pattern:

- `PowderKegSystem.gd`
- `EtherealSystem.gd`
- `AnchorBallSystem.gd`

Rules:

- `Table.gd` should report physics/gameplay events.
- Anomaly systems should react to those events.
- Avoid hardcoding new anomaly behavior directly into `Table.gd`.
- Put shared anomaly identity/state on `Ball.gd` only when the ball instance must carry it.
- Keep anomaly systems small, readable, and independently removable.
- Do not create a broad abstract anomaly framework until multiple anomalies prove it is needed.

## Development Rules

- Preserve current gameplay feel unless explicitly asked to tune it.
- Do not tune physics during cleanup or refactor passes.
- Do not make large rewrites without explicit permission.
- Keep systems simple and beginner-readable.
- Keep scripts modular and small.
- Prefer functions under 60 lines.
- Add short comments for important systems or non-obvious logic.
- Scene-authored boundaries and pockets are the source of truth.
- Do not reintroduce procedural/fallback table geometry.
- Keep exports/builds out of Git.
- Commit after stable milestones, especially after playable checkpoints or successful extractions.
- Avoid adding scoring, menus, upgrades, new anomaly balls, or broad progression systems unless explicitly requested.

## Current Extraction Direction

`BallPhysics` remains in `Table.gd` intentionally for now.

Ball physics is the highest-risk remaining extraction because it controls core feel, collision response, broad-phase behavior, shot lifecycle interactions, rail events, and Wayfinder event timing. It may be extracted later, but it is not required for future anomaly work yet.

Recommended near-term extraction approach:

- Keep extracting low-risk ownership boundaries first.
- Let `Table.gd` continue reporting core collision and shot events.
- Only extract `BallPhysics` after a stable checkpoint and with a focused verification pass.
