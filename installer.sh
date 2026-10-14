#!/bin/sh
#  Install and update k4. Same script for both: it pulls, updates packages and
#  shortcuts, and offers to restart the bar.
#
#      ./installer.sh                 everything: packages (incl. optional),
#                                 shortcuts, autostart, restart
#      ./installer.sh --dry-run       look and report; change nothing
#      ./installer.sh --yes           don't ask (for scripts)
#      ./installer.sh --no-optional   skip the optional packages
#      ./installer.sh --no-packages   skip the package manager
#      ./installer.sh --no-restart    leave the running bar alone
#      ./installer.sh --all           do all of the above without asking
#
#  The older aliases (--seco, --si, --opcionales, --sin-paquetes,
#  --sin-reiniciar) still work and are staying. Spanish was here first; the
#  door is now English, but the old keys still open it.

#  ── and from here on nothing else goes to the screen ─────────────────────────
#
#  `ayuda()` prints the header up to the first line that does not start with `#`,
#  and that gap above is exactly that: the door is what gets read, and what
#  follows is code commentary, which in this project is in English.
#
#  It is plain `sh`, not python, for a reason that has nothing to do with taste:
#  this script runs BEFORE any dependencies exist, so it cannot depend on any.
#  No bash, no python, no jq. Only what any system ships with.
#
#  What k4 needs is not written here: it lives in `dependencias.tsv`, the single
#  source of truth, which the README also reads.

set -eu

# ─── Presentation ────────────────────────────────────────────────────────────
# Color only when a terminal is in front. If this ends up in a log file, it
# should not fill up with escape sequences.
if [ -t 1 ]; then
    NEGRITA=$(printf '\033[1m'); APAGADO=$(printf '\033[2m')
    VERDE=$(printf '\033[32m'); AMBAR=$(printf '\033[33m')
    ROJO=$(printf '\033[31m'); FIN=$(printf '\033[0m')
else
    NEGRITA=''; APAGADO=''; VERDE=''; AMBAR=''; ROJO=''; FIN=''
fi

titulo() { printf '\n%s%s%s\n' "$NEGRITA" "$1" "$FIN"; }
bien()   { printf '  %s✓%s %s\n' "$VERDE" "$FIN" "$1"; }
aviso()  { printf '  %s!%s %s\n' "$AMBAR" "$FIN" "$1"; }
mal()    { printf '  %s✗%s %s\n' "$ROJO" "$FIN" "$1"; }
nota()   { printf '    %s%s%s\n' "$APAGADO" "$1" "$FIN"; }
morir()  { printf '\n%s✗ %s%s\n\n' "$ROJO" "$1" "$FIN" >&2; exit 1; }

# ─── Options ─────────────────────────────────────────────────────────────────
SECO=0; SIN_PREGUNTAR=0; OPCIONALES=1; SIN_PAQUETES=0; SIN_REINICIAR=0
# Does this machine have an NVIDIA GPU? The nvidia-smi check only makes sense
# then; on AMD/Intel-only boxes it is noise, not a missing dependency.
if command -v nvidia-smi >/dev/null 2>&1 || [ -d /proc/driver/nvidia ]; then
    NVIDIA=1
elif command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -iq nvidia; then
    NVIDIA=1
else
    NVIDIA=0
fi

# Help is the header of this same file, so they can never disagree: from line 2
# up to the first blank line. What comes after that gap is the "why", and that is
# not shown to whoever only asks how to use it.
ayuda() {
    awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^#[ ]?/, ""); print }' "$0"
    exit 0
}

# The outside flags count the same as the home ones, for the same reason as in
# `tools/plugins.py`: this project's code is in Spanish and is staying that way,
# but a command-line flag is not code, it is THE DOOR. Someone arriving to
# install the bar may not know what "seco" means, and a project only entered by
# Spanish speakers is not one, it is a club.
#
# And the Spanish ones are not retired or marked obsolete: they are in the README,
# in people's scripts and in the fingers of whoever has used them for months.
# They cost a pipe each.
#
# `--yes` had been in the README table for months but not in this `case`: anyone
# who copied it from there got "No conozco la opción". That is where all this
# comes from.
for arg in "$@"; do
    case "$arg" in
        --seco|--dry-run|-n)          SECO=1 ;;
        --si|--yes|-s|-y|--todo|--all) SIN_PREGUNTAR=1; OPCIONALES=1 ;;
        --opcionales|--optional|-o)   OPCIONALES=1 ;;
        --sin-opcionales|--no-optional) OPCIONALES=0 ;;
        --sin-paquetes|--no-packages) SIN_PAQUETES=1 ;;
        --sin-reiniciar|--no-restart) SIN_REINICIAR=1 ;;
        --ayuda|--help|-h)            ayuda ;;
        *) morir "Unknown option '$arg'. Try --ayuda / --help." ;;
    esac
