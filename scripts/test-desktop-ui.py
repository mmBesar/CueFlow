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
    "wide desktop side inspector": 'id: desktopDisplayDock',
    "wide desktop inspector breakpoint": 'width >= 1120',
    "reading canvas reserves inspector width": 'anchors.rightMargin: window.wideDesktopDisplayDock ? window.desktopDisplayDockWidth : 0',
    "floating controls stay attached to the reading canvas": 'anchors.right: prompterFlick.right',
    "desktop play/pause label": 'text: session.playing ? "Pause" : "Play"',
    "desktop reset button": 'id: displayResetDesktop',
    "desktop remote-enable action": 'id: remoteToggleDesktop',
    "bounded progress slider": 'Layout.maximumWidth: 440',
    "optional display tuning": 'visible: window.displayTuningExpanded',
    "desktop-specific remote page": 'id: desktopRemotePage',
    "remote controls dashboard": 'id: desktopRemoteDashboard',
    "desktop remote playback controls": 'id: desktopPlaybackGroup',
    "desktop fullscreen action": 'session.requestViewerFullscreenToggle()',
    "desktop remote editor is an inline panel": 'id: remoteDesktopScriptPanel',
    "inline editor visibility has one explicit state": 'visible: window.remoteDesktopScriptExpanded',
    "desktop script editor control": 'id: remoteDesktopScriptEditor',
    "editor toggles without a modal dialog": 'window.remoteDesktopScriptExpanded = !window.remoteDesktopScriptExpanded',
    "opening the editor reveals and focuses it": 'remoteDesktopScriptEditor.forceActiveFocus()',
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
check('!window.wideDesktopDisplayDock' in display_block,
      "the compact footer should be hidden when the wide side inspector is active")

dock_start = source.index('id: desktopDisplayDock')
dock_end = source.index('id: displayOverlayDock', dock_start)
dock_block = source[dock_start:dock_end]
check('anchors.top: parent.top' in dock_block and 'anchors.right: parent.right' in dock_block
      and 'anchors.bottom: parent.bottom' in dock_block,
      "the wide inspector must occupy its own full-height column")
check('id: displaySeekDock' in dock_block and 'id: displayDockPlayPause' in dock_block,
      "the wide inspector must provide independent playback and position controls")
check('id: displaySpeedDock' in dock_block and 'id: displayFontSizeDock' in dock_block
      and 'id: displayWidthDock' in dock_block,
      "the wide inspector must expose the reading adjustments when expanded")

# The desktop remote editor belongs to the page layout, but stays collapsed by default.
remote_start = source.index('id: desktopRemotePage')
remote_end = source.index('// REMOTE MODE', remote_start)
remote_block = source[remote_start:remote_end]
check('id: remoteDesktopScriptPanel' in remote_block and 'TextArea {' in remote_block and 'ScrollView {' in remote_block,
      "desktop remote editor must be embedded in the remote page, not a modal popup")
check('remoteScriptDialog' not in source,
      "the old white/dimming modal remote editor must not return")
check('color: window.activePalette.mantle' in remote_block and 'color: window.activePalette.base' in remote_block,
      "inline editor surfaces must use the active Catppuccin palette")
check('Layout.maximumWidth: 1040' in remote_block,
      "desktop remote dashboard should remain centered and width-bounded")
check('text: "Keyboard: Space play/pause' in remote_block,
      "desktop remote keyboard help is missing")

# Keep the supplied SVG as the single editable/source asset. Density-specific PNGs
# are permitted only where Android launchers require them; they are derived copies.
import struct
import xml.etree.ElementTree as ET

icon = ROOT / "icon" / "CueFlow-icon.svg"
check(icon.is_file(), "the canonical icon/CueFlow-icon.svg source is missing")
try:
    icon_root = ET.parse(icon).getroot()
except ET.ParseError as exc:
    fail(f"the canonical app icon is not valid SVG/XML: {exc}")
icon_text = icon.read_text(encoding="utf-8")
check('#24273a' in icon_text and '#c6a0f6' in icon_text,
      "the app icon no longer uses CueFlow's muted Catppuccin palette")
check('source: "qrc:/icons/CueFlow-icon.svg"' in source,
      "the main UI must load the canonical SVG icon")
check('QIcon(QStringLiteral(":/icons/CueFlow-icon.svg"))' in (ROOT / "src/main.cpp").read_text(encoding="utf-8"),
      "the native desktop window must load the canonical SVG icon")
cmake = (ROOT / "CMakeLists.txt").read_text(encoding="utf-8")
check('FILES icon/CueFlow-icon.svg' in cmake and 'Qt6::Svg' in cmake,
      "the canonical SVG must be embedded and Qt SVG support linked")
for script_name in ("package-appimage.sh", "package-linux-bundle.sh"):
    package_script = (ROOT / "scripts" / script_name).read_text(encoding="utf-8")
    check('icon/CueFlow-icon.svg' in package_script,
          f"{script_name} must package the canonical SVG icon")
check(not (ROOT / "assets" / "icons").exists(),
      "obsolete duplicate assets/icons raster source directory must be removed")
# A legacy SVG may remain on disk for compatibility, but all active app and
# packaging entry points must reference the requested canonical source instead.
check('packaging/linux/cueflow.svg' not in cmake,
      "CMake must not install the obsolete duplicate Linux SVG icon")
for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    launcher = ROOT / "packaging/android/res" / f"mipmap-{density}" / "ic_launcher.png"
    check(launcher.is_file(), f"Android {density} launcher derivative is missing")
    header = launcher.read_bytes()[:24]
    check(header[:8] == b"\x89PNG\r\n\x1a\n", f"Android {density} launcher is not PNG")
    dimensions = struct.unpack(">II", header[16:24])
    check(dimensions == (size, size), f"Android {density} launcher has dimensions {dimensions}, expected {(size, size)}")
legacy_ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
check('icon_root = pathlib.Path("packaging/android/res")' in legacy_ci,
      "legacy Android build must use launcher derivatives generated from the canonical SVG")
check('for component in Core Gui Network Qml Quick QuickControls2 Svg' in legacy_ci,
      "desktop/Android Qt builds must verify the Qt SVG component")
print(f"[desktop-ui-test] PASS: balanced QML, {len(ids)} unique ids, wide desktop inspector, non-overlapping reading viewport, compact responsive controls, inline themed remote editor, canonical SVG icon, and Android launcher derivatives.")
