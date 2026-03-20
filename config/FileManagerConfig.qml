import QtQuick

QtObject {
    property bool showHidden: true
    property bool sortReverse: false
    property Sizes sizes: Sizes {}

    component Sizes: QtObject {
        property int windowWidth: 1000
        property int windowHeight: 600
        property int itemHeight: 24
    }
}
