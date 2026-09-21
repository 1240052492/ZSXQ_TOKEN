"""Guard the repository against an unrecorded license/compliance state."""

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
REVIEW = ROOT / "docs" / "compliance" / "license-review.md"


def main() -> None:
    text = REVIEW.read_text(encoding="utf-8") if REVIEW.exists() else ""
    required = ["AGPL-3.0", "LocalMiniDrama", "状态：", "结论："]
    missing = [value for value in required if value not in text]
    if missing:
        print(f"ERROR: license review missing: {missing}")
        sys.exit(1)
    if re.search(r"结论：\s*(通过|approved|pass)\s*$", text, re.IGNORECASE | re.MULTILINE):
        print("License review recorded as approved; retain legal evidence in the PR.")
    else:
        print("License review is pending; production release remains blocked.")


if __name__ == "__main__":
    main()
