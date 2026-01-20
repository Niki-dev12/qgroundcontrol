/****************************************************************************
 *
 *  SpatialUser4Instrument.qml
 *  Instrument-style widget for user3Lat/user3Lon/user3Data + selected tag row
 *
 ****************************************************************************/

import QtQuick
import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Palette

Rectangle {
    id: root

    implicitWidth:  ScreenTools.defaultFontPixelHeight * 12
    implicitHeight: ScreenTools.defaultFontPixelHeight * 6.2 
    width:          implicitWidth
    height:         implicitHeight

    readonly property int windowColumns: 3
    readonly property int coordinatePrecision: 5
    property bool debug: false

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle

    // USER3 facts
    readonly property var user3LatFact:  vehicle ? vehicle.user3Lat  : null
    readonly property var user3LonFact:  vehicle ? vehicle.user3Lon  : null
    readonly property var user3DataFact: vehicle ? vehicle.user3Data : null

    // List of all detected USER4 
    property var tagIdsModel: []
    property int selectedTagId: -1
    property var comboDet: null

    function updateComboDet() {
        comboDet = null
        if (!vehicle || selectedTagId < 0 || !vehicle.geopixelDetections) {
            return
        }

        const list = vehicle.geopixelDetections
        for (let i = 0; i < list.count; i++) {
            const det = list.get(i)
            if (det && det.objectId === selectedTagId) {
                comboDet = det
                return
            }
        }
    }

    Connections {
        target: root.vehicle

        function onSelectedGeopixelObjectIdChanged() {
            if (!root.vehicle) return

            root.selectedTagId = root.vehicle.selectedGeopixelObjectId
            root.updateComboDet()

            // also keep combo UI synced
            const idx = root.tagIdsModel.indexOf(root.selectedTagId)
            if (idx >= 0 && tagCombo.currentIndex !== idx) {
                tagCombo.currentIndex = idx
            }
        }
    }

    Component.onCompleted: {
        if (vehicle) {
            selectedTagId = vehicle.selectedGeopixelObjectId
            updateComboDet()
        }
    }

    readonly property var comboCoord: (comboDet && comboDet.coordinate && comboDet.coordinate.isValid)
                                    ? comboDet.coordinate
                                    : null

    QGCPalette {
        id: palette
        colorGroupEnabled: true
    }

    color: palette.window
    border.color: palette.text
    radius: ScreenTools.defaultFontPixelHeight * 0.5

    function formatNumber(value, digits) {
        const d = Math.max(0, Math.min(10, Number(digits) || 0))
        const n = Number(value)
        return Number.isFinite(n) ? n.toFixed(d) : "--"
    }

    function rebuildTagIdsModel() {
        const v = vehicle
        if (!v || !v.geopixelDetections) {
            tagIdsModel = []
            return
        }

        const arr = []
        const list = v.geopixelDetections
        for (let i = 0; i < list.count; i++) {
            const det = list.get(i)
            if (det && det.objectId !== undefined && det.objectId !== null) {
                arr.push(det.objectId)
            }
        }

        tagIdsModel = Array.from(new Set(arr)).sort((a,b) => a-b)
    }

    onVehicleChanged: rebuildTagIdsModel()

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: root.rebuildTagIdsModel()
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth

        readonly property real hSpacing: ScreenTools.defaultFontPixelWidth
        readonly property real vSpacing: ScreenTools.defaultFontPixelHeight * 0.2
        readonly property real cellWidth: (width - (hSpacing * (root.windowColumns - 1))) / root.windowColumns

        Grid {
            id: grid
            anchors.fill: parent

            columns: root.windowColumns
            columnSpacing: content.hSpacing
            rowSpacing: content.vSpacing

            // ROW 0: ComboBox selecting
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Tag:")
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.selectedTagId >= 0 ? String(root.selectedTagId) : "--"
            }

            Item {
                id: comboCell
                width: content.cellWidth
                height: ScreenTools.defaultFontPixelHeight * 1.6
                clip: true
                z: 1000

                // Allow clicks for ComboBox
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    propagateComposedEvents: true
                    onPressed:  mouse.accepted = false
                    onClicked:  mouse.accepted = false
                }

                QGCComboBox {
                    id: tagCombo
                    anchors.fill: parent

                    model: root.tagIdsModel
                    enabled: root.tagIdsModel.length > 0

                    Connections {
                        target: root.vehicle
                        function onSelectedGeopixelObjectIdChanged() {
                            if (!root.vehicle) return
                            const idx = root.tagIdsModel.indexOf(root.vehicle.selectedGeopixelObjectId)
                            if (idx >= 0 && tagCombo.currentIndex !== idx) {
                                tagCombo.currentIndex = idx
                            }
                        }
                    }

                    onActivated: {
                        if (!root.vehicle) return
                        if (currentIndex >= 0 && currentIndex < root.tagIdsModel.length) {
                            const id = root.tagIdsModel[currentIndex]
                            root.vehicle.selectedGeopixelObjectId = id
                            root.selectedTagId = id
                            root.updateComboDet()
                        }
                    }
                }
            }

            // Header row
            QGCLabel { width: content.cellWidth; horizontalAlignment: Text.AlignHCenter; text: qsTr("Lat:") }
            QGCLabel { width: content.cellWidth; horizontalAlignment: Text.AlignHCenter; text: qsTr("Lon:") }
            QGCLabel { width: content.cellWidth; horizontalAlignment: Text.AlignHCenter; text: qsTr("Height:") }

            // Row 1: USER3
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.user3LatFact ? root.formatNumber(root.user3LatFact.rawValue, root.coordinatePrecision) : "--"
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.user3LonFact ? root.formatNumber(root.user3LonFact.rawValue, root.coordinatePrecision) : "--"
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.user3DataFact ? root.formatNumber(root.user3DataFact.rawValue, 1) : "--"
            }

            // Row 2: USER 4
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.comboCoord ? root.formatNumber(root.comboCoord.latitude, root.coordinatePrecision) : "--"
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.comboCoord ? root.formatNumber(root.comboCoord.longitude, root.coordinatePrecision) : "--"
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.comboDet ? root.formatNumber(root.comboDet.altitude, 1) : "--"
            }
        }
    }
}
