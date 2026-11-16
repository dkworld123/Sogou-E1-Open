#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "recorder.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("E1 Recorder");

    Recorder recorder;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("recorder", &recorder);
    engine.load(QUrl(QStringLiteral("qrc:/main.qml")));
    if (engine.rootObjects().isEmpty()) return -1;
    return app.exec();
}
