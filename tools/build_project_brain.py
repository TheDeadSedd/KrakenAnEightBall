#!/usr/bin/env python3
"""Generate local reference reports for Kraken An Eight Ball.

This script is intentionally boring and local-only:
- It scans project files for lightweight metadata and simple heuristics.
- It never edits gameplay/source files.
- It writes only inside project_brain/.
"""

from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "project_brain"
AGENTS_DIR = OUTPUT_DIR / "agents"

SCAN_EXTENSIONS = {".gd", ".tscn", ".tres", ".res", ".md"}
SKIP_DIRS = {".git", ".godot", "project_brain", "__pycache__"}
SKIP_PREFIXES = {
    ("addons", "godot-git-plugin"),
}

INDEX_SECTIONS = [
    "Mechanics",
    "Physics",
    "Anomaly Balls",
    "Systems",
    "UI",
    "Debug Tools",
    "Performance Concerns",
    "In Progress",
    "Needs Review",
    "Recently Changed",
    "Unclassified",
]

KNOWN_CATEGORY_HINTS = {
    "AGENTS.md": ["Systems", "Debug Tools", "In Progress", "Needs Review"],
    "CHECKPOINT_EscalationLoopPlayable.md": ["Needs Review"],
    "CHECKPOINT_PrototypePhysicsPlayable.md": ["Needs Review"],
    "NOTES.md": ["Needs Review"],
    "STACK.md": ["Needs Review"],
    "scenes/Ball.tscn": ["Systems"],
    "scenes/CueBall.tscn": ["Mechanics", "Systems", "UI"],
    "scenes/Main.tscn": ["Systems", "UI"],
    "scenes/MainMenu.tscn": ["Systems", "UI", "In Progress"],
    "scenes/Table.tscn": ["Physics", "Systems"],
    "scripts/AimPreview.gd": ["Physics", "UI", "Performance Concerns"],
    "scripts/AnchorBallSystem.gd": ["Anomaly Balls", "Systems", "Performance Concerns", "In Progress"],
    "scripts/AudioSettings.gd": ["Systems", "UI"],
    "scripts/BackRoomDealPanel.gd": ["UI", "Systems", "In Progress"],
    "scripts/BackRoomDealSystem.gd": ["Systems", "UI", "In Progress"],
    "scripts/BallAudioSystem.gd": ["Systems", "Performance Concerns", "In Progress"],
    "scripts/BallDropMeter.gd": ["UI", "Systems", "Needs Review"],
    "scripts/BallDropSystem.gd": ["Mechanics", "Systems", "UI", "Performance Concerns", "In Progress"],
    "scripts/BallPlacementSystem.gd": ["Systems", "UI", "Performance Concerns", "In Progress"],
    "scripts/Ball.gd": ["Mechanics", "Physics", "Performance Concerns"],
    "scripts/BoundarySystem.gd": ["Physics", "Systems", "Performance Concerns"],
    "scripts/CannonBallSystem.gd": ["Anomaly Balls", "Systems", "Performance Concerns", "In Progress"],
    "scripts/CueController.gd": ["Mechanics", "UI"],
    "scripts/CueProgressionSystem.gd": ["Systems", "UI", "In Progress"],
    "scripts/DebugPanel.gd": ["UI", "Debug Tools", "Performance Concerns", "In Progress"],
    "scripts/DebugOverlay.gd": ["UI", "Debug Tools"],
    "scripts/EmbezzlerSystem.gd": ["Anomaly Balls", "Systems", "Performance Concerns", "In Progress"],
    "scripts/EventMetadata.gd": ["Mechanics", "Systems"],
    "scripts/GameplayMusicSystem.gd": ["Systems", "UI", "In Progress"],
    "scripts/HudFeed.gd": ["UI", "Systems", "Performance Concerns", "In Progress"],
    "scripts/ItemIconDraw.gd": ["UI", "Systems"],
    "scripts/Main.gd": ["Systems", "UI"],
    "scripts/MainMenu.gd": ["Systems", "UI", "In Progress"],
    "scripts/MainMenuCueLockerPanel.gd": ["UI", "Systems", "In Progress"],
    "scripts/MainMenuPresentationOverlay.gd": ["UI", "Performance Concerns", "In Progress"],
    "scripts/MainMenuRunHistoryPanel.gd": ["UI", "Systems", "In Progress"],
    "scripts/OathHUD.gd": ["UI", "Systems", "In Progress"],
    "scripts/OathSystem.gd": ["Systems", "Mechanics", "Debug Tools", "In Progress"],
    "scripts/OptionsMenu.gd": ["UI", "Systems"],
    "scripts/PauseMenu.gd": ["UI", "Systems", "Debug Tools", "In Progress"],
    "scripts/PassageHUD.gd": ["UI", "Systems", "In Progress"],
    "scripts/PassageSystem.gd": ["Mechanics", "Systems", "In Progress"],
    "scripts/PocketSystem.gd": ["Physics", "Systems", "Performance Concerns"],
    "scripts/PocketStreakPresenter.gd": ["UI", "Systems", "Performance Concerns", "In Progress"],
    "scripts/PocketStreakSystem.gd": ["Mechanics", "Systems", "UI", "In Progress"],
    "scripts/PowderKegSystem.gd": ["Anomaly Balls", "Systems", "Performance Concerns"],
    "scripts/ProgressionSystem.gd": ["Systems", "UI", "In Progress"],
    "scripts/QuartermasterHUD.gd": ["UI", "Systems", "Performance Concerns", "In Progress"],
    "scripts/QuartermasterOfferRefreshEffect.gd": ["UI", "Performance Concerns", "In Progress"],
    "scripts/QuartermasterSystem.gd": ["Systems", "UI", "In Progress"],
    "scripts/ReserveDeploymentPresenter.gd": ["UI", "Systems", "Performance Concerns", "In Progress"],
    "scripts/ReserveSlotsUI.gd": ["UI", "Systems", "In Progress"],
    "scripts/ReserveSystem.gd": ["Systems", "UI", "In Progress"],
    "scripts/RunHistorySystem.gd": ["Systems", "UI", "In Progress"],
    "scripts/RunLedgerHUD.gd": ["UI", "Systems", "In Progress"],
    "scripts/RunStatsHUD.gd": ["UI", "Systems", "In Progress"],
    "scripts/RunStatsSystem.gd": ["Systems", "UI", "In Progress"],
    "scripts/ScoreSystem.gd": ["Mechanics", "Systems", "UI", "In Progress"],
    "scripts/ShotEventSystem.gd": ["Mechanics", "Systems"],
    "scripts/SpawnSystem.gd": ["Mechanics", "Systems", "In Progress"],
    "scripts/Table.gd": ["Mechanics", "Physics", "Systems", "Performance Concerns"],
    "scripts/TableDecorRandomizer.gd": ["UI", "Systems"],
    "scripts/TableEventMenu.gd": ["UI", "Systems", "In Progress"],
    "scripts/TableEventMeter.gd": ["UI", "Systems", "In Progress"],
    "scripts/TableEventSystem.gd": ["Mechanics", "Systems", "UI", "Performance Concerns", "In Progress"],
    "scripts/TableImpactShakeSystem.gd": ["UI", "Systems", "Performance Concerns", "In Progress"],
    "scripts/TableObstacleSystem.gd": ["Physics", "Systems", "Debug Tools", "Performance Concerns", "In Progress"],
    "scripts/TreasureBallSystem.gd": ["Anomaly Balls", "Systems", "Performance Concerns", "In Progress"],
    "scripts/WayfinderSystem.gd": ["Anomaly Balls", "Systems"],
    "scripts/WayfinderCurrentPresenter.gd": ["UI", "Systems", "Performance Concerns", "In Progress"],
}

PLANNED_SYSTEMS = {}

