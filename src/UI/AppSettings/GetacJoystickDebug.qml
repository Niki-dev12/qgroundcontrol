/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Controllers
import QGroundControl.Palette
import QGroundControl.ScreenTools

SettingsPage {
    id: root

    QGCPalette { id: qgcPal }

    GetacJoystickDebugger {
        id: debuggerController
    }

    SettingsGroupLayout {
        heading: qsTr("Connection")

        GridLayout {
            columns: 2
            columnSpacing: ScreenTools.defaultFontPixelWidth * 2
            rowSpacing: ScreenTools.defaultFontPixelHeight / 2
            Layout.fillWidth: true

            QGCLabel { text: qsTr("COM Port") }
            RowLayout {
                Layout.fillWidth: true

                QGCComboBox {
                    id: portCombo
                    Layout.fillWidth: true
                    model: debuggerController.availablePorts.length > 0 ? debuggerController.availablePorts : [ qsTr("None Available") ]
                    enabled: !debuggerController.connected && debuggerController.availablePorts.length > 0

                    onActivated: (index) => {
                        if (debuggerController.availablePorts.length > 0) {
                            debuggerController.selectedPort = textAt(index)
                        }
                    }

                    Component.onCompleted: {
                        if (debuggerController.availablePorts.length > 0) {
                            debuggerController.selectedPort = textAt(0)
                        }
                    }
                }

                QGCButton {
                    text: qsTr("Refresh")
                    enabled: !debuggerController.connected
                    onClicked: debuggerController.refreshPorts()
                }
            }

            QGCLabel { text: qsTr("State") }
            QGCLabel {
                Layout.fillWidth: true
                text: debuggerController.status
                elide: Text.ElideMiddle
            }

            QGCLabel { text: qsTr("Packet") }
            QGCLabel {
                Layout.fillWidth: true
                text: debuggerController.packetStatus
                color: debuggerController.failsafe || debuggerController.frameLost ? qgcPal.warningText : qgcPal.text
                elide: Text.ElideRight
            }

            QGCLabel { text: qsTr("Last Packet") }
            QGCLabel {
                Layout.fillWidth: true
                text: debuggerController.lastPacketTime === "" ? qsTr("None") : debuggerController.lastPacketTime
            }
        }

        RowLayout {
            Layout.fillWidth: true

            QGCButton {
                text: debuggerController.connected ? qsTr("Disconnect") : qsTr("Connect")
                onClicked: debuggerController.connected ? debuggerController.disconnectPort() : debuggerController.connectPort()
            }

            QGCButton {
                text: qsTr("Send Init")
                enabled: debuggerController.connected
                onClicked: debuggerController.sendInitialization()
            }

            QGCButton {
                text: qsTr("Clear")
                onClicked: debuggerController.clearLog()
            }

            QGCButton {
                text: qsTr("Save Raw Log")
                enabled: debuggerController.rawBytes.length > 0
                onClicked: debuggerController.saveRawLog()
            }
        }

        GridLayout {
            columns: 4
            columnSpacing: ScreenTools.defaultFontPixelWidth * 2
            rowSpacing: ScreenTools.defaultFontPixelHeight / 2

            QGCLabel { text: qsTr("ACK") }
            QGCLabel {
                text: debuggerController.ackReceived ? qsTr("Received") : qsTr("Waiting")
                color: debuggerController.ackReceived ? qgcPal.text : qgcPal.warningText
            }

            QGCLabel { text: qsTr("Valid") }
            QGCLabel { text: debuggerController.validPackets }

            QGCLabel { text: qsTr("CRC Errors") }
            QGCLabel {
                text: debuggerController.crcErrors
                color: debuggerController.crcErrors > 0 ? qgcPal.warningText : qgcPal.text
            }

            QGCLabel { text: qsTr("Flags") }
            QGCLabel {
                text: (debuggerController.frameLost ? qsTr("Frame Lost ") : "") +
                      (debuggerController.failsafe ? qsTr("Failsafe") : (!debuggerController.frameLost ? qsTr("OK") : ""))
                color: debuggerController.frameLost || debuggerController.failsafe ? qgcPal.warningText : qgcPal.text
            }
        }
    }

    SettingsGroupLayout {
        heading: qsTr("Joystick Backend")

        GridLayout {
            columns: 2
            columnSpacing: ScreenTools.defaultFontPixelWidth * 2
            rowSpacing: ScreenTools.defaultFontPixelHeight / 2
            Layout.fillWidth: true

            QGCLabel { text: qsTr("Enabled") }
            QGCCheckBox {
                checked: debuggerController.joystickBackendEnabled
                onCheckedChanged: debuggerController.joystickBackendEnabled = checked
            }

            QGCLabel { text: qsTr("Forced Port") }
            RowLayout {
                Layout.fillWidth: true

                QGCLabel {
                    Layout.fillWidth: true
                    text: debuggerController.forcedJoystickPort === "" ? qsTr("Auto-detect") : debuggerController.forcedJoystickPort
                    elide: Text.ElideMiddle
                }

                QGCButton {
                    text: qsTr("Use Selected")
                    enabled: debuggerController.selectedPort !== ""
                    onClicked: debuggerController.useSelectedPortForJoystick()
                }

                QGCButton {
                    text: qsTr("Auto")
                    onClicked: debuggerController.forcedJoystickPort = ""
                }
            }
        }
    }

    SettingsGroupLayout {
        heading: qsTr("Channels")

        GridLayout {
            columns: root.width > ScreenTools.defaultFontPixelWidth * 90 ? 2 : 1
            columnSpacing: ScreenTools.defaultFontPixelWidth * 3
            rowSpacing: ScreenTools.defaultFontPixelHeight / 2
            Layout.fillWidth: true

            Repeater {
                model: debuggerController.channelValues.length

                RowLayout {
                    Layout.fillWidth: true

                    QGCLabel {
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5
                        text: qsTr("CH%1").arg(modelData + 1)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
                        color: qgcPal.windowShade

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width,
                               ((debuggerController.channelValues[modelData] - 995) / 1000.0) * parent.width - width / 2))
                            width: ScreenTools.defaultFontPixelWidth
                            height: parent.height
                            color: qgcPal.text
                        }
                    }

                    QGCLabel {
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                        horizontalAlignment: Text.AlignRight
                        text: debuggerController.channelValues[modelData]
                    }
                }
            }
        }
    }

    SettingsGroupLayout {
        heading: qsTr("Buttons")

        GridLayout {
            columns: root.width > ScreenTools.defaultFontPixelWidth * 90 ? 5 : 2
            columnSpacing: ScreenTools.defaultFontPixelWidth * 2
            rowSpacing: ScreenTools.defaultFontPixelHeight / 2

            Repeater {
                model: debuggerController.buttonValues.length

                RowLayout {
                    QGCLabel {
                        text: qsTr("B%1").arg(modelData + 1)
                    }

                    Rectangle {
                        width: ScreenTools.defaultFontPixelHeight
                        height: width
                        radius: width / 2
                        color: debuggerController.buttonValues[modelData] ? qgcPal.colorGreen : qgcPal.windowShade
                        border.color: qgcPal.text
                        border.width: 1
                    }
                }
            }
        }
    }

    SettingsGroupLayout {
        heading: qsTr("Raw Bytes")

        TextArea {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 10
            readOnly: true
            wrapMode: TextEdit.Wrap
            text: debuggerController.rawBytes
            color: qgcPal.text
            background: Rectangle {
                color: qgcPal.windowShade
                border.color: qgcPal.text
                border.width: 1
            }
        }
    }
}
