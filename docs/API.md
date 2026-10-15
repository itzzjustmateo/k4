# k5 public API

This is the public surface available to plugins. The API lives in `api/K5/`; the
source files contain additional implementation notes.

## Imports

A plugin imports Qt and k5:

```qml
import QtQuick
import K5 as K5
```

Start the host with `arrancar`. It adds `api/` to `QML_IMPORT_PATH`; launching
`quickshell -p shell.qml` directly will not resolve `import K5`.

Qt (`QtQuick`, `QtMultimedia`, `Timer`, animations, and so on) is the portable
layer. Quickshell and Wayland should stay behind a `K5` API type whenever an
equivalent exists.

## Plugin contract

`K4Plugin` is the root object of a module:

| Property | Meaning |
|---|---|
| `name` | Stable, unique plugin ID |
| `title` | Human-readable name |
| `habilitado` | Persistent user permission |
| `active` | Requests the island right now |
| `priority` | Arbitration priority |
| `transitorio` | View that appears unasked and expires on its own; it closes the moment another plugin takes the island |
| `islandWidth`, `islandHeight` | Requested island size |
| `view` | Component rendered by the host |
| `viewLoaded` | Keep the size while the view closes |
| `grabKeyboard` | Exclusive keyboard focus |
| `tecladoOpcional` | On-demand keyboard focus |
| `closeOnHoverExit` | Enable hover-exit timeout |

`active` and `habilitado` are different states:

```qml
K4Plugin {
    name: "hello"
    active: habilitado && abierto
    property bool abierto: false
}
```

Repo modules import that root type from `core/`; third-party plugins use the
same contract as `K5.Plugin`.

## Visual components

The bar's look, ready to assemble — every piece takes the palette from
`K5.Tema` so a plugin lands looking native:

| Type | What it is |
|---|---|
| `K5.Etiqueta` | Text with the bar's defaults (white, Adwaita, 12px) |
| `K5.Glifo` | A Nerd Font glyph (find codepoints with `tools/glifos.py`) |
| `K5.Icono` | An `IconImage` ready to render application icons |
| `K5.IconoPlugin` | A plugin's own image, falling back to a glyph |
| `K5.Miniatura` | The live thumbnail of an open window, by address |
| `K5.Interruptor` | The bar's switch |
| `K5.Deslizador` | The bar's slider |
| `K5.Medidor` | A read-only bar: `valor` out of `maximo`, with the house track and easing |
| `K5.Baldosa` | Pressable card: hover lift, press sink |
| `K5.Boton` | Round one-glyph button |
| `K5.Aparicion` | Fade-in for views |
| `K5.Rodillo` | Scrollable column whose wheel works over hoverable rows |
| `K5.FocoInicial` | Grabs keyboard focus when a view opens |

`examples/piezas/` is the runnable showcase of all of them.

## Plugin state that survives: `K5.Guardado`

For game saves, counters, anything that must outlive a restart. It owns a
JSON file under the plugin's own state directory:

```qml
property var guardado: K5.Guardado {
    plugin: "hello"
    onCargado: function (d) { self.visitas = d.visitas || 0 }
}

function apuntar() {
    guardado.guardar({ visitas: visitas })
}
```

Prefer it over raw `K5.Fichero` for plugin state: the path, the directory
and the load signal are handled for you.

## Spanish first, translated everywhere: `K5.Idioma`

Wrap every user-facing string in `K5.Idioma.t("…")` and format with
`K5.Idioma.f("%1 things", n)`. Source strings are Spanish; `en.json` and
friends translate, and missing entries fall back to the original.

`python3 tools/textos.py` reports coverage per language and `textos.py
plantilla` rebuilds the template a translator fills in.

### Strings that are born in a script

A tool under `tools/` is a command-line program and speaks Spanish — its
audience is whoever runs it. But some of what it prints is not for that
person: it travels up as JSON and the BAR paints it, in whatever language the
bar is set to. The shortcut panel's verbs and the clipboard's type labels are
exactly that.

Those are interface strings even though they live in Python, and they have to
be marked, because `tools/textos.py` reads `.qml` and would never see them:

