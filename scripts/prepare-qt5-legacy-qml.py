#!/usr/bin/env python3
"""Prepare the shared CueFlow QML for Qt 5.15's versioned import syntax.

Qt 6 permits versionless imports. Qt 5.15 requires explicit import versions,
so the Android 6 build gets a generated copy while the primary Qt 6 source stays
versionless. The generated file is ignored by Git and recreated by CI.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
source = root / "qml" / "Main.qml"
target = root / "android-legacy" / "generated" / "Main.qml"

# Match the module versions provided by Qt 5.15.2, not Qt 6's module numbering.
versions = {
    "QtQuick": "2.15",
    "QtQuick.Controls": "2.15",
    "QtQuick.Controls.Material": "2.15",
    "QtQuick.Layouts": "1.15",
    "QtQuick.Window": "2.15",
}

text = source.read_text(encoding="utf-8")
lines = text.splitlines()
found = {uri: 0 for uri in versions}
out = []
for line in lines:
    match = re.fullmatch(r"(\s*import\s+)([A-Za-z0-9_.]+)(\s*)", line)
    if match and match.group(2) in versions:
        uri = match.group(2)
        found[uri] += 1
        out.append(f"{match.group(1)}{uri} {versions[uri]}{match.group(3)}")
    else:
        # Fail closed if a versionless QtQuick import is added later without
        # an explicit compatibility decision for the Qt 5.15 build.
        if re.fullmatch(r"\s*import\s+Qt(?:Quick|Qml)(?:\.[A-Za-z0-9_.]+)?\s*", line):
            if not re.fullmatch(r"\s*import\s+Qt(?:Quick|Qml)(?:\.[A-Za-z0-9_.]+)?\s+[0-9]+\.[0-9]+(?:\s+as\s+\w+)?\s*", line):
                raise SystemExit(f"Unhandled versionless Qt import in {source}: {line.strip()}")
        out.append(line)

missing = [uri for uri, count in found.items() if count != 1]
if missing:
    raise SystemExit("Expected each known import exactly once; missing/duplicate: " + ", ".join(missing))

generated = "\n".join(out) + "\n"
for uri in versions:
    expected = f"import {uri} {versions[uri]}"
    if generated.count(expected) != 1:
        raise SystemExit(f"Generated QML is missing expected import: {expected}")

target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(generated, encoding="utf-8")
print(f"Generated Qt 5.15-compatible QML: {target.relative_to(root)}")
print("Imports:")
for line in generated.splitlines():
    if line.startswith("import "):
        print("  " + line)
