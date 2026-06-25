"""
============================================================================
ML Pipeline: K-Means Clustering + Random Forest Prediction
Capstone Project - Toko KURNIA (Segmentasi & Prediksi Stok Produk Kain)
============================================================================

Sesuai Tujuan Penelitian:
1. K-Means Clustering → Segmentasi produk kain berdasarkan pola penjualan
   DAN kondisi stok secara objektif dan terukur
2. Random Forest Regressor → Prediksi kebutuhan stok kain pada periode
   tertentu dengan tingkat kesalahan rendah
3. Evaluasi Integrasi K-Means + RF → Rekomendasi operasional untuk
   meminimalkan overstock dan understock

Proses:
1. Load data historis penjualan + data stok
2. Feature engineering (agregasi bulanan, lag features, fitur stok)
3. K-Means Clustering → segmentasi produk (fast/medium/slow moving)
   - Fitur: penjualan, stok, turnover ratio, stockout frequency
   - Validasi: Silhouette Score, Davies-Bouldin Index
4. Random Forest Regressor → prediksi kebutuhan stok
   - Target: kebutuhan stok = penjualan + safety stock buffer
   - Evaluasi: MAE, RMSE, MAPE, R²
5. Rekomendasi Operasional → overstock/understock detection
6. Export semua hasil ke CSV untuk Flutter app
"""

import os
import warnings
import numpy as np
import pandas as pd

from sklearn.cluster import KMeans
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, mean_squared_error
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import silhouette_score, davies_bouldin_score

warnings.filterwarnings('ignore')

# ============================================================================
# PATHS
# ============================================================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(BASE_DIR, '..', 'assets', 'ml')

INPUT_SALES_CSV = os.path.join(ASSETS_DIR, 'hasil_segmentasi_produk_kain.csv')
INPUT_STOCK_CSV = os.path.join(ASSETS_DIR, 'data_historis_stok.csv')

OUTPUT_CLUSTERING_RESULTS = os.path.join(ASSETS_DIR, 'clustering_results.csv')
OUTPUT_CLUSTERING_EVAL = os.path.join(ASSETS_DIR, 'clustering_evaluation.csv')
OUTPUT_STOCK_PRED = os.path.join(ASSETS_DIR, 'stock_prediction_results.csv')
OUTPUT_MODEL_EVAL = os.path.join(ASSETS_DIR, 'model_evaluation.csv')
OUTPUT_RECOMMENDATIONS = os.path.join(ASSETS_DIR, 'rekomendasi_operasional.csv')


def load_data():
    """Load data penjualan dan data stok."""
    print("=" * 60)
    print("STEP 1: LOADING DATA")
    print("=" * 60)

    # Load data transaksi penjualan
    df_sales = pd.read_csv(INPUT_SALES_CSV)
    df_sales['DATE'] = pd.to_datetime(df_sales['DATE'], format='%d-%b-%y', errors='coerce')

    # Coba format alternatif
    mask_null = df_sales['DATE'].isna()
    if mask_null.any():
        df_sales.loc[mask_null, 'DATE'] = pd.to_datetime(
            df_sales.loc[mask_null, 'DATE'], format='%d-%m-%Y', errors='coerce'
        )

    df_sales = df_sales.dropna(subset=['DATE'])
    df_sales['year'] = df_sales['DATE'].dt.year
    df_sales['month'] = df_sales['DATE'].dt.month
    df_sales['year_month'] = df_sales['DATE'].dt.to_period('M')

    print(f"  [Penjualan] Total baris: {len(df_sales)}")
    print(f"  [Penjualan] Rentang: {df_sales['DATE'].min()} s/d {df_sales['DATE'].max()}")
    print(f"  [Penjualan] Produk unik: {df_sales['PFco_Code'].nunique()}")

    # Load data stok
    df_stock = pd.read_csv(INPUT_STOCK_CSV)
    print(f"  [Stok] Total baris: {len(df_stock)}")
    print(f"  [Stok] Produk unik: {df_stock['PFco_Code'].nunique()}")
    print(f"  [Stok] Distribusi status:")
    print(df_stock['status_stok'].value_counts().to_string())
    print()

    return df_sales, df_stock


