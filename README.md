# KURNIA MOBILE - Enterprise E-Commerce Platform with Midtrans & ML Insights

KURNIA MOBILE adalah platform e-commerce terintegrasi yang dibangun menggunakan **Flutter** di sisi frontend (dioptimalkan untuk target **Web** & **Mobile**) dan didukung oleh **PHP API Bridge** sebagai backend penghubung ke database **MySQL**. 

Platform ini dirancang untuk operasional ritel modern, mengintegrasikan sistem pembayaran otomatis menggunakan gateway **Midtrans Sandbox (Snap API)**, pelacakan pengiriman dinamis, serta modul analisis prediktif berbasis **Machine Learning (K-Means Clustering & Random Forest)** untuk segmentasi perputaran produk.

---

## 🚀 Fitur Utama & Alur Kerja (Workflows)

### 1. Sisi Pelanggan (Customer Features)
* **Katalog Belanja Interaktif**: Halaman storefront modern dengan dukungan pencarian produk real-time dan tata letak grid yang responsif.
* **Sistem Wishlist Reaktif**: Menyimpan produk favorit secara in-memory menggunakan `ChangeNotifier` dengan indikator counter badge dinamis dan gestur *Swipe-to-Dismiss* untuk menghapus item.
* **Optimasi Checkout**: Pemrosesan transaksi paralel menggunakan `Future.wait()` untuk menjamin performa respons di bawah 300ms.
* **Integrasi Midtrans Snap**: Pembayaran aman menggunakan overlay Snap JS SDK (di Web) dan peluncuran redirect eksternal secara asinkron dengan fallback penanganan popup blocker.
* **Pelacakan Pengiriman (Order Stepper)**: Indikator visual real-time pelacakan status pesanan pelanggan: **Bayar ➔ Dikemas ➔ Diantar ➔ Selesai**.
* **Konfirmasi Barang Diterima**: Tombol interaktif bagi pelanggan untuk menandai pesanan selesai secara mandiri ketika status kurir telah `Diantar`.
* **Pembatalan Pesanan**: Pelanggan dapat membatalkan dan menghapus transaksi secara permanen jika status pembayaran masih `Pending` (Belum Bayar).

### 2. Sisi Administrator (Admin Features)
* **Manajemen Katalog**: Operasi CRUD produk lengkap dengan kompresi gambar otomatis dan konversi gambar galeri/kamera menjadi string **Base64** secara asinkron sebelum disimpan ke database.
* **Dashboard Statistik Penjualan**: Laporan grafis real-time untuk pendapatan harian (minggu berjalan) dan akumulasi bulanan. Laporan ini secara ketat memfilter dan **hanya menghitung pesanan dengan status lunas/berhasil** (`success`, `settlement`, `capture`) guna menjamin validitas pembukuan keuangan.
* **Modul ML Insights**: Modul analitik tersemat yang memproses data transaksi produk kain:
  * *Segmentasi*: Visualisasi distribusi cluster perputaran produk (**Fast, Medium, Slow Moving**).
  * *Prediksi*: Form simulasi parameter penjualan (Quantity, Value, Total) untuk memprediksi kelas perputaran barang berbasis klasifikasi Random Forest.
* **Kelola Pesanan (Order Management)**: Panel khusus bagi admin untuk memantau alamat pengiriman pelanggan secara lengkap, menyaring pesanan berdasarkan status, dan memajukan siklus pengiriman (`dikemas` ➔ `diantar` ➔ `selesai`).

---

## 🛠️ Tech Stack & Arsitektur Sistem

Platform ini mengadopsi pola arsitektur **Layered Architecture / Clean Code** sederhana pada Flutter:

* **Frontend**: Dart | Flutter (Web & Android/iOS)
* **State Management**: Reactive programming dengan `ChangeNotifier` dan `ListenableBuilder` (minim overhead memory).
* **Backend Bridge**: Native PHP API dengan validasi JWT (JSON Web Token) untuk otentikasi login/register dan reset kata sandi berbasis token.
* **Database**: MySQL (MariaDB) dengan engine InnoDB untuk integritas relasi foreign key.
* **Payment Gateway**: Midtrans Snap API (Sandbox Mode).
* **Integrasi ML**: Embedded CSV Parser (`csv: ^6.0.0`) untuk evaluasi data analitik model clustering in-app.

### Struktur Direktori Utama Flutter
```
lib/
├── models/
│   ├── cart_item.dart           # Model struktur keranjang belanja
│   ├── product.dart             # Model struktur produk katalog
│   ├── segmentasi_produk.dart   # Model data segmentasi clustering ML
│   ├── transaksi.dart           # Model transaksi & data kurir/pengiriman
│   └── user_profile.dart        # Model profil pengguna & alamat
├── services/
│   ├── cart_service.dart        # Logika bisnis keranjang (singleton)
│   ├── database_service.dart    # Service API Bridge & Query MySQL Native
│   ├── ml_service.dart          # Pengolah data CSV & Decision Tree Classifier
│   └── wishlist_service.dart    # State Management Wishlist Pelanggan
├── views/
│   ├── admin/                   # Panel Dashboard Admin, Stats, ML, & Kelola Pesanan
│   ├── auth/                    # Halaman Splash, Login, Register, & Reset Sandi
│   └── customer/                # Catalog Storefront, Checkout, Wishlist, & Riwayat
└── widgets/                     # Komponen UI reusable (Helper Gambar, Tombol, dll.)
```

