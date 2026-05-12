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
    "scenes/Table.tscn": ["Physics", "Systems"],
    "scripts/AimPreview.gd": ["Physics", "Performance Concerns"],
    "scripts/AnchorBallSystem.gd": ["Anomaly Balls", "Systems", "Performance Concerns", "In Progress"],
    "scripts/BallDropMeter.gd": ["UI", "Systems", "In Progress"],
    "scripts/BallDropSystem.gd": ["Mechanics", "Systems", "UI", "Performance Concerns", "In Progress"],
    "scripts/Ball.gd": ["Mechanics", "Physics", "Performance Concerns"],
    "scripts/BoundarySystem.gd": ["Physics", "Systems", "Performance Concerns"],
    "scripts/CannonBallSystem.gd": ["Anomaly Balls", "Systems", "Performance Concerns", "In Progress"],
    "scripts/CueController.gd": ["Mechanics", "UI"],
    "scripts/DebugOverlay.gd": ["UI", "Debug Tools"],
    "scripts/Main.gd": ["Systems", "UI"],
    "scripts/PocketSystem.gd": ["Physics", "Systems", "Performance Concerns"],
    "scripts/PowderKegSystem.gd": ["Anomaly Balls", "Systems", "Performance Concerns"],
    "scripts/ScoreSystem.gd": ["Mechanics", "Systems", "UI", "In Progress"],
    "scripts/ShotEventSystem.gd": ["Mechanics", "Systems"],
    "scripts/SpawnSystem.gd": ["Mechanics", "Systems", "In Progress"],
    "scripts/Table.gd": ["Mechanics", "Physics", "Systems", "Performance Concerns"],
    "scripts/WayfinderSystem.gd": ["Anomaly Balls", "Systems"],
}

PLANNED_SYSTEMS = {
    "BallDropSystem.gd": {
        "status": "Planned",
        "summary": "Next major system for score-tied ball drops, drop rewards, rotating drop messages, and sink-penalty removal flow.",
        "agents": {
            "mechanics_agent": "Watches the score-to-more-balls escalation loop and cue/eight-ball sink consequences.",
            "systems_agent": "Should sit between ShotEventSystem/ScoreSystem and SpawnSystem so Table.gd stays a coordinator.",
            "ui_agent": "Watches rotating drop messages and reversed drop animation used as placeholder removal feedback.",
            "performance_agent": "Watches high-ball-count escalation, popup pressure, particle/trail load, and graceful visual degradation.",
        },
    },
}

