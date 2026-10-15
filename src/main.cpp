#include "SessionController.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlError>
#include <QQmlContext>
#include <QQuickStyle>
#include <QIcon>
#include <QDebug>
#ifdef Q_OS_ANDROID
#include <QVariant>
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
#include <QJniObject>
#else
#include <QtAndroid>
#include <QAndroidJniObject>
#endif
#endif
#include <QUrl>
#include <cstdlib>

#ifndef CUEFLOW_BUILD_COMMIT
#define CUEFLOW_BUILD_COMMIT "unknown"
#endif

namespace {

void setKeepScreenOn(bool keepOn) {
#ifdef Q_OS_ANDROID
    // FLAG_KEEP_SCREEN_ON is scoped to the foreground Activity's window.
    // Qt 6 and Qt 5 expose different JNI dispatch helpers.
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([keepOn]() -> QVariant {
        if (!QNativeInterface::QAndroidApplication::isActivityContext())
            return {};
        const QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid())
            return {};
        const QJniObject window = activity.callObjectMethod("getWindow", "()Landroid/view/Window;");
        if (!window.isValid())
            return {};
        constexpr jint KeepScreenOnFlag = 128; // WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        if (keepOn)
            window.callMethod<void>("addFlags", "(I)V", KeepScreenOnFlag);
        else
            window.callMethod<void>("clearFlags", "(I)V", KeepScreenOnFlag);
        return {};
    });
#else
    QtAndroid::runOnAndroidThread([keepOn]() {
        const QAndroidJniObject activity = QtAndroid::androidActivity();
        if (!activity.isValid())
            return;
        const QAndroidJniObject window = activity.callObjectMethod("getWindow", "()Landroid/view/Window;");
        if (!window.isValid())
            return;
        constexpr jint KeepScreenOnFlag = 128; // WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        if (keepOn)
            window.callMethod<void>("addFlags", "(I)V", KeepScreenOnFlag);
        else
            window.callMethod<void>("clearFlags", "(I)V", KeepScreenOnFlag);
    });
#endif
#else
    Q_UNUSED(keepOn);
#endif
}

} // namespace

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("CueFlow"));
    QCoreApplication::setOrganizationName(QStringLiteral("mmBesar"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0-dev"));
    qInfo().noquote() << "CueFlow build commit:" << CUEFLOW_BUILD_COMMIT;
    QQuickStyle::setStyle(QStringLiteral("Material"));

#ifdef Q_OS_ANDROID
    QObject::connect(&app, &QGuiApplication::applicationStateChanged, &app,
                     [](Qt::ApplicationState state) {
                         setKeepScreenOn(state == Qt::ApplicationActive);
                     });
#endif

    SessionController session;
    QQmlApplicationEngine engine;
    // Always print QML errors clearly. This is especially important for the
    // Qt 5.15 Android 6 build, where a failed root component previously left
    // an apparently blank white Activity running.
    QObject::connect(&engine, &QQmlEngine::warnings, &app,
                     [](const QList<QQmlError> &warnings) {
                         for (const QQmlError &warning : warnings)
                             qWarning().noquote() << "CueFlow QML:" << warning.toString();
                     });
    engine.rootContext()->setContextProperty(QStringLiteral("session"), &session);
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(EXIT_FAILURE); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("CueFlow"), QStringLiteral("Main"));
#else
    engine.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    if (engine.rootObjects().isEmpty()) {
        qCritical().noquote() << "CueFlow: failed to create the QML root object; see the QML diagnostics above.";
        return EXIT_FAILURE;
    }
#endif
    // The Activity is available by the time the QML engine is loaded.
    setKeepScreenOn(true);
    return app.exec();
}