done

# ─── Where the code is ───────────────────────────────────────────────────────
# `$0` is "sh" when this is read through a pipe (curl | sh). In that case there
# is no repository yet and it has to be cloned first.
if [ -f "$0" ] && [ "${0##*/}" = "installer.sh" ]; then
    RAIZ=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
else
    RAIZ=''
fi

DESTINO=${K4_DESTINO:-$HOME/.config/quickshell/k4}
TABLA="${RAIZ:-$DESTINO}/dependencias.tsv"

# ─── Package manager ─────────────────────────────────────────────────────────
# Arch is the first-class case: it installs. Elsewhere we only diagnose, because
# package names are indicative and quickshell is not even packaged outside Arch.
# `K4_GESTOR` forces one; it exists so the branches for the distros I do not
# have in front of me can be tested here.
if [ -n "${K4_GESTOR:-}" ];             then GESTOR=$K4_GESTOR
elif command -v pacman >/dev/null 2>&1;   then GESTOR=pacman
elif command -v apt-get >/dev/null 2>&1; then GESTOR=apt
elif command -v dnf >/dev/null 2>&1;     then GESTOR=dnf
elif command -v zypper >/dev/null 2>&1;  then GESTOR=zypper
else                                          GESTOR=ninguno
fi

# Mapping of names for managers that are not pacman. Only what changes; anything
# not listed is kept as is. It is indicative and said as such.
#
# A `-` means "this is not packaged in that distribution". Better say so than
# install something similar: fonts-firacode is not a Nerd Font, and whoever
# installs it will still see squares without knowing why.
traducir() {
    _p=$1
    [ "$GESTOR" = pacman ] && { printf '%s' "$_p"; return; }
    case "$GESTOR:$_p" in
        *:quickshell)            printf '%s' '-' ;;
        apt:ttf-meslo-nerd|dnf:ttf-meslo-nerd|zypper:ttf-meslo-nerd) printf '%s' '-' ;;
        apt:python)              printf 'python3' ;;
        apt:fd)                  printf 'fd-find' ;;
        apt:libpulse)            printf 'pulseaudio-utils' ;;
        apt:adwaita-fonts)       printf 'fonts-adwaita' ;;
        apt:qt6-multimedia)      printf 'qml6-module-qtmultimedia' ;;
        apt:qt6-multimedia-ffmpeg) printf 'qt6-multimedia-plugin-ffmpeg' ;;
        apt:libnotify)           printf 'libnotify-bin' ;;
        apt:networkmanager)      printf 'network-manager' ;;
        apt:wireplumber)         printf 'wireplumber' ;;
        dnf:python)              printf 'python3' ;;
        dnf:fd)                  printf 'fd-find' ;;
        dnf:libpulse)            printf 'pulseaudio-utils' ;;
        dnf:imagemagick)         printf 'ImageMagick' ;;
        dnf:libnotify)           printf 'libnotify' ;;
        dnf:networkmanager)      printf 'NetworkManager' ;;
        dnf:qt6-multimedia)      printf 'qt6-qtmultimedia' ;;
        dnf:qt6-multimedia-ffmpeg) printf 'qt6-qtmultimedia' ;;
        zypper:python)           printf 'python3' ;;
        zypper:libpulse)         printf 'pulseaudio-utils' ;;
        zypper:imagemagick)      printf 'ImageMagick' ;;
        zypper:qt6-multimedia)   printf 'qt6-multimedia-imports' ;;
        *)                       printf '%s' "$_p" ;;
    esac
}

# Is this package installed? The manager is asked, for things with no binary of
# their own: fonts and Qt modules.
hay_paquete() {
    case "$GESTOR" in
        pacman) pacman -Qq "$1" >/dev/null 2>&1 ;;
        apt)    dpkg -s "$(traducir "$1")" >/dev/null 2>&1 ;;
        dnf|zypper) rpm -q "$(traducir "$1")" >/dev/null 2>&1 ;;
        *)      return 1 ;;
    esac
}

# ─── Reading the table ──────────────────────────────────────────────────────
# No arrays: lists are space-separated strings, queried with `case`. That is the
# POSIX way, and it avoids duplicates (ffmpeg appears twice in the table, once
# as `ffmpeg` and once as `ffprobe`).
en_lista() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

