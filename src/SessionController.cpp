#include "SessionController.h"

#include <QJsonDocument>
#include <QJsonParseError>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSettings>
#include <QTextBlock>
#include <QTextBlockFormat>
#include <QTextCursor>
#include <QTextDocument>
#include <QQuickTextDocument>
#include <QStringList>

#include <algorithm>
#include <cmath>

namespace {

const QStringList &themeFlavorNames() {
    static const QStringList values = {
        QStringLiteral("Latte"), QString::fromUtf8("Frappé"),
        QStringLiteral("Macchiato"), QStringLiteral("Mocha")
    };
    return values;
}

const QStringList &themeAccentNames() {
    static const QStringList values = {
        QStringLiteral("Rosewater"), QStringLiteral("Flamingo"),
        QStringLiteral("Pink"), QStringLiteral("Mauve"),
        QStringLiteral("Red"), QStringLiteral("Maroon"),
        QStringLiteral("Peach"), QStringLiteral("Yellow"),
        QStringLiteral("Green"), QStringLiteral("Teal"),
        QStringLiteral("Sky"), QStringLiteral("Sapphire"),
        QStringLiteral("Blue"), QStringLiteral("Lavender"),
        QStringLiteral("Text"), QStringLiteral("Subtext 1"),
        QStringLiteral("Subtext 0"), QStringLiteral("Overlay 2"),
        QStringLiteral("Overlay 1"), QStringLiteral("Overlay 0"),
        QStringLiteral("Surface 2"), QStringLiteral("Surface 1"),
        QStringLiteral("Surface 0"), QStringLiteral("Base"),
        QStringLiteral("Mantle"), QStringLiteral("Crust")
    };
    return values;
}

QString canonicalChoice(const QString &value, const QStringList &choices) {
    const QString cleaned = value.trimmed();
    for (const QString &choice : choices) {
        if (choice.compare(cleaned, Qt::CaseInsensitive) == 0)
            return choice;
    }
    return {};
}

} // namespace

SessionController::SessionController(QObject *parent)
    : QObject(parent), model_(ScrollModel::kDefaultSpeedPixelsPerSecond) {
    loadSettings();
    refreshAddresses();

    frameTimer_.setInterval(16);
    frameTimer_.setTimerType(Qt::PreciseTimer);
    connect(&frameTimer_, &QTimer::timeout, this, &SessionController::onFrame);
    connect(&server_, &QTcpServer::newConnection, this, &SessionController::acceptConnections);
    settingsSaveTimer_.setSingleShot(true);
    settingsSaveTimer_.setInterval(400);
    connect(&settingsSaveTimer_, &QTimer::timeout, this, &SessionController::saveSettings);
    frameClock_.start();
    broadcastClock_.start();
    // The frame timer is demand-driven: it runs during display playback or
    // briefly to flush dirty state, rather than waking idle phones/desktops 60x/s.
}

SessionController::~SessionController() {
    settingsSaveTimer_.stop();
    saveSettings();
    stopHosting();
    disconnectSession();
}

QString SessionController::safeMarkdown() const {
    return sanitizeMarkdown(script_);
}

QString SessionController::sanitizeMarkdown(const QString &markdown) const {
    QString safe = markdown;
    // Native Markdown rendering must not unexpectedly fetch remote images from a script.
    // Retain each image's alt text while discarding the network resource reference.
    safe.replace(QRegularExpression(QString::fromLatin1(R"(!\[([^\]]*)\]\([^)]*\))")), QStringLiteral("\\1"));
    safe.remove(QRegularExpression(QString::fromLatin1(R"(<\s*img\b[^>]*>)"), QRegularExpression::CaseInsensitiveOption));
    safe.remove(QRegularExpression(QString::fromLatin1(R"(<\s*/?\s*(script|iframe|object|embed|video|audio|style)\b[^>]*>)"), QRegularExpression::CaseInsensitiveOption));
    return safe;
}

