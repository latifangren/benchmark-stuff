#!/bin/sh
#
# benchmark.sh - Benchmark & Stress Test Komprehensif untuk OpenWrt 25.x
# Ditargetkan untuk OpenWrt 25 (APK package manager, kernel 6.12+, modern Busybox/ash)
#
# Fitur Utama:
#   1) Informasi Sistem Lengkap (OS OpenWrt 25, Kernel, CPU, Freq, Thermal, RAM, Storage, Network)
#   2) Live Thermal & Frequency Watcher (Pemantauan Suhu Real-Time)
#   3) CPU Benchmark (Single & Multi-Thread Prime, Floating Point, Hashing OpenSSL)
#   4) Memory Bandwidth Benchmark (dd zero-fill / RAM throughput)
#   5) Disk I/O Benchmark (Sequential Write/Read & Custom File Size 16MB-512MB)
#   6) Network Speed & Latency Benchmark (Ping & HTTP Download Speed Test)
#   7) CPU Stress Test (Single & Multi-Core) dengan Opsi Durasi Kustom (30s, 1m, 5m, 10m, Custom)
#   8) Pengaman Suhu Otomatis (Thermal Protection Guard >82°C)
#   9) Indeks Skor Total & Ekspor Laporan Benchmark ke File (.txt)
#

set -u

# ---------- Konfigurasi Default ----------
CORES=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
[ -z "$CORES" ] || [ "$CORES" -eq 0 ] && CORES=1

PRIME_LIMIT=200000          # Batas perhitungan prima
MEM_MB=128                  # Ukuran data test memory
DISK_MB_DEFAULT=32          # Ukuran file test disk default
DISK_TESTFILE="/tmp/.openwrt25_disktest"
TEMP_MAX_LIMIT=82           # Batas suhu maksimal (°C)

LOG_FILE="/tmp/benchmark_openwrt25_$(date +%Y%m%d_%H%M%S).txt"

# ---------- Warna ANSI ----------
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_CYAN="\033[1;36m"
C_BLUE="\033[1;34m"
C_MAGENTA="\033[1;35m"
C_WHITE="\033[1;37m"

info()  { printf "${C_BOLD}${C_CYAN}[i]${C_RESET} %s\n" "$*"; }
ok()    { printf "${C_BOLD}${C_GREEN}[ok]${C_RESET} %s\n" "$*"; }
warn()  { printf "${C_BOLD}${C_YELLOW}[!]${C_RESET} %s\n" "$*"; }
err()   { printf "${C_BOLD}${C_RED}[x]${C_RESET} %s\n" "$*"; }
title() { printf "\n${C_BOLD}${C_BLUE}== %s ==${C_RESET}\n" "$*"; }

PIDFILE="/tmp/.cpubench_pids25"
STRESS_PIDS=""

cleanup() {
    if [ -n "$STRESS_PIDS" ]; then
        for pid in $STRESS_PIDS; do
            kill -9 "$pid" 2>/dev/null
        done
    fi
    by_pattern=$(ps w 2>/dev/null | grep 'awk.*sqrt(x\*x+1)' | grep -v grep | awk '{print $1}')
    for p in $by_pattern; do
        kill -9 "$p" 2>/dev/null
    done
    rm -f "$DISK_TESTFILE" "$PIDFILE" 2>/dev/null
}
trap cleanup EXIT INT TERM

save_pids() {
    echo "$STRESS_PIDS" > "$PIDFILE"
}

clear_pidfile() {
    rm -f "$PIDFILE"
    STRESS_PIDS=""
}

