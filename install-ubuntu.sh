#!/usr/bin/env bash
# Build and install Clavis on an Ubuntu/Debian arm64 desktop from this checkout.
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
prefix=${PREFIX:-"$HOME/.local"}
build_dir="$repo_root/build-ubuntu"
use_system=false
skip_deps=false
with_service=true
enable_service=false
start_now=false
dry_run=false
multiarch=""
cava_version=1.0.0
cava_sha256=2866cea11d0bd38406924ab2b47d5577f14909a7321ee928b6836391f375af7e
m3shapes_commit=8a6fe8961749887d677700b6508e0c9249968b7e
m3shapes_sha256=4ffff18350a2db6db6c47119ccda3b3682252e5e4c7d9d60dd546f3415fdb4ed

usage() {
    cat <<'EOF'
Usage: install-ubuntu.sh [OPTIONS]

Build and install Clavis on Ubuntu/Debian ARM64 (aarch64) or x86_64.

Options:
  --system              Install under /usr/local (uses sudo for install)
  --prefix PATH         Install prefix (default: $HOME/.local)
  --skip-deps           Do not run apt-get install
  --no-service          Do not write a systemd user unit
  --enable-service      Enable the user unit after writing it
  --start               Start the user unit after enabling it
  --dry-run             Print actions without making changes
  -h, --help            Show this help

Environment:
  PREFIX                Same as --prefix
  CLAVIS_KEY            Optional key-cli executable used by the shell at runtime

Examples:
  ./install-ubuntu.sh --dry-run
  ./install-ubuntu.sh --enable-service
  ./install-ubuntu.sh --system
EOF
}

while (($#)); do
    case $1 in
        --system) use_system=true ;;
        --prefix)
            [[ $# -ge 2 ]] || {
                echo "error: --prefix needs a path" >&2
                exit 2
            }
            prefix=$2
            shift
            ;;
        --prefix=*) prefix=${1#*=} ;;
        --skip-deps) skip_deps=true ;;
        --no-service) with_service=false ;;
        --enable-service) enable_service=true ;;
        --start) start_now=true ;;
        --dry-run) dry_run=true ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if $use_system; then
    prefix=/usr/local
