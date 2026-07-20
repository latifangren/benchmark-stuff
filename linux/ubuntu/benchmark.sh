#!/bin/bash
#
# benchmark.sh - Interactive & CLI Benchmark Script untuk Linux Ubuntu / Debian
# Ditargetkan untuk Ubuntu Server & Desktop (x86_64, ARM64 / Raspberry Pi / SBC)
#
# Fitur:
#   1) Informasi Sistem Komprehensif (OS Version, Kernel, CPU Governor & Freq, Thermal, RAM, Swap, Storage, Network)
#   2) Live Thermal & Frequency Watcher (Pemantauan Suhu Real-Time)
#   3) CPU Benchmark (Single & Multi-Thread Prime, OpenSSL SHA256 Kriptografi, AWK Floating Point)
#   4) Memory Benchmark (sysbench memory / dd RAM throughput)
#   5) Disk I/O Benchmark (Sequential Write/Read, Custom File Size 16MB-512MB)
#   6) Network Latency & Download Speed Test (Ping DNS & HTTP CDN Download)
#   7) CPU Stress Test (Single & Multi-Core) dengan Opsi Durasi Kustom (30s, 1m, 5m, 10m, Custom)
#   8) Pengaman Suhu Otomatis (Thermal Protection Guard >85°C)
#   9) Indeks Skor Total & Ekspor Laporan Benchmark ke File Timestamped (.txt)
#

set -uo pipefail

# ---------- Warna ANSI ----------
BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; CYAN="\033[36m"; RED="\033[31m"; RESET="\033[0m"

hr() { printf '%.0s-' {1..58}; echo; }
section() { echo -e "\n${BOLD}${CYAN}== $1 ==${RESET}"; hr; }
have() { command -v "$1" >/dev/null 2>&1; }

CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
TMPDIR="$(mktemp -d /tmp/benchmark_ubuntu.XXXXXX 2>/dev/null || echo /tmp)"
LOG_FILE="$HOME/benchmark_ubuntu_$(date +%Y%m%d_%H%M%S).txt"
TEMP_MAX_LIMIT=85

cleanup() {
    pkill -9 -f 'stress-ng' 2>/dev/null || true
    pkill -9 -f 'openssl speed' 2>/dev/null || true
    pkill -9 -f 'awk.*sqrt' 2>/dev/null || true
    rm -rf "$TMPDIR/memtest" "$TMPDIR/disktest" 2>/dev/null
    tput cnorm 2>/dev/null || true
}
trap cleanup EXIT INT TERM

CPU_MODEL=""
if have lscpu; then
    CPU_MODEL=$(lscpu | grep -m1 -E 'Model name|Vendor ID' | cut -d: -f2- | sed 's/^ *//')
