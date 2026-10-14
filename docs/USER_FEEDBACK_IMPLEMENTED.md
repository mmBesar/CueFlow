# User-feedback pass — 2026-10-14

This pass targets the first device tests and deliberately skips the app icon as requested.

## Implemented
- Floating fullscreen and controls icons now draw inside a fixed 40×40 canvas centered within each button, compensating for Qt Quick Controls styles that inset `contentItem` and otherwise offset the icon toward the lower-right.

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

# Remote controls, editor scrolling, CPU audit, and Android legacy target — 2026-10-14

- Added remote commands for toggling the display window's fullscreen state and the display control panel. The display remains authoritative and publishes the two view states in its snapshots so the remote button labels track the viewer.
- Wrapped both local and remote TextArea editors in ScrollView with a vertical scrollbar. This delegates touch dragging/flicking on Android and mouse-wheel/touchpad-wheel scrolling on desktop to Qt's scroll container while keeping each draft intact.
- Replaced floating-button line/rectangle composition with explicitly sized native QML rectangle shapes. The icons no longer depend on font glyph coverage, Canvas rendering, or inherited Item dimensions.
- Made the Markdown BiDi update idempotent in C++ and gated the QML trigger on actual text changes. Repeated block-format writes from `TextEdit.textChanged` can form a document-notification feedback loop; the formatter now skips blocks already using `Qt::LayoutDirectionAuto`, and the QML layer ignores text-change notifications that contain no text change.
- Kept Qt Quick's standard rendering architecture rather than introducing unneeded worker threads. GUI input/layout/render work is not made faster by forcing the app to occupy more cores; if sustained high CPU remains after eliminating the feedback path, profile with the app paused before attempting broader threading changes.
- Added a separate Qt 5.15.2/qmake build definition and CI job for an Android 6+ legacy APK (`armeabi-v7a`, min SDK/API 21, package ID `org.mmbesar.cueflow.legacy`). CI explicitly prepares Qt 5.15’s own package template and sets the manifest package and Gradle applicationId; the qmake project’s `ANDROID_PACKAGE_NAME` variable is not relied upon. The primary Android arm64 APK remains on Qt 6.12 and Android 9+ (API 28). Qt 5.15's official Android documentation lists support from Android 5/API 21 through Android 12/API 31; the legacy target is for old devices, not the recommended modern build.

## Verification still required

- Run the full modern Qt 6 and Qt 5.15 legacy Android jobs in GitHub Actions. The local environment does not have Qt's Android kits, Gradle wrapper, Android SDK, or QML lint tools installed, so APK compatibility has not been proven locally.
- Test remote fullscreen/control toggles in both directions: request them from Android remote while Linux is the display, and vice versa.
- Test long text editing via touch fling and mouse wheel on both editor views.
- Check idle CPU use with playback paused, then compare while playback is running. The source-level fix targets repeated block-format writes; it is not yet a measured CPU benchmark.
- Install `CueFlow-android6-armv7-legacy-debug.apk` on the Android 6 phone and verify keyboard, screen-awake, scroll, network pairing, and script edits. It is a separate package to allow the modern version to coexist.


# Legacy Android APK staging fix — 2026-10-14

- Corrected the Qt 5.15.2 Android 6 CI job to run `make apk_install_target` after compiling. A plain `make` compiles the native application library but does not stage it under `android-build/libs/<abi>/`, where `androiddeployqt` expects it. The Qt 5.15 `apk_install_target` is used explicitly before the packaging command.
- Kept the explicit `androiddeployqt` invocation after the staging target so the CI job can pin the Android SDK platform (`android-31`) and JDK path. The modern Qt 6 Android job and desktop/NixOS workflows are unchanged.


# Editor, touch controls, and release audit — 2026-10-14

## Implemented in source

