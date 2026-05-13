# Agent Report

Generated as a lightweight multi-role review. These are not autonomous agents; they are project lenses for future sessions.

Do not misuse: this report is not source of truth. Check real source files and `AGENTS.md` before changing gameplay behavior.

## Mechanics Agent

Relevant files:
- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles Anchor Ball cursed-tide pull, target rules, cooldowns, visuals, and debug counters.
- `scripts/Ball.gd` - Individual ball state, visuals, friction helpers, trails, and anomaly identity flags.
- `scripts/BallDropMeter.gd` - Vertical right-side HUD meter for progress toward the next score-earned ball drop.
- `scripts/BallDropSystem.gd` - Tracks Doubloon progress toward score-tied reward drops and cue/eight-ball sink penalties.
- `scripts/CannonBallSystem.gd` - Stage 3 Cannon Ball anomaly shell for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and pocket-side score popup presentation.
- `scripts/ShotEventSystem.gd` - Tracks causal per-shot scoring events for sunk balls.
- `scripts/SpawnSystem.gd` - Creates balls, queues reward drops, performs safe spawn searches, and owns current anomaly spawn odds.

What it appears to do:
- Tracks core play loops, shot lifecycle, scoring hooks, ball identity, and moment-to-moment billiards feel.
- Preserve cue feel, shot feel, pocket feel, and scoring values during cleanup.
- Score-tied ball drops and cue/eight-ball sink penalties now flow through BallDropSystem.gd boundaries.

Known risks or TODOs:
- BallDropSystem.gd is first-pass playable; drop tuning and penalty presentation still need playtesting.
- Cue/eight-ball sink penalties should not accidentally feed score-tied drop progress.

Questions for the developer:
- How many extra balls should different score-event tiers award?
- When should a crowded table stop escalating and start resolving?

## Systems Agent

Relevant files:
- `AGENTS.md` - Project documentation or checkpoint notes.
- `scenes/Main.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles Anchor Ball cursed-tide pull, target rules, cooldowns, visuals, and debug counters.
- `scripts/BallDropSystem.gd` - Tracks Doubloon progress toward score-tied reward drops and cue/eight-ball sink penalties.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/CannonBallSystem.gd` - Stage 3 Cannon Ball anomaly shell for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
- `scripts/PocketSystem.gd` - Loads authored pocket geometry and detects pocket captures.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and pocket-side score popup presentation.
- `scripts/ShotEventSystem.gd` - Tracks causal per-shot scoring events for sunk balls.

What it appears to do:
- Tracks module boundaries, ownership rules, scene wiring, and coordinator responsibilities.
- Table.gd should coordinate systems without absorbing new feature logic.
- Scene-authored geometry remains the source of truth.

Known risks or TODOs:
- Table.gd still owns BallPhysics; do not extract casually.
- Future reward logic could still bloat ScoreSystem or Table.gd if new BallDropSystem responsibilities are not respected.

Questions for the developer:
- What reward decisions should BallDropSystem.gd own before tuning starts?
- Which debug surfaces should graduate into permanent quality settings?

## Anomaly Ball Agent

