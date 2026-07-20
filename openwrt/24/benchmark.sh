#!/bin/sh
#
# benchmark.sh - Benchmark & Stress Test Komprehensif untuk OpenWrt 24.x
# Ditargetkan untuk OpenWrt 24 (ARM64 / ARMv7 / x86_64), ramah BusyBox (ash & bash)
#
# Fitur Utama:
#   1) Informasi Sistem Lengkap (OS, Kernel, CPU, Freq, Thermal, RAM, Storage, Network)
#   2) CPU Benchmark (Single & Multi-Thread Prime, Floating Point, Hashing OpenSSL)
#   3) Memory Bandwidth Benchmark (dd zero-fill / RAM throughput)
#   4) Disk I/O Benchmark (Sequential Write/Read & Disk Space Safety Check)
#   5) Network Speed & Latency Benchmark (Ping & HTTP Download Speed Test)
#   6) CPU Stress Test (Single & Multi-Core) dengan Thermal Throttling & Auto-Kill Protection (>80°C)
#   7) Ekspor Laporan Hasil Benchmark ke File (.txt)
#

# Stop on critical errors, allow pipe fail if supported
set -u

# ---------- Konfigurasi Default ----------
CORES=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
[ -z "$CORES" ] || [ "$CORES" -eq 0 ] && CORES=1

PRIME_LIMIT=200000          # Batas perhitungan prima
MEM_MB=128                  # Ukuran data test memory (disesuaikan untuk RAM OpenWrt)
DISK_MB=32                  # Ukuran file test disk (aman untuk flash/eMMC)
DISK_TESTFILE="/tmp/.openwrt_disktest"
STRESS_DURATION=30          # Durasi default stress test (detik)
TEMP_MAX_LIMIT=82           # Batas suhu maksimal (°C) sebelum stress test dihentikan demi keamanan device

LOG_FILE="/tmp/benchmark_openwrt24_$(date +%Y%m%d_%H%M%S).txt"

# ---------- Warna ANSI ----------
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_CYAN="\033[1;36m"
C_BLUE="\033[1;34m"
C_MAGENTA="\033[1;35m"

info()  { printf "${C_CYAN}[i]${C_RESET} %s\n" "$*"; }
ok()    { printf "${C_GREEN}[ok]${C_RESET} %s\n" "$*"; }
warn()  { printf "${C_YELLOW}[!]${C_RESET} %s\n" "$*"; }
err()   { printf "${C_RED}[x]${C_RESET} %s\n" "$*"; }
title() { printf "\n${C_BOLD}${C_BLUE}== %s ==${C_RESET}\n" "$*"; }

PIDFILE="/tmp/.cpubench_pids"
STRESS_PIDS=""

cleanup() {
    if [ -n "$STRESS_PIDS" ]; then
        for pid in $STRESS_PIDS; do
            kill -9 "$pid" 2>/dev/null
        done
    fi
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
            printf "Matikan proses lama tersebut? [Y/n]: "
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
    printf "\nTekan Enter untuk kembali ke menu..."
    read -r _
    echo
}

elapsed() {
    # $1=start epoch, $2=end epoch
    awk -v s="$1" -v e="$2" 'BEGIN{printf "%.2f", (e-s)}'
}

get_epoch_sec() {
    if date +%s.%N 2>/dev/null | grep -q '\.'; then
        date +%s.%N
    else
        date +%s
    fi
}

# ---------- Sensor Suhu ----------
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
        awk -v r="$raw" -v n="$name" 'BEGIN{
            c = (r > 1000) ? r/1000 : r;
            printf "    %-22s : %.1f°C\n", n, c;
        }'
    done
    [ "$found" -eq 0 ] && warn "Sensor suhu tidak terdeteksi di /sys/class/thermal/"
}

print_cpu_freq() {
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [ -f "$f" ] || continue
        cpu_name=$(basename "$(dirname "$(dirname "$f")")")
        khz=$(cat "$f" 2>/dev/null)
        [ -n "$khz" ] && awk -v n="$cpu_name" -v k="$khz" 'BEGIN{printf "    %-22s : %.2f MHz\n", n, k/1000}'
    done
}