- The main editor now uses narrow phone margins and a single compact heading instead of spending two rows on title/help text. Its border belongs to the fixed ScrollView viewport rather than the content-sized TextArea, and the text has a deeper top inset so placeholder/script lines stay clear of the frame. The editor fills the remaining height. Clear, Back, and Apply labels shorten on very narrow windows.
- Android and narrow-screen tuning can collapse behind a `Tune` action while keeping touch targets large. The desktop display controls use a dedicated two-panel deck: Playback and Position on the left, with Speed, Text size, and Text width grouped on the right. The panels stack on narrower desktop windows. Main desktop buttons have explicit 36px targets, wider natural widths, and persistent Play/Pause, Reset, and Remote labels so they are not clipped. The wide desktop remote view still caps the connection/control column and gives the script editor most of the horizontal space.
- Corrected the floating glyphs' optical horizontal position by shifting the icons left independently; the button hit targets and dock positions remain unchanged. The active Enable Remote button uses Catppuccin green with contrasting text while hosting is enabled.
- Desktop Space toggles play/pause in both display and remote mode, except while a script/address/PIN field or modal appearance dialog is active. Left/right nudges do not steal arrow keys from the remote editor/connection fields. Escape exits fullscreen rather than unexpectedly resetting playback.
- A completed tap on the Android reading surface toggles playback only while the display is in fullscreen. Normal-mode interactions and edit fields are not bound to that gesture.
- Added a Linux per-user bundle installer/launcher/icon plus uninstall script, a tag-based draft-release job, stable Android release-key signing, and SHA-256 checksums. The release job deliberately stops if signing secrets are not configured rather than publishing debug-signed APKs as production releases.

## Verification performed in the editing environment

- The QML and workflow sources were edited and inspected locally, but Qt/QML runtime tools are not installed in this environment, so this pass has not been Qt-built or rendered on a device.
- Passed locally: shell syntax checks, workflow YAML parsing and embedded shell checks, mocked AppImage packaging control flow, the large-archive validation regression test, dependency-free ScrollModel tests, CMake core build, and CTest. The AppImage control-flow test uses mocked downloader/tool binaries; it is not a real AppImage build. The Android fullscreen tap and exact icon alignment especially need confirmation on the same phone that previously exposed the issue.
- Release keystore secrets must be configured on GitHub before pushing a release tag. Linux x86_64 and aarch64 have one-file AppImage targets as well as the installable tarball fallback. The separate AppImage jobs reinstall the matching Qt toolchain so `linuxdeploy-plugin-qt` has `qmake` available on its own runner. AppImages are not universal and are not drop-in NixOS packages. No Windows/macOS builds are added by this pass.


# Keyboard navigation and speed controls — 2026-10-14

- Up/Down now nudge the display reading position by 40 rendered pixels per press (Up rewinds the viewport; Down advances it). The authoritative display handles the request; in remote mode the same shortcuts are sent through the existing nudge command.
- Left/Right now decrease/increase scrolling speed by 10 px/s per press, clamped to the UI slider's 0–600 px/s range. Remote speed changes use the existing speed command and are reflected by the host snapshot.
- Shortcuts are disabled while editing, while the Appearance dialog is open, when host/PIN/script fields have focus, or when one of the tuning/progress sliders has focus. Space retains play/pause behavior.
- Runtime verification still required: confirm key repeat behavior and directions with both device-role combinations, including while playback is running and near the beginning/end of the script.


# Desktop control deck revision — 2026-10-15

- Replaced the cramped desktop display-control row with two bordered groups: playback actions and position on the left, reading-adjustment sliders on the right. The control sections stack automatically below a 1020px window width.
- Restored comfortably sized desktop buttons with an explicit minimum width and 36px height; Play/Pause, Reset, and Enable remote/Remote enabled keep complete readable labels. The remote action remains green while hosting is active.
- Increased desktop mode-tab and form-control sizing while keeping Android sizing branches unchanged. Remote-mode action buttons now use normal desktop button heights instead of 24px controls.
- Added a dependency-free structural QML regression check to both core CI jobs, covering balanced delimiters, unique IDs, required desktop labels/layout, and preserved Android touch sizing.
- Local validation: the new UI structural test, ScrollModel tests, Linux package validation test, mocked AppImage packaging test, core-only CMake build, and CTest pass. The available environment lacks Qt/QML runtime tools, so the revised UI still needs a real Qt build and visual check on desktop; Android's branch should also be smoke-tested after CI.