def perform_clustering(df_sales, df_stock):
    """
    TUJUAN 1: K-Means Clustering untuk segmentasi produk kain
    berdasarkan pola penjualan DAN kondisi stok.

    Fitur clustering:
    - Pola penjualan: total_qty, total_value, avg_qty_per_trx, transaction_count
    - Kondisi stok: avg_stok_akhir, avg_turnover_ratio, stockout_frequency, overstock_frequency
    """
    print("=" * 60)
    print("STEP 2: K-MEANS CLUSTERING (Tujuan 1)")
    print("Segmentasi produk berdasarkan pola penjualan & kondisi stok")
    print("=" * 60)

    # --- Fitur dari data penjualan ---
    sales_agg = df_sales.groupby('PFco_Code').agg(
        total_qty=('QUANTITIES_Kgs', 'sum'),
        total_value=('VALUE', 'sum'),
        total_total_values=('Total_values', 'sum'),
        transaction_count=('DATE', 'count'),
        avg_qty_per_trx=('QUANTITIES_Kgs', 'mean'),
        avg_value_per_trx=('VALUE', 'mean'),
        unique_months=('year_month', 'nunique'),
    ).reset_index()

    # --- Fitur dari data stok ---
    stock_agg = df_stock.groupby('PFco_Code').agg(
        avg_stok_akhir=('stok_akhir', 'mean'),
        avg_safety_stock=('safety_stock', 'mean'),
        total_months_data=('bulan', 'count'),
    ).reset_index()

    # Hitung turnover ratio per produk (penjualan / rata-rata stok)
    # dan frekuensi stockout/overstock
    stock_status = df_stock.groupby('PFco_Code')['status_stok'].value_counts().unstack(fill_value=0)
    for col in ['stockout', 'understock', 'overstock', 'normal']:
        if col not in stock_status.columns:
            stock_status[col] = 0

    stock_status = stock_status.reset_index()
    stock_status['total_records'] = stock_status[['stockout', 'understock', 'overstock', 'normal']].sum(axis=1)
    stock_status['stockout_freq'] = (stock_status['stockout'] / stock_status['total_records'] * 100).round(2)
    stock_status['overstock_freq'] = (stock_status['overstock'] / stock_status['total_records'] * 100).round(2)
    stock_status['understock_freq'] = (stock_status['understock'] / stock_status['total_records'] * 100).round(2)

    # Merge semua fitur
    product_agg = sales_agg.merge(stock_agg, on='PFco_Code', how='left')
    product_agg = product_agg.merge(
        stock_status[['PFco_Code', 'stockout_freq', 'overstock_freq', 'understock_freq']],
        on='PFco_Code', how='left'
    )
    product_agg = product_agg.fillna(0)

    # Turnover ratio = total penjualan / (avg stok × jumlah bulan)
    product_agg['turnover_ratio'] = np.where(
        product_agg['avg_stok_akhir'] > 0,
        product_agg['total_qty'] / (product_agg['avg_stok_akhir'] * product_agg['total_months_data'].clip(lower=1)),
        0
    )

    # --- Standardize fitur untuk clustering ---
    cluster_features = [
        'total_qty', 'avg_qty_per_trx',
        'transaction_count', 'avg_stok_akhir', 'turnover_ratio',
        'stockout_freq', 'overstock_freq',
    ]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(product_agg[cluster_features])

    # --- Evaluasi k = 2 s/d 6 ---
    eval_results = []
    for k in range(2, 7):
        kmeans = KMeans(n_clusters=k, random_state=42, n_init=10)
        labels = kmeans.fit_predict(X_scaled)

        sil_score = silhouette_score(X_scaled, labels)
        db_score = davies_bouldin_score(X_scaled, labels)
        inertia = kmeans.inertia_

        eval_results.append({
            'k': k,
            'silhouette_score': round(sil_score, 4),
            'davies_bouldin_index': round(db_score, 4),
            'inertia': round(inertia, 2),
        })

        print(f"  k={k}: Silhouette={sil_score:.4f}, Davies-Bouldin={db_score:.4f}, Inertia={inertia:.2f}")

    # Simpan evaluasi clustering
    eval_df = pd.DataFrame(eval_results)
    eval_df.to_csv(OUTPUT_CLUSTERING_EVAL, index=False)
    print(f"\n  Saved clustering evaluation -> {OUTPUT_CLUSTERING_EVAL}")

    # --- Pilih k=3 sesuai proposal (fast/medium/slow moving) ---
    kmeans_final = KMeans(n_clusters=3, random_state=42, n_init=10)
    final_labels = kmeans_final.fit_predict(X_scaled)

    # Map cluster ke segmen berdasarkan total_qty (paling tinggi = fast moving)
    cluster_means = {}
    for c in range(3):
        mask = final_labels == c
        cluster_means[c] = product_agg.loc[mask, 'total_qty'].mean()

    sorted_clusters = sorted(cluster_means.keys(), key=lambda x: cluster_means[x], reverse=True)
    label_map = {
        sorted_clusters[0]: 'fast moving',
        sorted_clusters[1]: 'medium moving',
        sorted_clusters[2]: 'slow moving',
    }

    product_agg['cluster_id'] = final_labels
    product_agg['segment'] = [label_map[l] for l in final_labels]

    print(f"\n  Hasil Clustering (k=3):")
    for seg in ['fast moving', 'medium moving', 'slow moving']:
        count = (product_agg['segment'] == seg).sum()
        avg_qty = product_agg.loc[product_agg['segment'] == seg, 'total_qty'].mean()
        avg_turnover = product_agg.loc[product_agg['segment'] == seg, 'turnover_ratio'].mean()
        print(f"    {seg:15s}: {count:3d} produk | Avg Qty: {avg_qty:,.1f} Kg | Avg Turnover: {avg_turnover:.2f}")

    # Simpan hasil clustering
    output_cols = [
        'PFco_Code', 'segment', 'cluster_id',
        'total_qty', 'total_value', 'total_total_values',
        'transaction_count', 'avg_qty_per_trx', 'avg_value_per_trx',
        'unique_months', 'avg_stok_akhir', 'avg_safety_stock',
        'turnover_ratio', 'stockout_freq', 'overstock_freq', 'understock_freq',
    ]
    clustering_output = product_agg[output_cols].copy()
    clustering_output = clustering_output.round(2)
    clustering_output.to_csv(OUTPUT_CLUSTERING_RESULTS, index=False)
    print(f"\n  Saved clustering results -> {OUTPUT_CLUSTERING_RESULTS}")
    print()

    return product_agg