# ---------- Informasi Sistem ----------
feature_sysinfo() {
    title "Informasi Sistem & Hardware Device (OpenWrt 24)"
    
    os_name="OpenWrt"
    if [ -f /etc/openwrt_release ]; source /etc/openwrt_release 2>/dev/null; fi
    [ -n "${DISTRIB_DESCRIPTION:-}" ] && os_name="$DISTRIB_DESCRIPTION"
    
    model="Unknown Device"
    if [ -f /tmp/sysinfo/model ]; then
        model=$(cat /tmp/sysinfo/model)
    elif [ -f /proc/device-tree/model ]; then
        model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)
    fi

    arch=$(uname -m 2>/dev/null || echo "unknown")
    kernel=$(uname -r 2>/dev/null || echo "unknown")
    hostname=$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || echo "OpenWrt")

    echo "  • Hostname       : $hostname"
    echo "  • Model Device   : $model"
    echo "  • Arsitektur     : $arch"
    echo "  • Versi OS       : $os_name"
    echo "  • Versi Kernel   : $kernel"
    echo "  • Jumlah CPU Core: $CORES core"

    # CPU Model Info
    cpu_m=$(grep -m1 -E 'model name|Hardware|Processor' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //')
    [ -n "$cpu_m" ] && echo "  • Detail CPU     : $cpu_m"

    # Memory Info
    if [ -f /proc/meminfo ]; then
        total_ram=$(awk '/MemTotal:/ {printf "%.1f MB", $2/1024}' /proc/meminfo)
        free_ram=$(awk '/MemAvailable:/ {printf "%.1f MB", $2/1024}' /proc/meminfo 2>/dev/null || awk '/MemFree:/ {printf "%.1f MB", $2/1024}' /proc/meminfo)
        echo "  • Memori (RAM)   : Total $total_ram | Bebas: $free_ram"
    fi

    # Storage Info
    root_df=$(df -h / 2>/dev/null | awk 'NR==2{print "Total: "$2", Terpakai: "$3" ("$5"), Bebas: "$4}')
    [ -n "$root_df" ] && echo "  • Storage Root (/) : $root_df"

    tmp_df=$(df -h /tmp 2>/dev/null | awk 'NR==2{print "Total: "$2", Terpakai: "$3" ("$5"), Bebas: "$4}')
    [ -n "$tmp_df" ] && echo "  • Storage Temp (/tmp): $tmp_df"

    echo
    info "Frekuensi CPU:"
    print_cpu_freq

    echo
    info "Suhu Thermal Sensor:"
    print_thermal_info
}

# ---------- CPU Benchmark ----------
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
    ok "Single-Thread: $count bilangan prima ditemukan dalam ${t}s (Skor: $score ops/s)"

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
        ok "Multi-Thread ($CORES core): Selesai dalam ${t_multi}s (Skor Total: $score_multi ops/s)"
    fi

    # Crypto / OpenSSL test
    echo
    if command -v openssl >/dev/null 2>&1; then
        info "3. Testing Kriptografi Hashing (openssl speed sha256 - 3 detik)..."
        line=$(openssl speed -seconds 3 sha256 2>/dev/null | grep -E '^sha256' | tail -1)
        [ -n "$line" ] && echo "    $line" || warn "openssl speed tidak menghasilkan output"
    else
        warn "openssl tidak terinstall di OpenWrt ini (Skip test hash crypto)"
    fi

    # Floating point test
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
    ok "Floating Point Math: 2,000,000 iterasi selesai dalam ${t_fp}s"
}

# ---------- Memory Bandwidth ----------
feature_mem_bench() {
    title "Memory Bandwidth Benchmark (~${MEM_MB}MB)"
    info "Menjalankan dd transfer dari /dev/zero ke /dev/null..."
    s=$(get_epoch_sec)
    dd if=/dev/zero of=/dev/null bs=1M count="$MEM_MB" 2>/dev/null
    e=$(get_epoch_sec)
    t=$(elapsed "$s" "$e")
    mbs=$(awk -v m="$MEM_MB" -v t="$t" 'BEGIN{ if(t>0) printf "%.1f", m/t; else print 0 }')
    ok "RAM Bandwidth: ${mbs} MB/s (${MEM_MB}MB dalam ${t}s)"
}