FALTAN_BASE=''       # packages to install
FALTAN_OPC=''
DETALLE_BASE=''      # lines of "package purpose", with real newlines
DETALLE_OPC=''
SIN_PAQUETE=''       # missing things that cannot be installed
N_BASE=0; N_OPC=0; N_TOTAL=0

leer_tabla() {
    [ -f "$TABLA" ] || morir "Cannot find $TABLA. Is the repository complete?"
    while IFS='	' read -r comp paq nivel para || [ -n "$comp" ]; do
        case "$comp" in ''|\#*) continue ;; esac
        [ -n "${para:-}" ] || continue
        N_TOTAL=$((N_TOTAL + 1))

        # On a machine without an NVIDIA GPU this entry does not apply, and it is
        # not "missing": it is simply not part of this system.
        [ "$comp" = "nvidia-smi" ] && [ "$NVIDIA" -eq 0 ] && continue

        case "$comp" in
            pkg:*) hay_paquete "${comp#pkg:}" && continue ;;
            *)     command -v "$comp" >/dev/null 2>&1 && continue ;;
        esac

        # Missing. A `-` in the package column means it is not packaged anywhere:
        # we warn about it and that is the end of it.
        if [ "$paq" = '-' ]; then
            SIN_PAQUETE="$SIN_PAQUETE$comp	$para
"
            continue
        fi

        if [ "$nivel" = base ]; then
            en_lista "$paq" "$FALTAN_BASE" || {
                FALTAN_BASE="$FALTAN_BASE $paq"
                DETALLE_BASE="$DETALLE_BASE$paq	$para
"
                N_BASE=$((N_BASE + 1))
            }
        else
            en_lista "$paq" "$FALTAN_OPC" || {
                FALTAN_OPC="$FALTAN_OPC $paq"
                DETALLE_OPC="$DETALLE_OPC$paq	$para
"
                N_OPC=$((N_OPC + 1))
            }
        fi
    done < "$TABLA"

    # Drop the leading space.
    FALTAN_BASE=${FALTAN_BASE# }
    FALTAN_OPC=${FALTAN_OPC# }
}

pintar_detalle() {
    printf '%s' "$1" | while IFS='	' read -r paq para; do
        [ -n "$paq" ] || continue
        _n=$(traducir "$paq")
        if [ "$_n" = '-' ]; then
            printf '      %s%-22s%s %s%s%s\n' "$AMBAR" "$paq" "$FIN" \
                "$APAGADO" "$para — not packaged in $GESTOR, by hand" "$FIN"
        else
            printf '      %s%-22s%s %s%s%s\n' "$NEGRITA" "$_n" "$FIN" \
                "$APAGADO" "$para" "$FIN"
        fi
    done
}

# ─── Diagnosis ───────────────────────────────────────────────────────────────
diagnosticar() {
    titulo "Dependencies"
    leer_tabla

    if [ "$N_BASE" -eq 0 ]; then
        bien "Everything required is present ($N_TOTAL checks)."
    else
        mal "$N_BASE required things are missing:"
        pintar_detalle "$DETALLE_BASE"
    fi

    if [ "$N_OPC" -gt 0 ]; then
        aviso "Optional things are missing ($N_OPC). The bar runs without them:"
        pintar_detalle "$DETALLE_OPC"
    fi

    if [ -n "$SIN_PAQUETE" ]; then
        printf '%s' "$SIN_PAQUETE" | while IFS='	' read -r comp para; do
            [ -n "$comp" ] || continue
            aviso "$comp is not packaged; install it yourself if you want: $para"
        done
    fi

    if [ "$GESTOR" != pacman ] && [ "$N_BASE" -gt 0 ]; then
        printf '\n'
        aviso "There is no pacman here, so I only diagnose."
        nota "The $GESTOR package names are ORIENTATIVE: change them if your"
        nota "distribution calls them otherwise. And beware: quickshell is not"
        nota "packaged outside Arch, it has to be built."
    fi
}

# ─── Asking ──────────────────────────────────────────────────────────────────
# With --yes it does not ask. With no terminal in front either: an installer that
# waits for an answer nobody is going to type is worse than one that stops.
preguntar() {
    if [ "$SIN_PREGUNTAR" -eq 1 ]; then return 0; fi
    if [ ! -t 0 ]; then
        aviso "Nobody at the keyboard, so I am not doing it. With --yes I would."
        return 1
    fi
    printf '  %s%s%s [y/N] ' "$NEGRITA" "$1" "$FIN"
    read -r _r || return 1
    case "$_r" in s|S|si|Si|SI|y|Y) return 0 ;; *) return 1 ;; esac
}

