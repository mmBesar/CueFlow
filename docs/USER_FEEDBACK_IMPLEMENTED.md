# User-feedback pass — 2026-10-14

This pass targets the first device tests and deliberately skips the app icon as requested.

## Implemented

- Android foreground activity receives `FLAG_KEEP_SCREEN_ON`; the flag is cleared when CueFlow backgrounds and restored when it resumes.
- Main Material controls inherit the selected Catppuccin foreground, and reading text explicitly uses the selected flavor's text color.
- All four Catppuccin flavors (Latte, Frappé, Macchiato, Mocha) and all 26 named palette colors are available in Appearance settings; selections persist with `QSettings`.
- Display overlay controls use 34px icon buttons, hide after 3.5 seconds of inactivity, and reappear on screen taps/clicks.
- Pointer-driven scrolling pauses playback during the drag/flick and resumes it afterward if it was playing before the gesture.
- Layout changes during a pointer gesture are treated as geometry changes, not seeks; the previous authoritative progress fraction is preserved across range changes.
- The display owns playback advancement. The remote does not independently advance its local model against a different viewport range, eliminating a source of progress drift between snapshots.
- The display playback clock ticks at 8ms while playing for smoother fractional-pixel updates (16ms while idle/remote); network state broadcasts remain coalesced to approximately 60Hz.

## Still requires real-device verification

- Confirm Android stays awake during long sessions and releases the wake flag after the app backgrounds.
- Confirm all accent choices have sufficient contrast in real UI controls and QML Markdown on both light and dark flavors.
- Verify Linux-display/Android-remote interaction at different font sizes, text widths, viewport sizes, and with long mixed Arabic/English scripts, particularly that a reflow never forces progress to 100%.
- Confirm scroll feel on 60Hz and high-refresh-rate displays; the local playback tick is faster, but presentation cadence still depends on the platform.