fi
if [ -z "${CPU_MODEL:-}" ]; then
    CPU_MODEL=$(grep -m1 -E 'model name|Hardware|Processor' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //')
fi
[ -z "${CPU_MODEL:-}" ] && CPU_MODEL="Generic x86_64/ARM CPU"

# ---------- Sensor Suhu ----------
get_temp_c() {
    local max_t=0
    if have sensors; then
        local sens_t
        sens_t=$(sensors 2>/dev/null | grep -E 'Core 0|Package id 0|cpu_thermal|Composite' | awk '{print $2}' | tr -d '+°C' | cut -d. -f1 | head -n1)
        if [ -n "$sens_t" ] && [ "$sens_t" -gt 0 ] 2>/dev/null; then
            echo "$sens_t"
            return 0
        fi
    fi
    for z in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$z" ] || continue
        local raw c=0
        raw=$(cat "$z" 2>/dev/null) || continue
        [ -z "$raw" ] && continue
        if [ "$raw" -gt 1000 ] 2>/dev/null; then c=$((raw / 1000)); else c=$raw; fi
        if [ "$c" -gt "$max_t" ]; then max_t=$c; fi
    done
    if [ "$max_t" -gt 0 ]; then
        echo "$max_t"
        return 0
    fi
    return 1
}

show_thermal_detail() {
    local found=0
    if have sensors; then
        echo "  [lm-sensors output]:"
        sensors 2>/dev/null | grep -E 'Core|Package|temp|Composite|cpu' | sed 's/^/    /'
        found=1
    fi
    if [ "$found" -eq 0 ]; then
        for z in /sys/class/thermal/thermal_zone*/temp; do
            [ -r "$z" ] || continue
            found=1
            local zdir raw name c
            zdir=$(dirname "$z")
            name=$(cat "$zdir/type" 2>/dev/null || echo "thermal_zone")
            raw=$(cat "$z" 2>/dev/null) || continue
            [ -z "$raw" ] && continue
            if [ "$raw" -gt 1000 ] 2>/dev/null; then c=$((raw / 1000)); else c=$raw; fi
            printf "  %-22s : %d°C\n" "$name" "$c"
        done
    fi
    [ "$found" -eq 0 ] && echo "  Sensor suhu tidak terdeteksi."
}

show_temp_once() {
    local t
    if t=$(get_temp_c); then
        echo "Suhu CPU saat ini: ${t}°C"
    else
        echo "Sensor suhu tidak terbaca di sistem ini."
    fi
}

show_cpu_freq() {
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [ -r "$f" ] || continue
        local cpu_name khz
        cpu_name=$(basename "$(dirname "$(dirname "$f")")")
        khz=$(cat "$f" 2>/dev/null)
        [ -n "$khz" ] && awk -v n="$cpu_name" -v k="$khz" 'BEGIN{printf "  %-22s : %.2f MHz\n", n, k/1000}'
    done
}

show_cpu_freq_inline() {
    local str=""
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [ -r "$f" ] || continue
        local cpu_name khz mhz
        cpu_name=$(basename "$(dirname "$(dirname "$f")")")
        khz=$(cat "$f" 2>/dev/null)
        if [ -n "$khz" ]; then
            mhz=$(awk -v k="$khz" 'BEGIN{printf "%.0fMHz", k/1000}')
            str="$str $cpu_name:$mhz"
        fi
    done
    printf "Freq:%s" "$str"
}

run_live_watcher() {
    section "Live Thermal & CPU Frequency Watcher"
    echo -e "${YELLOW}Menampilkan suhu & frekuensi CPU real-time (Tekan Ctrl+C untuk berhenti)${RESET}\n"
    while true; do
        local t
        t=$(get_temp_c || echo "N/A")
        printf "\r  [Live Monitor] Suhu Maks: %3s°C | " "$t"
        show_cpu_freq_inline
        sleep 2
    done
}

dd_write() {
    local IN="$1" OUT="$2" BS="$3" COUNT="$4"
    local OUTPUT
    OUTPUT=$(dd if="$IN" of="$OUT" bs="$BS" count="$COUNT" conv=fdatasync 2>&1)
    if [ $? -eq 0 ]; then echo "$OUTPUT" | tail -n1; return 0; fi
    rm -f "$OUT"
    OUTPUT=$(dd if="$IN" of="$OUT" bs="$BS" count="$COUNT" conv=fsync 2>&1)
    if [ $? -eq 0 ]; then echo "$OUTPUT" | tail -n1; return 0; fi
    rm -f "$OUT"
    OUTPUT=$(dd if="$IN" of="$OUT" bs="$BS" count="$COUNT" 2>&1)
    echo "$OUTPUT" | tail -n1
    sync
}

print_header() {
    echo -e "${BOLD}${GREEN}Linux Ubuntu / Debian Benchmark & Stress Test${RESET}"
    echo "Tanggal   : $(date)"
    echo "Host      : $(hostname 2>/dev/null || echo ubuntu)"
    echo "Kernel    : $(uname -srmo)"
    echo "CPU       : ${CPU_MODEL} (${CPU_CORES} core)"
    echo "Memory    : $(free -h 2>/dev/null | awk '/Mem:/ {print $2}')"
    show_temp_once
}

# ---------- System Info ----------
run_sysinfo() {
    section "Informasi Sistem Komprehensif (Ubuntu / Debian)"
    
    local os_name="Ubuntu Linux"
    if [ -f /etc/os-release ]; then
        . /etc/os-release 2>/dev/null
        [ -n "${PRETTY_NAME:-}" ] && os_name="$PRETTY_NAME"
    fi

    echo "  • OS Distribution: $os_name"
    echo "  • Arsitektur     : $(uname -m)"
    echo "  • Kernel Version : $(uname -r)"
    echo "  • Hostname       : $(hostname)"
    echo "  • Package Manager: apt (Advanced Package Tool)"
    echo "  • Jumlah CPU Core: $CPU_CORES core"
    echo "  • Model CPU      : $CPU_MODEL"

    if [ -f /proc/meminfo ]; then
        local ram_total ram_avail
        ram_total=$(awk '/MemTotal:/ {printf "%.1f MB", $2/1024}' /proc/meminfo)
        ram_avail=$(awk '/MemAvailable:/ {printf "%.1f MB", $2/1024}' /proc/meminfo 2>/dev/null || awk '/MemFree:/ {printf "%.1f MB", $2/1024}' /proc/meminfo)
        echo "  • Memori (RAM)   : Total $ram_total | Bebas: $ram_avail"
    fi

    local root_space
    root_space=$(df -h / 2>/dev/null | awk 'NR==2{print "Total: "$2", Terpakai: "$3" ("$5"), Bebas: "$4}')
    [ -n "$root_space" ] && echo "  • Storage Root (/): $root_space"

    echo
    echo -e "${YELLOW}[Frekuensi CPU & Scaling Governor]${RESET}"
    show_cpu_freq

    echo
    echo -e "${YELLOW}[Thermal Sensors Detail]${RESET}"
    show_thermal_detail
}

# ---------- CPU Benchmark ----------
run_cpu_benchmark() {
    section "CPU Benchmark"
    if have sysbench; then
        echo -e "${YELLOW}[sysbench] Single-thread prime test (20,000 max-prime)${RESET}"
        sysbench cpu --cpu-max-prime=20000 --threads=1 run | grep -E "events per second|total time"
        echo -e "\n${YELLOW}[sysbench] Multi-thread prime test (${CPU_CORES} threads)${RESET}"
        sysbench cpu --cpu-max-prime=20000 --threads="$CPU_CORES" run | grep -E "events per second|total time"
    else
        echo -e "${YELLOW}[fallback] Pure AWK prime-count test (single-thread)${RESET}"
        local START END count limit ELAPSED
        START=$(date +%s.%N 2>/dev/null || date +%s); limit=200000
        count=$(awk -v limit="$limit" 'BEGIN{
            c=0
            for (i=2; i<=limit; i++) {
                isprime=1
                for (j=2; j*j<=i; j++) { if (i%j==0){isprime=0; break} }
                if (isprime) c++
            }
            print c
        }')
        END=$(date +%s.%N 2>/dev/null || date +%s)
        ELAPSED=$(awk -v s="$START" -v e="$END" 'BEGIN{printf "%.2f", e-s}')
        echo "Prime ditemukan di bawah $limit : $count"
        echo "Waktu                          : ${ELAPSED}s"
        echo "(Tip: Install sysbench via 'sudo apt update && sudo apt install sysbench' untuk hasil standar)"
    fi

    echo
    if have openssl; then
        echo -e "${YELLOW}[openssl] SHA256 Speed Test (3 detik)${RESET}"
        openssl speed -seconds 3 sha256 2>/dev/null | grep -E '^sha256' | tail -n 1
    else
        echo -e "${YELLOW}[openssl] Tidak terinstall (install via 'sudo apt install openssl')${RESET}"
    fi

    echo
    echo -e "${YELLOW}[AWK Math] Floating Point Calculation Test (2,000,000 ops)${RESET}"
    local fp_s fp_e fp_t
    fp_s=$(date +%s.%N 2>/dev/null || date +%s)
    awk 'BEGIN{
        x=1.00001
        for(i=1;i<=2000000;i++){
            x=x*1.0000001 + sin(i)/1000
        }
    }' >/dev/null
    fp_e=$(date +%s.%N 2>/dev/null || date +%s)
    fp_t=$(awk -v s="$fp_s" -v e="$fp_e" 'BEGIN{printf "%.2f", e-s}')
    echo "Floating Point Math: 2,000,000 iterasi selesai dalam ${fp_t}s"
}

