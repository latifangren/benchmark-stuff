# Dokumentasi & Panduan Penggunaan - postmarketOS / Alpine Linux

Dokumentasi ini berisi panduan penggunaan script benchmark dan stress test hardware yang dioptimalkan untuk **postmarketOS** (Linux berbasis Alpine Linux untuk smartphone, tablet, dan perangkat ARM/Embedded).

---

## 🛠️ Fitur Utama

- **Informasi Sistem Detail**: Deteksi model smartphone/device (via device-tree / proc), arsitektur CPU (ARM64/armv7), versi Musl libc, status memori RAM/Swap, storage, dan suhu thermal zone.
- **CPU Benchmark**: Pengujian multi-core & single-core prime calculation (sysbench / pure AWK), OpenSSL SHA256 speed test, dan AWK Floating Point math test.
- **Memory (RAM) Benchmark**: Pengujian read/write bandwidth RAM via `sysbench memory` atau `dd` tmpfs.
- **Disk Storage I/O Benchmark**: Pengujian sequential write & read pada penyimpanan eMMC/UFS/SD Card dengan proteksi ruang kosong.
- **Network Latency & Download Speed Test**: Pengujian latency ping dan kecepatan unduh CDN via `curl` / `wget`.
- **CPU Stress Test & Thermal Guard**: Pengujian ketahanan beban CPU dengan proteksi otomatis jika suhu mencapai **≥ 82°C** (Sangat krusial untuk perangkat smartphone fanless).
- **Ekspor Laporan**: Menyimpan laporan lengkap ke file `$HOME/benchmark_pmos_*.txt`.

---

## 🚀 Cara Penggunaan

### 1. Menjalankan Langsung via Terminal (SSH / PMOS Terminal)

```bash
wget -O benchmark.sh https://raw.githubusercontent.com/USER/benchmark-stuff/main/linux/postmarket-os/benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```

Atau menggunakan `curl`:

```bash
curl -sSL https://raw.githubusercontent.com/USER/benchmark-stuff/main/linux/postmarket-os/benchmark.sh -o benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```

### 2. Mode Perintah Langsung (CLI Flags)

- **Menjalankan Full Benchmark**:
  ```bash
  ./benchmark.sh --full
  ```
- **Hanya Informasi Sistem**:
  ```bash
  ./benchmark.sh --sysinfo
  ```
- **Ekspor Laporan ke File Log**:
  ```bash
  ./benchmark.sh --export
  ```

---

## ⚙️ Dependensi Paket (Alpine APK)

Untuk mendapatkan hasil pengujian standar (sysbench & openssl), install paket pendukung melalui `apk`:

```bash
sudo apk update
sudo apk add sysbench openssl coreutils curl
```

---

## ❓ Panduan Troubleshooting & FAQ

### 1. Suhu Smartphone Sangat Cepat Panas (Thermal Alarm `82°C`)
- **Penjelasan**: Smartphone/Tablet seperti Xiaomi, Google Pixel, Samsung dll tidak memiliki pendingin kipas (fanless). Saat disiksa stress test multi-core, suhu akan cepat naik.
- **Solusi**: Thermal guard pada script akan otomatis mematikan stress test. Lepas casing HP saat pengujian atau letakkan di atas permukaan pendingin.

### 2. Output `sysbench` Tidak Tersedia
- **Penyebab**: Paket `sysbench` belum diinstall.
- **Solusi**: Script akan otomatis berpindah (fallback) menggunakan engine pengujian murni AWK/Bash. Untuk hasil lebih presisi, pasang `sysbench` (`sudo apk add sysbench`).

### 3. Error `Permission denied` saat Menjalankan Script
- **Solusi**: Jalankan `chmod +x benchmark.sh` sebelum mengeksekusi.

### 4. Gagal Menulis File Benchmark Disk
- **Penyebab**: Ruang penyimpanan internal eMMC/SD Card penuh.
- **Solusi**: Cek sisa ruang disk dengan `df -h ~` dan bersihkan file yang tidak terpakai.
