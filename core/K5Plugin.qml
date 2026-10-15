//  Compatibilidad: el contrato vive en la API pública desde que existen los
//  plugins de fuera.
//
//  El tipo de verdad es `K5.Plugin` (api/K5/Plugin.qml): un plugin externo no
//  puede llegar a core/ por ruta relativa, así que el contrato tiene que estar
//  donde llega cualquiera — el módulo K5. Los 20 de casa siguen escribiendo
//  `K4Plugin {}` y les llega por aquí, sin tocar veinte ficheros para un
//  renombrado.

import K5 as K5

K5.Plugin {}