AGENT_DEFINITIONS = {
    "mechanics_agent": {
        "display": "Mechanics Agent",
        "responsibility": "Tracks core play loops, shot lifecycle, scoring hooks, shot-event history, ball identity, and moment-to-moment billiards feel.",
        "watch_keywords": ["table", "ball", "cue", "shot", "score", "spawn", "event", "placement", "intervention", "streak"],
        "notes": [
            "Current loop: better shots create Doubloons, completed Kraken Requests, Passage reduction, Kraken Intervention opportunities, player-chosen Table Events, more balls/anomalies, more interactions, and successful Passage rewards.",
            "Passage is the current run objective; Kraken Intervention is the active chosen-chaos economy; automatic BallDrop rewards are retired/gated.",
            "Early cue reclaim is shot-lifecycle coordination in Table.gd and should stay lightweight.",
            "Cue/eight-ball sinks are penalties now, not run-ending conditions.",
            "ShotEventSystem.gd now tracks foundational, skilled, heroic, legendary, and sink-moment events through causal shot history.",
            "PocketStreakSystem.gd tracks same-pocket streak bonuses separately from MULTI_SINK.",
            "RunStatsSystem.gd tracks current-run stats only; RunHistorySystem.gd persists finalized records.",
            "Preserve cue feel, shot feel, pocket feel, and scoring values during cleanup.",
            "Automatic score-triggered BallDrop rewards are retired/gated; BallDropSystem is mostly legacy/debug support plus cue/eight-ball penalty handling.",
        ],
        "questions": [
            "Which new shot-event thresholds need tuning after longer playtests?",
            "Which Kraken Intervention costs/weights/thresholds and Passage request rewards need playtest tuning?",
        ],
    },
    "systems_agent": {
        "display": "Systems Agent",
        "responsibility": "Tracks module boundaries, ownership rules, scene wiring, and coordinator responsibilities.",
        "watch_keywords": ["system", "table", "spawn", "pocket", "boundary", "main", "agent", "quartermaster", "reserve", "placement", "menu", "audio", "intervention", "broadside", "current", "passage", "oath", "progression", "history", "locker"],
        "notes": [
            "Table.gd should coordinate systems without absorbing new feature logic.",
            "Scene-authored geometry remains the source of truth.",
            "MainMenu.gd owns title-screen presentation and top-level panel orchestration; Run History and Cue Locker presentation live in focused panel scripts.",
            "OptionsMenu.gd and AudioSettings.gd own reusable options/audio settings instead of the former menu shell behavior.",
            "PassageSystem.gd owns current-run Passage and Kraken Requests; EventMetadata.gd owns reusable request/event descriptions.",
            "OathSystem.gd owns Oath definitions, timers, penalties, Quartermaster lock state, and cue modifier suppression.",
            "ProgressionSystem.gd owns persistent Kraken Favor; CueProgressionSystem.gd owns cue definitions/equipment/effect snapshots.",
            "TableEventSystem.gd owns Kraken Intervention thresholds, pending readiness, weighted offers, purchases, and event routing.",
            "Broadside Attack is the first authored staged intervention milestone and should remain a readable pirate artillery scenario.",
            "QuartermasterSystem.gd owns rotating offers and paid refresh; QuartermasterHUD.gd owns live side-rail shop presentation; BackRoomDealSystem.gd owns Back Room economy; ReserveSystem.gd owns slot data; BallPlacementSystem.gd owns item-agnostic placement.",
            "BallAudioSystem.gd owns pooled event-driven collision SFX instead of burying audio in physics.",
            "GameplayMusicSystem.gd owns low-volume looping gameplay music separate from SFX; music should support atmosphere without covering collision/event readability.",
            "TableImpactShakeSystem.gd owns presentation-only fake-3D table shake so gameplay geometry and HUD stay stable.",
            "TableObstacleSystem.gd owns debris spawning/debug and custom authored-polygon collision; it should not become general Table physics.",
            "Coalesce repeated input/event work in the owning coordinator instead of letting systems rebuild many times per frame.",
            "Prefer event/state-driven updates over continuous rescans when systems can track meaningful changes safely.",
        ],
        "questions": [
            "Which future systems should reuse BallPlacementSystem.gd before adding new placement code?",
            "Which debug surfaces should graduate into permanent quality settings?",
        ],
    },
    "anomaly_ball_agent": {
        "display": "Anomaly Ball Agent",
        "responsibility": "Tracks Wayfinder, Powder Keg, Anchor curse seeds, Cannon Ball, Treasure Ball, Embezzler, and future anomaly behavior boundaries.",
        "watch_keywords": ["wayfinder", "powder", "anchor", "cannon", "treasure", "embezzler", "anomaly", "ball", "current"],
        "notes": [
            "Wayfinder, Powder Keg, Anchor, Cannon, Treasure, and Embezzler all have focused system boundaries.",
            "Wayfinder Current is the cursed-tide extension of Wayfinder behavior: temporary possession, transferable guided momentum, transfer-on-hit propagation, and current-caused scoring support.",
            "Anchor's old continuous field identity is retired; current Anchor behavior is curse-seed selection, chains, cue-control-gated tightening, warning, spread, and collapse.",
            "Cannon Ball has debug/Table Event drop paths, collision tuning, Powder Keg launch, Broadside launch use, heavy-impact shake, and high-speed heat presence.",
            "Treasure Ball is a perception-grace/hiding/scuttle experiment that can appear through rare cargo/contraband discovery and awards a large Doubloon payout when sunk.",
            "Treasure should feel like a cautious sneaky thief, not a shortest-path optimizer, and remains separate from the Embezzler.",
            "Embezzler is capped and debug-spawnable; it copies Doubloon value, tracks a secret pocket, uses once-per-shot hide-or-run decisions, and resolves capture/escape.",
        ],
        "questions": [
            "Which future anomalies should interact with Anchor curse chains or Embezzler escape pressure?",
            "Should anomaly-touch scoring expand beyond current event rewards?",
        ],
    },
    "ui_agent": {
        "display": "UI Agent",
        "responsibility": "Tracks HUD, title screen, pause menu, modular debug panels, score popups, callouts, cue presentation, shop/reserve UI, and player-facing text.",
        "watch_keywords": ["debug", "score", "ui", "main", "menu", "pause", "quartermaster", "reserve", "cue", "popup", "label", "scene", "shake", "hud", "feed", "meter", "streak", "passage", "oath", "history", "locker"],
        "notes": [
            "MainMenu.tscn uses layered artwork with lightweight moon glow, star, shimmer, and fog overlays.",
            "MainMenu.gd now orchestrates focused Options, Run History, and Cue Locker panels rather than owning all row/card logic.",
            "OptionsMenu.gd is real UI with Master/Music/SFX sliders and pause/main-menu return contexts.",
            "PassageHUD.gd owns Passage/Kraken Wants presentation and request tooltip/reroll UI.",
            "OathHUD.gd owns compact active-Oath indicator/tooltip presentation.",
            "RunStatsHUD.gd owns the live ledger overlay; RunLedgerHUD.gd owns the BALLS/SUNK HUD cluster.",
            "TableEventMeter.gd owns the horizontal bottom-center Kraken Intervention meter and ready icon.",
            "TableEventMenu.gd owns the compact Request Kraken Intervention menu, offer cards, and Oath choice panel for single-offer replacement.",
            "HudFeed.gd owns the bottom-left rolling captain's-log feed with hover review and multiline wrapping.",
            "QuartermasterHUD.gd owns the live right-side side-rail shop; BackRoomDealPanel.gd owns Back Room option presentation; PauseMenu.gd no longer owns the active shop purchasing flow.",
            "PauseMenu.gd owns menu shell behavior, modular debug-panel toggles, and temporary Event Test Button checkboxes while gameplay is paused.",
            "DebugPanel.gd owns draggable pause-safe panel shells; DebugOverlay.gd formats visible panel content and the full F3 overlay.",
            "ReserveSlotsUI.gd owns icon-only table-frame slots; ReserveDeploymentPresenter.gd owns cursor icon/tether presentation.",
            "Score presentation now uses evolving pocket-side score stacks with Foundational/Skilled/Heroic/Legendary tier identity, count-up totals, and lane/yield behavior.",
            "PocketStreakPresenter.gd queues X2/X3/X4+ presentation, audio, and localized whirlpool/threat tells. These are deliberately psychological tells, not unfinished suction gameplay.",
            "Debug labels and test buttons should stay clearly marked and not leak temporary test wording into player-facing strings.",
            "TableImpactShakeSystem.gd owns fake-3D table impact shake and draw-only ball shimmy presentation.",
        ],
        "questions": [
            "Which debug panels should become default-on for regular playtesting?",
            "Which popup effects should degrade first on low-end machines?",
        ],
    },
    "performance_agent": {
        "display": "Performance Agent",
        "responsibility": "Tracks visual cost, broad-phase health, trail redraws, particle load, and stress-test readiness.",
        "watch_keywords": ["performance", "debug", "trail", "particle", "anchor", "powder", "treasure", "embezzler", "boundary", "pocket", "aim", "shake", "audio", "quartermaster", "reserve", "menu", "intervention", "streak", "current", "feed", "obstacle", "debris", "oath"],
        "notes": [
            "Do not solve chaos by preventing chaos; degrade visuals first.",
            "High ball counts and large earned chain reactions are intended.",
            "Coalesce repeated work before reducing gameplay ambition; avoid unnecessary redraws and reuse/pool temporary visuals where practical.",
            "Optimization should preserve readability as well as performance.",
            "Hidden debug panels/overlays should not keep formatting strings or requesting broad snapshots every frame.",
            "BallAudioSystem.gd uses pooled players, thresholds, and cooldowns so collision SFX scales with chaos.",
            "Pocket Streak audio uses a finite clip, fixed pool, cooldowns, caps, and a dedicated reverb bus; do not reintroduce AudioStreamGenerator.",
            "Anchor is now state/event-driven curse-seed gameplay, not continuous force-field simulation.",
            "Embezzler is capped and event-driven around score gain, aim pressure, once-per-shot decisions, capture, and escape.",
            "Score stack coalescing reduces independent label/tween pressure during high-chaos scoring.",
            "Kraken Intervention is shot/event-driven; old automatic BallDrop reward spawning should remain gated and backstage.",
            "Wayfinder Current is intentionally uncapped in affected-ball count for now, but keeps radius, lifetime, transfer-depth, and eligibility safeguards.",
            "Pocket Streak whirlpool/threat tells are localized presentation-only effects with no suction/pull by deliberate design.",
            "Quartermaster stock refresh is event-driven; Reserve and placement presentation should avoid continuous scans.",
            "TableObstacleSystem.gd should keep authored-polygon collision cheap through moving-ball filtering, cached transforms, and broadphase rejection.",
            "Hover-only HUD/UI should respect cue-drag suppression so active aiming owns mouse hover behavior.",
            "Main menu atmosphere is draw-only/lightweight and should stay presentation-only.",
            "AimPreview.gd uses broad-phase filtering, rebuild coalescing, and debug counters to keep swept prediction affordable without lying about grazes.",
        ],
        "questions": [
            "What visual-quality tiers should exist for trails, particles, aura effects, and score labels?",
            "When should pooling replace ad hoc temporary visual nodes?",
        ],
    },
    "lore_agent": {
        "display": "Lore/Theme Agent",
        "responsibility": "Tracks pirate/kraken tone, anomaly fantasy, callout language, and presentation consistency.",
        "watch_keywords": ["agents", "notes", "stack", "score", "spawn", "main", "menu", "quartermaster", "reserve", "passage", "oath", "favor", "cue"],
        "notes": [
            "Tone is pirate arcade chaos with readable eldritch flair and a little mischievous weirdness.",
            "The title screen leans pirate arcade adventure and dangerous ocean night, not oppressive cosmic horror.",
            "Passage fantasy: the Kraken intends to take the ship, and the player bargains for safe passage with wealth and skill.",
            "Kraken Intervention should feel like bargaining with the table for dangerous aid and choosing intentional chaos.",
            "Oaths should feel like risky promises sworn to the Kraken, not ordinary UI reroll buttons.",
            "Kraken Favor is the persistent proof that the Kraken remembers successful voyages.",
            "Broadside Attack should feel authored and nautical: warning beat, Powder Keg lanes, then Cannon Balls from a cursed gun deck.",
            "Wayfinder Current should feel like a cursed tide possessing nearby balls with transferable guided momentum.",
            "Pocket Streak X4+ should feel like a hungry pocket waking up without adding real suction yet.",
            "The Quartermaster/Reserve loop should feel like mounted tactical table hardware rather than a debug catalog.",
            "Doubloons belong to this game; Insight is reserved for the larger future Cuethulhu direction.",
        ],
        "questions": [
            "How weird should Kraken Intervention and HudFeed language get as chaos escalates?",
            "Should each anomaly get a unique drop callout pool?",
        ],
    },
    "cleanup_agent": {
        "display": "Cleanup Agent",
        "responsibility": "Tracks stale comments, unclear names, ownership drift, temporary debug leftovers, and documentation freshness.",
        "watch_keywords": ["agent", "debug", "system", "table", "spawn", "score", "shot", "quartermaster", "reserve", "menu", "audio", "passage", "oath", "cue", "history"],
        "notes": [
            "Cleanup should preserve gameplay behavior and avoid opportunistic physics retuning.",
            "AGENTS.md, NOTES.md, STACK.md, and project_brain should be refreshed after major playable milestones.",
            "Generated docs should reflect Passage, Oaths, Kraken Intervention/Table Events, Quartermaster Refresh, Back Room Deals, Run Stats/History, Kraken Favor, Cue Locker/modifiers, debris, Broadside Attack, Wayfinder Current, Pocket Streak, HudFeed, live Quartermaster HUD, gameplay music, Anchor curse seeds, Treasure payout/discovery, Embezzler, score stacks, and expanded shot events.",
        ],
        "questions": [
            "Which debug toggles should remain long-term?",
            "Which generated reports are becoming noisy or stale?",
        ],
    },
}