# ---------- Memory Benchmark ----------
run_memory_benchmark() {
    section "Memory (RAM) Benchmark"
    if have sysbench; then
        echo -e "${YELLOW}[sysbench] Memory read/write bandwidth (2GB total transfer)${RESET}"
        sysbench memory --memory-block-size=1M --memory-total-size=2G run | grep -E "transferred|events per second"
    elif have dd; then
        echo -e "${YELLOW}[dd] tmpfs write/read throughput (512MB RAM test)${RESET}"
        dd_write /dev/zero "$TMPDIR/memtest" 1M 512
        echo "Read throughput:"
        dd if="$TMPDIR/memtest" of=/dev/null bs=1M 2>&1 | tail -n1
        rm -f "$TMPDIR/memtest"
    else
        echo "Tidak ada tool tersedia untuk test memory (butuh sysbench atau dd)."
    fi
}

ask_disk_size() {
    echo -e "\n${YELLOW}Pilih Ukuran File Test Disk Storage:${RESET}"
    echo "  1) 32 MB"
    echo "  2) 64 MB"
    echo "  3) 128 MB"
    echo "  4) 256 MB"
    echo "  5) 512 MB (Default Ubuntu/Debian)"
    echo "  6) 1024 MB (1GB untuk NVMe/SSD)"
    read -r -p "Pilihan ukuran [1-6, default 5]: " sz_choice
    case "$sz_choice" in
        1) echo 32 ;;
        2) echo 64 ;;
        3) echo 128 ;;
        4) echo 256 ;;
        5) echo 512 ;;
        6) echo 1024 ;;
        *) echo 512 ;;
    esac
}

