# User-feedback pass — 2026-10-14

This pass targets the first device tests and deliberately skips the app icon as requested.

## Implemented

- Android foreground activity receives `FLAG_KEEP_SCREEN_ON`; the flag is cleared when CueFlow backgrounds and restored when it resumes.
- Main Material controls inherit the selected Catppuccin foreground, and reading text explicitly uses the selected flavor's text color.
- All four Catppuccin flavors (Latte, Frappé, Macchiato, Mocha) and all 26 named palette colors are available in Appearance settings; selections persist with `QSettings`.
- Display overlay controls use 34px icon buttons; they now auto-hide only in fullscreen and reappear after a completed tap/click on the reading area.
- Pointer-driven scrolling pauses playback during a gesture and resumes it afterward if it was playing before; the normalized position is committed once the native flick finishes to avoid per-frame feedback.
- Layout changes during a pointer gesture are treated as geometry changes, not seeks; the previous authoritative progress fraction is preserved across range changes.
- The display owns playback advancement. The remote does not independently advance its local model against a different viewport range, eliminating a source of progress drift between snapshots.
- Display playback uses a 16ms cadence; the frame timer is demand-driven and does not poll while idle or in remote mode. State broadcasts are coalesced to approximately 60Hz.

## Still requires real-device verification

- Confirm Android stays awake during long sessions and releases the wake flag after the app backgrounds.
- Confirm all accent choices have sufficient contrast in real UI controls and QML Markdown on both light and dark flavors.
- Verify Linux-display/Android-remote interaction at different font sizes, text widths, viewport sizes, and with long mixed Arabic/English scripts, particularly that a reflow never forces progress to 100%.
- Confirm scroll feel on 60Hz and high-refresh-rate displays; the local playback tick is faster, but presentation cadence still depends on the platform.


# Follow-up — responsiveness and control behavior

## Implemented in the next pass

- Native touch/momentum scrolling no longer sends a seek command and synchronously echoes the content position back through QML for every motion frame. The normalized position is committed once after the gesture/flick ends; layout reflow during a gesture still preserves the last authoritative progress.
- The reading `Flickable` is explicitly vertical, keeps subpixel positions for animation quality, allows a higher maximum flick velocity for long scripts, and the read-only text does not take keyboard focus on press.
- Playback uses a 16 ms cadence rather than switching to an 8 ms timer. The C++ frame timer is demand-driven: it runs during display playback or briefly to flush changed state, and sleeps while idle or in remote mode.
- Only the small floating display buttons auto-hide, and only in fullscreen. The main playback/control panel stays visible. Leaving fullscreen always restores the floating buttons.
- Fullscreen controls reveal on a completed left/right click or touchscreen tap on the reading area; detection occurs on release to avoid changing the pointer target mid-press. The root-level handler that interfered with normal-mode interaction was removed.
- Display tuning controls use a three-column layout on wide windows and a single compact column on narrow screens. Remote control margins and spacing were reduced.
- Mouse-wheel and touchpad-wheel input adjusts speed, font size, text width, and reading position when the pointer is over the corresponding slider.

## Verification still required

- Test Android touch dragging and flicks on-device; maximum flick velocity and actual smoothness depend on the phone, refresh rate, Qt render backend, and script complexity.
- Test fullscreen overlay reveal using single taps, slow/fast swipes, and mouse clicks; normal mode must never auto-hide controls.
- Confirm speed, font-size, width, and position change by one intuitive step per wheel notch on Linux, including when the display is paired to an Android remote.
- Confirm Linux/Android builds with GitHub Actions. Source-level tests do not replace real-device performance checks.


# Interaction and pairing audit — 2026-10-14

- Floating controls are now vertically stacked and contain only fullscreen and fullscreen control-panel toggle actions. The Appearance button remains in the header; the Edit action is in the header beside it. Fullscreen and control-panel symbols are drawn from shapes rather than font glyphs, avoiding tofu/missing-glyph boxes on Android.
- In windowed mode the dock and control panel stay fully visible. In fullscreen, the main playback/tuning panel can be hidden independently and restored from the dock; the dock fades to 16% opacity instead of becoming unclickable/invisible. A tap on the reading surface also reveals it.
- Removed focus-conditional `Binding` objects from both script TextAreas. Draft synchronization is explicit and refuses to replace text while the editor has focus, preventing the editor from blanking/resetting during virtual-keyboard focus changes. Added Clear actions for display and remote drafts. Exiting the editor keeps an unsaved draft; Apply commits it to the display.
- Pairing PIN is four digits, stable during a host session and unchanged by failed attempts. Five consecutive failures trigger a 30-second cooldown. Starting/stopping hosting resets the cooldown state. The transport remains unauthenticated until PIN verification and unencrypted after pairing, so it must remain on a trusted LAN.

## Verification still required

- Run the full Qt/Android CI build after these changes.
- On Android, test editing before and after opening the soft keyboard, clear/paste, text retention after leaving/re-entering the editor, and sending drafts to a Linux display.
- Verify fullscreen dock fade/tap recovery and the controls-panel toggle with both touch and mouse.
- Test four-digit pairing, reconnects without PIN rotation, and the failed-PIN cooldown across at least five attempts.
