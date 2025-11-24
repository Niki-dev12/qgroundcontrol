/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGC.Terrain 1.0     // for TerrainAheadSampler

Item {
    id: root
    implicitWidth:  _totalRadius * 4
    implicitHeight: implicitWidth / 2

    property real compassRadius:        ScreenTools.defaultFontPixelHeight * 6 / 2
    property real attitudeAngleDegrees: 0

    property real attitudeSize:         ScreenTools.defaultFontPixelHeight * 0.75
    property real attitudeSpacing:      ScreenTools.defaultFontPixelHeight / 4

    property real _totalRadius:             compassRadius + attitudeSpacing + attitudeSize
    property real _attitudeRadius:          (width / 2) - (attitudeSize / 2)
    property real _maxAngleDegrees:         30
    property real _maxRadians:              _maxAngleDegrees * Math.PI / 180
    property real _zeroAttitudeRadians:     Math.PI * 1.5
    property real _clampedAngleDegrees:     Math.min(Math.max(attitudeAngleDegrees, -_maxAngleDegrees), _maxAngleDegrees)
    property real _attitudeAnglePercent:    _clampedAngleDegrees / _maxAngleDegrees

    property var  qgcPal:   QGroundControl.globalPalette
    property var  vehicle:  QGroundControl.multiVehicleManager.activeVehicle

    on_AttitudeAnglePercentChanged: angleIndicator.requestPaint()

    readonly property string _noCompassPath:
        "qrc:/qml/QGroundControl/FlightMap/Widgets/AGLIndicator.qml"

    property var _instrumentFact: QGroundControl.settingsManager.flyViewSettings.instrumentQmlFile2

    // -----------------------------------------------------------
    //  TerrainAheadProfile component (local)
    // -----------------------------------------------------------
    component TerrainAheadProfile : Item {
        id: terrainRoot

        property var  vehicle
        property real aheadDistanceM: 500
        property real stepM: 25
        property real warnAGLM: 20
        property real warnUnderAGLM: 10
        property int  hz: 4

        property color cLine:     "#11C900"
        property color cFill:     "#0e3420"
        property color cWarn:     "#ff6b6b"
        property color cText:     "#ffffff"
        property color cVehicle:  "#ADFF2F"

        property color cWarnUnder: "#ff3b30"
        property color cWarnAhead: "#ff9500"
        property real  warnAheadAGLM: 10

        implicitWidth:  0
        implicitHeight: 0

        function _finite(n) { return Number.isFinite(n) }
        function _val(x) {
            if (x === undefined || x === null) return NaN
            if (typeof x === "number") return x
            if (x && typeof x.value === "number") return x.value
            if (x && typeof x.rawValue === "number") return x.rawValue
            return NaN
        }

        property real latNow:     _val(vehicle ? vehicle.latitude         : NaN)
        property real lonNow:     _val(vehicle ? vehicle.longitude        : NaN)
        property real altAMSLNow: _val(vehicle ? vehicle.altitudeAMSL     : NaN)
        property real altRelNow:  _val(vehicle ? vehicle.altitudeRelative : NaN)
        property real hdgNow: {
            if (!vehicle) return NaN
            const h = _val(vehicle.heading)
            return _finite(h) ? ((h % 360) + 360) % 360 : NaN
        }

        TerrainAheadSampler {
            id: sampler
            vehicle:             terrainRoot.vehicle
            aheadDistanceMeters: terrainRoot.aheadDistanceM
            hz:                  terrainRoot.hz
        }

        readonly property real aglNow: {
            const t = sampler.terrainNowAMSL
            if (_finite(t) && _finite(altAMSLNow)) return altAMSLNow - t
            if (_finite(altRelNow)) return altRelNow
            return NaN
        }

        // RED: danger directly under drone
        readonly property bool dangerUnder: _finite(aglNow) && aglNow < warnUnderAGLM

        // ORANGE: danger somewhere ahead
        readonly property bool dangerAhead: {
            const pts = sampler.points || []
            if (!_finite(altAMSLNow) || !pts.length) return false

            const minSkipDist = 5
            for (let i = 0; i < pts.length; i++) {
                const p = pts[i]
                if (!_finite(p.elevAMSL)) continue
                if (p.d <= minSkipDist) continue

                const agl = altAMSLNow - p.elevAMSL
                if (_finite(agl) && agl < warnAheadAGLM) {
                    return true
                }
            }
            return false
        }

        property real _minH: NaN
        property real _maxH: NaN

        function _computeYFromAMSL(h, top, bot) {
            if (!_finite(_minH) || !_finite(_maxH) || _maxH <= _minH) return bot
            return bot - (h - _minH) * (bot - top) / Math.max(1, (_maxH - _minH))
        }

        function _rewindow() {
            const pts = sampler.points || []
            let minH = +1e12, maxH = -1e12
            for (let i=0; i<pts.length; i++) {
                const e = pts[i].elevAMSL
                if (_finite(e)) {
                    if (e < minH) minH = e
                    if (e > maxH) maxH = e
                }
            }
            if (_finite(altAMSLNow)) {
                if (altAMSLNow < minH) minH = altAMSLNow
                if (altAMSLNow > maxH) maxH = altAMSLNow
            }
            if (!Number.isFinite(minH) || !Number.isFinite(maxH)) { minH = 0; maxH = 100 }

            const span = Math.max(60, maxH - minH)
            const pad  = Math.max(30, span * 0.25)
            _minH = minH - pad
            _maxH = maxH + pad
            canvas.requestPaint()
        }

        onLatNowChanged:     sampler.resample && sampler.resample()
        onLonNowChanged:     sampler.resample && sampler.resample()
        onHdgNowChanged:     sampler.resample && sampler.resample()
        onAltAMSLNowChanged: canvas.requestPaint()

        Connections {
            target: sampler
            ignoreUnknownSignals: true
            function onPointsChanged()         { _rewindow() }
            function onTerrainNowAMSLChanged() { canvas.requestPaint() }
        }

        Timer {
            interval: Math.max(120, 1000/hz)
            repeat: true
            running: terrainRoot.visible
            onTriggered: { sampler.resample && sampler.resample() }
        }

        Canvas {
            id: hatch
            width: 12
            height: 12
            renderTarget:  Canvas.FramebufferObject
            renderStrategy: Canvas.Threaded
            onPaint: {
                const c = getContext("2d")
                c.clearRect(0,0,width,height)
                c.strokeStyle = "#11C900"
                c.globalAlpha = 0.25
                c.lineWidth = 1.0
                c.beginPath()
                c.moveTo(0, height);       c.lineTo(width, 0)
                c.moveTo(-width/2, height); c.lineTo(width/2, 0)
                c.stroke()
            }
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true
            implicitWidth:  0
            implicitHeight: 0

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0,0,width,height)

                // background
                ctx.fillStyle = "rgba(0,0,0,0.40)"
                ctx.fillRect(0,0,width,height)

                const top = 6
                const bot = height - 18

                function xForD(d) { return d / Math.max(1, aheadDistanceM) * width }
                function isF(n) { return Number.isFinite(n) }

                const pts = sampler.points || []

                const aglUnder     = aglNow
                const redDanger    = dangerUnder
                const orangeDanger = !redDanger && dangerAhead

                const RED    = "#ff3b30"
                const ORANGE = "#ff9500"
                const profileColor = redDanger ? RED : (orangeDanger ? ORANGE : cLine)

                // AMSL baseline
                ctx.setLineDash([4,4])
                ctx.strokeStyle = "rgba(255,255,255,0.18)"
                ctx.lineWidth = 1
                let y0 = bot
                if (isF(altAMSLNow)) {
                    y0 = _computeYFromAMSL(altAMSLNow, top, bot)
                    ctx.beginPath(); ctx.moveTo(0,y0); ctx.lineTo(width,y0); ctx.stroke()
                }
                ctx.setLineDash([])

                if (!pts.length) return

                // Filled terrain area
                ctx.beginPath()
                ctx.moveTo(0, bot)
                for (let i = 0; i < pts.length; i++) {
                    const x = xForD(pts[i].d)
                    const y = isF(pts[i].elevAMSL)
                        ? _computeYFromAMSL(pts[i].elevAMSL, top, bot)
                        : bot
                    ctx.lineTo(x, y)
                }
                ctx.lineTo(width, bot)
                ctx.closePath()

                ctx.save()
                ctx.clip()
                ctx.globalAlpha = 0.45
                ctx.strokeStyle = profileColor
                ctx.lineWidth = 1.0

                ctx.save()
                ctx.clip()

                const pattern = ctx.createPattern(hatch, "repeat")
                ctx.globalAlpha = redDanger ? 0.55 : (orangeDanger ? 0.50 : 0.45)
                ctx.fillStyle = pattern
                ctx.fillRect(0, 0, width, height)

                ctx.restore()
                ctx.restore()

                // Outline
                ctx.beginPath()
                let first = true
                for (let i=0; i<pts.length; i++) {
                    const x = xForD(pts[i].d)
                    const y = isF(pts[i].elevAMSL)
                        ? _computeYFromAMSL(pts[i].elevAMSL, top, bot)
                        : bot
                    if (first) {
                        ctx.moveTo(x, y)
                        first = false
                    } else {
                        ctx.lineTo(x, y)
                    }
                }
                ctx.lineWidth = 2
                ctx.strokeStyle = profileColor
                ctx.stroke()

                ctx.fillStyle = "rgba(255,255,255,0.70)"
                ctx.font = "11px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "top"

                const tickLabelPad = 12
                const innerW = Math.max(1, width - tickLabelPad * 2)

                function xForTick(d) {
                    return tickLabelPad + d / Math.max(1, aheadDistanceM) * innerW
                }

                for (let m=0; m<=aheadDistanceM; m+=100) {
                    const x = xForTick(m)
                    ctx.fillRect(x, height-14, 1, 6)
                    ctx.fillText(m.toString(), x, height-12)
                }

                // Drone glyph + AGL text
                if (isF(altAMSLNow)) {
                    const glyphX = 10
                    const glyphY = y0
                    const w = 12, h = 10

                    ctx.beginPath()
                    ctx.moveTo(glyphX, glyphY - h/2)
                    ctx.lineTo(glyphX - w/2, glyphY + h/2)
                    ctx.lineTo(glyphX + w/2, glyphY + h/2)
                    ctx.closePath()
                    ctx.fillStyle = cVehicle
                    ctx.fill()

                    ctx.beginPath()
                    ctx.arc(glyphX, glyphY, 2.5, 0, Math.PI*2, false)
                    ctx.fillStyle = cVehicle
                    ctx.fill()

                    const aglTxt = isF(aglUnder) ? (Math.round(aglUnder) + " m AGL") : "— AGL"
                    const label  = aglTxt

                    ctx.font = "bold 12px sans-serif"
                    ctx.textAlign = "left"
                    ctx.textBaseline = "bottom"

                    const padX = 6, padY = 4
                    const tm = ctx.measureText(label)
                    const rectW = tm.width + padX*2
                    const rectH = 18 + padY*2
                    const boxX = 4
                    const boxY = Math.max(4, glyphY - rectH - 8)

                    ctx.globalAlpha = 0.55
                    ctx.fillStyle = "#000000"
                    ctx.fillRect(boxX, boxY, rectW, rectH)
                    ctx.globalAlpha = 1.0
                    ctx.lineWidth = 1.5
                    ctx.strokeStyle = profileColor
                    ctx.strokeRect(boxX+0.5, boxY+0.5, rectW-1, rectH-1)

                    ctx.fillStyle = cText
                    ctx.fillText(label, boxX + padX, boxY + rectH - padY - 2)
                }
            }
        }

        Component.onCompleted: _rewindow()
    }

    TerrainAheadProfile {
        id: terrainProfile
        anchors.fill: parent
        vehicle:      root.vehicle
        aheadDistanceM: 500
        stepM:          25
        warnAGLM:       20
        warnUnderAGLM:  10

        visible: _instrumentFact.rawValue === _noCompassPath
    }

    // Dummy
    Canvas {
        id: angleIndicator
        anchors.fill: parent
        visible: false
    }
}