@dataclass
class FileInfo:
    path: str
    title: str
    categories: list[str] = field(default_factory=list)
    status: str = ""
    owner: str = ""
    notes: str = ""
    summary: str = ""
    uncertain: bool = False


def main() -> None:
    files = scan_project_files()
    changed_paths = get_recently_changed_paths()
    write_output("README.md", build_readme())
    write_output("PROJECT_INDEX.md", build_project_index(files, changed_paths))
    write_output("AGENT_REPORT.md", build_agent_report(files))
    for agent_id, definition in AGENT_DEFINITIONS.items():
        write_output(f"agents/{agent_id}.md", build_agent_file(agent_id, definition, files))


def scan_project_files() -> list[FileInfo]:
    infos: list[FileInfo] = []
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix.lower() not in SCAN_EXTENSIONS:
            continue
        if should_skip(path):
            continue

        rel_path = to_posix(path.relative_to(ROOT))
        text = read_text(path)
        metadata = parse_index_metadata(text)
        info = build_file_info(rel_path, metadata)
        infos.append(info)
    return infos


def should_skip(path: Path) -> bool:
    rel_parts = path.relative_to(ROOT).parts
    if any(part in SKIP_DIRS for part in rel_parts):
        return True
    for prefix in SKIP_PREFIXES:
        if rel_parts[: len(prefix)] == prefix:
            return True
    return False


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def parse_index_metadata(text: str) -> dict[str, str]:
    metadata: dict[str, str] = {}
    pattern = re.compile(r"^\s*(?:#|//|;)?\s*index:(\w+)\s+(.*?)\s*$", re.IGNORECASE)
    for line in text.splitlines()[:80]:
        match = pattern.match(line)
        if match:
            metadata[match.group(1).lower()] = match.group(2).strip()
    return metadata


