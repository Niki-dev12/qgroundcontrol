/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay

RowLayout {
    id: bottomRightRowLayout

    property real bottomEdgeRightInset:  height + _layoutMargin
    property real bottomEdgeCenterInset: bottomEdgeRightInset
    property real rightEdgeBottomInset:  width + _layoutMargin
    property real telemetryBarHeight: (telemetryBar.visible ? telemetryBar.height : 0)

    TelemetryValuesBar {
        id: telemetryBar
        Layout.alignment:       Qt.AlignBottom
        extraWidth:             instrumentPanel.extraValuesWidth
        settingsGroup:          factValueGrid.telemetryBarSettingsGroup
        specificVehicleForCard: null // Tracks active vehicle
    }

    FlyViewInstrumentPanel {
        id:                 instrumentPanel
        Layout.alignment:   Qt.AlignBottom
        visible:            QGroundControl.corePlugin.options.flyView.showInstrumentPanel && _showSingleVehicleUI
    }
}
