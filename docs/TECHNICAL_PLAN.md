# Product and technical plan

## Decision

Build a clean native-first application using Qt 6 / Qt Quick (QML) with a small C++ core. Do not add Rust merely for novelty: this app's riskiest requirements are cross-platform text layout, Arabic/English BiDi, mobile lifecycle behavior, and reliable direct-device networking. Qt has strong primitives for those areas and is packaged for the Linux architectures in scope. Keep the playback model independent from Qt so the core stays easy to test or port.

## Product interaction model

### Display
- A distraction-free script surface, no browser chrome.
- Markdown editor with a one-tap return to playback.
- Continuous scroll with speed expressed in px/s.
- Direct progress scrub, small pixel nudges, play/pause, reset, adjustable font and line width.
- Fullscreen with compact floating controls that auto-hide after inactivity and return on touch/click; windowed controls remain visible.
- Script and preferences saved locally.
- Start/stop a temporary LAN control session only when requested.

### Remote
- Connect by LAN address + short pairing PIN; QR and mDNS service discovery follow after the protocol stabilizes.
- Play/pause/reset, live scrub, press-and-hold precision nudges, speed, font size, and width.
- Edit/paste Markdown and explicitly send it to the display.
- Mirror authoritative playback state from the display; the remote does not independently simulate scrolling.

## Scroll model

The core stores normalized progress `p ∈ [0, 1]`, speed `v` in rendered pixels/second, and the current scroll range `R`. For elapsed time `dt`, advancement is `p += v * dt / R`, clamped to `[0, 1]`. The precise 16 ms controller timer updates the QML Flickable position; the presentation cadence remains constrained by the platform render loop. This makes motion independent of timer frequency and avoids the current one-pixel/zero-duration animation loop. Seeking updates the normalized progress continuously; small nudges add `deltaPixels / R`.

Frame pauses are capped at 50 ms, so backgrounding the app or hitting a breakpoint will not jump far through the script when the timer runs again. A later hardening pass must pause explicitly on Android lifecycle transitions and resume only by policy/user intent.

## Markdown, RTL, BiDi

Use Qt's Markdown text support rather than browser HTML. After Markdown layout, set each text block's layout direction to `Qt::LayoutDirectionAuto` so each paragraph/heading can determine direction from its content, not only the first paragraph in the whole script. Test mixed identifiers, Latin product names, punctuation, numbers, URLs, and inline code as a release gate. Images are stripped from the display renderer in this prototype to prevent unexpected remote image fetches while presenting a script.

Do not claim perfect Arabic/BiDi support until this has been tested visually on Linux and Android. Text layout differs across platform/font versions; the included mixed-language Markdown file is only the start of a regression corpus.

## Device-to-device session protocol

- Display opens a TCP listener only when explicitly enabled.
- Pairing uses a six-digit PIN. In the prototype it remains valid until hosting is stopped; expiration and failed-attempt throttling are not implemented yet.
- JSON messages are newline-delimited and size limited. A client must authenticate before sending commands; only one remote is accepted initially.
- The display owns playback state and is the source of truth. Progress updates are coalesced; script text is sent only at pairing or when replaced, not on every frame.
- Initial transport is plaintext for trusted LAN prototyping. Do not forward the port publicly. Before recommending use on untrusted networks, implement TLS with certificate verification/pinning or an authenticated encrypted transport.
- Current manual pairing is intentionally a simple first milestone. The next milestone should add PIN expiration and failed-attempt throttling, then QR pairing, IPv4/IPv6 handling, and mDNS discovery where the network allows multicast.

## Milestones

### M0 — foundation (this scaffold)
- Product architecture and platform fit established.
- Dependency-free scroll model with tests.
- Qt Quick UI and LAN protocol skeleton.

### M1 — first native Linux build
- Build with Qt 6.8+.
- Fix all compiler/QML warnings.
- Add QtTest protocol tests and a fake-clock scrolling test.
- Verify Arabic/English rendering and correct content height.
- Run display/remote locally and across two LAN devices.
- Verify that the remote never advances playback independently and layout reflow cannot turn the current offset into an accidental end-of-script seek.

### M2 — polish and protocol
- PIN expiration/throttling, QR pairing, and mDNS discovery.
- Reconnection and stale-session handling.
- TLS or another authenticated encrypted transport before use on untrusted networks.
- Keyboard/remote hotkeys, focus dimming.

### M3 — Android
- Build Android arm64 package.
- Orientation support, Android back-key behavior, and deeper lifecycle handling remain future work. Android foreground screen-on handling and compact auto-hiding controls are now implemented; verify on a physical device.
- Real-device test in both display and remote roles.

### M4 — packaging and architecture coverage
- Linux packages/artifacts for amd64 and arm64.
- Native RISC-V64 core testing through RISE runners is configured. Full Qt GUI build and runtime testing still requires a suitable Qt 6.5+ toolchain on RISC-V64.
- Optional web client only if concrete use cases justify maintaining it; it is not required for the native product.

## Release acceptance criteria

- No perceptible periodic jumps at any supported speed; rate is stable across 30/60/120 Hz frame rates.
- Position slider tracks during drag, supports fine adjustment, and never maps a single arrow press to 1% of an arbitrarily long script.
- Both device-role permutations work.
- Script persistence and script transfer preserve Unicode and Markdown exactly.
- BiDi corpus passes on tested target platforms.
- No network image loading while displaying scripts; no Internet dependency for core use.
- No claim of RISC-V/Android support until builds and device tests pass.
