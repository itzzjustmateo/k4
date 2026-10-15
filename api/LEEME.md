# Writing a k5 plugin

This is the quick reference. For complete guides see:

- [Public API](../docs/API.md)
- [Creating a plugin](../docs/PLUGINS.md)
- [Creating a game plugin](../docs/GAMES.md)

> A plugin imports `QtQuick` and `K5`. Nothing else from the host.

## Minimal plugin

```qml
import QtQuick
import K5 as K5
import "../../core"

K4Plugin {
    id: self
    name: "hello"
    title: "Hello"
    priority: 70
    active: habilitado && abierto
    islandWidth: 300
    islandHeight: 120

    property bool abierto: false

    view: Component {
        Item {
            IslandLabel { anchors.centerIn: parent; text: "Hello" }
        }
    }

    K5.Ipc {
        target: "k5.hello"
        function toggle(): void { self.abierto = !self.abierto }
    }
}
```

`K4Plugin` is the contract: it declares when the plugin wants the island, its
requested size, the view to render and keyboard behavior. The host binds
`habilitado` to `PluginManager`; it is different from `active`:

```qml
K5.Process { running: self.habilitado && self.abierto }
Timer { running: self.habilitado && self.abierto }
```

Processes, timers and IPC handlers are direct children of the plugin. A view is
mounted only while the host gives the plugin the island, so long-lived work must
not be declared inside the view.

## Exported types

| Type | Use |
|---|---|
| `K5.Plugin` | The contract: island size, priority, keyboard, view |
| `K5.Process` | Run a process and read line or complete output |
| `K5.Ipc` | Expose commands to Hyprland and other clients |
| `K5.Fichero` | Read/write a small text or JSON file |
| `K5.Paths` | Installation, tools and state paths |
| `K5.Sistema` | Launch, open, notify, copy and read environment |
| `K5.Apps` | Installed applications and icons |
| `K5.Icono` | Theme-aware application icon |
| `K5.Miniatura` | Live thumbnail of an open window, given its address |
| `K5.Ventana` | Full-screen layer-shell surface |
| `K5.PorPantalla` | One instance per monitor |
| `K5.Cargador` | Lazy-load expensive content |
| `K5.Atajo` | Global shortcut |
| `K5.Autenticacion` | PAM authentication |
| `K5.BloqueoSesion` | Real session lock |
| `K5.SuperficieBloqueo` | What is drawn while locked, one per monitor |
| `K5.MenuBandeja` | Tray application menu |
| `K5.Pildora` | Small indicators in the folded pill |
| `K5.Capsula` | A flank extension: the capsule grows toward a screen edge with your text |
| `K5.Submapas` | The Hyprland submap in force right now, read only |
| `K5.Sonido` | Short sound effect (permission `sonido`) |
| `K5.Tema` | Palette, fonts, island geometry — and `tintar()` to tint the bar's ambience |
| `K5.Idioma` | Translation: `t()` and `f()` |
| `K5.Guardado` | Plugin state as JSON, in its own directory |
| `K5.Etiqueta` | Text with the bar's defaults |
| `K5.Glifo` | Nerd Font glyph |
| `K5.IconoPlugin` | A plugin's icon: its image, or its glyph |
| `K5.Interruptor` | The bar's switch |
| `K5.Deslizador` | Labelled slider |
| `K5.Medidor` | Read-only bar: `valor` out of `maximo`, house track and easing |
| `K5.Baldosa` | Pressable card |
| `K5.Boton` | Round single-glyph button |
| `K5.Rodillo` | Scroll area that obeys the wheel, house scroll bar included |
| `K5.Desplazador` | The house scroll bar, for your own lists |
| `K5.Estela` | The house caret with its trail, as a `cursorDelegate` |
| `K5.Terminal` | Run a script in the house terminal, or open one (needs `procesos`) |
| `K5.Aparicion` | Fade in instead of popping |
| `K5.FocoInicial` | Move the caret into your text field |
| `K5.Audio` | Volume and mute (writing needs `audio`) |
| `K5.Medios` | What is playing (controls need `medios`) |
| `K5.Notificaciones` | Incoming notifications |
| `K5.Red` | Wi-Fi and Bluetooth, read only |
| `K5.Escritorios` | Hyprland workspaces |
| `K5.Portapapeles` | Clipboard history (reading needs `portapapeles`) |
| `K5.Reloj` | The bar's single clock |
| `K5.Ajustes` | Your own settings inside the bar's Settings — switches, choices, free text (`secreto` for keys) |
| `K5.Huella` | Aggregated personal data (Steam, packages), double-keyed: `datos-personales` permission + per-source user opt-in |
| `K5.Lanzador` | Contribute results to the launcher |
| `K5.Isla` | Island state: open, occupant, maximum height — plus `rect`/`rectEn()`/`posicion` (geometry, per screen) — `efecto()` (shake, push, tug) and `colocar()` (slide along the edge) |

## Catalog and registration

Plugins are loaded **dynamically**, one by one, each in its own try: a plugin
that fails to compile is recorded with its error and the bar starts without
it. Disabled means not instantiated.

A plugin of your own goes in `~/.config/k5/plugins/<id>/` with a `plugin.json`
manifest — nothing in this repository is touched. See `docs/PLUGINS.md`;
`examples/hola` and `examples/snake` are complete, runnable examples.

A plugin contributed to the repository goes under `plugins/` with a `qmldir`
listing every type in the folder (sibling types do not resolve without it) and
an entry in `plugins/catalog.json`. It is no longer imported or instantiated in
`shell.qml`.

Validate the result with:

```sh
python3 tools/plugins.py
python3 tools/api.py
```

Third-party plugins are loaded, so read the honest security note in
`docs/PLUGINS.md`: declared permissions are informed consent plus static
analysis, not a sandbox. QML runs in the bar's process.

## API changes

If a plugin needs a capability that is missing, add it under `api/K5/` rather
than importing a private Quickshell type in the plugin. Keep the wrapper small,
document its signals and properties, and update `docs/API.md` with an example.
Restart the bar after changing the `K5` module because QML caches imported
modules.