def train_random_forest(df_sales, df_stock, product_agg):
    """
    TUJUAN 2: Random Forest Regressor untuk prediksi kebutuhan stok kain
    pada periode tertentu dengan tingkat kesalahan yang rendah.

    Target: kebutuhan_stok = penjualan + safety_stock_buffer
    """
    print("=" * 60)
    print("STEP 3: RANDOM FOREST - PREDIKSI STOK (Tujuan 2)")
    print("Prediksi kebutuhan stok kain per periode")
    print("=" * 60)

    # --- Agregasi bulanan gabungan penjualan + stok ---
    monthly_sales = df_sales.groupby(['PFco_Code', 'year_month']).agg(
        monthly_qty=('QUANTITIES_Kgs', 'sum'),
        monthly_value=('VALUE', 'sum'),
        monthly_total_values=('Total_values', 'sum'),
        monthly_trx_count=('DATE', 'count'),
    ).reset_index()

    monthly_sales['year_month_str'] = monthly_sales['year_month'].astype(str)
    monthly_sales = monthly_sales.sort_values(['PFco_Code', 'year_month'])

    # Gabung dengan data stok
    df_stock['year_month_str'] = df_stock['tahun'].astype(str) + '-' + df_stock['bulan'].astype(str).str.zfill(2)
    stock_monthly = df_stock[['PFco_Code', 'year_month_str', 'stok_awal', 'stok_masuk',
                               'stok_akhir', 'safety_stock', 'status_stok']].copy()

    monthly = monthly_sales.merge(stock_monthly, on=['PFco_Code', 'year_month_str'], how='left')
    monthly = monthly.fillna(0)
    monthly = monthly.sort_values(['PFco_Code', 'year_month'])

    # --- Target: kebutuhan stok = penjualan + safety stock ---
    monthly['kebutuhan_stok'] = monthly['monthly_qty'] + monthly['safety_stock']

    # --- Feature Engineering ---
    # Lag features (1, 2, 3 bulan sebelumnya)
    for lag in [1, 2, 3]:
        monthly[f'qty_lag_{lag}'] = monthly.groupby('PFco_Code')['monthly_qty'].shift(lag)
        monthly[f'value_lag_{lag}'] = monthly.groupby('PFco_Code')['monthly_value'].shift(lag)
        monthly[f'stok_lag_{lag}'] = monthly.groupby('PFco_Code')['stok_akhir'].shift(lag)

    # Rolling average 3 bulan
    monthly['qty_rolling_3'] = monthly.groupby('PFco_Code')['monthly_qty'].transform(
        lambda x: x.rolling(3, min_periods=1).mean()
    )
    monthly['value_rolling_3'] = monthly.groupby('PFco_Code')['monthly_value'].transform(
        lambda x: x.rolling(3, min_periods=1).mean()
    )
    monthly['stok_rolling_3'] = monthly.groupby('PFco_Code')['stok_akhir'].transform(
        lambda x: x.rolling(3, min_periods=1).mean()
    )

    # Seasonality (bulan)
    monthly['month_num'] = monthly['year_month'].dt.month

    # Segment dari clustering
    seg_map = product_agg.set_index('PFco_Code')['segment'].to_dict()
    monthly['segment'] = monthly['PFco_Code'].map(seg_map)
    seg_encode = {'fast moving': 2, 'medium moving': 1, 'slow moving': 0}
    monthly['segment_code'] = monthly['segment'].map(seg_encode).fillna(0)

    # Turnover ratio dari clustering
    turnover_map = product_agg.set_index('PFco_Code')['turnover_ratio'].to_dict()
    monthly['turnover_ratio'] = monthly['PFco_Code'].map(turnover_map).fillna(0)

    # Drop NaN (dari lag features)
    monthly_clean = monthly.dropna().copy()

    # Hanya gunakan baris dengan penjualan > 0 untuk training yang lebih akurat
    monthly_train = monthly_clean[monthly_clean['monthly_qty'] > 0].copy()

    print(f"  Data bulanan total: {len(monthly)} baris")
    print(f"  Data setelah cleaning: {len(monthly_clean)} baris")
    print(f"  Data untuk training (qty > 0): {len(monthly_train)} baris")

    # --- Features & Target ---
    feature_cols = [
        'qty_lag_1', 'qty_lag_2', 'qty_lag_3',
        'stok_lag_1', 'stok_lag_2', 'stok_lag_3',
        'qty_rolling_3', 'stok_rolling_3',
        'month_num', 'segment_code', 'turnover_ratio',
        'safety_stock',
    ]

    X = monthly_train[feature_cols].values
    y = monthly_train['kebutuhan_stok'].values

    # --- Train/Test Split ---
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    print(f"  Training set: {len(X_train)} | Test set: {len(X_test)}")

    # --- Train Random Forest ---
    rf = RandomForestRegressor(
        n_estimators=150,
        max_depth=12,
        min_samples_split=5,
        min_samples_leaf=3,
        random_state=42,
        n_jobs=-1,
    )

    rf.fit(X_train, y_train)

    # --- Evaluasi Model ---
    y_pred = rf.predict(X_test)

    mae = mean_absolute_error(y_test, y_pred)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))

    # MAPE — hanya untuk y_test > 0 (hindari pembagian nol)
    mask_nz = y_test > 0
    if mask_nz.sum() > 0:
        mape = np.mean(np.abs((y_test[mask_nz] - y_pred[mask_nz]) / y_test[mask_nz])) * 100
    else:
        mape = 0.0

    r2 = rf.score(X_test, y_test)

    print(f"\n  === MODEL EVALUATION ===")
    print(f"  MAE  : {mae:.2f} Kg")
    print(f"  RMSE : {rmse:.2f} Kg")
    print(f"  MAPE : {mape:.2f}%")
    print(f"  R²   : {r2:.4f}")

    # Feature Importance
    importances = rf.feature_importances_
    feat_imp = pd.DataFrame({
        'feature': feature_cols,
        'importance': importances,
    }).sort_values('importance', ascending=False)

    print(f"\n  Feature Importance:")
    for _, row in feat_imp.iterrows():
        bar = "#" * int(row['importance'] * 50)
        print(f"    {row['feature']:20s} {row['importance']:.4f} {bar}")

    # --- Simpan evaluasi model ---
    eval_data = [
        {'metric': 'MAE', 'value': round(mae, 4), 'unit': 'Kg',
         'description': 'Mean Absolute Error - Rata-rata kesalahan absolut prediksi'},
        {'metric': 'RMSE', 'value': round(rmse, 4), 'unit': 'Kg',
         'description': 'Root Mean Squared Error - Akar rata-rata kuadrat kesalahan'},
        {'metric': 'MAPE', 'value': round(mape, 2), 'unit': '%',
         'description': 'Mean Absolute Percentage Error - Rata-rata persentase kesalahan'},
        {'metric': 'R2_Score', 'value': round(r2, 4), 'unit': '',
         'description': 'Koefisien determinasi - Seberapa baik model menjelaskan variasi data'},
        {'metric': 'N_Estimators', 'value': 150, 'unit': 'trees',
         'description': 'Jumlah pohon keputusan dalam Random Forest'},
        {'metric': 'Max_Depth', 'value': 12, 'unit': '',
         'description': 'Kedalaman maksimum setiap pohon keputusan'},
        {'metric': 'Min_Samples_Split', 'value': 5, 'unit': '',
         'description': 'Minimum sampel untuk split node'},
        {'metric': 'Min_Samples_Leaf', 'value': 3, 'unit': '',
         'description': 'Minimum sampel pada leaf node'},
        {'metric': 'Training_Samples', 'value': len(X_train), 'unit': 'rows',
         'description': 'Jumlah data latih (80% dari total)'},
        {'metric': 'Test_Samples', 'value': len(X_test), 'unit': 'rows',
         'description': 'Jumlah data uji (20% dari total)'},
        {'metric': 'Total_Features', 'value': len(feature_cols), 'unit': '',
         'description': 'Jumlah fitur yang digunakan'},
    ]

    # Feature importance
    for _, row in feat_imp.iterrows():
        eval_data.append({
            'metric': f'FI_{row["feature"]}',
            'value': round(row['importance'], 4),
            'unit': '',
            'description': f'Feature Importance: {row["feature"]}',
        })

    eval_df = pd.DataFrame(eval_data)
    eval_df.to_csv(OUTPUT_MODEL_EVAL, index=False)
    print(f"\n  Saved model evaluation -> {OUTPUT_MODEL_EVAL}")

    # --- Prediksi Stok per Produk (3 bulan ke depan) ---
    print(f"\n  Generating stock predictions...")

    predictions = []
    products = monthly_train['PFco_Code'].unique()

    for pcode in products:
        prod_data = monthly_train[monthly_train['PFco_Code'] == pcode].sort_values('year_month')

        if len(prod_data) < 3:
            continue

        last_row = prod_data.iloc[-1]

        # Prediksi 3 bulan ke depan secara iteratif
        pred_months = []
        current_features = last_row[feature_cols].values.reshape(1, -1).astype(float).copy()

        for m in range(3):
            pred = rf.predict(current_features)[0]
            pred = max(0, pred)
            pred_months.append(round(pred, 2))

            # Shift features untuk bulan berikutnya
            new_features = current_features.copy()
            # Shift qty lags
            new_features[0, 2] = new_features[0, 1]  # lag3 = old lag2
            new_features[0, 1] = new_features[0, 0]  # lag2 = old lag1
            new_features[0, 0] = pred                  # lag1 = prediction
            # Shift stok lags
            new_features[0, 5] = new_features[0, 4]  # lag3 = old lag2
            new_features[0, 4] = new_features[0, 3]  # lag2 = old lag1
            new_features[0, 3] = max(0, new_features[0, 3] - pred + pred * 1.1)  # estimasi stok lag1
            # Update rolling average qty
            new_features[0, 6] = (new_features[0, 0] + new_features[0, 1] + new_features[0, 2]) / 3
            # Update month
            current_month = int(new_features[0, 8])
            new_features[0, 8] = (current_month % 12) + 1

            current_features = new_features

        # Rata-rata actual kebutuhan stok (3 bulan terakhir)
        last_3 = prod_data.tail(3)['kebutuhan_stok']
        actual_avg = round(last_3.mean(), 2)

        # Evaluasi per produk
        prod_X = prod_data[feature_cols].values
        prod_y = prod_data['kebutuhan_stok'].values
        prod_pred = rf.predict(prod_X)
        prod_mae = round(mean_absolute_error(prod_y, prod_pred), 2)
        prod_rmse = round(np.sqrt(mean_squared_error(prod_y, prod_pred)), 2)

        mask_nz_prod = prod_y > 0
        if mask_nz_prod.sum() > 0:
            prod_mape = round(
                np.mean(np.abs((prod_y[mask_nz_prod] - prod_pred[mask_nz_prod]) / prod_y[mask_nz_prod])) * 100, 2
            )
        else:
            prod_mape = 0.0

        segment = seg_map.get(pcode, 'slow moving')
        safety = product_agg.loc[product_agg['PFco_Code'] == pcode, 'avg_safety_stock'].values
        safety_val = round(safety[0], 2) if len(safety) > 0 else 0.0

        predictions.append({
            'PFco_Code': pcode,
            'segment': segment,
            'predicted_qty_month1': pred_months[0],
            'predicted_qty_month2': pred_months[1],
            'predicted_qty_month3': pred_months[2],
            'actual_avg_need': actual_avg,
            'safety_stock': safety_val,
            'mae': prod_mae,
            'rmse': prod_rmse,
            'mape': prod_mape,
        })

    pred_df = pd.DataFrame(predictions)
    pred_df.to_csv(OUTPUT_STOCK_PRED, index=False)
    print(f"  Predictions for {len(predictions)} products saved -> {OUTPUT_STOCK_PRED}")
    print()

    return rf, pred_df, monthly_train, feature_cols


