<<<<<<< HEAD
=======
// CustomHudOverlay.qml
>>>>>>> 2ec41fb76... HUD
import QtQuick
import QGroundControl
import QGroundControl.Controls

Item {
    id: hud
<<<<<<< HEAD
    anchors.fill: parent
=======
    // Make absolutely sure we fill our parent
    anchors.fill: parent
    x: 0; y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
>>>>>>> 2ec41fb76... HUD

    // External bindings from parent file
    property var vehicle
    property var camera
    property var pipState

<<<<<<< HEAD
    // 0 = heading, 1 = bottom compass
    property int hudCompassMode: 1

    // ---- Style ----
    readonly property color cGreen: "#11C900"
    readonly property color cFill : "#112511"
    readonly property color cText : "#000000"
=======
    property int hudCompassMode: 1

    // ---- Style ----
    readonly property color cGreen: "#11C900"     // bright HUD green
    readonly property color cFill : "#112511"     // translucent green fill
    readonly property color cBox  : "#11C900"
    readonly property color cText : "#000000"     // black text inside green boxes
>>>>>>> 2ec41fb76... HUD
    readonly property real  thick : 5
    readonly property real  pad   : Math.round(width * 0.01)
    readonly property real  big   : ScreenTools.largeFontPointSize
    readonly property real  sm    : ScreenTools.smallFontPointSize

<<<<<<< HEAD
    // ---- Data helpers ----
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

    // ---------- Top heading tape ----------
    Item {
        id: headingTape
        width: parent.width * 0.5
        anchors.top: parent.top
        anchors.topMargin: pad
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.round(parent.height * 0.10)
        visible: hud.hudCompassMode === 0
=======
    property real _headingToNextWP:             vehicle ? vehicle.headingToNextWP.rawValue : 0

    // ---- Data helpers (robust for Fact or plain values) ----
    function _val(x) {
        // Accepts: number, { value }, { rawValue }
        if (x === undefined || x === null) return NaN
        if (typeof x === "number") return x
        if (typeof x.value === "number") return x.value
        if (typeof x.rawValue === "number") return x.rawValue
        return NaN
    }

    function hdg() {
        // heading in degrees [0..360)
        var h = _val(vehicle ? vehicle.heading : NaN)
        return isFinite(h) ? ((h % 360) + 360) % 360 : NaN
    }

    function pitch() {
        var p = _val(vehicle ? vehicle.pitch : NaN)
        return isFinite(p) ? p : 0
    }

    function roll() {
        var r = _val(vehicle ? vehicle.roll : NaN)
        return isFinite(r) ? r : 0
    }

    function gs() {
        // ground speed (m/s)
        var v = _val(vehicle ? vehicle.groundSpeed : NaN)
        return isFinite(v) ? v : NaN
    }

    function vs() {
        // vertical speed / climb rate (m/s), positive up
        var v = _val(vehicle ? (vehicle.climbRate !== undefined ? vehicle.climbRate
                                    : vehicle.verticalSpeed) : NaN)
        return isFinite(v) ? v : NaN
    }

    function alt() {
        // relative altitude (m)
        var a = _val(vehicle ? vehicle.altitudeRelative : NaN)
        return isFinite(a) ? a : NaN
    }

    function volts() {
        // battery voltage
        var v = vehicle && vehicle.battery ? _val(vehicle.battery.voltage) : NaN
        if (!isFinite(v)) v = _val(vehicle ? vehicle.batteryVoltage : NaN)
        return isFinite(v) ? v : NaN
    }


    // ---------- Top heading tape ----------
    Item {
        id: headingTape
        width: parent.width * 0.5      // ← half of video
        anchors.top: parent.top
        anchors.topMargin: pad
        anchors.horizontalCenter: parent.horizontalCenter   // ← centered
        height: Math.round(parent.height * 0.10)
        visible: !hud.hudCompassMode
>>>>>>> 2ec41fb76... HUD

        Rectangle { anchors.fill: parent; color: "transparent" }

        // Center caret
        Rectangle {
<<<<<<< HEAD
            width: 14; height: 10
            color: "transparent"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            border.color: cGreen
            border.width: thick
=======
            width: 14; height: 10; color: "transparent"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            border.color: cGreen; border.width: thick
>>>>>>> 2ec41fb76... HUD
        }

        MouseArea {
            anchors.fill: parent
<<<<<<< HEAD
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
=======
            onClicked: {
                // toggle 0 <-> 1
                hud.hudCompassMode = hud.hudCompassMode === 0 ? 1 : 0
                console.log("hudCompassMode =", hud.hudCompassMode)
            }
        }

        Connections {
            target: headingTape
            function onCompassClicked(angleDeg) {
                console.log("Request gimbal/yaw to", angleDeg);
                if (vehicle && vehicle.gimbalController) {
                    if (vehicle.gimbalController.setYawAbsolute) {
                        vehicle.gimbalController.setYawAbsolute(angleDeg);
                    }
                }
            }
        }

        // Moving labels W, NW, N, ...
        Repeater {
            id: hdgRep
            model: 9   // a small window of labels around current heading
            delegate: Rectangle {
                // --- use ':' for property initializers in QML ---
                readonly property var  labels: ["W","WNW","NW","NNW","N","NNE","NE","ENE","Et"]
                readonly property real stepDeg: 45 //11.25         // 32-wind style
                readonly property real center: isFinite(hdg()) ? hdg() : 0
                readonly property real deg:    Math.round(center/stepDeg)*stepDeg + (index-4)*stepDeg
                readonly property real span:   180.0           // degrees visible across width
>>>>>>> 2ec41fb76... HUD
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
<<<<<<< HEAD
                    text: {
                        const idx = Math.round((deg / 45) % 8 + 8) % 8
                        const comps = ["N","NE","E","SE","S","SW","W","NW"]
                        return comps[idx]
                    }
                }

=======

                    // Compass label (0° = N)
                    text: {
                        const centerDeg = deg;                                   // heading for this tick
                        const idx = Math.round((centerDeg / 45) % 8 + 8) % 8;    // normalized 0–7
                        const comps = ["N","NE","E","SE","S","SW","W","NW"];     // <-- start at North
                        return comps[idx];
                    }
                }



                // Small tick above each label
>>>>>>> 2ec41fb76... HUD
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: -18
<<<<<<< HEAD
                    width: 3; height: 10
=======
                    width: 3
                    height: 10
>>>>>>> 2ec41fb76... HUD
                    color: cGreen
                }
            }
        }
<<<<<<< HEAD
=======

