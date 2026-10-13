#pragma once

#include "ScrollModel.h"

#include <QElapsedTimer>
#include <QHash>
#include <QHostAddress>
#include <QJsonObject>
#include <QList>
#include <QNetworkInterface>
#include <QObject>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QSet>
#include <QStringList>

class QQuickTextDocument;

class SessionController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString script READ script NOTIFY scriptChanged)
    Q_PROPERTY(QString safeMarkdown READ safeMarkdown NOTIFY scriptChanged)
    Q_PROPERTY(QString draftScript READ draftScript WRITE setDraftScript NOTIFY draftScriptChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(bool remoteMode READ remoteMode NOTIFY remoteModeChanged)
    Q_PROPERTY(bool hosting READ hosting NOTIFY hostingChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString pin READ pin NOTIFY pinChanged)
    Q_PROPERTY(QString hostAddress READ hostAddress WRITE setHostAddress NOTIFY hostAddressChanged)
    Q_PROPERTY(QStringList localAddresses READ localAddresses NOTIFY localAddressesChanged)
    Q_PROPERTY(int port READ port CONSTANT)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(double speed READ speed NOTIFY speedChanged)
    Q_PROPERTY(int fontSize READ fontSize NOTIFY fontSizeChanged)
    Q_PROPERTY(int textWidth READ textWidth NOTIFY textWidthChanged)
    Q_PROPERTY(double scrollRange READ scrollRange NOTIFY scrollRangeChanged)

public:
    explicit SessionController(QObject *parent = nullptr);
    ~SessionController() override;

    QString script() const { return script_; }
    QString safeMarkdown() const;
    QString draftScript() const { return draftScript_; }
    bool playing() const { return model_.playing(); }
    bool remoteMode() const { return remoteMode_; }
    bool hosting() const { return server_.isListening(); }
    bool connected() const { return connected_; }
    QString status() const { return status_; }
    QString pin() const { return pin_; }
    QString hostAddress() const { return hostAddress_; }
    QStringList localAddresses() const { return localAddresses_; }
    int port() const { return kPort; }
    double progress() const { return model_.progress(); }
    double speed() const { return model_.speed(); }
    int fontSize() const { return fontSize_; }
    int textWidth() const { return textWidth_; }
    double scrollRange() const { return scrollRange_; }

    Q_INVOKABLE void setMode(const QString &mode);
    Q_INVOKABLE void startHosting();
    Q_INVOKABLE void stopHosting();
    Q_INVOKABLE void connectToHost(const QString &address, const QString &pin);
    Q_INVOKABLE void disconnectSession();
    Q_INVOKABLE void togglePlayback();
    Q_INVOKABLE void resetPlayback();
    Q_INVOKABLE void beginSeek();
    Q_INVOKABLE void seekTo(double normalizedProgress);
    Q_INVOKABLE void endSeek();
    Q_INVOKABLE void nudgePixels(double delta);
    Q_INVOKABLE void setSpeed(double pixelsPerSecond);
    Q_INVOKABLE void setFontSize(int points);
    Q_INVOKABLE void setTextWidth(int percent);
    Q_INVOKABLE void setScrollRange(double pixels);
    Q_INVOKABLE void setScript(const QString &markdown);
    Q_INVOKABLE void sendDraftScript();
    Q_INVOKABLE void applyAutoBidi(QObject *quickTextDocument);

public slots:
    void setDraftScript(const QString &markdown);
    void setHostAddress(const QString &address);

signals:
    void scriptChanged();
    void draftScriptChanged();
    void playingChanged();
    void remoteModeChanged();
    void hostingChanged();
    void connectedChanged();
    void statusChanged();
    void pinChanged();
    void hostAddressChanged();
    void localAddressesChanged();
    void progressChanged();
    void speedChanged();
    void fontSizeChanged();
    void textWidthChanged();
    void scrollRangeChanged();

private slots:
    void onFrame();
    void acceptConnections();

private:
    static constexpr quint16 kPort = 47773;
    static constexpr qsizetype kMaxFrameBytes = 2 * 1024 * 1024;
    static constexpr qsizetype kMaxScriptChars = 1'000'000;

    void setStatus(const QString &status);
    void setConnected(bool connected);
    void setPlayingLocal(bool playing);
    void setProgressLocal(double value);
    void setSpeedLocal(double pixelsPerSecond);
    void setFontSizeLocal(int points);
    void setTextWidthLocal(int percent);
    void setScriptLocal(const QString &markdown);
    void setRangeLocal(double pixels);
    void markDirty(bool includeScript = false);
    void sendSnapshot(QTcpSocket *socket, bool includeScript);
    void sendCommand(const QJsonObject &command);
    void writeJson(QTcpSocket *socket, const QJsonObject &object);
    void readSocket(QTcpSocket *socket);
    void handleMessage(QTcpSocket *socket, const QJsonObject &object);
    void handleCommand(const QJsonObject &command);
    void closeSocket(QTcpSocket *socket);
    void refreshAddresses();
    void loadSettings();
    void saveSettings();
    void scheduleSaveSettings();
    QString sanitizeMarkdown(const QString &markdown) const;

    ScrollModel model_;
    QTcpServer server_;
    QTcpSocket *clientSocket_ = nullptr;
    QTcpSocket *hostPeer_ = nullptr;
    QHash<QTcpSocket *, QByteArray> readBuffers_;
    QSet<QTcpSocket *> authenticatedPeers_;
    QTimer frameTimer_;
    QTimer settingsSaveTimer_;
    QElapsedTimer frameClock_;
    QElapsedTimer broadcastClock_;
    QString script_;
    QString draftScript_;
    QString status_ = QStringLiteral("Ready");
    QString pin_;
    QString hostAddress_;
    QStringList localAddresses_;
    double scrollRange_ = 0.0;
    int fontSize_ = 44;
    int textWidth_ = 88;
    bool remoteMode_ = false;
    bool connected_ = false;
    bool dirty_ = false;
    bool dirtyScript_ = false;
    bool scrubbing_ = false;
    bool resumeAfterSeek_ = false;
    bool draftDirty_ = false;
};
