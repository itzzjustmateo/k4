//  Capa fina sobre K5.Interruptor — ver core/IconGlyph.qml. Solo traduce los
//  nombres: `checked`/`toggled` es lo que escriben los veinte de casa.

import K5 as K5

K5.Interruptor {
    id: control

    property alias checked: control.marcado
    signal toggled()

    onAlternado: control.toggled()
}