check_stale_processes() {
    if [ -f "$PIDFILE" ]; then
        pids=$(cat "$PIDFILE" 2>/dev/null)
        stale=""
        for p in $pids; do
            if kill -0 "$p" 2>/dev/null; then
                stale="$stale $p"
            fi
        done
        if [ -n "$stale" ]; then
            warn "Ditemukan sisa proses stress test lama (PID:$stale)"
            printf "${C_BOLD}${C_YELLOW}Matikan proses lama tersebut? [Y/n]: ${C_RESET}"
            read -r ans
            if [ -z "$ans" ] || [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
                for p in $stale; do kill -9 "$p" 2>/dev/null; done
                ok "Proses lama telah dimatikan."
            fi
            clear_pidfile
            sleep 1
        fi
    fi
}

press_enter() {
    printf "\n${C_BOLD}${C_WHITE}Tekan Enter untuk kembali ke menu...${C_RESET}"
    read -r _
    echo
}

elapsed() {
    awk -v s="$1" -v e="$2" 'BEGIN{printf "%.2f", (e-s)}'
}

get_epoch_sec() {
    if date +%s.%N 2>/dev/null | grep -q '\.'; then
        date +%s.%N
    else
        date +%s
    fi
}

get_highest_temp() {
    max_t=0
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        [ -f "$zone" ] || continue
        raw=$(cat "$zone" 2>/dev/null)
        [ -z "$raw" ] && continue
        if [ "$raw" -gt 1000 ] 2>/dev/null; then
            c=$((raw / 1000))
        else
            c=$raw
        fi
        if [ "$c" -gt "$max_t" ]; then
            max_t=$c
        fi
    done
    echo "$max_t"
}

print_thermal_info() {
    found=0
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        [ -f "$zone" ] || continue
        found=1
        zdir=$(dirname "$zone")
        name=$(cat "$zdir/type" 2>/dev/null || echo "zone")
        raw=$(cat "$zone" 2>/dev/null)
        [ -z "$raw" ] && continue
        awk -v r="$raw" -v n="$name" -v c_green="$C_GREEN" -v c_yellow="$C_YELLOW" -v c_red="$C_RED" -v c_reset="$C_RESET" 'BEGIN{
            c = (r > 1000) ? r/1000 : r;
            col = (c >= 75) ? c_red : ((c >= 60) ? c_yellow : c_green);
            printf "    %-22s : %s%.1f°C%s\n", n, col, c, c_reset;
        }'
    done
    [ "$found" -eq 0 ] && warn "Sensor suhu tidak terdeteksi di /sys/class/thermal/"
}

print_cpu_freq() {
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [ -f "$f" ] || continue
        cpu_name=$(basename "$(dirname "$(dirname "$f")")")
        khz=$(cat "$f" 2>/dev/null)
        [ -n "$khz" ] && awk -v n="$cpu_name" -v k="$khz" -v c_cyan="$C_CYAN" -v c_reset="$C_RESET" 'BEGIN{printf "    %-22s : %s%.2f MHz%s\n", n, c_cyan, k/1000, c_reset}'
    done
}

print_cpu_freq_inline() {
    str=""
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [ -f "$f" ] || continue
        cpu_name=$(basename "$(dirname "$(dirname "$f")")")
        khz=$(cat "$f" 2>/dev/null)
        if [ -n "$khz" ]; then
            mhz=$(awk -v k="$khz" 'BEGIN{printf "%.0fMHz", k/1000}')
            str="$str ${C_CYAN}$cpu_name:${C_BOLD}$mhz${C_RESET}"
        fi
    done
    printf "Freq:%s" "$str"
}

feature_live_watcher() {
    title "Live Thermal & CPU Frequency Watcher"
    info "Menampilkan suhu & frekuensi CPU secara real-time (Tekan Ctrl+C untuk kembali)"
    echo
    while true; do
        curr_temp=$(get_highest_temp)
        if [ "$curr_temp" -ge 75 ]; then
            t_col="${C_RED}${curr_temp}°C${C_RESET}"
        elif [ "$curr_temp" -ge 60 ]; then
            t_col="${C_YELLOW}${curr_temp}°C${C_RESET}"
        else
            t_col="${C_GREEN}${curr_temp}°C${C_RESET}"
        fi
        printf "\r  [Live Monitor] Suhu Maks: %b | " "$t_col"
        print_cpu_freq_inline
        sleep 2
    done
}