void SessionController::loadSettings() {
    QSettings settings(QStringLiteral("mmBesar"), QStringLiteral("CueFlow"));
    script_ = settings.value(QStringLiteral("script"), QString::fromUtf8(
        "# أهلاً بك في CueFlow\n\n"
        "هذا مثال لقراءة نص عربي مع **English terms** وأسماء البرامج مثل `Qt 6` و`Linux`.\n\n"
        "## أثناء التسجيل\n\n"
        "- ابدأ القراءة بسرعة مريحة.\n"
        "- استخدم جهازاً آخر للتحكم في السرعة والموضع.\n\n"
        "The same app can be the display or the remote. النص العربي والإنجليزي يجب أن يظهرا بالترتيب الصحيح."
    )).toString();
    draftScript_ = script_;
    model_.setSpeed(settings.value(QStringLiteral("speed"), ScrollModel::kDefaultSpeedPixelsPerSecond).toDouble());
    fontSize_ = std::clamp(settings.value(QStringLiteral("fontSize"), 44).toInt(), 12, 120);
    textWidth_ = std::clamp(settings.value(QStringLiteral("textWidth"), 88).toInt(), 35, 100);
    themeFlavor_ = canonicalChoice(settings.value(QStringLiteral("themeFlavor"), QStringLiteral("Macchiato")).toString(), themeFlavorNames());
    if (themeFlavor_.isEmpty()) themeFlavor_ = QStringLiteral("Macchiato");
    themeAccent_ = canonicalChoice(settings.value(QStringLiteral("themeAccent"), QStringLiteral("Mauve")).toString(), themeAccentNames());
    if (themeAccent_.isEmpty()) themeAccent_ = QStringLiteral("Mauve");
    // Intentionally start at the beginning each time; script and reading preferences persist.
    model_.setProgress(0.0);
    model_.setPlaying(false);
}

void SessionController::saveSettings() {
    QSettings settings(QStringLiteral("mmBesar"), QStringLiteral("CueFlow"));
    settings.setValue(QStringLiteral("script"), script_);
    settings.setValue(QStringLiteral("speed"), model_.speed());
    settings.setValue(QStringLiteral("fontSize"), fontSize_);
    settings.setValue(QStringLiteral("textWidth"), textWidth_);
    settings.setValue(QStringLiteral("themeFlavor"), themeFlavor_);
    settings.setValue(QStringLiteral("themeAccent"), themeAccent_);
    settings.sync();
}

void SessionController::setMode(const QString &mode) {
    const bool useRemote = (mode.compare(QStringLiteral("remote"), Qt::CaseInsensitive) == 0);
    if (remoteMode_ == useRemote)
        return;

    stopHosting();
    disconnectSession();
    if (model_.playing()) {
        model_.setPlaying(false);
        emit playingChanged();
    }
    remoteMode_ = useRemote;
    frameTimer_.stop();
    dirty_ = false;
    dirtyScript_ = false;
    emit remoteModeChanged();
    setStatus(useRemote ? QStringLiteral("Enter the display device's LAN address and pairing PIN")
                        : QStringLiteral("Display mode — start a remote session when needed"));
}

void SessionController::startHosting() {
    if (remoteMode_) {
        setStatus(QStringLiteral("Switch to Display mode before hosting"));
        return;
    }
    if (server_.isListening())
        return;

    // Generate one short LAN pairing PIN for this hosting session. It stays
    // stable across reconnects and failed attempts, and rotates only when the
    // user stops and starts hosting again.
    failedPairingAttempts_ = 0;
    pairingLockoutClock_.invalidate();
    pin_ = QString::number(QRandomGenerator::global()->bounded(1000, 10000));
    emit pinChanged();
    if (!server_.listen(QHostAddress::AnyIPv4, kPort)) {
        setStatus(QStringLiteral("Could not listen on port %1: %2").arg(kPort).arg(server_.errorString()));
        pin_.clear();
        emit pinChanged();
        return;
    }
    refreshAddresses();
    emit hostingChanged();
    setStatus(QStringLiteral("Remote session active on port %1; use a listed LAN address and the PIN").arg(kPort));
}

void SessionController::stopHosting() {
    if (server_.isListening()) {
        server_.close();
        if (hostPeer_)
            closeSocket(hostPeer_);
        emit hostingChanged();
        setStatus(QStringLiteral("Remote session stopped"));
    }
    failedPairingAttempts_ = 0;
    pairingLockoutClock_.invalidate();
    if (!pin_.isEmpty()) {
        pin_.clear();
        emit pinChanged();
    }
}

