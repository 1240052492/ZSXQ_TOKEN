"""Validate the machine-readable license review status.

Pending is intentionally a failing gate. A production release cannot claim
license approval until a reviewer records a decision and evidence.
"""

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
REVIEW = ROOT / "docs" / "compliance" / "license-review.md"


def main() -> None:
    if not REVIEW.exists():
        print("ERROR: missing docs/compliance/license-review.md")
        return 1
    text = REVIEW.read_text(encoding="utf-8")
    for field in ("status", "reviewer", "reviewed_at", "decision"):
        if not re.search(rf"^{field}:\s*.*$", text, re.MULTILINE):
            print(f"ERROR: missing license review field: {field}")
            return 1
    if "AGPL-3.0" not in text or "LocalMiniDrama" not in text:
        print("ERROR: license review must cover AGPL-3.0 and LocalMiniDrama")
        return 1
    status = re.search(r"^status:\s*(\S+)", text, re.MULTILINE).group(1).lower()
    decision = re.search(r"^decision:\s*(\S+)", text, re.MULTILINE).group(1).lower()
    if status != "approved" or decision not in {"approved", "pass"}:
        print("License review is pending; production release remains blocked.")
        return 1
    print("License review approved; retain legal evidence in the PR.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
