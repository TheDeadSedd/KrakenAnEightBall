# Project Notes

Kraken An Eight Ball is currently a pirate/eldritch arcade-chaos billiards prototype. It has grown into a systemic playtest bed for escalating table states, readable anomaly balls, and trick-shot celebration.

## Current Gameplay Loop

- Shoot with drag-and-release arcade billiards controls.
- Sink object balls for Doubloons and trick-shot event bonuses.
- Score feeds `BallDropSystem.gd` progress.
- Earned drops add more balls to the table.
- More balls create more chains, anomalies, risk, and score opportunities.
- Early cue reclaim lets the player aim again once the cue ball is safely stopped, even while some table motion continues.
- The player survives and exploits the escalating table state instead of simply clearing a rack.

Cue ball and eight ball sinks no longer end the game. Each currently costs 25 Doubloons and removes one eligible object ball from the table as a penalty.

## Current Special Balls

- Wayfinder Ball: cue-contact anomaly that can guide eligible balls toward pockets.
- Powder Keg: explodes on cue-ball or Cannon Ball contact, pushes nearby balls, removes itself, and requests fake-3D table impact shake.
- Anchor Ball: creates a cursed-tide pull on object balls, with one strongest Anchor current per target instead of stacked pulls.
- Cannon Ball: heavy iron debug-spawn anomaly built around delayed-chaos "future problem" identity: hard to start, hard to stop, dangerous once moving, and visually marked by red/orange heat presence.
- Treasure Ball: debug-spawn experiment that notices the aim-line corridor, chooses cover, avoids being watched too closely, scuttles away while perceived, and uses draw-only legs.

## Presentation Notes

- Fake-3D presentation systems add impact and table feel without moving authoritative gameplay positions.
- Powder Keg explosions and Cannon heavy impacts can shake table art and visually shimmy balls while HUD/debug UI stays stable.
- Presentation should stay readable and degrade before gameplay ambition is reduced.

## Tone

The tone is arcade chaos plus pirate/eldritch personality: readable, punchy, a little ridiculous, and celebratory. Doubloons belong to this project. Insight remains reserved for the larger future Cuethulhu direction.

## Architecture Reminder

`AGENTS.md` is the authoritative development/process document. Project Brain reports are reference-only and should be checked against real scripts/scenes before changing behavior.
