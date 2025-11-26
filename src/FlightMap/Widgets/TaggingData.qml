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

    implicitWidth:  ScreenTools.defaultFontPixelHeight * 12
    implicitHeight: ScreenTools.defaultFontPixelHeight * 2.8
    width:          implicitWidth
    height:         implicitHeight

    property real extraInset:       0
    property real extraValuesWidth: implicitWidth

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    color:       qgcPal.window
    border.color:qgcPal.text
    radius:      ScreenTools.defaultFontPixelHeight * 0.5

    function fmt(value, digits) {
        return (value === undefined || value === null || isNaN(value))
                ? "--"
                : Number(value).toFixed(digits)
    }

    Column {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.2

        // -------------------------
        // ROW 1: STATIC LABEL HEADERS
        // -------------------------
        
        Row {
            width: parent.width
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                width: parent.width / 3
                horizontalAlignment: Text.AlignHCenter
                text: "Lat"
            }

            QGCLabel {
                width: parent.width / 3
                horizontalAlignment: Text.AlignHCenter
                text: "Lon"
            }

            QGCLabel {
                width: parent.width / 3
                horizontalAlignment: Text.AlignHCenter
                text: "Dist"
            }
        }

        // -------------------------
        // ROW 2: EXISTING VALUES
        // -------------------------
        Row {
            width: parent.width
            spacing: ScreenTools.defaultFontPixelWidth

            // LAT VALUE
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

            // LON VALUE
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

            // DIST VALUE (was specialData)
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
    }

}
