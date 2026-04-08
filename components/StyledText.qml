import "../services"
import QtQuick

Text {
    id: root

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Theme.palette.onSurface
    font.family: Theme.font.family.sans
    font.pointSize: Theme.font.size.sm

    Behavior on color {
        CAnim {}
    }
}
