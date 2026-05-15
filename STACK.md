# Tech Stack

## Engine

- Godot 4
- GDScript
- 2D `Node2D` scenes with custom arcade billiards physics
- Windows-first local prototype, Android later

## Scenes And App Shell

- `scenes/MainMenu.tscn` / `scripts/MainMenu.gd` owns the title screen and menu button flow.
- `scenes/Main.tscn` remains the gameplay scene loaded by Start Run.
- `scripts/Main.gd` stays a small app shell for top-level wiring such as fullscreen toggling.
- Pause UI lives under the gameplay HUD/CanvasLayer and is separate from title-screen ownership.

## Physics And Geometry

- Real ball physics is custom/manual and currently lives in `scripts/Table.gd`.
- Balls are authored/presented as nodes, but gameplay movement and collision response are not driven by `RigidBody2D`.
- Ball-vs-ball broad-phase spatial partitioning supports high ball counts.
- Stopped-ball filtering keeps settled table states cheap.
- Boundaries and pockets are scene-authored source of truth, loaded by `BoundarySystem.gd` and `PocketSystem.gd`.
- `BallPlacementSystem.gd` uses existing safe placement helpers for shop/reserve/manual placement without changing physics or geometry rules.

## Prediction And Presentation

- `AimPreview.gd` owns side-effect-free prediction and polished aim presentation.
- Prediction uses swept checks and broad-phase filtering so the guide remains accurate without scanning every ball every step.
- `Table.gd` coalesces aim-preview rebuilds so input spam becomes one accurate rebuild per frame while dragging.
- `TableImpactShakeSystem.gd` owns presentation-only fake-3D table impact shake; gameplay positions and HUD/debug UI do not move.
- Draw-only anomaly visuals in `Ball.gd` include Cannon heat/ember presence and Treasure scuttle legs.
- `MainMenuPresentationOverlay.gd` owns draw-only title-screen atmosphere: moon glow, star twinkles, ocean shimmer, and fog.
- `ReserveDeploymentPresenter.gd` owns draw-only Reserve cursor icon/tether presentation.
- `QuartermasterOfferRefreshEffect.gd` owns the presentation-only fresh-stock glow/shimmer.

## UI, Debug, And Pause

- `PauseMenu.gd` owns pause-menu tabs, Resume/Quit behavior, the Quartermaster tab, and debug panel toggles.
- `DebugOverlay.gd` owns the old full F3 overlay and modular debug-panel wiring.
- `DebugPanel.gd` provides the draggable pause-safe panel shell.
- Hidden debug panels should not refresh text every frame or request unnecessary snapshot sections.
- UI panels and Reserve slots consume their own click/drag input without stealing an already active cue drag.

## Economy And Placement

- `QuartermasterSystem.gd` owns inventory, prices, affordability, active rotating offers, and event-driven offer refresh.
- Current active offers are drawn from Loose Object Ball, Wayfinder Ball, and Powder Keg.
- Successful purchases spend Doubloons and fill the first empty `ReserveSystem.gd` slot.
- `ReserveSystem.gd` owns three slot contents and deployment state.
- Reserve deployment uses `BallPlacementSystem.gd`; confirm places and clears the slot, cancel keeps the item.
- Quartermaster spending must not emit score-award signals or advance `BallDropSystem.gd` progress.

## Scoring And Shot Events

- `ShotEventSystem.gd` owns causal shot history and never awards Doubloons directly.
- `ScoreSystem.gd` owns Doubloon values, total updates, scoring breakdowns, and pocket-side popups.
- Current event tiers are foundational, skilled, heroic, and legendary.
- Implemented events include `BANK`, `CHAIN`, `MULTI_CHAIN`, `ANOMALY_TOUCH`, `MULTI_SINK`, `KRAKEN_KICK`, `DOUBLE_BANK`, `THIN_CUT`, `CLUSTER_BREAK`, `CROSS_CORNER_BANK`, `FULL_TABLE_KICK`, `POWDER_ROUTE`, `KRAKEN_CURRENT`, `TRIPLE_BANK`, `CANNON_CHAIN`, and `TREASURE_SNARE`.

## Audio

- `BallAudioSystem.gd` owns ball-to-ball collision sounds.
- Collision audio is event-driven from meaningful impact reports rather than scanned continuously.
- Audio playback uses a small pool of `AudioStreamPlayer` nodes, randomized hit streams, slight pitch variation, impact-scaled volume, and cooldown/spam filtering.
- Audio should never change physics, collision math, cue feel, scoring, or anomaly behavior.

## Optimization Philosophy

- Support chaos gracefully instead of preventing chaos.
- Large earned chain reactions and 100+ ball stress tests are intended.
- Coalesce repeated work, avoid unnecessary redraws, and use broad-phase/spatial filtering before reducing gameplay ambition.
- Gate hidden debug work; invisible panels should be logically cheap, not merely transparent.
- Prefer event-driven stock refresh, collision audio, shot-event recording, and placement state changes over passive per-frame scans.
- Degrade visuals first under load: particles, trails, aura effects, popup labels, fake-3D shake, and other presentation layers.
- Preserve readability as well as FPS; faster effects that hide cause/effect relationships are usually the wrong trade.
- Keep gameplay/physics authoritative and correct.

## Do Not

- Do not use C# unless the project explicitly changes direction.
- Do not reintroduce procedural/fallback pocket or rail geometry.
- Do not move core physics out of `Table.gd` without a focused extraction plan and validation pass.
- Do not use gameplay ball-count caps as the primary performance fix unless explicitly requested.
- Do not route shop spending through score-award/drop-progress signals.
- Do not put Reserve-specific visuals or Quartermaster-specific logic into `BallPlacementSystem.gd`.
- Do not let title-screen or debug UI changes touch gameplay systems.
- Do not commit exported builds, APKs, zips, or large generated artifacts.
