//  El cursor de la casa, edición de dentro.
//
//  Envoltorio de K5.Estela y nada más: la implementación vive UNA vez, en la
//  API, porque los plugins de fuera también lo necesitan. Aquí solo se le da
//  el color de core y el nombre de la familia.
//
//      TextInput { cursorDelegate: IslandCursor {} }

import K5 as K5

K5.Estela {
    color: Theme.ink
}
