import "../services"
import QtQuick

ColorAnimation {
    duration: FmTheme.animDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: FmTheme.animCurveStandard
}
