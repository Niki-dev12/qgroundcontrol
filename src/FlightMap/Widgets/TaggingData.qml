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
import QGroundControl.Vehicle
import QGroundControl.Palette

Rectangle {
    id: instrumentRoot

    implicitWidth:  ScreenTools.defaultFontPixelHeight * 12
    implicitHeight: ScreenTools.defaultFontPixelHeight * 2.8
    width:          implicitWidth
    height:         implicitHeight

    property real extraInset:       0
    property real extraValuesWidth: implicitWidth
    readonly property int  windowWidthFactor:       3
    readonly property int  coordinatePrecision:     5

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle

    QGCPalette {
        id: qgcPalette
        colorGroupEnabled: true
    }

    color:        qgcPalette.window
    border.color: qgcPalette.text
    radius:       ScreenTools.defaultFontPixelHeight * 0.5

    function formatValue(numericValue, digitsCount) {
        if (numericValue === undefined || numericValue === null || isNaN(numericValue)) {
            return "--"
        }
        return Number(numericValue).toFixed(digitsCount)
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
                width: parent.width / windowWidthFactor
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Lat:")
            }

            QGCLabel {
                width: parent.width / windowWidthFactor
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Lon:")
            }

            QGCLabel {
                width: parent.width / windowWidthFactor
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Dist:")
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
                width: parent.width / windowWidthFactor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                text: formatValue(
                          instrumentRoot.vehicle && instrumentRoot.vehicle.specialLat
                              ? instrumentRoot.vehicle.specialLat.rawValue
                              : NaN,
                          coordinatePrecision
                      )
            }

            // LON VALUE
            QGCLabel {
                width: parent.width / windowWidthFactor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                text: formatValue(
                          instrumentRoot.vehicle && instrumentRoot.vehicle.specialLon
                              ? instrumentRoot.vehicle.specialLon.rawValue
                              : NaN,
                          coordinatePrecision
                      )
            }

            // DIST VALUE
            QGCLabel {
                width: parent.width / windowWidthFactor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                text: formatValue(
                          instrumentRoot.vehicle && instrumentRoot.vehicle.specialData
                              ? instrumentRoot.vehicle.specialData.rawValue
                              : NaN,
                          1
                      )
            }
        }
    }
}