feature_sysinfo() {
    title "Informasi Sistem & Hardware Device (OpenWrt 25)"
    
    os_name="OpenWrt 25.x"
    if [ -f /etc/openwrt_release ]; then
        . /etc/openwrt_release 2>/dev/null
        [ -n "${DISTRIB_DESCRIPTION:-}" ] && os_name="$DISTRIB_DESCRIPTION"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release 2>/dev/null
        [ -n "${PRETTY_NAME:-}" ] && os_name="$PRETTY_NAME"
    fi
    
    model="Unknown Device"
    if [ -f /tmp/sysinfo/model ]; then
        model=$(cat /tmp/sysinfo/model)
    elif [ -f /proc/device-tree/model ]; then
        model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)
    fi

    arch=$(uname -m 2>/dev/null || echo "unknown")
    kernel=$(uname -r 2>/dev/null || echo "unknown")
    hostname=$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || echo "OpenWrt25")

    pkg_mgr="Unknown"
    if command -v apk >/dev/null 2>&1; then
        pkg_mgr="APK (Alpine Package Keeper / OpenWrt 25+)"
    elif command -v opkg >/dev/null 2>&1; then
        pkg_mgr="OPKG (Legacy)"
    fi

    echo "  • Hostname       : ${C_BOLD}${C_YELLOW}${hostname}${C_RESET}"
    echo "  • Model Device   : ${C_BOLD}${C_GREEN}${model}${C_RESET}"
    echo "  • Arsitektur     : ${C_CYAN}${arch}${C_RESET}"
    echo "  • Versi OS       : ${C_GREEN}${os_name}${C_RESET}"
    echo "  • Versi Kernel   : ${C_CYAN}${kernel}${C_RESET}"
    echo "  • Package Manager: ${C_MAGENTA}${pkg_mgr}${C_RESET}"
    echo "  • Jumlah CPU Core: ${C_BOLD}${C_GREEN}${CORES} core${C_RESET}"

    cpu_m=$(grep -m1 -E 'model name|Hardware|Processor' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //')
    [ -n "$cpu_m" ] && echo "  • Detail CPU     : ${C_WHITE}${cpu_m}${C_RESET}"

    if [ -f /proc/meminfo ]; then
        total_ram=$(awk '/MemTotal:/ {printf "%.1f MB", $2/1024}' /proc/meminfo)
        free_ram=$(awk '/MemAvailable:/ {printf "%.1f MB", $2/1024}' /proc/meminfo 2>/dev/null || awk '/MemFree:/ {printf "%.1f MB", $2/1024}' /proc/meminfo)
        echo "  • Memori (RAM)   : Total ${C_BOLD}${C_CYAN}${total_ram}${C_RESET} | Bebas: ${C_GREEN}${free_ram}${C_RESET}"
    fi

    root_df=$(df -h / 2>/dev/null | awk 'NR==2{print "Total: "$2", Terpakai: "$3" ("$5"), Bebas: "$4}')
    [ -n "$root_df" ] && echo "  • Storage Root (/) : ${C_WHITE}${root_df}${C_RESET}"

    echo
    info "Frekuensi CPU Saat Ini:"
    print_cpu_freq

    echo
    info "Suhu Thermal Sensor:"
    print_thermal_info
}

run_prime_single() {
    limit=$1
    s=$(get_epoch_sec)
    count=$(awk -v limit="$limit" 'BEGIN{
        c=0
        for (i=2; i<=limit; i++) {
            isprime=1
            for (j=2; j*j<=i; j++) { if (i%j==0){isprime=0; break} }
            if (isprime) c++
        }
        print c
    }')
    e=$(get_epoch_sec)
    t=$(elapsed "$s" "$e")
    echo "$count|$t"
}