void SessionController::connectToHost(const QString &address, const QString &pin) {
    if (!remoteMode_) {
        setStatus(QStringLiteral("Switch to Remote mode before connecting"));
        return;
    }
    const QString cleanAddress = address.trimmed();
    const QString cleanPin = pin.trimmed();
    if (cleanAddress.isEmpty() || cleanPin.size() != 4) {
        setStatus(QStringLiteral("Enter a host address and the four-digit pairing PIN"));
        return;
    }

    disconnectSession();
    hostAddress_ = cleanAddress;
    emit hostAddressChanged();
    clientSocket_ = new QTcpSocket(this);
    connect(clientSocket_, &QTcpSocket::connected, this, [this, cleanPin]() {
        QJsonObject hello;
        hello.insert(QStringLiteral("type"), QStringLiteral("hello"));
        hello.insert(QStringLiteral("pin"), cleanPin);
        writeJson(clientSocket_, hello);
        setStatus(QStringLiteral("Connected to host; verifying pairing PIN…"));
    });
    connect(clientSocket_, &QTcpSocket::readyRead, this, [this]() { readSocket(clientSocket_); });
    connect(clientSocket_, &QTcpSocket::disconnected, this, [this]() {
        if (clientSocket_) {
            readBuffers_.remove(clientSocket_);
            clientSocket_->deleteLater();
            clientSocket_ = nullptr;
        }
        setConnected(false);
        if (remoteMode_ && model_.playing()) {
            model_.setPlaying(false);
            emit playingChanged();
        }
        setStatus(QStringLiteral("Disconnected from display"));
    });
    connect(clientSocket_, &QTcpSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) {
        if (clientSocket_)
            setStatus(QStringLiteral("Connection failed: %1").arg(clientSocket_->errorString()));
    });
    clientSocket_->connectToHost(cleanAddress, kPort);
    setStatus(QStringLiteral("Connecting to %1:%2…").arg(cleanAddress).arg(kPort));
}

void SessionController::disconnectSession() {
    if (clientSocket_) {
        QTcpSocket *socket = clientSocket_;
        clientSocket_ = nullptr;
        readBuffers_.remove(socket);
        socket->disconnect(this);
        socket->abort();
        socket->deleteLater();
    }
    if (hostPeer_)
        closeSocket(hostPeer_);
    setConnected(false);
    if (remoteMode_ && model_.playing()) {
        model_.setPlaying(false);
        emit playingChanged();
    }
}

void SessionController::togglePlayback() {
    if (remoteMode_) {
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("toggle"));
        sendCommand(command);
        return;
    }
    setPlayingLocal(!model_.playing());
}

void SessionController::resetPlayback() {
    if (remoteMode_) {
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("reset"));
        sendCommand(command);
        return;
    }
    model_.reset();
    emit progressChanged();
    emit playingChanged();
    markDirty();
}

void SessionController::beginSeek() {
    if (scrubbing_)
        return;
    scrubbing_ = true;
    resumeAfterSeek_ = model_.playing();
    if (remoteMode_) {
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("begin_seek"));
        sendCommand(command);
    } else {
        setPlayingLocal(false);
    }
}

void SessionController::seekTo(double normalizedProgress) {
    const double before = model_.progress();
    model_.setProgress(normalizedProgress);
    if (model_.progress() != before)
        emit progressChanged();

    if (remoteMode_) {
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("seek"));
        command.insert(QStringLiteral("value"), model_.progress());
        sendCommand(command);
    } else if (model_.progress() != before) {
        markDirty();
    }
}

void SessionController::endSeek() {
    if (!scrubbing_)
        return;
    scrubbing_ = false;
    if (remoteMode_) {
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("end_seek"));
        sendCommand(command);
    } else if (resumeAfterSeek_) {
        setPlayingLocal(true);
    }
    resumeAfterSeek_ = false;
}

void SessionController::nudgePixels(double delta) {
    if (remoteMode_) {
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("nudge"));
        command.insert(QStringLiteral("value"), delta);
        sendCommand(command);
        return;
    }
    if (model_.nudgePixels(delta, scrollRange_)) {
        emit progressChanged();
        markDirty();
    }
}

