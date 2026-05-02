import "../services"
import QtQuick

NumberAnimation {
    duration: FmTheme.animDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: FmTheme.animCurveStandard
}