# ---------- Disk I/O Benchmark ----------
feature_disk_bench() {
    title "Disk I/O Benchmark (${DISK_MB}MB di /tmp)"
    
    target_dir=$(dirname "$DISK_TESTFILE")
    free_kb=$(df -k "$target_dir" 2>/dev/null | awk 'NR==2{print $4}')
    req_kb=$((DISK_MB * 1024 + 10240))
    if [ -n "$free_kb" ] && [ "$free_kb" -lt "$req_kb" ]; then
        err "Sisa ruang storage tidak cukup di $target_dir (Bebas: $((free_kb/1024))MB, Butuh: $((req_kb/1024))MB). Batalkan test."
        return
    fi
    warn "Perhatian: Test ini melakukan write ke storage tmpfs/flash."

    info "Menulis file test (Write speed)..."
    s=$(get_epoch_sec)
    dd if=/dev/zero of="$DISK_TESTFILE" bs=1M count="$DISK_MB" conv=fsync 2>/dev/null || dd if=/dev/zero of="$DISK_TESTFILE" bs=1M count="$DISK_MB" 2>/dev/null
    sync
    e=$(get_epoch_sec)
    t=$(elapsed "$s" "$e")
    write_mbs=$(awk -v m="$DISK_MB" -v t="$t" 'BEGIN{ if(t>0) printf "%.1f", m/t; else print 0 }')
    ok "Kecepatan Write: ${write_mbs} MB/s (${DISK_MB}MB dalam ${t}s)"

    # Clear page cache jika punya akses root
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

    info "Membaca file test (Read speed)..."
    s=$(get_epoch_sec)
    dd if="$DISK_TESTFILE" of=/dev/null bs=1M 2>/dev/null
    e=$(get_epoch_sec)
    t=$(elapsed "$s" "$e")
    read_mbs=$(awk -v m="$DISK_MB" -v t="$t" 'BEGIN{ if(t>0) printf "%.1f", m/t; else print 0 }')
    ok "Kecepatan Read : ${read_mbs} MB/s (${DISK_MB}MB dalam ${t}s)"

    rm -f "$DISK_TESTFILE"
}

# ---------- Network Speed & Latency ----------
feature_network_bench() {
    title "Network Latency & Download Speed Test"
    
    info "1. Testing Latency Ping ke Public DNS..."
    for target in "1.1.1.1" "8.8.8.8"; do
        if command -v ping >/dev/null 2>&1; then
            res=$(ping -c 3 "$target" 2>/dev/null | grep -E 'round-trip|rtt' | cut -d'=' -f2 | cut -d'/' -f2)
            if [ -n "$res" ]; then
                ok "Ping ke $target: avg ${res} ms"
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
            ok "Download 10MB Selesai dalam ${t}s (~${speed_mbps} Mbps)"
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
            ok "Download 10MB Selesai dalam ${t}s (~${speed_mbps} Mbps)"
        else
            warn "Download via curl gagal atau timeout."
        fi
    else
        warn "Tool curl/wget tidak tersedia di router ini."
    fi
}

# ---------- CPU Stress Test dengan Thermal Protection Guard ----------
busy_loop() {
    awk 'BEGIN{ x=1.23456; while(1){ for(i=0;i<100000;i++){ x=sqrt(x*x+1) } } }'
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
            printf "  [t=%2ds/%2ds] Suhu CPU: %d°C\n" "$elapsed" "$duration" "$curr_temp"
            if [ "$curr_temp" -ge "$TEMP_MAX_LIMIT" ]; then
                err "ALARM: Suhu CPU telah mencapai ${curr_temp}°C (Batas Aman: ${TEMP_MAX_LIMIT}°C)!"
                warn "Menghentikan stress test secara otomatis untuk mencegah overheating!"
                aborted=1
                break
            fi
        else
            printf "  [t=%2ds/%2ds] Stress test berjalan...\n" "$elapsed" "$duration"
        fi
    done
    return $aborted
}