>>>>>>> 2ec41fb76... HUD
    }

    // ---------- Central horizon & reticle ----------
    Item {
        id: horizon
        anchors.fill: parent
<<<<<<< HEAD

        // Bind to Facts
        property real rollDeg:  (vehicle && vehicle.roll  && _finite(vehicle.roll.value))  ? vehicle.roll.value  : 0
        property real pitchDeg: (vehicle && vehicle.pitch && _finite(vehicle.pitch.value)) ? vehicle.pitch.value : 0
=======
        property real _scrollOffset: 0
        property real _lastTime: 0

        Timer {
            interval: 16
            running: true
            repeat: true
            onTriggered: attitudeCanvas.requestPaint()
        }

        // Bind to Facts (or 0 if missing)
        property real rollDeg:  (vehicle && vehicle.roll  && isFinite(vehicle.roll.value))  ? vehicle.roll.value  : 0
        property real pitchDeg: (vehicle && vehicle.pitch && isFinite(vehicle.pitch.value)) ? vehicle.pitch.value : 0
>>>>>>> 2ec41fb76... HUD

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
<<<<<<< HEAD
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
=======
                // -- stable dt for smooth scroll independent of MAVLink rate
                var now = Date.now()
                var dt = horizon._lastTime > 0 ? (now - horizon._lastTime) / 1000.0 : 0.016
                horizon._lastTime = now

                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                // --- constants / tuning ---
                const horizonY     = height * 0.55    // where your crosshair lives
                const tickMeters   = 2                 // altitude per minor tick
                const pxPerTick    = 20                // pixels per minor tick
                const scrollRate   = 12                // px per (m/s)
                const ticksVisible = 12                // how many up/down to draw

                // --- numeric guards ---
                var vspd = Number.isFinite(vs())  ? vs()  : 0
                var a0   = Number.isFinite(alt()) ? alt() : 0

                // ---------------------------------------------
                // 1) Draw horizon (roll/pitch transform)
>>>>>>> 2ec41fb76... HUD
                // ---------------------------------------------
                ctx.save()
                ctx.translate(width/2, horizonY)
                ctx.rotate(roll() * Math.PI/180)
                ctx.translate(0, -pitch() * 2.0)

                ctx.strokeStyle = cGreen
                ctx.lineWidth = thick

<<<<<<< HEAD
                const halfSpan2 = width * 0.15
                const gapHalf   = 40

                // left segment
                ctx.beginPath(); ctx.moveTo(-halfSpan2, 0); ctx.lineTo(-gapHalf, 0); ctx.stroke()
                // right segment
                ctx.beginPath(); ctx.moveTo(gapHalf, 0);    ctx.lineTo(halfSpan2, 0); ctx.stroke()

                // pitch text (left + right)
                const pitchVal = Math.round(horizon.pitchDeg * 10) / 10
                const txt = pitchVal + "°"
=======
                const halfSpan2 = width * 0.25  // total half-length of horizon bar
                const gapHalf   = 20            // half of the empty gap in the middle

                // left segment
                ctx.beginPath()
                ctx.moveTo(-halfSpan2, 0)
                ctx.lineTo(-gapHalf, 0)
                ctx.stroke()

                // right segment
                ctx.beginPath()
                ctx.moveTo(gapHalf, 0)
                ctx.lineTo(halfSpan2, 0)
                ctx.stroke()

                // ---------------------------------------------
                // 1b) Pitch text on the horizon line (left + right)
                // ---------------------------------------------
                // get pitch (you have horizon.pitchDeg bound above)
                var pitchVal = Math.round(horizon.pitchDeg * 10) / 10  // 1 decimal
                var txt = pitchVal + "°"
>>>>>>> 2ec41fb76... HUD

                ctx.font = "14px sans-serif"
                ctx.textBaseline = "middle"

<<<<<<< HEAD
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
=======
                // LEFT text position: middle of (-halfSpan2 .. -gapHalf)
                var leftCenterX = (-halfSpan2 + -gapHalf) / 2
                var leftCenterY = 16

                // RIGHT text position: middle of (gapHalf .. halfSpan2)
                var rightCenterX = (gapHalf + halfSpan2) / 2
                var rightCenterY = 16

                // measure once
                var metrics = ctx.measureText(txt)
                var textW   = metrics.width
                var textH   = 16
                var padX    = 4
                var padY    = 2

                // draw background + text for LEFT
                ctx.save()
                ctx.fillStyle = Qt.rgba(0.07, 0.79, 0.0, 0.5)   // green, 0.3 opacity
                ctx.fillRect(leftCenterX - textW/2 - padX,
                            leftCenterY - textH/2 - padY,
                            textW + padX*2,
                            textH + padY*2)
                ctx.restore()

                ctx.fillStyle = "#000000"
                ctx.textAlign = "center"
                ctx.fillText(txt, leftCenterX, leftCenterY)

                // draw background + text for RIGHT
                ctx.save()
                ctx.fillStyle = Qt.rgba(0.07, 0.79, 0.0, 0.5)
                ctx.fillRect(rightCenterX - textW/2 - padX,
                            rightCenterY - textH/2 - padY,
                            textW + padX*2,
                            textH + padY*2)
                ctx.restore()

                ctx.fillStyle = "#000000"
                ctx.textAlign = "center"
                ctx.fillText(txt, rightCenterX, rightCenterY)
>>>>>>> 2ec41fb76... HUD

                ctx.restore()

                // ---------------------------------------------
<<<<<<< HEAD
                // 2) RIGHT ladder: ALTITUDE  (major every 10 m)
                //    LEFT  ladder: SPEED     (major every 1 m/s)
                // Both use SAME ladderPxPerTick for symmetry.
                // ---------------------------------------------
=======
                // 2) Altitude-driven tick ladder (fixed frame)
                // ---------------------------------------------
                horizon._scrollOffset -= vspd * scrollRate * dt
                // wrap to [0..pxPerTick)
                horizon._scrollOffset = ((horizon._scrollOffset % pxPerTick) + pxPerTick) % pxPerTick
>>>>>>> 2ec41fb76... HUD

                ctx.strokeStyle = cGreen
                ctx.fillStyle   = cGreen

<<<<<<< HEAD
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

                            // // background
                            // ctx.globalAlpha = 0.5
                            // ctx.fillStyle = "#000000"
                            // ctx.fillRect(rectX, rectY, rectW, rectH)

                            // // border, pixel-aligned
                            // ctx.globalAlpha = 1.0
                            // ctx.lineWidth = 2
                            // ctx.strokeStyle = cGreen
                            // ctx.strokeRect(rectX + 0.5, rectY + 0.5, rectW - 1, rectH - 1)

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

                            // optional bg:
                            // ctx.fillStyle = "rgba(18,201,0,0.35)"
                            // ctx.fillRect(rectX, rectY, rectW, 20)

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
=======
                // must match horizon geometry
                const halfSpan = width * 0.25    // same as in horizon part
                const leftX    = width/2 - halfSpan
                const rightX   = width/2 + halfSpan

                // how many meters the pixel scroll represents
                var visualAltOffsetMeters = (horizon._scrollOffset / pxPerTick) * tickMeters

                // current real alt (can be 47.3, 101.8, ...)
                var altNow = a0

                // stable base altitude (aligned to tickMeters)
                var baseAlt = Math.floor((altNow - visualAltOffsetMeters) / tickMeters) * tickMeters

                // figure out which tick is the "current" one
                var activeTickAlt = Math.round(altNow / tickMeters) * tickMeters

                // --------------------------------------------------
                // 1) DRAW MOVING TICKS (left + right) - same as before
                // --------------------------------------------------
                for (var i = -ticksVisible; i <= ticksVisible; i++) {
                    var altTick = baseAlt + i * tickMeters
                    var y = horizonY + i * pxPerTick + horizon._scrollOffset
                    if (y < -10 || y > height + 10) continue

                    var isMajor = (altTick % 10) === 0
                    ctx.lineWidth = isMajor ? 5 : 3.5

                    // LEFT tick
                    ctx.beginPath()
                    ctx.moveTo(leftX, y)
                    ctx.lineTo(leftX + (isMajor ? 34 : 18), y)
                    ctx.stroke()

                    // RIGHT tick
                    ctx.beginPath()
                    ctx.moveTo(rightX, y)
                    ctx.lineTo(rightX - (isMajor ? 34 : 18), y)
                    ctx.stroke()
                }

                // --------------------------------------------------
                // 2) DRAW FIXED LABELS (do NOT use y from ticks)
                // --------------------------------------------------

                // fixed Y position for labels (centered on horizon line)
                const labelY = horizonY

                // ---- RIGHT: ALTITUDE (stationary) ----
                {
                    const text = altNow.toFixed(0) + " m"   // or use activeTickAlt if you want rounded
                    ctx.font = "14px sans-serif"
                    ctx.textAlign = "left"
                    ctx.textBaseline = "middle"

                    const padX = 6
                    const padY = 3
                    const metrics = ctx.measureText(text)
                    const textWidth = metrics.width
                    const textHeight = 18
                    const rectX = rightX + 4
                    const rectY = labelY - textHeight / 2 - padY
                    const rectW = textWidth + padX * 2
                    const rectH = textHeight + padY * 2

                    ctx.save()
                    ctx.fillStyle = Qt.rgba(0.07, 0.79, 0.0, 0.7)
                    ctx.fillRect(rectX, rectY, rectW, rectH)
                    ctx.restore()

                    ctx.fillStyle = "#000000"
                    ctx.fillText(text, rectX + padX, labelY)
                }

                // ---- LEFT: SPEED (stationary) ----
                {
                    const spd = vs()    // your speed source
                    const speedText = spd.toFixed(1) + " m/s"

                    ctx.font = "14px sans-serif"
                    ctx.textAlign = "right"
                    ctx.textBaseline = "middle"

                    const padX = 6
                    const padY = 3
                    const m2 = ctx.measureText(speedText)
                    const tw2 = m2.width
                    const th2 = 18
                    const rectW2 = tw2 + padX * 2
                    const rectH2 = th2 + padY * 2
                    const rectX2 = leftX - rectW2 - 4
                    const rectY2 = labelY - th2 / 2 - padY

                    ctx.save()
                    ctx.fillStyle = Qt.rgba(0.07, 0.79, 0.0, 0.7)
                    ctx.fillRect(rectX2, rectY2, rectW2, rectH2)
                    ctx.restore()

                    ctx.fillStyle = "#000000"
                    ctx.fillText(speedText, rectX2 + rectW2 - padX, labelY)
                }


                // ---------------------------------------------
                // 3) Crosshair (no rotation) with empty center
>>>>>>> 2ec41fb76... HUD
                // ---------------------------------------------
                ctx.strokeStyle = cGreen
                ctx.lineWidth = thick

<<<<<<< HEAD
                const cx = width / 2
                const cy = horizonY
                const gapHalf2 = 20
                const armLen = gapHalf2 + 18

                ctx.beginPath(); ctx.moveTo(cx, cy - armLen); ctx.lineTo(cx, cy - gapHalf2); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx, cy + gapHalf2); ctx.lineTo(cx, cy + armLen); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx - armLen, cy);   ctx.lineTo(cx - gapHalf2, cy); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx + gapHalf2, cy); ctx.lineTo(cx + armLen, cy);   ctx.stroke()