void SessionController::setSpeed(double pixelsPerSecond) {
    const double value = std::clamp(pixelsPerSecond, 0.0, 1200.0);
    if (remoteMode_) {
        model_.setSpeed(value);
        emit speedChanged();
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("speed"));
        command.insert(QStringLiteral("value"), value);
        sendCommand(command);
        return;
    }
    setSpeedLocal(value);
}

void SessionController::setFontSize(int points) {
    const int value = std::clamp(points, 12, 120);
    if (remoteMode_) {
        fontSize_ = value;
        emit fontSizeChanged();
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("font_size"));
        command.insert(QStringLiteral("value"), value);
        sendCommand(command);
        return;
    }
    setFontSizeLocal(value);
}

void SessionController::setTextWidth(int percent) {
    const int value = std::clamp(percent, 35, 100);
    if (remoteMode_) {
        textWidth_ = value;
        emit textWidthChanged();
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("text_width"));
        command.insert(QStringLiteral("value"), value);
        sendCommand(command);
        return;
    }
    setTextWidthLocal(value);
}

void SessionController::setScrollRange(double pixels) {
    // Only the display can measure the authoritative scrollable range. A remote's
    // local viewport is a different size and must never overwrite the host value.
    if (remoteMode_)
        return;
    setRangeLocal(std::max(0.0, pixels));
}

void SessionController::setThemeFlavor(const QString &flavor) {
    const QString value = canonicalChoice(flavor, themeFlavorNames());
    if (value.isEmpty() || themeFlavor_ == value)
        return;
    themeFlavor_ = value;
    emit themeFlavorChanged();
    scheduleSaveSettings();
}

void SessionController::setThemeAccent(const QString &accent) {
    const QString value = canonicalChoice(accent, themeAccentNames());
    if (value.isEmpty() || themeAccent_ == value)
        return;
    themeAccent_ = value;
    emit themeAccentChanged();
    scheduleSaveSettings();
}

void SessionController::requestViewerFullscreenToggle() {
    if (remoteMode_) {
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("viewer_fullscreen_toggle"));
        sendCommand(command);
        return;
    }
    emit viewerFullscreenToggleRequested();
}

void SessionController::requestViewerControlsToggle() {
    if (remoteMode_) {
        QJsonObject command;
        command.insert(QStringLiteral("name"), QStringLiteral("viewer_controls_toggle"));
        sendCommand(command);
        return;
    }
    emit viewerControlsToggleRequested();
}

void SessionController::setViewerFullscreenState(bool fullscreen) {
    // Only the display owns its window state. The remote learns it from snapshots.
    if (remoteMode_ || viewerFullscreen_ == fullscreen)
        return;
    viewerFullscreen_ = fullscreen;
    emit viewerFullscreenChanged();
    markDirty();
}

void SessionController::setViewerControlsVisibleState(bool visible) {
    // Only the display owns its controls visibility. The remote learns it from snapshots.
    if (remoteMode_ || viewerControlsVisible_ == visible)
        return;
    viewerControlsVisible_ = visible;
    emit viewerControlsVisibleChanged();
    markDirty();
}

void SessionController::setScript(const QString &markdown) {
    if (remoteMode_) {
        setDraftScript(markdown);
        return;
    }
    setScriptLocal(markdown);
}

void SessionController::setDraftScript(const QString &markdown) {
    const QString trimmed = markdown.left(kMaxScriptChars);
    if (draftScript_ == trimmed)
        return;
    draftScript_ = trimmed;
    draftDirty_ = true;
    emit draftScriptChanged();
}

void SessionController::sendDraftScript() {
    if (!remoteMode_ || !connected_) {
        setStatus(QStringLiteral("Connect to a display before sending a script"));
        return;
    }
    QJsonObject command;
    command.insert(QStringLiteral("name"), QStringLiteral("set_script"));
    command.insert(QStringLiteral("value"), draftScript_);
    sendCommand(command);
    setStatus(QStringLiteral("Sending script to display…"));
}

void SessionController::setHostAddress(const QString &address) {
    if (hostAddress_ == address)
        return;
    hostAddress_ = address;
    emit hostAddressChanged();
}

