# niri-bootstrap

Script único e idempotente para dejar una instalación limpia de **Arch / CachyOS** lista con [**niri**](https://github.com/YaLTeR/niri) (Wayland scrollable WM), shell [**noctalia**](https://github.com/noctalia-dev/noctalia), terminal **alacritty**, prompt **starship**, shell **fish** y el resto del stack cyberpunk-netrunner.

> Pensado para una torre / laptop personal. No es un installer "para todos" — se asume que ya tenés Arch booteado y querés llegar rápido al entorno gráfico.

## Qué hace, en orden

1. **Sanity checks** — confirma que es Arch-based, hay red, y *no* corre como root.
2. **`pacman -Sy`** seguido de `pacman -S --needed` con todo lo de [`packages.txt`](packages.txt): niri, alacritty, fish, starship, micro, btop, fastfetch, pipewire stack, gamescope, Nerd Font, utilities Wayland.
3. **AUR** (opcional con `--no-aur`) — instala `paru` si no está, después usa paru para los paquetes de [`packages-aur.txt`](packages-aur.txt) (por defecto: `noctalia-shell`).
4. **Dotfiles** (opcional con `--skip-dotfiles`) — clona [`PandaAkiraNakai/dotfiles`](https://github.com/PandaAkiraNakai/dotfiles) en `~/.local/share/niri-bootstrap/dotfiles` y copia su `config/*` a `~/.config/`, respaldando todo lo que ya existe con sufijo `.bak-YYYYMMDD-HHMMSS`.
5. **Servicios `systemd --user`** — habilita pipewire, pipewire-pulse y wireplumber.
6. **Shell** — si tu shell no es fish, ejecuta `chsh -s $(command -v fish)`.
7. **Resumen final** con los pasos manuales que quedan (loguearte en niri, editar el layout de monitores, etc.).

## Requisitos

- Arch Linux, CachyOS u otra distro Arch-based con `pacman`.
- Acceso a `sudo`.
- Conexión a internet.

## Uso

```bash
git clone https://github.com/PandaAkiraNakai/niri-bootstrap.git
cd niri-bootstrap
./bootstrap.sh
```

### Flags

| Flag | Efecto |
|------|--------|
| `--dry-run` | Muestra paso por paso qué haría, sin tocar el sistema. |
| `--no-aur` | Salta `paru` y los paquetes AUR (te quedás sin noctalia, niri queda usable a secas). |
| `--skip-dotfiles` | No clona ni copia configs. Útil si querés probar con tus propios dotfiles. |
| `--dotfiles-repo URL` | Usa otro repo en vez del default. Tiene que respetar el layout `config/<app>/...`. |
| `-h`, `--help` | Imprime el bloque de ayuda del header del script. |

Ejemplos:

```bash
./bootstrap.sh --dry-run
./bootstrap.sh --no-aur --dotfiles-repo https://github.com/tu-user/dotfiles.git
./bootstrap.sh --skip-dotfiles
```

## Idempotencia

- `pacman -S --needed` saltea paquetes ya instalados.
- `paru -S --needed` también.
- Si los dotfiles ya están clonados, hace `git pull --ff-only` en vez de re-clonar.
- Antes de pisar una config existente, la respalda con timestamp — nunca se pierde nada accidentalmente.
- Los servicios systemd con `is-enabled` ya activo no se re-habilitan.

Reejecutar es seguro y, en general, rápido (todo lo "ya hecho" se omite).

## Personalizar

### Cambiar la lista de paquetes

Editás directo [`packages.txt`](packages.txt) y [`packages-aur.txt`](packages-aur.txt). Una línea por paquete, comentarios con `#`.

### Cambiar de dotfiles

Tres opciones:

1. Forkear `PandaAkiraNakai/dotfiles`, editar a gusto, y pasar tu fork con `--dotfiles-repo`.
2. Mantener un repo desde cero con la misma estructura (`config/<app>/...`).
3. Saltar dotfiles con `--skip-dotfiles` y trabajar a mano sobre `~/.config/`.

## Qué *no* hace

- No edita `/etc/fstab`, no crea usuarios, no cambia hostname.
- No instala greeter (GDM / SDDM / tuigreet). Si arrancás tty puro vas a tener que lanzar `niri` a mano o instalar uno por separado.
- No configura tu monitor layout — `~/.config/niri/cfg/display.kdl` viene con outputs genéricos; usar `niri msg outputs` para descubrir los nombres reales y editar.
- No instala paquetes específicos de "mi setup" (bots, MonkeyMoney, etc). Es base reutilizable.

## Cómo deshacer

Los respaldos automáticos quedan en `~/.config/<app>.bak-YYYYMMDD-HHMMSS`. Para volver a una config previa:

```bash
mv ~/.config/niri ~/.config/niri.nuevo
mv ~/.config/niri.bak-20260520-143000 ~/.config/niri
```

Los paquetes instalados se sacan con `sudo pacman -Rns <pkg>` uno por uno (o todos con la lista de `packages.txt`).

## Licencia

MIT — ver [LICENSE](LICENSE).

<!-- profile-excerpt -->
Script idempotente que parte de un **Arch / CachyOS** limpio y deja el deck listo: paquetes oficiales, AUR vía paru, clone de [`dotfiles`](https://github.com/PandaAkiraNakai/dotfiles), servicios `systemd --user` (pipewire stack) y `chsh` a fish. Flags `--dry-run`, `--no-aur`, `--skip-dotfiles`, `--dotfiles-repo`. Backup automático con timestamp de cualquier config preexistente. `// jack-in desde cero · idempotente · sin sorpresas`
<!-- /profile-excerpt -->
