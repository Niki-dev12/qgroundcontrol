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

    readonly property string _noCompassPath:
        "qrc:/qml/QGroundControl/FlightMap/Widgets/AGLIndicator.qml"
    property var _instrumentFact: QGroundControl.settingsManager.flyViewSettings.instrumentQmlFile2

    readonly property bool instrumentOnTop:
        _instrumentFact && _instrumentFact.rawValue === _noCompassPath
    property real telemetryBarHeight: instrumentOnTop
                                      ? (telemetryBarVertical.visible   ? telemetryBarVertical.height   : 0)
                                      : (telemetryBarHorizontal.visible ? telemetryBarHorizontal.height : 0)


    ColumnLayout {
        id: verticalLayout

        // This whole column is treated as one child in the RowLayout
        Layout.alignment: Qt.AlignRight | Qt.AlignBottom
        Layout.fillWidth: true
        visible:          bottomRightRowLayout.instrumentOnTop

        FlyViewInstrumentPanel {
            id:                 instrumentPanelVertical
            Layout.alignment:   Qt.AlignRight | Qt.AlignBottom
            Layout.fillWidth:   true

            visible:            QGroundControl.corePlugin.options.flyView.showInstrumentPanel
                                && _showSingleVehicleUI
        }

        TelemetryValuesBar {
            id: telemetryBarVertical
            Layout.alignment:   Qt.AlignRight | Qt.AlignBottom
            Layout.fillWidth:   true

            extraWidth:             instrumentPanelVertical.extraValuesWidth
            settingsGroup:          factValueGrid.telemetryBarSettingsGroup
            specificVehicleForCard: null
        }
    }

    TelemetryValuesBar {
        id: telemetryBarHorizontal
        visible:          !bottomRightRowLayout.instrumentOnTop
        Layout.alignment: Qt.AlignBottom

        extraWidth:             instrumentPanelHorizontal.extraValuesWidth
        settingsGroup:          factValueGrid.telemetryBarSettingsGroup
        specificVehicleForCard: null
    }

    FlyViewInstrumentPanel {
        id:                 instrumentPanelHorizontal
        visible:            !bottomRightRowLayout.instrumentOnTop
                            && QGroundControl.corePlugin.options.flyView.showInstrumentPanel
                            && _showSingleVehicleUI
        Layout.alignment:   Qt.AlignBottom
    }
}
