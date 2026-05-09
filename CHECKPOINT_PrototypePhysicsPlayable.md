# Checkpoint: Prototype Physics Playable

Date: 2026-05-09

This checkpoint captures the first genuinely playable version of the prototype physics. The game is still intentionally small, but the core billiards feel is now fun enough to build on.

## Why This Checkpoint Matters

This is the point where the prototype first became genuinely fun/playable with the custom arcade billiards physics system. The earlier versions proved that Godot's default 2D rigid-body behavior was not giving the right billiards feel for this project, while the current manual movement model gives satisfying breaks, readable angled hits, and forgiving pockets.

## Current Project State

Kraken An Eight Ball is currently a simple top-down 2D billiards prototype in Godot 4 using GDScript only. It has a main scene, table scene, reusable ball scene, cue ball scene, manual arcade billiards physics, drag-to-shoot controls, pockets, and basic game-over/reset behavior.

The prototype is not a full roguelike yet. It is a playable physics and controls baseline.

## Working Systems

- Main scene with table and simple HUD status text.
- Clean visible table drawn from `Table.gd`.
- Cue ball and numbered object balls spawned at runtime.
- Drag near the cue ball, pull back, and release to shoot.
- Cue stick / aim guide while dragging.
- Manual ball movement using `Ball.velocity`.
- Manual equal-mass ball-to-ball collision response.
- Manual playfield boundary bounce.
- Pocket detection using pocket centers and a forgiving catch radius.
- Cue ball sunk behavior.
- 8 ball sunk behavior.
- Debug no-game-over mode that resets cue ball and 8 ball instead of ending the game.
- Safe reset search that tries to avoid pockets and overlapping visible balls.
- Editor preview guides for table bounds, pocket centers, pocket catch zones, and rail/boundary guides.

## Abandoned Or Replaced

- `RigidBody2D` ball physics was abandoned.
- Godot's built-in ball-to-ball collision solver was replaced because head-on and angled transfer felt dead or unreliable.
- Custom velocity rewriting on top of `RigidBody2D` was also abandoned because it fought the engine physics.
- Physical pocket jaw colliders were removed because they made pocket-area behavior feel too aggressive.
- Visible rail geometry is no longer tied to collision helper geometry.
- Pocket `CollisionShape2D` resources were removed from the scene because pocket detection is now manual.

## Current Physics Approach

Balls are `Node2D` scenes, not `RigidBody2D`. Each ball stores its own `velocity: Vector2` in `scripts/Ball.gd`.

Each physics frame, `scripts/Table.gd`:

- Moves visible balls by velocity.
- Resolves ball-to-ball circle overlaps.
- Applies an equal-mass collision impulse along the center-to-center normal.
- Checks pockets before rail clamping.
- Resolves playfield bounds using `PLAYFIELD_RECT`.
- Applies rolling friction and layered low-speed drag.

This is intentionally arcade billiards, not simulation billiards.

## Current Tuning Feel

The break feels lively and satisfying. Direct hits transfer momentum well. Angled hits and grazes are readable enough for trick-shot play. Pockets are forgiving, which fits the current goal of fun combo-heavy play rather than strict pool simulation.

Friction has been tuned upward from the early chaotic prototype, but the game still has a lively arcade feel. Low-speed drag bands help slow balls settle instead of creeping forever.

## Known Issues

- Pockets are playable but still not final. Corner and side pocket feel may need small tuning once scoring/trick-shot goals are clearer.
- Rail behavior is currently simple playfield-boundary clamping, not true segmented pocket-mouth rails.
- Table art is functional programmer art.
- No scoring or trick-shot tracking exists yet.
- No special balls exist yet.
- No progression, upgrades, menus, or roguelike loop exists yet.
- `DEBUG_NO_GAME_OVER` is currently enabled for easier physics testing.

## Debug And Editor Tooling

In `scripts/Table.gd`:

- `DEBUG_NO_GAME_OVER := true` resets cue ball and 8 ball instead of ending the game.
- `DEBUG_DRAW_RAIL_RECTS := false` controls runtime rail/boundary debug drawing.
- `EDITOR_DRAW_GUIDES := true` draws editor preview guides.
- `EDITOR_DRAW_POCKET_CATCH_ZONES := true` draws editor pocket catch-radius guides.
- `@tool` lets the table art and editor guides appear in the Godot editor preview.

## Important Tuning Constants

In `scripts/Ball.gd`:

- `radius := 14.0`
- `rolling_friction := 105.0`
- `stop_threshold := 4.0`
- `medium_speed_drag_start := 140.0`
- `medium_speed_drag_multiplier := 1.15`
- `low_speed_drag_start := 60.0`
- `low_speed_drag_multiplier := 1.8`
- `crawl_speed_drag_start := 22.0`
- `crawl_speed_drag_multiplier := 3.0`

In `scripts/Table.gd`:

- `PLAYFIELD_RECT` is built from `PLAYFIELD_LEFT`, `PLAYFIELD_TOP`, `PLAYFIELD_RIGHT`, and `PLAYFIELD_BOTTOM`.
- `POCKET_RADIUS := 18.0`
- `POCKET_CATCH_BONUS := 8.0`
- `MAX_DRAG_DISTANCE := 210.0`
- `MIN_SHOT_DISTANCE := 12.0`
- `SHOT_POWER := 9.4`
- `BALL_COLLISION_RESTITUTION := 0.98`
- `RAIL_RESTITUTION := 0.92`
- `PHYSICS_SUBSTEPS := 2`

## Architectural Decisions

- Keep physics simple, readable, and local to `Ball.gd` and `Table.gd`.
- Use manual arcade physics instead of engine rigid-body billiards.
- Keep balls as lightweight `Node2D` objects with drawn visuals.
- Keep visible table art separate from collision behavior.
- Use editor guide drawing for tuning instead of adding in-game UI.
- Keep debug behavior code-only and easy to toggle.
- Avoid future-facing placeholder systems until the core loop earns them.

## Recommended Next Steps

1. Add a minimal score system for sunk balls.
2. Add simple trick-shot detection one piece at a time, starting with bank shots or combo hits.
3. Add a basic shot result summary after balls settle.
4. Decide when `DEBUG_NO_GAME_OVER` should default to `false`.
5. Tune pocket forgiveness after scoring creates clearer player incentives.
6. Add one special ball only after the base scoring loop feels good.

## Intentionally Not Added Yet

- No scoring implementation.
- No trick-shot bonuses.
- No special balls.
- No ball spawning escalation.
- No upgrades.
- No menus.
- No roguelike progression.
- No save/load.
- No networking.
- No Android-specific controls.
- No polished pirate/kraken art pass.
