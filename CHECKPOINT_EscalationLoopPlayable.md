# Checkpoint: Escalation Loop Playable

Date: 2026-05-09

This checkpoint captures the first playable version of the prototype's arcade escalation loop. The core billiards physics were already fun; this pass adds the first reason for the table to keep evolving instead of simply emptying out.

## Why This Checkpoint Matters

This is the point where the prototype evolved from a fun billiards toy into a true arcade/roguelike escalation prototype. Sinking balls can immediately add new balls, stylish shots create visible chaos, and the table now feels alive instead of simply emptying.

The loop is still intentionally small, but it now has a clear emotional shape: take a shot, sink balls, earn more chaos, and watch new threats drop onto the table.

## Current Project State

Kraken An Eight Ball is currently a top-down 2D Godot 4 billiards prototype using GDScript only. It has manual arcade billiards physics, drag-to-shoot controls, numbered balls, forgiving pockets, debug/editor tooling, and a lightweight shot evaluation system that can spawn new balls during play.

The project is not a full roguelike yet. This checkpoint is specifically the first playable escalation baseline.

## Gameplay Systems Working Now

- Main scene, table scene, ball scene, and cue ball scene are playable.
- The game starts with 1 cue ball and 15 numbered object balls.
- The 8 ball is included and still uses the current 8-ball sunk behavior.
- Drag near the cue ball, pull back, and release to shoot.
- A simple cue line / cue stick visual appears while aiming.
- Balls move with custom arcade physics.
- Balls collide with each other using manual circle collision.
- Balls bounce off the playfield bounds.
- Pockets detect sunk balls with a forgiving catch radius.
- Cue ball and 8 ball can reset in debug mode.
- Object balls can be sunk and removed.
- Sinking object balls can immediately queue new ball spawns.
- Newly spawned balls use a visible drop animation before joining gameplay.

## Shot Evaluation And Spawn Reward Rules

The shot tracking lives in `scripts/Table.gd`.

Current implemented reward rules:

- Every 2 pocketed object balls queues 1 spawned object ball.
- Pocketing 2 or more object balls in the same shot queues 1 extra spawned object ball.
- If the cue ball touched a rail before an object ball is pocketed, the bank bonus queues 1 extra spawned object ball.

These are not score rules yet. They are chaos/escalation rules only.

Duplicate bonus rewards are prevented with per-shot flags:

- `shot_multi_pocket_bonus_awarded`
- `shot_bank_bonus_awarded`

Base spawn progress persists across shots with:

- `pocketed_object_ball_spawn_progress`

## Immediate Ball Spawning

Spawn rewards are awarded when object balls are pocketed, not when the shot ends.

When an object ball is pocketed:

- `_note_object_ball_pocketed()` updates the current shot stats.
- `_award_base_spawn_progress()` checks the every-2-object-balls rule.
- `_try_award_multi_pocket_bonus()` checks the same-shot multi-pocket bonus.
- `_try_award_bank_bonus()` checks the bank bonus if the cue ball touched a rail.
- `_queue_spawn_reward()` adds earned drops to `pending_spawn_count`.

The actual drops are processed by `_process_spawn_queue(delta)`, which spawns one reward ball at a time using a short stagger.

## Ball-Drop Reward Presentation

The drop animation lives in `scripts/Ball.gd`.

When `begin_spawn_drop(final_position)` is called:

- The ball appears above its reserved landing spot.
- The ball starts large.
- It quickly scales down as if falling toward the table.
- It squashes once on landing.
- It rebounds slightly.
- It settles back to normal scale.

During the drop, `gameplay_enabled` is `false`. This makes the new ball temporarily ignore normal movement, friction, collisions, rail checks, and pocket checks. When the animation finishes, `_finish_spawn_drop()` restores normal gameplay.

Queued drops are staggered by `SPAWN_DROP_STAGGER := 0.14` in `scripts/Table.gd`, so multiple earned balls are easier to see.

## Current Physics Approach

Balls are `Node2D` objects with a manual `velocity: Vector2` in `scripts/Ball.gd`.

`scripts/Table.gd` owns the arcade billiards physics loop:

- Move active balls by velocity.
- Resolve ball-to-ball overlap.
- Apply equal-mass impulse along the contact normal.
- Check pockets before rail clamping.
- Clamp and bounce balls inside `PLAYFIELD_RECT`.
- Apply rolling friction and layered low-speed drag.

Godot `RigidBody2D` billiards physics was abandoned earlier because it did not produce reliable billiards-style transfer for this prototype.

## Current Visual And Art State

All visuals are still generated in-engine.

- Table art is drawn in `scripts/Table.gd` using `_draw()`.
- Balls are drawn in `scripts/Ball.gd`.
- Balls have distinct billiards-inspired colors.
- The cue ball is white.
- The 8 ball is dark/black.
- Number labels are centered on object balls.
- Balls have a simple rim, highlight, and shaded body.
- Spawned reward balls have a large-to-normal drop/bounce animation.

There are no imported art assets yet.

