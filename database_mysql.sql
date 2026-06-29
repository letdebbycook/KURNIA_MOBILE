-- ==========================================
-- SCRIPT DATABASE MYSQL: KURNIA MOBILE
-- BERDASARKAN DOKUMEN CLASS DIAGRAM
-- ==========================================

CREATE DATABASE IF NOT EXISTS kurnia_mobile;
USE kurnia_mobile;

-- 1. Tabel User (users)
-- Representasi data kredensial, autentikasi, registrasi, dan profil pengguna.
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

-- 2. Tabel Produk (produk)
-- Representasi data katalog produk toko dengan kolom kategori dan stok.
CREATE TABLE IF NOT EXISTS produk (
  id_produk INT AUTO_INCREMENT PRIMARY KEY,
  nama VARCHAR(64) NOT NULL UNIQUE,
  harga DECIMAL(15, 2) NOT NULL,
  deskripsi VARCHAR(255) NOT NULL,
  imageUrl LONGTEXT NULL,
  kategori VARCHAR(50) DEFAULT 'Lain-lain',
  stok INT DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Tabel Transaksi (transaksi)
-- Representasi data transaksi pemesanan barang oleh pelanggan.
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
  user_nama VARCHAR(100) NULL,
  user_telepon VARCHAR(20) NULL,
  user_alamat TEXT NULL,
  FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Tabel Notifikasi (notifikasi)
CREATE TABLE IF NOT EXISTS notifikasi (
  id_notifikasi INT AUTO_INCREMENT PRIMARY KEY,
  id_user INT NOT NULL,
  judul VARCHAR(100) NOT NULL,
  pesan TEXT NOT NULL,
  is_read TINYINT(1) DEFAULT 0,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Tabel Ulasan (ulasan)
CREATE TABLE IF NOT EXISTS ulasan (
  id_ulasan INT AUTO_INCREMENT PRIMARY KEY,
  id_produk INT NOT NULL,
  id_user INT NOT NULL,
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  komentar TEXT NULL,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (id_produk) REFERENCES produk(id_produk) ON DELETE CASCADE,
  FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. Tabel Address Book (address_book)
CREATE TABLE IF NOT EXISTS address_book (
  id_alamat INT AUTO_INCREMENT PRIMARY KEY,
  id_user INT NOT NULL,
  label VARCHAR(50) NOT NULL,
  nama_penerima VARCHAR(100) NOT NULL,
  telepon_penerima VARCHAR(20) NOT NULL,
  alamat_lengkap TEXT NOT NULL,
  is_utama TINYINT(1) DEFAULT 0,
  FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ==========================================
-- SEEDING DATA AWAL (DEFAULT TEST DATA)
-- ==========================================

-- Seeding Produk Awal (produk)
INSERT INTO produk (nama, harga, deskripsi, imageUrl, kategori, stok) VALUES
('Beras Premium Kurnia 5kg', 78500.00, 'Beras kualitas super poles premium, sangat pulen, bersih, dan harum alami.', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&auto=format&fit=crop&q=80', 'Beras', 25),
('Minyak Goreng SunCo 2L', 38900.00, 'Minyak goreng kelapa sawit bermutu tinggi, bening dan tidak cepat hitam.', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=600&auto=format&fit=crop&q=80', 'Minyak Goreng', 40),
('Gula Pasir Gulaku 1kg', 17500.00, 'Gula tebu pilihan bermutu tinggi, bersih, putih manis alami.', 'https://images.unsplash.com/photo-1581798459219-318e76aecc7b?w=600&auto=format&fit=crop&q=80', 'Gula', 15),
('Tepung Terigu Segitiga Biru 1kg', 14500.00, 'Tepung terigu serbaguna protein sedang, cocok untuk aneka kue dan gorengan.', 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80', 'Tepung', 30)
ON DUPLICATE KEY UPDATE nama=nama;

-- Seeding Pengguna Default (users)
INSERT INTO users (username, password, email, nama, telepon, image_url) VALUES
('admin', 'admin', 'admin@kurnia.com', 'Administrator', '081122334455', 'https://api.dicebear.com/7.x/adventurer/png?seed=admin'),
('customer', 'customer', 'cust@kurnia.com', 'Budi Santoso', '081234567890', 'https://api.dicebear.com/7.x/adventurer/png?seed=customer')
ON DUPLICATE KEY UPDATE username=username;