# Whoever raises privileges. If already root, nobody.
if [ "$(id -u)" = 0 ];                then SUDO=''
elif command -v sudo >/dev/null 2>&1;  then SUDO='sudo'
elif command -v doas >/dev/null 2>&1;  then SUDO='doas'
else                                        SUDO=''
fi

# ─── Step: packages ──────────────────────────────────────────────────────────
paso_paquetes() {
    titulo "Packages"

    if [ "$SIN_PAQUETES" -eq 1 ]; then
        nota "Skipped, you asked for it with --sin-paquetes."
        return 0
    fi

    _lista=$FALTAN_BASE
    if [ "$OPCIONALES" -eq 1 ]; then
        _lista="$_lista $FALTAN_OPC"
    elif [ -n "$FALTAN_OPC" ]; then
        nota "Optional things are left out. If you want them: ./installer.sh --optional"
    fi

    # Leave out what is not packaged in this distribution: it was already warned
    # when diagnosing, and putting it in the order only makes it fail entirely.
    _instalables=''
    for _p in $_lista; do
        [ -n "$_p" ] || continue
        _n=$(traducir "$_p")
        [ "$_n" = '-' ] && continue
        _instalables="$_instalables $_n"
    done
    _instalables=${_instalables# }

    if [ -z "$_instalables" ]; then
        bien "Nothing to install."
        return 0
    fi

    if [ "$GESTOR" != pacman ]; then
        aviso "I do not install anything outside Arch. The command, for you to review:"
        case "$GESTOR" in
            apt)    printf '\n      sudo apt install %s\n\n' "$_instalables" ;;
            dnf)    printf '\n      sudo dnf install %s\n\n' "$_instalables" ;;
            zypper) printf '\n      sudo zypper install %s\n\n' "$_instalables" ;;
            *)      printf '\n      %s\n\n' "$_instalables" ;;
        esac
        return 0
    fi

    if [ -z "$SUDO" ] && [ "$(id -u)" != 0 ]; then
        mal "Neither sudo nor doas found. Install it yourself:"
        printf '\n      pacman -S --needed %s\n\n' "$_instalables"
        return 0
    fi

    # `PACMAN=echo` allows testing this step without actually installing.
    _pac=${PACMAN:-pacman}
    printf '  I am about to run:\n\n      %s%s %s -S --needed %s%s\n\n' \
        "$NEGRITA" "$SUDO" "$_pac" "$_instalables" "$FIN"

    if preguntar "Shall I run it?"; then
        printf '\n'
        # Without quotes on purpose: `_instalables` is several words and $SUDO can
        # be empty.
        # shellcheck disable=SC2086
        if $SUDO $_pac -S --needed $_instalables; then
            printf '\n'
            bien "Installed."
        else
            printf '\n'
            mal "The package manager failed. I continue with the rest."
        fi
    else
        aviso "I am not installing anything. Copy the line above whenever you want."
    fi
    return 0
}

# ─── Step: Hyprland ──────────────────────────────────────────────────────────
# k4 owns ONE file and adds ONE line to yours. Same deal as the theme module
# does with config/k4-theme.lua, and for the same reason: reverting is deleting
# two things, not guessing what changed.
HYPR=${HYPR_DIR:-$HOME/.config/hypr}

# Normalize the key of a shortcut line for comparison.
# In Lua the modifier is usually a variable (`mainMod`), so it is replaced by
# SUPER. If your configuration calls it something else, this slips through and
# the only thing lost is a warning: it never writes anything wrong because of it.
teclas_lua() {
    sed -n 's/^[[:space:]]*hl\.bind(\([^,]*\),.*/\1/p' "$1" 2>/dev/null \
        | sed -e 's/"//g' -e 's/\.\.//g' -e 's/[[:space:]]//g' \
        | tr 'a-z' 'A-Z' \
        | sed -e 's/^MAINMOD/SUPER/' -e 's/^MOD/SUPER/' -e 's/^SUPERMOD/SUPER/' \
        | sed '/^$/d' | sort -u
}

teclas_conf() {
    sed -n 's/^[[:space:]]*bind[lnedmpirst]*[[:space:]]*=[[:space:]]*\([^,]*\),[[:space:]]*\([^,]*\),.*/\1 \2/p' \
        "$1" 2>/dev/null \
        | tr 'a-z' 'A-Z' \
        | sed -e 's/\$[A-Z0-9_]*MOD/SUPER/g' -e 's/[[:space:]]\{1,\}/+/g' \
              -e 's/^+//' -e 's/+$//' \
        | sed '/^$/d' | sort -u
}

