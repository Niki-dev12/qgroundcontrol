/****************************************************************************
 *
 *  SpatialUser3Instrument.qml
 *  Instrument-style widget for specialLat / specialLon / specialData
 *
 ****************************************************************************/

import QtQuick
import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.Vehicle
import QGroundControl.Palette

Rectangle {
    id: control

    // --- Instrument sizing & contract ---
    implicitWidth:  ScreenTools.defaultFontPixelHeight * 12
    implicitHeight: ScreenTools.defaultFontPixelHeight * 2
    width:          implicitWidth
    height:         implicitHeight

    // FlyViewInstrumentPanel expects these:
    property real extraInset:       0
    property real extraValuesWidth: implicitWidth

    // Active vehicle
    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle

    // Local palette used for colors
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    color:       qgcPal.window
    border.color:qgcPal.text
    radius:      ScreenTools.defaultFontPixelHeight * 0.5

    // ---- Helper ----
    function fmt(value, digits) {
        return (value === undefined || value === null || isNaN(value))
                ? "--"
                : Number(value).toFixed(digits)
    }

    Row {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelWidth

        // LAT
        QGCLabel {
            width: parent.width / 3
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
            text: fmt(
                control.vehicle && control.vehicle.specialLat
                    ? control.vehicle.specialLat.rawValue
                    : NaN,
                4
            )
        }

        // LON
        QGCLabel {
            width: parent.width / 3
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
            text: fmt(
                control.vehicle && control.vehicle.specialLon
                    ? control.vehicle.specialLon.rawValue
                    : NaN,
                4
            )
        }

        // SPECIAL
        QGCLabel {
            width: parent.width / 3
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
            text: fmt(
                control.vehicle && control.vehicle.specialData
                    ? control.vehicle.specialData.rawValue
                    : NaN,
                1
            )
        }
    }

    Component.onCompleted: {
        console.log("[SpatialUser3Instrument] vehicle =", control.vehicle)
        if (control.vehicle) {
            console.log("[SpatialUser3Instrument] specialLat  =", control.vehicle.specialLat)
            console.log("[SpatialUser3Instrument] specialLon  =", control.vehicle.specialLon)
            console.log("[SpatialUser3Instrument] specialData =", control.vehicle.specialData)
        }
    }
}
