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
    property bool controlsVisible: true

    palette.window: "#111318"
    palette.windowText: "#f1f1f5"
    palette.base: "#1a1d24"
    palette.alternateBase: "#242834"
    palette.text: "#f1f1f5"
    palette.button: "#242834"
    palette.buttonText: "#f1f1f5"
    palette.highlight: "#b4a1e8"
    palette.highlightedText: "#111318"

    header: ToolBar {
        visible: window.visibility !== Window.FullScreen
        contentHeight: 58
        background: Rectangle { color: "#191c23" }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 14
            Label {
                text: "CueFlow"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: "#f1f1f5"
            }
            Label {
                text: "NATIVE TELEPROMPTER"
                font.pixelSize: 10
                font.letterSpacing: 1.7
                color: "#9ba0ad"
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                radius: 12
                color: session.connected ? "#214536" : session.hosting ? "#44365c" : "#292d36"
                implicitHeight: 30
                implicitWidth: statusLabel.implicitWidth + 24
                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: session.connected ? "REMOTE CONNECTED" : session.hosting ? "SESSION OPEN" : "LOCAL MODE"
                    color: "#f1f1f5"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
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
            background: Rectangle { color: "#191c23" }
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
                            property bool syncingFromModel: false

                            onContentYChanged: {
                                if (!syncingFromModel && session.scrollRange > 0)
                                    session.seekTo(contentY / session.scrollRange)
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
                                    selectByMouse: false
                                    wrapMode: TextEdit.Wrap
                                    color: "#f4f2f8"
                                    font.family: "Noto Sans Arabic"
                                    font.pointSize: session.fontSize
                                    font.weight: Font.Normal
                                    horizontalAlignment: TextEdit.AlignHCenter
                                    textMargin: 0
                                    padding: 0
                                    height: Math.max(contentHeight, 1)
                                    onTextChanged: Qt.callLater(function() { session.applyAutoBidi(textDocument) })
                                    onContentHeightChanged: Qt.callLater(function() {
                                        session.setScrollRange(Math.max(0, prompterFlick.contentHeight - prompterFlick.height))
                                    })
                                    onWidthChanged: Qt.callLater(function() {
                                        session.setScrollRange(Math.max(0, prompterFlick.contentHeight - prompterFlick.height))
                                    })
                                }

                                Item { width: 1; height: Math.max(100, prompterFlick.height * 0.66) }
                            }

                            Connections {
                                target: session
                                function onProgressChanged() {
                                    prompterFlick.syncingFromModel = true
                                    prompterFlick.contentY = session.progress * Math.max(0, prompterFlick.contentHeight - prompterFlick.height)
                                    prompterFlick.syncingFromModel = false
                                }
                                function onScrollRangeChanged() {
                                    prompterFlick.syncingFromModel = true
                                    prompterFlick.contentY = session.progress * Math.max(0, prompterFlick.contentHeight - prompterFlick.height)
                                    prompterFlick.syncingFromModel = false
                                }
                            }

                            Component.onCompleted: Qt.callLater(function() {
                                session.setScrollRange(Math.max(0, contentHeight - height))
                                contentY = session.progress * Math.max(0, contentHeight - height)
                            })

                            // Low-contrast edge fades keep attention on the reading line.
                            Rectangle {
                                anchors.top: parent.top
                                width: parent.width
                                height: Math.min(100, parent.height * 0.15)
                                z: 3
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#111318" }
                                    GradientStop { position: 1.0; color: "#00111318" }
                                }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.min(100, parent.height * 0.15)
                                z: 3
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#00111318" }
                                    GradientStop { position: 1.0; color: "#111318" }
                                }
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height * 0.46
                                width: Math.min(parent.width * 0.92, 1200)
                                height: 1
                                color: "#5b536e"
                                opacity: 0.44
                                z: 4
                            }
                        }

                        Column {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 8
                            z: 5
                            Button {
                                text: window.visibility === Window.FullScreen ? "Exit fullscreen" : "Fullscreen"
                                onClicked: window.visibility = window.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
                            }
                            Button {
                                visible: window.visibility !== Window.FullScreen
                                text: window.editingScript ? "Display script" : "Edit Markdown"
                                onClicked: {
                                    if (!window.editingScript)
                                        session.setDraftScript(session.script)
                                    window.editingScript = !window.editingScript
                                }
                            }
                            Button {
                                text: window.controlsVisible ? "Hide controls" : "Show controls"
                                onClicked: window.controlsVisible = !window.controlsVisible
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
                            Label { text: "Markdown • Arabic + English • stored locally"; color: "#9ba0ad" }
                            TextArea {
                                id: scriptEditor
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Binding { target: scriptEditor; property: "text"; value: session.draftScript; when: !scriptEditor.activeFocus }
                                placeholderText: "Write your Markdown script here…"
                                wrapMode: TextEdit.Wrap
                                font.family: "monospace"
                                font.pixelSize: 16
                                onTextChanged: session.setDraftScript(text)
                                background: Rectangle { color: "#191c23"; radius: 10; border.color: "#353a47" }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                Button { text: "Cancel"; onClicked: window.editingScript = false }
                                Button {
                                    text: "Apply script"
                                    highlighted: true
                                    onClicked: {
                                        session.setScript(session.draftScript)
                                        window.editingScript = false
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#303440"; visible: window.controlsVisible }
                ColumnLayout {
                    visible: window.controlsVisible
                    Layout.fillWidth: true
                    Layout.leftMargin: 18
                    Layout.rightMargin: 18
                    Layout.topMargin: 10
                    Layout.bottomMargin: 12
                    spacing: 8

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
                        Label { text: Math.round(session.progress * 1000) / 10 + "%"; color: "#b9b2ca"; font.pixelSize: 12 }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Position"; Layout.preferredWidth: 65; color: "#b9bdc8" }
                        Slider {
                            id: displaySeek
                            Layout.fillWidth: true
                            from: 0; to: 1; stepSize: 0.0001
                            Binding { target: displaySeek; property: "value"; value: session.progress; when: !displaySeek.pressed }
                            onPressedChanged: pressed ? session.beginSeek() : session.endSeek()
                            onMoved: session.seekTo(value)
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 7
                        Label { text: "Speed · " + Math.round(session.speed) + " px/s"; color: "#b9bdc8" }
                        Slider {
                            id: displaySpeed
                            Layout.fillWidth: true
                            from: 0; to: 600; stepSize: 1
                            Binding { target: displaySpeed; property: "value"; value: session.speed; when: !displaySpeed.pressed }
                            onMoved: session.setSpeed(value)
                        }
                        Label { text: "Font · " + session.fontSize + " pt"; color: "#b9bdc8" }
                        Slider {
                            id: displayFontSize
                            Layout.fillWidth: true
                            from: 12; to: 100; stepSize: 1
                            Binding { target: displayFontSize; property: "value"; value: session.fontSize; when: !displayFontSize.pressed }
                            onMoved: session.setFontSize(value)
                        }
                        Label { text: "Text width · " + session.textWidth + "%"; color: "#b9bdc8" }
                        Slider {
                            id: displayWidth
                            Layout.fillWidth: true
                            from: 35; to: 100; stepSize: 1
                            Binding { target: displayWidth; property: "value"; value: session.textWidth; when: !displayWidth.pressed }
                            onMoved: session.setTextWidth(value)
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: session.hosting
                        radius: 8
                        color: "#211d2a"
                        border.color: "#4a405d"
                        implicitHeight: hostInfo.implicitHeight + 18
                        ColumnLayout {
                            id: hostInfo
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 3
                            Label { text: "Pair from another device"; font.bold: true; color: "#e3daf8" }
                            Label { text: "Address: " + session.localAddresses.join("  ·  "); wrapMode: Text.Wrap; color: "#c7c0d6" }
                            Label { text: "Port: " + session.port + "     PIN: " + session.pin; color: "#c7c0d6" }
                        }
                    }
                    Label { text: session.status; color: "#969baa"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap }
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
                    color: "#a7acb9"
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
                            placeholderText: "6-digit PIN"
                            maximumLength: 6
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
                    color: "#191c23"
                    border.color: "#303440"
                    visible: session.connected
                    implicitHeight: remoteControls.implicitHeight + 36
                    ColumnLayout {
                        id: remoteControls
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 16
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
                        Label { text: "Live position · " + Math.round(session.progress * 1000) / 10 + "%"; color: "#c9c3d8" }
                        Slider {
                            id: remoteSeek
                            Layout.fillWidth: true
                            from: 0; to: 1; stepSize: 0.0001
                            Binding { target: remoteSeek; property: "value"; value: session.progress; when: !remoteSeek.pressed }
                            onPressedChanged: pressed ? session.beginSeek() : session.endSeek()
                            onMoved: session.seekTo(value)
                        }
                        Label { text: "Speed · " + Math.round(session.speed) + " px/s"; color: "#c9c3d8" }
                        Slider {
                            id: remoteSpeed
                            Layout.fillWidth: true
                            from: 0; to: 600; stepSize: 1
                            Binding { target: remoteSpeed; property: "value"; value: session.speed; when: !remoteSpeed.pressed }
                            onMoved: session.setSpeed(value)
                        }
                        Label { text: "Font · " + session.fontSize + " pt"; color: "#c9c3d8" }
                        Slider {
                            id: remoteFontSize
                            Layout.fillWidth: true
                            from: 12; to: 100; stepSize: 1
                            Binding { target: remoteFontSize; property: "value"; value: session.fontSize; when: !remoteFontSize.pressed }
                            onMoved: session.setFontSize(value)
                        }
                        Label { text: "Text width · " + session.textWidth + "%"; color: "#c9c3d8" }
                        Slider {
                            id: remoteWidth
                            Layout.fillWidth: true
                            from: 35; to: 100; stepSize: 1
                            Binding { target: remoteWidth; property: "value"; value: session.textWidth; when: !remoteWidth.pressed }
                            onMoved: session.setTextWidth(value)
                        }
                        Button { text: "Reset to beginning"; onClicked: session.resetPlayback() }
                    }
                }

                Frame {
                    Layout.fillWidth: true
                    visible: true
                    background: Rectangle { color: "#191c23"; radius: 10; border.color: "#303440" }
                    ColumnLayout {
                        anchors.fill: parent
                        Label { text: "Send a new script"; font.bold: true }
                        TextArea {
                            id: remoteScriptEditor
                            Layout.fillWidth: true
                            Layout.preferredHeight: 170
                            Binding { target: remoteScriptEditor; property: "text"; value: session.draftScript; when: !remoteScriptEditor.activeFocus }
                            wrapMode: TextEdit.Wrap
                            placeholderText: "Paste Markdown here…"
                            onTextChanged: session.setDraftScript(text)
                        }
                        RowLayout {
                            Layout.fillWidth: true
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
                    Label { text: session.status; color: "#969baa"; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    Button { text: "Disconnect"; enabled: session.connected; onClicked: session.disconnectSession() }
                }
            }
            }
        }
    }

    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: !session.remoteMode && !window.editingScript; onActivated: session.togglePlayback() }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: session.resetPlayback() }
    Shortcut { sequence: "Left"; context: Qt.ApplicationShortcut; enabled: !window.editingScript; onActivated: session.nudgePixels(-20) }
    Shortcut { sequence: "Right"; context: Qt.ApplicationShortcut; enabled: !window.editingScript; onActivated: session.nudgePixels(20) }
}
