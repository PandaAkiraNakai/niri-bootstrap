#!/usr/bin/env bash
# bootstrap.sh — instala niri + stack cyberpunk-netrunner en Arch / CachyOS.
#
# Uso:
#   ./bootstrap.sh                    # instala todo (pacman + AUR + dotfiles)
#   ./bootstrap.sh --dry-run          # muestra qué haría, sin tocar nada
#   ./bootstrap.sh --no-aur           # salta paquetes AUR (sin noctalia)
#   ./bootstrap.sh --skip-dotfiles    # no clona ni copia configs
#   ./bootstrap.sh --dotfiles-repo URL    # usa otro repo de dotfiles
#
# Idempotente: re-ejecutar es seguro. Los paquetes ya instalados se omiten,
# las configs existentes se respaldan con timestamp antes de copiar.

set -euo pipefail

# ─── Defaults ───────────────────────────────────────────────────────────
DRY_RUN=0
DO_AUR=1
DO_DOTFILES=1
DOTFILES_REPO="https://github.com/PandaAkiraNakai/dotfiles.git"
PKG_FILE="$(dirname "$(readlink -f "$0")")/packages.txt"
AUR_FILE="$(dirname "$(readlink -f "$0")")/packages-aur.txt"
BACKUP_SUFFIX=".bak-$(date +%Y%m%d-%H%M%S)"

# ─── Colores (truecolor, paleta cyberpunk del repo dotfiles) ────────────
if [[ -t 1 ]]; then
    C_CYAN=$'\e[38;2;0;240;255m'
    C_MAGENTA=$'\e[38;2;255;44;241m'
    C_YELLOW=$'\e[38;2;249;248;113m'
    C_GREEN=$'\e[38;2;54;249;164m'
    C_RED=$'\e[38;2;255;56;100m'
    C_DIM=$'\e[2m'
    C_RESET=$'\e[0m'
else
    C_CYAN=""; C_MAGENTA=""; C_YELLOW=""; C_GREEN=""; C_RED=""; C_DIM=""; C_RESET=""
fi

step()    { printf '%s>>%s %s\n'           "$C_MAGENTA" "$C_RESET" "$1"; }
info()    { printf '%s   %s%s\n'           "$C_DIM"     "$1"      "$C_RESET"; }
ok()      { printf '%s ✓ %s%s\n'           "$C_GREEN"   "$1"      "$C_RESET"; }
warn()    { printf '%s ⚠ %s%s\n'           "$C_YELLOW"  "$1"      "$C_RESET" >&2; }
err()     { printf '%s ✗ %s%s\n'           "$C_RED"     "$1"      "$C_RESET" >&2; }

# ─── Parseo de args ─────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)        DRY_RUN=1; shift;;
        --no-aur)         DO_AUR=0; shift;;
        --skip-dotfiles)  DO_DOTFILES=0; shift;;
        --dotfiles-repo)  DOTFILES_REPO="$2"; shift 2;;
        --dotfiles-repo=*) DOTFILES_REPO="${1#*=}"; shift;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) err "flag desconocido: $1"; exit 2;;
    esac
done

# Wrapper que respeta --dry-run.
do_run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '%s    [dry] %s%s\n' "$C_DIM" "$*" "$C_RESET"
    else
        "$@"
    fi
}

# ─── Sanity checks ──────────────────────────────────────────────────────
step "Sanity checks"

if [[ $EUID -eq 0 ]]; then
    err "No corras esto como root. El script invoca sudo cuando hace falta."
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    err "No puedo leer /etc/os-release — sistema desconocido."
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}:${ID_LIKE:-}" in
    arch:*|cachyos:*|*:*arch*) ok "Distro Arch-based detectada: ${PRETTY_NAME:-$ID}";;
    *) err "Distro no soportada: ${PRETTY_NAME:-$ID}. Este script asume pacman."; exit 1;;
esac

if ! command -v pacman >/dev/null; then
    err "pacman no está en PATH — abortando."
    exit 1
fi

if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
    warn "Sin red hacia archlinux.org — la instalación va a fallar al sincronizar."
fi

[[ -r "$PKG_FILE" ]] || { err "No encuentro $PKG_FILE"; exit 1; }
[[ -r "$AUR_FILE" ]] || { err "No encuentro $AUR_FILE"; exit 1; }

ok "Listo para arrancar"
[[ $DRY_RUN -eq 1 ]] && info "Modo dry-run: no se va a tocar el sistema."

# ─── Lectura de listas de paquetes ──────────────────────────────────────
read_pkglist() {
    grep -vE '^\s*(#|$)' "$1" | awk '{print $1}'
}

mapfile -t PKGS     < <(read_pkglist "$PKG_FILE")
mapfile -t AUR_PKGS < <(read_pkglist "$AUR_FILE")

step "Paquetes oficiales (${#PKGS[@]})"
printf '   %s\n' "${PKGS[@]}" | column -c 80 || printf '   %s\n' "${PKGS[@]}"