=======
                const cx        = width / 2
                const cy        = horizonY
                const armLen    = 18          // total half-length of arms (like before)
                const gapHalf2   = 5           // half-size of empty square in center

                // vertical upper arm
                ctx.beginPath()
                ctx.moveTo(cx, cy - armLen)
                ctx.lineTo(cx, cy - gapHalf2)
                ctx.stroke()

                // vertical lower arm
                ctx.beginPath()
                ctx.moveTo(cx, cy + gapHalf2)
                ctx.lineTo(cx, cy + armLen)
                ctx.stroke()

                // horizontal left arm
                ctx.beginPath()
                ctx.moveTo(cx - armLen, cy)
                ctx.lineTo(cx - gapHalf2, cy)
                ctx.stroke()

                // horizontal right arm
                ctx.beginPath()
                ctx.moveTo(cx + gapHalf2, cy)
                ctx.lineTo(cx + armLen, cy)
                ctx.stroke()

>>>>>>> 2ec41fb76... HUD
            }
        }

        Connections {
            target: vehicle ? vehicle.roll : null
            function onValueChanged() { attitudeCanvas.requestPaint() }
        }
        Connections {
            target: vehicle ? vehicle.pitch : null
            function onValueChanged() { attitudeCanvas.requestPaint() }
        }
<<<<<<< HEAD
=======

>>>>>>> 2ec41fb76... HUD
        Connections {
            target: vehicle ? vehicle.altitudeRelative : null
            function onValueChanged() { attitudeCanvas.requestPaint() }
        }
        Connections {
            target: (vehicle && vehicle.climbRate) ? vehicle.climbRate : null
            function onValueChanged() { attitudeCanvas.requestPaint() }
        }
<<<<<<< HEAD
        Connections {
            target: vehicle ? vehicle.groundSpeed : null
            function onValueChanged() { attitudeCanvas.requestPaint() }
        }
    }

    // ---------- Bottom-center compass using QGC vehicle heading ----------
=======

    }

    // ---------- Bottom-center compass using QGC vehicle heading ----------

    // ---------- Bottom-center compass using QGC vehicle heading ----------
>>>>>>> 2ec41fb76... HUD
    Item {
        id: bottomCompass
        width: hud.width * 0.10
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: hud.pad * 2
<<<<<<< HEAD
        visible: hud.hudCompassMode === 1
=======
        visible: hud.hudCompassMode

        signal compassClicked(real angleDeg)
>>>>>>> 2ec41fb76... HUD

        property color compassColor: cGreen
        readonly property real compassRadius: Math.min(width, height) * 0.40

        readonly property real launchHeadingDeg: {
<<<<<<< HEAD
            if (vehicle && vehicle.headingToHome && _finite(vehicle.headingToHome.rawValue)) {
                return vehicle.headingToHome.rawValue
            }
            if (vehicle && vehicle.headingToNextWP && _finite(vehicle.headingToNextWP.rawValue)) {
=======
            if (vehicle && vehicle.headingToHome && isFinite(vehicle.headingToHome.rawValue)) {
                return vehicle.headingToHome.rawValue
            }
            if (vehicle && vehicle.headingToNextWP && isFinite(vehicle.headingToNextWP.rawValue)) {
>>>>>>> 2ec41fb76... HUD
                return vehicle.headingToNextWP.rawValue
            }
            return NaN
        }
<<<<<<< HEAD
        function showLaunchIndicator() { return _finite(bottomCompass.launchHeadingDeg) }

        readonly property real headingDeg: {
            if (!vehicle || !vehicle.heading) return 0
            const h = (vehicle.heading.rawValue !== undefined) ? vehicle.heading.rawValue : vehicle.heading
            return _finite(h) ? h : 0
=======

        function showLaunchIndicator() {
            return isFinite(bottomCompass.launchHeadingDeg)
        }

        // single source of truth for heading
        readonly property real headingDeg: {
            if (!vehicle || !vehicle.heading) return 0
            var h = vehicle.heading.rawValue !== undefined ? vehicle.heading.rawValue : vehicle.heading
            return isFinite(h) ? h : 0
>>>>>>> 2ec41fb76... HUD
        }

        MouseArea {
            anchors.fill: parent
<<<<<<< HEAD
            onClicked: hud.hudCompassMode = hud.hudCompassMode === 0 ? 1 : 0
        }

        // 1) COMPASS DIAL
=======
            onClicked: {
                hud.hudCompassMode = hud.hudCompassMode === 0 ? 1 : 0
            }
        }

        // ------------------------------------------------------------------
        // 1) COMPASS DIAL (this one will ROTATE)
        // ------------------------------------------------------------------
>>>>>>> 2ec41fb76... HUD
        Canvas {
            id: compassCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
<<<<<<< HEAD
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
=======
                var ctx = getContext("2d")
                ctx.reset && ctx.reset()
                ctx.clearRect(0, 0, width, height)

                var cx = width / 2
                var cy = height / 2
                var outerR = bottomCompass.compassRadius
                var innerR = outerR * 0.85
                var heading = bottomCompass.headingDeg   // 0..360

                // -------------------- ROTATE WHOLE DIAL --------------------
                ctx.save()
                ctx.translate(cx, cy)
                ctx.rotate(-heading * Math.PI / 180)     // <— rotate by -heading
                ctx.translate(-cx, -cy)

                // ----- OUTER RING -----
                ctx.beginPath()
                ctx.arc(cx, cy, outerR, 0, Math.PI * 2, false)
                ctx.fillStyle = "rgba(0,0,0,0.35)"
                ctx.fill()

                ctx.beginPath()
                ctx.arc(cx, cy, outerR, 0, Math.PI * 2, false)
                ctx.lineWidth = 2
                ctx.strokeStyle = "rgba(255,255,255,0.35)"
                ctx.stroke()

                // ----- INNER DISK -----
                ctx.beginPath()
                ctx.arc(cx, cy, innerR, 0, Math.PI * 2, false)
                ctx.fillStyle = "rgba(0,0,0,0.20)"
                ctx.fill()

                // ----- RADIAL SECTORS -----
                var sectors = 8
                ctx.save()
                ctx.translate(cx, cy)
                for (var i = 0; i < sectors; i++) {
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    var a0 = (i * 2 * Math.PI / sectors) - Math.PI/2
                    var a1 = ((i + 1) * 2 * Math.PI / sectors) - Math.PI/2
                    ctx.arc(0, 0, innerR, a0, a1, false)
                    ctx.closePath()
                    ctx.fillStyle = (i % 2 === 0)
                            ? "rgba(120,120,120,0.05)"
                            : "rgba(120,120,120,0.14)"
>>>>>>> 2ec41fb76... HUD
                    ctx.fill()
                }
                ctx.restore()

<<<<<<< HEAD
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
=======
                // ----- TICKS + CARDINALS -----
                ctx.save()
                ctx.translate(cx, cy)

                var cardinals = [
                    {deg:   0, label: "N"},
                    {deg:  90, label: "E"},
                    {deg: 180, label: "S"},
                    {deg: 270, label: "W"}
                ]

                // ticks every 30°
                for (var a = 0; a < 360; a += 30) {
                    var rad = (a - 90) * Math.PI / 180
                    var r1 = outerR - 2
                    var r2 = outerR - 10
>>>>>>> 2ec41fb76... HUD
                    ctx.beginPath()
                    ctx.moveTo(Math.cos(rad)*r1, Math.sin(rad)*r1)
                    ctx.lineTo(Math.cos(rad)*r2, Math.sin(rad)*r2)
                    ctx.lineWidth = 2
                    ctx.strokeStyle = "rgba(255,255,255,0.4)"
                    ctx.stroke()
                }
<<<<<<< HEAD
=======

                // cardinal letters
>>>>>>> 2ec41fb76... HUD
                ctx.fillStyle = "#ffffff"
                ctx.font = "bold " + (outerR * 0.20) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                cardinals.forEach(function(c) {
<<<<<<< HEAD
                    const rad = (c.deg - 90) * Math.PI / 180
                    const rtxt = outerR - 16
=======
                    var rad = (c.deg - 90) * Math.PI / 180
                    var rtxt = outerR - 16
>>>>>>> 2ec41fb76... HUD
                    ctx.save()
                    ctx.translate(Math.cos(rad)*rtxt, Math.sin(rad)*rtxt)
                    ctx.fillText(c.label, 0, 0)
                    ctx.restore()
                })
<<<<<<< HEAD
                ctx.restore(); ctx.restore()

                // fixed heading number
                const headingStr = ("000" + Math.round(heading)).slice(-3)
=======

                ctx.restore()
                ctx.restore() // <— important, end rotation

                // -------------------- FIXED OVERLAYS --------------------
                // white up line
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(cx, cy - innerR)
                ctx.lineWidth = 2
                ctx.strokeStyle = "rgba(255,255,255,0.85)"
                ctx.stroke()

                // heading number (fixed)
                var headingStr = ("000" + Math.round(heading)).slice(-3)
>>>>>>> 2ec41fb76... HUD
                ctx.font = "bold " + (outerR * 0.22) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "bottom"
                ctx.fillStyle = "rgba(0,255,128,0.95)"
                ctx.fillText(headingStr, cx, cy - outerR - 4)
<<<<<<< HEAD
            }
        }

=======

                // // yellow top marker
                // var triW = outerR * 0.25
                // var triH = outerR * 0.18
                // ctx.beginPath()
                // ctx.moveTo(cx, cy - outerR - triH - 6)
                // ctx.lineTo(cx - triW/2, cy - outerR - 6)
                // ctx.lineTo(cx + triW/2, cy - outerR - 6)
                // ctx.closePath()
                // ctx.fillStyle = "rgba(255,200,0,1.0)"
                // ctx.fill()
                // ctx.lineWidth = 1
                // ctx.strokeStyle = "rgba(0,0,0,0.3)"
                // ctx.stroke()
            }
        }

        // ensure repaint