def generate_recommendations(product_agg, pred_df, df_stock):
    """
    TUJUAN 3: Evaluasi integrasi K-Means + Random Forest.
    Menyusun rekomendasi operasional untuk meminimalkan overstock dan understock.
    """
    print("=" * 60)
    print("STEP 4: REKOMENDASI OPERASIONAL (Tujuan 3)")
    print("Integrasi K-Means + Random Forest")
    print("=" * 60)

    # Ambil data stok terakhir per produk (3 bulan terakhir)
    df_stock_sorted = df_stock.sort_values(['PFco_Code', 'tahun', 'bulan'])
    latest_stock = df_stock_sorted.groupby('PFco_Code').tail(3)
    latest_avg = latest_stock.groupby('PFco_Code').agg(
        current_avg_stock=('stok_akhir', 'mean'),
        current_safety=('safety_stock', 'mean'),
        recent_avg_sales=('penjualan', 'mean'),
    ).reset_index().round(2)

    # Status stok terakhir
    last_status = df_stock_sorted.groupby('PFco_Code').tail(1)[['PFco_Code', 'status_stok', 'stok_akhir']]
    last_status.columns = ['PFco_Code', 'last_status', 'last_stok']

    # Merge clustering + prediction + stok
    reco = product_agg[['PFco_Code', 'segment', 'turnover_ratio',
                         'stockout_freq', 'overstock_freq']].copy()
    reco = reco.merge(latest_avg, on='PFco_Code', how='left')
    reco = reco.merge(last_status, on='PFco_Code', how='left')

    # Merge prediksi
    if not pred_df.empty:
        pred_subset = pred_df[['PFco_Code', 'predicted_qty_month1', 'predicted_qty_month2',
                                'predicted_qty_month3', 'actual_avg_need']].copy()
        pred_subset['avg_predicted_need'] = (
            pred_subset['predicted_qty_month1'] +
            pred_subset['predicted_qty_month2'] +
            pred_subset['predicted_qty_month3']
        ) / 3
        reco = reco.merge(pred_subset[['PFco_Code', 'avg_predicted_need']], on='PFco_Code', how='left')
    else:
        reco['avg_predicted_need'] = 0

    reco = reco.fillna(0)

    # --- Generate rekomendasi ---
    recommendations = []

    for _, row in reco.iterrows():
        pcode = row['PFco_Code']
        segment = row['segment']
        current_stock = row.get('current_avg_stock', 0)
        predicted_need = row.get('avg_predicted_need', 0)
        safety = row.get('current_safety', 0)
        turnover = row.get('turnover_ratio', 0)
        stockout_pct = row.get('stockout_freq', 0)
        overstock_pct = row.get('overstock_freq', 0)
        recent_sales = row.get('recent_avg_sales', 0)

        # Hitung selisih stok vs kebutuhan
        if predicted_need > 0:
            stock_ratio = current_stock / predicted_need
        else:
            stock_ratio = 2.0 if current_stock > 0 else 0.0

        # Tentukan risk category
        if stock_ratio > 1.8 or overstock_pct > 30:
            risk = 'overstock'
        elif stock_ratio < 0.5 or stockout_pct > 20:
            risk = 'understock'
        elif stock_ratio < 0.8 or stockout_pct > 10:
            risk = 'perlu_perhatian'
        else:
            risk = 'optimal'

        # Priority berdasarkan segment + risk
        if segment == 'fast moving':
            if risk in ['understock', 'perlu_perhatian']:
                priority = 'KRITIS'
            else:
                priority = 'TINGGI'
        elif segment == 'medium moving':
            if risk == 'understock':
                priority = 'TINGGI'
            else:
                priority = 'SEDANG'
        else:
            priority = 'RENDAH'

        # Generate aksi rekomendasi
        if risk == 'overstock':
            action = 'KURANGI STOK'
            suggestion = (
                f'Stok berlebih ({current_stock:.0f} Kg vs kebutuhan {predicted_need:.0f} Kg). '
                f'Kurangi pembelian dan pertimbangkan promosi/bundling untuk menghabiskan stok.'
            )
            restock_qty = max(0, round(predicted_need - current_stock, 2))
        elif risk == 'understock':
            action = 'TAMBAH STOK SEGERA'
            deficit = max(0, predicted_need - current_stock)
            suggestion = (
                f'Stok kurang ({current_stock:.0f} Kg vs kebutuhan {predicted_need:.0f} Kg). '
                f'Segera restock minimal {deficit:.0f} Kg + safety stock {safety:.0f} Kg.'
            )
            restock_qty = round(deficit + safety, 2)
        elif risk == 'perlu_perhatian':
            action = 'MONITOR & SIAPKAN'
            suggestion = (
                f'Stok mendekati batas minimum. Siapkan order pembelian '
                f'{predicted_need:.0f} Kg untuk periode berikutnya.'
            )
            restock_qty = round(predicted_need * 1.1, 2)
        else:
            action = 'PERTAHANKAN'
            suggestion = (
                f'Stok dalam kondisi optimal ({current_stock:.0f} Kg). '
                f'Pertahankan pola restocking saat ini.'
            )
            restock_qty = round(predicted_need, 2)

        recommendations.append({
            'PFco_Code': pcode,
            'segment': segment,
            'risk_category': risk,
            'priority': priority,
            'action': action,
            'current_stock_kg': round(current_stock, 2),
            'predicted_need_kg': round(predicted_need, 2),
            'safety_stock_kg': round(safety, 2),
            'restock_qty_kg': restock_qty,
            'turnover_ratio': round(turnover, 2),
            'stockout_pct': round(stockout_pct, 2),
            'overstock_pct': round(overstock_pct, 2),
            'suggestion': suggestion,
        })

    reco_df = pd.DataFrame(recommendations)
    reco_df.to_csv(OUTPUT_RECOMMENDATIONS, index=False)

    # Statistik ringkasan
    risk_counts = reco_df['risk_category'].value_counts()
    print(f"\n  Total produk: {len(reco_df)}")
    print(f"  Distribusi risiko:")
    for risk, count in risk_counts.items():
        pct = count / len(reco_df) * 100
        icon = {'overstock': '[OVR]', 'understock': '[UND]', 'perlu_perhatian': '[ATT]', 'optimal': '[OK]'}.get(risk, '')
        print(f"    {icon} {risk:18s}: {count:3d} produk ({pct:.1f}%)")

    # Per segmen
    print(f"\n  Rekomendasi per segmen:")
    for seg in ['fast moving', 'medium moving', 'slow moving']:
        seg_data = reco_df[reco_df['segment'] == seg]
        if len(seg_data) > 0:
            print(f"\n    [{seg.upper()}] ({len(seg_data)} produk)")
            seg_risk = seg_data['risk_category'].value_counts()
            for r, c in seg_risk.items():
                print(f"      {r}: {c}")

    print(f"\n  Saved -> {OUTPUT_RECOMMENDATIONS}")
    print()

    return reco_df