def build_file_info(rel_path: str, metadata: dict[str, str]) -> FileInfo:
    title = metadata.get("title") or guess_title(rel_path)
    categories = categories_from_metadata(metadata)
    status = metadata.get("status", "")
    owner = metadata.get("owner", "")
    notes = metadata.get("notes", "")

    if not categories:
        categories = guess_categories(rel_path)

    if not owner:
        owner = guess_owner(rel_path)

    summary = guess_summary(rel_path)
    uncertain = not categories or categories == ["Unclassified"]
    if not categories:
        categories = ["Unclassified"]

    if status.lower() == "in progress" and "In Progress" not in categories:
        categories.append("In Progress")

    return FileInfo(
        path=rel_path,
        title=title,
        categories=dedupe(categories),
        status=status,
        owner=owner,
        notes=notes,
        summary=summary,
        uncertain=uncertain,
    )


def categories_from_metadata(metadata: dict[str, str]) -> list[str]:
    raw_category = metadata.get("category", "")
    categories: list[str] = []
    for part in re.split(r"[/,]", raw_category):
        normalized = normalize_section(part.strip())
        if normalized:
            categories.append(normalized)
    return dedupe(categories)


def normalize_section(name: str) -> str:
    lowered = name.lower()
    for section in INDEX_SECTIONS:
        if lowered == section.lower():
            return section
    return ""


def guess_title(rel_path: str) -> str:
    name = Path(rel_path).stem
    return name.replace("_", " ").replace("-", " ")


def guess_categories(rel_path: str) -> list[str]:
    if rel_path in KNOWN_CATEGORY_HINTS:
        return KNOWN_CATEGORY_HINTS[rel_path]

    lowered = rel_path.lower()
    categories: list[str] = []

    if "balldrop" in lowered or "ball_drop" in lowered:
        categories.extend(["Mechanics", "Systems", "UI", "Performance Concerns", "In Progress"])
    if any(token in lowered for token in ["wayfinder", "powder", "anchor", "treasure", "embezzler", "anomaly"]):
        categories.extend(["Anomaly Balls", "Performance Concerns"])
    if "debug" in lowered:
        categories.extend(["UI", "Debug Tools"])
    if any(token in lowered for token in ["quartermaster", "reserve", "placement", "pause", "menu"]):
        categories.extend(["Systems", "UI", "In Progress"])
    if "audio" in lowered:
        categories.extend(["Systems", "Performance Concerns"])
    if any(token in lowered for token in ["checkpoint", "notes", "stack"]):
        categories.append("Needs Review")

    return dedupe(categories) or ["Unclassified"]


def guess_owner(rel_path: str) -> str:
    name = Path(rel_path).name
    exact_owners = {
        "AnchorBallSystem.gd": "anomaly_ball_agent",
        "AudioSettings.gd": "systems_agent",
        "BackRoomDealPanel.gd": "ui_agent",
        "BackRoomDealSystem.gd": "systems_agent",
        "CannonBallSystem.gd": "anomaly_ball_agent",
        "CueProgressionSystem.gd": "systems_agent",
        "EmbezzlerSystem.gd": "anomaly_ball_agent",
        "EventMetadata.gd": "systems_agent",
        "PowderKegSystem.gd": "anomaly_ball_agent",
        "TreasureBallSystem.gd": "anomaly_ball_agent",
        "WayfinderSystem.gd": "anomaly_ball_agent",
        "WayfinderCurrentPresenter.gd": "ui_agent",
        "ItemIconDraw.gd": "ui_agent",
        "Ball.gd": "mechanics_agent",
        "BallAudioSystem.gd": "systems_agent",
        "BallPlacementSystem.gd": "systems_agent",
        "CueController.gd": "mechanics_agent",
        "ShotEventSystem.gd": "mechanics_agent",
        "PocketStreakSystem.gd": "mechanics_agent",
        "Table.gd": "mechanics_agent",
        "TableEventSystem.gd": "systems_agent",
        "AimPreview.gd": "performance_agent",
        "BoundarySystem.gd": "systems_agent",
        "TableImpactShakeSystem.gd": "ui_agent",
        "PocketSystem.gd": "systems_agent",
        "SpawnSystem.gd": "systems_agent",
        "QuartermasterSystem.gd": "systems_agent",
        "QuartermasterHUD.gd": "ui_agent",
        "ReserveSystem.gd": "systems_agent",
        "GameplayMusicSystem.gd": "systems_agent",
        "Main.gd": "systems_agent",
        "MainMenu.gd": "ui_agent",
        "MainMenuCueLockerPanel.gd": "ui_agent",
        "MainMenuPresentationOverlay.gd": "ui_agent",
        "MainMenuRunHistoryPanel.gd": "ui_agent",
        "OathHUD.gd": "ui_agent",
        "OathSystem.gd": "systems_agent",
        "OptionsMenu.gd": "ui_agent",
        "PauseMenu.gd": "ui_agent",
        "PassageHUD.gd": "ui_agent",
        "PassageSystem.gd": "systems_agent",
        "DebugOverlay.gd": "ui_agent",
        "DebugPanel.gd": "ui_agent",
        "BallDropMeter.gd": "ui_agent",
        "TableEventMeter.gd": "ui_agent",
        "TableEventMenu.gd": "ui_agent",
        "HudFeed.gd": "ui_agent",
        "PocketStreakPresenter.gd": "ui_agent",
        "QuartermasterOfferRefreshEffect.gd": "ui_agent",
        "ReserveDeploymentPresenter.gd": "ui_agent",
        "ReserveSlotsUI.gd": "ui_agent",
        "ProgressionSystem.gd": "systems_agent",
        "RunHistorySystem.gd": "systems_agent",
        "RunLedgerHUD.gd": "ui_agent",
        "RunStatsHUD.gd": "ui_agent",
        "RunStatsSystem.gd": "systems_agent",
        "ScoreSystem.gd": "ui_agent",
        "BallDropSystem.gd": "systems_agent",
        "TableDecorRandomizer.gd": "ui_agent",
        "TableObstacleSystem.gd": "systems_agent",
        "AGENTS.md": "cleanup_agent",
    }
    if name in exact_owners:
        return exact_owners[name]

    lowered = rel_path.lower()
    scores: dict[str, int] = {}
    for agent_id, definition in AGENT_DEFINITIONS.items():
        score = 0
        for keyword in definition["watch_keywords"]:
            if keyword in lowered:
                score += 1
        scores[agent_id] = score
    best_agent = max(scores, key=scores.get)
    return best_agent if scores[best_agent] > 0 else "cleanup_agent"


