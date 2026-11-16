// demo_ui.qml — 纯 QML 演示界面（无需编译 C++，用 qmlscene 即可跑）。
// 用于验证屏幕/触摸渲染。录音功能需在编译版 App（main.qml + recorder.cpp）中才生效。
import QtQuick 2.9

Rectangle {
    id: root
    width: 320; height: 320
    color: "#0d1117"

    property bool recording: false
    property int secs: 0

    Timer {
        id: timer
        interval: 1000; repeat: true
        onTriggered: if (root.recording) root.secs++
    }

    Rectangle {
        id: recBtn
        width: 150; height: 150; radius: 75
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -20
        color: root.recording ? "#e53935" : "#2ea043"
        Behavior on color { ColorAnimation { duration: 200 } }

        Text {
            anchors.centerIn: parent
            text: root.recording ? "■" : "●"
            color: "white"; font.pixelSize: 70
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.recording = !root.recording
                if (root.recording) { root.secs = 0; timer.running = true }
                else { timer.running = false }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        text: root.recording ? ("录制中 " + root.secs + "s") : "点击开始"
        color: "#8b949e"; font.pixelSize: 18
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        text: "E1 Qt5 Demo"
        color: "#586069"; font.pixelSize: 13
    }
}
