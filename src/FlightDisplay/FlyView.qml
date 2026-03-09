/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controllers
import QGroundControl.Controls
import QGroundControl.FactSystem
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.Palette
import QGroundControl.ScreenTools
import QGroundControl.Vehicle

// 3D Viewer modules
import Viewer3D

Item {
    id: _root

    // These should only be used by MainRootWindow
    property var planController:    _planController
    property var guidedController:  _guidedController

    // Properties of UTM adapter
    property bool utmspSendActTrigger: false

    PlanMasterController {
        id:                     _planController
        flyView:                true
        Component.onCompleted:  start()
    }

    property bool   _mainWindowIsMap:       mapControl.pipState.state === mapControl.pipState.fullState
    property bool   _isFullWindowItemDark:  _mainWindowIsMap ? mapControl.isSatelliteMap : true
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _missionController:     _planController.missionController
    property var    _geoFenceController:    _planController.geoFenceController
    property var    _rallyPointController:  _planController.rallyPointController
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property var    _guidedController:      guidedActionsController
    property var    _guidedValueSlider:     guidedValueSlider
    property var    _widgetLayer:           widgetLayer
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    property rect   _centerViewport:        Qt.rect(0, 0, width, height)
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 30
    property var    _mapControl:            mapControl

    property real   _fullItemZorder:    0
    property real   _pipItemZorder:     QGroundControl.zOrderWidgets

    readonly property real _layoutMargin: ScreenTools.defaultFontPixelWidth
    readonly property real _layoutSpacing: ScreenTools.defaultFontPixelWidth / 2

    //FPV
    // Base unit that follows QGC scaling (DPI/font scaling)
    readonly property real _u: ScreenTools.defaultFontPixelHeight

    // Strip width scales with UI
    readonly property real _edgeStripWidth: Math.max(_u * 2.6, 40)

    // Button geometry scales with UI
    readonly property real _edgeBtnSize:    Math.max(_u * 2.2, 36)
    readonly property real _edgeBtnWidthMul: 2.8

    readonly property real _edgeBtnPad:     Math.max(_u * 0.10, 2)
    readonly property real _edgeBtnFont:    Math.max(_u * 1.05, 14)

    // Spacing & offsets scale with UI
    readonly property real _edgeSpacing:    Math.max(_u * 0.55, 10)
    readonly property real _edgeXInset:     Math.max(_u * 1.2, 20)
    readonly property real _edgeYInset:     Math.max(_u * 1.2, 20)
    readonly property real _edgeRotateShiftLeft:  Math.max(_u * 1.2, 20)
    readonly property real _edgeRotateShiftRight: Math.max(_u * 0.6, 12)

    readonly property real _edgeTopMarginLeft:  Math.max(_u * 1.2, 20)
    readonly property real _edgeTopMarginRight: Math.max(_u * 0.8, 16)
    readonly property real _edgeSlotHeight: _edgeBtnSize + _edgeSpacing

    readonly property int uiLayout: QGroundControl.settingsManager.appSettings.uiLayout.rawValue
    readonly property bool _isFPVLayout: QGroundControl.settingsManager.appSettings.uiLayout.rawValue === 2
    //FPV

    function _calcCenterViewPort() {
        var newToolInset = Qt.rect(0, 0, width, height)
        toolstrip.adjustToolInset(newToolInset)
    }

    function dropMainStatusIndicatorTool() {
        toolbar.dropMainStatusIndicatorTool();
    }

    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeBottomInset:    _pipView.leftEdgeBottomInset
        bottomEdgeLeftInset:    _pipView.bottomEdgeLeftInset
    }

    FlyViewToolBar {
        id:         toolbar
        visible:    !QGroundControl.videoManager.fullScreen
    }

    //FPV
    // LEFT EDGE
    Rectangle {
        id: leftEdge
        z: 999
        visible: _isFPVLayout
        color: edgeColor

        width: _edgeStripWidth
        height: parent.height
        anchors.left: parent.left
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        clip: false

        property var buttonActions: [
            { label: "AI Strike",   command: 31055, param1: 0, isToggle: true },
            { label: "Visual Nav",  command: 31056, param1: 0, isToggle: true },
            { label: "Auto Rec",    command: 31057, param1: 0, isToggle: true },
            { label: "Dataset Acq", command: 31058, param1: 0, isToggle: true },
            { label: "Show HUD",    command: 31059, param1: 1, isToggle: true, handler: "hudVisibility" }
        ]

        function sendCommand(command, param1, isToggle, enabled, handler) {
            const vehicle = QGroundControl.multiVehicleManager.activeVehicle
            if (!vehicle) return
            vehicle.onSidePanelButtonClicked(command, param1, isToggle, enabled)

            if (handler === "hudVisibility") {
                vehicle.toggleHudVisibility(enabled)
            }
        }

        readonly property real _compactSpacing: Math.max(_u * 0.18, 4)
        // slot height must match the rotated height === original width
        // readonly property real _slotH: (_edgeBtnSize * _edgeBtnWidthMul) + (_edgeBtnPad * 1.0)
        readonly property real _slotH: (_edgeBtnSize * _edgeBtnWidthMul)

        Component {
            id: toggleButtonComponent1
            QGCButton {
                id: btn
                width:  _edgeBtnSize * _edgeBtnWidthMul
                height: _edgeBtnSize
                padding: _edgeBtnPad
                font.pixelSize: _edgeBtnFont
                checkable: true

                transform: Rotation {
                    origin.x: btn.width  / 2
                    origin.y: btn.height / 2
                    angle: 270
                }

                property var v: QGroundControl.multiVehicleManager.activeVehicle

                checked: buttonConfig.handler === "hudVisibility"
                    ? (v ? v.hudVisible : false)
                    : (buttonConfig.command === 31055 && v
                            ? v.aiStrike
                            : (buttonConfig.param1 === 1))

                text: buttonConfig.handler === "hudVisibility"
                        ? (checked ? "Hide HUD" : "Show HUD")
                        : buttonConfig.label

                onClicked: {
                    if (v && buttonConfig.handler === "hudVisibility") {
                        v.setHudVisible(!v.hudVisible)
                        return
                    }
                    if (v && buttonConfig.command === 31055) { // AI Strike
                        v.setAIStrike(!v.aiStrike)
                        return
                    }
                    leftEdge.sendCommand(buttonConfig.command,buttonConfig.param1 || 0,true,checked,buttonConfig.handler)
                }

                Component.onCompleted: {
                    if (buttonConfig.handler !== "hudVisibility"
                                && buttonConfig.command !== 31055
                                && checked) {

                        leftEdge.sendCommand(
                            buttonConfig.command,
                            buttonConfig.param1 || 0,
                            true,
                            checked,
                            buttonConfig.handler
                        )
                    }
                }
            }
        }

        Component {
            id: normalButtonComponent1
            QGCButton {
                id: btn
                width:  _edgeBtnSize * _edgeBtnWidthMul
                height: _edgeBtnSize
                padding: _edgeBtnPad
                font.pixelSize: _edgeBtnFont
                text: buttonConfig.label

                transform: Rotation {
                    origin.x: btn.width  / 2
                    origin.y: btn.height / 2
                    angle: 270
                }

                onClicked: leftEdge.sendCommand(
                    buttonConfig.command,
                    buttonConfig.param1 || 0,
                    false,
                    true,
                    buttonConfig.handler
                )
            }
        }

        Column {
            id: columnleft
            width: parent.width
            spacing: _compactSpacing
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 0  //Math.max(_u * 0.8, 12)

            Repeater {
                model: leftEdge.buttonActions

                Item {
                    width: columnleft.width
                    height: leftEdge._slotH

                    Loader {
                        anchors.centerIn: parent
                        property var buttonConfig: modelData
                        sourceComponent: modelData.isToggle ? toggleButtonComponent1 : normalButtonComponent1
                    }
                }
            }
        }
    }

    // RIGHT EDGE
    Rectangle {
        id: rightEdge
        z: 999
        visible: _isFPVLayout
        color: edgeColor

        width: _edgeStripWidth
        height: parent.height
        anchors.right: parent.right
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        clip: false

        property var buttonActions: [
            { label: "Tracker Type", command: 31053, param1: 0, isToggle: true },
            { label: "Select Mode",  command: 31054, param1: 1, isToggle: true },
            { label: "Engage",       command: 31052 },
            { label: "Track",        command: 31051 },
            { label: "Cancel",       command: 31050 }
        ]

        function sendCommand(command, param1, isToggle, enabled) {
            const v = QGroundControl.multiVehicleManager.activeVehicle
            if (v) v.onSidePanelButtonClicked(command, param1, isToggle, enabled)
        }

        readonly property real _compactSpacing: Math.max(_u * 0.18, 4)
        readonly property real _slotH: (_edgeBtnSize * _edgeBtnWidthMul)  // + (_edgeBtnPad * 1.0)

        Component {
            id: toggleButtonComponent
            QGCButton {
                id: btn
                width:  _edgeBtnSize * _edgeBtnWidthMul
                height: _edgeBtnSize
                padding: _edgeBtnPad
                font.pixelSize: _edgeBtnFont

                text: buttonConfig.label
                checkable: true

                transform: Rotation {
                    origin.x: btn.width  / 2
                    origin.y: btn.height / 2
                    angle: 90
                }

                property var v: QGroundControl.multiVehicleManager.activeVehicle

                checked: (buttonConfig.command === 31053 && v)
                    ? v.currentTrackerTypeValue
                    : (buttonConfig.command === 31054 && v)
                        ? v.currentSelectModeValue
                        : (buttonConfig.param1 === 1)

                onClicked: {
                    if (v && buttonConfig.command === 31053) {
                        v.setTrackerType(!v.currentTrackerTypeValue)
                        return
                    }
                    if (v && buttonConfig.command === 31054) {
                        v.setSelectMode(!v.currentSelectModeValue)
                        return
                    }
                    rightEdge.sendCommand(
                        buttonConfig.command,
                        buttonConfig.param1 || 0,
                        buttonConfig.isToggle || 0,
                        checked
                    )
                }

                // Prevent double-send for 31053
                onCheckedChanged: {
                    if (buttonConfig.command === 31053) return
                    if (buttonConfig.command === 31054) return
                    rightEdge.sendCommand(
                        buttonConfig.command,
                        buttonConfig.param1 || 0,
                        buttonConfig.isToggle || 0,
                        checked
                    )
                }
            }
        }

        Component {
            id: normalButtonComponent
            QGCButton {
                id: btn
                width:  _edgeBtnSize * _edgeBtnWidthMul
                height: _edgeBtnSize
                padding: _edgeBtnPad
                font.pixelSize: _edgeBtnFont

                text: buttonConfig.label

                transform: Rotation {
                    origin.x: btn.width  / 2
                    origin.y: btn.height / 2
                    angle: 90
                }

                onClicked: rightEdge.sendCommand(
                    buttonConfig.command,
                    buttonConfig.param1 || 0,
                    false,
                    true
                )
            }
        }

        Column {
            id: columnright
            width: parent.width
            spacing: _compactSpacing
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 0    //Math.max(_u * 0.8, 12)

            Repeater {
                model: rightEdge.buttonActions

                Item {
                    width: columnright.width
                    height: rightEdge._slotH

                    Loader {
                        anchors.centerIn: parent
                        property var buttonConfig: modelData
                        sourceComponent: modelData.isToggle ? toggleButtonComponent : normalButtonComponent
                    }
                }
            }
        }
    }
    //FPV

    Item {
        id:                 mapHolder
        anchors.top:        toolbar.bottom
        anchors.bottom:     parent.bottom
        anchors.left:  _isFPVLayout ? leftEdge.right  : parent.left  //FPV
        anchors.right: _isFPVLayout ? rightEdge.left : parent.right  //FPV

        FlyViewMap {
            id:                     mapControl
            planMasterController:   _planController
            rightPanelWidth:        ScreenTools.defaultFontPixelHeight * 9
            pipView:                _pipView
            pipMode:                !_mainWindowIsMap
            toolInsets:             customOverlay.totalToolInsets
            mapName:                "FlightDisplayView"
            enabled:                !viewer3DWindow.isOpen
        }

        FlyViewVideo {
            id:         videoControl
            pipView:    _pipView

            telemetryBottomInset: (
                widgetLayer.visible
                ? (widgetLayer.bottomRightRowLayout.telemetryBarHeight + _layoutMargin)
                : 0
            )

                property bool _minRaw: (_pipView && _pipView.show && !QGroundControl.videoManager.fullScreen)

                property bool videoMinimized: false

                Timer {
                    id: _minDebounce
                    interval: 150
                    repeat: false
                    onTriggered: {
                        if (videoControl.videoMinimized !== videoControl._minRaw) {
                            videoControl.videoMinimized = videoControl._minRaw
                            console.log("[FlyViewVideo] videoMinimized ->", videoControl.videoMinimized)
                        }
                    }
                }
                on_MinRawChanged: _minDebounce.restart()

        }

        PipView {
            id:                     _pipView
            anchors.left:           parent.left
            anchors.bottom:         parent.bottom
            anchors.margins:        _toolsMargin
            item1IsFullSettingsKey: "MainFlyWindowIsMap"
            item1:                  mapControl
            item2:                  QGroundControl.videoManager.hasVideo ? videoControl : null
            show:                   QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.fullScreen &&
                                        (videoControl.pipState.state === videoControl.pipState.pipState || mapControl.pipState.state === mapControl.pipState.pipState)
            z:                      QGroundControl.zOrderWidgets

            property real leftEdgeBottomInset: visible ? width + anchors.margins : 0
            property real bottomEdgeLeftInset: visible ? height + anchors.margins : 0
        }

        FlyViewWidgetLayer {
            id:                     widgetLayer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            z:                      _fullItemZorder + 2 // we need to add one extra layer for map 3d viewer (normally was 1)
            parentToolInsets:       _toolInsets
            mapControl:             _mapControl
            visible:                !QGroundControl.videoManager.fullScreen
            utmspActTrigger:        utmspSendActTrigger
            isViewer3DOpen:         viewer3DWindow.isOpen
        }

        FlyViewCustomLayer {
            id:                 customOverlay
            anchors.fill:       widgetLayer
            z:                  _fullItemZorder + 2
            parentToolInsets:   widgetLayer.totalToolInsets
            mapControl:         _mapControl
            visible:            !QGroundControl.videoManager.fullScreen
        }

        // Development tool for visualizing the insets for a paticular layer, show if needed
        FlyViewInsetViewer {
            id:                     widgetLayerInsetViewer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            z:                      widgetLayer.z + 1
            insetsToView:           widgetLayer.totalToolInsets
            visible:                false
        }

        GuidedActionsController {
            id:                 guidedActionsController
            missionController:  _missionController
            guidedValueSlider:     _guidedValueSlider
        }

        //-- Guided value slider (e.g. altitude)
        GuidedValueSlider {
            id:                 guidedValueSlider
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            z:                  QGroundControl.zOrderTopMost
            visible:            false
        }

        Viewer3D{
            id:                     viewer3DWindow
            anchors.fill:           parent
        }
    }
}
