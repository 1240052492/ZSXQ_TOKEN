"""Validate the machine-readable acceptance matrix for pull-request gating."""

import json
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
MATRIX = ROOT / "docs" / "acceptance" / "matrix.json"
REQUIRED_IDS = {f"M{i:02d}" for i in range(1, 21)} | {f"E2E-{i:02d}" for i in range(1, 6)}
REQUIRED_REQUIREMENTS = {str(i) for i in range(1, 17)}
ALLOWED_STATUS = {"planned", "in_progress", "passed", "blocked"}
ALLOWED_PRIORITY = {"P0", "P1", "P2"}


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    sys.exit(1)


def main() -> None:
    if not MATRIX.exists():
        fail(f"missing {MATRIX}")
    try:
        data = json.loads(MATRIX.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"invalid JSON: {exc}")

    items = data.get("items")
    if not isinstance(items, list):
        fail("items must be a list")

    seen = set()
    for item in items:
        if not isinstance(item, dict):
            fail("each item must be an object")
        item_id = item.get("id")
        if not item_id or item_id in seen:
            fail(f"missing or duplicate id: {item_id!r}")
        seen.add(item_id)
        for field in ("module", "goal", "acceptance", "evidence", "blocker", "owner"):
            if not item.get(field):
                fail(f"{item_id}: missing {field}")
        if item.get("status") not in ALLOWED_STATUS:
            fail(f"{item_id}: invalid status")
        if item.get("priority") not in ALLOWED_PRIORITY:
            fail(f"{item_id}: invalid priority")
        if item.get("status") == "passed":
            if not item.get("verified_by") or not item.get("verified_at"):
                fail(f"{item_id}: passed requires verified_by and verified_at")
            if not item.get("evidence_links"):
                fail(f"{item_id}: passed requires evidence_links")

    missing = REQUIRED_IDS - seen
    if missing:
        fail(f"missing required acceptance ids: {sorted(missing)}")
    trace = data.get("requirement_trace")
    if not isinstance(trace, dict):
        fail("requirement_trace must be an object")
    missing_requirements = REQUIRED_REQUIREMENTS - set(trace)
    if missing_requirements:
        fail(f"missing original requirements: {sorted(missing_requirements)}")

    critical_unpassed = [
        item["id"] for item in items
        if item["priority"] in {"P0", "P1"} and item["status"] != "passed"
    ]
    if critical_unpassed and data.get("gate_mode") == "production":
        fail(f"production gate has unpassed P0/P1 items: {critical_unpassed}")

    print(f"Acceptance matrix valid: {len(items)} items; gate_mode={data.get('gate_mode')}")


if __name__ == "__main__":
    main()
