# Dokumentasi & Panduan Penggunaan - OpenWrt 24.x

Dokumentasi ini berisi panduan lengkap untuk menggunakan script benchmark dan stress test hardware pada sistem operasi **OpenWrt 24.x** (misalnya OpenWrt 24.10.x).

---

## 🛠️ Fitur Utama

- **Informasi Sistem & Hardware**: Deteksi model router/STB, versi OpenWrt, kernel, arsitektur CPU, frekuensi CPU MHz, memori RAM, dan sensor suhu thermal zone.
- **CPU Benchmark**: Pengujian perhitungan bilangan prima single-thread & multi-thread, pengujian floating point AWK, dan hashing kriptografi (OpenSSL SHA256 jika tersedia).
- **Memory Bandwidth Benchmark**: Pengujian throughput RAM menggunakan `dd` dari `/dev/zero` ke `/dev/null`.
- **Disk Storage I/O Benchmark**: Pengujian kecepatan Write (dengan `fsync`) dan Read pada penyimpanan flash/tmpfs dengan proteksi batas sisa ruang disk.
- **Network Latency & Download Speed Test**: Pengujian ping latency ke public DNS (1.1.1.1 & 8.8.8.8) dan download speedtest file 10MB via `wget` / `curl`.
- **CPU Stress Test & Thermal Protection Guard**: Membebani CPU (single/multi-core) dengan pemantauan suhu & frekuensi CPU real-time. Memiliki **opsi durasi kustom** (30 detik, 1 menit, 5 menit, 10 menit, atau custom detik) dan **Proteksi Otomatis** yang menghentikan stress test jika suhu CPU mencapai **≥ 82°C**.
- **Live Thermal & Frequency Watcher**: Pemantauan suhu dan frekuensi CPU secara terus menerus (real-time).
- **Custom Disk Test Size**: Opsi pilihan ukuran data uji storage (16MB, 32MB, 64MB, 128MB, 256MB, 512MB).
- **Ekspor Laporan**: Menyimpan hasil pengujian ke file log `/tmp/benchmark_openwrt24_*.txt`.

---

## 🚀 Cara Penggunaan

### 1. Menjalankan Langsung via wget / curl (Tanpa Clone)

Jalankan perintah ini melalui terminal SSH OpenWrt 24 Anda:

```bash
wget -O /tmp/benchmark.sh https://raw.githublatifangrencontent.com/latifangren/benchmark-stuff/main/openwrt/24/benchmark.sh && chmod +x /tmp/benchmark.sh && /tmp/benchmark.sh
```

Atau jika menggunakan `curl`:

```bash
curl -sSL https://raw.githublatifangrencontent.com/latifangren/benchmark-stuff/main/openwrt/24/benchmark.sh -o /tmp/benchmark.sh && chmod +x /tmp/benchmark.sh && /tmp/benchmark.sh
```

### 2. Menjalankan via Local Clone / Download File

```bash
cd /tmp
chmod +x benchmark.sh
./benchmark.sh
```

### 3. Mode Perintah Langsung (CLI Flags)

- **Menjalankan Full Benchmark tanpa menu interactive**:
  ```bash
  ./benchmark.sh --full
  ```
- **Hanya menampilkan informasi sistem & suhu**:
  ```bash
  ./benchmark.sh --sysinfo
  ```
- **Menjalankan dan langsung mengekspor laporan ke file**:
  ```bash
  ./benchmark.sh --export
  ```

---

## ⚙️ Dependensi Paket Opsional (OPKG)

Script ini dirancang **ringan tanpa butuh sysbench/stress-ng** (menggunakan bawaan BusyBox / POSIX shell). Namun, beberapa fitur akan lebih optimal jika paket berikut diinstall:

```bash
opkg update
opkg install openssl-util wget-ssl coreutils-dd
```

---

## ❓ Panduan Troubleshooting & FAQ

### 1. Error `Permission denied` saat menjalankan script
- **Penyebab**: Script belum diberikan izin eksekusi (`+x`).
- **Solusi**:
  ```bash
  chmod +x benchmark.sh
  ```

### 2. Error `-ash: ./benchmark.sh: not found` atau Syntax Error
- **Penyebab**: Format baris file berformat Windows (CRLF `\r\n`).
- **Solusi**: Ubah ke format Unix (LF):
  ```bash
  dos2unix benchmark.sh
  # Atau jalankan via sh langsung:
  sh benchmark.sh
  ```

### 3. Warning `ALARM: Suhu CPU telah mencapai 82°C!` saat Stress Test
- **Penjelasan**: Ini adalah fitur keselamatan **Thermal Protection Guard**. Perangkat Anda tidak memiliki pendingin (heatsink/fan) yang memadai atau thermal paste telah mengering.
- **Solusi**:
  - Gunakan fan eksternal / heatsink tambahan pada router/STB.
  - Jangan jalankan stress test dalam durasi yang terlalu lama.

### 4. Gagal Menulis Disk Benchmark (`Sisa ruang storage tidak cukup`)
- **Penjelasan**: Ruang penyimpanan `/tmp` atau overlay flash kurang dari batas aman (butuh minimal sisa ~40MB).
- **Solusi**: Hapus file sementara di `/tmp` atau sambungkan USB drive / MicroSD external.

### 5. Proses Stress Test Masih Jalan di Background saat Terputus (SSH Disconnect)
- **Solusi**: Script sudah dilengkapi fitur **Stale Process Detector**. Saat Anda membuka script kembali, script akan menawarkan untuk mematikan sisa proses lama otomatis. Atau matikan manual via:
  ```bash
  killall awk 2>/dev/null
  ```
