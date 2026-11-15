import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property color fillColor: BlurService.backgroundColor(Appearance.colors.colLayer0)
    property real cornerRadius: height / 2
    property real shadowPadding: Sizes.barShadowBuffer
    readonly property string contextualEdge: findContextEdge(root.parent)

    function findContextEdge(item) {
        let current = item;
        while (current !== null && current !== undefined) {
            if (current.popupEdge !== undefined)
                return current.popupEdge;
            current = current.parent;
        }
        return "top";
    }

    LiquidGlassSurface {
        anchors.fill: parent
        radius: root.cornerRadius
        baseColor: root.fillColor
        blurOpacity: 0.64
        fallbackOpacity: 0.96
        topHighlight: 0.20
        bottomReflection: 0.04
        clearMaterial: false
    }
}