>>>>>>> 2ec41fb76... HUD
        onWidthChanged: compassCanvas.requestPaint()
        onHeightChanged: compassCanvas.requestPaint()
        onHeadingDegChanged: compassCanvas.requestPaint()

<<<<<<< HEAD
        // 2) FIXED ARROW
=======
        // ------------------------------------------------------------------
        // 2) FIXED ARROW (no rotation now)
        // ------------------------------------------------------------------
>>>>>>> 2ec41fb76... HUD
        Item {
            id: headingArrow
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
<<<<<<< HEAD
            visible: !!vehicle
=======
            visible: vehicle !== null
            rotation: 0    // <— remove rotation
>>>>>>> 2ec41fb76... HUD

            Canvas {
                id: headingArrowCanvas
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                antialiasing: true

                onPaint: {
<<<<<<< HEAD
                    const ctx = getContext("2d")
                    ctx.clearRect(0,0,width,height)

                    const cx = width/2
                    const cy = height/2
                    const len = Math.min(width, height) * 0.40

                    ctx.beginPath()
                    ctx.moveTo(cx, cy - len/4)
                    ctx.lineTo(cx - 6, cy)
                    ctx.lineTo(cx + 6, cy)
                    ctx.closePath()
                    ctx.fillStyle = "rgba(180,255,26,0.5)"; ctx.fill()

                    ctx.beginPath()
                    ctx.arc(cx, cy, 3, 0, Math.PI*2, false)
                    ctx.fillStyle = cGreen; ctx.fill()
=======
                    var ctx = getContext("2d")
                    ctx.clearRect(0,0,width,height)

                    var cx = width/2
                    var cy = height/2
                    var len = Math.min(width, height) * 0.40

                    // arrow pointing UP
                    ctx.beginPath()
                    ctx.moveTo(cx, cy - len)
                    ctx.lineTo(cx - 6, cy)
                    ctx.lineTo(cx + 6, cy)
                    ctx.closePath()

                    ctx.fillStyle = Qt.rgba(0.7, 1.0, 0.1, 0.5)
                    ctx.fill()

                    // center dot
                    ctx.beginPath()
                    ctx.arc(cx, cy, 3, 0, Math.PI*2, false)
                    ctx.fillStyle = cGreen
                    ctx.fill()
>>>>>>> 2ec41fb76... HUD
                }
            }
        }

