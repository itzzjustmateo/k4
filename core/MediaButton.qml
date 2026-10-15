//  Capa fina sobre K5.Boton — ver core/IconGlyph.qml. Solo traduce nombres.

import K5 as K5

K5.Boton {
    id: control

    property alias glyph: control.glifo
    property alias glyphSize: control.tamano
    property alias glyphColor: control.color
    property alias enabledAction: control.activo
    signal activated()

    onPulsado: control.activated()
}
