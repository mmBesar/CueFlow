#include "SessionController.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QIcon>
#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QVariant>
#endif
#include <cstdlib>

namespace {

void setKeepScreenOn(bool keepOn) {
#ifdef Q_OS_ANDROID
    // FLAG_KEEP_SCREEN_ON is scoped to the foreground Activity's window.
    // Apply it on Android's UI thread and clear it when CueFlow backgrounds.
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
    Q_UNUSED(keepOn);
#endif
}

} // namespace

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("CueFlow"));
    QCoreApplication::setOrganizationName(QStringLiteral("mmBesar"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0-dev"));
    QQuickStyle::setStyle(QStringLiteral("Material"));

#ifdef Q_OS_ANDROID
    QObject::connect(&app, &QGuiApplication::applicationStateChanged, &app,
                     [](Qt::ApplicationState state) {
                         setKeepScreenOn(state == Qt::ApplicationActive);
                     });
#endif

    SessionController session;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("session"), &session);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(EXIT_FAILURE); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("CueFlow"), QStringLiteral("Main"));
    // The Activity is available by the time the QML engine is loaded.
    setKeepScreenOn(true);
    return app.exec();
}