```python
#  Identity function. It exists to MARK: textos.py collects exactly this call.
def T(s):
    return s


VERBOS = {
    "window.close": T("Cerrar la ventana"),
    "focus": T("Cambiar el foco"),
}
```

Marked, they count towards coverage like any other string. Unmarked they do
not, which does not mean "untranslated" — it means **nobody will ever be told
they are untranslated**, and one day they show up in Spanish inside an English
bar. That is how 23 of them went unnoticed.

Two rules that follow from how they are consumed:

- **Send the phrase and its detail apart.** `"Cerrar la ventana"` is prose and
  gets translated; `left`, `togglesplit` or a workspace number are
  identifiers the user wrote in their own config, and translating those would
  be inventing a name for their setup. Whoever paints joins them — it is the
  only side that knows the language.
- **Keep punctuation out of the translatable string.** Shipping
  `"Cerrar la ventana · %1"` looks convenient and translates nothing: that
  composed string is not in the table, only the phrase is. And it should not
  be, or every verb would need a second entry for its version with a detail.

This applies to the repo's own `tools/`. A plugin that ships its own script is
not scanned — route its user-facing text through `K5.Idioma.t()` on the QML
side instead, where it will be picked up.

## Processes: `K5.Process`

`K5.Process` wraps an external process and provides two output modes:

```qml
K5.Process {
    id: query
    command: ["python3", K5.Paths.guion("data.py")]
    running: abierto
    onSalida: function (text) { model = JSON.parse(text) }
    onLineaError: function (line) { console.warn(line) }
}
```

For one event per line:

```qml
K5.Process {
    command: ["my-command", "--watch"]
    porLineas: true
    running: true
    onLinea: function (line) { ... }
}
```

Properties include `command`, `running`, `workingDirectory`, `environment`,
`porLineas` and `entradaAbierta`. Signals are `arrancado`, `linea`, `salida`,
`lineaError` and `terminado(code)`. Stop a process that writes a file with
`parar()` (SIGINT), not a hard kill.

## Files and paths

`K5.Paths` keeps plugins independent from filesystem layout:

```qml
readonly property string statePath: K5.Paths.estado + "/hello.json"
K5.Fichero { id: state; path: statePath; blockLoading: true }

function save() {
    state.setText(JSON.stringify({ count: count }, null, 2))
}
```

- `K5.Paths.estado`: `~/.local/state/k5`, for persistent state.
- `K5.Paths.raiz`: the k5 installation root.
- `K5.Paths.guion(name)`: a file inside `tools/`.
- `K5.Paths.enRaiz(relative)`: any repository asset.

`K5.Fichero` provides `path`, `text()`, `setText()`, `blockLoading` and
`onLoaded`. Use it for small JSON/text files, not media assets.

## System and applications

`K5.Sistema` provides desktop actions:

```qml
K5.Sistema.abrir(path)
K5.Sistema.lanzar(["program", "--option"])
K5.Sistema.avisar("Title", "Details", false)
K5.Sistema.copiar("text")
const home = K5.Sistema.entorno("HOME")
```

`K5.Apps.lista` contains installed desktop entries; `K5.Apps.porId(id)` looks
one up and `K5.Apps.icono(name)` resolves its icon. `K5.Icono` is an
`IconImage` ready to render.

### Window thumbnails

`K5.Miniatura` paints what is inside another window, and keeps painting it —
it is live, not a photo taken when the panel opened. A window switcher, an
Alt+Tab, a preview on hover: places where the title is not enough, because
three terminals are called the same and look nothing alike.

```qml
K5.Miniatura {
    width: 160; height: 100
    direccion: "0x5622613de2c0"      // the one `hyprctl clients` gives
}
```

You hand it the window's **address**, not the window: a plugin cannot talk to
the compositor — that is what services are for — but it does have the address,
which is what `hyprctl` returns and what you already use to focus a window.
Finding whose window it is happens inside.

If the window does not exist, or closes while you are looking at it, nothing
is painted. That is deliberate and there is no signal for it: whoever shows
the thumbnail already knows which windows they have, and a thumbnail that
shouts when its window goes is more annoying than a gap.