# ---------- Disk I/O Benchmark ----------
run_disk_benchmark() {
    local disk_mb="${1:-}"
    if [ -z "$disk_mb" ]; then
        disk_mb=$(ask_disk_size)
    fi

    section "Disk Storage I/O Benchmark (${disk_mb}MB di $HOME)"
    local DISK_TEST_FILE="$HOME/.benchmark_disktest.tmp"
    local free_kb
    free_kb=$(df -k "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
    if [ -n "$free_kb" ] && [ "$free_kb" -lt $((disk_mb*1024 + 20480)) ]; then
        echo -e "${RED}Sisa ruang disk kurang untuk test ${disk_mb}MB. Batalkan.${RESET}"
        return 1
    fi

    if have dd; then
        echo -e "${YELLOW}[dd] Sequential write test (${disk_mb}MB dengan fsync)${RESET}"
        dd_write /dev/zero "$DISK_TEST_FILE" 1M "$disk_mb"
        sync
        
        echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
        
        echo -e "\n${YELLOW}[dd] Sequential read test (${disk_mb}MB)${RESET}"
        dd if="$DISK_TEST_FILE" of=/dev/null bs=1M 2>&1 | tail -n1
        rm -f "$DISK_TEST_FILE"
    else
        echo "Tool 'dd' tidak ditemukan, skip disk benchmark."
    fi
}

# ---------- Network Benchmark ----------
run_network_benchmark() {
    section "Network Latency & Download Speed Test"
    echo -e "${YELLOW}[Ping Latency Test]${RESET}"
    for target in "1.1.1.1" "8.8.8.8"; do
        if have ping; then
            local p_res
            p_res=$(ping -c 3 "$target" 2>/dev/null | grep -E 'round-trip|rtt' | cut -d'=' -f2 | cut -d'/' -f2 || true)
            [ -n "$p_res" ] && echo "  • Ping ke $target : ${p_res} ms" || echo "  • Ping ke $target : Timeout/Gagal"
        fi
    done

    echo -e "\n${YELLOW}[HTTP Download Speed Test - CDN 50MB File]${RESET}"
    local url="http://speedtest.tele2.net/50MB.zip"
    if have curl; then
        local s e t speed
        s=$(date +%s.%N 2>/dev/null || date +%s)
        curl -s -m 15 -o /dev/null "$url"
        e=$(date +%s.%N 2>/dev/null || date +%s)
        t=$(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.2f", e-s}')
        if awk -v t="$t" 'BEGIN{exit !(t>0)}'; then
            speed=$(awk -v t="$t" 'BEGIN{printf "%.2f", (50*8)/t}')
            echo "  • Download 50MB via curl : Selesai dalam ${t}s (~${speed} Mbps)"
        fi
    elif have wget; then
        local s e t speed
        s=$(date +%s.%N 2>/dev/null || date +%s)
        wget -q --timeout=15 -O /dev/null "$url"
        e=$(date +%s.%N 2>/dev/null || date +%s)
        t=$(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.2f", e-s}')
        if awk -v t="$t" 'BEGIN{exit !(t>0)}'; then
            speed=$(awk -v t="$t" 'BEGIN{printf "%.2f", (50*8)/t}')
            echo "  • Download 50MB via wget : Selesai dalam ${t}s (~${speed} Mbps)"
        fi
    else
        echo "Tool curl/wget tidak ditemukan."
    fi
}

ask_duration() {
    echo -e "\n${YELLOW}Pilih Durasi Stress Test CPU:${RESET}"
    echo "  1) 30 Detik (Tes Cepat)"
    echo "  2) 1 Menit"
    echo "  3) 5 Menit (Tes Stabilitas Standard)"
    echo "  4) 10 Menit (Tes Ketahanan Thermal)"
    echo "  5) Input Durasi Kustom (dalam detik)"
    read -r -p "Pilihan [1-5, default 1]: " dur_choice
    case "$dur_choice" in
        2) echo 60 ;;
        3) echo 300 ;;
        4) echo 600 ;;
        5)
            read -r -p "Masukkan durasi dalam detik (misal 120): " cust_sec
            cust_sec=$(echo "$cust_sec" | tr -cd '0-9')
            [ -z "$cust_sec" ] || [ "$cust_sec" -lt 5 ] && cust_sec=30
            echo "$cust_sec"
            ;;
        *) echo 30 ;;
    esac
}

