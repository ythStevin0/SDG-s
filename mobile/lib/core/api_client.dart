import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'engine.dart';
import 'formatters.dart';
import 'models.dart';

class ApiClient {
  String baseUrl;
  String? token;
  bool offlineFallbackMode = false;

  ApiClient({required this.baseUrl, this.token});

  // Dukungan URL backend publik via --dart-define=API_BASE_URL serta jembatan 10.0.2.2 untuk emulator.
  static String defaultBaseUrl() {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) return 'http://localhost:8080';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  final OfflineDemoStore _offline = OfflineDemoStore();

  String _idemKey() =>
      'idem-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(999999)}';

  Map<String, String> _headers({bool withIdempotency = false}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'X-Request-ID': 'mob-${DateTime.now().millisecondsSinceEpoch}',
    };
    if (token != null && token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    if (withIdempotency) {
      h['Idempotency-Key'] = _idemKey();
    }
    return h;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$cleanBase$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> getJson(String path, [Map<String, String>? query]) async {
    final resp = await http
        .get(_uri(path, query), headers: _headers())
        .timeout(const Duration(seconds: 6));
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      throw Exception(decoded['error'] ?? 'Permintaan gagal (${resp.statusCode})');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool idempotent = false,
  }) async {
    final resp = await http
        .post(
          _uri(path),
          headers: _headers(withIdempotency: idempotent),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      throw Exception(decoded['error'] ?? 'Permintaan gagal (${resp.statusCode})');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body) async {
    final resp = await http
        .put(_uri(path), headers: _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 8));
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      throw Exception(decoded['error'] ?? 'Permintaan gagal (${resp.statusCode})');
    }
    return decoded;
  }

  Future<void> deleteJson(String path) async {
    final resp = await http
        .delete(_uri(path), headers: _headers())
        .timeout(const Duration(seconds: 6));
    if (resp.statusCode >= 400) {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(decoded['error'] ?? 'Gagal menghapus');
    }
  }

  Future<Map<String, dynamic>> checkHealth() async {
    if (offlineFallbackMode) {
      return {
        'status': 'offline_standalone',
        'architecture': 'Mode Simulasi Offline Mandiri (Dart Engine)',
        'counts': {'users': 5, 'commodities': _offline.commodities.length, 'warehouses': 4, 'demands': 4},
      };
    }
    try {
      return await getJson('/api/v1/health');
    } catch (_) {
      offlineFallbackMode = true;
      return {
        'status': 'offline_standalone',
        'architecture': 'Mode Simulasi Offline Mandiri (Server lokal tidak terjangkau)',
        'counts': {'users': 5, 'commodities': _offline.commodities.length, 'warehouses': 4, 'demands': 4},
      };
    }
  }

  Future<({String token, UserProfile user})> demoLogin(String preset) async {
    if (!offlineFallbackMode) {
      try {
        final res = await postJson('/api/v1/auth/demo', {'preset': preset});
        final tok = res['token'].toString();
        final usr = UserProfile.fromJson((res['user'] as Map).cast<String, dynamic>());
        token = tok;
        return (token: tok, user: usr);
      } catch (_) {
        offlineFallbackMode = true;
      }
    }
    final usr = _offline.demoLogin(preset);
    token = 'offline-${usr.id}';
    return (token: token!, user: usr);
  }

  Future<({String token, UserProfile user})> login(String email, String password) async {
    if (offlineFallbackMode) {
      final usr = _offline.loginByEmail(email, password);
      token = 'offline-${usr.id}';
      return (token: token!, user: usr);
    }
    final res = await postJson('/api/v1/auth/login', {'email': email, 'password': password});
    final tok = res['token'].toString();
    final usr = UserProfile.fromJson((res['user'] as Map).cast<String, dynamic>());
    token = tok;
    return (token: tok, user: usr);
  }

  Future<({String token, UserProfile user})> register({
    required String email,
    required String password,
    required String nama,
    required String role,
    required String kabupaten,
  }) async {
    if (offlineFallbackMode) {
      final usr = _offline.register(email: email, nama: nama, role: role, kabupaten: kabupaten);
      token = 'offline-${usr.id}';
      return (token: token!, user: usr);
    }
    final res = await postJson('/api/v1/auth/register', {
      'email': email,
      'password': password,
      'nama': nama,
      'role': role,
      'kabupaten': kabupaten,
    });
    final tok = res['token'].toString();
    final usr = UserProfile.fromJson((res['user'] as Map).cast<String, dynamic>());
    token = tok;
    return (token: tok, user: usr);
  }

  Future<List<CommodityModel>> fetchCommodities() async {
    if (offlineFallbackMode) return _offline.commodities;
    try {
      final res = await getJson('/api/v1/commodities');
      return (res['commodities'] as List)
          .map((e) => CommodityModel.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      offlineFallbackMode = true;
      return _offline.commodities;
    }
  }

  Future<({List<PricePoint> series, ForecastOutput forecast, int latestPrice, CommodityModel commodity})>
      fetchPrices(String commodityKode) async {
    if (!offlineFallbackMode) {
      try {
        final res = await getJson('/api/v1/prices', {'commodity': commodityKode});
        final series = (res['series'] as List)
            .map((e) => PricePoint.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        final fc = ForecastOutput.fromJson((res['forecast'] as Map).cast<String, dynamic>());
        final comm = CommodityModel.fromJson((res['commodity'] as Map).cast<String, dynamic>());
        final latest = (res['latestPrice'] as num).round();
        return (series: series, forecast: fc, latestPrice: latest, commodity: comm);
      } catch (_) {
        offlineFallbackMode = true;
      }
    }
    return _offline.pricesFor(commodityKode);
  }

  Future<Map<String, dynamic>> fetchImpact() async {
    if (!offlineFallbackMode) {
      try {
        return await getJson('/api/v1/impact');
      } catch (_) {
        offlineFallbackMode = true;
      }
    }
    return _offline.impactSummary();
  }

  Future<List<StockItem>> fetchStocks(String userId) async {
    if (offlineFallbackMode) return _offline.stocksFor(userId);
    final res = await getJson('/api/v1/stocks');
    return (res['stocks'] as List)
        .map((e) => StockItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> createStock(String userId, Map<String, dynamic> payload) async {
    if (offlineFallbackMode) {
      _offline.addStock(userId, payload);
      return;
    }
    await postJson('/api/v1/stocks', payload, idempotent: true);
  }

  Future<void> deleteStock(String stockId) async {
    if (offlineFallbackMode) {
      _offline.deleteStock(stockId);
      return;
    }
    await deleteJson('/api/v1/stocks/$stockId');
  }

  Future<Map<String, dynamic>> evaluateStockDecision(
    StockItem stock,
    Map<String, dynamic> params,
  ) async {
    if (!offlineFallbackMode) {
      return await postJson('/api/v1/stocks/${stock.id}/decide', params);
    }
    return _offline.evaluateStock(stock, params);
  }

  Future<List<WarehouseItem>> fetchWarehouses({
    required String commodity,
    required String kabupaten,
    required double qtyKg,
    bool onlySrg = false,
    bool mine = false,
    String? ownerId,
  }) async {
    if (offlineFallbackMode) {
      return _offline.listWarehouses(
        commodity: commodity,
        kabupaten: kabupaten,
        qtyKg: qtyKg,
        onlySrg: onlySrg,
        mine: mine,
        ownerId: ownerId,
      );
    }
    final res = await getJson('/api/v1/warehouses', {
      'commodity': commodity,
      'kabupaten': kabupaten,
      'qtyKg': qtyKg.toStringAsFixed(0),
      if (onlySrg) 'onlySrg': 'true',
      if (mine) 'mine': 'true',
    });
    return (res['warehouses'] as List)
        .map((e) => WarehouseItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> updateWarehouse(String id, Map<String, dynamic> payload) async {
    if (offlineFallbackMode) {
      _offline.updateWarehouse(id, payload);
      return;
    }
    await putJson('/api/v1/warehouses/$id', payload);
  }

  Future<List<GroupItem>> fetchGroups(String userId) async {
    if (offlineFallbackMode) return _offline.groupsFor(userId);
    final res = await getJson('/api/v1/groups');
    return (res['groups'] as List)
        .map((e) => GroupItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> joinGroup(String userId, String kodeGabung) async {
    if (offlineFallbackMode) {
      _offline.joinGroup(userId, kodeGabung);
      return;
    }
    await postJson('/api/v1/groups/join', {'kodeGabung': kodeGabung});
  }

  Future<void> createGroup(String userId, String userNama, String nama, String kabupaten) async {
    if (offlineFallbackMode) {
      _offline.createGroup(userId, userNama, nama, kabupaten);
      return;
    }
    await postJson('/api/v1/groups', {'nama': nama, 'kabupaten': kabupaten}, idempotent: true);
  }

  Future<List<LotItem>> fetchLots(String userId) async {
    if (offlineFallbackMode) return _offline.lotsFor(userId);
    final res = await getJson('/api/v1/lots');
    return (res['lots'] as List)
        .map((e) => LotItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> createLot(String groupId, String commodityKode, double targetKg) async {
    if (offlineFallbackMode) {
      _offline.createLot(groupId, commodityKode, targetKg);
      return;
    }
    await postJson(
      '/api/v1/lots',
      {'groupId': groupId, 'commodityKode': commodityKode, 'targetKg': targetKg},
      idempotent: true,
    );
  }

  Future<void> contributeLot(String userId, String userNama, String lotId, String stockId, double qtyKg) async {
    if (offlineFallbackMode) {
      _offline.contributeLot(userId, userNama, lotId, stockId, qtyKg);
      return;
    }
    await postJson(
      '/api/v1/lots/$lotId/contribute',
      {'stockId': stockId, 'qtyKg': qtyKg},
      idempotent: true,
    );
  }

  Future<List<RentalItem>> fetchRentals(String userId, String role) async {
    if (offlineFallbackMode) return _offline.rentals;
    final res = await getJson('/api/v1/rentals');
    return (res['rentals'] as List)
        .map((e) => RentalItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> submitRental(UserProfile user, Map<String, dynamic> payload) async {
    if (offlineFallbackMode) {
      _offline.submitRental(user, payload);
      return;
    }
    await postJson('/api/v1/rentals', payload, idempotent: true);
  }

  Future<void> respondRental(String requestId, String action, [String? reason]) async {
    if (offlineFallbackMode) {
      _offline.respondRental(requestId, action);
      return;
    }
    await postJson('/api/v1/rentals/$requestId/respond', {
      'action': action,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<List<DemandItem>> fetchDemands({String? commodity, bool mine = false, String? buyerId}) async {
    if (offlineFallbackMode) return _offline.listDemands(commodity: commodity, mine: mine, buyerId: buyerId);
    final res = await getJson('/api/v1/demands', {
      if (commodity != null && commodity.isNotEmpty) 'commodity': commodity,
      if (mine) 'mine': 'true',
    });
    return (res['demands'] as List)
        .map((e) => DemandItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> createDemand(UserProfile user, Map<String, dynamic> payload) async {
    if (offlineFallbackMode) {
      _offline.createDemand(user, payload);
      return;
    }
    await postJson('/api/v1/demands', payload, idempotent: true);
  }

  Future<List<SaleItem>> fetchSales() async {
    if (offlineFallbackMode) return _offline.sales;
    final res = await getJson('/api/v1/sales');
    return (res['sales'] as List)
        .map((e) => SaleItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> submitSale(UserProfile user, Map<String, dynamic> payload) async {
    if (offlineFallbackMode) {
      _offline.submitSale(user, payload);
      return;
    }
    await postJson('/api/v1/sales', payload, idempotent: true);
  }

  Future<void> respondSale(String offerId, String action, [String? reason]) async {
    if (offlineFallbackMode) {
      _offline.respondSale(offerId, action);
      return;
    }
    await postJson('/api/v1/sales/$offerId/respond', {
      'action': action,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> adminCreateCommodity(Map<String, dynamic> payload) async {
    if (offlineFallbackMode) {
      _offline.addCommodity(payload);
      return;
    }
    await postJson('/api/v1/admin/commodities', payload);
  }

  Future<Map<String, dynamic>> explainAI(Map<String, dynamic> payload) async {
    if (!offlineFallbackMode) {
      try {
        final res = await postJson('/api/v1/ai/explain', payload);
        return (res['explanation'] as Map).cast<String, dynamic>();
      } catch (_) {}
    }
    final rec = (payload['rekomendasi'] ?? 'JUAL').toString();
    final weeks = (payload['horizonMinggu'] as num? ?? 8).toInt();
    final be = formatIntId((payload['titikImpasPerKg'] as num? ?? 5500));
    final biaya = formatIntId((payload['totalBiayaSimpan'] as num? ?? 1200000));
    final selisih = formatIntId(((payload['selisihRp'] as num? ?? 0)).abs());
    return {
      'ringkasan': rec == 'JUAL'
          ? 'Sebaiknya jual sekarang karena perkiraan kenaikan harga belum menutup biaya simpan (Rp$biaya).'
          : 'Disarankan menahan selama $weeks minggu dengan potensi tambahan hasil Rp$selisih bila harga minimal Rp$be/kg.',
      'alasan': [
        'Titik impas harga jual setelah simpan adalah Rp$be/kg.',
        'Total biaya simpan, angkut, susut, dan bunga tercatat Rp$biaya.',
      ],
      'langkah_berikut': rec == 'JUAL'
          ? ['Buka tab Janji Beli untuk memilih pembeli siaga.', 'Pastikan harga tawar di atas harga pasar.']
          : ['Cek kesiapan kadar air stok panen.', 'Cari gudang terdekat atau gabung Lot Kolektif poktan.'],
      'peringatan': rec == 'TAHAN_BERISIKO'
          ? 'Prediksi masih memiliki risiko turun di batas bawah. Pantau harga mingguan.'
          : null,
      'fallback_used': true,
    };
  }

  Future<Map<String, dynamic>> extractWaOffer(String rawText) async {
    if (!offlineFallbackMode) {
      try {
        final res = await postJson('/api/v1/ai/extract', {'rawText': rawText});
        return (res['extracted'] as Map).cast<String, dynamic>();
      } catch (_) {}
    }
    final priceMatch = RegExp(r'Rp\.?\s*([\d.,]+)\s*(rb|ribu|jt|juta)?', caseSensitive: false)
        .firstMatch(rawText);
    int? perKg;
    int? borongan;
    if (priceMatch != null) {
      final rawNum = priceMatch.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      final base = double.tryParse(rawNum) ?? 0;
      final unit = (priceMatch.group(2) ?? '').toLowerCase();
      final mult = (unit == 'jt' || unit == 'juta')
          ? 1000000
          : (unit == 'rb' || unit == 'ribu')
              ? 1000
              : 1;
      final val = (base * mult).round();
      if (val >= 100 && val <= 200000) {
        perKg = val;
      } else if (val > 200000) {
        borongan = val;
      }
    }
    return {
      'jenis': RegExp(r'panjar|ijon|tebas', caseSensitive: false).hasMatch(rawText)
          ? 'panjar'
          : 'pembelian',
      'harga_per_kg': perKg,
      'harga_total_borongan': borongan,
      'fallback_used': true,
    };
  }
}

// Penyimpanan status lokal saat APK dijalankan mandiri tanpa koneksi server.
class OfflineDemoStore {
  final List<UserProfile> users = [
    const UserProfile(
      id: 'u-petani',
      email: 'petani@demo.id',
      role: 'petani',
      nama: 'Pak Slamet',
      noWa: '6281234567801',
      kabupaten: 'Banyumas',
      isDemo: true,
    ),
    const UserProfile(
      id: 'u-poktan',
      email: 'poktan@demo.id',
      role: 'petani',
      nama: 'Bu Rini (Ketua Poktan)',
      noWa: '6281234567802',
      kabupaten: 'Banyumas',
      namaOrg: 'Poktan Tani Jaya',
      isDemo: true,
    ),
    const UserProfile(
      id: 'u-gudang',
      email: 'gudang@demo.id',
      role: 'gudang',
      nama: 'Pak Joko (Pengelola SRG)',
      noWa: '6281234567803',
      kabupaten: 'Banyumas',
      namaOrg: 'Gudang SRG Banyumas',
      isDemo: true,
    ),
    const UserProfile(
      id: 'u-pembeli',
      email: 'pembeli@demo.id',
      role: 'pembeli',
      nama: 'Koperasi & SPPG Mitra Banyumas',
      noWa: '6281234567804',
      kabupaten: 'Banyumas',
      namaOrg: 'Koperasi Pangan Banyumas (Mitra SPPG)',
      tipePembeli: 'sppg',
      isDemo: true,
    ),
    const UserProfile(
      id: 'u-admin',
      email: 'admin@demo.id',
      role: 'admin',
      nama: 'Admin SimpanJual',
      noWa: '6281234567805',
      kabupaten: 'Banyumas',
      isDemo: true,
    ),
  ];

  late List<CommodityModel> commodities;
  late Map<String, List<PricePoint>> priceSeries;
  late List<StockItem> stocks;
  late List<WarehouseItem> rawWarehouses;
  late List<GroupItem> groups;
  late List<LotItem> lots;
  final List<RentalItem> rentals = [];
  late List<DemandItem> demands;
  final List<SaleItem> sales = [];

  OfflineDemoStore() {
    const jagungParams = CommodityParams(
      kadarAirMaksPct: 15,
      kotoranMaksPct: 3,
      rusakMaksPct: 5,
      susutPerBulan: 0.005,
      susutRumahPerBulan: 0.03,
      biayaPengeringanPerKg: 150,
      tarifSewaMurah: 1,
      tarifSewaMahal: 8,
      fasilitasWajib: ['ventilasi', 'lantai_palet_kering', 'kontrol_hama'],
    );
    const gabahParams = CommodityParams(
      kadarAirMaksPct: 14,
      kotoranMaksPct: 3,
      rusakMaksPct: 5,
      susutPerBulan: 0.005,
      susutRumahPerBulan: 0.025,
      biayaPengeringanPerKg: 150,
      tarifSewaMurah: 1,
      tarifSewaMahal: 8,
      fasilitasWajib: ['ventilasi', 'lantai_palet_kering', 'kontrol_hama'],
    );
    commodities = [
      const CommodityModel(
        id: 'c-jagung',
        kode: 'jagung',
        nama: 'Jagung Pipil',
        satuan: 'kg',
        params: jagungParams,
      ),
      const CommodityModel(
        id: 'c-gabah',
        kode: 'gabah',
        nama: 'Gabah Kering Giling (GKG)',
        satuan: 'kg',
        params: gabahParams,
      ),
    ];
    priceSeries = {
      'jagung': SimpanJualEngine.generateSeasonalSeries(4950, 550, 64),
      'gabah': SimpanJualEngine.generateSeasonalSeries(6400, 650, 64),
    };
    stocks = [
      const StockItem(
        id: 'st-1',
        ownerId: 'u-petani',
        commodityId: 'c-jagung',
        commodityKode: 'jagung',
        commodityNama: 'Jagung Pipil',
        commodityParams: jagungParams,
        qtyKg: 5000,
        reservedKg: 0,
        soldKg: 0,
        freeKg: 5000,
        kadarAir: 14.5,
        kotoranPct: 2.0,
        rusakPct: 3.0,
        tglPanen: '2026-11-20',
        kabupaten: 'Banyumas',
        status: 'tersedia',
        catatan: 'Panen blok sawah Sokaraja, jagung pipil kuning',
      ),
      const StockItem(
        id: 'st-2',
        ownerId: 'u-petani',
        commodityId: 'c-gabah',
        commodityKode: 'gabah',
        commodityNama: 'Gabah Kering Giling (GKG)',
        commodityParams: gabahParams,
        qtyKg: 4000,
        reservedKg: 0,
        soldKg: 0,
        freeKg: 4000,
        kadarAir: 22.0,
        kotoranPct: 2.5,
        rusakPct: 3.5,
        tglPanen: '2026-11-22',
        kabupaten: 'Banyumas',
        status: 'tersedia',
        catatan: 'Gabah Kering Panen (GKP) basah, perlu dijemur sebelum masuk SRG',
      ),
      const StockItem(
        id: 'st-3',
        ownerId: 'u-poktan',
        commodityId: 'c-jagung',
        commodityKode: 'jagung',
        commodityNama: 'Jagung Pipil',
        commodityParams: jagungParams,
        qtyKg: 6000,
        reservedKg: 6000,
        soldKg: 0,
        freeKg: 0,
        kadarAir: 14.0,
        kotoranPct: 2.0,
        rusakPct: 2.5,
        tglPanen: '2026-11-18',
        kabupaten: 'Banyumas',
        status: 'teralokasi_penuh',
        catatan: 'Stok himpunan anggota Poktan Tani Jaya',
      ),
    ];

    const emptyScore = WarehouseScoreModel(
      isEligible: true,
      totalScore: 95,
      distanceKm: 10,
      fasilitasWajib: 30,
      kondisiDanSrg: 30,
      jarak: 14,
      tarif: 12,
      kapasitas: 10,
    );
    rawWarehouses = [
      const WarehouseItem(
        id: 'wh-1',
        ownerId: 'u-gudang',
        nama: 'Gudang SRG Banyumas (Data Ilustrasi)',
        kabupaten: 'Banyumas',
        lat: -7.4314,
        lng: 109.2478,
        kapasitasKg: 100000,
        tersediaKg: 82000,
        tarifPerKgHari: 2.5,
        minVolumeKg: 5000,
        minHari: 30,
        isSrg: true,
        komoditasDiterima: ['jagung', 'gabah'],
        checklist: {
          'atap_tidak_bocor': true,
          'ventilasi': true,
          'lantai_palet_kering': true,
          'kontrol_hama': true,
          'alat_ukur_ka': true,
          'keamanan_suhu': true,
        },
        kontakWa: '6281234567803',
        isDemo: true,
        score: emptyScore,
        estimasiSewa30Hr: 375000,
      ),
      const WarehouseItem(
        id: 'wh-2',
        ownerId: 'u-gudang',
        nama: 'Gudang Koperasi Tani Makmur Cilacap (Data Ilustrasi)',
        kabupaten: 'Cilacap',
        lat: -7.7188,
        lng: 109.0154,
        kapasitasKg: 60000,
        tersediaKg: 45000,
        tarifPerKgHari: 3.0,
        minVolumeKg: 2000,
        minHari: 14,
        isSrg: false,
        komoditasDiterima: ['jagung', 'gabah'],
        checklist: {
          'atap_tidak_bocor': true,
          'ventilasi': true,
          'lantai_palet_kering': true,
          'kontrol_hama': true,
          'alat_ukur_ka': false,
          'keamanan_suhu': false,
        },
        kontakWa: '6281234567803',
        isDemo: true,
        score: emptyScore,
        estimasiSewa30Hr: 450000,
      ),
      const WarehouseItem(
        id: 'wh-3',
        ownerId: 'u-gudang',
        nama: 'Penggilingan & Lumbung Purbalingga (Data Ilustrasi)',
        kabupaten: 'Purbalingga',
        lat: -7.3881,
        lng: 109.3639,
        kapasitasKg: 40000,
        tersediaKg: 28000,
        tarifPerKgHari: 3.5,
        minVolumeKg: 1000,
        minHari: 14,
        isSrg: false,
        komoditasDiterima: ['gabah'],
        checklist: {
          'atap_tidak_bocor': true,
          'ventilasi': true,
          'lantai_palet_kering': true,
          'kontrol_hama': false,
          'alat_ukur_ka': true,
          'keamanan_suhu': false,
        },
        kontakWa: '6281234567803',
        isDemo: true,
        score: emptyScore,
        estimasiSewa30Hr: 525000,
      ),
    ];

    groups = [
      const GroupItem(
        id: 'grp-1',
        nama: 'Poktan Tani Jaya Banyumas',
        kabupaten: 'Banyumas',
        ketuaId: 'u-poktan',
        ketuaNama: 'Bu Rini (Ketua Poktan)',
        kodeGabung: 'TANIJAYA',
        isKetua: true,
        memberCount: 2,
      ),
    ];

    lots = [
      const LotItem(
        id: 'lot-1',
        groupId: 'grp-1',
        groupNama: 'Poktan Tani Jaya Banyumas',
        kodeGabung: 'TANIJAYA',
        isKetua: true,
        commodityId: 'c-jagung',
        commodityKode: 'jagung',
        commodityNama: 'Jagung Pipil',
        targetKg: 10000,
        terkumpulKg: 6000,
        progressPct: 60.0,
        status: 'mengumpulkan',
        warehouseNama: 'Gudang SRG Banyumas (Data Ilustrasi)',
        contributions: [
          LotContributionItem(
            id: 'lc-1',
            userNama: 'Bu Rini (Ketua Poktan)',
            qtyKg: 6000,
            sharePct: 100.0,
          ),
        ],
      ),
    ];

    demands = [
      const DemandItem(
        id: 'dem-1',
        buyerId: 'u-pembeli',
        buyerNama: 'Koperasi & SPPG Mitra Banyumas',
        buyerOrg: 'Koperasi Pangan Banyumas (Mitra SPPG)',
        commodityId: 'c-jagung',
        commodityKode: 'jagung',
        commodityNama: 'Jagung Pipil',
        qtyKg: 15000,
        terpenuhiKg: 3000,
        sisaKuotaKg: 12000,
        progressPct: 20.0,
        hargaAcuan: 5850,
        dibutuhkanPada: '2027-01-15',
        kabupaten: 'Banyumas',
        kadarAirMaksPct: 15,
        catatanMutu: 'Jagung pipil kering bersih bebas jamur',
        status: 'aktif',
        isDemo: true,
      ),
      const DemandItem(
        id: 'dem-2',
        buyerId: 'u-pembeli',
        buyerNama: 'Koperasi & SPPG Mitra Banyumas',
        buyerOrg: 'Koperasi Pangan Banyumas (Mitra SPPG)',
        commodityId: 'c-gabah',
        commodityKode: 'gabah',
        commodityNama: 'Gabah Kering Giling (GKG)',
        qtyKg: 20000,
        terpenuhiKg: 5000,
        sisaKuotaKg: 15000,
        progressPct: 25.0,
        hargaAcuan: 7200,
        dibutuhkanPada: '2027-01-20',
        kabupaten: 'Banyumas',
        kadarAirMaksPct: 14,
        catatanMutu: 'Gabah Kering Giling standar RMU/SPPG',
        status: 'aktif',
        isDemo: true,
      ),
    ];
  }

  UserProfile demoLogin(String preset) {
    final map = {
      'petani': 'petani@demo.id',
      'poktan': 'poktan@demo.id',
      'gudang': 'gudang@demo.id',
      'pembeli': 'pembeli@demo.id',
      'admin': 'admin@demo.id',
    };
    final email = map[preset] ?? 'petani@demo.id';
    return users.firstWhere((u) => u.email == email);
  }

  UserProfile loginByEmail(String email, String password) {
    final match = users.where((u) => u.email.toLowerCase() == email.toLowerCase());
    if (match.isEmpty || password.length < 4) {
      throw Exception('Email atau kata sandi salah');
    }
    return match.first;
  }

  UserProfile register({
    required String email,
    required String nama,
    required String role,
    required String kabupaten,
  }) {
    final u = UserProfile(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      role: role,
      nama: nama,
      kabupaten: kabupaten,
    );
    users.add(u);
    return u;
  }

  ({List<PricePoint> series, ForecastOutput forecast, int latestPrice, CommodityModel commodity})
      pricesFor(String kode) {
    final comm = commodities.firstWhere(
      (c) => c.kode == kode || c.id == kode,
      orElse: () => commodities.first,
    );
    final series = priceSeries[comm.kode] ?? SimpanJualEngine.generateSeasonalSeries(5500, 500, 64);
    final fc = SimpanJualEngine.generateForecast(series);
    return (series: series, forecast: fc, latestPrice: series.last.hargaPerKg, commodity: comm);
  }

  Map<String, dynamic> impactSummary() => {
        'tambahanPendapatanRp': 4250000,
        'stokTerserapKg': 10000.0,
        'susutDicegahKg': 240.0,
        'petaniTergabung': 2,
        'lotKolektifCount': lots.length,
      };

  List<StockItem> stocksFor(String userId) =>
      stocks.where((s) => s.ownerId == userId).toList();

  void addStock(String userId, Map<String, dynamic> p) {
    final kode = (p['commodityKode'] ?? p['commodityId'] ?? 'jagung').toString();
    final comm = commodities.firstWhere((c) => c.kode == kode || c.id == kode, orElse: () => commodities.first);
    final qty = (p['qtyKg'] as num).toDouble();
    stocks.insert(
      0,
      StockItem(
        id: 'st-${DateTime.now().millisecondsSinceEpoch}',
        ownerId: userId,
        commodityId: comm.id,
        commodityKode: comm.kode,
        commodityNama: comm.nama,
        commodityParams: comm.params,
        qtyKg: qty,
        reservedKg: 0,
        soldKg: 0,
        freeKg: qty,
        kadarAir: (p['kadarAir'] as num? ?? 14).toDouble(),
        kotoranPct: (p['kotoranPct'] as num? ?? 2).toDouble(),
        rusakPct: (p['rusakPct'] as num? ?? 3).toDouble(),
        tglPanen: (p['tglPanen'] ?? '2026-11-27').toString(),
        kabupaten: (p['kabupaten'] ?? 'Banyumas').toString(),
        status: 'tersedia',
        catatan: p['catatan']?.toString(),
      ),
    );
  }

  void deleteStock(String stockId) {
    stocks.removeWhere((s) => s.id == stockId && s.reservedKg == 0 && s.soldKg == 0);
  }

  Map<String, dynamic> evaluateStock(StockItem st, Map<String, dynamic> p) {
    final pr = pricesFor(st.commodityKode);
    final dec = SimpanJualEngine.evaluateHoldVsSell(
      qtyKg: st.qtyKg,
      kadarAirAktual: st.kadarAir,
      kadarAirAmbang: st.commodityParams.kadarAirMaksPct,
      biayaPengeringanPerKg:
          (p['biayaPengeringanPerKg'] as num?)?.toDouble() ?? st.commodityParams.biayaPengeringanPerKg,
      p0Dry: pr.latestPrice.toDouble(),
      predictions: pr.forecast.predictions,
      tarifSewaPerKgHari: (p['tarifSewaPerKgHari'] as num?)?.toDouble() ?? 2.5,
      biayaAngkutPerKg: (p['biayaAngkutPerKg'] as num?)?.toDouble() ?? 20,
      biayaTetap: (p['biayaTetap'] as num?)?.toDouble() ?? 100000,
      susutPerBulan: (p['susutPerBulan'] as num?)?.toDouble() ?? st.commodityParams.susutPerBulan,
      rasioPinjaman: (p['rasioPinjaman'] as num?)?.toDouble() ?? 0.70,
      bungaTahunan: (p['bungaTahunan'] as num?)?.toDouble() ?? 0.06,
    );
    PanjarResult? pj;
    final mode = (p['panjarMode'] ?? 'per_kg').toString();
    if (mode == 'borongan' && (p['totalBoronganRp'] as num? ?? 0) > 0) {
      pj = SimpanJualEngine.evaluatePanjar(
        mode: 'borongan',
        totalBoronganRp: (p['totalBoronganRp'] as num).toDouble(),
        qtyKg: st.qtyKg,
        p0Actual: pr.latestPrice.toDouble(),
        pendapatanTahanRp: dec.best.pendapatanTahan.toDouble(),
        pinjamanSrgRp: dec.pinjamanAwal.toDouble(),
      );
    } else if ((p['hargaPanjarPerKg'] as num? ?? 0) > 0) {
      pj = SimpanJualEngine.evaluatePanjar(
        mode: 'per_kg',
        hargaPanjarPerKg: (p['hargaPanjarPerKg'] as num).toDouble(),
        qtyKg: st.qtyKg,
        p0Actual: pr.latestPrice.toDouble(),
        pendapatanTahanRp: dec.best.pendapatanTahan.toDouble(),
        pinjamanSrgRp: dec.pinjamanAwal.toDouble(),
      );
    }
    return {
      'latestPrice': pr.latestPrice,
      'forecast': pr.forecast,
      'decision': dec,
      'panjar': pj,
      'readiness': SimpanJualEngine.evaluateReadiness(
        kadarAir: st.kadarAir,
        kotoranPct: st.kotoranPct,
        rusakPct: st.rusakPct,
        params: st.commodityParams,
      ),
    };
  }

  List<WarehouseItem> listWarehouses({
    required String commodity,
    required String kabupaten,
    required double qtyKg,
    bool onlySrg = false,
    bool mine = false,
    String? ownerId,
  }) {
    final comm = commodities.firstWhere((c) => c.kode == commodity, orElse: () => commodities.first);
    final scored = rawWarehouses
        .where((w) => (!onlySrg || w.isSrg) && (!mine || w.ownerId == ownerId))
        .map((w) {
      final sc = SimpanJualEngine.scoreWarehouse(
        komoditasDiterima: w.komoditasDiterima,
        tersediaKg: w.tersediaKg,
        tarifPerKgHari: w.tarifPerKgHari,
        isSrg: w.isSrg,
        checklist: w.checklist,
        whLat: w.lat,
        whLng: w.lng,
        commodityCode: comm.kode,
        params: comm.params,
        qtyDibutuhkan: qtyKg,
        farmerKab: kabupaten,
      );
      return WarehouseItem(
        id: w.id,
        ownerId: w.ownerId,
        nama: w.nama,
        kabupaten: w.kabupaten,
        lat: w.lat,
        lng: w.lng,
        kapasitasKg: w.kapasitasKg,
        tersediaKg: w.tersediaKg,
        tarifPerKgHari: w.tarifPerKgHari,
        minVolumeKg: w.minVolumeKg,
        minHari: w.minHari,
        isSrg: w.isSrg,
        komoditasDiterima: w.komoditasDiterima,
        checklist: w.checklist,
        kontakWa: w.kontakWa,
        isDemo: w.isDemo,
        score: sc,
        estimasiSewa30Hr: (qtyKg * w.tarifPerKgHari * 30).round(),
      );
    }).toList();
    scored.sort((a, b) {
      if (a.score.isEligible != b.score.isEligible) {
        return a.score.isEligible ? -1 : 1;
      }
      return b.score.totalScore.compareTo(a.score.totalScore);
    });
    return scored;
  }

  void updateWarehouse(String id, Map<String, dynamic> p) {
    final idx = rawWarehouses.indexWhere((w) => w.id == id);
    if (idx < 0) return;
    final old = rawWarehouses[idx];
    rawWarehouses[idx] = WarehouseItem(
      id: old.id,
      ownerId: old.ownerId,
      nama: old.nama,
      kabupaten: old.kabupaten,
      lat: old.lat,
      lng: old.lng,
      kapasitasKg: (p['kapasitasKg'] as num?)?.toDouble() ?? old.kapasitasKg,
      tersediaKg: (p['tersediaKg'] as num?)?.toDouble() ?? old.tersediaKg,
      tarifPerKgHari: (p['tarifPerKgHari'] as num?)?.toDouble() ?? old.tarifPerKgHari,
      minVolumeKg: old.minVolumeKg,
      minHari: old.minHari,
      isSrg: old.isSrg,
      komoditasDiterima: old.komoditasDiterima,
      checklist: (p['checklist'] as Map?)?.cast<String, bool>() ?? old.checklist,
      kontakWa: old.kontakWa,
      isDemo: old.isDemo,
      score: old.score,
      estimasiSewa30Hr: old.estimasiSewa30Hr,
    );
  }

  List<GroupItem> groupsFor(String userId) => groups
      .map((g) => GroupItem(
            id: g.id,
            nama: g.nama,
            kabupaten: g.kabupaten,
            ketuaId: g.ketuaId,
            ketuaNama: g.ketuaNama,
            kodeGabung: g.kodeGabung,
            isKetua: g.ketuaId == userId,
            memberCount: g.memberCount,
          ))
      .toList();

  void joinGroup(String userId, String kode) {
    final exists = groups.any((g) => g.kodeGabung.toUpperCase() == kode.toUpperCase());
    if (!exists) throw Exception('Kode gabung tidak ditemukan');
  }

  void createGroup(String userId, String userNama, String nama, String kab) {
    groups.insert(
      0,
      GroupItem(
        id: 'grp-${DateTime.now().millisecondsSinceEpoch}',
        nama: nama,
        kabupaten: kab,
        ketuaId: userId,
        ketuaNama: userNama,
        kodeGabung: 'PKT${math.Random().nextInt(9000) + 1000}',
        isKetua: true,
        memberCount: 1,
      ),
    );
  }

  List<LotItem> lotsFor(String userId) => lots
      .map((l) => LotItem(
            id: l.id,
            groupId: l.groupId,
            groupNama: l.groupNama,
            kodeGabung: l.kodeGabung,
            isKetua: userId == 'u-poktan',
            commodityId: l.commodityId,
            commodityKode: l.commodityKode,
            commodityNama: l.commodityNama,
            targetKg: l.targetKg,
            terkumpulKg: l.terkumpulKg,
            progressPct: l.progressPct,
            status: l.status,
            warehouseNama: l.warehouseNama,
            contributions: l.contributions,
          ))
      .toList();

  void createLot(String groupId, String commodityKode, double targetKg) {
    final g = groups.firstWhere((e) => e.id == groupId, orElse: () => groups.first);
    final c = commodities.firstWhere((e) => e.kode == commodityKode, orElse: () => commodities.first);
    lots.insert(
      0,
      LotItem(
        id: 'lot-${DateTime.now().millisecondsSinceEpoch}',
        groupId: g.id,
        groupNama: g.nama,
        kodeGabung: g.kodeGabung,
        isKetua: true,
        commodityId: c.id,
        commodityKode: c.kode,
        commodityNama: c.nama,
        targetKg: targetKg,
        terkumpulKg: 0,
        progressPct: 0,
        status: 'mengumpulkan',
        contributions: const [],
      ),
    );
  }

  void contributeLot(String userId, String userNama, String lotId, String stockId, double qtyKg) {
    final idx = lots.indexWhere((l) => l.id == lotId);
    if (idx < 0) return;
    final old = lots[idx];
    final nextKg = old.terkumpulKg + qtyKg;
    lots[idx] = LotItem(
      id: old.id,
      groupId: old.groupId,
      groupNama: old.groupNama,
      kodeGabung: old.kodeGabung,
      isKetua: old.isKetua,
      commodityId: old.commodityId,
      commodityKode: old.commodityKode,
      commodityNama: old.commodityNama,
      targetKg: old.targetKg,
      terkumpulKg: nextKg,
      progressPct: ((nextKg / old.targetKg) * 100).clamp(0, 100),
      status: nextKg >= old.targetKg ? 'siap_ajukan' : 'mengumpulkan',
      warehouseNama: old.warehouseNama,
      contributions: [
        ...old.contributions,
        LotContributionItem(
          id: 'lc-${DateTime.now().millisecondsSinceEpoch}',
          userNama: userNama,
          qtyKg: qtyKg,
          sharePct: (qtyKg / nextKg) * 100,
        ),
      ],
    );
  }

  void submitRental(UserProfile user, Map<String, dynamic> p) {
    final wh = rawWarehouses.firstWhere((w) => w.id == p['warehouseId']);
    final qty = (p['qtyKg'] as num).toDouble();
    final hari = (p['hari'] as num).toInt();
    rentals.insert(
      0,
      RentalItem(
        id: 'rr-${DateTime.now().millisecondsSinceEpoch}',
        requesterId: user.id,
        requesterNama: user.nama,
        warehouseId: wh.id,
        warehouseNama: wh.nama,
        kabupaten: wh.kabupaten,
        kontakWa: wh.kontakWa,
        qtyKg: qty,
        hari: hari,
        estimasiBiaya: (qty * wh.tarifPerKgHari * hari).round(),
        status: 'diajukan',
      ),
    );
  }

  void respondRental(String id, String action) {
    final idx = rentals.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    final r = rentals[idx];
    final nextStatus = action == 'terima'
        ? 'diterima'
        : action == 'tolak'
            ? 'ditolak'
            : action == 'selesai'
                ? 'selesai'
                : 'dibatalkan';
    rentals[idx] = RentalItem(
      id: r.id,
      requesterId: r.requesterId,
      requesterNama: r.requesterNama,
      warehouseId: r.warehouseId,
      warehouseNama: r.warehouseNama,
      kabupaten: r.kabupaten,
      kontakWa: r.kontakWa,
      qtyKg: r.qtyKg,
      hari: r.hari,
      estimasiBiaya: r.estimasiBiaya,
      status: nextStatus,
    );
  }

  List<DemandItem> listDemands({String? commodity, bool mine = false, String? buyerId}) {
    return demands.where((d) {
      if (commodity != null && commodity.isNotEmpty && d.commodityKode != commodity) {
        return false;
      }
      if (mine && buyerId != null && d.buyerId != buyerId) return false;
      return true;
    }).toList();
  }

  void createDemand(UserProfile user, Map<String, dynamic> p) {
    final kode = (p['commodityKode'] ?? 'jagung').toString();
    final comm = commodities.firstWhere((c) => c.kode == kode, orElse: () => commodities.first);
    final qty = (p['qtyKg'] as num).toDouble();
    demands.insert(
      0,
      DemandItem(
        id: 'dem-${DateTime.now().millisecondsSinceEpoch}',
        buyerId: user.id,
        buyerNama: user.nama,
        buyerOrg: user.namaOrg,
        commodityId: comm.id,
        commodityKode: comm.kode,
        commodityNama: comm.nama,
        qtyKg: qty,
        terpenuhiKg: 0,
        sisaKuotaKg: qty,
        progressPct: 0,
        hargaAcuan: (p['hargaAcuan'] as num).round(),
        dibutuhkanPada: (p['dibutuhkanPada'] ?? '2027-01-30').toString(),
        kabupaten: (p['kabupaten'] ?? user.kabupaten).toString(),
        catatanMutu: p['catatan']?.toString(),
        status: 'aktif',
        isDemo: false,
      ),
    );
  }

  void submitSale(UserProfile user, Map<String, dynamic> p) {
    final d = demands.firstWhere((e) => e.id == p['demandId']);
    final qty = (p['qtyKg'] as num).toDouble();
    final tawar = (p['hargaTawar'] as num).round();
    sales.insert(
      0,
      SaleItem(
        id: 'so-${DateTime.now().millisecondsSinceEpoch}',
        sellerId: user.id,
        sellerNama: user.nama,
        demandId: d.id,
        buyerNama: d.buyerNama,
        buyerNoWa: '6281234567804',
        commodityKode: d.commodityKode,
        commodityNama: d.commodityNama,
        hargaAcuan: d.hargaAcuan,
        qtyKg: qty,
        hargaTawar: tawar,
        totalNilaiRp: (qty * tawar).round(),
        status: 'diajukan',
      ),
    );
  }

  void respondSale(String id, String action) {
    final idx = sales.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    final s = sales[idx];
    final nextStatus = action == 'terima'
        ? 'diterima'
        : action == 'tolak'
            ? 'ditolak'
            : action == 'selesai'
                ? 'selesai'
                : 'dibatalkan';
    sales[idx] = SaleItem(
      id: s.id,
      sellerId: s.sellerId,
      sellerNama: s.sellerNama,
      demandId: s.demandId,
      buyerNama: s.buyerNama,
      buyerNoWa: s.buyerNoWa,
      commodityKode: s.commodityKode,
      commodityNama: s.commodityNama,
      hargaAcuan: s.hargaAcuan,
      qtyKg: s.qtyKg,
      hargaTawar: s.hargaTawar,
      totalNilaiRp: s.totalNilaiRp,
      status: nextStatus,
    );
  }

  void addCommodity(Map<String, dynamic> p) {
    final kode = (p['kode'] ?? 'kedelai').toString().toLowerCase();
    final nama = (p['nama'] ?? 'Kedelai Lokal').toString();
    final base = (p['hargaAwalKg'] as num? ?? 9200).toDouble();
    final params = CommodityParams.fromJson(
      (p['params'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    commodities.add(CommodityModel(
      id: 'c-$kode',
      kode: kode,
      nama: nama,
      satuan: 'kg',
      params: params,
    ));
    priceSeries[kode] = SimpanJualEngine.generateSeasonalSeries(base, base * 0.08, 64);
  }
}
