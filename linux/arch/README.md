# Dokumentasi & Panduan Penggunaan - Arch Linux

Dokumentasi ini berisi panduan penggunaan script benchmark dan stress test hardware untuk sistem operasi **Arch Linux**, **Manjaro**, **EndeavourOS**, dan distro berbasis Arch (x86_64, ARM64).

---

## 🛠️ Fitur Utama

- **Informasi Sistem Detail**: Informasi distribusi Arch Linux rolling release, kernel versi terbaru, CPU governor, frekuensi CPU, RAM, Swap, sisa storage, dan detail sensor suhu.
- **CPU Benchmark**: Pengujian Single-thread & Multi-thread Prime (sysbench / AWK), OpenSSL SHA256 Kriptografi, dan Floating Point Math test.
- **Memory (RAM) Bandwidth**: Pengujian kecepatan read/write RAM via `sysbench memory` atau `dd` tmpfs.
- **Disk Storage I/O Benchmark**: Pengujian kecepatan Sequential Write (`fsync`) dan Read (dengan pembentukan cache flush) pada NVMe, SSD, atau HDD.
- **Network Latency & Download Speed Test**: Pengujian ping latency ke DNS Publik dan tes kecepatan unduh file CDN 50MB.
- **CPU Stress Test & Thermal Protection Guard**: Membebani CPU (single & multi-core) dengan pilihan durasi (30s, 1m, 5m, 10m, kustom) dan proteksi otomatis jika suhu mencapai **≥ 85°C**.
- **Live Thermal & Frequency Watcher**: Monitoring suhu & MHz frekuensi CPU real-time.
- **Custom Disk Test Size**: Opsi pilihan ukuran file uji storage (32MB - 1024MB).
- **Ekspor Laporan**: Menyimpan hasil benchmark ke file `$HOME/benchmark_arch_*.txt`.

---

## 🚀 Cara Penggunaan

### 1. Menjalankan Langsung via Terminal

```bash
wget -O benchmark.sh https://raw.githublatifangrencontent.com/latifangren/benchmark-stuff/main/linux/arch/benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```

Atau menggunakan `curl`:

```bash
curl -sSL https://raw.githublatifangrencontent.com/latifangren/benchmark-stuff/main/linux/arch/benchmark.sh -o benchmark.sh && chmod +x benchmark.sh && ./benchmark.sh
```

### 2. Mode Parameter CLI

- **Full Benchmark tanpa menu interactive**:
  ```bash
  ./benchmark.sh --full
  ```
- **Tampilkan Informasi Sistem**:
  ```bash
  ./benchmark.sh --sysinfo
  ```
- **Ekspor Laporan ke File**:
  ```bash
  ./benchmark.sh --export
  ```

---

## ⚙️ Rekomendasi Paket Pendukung (PACMAN)

Untuk mengaktifkan pengujian performa standar dan pembacaan sensor lengkap di Arch Linux:

```bash
sudo pacman -S --needed sysbench openssl lm_sensors curl coreutils
sudo sensors-detect --auto
```

---

## ❓ Panduan Troubleshooting & FAQ

### 1. Sensor Suhu Tidak Terbaca
- **Solusi**: Install `lm_sensors` dan jalankan pemindaian modul:
  ```bash
  sudo pacman -S lm_sensors
  sudo sensors-detect --auto
  ```

### 2. Peringatan Thermal Alarm (`>= 85°C`)
- **Penjelasan**: Pengujian stress test menyebabkan suhu prosesor melewati ambang batas aman. Thermal guard akan menghentikan tes secara otomatis demi keamanan hardware.

### 3. Kebocoran Memori atau Cache pada Test Read Storage
- **Solusi**: Jalankan script dengan `sudo ./benchmark.sh` agar script dapat mengosongkan cache RAM sistem secara efisien sebelum pengujian membaca disk.

### 4. Gagal Menjalankan Script (`Permission denied`)
- **Solusi**: Jalankan `chmod +x benchmark.sh`.
