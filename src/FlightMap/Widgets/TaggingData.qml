/****************************************************************************
 *
 *  SpatialUser4Instrument.qml
 *  Instrument-style widget for specialLat / specialLon / specialData
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
    implicitHeight: ScreenTools.defaultFontPixelHeight * 4
    width:          implicitWidth
    height:         implicitHeight

    readonly property int windowColumns: 3
    readonly property int coordinatePrecision: 5
    property bool debug: false

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle

    readonly property int selectedTagId: vehicle ? vehicle.selectedGeopixelObjectId : -1
    readonly property var selectedDet:   vehicle ? vehicle.geopixelDetectionById(selectedTagId) : null

    readonly property var specialLatFact:  vehicle ? vehicle.specialLat  : null
    readonly property var specialLonFact:  vehicle ? vehicle.specialLon  : null
    readonly property var specialDataFact: vehicle ? vehicle.specialData : null

    readonly property var selCoord: (selectedDet && selectedDet.coordinate && selectedDet.coordinate.isValid)
                                    ? selectedDet.coordinate
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

            // Header row defines the columns
            QGCLabel { width: content.cellWidth; horizontalAlignment: Text.AlignHCenter; text: qsTr("Lat:") }
            QGCLabel { width: content.cellWidth; horizontalAlignment: Text.AlignHCenter; text: qsTr("Lon:") }
            QGCLabel { width: content.cellWidth; horizontalAlignment: Text.AlignHCenter; text: qsTr("Height:") }

            // Row 1: current coordinate data
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.specialLatFact ? root.formatNumber(root.specialLatFact.rawValue, root.coordinatePrecision) : "--"
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.specialLonFact ? root.formatNumber(root.specialLonFact.rawValue, root.coordinatePrecision) : "--"
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.specialDataFact ? root.formatNumber(root.specialDataFact.rawValue, 1) : "--"
            }

            // Row 2: selected detection coordinate
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.selCoord ? root.formatNumber(root.selCoord.latitude, root.coordinatePrecision) : "--"
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.selCoord ? root.formatNumber(root.selCoord.longitude, root.coordinatePrecision) : "--"
            }
            QGCLabel {
                width: content.cellWidth
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                // Again: label and units must match. This shows altitude currently.
                text: root.selectedDet ? root.formatNumber(root.selectedDet.altitude, 1) : "--"
            }
        }
    }

    onSelectedTagIdChanged: if (debug) console.log("[TaggingData] selectedTagId =", selectedTagId)
    onSelectedDetChanged:   if (debug) console.log("[TaggingData] selectedDet =", selectedDet)
}
