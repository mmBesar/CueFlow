#!/usr/bin/env python3
"""Dependency-free structural regression checks for CueFlow's adaptive UI and app identity."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import re
import struct
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "qml" / "Main.qml"
source = QML.read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"[desktop-ui-test] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def check(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


# Structural scan skips comments/strings and catches obvious bracket corruption.
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
    "desktop right-hand control dock": 'id: desktopControlDock',
    "main display stays in a separate workspace": 'id: displayWorkspace',
    "narrow desktop transport controls": 'id: desktopCompactControls',
    "collapsible compact tuning": 'id: desktopCompactTuning',
    "readable desktop Play/Pause": 'text: session.playing ? "Pause" : "Play"',
    "visible desktop Reset label": 'text: "Reset"',
    "remote toggle label": 'text: session.hosting ? "Remote enabled" : "Enable remote"',
    "right sidebar playback panel": 'id: desktopPlaybackPanel',
    "right sidebar reading adjustment panel": 'id: desktopTuningPanel',
    "text-size control in sidebar": 'id: displayFontSizeDesktop',
    "text-width control in sidebar": 'id: displayWidthDesktop',
    "Android retains its separate touch layout": 'visible: !window.desktopUi && !window.editingScript',
    "app icon is used in the UI": 'source: "qrc:/icons/cueflow-icon.png"',
    "wide remote view does not jump away from controls": 'if (!remoteContent.wideDesktop)',
}
for description, marker in required.items():
    check(marker in source, f"missing {description} ({marker})")

check('window.width >= 1020' in source and 'Layout.preferredWidth: 316' in source,
      "desktop dock breakpoint/width was changed without updating this test")
check('elide: Text.ElideNone' in source,
      "remote button labels must not be deliberately elided")
for compact_slider in ("displaySeekCompact", "displaySpeedCompact", "displayFontSizeCompact", "displayWidthCompact"):
    check(source.count(f"!{compact_slider}.activeFocus") >= 5,
          f"global keyboard shortcuts must yield while {compact_slider} is focused")
icon_file = ROOT / "assets/icons/cueflow-icon.png"
check(icon_file.is_file(), "generated app icon asset is missing")
check((ROOT / "packaging/linux/cueflow.svg").is_file(), "scalable Linux icon is missing")
try:
    icon_svg = ET.parse(ROOT / "packaging/linux/cueflow.svg").getroot()
except ET.ParseError as exc:
    fail(f"scalable icon SVG is invalid: {exc}")
check(icon_svg.tag.endswith("svg"), "scalable icon root is not an SVG")
check((ROOT / "src/main.cpp").read_text(encoding="utf-8").find('setWindowIcon(QIcon(QStringLiteral(":/icons/cueflow-icon.png")))') >= 0,
      "native window icon is not configured")
check('QGuiApplication::setDesktopFileName(QStringLiteral("cueflow"))' in (ROOT / "src/main.cpp").read_text(encoding="utf-8"),
      "Linux desktop-entry identity is not configured")
check('BASE assets/icons' in (ROOT / "CMakeLists.txt").read_text(encoding="utf-8"),
      "Qt resource alias base must keep :/icons/cueflow-icon.png stable")
for size in (16, 24, 32, 48, 64, 72, 96, 128, 144, 192, 256, 512):
    png = ROOT / "assets/icons" / ("cueflow-icon.png" if size == 512 else f"cueflow-icon-{size}.png")
    check(png.is_file(), f"icon size {size} is missing")
    header = png.read_bytes()[:24]
    check(header[:8] == b"\x89PNG\r\n\x1a\n", f"icon size {size} is not a PNG")
    dimensions = struct.unpack(">II", header[16:24])
    check(dimensions == (size, size), f"icon {png.name} has unexpected dimensions {dimensions}")
for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    modern = ROOT / "packaging/android/res" / f"mipmap-{density}" / "ic_launcher.png"
    check(modern.is_file(), f"modern Android icon for {density} is missing")
    check(f'"mipmap-{density}": {size}' in (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8"),
          f"legacy Android {density} icon staging is missing")
check('QT_ANDROID_APP_ICON "@mipmap/ic_launcher"' in (ROOT / "CMakeLists.txt").read_text(encoding="utf-8"),
      "modern Android launcher icon property is missing")
check((ROOT / "docs/releases/v0.1.0.md").is_file(), "first-release notes are missing")
print(f"[desktop-ui-test] PASS: balanced QML, {len(ids)} unique ids, adaptive desktop layout, remote controls, Android separation, app/window/launcher icons, and v0.1.0 release notes.")
