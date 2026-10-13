#include "SessionController.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QIcon>
#include <cstdlib>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("CueFlow"));
    QCoreApplication::setOrganizationName(QStringLiteral("mmBesar"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0-dev"));
    QQuickStyle::setStyle(QStringLiteral("Material"));

    SessionController session;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("session"), &session);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(EXIT_FAILURE); }, Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("CueFlow"), QStringLiteral("Main"));
    return app.exec();
}