void SessionController::applyAutoBidi(QObject *quickTextDocument) {
    auto *wrapper = qobject_cast<QQuickTextDocument *>(quickTextDocument);
    if (!wrapper || !wrapper->textDocument())
        return;

    QTextDocument *document = wrapper->textDocument();
    bool editBlockOpen = false;
    QTextCursor editCursor(document);
    for (QTextBlock block = document->begin(); block.isValid(); block = block.next()) {
        QTextBlockFormat format = block.blockFormat();
        // QTextDocument can signal changes for block-format updates. The QML
        // textChanged handler may call this method again, so skip paragraphs whose
        // direction is already automatic. Open an edit block only if there's real
        // work to do; an empty begin/end pair should never generate needless work.
        if (format.layoutDirection() == Qt::LayoutDirectionAuto)
            continue;
        if (!editBlockOpen) {
            editCursor.beginEditBlock();
            editBlockOpen = true;
        }
        format.setLayoutDirection(Qt::LayoutDirectionAuto);
        QTextCursor blockCursor(block);
        blockCursor.setBlockFormat(format);
    }
    if (editBlockOpen)
        editCursor.endEditBlock();
}

void SessionController::onFrame() {
    const qint64 ns = frameClock_.nsecsElapsed();
    frameClock_.restart();
    const double elapsed = static_cast<double>(ns) / 1'000'000'000.0;
    const bool wasPlaying = model_.playing();

    // The display is the sole playback clock. Advancing the remote's local model
    // using its own (different) viewport range makes it drift between snapshots.
    if (!remoteMode_ && model_.advance(elapsed, scrollRange_)) {
        emit progressChanged();
        dirty_ = true;
    }
    if (wasPlaying != model_.playing()) {
        emit playingChanged();
        dirty_ = true;
    }

    // Match the common 60 Hz presentation cadence. Faster timers only woke the
    // UI more often than it could present frames and amplified QML work on mobile.
    if (dirty_ && broadcastClock_.elapsed() >= 16) {
        if (!remoteMode_ && hostPeer_ && authenticatedPeers_.contains(hostPeer_))
            sendSnapshot(hostPeer_, dirtyScript_);
        dirty_ = false;
        dirtyScript_ = false;
        broadcastClock_.restart();
    }

    // Idle sessions have no reason to poll. A paused, zero-speed, or zero-range
    // session also needs no animation frames; changing speed/range marks it dirty
    // and restarts the timer. This avoids a needless 60 Hz wakeup at speed 0.
    const bool canAdvance = model_.playing() && model_.speed() > 0.0 && scrollRange_ > 0.0;
    if (remoteMode_ || (!canAdvance && !dirty_))
        frameTimer_.stop();
}

void SessionController::acceptConnections() {
    while (server_.hasPendingConnections()) {
        QTcpSocket *socket = server_.nextPendingConnection();
        if (!socket)
            continue;
        if (hostPeer_ && hostPeer_->state() != QAbstractSocket::UnconnectedState) {
            socket->disconnectFromHost();
            socket->deleteLater();
            continue;
        }
        hostPeer_ = socket;
        connect(socket, &QTcpSocket::readyRead, this, [this, socket]() { readSocket(socket); });
        connect(socket, &QTcpSocket::disconnected, this, [this, socket]() {
            const bool pairingRejected = socket->property("cueflowPairingRejected").toBool();
            authenticatedPeers_.remove(socket);
            readBuffers_.remove(socket);
            if (hostPeer_ == socket)
                hostPeer_ = nullptr;
            socket->deleteLater();
            setConnected(false);
            if (!pairingRejected)
                setStatus(QStringLiteral("Remote disconnected"));
        });
        connect(socket, &QTcpSocket::errorOccurred, this, [this, socket](QAbstractSocket::SocketError) {
            if (socket == hostPeer_)
                setStatus(QStringLiteral("Remote socket error: %1").arg(socket->errorString()));
        });
    }
}

