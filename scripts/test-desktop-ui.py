#!/usr/bin/env python3
"""Dependency-free structural regression checks for CueFlow's responsive QML UI."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "qml" / "Main.qml"
source = QML.read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"[desktop-ui-test] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def check(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


# This is a structural check, not a replacement for Qt's qmllint or a GUI run.
# It catches broken delimiters and common regressions in the desktop panel source.
stack: list[tuple[str, int]] = []
pairs = {")": "(", "]": "[", "}": "{"}
state = "code"
quote = ""
line = 1
i = 0
while i < len(source):
    char = source[i]
    following = source[i + 1] if i + 1 < len(source) else ""
    if char == "\n":
        line += 1
    if state == "line_comment":
        if char == "\n":
            state = "code"
        i += 1
        continue
    if state == "block_comment":
        if char == "*" and following == "/":
            state = "code"
            i += 2
            continue
        i += 1
        continue
    if state == "string":
        if char == "\\":
            i += 2
            continue
        if char == quote:
            state = "code"
        i += 1
        continue
    if char == "/" and following == "/":
        state = "line_comment"
        i += 2
        continue
    if char == "/" and following == "*":
        state = "block_comment"
        i += 2
        continue
    if char in ('"', "'"):
        state = "string"
        quote = char
        i += 1
        continue
    if char in "({[":
        stack.append((char, line))
    elif char in ")}]":
        if not stack or stack[-1][0] != pairs[char]:
            fail(f"unmatched {char!r} on line {line}")
        stack.pop()
    i += 1
check(not stack, f"unclosed delimiter(s): {stack[-5:]}")
check(state not in ("string", "block_comment"), f"unterminated {state}")

ids = re.findall(r"^\s*id:\s*([A-Za-z_]\w*)", source, re.MULTILINE)
duplicates = {name: count for name, count in Counter(ids).items() if count > 1}
check(not duplicates, f"duplicate QML ids: {duplicates}")

required = {
    "desktop two-column control deck": 'id: desktopDisplayControls',
    "playback section": 'text: "PLAYBACK"',
    "reading adjustments section": 'text: "READING ADJUSTMENTS"',
    "play/pause text label": 'text: session.playing ? "Pause" : "Play"',
    "reset text label": 'text: "Reset"',
    "remote action label": 'text: session.hosting ? "Remote enabled" : "Enable remote"',
    "text-size control": 'id: displayFontSizeDesktop',
    "text-width control": 'id: displayWidthDesktop',
    "desktop/mobile layout separation": 'visible: !window.desktopUi && !window.editingScript',
    "Android remains touch-sized": 'implicitHeight: window.desktopUi ? 34 : 46',
}
for description, marker in required.items():
    check(marker in source, f"missing {description} ({marker})")

check('columns: window.width >= 1020 ? 2 : 1' in source,
      "desktop controls no longer adapt between side-by-side and stacked layouts")
check('elide: Text.ElideNone' in source,
      "remote button label must not be deliberately elided")
print(f"[desktop-ui-test] PASS: balanced QML, {len(ids)} unique ids, desktop labels/layout, and Android sizing.")