feature_cpu_bench() {
    title "CPU Benchmark (Single & Multi-Thread Prime)"
    info "1. Testing Single-Thread Prime Test (Batas: $PRIME_LIMIT)..."
    res=$(run_prime_single "$PRIME_LIMIT")
    count=${res%%|*}
    t=${res##*|}
    score=$(awk -v c="$count" -v t="$t" 'BEGIN{ if(t>0) printf "%.0f", c/t; else print 0 }')
    ok "Single-Thread: ${C_GREEN}${count}${C_RESET} bilangan prima ditemukan dalam ${C_CYAN}${t}s${C_RESET} (Skor: ${C_BOLD}${C_GREEN}${score}${C_RESET} ops/s)"

    score_multi=0
    if [ "$CORES" -gt 1 ]; then
        echo
        info "2. Testing Multi-Thread Prime Test ($CORES Core Paralel)..."
        s=$(get_epoch_sec)
        pids=""
        for i in $(seq 1 "$CORES"); do
            awk -v limit="$PRIME_LIMIT" 'BEGIN{
                c=0
                for (k=2; k<=limit; k++) {
                    isprime=1
                    for (j=2; j*j<=k; j++) { if (k%j==0){isprime=0; break} }
                    if (isprime) c++
                }
            }' >/dev/null 2>&1 &
            pids="$pids $!"
        done
        for p in $pids; do
            wait "$p" 2>/dev/null
        done
        e=$(get_epoch_sec)
        t_multi=$(elapsed "$s" "$e")
        score_multi=$(awk -v c="$count" -v cores="$CORES" -v t="$t_multi" 'BEGIN{ if(t>0) printf "%.0f", (c*cores)/t; else print 0 }')
        ok "Multi-Thread ($CORES core): Selesai dalam ${C_CYAN}${t_multi}s${C_RESET} (Skor Total: ${C_BOLD}${C_GREEN}${score_multi}${C_RESET} ops/s)"
    fi

    echo
    if command -v openssl >/dev/null 2>&1; then
        info "3. Testing Kriptografi Hashing (openssl speed sha256 - 3 detik)..."
        line=$(openssl speed -seconds 3 sha256 2>/dev/null | grep -E '^sha256' | tail -1)
        [ -n "$line" ] && echo "    ${C_CYAN}$line${C_RESET}" || warn "openssl speed tidak menghasilkan output"
    else
        warn "openssl tidak terinstall (Gunakan 'apk add openssl-util' jika butuh test hash)"
    fi

    echo
    info "4. Testing Perhitungan Floating Point (Math AWK Test)..."
    s=$(get_epoch_sec)
    awk 'BEGIN{
        x=1.00001
        for(i=1;i<=2000000;i++){
            x=x*1.0000001 + sin(i)/1000
        }
    }' >/dev/null
    e=$(get_epoch_sec)
    t_fp=$(elapsed "$s" "$e")
    ok "Floating Point Math: 2,000,000 iterasi selesai dalam ${C_CYAN}${t_fp}s${C_RESET}"

    LAST_CPU_SCORE=$score
    LAST_MULTI_SCORE=$score_multi
}

feature_mem_bench() {
    title "Memory Bandwidth Benchmark (~${MEM_MB}MB)"
    info "Menjalankan dd transfer dari /dev/zero ke /dev/null..."
    s=$(get_epoch_sec)
    dd if=/dev/zero of=/dev/null bs=1M count="$MEM_MB" 2>/dev/null
    e=$(get_epoch_sec)
    t=$(elapsed "$s" "$e")
    mbs=$(awk -v m="$MEM_MB" -v t="$t" 'BEGIN{ if(t>0) printf "%.1f", m/t; else print 0 }')
    ok "RAM Bandwidth: ${C_BOLD}${C_GREEN}${mbs} MB/s${C_RESET} (${MEM_MB}MB dalam ${C_CYAN}${t}s${C_RESET})"
    LAST_MEM_SCORE=$mbs
}