AGENT_DEFINITIONS = {
    "mechanics_agent": {
        "display": "Mechanics Agent",
        "responsibility": "Tracks core play loops, shot lifecycle, scoring hooks, ball identity, and moment-to-moment billiards feel.",
        "watch_keywords": ["table", "ball", "cue", "shot", "score", "spawn", "event"],
        "notes": [
            "Preserve cue feel, shot feel, pocket feel, and scoring values during cleanup.",
            "Score-tied ball drops and cue/eight-ball sink penalties now flow through BallDropSystem.gd boundaries.",
        ],
        "questions": [
            "How many extra balls should different score-event tiers award?",
            "When should a crowded table stop escalating and start resolving?",
        ],
    },
    "systems_agent": {
        "display": "Systems Agent",
        "responsibility": "Tracks module boundaries, ownership rules, scene wiring, and coordinator responsibilities.",
        "watch_keywords": ["system", "table", "spawn", "pocket", "boundary", "main", "agent"],
        "notes": [
            "Table.gd should coordinate systems without absorbing new feature logic.",
            "Scene-authored geometry remains the source of truth.",
        ],
        "questions": [
            "What reward decisions should BallDropSystem.gd own before tuning starts?",
            "Which debug surfaces should graduate into permanent quality settings?",
        ],
    },
    "anomaly_ball_agent": {
        "display": "Anomaly Ball Agent",
        "responsibility": "Tracks Wayfinder, Powder Keg, Anchor Ball, Cannon Ball, and future anomaly behavior boundaries.",
        "watch_keywords": ["wayfinder", "powder", "anchor", "cannon", "anomaly", "ball"],
        "notes": [
            "Wayfinder, Powder Keg, and Anchor are active anomaly systems; Cannon Ball has first-pass heavy collision and Powder Keg launch behavior.",
            "Anchor has independent priority spawn odds and object-ball-only pull.",
        ],
        "questions": [
            "Should future anomalies interact with Anchor fields, or stay independent?",
            "Should anomaly-touch scoring expand beyond current event rewards?",
        ],
    },
    "ui_agent": {
        "display": "UI Agent",
        "responsibility": "Tracks HUD, debug panels, score popups, callouts, cue presentation, and player-facing text.",
        "watch_keywords": ["debug", "score", "ui", "main", "cue", "popup", "label", "scene"],
        "notes": [
            "Score popups are pocket-side arcade celebrations, not generic UI spam.",
            "Debug labels should stay clearly marked and not leak temporary test wording into player-facing strings.",
            "BallDropSystem.gd owns rotating score-earned drop-message selection; SpawnSystem/Table carry those messages to callouts.",
        ],
        "questions": [
            "Should ball drop callouts get themed variants now that the BallDropSystem spine exists?",
            "Which popup effects should degrade first on low-end machines?",
        ],
    },
    "performance_agent": {
        "display": "Performance Agent",
        "responsibility": "Tracks visual cost, broad-phase health, trail redraws, particle load, and stress-test readiness.",
        "watch_keywords": ["performance", "debug", "trail", "particle", "anchor", "powder", "boundary", "pocket", "aim"],
        "notes": [
            "Do not solve chaos by preventing chaos; degrade visuals first.",
            "High ball counts and large earned chain reactions are intended.",
            "BallDropSystem.gd exists as the score-tied drop spine and should be watched for high-count visual scaling pressure.",
        ],
        "questions": [
            "What visual-quality tiers should exist for trails, particles, aura effects, and score labels?",
            "When should pooling replace ad hoc temporary visual nodes?",
        ],
    },
    "lore_agent": {
        "display": "Lore/Theme Agent",
        "responsibility": "Tracks pirate/kraken tone, anomaly fantasy, callout language, and presentation consistency.",
        "watch_keywords": ["agents", "notes", "stack", "score", "spawn", "main"],
        "notes": [
            "Tone is pirate arcade chaos with readable eldritch flair.",
            "Doubloons belong to this prototype; Insight is reserved for the larger future Cuethulhu direction.",
        ],
        "questions": [
            "How weird should ball drop callouts get as chaos escalates?",
            "Should each anomaly get a unique drop callout pool?",
        ],
    },
    "cleanup_agent": {
        "display": "Cleanup Agent",
        "responsibility": "Tracks stale comments, unclear names, ownership drift, temporary debug leftovers, and documentation freshness.",
        "watch_keywords": ["agent", "debug", "system", "table", "spawn", "score", "shot"],
        "notes": [
            "Cleanup should preserve gameplay behavior and avoid opportunistic physics retuning.",
            "AGENTS.md and project_brain should be refreshed after major playable milestones.",
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
    if any(token in lowered for token in ["wayfinder", "powder", "anchor", "anomaly"]):
        categories.extend(["Anomaly Balls", "Performance Concerns"])
    if "debug" in lowered:
        categories.extend(["UI", "Debug Tools"])
    if any(token in lowered for token in ["checkpoint", "notes", "stack"]):
        categories.append("Needs Review")

    return dedupe(categories) or ["Unclassified"]


def guess_owner(rel_path: str) -> str:
    name = Path(rel_path).name
    exact_owners = {
        "AnchorBallSystem.gd": "anomaly_ball_agent",
        "CannonBallSystem.gd": "anomaly_ball_agent",
        "PowderKegSystem.gd": "anomaly_ball_agent",
        "WayfinderSystem.gd": "anomaly_ball_agent",
        "Ball.gd": "mechanics_agent",
        "CueController.gd": "mechanics_agent",
        "ShotEventSystem.gd": "mechanics_agent",
        "Table.gd": "mechanics_agent",
        "AimPreview.gd": "performance_agent",
        "BoundarySystem.gd": "systems_agent",
        "PocketSystem.gd": "systems_agent",
        "SpawnSystem.gd": "systems_agent",
        "Main.gd": "systems_agent",
        "DebugOverlay.gd": "ui_agent",
        "BallDropMeter.gd": "ui_agent",
        "ScoreSystem.gd": "ui_agent",
        "BallDropSystem.gd": "systems_agent",
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
        return "High-level table coordinator and current home of authoritative arcade ball physics."
    if name == "Ball.gd":
        return "Individual ball state, visuals, friction helpers, trails, and anomaly identity flags."
    if name == "SpawnSystem.gd":
        return "Creates balls, queues reward drops, performs safe spawn searches, and owns current anomaly spawn odds."
    if name == "BallDropSystem.gd":
        return "Tracks Doubloon progress toward score-tied reward drops and cue/eight-ball sink penalties."
    if name == "BallDropMeter.gd":
        return "Vertical right-side HUD meter for progress toward the next score-earned ball drop."
    if name == "ScoreSystem.gd":
        return "Converts shot-event history into Doubloons and pocket-side score popup presentation."
    if name == "ShotEventSystem.gd":
        return "Tracks causal per-shot scoring events for sunk balls."
    if name == "WayfinderSystem.gd":
        return "Handles Wayfinder activation and temporary guided-ball redirects."
    if name == "PowderKegSystem.gd":
        return "Handles Powder Keg cue/Cannon-contact explosions, radial pushes, Cannon launches, and particle bursts."
    if name == "AnchorBallSystem.gd":
        return "Handles Anchor Ball cursed-tide pull, target rules, cooldowns, visuals, and debug counters."
    if name == "CannonBallSystem.gd":
        return "Stage 3 Cannon Ball anomaly shell for identity, visuals, heavy impulse modifiers, and Powder Keg launch tuning."
    if name == "DebugOverlay.gd":
        return "Formats debug menu, performance overlay, toggles, and physics debug text."
    if name == "AimPreview.gd":
        return "Draws aim preview and side-effect-free cue-ball prediction."
    if name == "BoundarySystem.gd":
        return "Loads authored rail/boundary geometry and shared boundary helpers."
    if name == "PocketSystem.gd":
        return "Loads authored pocket geometry and detects pocket captures."
    if name == "CueController.gd":
        return "Owns cue visuals, grab-zone hit testing, pullback, and strike presentation."
    if name == "Main.gd":
        return "Small app shell and top-level scene wiring."
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
            "Important rules:",
            "",
            "- Gameplay source of truth remains the real scripts, scenes, and `AGENTS.md`.",
            "- Generated reports may be imperfect and should not override code review.",
            "- The scanner is local-only and should only generate/update files inside `project_brain/`.",
            "- No autonomous agents live here. These are role maps and reports only.",
            "",
            "## Do Not Misuse",
            "",
            "- `project_brain/` is not source of truth.",
            "- Do not make gameplay changes based only on generated reports.",
            "- Always check real source files and `AGENTS.md` before editing behavior.",
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
        "## Next Major Goal",
        "",
        "- Continue stabilizing the score-tied ball drop loop: better play creates more score events/Doubloons, more balls, more interactions, and higher score before the table empties.",
        "- Score-earned drop messages rotate now; keep expanding/tuning the message pool as the loop gets juicier.",
        "- Cue-ball and eight-ball sinks cost 25 Doubloons and remove one eligible object ball.",
        "- Current penalty removal uses a simple scale/fade placeholder; a reversed ball-drop animation can replace it later.",
        "- System boundary: `BallDropSystem.gd` decides score-tied drop rewards, then `SpawnSystem.gd` performs drops while `Table.gd` coordinates only.",
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
        "# index:notes Applies table manipulation aura to nearby balls.",
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
    if info.notes:
        details.append(f"notes: {info.notes}")
    return f"- `{info.path}` - {info.title}. {'; '.join(details)}"


def build_agent_report(files: list[FileInfo]) -> str:
    lines = [
        "# Agent Report",
        "",
        "Generated as a lightweight multi-role review. These are not autonomous agents; they are project lenses for future sessions.",
        "",
        "Do not misuse: this report is not source of truth. Check real source files and `AGENTS.md` before changing gameplay behavior.",
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
            "BallDropSystem.gd is first-pass playable; drop tuning and penalty presentation still need playtesting.",
            "Cue/eight-ball sink penalties should not accidentally feed score-tied drop progress.",
        ],
        "systems_agent": [
            "Table.gd still owns BallPhysics; do not extract casually.",
            "Future reward logic could still bloat ScoreSystem or Table.gd if new BallDropSystem responsibilities are not respected.",
        ],
        "anomaly_ball_agent": [
            "Anchor behavior is tuned by feel and should be adjusted incrementally.",
            "Future anomalies should avoid hidden coupling through Table.gd.",
        ],
        "ui_agent": [
            "Score popup readability can regress when many events happen at once.",
            "Debug overlay can become noisy as more counters are added.",
        ],
        "performance_agent": [
            "Visual effects should degrade before gameplay chaos is limited.",
            "Pooling/reuse is not broadly implemented for temporary visuals yet.",
        ],
        "lore_agent": [
            "Score-earned drop callouts now rotate; future passes should tune message frequency and tone.",
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