## Reading the machine

Live system data, one wrapper per source. Reading is free; the few write
operations are permission-gated (see the manifest permissions below):

| Type | Reads | Gated writes |
|---|---|---|
| `K5.Audio` | volume, mute | `ponerVolumen`, `alternarSilencio` → `audio` |
| `K5.Medios` | player, track, artwork | `alternarPausa`, `siguiente`… → `medios` |
| `K5.Red` | Wi-Fi and Bluetooth state | none — read-only, no exceptions |
| `K5.Escritorios` | Hyprland workspaces, and `lleno(screen)` — is something filling that screen? | — |
| `K5.Notificaciones` | notification count and recents | `limpiar` → `notificaciones` |
| `K5.Portapapeles` | clipboard history | reading is itself gated → `portapapeles` |
| `K5.Reloj` | the bar's clock | — |

## Sound: `K5.Sonido`

A short effect — `fuente` points at the audio file, `volumen` scales it.
Requires the `sonido` permission: a plugin that can make noise says so.

```qml
K5.Sonido {
    id: campana
    fuente: campana.delSistema("bell")
    volumen: 0.4
}
```

Then `campana.sonar()` plays it.
`delSistema(name)` resolves a desktop theme sound already installed on the
machine — `bell`, `message`, `complete`, `dialog-error` — so a plugin can
have sound without shipping audio files. Note it is a method **of the
object**, not of the type: `campana.delSistema(…)`, never
`K5.Sonido.delSistema(…)`, which fails silently inside the binding and
leaves you with no sound and no error. `listo` tells you whether it can
actually play.

## IPC, windows and shortcuts

Expose commands with `K5.Ipc`:

```qml
K5.Ipc {
    target: "k5.hello"
    function toggle(): void { self.abierto = !self.abierto }
}
```

Call it from Hyprland with:

```sh
quickshell ipc -p ~/.config/quickshell/k5/shell.qml call k5.hello toggle
```

- `K5.Ventana`: a full-screen `wlr-layer-shell` surface that does not reserve
  layout space. `capa` picks the level: `"encima"` above everything (the
  island included), `"normal"` above windows and below the island, and
  `"fondo"` **below the windows** — what an animated wallpaper needs. It
  lands on `Bottom`, not `Background`: wallpaper daemons live on
  `Background`, and within one layer the newest surface wins, so relaunching
  awww-daemon would silently cover whatever you drew. Give a background window a 0×0
  `zonaActiva`, or its `null` mask swallows every click on the desktop.
- `K5.PorPantalla`: one instance per monitor.
- `K5.Cargador`: a `LazyLoader` for expensive views or windows.
- `K5.Atajo`: a global shortcut identified by `appid: "k5"` and `name`.
- `K5.Autenticacion`: PAM authentication state and signals.
- `K5.BloqueoSesion` and `K5.SuperficieBloqueo`: the real `ext-session-lock`
  and its per-output surface.
- `K5.MenuBandeja`: an application tray menu.

## Pill indicators

Plugins can register a small indicator without editing `shell.qml`:

```qml
Component.onCompleted: K5.Pildora.registrar(
    "hello.status", "ready", 0xF05A1, "#30d158", 80, true)

Connections {
    target: K5.Pildora
    function onInvocado(id) {
        if (id === "hello.status") self.abierto = true
    }
}
```

Available operations are `registrar(id, text, glyph, color, order, visible)`,
`actualizar(id, fields)`, `quitar(id)` and `quitarDe(owner)`. IDs must start with
the plugin ID (`hello.`). The host removes a plugin's indicators when it is
disabled.

## Your settings, in Settings

Plugins contribute rows to the bar's Settings screen with `K5.Ajustes`: the
plugin keeps the values, the bar asks for them (`valores`) and notifies
(`cambiado`). A switch per option is the default; `tipo` unlocks the rest:

- `"eleccion"`: chips with your own `alternativas: [{ codigo, nombre }]`;
  `cambiado` delivers the chosen `codigo`.