ask_disk_size() {
    echo
    info "Pilih Ukuran File Test Disk Storage:"
    echo "  ${C_CYAN}1)${C_RESET} 16 MB  (Aman untuk storage flash/STB kecil)"
    echo "  ${C_CYAN}2)${C_RESET} 32 MB  (Standard OpenWrt)"
    echo "  ${C_CYAN}3)${C_RESET} 64 MB"
    echo "  ${C_CYAN}4)${C_RESET} 128 MB"
    echo "  ${C_CYAN}5)${C_RESET} 256 MB (Disarankan untuk USB/MicroSD)"
    echo "  ${C_CYAN}6)${C_RESET} 512 MB"
    printf "${C_BOLD}${C_YELLOW}Pilihan ukuran [1-6, default 2]: ${C_RESET}"
    read -r sz_choice
    case "$sz_choice" in
        1) SELECTED_DISK_MB=16 ;;
        2) SELECTED_DISK_MB=32 ;;
        3) SELECTED_DISK_MB=64 ;;
        4) SELECTED_DISK_MB=128 ;;
        5) SELECTED_DISK_MB=256 ;;
        6) SELECTED_DISK_MB=512 ;;
        *) SELECTED_DISK_MB=32 ;;
    esac
}

feature_disk_bench() {
    disk_mb=${1:-}
    if [ -z "$disk_mb" ]; then
        ask_disk_size
        disk_mb=$SELECTED_DISK_MB
    fi

    title "Disk I/O Benchmark (${disk_mb}MB di /tmp)"
    
    target_dir=$(dirname "$DISK_TESTFILE")
    free_kb=$(df -k "$target_dir" 2>/dev/null | awk 'NR==2{print $4}')
    req_kb=$((disk_mb * 1024 + 10240))
    if [ -n "$free_kb" ] && [ "$free_kb" -lt "$req_kb" ]; then
        err "Sisa ruang storage tidak cukup di $target_dir. Batalkan test."
        return
    fi
    warn "Perhatian: Test ini melakukan write ke storage tmpfs/flash."

    info "Menulis file test (Write speed)..."
    s=$(get_epoch_sec)
    dd if=/dev/zero of="$DISK_TESTFILE" bs=1M count="$disk_mb" conv=fsync 2>/dev/null || dd if=/dev/zero of="$DISK_TESTFILE" bs=1M count="$disk_mb" 2>/dev/null
    sync
    e=$(get_epoch_sec)
    t=$(elapsed "$s" "$e")
    write_mbs=$(awk -v m="$disk_mb" -v t="$t" 'BEGIN{ if(t>0) printf "%.1f", m/t; else print 0 }')
    ok "Kecepatan Write: ${C_BOLD}${C_GREEN}${write_mbs} MB/s${C_RESET} (${disk_mb}MB dalam ${C_CYAN}${t}s${C_RESET})"

    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

    info "Membaca file test (Read speed)..."
    s=$(get_epoch_sec)
    dd if="$DISK_TESTFILE" of=/dev/null bs=1M 2>/dev/null
    e=$(get_epoch_sec)
    t=$(elapsed "$s" "$e")
    read_mbs=$(awk -v m="$disk_mb" -v t="$t" 'BEGIN{ if(t>0) printf "%.1f", m/t; else print 0 }')
    ok "Kecepatan Read : ${C_BOLD}${C_GREEN}${read_mbs} MB/s${C_RESET} (${disk_mb}MB dalam ${C_CYAN}${t}s${C_RESET})"

    rm -f "$DISK_TESTFILE"
    LAST_DISK_WRITE=$write_mbs
    LAST_DISK_READ=$read_mbs
}

