#include <QDebug>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlDebuggingEnabler>
#include <QUrl>
#include <QtQml>
#include <cstdio>

static QQmlTriviallyDestructibleDebuggingEnabler enabler;

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);

    QCoreApplication::setOrganizationName("Logos");
    QCoreApplication::setOrganizationDomain("logos.co");
    QCoreApplication::setApplicationName("LogosLibp2p");

    QQmlApplicationEngine engine;

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app, [](const QList<QQmlError>& warnings) {
        for (const QQmlError& warning : warnings) {
            qWarning().noquote() << warning.toString();
        }
    });

    engine.addImportPath(QCoreApplication::applicationDirPath() + "/qml");
    const QUrl mainUrl = QUrl::fromLocalFile(QCoreApplication::applicationDirPath() + "/Libp2pBackend/Preview.qml");
    QQmlComponent component(&engine, mainUrl);
    if (component.isError()) {
        for (const QQmlError& error : component.errors()) {
            fprintf(stderr, "%s\n", error.toString().toUtf8().constData());
        }
        return 1;
    }

    QObject* root = component.create();
    if (!root) {
        for (const QQmlError& error : component.errors()) {
            fprintf(stderr, "%s\n", error.toString().toUtf8().constData());
        }
        fprintf(stderr, "Failed to create the libp2p UI preview root object\n");
        qWarning() << "Failed to create the libp2p UI preview root object from" << mainUrl;
        return 1;
    }

    return app.exec();
}
