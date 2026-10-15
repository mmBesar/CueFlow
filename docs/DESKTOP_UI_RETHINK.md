# Desktop UI layout decisions

This pass is a correction to the previous desktop control-deck change. The goal is to preserve the reading surface as the main part of the display window and make editing an intentional action rather than the default remote view.

## Display mode

- The prompt/read viewport consumes the available vertical space.
- The desktop control deck and both panels explicitly set `Layout.fillHeight: false`. Their implicit height comes from the contained controls, so the controls stay in a compact footer instead of competing with the reading surface for the window height.
- Playback/position and reading adjustments remain separate panels. The reading sliders are grouped in columns on wide windows and stack as space shrinks.
- Mobile keeps its existing touch-first control row; desktop sizing is not reused for Android touch controls.

## Remote mode

- The landing view prioritizes connection state and playback controls. The script editor starts collapsed.
- The toolbar's Edit action toggles the editor. On wide desktop windows, the editor opens beside the control card; on narrow windows it appears below the controls and the view scrolls only after Edit is explicitly requested.
- Done, switching to Remote, and sending a script return to the top-level remote controls.
- The content height tracks the GridLayout's implicit content height rather than making the editor fill the whole viewport.

## Color and visual hierarchy

The bundled `packaging/linux/cueflow.svg` establishes a muted Catppuccin Macchiato palette: base `#24273a`, surface `#363a4f`, text `#cad3f5`, and mauve `#c6a0f6`. Active desktop states use soft mauve text/borders against a neutral surface instead of saturated green fills. Existing flavor/accent settings remain available.

## Design references

The remote controls follow the common teleprompter hierarchy of primary Play/Pause and position controls first, with display settings secondary and the script editor separate. Examples reviewed: [RemoteCue controller](https://remotecue.app/) and its [display-settings panel](https://remotecue.app/). The layout bug was also checked against [Qt Quick Layouts documentation](https://doc.qt.io/qt-6/qtquicklayouts-overview.html), which notes that `Layout.fillHeight` defaults to true for layouts, and the [Qt Quick Controls ScrollView documentation](https://doc.qt.io/qt-6/qml-qtquick-controls-scrollview.html) for scrollable editor sizing.

## Validation limitation

`scripts/test-desktop-ui.py` is a structural regression check, not a GUI renderer. The core ScrollModel, archive packaging, and mocked AppImage packaging tests can run without Qt, but final spacing and rendering still require the Qt GUI build and a visual check on Linux.