paso_hyprland() {
    titulo "Hyprland"

    if [ ! -d "$HYPR" ]; then
        aviso "No $HYPR: not setting shortcuts."
        nota "The bar still starts; only the keys are missing."
        return 0
    fi

    # Lua config (CachyOS/noctalia) or the classic one?
    if [ -f "$HYPR/hyprland.lua" ]; then
        FORMA=lua
        PLANTILLA="$RAIZ/hypr/k4.lua"
        CFG="$HYPR/config/k4.lua"
        ENTRADA="$HYPR/hyprland.lua"
        ENGANCHE='require("config.k4")'
        MARCA='require("config.k4")'
    elif [ -f "$HYPR/hyprland.conf" ]; then
        FORMA=conf
        PLANTILLA="$RAIZ/hypr/k4.conf"
        CFG="$HYPR/k4.conf"
        ENTRADA="$HYPR/hyprland.conf"
        ENGANCHE="source = $CFG"
        MARCA="k4.conf"
    else
        aviso "Neither hyprland.lua nor hyprland.conf in $HYPR."
        nota "I do not know where to put the shortcuts. Create it and rerun."
        return 0
    fi

    [ -f "$PLANTILLA" ] || morir "Missing template $PLANTILLA."

    # 1 · k4's file. Always rewritten: it is ours.
    mkdir -p "$(dirname "$CFG")"
    sed "s|@RAIZ@|$RAIZ|g" "$PLANTILLA" > "$CFG"
    bien "Written $CFG ($FORMA)."

    # 2 · The hook line, only if it is not already there. Running twice cannot
    #     leave two lines.
    if grep -qF "$MARCA" "$ENTRADA" 2>/dev/null; then
        bien "Already hooked in $(basename "$ENTRADA")."
    elif [ "$FORMA" = lua ] && grep -qF 'require("config.k4-theme")' "$ENTRADA"; then
        # The theme has to come last so its settings win, so the shortcuts slip
        # in right before it instead of going at the end.
        # We enter above the comment that accompanies the theme, not between the
        # comment and its line: there it would be orphaned and look like ours.
        _tmp="$ENTRADA.k4nuevo"
        awk -v linea="$ENGANCHE" '
            function suelta() { for (i = 1; i <= n; i++) print buf[i]; n = 0 }
            /^[[:space:]]*(--.*)?$/ { buf[++n] = $0; next }
            /require\("config\.k4-theme"\)/ && !hecho {
                print "";
                print "-- k4: shortcuts and startup of the bar";
                print linea;
                hecho = 1;
                suelta(); print; next
            }
            { suelta(); print }
            END { suelta() }
        ' "$ENTRADA" > "$_tmp" && mv "$_tmp" "$ENTRADA"
        bien "Hooked into $(basename "$ENTRADA"), before the theme."
    else
        {
            printf '\n'
            if [ "$FORMA" = lua ]; then
                printf -- '-- k4: shortcuts and startup of the bar\n'
            else
                printf '# k4: shortcuts and startup of the bar\n'
            fi
            printf '%s\n' "$ENGANCHE"
        } >> "$ENTRADA"
        bien "Hooked at the end of $(basename "$ENTRADA")."
    fi

    migrar_duplicados
    revisar_duplicados
    revisar_colisiones
}

# ─── What you already had set up ─────────────────────────────────────────────
# Recognizing a k4 line is not grepping for "call k4": almost nobody writes the
# whole command on every shortcut; it is saved in a variable and concatenated.
# In a normal configuration the text only shows up in the three definitions and
# in none of the twenty-odd shortcut lines. So first we find out what those
# variables are called, and then we also search for them.
# Only the files Hyprland actually loads. Not `grep -r`: a `binds.lua.bak`
# thrown about would show up in every warning without Hyprland ever having read
# it. Confirmed with my own backups.
ficheros_hypr() {
    for _g in "$HYPR"/*.lua "$HYPR"/*.conf "$HYPR"/config/*.lua "$HYPR"/config/*.conf; do
        [ -f "$_g" ] || continue
        [ "$_g" = "$CFG" ] && continue
        printf '%s\n' "$_g"
    done
}

patron_k4() {
    _vars=$(
        ficheros_hypr | while IFS= read -r _f; do
            grep -hE '=[^=]*call k4' "$_f" 2>/dev/null || true
        done \
        | sed -E 's/^[[:space:]]*(local[[:space:]]+)?//' \
        | sed -E 's/[[:space:]]*=.*//' \
        | grep -E '^\$?[A-Za-z_][A-Za-z0-9_]*$' | sort -u
    )
    #  The GLOBAL shortcuts k4 installs, one by one and not with a wildcard
    #  `k4:*`: a plugin from outside also publishes its own — the crack, to name
    #  just one — and each user binds those by hand. Sweeping them with a broad
    #  pattern would delete bindings k4 did not put in and cannot restore.
    _pat='call k4|k4:clic|k4:clicDerecho|k4:dual|k4:atalaya'
    for _v in $_vars; do
        # The `$` of hyprland.conf variables has to be escaped for the ERE.
        _pat="$_pat|$(printf '%s' "$_v" | sed 's/\$/\\$/')"
    done
    printf '%s' "$_pat"
}

