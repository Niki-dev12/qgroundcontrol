// CustomHudOverlay.qml
import QtQuick
import QGroundControl
import QGroundControl.Controls

Item {
    id: hud
    // Make absolutely sure we fill our parent
    anchors.fill: parent
    x: 0; y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    // External bindings from parent file
    property var vehicle
    property var camera
    property var pipState

    property int hudCompassMode: 1

    // ---- Style ----
    readonly property color cGreen: "#11C900"     // bright HUD green
    readonly property color cFill : "#112511"     // translucent green fill
    readonly property color cBox  : "#11C900"
    readonly property color cText : "#000000"     // black text inside green boxes
    readonly property real  thick : 5
    readonly property real  pad   : Math.round(width * 0.01)
    readonly property real  big   : ScreenTools.largeFontPointSize
    readonly property real  sm    : ScreenTools.smallFontPointSize

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

        Rectangle { anchors.fill: parent; color: "transparent" }

        // Center caret
        Rectangle {
            width: 14; height: 10; color: "transparent"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            border.color: cGreen; border.width: thick
        }

        MouseArea {
            anchors.fill: parent
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

                    // Compass label (0° = N)
                    text: {
                        const centerDeg = deg;                                   // heading for this tick
                        const idx = Math.round((centerDeg / 45) % 8 + 8) % 8;    // normalized 0–7
                        const comps = ["N","NE","E","SE","S","SW","W","NW"];     // <-- start at North
                        return comps[idx];
                    }
                }



                // Small tick above each label
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: -18
                    width: 3
                    height: 10
                    color: cGreen
                }
            }
        }

    }

    // ---------- Central horizon & reticle ----------
    Item {
        id: horizon
        anchors.fill: parent
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
                // ---------------------------------------------
                ctx.save()
                ctx.translate(width/2, horizonY)
                ctx.rotate(roll() * Math.PI/180)
                ctx.translate(0, -pitch() * 2.0)

                ctx.strokeStyle = cGreen
                ctx.lineWidth = thick

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

                ctx.font = "14px sans-serif"
                ctx.textBaseline = "middle"

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

                ctx.restore()

                // ---------------------------------------------
                // 2) Altitude-driven tick ladder (fixed frame)
                // ---------------------------------------------
                horizon._scrollOffset -= vspd * scrollRate * dt
                // wrap to [0..pxPerTick)
                horizon._scrollOffset = ((horizon._scrollOffset % pxPerTick) + pxPerTick) % pxPerTick

                ctx.strokeStyle = cGreen
                ctx.fillStyle   = cGreen

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
                // ---------------------------------------------
                ctx.strokeStyle = cGreen
                ctx.lineWidth = thick

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

        Connections {
            target: vehicle ? vehicle.altitudeRelative : null
            function onValueChanged() { attitudeCanvas.requestPaint() }
        }
        Connections {
            target: (vehicle && vehicle.climbRate) ? vehicle.climbRate : null
            function onValueChanged() { attitudeCanvas.requestPaint() }
        }

    }

    // ---------- Bottom-center compass using QGC vehicle heading ----------

    // ---------- Bottom-center compass using QGC vehicle heading ----------
    Item {
        id: bottomCompass
        width: hud.width * 0.10
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: hud.pad * 2
        visible: hud.hudCompassMode

        signal compassClicked(real angleDeg)

        property color compassColor: cGreen
        readonly property real compassRadius: Math.min(width, height) * 0.40

        readonly property real launchHeadingDeg: {
            if (vehicle && vehicle.headingToHome && isFinite(vehicle.headingToHome.rawValue)) {
                return vehicle.headingToHome.rawValue
            }
            if (vehicle && vehicle.headingToNextWP && isFinite(vehicle.headingToNextWP.rawValue)) {
                return vehicle.headingToNextWP.rawValue
            }
            return NaN
        }

        function showLaunchIndicator() {
            return isFinite(bottomCompass.launchHeadingDeg)
        }

        // single source of truth for heading
        readonly property real headingDeg: {
            if (!vehicle || !vehicle.heading) return 0
            var h = vehicle.heading.rawValue !== undefined ? vehicle.heading.rawValue : vehicle.heading
            return isFinite(h) ? h : 0
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                hud.hudCompassMode = hud.hudCompassMode === 0 ? 1 : 0
            }
        }

        // ------------------------------------------------------------------
        // 1) COMPASS DIAL (this one will ROTATE)
        // ------------------------------------------------------------------
        Canvas {
            id: compassCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
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
                    ctx.fill()
                }
                ctx.restore()

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
                    ctx.beginPath()
                    ctx.moveTo(Math.cos(rad)*r1, Math.sin(rad)*r1)
                    ctx.lineTo(Math.cos(rad)*r2, Math.sin(rad)*r2)
                    ctx.lineWidth = 2
                    ctx.strokeStyle = "rgba(255,255,255,0.4)"
                    ctx.stroke()
                }

                // cardinal letters
                ctx.fillStyle = "#ffffff"
                ctx.font = "bold " + (outerR * 0.20) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                cardinals.forEach(function(c) {
                    var rad = (c.deg - 90) * Math.PI / 180
                    var rtxt = outerR - 16
                    ctx.save()
                    ctx.translate(Math.cos(rad)*rtxt, Math.sin(rad)*rtxt)
                    ctx.fillText(c.label, 0, 0)
                    ctx.restore()
                })

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
                ctx.font = "bold " + (outerR * 0.22) + "px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "bottom"
                ctx.fillStyle = "rgba(0,255,128,0.95)"
                ctx.fillText(headingStr, cx, cy - outerR - 4)

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
        onWidthChanged: compassCanvas.requestPaint()
        onHeightChanged: compassCanvas.requestPaint()
        onHeadingDegChanged: compassCanvas.requestPaint()

        // ------------------------------------------------------------------
        // 2) FIXED ARROW (no rotation now)
        // ------------------------------------------------------------------
        Item {
            id: headingArrow
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            visible: vehicle !== null
            rotation: 0    // <— remove rotation

            Canvas {
                id: headingArrowCanvas
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                antialiasing: true

                onPaint: {
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
                }
            }
        }

        // ------------------------------------------------------------------
        // 3) launch/home indicator and gimbal repeater
        // (can stay as you had it)
        // ------------------------------------------------------------------
        Rectangle {
            id: launchIndicator
            visible: bottomCompass.showLaunchIndicator()
            width:  22
            height: 22
            radius: width/2
            color: "transparent"
            border.color: bottomCompass.compassColor
            border.width: 3

            property real _a: bottomCompass.launchHeadingDeg
            x: {
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
            }

            QGCLabel {
                anchors.centerIn: parent
                text: "L"
                font.bold: true
                color: bottomCompass.compassColor
            }
        }

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