def main():
    print("\n" + "=" * 60)
    print("  ML PIPELINE - TOKO KURNIA")
    print("  K-Means Clustering + Random Forest Prediction")
    print("  Sesuai Tujuan Penelitian Proposal Capstone")
    print("=" * 60 + "\n")

    # 1. Load data
    df_sales, df_stock = load_data()

    # 2. K-Means Clustering (Tujuan 1)
    product_agg = perform_clustering(df_sales, df_stock)

    # 3. Random Forest Prediction (Tujuan 2)
    rf, pred_df, monthly_data, feature_cols = train_random_forest(df_sales, df_stock, product_agg)

    # 4. Rekomendasi Operasional (Tujuan 3)
    reco_df = generate_recommendations(product_agg, pred_df, df_stock)

    print("=" * 60)
    print("  PIPELINE COMPLETE!")
    print("=" * 60)
    print(f"  Output files:")
    print(f"    1. {OUTPUT_CLUSTERING_RESULTS}")
    print(f"    2. {OUTPUT_CLUSTERING_EVAL}")
    print(f"    3. {OUTPUT_STOCK_PRED}")
    print(f"    4. {OUTPUT_MODEL_EVAL}")
    print(f"    5. {OUTPUT_RECOMMENDATIONS}")
    print()


if __name__ == '__main__':
    main()