feature_network_bench() {
    title "Network Latency & Download Speed Test"
    
    info "1. Testing Latency Ping ke Public DNS..."
    for target in "1.1.1.1" "8.8.8.8"; do
        if command -v ping >/dev/null 2>&1; then
            res=$(ping -c 3 "$target" 2>/dev/null | grep -E 'round-trip|rtt' | cut -d'=' -f2 | cut -d'/' -f2)
            if [ -n "$res" ]; then
                ok "Ping ke $target: avg ${C_BOLD}${C_GREEN}${res} ms${C_RESET}"
            else
                warn "Ping ke $target gagal atau RTT tidak terurai"
            fi
        fi
    done

    echo
    info "2. Testing Speed Download HTTP (File Test 10MB dari CDN)..."
    url="http://speedtest.tele2.net/10MB.zip"
    if command -v wget >/dev/null 2>&1; then
        s=$(get_epoch_sec)
        wget -q --timeout=10 -O /dev/null "$url"
        rc=$?
        e=$(get_epoch_sec)
        t=$(elapsed "$s" "$e")
        if [ $rc -eq 0 ] && awk -v t="$t" 'BEGIN{exit !(t>0)}'; then
            speed_mbps=$(awk -v t="$t" 'BEGIN{printf "%.2f", (10 * 8)/t}')
            ok "Download 10MB Selesai dalam ${C_CYAN}${t}s${C_RESET} (~${C_BOLD}${C_GREEN}${speed_mbps} Mbps${C_RESET})"
        else
            warn "Download via wget gagal atau timeout."
        fi
    elif command -v curl >/dev/null 2>&1; then
        s=$(get_epoch_sec)
        curl -s -m 10 -o /dev/null "$url"
        rc=$?
        e=$(get_epoch_sec)
        t=$(elapsed "$s" "$e")
        if [ $rc -eq 0 ] && awk -v t="$t" 'BEGIN{exit !(t>0)}'; then
            speed_mbps=$(awk -v t="$t" 'BEGIN{printf "%.2f", (10 * 8)/t}')
            ok "Download 10MB Selesai dalam ${C_CYAN}${t}s${C_RESET} (~${C_BOLD}${C_GREEN}${speed_mbps} Mbps${C_RESET})"
        else
            warn "Download via curl gagal atau timeout."
        fi
    else
        warn "Tool curl/wget tidak tersedia di router ini."
    fi
}

ask_stress_duration() {
    echo
    info "Pilih Durasi Stress Test CPU:"
    echo "  ${C_CYAN}1)${C_RESET} 30 Detik (Tes Cepat)"
    echo "  ${C_CYAN}2)${C_RESET} 1 Menit"
    echo "  ${C_CYAN}3)${C_RESET} 5 Menit (Tes Stabilitas Standard)"
    echo "  ${C_CYAN}4)${C_RESET} 10 Menit (Tes Ketahanan Thermal)"
    echo "  ${C_CYAN}5)${C_RESET} Input Durasi Kustom (dalam detik)"
    printf "${C_BOLD}${C_YELLOW}Pilihan durasi [1-5, default 1]: ${C_RESET}"
    read -r dur_choice
    case "$dur_choice" in
        2) SELECTED_DUR=60 ;;
        3) SELECTED_DUR=300 ;;
        4) SELECTED_DUR=600 ;;
        5)
            printf "${C_BOLD}${C_YELLOW}Masukkan durasi dalam detik (misal 120 untuk 2 menit): ${C_RESET}"
            read -r cust_sec
            cust_sec=$(echo "$cust_sec" | tr -cd '0-9')
            [ -z "$cust_sec" ] || [ "$cust_sec" -lt 5 ] && cust_sec=30
            SELECTED_DUR="$cust_sec"
            ;;
        *) SELECTED_DUR=30 ;;
    esac
}

busy_loop() {
    exec awk 'BEGIN{ x=1.23456; while(1){ for(i=0;i<100000;i++){ x=sqrt(x*x+1) } } }'
}

