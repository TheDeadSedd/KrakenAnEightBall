# Lore/Theme Agent

Responsibility: Tracks pirate/kraken tone, anomaly fantasy, callout language, and presentation consistency.

This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.

Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.

## Files Watched

- `AGENTS.md` - Project documentation or checkpoint notes.
- `NOTES.md` - Project documentation or checkpoint notes.
- `STACK.md` - Project documentation or checkpoint notes.
- `scenes/Main.tscn` - Godot scene file used for authored node layout and scene wiring.
- `scripts/Main.gd` - Small app shell and top-level scene wiring.
- `scripts/ScoreSystem.gd` - Converts shot-event history into Doubloons and pocket-side score popup presentation.
- `scripts/SpawnSystem.gd` - Creates balls, queues reward drops, performs safe spawn searches, and owns current anomaly spawn odds.

## Current Notes

- Tone is pirate arcade chaos with readable eldritch flair.
- Doubloons belong to this prototype; Insight is reserved for the larger future Cuethulhu direction.

## Risks Or TODOs

- Score-earned drop callouts now rotate; future passes should tune message frequency and tone.
- Keep Doubloons language here; do not import Insight terminology from future Cuethulhu work.

## Questions

- How weird should ball drop callouts get as chaos escalates?
- Should each anomaly get a unique drop callout pool?