def guess_summary(rel_path: str) -> str:
    name = Path(rel_path).name
    lowered = rel_path.lower()
    if name == "Table.gd":
        return "High-level table coordinator, shot lifecycle owner, early cue-reclaim gate, and current home of authoritative arcade ball physics."
    if name == "PassageSystem.gd":
        return "Owns current-run Passage requirement, active Kraken Request, request rewards/completion, request rerolls, Passage pressure, and successful-run completion state."
    if name == "PassageHUD.gd":
        return "Compact live Passage/Kraken Wants HUD presenter with request tooltip and request reroll forwarding."
    if name == "EventMetadata.gd":
        return "Central event/request metadata registry for labels and descriptions used by Passage tooltips and future reusable references."
    if name == "OathSystem.gd":
        return "Owns data-driven Oath definitions, active Oath state, shot timers, completion/failure, Quartermaster lock state, cue modifier suppression, and debug helpers."
    if name == "OathHUD.gd":
        return "Compact active-Oath HUD indicator and tooltip presenter using OathSystem snapshots."
    if name == "ProgressionSystem.gd":
        return "Persistent Kraken Favor owner for user://progression.json, successful-Passage reward calculation, safe Favor spending/adding, and cue progression data storage."
    if name == "CueProgressionSystem.gd":
        return "Owns cue part definitions, unlock/equip validation, equipped loadout snapshots, effect definitions, and active cue modifier snapshots."
    if name == "RunStatsSystem.gd":
        return "Current-run ledger system for money split, sunk/active counts, run time, Passage/Oath/cue snapshots, economy counters, and shared Run Stats row metadata."
    if name == "RunStatsHUD.gd":
        return "Live top-left Run Stats button and compact ledger overlay presenter."
    if name == "RunLedgerHUD.gd":
        return "Compact lower-HUD BALLS/SUNK counter cluster presenter."
    if name == "RunHistorySystem.gd":
        return "Persistent finalized run history owner for user://run_history.json, record normalization, duplicate-save prevention, clearing, and 25-record retention."
    if name == "MainMenuRunHistoryPanel.gd":
        return "Main Menu Run History panel UI presenter for list rows, empty state, Back, Clear History, and confirmation."
    if name == "MainMenuCueLockerPanel.gd":
        return "Main Menu Cue Locker panel UI presenter for Favor, equipped loadout, grouped cue parts, unlock/equip controls, and Back."
    if name == "OptionsMenu.gd":
        return "Reusable Options panel presenter with Audio sliders and context-aware Back behavior for main menu and pause menu."
    if name == "AudioSettings.gd":
        return "Audio settings owner for user://settings.cfg, Master/Music/SFX bus lookup, volume conversion, and runtime bus volume application."
    if name == "BackRoomDealSystem.gd":
        return "Back Room Deal data/economy owner for unlock threshold, cost, special-ball deal definitions, availability checks, spending, and Reserve insertion."
    if name == "BackRoomDealPanel.gd":
        return "Compact Back Room Deal panel presenter for title/flavor, deal rows, unavailable reasons, close/cancel, and selected deal emission."
    if name == "ItemIconDraw.gd":
        return "Shared presentation-only compact item/ball preview drawing helpers for shop, Reserve, Back Room, and related HUD surfaces."
    if name == "TableObstacleSystem.gd":
        return "Owns TableObstacle spawning/clearing, debug placement, authored collision polygon extraction/cache, broadphase, custom ball collision, debug draw, and counters."
    if name == "TableDecorRandomizer.gd":
        return "Presentation-only table decor variant randomizer for authored prop visuals."
    if name == "Ball.gd":
        return "Individual ball state, visuals, friction helpers, trails, draw-only anomaly presentation such as Cannon heat and Treasure legs, and anomaly identity flags."
    if name == "SpawnSystem.gd":
        return "Creates balls, performs safe spawn searches, owns regular anomaly odds, executes Table Event drop/launch helpers, and routes debug Anchor requests into curse-seed transformation."
    if name == "BallPlacementSystem.gd":
        return "Reusable item-agnostic placement mode with ghost preview, safe-position validation, and confirm/cancel flow for shop, Reserve, debug, and future placement effects."
    if name == "QuartermasterSystem.gd":
        return "Owns Quartermaster inventory, prices, affordability, active rotating offers, paid event-driven refresh scaling/shot decay, access blockers, and purchase-to-Reserve state."
    if name == "QuartermasterHUD.gd":
        return "Live right-side Quartermaster side-rail shop presentation with item slots, refresh/Back Room buttons, costs, hover tooltips, affordability tinting, and cue-safe clicks."
    if name == "QuartermasterOfferRefreshEffect.gd":
        return "Presentation-only fresh-stock glow/shimmer effect for newly refreshed Quartermaster offers."
    if name == "ReserveSystem.gd":
        return "Owns three Reserve slot contents, selected/deploying state, deployment confirm/cancel bookkeeping, snapshots, and simple debug counters."
    if name == "ReserveSlotsUI.gd":
        return "Icon-only upper table-frame Reserve slot UI with hover glow, click consumption, and deployment request wiring."
    if name == "ReserveDeploymentPresenter.gd":
        return "Draw-only cursor icon and dotted tether presentation while deploying a reserved item."
    if name == "BallDropSystem.gd":
        return "Backstage legacy/gated automatic reward-drop helpers plus active cue/eight-ball sink penalty handling and debug plumbing."
    if name == "BallDropMeter.gd":
        return "Retired/legacy vertical HUD meter for the old automatic BallDrop loop; current progression UI is TableEventMeter."
    if name == "TableEventSystem.gd":
        return "Owns Kraken Intervention shot-earned threshold tracking, pending readiness, weighted offers, Oath-backed single-slot replacement, purchases, cargo discovery, debug triggers, and player-chosen Table Event execution routing."
    if name == "TableEventMeter.gd":
        return "Horizontal bottom-center KRAKEN INTERVENTION meter with shot progress, percent text, pulse feedback, and ready icon."
    if name == "TableEventMenu.gd":
        return "Compact Request Kraken Intervention menu with weighted offer cards, Oath choice replacement panel, affordability, rarity display, hover, close, and purchase/replacement forwarding."
    if name == "HudFeed.gd":
        return "Bottom-left rolling captain's-log feed with fading stack, hover-scroll review, history, and multiline wrapped entries."
    if name == "PocketStreakSystem.gd":
        return "Tracks same-pocket object-ball streaks per shot, same-pocket scoring subtotals, multiplier context, and double-award safety."
    if name == "PocketStreakPresenter.gd":
        return "Queued Pocket Streak multiplier presentation, fixed-pool audio/reverb, X4+ whirlpool visuals, and localized presentation-only threat tells."
    if name == "GameplayMusicSystem.gd":
        return "Low-volume looping gameplay music owner, separate from collision, UI, Pocket Streak, and anomaly SFX."
    if name == "TableImpactShakeSystem.gd":
        return "Handles presentation-only table impact shake and draw-only ball shimmy for Powder Keg explosions and Cannon heavy impacts."
    if name == "ScoreSystem.gd":
        return "Converts shot-event history into Doubloons, Treasure/Embezzler payout awards, and evolving pocket-side score stack presentation."
    if name == "ShotEventSystem.gd":
        return "Tracks causal per-shot foundational, skilled, heroic, legendary, and sink-moment scoring events for sunk balls."
    if name == "WayfinderSystem.gd":
        return "Handles Wayfinder activation, guided redirects, temporary Wayfinder Current carriers, transfer-on-hit guided momentum, and current-caused scoring snapshots."
    if name == "WayfinderCurrentPresenter.gd":
        return "Draw-only Wayfinder Current readability presentation for initial teal/gold pulses and transfer flashes."
    if name == "PowderKegSystem.gd":
        return "Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts."
    if name == "AnchorBallSystem.gd":
        return "Handles the new Anchor curse-seed model: eight-ball penalty seed creation, chains/leashes, cue-control-gated tightening, warning timer, spread, collapse, presentation, and debug counters."
    if name == "CannonBallSystem.gd":
        return "Cannon Ball anomaly system for identity, visuals, heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and high-speed heat presence."
    if name == "TreasureBallSystem.gd":
        return "Treasure Ball system for identity tracking, AimPreview corridor perception grace, committed hide targets, corridor/pocket-aware fleeing, soft scuttle movement, self-braking, reduced self-steer shove, and draw-only leg reporting; payout/discovery live in scoring/event systems."
    if name == "EmbezzlerSystem.gd":
        return "Embezzler anomaly system for copied Doubloon storage, secret target pocket, willingness, once-per-shot hide-or-run decisions, escape commitment, pocket roll, capture payout, escape cleanup, visuals, and debug counters."
    if name == "DebugOverlay.gd":
        return "Formats debug menu, modular visible debug panels, requested-section performance snapshots, full F3 overlay, toggles, and physics debug text."
    if name == "DebugPanel.gd":
        return "Reusable draggable debug panel shell with pause-safe input consumption and lightweight text display."
    if name == "AimPreview.gd":
        return "Draws polished aim lines, swept cue/target prediction, pocket stopping, endpoint markers, Treasure/Embezzler perception snapshots, and AimPreview broad-phase counters."
    if name == "BoundarySystem.gd":
        return "Loads authored rail/boundary geometry and shared boundary helpers."
    if name == "PocketSystem.gd":
        return "Loads authored pocket geometry and detects pocket captures."
    if name == "CueController.gd":
        return "Owns cue visuals, grab-zone hit testing, pullback, and strike presentation."
    if name == "Main.gd":
        return "Small app shell and top-level scene wiring."
    if name == "MainMenu.gd":
        return "Title-screen shell, layered menu presentation, button input, and transition into the gameplay scene."
    if name == "MainMenuPresentationOverlay.gd":
        return "Draw-only layered title-screen atmosphere for moon glow, stars, ocean shimmer, and fog."
    if name == "PauseMenu.gd":
        return "Pause menu shell, resume/quit wiring, legacy/hidden Quartermaster tab state, debug panel toggles, and temporary Event Test Button checkboxes."
    if name == "BallAudioSystem.gd":
        return "Pooled event-driven ball-to-ball collision audio with random hit selection, pitch variation, intensity scaling, and cooldown filtering."
    if name == "MainMenu.tscn":
        return "Layered title-screen scene with background art, animated overlay passes, foreground art, fog, and menu UI."
    if lowered.endswith(".tscn"):
        return "Godot scene file used for authored node layout and scene wiring."
    if lowered.endswith(".md"):
        return "Project documentation or checkpoint notes."
    return "Scanned project file; classification is best-effort."


