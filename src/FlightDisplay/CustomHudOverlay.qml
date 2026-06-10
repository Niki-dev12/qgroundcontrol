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

    property int hudCompassmallode: 1

    required property real bottomUiInset
    property bool  videoMinimized: false

    //---------------HUD CONSTANTS------------------

    // Bottom inset behaviour
    readonly property real hudMinimizedBottomMultiplier: 3
    readonly property real hudBottomInsetExtraPx:        8

    // Heading tape
    readonly property real hudHeadingTapeWidthFraction:    0.50
    readonly property real hudHeadingTapeHeightFraction:   0.10
    readonly property int  hudHeadingTapeModelCount:       9
    readonly property real hudHeadingStepDeg:             45
    readonly property real hudHeadingSpanDeg:            180
    readonly property int  hudHeadingCenterIndex:         4
    readonly property int  hudHeadingLabelRadiusPx:       4
    readonly property int  hudHeadingLabelHeightPx:      32
    readonly property int  hudHeadingLabelMinWidthPx:    36
    readonly property int  hudHeadingTickTopMarginPx:   -18
    readonly property int  hudHeadingTickWidthPx:         3
    readonly property int  hudHeadingTickHeightPx:       10

    // Horizon / ladders
    readonly property real hudHorizonCenterYFraction:      0.50
    readonly property real hudLadderHeightFraction:        0.55
    readonly property real hudLadderMaxHeightPx:          260
    readonly property real hudLadderPixelsPerTick:         14
    readonly property real hudLadderVisibleDivisor:        2.0

    readonly property real hudAltTickStep:                 2.0
    readonly property real hudAltMajorEvery:              10.0
    readonly property real hudSpeedTickStep:               0.5
    readonly property real hudSpeedMajorEvery:             1.0

    readonly property real hudLadderHalfspanFraction:      0.25
    readonly property real hudTickBaseLengthFraction:      0.04
    readonly property real hudTickMaxLengthPx:            26
    readonly property real hudMinorTickLengthFactor:       0.55

    readonly property real hudTickBaseThicknessmallinPx:      1.5
    readonly property real hudTickBaseThicknessHeightFactor: 0.004
    readonly property real hudTickMaxThicknessPx:          3.0
    readonly property real hudMajorTickWidthFactor:        1.8

    readonly property real hudTapeLineWidthPx:             2.0
    readonly property real hudEndTickLengthFactor:         1.6

    readonly property real hudPitchTranslateFactor:        2.0
    readonly property real hudHorizonInnerWidthFraction:   0.15
    readonly property int  hudHorizonGapHalfPx:           40

    readonly property int  hudPitchTextYPx:               16
    readonly property int  hudPitchTextHeightPx:          16
    readonly property int  hudPitchPadXPx:                 4
    readonly property int  hudPitchPadYPx:                 2

    readonly property int  hudAltLineOffsetPx:             6
    readonly property int  hudAltLabelGapPx:              12
    readonly property int  hudAltTextHeightPx:            18
    readonly property int  hudAltPadXPx:                   6
    readonly property int  hudAltPadYPx:                   3

    readonly property real hudStrokePixelOffset:           0.5

    //Speed ladder
    readonly property int  hudSpeedTextHeightPx:          18
    readonly property int  hudSpeedPadXPx:                 6
    readonly property int  hudSpeedPadYPx:                 3
    readonly property int  hudSpeedLabelGapPx:            12

    // Crosshair
    readonly property int  hudCrossGapPx:                 20
    readonly property int  hudCrossArmExtraPx:            18

    // Bottom compass sizing
    readonly property real hudCompassTargetWidthFrac:      0.15
    readonly property real hudCompassmallinSizeMult:          8
    readonly property real hudCompassBigSizeMult:         12
    readonly property real hudCompassmallaxSizeMult:         12
    readonly property real hudCompassHalfEpsmallult:          2

    readonly property real hudCompassRadiusFraction:       0.40
    readonly property real hudCompassInnerRadiusFactor:    0.85
    readonly property real hudCompassCardinalFontFrac:     0.20
    readonly property int  hudCompassTickOuterOffsetPx:    2
    readonly property int  hudCompassTickInnerOffsetPx:   10
    readonly property int  hudCompassCardinalTextOffsetPx:16
    readonly property int  hudCompassTickStepDeg:         30
    readonly property int  hudCompassCardinalCount:        8

    readonly property real hudHeadingFontSizeFrac:         0.22
    readonly property int  hudHeadingBaselineOffsetPx:     4

    // Launch indicator & gimbal
    readonly property int  hudLaunchIndicatorSizePx:      22
    readonly property real hudGimbalRadiusOffsetPx:       1.5
    readonly property real hudGimbalSpanDeg:             10
    readonly property real hudGimbalStrokeWidthPx:        1.5

    // Tick
    readonly property real hudMajorTickEps:               1e-6

    // ---- Style ----
    readonly property color cGreen: "#11C900"
    readonly property color cFill : "#112511"
    readonly property color cText : "#000000"
    readonly property real  thick : 5
    readonly property real  pad   : Math.round(width * 0.01)
    readonly property real  big   : ScreenTools.largeFontPointSize
    readonly property real  small    : ScreenTools.smallallFontPointSize

    // Canvas-specific helper colors
    readonly property string highlightFillColor: "rgba(17,201,0,0.5)"

    // Compass / gimbal colors (Canvas strings)
    readonly property string compassOuterFillColor:   "rgba(0,0,0,0.35)"
    readonly property string compassOuterStrokeColor: "rgba(255,255,255,0.35)"
    readonly property string compassInnerFillColor:   "rgba(0,0,0,0.20)"
    readonly property string compassTickStrokeColor:  "rgba(255,255,255,0.4)"
    readonly property string compassCardinalTextColor:"white"
    readonly property string headingTextColor:        "rgba(0,255,128,0.95)"
    readonly property string headingArrowFillColor:   "rgba(180,255,26,0.5)"
    readonly property string gimbalFillActiveColor:   "rgba(255,140,0,0.25)"
    readonly property string gimbalFillInactiveColor: "rgba(255,140,0,0.15)"
    readonly property string gimbalStrokeColor:       "rgba(0,0,0,0.4)"

    property real effectiveBottomInset: videoMinimized
                                        ? (hud.pad * hudMinimizedBottomMultiplier)
                                        : (bottomUiInset + hudBottomInsetExtraPx)

    onEffectiveBottomInsetChanged:
        console.log("[hud] effectiveBottomInset ->", effectiveBottomInset)

    //helpers
    function getNumericValue(source) {
        if (source === undefined || source === null) {
            return NaN
        }
        if (typeof source === "number") {
            return source
        }
        if (source && typeof source.value === "number") {
            return source.value
        }
        if (source && typeof source.rawValue === "number") {
            return source.rawValue
        }
        return NaN
    }

    function isFiniteNumber(value) {
        return Number.isFinite(value)
    }

    //Angle helpers global
    function normalizeAngle360(degrees) {
        const numericAngle = getNumericValue(degrees)
        if (!isFiniteNumber(numericAngle)) {
            return NaN
        }
        let normalized = numericAngle % 360
        if (normalized < 0) {
            normalized += 360
        }
        return normalized
    }

    function normalizeAngle180(degrees) {
        const numericAngle = getNumericValue(degrees)
        if (!isFiniteNumber(numericAngle)) {
            return NaN
        }
        return normalizeAngle360(numericAngle + 180) - 180
    }

    //Accessors
    function getHeading() {
        const headingValue = getNumericValue(vehicle ? vehicle.heading : NaN)
        const normalized   = normalizeAngle360(headingValue)
        return isFiniteNumber(normalized) ? normalized : NaN
    }

    function getPitch() {
        const pitchValue = getNumericValue(vehicle ? vehicle.pitch : NaN)
        return isFiniteNumber(pitchValue) ? pitchValue : NaN
    }

    function getRoll() {
        const rollValue = getNumericValue(vehicle ? vehicle.roll : NaN)
        return isFiniteNumber(rollValue) ? rollValue : NaN
    }

    function getRelativeAltitude() {
        const altitudeValue = getNumericValue(vehicle ? vehicle.altitudeRelative : NaN)
        return isFiniteNumber(altitudeValue) ? altitudeValue : NaN
    }

    function getVerticalSpeed() {
        let verticalSpeedSource = NaN
        if (vehicle) {
            if (vehicle.climbRate !== undefined) {
                verticalSpeedSource = vehicle.climbRate
            } else if (vehicle.verticalSpeed !== undefined) {
                verticalSpeedSource = vehicle.verticalSpeed
            }
        }
        const verticalSpeedValue = getNumericValue(verticalSpeedSource)
        return isFiniteNumber(verticalSpeedValue) ? verticalSpeedValue : NaN
    }

    function getGroundSpeed() {
        let speedSource = NaN
        if (vehicle) {
            if (vehicle.groundSpeed !== undefined) {
                speedSource = vehicle.groundSpeed
            } else if (vehicle.horizontalSpeed !== undefined) {
                speedSource = vehicle.horizontalSpeed
            }
        }
        const speedValue = getNumericValue(speedSource)
        return isFiniteNumber(speedValue) ? speedValue : NaN
    }

    function getBatteryVoltage() {
        let voltageValue = NaN

        if (vehicle && vehicle.battery) {
            voltageValue = getNumericValue(vehicle.battery.voltage)
        }

        if (!isFiniteNumber(voltageValue)) {
            voltageValue = getNumericValue(vehicle ? vehicle.batteryVoltage : NaN)
        }

        return isFiniteNumber(voltageValue) ? voltageValue : NaN
    }

    function factOrNull(factCandidate) {
        return (factCandidate
                && typeof factCandidate === "object"
                && (factCandidate.value !== undefined || factCandidate.rawValue !== undefined))
               ? factCandidate
               : null
    }

    // ---------- Top heading tape ----------
    Item {
        id: headingTape
        width: parent.width * hudHeadingTapeWidthFraction
        anchors.top: parent.top
        anchors.topMargin: pad
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.round(parent.height * hudHeadingTapeHeightFraction)
        visible: hud.hudCompassmallode === 0

        readonly property real headingStepDeg: hudHeadingStepDeg
        readonly property real centerHeadingDeg: {
            const headingValue = getHeading()
            return isFiniteNumber(headingValue) ? headingValue : 0
        }

        Rectangle { anchors.fill: parent; color: "transparent" }

        // Center caret
        Rectangle {
            width: 14
            height: 10
            color: "transparent"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            border.color: cGreen
            border.width: thick
        }

        MouseArea {
            anchors.fill: parent
            onClicked: hud.hudCompassmallode = hud.hudCompassmallode === 0 ? 1 : 0
        }

        // Moving labels
        Repeater {
            id: hdgRep
            model: hudHeadingTapeModelCount
            delegate: Rectangle {
                readonly property real stepDeg:  headingTape.headingStepDeg
                readonly property real center : headingTape.centerHeadingDeg
                readonly property real degree : Math.round(center/stepDeg)*stepDeg
                                                + (index-hudHeadingCenterIndex) * stepDeg
                readonly property real span   : hudHeadingSpanDeg
                readonly property real xCenter: (degree - center) / span * headingTape.width
                                                + headingTape.width / 2

                x: xCenter - width / 2
                anchors.verticalCenter: parent.verticalCenter
                radius: hudHeadingLabelRadiusPx
                color: cGreen
                border.color: cGreen
                border.width: 1
                height: hudHeadingLabelHeightPx
                width: Math.max(hudHeadingLabelMinWidthPx, label.implicitWidth + 12)
                visible: Math.abs(xCenter - headingTape.width / 2)< headingTape.width / 2 + width

                QGCLabel {
                    id: label
                    anchors.centerIn: parent
                    color: cText
                    font.bold: true
                    font.pointSize: big
                    text: {
                        const indexInCompass = Math.round((degree / hudHeadingStepDeg)
                                                          % hudCompassCardinalCount
                                                          + hudCompassCardinalCount)
                                                % hudCompassCardinalCount
                        const labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
                        return labels[indexInCompass]
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: hudHeadingTickTopMarginPx
                    width:  hudHeadingTickWidthPx
                    height: hudHeadingTickHeightPx
                    color: cGreen
                }
            }
        }
    }

    // ---------- Central horizon & reticle ----------
    Item {
        id: horizon
        anchors.fill: parent

        Canvas {
            id: attitudeCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const context = getContext("2d")
                context.clearRect(0, 0, width, height)

                // --- constants / tuning ---
                const horizonY = height * hudHorizonCenterYFraction

                const ladderCenterY = horizonY
                const ladderHeight  = Math.min(height * hudLadderHeightFraction,
                                               hudLadderMaxHeightPx)
                const ladderTop     = ladderCenterY - ladderHeight / 2
                const ladderBottom  = ladderCenterY + ladderHeight / 2

                const ladderPixelsPerTick = hudLadderPixelsPerTick
                const ticksVisible        = Math.floor(
                                                ladderHeight /
                                                (ladderPixelsPerTick * hudLadderVisibleDivisor))

                // Altitude scale
                const altitudeTickStep   = hudAltTickStep
                const altitudeMajorEvery = hudAltMajorEvery
                // Speed scale
                const speedTickStep      = hudSpeedTickStep
                const speedMajorEvery    = hudSpeedMajorEvery

                // live values
                const verticalSpeedValue    = getVerticalSpeed()
                const verticalSpeedNow      = isFiniteNumber(verticalSpeedValue)
                                              ? verticalSpeedValue : 0
                const relativeAltitudeValue = getRelativeAltitude()
                const relativeAltitudeNow   = isFiniteNumber(relativeAltitudeValue)
                                              ? relativeAltitudeValue : 0
                const groundSpeedValue      = getGroundSpeed()
                const groundSpeedNow        = isFiniteNumber(groundSpeedValue)
                                              ? groundSpeedValue : 0

                // helpers
                function ismallajorTick(value, majorStep) {
                    const ratio = value / majorStep
                    return Math.abs(ratio - Math.round(ratio)) < hudMajorTickEps
                }
                // Map a tick value to Y
                function yForTick(currentValue, tickValue, tickStep) {
                    const deltaTicks = (tickValue - currentValue) / tickStep
                    return ladderCenterY - deltaTicks * ladderPixelsPerTick
                }

                // --- geometry shared by labels/ticks ---
                const halfSpan = width * hudLadderHalfspanFraction
                const leftX    = width / 2 - halfSpan
                const rightX   = width / 2 + halfSpan

                const rawTickBaseLength = width * hudTickBaseLengthFraction
                const maxTickLength     = hudTickMaxLengthPx
                const tickBaseLength    = Math.min(rawTickBaseLength, maxTickLength)
                const majorTickLength   = tickBaseLength
                const minorTickLength   = tickBaseLength * hudMinorTickLengthFactor

                const rawTickBaseThickness = Math.max(hudTickBaseThicknessmallinPx,
                                                      height * hudTickBaseThicknessHeightFactor)
                const maxTickThickness     = hudTickMaxThicknessPx
                const tickBaseThickness    = Math.min(rawTickBaseThickness, maxTickThickness)
                const majorTickWidth       = tickBaseThickness * hudMajorTickWidthFactor
                const minorTickWidth       = tickBaseThickness

                const tapeLineWidth  = hudTapeLineWidthPx
                const endTickLength  = majorTickLength * hudEndTickLengthFactor

                // ---------------------------------------------
                // 1) Horizon line (roll/pitch transform)
                // ---------------------------------------------
                context.save()
                context.translate(width / 2, horizonY)
                context.rotate(-getRoll() * Math.PI / 180)
                context.translate(0, getPitch() * hudPitchTranslateFactor)

                context.strokeStyle = cGreen
                context.lineWidth = thick

                const halfSpanInner = width * hudHorizonInnerWidthFraction
                const gapHalf       = hudHorizonGapHalfPx

                // left segment
                context.beginPath()
                context.moveTo(-halfSpanInner, 0)
                context.lineTo(-gapHalf, 0)
                context.stroke()
                // right segment
                context.beginPath()
                context.moveTo(gapHalf, 0)
                context.lineTo(halfSpanInner, 0)
                context.stroke()

                // pitch text (left + right)
                const pitchRounded = Math.round(getPitch() * 10) / 10
                const pitchText    = pitchRounded + "°"

                context.font = "14px sans-serif"
                context.textBaseline = "middle"

                const leftCenterX  = (-halfSpanInner + -gapHalf) / 2
                const rightCenterX = (gapHalf + halfSpanInner) / 2
                const pitchMetrics = context.measureText(pitchText)
                const pitchTextWidth  = pitchMetrics.width
                const pitchTextHeight = hudPitchTextHeightPx
                const pitchPadX       = hudPitchPadXPx
                const pitchPadY       = hudPitchPadYPx

                // background rectangles for pitch labels
                context.save()
                context.fillStyle = hud.highlightFillColor
                context.fillRect(leftCenterX - pitchTextWidth / 2 - pitchPadX,
                                 hudPitchTextYPx - pitchTextHeight / 2 - pitchPadY,
                                 pitchTextWidth + pitchPadX * 2,
                                 pitchTextHeight + pitchPadY * 2)
                context.restore()
                context.fillStyle = cText
                context.textAlign = "center"
                context.fillText(pitchText, leftCenterX, hudPitchTextYPx)

                context.save()
                context.fillStyle = hud.highlightFillColor
                context.fillRect(rightCenterX - pitchTextWidth / 2 - pitchPadX,
                                 hudPitchTextYPx - pitchTextHeight / 2 - pitchPadY,
                                 pitchTextWidth + pitchPadX * 2,
                                 pitchTextHeight + pitchPadY * 2)
                context.restore()
                context.fillStyle = cText
                context.textAlign = "center"
                context.fillText(pitchText, rightCenterX, hudPitchTextYPx)

                context.restore()

                // ---------------------------------------------
                // 2) RIGHT ladder: ALTITUDE  (major every 10 m)
                //    LEFT  ladder: SPEED     (major every 1 m/s)
                //    Both use SAME ladderPxPerTick for symmetry.
                // ---------------------------------------------

                context.strokeStyle = cGreen
                context.fillStyle   = cGreen

                // ALTITUDE (RIGHT)
                {
                    const baseAltitude = Math.floor(relativeAltitudeNow / altitudeTickStep)
                                         * altitudeTickStep

                    const altitudeLineX = rightX - tickBaseLength - hudAltLineOffsetPx


                    context.save()
                    context.strokeStyle = hud.highlightFillColor
                    context.lineWidth   = tapeLineWidth
                    context.beginPath()
                    context.moveTo(altitudeLineX, ladderTop)
                    context.lineTo(altitudeLineX, ladderBottom)
                    context.stroke()
                    context.restore()

                    context.save()
                    context.strokeStyle = cGreen
                    context.lineWidth   = tapeLineWidth

                    context.beginPath()
                    context.moveTo(altitudeLineX, ladderTop)
                    context.lineTo(altitudeLineX + endTickLength, ladderTop)
                    context.stroke()

                    context.beginPath()
                    context.moveTo(altitudeLineX, ladderBottom)
                    context.lineTo(altitudeLineX + endTickLength, ladderBottom)
                    context.stroke()

                    context.restore()

                    const altitudeSign  = verticalSpeedNow >= 0 ? "+" : "−"
                    const altitudeText  = `${relativeAltitudeNow.toFixed(0)} m  `
                                          + `${altitudeSign}${Math.abs(verticalSpeedNow).toFixed(1)} m/s`

                    context.font         = "bold 14px sans-serif"
                    context.textAlign    = "left"
                    context.textBaseline = "middle"

                    const altitudePadX = hudAltPadXPx
                    const altitudePadY = hudAltPadYPx
                    const altitudeMetrics = context.measureText(altitudeText)
                    const altitudeTextWidth  = altitudeMetrics.width
                    const altitudeTextHeight = hudAltTextHeightPx
                    const altitudeRectWidth  = altitudeTextWidth + altitudePadX * 2
                    const altitudeRectHeight = altitudeTextHeight + altitudePadY * 4

                    const altitudeLabelHorizontalGap = hudAltLabelGapPx
                    const altitudeRectX  = altitudeLineX + altitudeLabelHorizontalGap
                    const altitudeRectY  = ladderCenterY - altitudeRectHeight / 2

                    const altitudeLabelTop    = altitudeRectY
                    const altitudeLabelBottom = altitudeRectY + altitudeRectHeight

                    for (let i = -ticksVisible; i <= ticksVisible; i++) {
                        const tickValue = baseAltitude + i * altitudeTickStep
                        const tickY = yForTick(relativeAltitudeNow, tickValue, altitudeTickStep)

                        if (tickY < ladderTop || tickY > ladderBottom) {
                            continue
                        }

                        const majorTick      = ismallajorTick(tickValue, altitudeMajorEvery)
                        context.lineWidth    = majorTick ? majorTickWidth : minorTickWidth
                        const thisTickLength = majorTick ? majorTickLength : minorTickLength

                        const inLabelBand = (tickY >= altitudeLabelTop && tickY <= altitudeLabelBottom)

                        let tickStartX
                        let tickEndX

                        if (inLabelBand) {
                            tickStartX = altitudeLineX
                            tickEndX   = altitudeRectX
                        } else {
                            tickStartX = altitudeLineX
                            tickEndX   = altitudeLineX + thisTickLength
                        }

                        context.beginPath()
                        context.moveTo(tickStartX, tickY)
                        context.lineTo(tickEndX,   tickY)
                        context.stroke()

                        if (majorTick && !inLabelBand) {
                            const labelText    = Math.round(tickValue).toString()
                            const labelGapPx   = 6

                            context.save()
                            context.font         = "13px sans-serif"
                            context.textBaseline = "middle"
                            context.textAlign    = "left"
                            context.fillStyle    = cGreen

                            const labelX = tickEndX + labelGapPx
                            context.fillText(labelText, labelX, tickY)
                            context.restore()
                        }
                    }

                    // background
                    context.save()
                    context.globalAlpha = 0.5
                    context.fillStyle   = cFill
                    context.fillRect(altitudeRectX, altitudeRectY,
                                     altitudeRectWidth, altitudeRectHeight)
                    context.restore()

                    // border
                    const strokePixelOffset = hudStrokePixelOffset
                    context.lineWidth   = 2
                    context.strokeStyle = cGreen
                    context.strokeRect(altitudeRectX + strokePixelOffset,
                                       altitudeRectY + strokePixelOffset,
                                       altitudeRectWidth  - 2 * strokePixelOffset,
                                       altitudeRectHeight - 2 * strokePixelOffset)

                    // text
                    context.fillStyle = cGreen
                    context.fillText(altitudeText,
                                     altitudeRectX + altitudePadX,
                                     ladderCenterY)
                }

                // SPEED (LEFT)
                {
                    const baseSpeed = Math.floor(groundSpeedNow / speedTickStep)
                                      * speedTickStep

                    const speedLineX = leftX + tickBaseLength + hudAltLineOffsetPx

                    context.save()
                    context.strokeStyle = hud.highlightFillColor
                    context.lineWidth   = tapeLineWidth
                    context.beginPath()
                    context.moveTo(speedLineX, ladderTop)
                    context.lineTo(speedLineX, ladderBottom)
                    context.stroke()
                    context.restore()

                    context.save()
                    context.strokeStyle = cGreen
                    context.lineWidth   = tapeLineWidth

                    context.beginPath()
                    context.moveTo(speedLineX - endTickLength, ladderTop)
                    context.lineTo(speedLineX,                 ladderTop)
                    context.stroke()

                    context.beginPath()
                    context.moveTo(speedLineX - endTickLength, ladderBottom)
                    context.lineTo(speedLineX,                 ladderBottom)
                    context.stroke()

                    context.restore()

                    // ---- LEFT fixed label (GS) ----
                    const groundSpeedLabelValue = isFiniteNumber(groundSpeedNow)
                                                  ? groundSpeedNow : 0
                    const groundSpeedText       = `${groundSpeedLabelValue.toFixed(1)} m/s`

                    context.font         = "bold 16px sans-serif"
                    context.textAlign    = "right"
                    context.textBaseline = "middle"

                    const groundSpeedPadX = hudSpeedPadXPx
                    const groundSpeedPadY = hudSpeedPadYPx
                    const groundSpeedMetrics = context.measureText(groundSpeedText)
                    const groundSpeedTextWidth  = groundSpeedMetrics.width
                    const groundSpeedTextHeight = hudSpeedTextHeightPx
                    const groundSpeedRectWidth  = groundSpeedTextWidth + groundSpeedPadX * 2
                    const groundSpeedRectHeight = groundSpeedTextHeight + groundSpeedPadY * 4

                    const speedRectGapToCenterLine = hudSpeedLabelGapPx
                    const speedRectX = speedLineX - groundSpeedRectWidth - speedRectGapToCenterLine
                    const speedRectY = ladderCenterY - groundSpeedRectHeight / 2

                    const speedLabelTop    = speedRectY
                    const speedLabelBottom = speedRectY + groundSpeedRectHeight

                    // --- SPEED ticks (full ladder) ---
                    for (let j = -ticksVisible; j <= ticksVisible; j++) {
                        const tickValue = baseSpeed + j * speedTickStep
                        const tickY = yForTick(groundSpeedNow, tickValue, speedTickStep)

                        if (tickY < ladderTop || tickY > ladderBottom) {
                            continue
                        }

                        const majorTick      = ismallajorTick(tickValue, speedMajorEvery)
                        context.lineWidth    = majorTick ? majorTickWidth : minorTickWidth
                        const thisTickLength = majorTick ? majorTickLength : minorTickLength

                        const inLabelBand = (tickY >= speedLabelTop && tickY <= speedLabelBottom)

                        let tickStartX
                        let tickEndX

                        if (inLabelBand) {
                            tickStartX = speedRectX + groundSpeedRectWidth
                            tickEndX   = speedLineX
                        } else {
                            tickStartX = speedLineX - thisTickLength
                            tickEndX   = speedLineX
                        }

                        context.beginPath()
                        context.moveTo(tickStartX, tickY)
                        context.lineTo(tickEndX,   tickY)
                        context.stroke()

                        if (majorTick && !inLabelBand) {
                            const labelText    = Math.round(tickValue).toString()
                            const labelGapPx   = 6

                            context.save()
                            context.font         = "13px sans-serif"
                            context.textBaseline = "middle"
                            context.textAlign    = "right"
                            context.fillStyle    = cGreen

                            const labelX = tickStartX - labelGapPx
                            context.fillText(labelText, labelX, tickY)
                            context.restore()
                        }
                    }

                    context.save()
                    context.globalAlpha = 0.5
                    context.fillStyle   = cFill
                    context.fillRect(speedRectX, speedRectY,
                                     groundSpeedRectWidth, groundSpeedRectHeight)
                    context.restore()

                    const strokePixelOffset = hudStrokePixelOffset
                    context.lineWidth   = 2
                    context.strokeStyle = cGreen
                    context.strokeRect(speedRectX + strokePixelOffset,
                                       speedRectY + strokePixelOffset,
                                       groundSpeedRectWidth  - 2 * strokePixelOffset,
                                       groundSpeedRectHeight - 2 * strokePixelOffset)

                    context.fillStyle = cGreen
                    context.fillText(groundSpeedText,
                                     speedRectX + groundSpeedRectWidth - groundSpeedPadX,
                                     ladderCenterY)
                }

                // ---------------------------------------------
                // 3) Crosshair
                // ---------------------------------------------
                context.strokeStyle = cGreen
                context.lineWidth = thick

                const centerX    = width / 2
                const centerY    = horizonY
                const crossGap   = hudCrossGapPx
                const armLength  = crossGap + hudCrossArmExtraPx

                // vertical up
                context.beginPath()
                context.moveTo(centerX, centerY - armLength)
                context.lineTo(centerX, centerY - crossGap)
                context.stroke()

                // vertical down
                context.beginPath()
                context.moveTo(centerX, centerY + crossGap)
                context.lineTo(centerX, centerY + armLength)
                context.stroke()

                // horizontal left
                context.beginPath()
                context.moveTo(centerX - armLength, centerY)
                context.lineTo(centerX - crossGap,  centerY)
                context.stroke()

                // horizontal right
                context.beginPath()
                context.moveTo(centerX + crossGap,  centerY)
                context.lineTo(centerX + armLength, centerY)
                context.stroke()
            }
        }

        // Repaint on geometry changes
        onWidthChanged:  attitudeCanvas.requestPaint()
        onHeightChanged: attitudeCanvas.requestPaint()

        // ROLL
        Connections {
            target: factOrNull(vehicle ? vehicle.roll : null)
            function onValueChanged() { attitudeCanvas.requestPaint() }
        }
        Connections {
            target: vehicle
            ignoreUnknownSignals: true
            function onRollChanged() { attitudeCanvas.requestPaint() }
        }

        // PITCH
        Connections {
            target: factOrNull(vehicle ? vehicle.pitch : null)
            function onValueChanged() { attitudeCanvas.requestPaint() }
        }
        Connections {
            target: vehicle
            ignoreUnknownSignals: true
            function onPitchChanged() { attitudeCanvas.requestPaint() }
        }

        // ALT REL
        Connections {
            target: factOrNull(vehicle ? vehicle.altitudeRelative : null)
            function onRawValueChanged() { attitudeCanvas.requestPaint() }
        }
        Connections {
            target: vehicle
            ignoreUnknownSignals: true
            function onAltitudeRelativeChanged() { attitudeCanvas.requestPaint() }
        }

        // CLIMB/VSPD
        Connections {
            target: factOrNull(vehicle ? vehicle.climbRate : null)
            function onRawValueChanged() { attitudeCanvas.requestPaint() }
        }
        Connections {
            target: vehicle
            ignoreUnknownSignals: true
            function onClimbRateChanged() { attitudeCanvas.requestPaint() }
        }

        // GROUND SPEED
        Connections {
            target: factOrNull(vehicle ? vehicle.groundSpeed : null)
            function onRawValueChanged() { attitudeCanvas.requestPaint() }
        }
        Connections {
            target: vehicle
            ignoreUnknownSignals: true
            function onGroundSpeedChanged() { attitudeCanvas.requestPaint() }
        }
    }

    // ---------- Bottom-center compass using QGC vehicle heading ----------
    Item {
        id: bottomCompass

        readonly property real minSizePx:   ScreenTools.defaultFontPixelHeight * hudCompassmallinSizeMult
        readonly property real targetFrac:  hudCompassTargetWidthFrac

        readonly property real screenWidth: Qt.application && Qt.application.screens.length > 0
                                            ? Qt.application.screens[0].width
                                            : width

        readonly property real bigSizePx:   ScreenTools.defaultFontPixelHeight * hudCompassBigSizeMult
        readonly property real maxSizePx:   ScreenTools.defaultFontPixelHeight * hudCompassmallaxSizeMult
        readonly property real halfEpsPx:   ScreenTools.defaultFontPixelHeight * hudCompassHalfEpsmallult

        readonly property bool _inMainWin: Window.window && Window.window === mainWindow
        readonly property bool _fillsmallainWin: _inMainWin &&
                                              Math.abs(hud.width - Window.window.width) <
                                                ScreenTools.defaultFontPixelHeight
        readonly property bool _useFancySizing: _fillsmallainWin

        width: {
            const hudWidth         = hud.width
            const normalScaledSize = Math.max(minSizePx, hudWidth * targetFrac)
            if (!_useFancySizing) {
                return normalScaledSize
            }
            const halfScreenWidth = screenWidth / 2
            if (hudWidth < halfScreenWidth - halfEpsPx) {
                return normalScaledSize
            } else if (Math.abs(hudWidth - halfScreenWidth) <= halfEpsPx) {
                return bigSizePx
            } else {
                return maxSizePx
            }
        }

        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: hud.pad
        visible: hud.hudCompassmallode === 1
        property color compassColor: cGreen
        readonly property real compassRadius: Math.min(width, height) * hudCompassRadiusFraction

        readonly property real launchHeadingDeg: {
            if (vehicle && vehicle.headingToHome && isFiniteNumber(vehicle.headingToHome.rawValue)) {
                return normalizeAngle360(vehicle.headingToHome.rawValue)
            }
            if (vehicle && vehicle.headingToNextWP && isFiniteNumber(vehicle.headingToNextWP.rawValue)) {
                return normalizeAngle360(vehicle.headingToNextWP.rawValue)
            }
            return NaN
        }
        function showLaunchIndicator() { return isFiniteNumber(bottomCompass.launchHeadingDeg) }

        readonly property real headingDeg: {
            const heading = getHeading()
            return isFiniteNumber(heading) ? heading : 0
        }

        MouseArea {
            anchors.fill: parent
            onClicked: hud.hudCompassmallode = hud.hudCompassmallode === 0 ? 1 : 0
        }

        // 1) COMPASS DIAL
        Canvas {
            id: compassCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const context = getContext("2d")
                context.reset && context.reset()
                context.clearRect(0, 0, width, height)

                const centerX = width / 2
                const centerY = height / 2
                const outerRadius = bottomCompass.compassRadius
                const innerRadius = outerRadius * hudCompassInnerRadiusFactor
                const heading = bottomCompass.headingDeg

                context.save()
                context.translate(centerX, centerY)
                context.rotate(-heading * Math.PI / 180)
                context.translate(-centerX, -centerY)

                // OUTER ring
                context.beginPath()
                context.arc(centerX, centerY, outerRadius, 0, Math.PI * 2, false)
                context.fillStyle = hud.compassOuterFillColor
                context.fill()
                context.beginPath()
                context.arc(centerX, centerY, outerRadius, 0, Math.PI * 2, false)
                context.lineWidth = 2
                context.strokeStyle = hud.compassOuterStrokeColor
                context.stroke()

                // INNER disk
                context.beginPath()
                context.arc(centerX, centerY, innerRadius, 0, Math.PI * 2, false)
                context.fillStyle = hud.compassInnerFillColor
                context.fill()

                // sectors
                const sectors = hudCompassCardinalCount
                context.save()
                context.translate(centerX, centerY)
                for (let sectorIndex = 0; sectorIndex < sectors; sectorIndex++) {
                    context.beginPath()
                    context.moveTo(0, 0)
                    const startAngle = (sectorIndex * 2 * Math.PI / sectors) - Math.PI / 2
                    const endAngle   = ((sectorIndex + 1) * 2 * Math.PI / sectors) - Math.PI / 2
                    context.arc(0, 0, innerRadius, startAngle, endAngle, false)
                    context.closePath()
                    context.fillStyle = (sectorIndex % 2 === 0)
                                        ? "rgba(120,120,120,0.05)"
                                        : "rgba(120,120,120,0.14)"
                    context.fill()
                }
                context.restore()

                // ticks + cardinals
                context.save()
                context.translate(centerX, centerY)
                const cardinals = [
                    { deg: 0,   label: "N" },
                    { deg: 90,  label: "E" },
                    { deg: 180, label: "S" },
                    { deg: 270, label: "W" }
                ]
                for (let angle = 0; angle < 360; angle += hudCompassTickStepDeg) {
                    const radians = (angle - 90) * Math.PI / 180
                    const tickOuterRadius = outerRadius - hudCompassTickOuterOffsetPx
                    const tickInnerRadius = outerRadius - hudCompassTickInnerOffsetPx
                    context.beginPath()
                    context.moveTo(Math.cos(radians) * tickOuterRadius,
                                   Math.sin(radians) * tickOuterRadius)
                    context.lineTo(Math.cos(radians) * tickInnerRadius,
                                   Math.sin(radians) * tickInnerRadius)
                    context.lineWidth = 2
                    context.strokeStyle = hud.compassTickStrokeColor
                    context.stroke()
                }
                context.fillStyle = hud.compassCardinalTextColor
                context.font = "bold " + (outerRadius * hudCompassCardinalFontFrac) + "px sans-serif"
                context.textAlign = "center"
                context.textBaseline = "middle"
                cardinals.forEach(function(cardinal) {
                    const radians = (cardinal.deg - 90) * Math.PI / 180
                    const textRadius = outerRadius - hudCompassCardinalTextOffsetPx
                    context.save()
                    context.translate(Math.cos(radians) * textRadius,
                                      Math.sin(radians) * textRadius)
                    context.fillText(cardinal.label, 0, 0)
                    context.restore()
                })
                context.restore()
                context.restore()

                // fixed heading number
                const headingString = ("000" + Math.round(heading)).slice(-3)

                const headingFontSize = outerRadius * hudHeadingFontSizeFrac
                context.font = "bold " + headingFontSize + "px sans-serif"
                context.textAlign = "center"
                context.textBaseline = "bottom"
                context.fillStyle = hud.headingTextColor

                const desiredBaselineY   = centerY - outerRadius - hudHeadingBaselineOffsetPx
                const minimumBaselineY   = headingFontSize + hudHeadingBaselineOffsetPx
                const textBaselineY      = Math.max(minimumBaselineY, desiredBaselineY)
                context.fillText(headingString, centerX, textBaselineY)
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
                    const context = getContext("2d")
                    context.clearRect(0,0,width,height)

                    const centerX = width/2
                    const centerY = height/2
                    const arrowLength = Math.min(width, height) * hudCompassRadiusFraction

                    context.beginPath()
                    context.moveTo(centerX, centerY - arrowLength / 4)
                    context.lineTo(centerX - 6, centerY)
                    context.lineTo(centerX + 6, centerY)
                    context.closePath()
                    context.fillStyle = hud.headingArrowFillColor
                    context.fill()

                    context.beginPath()
                    context.arc(centerX, centerY, 3, 0, Math.PI*2, false)
                    context.fillStyle = cGreen
                    context.fill()
                }
            }
        }

        Rectangle {
            id: launchIndicator
            visible: bottomCompass.showLaunchIndicator()
            width:  hudLaunchIndicatorSizePx
            height: hudLaunchIndicatorSizePx
            radius: width / 2
            color: "red"

            property real _relativeAngleDeg: {
                if (!visible || !isFiniteNumber(bottomCompass.launchHeadingDeg)) {
                    return 0
                }
                const headingDifference = bottomCompass.launchHeadingDeg - bottomCompass.headingDeg
                return normalizeAngle360(headingDifference)
            }

            x: {
                if (!visible) return 0
                const radians = _relativeAngleDeg * Math.PI / 180.0
                const centerX = bottomCompass.width / 2
                return centerX + bottomCompass.compassRadius * Math.sin(radians) - width / 2
            }
            y: {
                if (!visible) return 0
                const radians = _relativeAngleDeg * Math.PI / 180.0
                const centerY = bottomCompass.height / 2
                return centerY - bottomCompass.compassRadius * Math.cos(radians) - height / 2
            }

            QGCLabel {
                anchors.centerIn: parent
                text: "L"
                font.bold: true
                color: cGreen
            }
        }

        // 3) launch/home indicator
        Repeater {
            id: gimbalRep
            model: vehicle && vehicle.gimbalController ? vehicle.gimbalController.gimbals : []

            delegate: Item {
                id: gimbalItem
                anchors.centerIn: bottomCompass
                width: bottomCompass.width
                height: bottomCompass.height

                property real _lastGoodAbsoluteYaw: 0
                property bool _hasLastGoodYaw: false

                readonly property bool _absoluteYawValid: object
                                                        && object.absoluteYaw
                                                        && isFiniteNumber(object.absoluteYaw.rawValue)
                readonly property real _absoluteYawDeg: _absoluteYawValid
                                                        ? object.absoluteYaw.rawValue
                                                        : (_hasLastGoodYaw ? _lastGoodAbsoluteYaw : 0)

                readonly property real droneHeadingDeg: normalizeAngle360(bottomCompass.headingDeg)

                property real mountYawOffsetDeg: 0

                readonly property real relAngleDeg: {
                    if (!_absoluteYawValid || !isFiniteNumber(droneHeadingDeg)) {
                        return 0
                    }
                    const absoluteYawWithOffset = _absoluteYawDeg + mountYawOffsetDeg
                    return normalizeAngle180(absoluteYawWithOffset - droneHeadingDeg)
                }

                on_AbsoluteYawDegChanged: {
                    if (_absoluteYawValid) {
                        _lastGoodAbsoluteYaw = _absoluteYawDeg
                        _hasLastGoodYaw = true
                    }
                }

                visible: vehicle
                         && QGroundControl.settingsmallanager.gimbalControllerSettings
                                .showAzimuthIndicatorOnMap.rawValue

                opacity: object === vehicle.gimbalController.activeGimbal ? 1.0 : 0.4

                Canvas {
                    id: gimbalCanvas
                    anchors.fill: parent
                    antialiasing: true

                    onPaint: {
                        const context = getContext("2d")
                        context.clearRect(0,0,width,height)

                        const centerX = width / 2
                        const centerY = height / 2
                        const radius  = bottomCompass.compassRadius - hudGimbalRadiusOffsetPx

                        let angleCenter = gimbalItem.relAngleDeg * Math.PI / 180.0
                        angleCenter -= Math.PI / 2

                        const spanDeg = hudGimbalSpanDeg
                        const spanRad = spanDeg * Math.PI / 180.0
                        const angleStart = angleCenter - spanRad/2
                        const angleEnd   = angleCenter + spanRad/2

                        context.beginPath()
                        context.moveTo(centerX, centerY)
                        context.arc(centerX, centerY, radius, angleStart, angleEnd, false)
                        context.closePath()
                        context.fillStyle = (gimbalItem.opacity === 1.0)
                            ? hud.gimbalFillActiveColor
                            : hud.gimbalFillInactiveColor
                        context.fill()

                        context.beginPath()
                        context.lineWidth = hudGimbalStrokeWidthPx
                        context.strokeStyle = hud.gimbalStrokeColor
                        context.moveTo(centerX, centerY)
                        context.lineTo(centerX + Math.cos(angleStart) * radius,
                                       centerY + Math.sin(angleStart) * radius)
                        context.moveTo(centerX, centerY)
                        context.lineTo(centerX + Math.cos(angleEnd) * radius,
                                       centerY + Math.sin(angleEnd) * radius)
                        context.stroke()
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
    }
}
