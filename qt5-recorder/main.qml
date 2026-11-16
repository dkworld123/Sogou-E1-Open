import QtQuick 2.7
import QtQuick.Window 2.2

Window {
    visible: true
    width: 320; height: 320
    color: "#0f1216"
    title: "E1 Recorder"

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: recorder.recording ? ("● REC  " + recorder.elapsed + "s") : "待机"
            color: recorder.recording ? "#ff5252" : "#9aa7b0"
            font.pixelSize: 22; font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // 电平表
        Rectangle {
            width: parent.width; height: 14; radius: 7
            color: "#222b33"
            Rectangle {
                width: Math.max(0, Math.min(1, recorder.level / 100.0)) * parent.width
                height: parent.height; radius: 7
                color: "#36d399"
            }
        }

        // 录音按钮
        Rectangle {
            id: btn
            width: 120; height: 120; radius: 60
            anchors.horizontalCenter: parent.horizontalCenter
            color: recorder.recording ? "#ff5252" : "#2a6df4"
            Text {
                anchors.centerIn: parent
                text: recorder.recording ? "停止" : "录音"
                color: "white"; font.pixelSize: 22; font.bold: true
            }
            MouseArea {
                anchors.fill: parent
                onClicked: recorder.recording ? recorder.stop() : recorder.start()
            }
        }

        Text {
            text: recorder.status
            color: "#9aa7b0"; font.pixelSize: 13
            wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
        }
    }

    Component.onCompleted: console.log("E1 Qt5 Recorder UI loaded")
}
