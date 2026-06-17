"""
============================================================================
Generate Data Historis Stok (Dummy Realistis)
============================================================================

Script ini membuat data historis stok bulanan yang realistis berdasarkan
data transaksi penjualan yang ada di hasil_segmentasi_produk_kain.csv.

Logika:
- Untuk setiap produk per bulan, hitung total penjualan dari data transaksi
- Generate stok awal berdasarkan buffer dari rata-rata penjualan
- Generate stok masuk (pembelian/restocking) berdasarkan kebutuhan
- Stok akhir = stok awal + stok masuk - penjualan
- Safety stock = rata-rata penjualan bulanan × faktor keamanan
- Status: normal, overstock, understock, stockout
"""

import os
import numpy as np
import pandas as pd
from datetime import datetime

np.random.seed(42)

# ============================================================================
# PATHS
# ============================================================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(BASE_DIR, '..', 'assets', 'ml')
INPUT_CSV = os.path.join(ASSETS_DIR, 'hasil_segmentasi_produk_kain.csv')
OUTPUT_CSV = os.path.join(ASSETS_DIR, 'data_historis_stok.csv')


def generate_stock_data():
    """Generate data historis stok bulanan yang realistis."""
    print("=" * 60)
    print("GENERATING STOCK HISTORY DATA")
    print("=" * 60)

    # Load data transaksi
    df = pd.read_csv(INPUT_CSV)
    df['DATE'] = pd.to_datetime(df['DATE'], format='%d-%b-%y', errors='coerce')

    # Coba format alternatif untuk tanggal yang gagal parse
    mask_null = df['DATE'].isna()
    if mask_null.any():
        df.loc[mask_null, 'DATE'] = pd.to_datetime(
            df.loc[mask_null, 'DATE'], format='%d-%m-%Y', errors='coerce'
        )

    df = df.dropna(subset=['DATE'])
    df['year_month'] = df['DATE'].dt.to_period('M')

    # Agregasi penjualan bulanan per produk
    monthly_sales = df.groupby(['PFco_Code', 'year_month']).agg(
        penjualan=('QUANTITIES_Kgs', 'sum'),
    ).reset_index()

    monthly_sales = monthly_sales.sort_values(['PFco_Code', 'year_month'])

    products = monthly_sales['PFco_Code'].unique()
    print(f"  Produk: {len(products)}")

    stock_records = []

    for pcode in products:
        prod_sales = monthly_sales[monthly_sales['PFco_Code'] == pcode]
        sales_dict = dict(zip(
            prod_sales['year_month'].astype(str),
            prod_sales['penjualan']
        ))

        # Hanya ambil rentang bulan aktif produk ini (first sale to last sale)
        first_month = prod_sales['year_month'].min()
        last_month = prod_sales['year_month'].max()
        product_months = pd.period_range(start=first_month, end=last_month, freq='M')

        # Hitung rata-rata penjualan bulanan (hanya bulan yang ada transaksi)
        avg_monthly_sales = prod_sales['penjualan'].mean()
        std_monthly_sales = prod_sales['penjualan'].std()
        if pd.isna(std_monthly_sales) or std_monthly_sales == 0:
            std_monthly_sales = avg_monthly_sales * 0.2

        # Safety stock = 20-35% dari rata-rata penjualan (realistis untuk ritel)
        safety_factor = np.random.uniform(0.20, 0.35)
        safety_stock = round(avg_monthly_sales * safety_factor, 2)

        # Stok awal bulan pertama = rata-rata penjualan × 0.8-1.3 (buffer awal tidak terlalu besar)
        initial_buffer = np.random.uniform(0.8, 1.3)
        stok_awal = round(avg_monthly_sales * initial_buffer, 2)

        idle_months_count = 0  # Track bulan berturut-turut tanpa penjualan

        for period in product_months:
            period_str = str(period)
            tahun = period.year
            bulan = period.month

            # Penjualan bulan ini (0 jika tidak ada transaksi)
            penjualan = round(sales_dict.get(period_str, 0), 2)

            if penjualan > 0:
                idle_months_count = 0
                # Restocking saat ada penjualan
                # 55% normal, 25% under-restock, 20% over-restock
                restock_type = np.random.choice(
                    ['normal', 'under', 'over'],
                    p=[0.55, 0.25, 0.20]
                )

                if restock_type == 'normal':
                    restock_factor = np.random.uniform(0.9, 1.15)
                elif restock_type == 'under':
                    restock_factor = np.random.uniform(0.4, 0.75)
                else:  # over
                    restock_factor = np.random.uniform(1.3, 1.7)

                stok_masuk = round(penjualan * restock_factor, 2)
                noise = np.random.normal(0, avg_monthly_sales * 0.03)
                stok_masuk = max(0, round(stok_masuk + noise, 2))
            else:
                idle_months_count += 1
                # Bulan tanpa penjualan: jarang restock, stok berkurang alami
                if np.random.random() < 0.15:
                    stok_masuk = round(avg_monthly_sales * np.random.uniform(0.05, 0.2), 2)
                else:
                    stok_masuk = 0.0

                # Stok berkurang alami (sample rusak, penyusutan, dll) — 5-15% per bulan idle
                shrinkage = stok_awal * np.random.uniform(0.05, 0.15)
                penjualan = round(shrinkage, 2)  # Penyusutan dicatat sebagai "keluar"

            # Hitung stok akhir
            stok_akhir = round(stok_awal + stok_masuk - penjualan, 2)

            # Pastikan stok akhir tidak negatif (minimum 0 = stockout)
            if stok_akhir < 0:
                stok_akhir = 0.0

            # Penjualan asli (bukan shrinkage) untuk record
            actual_sales = round(sales_dict.get(period_str, 0), 2)

            # Tentukan status stok — threshold lebih ketat
            if stok_akhir <= 0:
                status = 'stockout'
            elif stok_akhir < safety_stock:
                status = 'understock'
            elif stok_akhir > avg_monthly_sales * 1.5:
                status = 'overstock'
            else:
                status = 'normal'

            stock_records.append({
                'PFco_Code': pcode,
                'tahun': tahun,
                'bulan': bulan,
                'stok_awal': stok_awal,
                'stok_masuk': stok_masuk,
                'penjualan': actual_sales,
                'stok_akhir': stok_akhir,
                'safety_stock': safety_stock,
                'status_stok': status,
            })

            # Stok awal bulan berikutnya = stok akhir bulan ini
            stok_awal = stok_akhir

    stock_df = pd.DataFrame(stock_records)
    stock_df.to_csv(OUTPUT_CSV, index=False)

    # Statistik
    status_counts = stock_df['status_stok'].value_counts()
    total_records = len(stock_df)

    print(f"\n  Total records: {total_records}")
    print(f"  Distribusi status stok:")
    for status, count in status_counts.items():
        pct = count / total_records * 100
        print(f"    {status:12s}: {count:6d} ({pct:.1f}%)")

    print(f"\n  Saved -> {OUTPUT_CSV}")
    print()

    return stock_df


if __name__ == '__main__':
    generate_stock_data()
