import Quickshell.Io

JsonObject {
    property bool enabled: true
    property bool showHidden: false
    property bool sortReverse: false
    property Sizes sizes: Sizes {}

    component Sizes: JsonObject {
        property int windowWidth: 1000
        property int windowHeight: 600
        property int sidebarWidth: 200
        property int itemHeight: 36
    }
}