def get_recently_changed_paths() -> list[str]:
    try:
        result = subprocess.run(
            ["git", "status", "--short", "--untracked-files=all"],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return []

    changed: list[str] = []
    for line in result.stdout.splitlines():
        if len(line) < 4:
            continue
        path = line[3:].strip()
        if " -> " in path:
            path = path.split(" -> ", 1)[1].strip()
        path = path.replace("\\", "/")
        if path.startswith("project_brain/"):
            continue
        changed.append(path)
    return changed


def build_readme() -> str:
    return "\n".join(
        [
            "# Project Brain",
            "",
            "This folder is generated/reference-only.",
            "",
            "It exists to help future AI/Codex sessions understand Kraken An Eight Ball quickly without rereading the whole project from zero.",
            "",
            "Current snapshot:",
            "",
            "- Kraken An Eight Ball is a systemic arcade-chaos billiards prototype.",
            "- The current loop is better shots -> Doubloons and Kraken Requests -> Passage reduction -> Kraken Intervention / Quartermaster / Oath choices -> more balls/anomalies/chaos -> successful Passage and Kraken Favor.",
            "- Passage is the current run objective; Kraken Intervention is the active chosen-chaos economy; automatic score-triggered BallDrop rewards are retired/gated.",
            "- BallDropSystem is mostly penalty handling, legacy support, and debug plumbing.",
            "- Passage, Oaths, Run Stats/History, Kraken Favor, Cue Locker/modifiers, Options, Back Room Deals, table debris, Main Menu, pooled collision audio, gameplay music, live Quartermaster HUD, Reserve slots/deployment, HudFeed, modular debug panels, evolving score stacks, Pocket Streaks, Anchor curse seeds, Treasure payout/discovery, Embezzler, Broadside Attack, Wayfinder Current, and expanded shot-event tiers are active modern systems.",
            "- Early cue reclaim, cue-drag hover suppression, fake-3D presentation, Cannon heat/impact presence, Treasure perception grace/hiding, Embezzler hide-or-run pressure, Pocket Streak whirlpools, authored debris collision, and Wayfinder Current readability pulses remain important active systems.",
            "- Generated reports are a project map only; `AGENTS.md` and the real scripts/scenes remain authoritative.",
            "",
            "Important rules:",
            "",
            "- Gameplay source of truth remains the real scripts, scenes, and `AGENTS.md`.",
            "- Generated reports may be imperfect and should not override code review.",
            "- `project_brain/debug_media/` is reference-only visual evidence, not gameplay/source code.",
            "- The scanner is local-only and should only generate/update files inside `project_brain/`.",
            "- No autonomous agents live here. These are role maps and reports only.",
            "",
            "## Do Not Misuse",
            "",
            "- `project_brain/` is not source of truth.",
            "- Do not make gameplay changes based only on generated reports.",
            "- Always check real source files and `AGENTS.md` before editing behavior.",
            "",
            "## Debug Media",
            "",
            "`project_brain/debug_media/` is for visual debugging references, performance captures, feel/polish references, reproduction clips, and comparison screenshots/videos.",
            "",
            "- Check relevant debug media when investigating feel, prediction, anomaly, UI, or performance issues.",
            "- Treat debug media as reference material only; never as gameplay/source code or authoritative behavior.",
            "",
            "Regenerate with:",
            "",
            "```powershell",
            "python tools/build_project_brain.py",
            "```",
            "",
        ]
    )


def build_project_index(files: list[FileInfo], changed_paths: list[str]) -> str:
    section_map: dict[str, list[FileInfo]] = {section: [] for section in INDEX_SECTIONS}
    for info in files:
        for category in info.categories:
            if category in section_map and category != "Recently Changed":
                section_map[category].append(info)

    changed_lookup = set(changed_paths)
    section_map["Recently Changed"] = [info for info in files if info.path in changed_lookup]

    lines = [
        "# Project Index",
        "",
        "Generated by `tools/build_project_brain.py`.",
        "",
        "This is a fast project map, not a substitute for reading source files and `AGENTS.md`.",
        "",
        "## Do Not Misuse",
        "",
        "- `project_brain/` is not source of truth.",
        "- Do not make gameplay changes based only on generated reports.",
        "- Always check real source files and `AGENTS.md` before editing behavior.",
        "",
        "## Debug Media References",
        "",
        "- `project_brain/debug_media/` stores visual debugging references, performance captures, feel/polish references, reproduction clips, and comparison screenshots/videos.",
        "- Future sessions should check relevant clips/screenshots when investigating feel, prediction, anomaly, UI, or performance issues.",
        "- Debug media is reference material only and should never be treated as gameplay/source code.",
        "",
        "## Current Game State",
        "",
        "- Kraken An Eight Ball is a systemic arcade-chaos billiards prototype with multiple active escalation systems.",
        "- Core loop: better shots -> Doubloons and Kraken Requests -> Passage reduction -> Kraken Intervention / Quartermaster / Oath choices -> more balls/anomalies/chaos -> stronger scoring opportunities -> successful Passage and Kraken Favor.",
        "- `MainMenu.tscn` / `MainMenu.gd` now provide an atmospheric layered title screen with lightweight animated overlays.",
        "- `PassageSystem.gd` owns the current-run Passage objective and active Kraken Requests.",
        "- `OathSystem.gd` owns data-driven Oaths, active timers, penalties/restrictions, Quartermaster lock state, and cue modifier suppression.",
        "- `TableEventSystem.gd` owns the active Kraken Intervention economy: shot-earned threshold, pending readiness after cue control, weighted offers, Oath-backed single-slot replacement, purchases, cargo discovery, and event routing.",
        "- Kraken Intervention replaces invisible automatic reward spawning with economic agency, intentional chaos, and tactical risk/reward decisions.",
        "- `TableEventMeter.gd` and `TableEventMenu.gd` present the horizontal KRAKEN INTERVENTION meter and compact Request Kraken Intervention choice menu.",
        "- Automatic score-triggered BallDrop rewards are retired/gated. `BallDropSystem.gd` is mostly penalty handling, legacy support, and debug plumbing.",
        "- Current Table Events include Cheap Cargo, Loose Cargo, Powder Cache, Wayfinder's Favor, Cannon Warning, Broadside Attack, and Wayfinder Current.",
        "- Loose Cargo Contraband uses one event-level roll and a weighted table; Lucky Chalk can raise the chance through cue modifiers.",
        "- Broadside Attack is the first authored staged intervention milestone: warning beat, Powder Keg lanes, then delayed Cannon Balls from a cursed gun deck.",
        "- Wayfinder Current is the cursed-tide intervention: temporary possession with transferable guided momentum and current-caused scoring support.",
        "- `QuartermasterSystem.gd` owns three rotating tactical offers and paid stock refresh; `QuartermasterHUD.gd` presents them as a live side-rail shop; successful buys spend Doubloons and fill `ReserveSystem.gd` slots.",
        "- `BackRoomDealSystem.gd` owns expensive specific-item procurement into Reserve after refresh pressure climbs high enough.",
        "- Reserve deployment uses `BallPlacementSystem.gd`, with `ReserveSlotsUI.gd` and `ReserveDeploymentPresenter.gd` handling icon-only slots and tethered presentation.",
        "- `RunStatsSystem.gd` owns current-run stats; `RunHistorySystem.gd` persists finalized records; `ProgressionSystem.gd` persists Kraken Favor and cue progression data.",
        "- `CueProgressionSystem.gd` owns cue definitions, unlock/equip state, effect definitions, and generic active modifier snapshots.",
        "- `BallAudioSystem.gd` owns pooled event-driven ball-to-ball collision sounds with spam filtering.",
        "- `GameplayMusicSystem.gd` owns low-volume looping gameplay music, separate from SFX and quieter than collision/event readability.",
        "- `PocketStreakSystem.gd` and `PocketStreakPresenter.gd` own same-pocket streak scoring, queued X2/X3/X4+ presentation, audio, whirlpool visuals, and psychological threat tells with deliberately no gameplay suction.",
        "- `HudFeed.gd` owns the rolling bottom-left captain's-log feed with fading, hover review, and multiline wrapping.",
        "- `DebugOverlay.gd` supports modular draggable panels, pause-safe interaction, scrollable Dev Options, and requested-section hidden-work gating.",
        "- `ShotEventSystem.gd` tracks foundational, skilled, heroic, legendary, and sink-moment scoring-event tiers for `ScoreSystem.gd` rewards.",
        "- `ScoreSystem.gd` routes implemented reward tiers and Treasure/Embezzler payouts into evolving pocket-side score stacks with count-up totals, tier colors/glows, lane management, and yield/fade behavior.",
        "- Early cue reclaim lets players regain control after the cue ball stops under safe motion conditions.",
        "- `TableImpactShakeSystem.gd` owns fake-3D presentation-only impact shake for Powder Keg and Cannon events.",
        "- `TableObstacleSystem.gd` owns debug-spawned wood debris and custom authored-polygon collision support.",
        "- Anchor's old continuous pull field is retired; current Anchor gameplay is state/event-driven curse seeds, chains, warning, spread, and collapse.",
        "- Cannon Ball is a debug/Event/Contraband heavy-iron anomaly with heat presence and heavy-impact behavior.",
        "- Treasure Ball is a rare discovery/perception grace/hiding experiment that reacts to being watched by the aim guide and awards a large payout when sunk.",
        "- Embezzler is a separate capped/debug-spawn greed anomaly that copies Doubloon value, hides or runs once per shot, tries to escape through a secret pocket, and pays out if caught.",
        "- Optimization philosophy: support chaos gracefully, coalesce repeated work, and degrade visuals before limiting gameplay.",
        "",
        "## Next Major Goal",
        "",
        "- Continue stabilizing the Passage-centered run loop: request clarity/rewards, Passage pacing, completion summaries, Kraken Favor cadence, and cue progression readability.",
        "- Continue tuning the supporting economy: Kraken Intervention threshold feel, event costs, offer weights, Quartermaster refresh pressure, Back Room timing, and Oath risk readability.",
        "- Tune new scoring-event thresholds only through focused passes; do not casually change score values during UI/docs/cleanup work.",
        "- Future Table Events can expand the intervention pool, but event execution should remain in focused owners rather than growing Table.gd.",
        "- Future Quartermaster and cue progression work can add more stock rules, rerolls, unlocks, or modifiers, but current data owners should stay small and data-driven.",
        "- Cue-ball and eight-ball sinks cost 25 Doubloons; cue-ball sinks remove one eligible object ball, while eight-ball sinks try to transform one eligible object ball into an Anchor curse seed.",
        "- System boundary: `TableEventSystem.gd` decides intervention opportunities/purchases, then `SpawnSystem.gd` and anomaly systems perform consequences while `Table.gd` coordinates only.",
        "",
        "## Metadata Comments",
        "",
        "The scanner understands optional comments in source files:",
        "",
        "```gdscript",
        "# index:title Anchor Ball",
        "# index:category Mechanics / Anomaly Balls",
        "# index:status In Progress",
        "# index:owner anomaly_ball_agent",
        "# index:notes Owns curse-seed chains, warning, spread, collapse, and debug state.",
        "```",
        "",
    ]

    for section in INDEX_SECTIONS:
        lines.append(f"## {section}")
        lines.append("")
        if section == "Recently Changed" and not changed_paths:
            lines.append("No current working tree changes detected outside `project_brain/`.")
        elif section == "Recently Changed":
            scanned_changed = sorted(section_map[section], key=lambda item: item.path)
            mapped_paths = {info.path for info in section_map[section]}
            outside_changed = [
                changed_path
                for changed_path in sorted(changed_paths)
                if changed_path not in mapped_paths and not changed_path.startswith("project_brain/")
            ]
            if scanned_changed:
                lines.append("Changed scanned files:")
                for info in scanned_changed:
                    lines.append(format_file_bullet(info))
            else:
                lines.append("No changed scanned files detected outside `project_brain/`.")
            if outside_changed:
                lines.append("")
                lines.append("Changed files outside scanner set:")
                for changed_path in outside_changed:
                    lines.append(f"- `{changed_path}` - Recently changed but outside the scanned file set.")
        elif not section_map[section]:
            lines.append("No files currently mapped here.")
        else:
            for info in sorted(section_map[section], key=lambda item: item.path):
                lines.append(format_file_bullet(info))
        lines.append("")

    lines.extend(
        [
            "## Notes",
            "",
            "- `Unclassified` means the scanner did not have enough metadata or naming confidence.",
            "- Add `# index:*` comments to important files if you want stronger classification.",
            "- Third-party addon internals are skipped to keep this map focused on project code.",
            "",
        ]
    )
    return "\n".join(lines)


def format_file_bullet(info: FileInfo) -> str:
    details = [info.summary]
    if info.status:
        details.append(f"status: {info.status}")
    if info.owner:
        details.append(f"owner: {info.owner}")
    notes = clean_metadata_notes(info.notes)
    if notes and notes.lower() not in info.summary.lower():
        details.append(f"notes: {notes}")
    return f"- `{info.path}` - {info.title}. {'; '.join(details)}"


def clean_metadata_notes(notes: str) -> str:
    """Keep generated docs current without editing source metadata comments."""
    cleaned = re.sub(r"^Stage\s+\d+\s+", "", notes, flags=re.IGNORECASE).strip()
    lowered = cleaned.lower()
    if "doubloon progress" in lowered and "special-ball sink penalties" in lowered:
        return "Legacy/gated automatic reward-drop progress remains retired; cue/eight-ball penalties remain active."
    if "vertical right-side meter" in lowered and "score progress" in lowered:
        return "Retired legacy BallDrop meter; current progression UI is the horizontal Kraken Intervention meter."
    return cleaned


def build_agent_report(files: list[FileInfo]) -> str:
    lines = [
        "# Agent Report",
        "",
        "Generated as a lightweight multi-role review. These are not autonomous agents; they are project lenses for future sessions.",
        "",
        "Do not misuse: this report is not source of truth. Check real source files and `AGENTS.md` before changing gameplay behavior.",
        "",
        "Reference media: check `project_brain/debug_media/` for relevant clips, captures, or comparison screenshots when investigating feel, prediction, anomaly, UI, or performance issues. Treat those files as evidence only, never as gameplay/source code.",
        "",
    ]
    for agent_id, definition in AGENT_DEFINITIONS.items():
        watched = files_for_agent(files, agent_id)
        lines.append(f"## {definition['display']}")
        lines.append("")
        lines.append("Relevant files:")
        lines.extend(format_path_list(watched[:12]))
        planned = planned_systems_for_agent(agent_id)
        if planned:
            lines.append("")
            lines.append("Planned systems:")
            lines.extend(format_planned_systems(planned, agent_id))
        lines.append("")
        lines.append("What it appears to do:")
        lines.append(f"- {definition['responsibility']}")
        for note in definition["notes"]:
            lines.append(f"- {note}")
        lines.append("")
        lines.append("Known risks or TODOs:")
        for risk in risks_for_agent(agent_id):
            lines.append(f"- {risk}")
        lines.append("")
        lines.append("Questions for the developer:")
        for question in definition["questions"]:
            lines.append(f"- {question}")
        lines.append("")
    return "\n".join(lines)


def build_agent_file(agent_id: str, definition: dict[str, object], files: list[FileInfo]) -> str:
    watched = files_for_agent(files, agent_id)
    lines = [
        f"# {definition['display']}",
        "",
        f"Responsibility: {definition['responsibility']}",
        "",
        "This file is generated/reference-only. It does not grant autonomous behavior and is not source of truth.",
        "",
        "Do not change gameplay based only on this report; check real source files and `AGENTS.md` first.",
        "",
        "When investigating feel, prediction, anomaly, UI, or performance issues, check relevant `project_brain/debug_media/` clips or screenshots. They are reference material only, not gameplay/source code.",
        "",
        "## Files Watched",
        "",
    ]
    lines.extend(format_path_list(watched))
    planned = planned_systems_for_agent(agent_id)
    if planned:
        lines.extend(
            [
                "",
                "## Planned Watches",
                "",
            ]
        )
        lines.extend(format_planned_systems(planned, agent_id))
    lines.extend(
        [
            "",
            "## Current Notes",
            "",
        ]
    )
    for note in definition["notes"]:
        lines.append(f"- {note}")
    lines.extend(
        [
            "",
            "## Risks Or TODOs",
            "",
        ]
    )
    for risk in risks_for_agent(agent_id):
        lines.append(f"- {risk}")
    lines.extend(
        [
            "",
            "## Questions",
            "",
        ]
    )
    for question in definition["questions"]:
        lines.append(f"- {question}")
    lines.append("")
    return "\n".join(lines)


def files_for_agent(files: list[FileInfo], agent_id: str) -> list[FileInfo]:
    definition = AGENT_DEFINITIONS[agent_id]
    watched: list[FileInfo] = []
    for info in files:
        lowered = info.path.lower()
        if info.owner == agent_id:
            watched.append(info)
            continue
        if any(keyword in lowered for keyword in definition["watch_keywords"]):
            watched.append(info)
    return sorted(dedupe_files(watched), key=lambda item: item.path)


def planned_systems_for_agent(agent_id: str) -> list[tuple[str, dict[str, object]]]:
    planned: list[tuple[str, dict[str, object]]] = []
    for name, definition in PLANNED_SYSTEMS.items():
        if (ROOT / "scripts" / name).exists():
            continue
        agents = definition.get("agents", {})
        if isinstance(agents, dict) and agent_id in agents:
            planned.append((name, definition))
    return planned


def format_planned_systems(planned: Iterable[tuple[str, dict[str, object]]], agent_id: str) -> list[str]:
    lines: list[str] = []
    for name, definition in planned:
        status = definition.get("status", "Planned")
        summary = definition.get("summary", "")
        agents = definition.get("agents", {})
        note = ""
        if isinstance(agents, dict):
            note = str(agents.get(agent_id, ""))
        if note:
            lines.append(f"- `{name}` ({status}) - {summary} {note}")
        else:
            lines.append(f"- `{name}` ({status}) - {summary}")
    return lines


def risks_for_agent(agent_id: str) -> list[str]:
    risks = {
        "mechanics_agent": [
            "Kraken Intervention threshold/cost/weight tuning is first-pass and needs longer playtesting.",
            "Cue/eight-ball sink penalties should not accidentally feed Kraken Intervention or revive legacy BallDrop progress.",
            "Early cue reclaim must stay safe: cue-ball motion or reset/drop states should still block release.",
            "Expanded shot-event thresholds may need conservative tuning after longer chaos-table sessions.",
            "Pocket Streak bonuses should remain double-award safe when multiple same-pocket sinks resolve rapidly.",
        ],
        "systems_agent": [
            "Table.gd still owns BallPhysics; do not extract casually.",
            "Future Table Event logic could still bloat ScoreSystem or Table.gd if TableEventSystem ownership is not respected.",
            "Quartermaster, Reserve, and BallPlacement boundaries should stay separate as more purchasable/deployable effects are added.",
            "BallAudioSystem should stay event-driven and not become a physics-side concern.",
            "Broadside and Wayfinder Current should keep sequencing/routing in focused owners rather than duplicating logic in debug buttons.",
        ],
        "anomaly_ball_agent": [
            "Anchor curse-seed behavior is tuned by feel and should be adjusted incrementally without restoring continuous field pull.",
            "Future anomalies should avoid hidden coupling through Table.gd.",
            "Treasure payout and cargo/contraband discovery are implemented; keep Treasure distinct from Embezzler cashout/escape behavior.",
            "Embezzler is capped and can appear through debug/contraband paths; broader spawn odds and special interactions are still future work.",
            "Wayfinder Current affected-ball count is intentionally uncapped for now; tune radius/readability before adding hard caps.",
        ],
        "ui_agent": [
            "Score stack lane/readability can regress when many high-tier events happen near the same pocket.",
            "Pocket Streak whirlpool/threat tells should remain readable without implying real suction until a gameplay pass adds it explicitly.",
            "Kraken Intervention menu and meter should stay cue-input safe and centered as UI art evolves.",
            "Modular debug panels can become noisy as more sections are added; keep hidden-panel gating intact.",
            "Main menu atmosphere should remain lightweight and layered correctly behind foreground silhouettes.",
            "Quartermaster and Reserve UI should not steal active cue drag/release input.",
        ],
        "performance_agent": [
            "Visual effects should degrade before gameplay chaos is limited.",
            "Pooling/reuse is not broadly implemented for temporary visuals yet.",
            "AimPreview rebuild coalescing should preserve reliable graze behavior and avoid tolerance-based lies.",
            "Hidden debug UI should remain logically cheap, not merely invisible.",
            "Collision audio cooldowns should prevent spam without making meaningful impacts feel late.",
            "Anchor should stay event/state-driven; avoid reintroducing continuous force scans.",
            "Embezzler should stay capped and avoid same-shot escape-roll spam.",
            "Score stacks should coalesce celebration before any visual suppression is considered.",
            "Kraken Intervention and HudFeed should remain event/message-driven rather than becoming per-frame scanners.",
        ],
        "lore_agent": [
            "Kraken Intervention language should feel like bargaining with the table, not a generic upgrade menu.",
            "Pocket Streak HudFeed lines should stay compact while preserving kraken/pocket-hunger flavor.",
            "Quartermaster wording should stay pirate-tactical and not feel like a debug catalog.",
            "Keep Doubloons language here; do not import Insight terminology from future Cuethulhu work.",
        ],
        "cleanup_agent": [
            "Generated reports can drift if not regenerated after major changes.",
            "Scanner classifications are heuristic until files add `# index:*` metadata.",
        ],
    }
    return risks[agent_id]


def format_path_list(files: Iterable[FileInfo]) -> list[str]:
    file_list = list(files)
    if not file_list:
        return ["- No matching files found yet."]
    return [f"- `{info.path}` - {info.summary}" for info in file_list]


def write_output(relative_path: str, text: str) -> None:
    target = (OUTPUT_DIR / relative_path).resolve()
    output_root = OUTPUT_DIR.resolve()
    try:
        target.relative_to(output_root)
    except ValueError as exc:
        raise RuntimeError(f"Refusing to write outside project_brain: {target}") from exc

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8", newline="\n")


def dedupe(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        if not value or value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


def dedupe_files(files: Iterable[FileInfo]) -> list[FileInfo]:
    seen: set[str] = set()
    result: list[FileInfo] = []
    for info in files:
        if info.path in seen:
            continue
        seen.add(info.path)
        result.append(info)
    return result


def to_posix(path: Path) -> str:
    return path.as_posix()


if __name__ == "__main__":
    main()
