"""Static checks for the WP-02 contract and database-boundary baseline."""

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def fail(message: str) -> int:
    print(f"ERROR: {message}")
    return 1


def main() -> int:
    contract = ROOT / "contracts" / "platform-integration.openapi.yaml"
    opc = ROOT / "infra" / "postgres" / "opc_core" / "001_init.sql"
    canvas = ROOT / "infra" / "postgres" / "super_canvas" / "001_init.sql"
    for path in (contract, opc, canvas):
        if not path.exists() or path.stat().st_size == 0:
            return fail(f"missing contract artifact: {path}")

    contract_text = contract.read_text(encoding="utf-8")
    for required in ("/internal/v1/sso/exchange:", "/internal/v1/models/catalog:", "/internal/v1/quotes:", "/internal/v1/reservations:", "/internal/v1/model-proxy/invoke:", "/internal/v1/settlements:", "Idempotency-Key", "price_version"):
        if required not in contract_text:
            return fail(f"contract missing {required}")

    opc_text = opc.read_text(encoding="utf-8")
    canvas_text = canvas.read_text(encoding="utf-8")
    if "wallet" in canvas_text.lower() or "ledger" in canvas_text.lower():
        return fail("super_canvas schema must not define wallet or ledger tables")
    if "REFERENCES platform_user_refs" not in canvas_text:
        return fail("super_canvas must constrain user references locally")
    if "CREATE TABLE IF NOT EXISTS business_events" not in opc_text:
        return fail("opc_core must define business event intake")
    if re.search(r"REFERENCES\s+(new_api|opc_core|super_canvas)\.", opc_text + canvas_text, re.IGNORECASE):
        return fail("database migrations must not contain cross-database foreign keys")

    print("WP-02 contract and database boundary checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