fi
prefix=${prefix%/}
prefix=${prefix/#\~/$HOME}
if [[ $prefix != /* ]]; then
    echo "error: install prefix must be absolute: $prefix" >&2
    exit 2
fi

run_cmd() {
    if $dry_run; then
        printf ' +'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

run_sudo() {
    if [[ $EUID -eq 0 ]]; then
        run_cmd "$@"
    else
        run_cmd sudo "$@"
    fi
}

run_install() {
    if [[ $prefix == /usr || $prefix == /usr/local ]]; then
        run_sudo "$@"
    else
        run_cmd "$@"
    fi
}

if [[ $EUID -eq 0 ]]; then
    echo "error: run as the desktop user, not root" >&2
    exit 2
fi

if [[ ! -r /etc/os-release ]]; then
    echo "error: /etc/os-release is missing; this installer targets Ubuntu/Debian" >&2
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
    *ubuntu*|*debian*) ;;
    *)
        echo "error: this installer targets Ubuntu/Debian, found ${PRETTY_NAME:-unknown}" >&2
        exit 1
        ;;
esac

machine=$(uname -m)
case $machine in
    aarch64|arm64) machine=aarch64 ;;
    x86_64|amd64) machine=x86_64 ;;
    *)
        echo "error: unsupported architecture: $machine (expected aarch64 or x86_64)" >&2
        exit 1
        ;;
esac
multiarch=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || true)
if [[ -z $multiarch ]]; then
    case $machine in
        aarch64) multiarch=aarch64-linux-gnu ;;
        x86_64) multiarch=x86_64-linux-gnu ;;
    esac
fi
libdir="$prefix/lib/$multiarch"
qmldir="$prefix/lib/$multiarch/qt6/qml"
qml_import_path="$qmldir"
for candidate in "/usr/lib/$multiarch/qt6/qml" /usr/lib/qt6/qml; do
    [[ -d $candidate && $candidate != "$qmldir" ]] && qml_import_path="$qml_import_path:$candidate"
done

echo "Clavis Ubuntu installer"
echo "  system: ${PRETTY_NAME:-unknown} ($machine, $multiarch)"
echo "  prefix: $prefix"
echo "  QML:    $qmldir"
echo "  build:  $build_dir"

apt_packages=(
    build-essential cmake ninja-build pkg-config python3 git curl ca-certificates
    libfftw3-dev qt6-base-dev qt6-base-dev-tools qt6-declarative-dev
    qt6-declarative-dev-tools qt6-wayland-dev qt6-tools-dev qt6-tools-dev-tools
    qt6-shadertools-dev qt6-svg-dev qtkeychain-qt6-dev libpipewire-0.3-dev
    libudev-dev libxkbcommon-dev qml6-module-qtquick qml6-module-qtquick-controls
    qml6-module-qtquick-layouts qml6-module-qtquick-window
    qml6-module-qtquick-effects qml6-module-qt5compat-graphicaleffects
    qml6-module-qtlocation qml6-module-qtpositioning qml6-module-qt-labs-lottieqt
    quickshell niri jq ffmpeg wl-clipboard brightnessctl xdg-utils libnotify-bin
    gsettings-desktop-schemas \
    fcitx5 fcitx5-chinese-addons fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 \
    fcitx5-frontend-qt5 fcitx5-frontend-qt6 \
    ibus ibus-gtk3 ibus-gtk4 ibus-libpinyin ibus-wayland im-config wtype wf-recorder
)

if ! $skip_deps; then
    echo "Installing Ubuntu dependencies..."
    run_sudo apt-get update
    run_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${apt_packages[@]}"
fi

for command in cmake ninja pkg-config python3 qs; do
    if ! command -v "$command" >/dev/null 2>&1 && ! $dry_run; then
        echo "error: required command missing after dependency install: $command" >&2
        exit 1
    fi
done

export PKG_CONFIG_PATH="$libdir/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

temporary=$(mktemp -d "${TMPDIR:-/tmp}/clavis-ubuntu.XXXXXX")
trap 'rm -rf -- "$temporary"' EXIT

install_libcava() {
    if pkg-config --exists libcava; then
        echo "libcava: found $(pkg-config --modversion libcava)"
        return
    fi
    echo "libcava: not packaged by Ubuntu; building the MIT-licensed cavacore $cava_version shared library"
    local archive="$temporary/cava-$cava_version.tar.gz"
    local source="$temporary/cava-$cava_version"
    run_cmd curl --fail --silent --show-error --location \
        "https://github.com/karlstav/cava/archive/refs/tags/$cava_version.tar.gz" \
        --output "$archive"
    if ! $dry_run; then
        printf '%s  %s\n' "$cava_sha256" "$archive" | sha256sum --check --status || {
            echo "error: cava archive checksum mismatch" >&2
            exit 1
        }
        tar -xzf "$archive" -C "$temporary"
    fi
    local library="$temporary/libcava.so.1.0.0"
    if ! $dry_run; then
        cc -O2 -fPIC -shared -Wl,-soname,libcava.so.1 -I"$source" \
            "$source/cavacore.c" -o "$library" -lfftw3 -lm
    fi
    run_install install -d "$libdir" "$prefix/include/cava" "$libdir/pkgconfig"
    run_install install -m755 "$library" "$libdir/libcava.so.1.0.0"
    run_install ln -sfn libcava.so.1.0.0 "$libdir/libcava.so.1"
    run_install ln -sfn libcava.so.1 "$libdir/libcava.so"
    run_install install -m644 "$source/cavacore.h" "$prefix/include/cava/cavacore.h"
    cat > "$temporary/libcava.pc" <<EOF
prefix=$prefix
includedir=\${prefix}/include
libdir=\${prefix}/lib/$multiarch

Name: libcava
Description: cava visualization core
Version: $cava_version
Libs: -L\${libdir} -lcava
Cflags: -I\${includedir}/cava
EOF
    run_install install -m644 "$temporary/libcava.pc" "$libdir/pkgconfig/libcava.pc"
    if [[ $prefix == /usr || $prefix == /usr/local ]]; then
        run_sudo ldconfig
    fi
}

find_m3shapes() {
    local candidate
    for candidate in \
        "$qmldir/M3Shapes/qmldir" \
        "/usr/lib/$multiarch/qt6/qml/M3Shapes/qmldir" \
        "/usr/lib/qt6/qml/M3Shapes/qmldir" \
        "/usr/local/lib/$multiarch/qt6/qml/M3Shapes/qmldir"; do
        [[ -f $candidate ]] && return 0
    done
    return 1
}

install_m3shapes() {
    if find_m3shapes; then
        echo "M3Shapes: found"
        return
    fi
    echo "M3Shapes: installing Qt QML runtime module"
    local archive="$temporary/m3shapes.tar.gz"
    local source="$temporary/m3shapes-$m3shapes_commit"
    run_cmd curl --fail --silent --show-error --location \
        "https://github.com/soramanew/m3shapes/archive/$m3shapes_commit.tar.gz" \
        --output "$archive"
    if ! $dry_run; then
        printf '%s  %s\n' "$m3shapes_sha256" "$archive" | sha256sum --check --status || {
            echo "error: M3Shapes archive checksum mismatch" >&2
            exit 1
        }
        tar -xzf "$archive" -C "$temporary"
    fi
    local build="$source/build"
    run_cmd cmake -S "$source" -B "$build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DCMAKE_INSTALL_LIBDIR="lib/$multiarch" \
        -DINSTALL_QMLDIR="lib/$multiarch/qt6/qml" \
        -DM3SHAPES_BUILD_EXAMPLES=OFF
    run_cmd cmake --build "$build"
    run_install cmake --install "$build"
}

install_libcava
install_m3shapes

# The source checkout intentionally keeps generated Meteocons assets out of git.
# Release sources bundle them; a source install must fetch the same pinned
# resources before CMake copies assets/ into the runtime config.
if [[ ! -f "$repo_root/assets/icons/weather/meteocons/svg/flat/clear-day.svg" \
      || ! -f "$repo_root/assets/icons/weather/meteocons/lottie/fill/clear-day.json" ]]; then
    echo "Weather icons: fetching pinned Meteocons resources"
    run_cmd python3 "$repo_root/scripts/release.py" bundle-resources \
        --cache "$temporary/resources-cache"
fi

echo "Configuring Clavis..."
run_cmd cmake -S "$repo_root" -B "$build_dir" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCLAVIS_QML_INSTALL_DIR="lib/$multiarch/qt6/qml" \
    -DCLAVIS_CONFIG_INSTALL_DIR="etc/xdg/quickshell/clavis" \
    -DCLAVIS_SYSTEMD_USER_INSTALL_DIR="lib/systemd/user"

echo "Building Clavis..."
run_cmd cmake --build "$build_dir"

echo "Installing Clavis into $prefix..."
run_install cmake --install "$build_dir"

config_target="$prefix/etc/xdg/quickshell/clavis"
config_link="$HOME/.config/quickshell/clavis"
if ! $dry_run && [[ ! -e $config_target ]]; then
    echo "warning: installed config directory not found: $config_target" >&2
elif [[ -e $config_link && ! -L $config_link ]]; then
    echo "warning: $config_link is not a symlink; leaving it unchanged" >&2
else
    run_cmd mkdir -p "$HOME/.config/quickshell"
    run_cmd ln -sfn "$config_target" "$config_link"
fi

wrapper="$prefix/bin/clavis-shell"
wrapper_source="$temporary/clavis-shell"
key_command=$(command -v key 2>/dev/null || true)
cat > "$wrapper_source" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export QML_IMPORT_PATH="$qml_import_path\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}"
export LD_LIBRARY_PATH="$libdir\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
if [[ -z "\${CLAVIS_KEY:-}" && -x "$key_command" ]]; then
    export CLAVIS_KEY="$key_command"
fi
exec "$(command -v qs 2>/dev/null || echo /usr/bin/qs)" -c clavis "\$@"
EOF
run_install install -d "$prefix/bin"
run_install install -m755 "$wrapper_source" "$wrapper"

desktop_dir="$HOME/.local/share/applications"
desktop_file="$desktop_dir/org.clavis.Launchpad.desktop"
run_cmd mkdir -p "$desktop_dir"
cat > "$temporary/org.clavis.Launchpad.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Launchpad
Comment=Open the Clavis application grid
Exec="$wrapper" ipc call launchpad toggle
Icon=org.quickshell
Terminal=false
Categories=Utility;
StartupNotify=false
EOF
run_cmd install -m644 "$temporary/org.clavis.Launchpad.desktop" "$desktop_file"

# Make IBus available to applications launched outside the shell as well.
# environment.d is consumed by the systemd user manager at login.
environment_dir="$HOME/.config/environment.d"
run_cmd mkdir -p "$environment_dir"
if [[ ! -e "$environment_dir/90-clavis-ibus.conf" ]]; then
    cat > "$temporary/90-clavis-ibus.conf" <<EOF
GTK_IM_MODULE=wayland
QT_IM_MODULE=wayland
QT_IM_MODULES=wayland
INPUT_METHOD=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
EOF
    run_cmd install -m644 "$temporary/90-clavis-ibus.conf" "$environment_dir/90-clavis-ibus.conf"
fi
if command -v im-config >/dev/null 2>&1; then
    run_cmd im-config -n fcitx5 || true
fi

service_file="$HOME/.config/systemd/user/clavis-shell-ubuntu.service"
if $with_service; then
    run_cmd mkdir -p "$(dirname "$service_file")"
    cat > "$temporary/clavis-shell-ubuntu.service" <<EOF
[Unit]
Description=Clavis Shell (Ubuntu)
Documentation=https://github.com/StatIndet/quickshell
After=graphical-session.target
PartOf=graphical-session.target
StartLimitIntervalSec=30
StartLimitBurst=5

[Service]
Type=simple
Environment="MALLOC_CONF=thp:never,narenas:4,dirty_decay_ms:3000"
Environment="GTK_IM_MODULE=wayland"
Environment="QT_IM_MODULE=wayland"
Environment="QT_IM_MODULES=wayland"
Environment="INPUT_METHOD=fcitx"
Environment="XMODIFIERS=@im=fcitx"
ExecStart=$wrapper -n
Restart=on-failure
RestartSec=2
TimeoutStopSec=10

[Install]
WantedBy=graphical-session.target
EOF
    run_cmd install -m644 "$temporary/clavis-shell-ubuntu.service" "$service_file"

    agent_service_file="$HOME/.config/systemd/user/clavis-agent.service"
    cat > "$temporary/clavis-agent.service" <<EOF
[Unit]
Description=Clavis native desktop agent backend
After=network-online.target

[Service]
Type=simple
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/python3 $HOME/.local/etc/xdg/quickshell/clavis/scripts/agent/clavis-agentd.py
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF
    run_cmd install -m644 "$temporary/clavis-agent.service" "$agent_service_file"
    run_cmd systemctl --user daemon-reload
fi

if $enable_service || $start_now; then
    if ! $with_service; then
        echo "error: --enable-service/--start require the systemd unit; remove --no-service" >&2
        exit 2
    fi
fi
if $enable_service; then
    run_cmd systemctl --user enable clavis-shell-ubuntu.service
    run_cmd systemctl --user enable clavis-agent.service
fi
if $start_now; then
    run_cmd systemctl --user start clavis-shell-ubuntu.service
    run_cmd systemctl --user start clavis-agent.service
fi

cat <<EOF

Clavis install complete.

Run in the foreground:
  $wrapper

Open Launchpad:
  $wrapper ipc call launchpad toggle

EOF
if $with_service; then
    cat <<SERVICE
The systemd user unit is optional:
  $service_file
  systemctl --user enable --now clavis-shell-ubuntu.service

SERVICE
else
    echo "systemd user unit: skipped (--no-service)"
    echo
fi
cat <<'EOF'
Full shell windows require a wlr-layer-shell compositor (Niri is installed by
this script). GNOME sessions use the Launchpad toplevel only.

EOF
if command -v key >/dev/null 2>&1; then
    echo "key-cli: $(key version)"
    echo "The wrapper exports CLAVIS_KEY=$key_command for this shell."
    echo "Keyboard lock indicators still require explicit udev authorization."
else
    echo "key-cli is a separate project and was not installed. Recording, clipboard"
    echo "history, system metrics and keyboard-lock indicators remain unavailable."
fi