void SessionController::readSocket(QTcpSocket *socket) {
    if (!socket)
        return;
    QByteArray &buffer = readBuffers_[socket];
    buffer += socket->readAll();
    if (buffer.size() > kMaxFrameBytes && !buffer.contains('\n')) {
        closeSocket(socket);
        return;
    }
    while (true) {
        const qsizetype newline = buffer.indexOf('\n');
        if (newline < 0)
            break;
        if (newline > kMaxFrameBytes) {
            closeSocket(socket);
            return;
        }
        const QByteArray line = buffer.left(newline).trimmed();
        buffer.remove(0, newline + 1);
        if (line.isEmpty())
            continue;
        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(line, &error);
        if (error.error != QJsonParseError::NoError || !document.isObject()) {
            closeSocket(socket);
            return;
        }
        handleMessage(socket, document.object());
    }
}

void SessionController::handleMessage(QTcpSocket *socket, const QJsonObject &object) {
    const QString type = object.value(QStringLiteral("type")).toString();
    if (!remoteMode_ && socket == hostPeer_) {
        if (type == QStringLiteral("hello")) {
            // A four-digit PIN is convenient on a phone keyboard, so make
            // repeated LAN guesses expensive without rotating the PIN on each
            // failed attempt. Five failures trigger a 30-second cooldown.
            if (pairingLockoutClock_.isValid()) {
                if (pairingLockoutClock_.elapsed() < 30'000) {
                    socket->setProperty("cueflowPairingRejected", true);
                    setStatus(QStringLiteral("Pairing temporarily locked after failed PIN attempts; try again shortly"));
                    closeSocket(socket);
                    return;
                }
                pairingLockoutClock_.invalidate();
                failedPairingAttempts_ = 0;
            }

            const QString suppliedPin = object.value(QStringLiteral("pin")).toString();
            if (!server_.isListening() || suppliedPin.size() != 4 || suppliedPin != pin_) {
                const bool lockoutStarted = server_.isListening() && ++failedPairingAttempts_ >= 5;
                if (lockoutStarted)
                    pairingLockoutClock_.start();
                socket->setProperty("cueflowPairingRejected", true);
                setStatus(lockoutStarted
                    ? QStringLiteral("Too many incorrect PIN attempts; pairing locked for 30 seconds")
                    : QStringLiteral("Rejected a remote with an invalid pairing PIN"));
                closeSocket(socket);
                return;
            }
            failedPairingAttempts_ = 0;
            authenticatedPeers_.insert(socket);
            setConnected(true);
            setStatus(QStringLiteral("Remote connected"));
            sendSnapshot(socket, true);
            return;
        }
        if (!authenticatedPeers_.contains(socket)) {
            closeSocket(socket);
            return;
        }
        if (type == QStringLiteral("command"))
            handleCommand(object);
        return;
    }

    if (remoteMode_ && socket == clientSocket_ && type == QStringLiteral("state")) {
        if (!connected_)
            setConnected(true);
        if (object.contains(QStringLiteral("script"))) {
            const QString incomingScript = object.value(QStringLiteral("script")).toString().left(kMaxScriptChars);
            if (script_ != incomingScript) {
                script_ = incomingScript;
                emit scriptChanged();
            }
            if (!draftDirty_ || draftScript_ == incomingScript) {
                if (draftScript_ != incomingScript) {
                    draftScript_ = incomingScript;
                    emit draftScriptChanged();
                }
                draftDirty_ = false;
            }
        }
        if (object.contains(QStringLiteral("playing"))) {
            const bool value = object.value(QStringLiteral("playing")).toBool();
            if (model_.playing() != value) {
                model_.setPlaying(value);
                emit playingChanged();
            }
        }
        if (object.contains(QStringLiteral("progress"))) {
            const double value = object.value(QStringLiteral("progress")).toDouble();
            if (!qFuzzyCompare(model_.progress() + 1.0, value + 1.0)) {
                model_.setProgress(value);
                emit progressChanged();
            }
        }
        if (object.contains(QStringLiteral("speed"))) {
            const double value = object.value(QStringLiteral("speed")).toDouble();
            if (!qFuzzyCompare(model_.speed() + 1.0, value + 1.0)) {
                model_.setSpeed(value);
                emit speedChanged();
            }
        }
        if (object.contains(QStringLiteral("fontSize"))) {
            const int value = object.value(QStringLiteral("fontSize")).toInt();
            if (fontSize_ != value) { fontSize_ = value; emit fontSizeChanged(); }
        }
        if (object.contains(QStringLiteral("textWidth"))) {
            const int value = object.value(QStringLiteral("textWidth")).toInt();
            if (textWidth_ != value) { textWidth_ = value; emit textWidthChanged(); }
        }
        if (object.contains(QStringLiteral("scrollRange"))) {
            const double value = object.value(QStringLiteral("scrollRange")).toDouble();
            if (!qFuzzyCompare(scrollRange_ + 1.0, value + 1.0)) {
                scrollRange_ = value;
                emit scrollRangeChanged();
            }
        }
        if (object.contains(QStringLiteral("viewerFullscreen"))) {
            const bool value = object.value(QStringLiteral("viewerFullscreen")).toBool();
            if (viewerFullscreen_ != value) {
                viewerFullscreen_ = value;
                emit viewerFullscreenChanged();
            }
        }
        if (object.contains(QStringLiteral("viewerControlsVisible"))) {
            const bool value = object.value(QStringLiteral("viewerControlsVisible")).toBool();
            if (viewerControlsVisible_ != value) {
                viewerControlsVisible_ = value;
                emit viewerControlsVisibleChanged();
            }
        }
        setStatus(QStringLiteral("Connected to display"));
    }
}

