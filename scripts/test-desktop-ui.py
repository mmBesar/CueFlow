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


def object_block_for_id(object_id: str) -> tuple[str, str]:
    """Return an item's QML block and the indentation used by its direct properties."""
    match = re.search(r"^(\s*)id:\s*" + re.escape(object_id) + r"\s*$", source, re.MULTILINE)
    if not match:
        fail(f"cannot find QML object id {object_id}")
    indent = match.group(1)
    opening = source.rfind("{", 0, match.start())
    if opening < 0:
        fail(f"cannot find object opening brace for {object_id}")
    # Walk braces while ignoring comments and quoted strings, so nested children do not
    # accidentally count as direct properties of the object being inspected.
    depth = 0
    state = "code"
    quote = ""
    i = opening
    while i < len(source):
        char = source[i]
        following = source[i + 1] if i + 1 < len(source) else ""
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
        if char in ("\"", "'"):
            state = "string"
            quote = char
            i += 1
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[opening:i + 1], indent
        i += 1
    fail(f"unclosed object block for {object_id}")
    raise AssertionError("unreachable")


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
    "desktop natural-height control dock": 'id: desktopDisplayControls',
    "desktop playback action grid": 'id: desktopPlaybackPanel',
    "desktop reading adjustment panel": 'id: desktopTuningPanel',
    "desktop session pairing row": 'id: desktopSessionInfo',
    "reading adjustments section": 'text: "READING ADJUSTMENTS"',
    "play/pause text label": 'text: session.playing ? "Pause" : "Play"',
    "reset text label": 'text: "Reset"',
    "remote action labels": '"Remote enabled"',
    "remote enable label": '"Enable remote"',
    "desktop remote workspace": 'id: remoteDesktopLayout',
    "desktop fixed control sidebar": 'id: remoteDesktopControlPanel',
    "desktop script editor pane": 'id: remoteDesktopScriptEditor',
    "desktop overview panel": 'id: remoteDesktopOverviewPanel',
    "desktop remote transport grid": 'id: remoteDesktopTransportButtons',
    "remote editor is opt-in": 'property bool remoteEditorVisible: false',
    "narrow remote transport grid": 'id: compactRemoteTransportButtons',
    "desktop remote position control": 'id: remoteDesktopSeek',
    "desktop remote speed control": 'id: remoteDesktopSpeed',
    "text-size control": 'id: displayFontSizeDesktop',
    "text-width control": 'id: displayWidthDesktop',
    "desktop/mobile layout separation": 'visible: !window.desktopUi && !window.editingScript',
    "Android remains touch-sized": 'implicitHeight: window.desktopUi ? 34 : 46',
}
for description, marker in required.items():
    check(marker in source, f"missing {description} ({marker})")

check('columns: window.width >= 760 ? 4 : 2' in source,
      "desktop display actions should keep a one-row wide layout and reflow on narrow windows")
check('visible: window.desktopUi && window.width >= 900' in source,
      "wide desktop remote workspace is not enabled")
check('visible: !(window.desktopUi && window.width >= 900)' in source,
      "the scrolling mobile/narrow remote page can overlap the wide desktop workspace")
check('remoteDesktopScriptEditor.forceActiveFocus()' in source,
      "the desktop Edit action must focus the editor without scrolling controls away")
check('visible: window.remoteEditorVisible' in source,
      "both remote script editors must be hidden until editing is requested")
check('Layout.maximumHeight: window.width >= 1020' not in source,
      "desktop control area must not be capped below its visible content")
check('visible: window.displayTuningExpanded' in source,
      "desktop tuning sliders must collapse until explicitly requested")
check('columns: window.remoteEditorVisible ? 2 : 4' in source,
      "wide remote transport buttons should reflow when the editor narrows the sidebar")
check('columns: remoteContent.width >= 620 ? 3 : 2' in source,
      "narrow remote transport buttons should reflow rather than squeeze labels")
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
check('implicitHeight: desktopDisplayContent.implicitHeight + 16' in source,
      "desktop control dock should size itself to its content rather than overflow a hard height cap")
check('Layout.fillWidth: false' in source[source.index('id: displayPlayPauseDesktop'):source.index('id: displayResetDesktop')],
      "desktop playback buttons must not stretch to fill the whole window")
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
check('visible: !window.remoteEditorVisible' in source,
      "desktop remote overview should replace the script editor while editing is closed")
for editor_id in ("remoteEditorFrame", "remoteDesktopEditorPanel"):
    block, indent = object_block_for_id(editor_id)
    direct_visible = re.findall(r"^" + re.escape(indent) + r"visible:\s*(.+?)\s*$", block, re.MULTILINE)
    check(len(direct_visible) == 1 and direct_visible[0] == "window.remoteEditorVisible",
          f"{editor_id} must have one authoritative remoteEditorVisible binding (got {direct_visible})")
print(f"[desktop-ui-test] PASS: balanced QML, {len(ids)} unique ids, content-sized display dock, remote editor toggle, readable transport layouts, and Android sizing.")
