//  La vista: solo existe mientras el plugin tiene la island.
//
//  Un plugin de fuera importa QtQuick y K5, nada más. La paleta llega por
//  K5.Tema y el texto con los defaults de la barra por K5.Etiqueta.

import QtQuick
import K5 as K5

Item {
    required property var plugin

    Rectangle {
        anchors.centerIn: parent
        width: 320
        height: 64
        radius: 14
        color: K5.Tema.superficie

        Column {
            anchors.centerIn: parent
            spacing: 2

            K5.Etiqueta {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !plugin.saludar ? K5.Idioma.t("Contando visitas")
                    : plugin.aQuien
                      ? K5.Idioma.f(K5.Idioma.t("Hola, %1"), plugin.aQuien)
                      : K5.Idioma.t("Hola desde un plugin de fuera")
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            K5.Etiqueta {
                anchors.horizontalCenter: parent.horizontalCenter
                text: K5.Idioma.f(K5.Idioma.t("Abierto %1 veces"),
                                  plugin.visitas)
                color: K5.Tema.apagado
                font.pixelSize: 11
            }
        }
    }
}
