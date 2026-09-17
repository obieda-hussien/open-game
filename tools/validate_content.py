#!/usr/bin/env python3
"""Fast, dependency-free validation for Last Shift data and repository structure."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []


def fail(message: str) -> None:
    ERRORS.append(message)


def load_json(relative: str) -> dict:
    path = ROOT / relative
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"Missing {relative}")
    except json.JSONDecodeError as exc:
        fail(f"{relative}: invalid JSON: {exc}")
    return {}


def validate_missions() -> None:
    data = load_json("data/missions/prologue.json")
    missions = data.get("missions")
    if not isinstance(missions, list) or not missions:
        fail("Mission file must contain a non-empty 'missions' list.")
        return

    seen_ids: set[str] = set()
    for mission in missions:
        if not isinstance(mission, dict):
            fail("Every mission must be an object.")
            continue
        mission_id = mission.get("id")
        if not isinstance(mission_id, str) or not mission_id:
            fail("Mission missing id.")
            continue
        if mission_id in seen_ids:
            fail(f"Duplicate mission id: {mission_id}")
        seen_ids.add(mission_id)

        stages = mission.get("stages")
        if not isinstance(stages, dict) or not stages:
            fail(f"{mission_id}: missing stages.")
            continue

        start = mission.get("start_stage")
        if start not in stages:
            fail(f"{mission_id}: start_stage '{start}' does not exist.")

        for stage_id, stage in stages.items():
            if not isinstance(stage, dict):
                fail(f"{mission_id}/{stage_id}: stage must be an object.")
                continue
            if not stage.get("objective"):
                fail(f"{mission_id}/{stage_id}: objective is required.")

            next_stage = stage.get("next")
            if next_stage and next_stage != "__complete" and next_stage not in stages:
                fail(f"{mission_id}/{stage_id}: next stage '{next_stage}' does not exist.")

            choices = stage.get("choices", [])
            if choices and not isinstance(choices, list):
                fail(f"{mission_id}/{stage_id}: choices must be a list.")
                continue
            choice_ids: set[str] = set()
            for choice in choices:
                if not isinstance(choice, dict):
                    fail(f"{mission_id}/{stage_id}: choice must be an object.")
                    continue
                choice_id = choice.get("id")
                if not choice_id:
                    fail(f"{mission_id}/{stage_id}: choice missing id.")
                elif choice_id in choice_ids:
                    fail(f"{mission_id}/{stage_id}: duplicate choice id '{choice_id}'.")
                choice_ids.add(str(choice_id))
                target = choice.get("next")
                if target and target != "__complete" and target not in stages:
                    fail(f"{mission_id}/{stage_id}: choice target '{target}' does not exist.")


def validate_events() -> None:
    data = load_json("data/events/world_events.json")
    events = data.get("events")
    if not isinstance(events, list):
        fail("Event file must contain an 'events' list.")
        return

    seen_ids: set[str] = set()
    for event in events:
        if not isinstance(event, dict):
            fail("Every event must be an object.")
            continue
        event_id = event.get("id")
        if not isinstance(event_id, str) or not event_id:
            fail("Dynamic event missing id.")
            continue
        if event_id in seen_ids:
            fail(f"Duplicate dynamic event id: {event_id}")
        seen_ids.add(event_id)

        chance = event.get("chance_per_minute", 0)
        if not isinstance(chance, (int, float)) or chance < 0 or chance > 1:
            fail(f"{event_id}: chance_per_minute must be in [0, 1].")
        for key in ("start_hour", "end_hour"):
            value = event.get(key, 0)
            if not isinstance(value, (int, float)) or not 0 <= value <= 24:
                fail(f"{event_id}: {key} must be in [0, 24].")


def validate_required_files() -> None:
    required = [
        "project.godot",
        "export_presets.cfg",
        "scenes/main.tscn",
        "scenes/player/player.tscn",
        "src/autoload/game_settings.gd",
        "src/world/open_world_streamer.gd",
        ".github/workflows/android-ci.yml",
        ".circleci/config.yml",
    ]
    for relative in required:
        if not (ROOT / relative).is_file():
            fail(f"Missing required file: {relative}")


def main() -> int:
    validate_required_files()
    validate_missions()
    validate_events()

    if ERRORS:
        print("Content validation FAILED:")
        for error in ERRORS:
            print(f"  - {error}")
        return 1

    print("Content validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