<<<<<<< HEAD
        // 3) launch/home indicator and gimbal azimuth
        Rectangle {
            id: launchIndicator
            visible: bottomCompass.showLaunchIndicator()
            width: 22; height: 22
=======
        // ------------------------------------------------------------------
        // 3) launch/home indicator and gimbal repeater
        // (can stay as you had it)
        // ------------------------------------------------------------------
        Rectangle {
            id: launchIndicator
            visible: bottomCompass.showLaunchIndicator()
            width:  22
            height: 22
>>>>>>> 2ec41fb76... HUD
            radius: width/2
            color: "transparent"
            border.color: bottomCompass.compassColor
            border.width: 3

            property real _a: bottomCompass.launchHeadingDeg
            x: {
<<<<<<< HEAD
                if (!visible) return 0
                const a = _a * Math.PI / 180.0
                const cx = bottomCompass.width / 2
                return cx + bottomCompass.compassRadius * Math.sin(a) - width/2
            }
            y: {
                if (!visible) return 0
                const a = _a * Math.PI / 180.0
                const cy = bottomCompass.height / 2
                return cy - bottomCompass.compassRadius * Math.cos(a) - height/2
=======
                if (!visible) return 0;
                var a = _a * Math.PI / 180.0;
                var cx = bottomCompass.width / 2;
                return cx + bottomCompass.compassRadius * Math.sin(a) - width/2;
            }
            y: {
                if (!visible) return 0;
                var a = _a * Math.PI / 180.0;
                var cy = bottomCompass.height / 2;
                return cy - bottomCompass.compassRadius * Math.cos(a) - height/2;
>>>>>>> 2ec41fb76... HUD
            }

            QGCLabel {
                anchors.centerIn: parent
                text: "L"
                font.bold: true
                color: bottomCompass.compassColor
            }
        }

<<<<<<< HEAD
        Repeater {
            id: gimbalRep
            model: vehicle && vehicle.gimbalController ? vehicle.gimbalController.gimbals : []

            delegate: Item {
                id: gimbalItem
                anchors.centerIn: bottomCompass
                width: bottomCompass.width
                height: bottomCompass.height

                function norm360(d) {
                    return ((d % 360) + 360) % 360
                }
                function wrap180(d) {
                    let a = ((d + 180) % 360 + 360) % 360
                    return a - 180
                }

                property real _lastGoodAbsYaw: 0
                property bool _haveLast: false

                readonly property bool _absYawValid: object && object.absoluteYaw && Number.isFinite(object.absoluteYaw.rawValue)
                readonly property real _absYawDeg: _absYawValid ? object.absoluteYaw.rawValue
                                                            : (_haveLast ? _lastGoodAbsYaw : 0)

                readonly property real droneHeading: norm360(bottomCompass.headingDeg)

                readonly property real _rel1: wrap180(norm360(_absYawDeg) - droneHeading)
                readonly property real _rel2: wrap180(norm360(_absYawDeg + 90) - droneHeading)

                property real _lastRel: 0
                readonly property real relAngleDeg: {
                    const cand1 = _rel1
                    const cand2 = _rel2
                    function dist(a,b){ return Math.abs(wrap180(a-b)) }
                    const chosen = (dist(cand1, _lastRel) <= dist(cand2, _lastRel)) ? cand1 : cand2
                    _lastRel = chosen
                    return chosen
                }

                on_AbsYawDegChanged: {
                    if (_absYawValid) { _lastGoodAbsYaw = _absYawDeg; _haveLast = true }
                }


                visible: vehicle
                        && QGroundControl.settingsManager.gimbalControllerSettings.showAzimuthIndicatorOnMap.rawValue

                opacity: object === vehicle.gimbalController.activeGimbal ? 1.0 : 0.4

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

                        let aCenter = (gimbalItem.relAngleDeg) * Math.PI / 180.0
                        aCenter -= Math.PI / 2

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
                }

                Connections { target: bottomCompass; function onHeadingDegChanged() { gimbalCanvas.requestPaint() } }
                Connections { target: object && object.absoluteYaw ? object.absoluteYaw : null
                            function onRawValueChanged() { gimbalCanvas.requestPaint() } }
            }
        }
    }
}
=======
            // 2) gimbal indicators

            Repeater {
                id: gimbalRep
                model: vehicle && vehicle.gimbalController ? vehicle.gimbalController.gimbals : []

                delegate: Item {
                    id: gimbalItem
                    anchors.centerIn: bottomCompass
                    width: bottomCompass.width
                    height: bottomCompass.height

                    readonly property real gimbalYaw: {
                        if (!object) return 0
                        if (object.absoluteYaw && isFinite(object.absoluteYaw.rawValue))
                            return object.absoluteYaw.rawValue
                        return 0
                    }

                    readonly property real droneHeading: bottomCompass.headingDeg
                    readonly property real relAngleDeg: gimbalYaw - droneHeading

                    visible: vehicle
                            && !isNaN(gimbalYaw)
                            && QGroundControl.settingsManager.gimbalControllerSettings
                                    .showAzimuthIndicatorOnMap.rawValue

                    opacity: object === vehicle.gimbalController.activeGimbal ? 1.0 : 0.4

                    Canvas {
                        id: gimbalCanvas
                        anchors.fill: parent
                        antialiasing: true

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0,0,width,height)

                            var cx = width / 2
                            var cy = height / 2
                            var r  = bottomCompass.compassRadius - 1.5

                            // compute relative angle in radians (0° = up)
                            var aCenter = (gimbalItem.relAngleDeg) * Math.PI / 180.0
                            aCenter -= Math.PI / 2 // canvas 0 rad = right

                            // span of indicator
                            var spanDeg = 10
                            var spanRad = spanDeg * Math.PI / 180.0
                            var a1 = aCenter - spanRad/2
                            var a2 = aCenter + spanRad/2

                            var col = (gimbalItem.opacity === 1.0)
                                    ? "rgba(255,140,0,1.0)"      // active gimbal border
                                    : "rgba(255,140,0,0.35)"     // inactive

                            // ---------- FILL SECTOR ----------
                            ctx.beginPath()
                            ctx.moveTo(cx, cy)
                            ctx.arc(cx, cy, r, a1, a2, false)
                            ctx.closePath()

                            ctx.fillStyle = (gimbalItem.opacity === 1.0)
                                    ? "rgba(255,140,0,0.25)"     // active fill
                                    : "rgba(255,140,0,0.15)"     // inactive fill
                            ctx.fill()

                            // ---------- STROKE BORDER ----------
                            // ctx.lineWidth = 2
                            // ctx.strokeStyle = col
                            // ctx.stroke()

                            // ---------- OPTIONAL EDGE LINES (for clarity) ----------
                            ctx.beginPath()
                            ctx.lineWidth = 1.5
                            ctx.strokeStyle = "rgba(0,0,0,0.4)"
                            ctx.moveTo(cx, cy)
                            ctx.lineTo(cx + Math.cos(a1) * r, cy + Math.sin(a1) * r)
                            ctx.moveTo(cx, cy)
                            ctx.lineTo(cx + Math.cos(a2) * r, cy + Math.sin(a2) * r)
                            ctx.stroke()
                        }
                    }

                    Connections {
                        target: bottomCompass
                        function onHeadingDegChanged() { gimbalCanvas.requestPaint() }
                    }
                    Connections {
                        target: object && object.absoluteYaw ? object.absoluteYaw : null
                        function onRawValueChanged() { gimbalCanvas.requestPaint() }
                    }
                }
            }



            // Repeater {
            //     id: gimbalRep
            //     model: vehicle && vehicle.gimbalController ? vehicle.gimbalController.gimbals : []

            //     delegate: Item {
            //         id: gimbalItem
            //         anchors.centerIn: bottomCompass
            //         width: bottomCompass.width
            //         height: bottomCompass.height

            //         readonly property real gimbalYaw: {
            //             if (!object) return 0
            //             if (object.absoluteYaw && isFinite(object.absoluteYaw.rawValue))
            //                 return object.absoluteYaw.rawValue
            //             return 0
            //         }

            //         readonly property real droneHeading: bottomCompass.headingDeg
            //         rotation: gimbalYaw-droneHeading

            //         visible: vehicle
            //                 && !isNaN(gimbalYaw)
            //                 && QGroundControl.settingsManager.gimbalControllerSettings
            //                         .showAzimuthIndicatorOnMap.rawValue

            //         opacity: object === vehicle.gimbalController.activeGimbal ? 1.0 : 0.4

            //         Canvas {
            //             id: gimbalCanvas
            //             anchors.fill: parent
            //             antialiasing: true

            //             onPaint: {
            //                 var ctx = getContext("2d")
            //                 ctx.clearRect(0,0,width,height)

            //                 var cx = width / 2
            //                 var cy = height / 2
            //                 var r  = Math.min(width, height) * 0.35

            //                 // triangle with tip at center, wide edge at outer radius
            //                 ctx.beginPath()
            //                 // tip in the rotation axis (center)
            //                 ctx.moveTo(cx, cy)

            //                 // wide base on the circle
            //                 ctx.lineTo(cx - 20, cy - r)   // left edge on the rim
            //                 ctx.lineTo(cx + 20, cy - r)   // right edge on the rim

            //                 ctx.closePath()

            //                 ctx.fillStyle = Qt.rgba(1.0, 0.5, 0.0, 0.4)
            //                 ctx.fill()

            //                 ctx.lineWidth = 1
            //                 ctx.strokeStyle = Qt.rgba(0,0,0,0.4)
            //                 ctx.stroke()
            //             }

            //         }

            //         onRotationChanged: gimbalCanvas.requestPaint()

            //         Connections {
            //             target: bottomCompass
            //             function onHeadingDegChanged() {
            //                 gimbalCanvas.requestPaint()
            //             }
            //         }

            //         Connections {
            //             target: object && object.absoluteYaw ? object.absoluteYaw : null
            //             function onRawValueChanged() {
            //                 gimbalCanvas.requestPaint()
            //             }
            //         }
            //     }
            // }
    }

    // Item {
    //     id: bottomCompass
    //     width: hud.width * 0.10
    //     height: width
    //     anchors.horizontalCenter: parent.horizontalCenter
    //     anchors.bottom: parent.bottom
    //     anchors.bottomMargin: hud.pad * 2
    //     visible: hud.hudCompassMode    // vehicle !== null

    //     signal compassClicked(real angleDeg)

    //     // base colors
    //     property color compassColor: cGreen

    //     // ---- NEW: radius we use for markers (same as in Canvas) ----
    //     readonly property real compassRadius: Math.min(width, height) * 0.40

    //     // ---- NEW: heading to launch/home ----
    //     // try to read it from vehicle; adapt to your real property name
    //     readonly property real launchHeadingDeg: {
    //         if (vehicle && vehicle.headingToHome && isFinite(vehicle.headingToHome.rawValue)) {
    //             // QGC usually: 0 = north, increases clockwise
    //             return vehicle.headingToHome.rawValue
    //         }
    //         // fallback – if you have _headingToNextWP on hud/vehicle, you can use that
    //         if (vehicle && vehicle.headingToNextWP && isFinite(vehicle.headingToNextWP.rawValue)) {
    //             return vehicle.headingToNextWP.rawValue
    //         }
    //         return NaN
    //     }

    //     // ---- NEW: helper to know if we should show it ----
    //     function showLaunchIndicator() {
    //         return isFinite(bottomCompass.launchHeadingDeg)
    //     }

    //     // we reuse this to get heading
    //     readonly property real headingDeg: {
    //         if (!vehicle || !vehicle.heading) return 0
    //         var h = vehicle.heading.rawValue !== undefined ? vehicle.heading.rawValue : vehicle.heading
    //         return isFinite(h) ? h : 0
    //     }

    //     MouseArea {
    //         anchors.fill: parent
    //         onClicked: {
    //             // toggle 0 <-> 1
    //             hud.hudCompassMode = hud.hudCompassMode === 0 ? 1 : 0
    //             console.log("hudCompassMode =", hud.hudCompassMode)
    //         }
    //     }

    //     Connections {
    //         target: bottomCompass
    //         function onCompassClicked(angleDeg) {
    //             console.log("Request gimbal/yaw to", angleDeg);
    //             if (vehicle && vehicle.gimbalController) {
    //                 if (vehicle.gimbalController.setYawAbsolute) {
    //                     vehicle.gimbalController.setYawAbsolute(angleDeg);
    //                 }
    //             }
    //         }
    //     }

    //     // base compass drawing (ring, cross, dots)
    //     Canvas {
    //         id: compassCanvas
    //         anchors.fill: parent
    //         antialiasing: true

    //         onPaint: {
    //             var ctx = getContext("2d")
    //             ctx.reset && ctx.reset()
    //             ctx.clearRect(0, 0, width, height)

    //             var cx = width / 2
    //             var cy = height / 2
    //             var outerR = bottomCompass.compassRadius      // use the property
    //             var innerR = outerR * 0.16                    // small center

    //             // dashed circle
    //             ctx.save()
    //             ctx.setLineDash([6, 6])
    //             ctx.lineWidth = 5
    //             ctx.strokeStyle = bottomCompass.compassColor
    //             ctx.beginPath()
    //             ctx.arc(cx, cy, outerR, 0, Math.PI * 2, false)
    //             ctx.stroke()
    //             ctx.restore()

    //             // cross lines (up, right, down, left)
    //             ctx.strokeStyle = bottomCompass.compassColor
    //             ctx.lineWidth = 4

    //             // up
    //             ctx.beginPath()
    //             ctx.moveTo(cx, cy - outerR - 15)
    //             ctx.lineTo(cx, cy - outerR + 2)
    //             ctx.stroke()

    //             // down
    //             ctx.beginPath()
    //             ctx.moveTo(cx, cy + outerR - 2)
    //             ctx.lineTo(cx, cy + outerR + 15)
    //             ctx.stroke()

    //             // left
    //             ctx.beginPath()
    //             ctx.moveTo(cx - outerR - 15, cy)
    //             ctx.lineTo(cx - outerR + 2, cy)
    //             ctx.stroke()

    //             // right
    //             ctx.beginPath()
    //             ctx.moveTo(cx + outerR - 2, cy)
    //             ctx.lineTo(cx + outerR + 15, cy)
    //             ctx.stroke()

    //             // end dots
    //             function dot(x, y, r) {
    //                 ctx.beginPath()
    //                 ctx.arc(x, y, r, 0, Math.PI * 2, false)
    //                 ctx.fill()
    //             }

    //             ctx.fillStyle = bottomCompass.compassColor
    //             dot(cx, cy - outerR - 15, 2.5)   // top
    //             dot(cx, cy + outerR + 15, 2.5)   // bottom
    //             dot(cx - outerR - 15, cy, 2.5)   // left
    //             dot(cx + outerR + 15, cy, 2.5)   // right

    //             // small inner circle
    //             ctx.beginPath()
    //             ctx.lineWidth = 1.5
    //             ctx.strokeStyle = bottomCompass.compassColor
    //             ctx.arc(cx, cy, innerR, 0, Math.PI * 2, false)
    //             ctx.stroke()
    //         }
    //     }

    //     // repaint on resize
    //     onWidthChanged: compassCanvas.requestPaint()
    //     onHeightChanged: compassCanvas.requestPaint()

    //     // 1) main heading arrow (drone orientation)
    //     Item {
    //         id: headingArrow
    //         anchors.centerIn: parent
    //         width: parent.width
    //         height: parent.height
    //         visible: vehicle !== null
    //         rotation: bottomCompass.headingDeg  // keep arrow pointing "north" of drone

    //         Canvas {
    //             id: headingArrowCanvas
    //             anchors.centerIn: parent
    //             width: parent.width
    //             height: parent.height
    //             antialiasing: true

    //             onPaint: {
    //                 var ctx = getContext("2d")
    //                 ctx.clearRect(0,0,width,height)

    //                 var cx = width/2
    //                 var cy = height/2
    //                 var len = Math.min(width, height) * 0.40

    //                 // simple triangle arrow
    //                 ctx.beginPath()
    //                 ctx.moveTo(cx, cy - len)         // tip up
    //                 ctx.lineTo(cx - 6, cy)           // left base
    //                 ctx.lineTo(cx + 6, cy)           // right base
    //                 ctx.closePath()

    //                 ctx.fillStyle = Qt.rgba(0.7, 1.0, 0.1, 0.5)  // translucent greenish
    //                 ctx.fill()

    //                 // center dot
    //                 ctx.beginPath()
    //                 ctx.arc(cx, cy, 3, 0, Math.PI*2, false)
    //                 ctx.fillStyle = cGreen
    //                 ctx.fill()
    //             }
    //         }

    //         Component.onCompleted: headingArrowCanvas.requestPaint()
    //     }

    //     // ---- NEW: launch / home indicator (on top of canvases, under gimbals) ----
    //     Rectangle {
    //         id: launchIndicator
    //         visible: bottomCompass.showLaunchIndicator()
    //         width:  22
    //         height: 22
    //         radius: width/2
    //         color: "transparent"
    //         border.color: bottomCompass.compassColor
    //         border.width: 3

    //         // convert angle -> x,y on circle
    //         // 0° = up, cw+
    //         property real _a: bottomCompass.launchHeadingDeg
    //         x: {
    //             if (!visible) return 0;
    //             var a = _a * Math.PI / 180.0;
    //             var cx = bottomCompass.width / 2;
    //             return cx + bottomCompass.compassRadius * Math.sin(a) - width/2;
    //         }
    //         y: {
    //             if (!visible) return 0;
    //             var a = _a * Math.PI / 180.0;
    //             var cy = bottomCompass.height / 2;
    //             return cy - bottomCompass.compassRadius * Math.cos(a) - height/2;
    //         }

    //         QGCLabel {
    //             anchors.centerIn: parent
    //             text: "L"
    //             font.bold: true
    //             color: bottomCompass.compassColor
    //         }
    //     }

    //     // 2) gimbal indicators
    //     Repeater {
    //         id: gimbalRep
    //         model: vehicle && vehicle.gimbalController ? vehicle.gimbalController.gimbals : []

    //         delegate: Item {
    //             id: gimbalItem
    //             anchors.centerIn: bottomCompass
    //             width: bottomCompass.width
    //             height: bottomCompass.height

    //             readonly property real gimbalYaw: {
    //                 if (!object) return 0
    //                 if (object.absoluteYaw && isFinite(object.absoluteYaw.rawValue))
    //                     return object.absoluteYaw.rawValue
    //                 return 0
    //             }

    //             readonly property real droneHeading: bottomCompass.headingDeg
    //             rotation: gimbalYaw

    //             visible: vehicle
    //                     && !isNaN(gimbalYaw)
    //                     && QGroundControl.settingsManager.gimbalControllerSettings
    //                             .showAzimuthIndicatorOnMap.rawValue

    //             opacity: object === vehicle.gimbalController.activeGimbal ? 1.0 : 0.4

    //             Canvas {
    //                 id: gimbalCanvas
    //                 anchors.fill: parent
    //                 antialiasing: true

    //                 onPaint: {
    //                     var ctx = getContext("2d")
    //                     ctx.clearRect(0,0,width,height)

    //                     var cx = width / 2
    //                     var cy = height / 2
    //                     var r  = Math.min(width, height) * 0.35

    //                     // triangle with tip at center, wide edge at outer radius
    //                     ctx.beginPath()
    //                     // tip in the rotation axis (center)
    //                     ctx.moveTo(cx, cy)

    //                     // wide base on the circle
    //                     ctx.lineTo(cx - 20, cy - r)   // left edge on the rim
    //                     ctx.lineTo(cx + 20, cy - r)   // right edge on the rim

    //                     ctx.closePath()

    //                     ctx.fillStyle = Qt.rgba(1.0, 0.5, 0.0, 0.4)
    //                     ctx.fill()

    //                     ctx.lineWidth = 1
    //                     ctx.strokeStyle = Qt.rgba(0,0,0,0.4)
    //                     ctx.stroke()
    //                 }

    //             }

    //             onRotationChanged: gimbalCanvas.requestPaint()

    //             Connections {
    //                 target: bottomCompass
    //                 function onHeadingDegChanged() {
    //                     gimbalCanvas.requestPaint()
    //                 }
    //             }

    //             Connections {
    //                 target: object && object.absoluteYaw ? object.absoluteYaw : null
    //                 function onRawValueChanged() {
    //                     gimbalCanvas.requestPaint()
    //                 }
    //             }
    //         }
    //     }
    // }

    // Item {
    //     id: bottomCompass
    //     width: hud.width * 0.10
    //     height: width
    //     anchors.horizontalCenter: parent.horizontalCenter
    //     anchors.bottom: parent.bottom
    //     anchors.bottomMargin: hud.pad * 2
    //     visible: hud.hudCompassMode//vehicle !== null

    //     signal compassClicked(real angleDeg)

    //     // base colors
    //     property color compassColor: cGreen

    //     // we reuse this to get heading
    //     readonly property real headingDeg: {
    //         if (!vehicle || !vehicle.heading) return 0
    //         var h = vehicle.heading.rawValue !== undefined ? vehicle.heading.rawValue : vehicle.heading
    //         return isFinite(h) ? h : 0
    //     }

    //     MouseArea {
    //         anchors.fill: parent
    //         onClicked: {
    //             // toggle 0 <-> 1
    //             hud.hudCompassMode = hud.hudCompassMode === 0 ? 1 : 0
    //             console.log("hudCompassMode =", hud.hudCompassMode)
    //         }
    //     }

    //     Connections {
    //         target: bottomCompass
    //         function onCompassClicked(angleDeg) {
    //             console.log("Request gimbal/yaw to", angleDeg);
    //             if (vehicle && vehicle.gimbalController) {
    //                 if (vehicle.gimbalController.setYawAbsolute) {
    //                     vehicle.gimbalController.setYawAbsolute(angleDeg);
    //                 }
    //             }
    //         }
    //     }

    //     // base compass drawing (ring, cross, dots)
    //     Canvas {
    //         id: compassCanvas
    //         anchors.fill: parent
    //         antialiasing: true

    //         onPaint: {
    //             var ctx = getContext("2d")
    //             ctx.reset && ctx.reset()
    //             ctx.clearRect(0, 0, width, height)

    //             var cx = width / 2
    //             var cy = height / 2
    //             var outerR = Math.min(width, height) * 0.40     // dashed ring
    //             var innerR = outerR * 0.16                      // small center

    //             // dashed circle
    //             ctx.save()
    //             ctx.setLineDash([6, 6])
    //             ctx.lineWidth = 2
    //             ctx.strokeStyle = bottomCompass.compassColor
    //             ctx.beginPath()
    //             ctx.arc(cx, cy, outerR, 0, Math.PI * 2, false)
    //             ctx.stroke()
    //             ctx.restore()

    //             // cross lines (up, right, down, left)
    //             ctx.strokeStyle = bottomCompass.compassColor
    //             ctx.lineWidth = 2

    //             // up
    //             ctx.beginPath()
    //             ctx.moveTo(cx, cy - outerR - 15)
    //             ctx.lineTo(cx, cy - outerR + 2)
    //             ctx.stroke()

    //             // down
    //             ctx.beginPath()
    //             ctx.moveTo(cx, cy + outerR - 2)
    //             ctx.lineTo(cx, cy + outerR + 15)
    //             ctx.stroke()

    //             // left
    //             ctx.beginPath()
    //             ctx.moveTo(cx - outerR - 15, cy)
    //             ctx.lineTo(cx - outerR + 2, cy)
    //             ctx.stroke()

    //             // right
    //             ctx.beginPath()
    //             ctx.moveTo(cx + outerR - 2, cy)
    //             ctx.lineTo(cx + outerR + 15, cy)
    //             ctx.stroke()

    //             // end dots
    //             function dot(x, y, r) {
    //                 ctx.beginPath()
    //                 ctx.arc(x, y, r, 0, Math.PI * 2, false)
    //                 ctx.fill()
    //             }

    //             ctx.fillStyle = bottomCompass.compassColor
    //             dot(cx, cy - outerR - 15, 2.5)   // top
    //             dot(cx, cy + outerR + 15, 2.5)   // bottom
    //             dot(cx - outerR - 15, cy, 2.5)   // left
    //             dot(cx + outerR + 15, cy, 2.5)   // right

    //             // small inner circle
    //             ctx.beginPath()
    //             ctx.lineWidth = 1.5
    //             ctx.strokeStyle = bottomCompass.compassColor
    //             ctx.arc(cx, cy, innerR, 0, Math.PI * 2, false)
    //             ctx.stroke()
    //         }
    //     }

    //     // repaint on resize
    //     onWidthChanged: compassCanvas.requestPaint()
    //     onHeightChanged: compassCanvas.requestPaint()

    //     // 1) main heading arrow (drone orientation)
    //     Item {
    //         id: headingArrow
    //         anchors.centerIn: parent
    //         width: parent.width
    //         height: parent.height
    //         visible: vehicle !== null
    //         rotation: bottomCompass.headingDeg  // keep arrow pointing "north" of drone

    //         Canvas {
    //             id: headingArrowCanvas
    //             anchors.centerIn: parent
    //             width: parent.width
    //             height: parent.height
    //             antialiasing: true

    //             onPaint: {
    //                 var ctx = getContext("2d")
    //                 ctx.clearRect(0,0,width,height)

    //                 var cx = width/2
    //                 var cy = height/2
    //                 var len = Math.min(width, height) * 0.40

    //                 // simple triangle arrow
    //                 ctx.beginPath()
    //                 ctx.moveTo(cx, cy - len)         // tip up
    //                 ctx.lineTo(cx - 6, cy)           // left base
    //                 ctx.lineTo(cx + 6, cy)           // right base
    //                 ctx.closePath()

    //                 ctx.fillStyle = Qt.rgba(0.7, 1.0, 0.1, 0.35)  // translucent greenish
    //                 ctx.fill()

    //                 // center dot
    //                 ctx.beginPath()
    //                 ctx.arc(cx, cy, 3, 0, Math.PI*2, false)
    //                 ctx.fillStyle = cGreen
    //                 ctx.fill()
    //             }
    //         }

    //         Component.onCompleted: headingArrowCanvas.requestPaint()
    //     }

    //     // we overlay separate rotated items, just like your map code
    //     // 2) gimbal indicators
    //     Repeater {
    //         id: gimbalRep
    //         model: vehicle && vehicle.gimbalController ? vehicle.gimbalController.gimbals : []

    //         delegate: Item {
    //             id: gimbalItem
    //             anchors.centerIn: bottomCompass
    //             width: bottomCompass.width
    //             height: bottomCompass.height

    //             // pull gimbal yaw from model
    //             readonly property real gimbalYaw: {
    //                 if (!object) return 0
    //                 if (object.absoluteYaw && isFinite(object.absoluteYaw.rawValue))
    //                     return object.absoluteYaw.rawValue
    //                 return 0
    //             }

    //             // ALSO depend on headingDeg:
    //             readonly property real droneHeading: bottomCompass.headingDeg

    //             // rotate arrow to gimbal yaw, but compensate drone heading
    //             rotation: gimbalYaw

    //             visible: vehicle
    //                     && !isNaN(gimbalYaw)
    //                     && QGroundControl.settingsManager.gimbalControllerSettings
    //                             .showAzimuthIndicatorOnMap.rawValue

    //             opacity: object === vehicle.gimbalController.activeGimbal ? 1.0 : 0.4

    //             Canvas {
    //                 id: gimbalCanvas
    //                 anchors.fill: parent
    //                 antialiasing: true

    //                 onPaint: {
    //                     var ctx = getContext("2d")
    //                     ctx.clearRect(0,0,width,height)

    //                     var cx = width/2
    //                     var cy = height/2
    //                     var r  = Math.min(width, height) * 0.35

    //                     // arrow
    //                     ctx.beginPath()
    //                     ctx.moveTo(cx, cy - r)
    //                     ctx.lineTo(cx - 5, cy)
    //                     ctx.lineTo(cx + 5, cy)
    //                     ctx.closePath()

    //                     ctx.fillStyle = Qt.rgba(1.0, 0.5, 0.0, 0.7)
    //                     ctx.fill()

    //                     ctx.lineWidth = 1
    //                     ctx.strokeStyle = Qt.rgba(0,0,0,0.3)
    //                     ctx.stroke()
    //                 }
    //             }

    //             // repaint when our own rotation changes (gimbal OR heading changed)
    //             onRotationChanged: gimbalCanvas.requestPaint()

    //             // ALSO repaint when headingDeg changes (binding already does it, but be explicit)
    //             Connections {
    //                 target: bottomCompass
    //                 function onHeadingDegChanged() {
    //                     gimbalCanvas.requestPaint()
    //                 }
    //             }

    //             // if your gimbal object actually emits a signal on yaw change,
    //             // you can connect to it too:
    //             Connections {
    //                 target: object && object.absoluteYaw ? object.absoluteYaw : null
    //                 function onRawValueChanged() {
    //                     gimbalCanvas.requestPaint()
    //                 }
    //             }
    //         }
    //     }
    // }



}
    // // ---------- Bottom-left vertical speed (↓ 3.28 m/s style) ----------
    // Rectangle {
    //     id: vsBox
    //     color: cGreen; border.color: cGreen; border.width: 1; radius: 3
    //     anchors.left: parent.left; anchors.leftMargin: pad*2
    //     anchors.bottom: parent.bottom; anchors.bottomMargin: pad*2
    //     width: Math.max(160, vsLabel.implicitWidth + 16)
    //     height: 36
    //     QGCLabel {
    //         id: vsLabel
    //         anchors.centerIn: parent
    //         color: cText
    //         font.bold: true
    //         font.pointSize: big
    //         text: {
    //             if (!isFinite(vs())) return "--"
    //             var arrow = vs() < 0 ? "↓ " : "↑ "
    //             arrow + Math.abs(vs()).toFixed(1) + " m/s"
    //         }
    //     }
    // }

    // // ---------- Right altitude tape + stacked boxes ----------
    // Item {
    //     id: altTape
    //     width: Math.round(parent.width * 0.06)
    //     anchors.right: parent.right
    //     anchors.verticalCenter: parent.verticalCenter
    //     anchors.rightMargin: pad*2
    //     height: Math.round(parent.height * 0.55)

    //     // ladder
    //     Repeater {
    //         model: 9
    //         delegate: Rectangle {
    //             width: altTape.width
    //             height: 2
    //             color: cGreen
    //             anchors.right: parent.right
    //             anchors.verticalCenter: parent.verticalCenter
    //             y: (index-4)* (altTape.height/10)
    //         }
    //     }

    //     // main altitude readouts stacked
    //     Column {
    //         anchors.right: parent.right
    //         anchors.verticalCenter: parent.verticalCenter
    //         spacing: pad

    //         function altBox(textVal) {
    //             return textVal
    //         }

    //         // Top box
    //         Rectangle {
    //             color: cGreen; border.color: cGreen; border.width: 1; radius: 3
    //             width: Math.max(150, topLabel.implicitWidth + 14); height: 36
    //             QGCLabel {
    //                 id: topLabel
    //                 anchors.centerIn: parent
    //                 color: cText; font.bold: true; font.pointSize: big
    //                 text: isFinite(alt()) ? (Math.round(alt()) + " m") : "--"
    //             }
    //         }
    //         // // Mid box (dummy extra number like in screenshot)
    //         // Rectangle {
    //         //     color: cGreen; border.color: cGreen; border.width: 1; radius: 3
    //         //     width: Math.max(150, midLabel.implicitWidth + 14); height: 36
    //         //     QGCLabel {
    //         //         id: midLabel
    //         //         anchors.centerIn: parent
    //         //         color: cText; font.bold: true; font.pointSize: big
    //         //         text: isFinite(alt()) ? (Math.round(alt()-8) + " m") : "--"
    //         //     }
    //         // }
    //     }
    // }

    // // ---------- Top-right Voltage box (0.0V style) ----------
    // Rectangle {
    //     id: vBox
    //     color: cGreen; border.color: cGreen; border.width: 1; radius: 3
    //     anchors.top: parent.top; anchors.topMargin: Math.round(pad*6)
    //     anchors.right: parent.right; anchors.rightMargin: Math.round(pad*8)
    //     width: Math.max(90, voltLabel.implicitWidth + 12)
    //     height: 36
    //     QGCLabel {
    //         id: voltLabel
    //         anchors.centerIn: parent
    //         color: cText
    //         font.bold: true
    //         font.pointSize: big
    //         text: isFinite(volts()) ? volts().toFixed(1) + "V" : "--"
    //     }
    // }

    // // ---------- Top-left mode box (A | STAB style) ----------
    // Rectangle {
    //     id: modeBox
    //     color: cGreen; border.color: cGreen; border.width: 1; radius: 3
    //     anchors.left: parent.left; anchors.leftMargin: Math.round(pad*2)
    //     anchors.top: parent.top; anchors.topMargin: Math.round(pad*6)
    //     width: Math.max(140, modeLabel.implicitWidth + 12)
    //     height: 32
    //     QGCLabel {
    //         id: modeLabel
    //         anchors.centerIn: parent
    //         color: cText; font.bold: true; font.pointSize: big
    //         text: {
    //             let m = vehicle && vehicle.flightMode ? vehicle.flightMode : "----"
    //             // “A | STAB” demo: prefix with A if armed
    //             let armed = vehicle && vehicle.armed ? "A | " : ""
    //             armed + m
    //         }
    //     }
    // }

>>>>>>> 2ec41fb76... HUD
