//  El escaparate de la island como escenario: teñir la barra entera, pedirle
//  gestos físicos y pintar FUERA de ella con una ventana propia.
//
//  Copia la carpeta a ~/.config/k5/plugins/efectos, enciéndelo en Ajustes y
//  `quickshell ipc -p <ruta>/shell.qml call k5.efectos toggle` lo abre.

import QtQuick
import K5 as K5

K5.Plugin {
    id: self

    name: "efectos"
    title: "Efectos"
    priority: 64
    active: abierto
    islandWidth: 620
    islandHeight: 168

    property bool abierto: false
    //  La mano vive aparte de la island: puede quedarse saludando con el
    //  módulo cerrado, que es justo lo que haría una mascota.
    property bool manoFuera: false


    //  ── idioma ───────────────────────────────────────────────────
    //
    //  La barra traduce con UN diccionario suyo y ahí no entra un plugin de
    //  fuera: `K5.Idioma.t()` devuelve el original. Con la barra en inglés eso
    //  son cadenas en español dentro de una interfaz en inglés. Así que el
    //  plugin trae su tabla; el español se queda como fuente y lo que falte
    //  cae al original en vez de salir roto.
    readonly property var _en: ({
        "La island como escenario": "The island as a stage",
        "Bosque":                   "Forest",
        "Brasa":                    "Ember",
        "Abismo":                   "Abyss",
        "Destintar":                "Untint",
        "Sacudida":                 "Shake",
        "Empujón":                  "Shove",
        "Tirón":                    "Tug",
        "Esconder la mano":         "Hide the hand",
        "Sacar la mano":            "Show the hand",
        "De paseo":                 "Out for a walk"
    })

    function tr(s) {
        return K5.Idioma.codigo === "es" ? s : (_en[s] || s)
    }

    function trf(s, a, b) {
        var r = tr(s)
        if (a !== undefined) r = r.replace("%1", a)
        if (b !== undefined) r = r.replace("%2", b)
        return r
    }

    view: Component { EfectosView { plugin: self } }

    //  La ventana de la mano solo existe mientras hace falta.
    property var cargadorMano: K5.Cargador {
        active: self.manoFuera
        Mano { plugin: self }
    }

    K5.Ipc {
        target: "k5.efectos"
        function toggle(): void { self.abierto = !self.abierto }
        function close(): void {
            self.abierto = false
            self.manoFuera = false
        }
        function tinte(color: string): void {
            K5.Tema.tintar("efectos", color, 0.35, 4000)
        }
        function gesto(nombre: string): void {
            K5.Isla.efecto("efectos", nombre)
        }
        function mano(): void { self.manoFuera = !self.manoFuera }
        function paseo(fraccion: string): void {
            K5.Isla.colocar("efectos", Number(fraccion), 3000)
        }
    }
}
