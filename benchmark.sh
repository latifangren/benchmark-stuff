#!/bin/sh
#
# benchmark.sh - Script Auto-Detect OS & Device Launcher
# Otomatis mendeteksi sistem operasi (OpenWrt 24/25, Termux, Ubuntu, postmarketOS, Arch)
# lalu mengarahkan ke script benchmark yang paling sesuai.
#

set -u

# ---------- Warna ANSI ----------
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_CYAN="\033[1;36m"
C_BLUE="\033[1;34m"

info()  { printf "${C_CYAN}[i]${C_RESET} %b\n" "$*"; }
ok()    { printf "${C_GREEN}[ok]${C_RESET} %b\n" "$*"; }
warn()  { printf "${C_YELLOW}[!]${C_RESET} %b\n" "$*"; }

BASE_URL="https://raw.githubusercontent.com/latifangren/benchmark-stuff/main"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")"

# ---------- Deteksi OS / Lingkungan ----------
detect_target() {
    # 1. Android Termux
    if [ -n "${PREFIX:-}" ] && echo "$PREFIX" | grep -q "com.termux"; then
        echo "android/termux"
        return
    fi
    if command -v getprop >/dev/null 2>&1 && [ -d "/data/data/com.termux" ]; then
        echo "android/termux"
        return
    fi

    # 2. OpenWrt
    if [ -f /etc/openwrt_release ] || [ -f /etc/openwrt_version ]; then
        rel=""
        if [ -f /etc/openwrt_release ]; then
            . /etc/openwrt_release 2>/dev/null
            rel="${DISTRIB_RELEASE:-}"
        fi
        
        if echo "$rel" | grep -q "^25" || command -v apk >/dev/null 2>&1; then
            echo "openwrt/25"
        else
            echo "openwrt/24"
        fi
        return
    fi

    # Check via /etc/os-release
    if [ -f /etc/os-release ]; then
        os_id=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        os_like=$(grep -E '^ID_LIKE=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')

        # 3. postmarketOS / Alpine Linux
        if [ "$os_id" = "postmarketos" ] || [ "$os_id" = "alpine" ] || echo "$os_like" | grep -q "alpine"; then
            echo "linux/postmarket-os"
            return
        fi

        # 4. Ubuntu / Debian
        if [ "$os_id" = "ubuntu" ] || [ "$os_id" = "debian" ] || echo "$os_like" | grep -q -E "ubuntu|debian"; then
            echo "linux/ubuntu"
            return
        fi

        # 5. Arch Linux / Manjaro / EndeavourOS
        if [ "$os_id" = "arch" ] || [ "$os_id" = "manjaro" ] || [ "$os_id" = "endeavouros" ] || echo "$os_like" | grep -q "arch"; then
            echo "linux/arch"
            return
        fi
    fi

    # Fallback berdasarkan Package Manager
    if command -v opkg >/dev/null 2>&1; then
        echo "openwrt/24"
    elif command -v apk >/dev/null 2>&1; then
        echo "linux/postmarket-os"
    elif command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1; then
        echo "linux/ubuntu"
    elif command -v pacman >/dev/null 2>&1; then
        echo "linux/arch"
    else
        # Default fallback
        echo "openwrt/24"
    fi
}

main() {
    printf "${C_BOLD}${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_BOLD}${C_CYAN}    Auto-Detect OS & Device Benchmark Launcher          ${C_RESET}\n"
    printf "${C_BOLD}${C_CYAN}========================================================${C_RESET}\n"

    target_path=$(detect_target)
    info "Sistem terdeteksi : ${C_BOLD}${C_GREEN}${target_path}${C_RESET}"

    sh_cmd="sh"
    command -v bash >/dev/null 2>&1 && sh_cmd="bash"

    # Cek apakah file lokal ada (Mode Clone)
    local_script="${SCRIPT_DIR}/${target_path}/benchmark.sh"
    if [ -n "$SCRIPT_DIR" ] && [ -f "$local_script" ]; then
        ok "Menjalankan script lokal: ${local_script}"
        chmod +x "$local_script" 2>/dev/null || true
        exec "$sh_cmd" "$local_script" "$@"
    else
        # Mode Remote (curl / wget online execution dengan Cache Buster)
        cache_buster=$(date +%s 2>/dev/null || echo "1")
        remote_url="${BASE_URL}/${target_path}/benchmark.sh?v=${cache_buster}"
        tmp_target="/tmp/bench_auto_target.sh"
        [ -d "/tmp" ] || tmp_target="${PREFIX:-/tmp}/bench_auto_target.sh"

        info "Mengunduh script benchmark untuk ${target_path}..."
        if command -v wget >/dev/null 2>&1; then
            wget -q -O "$tmp_target" "$remote_url"
        elif command -v curl >/dev/null 2>&1; then
            curl -sSL "$remote_url" -o "$tmp_target"
        else
            warn "Wget atau Curl tidak ditemukan. Tidak dapat mengunduh script."
            exit 1
        fi

        if [ -s "$tmp_target" ]; then
            chmod +x "$tmp_target" 2>/dev/null || true
            ok "Berhasil diunduh. Memulai benchmark..."
            exec "$sh_cmd" "$tmp_target" "$@"
        else
            warn "Gagal mengunduh script dari $remote_url"
            exit 1
        fi
    fi
}

main "$@"