if [[ $DO_AUR -eq 1 && ${#AUR_PKGS[@]} -gt 0 ]]; then
    step "Paquetes AUR (${#AUR_PKGS[@]})"
    printf '   %s\n' "${AUR_PKGS[@]}"
fi

# ─── Sync + install pacman ──────────────────────────────────────────────
step "Sincronizando bases de datos de pacman"
do_run sudo pacman -Sy --noconfirm

step "Instalando paquetes oficiales (saltea los ya instalados)"
do_run sudo pacman -S --needed --noconfirm "${PKGS[@]}"
ok "Paquetes oficiales listos"

# ─── AUR helper (paru) ──────────────────────────────────────────────────
if [[ $DO_AUR -eq 1 ]]; then
    if command -v paru >/dev/null; then
        info "paru detectado: $(paru --version | head -1)"
    elif command -v yay >/dev/null; then
        info "yay detectado, lo usaré en vez de paru"
    else
        step "paru no instalado — armando desde el AUR"
        do_run sudo pacman -S --needed --noconfirm base-devel
        TMPDIR="$(mktemp -d)"
        do_run git clone https://aur.archlinux.org/paru.git "$TMPDIR/paru"
        do_run sh -c "cd '$TMPDIR/paru' && makepkg -si --noconfirm"
        do_run rm -rf "$TMPDIR"
        ok "paru instalado"
    fi

    HELPER=""
    command -v paru >/dev/null && HELPER=paru
    [[ -z "$HELPER" ]] && command -v yay >/dev/null && HELPER=yay

    if [[ -n "$HELPER" && ${#AUR_PKGS[@]} -gt 0 ]]; then
        step "Instalando paquetes AUR con $HELPER"
        do_run "$HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"
        ok "Paquetes AUR listos"
    fi
fi

# ─── Dotfiles ───────────────────────────────────────────────────────────
if [[ $DO_DOTFILES -eq 1 ]]; then
    step "Clonando dotfiles ($DOTFILES_REPO)"
    DOTFILES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/niri-bootstrap/dotfiles"
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        info "Repo ya existe en $DOTFILES_DIR, hago git pull"
        do_run git -C "$DOTFILES_DIR" pull --ff-only
    else
        do_run mkdir -p "$(dirname "$DOTFILES_DIR")"
        do_run git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi

    step "Copiando configs a ~/.config (con backup si existían)"
    if [[ -d "$DOTFILES_DIR/config" ]]; then
        for src in "$DOTFILES_DIR/config"/*; do
            name="$(basename "$src")"
            # Caso especial: starship.toml vive directo en ~/.config/, no
            # en subdir.
            if [[ "$name" == "starship.toml" ]]; then
                dst="$HOME/.config/starship.toml"
            else
                dst="$HOME/.config/$name"
            fi
            if [[ -e "$dst" && ! -L "$dst" ]]; then
                info "Backup: $dst → $dst$BACKUP_SUFFIX"
                do_run mv "$dst" "$dst$BACKUP_SUFFIX"
            elif [[ -L "$dst" ]]; then
                do_run rm "$dst"
            fi
            do_run mkdir -p "$(dirname "$dst")"
            do_run cp -r "$src" "$dst"
        done
        ok "Configs copiadas a ~/.config/"
    else
        warn "$DOTFILES_DIR/config no existe — ¿el repo cambió de layout?"
    fi
fi

# ─── Servicios systemd (user) ───────────────────────────────────────────
step "Habilitando servicios systemd --user (audio + portal)"
USER_SERVICES=(
    pipewire.service
    pipewire-pulse.service
    wireplumber.service
)
for svc in "${USER_SERVICES[@]}"; do
    if systemctl --user is-enabled "$svc" >/dev/null 2>&1; then
        info "$svc ya está habilitado"
    else
        do_run systemctl --user enable --now "$svc"
        ok "Habilitado $svc"
    fi
done

# ─── Shell por defecto ──────────────────────────────────────────────────
if [[ "${SHELL:-}" != *fish ]]; then
    step "Cambiando shell default a fish"
    if command -v fish >/dev/null; then
        if grep -q "^$(command -v fish)$" /etc/shells 2>/dev/null; then
            do_run chsh -s "$(command -v fish)" "$USER"
            ok "Shell default ahora es fish (efectivo en próximo login)"
        else
            warn "$(command -v fish) no está en /etc/shells — agregalo manualmente"
        fi
    else
        warn "fish no se instaló — saltando chsh"
    fi
fi

# ─── Fin ────────────────────────────────────────────────────────────────
step "Listo"

cat <<EOF

${C_CYAN}══════════════════════════════════════════════════════════════════════${C_RESET}
${C_MAGENTA}  bootstrap completado.${C_RESET}

Siguientes pasos manuales:

  1. Cerrar sesión y elegir niri en el greeter (GDM / SDDM / tuigreet).
     Si no aparece, verifica que /usr/share/wayland-sessions/niri.desktop
     fue instalado por el paquete niri.

  2. Reiniciar para que fish quede como shell default si lo cambiaste
     y para que los servicios user arranquen con la sesión.

  3. Una vez en niri, editar el monitor layout en
     ~/.config/niri/cfg/display.kdl con tu hardware real
     (\`niri msg outputs\` te lista los nombres).

  4. Asegurarte de que la Nerd Font funciona en tu terminal — el prompt
     de starship usa iconos de Nerd Font.

${C_DIM}  Si algo se rompe, los configs originales están en *${BACKUP_SUFFIX}
  dentro de ~/.config/.${C_RESET}
${C_CYAN}══════════════════════════════════════════════════════════════════════${C_RESET}

EOF