# Before warning, the old lines the installer can identify without ambiguity are
# removed. A copy is saved next to each file: if someone had their own action that
# looks like k4, they can recover it from there. Comment lines are never touched.
migrar_duplicados() {
    PAT_K4=$(patron_k4)
    [ -n "$PAT_K4" ] || return 0

    _cambios=0
    _ficheros=$(ficheros_hypr)
    [ -n "$_ficheros" ] || return 0

    while IFS= read -r _f; do
        [ -n "$_f" ] || continue
        _tmp=$(mktemp) || continue

        # The pattern includes the variables pointing to "call k4", so it also
        # covers the bind lines that concatenate k4Call. All comments and
        # everything that is not a complete k4 line are kept.
        awk -v patron="$PAT_K4" -v raiz="$RAIZ" -v destino="$DESTINO" '
            /^[[:space:]]*(--|#)/ { print; next }
            (index($0, raiz "/arrancar") || index($0, destino "/arrancar") || $0 ~ /k4\/arrancar/) { quitadas++; next }
            $0 ~ patron { quitadas++; next }
            { print }
            END { if (quitadas) printf "%d\n", quitadas > "/dev/stderr" }
        ' "$_f" > "$_tmp" 2>"$_tmp.n"
        _quitadas=$(cat "$_tmp.n" 2>/dev/null || printf '0')
        rm -f "$_tmp.n"
        # `mktemp` creates 0600; the original file's permissions are preserved on
        # replacement so a shared configuration does not accidentally become
        # private.
        if ! chmod --reference="$_f" "$_tmp" 2>/dev/null; then
            _modo=$(ls -ld "$_f" 2>/dev/null | awk '{print $1}' | cut -c2- || true)
            [ -n "${_modo:-}" ] && chmod "$_modo" "$_tmp" 2>/dev/null || true
        fi

        if [ "${_quitadas:-0}" -eq 0 ] || cmp -s "$_f" "$_tmp"; then
            rm -f "$_tmp"
            continue
        fi

        _copia="$_f.k4.bak"
        if [ -e "$_copia" ]; then
            _copia="$_f.k4.bak.$(date +%Y%m%d-%H%M%S)"
        fi
        cp -p "$_f" "$_copia"
        mv "$_tmp" "$_f"
        _cambios=$((_cambios + 1))
        bien "Migrated $_quitadas old k4 lines in $(basename "$_f")."
        nota "Backup: $_copia"
    done <<EOF
$_ficheros
EOF

    if [ "$_cambios" -gt 0 ]; then
        nota "The new shortcuts and startup are centralized in $(basename "$CFG")."
    fi
}

# If any line that does not look like a complete line were left, it is shown so
# it does not go unnoticed. In a normal install nothing should remain.
revisar_duplicados() {
    PAT_K4=$(patron_k4)
    _viejos=$(ficheros_hypr | while IFS= read -r _f; do
        awk -v f="$_f" -v patron="$PAT_K4" -v raiz="$RAIZ" -v destino="$DESTINO" '
            /^[[:space:]]*(--|#)/ { next }
            (index($0, raiz "/arrancar") || index($0, destino "/arrancar") || $0 ~ /k4\/arrancar/ || $0 ~ patron) {
                printf "%s:%d:%s\n", f, NR, $0
            }
        ' "$_f" 2>/dev/null || true
    done)
    [ -n "$_viejos" ] || return 0

    _atajos=$(printf '%s\n' "$_viejos" | grep -E "$PAT_K4" || true)
    _arranques=$(printf '%s\n' "$_viejos" | grep '/arrancar' || true)

    if [ -n "$_atajos" ]; then
        printf '\n'
        aviso "You have hand-written k4 shortcuts. They are now redundant: remove"
        nota  "them or they will fire twice. Review those lines before deleting."
        pintar_lineas "$_atajos"
    fi

    if [ -n "$_arranques" ]; then
        printf '\n'
        aviso "And you were already starting the bar from your config:"
        pintar_lineas "$_arranques"
        nota "Remove it: $(basename "$CFG") now does it. With two, double island."
    fi
}

# `grep -n` lines, grouped by file and in numeric order, with the path trimmed
# and the contents shortened. Without this they are forty repeated absolute paths
# sorted as text, unreadable.
pintar_lineas() {
    printf '%s\n' "$1" | awk -F: -v base="$HYPR/" -v ap="$APAGADO" -v fin="$FIN" '
        {
            f = $1; n = $2;
            sub("^" base, "", f);
            texto = $0;
            sub(/^[^:]*:[^:]*:/, "", texto);
            gsub(/^[[:space:]]+/, "", texto);
            if (length(texto) > 58) texto = substr(texto, 1, 55) "…";
            clave[++i] = sprintf("%s\t%06d\t%s", f, n, texto);
        }
        END {
            n = asort_simple(clave, i);
            for (j = 1; j <= i; j++) {
                split(clave[j], p, "\t");
                printf "    %s%-22s%s %s%s%s\n", "", p[1] ":" (p[2] + 0), "", ap, p[3], fin
            }
        }
        function asort_simple(a, n,   x, y, t) {
            for (x = 2; x <= n; x++) {
                t = a[x];
                for (y = x - 1; y >= 1 && a[y] > t; y--) a[y + 1] = a[y];
                a[y + 1] = t
            }
            return n
        }'
}

# Keys k4 wants that you already use for something else. Just a warning: whoever
# is defined last wins, and that is not decided by the installer.
revisar_colisiones() {
    _tmp=$(mktemp -d) || return 0

    if [ "$FORMA" = lua ]; then teclas_lua "$CFG"; else teclas_conf "$CFG"; fi > "$_tmp/mias"
    [ -s "$_tmp/mias" ] || { rm -rf "$_tmp"; return 0; }

    : > "$_tmp/suyas"
    ficheros_hypr > "$_tmp/ficheros"
    while IFS= read -r _f; do
        # Only lines that are NOT k4's count: the user's were already warned about.
        grep -vE "$PAT_K4" "$_f" > "$_tmp/limpio" 2>/dev/null || true
        case "$_f" in
            *.lua)  teclas_lua  "$_tmp/limpio" >> "$_tmp/suyas" ;;
            *.conf) teclas_conf "$_tmp/limpio" >> "$_tmp/suyas" ;;
        esac
    done < "$_tmp/ficheros"

    sort -u "$_tmp/suyas" -o "$_tmp/suyas"
    _choque=$(comm -12 "$_tmp/mias" "$_tmp/suyas")
    rm -rf "$_tmp"

    [ -n "$_choque" ] || return 0
    printf '\n'
    aviso "These keys are already used for something else:"
    printf '%s\n' "$_choque" | while IFS= read -r t; do
        [ -n "$t" ] && nota "$t"
    done
    nota "The last one defined wins, and k4's enter with \"$ENGANCHE\"."
    nota "If you prefer yours, bind them again AFTER that line."
}

