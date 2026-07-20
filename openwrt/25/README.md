# Dokumentasi & Panduan Penggunaan - OpenWrt 25.x

Dokumentasi ini berisi panduan lengkap penggunaan script benchmark dan stress test hardware untuk versi **OpenWrt 25.x** (OpenWrt modern dengan sistem paket APK / Linux Kernel 6.12+).

---

## 🛠️ Fitur Utama

- **Informasi Sistem OpenWrt 25**: Deteksi otomatis arsitektur, kernel modern, model perangkat, status package manager (APK/OPKG), frekuensi CPU, RAM, storage, dan suhu thermal zone.
- **CPU Benchmark**: Pengujian perhitungan bilangan prima single-thread & multi-thread, pengujian floating point math AWK, dan hashing kriptografi OpenSSL SHA256.
- **Memory Bandwidth Benchmark**: Pengujian throughput RAM menggunakan `dd` dari `/dev/zero` ke `/dev/null`.
- **Disk Storage I/O Benchmark**: Pengujian kecepatan Write (fsync) dan Read pada penyimpanan flash/tmpfs.
- **Network Speed & Latency Test**: Pengujian ping latency ke 1.1.1.1 & 8.8.8.8 serta tes kecepatan download HTTP file 10MB dari CDN.
- **CPU Stress Test & Thermal Protection Guard**: Membebani CPU (single & multi-core) dengan pemantauan suhu real-time. Memiliki **opsi pilihan durasi** (30 detik, 1m, 5m, 10m, atau kustom) dan otomatis menghentikan tes jika suhu CPU mencapai **≥ 82°C**.
- **Live Thermal & Frequency Watcher**: Pemantauan suhu & frekuensi CPU real-time tanpa membebani sistem.
- **Custom Disk Test Size**: Opsi pilihan ukuran file uji disk (16MB hingga 512MB).
- **Ekspor Laporan**: Menyimpan hasil pengujian ke `/tmp/benchmark_openwrt25_*.txt`.

---

## 🚀 Cara Penggunaan

### 1. Eksekusi Langsung via CLI

```bash
wget -O /tmp/benchmark.sh https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/openwrt/25/benchmark.sh && chmod +x /tmp/benchmark.sh && /tmp/benchmark.sh
```

Atau menggunakan `curl`:

```bash
curl -sSL https://raw.githubusercontent.com/latifangren/benchmark-stuff/main/openwrt/25/benchmark.sh -o /tmp/benchmark.sh && chmod +x /tmp/benchmark.sh && /tmp/benchmark.sh
```

### 2. Mode Parameter CLI

- **Full Benchmark tanpa menu**:
  ```bash
  ./benchmark.sh --full
  ```
- **Hanya Tampilkan SysInfo & Thermal**:
  ```bash
  ./benchmark.sh --sysinfo
  ```
- **Ekspor Laporan ke File**:
  ```bash
  ./benchmark.sh --export
  ```

---

## ⚙️ Manajemen Paket OpenWrt 25 (APK)

OpenWrt 25 menggunakan **`apk`** sebagai manajer paket resmi pengganti `opkg`. Untuk memasang alat pengujian tambahan (seperti OpenSSL / wget):

```bash
apk update
apk add openssl-util wget coreutils-dd
```

---

## ❓ Panduan Troubleshooting & FAQ

### 1. Error `apk: command not found`
- **Penyebab**: Perangkat Anda menggunakan OpenWrt versi 24 atau lebih lama (masih menggunakan `opkg`).
- **Solusi**: Gunakan script dari folder `openwrt/24/benchmark.sh`.

### 2. Error `Permission denied`
- **Solusi**: Berikan izin eksekusi script dengan `chmod +x benchmark.sh`.

### 3. Alarm Suhu Panas (`>= 82°C`)
- **Penyebab**: Stress test memicu panas berlebih pada CPU tanpa pendingin aktif.
- **Tindakan**: Thermal guard akan langsung mematikan proses stress test secara otomatis agar hardware tidak mengalami overheating atau permanent damage.

### 4. Peringatan Ruang Storage Kurang
- **Solusi**: Jalankan script dari folder yang memiliki ruang kosong cukup atau tambahkan USB Storage / Swap drive.
