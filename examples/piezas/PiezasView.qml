import QtQuick
import K5 as K5

K5.Aparicion {
    id: vista

    required property var plugin

    K5.Rodillo {
        anchors.fill: parent
        anchors.margins: 14

        Column {
            width: parent.width
            spacing: 14

            K5.Etiqueta {
                text: K5.Idioma.t("Piezas de la API")
                font.pixelSize: 15
                font.weight: Font.Bold
            }

            // ── Interruptor ───────────────────────────────────────
            Row {
                width: parent.width
                spacing: 10

                K5.Glifo {
                    text: "󰛨"  // md-lightbulb_on
                    color: vista.plugin.encendido ? K5.Tema.amarillo
                                                  : K5.Tema.tenue
                    anchors.verticalCenter: parent.verticalCenter
                }

                K5.Etiqueta {
                    text: K5.Idioma.t("Interruptor")
                    width: parent.width - 100
                    anchors.verticalCenter: parent.verticalCenter
                }

                K5.Interruptor {
                    marcado: vista.plugin.encendido
                    anchors.verticalCenter: parent.verticalCenter
                    //  No cambia solo: manda el plugin.
                    onAlternado: vista.plugin.encendido = !vista.plugin.encendido
                }
            }

            // ── Deslizador ────────────────────────────────────────
            K5.Deslizador {
                width: parent.width
                etiqueta: K5.Idioma.t("Deslizador")
                valor: vista.plugin.nivel
                sufijo: "%"
                onMovido: function (v) { vista.plugin.nivel = v }
            }

            // ── Medidor ───────────────────────────────────────────
            //  El hermano quieto del deslizador: este se mira, no se toca.
            Row {
                width: parent.width
                spacing: 10

                K5.Etiqueta {
                    width: 70
                    anchors.verticalCenter: parent.verticalCenter
                    text: K5.Idioma.t("Medidor")
                    color: K5.Tema.apagado
                    font.pixelSize: 11
                }

                K5.Medidor {
                    width: parent.width - 118
                    anchors.verticalCenter: parent.verticalCenter
                    valor: vista.plugin.nivel
                    maximo: 100
                    tono: valor >= 85 ? K5.Tema.rojo
                        : valor >= 60 ? K5.Tema.amarillo : K5.Tema.verde
                    //  Con 3, un valor diminuto se sigue viendo.
                    minimo: 3
                }

                K5.Etiqueta {
                    width: 38
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(vista.plugin.nivel) + "%"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                }
            }

            // ── Baldosas ──────────────────────────────────────────
            Row {
                spacing: 10

                K5.Baldosa {
                    width: 150
                    height: 66
                    activa: vista.plugin.baldosaActiva
                    onPulsada: vista.plugin.baldosaActiva = !vista.plugin.baldosaActiva

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        K5.Glifo {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰖩"  // md-wifi
                            font.pixelSize: 20
                            color: vista.plugin.baldosaActiva ? K5.Tema.azul
                                                              : K5.Tema.apagado
                        }
                        K5.Etiqueta {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: vista.plugin.baldosaActiva
                                ? K5.Idioma.t("Activa") : K5.Idioma.t("Baldosa")
                            font.pixelSize: 11
                        }
                    }
                }

                K5.Baldosa {
                    width: 150
                    height: 66
                    pulsable: false

                    K5.Etiqueta {
                        anchors.centerIn: parent
                        text: K5.Idioma.t("No pulsable")
                        color: K5.Tema.apagado
                        font.pixelSize: 11
                    }
                }
            }

            // ── Botones ───────────────────────────────────────────
            Row {
                spacing: 4

                K5.Boton {
                    glifo: "󰒮"  // md-skip_previous
                    activo: false                  // apagado, no escondido
                }
                K5.Boton {
                    glifo: "󰐊"  // md-play
                    tamano: 24
                    onPulsado: vista.plugin.pulsaciones += 1
                }
                K5.Boton {
                    glifo: "󰒭"  // md-skip_next
                    onPulsado: vista.plugin.pulsaciones += 1
                }

                K5.Etiqueta {
                    anchors.verticalCenter: parent.verticalCenter
                    text: K5.Idioma.f(K5.Idioma.t("%1 pulsaciones"),
                                      vista.plugin.pulsaciones)
                    color: K5.Tema.apagado
                    font.pixelSize: 11
                }
            }

            // ── Estela: el cursor de la casa ──────────────────────
            //
            //  Va de `cursorDelegate` y ya: el campo lo coloca, la pieza
            //  decide cómo se pinta. Escribe aquí y mira el rastro.
            K5.Etiqueta {
                text: K5.Idioma.t("Estela — escribe y mira el cursor")
                font.pixelSize: 11
                color: K5.Tema.apagado
            }

            Rectangle {
                width: parent.width
                height: 34
                radius: 10
                color: K5.Tema.superficie

                TextInput {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: K5.Tema.tinta
                    font.pixelSize: 13
                    selectByMouse: true
                    cursorVisible: true
                    cursorDelegate: K5.Estela {}
                    text: K5.Idioma.t("escribe algo")
                }
            }

            // ── Relleno, para que haya algo que rodar ─────────────
            Repeater {
                model: 6
                delegate: K5.Baldosa {
                    required property int index
                    width: parent.width
                    height: 44

                    K5.Etiqueta {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        text: K5.Idioma.f(K5.Idioma.t("Fila %1 · mueve la rueda"),
                                          index + 1)
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