---

## 💾 Skema Database & Auto-Migration

Sistem ini didesain agar mudah di-deploy dengan fitur **Auto-Migration**. Saat API pertama kali dipanggil dari aplikasi, skema database pada MySQL akan bermigrasi secara otomatis untuk menyesuaikan kolom-kolom baru.

### Skema Relasi Database (`database_mysql.sql`)
```sql
CREATE DATABASE IF NOT EXISTS kurnia_mobile;
USE kurnia_mobile;

-- Tabel Users
CREATE TABLE IF NOT EXISTS users (
  id_user INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(64) NOT NULL UNIQUE,
  password VARCHAR(30) NOT NULL,
  email VARCHAR(100) NOT NULL,
  nama VARCHAR(64) NOT NULL,
  telepon VARCHAR(20) NOT NULL,
  alamat TEXT NULL,
  image_url LONGTEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabel Produk
CREATE TABLE IF NOT EXISTS produk (
  id_produk INT AUTO_INCREMENT PRIMARY KEY,
  nama VARCHAR(64) NOT NULL UNIQUE,
  harga DECIMAL(15, 2) NOT NULL,
  deskripsi VARCHAR(255) NOT NULL,
  imageUrl LONGTEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabel Transaksi
CREATE TABLE IF NOT EXISTS transaksi (
  id_transaksi INT AUTO_INCREMENT PRIMARY KEY,
  id_user INT NOT NULL,
  metode_bayar VARCHAR(50) NOT NULL,
  total DECIMAL(16, 2) NOT NULL,
  productName VARCHAR(100) NOT NULL,
  timestamp DATETIME NOT NULL,
  status_pembayaran VARCHAR(20) DEFAULT 'pending',
  status_pesanan VARCHAR(20) DEFAULT 'pending',
  midtrans_order_id VARCHAR(100) NULL,
  midtrans_redirect_url TEXT NULL,
  FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## ⚙️ Panduan Instalasi & Konfigurasi

### 1. Konfigurasi Backend & Database (XAMPP)
1. Aktifkan modul **Apache** dan **MySQL** pada XAMPP Control Panel Anda.
2. Buat folder baru bernama `kurnia_api` di dalam direktori `C:\xampp\htdocs\`.
3. Salin berkas backend bridge [api.php](file:///C:/xampp/htdocs/kurnia_api/api.php) dan pendukungnya (`jwt_helper.php` jika ada) ke folder `C:\xampp\htdocs\kurnia_api\`.
4. Sesuaikan kredensial server key Midtrans Anda pada berkas `api.php`:
   ```php
   define('MIDTRANS_CLIENT_KEY', 'Mid-client-XXXXX');
   define('MIDTRANS_SERVER_KEY', 'Mid-server-XXXXX');
   ```

### 2. Konfigurasi Flutter
1. Jalankan perintah untuk mengunduh library yang dibutuhkan:
   ```bash
   flutter pub get
   ```
2. Pastikan file asset CSV klasifikasi produk kain berada di direktori `assets/ml/hasil_segmentasi_produk_kain.csv`.
3. Jalankan aplikasi menggunakan target Chrome Web (atau Emulator/Device Fisik):
   ```bash
   flutter run -d chrome
   ```

*Catatan untuk target Web:* Karena Flutter Hot Restart tidak memuat ulang skrip static eksternal pada HTML secara penuh, lakukan **Hard Refresh / F5** pada browser Chrome Anda jika baru pertama kali mendeploy file `web/index.html` untuk memuat library **Midtrans Snap JS SDK** secara sempurna.

---

## 🔒 Konfigurasi Webhook Midtrans (Notifikasi Otomatis)
Agar status pembayaran di database lokal MySQL terupdate secara otomatis saat pelanggan membayar (tanpa perlu menekan tombol "Cek Status"), konfigurasikan Notification URL pada Portal Merchant Midtrans Anda:

1. Masuk ke **[Dashboard Midtrans](https://dashboard.sandbox.midtrans.com/)**.
2. Masuk ke menu **Settings ➔ Configuration**.
3. Set **Payment Notification URL** Anda ke alamat server publik Anda (atau gunakan tool tunneling seperti `ngrok` untuk mengekspos localhost Anda):
   ```
   http://<domain-publik-anda>/kurnia_api/api.php?action=midtrans_notification
   ```
4. Sistem `api.php` secara otomatis memvalidasi keaslian signature key SHA512 yang dikirimkan oleh server Midtrans sebelum melakukan pembaruan status di database.
