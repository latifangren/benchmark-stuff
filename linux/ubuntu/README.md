# Dokumentasi & Panduan Penggunaan - Linux Ubuntu / Debian

Dokumentasi ini berisi panduan penggunaan script benchmark dan stress test hardware untuk sistem operasi **Linux Ubuntu** (Server & Desktop) serta distro turunan Debian (x86_64, ARM64 / Raspberry Pi / SBC).

---

## 🛠️ Fitur Utama

- **Informasi Sistem Komprehensif**: Deteksi rincian distribusi Ubuntu, versi Kernel, arsitektur, CPU governor, frekuensi CPU MHz, memori RAM, Swap, ruang storage, dan sensor suhu via `lm-sensors` / thermal zone.
- **CPU Benchmark**: Pengujian Single-thread & Multi-thread Prime (sysbench / AWK), OpenSSL SHA256 Kriptografi, dan Floating Point Math test.
- **Memory (RAM) Bandwidth**: Pengujian kecepatan read/write RAM via `sysbench memory` atau `dd` tmpfs throughput.
- **Disk Storage I/O Benchmark**: Pengujian kecepatan Sequential Write (`fsync`) dan Sequential Read (dengan pembentukan cache flush) pada NVMe, SSD, atau HDD.
- **Network Latency & Download Speed Test**: Pengujian respon ping ke DNS Publik (1.1.1.1 & 8.8.8.8) dan tes kecepatan download file 50MB dari CDN.
- **CPU Stress Test & Thermal Protection Guard**: Membebani CPU (single & multi-core) dengan pilihan durasi (30s, 1m, 5m, 10m, kustom) dan proteksi otomatis jika suhu mencapai **≥ 85°C**.
- **Live Thermal & Frequency Watcher**: Pemantauan suhu & frekuensi CPU secara real-time.
- **Custom Disk Test Size**: Pilihan ukuran data uji storage (32MB - 1024MB).
- **Ekspor Laporan**: Menyimpan hasil pengujian ke `$HOME/benchmark_ubuntu_*.txt`.

---

## 🚀 Cara Penggunaan

### 1. Menjalankan Langsung via Terminal

```bash
wget -O benchmark.sh https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/linux/ubuntu/benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```

Atau menggunakan `curl`:

```bash
curl -sSL https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/linux/ubuntu/benchmark.sh -o benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```

### 2. Mode Parameter CLI

- **Full Benchmark tanpa menu interactive**:
  ```bash
  ./benchmark.sh --full
  ```
- **Hanya Informasi Sistem & Suhu**:
  ```bash
  ./benchmark.sh --sysinfo
  ```
- **Ekspor Laporan ke File**:
  ```bash
  ./benchmark.sh --export
  ```

---

## ⚙️ Rekomendasi Paket Pendukung (APT)

Untuk hasil pengujian terbaik dan pembacaan suhu sensor yang akurat, pasang paket berikut:

```bash
sudo apt update
sudo apt install -y sysbench openssl lm-sensors curl coreutils
sudo sensors-detect --auto
```

---

## ❓ Panduan Troubleshooting & FAQ

### 1. Sensor Suhu Tidak Terbaca (`Sensor suhu tidak terdeteksi`)
- **Penyebab**: Modul kernel `lm-sensors` belum diinisialisasi.
- **Solusi**:
  ```bash
  sudo apt install lm-sensors
  sudo sensors-detect --auto
  ```

### 2. Kecepatan Read Disk Terlihat Sangat Tinggi (GigaByte/detik)
- **Penjelasan**: Pembacaan disk dilakukan dari Page Cache Linux (RAM), bukan fisik disk.
- **Solusi**: Jalankan script dengan hak akses `sudo` agar script dapat mengosongkan cache memory (`echo 3 > /proc/sys/vm/drop_caches`) sebelum tes membaca dimulai.

### 3. Alarm Thermal Protection (`>= 85°C`)
- **Penyebab**: Sistem pendingin PC/Server/Raspberry Pi kurang optimal.
- **Tindakan**: Thermal guard akan langsung menghentikan stress test untuk menjaga keamanan prosesor. Periksa kipas pendingin atau ganti thermal paste.

### 4. Permission Denied saat Eksekusi Script
- **Solusi**: Jalankan `chmod +x benchmark.sh` sebelum eksekusi.