## Current Tuning Feel

The prototype currently aims for arcade billiards rather than strict simulation.

- Breaks feel lively.
- Ball-to-ball transfer is readable and satisfying.
- Pockets are forgiving.
- Trick-shot-friendly chaos is starting to emerge.
- Friction is controlled enough for regular play but still lively.
- Low-speed drag helps balls settle instead of creeping forever.
- Ball drops make new spawns feel like rewards and threats.

## Known Issues And Rough Edges

- There is no score system yet.
- Shot evaluation only supports the first escalation rewards.
- Bank detection is simple: cue ball rail touch before an object ball sinks.
- There is no distinction yet between intentional bank shots and chaotic rail touches.
- Spawned balls are normal object balls only.
- Spawn safe-position search is simple and centered around the table center.
- Pocket and rail behavior are still prototype-level.
- Table and ball art are readable but not final pirate/kraken art.
- `DEBUG_NO_GAME_OVER` is currently enabled for easier testing.
- The checkpoint file `CHECKPOINT_PrototypePhysicsPlayable.md` still describes the earlier pre-escalation milestone.

## Important Constants

In `scripts/Table.gd`:

- `DEBUG_NO_GAME_OVER := true`
- `DEBUG_DRAW_RAIL_RECTS := false`
- `EDITOR_DRAW_GUIDES := true`
- `EDITOR_DRAW_POCKET_CATCH_ZONES := true`
- `PLAYFIELD_LEFT`, `PLAYFIELD_TOP`, `PLAYFIELD_RIGHT`, `PLAYFIELD_BOTTOM`
- `POCKET_RADIUS := 18.0`
- `POCKET_CATCH_BONUS := 8.0`
- `CUE_START := Vector2(340, 360)`
- `RACK_ORIGIN := Vector2(790, 360)`
- `RACK_SPACING_MULTIPLIER := 2.12`
- `BASE_SPAWN_POCKET_COUNT := 2`
- `MULTI_POCKET_BONUS_THRESHOLD := 2`
- `SPAWN_SEARCH_CENTER := Vector2(600, 360)`
- `SPAWN_SEARCH_STEP := 34.0`
- `SPAWN_SEARCH_RINGS := 10`
- `SPAWN_DROP_STAGGER := 0.14`
- `SPAWN_BALL_NUMBERS`
- `MAX_DRAG_DISTANCE := 210.0`
- `SHOT_POWER := 9.4`
- `BALL_COLLISION_RESTITUTION := 0.98`
- `RAIL_RESTITUTION := 0.92`
- `PHYSICS_SUBSTEPS := 2`

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
- `spawn_drop_start_scale := 2.6`
- `spawn_drop_lift := 36.0`
- `spawn_drop_fall_time := 0.18`
- `spawn_drop_squash_time := 0.06`
- `spawn_drop_rebound_time := 0.07`
- `spawn_drop_settle_time := 0.08`
- `spawn_drop_squash_scale := Vector2(1.18, 0.82)`
- `spawn_drop_rebound_scale := Vector2(0.92, 1.08)`

## Debug And Editor Tooling

`scripts/Table.gd` uses `@tool`, so table art and editor guides can appear in the Godot editor.

Current toggles:

- `DEBUG_NO_GAME_OVER` resets the cue ball and 8 ball instead of ending the game.
- `DEBUG_DRAW_RAIL_RECTS` draws runtime rail/boundary debug rectangles.
- `EDITOR_DRAW_GUIDES` draws editor preview guides.
- `EDITOR_DRAW_POCKET_CATCH_ZONES` draws pocket catch-radius guides in the editor.

Safe reset and safe spawn checks try to avoid pockets, rails, and visible balls. Dropping balls reserve their final landing position through `Ball.get_safe_position()` so follow-up drops do not stack onto the same spot.

## Architectural Decisions

- Keep the escalation loop inside `scripts/Table.gd` for now.
- Keep ball presentation state inside `scripts/Ball.gd`.
- Use a small integer pending-spawn queue instead of a larger event system.
- Award spawn rewards immediately on pocket events.
- Use per-shot boolean flags to prevent duplicate bonus awards.
- Keep the system as chaos/escalation only, not scoring.
- Keep visuals generated in code until the loop proves it deserves art investment.

## Recommended Next Development Steps

1. Playtest the immediate spawn loop for pacing and table overcrowding.
2. Decide whether spawned balls should enter with a tiny random nudge after landing.
3. Add the first minimal score system only after the escalation pacing feels stable.
4. Add a simple shot result summary once score events exist.
5. Refine bank-shot detection if it becomes too generous.
6. Add one special ball only after normal spawned balls feel balanced.
7. Decide when `DEBUG_NO_GAME_OVER` should default to `false`.

## Intentionally Not Added Yet

- No scoring display.
- No final score rules.
- No trick-shot score categories.
- No special balls.
- No upgrades.
- No roguelike progression.
- No menus.
- No particles.
- No imported art assets.
- No sound effects.
- No save/load.
- No networking.
- No Android controls.