stress_monitor() {
    duration=$1
    step=2
    elapsed=0
    aborted=0

    while [ "$elapsed" -lt "$duration" ]; do
        sleep "$step"
        elapsed=$((elapsed + step))

        curr_temp=$(get_highest_temp)
        if [ "$curr_temp" -gt 0 ]; then
            if [ "$curr_temp" -ge 75 ]; then
                t_col="${C_BOLD}${C_RED}${curr_temp}°C${C_RESET}"
            elif [ "$curr_temp" -ge 60 ]; then
                t_col="${C_BOLD}${C_YELLOW}${curr_temp}°C${C_RESET}"
            else
                t_col="${C_BOLD}${C_GREEN}${curr_temp}°C${C_RESET}"
            fi
            printf "  [t=%3ds/%3ds] Suhu CPU: %b | " "$elapsed" "$duration" "$t_col"
            print_cpu_freq_inline
            printf "\n"
            if [ "$curr_temp" -ge "$TEMP_MAX_LIMIT" ]; then
                echo
                err "ALARM: Suhu CPU telah mencapai ${curr_temp}°C (Batas Aman: ${TEMP_MAX_LIMIT}°C)!"
                warn "Menghentikan stress test secara otomatis untuk mencegah overheating!"
                aborted=1
                break
            fi
        else
            printf "  [t=%3ds/%3ds] Stress test berjalan...\n" "$elapsed" "$duration"
        fi
    done
    return $aborted
}

feature_stress_single() {
    ask_stress_duration
    dur=$SELECTED_DUR
    title "Stress Test CPU - Single Core (${dur}s)"
    warn "Pengaman Suhu Aktif: Test akan otomatis mati jika suhu >= ${TEMP_MAX_LIMIT}°C"
    info "Menjalankan 1 proses busy-loop..."

    busy_loop &
    STRESS_PIDS="$!"
    save_pids

    stress_monitor "$dur"
    res=$?

    for pid in $STRESS_PIDS; do kill -9 "$pid" 2>/dev/null; done
    by_pattern=$(ps w 2>/dev/null | grep 'awk.*sqrt(x\*x+1)' | grep -v grep | awk '{print $1}')
    for p in $by_pattern; do kill -9 "$p" 2>/dev/null; done
    clear_pidfile

    if [ $res -eq 0 ]; then
        ok "Stress test single-core selesai dengan aman."
    else
        warn "Stress test dihentikan oleh Thermal Guard."
    fi
}

feature_stress_multi() {
    ask_stress_duration
    dur=$SELECTED_DUR
    title "Stress Test CPU - Multi Core ($CORES Core, ${dur}s)"
    warn "Pengaman Suhu Aktif: Test akan otomatis mati jika suhu >= ${TEMP_MAX_LIMIT}°C"
    info "Menjalankan $CORES proses busy-loop paralel..."

    STRESS_PIDS=""
    for i in $(seq 1 "$CORES"); do
        busy_loop &
        STRESS_PIDS="$STRESS_PIDS $!"
    done
    save_pids

    stress_monitor "$dur"
    res=$?

    for pid in $STRESS_PIDS; do kill -9 "$pid" 2>/dev/null; done
    by_pattern=$(ps w 2>/dev/null | grep 'awk.*sqrt(x\*x+1)' | grep -v grep | awk '{print $1}')
    for p in $by_pattern; do kill -9 "$p" 2>/dev/null; done
    clear_pidfile

    if [ $res -eq 0 ]; then
        ok "Stress test multi-core selesai dengan aman."
    else
        warn "Stress test dihentikan oleh Thermal Guard."
    fi
}

feature_full() {
    feature_sysinfo
    feature_cpu_bench
    feature_mem_bench
    feature_disk_bench "$DISK_MB_DEFAULT"
    feature_network_bench

    title "Ringkasan & Indeks Performa Sistem"
    echo "  • Skor CPU Single-Thread : ${C_BOLD}${C_GREEN}${LAST_CPU_SCORE:-0}${C_RESET} ops/s"
    echo "  • Skor CPU Multi-Thread  : ${C_BOLD}${C_GREEN}${LAST_MULTI_SCORE:-0}${C_RESET} ops/s"
    echo "  • Throughput Memory RAM  : ${C_BOLD}${C_GREEN}${LAST_MEM_SCORE:-0}${C_RESET} MB/s"
    echo "  • Storage Write Speed    : ${C_BOLD}${C_GREEN}${LAST_DISK_WRITE:-0}${C_RESET} MB/s"
    echo "  • Storage Read Speed     : ${C_BOLD}${C_GREEN}${LAST_DISK_READ:-0}${C_RESET} MB/s"
}

