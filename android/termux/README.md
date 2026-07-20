# Dokumentasi & Panduan Penggunaan - Android Termux

Dokumentasi ini berisi panduan penggunaan script benchmark dan stress test hardware yang didesain khusus untuk lingkungan **Android** menggunakan aplikasi **Termux** (smartphone, tablet, Android TV box).

---

## 🛠️ Fitur Utama

- **Informasi Sistem Android**: Deteksi brand/model HP (via Android `getprop`), versi Android, SDK API level, chipset/SoC (Qualcomm Snapdragon, MediaTek, Exynos, Unisoc), versi kernel, RAM, storage, dan suhu baterai/SoC.
- **Live Thermal & Frequency Watcher**: Pemantauan suhu perangkat dan frekuensi CPU per core secara real-time.
- **CPU Benchmark**: Pengujian Single-thread & Multi-thread Prime (sysbench / AWK), OpenSSL SHA256 Kriptografi, dan Floating Point Math test.
- **Memory (RAM) Bandwidth**: Pengujian kecepatan read/write RAM via `sysbench memory` atau `dd` throughput.
- **Disk Storage I/O Benchmark**: Pengujian kecepatan Sequential Write (`fsync`) dan Read pada penyimpanan internal Termux (`$HOME`) atau `/sdcard` dengan opsi ukuran file kustom (16MB - 512MB).
- **Network Latency & Download Speed Test**: Pengujian respon ping ke DNS Publik dan tes kecepatan unduh file CDN 10MB.
- **CPU Stress Test & Thermal Protection Guard**: Membebani CPU (single & multi-core) dengan pilihan durasi (30s, 1m, 5m, 10m, kustom) dan proteksi otomatis jika suhu mencapai **≥ 82°C** untuk melindungi baterai & layar smartphone.
- **Ekspor Laporan**: Menyimpan hasil benchmark ke file `$HOME/benchmark_termux_*.txt`.

---

## 🚀 Cara Penggunaan

### 1. Menjalankan Langsung di Termux (One-Liner)

Buka aplikasi **Termux** lalu jalankan perintah berikut:

```bash
curl -sSL https://raw.githubusercontent.com/USER/benchmark-stuff/main/android/termux/benchmark.sh -o benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```

Atau menggunakan `wget`:

```bash
wget -O benchmark.sh https://raw.githubusercontent.com/USER/benchmark-stuff/main/android/termux/benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```

### 2. Mode Parameter CLI

- **Full Benchmark tanpa menu interactive**:
  ```bash
  ./benchmark.sh --full
  ```
- **Tampilkan Informasi Sistem Android**:
  ```bash
  ./benchmark.sh --sysinfo
  ```
- **Ekspor Laporan ke File**:
  ```bash
  ./benchmark.sh --export
  ```

---

## ⚙️ Rekomendasi Paket Pendukung Termux (`pkg`)

Agar hasil pengujian lebih presisi dan fitur deteksi suhu baterai berfungsi, install paket berikut di Termux:

```bash
pkg update && pkg upgrade -y
pkg install -y sysbench openssl termux-api curl coreutils
```

---

## ❓ Panduan Troubleshooting & FAQ

### 1. Suhu Baterai/CPU Tidak Terbaca
- **Solusi**: Install aplikasi **Termux:API** dari F-Droid / Play Store serta paketnya di dalam Termux terminal:
  ```bash
  pkg install termux-api
  ```

### 2. Error `Permission denied` saat Menjalankan Script
- **Solusi**: Jalankan `chmod +x benchmark.sh`.

### 3. Alarm Thermal Protection (`>= 82°C`)
- **Penjelasan**: Smartphone/Tablet menggunakan pendingin pasif tanpa kipas (fanless). Stress test multi-core dapat menaikkan suhu dengan cepat.
- **Tindakan**: Script akan otomatis menghentikan stress test untuk melindungi komponen layar (OLED/AMOLED) dan kesehatan baterai HP dari overheating.

### 4. Termux Berhenti Sendiri saat Stress Test Berjalan di Background (Phantom Process Killer / Android 12+)
- **Penjelasan**: Fitur manajemen daya agresif Android 12/13/14 (Phantom Process Killer) akan menghentikan proses yang memakan CPU tinggi di background.
- **Solusi**: Biarkan aplikasi Termux tetap terbuka di layar utama saat pengujian stress test berjalan, atau nonaktifkan optimasi baterai untuk aplikasi Termux di pengaturan Android (`Settings -> Battery -> Unrestricted`).
