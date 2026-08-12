#!/usr/bin/env python3
"""Validate TTop Desk's supported widget-local translation catalog."""

from __future__ import annotations

import ast
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATTERN = re.compile(r"\bttopTr\(\s*\"((?:[^\"\\]|\\.)*)\"")


def po_messages(path: Path) -> dict[str, str]:
    messages: dict[str, str] = {}
    current_field: str | None = None
    current_id = ""
    current_value = ""

    def finish() -> None:
        nonlocal current_id, current_value
        if current_id:
            messages[current_id] = current_value
        current_id = ""
        current_value = ""

    for raw_line in path.read_text(encoding="utf-8").splitlines() + [""]:
        line = raw_line.strip()
        if line.startswith("msgid "):
            finish()
            current_field = "id"
            current_id = ast.literal_eval(line[6:])
        elif line.startswith("msgstr "):
            current_field = "value"
            current_value = ast.literal_eval(line[7:])
        elif line.startswith('"'):
            part = ast.literal_eval(line)
            if current_field == "id":
                current_id += part
            elif current_field == "value":
                current_value += part
        elif not line:
            finish()
            current_field = None
    return messages


def main() -> None:
    sources: set[str] = set()
    for path in sorted((ROOT / "package/contents").rglob("*.qml")):
        text = path.read_text(encoding="utf-8")
        for match in SOURCE_PATTERN.finditer(text):
            sources.add(ast.literal_eval('"' + match.group(1) + '"'))

    catalog = po_messages(
        ROOT / "po/de/plasma_applet_io.github.s3cb34r.ttopdesk.po"
    )
    missing = sorted(sources - catalog.keys())
    untranslated = sorted(source for source in sources if not catalog.get(source))
    extra = sorted(catalog.keys() - sources)
    if missing or untranslated or extra:
        details = []
        if missing:
            details.append("missing: " + ", ".join(missing))
        if untranslated:
            details.append("untranslated: " + ", ".join(untranslated))
        if extra:
            details.append("obsolete/unused: " + ", ".join(extra))
        raise SystemExit("; ".join(details))

    required = {
        "TEMPERATURE": "TEMPERATUR",
        "NETWORK": "NETZWERK",
        "DISK I/O": "DATENTRÄGER-I/O",
        "FILESYSTEMS": "DATEISYSTEME",
        "TOP PROCESSES": "TOP-PROZESSE",
        "Backend unavailable": "Backend nicht verfügbar",
        "No process data": "Keine Prozessdaten",
    }
    for source, expected in required.items():
        if catalog.get(source) != expected:
            raise SystemExit(
                f"German lookup mismatch for {source!r}: {catalog.get(source)!r}"
            )

    print(f"German catalog covers all {len(sources)} widget-local source strings.")


if __name__ == "__main__":
    main()