# ─── Step: the code ──────────────────────────────────────────────────────────
ORIGEN=${K4_ORIGEN:-https://github.com/k4ditano/k4.git}

# First install through a pipe: there is no repository here yet.
clonar_y_seguir() {
    titulo "Code"
    command -v git >/dev/null 2>&1 || morir "I need git to clone k4."

    if [ -e "$DESTINO" ]; then
        morir "$DESTINO already exists. If it is a k4 install, run it from there:
    $DESTINO/installer.sh"
    fi

    printf '  Cloning into %s...\n' "$DESTINO"
    mkdir -p "$(dirname "$DESTINO")"
    git clone --depth 1 "$ORIGEN" "$DESTINO" || morir "Could not clone."
    bien "Cloned."

    # And it relaunches from the repository, where the table and templates are.
    # Standard input is busy with the script itself (we are being read through a
    # pipe), so the terminal is recovered to be able to ask; if there is none,
    # it continues without it.
    printf '\n%s  Continuing from %s%s\n' "$APAGADO" "$DESTINO/installer.sh" "$FIN"
    if (true < /dev/tty) 2>/dev/null; then
        exec "$DESTINO/installer.sh" "$@" < /dev/tty
    else
        exec "$DESTINO/installer.sh" "$@"
    fi
}

paso_codigo() {
    titulo "Code"

    if [ ! -d "$RAIZ/.git" ]; then
        nota "$RAIZ is not a git repository: nothing to update."
        return 0
    fi
    if ! command -v git >/dev/null 2>&1; then
        aviso "Without git I cannot update. I continue with the rest."
        return 0
    fi

    # Nothing is touched with uncommitted changes. Losing someone's work by
    # "updating" is exactly what must not happen.
    if [ -n "$(git -C "$RAIZ" status --porcelain 2>/dev/null)" ]; then
        aviso "You have uncommitted changes in $RAIZ: I am not updating the code."
        nota "Stash or discard them and rerun."
        return 0
    fi

    _antes=$(git -C "$RAIZ" rev-parse --short HEAD 2>/dev/null || printf '?')
    if git -C "$RAIZ" pull --ff-only --quiet 2>/dev/null; then
        _ahora=$(git -C "$RAIZ" rev-parse --short HEAD 2>/dev/null || printf '?')
        if [ "$_antes" = "$_ahora" ]; then
            bien "Already up to date ($_ahora)."
        else
            bien "Updated: $_antes → $_ahora."
        fi
    else
        aviso "Could not update (no network, or the branch diverged?)."
        nota "I continue with the rest: shortcuts and packages do not depend on this."
    fi
}

# ─── Step: the skill for agents ──────────────────────────────────────────────
# An agent working on this machine does not know there is a bar called k4, nor
# that everything in it is plugins. You can tell it every time, or leave it
# written once where it reads it on its own.
#
# It is linked, not copied: so updating k4 updates what it reads too.
paso_agente() {
    titulo "For the agents"
    if [ ! -d "$RAIZ/agents/skills/k4" ]; then
        aviso "I cannot find the skill; I skip it."
        return
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        aviso "Without python3 I cannot link it."
        return
    fi
    python3 "$RAIZ/tools/agent.py" --install 2>/dev/null | while read -r l; do
        nota "$l"
    done
    bien "Claude, Codex and company will know what this is and how to write a plugin for it"
}

# ─── Step: restart ───────────────────────────────────────────────────────────
paso_reiniciar() {
    titulo "The bar"

    if [ "$SIN_REINICIAR" -eq 1 ]; then
        nota "I am not touching it, you asked with --sin-reiniciar."
        return 0
    fi

    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl reload >/dev/null 2>&1 && bien "Hyprland configuration reloaded."
    fi

    command -v quickshell >/dev/null 2>&1 || {
        aviso "quickshell is not installed yet; I cannot start the bar."
        return 0
    }

    if pgrep -x quickshell >/dev/null 2>&1; then
        preguntar "Restart the bar so it picks up the changes?" || {
            nota "OK. Start it whenever you want: $RAIZ/arrancar"
            return 0
        }
        # `pkill -x`, never `pkill -f`: with -f the pattern also matches this
        # script's own command line and kills it. It has happened twice and the
        # symptom is a double island.
        pkill -x quickshell || true
        _i=0
        while pgrep -x quickshell >/dev/null 2>&1 && [ "$_i" -lt 20 ]; do
            sleep 0.2; _i=$((_i + 1))
        done
    fi

    "$RAIZ/arrancar" --no-duplicate -d >/dev/null 2>&1 &
    _i=0
    while [ "$_i" -lt 25 ]; do
        pgrep -x quickshell >/dev/null 2>&1 && break
        sleep 0.2; _i=$((_i + 1))
    done

    _n=$(pgrep -c -x quickshell 2>/dev/null || printf '0')
    case "$_n" in
        1) bien "The bar is running." ;;
        0) mal "The bar did not start. See what it says: $RAIZ/arrancar" ;;
        *) mal "There are $_n quickshell running: that is the double island."
           nota "Stop it all with \"pkill -x quickshell\" and start one." ;;
    esac
}