- `"texto"`: a free-text field — a URL, a model name, an API key. `pista`
  is the empty-field hint and `secreto: true` masks the value once typing
  stops. The value arrives on confirm (Enter or focus out), not per
  keystroke.

With these, a plugin that talks to a service, an AI or a CLI configures
itself in Settings like everything else.

## Your results in the launcher: `K5.Lanzador`

Answer the launcher's queries whenever you can — a slow source blocks
nobody. Your results appear below the system's applications:

```qml
K5.Lanzador {
    plugin: "hola"
    onBuscando: function (texto) {
        resultados = texto.length < 2 ? []
            : [{ id: "abrir", titulo: K5.Idioma.t("Abrir Hola"), desc: "…" }]
    }
    onElegido: function (id) { self.abierto = true }
}
```

## The island as a stage

- `K5.Tema.tintar(id, color, strength, durationMs)` tints the bar's neutral
  scaffold — island, surfaces, tracks — and everything painted with the
  theme recolors itself reactively. Ink and semantic colors stay untouched
  so text stays readable; strength is capped at 0.45 by the host, and
  `K5.Tema.destintar(id)` — or disabling the plugin — reverts it.
- `K5.Isla.efecto(id, name, strength)` asks for a physical gesture:
  `"sacudida"` (a hit), `"empujon"` (something heavy lands), `"tiron"`
  (something pulls, like a fish on the line). The host animates and
  rate-limits to one gesture per half second.
- `K5.Isla.rect` is the island's real screen geometry (`{ x, y, ancho,
  alto }`); with a transparent `K5.Ventana` above everything you can draw
  outside the island — a waving hand, a pet peeking over the edge.
- `K5.Isla.aLaVista` says whether anyone can see the island right now —
  false while it is retracted in *Hidden* space mode, while a capture or a
  system dialog has it out of the way, and on a monitor whose bar is not
  showing. **An animation that never ends must ask this**, because in Qt
  Quick an animation does not stop when its item stops being visible; see
  [PLUGINS.md](PLUGINS.md#an-animation-nobody-sees-still-runs).
- The bar's edge and alignment belong to the user (Settings: top/bottom,
  left/center/right). `K5.Isla.posicion` tells you the edge; and
  `K5.Isla.colocar(id, fraction, durationMs)` slides the island along it
  for the duration of a scene — a dodge, a paddle, stepping aside — and it
  springs back on timeout, `soltar(id)`, or disable.

`examples/efectos/` has every piece working, hand included.

## Personal data: `K5.Huella`

Aggregated slices of the user's real life, under a **double key**: the
plugin declares the `datos-personales` manifest permission (just naming
`K5.Huella` demands it) AND the user enables each source individually in
Settings → "Datos personales" — everything off by default. Aggregation
happens in the python readers (`tools/huella.py`) before anything touches
QML, and forgetting is immediate.

Shipped sources: `steam` (`{ juegos, minutos, titulos }`) and `paquetes`
(`{ total, ultimaActualizacion }`). Check `K5.Huella.activa("steam")`
before reading — without both keys you get empty objects, never errors.

Planned next, same rules: focus time per app, local git rhythm, browser
domains (never URLs), shell binaries (never arguments). Hard red lines
that no permission opens: keylogging, notification or file contents,
mic/camera content — only a binary "in use" indicator.

## Current boundaries

Plugin loading is dynamic and isolated: each plugin is created on its own, a
failure is recorded with its error, and the rest start. Disabled means not
instantiated. Third-party plugins load from `~/.config/k5/plugins/<id>/`.

What that does **not** mean is a sandbox. QML runs inside the bar's process and
a loaded plugin can do whatever the bar can do. The declared permissions are
informed consent — you see them before enabling — plus a static analysis that
turns carelessness and simple deception into an installation error. Installing
a plugin is trusting its author.

Two doors stay shut on purpose: connecting to networks and pairing Bluetooth
devices are read-only for plugins, with no permission that opens them.

The full guide, kept current by `tools/api.py` and `tools/guia.py`, is
`docs/PLUGINS.md`. New dependencies still go in `dependencias.tsv`.