feature_stress_single() {
    title "Stress Test CPU - Single Core (${STRESS_DURATION}s)"
    warn "Pengaman Suhu Aktif: Test akan otomatis mati jika suhu >= ${TEMP_MAX_LIMIT}°C"
    info "Menjalankan 1 proses busy-loop..."

    busy_loop &
    STRESS_PIDS="$!"
    save_pids

    stress_monitor "$STRESS_DURATION"
    res=$?

    for pid in $STRESS_PIDS; do kill -9 "$pid" 2>/dev/null; done
    clear_pidfile

    if [ $res -eq 0 ]; then
        ok "Stress test single-core selesai dengan aman."
    else
        warn "Stress test dihentikan oleh Thermal Guard."
    fi
}

feature_stress_multi() {
    title "Stress Test CPU - Multi Core ($CORES Core, ${STRESS_DURATION}s)"
    warn "Pengaman Suhu Aktif: Test akan otomatis mati jika suhu >= ${TEMP_MAX_LIMIT}°C"
    info "Menjalankan $CORES proses busy-loop paralel..."

    STRESS_PIDS=""
    for i in $(seq 1 "$CORES"); do
        busy_loop &
        STRESS_PIDS="$STRESS_PIDS $!"
    done
    save_pids

    stress_monitor "$STRESS_DURATION"
    res=$?

    for pid in $STRESS_PIDS; do kill -9 "$pid" 2>/dev/null; done
    clear_pidfile

    if [ $res -eq 0 ]; then
        ok "Stress test multi-core selesai dengan aman."
    else
        warn "Stress test dihentikan oleh Thermal Guard."
    fi
}

# ---------- Full Benchmark & Export ----------
feature_full() {
    feature_sysinfo
    feature_cpu_bench
    feature_mem_bench
    feature_disk_bench
    feature_network_bench
}

export_report() {
    info "Menyimpan laporan lengkap ke: $LOG_FILE"
    {
        echo "=========================================================="
        echo " LAPORAN BENCHMARK OPENWRT 24"
        echo " Tanggal : $(date)"
        echo "=========================================================="
        feature_full
    } > "$LOG_FILE" 2>&1
    ok "Laporan berhasil disimpan ke $LOG_FILE"
}

# ---------- Menu Utama ----------
banner() {
    clear
    printf "${C_BOLD}${C_CYAN}========================================================${C_RESET}\n"
    printf "${C_BOLD}${C_CYAN}    OpenWrt 24 Benchmark & Hardware Stress Tool         ${C_RESET}\n"
    printf "${C_BOLD}${C_CYAN}    Host: $(hostname 2>/dev/null || echo OpenWrt) ($CORES Core CPU)${C_RESET}\n"
    printf "${C_BOLD}${C_CYAN}========================================================${C_RESET}\n"
    echo " 1) Full Benchmark (SysInfo, CPU, RAM, Storage, Net)"
    echo " 2) Informasi Sistem & Thermal CPU"
    echo " 3) CPU Benchmark saja (Prime, Hash, Floating Point)"
    echo " 4) Memory (RAM) Bandwidth Benchmark"
    echo " 5) Disk Storage I/O Benchmark"
    echo " 6) Network Latency & Download Speed Test"
    echo " 7) Stress Test CPU - Single Core"
    echo " 8) Stress Test CPU - Multi Core (Semua Core)"
    echo " 9) Ekspor Laporan Benchmark ke File Text"
    echo " 0) Keluar"
    printf "${C_BOLD}${C_CYAN}--------------------------------------------------------${C_RESET}\n"
}

main() {
    check_stale_processes

    # Dukungan CLI Flag
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
        printf "Pilih menu [0-9]: "
        read -r choice
        case "$choice" in
            1) feature_full; press_enter ;;
            2) feature_sysinfo; press_enter ;;
            3) feature_cpu_bench; press_enter ;;
            4) feature_mem_bench; press_enter ;;
            5) feature_disk_bench; press_enter ;;
            6) feature_network_bench; press_enter ;;
            7) feature_stress_single; press_enter ;;
            8) feature_stress_multi; press_enter ;;
            9) export_report; press_enter ;;
            0) echo "Terima kasih. Sampai jumpa!"; exit 0 ;;
            *) warn "Pilihan tidak valid"; sleep 1 ;;
        esac
    done
}

main "$@"