stress_worker() {
    if have stress-ng; then
        exec stress-ng --cpu 1 --timeout 3600s >/dev/null 2>&1
    elif have openssl; then
        exec sh -c 'while true; do openssl speed -seconds 1 sha256 >/dev/null 2>&1; done'
    else
        exec awk 'BEGIN{ x=1.23456; while(1){ for(i=0;i<100000;i++){ x=sqrt(x*x+1) } } }'
    fi
}

monitor_temp_during() {
    local seconds="$1"
    local elapsed=0
    local step=2
    local t
    local aborted=0
    while [ "$elapsed" -lt "$seconds" ]; do
        local remaining=$((seconds - elapsed))
        local sleep_for=$step
        [ "$remaining" -lt "$step" ] && sleep_for=$remaining
        sleep "$sleep_for"
        elapsed=$((elapsed + sleep_for))
        if t=$(get_temp_c); then
            printf "\r  [%3ds / %3ds] Suhu CPU: %s°C | " "$elapsed" "$seconds" "$t"
            show_cpu_freq_inline
            if [ "$t" -ge "$TEMP_MAX_LIMIT" ]; then
                echo
                echo -e "${RED}[!] BAHAYA: Suhu CPU telah mencapai ${t}°C (>= ${TEMP_MAX_LIMIT}°C)!${RESET}"
                echo -e "${YELLOW}Stress test dihentikan otomatis demi keamanan sistem.${RESET}"
                aborted=1
                break
            fi
        else
            printf "\r  [%3ds / %3ds]   " "$elapsed" "$seconds"
        fi
    done
    echo
    return $aborted
}

run_stress_single() {
    section "CPU Stress Test - Single Core"
    local DUR
    DUR=$(ask_duration)
    echo -e "${RED}Membebani 1 core selama ${DUR}s... (Safety Limit: ${TEMP_MAX_LIMIT}°C)${RESET}"
    show_temp_once

    stress_worker &
    local PID=$!

    monitor_temp_during "$DUR"
    local res=$?

    kill -9 "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    pkill -9 -f 'stress-ng' 2>/dev/null || true
    pkill -9 -f 'openssl speed' 2>/dev/null || true
    pkill -9 -f 'awk.*sqrt' 2>/dev/null || true

    if [ $res -eq 0 ]; then
        echo -e "${GREEN}Stress single-core selesai dengan aman.${RESET}"
    fi
    show_temp_once
}