Relevant files:
- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles Anchor Ball cursed-tide pull, target rules, cooldowns, visuals, and debug counters.
- `scripts/Ball.gd` - Individual ball state, visuals, friction helpers, trails, and anomaly identity flags.
- `scripts/BallDropMeter.gd` - Vertical right-side HUD meter for progress toward the next score-earned ball drop.
- `scripts/BallDropSystem.gd` - Tracks Doubloon progress toward score-tied reward drops and cue/eight-ball sink penalties.
- `scripts/CannonBallSystem.gd` - Stage 3 Cannon Ball anomaly shell for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/WayfinderSystem.gd` - Handles Wayfinder activation and temporary guided-ball redirects.

What it appears to do:
- Tracks Wayfinder, Powder Keg, Anchor Ball, Cannon Ball, and future anomaly behavior boundaries.
- Wayfinder, Powder Keg, and Anchor are active anomaly systems; Cannon Ball has first-pass heavy collision, Powder Keg launch, heavy-impact shake, and high-speed heat presence.
- Anchor has independent priority spawn odds and object-ball-only pull.

Known risks or TODOs:
- Anchor behavior is tuned by feel and should be adjusted incrementally.
- Future anomalies should avoid hidden coupling through Table.gd.

Questions for the developer:
- Should future anomalies interact with Anchor fields, or stay independent?
- Should anomaly-touch scoring expand beyond current event rewards?

## UI Agent

Relevant files:
- `scenes/Ball.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/CueBall.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Main.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/BallDropMeter.gd` - Vertical right-side HUD meter for progress toward the next score-earned ball drop.
- `scripts/CueController.gd` - Owns cue visuals, grab-zone hit testing, pullback, and strike presentation.
- `scripts/DebugOverlay.gd` - Formats debug menu, performance overlay, toggles, and physics debug text.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and pocket-side score popup presentation.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.

What it appears to do:
- Tracks HUD, debug panels, score popups, callouts, cue presentation, and player-facing text.
- Score popups are pocket-side arcade celebrations, not generic UI spam.
- Debug labels should stay clearly marked and not leak temporary test wording into player-facing strings.
- BallDropSystem.gd owns rotating score-earned drop-message selection; SpawnSystem/Table carry those messages to callouts.

Known risks or TODOs:
- Score popup readability can regress when many events happen at once.
- Debug overlay can become noisy as more counters are added.

Questions for the developer:
- Should ball drop callouts get themed variants now that the BallDropSystem spine exists?
- Which popup effects should degrade first on low-end machines?

## Performance Agent

Relevant files:
- `scripts/AimPreview.gd` - Draws aim preview and side-effect-free cue-ball prediction.
- `scripts/AnchorBallSystem.gd` - Handles Anchor Ball cursed-tide pull, target rules, cooldowns, visuals, and debug counters.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/DebugOverlay.gd` - Formats debug menu, performance overlay, toggles, and physics debug text.
- `scripts/PocketSystem.gd` - Loads authored pocket geometry and detects pocket captures.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/TableImpactShakeSystem.gd` - Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts.

What it appears to do:
- Tracks visual cost, broad-phase health, trail redraws, particle load, and stress-test readiness.
- Do not solve chaos by preventing chaos; degrade visuals first.
- High ball counts and large earned chain reactions are intended.
- BallDropSystem.gd exists as the score-tied drop spine and should be watched for high-count visual scaling pressure.

Known risks or TODOs:
- Visual effects should degrade before gameplay chaos is limited.
- Pooling/reuse is not broadly implemented for temporary visuals yet.

Questions for the developer:
- What visual-quality tiers should exist for trails, particles, aura effects, and score labels?
- When should pooling replace ad hoc temporary visual nodes?

## Lore/Theme Agent

Relevant files:
- `AGENTS.md` - Project documentation or checkpoint notes.
- `NOTES.md` - Project documentation or checkpoint notes.
- `STACK.md` - Project documentation or checkpoint notes.
- `scenes/Main.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and pocket-side score popup presentation.
- `scripts/SpawnSystem.gd` - Creates balls, queues reward drops, performs safe spawn searches, and owns current anomaly spawn odds.

What it appears to do:
- Tracks pirate/kraken tone, anomaly fantasy, callout language, and presentation consistency.
- Tone is pirate arcade chaos with readable eldritch flair.
- Doubloons belong to this prototype; Insight is reserved for the larger future Cuethulhu direction.

Known risks or TODOs:
- Score-earned drop callouts now rotate; future passes should tune message frequency and tone.
- Keep Doubloons language here; do not import Insight terminology from future Cuethulhu work.

Questions for the developer:
- How weird should ball drop callouts get as chaos escalates?
- Should each anomaly get a unique drop callout pool?

## Cleanup Agent

Relevant files:
- `AGENTS.md` - Project documentation or checkpoint notes.
- `CHECKPOINT_EscalationLoopPlayable.md` - Project documentation or checkpoint notes.
- `CHECKPOINT_PrototypePhysicsPlayable.md` - Project documentation or checkpoint notes.
- `scenes/Table.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/AnchorBallSystem.gd` - Handles Anchor Ball cursed-tide pull, target rules, cooldowns, visuals, and debug counters.
- `scripts/BallDropSystem.gd` - Tracks Doubloon progress toward score-tied reward drops and cue/eight-ball sink penalties.
- `scripts/BoundarySystem.gd` - Loads authored rail/boundary geometry and shared boundary helpers.
- `scripts/CannonBallSystem.gd` - Stage 3 Cannon Ball anomaly shell for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence.
- `scripts/DebugOverlay.gd` - Formats debug menu, performance overlay, toggles, and physics debug text.
- `scripts/PocketSystem.gd` - Loads authored pocket geometry and detects pocket captures.
- `scripts/PowderKegSystem.gd` - Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and pocket-side score popup presentation.

What it appears to do:
- Tracks stale comments, unclear names, ownership drift, temporary debug leftovers, and documentation freshness.
- Cleanup should preserve gameplay behavior and avoid opportunistic physics retuning.
- AGENTS.md and project_brain should be refreshed after major playable milestones.

Known risks or TODOs:
- Generated reports can drift if not regenerated after major changes.
- Scanner classifications are heuristic until files add `# index:*` metadata.

Questions for the developer:
- Which debug toggles should remain long-term?
- Which generated reports are becoming noisy or stale?
