#!/usr/bin/env python3
"""Dependency-free structural regression checks for CueFlow's responsive QML UI."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
QML_PATH = ROOT / "qml" / "Main.qml"
source = QML_PATH.read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"[desktop-ui-test] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def check(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


# Balanced delimiters, ignoring comments and quoted strings. This is not a QML
# parser, but it catches common mistakes without requiring a Qt SDK in CI.
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
    "compact desktop display strip": 'id: desktopDisplayControls',
    "desktop play/pause label": 'text: session.playing ? "Pause" : "Play"',
    "desktop reset button": 'id: displayResetDesktop',
    "desktop remote-enable action": 'id: remoteToggleDesktop',
    "bounded progress slider": 'Layout.maximumWidth: 440',
    "optional display tuning": 'visible: window.displayTuningExpanded',
    "desktop-specific remote page": 'id: desktopRemotePage',
    "remote controls dashboard": 'id: desktopRemoteDashboard',
    "desktop remote playback controls": 'id: desktopPlaybackGroup',
    "desktop fullscreen action": 'session.requestViewerFullscreenToggle()',
    "desktop remote editor is a separate dialog": 'id: remoteScriptDialog',
    "desktop script editor control": 'id: remoteDesktopScriptEditor',
    "editor button opens dialog instead of scrolling the remote page": 'remoteScriptDialog.open()',
    "mobile remote page remains separate": 'visible: session.remoteMode && !window.desktopUi',
    "Android preserves touch sizing": 'implicitHeight: window.desktopUi ? 34 : 46',
    "soft accent state uses selected Catppuccin accent": 'Qt.rgba(window.accentColor.r, window.accentColor.g, window.accentColor.b, 0.14)',
}
for description, marker in required.items():
    check(marker in source, f"missing {description} ({marker})")

# Ensure the permanent display bar itself does not request extra vertical space.
display_start = source.index('id: desktopDisplayControls')
display_end = source.index('visible: !window.desktopUi && !window.editingScript', display_start)
display_block = source[display_start:display_end]
check('Layout.fillHeight: true' not in display_block,
      "desktop display controls must not request fill-height and eat reading space")
check('text: "PLAYBACK"' not in display_block,
      "old oversized card header should not return")
check('visible: window.displayTuningExpanded' in display_block,
      "desktop reading sliders should remain collapsed until requested")

# The always-visible desktop remote dashboard should not contain the editor body.
remote_start = source.index('id: desktopRemotePage')
remote_end = source.index('// REMOTE MODE', remote_start)
remote_block = source[remote_start:remote_end]
check('TextArea {' not in remote_block and 'ScrollView {' not in remote_block,
      "desktop remote editor leaked back into the main control page")
check('Layout.maximumWidth: 1040' in remote_block,
      "desktop remote dashboard should remain centered and width-bounded")
check('text: "Keyboard: Space play/pause' in remote_block,
      "desktop remote keyboard help is missing")

# The app icon is intentionally SVG and uses the same muted Catppuccin palette as
# the application; do not introduce a separate neon PNG asset.
icon = ROOT / "packaging" / "linux" / "cueflow.svg"
check(icon.exists(), "Catppuccin SVG application icon is missing")
icon_text = icon.read_text(encoding="utf-8")
check('#24273a' in icon_text and '#c6a0f6' in icon_text,
      "the application SVG no longer uses CueFlow's muted Catppuccin colors")
check(not any(p.suffix.lower() == ".png" and "icon" in p.name.lower() for p in ROOT.rglob("*")),
      "a separate raster app-icon asset was added; keep the SVG icon source")

print(f"[desktop-ui-test] PASS: balanced QML, {len(ids)} unique ids, compact display controls, desktop remote dashboard/editor separation, responsive layout, and Catppuccin SVG styling.")
