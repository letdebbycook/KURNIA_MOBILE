import 'dart:convert';
import 'package:http/http.dart' as http;

class OngkirService {
  final String _apiKey = 'EdFOOvhB92cf0494162cd288WLkbEppN';
  final String _baseUrl = 'https://api.rajaongkir.com/starter';

  // Asal Pengiriman: DKI Jakarta (Jakarta Pusat) - ID Kota: 152
  final String originCityId = '152';
  final String originCityName = 'Jakarta Pusat';

  /// Mendapatkan daftar Provinsi
  Future<List<Map<String, String>>> getProvinces() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/province'),
        headers: {
          'key': _apiKey,
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['rajaongkir']['results'] as List<dynamic>;
        return results.map((e) => {
          'id': e['province_id'].toString(),
          'name': e['province'].toString(),
        }).toList();
      }
    } catch (_) {}

    // Graceful fallback jika kena CORS di Web local atau kuota habis
    return fallbackProvinces;
  }

  /// Mendapatkan daftar Kota/Kabupaten berdasarkan ID Provinsi
  Future<List<Map<String, String>>> getCities(String provinceId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/city?province=$provinceId'),
        headers: {
          'key': _apiKey,
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['rajaongkir']['results'] as List<dynamic>;
        return results.map((e) => {
          'id': e['city_id'].toString(),
          'province_id': e['province_id'].toString(),
          'name': '${e['type']} ${e['city_name']}',
        }).toList();
      }
    } catch (_) {}

    // Fallback kota lokal berdasarkan provinsi
    return fallbackCities
        .where((city) => city['province_id'] == provinceId)
        .toList();
  }

  /// Menghitung ongkir real-time
  /// [destinationCityId]: ID Kota tujuan
  /// [weightInGrams]: Berat total paket dalam gram
  /// [courier]: Kode kurir ('jne', 'pos', 'tiki')
  Future<List<Map<String, dynamic>>> getShippingCost({
    required String destinationCityId,
    required int weightInGrams,
    required String courier,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/cost'),
        headers: {
          'key': _apiKey,
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: {
          'origin': originCityId,
          'destination': destinationCityId,
          'weight': weightInGrams.toString(),
          'courier': courier.toLowerCase(),
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['rajaongkir']['results'] as List<dynamic>;
        
        if (results.isNotEmpty) {
          final costsList = results[0]['costs'] as List<dynamic>;
          return costsList.map((e) {
            final costDetails = e['cost'][0];
            return {
              'service': e['service'].toString(),
              'description': e['description'].toString(),
              'cost': double.parse(costDetails['value'].toString()),
              'etd': costDetails['etd'].toString(), // Estimasi hari pengiriman
            };
          }).toList();
        }
      }
    } catch (_) {}

    // Fallback jika API gagal (simulasi harga yang wajar berdasarkan kurir & berat)
    final weightKg = weightInGrams / 1000.0;
    double baseRate = 15000.0;
    
    if (courier.toLowerCase() == 'jne') {
      baseRate = 18000.0;
    } else if (courier.toLowerCase() == 'tiki') {
      baseRate = 16000.0;
    }

    final calculatedCost = (baseRate * weightKg).roundToDouble();

    return [
      {
        'service': 'REG',
        'description': 'Layanan Reguler (Simulasi)',
        'cost': calculatedCost,
        'etd': '2-4 HARI',
      },
      {
        'service': 'OKE',
        'description': 'Layanan Ekonomis (Simulasi)',
        'cost': (calculatedCost * 0.8).roundToDouble(),
        'etd': '4-7 HARI',
      }
    ];
  }

  // ==========================================
  // STATIC FALLBACK DATA (34 PROVINCES & CITIES)
  // ==========================================
  
  static const List<Map<String, String>> fallbackProvinces = [
    {'id': '1', 'name': 'Bali'},
    {'id': '2', 'name': 'Bangka Belitung'},
    {'id': '3', 'name': 'Banten'},
    {'id': '4', 'name': 'Bengkulu'},
    {'id': '5', 'name': 'DI Yogyakarta'},
    {'id': '6', 'name': 'DKI Jakarta'},
    {'id': '7', 'name': 'Gorontalo'},
    {'id': '8', 'name': 'Jambi'},
    {'id': '9', 'name': 'Jawa Barat'},
    {'id': '10', 'name': 'Jawa Tengah'},
    {'id': '11', 'name': 'Jawa Timur'},
    {'id': '12', 'name': 'Kalimantan Barat'},
    {'id': '13', 'name': 'Kalimantan Selatan'},
    {'id': '14', 'name': 'Kalimantan Tengah'},
    {'id': '15', 'name': 'Kalimantan Timur'},
    {'id': '16', 'name': 'Kalimantan Utara'},
    {'id': '17', 'name': 'Kepulauan Riau'},
    {'id': '18', 'name': 'Lampung'},
    {'id': '19', 'name': 'Maluku'},
    {'id': '20', 'name': 'Maluku Utara'},
    {'id': '21', 'name': 'Nanggroe Aceh Darussalam (NAD)'},
    {'id': '22', 'name': 'Nusa Tenggara Barat (NTB)'},
    {'id': '23', 'name': 'Nusa Tenggara Timur (NTT)'},
    {'id': '24', 'name': 'Papua'},
    {'id': '25', 'name': 'Papua Barat'},
    {'id': '26', 'name': 'Riau'},
    {'id': '27', 'name': 'Sulawesi Barat'},
    {'id': '28', 'name': 'Sulawesi Selatan'},
    {'id': '29', 'name': 'Sulawesi Tengah'},
    {'id': '30', 'name': 'Sulawesi Tenggara'},
    {'id': '31', 'name': 'Sulawesi Utara'},
    {'id': '32', 'name': 'Sumatera Barat'},
    {'id': '33', 'name': 'Sumatera Selatan'},
    {'id': '34', 'name': 'Sumatera Utara'},
  ];

  static const List<Map<String, String>> fallbackCities = [
    // Bali (1)
    {'id': '17', 'province_id': '1', 'name': 'Kabupaten Badung'},
    {'id': '114', 'province_id': '1', 'name': 'Kota Denpasar'},
    {'id': '447', 'province_id': '1', 'name': 'Kabupaten Tabanan'},
    // Bangka Belitung (2)
    {'id': '27', 'province_id': '2', 'name': 'Kabupaten Bangka'},
    {'id': '333', 'province_id': '2', 'name': 'Kota Pangkal Pinang'},
    // Banten (3)
    {'id': '106', 'province_id': '3', 'name': 'Kota Cilegon'},
    {'id': '418', 'province_id': '3', 'name': 'Kota Serang'},
    {'id': '455', 'province_id': '3', 'name': 'Kota Tangerang'},
    {'id': '457', 'province_id': '3', 'name': 'Kota Tangerang Selatan'},
    // Bengkulu (4)
    {'id': '67', 'province_id': '4', 'name': 'Kota Bengkulu'},
    // DI Yogyakarta (5)
    {'id': '39', 'province_id': '5', 'name': 'Kabupaten Bantul'},
    {'id': '135', 'province_id': '5', 'name': 'Kabupaten Gunung Kidul'},
    {'id': '419', 'province_id': '5', 'name': 'Kabupaten Sleman'},
    {'id': '501', 'province_id': '5', 'name': 'Kota Yogyakarta'},
    // DKI Jakarta (6)
    {'id': '151', 'province_id': '6', 'name': 'Kota Jakarta Barat'},
    {'id': '152', 'province_id': '6', 'name': 'Kota Jakarta Pusat'},
    {'id': '153', 'province_id': '6', 'name': 'Kota Jakarta Selatan'},
    {'id': '154', 'province_id': '6', 'name': 'Kota Jakarta Timur'},
    {'id': '155', 'province_id': '6', 'name': 'Kota Jakarta Utara'},
    // Gorontalo (7)
    {'id': '129', 'province_id': '7', 'name': 'Kota Gorontalo'},
    // Jambi (8)
    {'id': '156', 'province_id': '8', 'name': 'Kota Jambi'},
    // Jawa Barat (9)
    {'id': '23', 'province_id': '9', 'name': 'Kota Bandung'},
    {'id': '24', 'province_id': '9', 'name': 'Kabupaten Bandung Barat'},
    {'id': '54', 'province_id': '9', 'name': 'Kota Bekasi'},
    {'id': '78', 'province_id': '9', 'name': 'Kota Bogor'},
    {'id': '107', 'province_id': '9', 'name': 'Kota Cimahi'},
    {'id': '109', 'province_id': '9', 'name': 'Kota Cirebon'},
    {'id': '115', 'province_id': '9', 'name': 'Kota Depok'},
    {'id': '133', 'province_id': '9', 'name': 'Kabupaten Garut'},
    {'id': '171', 'province_id': '9', 'name': 'Kabupaten Karawang'},
    {'id': '431', 'province_id': '9', 'name': 'Kota Sukabumi'},
    {'id': '468', 'province_id': '9', 'name': 'Kota Tasikmalaya'},
    // Jawa Tengah (10)
    {'id': '92', 'province_id': '10', 'name': 'Kabupaten Boyolali'},
    {'id': '249', 'province_id': '10', 'name': 'Kabupaten Kudus'},
    {'id': '272', 'province_id': '10', 'name': 'Kabupaten Magelang'},
    {'id': '346', 'province_id': '10', 'name': 'Kota Pekalongan'},
    {'id': '399', 'province_id': '10', 'name': 'Kota Salatiga'},
    {'id': '427', 'province_id': '10', 'name': 'Kota Semarang'},
    {'id': '445', 'province_id': '10', 'name': 'Kota Surakarta'},
    {'id': '467', 'province_id': '10', 'name': 'Kota Tegal'},
    // Jawa Timur (11)
    {'id': '42', 'province_id': '11', 'name': 'Kota Batu'},
    {'id': '74', 'province_id': '11', 'name': 'Kota Blitar'},
    {'id': '138', 'province_id': '11', 'name': 'Kabupaten Gresik'},
    {'id': '165', 'province_id': '11', 'name': 'Kabupaten Jember'},
    {'id': '178', 'province_id': '11', 'name': 'Kota Kediri'},
    {'id': '255', 'province_id': '11', 'name': 'Kota Madiun'},
    {'id': '278', 'province_id': '11', 'name': 'Kota Malang'},
    {'id': '289', 'province_id': '11', 'name': 'Kota Mojokerto'},
    {'id': '342', 'province_id': '11', 'name': 'Kota Pasuruan'},
    {'id': '363', 'province_id': '11', 'name': 'Kota Probolinggo'},
    {'id': '409', 'province_id': '11', 'name': 'Kabupaten Sidoarjo'},
    {'id': '444', 'province_id': '11', 'name': 'Kota Surabaya'},
    // Kalimantan Barat (12)
    {'id': '360', 'province_id': '12', 'name': 'Kota Pontianak'},
    {'id': '429', 'province_id': '12', 'name': 'Kota Singkawang'},
    // Kalimantan Selatan (13)
    {'id': '36', 'province_id': '13', 'name': 'Kota Banjarbaru'},
    {'id': '37', 'province_id': '13', 'name': 'Kota Banjarmasin'},
    // Kalimantan Tengah (14)
    {'id': '326', 'province_id': '14', 'name': 'Kota Palangka Raya'},
    // Kalimantan Timur (15)
    {'id': '35', 'province_id': '15', 'name': 'Kota Balikpapan'},
    {'id': '79', 'province_id': '15', 'name': 'Kota Bontang'},
    {'id': '387', 'province_id': '15', 'name': 'Kota Samarinda'},
    // Kalimantan Utara (16)
    {'id': '466', 'province_id': '16', 'name': 'Kota Tarakan'},
    // Kepulauan Riau (17)
    {'id': '48', 'province_id': '17', 'name': 'Kota Batam'},
    {'id': '462', 'province_id': '17', 'name': 'Kota Tanjung Pinang'},
    // Lampung (18)
    {'id': '32', 'province_id': '18', 'name': 'Kota Bandar Lampung'},
    {'id': '286', 'province_id': '18', 'name': 'Kota Metro'},
    // Maluku (19)
    {'id': '13', 'province_id': '19', 'name': 'Kota Ambon'},
    // Maluku Utara (20)
    {'id': '470', 'province_id': '20', 'name': 'Kota Ternate'},
    // Nanggroe Aceh Darussalam (21)
    {'id': '33', 'province_id': '21', 'name': 'Kota Banda Aceh'},
    {'id': '265', 'province_id': '21', 'name': 'Kota Lhokseumawe'},
    {'id': '397', 'province_id': '21', 'name': 'Kota Sabang'},
    // Nusa Tenggara Barat (22)
    {'id': '64', 'province_id': '22', 'name': 'Kota Bima'},
    {'id': '282', 'province_id': '22', 'name': 'Kota Mataram'},
    // Nusa Tenggara Timur (23)
    {'id': '248', 'province_id': '23', 'name': 'Kota Kupang'},
    // Papua (24)
    {'id': '160', 'province_id': '24', 'name': 'Kota Jayapura'},
    // Papua Barat (25)
    {'id': '437', 'province_id': '25', 'name': 'Kota Sorong'},
    // Riau (26)
    {'id': '124', 'province_id': '26', 'name': 'Kota Dumai'},
    {'id': '350', 'province_id': '26', 'name': 'Kota Pekanbaru'},
    // Sulawesi Barat (27)
    {'id': '276', 'province_id': '27', 'name': 'Kota Mamuju'},
    // Sulawesi Selatan (28)
    {'id': '273', 'province_id': '28', 'name': 'Kota Makassar'},
    {'id': '328', 'province_id': '28', 'name': 'Kota Palopo'},
    {'id': '335', 'province_id': '28', 'name': 'Kota Parepare'},
    // Sulawesi Tengah (29)
    {'id': '329', 'province_id': '29', 'name': 'Kota Palu'},
    // Sulawesi Tenggara (30)
    {'id': '187', 'province_id': '30', 'name': 'Kota Kendari'},
    // Sulawesi Utara (31)
    {'id': '72', 'province_id': '31', 'name': 'Kota Bitung'},
    {'id': '279', 'province_id': '31', 'name': 'Kota Manado'},
    {'id': '477', 'province_id': '31', 'name': 'Kota Tomohon'},
    // Sumatera Barat (32)
    {'id': '318', 'province_id': '32', 'name': 'Kota Padang'},
    {'id': '321', 'province_id': '32', 'name': 'Kota Padang Panjang'},
    {'id': '334', 'province_id': '32', 'name': 'Kota Pariaman'},
    {'id': '345', 'province_id': '32', 'name': 'Kota Payakumbuh'},
    // Sumatera Selatan (33)
    {'id': '269', 'province_id': '33', 'name': 'Kota Lubuk Linggau'},
    {'id': '327', 'province_id': '33', 'name': 'Kota Palembang'},
    {'id': '362', 'province_id': '33', 'name': 'Kota Prabumulih'},
    // Sumatera Utara (34)
    {'id': '68', 'province_id': '34', 'name': 'Kota Binjai'},
    {'id': '281', 'province_id': '34', 'name': 'Kota Medan'},
    {'id': '330', 'province_id': '34', 'name': 'Kota Pematang Siantar'},
    {'id': '408', 'province_id': '34', 'name': 'Kota Sibolga'},
    {'id': '465', 'province_id': '34', 'name': 'Kota Tanjung Balai'},
    {'id': '469', 'province_id': '34', 'name': 'Kota Tebing Tinggi'},
  ];
}
