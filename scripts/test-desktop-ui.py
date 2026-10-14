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
    "remote action labels": '"Remote enabled"',
    "remote enable label": '"Enable remote"',
    "desktop remote workspace": 'id: remoteDesktopLayout',
    "desktop fixed control sidebar": 'id: remoteDesktopControlPanel',
    "desktop script editor pane": 'id: remoteDesktopScriptEditor',
    "desktop remote position control": 'id: remoteDesktopSeek',
    "desktop remote speed control": 'id: remoteDesktopSpeed',
    "text-size control": 'id: displayFontSizeDesktop',
    "text-width control": 'id: displayWidthDesktop',
    "desktop/mobile layout separation": 'visible: !window.desktopUi && !window.editingScript',
    "Android remains touch-sized": 'implicitHeight: window.desktopUi ? 34 : 46',
}
for description, marker in required.items():
    check(marker in source, f"missing {description} ({marker})")

check('columns: window.width >= 1020 ? 2 : 1' in source,
      "desktop display controls no longer adapt between side-by-side and stacked layouts")
check('visible: window.desktopUi && window.width >= 900' in source,
      "wide desktop remote split workspace is not enabled")
check('visible: !(window.desktopUi && window.width >= 900)' in source,
      "the scrolling mobile/narrow remote page can overlap the wide desktop workspace")
check('remoteDesktopScriptEditor.forceActiveFocus()' in source,
      "the desktop Edit action must focus the editor without scrolling controls away")
check('if (remoteFlick.visible && !remoteScriptEditor.activeFocus' in source,
      "the hidden narrow-layout editor must not mirror every desktop keystroke")
check('if (remoteDesktopLayout.visible && !remoteDesktopScriptEditor.activeFocus' in source,
      "the hidden desktop editor must not mirror every mobile keystroke")
remote_desktop_layout = source[source.index('id: remoteDesktopLayout'):source.index('id: remoteDesktopWorkspace')]
check('onVisibleChanged: {' in remote_desktop_layout,
      "the desktop editor must resync drafts when switching back from the compact layout")
remote_flick = source[source.index('id: remoteFlick'):source.index('id: remoteContent')]
check('onVisibleChanged: {' in remote_flick,
      "the stacked editor must resync drafts when the window returns to its compact layout")
check('Layout.fillHeight: false' in source[source.index('id: desktopPlaybackPanel'):source.index('id: desktopPlaybackContent')],
      "desktop playback panel may expand vertically and steal space from the prompter")
check('Layout.fillHeight: false' in source[source.index('id: desktopTuningPanel'):source.index('id: desktopTuningContent')],
      "desktop tuning panel may expand vertically and steal space from the prompter")
check('visible: window.width >= 1020 || window.displayTuningExpanded' in source,
      "tuning controls should collapse into a Tune action on narrow desktop windows")
check('Layout.maximumHeight: window.width >= 1020' in source,
      "the desktop display control deck must have a bounded height so the reading scene remains dominant")
check('visible: session.hosting' in source[source.index('id: desktopSessionInfo'):source.index('id: desktopSessionContent')],
      "the desktop session-info row should not reserve space when hosting is inactive")
check(source.count('&& !remoteDesktopScriptEditor.activeFocus') >= 5,
      "all keyboard shortcuts must yield while the wide desktop script editor has focus")
check(source.count('&& !remoteDesktopHostField.activeFocus') == 5,
      "all keyboard shortcuts must yield while the wide desktop address field has focus")
check(source.count('&& !remoteDesktopPinField.activeFocus') == 5,
      "all keyboard shortcuts must yield while the wide desktop PIN field has focus")
check('elide: Text.ElideNone' in source,
      "remote button label must not be deliberately elided")
print(f"[desktop-ui-test] PASS: balanced QML, {len(ids)} unique ids, desktop labels/layout, and Android sizing.")