void SessionController::handleCommand(const QJsonObject &command) {
    const QString name = command.value(QStringLiteral("name")).toString();
    const QJsonValue value = command.value(QStringLiteral("value"));
    if (name == QStringLiteral("toggle")) {
        setPlayingLocal(!model_.playing());
    } else if (name == QStringLiteral("reset")) {
        model_.reset();
        emit progressChanged();
        emit playingChanged();
        markDirty();
    } else if (name == QStringLiteral("begin_seek")) {
        if (!scrubbing_) {
            scrubbing_ = true;
            resumeAfterSeek_ = model_.playing();
            setPlayingLocal(false);
        }
    } else if (name == QStringLiteral("seek")) {
        setProgressLocal(value.toDouble());
    } else if (name == QStringLiteral("end_seek")) {
        if (scrubbing_) {
            scrubbing_ = false;
            if (resumeAfterSeek_) setPlayingLocal(true);
            resumeAfterSeek_ = false;
        }
    } else if (name == QStringLiteral("nudge")) {
        if (model_.nudgePixels(value.toDouble(), scrollRange_)) {
            emit progressChanged();
            markDirty();
        }
    } else if (name == QStringLiteral("speed")) {
        setSpeedLocal(value.toDouble());
    } else if (name == QStringLiteral("font_size")) {
        setFontSizeLocal(value.toInt());
    } else if (name == QStringLiteral("text_width")) {
        setTextWidthLocal(value.toInt());
    } else if (name == QStringLiteral("set_script")) {
        const QString incoming = value.toString();
        if (incoming.size() <= kMaxScriptChars)
            setScriptLocal(incoming);
        else
            setStatus(QStringLiteral("Script rejected: it exceeds the size limit"));
    } else if (name == QStringLiteral("viewer_fullscreen_toggle")) {
        emit viewerFullscreenToggleRequested();
    } else if (name == QStringLiteral("viewer_controls_toggle")) {
        emit viewerControlsToggleRequested();
    }
}

void SessionController::sendSnapshot(QTcpSocket *socket, bool includeScript) {
    if (!socket || socket->state() != QAbstractSocket::ConnectedState)
        return;
    QJsonObject state;
    state.insert(QStringLiteral("type"), QStringLiteral("state"));
    state.insert(QStringLiteral("playing"), model_.playing());
    state.insert(QStringLiteral("progress"), model_.progress());
    state.insert(QStringLiteral("speed"), model_.speed());
    state.insert(QStringLiteral("fontSize"), fontSize_);
    state.insert(QStringLiteral("textWidth"), textWidth_);
    state.insert(QStringLiteral("scrollRange"), scrollRange_);
    state.insert(QStringLiteral("viewerFullscreen"), viewerFullscreen_);
    state.insert(QStringLiteral("viewerControlsVisible"), viewerControlsVisible_);
    if (includeScript)
        state.insert(QStringLiteral("script"), script_);
    writeJson(socket, state);
}

