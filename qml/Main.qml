import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: window
    width: 1280
    height: 820
    minimumWidth: 320
    minimumHeight: 420
    visible: true
    title: "CueFlow"
    color: palette.window

    property bool editingScript: false
    // Only the small floating buttons auto-hide; the main controls stay visible.
    property bool overlayControlsVisible: true
    property bool displayControlsVisible: true
    property var flavorNames: ["Latte", "Frappé", "Macchiato", "Mocha"]
    property var accentNames: [
        "Rosewater", "Flamingo", "Pink", "Mauve", "Red", "Maroon",
        "Peach", "Yellow", "Green", "Teal", "Sky", "Sapphire", "Blue", "Lavender",
        "Text", "Subtext 1", "Subtext 0", "Overlay 2", "Overlay 1", "Overlay 0",
        "Surface 2", "Surface 1", "Surface 0", "Base", "Mantle", "Crust"
    ]
    property var catppuccinFlavors: ({
        "Latte": {
            rosewater: "#dc8a78", flamingo: "#dd7878", pink: "#ea76cb", mauve: "#8839ef",
            red: "#d20f39", maroon: "#e64553", peach: "#fe640b", yellow: "#df8e1d",
            green: "#40a02b", teal: "#179299", sky: "#04a5e5", sapphire: "#209fb5",
            blue: "#1e66f5", lavender: "#7287fd", text: "#4c4f69", subtext1: "#5c5f77",
            subtext0: "#6c6f85", overlay2: "#7c7f93", overlay1: "#8c8fa1", overlay0: "#9ca0b0",
            surface2: "#acb0be", surface1: "#bcc0cc", surface0: "#ccd0da", base: "#eff1f5",
            mantle: "#e6e9ef", crust: "#dce0e8"
        },
        "Frappé": {
            rosewater: "#f2d5cf", flamingo: "#eebebe", pink: "#f4b8e4", mauve: "#ca9ee6",
            red: "#e78284", maroon: "#ea999c", peach: "#ef9f76", yellow: "#e5c890",
            green: "#a6d189", teal: "#81c8be", sky: "#99d1db", sapphire: "#85c1dc",
            blue: "#8caaee", lavender: "#babbf1", text: "#c6d0f5", subtext1: "#b5bfe2",
            subtext0: "#a5adce", overlay2: "#949cbb", overlay1: "#838ba7", overlay0: "#737994",
            surface2: "#626880", surface1: "#51576d", surface0: "#414559", base: "#303446",
            mantle: "#292c3c", crust: "#232634"
        },
        "Macchiato": {
            rosewater: "#f4dbd6", flamingo: "#f0c6c6", pink: "#f5bde6", mauve: "#c6a0f6",
            red: "#ed8796", maroon: "#ee99a0", peach: "#f5a97f", yellow: "#eed49f",
            green: "#a6da95", teal: "#8bd5ca", sky: "#91d7e3", sapphire: "#7dc4e4",
            blue: "#8aadf4", lavender: "#b7bdf8", text: "#cad3f5", subtext1: "#b8c0e0",
            subtext0: "#a5adcb", overlay2: "#939ab7", overlay1: "#8087a2", overlay0: "#6e738d",
            surface2: "#5b6078", surface1: "#494d64", surface0: "#363a4f", base: "#24273a",
            mantle: "#1e2030", crust: "#181926"
        },
        "Mocha": {
            rosewater: "#f5e0dc", flamingo: "#f2cdcd", pink: "#f5c2e7", mauve: "#cba6f7",
            red: "#f38ba8", maroon: "#eba0ac", peach: "#fab387", yellow: "#f9e2af",
            green: "#a6e3a1", teal: "#94e2d5", sky: "#89dceb", sapphire: "#74c7ec",
            blue: "#89b4fa", lavender: "#b4befe", text: "#cdd6f4", subtext1: "#bac2de",
            subtext0: "#a6adc8", overlay2: "#9399b2", overlay1: "#7f849c", overlay0: "#6c7086",
            surface2: "#585b70", surface1: "#45475a", surface0: "#313244", base: "#1e1e2e",
            mantle: "#181825", crust: "#11111b"
        }
    })
    readonly property var activePalette: catppuccinFlavors[session.themeFlavor] || catppuccinFlavors["Macchiato"]
    readonly property color backgroundColor: activePalette.base
    readonly property color foregroundColor: activePalette.text
    readonly property color accentColor: activePalette[colorKey(session.themeAccent)] || activePalette.mauve
    readonly property color accentTextColor: contrastingText(accentColor)

    function colorKey(name) {
        return String(name).toLowerCase().replace(/ /g, "")
    }

    function colorForName(name) {
        return activePalette[colorKey(name)] || activePalette.mauve
    }

    function transparentColor(colorValue) {
        return Qt.rgba(colorValue.r, colorValue.g, colorValue.b, 0)
    }

    function relativeLuminance(colorValue) {
        function linear(channel) {
            return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(colorValue.r) + 0.7152 * linear(colorValue.g) + 0.0722 * linear(colorValue.b)
    }

    function contrastRatio(first, second) {
        var l1 = relativeLuminance(first)
        var l2 = relativeLuminance(second)
        return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)
    }

    function contrastingText(colorValue) {
        // Pick whichever end of this flavor's foreground/background pair gives
        // the highest contrast for the chosen accent, even for unusual choices.
        return contrastRatio(colorValue, foregroundColor) >= contrastRatio(colorValue, backgroundColor)
                ? foregroundColor : backgroundColor
    }

    function revealControls() {
        overlayControlsVisible = true
        if (visibility === Window.FullScreen && !editingScript)
            controlsHideTimer.restart()
        else
            controlsHideTimer.stop()
    }

    function wheelDirection(event) {
        var delta = event.angleDelta.y
        if (delta === 0)
            delta = event.pixelDelta.y
        return delta > 0 ? 1 : delta < 0 ? -1 : 0
    }

    onVisibilityChanged: {
        session.setViewerFullscreenState(visibility === Window.FullScreen)
        if (visibility === Window.FullScreen) {
            displayControlsVisible = true
            revealControls()
        } else {
            controlsHideTimer.stop()
            overlayControlsVisible = true
            displayControlsVisible = true
        }
    }
    onDisplayControlsVisibleChanged: session.setViewerControlsVisibleState(displayControlsVisible)

    Timer {
        id: controlsHideTimer
        interval: 3500
        repeat: false
        onTriggered: {
            if (window.visibility !== Window.FullScreen || window.editingScript) {
                window.overlayControlsVisible = true
                return
            }
            if (!displaySeek.pressed && !displaySpeed.pressed
                    && !displayFontSize.pressed && !displayWidth.pressed
                    && !prompterFlick.moving)
                window.overlayControlsVisible = false
            else
                restart()
        }
    }

    Material.theme: session.themeFlavor === "Latte" ? Material.Light : Material.Dark
    Material.accent: accentColor
    // Explicit foreground prevents controls from retaining Material's default
    // near-black text when the selected Catppuccin flavor has a dark surface.
    Material.foreground: foregroundColor
    palette.window: activePalette.base
    palette.windowText: activePalette.text
    palette.base: activePalette.mantle
    palette.alternateBase: activePalette.surface0
    palette.text: activePalette.text
    palette.button: activePalette.surface0
    palette.buttonText: activePalette.text
    palette.highlight: accentColor
    palette.highlightedText: accentTextColor

    header: ToolBar {
        visible: window.visibility !== Window.FullScreen
        contentHeight: 58
        background: Rectangle { color: window.activePalette.mantle }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14
            Label {
                text: "CueFlow"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: window.activePalette.text
            }
            Label {
                visible: window.width > 650
                text: "NATIVE TELEPROMPTER"
                font.pixelSize: 10
                font.letterSpacing: 1.7
                color: window.activePalette.subtext0
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                visible: window.width > 480
                radius: 12
                color: session.connected ? window.activePalette.green : session.hosting ? window.activePalette.surface1 : window.activePalette.surface0
                implicitHeight: 30
                implicitWidth: statusLabel.implicitWidth + 18
                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: session.connected ? "REMOTE" : session.hosting ? "SESSION OPEN" : "LOCAL MODE"
                    color: window.activePalette.base
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }
            Button {
                text: session.remoteMode ? "Edit" : (window.editingScript ? "Back" : "Edit")
                implicitHeight: 38
                implicitWidth: 66
                padding: 6
                ToolTip.visible: hovered
                ToolTip.text: session.remoteMode ? "Edit or send a script" : (window.editingScript ? "Return to reading" : "Edit script")
                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                    Item {
                        width: 14; height: 16
                        visible: session.remoteMode || !window.editingScript
                        Rectangle {
                            x: 5; y: 1; width: 4; height: 12
                            rotation: 42
                            radius: 1
                            color: window.accentColor
                        }
                        Rectangle {
                            x: 2; y: 11; width: 5; height: 3
                            rotation: 42
                            radius: 1
                            color: window.activePalette.text
                        }
                    }
                    Item {
                        width: 14; height: 16
                        visible: !session.remoteMode && window.editingScript
                        Rectangle { x: 2; y: 7; width: 10; height: 2; color: window.activePalette.text }
                        Rectangle { x: 2; y: 4; width: 5; height: 2; rotation: -45; color: window.activePalette.text }
                        Rectangle { x: 2; y: 10; width: 5; height: 2; rotation: 45; color: window.activePalette.text }
                    }
                    Text {
                        text: session.remoteMode ? "Edit" : (window.editingScript ? "Back" : "Edit")
                        color: window.activePalette.text
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                    }
                    }
                }
                onClicked: {
                    if (session.remoteMode) {
                        remoteFlick.contentY = Math.max(0, remoteContent.y + remoteEditorFrame.y - 16)
                        Qt.callLater(function() { remoteScriptEditor.forceActiveFocus() })
                    } else if (!window.editingScript) {
                        // Keep an existing draft intact; entering the editor must not
                        // silently discard text left from a previous editing session.
                        window.editingScript = true
                        controlsHideTimer.stop()
                    } else {
                        window.editingScript = false
                        window.revealControls()
                    }
                }
                background: Rectangle { radius: 10; color: window.activePalette.surface0 }
            }
            Button {
                text: "⚙"
                implicitWidth: 40
                implicitHeight: 38
                padding: 0
                ToolTip.visible: hovered
                ToolTip.text: "Appearance"
                onClicked: appearanceDialog.open()
                contentItem: Text {
                    text: parent.text
                    color: window.activePalette.text
                    font.pixelSize: 20
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle { radius: 10; color: window.activePalette.surface0 }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: modeTabs
            visible: window.visibility !== Window.FullScreen
            Layout.fillWidth: true
            currentIndex: session.remoteMode ? 1 : 0
            onCurrentIndexChanged: session.setMode(currentIndex === 1 ? "remote" : "display")
            background: Rectangle { color: window.activePalette.mantle }
            TabButton { text: "Display" }
            TabButton { text: "Remote" }
        }

        // DISPLAY MODE ------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !session.remoteMode

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                StackLayout {
                    id: displayStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: window.editingScript ? 1 : 0

                    Item {
                        id: displayPage
                        Flickable {
                            id: prompterFlick
                            anchors.fill: parent
                            clip: true
                            contentWidth: width
                            contentHeight: scriptFlow.height
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.VerticalFlick
                            // Preserve subpixel positions for smooth text animation, while
                            // allowing a deliberate touch flick to cover long scripts.
                            pixelAligned: false
                            maximumFlickVelocity: 8000
                            property bool syncingFromModel: false
                            property bool localSeekGestureActive: false
                            property bool geometryChangedDuringGesture: false

                            onDraggingChanged: {
                                if (dragging && !syncingFromModel && !localSeekGestureActive) {
                                    localSeekGestureActive = true
                                    geometryChangedDuringGesture = false
                                    // Keep playback from fighting the user's drag/flick. If it
                                    // was playing, endSeek resumes it after movement settles.
                                    session.beginSeek()
                                }
                            }

                            // Commit position once when a native touch drag/flick ends. Calling
                            // into C++ and echoing progressChanged back into contentY on every
                            // motion frame made gestures crawl, especially on Android.
                            onMovementEnded: {
                                if (!localSeekGestureActive)
                                    return

                                const liveRange = Math.max(0, contentHeight - height)
                                const didGeometryChange = geometryChangedDuringGesture
                                if (!didGeometryChange && liveRange > 0) {
                                    session.seekTo(contentY / liveRange)
                                } else {
                                    // The range changed mid-gesture; preserve the last
                                    // authoritative progress fraction after the gesture ends.
                                    syncingFromModel = true
                                    contentY = session.progress * liveRange
                                    syncingFromModel = false
                                }
                                localSeekGestureActive = false
                                geometryChangedDuringGesture = false
                                session.endSeek()
                                if (didGeometryChange)
                                    Qt.callLater(syncScrollMetrics)
                            }

                            Column {
                                id: scriptFlow
                                width: prompterFlick.width
                                height: implicitHeight
                                spacing: 0

                                Item { width: 1; height: Math.max(80, prompterFlick.height * 0.34) }

                                TextEdit {
                                    id: renderedScript
                                    x: (scriptFlow.width - width) / 2
                                    width: Math.max(1, scriptFlow.width * session.textWidth / 100)
                                    text: session.safeMarkdown
                                    textFormat: TextEdit.MarkdownText
                                    readOnly: true
                                    activeFocusOnPress: false
                                    cursorVisible: false
                                    selectByMouse: false
                                    wrapMode: TextEdit.Wrap
                                    color: window.activePalette.text
                                    font.family: "Noto Sans Arabic"
                                    font.pointSize: session.fontSize
                                    font.weight: Font.Normal
                                    horizontalAlignment: TextEdit.AlignHCenter
                                    textMargin: 0
                                    padding: 0
                                    height: Math.max(contentHeight, 1)
                                    property string lastBidiText: ""
                                    function applyBidiForChangedText() {
                                        // Formatting a QTextDocument block can trigger textChanged
                                        // even when the text itself is unchanged. Keep the bidi
                                        // pass tied to actual content changes, not formatting events.
                                        if (lastBidiText === text)
                                            return
                                        lastBidiText = text
                                        session.applyAutoBidi(textDocument)
                                    }
                                    onTextChanged: Qt.callLater(applyBidiForChangedText)
                                    onContentHeightChanged: Qt.callLater(function() {
                                        if (!session.remoteMode)
                                            session.setScrollRange(Math.max(0, prompterFlick.contentHeight - prompterFlick.height))
                                    })
                                    onWidthChanged: Qt.callLater(function() {
                                        if (!session.remoteMode)
                                            session.setScrollRange(Math.max(0, prompterFlick.contentHeight - prompterFlick.height))
                                    })
                                }

                                Item { width: 1; height: Math.max(100, prompterFlick.height * 0.66) }
                            }

                            Connections {
                                target: session
                                function onProgressChanged() {
                                    if (prompterFlick.localSeekGestureActive)
                                        return
                                    prompterFlick.syncingFromModel = true
                                    prompterFlick.contentY = session.progress * Math.max(0, prompterFlick.contentHeight - prompterFlick.height)
                                    prompterFlick.syncingFromModel = false
                                }
                                function onScrollRangeChanged() {
                                    if (prompterFlick.localSeekGestureActive)
                                        return
                                    prompterFlick.syncingFromModel = true
                                    prompterFlick.contentY = session.progress * Math.max(0, prompterFlick.contentHeight - prompterFlick.height)
                                    prompterFlick.syncingFromModel = false
                                }
                            }

                            function syncScrollMetrics() {
                                // Defer reflow/range writes until a user's drag has completed,
                                // otherwise a font/viewport change can jump under their finger.
                                if (localSeekGestureActive) {
                                    geometryChangedDuringGesture = true
                                    return
                                }
                                // A remote never measures/overwrites the host's authoritative range.
                                if (session.remoteMode)
                                    return
                                const liveRange = Math.max(0, contentHeight - height)
                                syncingFromModel = true
                                session.setScrollRange(liveRange)
                                contentY = session.progress * liveRange
                                Qt.callLater(function() { prompterFlick.syncingFromModel = false })
                            }

                            onContentHeightChanged: {
                                if (localSeekGestureActive)
                                    geometryChangedDuringGesture = true
                                Qt.callLater(syncScrollMetrics)
                            }
                            onHeightChanged: {
                                if (localSeekGestureActive)
                                    geometryChangedDuringGesture = true
                                Qt.callLater(syncScrollMetrics)
                            }
                            Component.onCompleted: Qt.callLater(syncScrollMetrics)

                            TapHandler {
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                gesturePolicy: TapHandler.DragThreshold
                                onTapped: {
                                    if (window.visibility === Window.FullScreen && !window.editingScript)
                                        window.revealControls()
                                }
                            }

                            // Low-contrast edge fades keep attention on the reading line.
                            Rectangle {
                                anchors.top: parent.top
                                width: parent.width
                                height: Math.min(100, parent.height * 0.15)
                                z: 3
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: window.activePalette.base }
                                    GradientStop { position: 1.0; color: window.transparentColor(window.backgroundColor) }
                                }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.min(100, parent.height * 0.15)
                                z: 3
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: window.transparentColor(window.backgroundColor) }
                                    GradientStop { position: 1.0; color: window.activePalette.base }
                                }
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height * 0.46
                                width: Math.min(parent.width * 0.92, 1200)
                                height: 1
                                color: window.activePalette.overlay0
                                opacity: 0.44
                                z: 4
                            }
                        }

                        Column {
                            id: displayOverlayDock
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 6
                            z: 5
                            visible: !window.editingScript
                            opacity: window.visibility === Window.FullScreen && !window.overlayControlsVisible ? 0.16 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 180 } }

                            // Keep the faded dock hit-testable in fullscreen. The
                            // controls button itself remains available, so users never
                            // need a special gesture to recover hidden controls.
                            Button {
                                implicitWidth: 40; implicitHeight: 40; padding: 0
                                ToolTip.visible: hovered
                                ToolTip.text: window.visibility === Window.FullScreen ? "Exit fullscreen" : "Enter fullscreen"
                                onPressed: window.revealControls()
                                onClicked: window.visibility = window.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
                                background: Rectangle { radius: 12; color: window.activePalette.mantle; opacity: 0.96; border.color: window.activePalette.surface1 }
                                contentItem: Item {
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    // Qt Quick Controls styles may inset contentItem. Center a fixed-size
                                    // glyph canvas so icon coordinates stay aligned with the button face.
                                    Item {
                                        id: fullscreenGlyph
                                        width: 40
                                        height: 40
                                        anchors.centerIn: parent
                                        property color glyphColor: window.activePalette.text
                                        property bool fullscreenMode: window.visibility === Window.FullScreen

                                        // Native QML shapes work without font glyphs or Canvas on Qt 5/6.
                                        Rectangle { x: 8; y: 8; width: fullscreenGlyph.fullscreenMode ? 7 : 9; height: 2; radius: 1; color: fullscreenGlyph.glyphColor }
                                        Rectangle { x: 8; y: 8; width: 2; height: fullscreenGlyph.fullscreenMode ? 7 : 9; radius: 1; color: fullscreenGlyph.glyphColor }
                                        Rectangle { x: fullscreenGlyph.fullscreenMode ? 25 : 23; y: 8; width: fullscreenGlyph.fullscreenMode ? 7 : 9; height: 2; radius: 1; color: fullscreenGlyph.glyphColor }
                                        Rectangle { x: 30; y: 8; width: 2; height: fullscreenGlyph.fullscreenMode ? 7 : 9; radius: 1; color: fullscreenGlyph.glyphColor }
                                        Rectangle { x: 8; y: 30; width: fullscreenGlyph.fullscreenMode ? 7 : 9; height: 2; radius: 1; color: fullscreenGlyph.glyphColor }
                                        Rectangle { x: 8; y: 25; width: 2; height: fullscreenGlyph.fullscreenMode ? 7 : 9; radius: 1; color: fullscreenGlyph.glyphColor }
                                        Rectangle { x: fullscreenGlyph.fullscreenMode ? 25 : 23; y: 30; width: fullscreenGlyph.fullscreenMode ? 7 : 9; height: 2; radius: 1; color: fullscreenGlyph.glyphColor }
                                        Rectangle { x: 30; y: 25; width: 2; height: fullscreenGlyph.fullscreenMode ? 7 : 9; radius: 1; color: fullscreenGlyph.glyphColor }
                                    }
                                }
                            }
                            Button {
                                visible: window.visibility === Window.FullScreen
                                implicitWidth: 40; implicitHeight: 40; padding: 0
                                ToolTip.visible: hovered
                                ToolTip.text: window.displayControlsVisible ? "Hide controls" : "Show controls"
                                onPressed: window.revealControls()
                                onClicked: {
                                    window.displayControlsVisible = !window.displayControlsVisible
                                    window.revealControls()
                                }
                                background: Rectangle { radius: 12; color: window.activePalette.mantle; opacity: 0.96; border.color: window.activePalette.surface1 }
                                contentItem: Item {
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    // Keep the icon canvas centered even when a platform style
                                    // applies content insets to the Button.
                                    Item {
                                        id: controlsGlyph
                                        width: 40
                                        height: 40
                                        anchors.centerIn: parent
                                        property color glyphColor: window.activePalette.text
                                        property color glyphAccent: window.accentColor

                                        Rectangle { x: 9; y: 11; width: 22; height: 2; radius: 1; color: controlsGlyph.glyphColor }
                                        Rectangle { x: 9; y: 19; width: 22; height: 2; radius: 1; color: controlsGlyph.glyphColor }
                                        Rectangle { x: 9; y: 27; width: 22; height: 2; radius: 1; color: controlsGlyph.glyphColor }
                                        Rectangle { x: 15; y: 8; width: 5; height: 8; radius: 2; color: controlsGlyph.glyphAccent }
                                        Rectangle { x: 23; y: 16; width: 5; height: 8; radius: 2; color: controlsGlyph.glyphAccent }
                                        Rectangle { x: 12; y: 24; width: 5; height: 8; radius: 2; color: controlsGlyph.glyphAccent }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: editorPage
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12
                            Label { text: "Script editor"; font.pixelSize: 22; font.bold: true }
                            Label { text: "Markdown • Arabic + English • stored locally"; color: window.activePalette.subtext0 }
                            ScrollView {
                                id: scriptEditorScroll
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                TextArea {
                                    id: scriptEditor
                                    property bool syncingDraft: false
                                    width: scriptEditorScroll.availableWidth
                                    text: session.draftScript
                                    placeholderText: "Write your Markdown script here…"
                                    wrapMode: TextEdit.Wrap
                                    font.family: "monospace"
                                    font.pixelSize: 16
                                    selectByMouse: true
                                    persistentSelection: true
                                    onTextChanged: {
                                        if (!syncingDraft)
                                            session.setDraftScript(text)
                                    }
                                    Connections {
                                        target: session
                                        function onDraftScriptChanged() {
                                            // Never replace active user input. Update only when
                                            // a new authoritative draft arrives while unfocused.
                                            if (!scriptEditor.activeFocus && scriptEditor.text !== session.draftScript) {
                                                scriptEditor.syncingDraft = true
                                                scriptEditor.text = session.draftScript
                                                scriptEditor.syncingDraft = false
                                            }
                                        }
                                    }
                                    background: Rectangle { color: window.activePalette.mantle; radius: 10; border.color: window.activePalette.surface1 }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Button {
                                    text: "Clear"
                                    onClicked: {
                                        scriptEditor.text = ""
                                        scriptEditor.forceActiveFocus()
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Button { text: "Back to reading"; onClicked: { window.editingScript = false; window.revealControls() } }
                                Button {
                                    text: "Apply script"
                                    highlighted: true
                                    onClicked: {
                                        session.setScript(session.draftScript)
                                        window.editingScript = false
                                        window.revealControls()
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: window.activePalette.surface1
                    visible: !window.editingScript && (window.visibility !== Window.FullScreen || window.displayControlsVisible)
                }
                ColumnLayout {
                    visible: !window.editingScript && (window.visibility !== Window.FullScreen || window.displayControlsVisible)
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.topMargin: 5
                    Layout.bottomMargin: 5
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: session.playing ? "Pause" : "Play"
                            highlighted: true
                            onClicked: session.togglePlayback()
                        }
                        Button { text: "Reset"; onClicked: session.resetPlayback() }
                        Button {
                            text: session.hosting ? "Stop remote" : "Enable remote"
                            onClicked: session.hosting ? session.stopHosting() : session.startHosting()
                        }
                        Item { Layout.fillWidth: true }
                        Label { text: Math.round(session.progress * 1000) / 10 + "%"; color: window.activePalette.subtext1; font.pixelSize: 12 }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Position"; Layout.preferredWidth: 65; color: window.activePalette.subtext1 }
                        Slider {
                            id: displaySeek
                            Layout.fillWidth: true
                            from: 0; to: 1; stepSize: 0.0001
                            Binding { target: displaySeek; property: "value"; value: session.progress; when: !displaySeek.pressed }
                            onPressedChanged: pressed ? session.beginSeek() : session.endSeek()
                            onMoved: session.seekTo(value)
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: function(event) {
                                    const direction = window.wheelDirection(event)
                                    if (direction !== 0) {
                                        session.beginSeek()
                                        session.seekTo(Math.max(0, Math.min(1, session.progress + direction * 0.01)))
                                        session.endSeek()
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                    }
                    GridLayout {
                        id: displayTuningControls
                        Layout.fillWidth: true
                        columns: window.width >= 760 ? 3 : 1
                        columnSpacing: 14
                        rowSpacing: 4

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { text: "Speed · " + Math.round(session.speed) + " px/s"; color: window.activePalette.subtext1; font.pixelSize: 12 }
                            Slider {
                                id: displaySpeed
                                Layout.fillWidth: true
                                from: 0; to: 600; stepSize: 1
                                Binding { target: displaySpeed; property: "value"; value: session.speed; when: !displaySpeed.pressed }
                                onMoved: session.setSpeed(value)
                                WheelHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: function(event) {
                                        const direction = window.wheelDirection(event)
                                        if (direction !== 0) {
                                            session.setSpeed(Math.max(0, Math.min(600, session.speed + direction * 10)))
                                            event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { text: "Font · " + session.fontSize + " pt"; color: window.activePalette.subtext1; font.pixelSize: 12 }
                            Slider {
                                id: displayFontSize
                                Layout.fillWidth: true
                                from: 12; to: 100; stepSize: 1
                                Binding { target: displayFontSize; property: "value"; value: session.fontSize; when: !displayFontSize.pressed }
                                onMoved: session.setFontSize(value)
                                WheelHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: function(event) {
                                        const direction = window.wheelDirection(event)
                                        if (direction !== 0) {
                                            session.setFontSize(Math.max(12, Math.min(100, session.fontSize + direction)))
                                            event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label { text: "Text width · " + session.textWidth + "%"; color: window.activePalette.subtext1; font.pixelSize: 12 }
                            Slider {
                                id: displayWidth
                                Layout.fillWidth: true
                                from: 35; to: 100; stepSize: 1
                                Binding { target: displayWidth; property: "value"; value: session.textWidth; when: !displayWidth.pressed }
                                onMoved: session.setTextWidth(value)
                                WheelHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: function(event) {
                                        const direction = window.wheelDirection(event)
                                        if (direction !== 0) {
                                            session.setTextWidth(Math.max(35, Math.min(100, session.textWidth + direction)))
                                            event.accepted = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: session.hosting
                        radius: 8
                        color: window.activePalette.mantle
                        border.color: window.activePalette.surface2
                        implicitHeight: hostInfo.implicitHeight + 18
                        ColumnLayout {
                            id: hostInfo
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 3
                            Label { text: "Pair from another device"; font.bold: true; color: window.activePalette.text }
                            Label { text: "Address: " + session.localAddresses.join("  ·  "); wrapMode: Text.Wrap; color: window.activePalette.subtext1 }
                            Label { text: "Port: " + session.port + "     PIN: " + session.pin; color: window.activePalette.subtext1 }
                        }
                    }
                    Label { text: session.status; color: window.activePalette.subtext0; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap }
                }
            }
        }

        // REMOTE MODE -------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: session.remoteMode

            Flickable {
                id: remoteFlick
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: remoteContent.implicitHeight + 44
                boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: remoteContent
                x: 22
                y: 22
                width: Math.max(1, remoteFlick.width - 44)
                spacing: 16

                Label { text: "Remote control"; font.pixelSize: 26; font.bold: true }
                Label {
                    text: "Connect directly to the device showing your script. No cloud account or separate server."
                    color: window.activePalette.subtext1
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !session.connected
                    TextField {
                        id: hostField
                        Layout.fillWidth: true
                        placeholderText: "Display device LAN address (e.g. 192.168.1.25)"
                        text: session.hostAddress
                        onTextEdited: session.setHostAddress(text)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: pinField
                            Layout.fillWidth: true
                            Layout.maximumWidth: 220
                            placeholderText: "4-digit PIN"
                            maximumLength: 4
                            inputMethodHints: Qt.ImhDigitsOnly
                        }
                        Button {
                            text: "Connect"
                            highlighted: true
                            onClicked: session.connectToHost(hostField.text, pinField.text)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: window.activePalette.mantle
                    border.color: window.activePalette.surface1
                    visible: session.connected
                    implicitHeight: remoteControls.implicitHeight + 20
                    ColumnLayout {
                        id: remoteControls
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Button { text: "− 20 px"; onClicked: session.nudgePixels(-20); onPressAndHold: session.nudgePixels(-60) }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: session.playing ? "Pause" : "Play"
                                highlighted: true
                                onClicked: session.togglePlayback()
                            }
                            Item { Layout.fillWidth: true }
                            Button { text: "+ 20 px"; onClicked: session.nudgePixels(20); onPressAndHold: session.nudgePixels(60) }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Button {
                                Layout.fillWidth: true
                                text: session.viewerFullscreen ? "Exit display fullscreen" : "Fullscreen display"
                                font.pixelSize: 12
                                onClicked: session.requestViewerFullscreenToggle()
                            }
                            Button {
                                Layout.fillWidth: true
                                text: session.viewerControlsVisible ? "Hide display controls" : "Show display controls"
                                font.pixelSize: 12
                                onClicked: session.requestViewerControlsToggle()
                            }
                        }
                        Label { text: "Live position · " + Math.round(session.progress * 1000) / 10 + "%"; color: window.activePalette.subtext1 }
                        Slider {
                            id: remoteSeek
                            Layout.fillWidth: true
                            from: 0; to: 1; stepSize: 0.0001
                            Binding { target: remoteSeek; property: "value"; value: session.progress; when: !remoteSeek.pressed }
                            onPressedChanged: pressed ? session.beginSeek() : session.endSeek()
                            onMoved: session.seekTo(value)
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: function(event) {
                                    const direction = window.wheelDirection(event)
                                    if (direction !== 0) {
                                        session.beginSeek()
                                        session.seekTo(Math.max(0, Math.min(1, session.progress + direction * 0.01)))
                                        session.endSeek()
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                        Label { text: "Speed · " + Math.round(session.speed) + " px/s"; color: window.activePalette.subtext1 }
                        Slider {
                            id: remoteSpeed
                            Layout.fillWidth: true
                            from: 0; to: 600; stepSize: 1
                            Binding { target: remoteSpeed; property: "value"; value: session.speed; when: !remoteSpeed.pressed }
                            onMoved: session.setSpeed(value)
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: function(event) {
                                    const direction = window.wheelDirection(event)
                                    if (direction !== 0) {
                                        session.setSpeed(Math.max(0, Math.min(600, session.speed + direction * 10)))
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                        Label { text: "Font · " + session.fontSize + " pt"; color: window.activePalette.subtext1 }
                        Slider {
                            id: remoteFontSize
                            Layout.fillWidth: true
                            from: 12; to: 100; stepSize: 1
                            Binding { target: remoteFontSize; property: "value"; value: session.fontSize; when: !remoteFontSize.pressed }
                            onMoved: session.setFontSize(value)
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: function(event) {
                                    const direction = window.wheelDirection(event)
                                    if (direction !== 0) {
                                        session.setFontSize(Math.max(12, Math.min(100, session.fontSize + direction)))
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                        Label { text: "Text width · " + session.textWidth + "%"; color: window.activePalette.subtext1 }
                        Slider {
                            id: remoteWidth
                            Layout.fillWidth: true
                            from: 35; to: 100; stepSize: 1
                            Binding { target: remoteWidth; property: "value"; value: session.textWidth; when: !remoteWidth.pressed }
                            onMoved: session.setTextWidth(value)
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: function(event) {
                                    const direction = window.wheelDirection(event)
                                    if (direction !== 0) {
                                        session.setTextWidth(Math.max(35, Math.min(100, session.textWidth + direction)))
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                        Button { text: "Reset to beginning"; onClicked: session.resetPlayback() }
                    }
                }

                Frame {
                    id: remoteEditorFrame
                    Layout.fillWidth: true
                    visible: true
                    background: Rectangle { color: window.activePalette.mantle; radius: 10; border.color: window.activePalette.surface1 }
                    ColumnLayout {
                        anchors.fill: parent
                        Label { text: "Edit or send a script"; font.bold: true }
                        ScrollView {
                            id: remoteScriptEditorScroll
                            Layout.fillWidth: true
                            Layout.preferredHeight: 190
                            clip: true
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            TextArea {
                                id: remoteScriptEditor
                                property bool syncingDraft: false
                                width: remoteScriptEditorScroll.availableWidth
                                text: session.draftScript
                                wrapMode: TextEdit.Wrap
                                placeholderText: "Paste Markdown here…"
                                selectByMouse: true
                                persistentSelection: true
                                onTextChanged: {
                                    if (!syncingDraft)
                                        session.setDraftScript(text)
                                }
                                Connections {
                                    target: session
                                    function onDraftScriptChanged() {
                                        if (!remoteScriptEditor.activeFocus && remoteScriptEditor.text !== session.draftScript) {
                                            remoteScriptEditor.syncingDraft = true
                                            remoteScriptEditor.text = session.draftScript
                                            remoteScriptEditor.syncingDraft = false
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Button {
                                text: "Clear"
                                onClicked: {
                                    remoteScriptEditor.text = ""
                                    remoteScriptEditor.forceActiveFocus()
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "Send script to display"
                                enabled: session.connected
                                highlighted: true
                                onClicked: session.sendDraftScript()
                            }
                        }
                    }
                }

                Item { implicitHeight: 4 }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: session.status; color: window.activePalette.subtext0; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    Button { text: "Disconnect"; enabled: session.connected; onClicked: session.disconnectSession() }
                }
            }
            }
        }
    }

    Connections {
        target: session
        function onViewerFullscreenToggleRequested() {
            window.visibility = window.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
        }
        function onViewerControlsToggleRequested() {
            window.displayControlsVisible = !window.displayControlsVisible
            window.revealControls()
        }
    }

    Dialog {
        id: appearanceDialog
        title: "Appearance"
        modal: true
        focus: true
        width: Math.max(270, Math.min(window.width - 28, 420))
        anchors.centerIn: parent
        standardButtons: Dialog.Close
        background: Rectangle {
            radius: 16
            color: window.activePalette.mantle
            border.color: window.activePalette.surface1
        }

        contentItem: ColumnLayout {
            spacing: 12

            Label {
                text: "Catppuccin flavor"
                color: window.activePalette.text
                font.bold: true
            }
            ComboBox {
                id: flavorPicker
                Layout.fillWidth: true
                model: window.flavorNames
                currentIndex: Math.max(0, window.flavorNames.indexOf(session.themeFlavor))
                onActivated: session.setThemeFlavor(currentText)
            }
            Label {
                text: "Accent color"
                color: window.activePalette.text
                font.bold: true
            }
            ComboBox {
                id: accentPicker
                Layout.fillWidth: true
                model: window.accentNames
                currentIndex: Math.max(0, window.accentNames.indexOf(session.themeAccent))
                onActivated: session.setThemeAccent(currentText)
                delegate: ItemDelegate {
                    required property var modelData
                    width: accentPicker.width
                    highlighted: accentPicker.highlightedIndex === index
                    contentItem: RowLayout {
                        spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 9
                            color: window.colorForName(modelData)
                            border.color: window.activePalette.overlay0
                        }
                        Label {
                            text: modelData
                            color: window.activePalette.text
                            Layout.fillWidth: true
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: session.themeFlavor + " · " + session.themeAccent
                    color: window.activePalette.subtext1
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 8
                    color: window.accentColor
                    border.color: window.accentTextColor
                }
            }
            Label {
                text: "Changes are saved on this device."
                color: window.activePalette.subtext0
                font.pixelSize: 12
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
        }
    }

    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: !session.remoteMode && !window.editingScript; onActivated: session.togglePlayback() }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: session.resetPlayback() }

    Component.onCompleted: window.revealControls()
    Shortcut { sequence: "Left"; context: Qt.ApplicationShortcut; enabled: !window.editingScript; onActivated: session.nudgePixels(-20) }
    Shortcut { sequence: "Right"; context: Qt.ApplicationShortcut; enabled: !window.editingScript; onActivated: session.nudgePixels(20) }
}
