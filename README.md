# ⚡ Benchmark Stuff - Hardware Benchmark & Stress Test Toolkit

[![Platform](https://img.shields.io/badge/Platform-OpenWrt%20%7C%20Ubuntu%20%7C%20postmarketOS%20%7C%20Arch%20%7C%20Android%20Termux-blue.svg)](https://github.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Language](https://img.shields.io/badge/Language-Bahasa%20Indonesia-orange.svg)]()

**Benchmark Stuff** adalah repositori toolkit script benchmark & stress test hardware yang ringan, tangguh, dan portabel untuk berbagai sistem operasi Linux, router, dan mobile (OpenWrt 24, OpenWrt 25, Linux Ubuntu/Debian, postmarketOS / Alpine Linux, Arch Linux, dan Android Termux).

Toolkit ini didesain khusus agar dapat berjalan di perangkat dengan spesifikasi terbatas (seperti Router OpenWrt, STB Android/TV Box bekas, Smartphone bekas ber-postmarketOS, Raspberry Pi / SBC, hingga Server & PC Desktop) **tanpa ketergantungan wajib pada paket berat**.

---

## 🌟 Fitur Utama Toolkit

1. **📊 Informasi Sistem & Hardware Komprehensif**
   - Deteksi OS, versi Kernel, Hostname, Arsitektur CPU (x86_64, ARM64, armv7l).
   - Detail model CPU, jumlah core, frekuensi CPU (MHz), dan scaling governor.
   - Status penggunaan Memori RAM & Swap.
   - Penggunaan ruang penyimpanan (Storage Root `/` dan `/tmp`).
   - Pembacaan sensor suhu CPU / SoC thermal zone real-time.

2. **⚡ CPU Benchmark**
   - **Single-Thread & Multi-Thread Prime Calculation Test**: Menguji kecepatan pemrosesan matematis single-core dan multi-core.
   - **OpenSSL SHA256 Speed Test**: Pengujian kemampuan kriptografi hardware.
   - **AWK Floating Point Math Test**: Pengujian performa perhitungan angka desimal.

3. **💾 Memory (RAM) Bandwidth Benchmark**
   - Pengujian throughput kecepatan transfer data RAM (MB/s) menggunakan `sysbench memory` atau fallback `dd`.

4. **💽 Disk Storage I/O Benchmark**
   - **Sequential Write Speed**: Menguji kecepatan tulis penyimpanan dengan paksaan penyelarasan data fisik (`fsync` / `fdatasync`).
   - **Sequential Read Speed**: Menguji kecepatan baca fisik dengan fitur pembersihan page cache RAM.
   - **Safety Protection**: Proteksi otomatis pembatalan tes jika sisa ruang disk tidak mencukupi.

5. **🌐 Network Latency & Download Speed Test**
   - Latency ping test ke Public DNS (Cloudflare `1.1.1.1` & Google `8.8.8.8`).
   - HTTP Download Speed Test mengunduh file sampel dari CDN via `curl` / `wget` tanpa membebani disk.

6. **🔥 CPU Stress Test & Thermal Protection Guard**
   - Membebani 1 core (single-core) atau seluruh core (multi-core) CPU secara maksimal.
   - **Opsi Durasi Kustom**: Pilihan durasi 30 Detik, 1 Menit, 5 Menit, 10 Menit, atau Input Detik Kustom.
   - Live thermal monitoring: Menampilkan suhu CPU setiap 2 detik selama tes berlangsung.
   - **Thermal Protection Safety Guard**: Menghentikan stress test secara otomatis jika suhu melampaui batas aman (**82°C - 85°C**) untuk mencegah overheating atau kerusakan hardware (sangat krusial untuk perangkat fanless/embedded/STB).
   - Automatic cleanup sisa proses stress test jika terputus (stale process handler).

7. **👁️ Live Thermal & CPU Frequency Watcher**
   - Pemantauan suhu & frekuensi CPU (MHz per core) secara real-time tanpa membebani CPU.

8. **📑 Indeks Skor & Ekspor Laporan Benchmark**
   - Ringkasan indeks skor performa CPU, Memory RAM, dan Storage.
   - Menyimpan seluruh hasil benchmark ke file teks bertanda waktu (timestamped log).

---

## 📁 Struktur Repositori & Dokumentasi OS

Repositori ini dikelompokkan berdasarkan direktori sistem operasi target:

```text
benchmark-stuff/
├── README.md                          # Dokumentasi utama repositori
├── openwrt/
│   ├── 24/
│   │   ├── benchmark.sh              # Script benchmark OpenWrt 24.x (opkg / busybox ash)
│   │   └── README.md                 # Panduan penggunaan & troubleshooting OpenWrt 24
│   └── 25/
│       ├── benchmark.sh              # Script benchmark OpenWrt 25.x (apk package manager / modern kernel)
│       └── README.md                 # Panduan penggunaan & troubleshooting OpenWrt 25
├── linux/
│   ├── ubuntu/
│   │   ├── benchmark.sh              # Script benchmark Ubuntu / Debian (x86_64 / ARM / Raspberry Pi)
│   │   └── README.md                 # Panduan penggunaan & troubleshooting Ubuntu
│   ├── postmarket-os/
│   │   ├── benchmark.sh              # Script benchmark postmarketOS / Alpine Linux (ARM Smartphone/Tablet)
│   │   └── README.md                 # Panduan penggunaan & troubleshooting postmarketOS
│   └── arch/
│       ├── benchmark.sh              # Script benchmark Arch Linux / Manjaro / EndeavourOS
│       └── README.md                 # Panduan penggunaan & troubleshooting Arch Linux
└── android/
    └── termux/
        ├── benchmark.sh              # Script benchmark Android Termux (Smartphone / Tablet / Android TV)
        └── README.md                 # Panduan penggunaan & troubleshooting Termux
```

---

## 🚀 Panduan Eksekusi Cepat (Quick Start)

### ⚡ Mode Otomatis (Auto-Detect OS - Direkomendasikan)
Gunakan satu perintah ini untuk otomatis mendeteksi OS perangkat Anda (OpenWrt, Termux, Ubuntu, postmarketOS, Arch) dan menjalankan script yang paling sesuai:

**Menggunakan `wget`**:
```bash
wget -O /tmp/benchmark.sh https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/benchmark.sh && chmod +x /tmp/benchmark.sh && /tmp/benchmark.sh
```

**Menggunakan `curl`**:
```bash
curl -sSL https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/benchmark.sh -o /tmp/benchmark.sh && chmod +x /tmp/benchmark.sh && /tmp/benchmark.sh
```

---

### 🛠️ Mode Manual Per OS (Jika Ingin Memilih Sendiri)

### 🌐 OpenWrt 24.x (Router / STB B860H, HG680P, dll)
```bash
wget -O /tmp/benchmark.sh https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/openwrt/24/benchmark.sh && chmod +x /tmp/benchmark.sh && /tmp/benchmark.sh
```
👉 [Lihat Dokumentasi Lengkap OpenWrt 24](openwrt/24/README.md)

### 🌐 OpenWrt 25.x (OpenWrt Modern / APK Package Manager)
```bash
wget -O /tmp/benchmark.sh https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/openwrt/25/benchmark.sh && chmod +x /tmp/benchmark.sh && /tmp/benchmark.sh
```
👉 [Lihat Dokumentasi Lengkap OpenWrt 25](openwrt/25/README.md)

### 🤖 Android Termux (Smartphone / Tablet / TV Box)
```bash
curl -sSL https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/android/termux/benchmark.sh -o benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```
👉 [Lihat Dokumentasi Lengkap Termux](android/termux/README.md)

### 🐧 Linux Ubuntu / Debian / Raspberry Pi OS
```bash
curl -sSL https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/linux/ubuntu/benchmark.sh -o benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```
👉 [Lihat Dokumentasi Lengkap Ubuntu](linux/ubuntu/README.md)

### 📱 postmarketOS / Alpine Linux (Smartphone / Tablet Bekas)
```bash
curl -sSL https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/linux/postmarket-os/benchmark.sh -o benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```
👉 [Lihat Dokumentasi Lengkap postmarketOS](linux/postmarket-os/README.md)

### 🏹 Arch Linux / Manjaro / EndeavourOS
```bash
curl -sSL https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/linux/arch/benchmark.sh -o benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```
👉 [Lihat Dokumentasi Lengkap Arch Linux](linux/arch/README.md)

---

## 💻 Parameter Perintah CLI (Direct Flags)

Setiap script `benchmark.sh` mendukung parameter CLI untuk otomatisasi/scripting tanpa membuka menu interaktif:

| Parameter Flag | Fungsi / Deskripsi |
| :--- | :--- |
| `--full` | Menjalankan pengujian lengkap (System Info, CPU, Memory, Disk, Network) lalu selesai. |
| `--sysinfo` | Menampilkan ringkasan informasi sistem, frekuensi CPU, dan suhu thermal sensor saja. |
| `--export` | Menjalankan full benchmark dan menyimpan hasilnya secara otomatis ke file log teks. |

**Contoh Penggunaan:**
```bash
./benchmark.sh --full
./benchmark.sh --sysinfo
./benchmark.sh --export
```

---

## ❓ Panduan Troubleshooting & FAQ Lengkap

### 1. Error `Permission denied` saat Menjalankan Script
- **Penyebab**: File `benchmark.sh` belum memiliki izin sebagai program yang dapat dieksekusi (executable permission).
- **Solusi**: Berikan izin eksekusi dengan perintah:
  ```bash
  chmod +x benchmark.sh
  ```

### 2. Error `-bash: ./benchmark.sh: /bin/bash: bad interpreter: No such file or directory` atau Syntax Error pada OpenWrt / Alpine
- **Penyebab**: Script memiliki karakter pindah baris Windows (`CRLF` / `\r\n`) atau sistem tidak memiliki `/bin/bash` (hanya ada `/bin/sh` atau BusyBox ash).
- **Solusi**:
  - Ubah format file ke Unix LF menggunakan `dos2unix`:
    ```bash
    dos2unix benchmark.sh
    ```
  - Atau jalankan script dengan shell default secara langsung:
    ```bash
    sh benchmark.sh
    ```

### 3. Peringatan / Alarm `ALARM: Suhu CPU telah mencapai 82°C / 85°C!` saat Stress Test
- **Penjelasan**: Ini adalah fitur **Thermal Protection Guard**. Stress test menekan CPU hingga 100% load yang menyebabkan suhu meningkat tajam pada perangkat fanless/tanpa kipas.
- **Tindakan**:
  - Script akan mematikan proses stress test secara otomatis demi keselamatan komponen hardware Anda.
  - Tambahkan heatsink alumunium/tembaga atau kipas pendingin eksternal (USB fan) pada router/STB/HP.

### 4. Gagal Menjalankan Disk Benchmark (`Sisa ruang storage tidak cukup`)
- **Penjelasan**: Ruang penyimpanan pada direktori target kurang dari ambang batas aman (misal kurang dari 40MB pada OpenWrt atau 500MB pada Linux Ubuntu).
- **Solusi**: Bersihkan file yang tidak digunakan di `/tmp` atau pindahkan direktori pengujian ke media penyimpanan eksternal (Flashdisk / SSD / MicroSD).

### 5. Kecepatan Baca Storage Terlihat Sangat Tinggi (Ratusan MB/s - GB/s) pada SD Card / Flash Memory
- **Penjelasan**: Kernel Linux secara otomatis membaca file dari **RAM Page Cache** jika file tersebut baru saja ditulis.
- **Solusi**: Jalankan script sebagai `root` atau dengan `sudo` agar script diizinkan mengeksekusi perintah pembersihan cache RAM (`echo 3 > /proc/sys/vm/drop_caches`) sebelum tes membaca dimulai.

### 6. Proses Stress Test Terus Berjalan Setelah Sesi SSH Terputus
- **Penjelasan**: Sesi SSH yang mati mendadak saat stress test berjalan dapat meninggalkan proses background.
- **Solusi**: Script sudah dilengkapi **Stale Process Handler**. Saat Anda menjalankan script kembali, script akan mendeteksi proses lama dan menanyakan apakah ingin dimatikan. Anda juga bisa mematikannya secara manual:
  ```bash
  killall awk 2>/dev/null
  # Atau di Linux Ubuntu/Arch:
  killall stress-ng 2>/dev/null
  ```

---

## 📜 Lisensi & Kontribusi

Proyek ini dirilis di bawah lisensi **MIT License**. Kontribusi berupa pull request, penambahan dukungan OS baru, perbaikan bug, atau ide fitur sangat disukai!