void SessionController::sendCommand(const QJsonObject &command) {
    if (!remoteMode_ || !clientSocket_ || clientSocket_->state() != QAbstractSocket::ConnectedState) {
        setStatus(QStringLiteral("No display connection"));
        return;
    }
    QJsonObject message = command;
    message.insert(QStringLiteral("type"), QStringLiteral("command"));
    writeJson(clientSocket_, message);
}

void SessionController::writeJson(QTcpSocket *socket, const QJsonObject &object) {
    if (!socket || socket->state() != QAbstractSocket::ConnectedState)
        return;
    QByteArray bytes = QJsonDocument(object).toJson(QJsonDocument::Compact);
    bytes.append('\n');
    socket->write(bytes);
}

void SessionController::closeSocket(QTcpSocket *socket) {
    if (!socket)
        return;
    authenticatedPeers_.remove(socket);
    readBuffers_.remove(socket);
    if (hostPeer_ == socket)
        hostPeer_ = nullptr;
    if (clientSocket_ == socket)
        clientSocket_ = nullptr;
    socket->abort();
    socket->deleteLater();
    setConnected(false);
}

void SessionController::setStatus(const QString &status) {
    if (status_ == status)
        return;
    status_ = status;
    emit statusChanged();
}

void SessionController::setConnected(bool connected) {
    if (connected_ == connected)
        return;
    connected_ = connected;
    emit connectedChanged();
}

void SessionController::setPlayingLocal(bool playing) {
    if (model_.playing() == playing)
        return;
    model_.setPlaying(playing);
    emit playingChanged();
    markDirty();
}

void SessionController::setProgressLocal(double value) {
    const double before = model_.progress();
    model_.setProgress(value);
    if (model_.progress() != before) {
        emit progressChanged();
        markDirty();
    }
}

void SessionController::setSpeedLocal(double pixelsPerSecond) {
    const double before = model_.speed();
    model_.setSpeed(pixelsPerSecond);
    if (model_.speed() != before) {
        emit speedChanged();
        scheduleSaveSettings();
        markDirty();
    }
}

void SessionController::setFontSizeLocal(int points) {
    const int value = std::clamp(points, 12, 120);
    if (fontSize_ == value)
        return;
    fontSize_ = value;
    emit fontSizeChanged();
    scheduleSaveSettings();
    markDirty();
}

void SessionController::setTextWidthLocal(int percent) {
    const int value = std::clamp(percent, 35, 100);
    if (textWidth_ == value)
        return;
    textWidth_ = value;
    emit textWidthChanged();
    scheduleSaveSettings();
    markDirty();
}

void SessionController::setScriptLocal(const QString &markdown) {
    const QString capped = markdown.left(kMaxScriptChars);
    if (script_ == capped)
        return;
    const bool wasPlaying = model_.playing();
    const bool hadProgress = model_.progress() > 0.0;
    model_.reset();
    if (wasPlaying) emit playingChanged();
    if (hadProgress) emit progressChanged();
    script_ = capped;
    draftScript_ = capped;
    draftDirty_ = false;
    emit scriptChanged();
    emit draftScriptChanged();
    saveSettings();
    markDirty(true);
}

void SessionController::setRangeLocal(double pixels) {
    const double value = std::isfinite(pixels) ? std::clamp(pixels, 0.0, 100'000'000.0) : 0.0;
    if (qFuzzyCompare(scrollRange_ + 1.0, value + 1.0))
        return;
    scrollRange_ = value;
    emit scrollRangeChanged();
    markDirty();
}

void SessionController::markDirty(bool includeScript) {
    dirty_ = true;
    dirtyScript_ = dirtyScript_ || includeScript;
    if (!remoteMode_ && !frameTimer_.isActive()) {
        frameClock_.restart();
        broadcastClock_.restart();
        frameTimer_.start();
    }
}

void SessionController::scheduleSaveSettings() {
    settingsSaveTimer_.start();
}

void SessionController::refreshAddresses() {
    QStringList addresses;
    for (const QHostAddress &address : QNetworkInterface::allAddresses()) {
        if (address.protocol() == QAbstractSocket::IPv4Protocol && !address.isLoopback() && !address.isNull())
            addresses.append(address.toString());
    }
    addresses.removeDuplicates();
    addresses.sort();
    if (localAddresses_ != addresses) {
        localAddresses_ = addresses;
        emit localAddressesChanged();
    }
}