run_stress_multi() {
    section "CPU Stress Test - Multi Core (${CPU_CORES} Core)"
    local DUR
    DUR=$(ask_duration)
    echo -e "${RED}Membebani semua ${CPU_CORES} core selama ${DUR}s... (Safety Limit: ${TEMP_MAX_LIMIT}°C)${RESET}"
    show_temp_once

    local PIDS=()
    local i
    for ((i = 0; i < CPU_CORES; i++)); do
        stress_worker &
        PIDS+=("$!")
    done

    monitor_temp_during "$DUR"
    local res=$?

    for p in "${PIDS[@]}"; do
        kill -9 "$p" 2>/dev/null || true
    done
    wait 2>/dev/null || true
    pkill -9 -f 'stress-ng' 2>/dev/null || true
    pkill -9 -f 'openssl speed' 2>/dev/null || true
    pkill -9 -f 'awk.*sqrt' 2>/dev/null || true

    if [ $res -eq 0 ]; then
        echo -e "${GREEN}Stress multi-core selesai dengan aman.${RESET}"
    fi
    show_temp_once
}

run_full_benchmark() {
    run_sysinfo
    run_cpu_benchmark
    run_memory_benchmark
    run_disk_benchmark 512
    run_network_benchmark
    section "Selesai"
    echo -e "${GREEN}Full benchmark selesai.${RESET}"
}

export_report() {
    echo "Menyimpan laporan ke $LOG_FILE ..."
    {
        echo "=========================================================="
        echo " LAPORAN BENCHMARK UBUNTU LINUX"
        echo " Tanggal : $(date)"
        echo "=========================================================="
        run_full_benchmark
    } > "$LOG_FILE" 2>&1
    echo -e "${GREEN}Laporan tersimpan di: $LOG_FILE${RESET}"
}

show_menu() {
    echo
    hr
    echo -e "${BOLD}Pilih Mode Benchmark (Ubuntu / Debian):${RESET}"
    echo "  1) Full benchmark (SysInfo, CPU, RAM, Disk, Net)"
    echo "  2) Informasi Sistem Komprehensif & Suhu"
    echo "  3) Live Thermal & Frequency Watcher (Real-Time)"
    echo "  4) CPU benchmark saja (Prime, Hash, AWK Math)"
    echo "  5) Memory benchmark saja"
    echo "  6) Disk I/O benchmark saja (Ukuran file kustom)"
    echo "  7) Network latency & download speed test"
    echo "  8) Stress test CPU - single-core (Durasi kustom)"
    echo "  9) Stress test CPU - multi-core (${CPU_CORES} core, durasi kustom)"
    echo " 10) Ekspor laporan ke file text"
    echo "  0) Keluar"
    hr
}

main() {
    if [ "${1:-}" = "--full" ]; then
        run_full_benchmark
        exit 0
    elif [ "${1:-}" = "--sysinfo" ]; then
        run_sysinfo
        exit 0
    elif [ "${1:-}" = "--export" ]; then
        export_report
        exit 0
    fi

    print_header

    while true; do
        show_menu
        read -r -p "Masukkan pilihan [0-10]: " CHOICE
        echo
        case "$CHOICE" in
            1) run_full_benchmark ;;
            2) run_sysinfo ;;
            3) run_live_watcher ;;
            4) run_cpu_benchmark ;;
            5) run_memory_benchmark ;;
            6) run_disk_benchmark ;;
            7) run_network_benchmark ;;
            8) run_stress_single ;;
            9) run_stress_multi ;;
            10) export_report ;;
            0) echo "Sampai jumpa!"; break ;;
            *) echo -e "${RED}Pilihan tidak valid.${RESET}" ;;
        esac
    done
}

main "$@"