# ─── Here we go ──────────────────────────────────────────────────────────────
printf '\n%sk4%s · installer\n' "$NEGRITA" "$FIN"

# No repository under us (curl | sh): first of all get it, and this does not
# return: `clonar_y_seguir` ends in an `exec` of the already-cloned installer.
if [ -z "$RAIZ" ]; then
    [ "$SECO" -eq 1 ] && morir "With --dry-run I do not clone anything. Clone first:
    git clone $ORIGEN $DESTINO"
    clonar_y_seguir "$@"
fi

diagnosticar

if [ "$SECO" -eq 1 ]; then
    printf '\n%sDry mode: I touched nothing.%s\n\n' "$APAGADO" "$FIN"
    [ "$N_BASE" -eq 0 ] || exit 1
    exit 0
fi

paso_codigo
paso_paquetes
paso_hyprland
paso_agente
paso_reiniciar

titulo "Done"
if [ "$N_BASE" -gt 0 ]; then
    aviso "$N_BASE required packages are still missing; look at them above."
fi
nota "Shortcuts: SUPER+Space launcher · SUPER+I panel · SUPER+C capture"
nota "SUPER+SHIFT+C record · SUPER+SHIFT+E editor · SUPER+Z settings"
nota "All of them are in $RAIZ/hypr/ and are documented in the README."
printf '\n'