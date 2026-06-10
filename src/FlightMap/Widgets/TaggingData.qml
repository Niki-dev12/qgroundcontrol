/****************************************************************************
 *
 *  TaggingData.qml
 *  Instrument-style widget for selected tagging data.
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

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle

    readonly property var user3LatFact:  vehicle ? vehicle.user3Lat  : null
    readonly property var user3LonFact:  vehicle ? vehicle.user3Lon  : null
    readonly property var user3DataFact: vehicle ? vehicle.user3Data : null

    property var tagIdsModel: []
    property int selectedTagId: -1
    property var selectedTagDetection: null

    function updateSelectedTagDetection() {
        selectedTagDetection = null
        if (!vehicle || selectedTagId < 0 || !vehicle.geopixelDetections) {
            return
        }

        const detections = vehicle.geopixelDetections
        for (let detectionIndex = 0; detectionIndex < detections.count; detectionIndex++) {
            const detection = detections.get(detectionIndex)
            if (detection && detection.objectId === selectedTagId) {
                selectedTagDetection = detection
                return
            }
        }
    }

    Connections {
        target: root.vehicle

        function onSelectedGeopixelObjectIdChanged() {
            if (!root.vehicle) {
                return
            }

            root.selectedTagId = root.vehicle.selectedGeopixelObjectId
            root.updateSelectedTagDetection()

            const selectedTagIndex = root.tagIdsModel.indexOf(root.selectedTagId)
            if (selectedTagIndex >= 0 && tagCombo.currentIndex !== selectedTagIndex) {
                tagCombo.currentIndex = selectedTagIndex
            }
        }
    }

    Component.onCompleted: {
        if (vehicle) {
            selectedTagId = vehicle.selectedGeopixelObjectId
            updateSelectedTagDetection()
        }
    }

    readonly property var selectedTagCoordinate: (selectedTagDetection && selectedTagDetection.coordinate && selectedTagDetection.coordinate.isValid)
                                                ? selectedTagDetection.coordinate
                                                : null

    QGCPalette {
        id: palette
        colorGroupEnabled: true
    }

    color: palette.window
    border.color: palette.text
    radius: ScreenTools.defaultFontPixelHeight * 0.5

    function formatNumber(value, digits) {
        const boundedDigits = Math.max(0, Math.min(10, Number(digits) || 0))
        const numericValue = Number(value)
        return Number.isFinite(numericValue) ? numericValue.toFixed(boundedDigits) : "--"
    }

    function rebuildTagIdsModel() {
        const activeVehicle = vehicle
        if (!activeVehicle || !activeVehicle.geopixelDetections) {
            tagIdsModel = []
            return
        }

        const tagIds = []
        const detections = activeVehicle.geopixelDetections
        for (let detectionIndex = 0; detectionIndex < detections.count; detectionIndex++) {
            const detection = detections.get(detectionIndex)
            if (detection && detection.objectId !== undefined && detection.objectId !== null) {
                tagIds.push(detection.objectId)
            }
        }

        tagIdsModel = Array.from(new Set(tagIds)).sort((leftTagId, rightTagId) => leftTagId - rightTagId)
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
                            if (!root.vehicle) {
                                return
                            }

                            const selectedTagIndex = root.tagIdsModel.indexOf(root.vehicle.selectedGeopixelObjectId)
                            if (selectedTagIndex >= 0 && tagCombo.currentIndex !== selectedTagIndex) {
                                tagCombo.currentIndex = selectedTagIndex
                            }
                        }
                    }

                    onActivated: {
                        if (!root.vehicle) {
                            return
                        }

                        if (currentIndex >= 0 && currentIndex < root.tagIdsModel.length) {
                            const selectedTagId = root.tagIdsModel[currentIndex]
                            root.vehicle.selectedGeopixelObjectId = selectedTagId
                            root.selectedTagId = selectedTagId
                            root.updateSelectedTagDetection()
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
                text: root.selectedTagCoordinate ? root.formatNumber(root.selectedTagCoordinate.latitude, root.coordinatePrecision) : "--"
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.selectedTagCoordinate ? root.formatNumber(root.selectedTagCoordinate.longitude, root.coordinatePrecision) : "--"
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.selectedTagDetection ? root.formatNumber(root.selectedTagDetection.altitude, 1) : "--"
            }
        }
    }
}
