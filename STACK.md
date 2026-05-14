# Tech Stack

## Engine

- Godot 4
- GDScript
- 2D `Node2D` scenes with custom arcade billiards physics
- Windows-first local prototype, Android later

## Physics And Geometry

- Real ball physics is custom/manual and currently lives in `scripts/Table.gd`.
- Balls are authored/presented as nodes, but gameplay movement and collision response are not driven by `RigidBody2D`.
- Ball-vs-ball broad-phase spatial partitioning supports high ball counts.
- Stopped-ball filtering keeps settled table states cheap.
- Boundaries and pockets are scene-authored source of truth, loaded by `BoundarySystem.gd` and `PocketSystem.gd`.

## Prediction And Presentation

- `AimPreview.gd` owns side-effect-free prediction and polished aim presentation.
- Prediction uses swept checks and broad-phase filtering so the guide remains accurate without scanning every ball every step.
- `Table.gd` coalesces aim-preview rebuilds so input spam becomes one accurate rebuild per frame while dragging.
- `TableImpactShakeSystem.gd` owns presentation-only fake-3D table impact shake; gameplay positions and HUD/debug UI do not move.
- Draw-only anomaly visuals in `Ball.gd` include Cannon heat/ember presence and Treasure scuttle legs.

## Optimization Philosophy

- Support chaos gracefully instead of preventing chaos.
- Large earned chain reactions and 100+ ball stress tests are intended.
- Coalesce repeated work, avoid unnecessary redraws, and use broad-phase/spatial filtering before reducing gameplay ambition.
- Degrade visuals first under load: particles, trails, aura effects, popup labels, fake-3D shake, and other presentation layers.
- Keep gameplay/physics authoritative and correct.

## Do Not

- Do not use C# unless the project explicitly changes direction.
- Do not reintroduce procedural/fallback pocket or rail geometry.
- Do not move core physics out of `Table.gd` without a focused extraction plan and validation pass.
- Do not use gameplay ball-count caps as the primary performance fix unless explicitly requested.
- Do not commit exported builds, APKs, zips, or large generated artifacts.