export_report() {
    info "Menyimpan laporan lengkap ke: $LOG_FILE"
    {
        echo "=========================================================="
        echo " LAPORAN BENCHMARK OPENWRT 25"
        echo " Tanggal : $(date)"
        echo "=========================================================="
        feature_full
    } > "$LOG_FILE" 2>&1
    ok "Laporan berhasil disimpan ke $LOG_FILE"
}

banner() {
    clear
    printf "${C_BOLD}${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_BOLD}${C_MAGENTA}    OpenWrt 25 Benchmark & Hardware Stress Tool         ${C_RESET}\n"
    printf "${C_BOLD}${C_CYAN}    Host: ${C_YELLOW}$(hostname 2>/dev/null || echo OpenWrt25)${C_CYAN} (${C_GREEN}${CORES} Core CPU${C_CYAN})${C_RESET}\n"
    printf "${C_BOLD}${C_CYAN}========================================================${C_RESET}\n"
    printf " ${C_GREEN} 1)${C_RESET} ${C_BOLD}Full Benchmark${C_RESET} (SysInfo, CPU, RAM, Storage, Net & Score)\n"
    printf " ${C_CYAN} 2)${C_RESET} Informasi Sistem & Suhu Thermal\n"
    printf " ${C_CYAN} 3)${C_RESET} Live Thermal & Frequency Watcher (Real-Time)\n"
    printf " ${C_BLUE} 4)${C_RESET} CPU Benchmark (Prime, Hash, Floating Point)\n"
    printf " ${C_BLUE} 5)${C_RESET} Memory (RAM) Bandwidth Benchmark\n"
    printf " ${C_BLUE} 6)${C_RESET} Disk Storage I/O Benchmark (Ukuran file kustom)\n"
    printf " ${C_BLUE} 7)${C_RESET} Network Latency & Download Speed Test\n"
    printf " ${C_YELLOW} 8)${C_RESET} Stress Test CPU - Single Core (Durasi kustom)\n"
    printf " ${C_RED} 9)${C_RESET} Stress Test CPU - Multi Core (Durasi kustom)\n"
    printf " ${C_MAGENTA}10)${C_RESET} Ekspor Laporan Benchmark ke File Text\n"
    printf " ${C_RED} 0)${C_RESET} Keluar\n"
    printf "${C_BOLD}${C_CYAN}--------------------------------------------------------${C_RESET}\n"
}

main() {
    check_stale_processes

    if [ "${1:-}" = "--full" ]; then
        feature_full
        exit 0
    elif [ "${1:-}" = "--sysinfo" ]; then
        feature_sysinfo
        exit 0
    elif [ "${1:-}" = "--export" ]; then
        export_report
        exit 0
    fi

    while true; do
        banner
        printf "${C_BOLD}${C_YELLOW}Pilih menu [0-10]: ${C_RESET}"
        read -r choice
        case "$choice" in
            1) feature_full; press_enter ;;
            2) feature_sysinfo; press_enter ;;
            3) feature_live_watcher; press_enter ;;
            4) feature_cpu_bench; press_enter ;;
            5) feature_mem_bench; press_enter ;;
            6) feature_disk_bench; press_enter ;;
            7) feature_network_bench; press_enter ;;
            8) feature_stress_single; press_enter ;;
            9) feature_stress_multi; press_enter ;;
            10) export_report; press_enter ;;
            0) echo "Terima kasih. Sampai jumpa!"; exit 0 ;;
            *) warn "Pilihan tidak valid"; sleep 1 ;;
        esac
    done
}

main "$@"
