#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QtQml>
#include <QMetaType>
#include "GameEngine.h"

int main(int argc, char *argv[])
{
    QGuiApplication *app = SailfishApp::application(argc, argv);
    QQuickView *view = SailfishApp::createView();

    // Register C++ type for QML
    qmlRegisterType<GameEngine>(
        "harbour.zsir",
        1, 0,
        "GameEngine"
    );

    // Load QML from /usr/share/<appname>/qml/
    view->setSource(
        SailfishApp::pathTo("qml/harbour-zsirozas.qml")
    );
    view->show();

    return app->exec();
}
