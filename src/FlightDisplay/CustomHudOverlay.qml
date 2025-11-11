import QtQuick
import QGroundControl
import QGroundControl.Controls
import QGroundControl.ScreenTools
import QGC.Terrain 1.0


Item {
    id: hud
    anchors.fill: parent

    property var vehicle
    property var camera
    property var pipState

    property int hudCompassMode: 1

    // ---- Style ----
    readonly property color cGreen: "#11C900"
    readonly property color cFill : "#112511"
    readonly property color cText : "#000000"
    readonly property real  thick : 5
    readonly property real  pad   : Math.round(width * 0.01)
    readonly property real  big   : ScreenTools.largeFontPointSize
    readonly property real  sm    : ScreenTools.smallFontPointSize

    function _val(x) {
        if (x === undefined || x === null) return NaN
        if (typeof x === "number") return x
        if (x && typeof x.value === "number") return x.value
        if (x && typeof x.rawValue === "number") return x.rawValue
        return NaN
    }
    function _finite(n) { return Number.isFinite(n) }

    function hdg() {
        const h = _val(vehicle ? vehicle.heading : NaN)
        return _finite(h) ? ((h % 360) + 360) % 360 : NaN
    }
    function pitch() {
        const p = _val(vehicle ? vehicle.pitch : NaN)
        return _finite(p) ? p : 0
    }
    function roll() {
        const r = _val(vehicle ? vehicle.roll : NaN)
        return _finite(r) ? r : 0
    }
    function vs() {
        const v = _val(vehicle ? (vehicle.climbRate !== undefined ? vehicle.climbRate
                                                                   : vehicle.verticalSpeed) : NaN)
        return _finite(v) ? v : NaN
    }
    function gs() {
        const v = _val(vehicle ? (vehicle.groundSpeed !== undefined ? vehicle.groundSpeed
                                                                    : vehicle.horizontalSpeed) : NaN)
        return _finite(v) ? v : NaN
    }
    function alt() {
        const a = _val(vehicle ? vehicle.altitudeRelative : NaN)
        return _finite(a) ? a : NaN
    }
    function volts() {
        let v = (vehicle && vehicle.battery) ? _val(vehicle.battery.voltage) : NaN
        if (!_finite(v)) v = _val(vehicle ? vehicle.batteryVoltage : NaN)
        return _finite(v) ? v : NaN
    }

    function factOrNull(f) {
        return (f && typeof f === "object" && (f.value !== undefined || f.rawValue !== undefined)) ? f : null
    }

    component TerrainAheadProfile : Item {
        property var  vehicle
        property real aheadDistanceM: 500
        property real stepM: 25
        property real warnAGLM: 20
        property real warnUnderAGLM: 10
        property int  hz: 4

        property color cLine:  "#11C900"
        property color cFill:  "#0e3420"
        property color cWarn:  "#ff6b6b"
        property color cText:  "#ffffff"
        property color cVehicle: "#ADFF2F"

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
            vehicle:            terrainStrip.vehicle
            aheadDistanceMeters: terrainStrip.aheadDistanceM
            // stepMeters:          terrainStrip.stepM
            hz:                  terrainStrip.hz
        }


        readonly property real aglNow: {
            const t = sampler.terrainNowAMSL
            if (_finite(t) && _finite(altAMSLNow)) return altAMSLNow - t
            if (_finite(altRelNow)) return altRelNow
            return NaN
        }
        readonly property bool dangerUnder: _finite(aglNow) && aglNow < warnUnderAGLM

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
                if (_finite(e)) { if (e < minH) minH = e; if (e > maxH) maxH = e }
            }
            if (_finite(altAMSLNow)) { if (altAMSLNow < minH) minH = altAMSLNow; if (altAMSLNow > maxH) maxH = altAMSLNow }
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
            function onPointsChanged() { _rewindow() }
            function onTerrainNowAMSLChanged() { canvas.requestPaint() }
        }

        Timer {
            interval: Math.max(120, 1000/hz)
            repeat: true
            running: parent.visible
            onTriggered: { sampler.resample && sampler.resample() }
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0,0,width,height)

                ctx.fillStyle = "rgba(0,0,0,0.40)"
                ctx.fillRect(0,0,width,height)

                const top = 6
                const bot = height - 18

                // AMSL baseline
                ctx.setLineDash([4,4])
                ctx.strokeStyle = "rgba(255,255,255,0.18)"
                ctx.lineWidth = 1
                let y0 = bot
                if (_finite(altAMSLNow)) {
                    y0 = _computeYFromAMSL(altAMSLNow, top, bot)
                    ctx.beginPath(); ctx.moveTo(0,y0); ctx.lineTo(width,y0); ctx.stroke()
                }
                ctx.setLineDash([])

                const pts = sampler.points || []
                if (!pts.length) return
                const aheadDistanceM = terrainStrip.aheadDistanceM

                function xForD(d) { return d / Math.max(1, aheadDistanceM) * width }

                ctx.beginPath()
                ctx.moveTo(0, bot)
                for (let i=0; i<pts.length; i++) {
                    const s = pts[i]
                    const x = xForD(s.d)
                    const y = _finite(s.elevAMSL) ? _computeYFromAMSL(s.elevAMSL, top, bot) : bot
                    ctx.lineTo(x, y)
                }
                ctx.lineTo(width, bot)
                ctx.closePath()

                let forwardDanger = false
                if (_finite(altAMSLNow)) {
                    for (let i=0; i<pts.length; i++) {
                        const s = pts[i]
                        if (_finite(s.elevAMSL) && (altAMSLNow - s.elevAMSL) <= warnAGLM) { forwardDanger = true; break }
                    }
                }
                const danger = dangerUnder || forwardDanger

                ctx.fillStyle = danger ? cWarn : cFill
                ctx.globalAlpha = 0.35; ctx.fill(); ctx.globalAlpha = 1

                ctx.beginPath()
                let first = true
                for (let i=0; i<pts.length; i++) {
                    const s = pts[i]
                    const x = xForD(s.d)
                    const y = _finite(s.elevAMSL) ? _computeYFromAMSL(s.elevAMSL, top, bot) : bot
                    if (first) { ctx.moveTo(x, y); first = false } else { ctx.lineTo(x, y) }
                }
                ctx.lineWidth = 2
                ctx.strokeStyle = danger ? cWarn : cLine
                ctx.stroke()

                ctx.fillStyle = "rgba(255,255,255,0.70)"
                ctx.font = "11px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "top"
                for (let m=0; m<=aheadDistanceM; m+=100) {
                    const x = xForD(m)
                    ctx.fillRect(x, height-14, 1, 6)
                    ctx.fillText(m.toString(), x, height-12)
                }

                if (_finite(altAMSLNow)) {
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

                    const amslTxt = Math.round(altAMSLNow) + " m AMSL"
                    const aglTxt  = _finite(altRelNow) ? Math.round(altRelNow) + " m AGL" : "— AGL"
                    const label = amslTxt + "   " + aglTxt

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
                    ctx.strokeStyle = cLine
                    ctx.strokeRect(boxX+0.5, boxY+0.5, rectW-1, rectH-1)

                    ctx.fillStyle = cText
                    ctx.fillText(label, boxX + padX, boxY + rectH - padY - 2)
                }

                // AGL at far point
                if (_finite(altAMSLNow) && pts.length) {
                    const last = pts[pts.length-1]
                    if (_finite(last.elevAMSL)) {
                        const agl = Math.round(altAMSLNow - last.elevAMSL)
                        const yAC = _computeYFromAMSL(altAMSLNow, top, bot)
                        const xEnd = xForD(last.d)
                        ctx.setLineDash([3,3]); ctx.strokeStyle="#ffffff"; ctx.lineWidth=1.5
                        ctx.beginPath(); ctx.moveTo(xEnd, yAC); ctx.lineTo(xEnd, bot); ctx.stroke()
                        ctx.setLineDash([])

                        ctx.fillStyle="#ffffff"; ctx.font="bold 12px sans-serif"; ctx.textAlign="right"; ctx.textBaseline="bottom"
                        ctx.fillText("AGL @ " + Math.round(last.d) + " m: " + agl + " m",
                                    Math.min(width-6, xEnd), Math.max(12, y0-4))
                    }
                }
            }
        }

        // Initial windowing
        Component.onCompleted: _rewindow()
    }

    // ---------- Top heading tape ----------
    Item {
        id: headingTape
        width: parent.width * 0.5
        anchors.top: parent.top
        anchors.topMargin: pad
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.round(parent.height * 0.10)
        visible: hud.hudCompassMode === 0

        Rectangle { anchors.fill: parent; color: "transparent" }

        // Center caret
        Rectangle {
            width: 14; height: 10
            color: "transparent"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            border.color: cGreen
            border.width: thick
        }

        MouseArea {
            anchors.fill: parent
            onClicked: hud.hudCompassMode = hud.hudCompassMode === 0 ? 1 : 0
        }

        // Moving labels
        Repeater {
            id: hdgRep
            model: 9
            delegate: Rectangle {
                readonly property real stepDeg: 45
                readonly property real center : _finite(hdg()) ? hdg() : 0
                readonly property real deg    : Math.round(center/stepDeg)*stepDeg + (index-4)*stepDeg
                readonly property real span   : 180.0
                readonly property real xCenter: (deg - center)/span * headingTape.width + headingTape.width/2

                x: xCenter - width/2
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: cGreen
                border.color: cGreen
                border.width: 1
                height: 32
                width: Math.max(36, label.implicitWidth + 12)
                visible: Math.abs(xCenter - headingTape.width/2) < headingTape.width/2 + width

                QGCLabel {
                    id: label
                    anchors.centerIn: parent
                    color: cText
                    font.bold: true
                    font.pointSize: big
                    text: {
                        const idx = Math.round((deg / 45) % 8 + 8) % 8
                        const comps = ["N","NE","E","SE","S","SW","W","NW"]
                        return comps[idx]
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: -18
                    width: 3; height: 10
                    color: cGreen
                }
            }
        }
    }

    // ---------- Central horizon & reticle ----------
    Item {
        id: horizon
        anchors.fill: parent

        // Bind to Facts
        property real rollDeg:  (vehicle && vehicle.roll  && _finite(vehicle.roll.value))  ? vehicle.roll.value  : 0
        property real pitchDeg: (vehicle && vehicle.pitch && _finite(vehicle.pitch.value)) ? vehicle.pitch.value : 0

        // Repaint on changes
        onRollDegChanged:  attitudeCanvas.requestPaint()
        onPitchDegChanged: attitudeCanvas.requestPaint()
        onWidthChanged:    attitudeCanvas.requestPaint()
        onHeightChanged:   attitudeCanvas.requestPaint()

        Canvas {
            id: attitudeCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                // --- constants / tuning ---
                const horizonY        = height * 0.5
                const ladderPxPerTick = 20
                const ticksVisible    = 12
                // Altitude scale
                const altTickStep     = 2.0
                const altMajorEvery   = 10.0
                // Speed scale
                const spdTickStep     = 0.5
                const spdMajorEvery   = 1.0

                // live values
                const vspd   = _finite(vs())  ? vs()  : 0
                const altNow = _finite(alt()) ? alt() : 0
                const spdNow = _finite(gs())  ? gs()  : 0

                // helpers
                function isMajor(value, majorStep) {
                    const q = value / majorStep
                    return Math.abs(q - Math.round(q)) < 1e-6
                }
                // Map a tick value
                function yForTick(currentValue, tickValue, tickStep) {
                    const dticks = (tickValue - currentValue) / tickStep
                    return horizonY - dticks * ladderPxPerTick
                }

                // --- geometry shared by labels/ticks ---
                const halfSpan = width * 0.25
                const leftX    = width/2 - halfSpan
                const rightX   = width/2 + halfSpan

                // ---------------------------------------------
                // 1) Horizon line (roll/pitch transform)
                // ---------------------------------------------
                ctx.save()
                ctx.translate(width/2, horizonY)
                ctx.rotate(-roll() * Math.PI/180)
                ctx.translate(0, -pitch() * 2.0)

                ctx.strokeStyle = cGreen
                ctx.lineWidth = thick

                const halfSpan2 = width * 0.15
                const gapHalf   = 40

                // left segment
                ctx.beginPath(); ctx.moveTo(-halfSpan2, 0); ctx.lineTo(-gapHalf, 0); ctx.stroke()
                // right segment
                ctx.beginPath(); ctx.moveTo(gapHalf, 0);    ctx.lineTo(halfSpan2, 0); ctx.stroke()

                // pitch text (left + right)
                const pitchVal = Math.round(horizon.pitchDeg * 10) / 10
                const txt = pitchVal + "°"

                ctx.font = "14px sans-serif"
                ctx.textBaseline = "middle"

                const leftCenterX  = (-halfSpan2 + -gapHalf) / 2
                const rightCenterX = (gapHalf + halfSpan2) / 2
                const m = ctx.measureText(txt)
                const textW = m.width, textH = 16, padX = 4, padY = 2

                ctx.save(); ctx.fillStyle = "rgba(18,201,0,0.5)"
                ctx.fillRect(leftCenterX - textW/2 - padX, 16 - textH/2 - padY, textW + padX*2, textH + padY*2)
                ctx.restore()
                ctx.fillStyle = cText; ctx.textAlign = "center"; ctx.fillText(txt, leftCenterX, 16)

                ctx.save(); ctx.fillStyle = "rgba(18,201,0,0.5)"
                ctx.fillRect(rightCenterX - textW/2 - padX, 16 - textH/2 - padY, textW + padX*2, textH + padY*2)
                ctx.restore()
                ctx.fillStyle = cText; ctx.textAlign = "center"; ctx.fillText(txt, rightCenterX, 16)

                ctx.restore()

                // ---------------------------------------------
                // 2) RIGHT ladder: ALTITUDE  (major every 10 m)
                //    LEFT  ladder: SPEED     (major every 1 m/s)
                // Both use SAME ladderPxPerTick for symmetry.
                // ---------------------------------------------

                ctx.strokeStyle = cGreen
                ctx.fillStyle   = cGreen

                // ALTITUDE
                {
                    const baseAlt = Math.floor(altNow / altTickStep) * altTickStep

                    for (let i = -ticksVisible; i <= ticksVisible; i++) {
                        const tickVal = baseAlt + i * altTickStep
                        const y = yForTick(altNow, tickVal, altTickStep)
                        if (y < -10 || y > height + 10) continue

                        const major = isMajor(tickVal, altMajorEvery)
                        ctx.lineWidth = major ? 5 : 3.5

                        // RIGHT tick
                        ctx.beginPath()
                        ctx.moveTo(rightX, y)
                        ctx.lineTo(rightX - (major ? 34 : 18), y)
                        ctx.stroke()

                        if (major) {
                            // ---- Major tick label ----
                            const padX = 6, padY = 2
                            const rightTickLen = 34
                            const gap = 6

                            ctx.save()
                            ctx.font = "bold 13px sans-serif"
                            ctx.textBaseline = "middle"
                            ctx.textAlign = "left"

                            const label = Math.round(tickVal).toString()
                            const tm = ctx.measureText(label)
                            const rectW = tm.width + padX * 2
                            const rectH = 16 + padY * 2

                            const tickEndX = rightX - rightTickLen
                            const rectX = tickEndX - gap - rectW
                            const rectY = y - rectH / 2

                            // text (cGreen)
                            ctx.fillStyle = cGreen
                            ctx.fillText(label, rectX + padX, y)
                            ctx.restore()
                        }
                    }

                    // ---- Fixed label: ALT + VSPD ----
                    const sign = vspd >= 0 ? "+" : "−"
                    const text = `${altNow.toFixed(0)} m  ${sign}${Math.abs(vspd).toFixed(1)} m/s`

                    ctx.font = "bold 14px sans-serif"
                    ctx.textAlign = "left"
                    ctx.textBaseline = "middle"

                    const padX = 6, padY = 3
                    const mm = ctx.measureText(text)
                    const textWidth = mm.width
                    const textHeight = 18
                    const rectW = textWidth + padX * 2
                    const rectH = textHeight + padY * 4
                    const rectX = rightX + 4
                    const rectY = horizonY - rectH / 2

                    // background
                    ctx.save()
                    ctx.globalAlpha = 0.5
                    ctx.fillStyle = "#000000"
                    ctx.fillRect(rectX, rectY, rectW, rectH)
                    ctx.restore()

                    // border
                    ctx.lineWidth = 2
                    ctx.strokeStyle = cGreen
                    ctx.strokeRect(rectX + 0.5, rectY + 0.5, rectW - 1, rectH - 1)

                    // text
                    ctx.fillStyle = cGreen
                    ctx.fillText(text, rectX + padX, horizonY)
                }

                // SPEED
                {
                    const baseSpd = Math.floor(spdNow / spdTickStep) * spdTickStep
                    for (let j = -ticksVisible; j <= ticksVisible; j++) {
                        const tickVal = baseSpd + j * spdTickStep
                        const y = yForTick(spdNow, tickVal, spdTickStep)
                        if (y < -10 || y > height + 10) continue

                        const major = isMajor(tickVal, spdMajorEvery)
                        ctx.lineWidth = major ? 5 : 3.5

                        // LEFT tick
                        ctx.beginPath()
                        ctx.moveTo(leftX, y)
                        ctx.lineTo(leftX + (major ? 34 : 18), y)
                        ctx.stroke()

                        if (major) {
                            const leftTickLen = (major ? 34 : 18)
                            const gap = 6, padX5 = 6

                            ctx.save()
                            ctx.font = "13px sans-serif"
                            ctx.textBaseline = "middle"

                            const label = Math.round(tickVal).toString()
                            const ms = ctx.measureText(label)
                            const rectW = ms.width + padX5*2

                            const tickEndX = leftX + leftTickLen
                            const rectX = tickEndX + gap
                            const rectY = y - 10

                            ctx.textAlign = "left"
                            ctx.fillStyle = cGreen
                            ctx.fillText(label, rectX + padX5, y)
                            ctx.restore()
                        }
                    }

                    // ---- LEFT fixed label ----
                    {
                        const gsNow = _finite(gs()) ? gs() : 0
                        const text = `${gsNow.toFixed(1)} m/s`

                        ctx.font = "bold 16px sans-serif"
                        ctx.textAlign = "right"
                        ctx.textBaseline = "middle"

                        const padX = 6, padY = 3
                        const m = ctx.measureText(text)
                        const tw = m.width
                        const th = 18
                        const rectW = tw + padX * 2
                        const rectH = th + padY * 4
                        const rectX = leftX - rectW - 4
                        const rectY = horizonY - th / 1.5 - padY

                        ctx.save()
                        ctx.globalCompositeOperation = "source-over"
                        ctx.globalAlpha = 0.5
                        ctx.fillStyle = "#000000"
                        ctx.fillRect(rectX, rectY, rectW, rectH)
                        ctx.restore()

                        // border
                        ctx.lineWidth = 2
                        ctx.strokeStyle = cGreen
                        ctx.strokeRect(rectX + 0.5, rectY + 0.5, rectW - 1, rectH - 1)

                        // text
                        ctx.fillStyle = cGreen
                        ctx.fillText(text, rectX + rectW - padX, horizonY)
                    }

                }

                // ---------------------------------------------
                // 3) Crosshair
                // ---------------------------------------------
                ctx.strokeStyle = cGreen
                ctx.lineWidth = thick

                const cx = width / 2
                const cy = horizonY
                const gapHalf2 = 20
                const armLen = gapHalf2 + 18

                ctx.beginPath(); ctx.moveTo(cx, cy - armLen); ctx.lineTo(cx, cy - gapHalf2); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx, cy + gapHalf2); ctx.lineTo(cx, cy + armLen); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx - armLen, cy);   ctx.lineTo(cx - gapHalf2, cy); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx + gapHalf2, cy); ctx.lineTo(cx + armLen, cy);   ctx.stroke()
            }
        }

        // ROLL
        Connections { target: factOrNull(vehicle ? vehicle.roll : null)
            function onValueChanged() { attitudeCanvas.requestPaint() } }
        Connections { target: vehicle; ignoreUnknownSignals: true
            function onRollChanged() { attitudeCanvas.requestPaint() } }

        // PITCH
        Connections { target: factOrNull(vehicle ? vehicle.pitch : null)
            function onValueChanged() { attitudeCanvas.requestPaint() } }
        Connections { target: vehicle; ignoreUnknownSignals: true
            function onPitchChanged() { attitudeCanvas.requestPaint() } }

        // ALT REL
        Connections { target: factOrNull(vehicle ? vehicle.altitudeRelative : null)
            function onRawValueChanged() { attitudeCanvas.requestPaint() } }
        Connections { target: vehicle; ignoreUnknownSignals: true
            function onAltitudeRelativeChanged() { attitudeCanvas.requestPaint() } }

        // CLIMB/VSPD
        Connections { target: factOrNull(vehicle ? vehicle.climbRate : null)
            function onRawValueChanged() { attitudeCanvas.requestPaint() } }
        Connections { target: vehicle; ignoreUnknownSignals: true
            function onClimbRateChanged() { attitudeCanvas.requestPaint() } }

        // GROUND SPEED
        Connections { target: factOrNull(vehicle ? vehicle.groundSpeed : null)
            function onRawValueChanged() { attitudeCanvas.requestPaint() } }
        Connections { target: vehicle; ignoreUnknownSignals: true
            function onGroundSpeedChanged() { attitudeCanvas.requestPaint() } }

    }

    // ---------- Bottom-center compass using QGC vehicle heading ----------
    Item {
        id: bottomCompass
        width: hud.width * 0.10
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: hud.pad * 2
        visible: hud.hudCompassMode === 1

        property color compassColor: cGreen
        readonly property real compassRadius: Math.min(width, height) * 0.40

        readonly property real launchHeadingDeg: {
            if (vehicle && vehicle.headingToHome && _finite(vehicle.headingToHome.rawValue)) {
                return vehicle.headingToHome.rawValue
            }
            if (vehicle && vehicle.headingToNextWP && _finite(vehicle.headingToNextWP.rawValue)) {
                return vehicle.headingToNextWP.rawValue
            }
            return NaN
        }
        function showLaunchIndicator() { return _finite(bottomCompass.launchHeadingDeg) }

        readonly property real headingDeg: {
            if (!vehicle || !vehicle.heading) return 0
            const h = (vehicle.heading.rawValue !== undefined) ? vehicle.heading.rawValue : vehicle.heading
            return _finite(h) ? h : 0
        }

        MouseArea {
            anchors.fill: parent
            onClicked: hud.hudCompassMode = hud.hudCompassMode === 0 ? 1 : 0
        }

        // 1) COMPASS DIAL
        Canvas {
            id: compassCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset && ctx.reset()
                ctx.clearRect(0, 0, width, height)

                const cx = width / 2
                const cy = height / 2
                const outerR = bottomCompass.compassRadius
                const innerR = outerR * 0.85
                const heading = bottomCompass.headingDeg

                ctx.save()
                ctx.translate(cx, cy)
                ctx.rotate(-heading * Math.PI / 180)
                ctx.translate(-cx, -cy)

                // OUTER ring
                ctx.beginPath()
                ctx.arc(cx, cy, outerR, 0, Math.PI * 2, false)
                ctx.fillStyle = "rgba(0,0,0,0.35)"; ctx.fill()
                ctx.beginPath()
                ctx.arc(cx, cy, outerR, 0, Math.PI * 2, false)
                ctx.lineWidth = 2
                ctx.strokeStyle = "rgba(255,255,255,0.35)"; ctx.stroke()

                // INNER disk
                ctx.beginPath()
                ctx.arc(cx, cy, innerR, 0, Math.PI * 2, false)
                ctx.fillStyle = "rgba(0,0,0,0.20)"; ctx.fill()

                // sectors
                const sectors = 8
                ctx.save(); ctx.translate(cx, cy)
                for (let i = 0; i < sectors; i++) {
                    ctx.beginPath(); ctx.moveTo(0, 0)
                    const a0 = (i * 2 * Math.PI / sectors) - Math.PI/2
                    const a1 = ((i + 1) * 2 * Math.PI / sectors) - Math.PI/2
                    ctx.arc(0, 0, innerR, a0, a1, false)
                    ctx.closePath()
                    ctx.fillStyle = (i % 2 === 0) ? "rgba(120,120,120,0.05)" : "rgba(120,120,120,0.14)"
                    ctx.fill()
                }
                ctx.restore()

                // ticks + cardinals
                ctx.save(); ctx.translate(cx, cy)
                const cardinals = [
                    {deg: 0,   label: "N"},
                    {deg: 90,  label: "E"},
                    {deg: 180, label: "S"},
                    {deg: 270, label: "W"}
                ]
                for (let a = 0; a < 360; a += 30) {
                    const rad = (a - 90) * Math.PI / 180
                    const r1 = outerR - 2, r2 = outerR - 10
                    ctx.beginPath()
                    ctx.moveTo(Math.cos(rad)*r1, Math.sin(rad)*r1)
                    ctx.lineTo(Math.cos(rad)*r2, Math.sin(rad)*r2)
                    ctx.lineWidth = 2
                    ctx.strokeStyle = "rgba(255,255,255,0.4)"
                    ctx.stroke()
                }
                ctx.fillStyle = "#ffffff"
                ctx.font = "bold " + (outerR * 0.20) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                cardinals.forEach(function(c) {
                    const rad = (c.deg - 90) * Math.PI / 180
                    const rtxt = outerR - 16
                    ctx.save()
                    ctx.translate(Math.cos(rad)*rtxt, Math.sin(rad)*rtxt)
                    ctx.fillText(c.label, 0, 0)
                    ctx.restore()
                })
                ctx.restore(); ctx.restore()

                // fixed heading number
                const headingStr = ("000" + Math.round(heading)).slice(-3)
                ctx.font = "bold " + (outerR * 0.22) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "bottom"
                ctx.fillStyle = "rgba(0,255,128,0.95)"
                ctx.fillText(headingStr, cx, cy - outerR - 4)
            }
        }

        onWidthChanged: compassCanvas.requestPaint()
        onHeightChanged: compassCanvas.requestPaint()
        onHeadingDegChanged: compassCanvas.requestPaint()

        // 2) FIXED ARROW
        Item {
            id: headingArrow
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            visible: !!vehicle

            Canvas {
                id: headingArrowCanvas
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0,0,width,height)

                    const cx = width/2
                    const cy = height/2
                    const len = Math.min(width, height) * 0.40

                    ctx.beginPath()
                    ctx.moveTo(cx, cy - len/4)
                    ctx.lineTo(cx - 9, cy)
                    ctx.lineTo(cx + 9, cy)
                    ctx.closePath()
                    ctx.fillStyle = "rgba(180,255,26,0.5)"; ctx.fill()

                    ctx.beginPath()
                    ctx.arc(cx, cy, 3, 0, Math.PI*2, false)
                    ctx.fillStyle = cGreen; ctx.fill()
                }
            }
        }

        // 3) launch/home indicator and gimbal azimuth
        Rectangle {
            id: launchIndicator
            visible: bottomCompass.showLaunchIndicator()
            width: 22; height: 22
            radius: width/2
            color: "red"
            border.color: "red" //bottomCompass.compassColor
            border.width: 3

            function norm360(d) { return ((d % 360) + 360) % 360 }

            readonly property real relDeg: {
                if (!bottomCompass.showLaunchIndicator()) return NaN
                return norm360(bottomCompass.launchHeadingDeg - bottomCompass.headingDeg)
            }
            readonly property real relRad: relDeg * Math.PI / 180.0

            x: {
                if (!visible) return 0
                const cx = bottomCompass.width  / 2
                return cx + bottomCompass.compassRadius * Math.sin(relRad) - width/2
            }
            y: {
                if (!visible) return 0
                const cy = bottomCompass.height / 2
                return cy - bottomCompass.compassRadius * Math.cos(relRad) - height/2
            }

            QGCLabel {
                anchors.centerIn: parent
                text: "L"
                font.bold: true
                color: "black" //bottomCompass.compassColor
            }
        }


        Repeater {
            id: gimbalRep
            model: vehicle && vehicle.gimbalController ? vehicle.gimbalController.gimbals : []

            delegate: Item {
                id: gimbalItem
                anchors.centerIn: bottomCompass
                width: bottomCompass.width
                height: bottomCompass.height

                // --- helpers ---
                function norm360(d) { return ((d % 360) + 360) % 360 }
                function wrap180(d) { let a = norm360(d); return (a > 180) ? a - 360 : a }

                property bool absYawIsRadians: false

                property real mountYawOffsetDeg: 0

                readonly property real absYawDegNow: {
                    if (!object) return NaN
                    let v = hud._val(object.absoluteYaw)
                    if (!Number.isFinite(v)) return NaN
                    if (absYawIsRadians) v = v * 180 / Math.PI
                    return norm360(v)
                }

                readonly property real headDegNow: Number.isFinite(bottomCompass.headingDeg)
                                                ? norm360(bottomCompass.headingDeg) : NaN

                readonly property real relAngleDeg: {
                    if (!Number.isFinite(absYawDegNow) || !Number.isFinite(headDegNow)) return 0
                    return wrap180(absYawDegNow + mountYawOffsetDeg - headDegNow)
                }

                // Repaint when relAngleDeg changes
                onRelAngleDegChanged: gimbalCanvas.requestPaint()

                // Main drawing
                Canvas {
                    id: gimbalCanvas
                    anchors.fill: parent
                    antialiasing: true

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0,0,width,height)

                        const cx = width / 2
                        const cy = height / 2
                        const r  = bottomCompass.compassRadius - 1.5

                        const aCenter = (gimbalItem.relAngleDeg) * Math.PI/180 - Math.PI/2

                        const spanDeg = 10
                        const spanRad = spanDeg * Math.PI / 180.0
                        const a1 = aCenter - spanRad/2
                        const a2 = aCenter + spanRad/2

                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.arc(cx, cy, r, a1, a2, false)
                        ctx.closePath()
                        ctx.fillStyle = (gimbalItem.opacity === 1.0)
                            ? "rgba(255,140,0,0.25)"
                            : "rgba(255,140,0,0.15)"
                        ctx.fill()

                        ctx.beginPath()
                        ctx.lineWidth = 1.5
                        ctx.strokeStyle = "rgba(0,0,0,0.4)"
                        ctx.moveTo(cx, cy)
                        ctx.lineTo(cx + Math.cos(a1) * r, cy + Math.sin(a1) * r)
                        ctx.moveTo(cx, cy)
                        ctx.lineTo(cx + Math.cos(a2) * r, cy + Math.sin(a2) * r)
                        ctx.stroke()
                    }

                    // Recompute + repaint when inputs change
                    Connections {
                        target: bottomCompass
                        ignoreUnknownSignals: true
                        function onHeadingDegChanged() { gimbalCanvas.requestPaint() }
                    }
                    Connections {
                        target: factOrNull(object ? object.absoluteYaw : null)
                        ignoreUnknownSignals: true
                        function onRawValueChanged() {
                            if (gimbalItem._absYawValid) {
                                gimbalItem._lastGoodAbsYaw = object.absoluteYaw.rawValue
                                gimbalItem._haveLast = true
                            }
                            gimbalCanvas.requestPaint()
                        }
                    }
                    Connections {
                        target: gimbalItem
                        ignoreUnknownSignals: true
                        function onRelAngleDegChanged() { gimbalCanvas.requestPaint() }
                    }

                    onWidthChanged:  requestPaint()
                    onHeightChanged: requestPaint()
                    onVisibleChanged: if (visible) requestPaint()
                }

                // Initial compute
                Component.onCompleted: { gimbalCanvas.requestPaint() }

                // Visibility + opacity as before
                visible: vehicle
                    && QGroundControl.settingsManager.gimbalControllerSettings.showAzimuthIndicatorOnMap.rawValue
                opacity: object === vehicle.gimbalController.activeGimbal ? 1.0 : 0.4
            }


        }
    }

    readonly property string _noCompassPath:
        "qrc:/qml/QGroundControl/FlightMap/Widgets/NoCompassAttitude.qml"

    property var _instrumentFact: QGroundControl.settingsManager.flyViewSettings.instrumentQmlFile2

    TerrainAheadProfile {
        id: terrainStrip
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: hud.pad
        anchors.bottomMargin: hud.pad * 3
        width:  Math.max(220, hud.width * 0.22)
        height: Math.max(90,  hud.height * 0.16)

        vehicle: hud.vehicle
        aheadDistanceM: 500
        stepM: 25
        warnAGLM: 20

        visible: _instrumentFact.rawValue === _noCompassPath
    }

}

