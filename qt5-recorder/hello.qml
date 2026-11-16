import QtQuick 2.9

Rectangle {
    width: 320; height: 320
    color: "#101820"

    Rectangle {
        id: btn
        width: 160; height: 160; radius: 80
        anchors.centerIn: parent
        color: "#e53935"
        Text {
            anchors.centerIn: parent
            text: "●"
            color: "white"
            font.pixelSize: 80
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        text: "E1 Qt5 OK"
        color: "#ffffff"
        font.pixelSize: 22
    }
}
