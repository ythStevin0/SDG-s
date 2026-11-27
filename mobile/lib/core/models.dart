class UserProfile {
  final String id;
  final String email;
  final String role;
  final String nama;
  final String? noWa;
  final String kabupaten;
  final String provinsi;
  final String? namaOrg;
  final String? tipePembeli;
  final bool isDemo;

  const UserProfile({
    required this.id,
    required this.email,
    required this.role,
    required this.nama,
    this.noWa,
    required this.kabupaten,
    this.provinsi = 'Jawa Tengah',
    this.namaOrg,
    this.tipePembeli,
    this.isDemo = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: (j['id'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        role: (j['role'] ?? 'petani').toString(),
        nama: (j['nama'] ?? '').toString(),
        noWa: j['noWa']?.toString(),
        kabupaten: (j['kabupaten'] ?? 'Banyumas').toString(),
        provinsi: (j['provinsi'] ?? 'Jawa Tengah').toString(),
        namaOrg: j['namaOrg']?.toString(),
        tipePembeli: j['tipePembeli']?.toString(),
        isDemo: j['isDemo'] == true,
      );
}

class CommodityParams {
  final double kadarAirMaksPct;
  final double kotoranMaksPct;
  final double rusakMaksPct;
  final double susutPerBulan;
  final double susutRumahPerBulan;
  final double biayaPengeringanPerKg;
  final double tarifSewaMurah;
  final double tarifSewaMahal;
  final List<String> fasilitasWajib;

  const CommodityParams({
    required this.kadarAirMaksPct,
    required this.kotoranMaksPct,
    required this.rusakMaksPct,
    required this.susutPerBulan,
    required this.susutRumahPerBulan,
    required this.biayaPengeringanPerKg,
    required this.tarifSewaMurah,
    required this.tarifSewaMahal,
    required this.fasilitasWajib,
  });

  factory CommodityParams.fromJson(Map<String, dynamic> j) => CommodityParams(
        kadarAirMaksPct: (j['kadar_air_maks_pct'] as num? ?? 15).toDouble(),
        kotoranMaksPct: (j['kotoran_maks_pct'] as num? ?? 3).toDouble(),
        rusakMaksPct: (j['rusak_maks_pct'] as num? ?? 5).toDouble(),
        susutPerBulan: (j['susut_per_bulan'] as num? ?? 0.005).toDouble(),
        susutRumahPerBulan: (j['susut_rumah_per_bulan'] as num? ?? 0.025).toDouble(),
        biayaPengeringanPerKg: (j['biaya_pengeringan_per_kg'] as num? ?? 150).toDouble(),
        tarifSewaMurah: (j['tarif_sewa_murah'] as num? ?? 1).toDouble(),
        tarifSewaMahal: (j['tarif_sewa_mahal'] as num? ?? 8).toDouble(),
        fasilitasWajib: (j['fasilitas_wajib'] as List<dynamic>? ??
                const ['ventilasi', 'lantai_palet_kering', 'kontrol_hama'])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'kadar_air_maks_pct': kadarAirMaksPct,
        'kotoran_maks_pct': kotoranMaksPct,
        'rusak_maks_pct': rusakMaksPct,
        'susut_per_bulan': susutPerBulan,
        'susut_rumah_per_bulan': susutRumahPerBulan,
        'biaya_pengeringan_per_kg': biayaPengeringanPerKg,
        'tarif_sewa_murah': tarifSewaMurah,
        'tarif_sewa_mahal': tarifSewaMahal,
        'fasilitas_wajib': fasilitasWajib,
      };
}

class CommodityModel {
  final String id;
  final String kode;
  final String nama;
  final String satuan;
  final CommodityParams params;

  const CommodityModel({
    required this.id,
    required this.kode,
    required this.nama,
    required this.satuan,
    required this.params,
  });

  factory CommodityModel.fromJson(Map<String, dynamic> j) => CommodityModel(
        id: (j['id'] ?? '').toString(),
        kode: (j['kode'] ?? '').toString(),
        nama: (j['nama'] ?? '').toString(),
        satuan: (j['satuan'] ?? 'kg').toString(),
        params: CommodityParams.fromJson(
          (j['params'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}

class PricePoint {
  final String tanggal;
  final int hargaPerKg;

  const PricePoint({required this.tanggal, required this.hargaPerKg});

  factory PricePoint.fromJson(Map<String, dynamic> j) => PricePoint(
        tanggal: (j['tanggal'] ?? '').toString(),
        hargaPerKg: (j['hargaPerKg'] as num? ?? 0).round(),
      );
}

class HorizonPrediction {
  final int horizonWeeks;
  final double pricePoint;
  final double priceLow;
  final double priceHigh;

  const HorizonPrediction({
    required this.horizonWeeks,
    required this.pricePoint,
    required this.priceLow,
    required this.priceHigh,
  });

  factory HorizonPrediction.fromJson(Map<String, dynamic> j) => HorizonPrediction(
        horizonWeeks: (j['horizonWeeks'] as num? ?? 4).toInt(),
        pricePoint: (j['pricePoint'] as num? ?? 0).toDouble(),
        priceLow: (j['priceLow'] as num? ?? 0).toDouble(),
        priceHigh: (j['priceHigh'] as num? ?? 0).toDouble(),
      );
}

class ForecastOutput {
  final String selectedModel;
  final double mapePct;
  final int dataPointsCount;
  final String lastDate;
  final bool lowConfidence;
  final List<HorizonPrediction> predictions;

  const ForecastOutput({
    required this.selectedModel,
    required this.mapePct,
    required this.dataPointsCount,
    required this.lastDate,
    required this.lowConfidence,
    required this.predictions,
  });

  factory ForecastOutput.fromJson(Map<String, dynamic> j) => ForecastOutput(
        selectedModel: (j['selectedModel'] ?? 'Seasonal-MA').toString(),
        mapePct: (j['mapePct'] as num? ?? 7.5).toDouble(),
        dataPointsCount: (j['dataPointsCount'] as num? ?? 64).toInt(),
        lastDate: (j['lastDate'] ?? '').toString(),
        lowConfidence: j['lowConfidence'] == true,
        predictions: (j['predictions'] as List<dynamic>? ?? const [])
            .map((e) => HorizonPrediction.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class StockItem {
  final String id;
  final String ownerId;
  final String commodityId;
  final String commodityKode;
  final String commodityNama;
  final CommodityParams commodityParams;
  final double qtyKg;
  final double reservedKg;
  final double soldKg;
  final double freeKg;
  final double kadarAir;
  final double kotoranPct;
  final double rusakPct;
  final String tglPanen;
  final String kabupaten;
  final double? lat;
  final double? lng;
  final String status;
  final String? catatan;

  const StockItem({
    required this.id,
    required this.ownerId,
    required this.commodityId,
    required this.commodityKode,
    required this.commodityNama,
    required this.commodityParams,
    required this.qtyKg,
    required this.reservedKg,
    required this.soldKg,
    required this.freeKg,
    required this.kadarAir,
    required this.kotoranPct,
    required this.rusakPct,
    required this.tglPanen,
    required this.kabupaten,
    this.lat,
    this.lng,
    required this.status,
    this.catatan,
  });

  factory StockItem.fromJson(Map<String, dynamic> j) {
    final qty = (j['qtyKg'] as num? ?? 0).toDouble();
    final res = (j['reservedKg'] as num? ?? 0).toDouble();
    final sold = (j['soldKg'] as num? ?? 0).toDouble();
    final free = j['freeKg'] != null ? (j['freeKg'] as num).toDouble() : (qty - res - sold);
    return StockItem(
      id: (j['id'] ?? '').toString(),
      ownerId: (j['ownerId'] ?? '').toString(),
      commodityId: (j['commodityId'] ?? '').toString(),
      commodityKode: (j['commodityKode'] ?? 'jagung').toString(),
      commodityNama: (j['commodityNama'] ?? 'Jagung Pipil').toString(),
      commodityParams: CommodityParams.fromJson(
        (j['commodityParams'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      qtyKg: qty,
      reservedKg: res,
      soldKg: sold,
      freeKg: free < 0 ? 0 : free,
      kadarAir: (j['kadarAir'] as num? ?? 14).toDouble(),
      kotoranPct: (j['kotoranPct'] as num? ?? 2).toDouble(),
      rusakPct: (j['rusakPct'] as num? ?? 3).toDouble(),
      tglPanen: (j['tglPanen'] ?? '').toString(),
      kabupaten: (j['kabupaten'] ?? 'Banyumas').toString(),
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      status: (j['status'] ?? 'tersedia').toString(),
      catatan: j['catatan']?.toString(),
    );
  }
}

class HorizonEvaluation {
  final int horizonWeeks;
  final int days;
  final double susutSimpanPct;
  final double qtyEff;
  final int biayaSewa;
  final int biayaAngkut;
  final int biayaTetap;
  final int biayaPengeringan;
  final int bungaPinjaman;
  final int totalBiayaSimpan;
  final int pendapatanTahan;
  final int selisihRp;
  final double selisihPct;
  final int selisihLowRp;
  final int titikImpasPerKg;

  const HorizonEvaluation({
    required this.horizonWeeks,
    required this.days,
    required this.susutSimpanPct,
    required this.qtyEff,
    required this.biayaSewa,
    required this.biayaAngkut,
    required this.biayaTetap,
    required this.biayaPengeringan,
    required this.bungaPinjaman,
    required this.totalBiayaSimpan,
    required this.pendapatanTahan,
    required this.selisihRp,
    required this.selisihPct,
    required this.selisihLowRp,
    required this.titikImpasPerKg,
  });

  factory HorizonEvaluation.fromJson(Map<String, dynamic> j) => HorizonEvaluation(
        horizonWeeks: (j['horizonWeeks'] as num? ?? 4).toInt(),
        days: (j['days'] as num? ?? 28).toInt(),
        susutSimpanPct: (j['susutSimpanPct'] as num? ?? 0).toDouble(),
        qtyEff: (j['qtyEff'] as num? ?? 0).toDouble(),
        biayaSewa: (j['biayaSewa'] as num? ?? 0).round(),
        biayaAngkut: (j['biayaAngkut'] as num? ?? 0).round(),
        biayaTetap: (j['biayaTetap'] as num? ?? 0).round(),
        biayaPengeringan: (j['biayaPengeringan'] as num? ?? 0).round(),
        bungaPinjaman: (j['bungaPinjaman'] as num? ?? 0).round(),
        totalBiayaSimpan: (j['totalBiayaSimpan'] as num? ?? 0).round(),
        pendapatanTahan: (j['pendapatanTahan'] as num? ?? 0).round(),
        selisihRp: (j['selisihRp'] as num? ?? 0).round(),
        selisihPct: (j['selisihPct'] as num? ?? 0).toDouble(),
        selisihLowRp: (j['selisihLowRp'] as num? ?? 0).round(),
        titikImpasPerKg: (j['titikImpasPerKg'] as num? ?? 0).round(),
      );
}

class DecisionResult {
  final String recommendation;
  final int bestHorizonWeeks;
  final int pendapatanJualSegera;
  final int pinjamanAwal;
  final double qtySiap;
  final bool perluPengeringan;
  final double susutPengeringanKg;
  final HorizonEvaluation best;
  final List<HorizonEvaluation> allHorizons;
  final String summarySentence;

  const DecisionResult({
    required this.recommendation,
    required this.bestHorizonWeeks,
    required this.pendapatanJualSegera,
    required this.pinjamanAwal,
    required this.qtySiap,
    required this.perluPengeringan,
    required this.susutPengeringanKg,
    required this.best,
    required this.allHorizons,
    required this.summarySentence,
  });

  factory DecisionResult.fromJson(Map<String, dynamic> j) => DecisionResult(
        recommendation: (j['recommendation'] ?? 'JUAL').toString(),
        bestHorizonWeeks: (j['bestHorizonWeeks'] as num? ?? 4).toInt(),
        pendapatanJualSegera: (j['pendapatanJualSegera'] as num? ?? 0).round(),
        pinjamanAwal: (j['pinjamanAwal'] as num? ?? 0).round(),
        qtySiap: (j['qtySiap'] as num? ?? 0).toDouble(),
        perluPengeringan: j['perluPengeringan'] == true,
        susutPengeringanKg: (j['susutPengeringanKg'] as num? ?? 0).toDouble(),
        best: HorizonEvaluation.fromJson((j['best'] as Map).cast<String, dynamic>()),
        allHorizons: (j['allHorizons'] as List<dynamic>? ?? const [])
            .map((e) => HorizonEvaluation.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        summarySentence: (j['summarySentence'] ?? '').toString(),
      );
}

class PanjarResult {
  final int hargaPanjarPerKg;
  final int pendapatanPanjarRp;
  final int pendapatanTahanRp;
  final int selisihTerhadapTahanRp;
  final double selisihTerhadapTahanPct;
  final double diskonTerhadapPasarPct;
  final int tunaiHariIniPanjarRp;
  final int tunaiHariIniSrgRp;

  const PanjarResult({
    required this.hargaPanjarPerKg,
    required this.pendapatanPanjarRp,
    required this.pendapatanTahanRp,
    required this.selisihTerhadapTahanRp,
    required this.selisihTerhadapTahanPct,
    required this.diskonTerhadapPasarPct,
    required this.tunaiHariIniPanjarRp,
    required this.tunaiHariIniSrgRp,
  });

  factory PanjarResult.fromJson(Map<String, dynamic> j) => PanjarResult(
        hargaPanjarPerKg: (j['hargaPanjarPerKg'] as num? ?? 0).round(),
        pendapatanPanjarRp: (j['pendapatanPanjarRp'] as num? ?? 0).round(),
        pendapatanTahanRp: (j['pendapatanTahanRp'] as num? ?? 0).round(),
        selisihTerhadapTahanRp: (j['selisihTerhadapTahanRp'] as num? ?? 0).round(),
        selisihTerhadapTahanPct: (j['selisihTerhadapTahanPct'] as num? ?? 0).toDouble(),
        diskonTerhadapPasarPct: (j['diskonTerhadapPasarPct'] as num? ?? 0).toDouble(),
        tunaiHariIniPanjarRp: (j['tunaiHariIniPanjarRp'] as num? ?? 0).round(),
        tunaiHariIniSrgRp: (j['tunaiHariIniSrgRp'] as num? ?? 0).round(),
      );
}

class ReadinessResult {
  final String status;
  final List<String> reasons;
  final List<String> actions;

  const ReadinessResult({
    required this.status,
    required this.reasons,
    required this.actions,
  });

  factory ReadinessResult.fromJson(Map<String, dynamic> j) => ReadinessResult(
        status: (j['status'] ?? 'LAYAK').toString(),
        reasons: (j['reasons'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
        actions: (j['actions'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      );
}

class WarehouseScoreModel {
  final bool isEligible;
  final String? ineligibleReason;
  final int totalScore;
  final double distanceKm;
  final double fasilitasWajib;
  final double kondisiDanSrg;
  final double jarak;
  final double tarif;
  final double kapasitas;

  const WarehouseScoreModel({
    required this.isEligible,
    this.ineligibleReason,
    required this.totalScore,
    required this.distanceKm,
    required this.fasilitasWajib,
    required this.kondisiDanSrg,
    required this.jarak,
    required this.tarif,
    required this.kapasitas,
  });

  factory WarehouseScoreModel.fromJson(Map<String, dynamic> j) {
    final bd = (j['breakdown'] as Map?)?.cast<String, dynamic>() ?? const {};
    return WarehouseScoreModel(
      isEligible: j['isEligible'] == true,
      ineligibleReason: j['ineligibleReason']?.toString(),
      totalScore: (j['totalScore'] as num? ?? 0).round(),
      distanceKm: (j['distanceKm'] as num? ?? 0).toDouble(),
      fasilitasWajib: (bd['fasilitasWajib'] as num? ?? 0).toDouble(),
      kondisiDanSrg: (bd['kondisiDanSrg'] as num? ?? 0).toDouble(),
      jarak: (bd['jarak'] as num? ?? 0).toDouble(),
      tarif: (bd['tarif'] as num? ?? 0).toDouble(),
      kapasitas: (bd['kapasitas'] as num? ?? 0).toDouble(),
    );
  }
}

class WarehouseItem {
  final String id;
  final String ownerId;
  final String nama;
  final String kabupaten;
  final double lat;
  final double lng;
  final double kapasitasKg;
  final double tersediaKg;
  final double tarifPerKgHari;
  final double minVolumeKg;
  final int minHari;
  final bool isSrg;
  final List<String> komoditasDiterima;
  final Map<String, bool> checklist;
  final String? kontakWa;
  final bool isDemo;
  final WarehouseScoreModel score;
  final int estimasiSewa30Hr;

  const WarehouseItem({
    required this.id,
    required this.ownerId,
    required this.nama,
    required this.kabupaten,
    required this.lat,
    required this.lng,
    required this.kapasitasKg,
    required this.tersediaKg,
    required this.tarifPerKgHari,
    required this.minVolumeKg,
    required this.minHari,
    required this.isSrg,
    required this.komoditasDiterima,
    required this.checklist,
    this.kontakWa,
    required this.isDemo,
    required this.score,
    required this.estimasiSewa30Hr,
  });

  factory WarehouseItem.fromJson(Map<String, dynamic> j) {
    final rawCheck = (j['checklist'] as Map?)?.cast<String, dynamic>() ?? const {};
    final check = <String, bool>{
      'atap_tidak_bocor': rawCheck['atap_tidak_bocor'] == true,
      'ventilasi': rawCheck['ventilasi'] == true,
      'lantai_palet_kering': rawCheck['lantai_palet_kering'] == true,
      'kontrol_hama': rawCheck['kontrol_hama'] == true,
      'alat_ukur_ka': rawCheck['alat_ukur_ka'] == true,
      'keamanan_suhu': rawCheck['keamanan_suhu'] == true,
    };
    return WarehouseItem(
      id: (j['id'] ?? '').toString(),
      ownerId: (j['ownerId'] ?? '').toString(),
      nama: (j['nama'] ?? '').toString(),
      kabupaten: (j['kabupaten'] ?? 'Banyumas').toString(),
      lat: (j['lat'] as num? ?? -7.4314).toDouble(),
      lng: (j['lng'] as num? ?? 109.2478).toDouble(),
      kapasitasKg: (j['kapasitasKg'] as num? ?? 0).toDouble(),
      tersediaKg: (j['tersediaKg'] as num? ?? 0).toDouble(),
      tarifPerKgHari: (j['tarifPerKgHari'] as num? ?? 0).toDouble(),
      minVolumeKg: (j['minVolumeKg'] as num? ?? 0).toDouble(),
      minHari: (j['minHari'] as num? ?? 14).toInt(),
      isSrg: j['isSrg'] == true,
      komoditasDiterima:
          (j['komoditasDiterima'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      checklist: check,
      kontakWa: j['kontakWa']?.toString(),
      isDemo: j['isDemo'] == true,
      score: WarehouseScoreModel.fromJson(
        (j['score'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      estimasiSewa30Hr: (j['estimasiSewa30Hr'] as num? ?? 0).round(),
    );
  }
}

class GroupItem {
  final String id;
  final String nama;
  final String kabupaten;
  final String ketuaId;
  final String ketuaNama;
  final String kodeGabung;
  final bool isKetua;
  final int memberCount;

  const GroupItem({
    required this.id,
    required this.nama,
    required this.kabupaten,
    required this.ketuaId,
    required this.ketuaNama,
    required this.kodeGabung,
    required this.isKetua,
    required this.memberCount,
  });

  factory GroupItem.fromJson(Map<String, dynamic> j) => GroupItem(
        id: (j['id'] ?? '').toString(),
        nama: (j['nama'] ?? '').toString(),
        kabupaten: (j['kabupaten'] ?? '').toString(),
        ketuaId: (j['ketuaId'] ?? '').toString(),
        ketuaNama: (j['ketuaNama'] ?? '').toString(),
        kodeGabung: (j['kodeGabung'] ?? '').toString(),
        isKetua: j['isKetua'] == true,
        memberCount: (j['memberCount'] as num? ?? 1).toInt(),
      );
}

class LotContributionItem {
  final String id;
  final String userNama;
  final double qtyKg;
  final double sharePct;

  const LotContributionItem({
    required this.id,
    required this.userNama,
    required this.qtyKg,
    required this.sharePct,
  });

  factory LotContributionItem.fromJson(Map<String, dynamic> j) => LotContributionItem(
        id: (j['id'] ?? '').toString(),
        userNama: (j['userNama'] ?? '').toString(),
        qtyKg: (j['qtyKg'] as num? ?? 0).toDouble(),
        sharePct: (j['sharePct'] as num? ?? 0).toDouble(),
      );
}

class LotItem {
  final String id;
  final String groupId;
  final String groupNama;
  final String kodeGabung;
  final bool isKetua;
  final String commodityId;
  final String commodityKode;
  final String commodityNama;
  final double targetKg;
  final double terkumpulKg;
  final double progressPct;
  final String status;
  final String? warehouseNama;
  final List<LotContributionItem> contributions;

  const LotItem({
    required this.id,
    required this.groupId,
    required this.groupNama,
    required this.kodeGabung,
    required this.isKetua,
    required this.commodityId,
    required this.commodityKode,
    required this.commodityNama,
    required this.targetKg,
    required this.terkumpulKg,
    required this.progressPct,
    required this.status,
    this.warehouseNama,
    required this.contributions,
  });

  factory LotItem.fromJson(Map<String, dynamic> j) => LotItem(
        id: (j['id'] ?? '').toString(),
        groupId: (j['groupId'] ?? '').toString(),
        groupNama: (j['groupNama'] ?? '').toString(),
        kodeGabung: (j['kodeGabung'] ?? '').toString(),
        isKetua: j['isKetua'] == true,
        commodityId: (j['commodityId'] ?? '').toString(),
        commodityKode: (j['commodityKode'] ?? '').toString(),
        commodityNama: (j['commodityNama'] ?? '').toString(),
        targetKg: (j['targetKg'] as num? ?? 0).toDouble(),
        terkumpulKg: (j['terkumpulKg'] as num? ?? 0).toDouble(),
        progressPct: (j['progressPct'] as num? ?? 0).toDouble(),
        status: (j['status'] ?? 'mengumpulkan').toString(),
        warehouseNama: j['warehouseNama']?.toString(),
        contributions: (j['contributions'] as List<dynamic>? ?? const [])
            .map((e) => LotContributionItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class RentalItem {
  final String id;
  final String requesterId;
  final String requesterNama;
  final String warehouseId;
  final String warehouseNama;
  final String kabupaten;
  final String? kontakWa;
  final double qtyKg;
  final int hari;
  final int estimasiBiaya;
  final String status;
  final String? alasanTolak;

  const RentalItem({
    required this.id,
    required this.requesterId,
    required this.requesterNama,
    required this.warehouseId,
    required this.warehouseNama,
    required this.kabupaten,
    this.kontakWa,
    required this.qtyKg,
    required this.hari,
    required this.estimasiBiaya,
    required this.status,
    this.alasanTolak,
  });

  factory RentalItem.fromJson(Map<String, dynamic> j) => RentalItem(
        id: (j['id'] ?? '').toString(),
        requesterId: (j['requesterId'] ?? '').toString(),
        requesterNama: (j['requesterNama'] ?? '').toString(),
        warehouseId: (j['warehouseId'] ?? '').toString(),
        warehouseNama: (j['warehouseNama'] ?? '').toString(),
        kabupaten: (j['kabupaten'] ?? '').toString(),
        kontakWa: j['kontakWa']?.toString(),
        qtyKg: (j['qtyKg'] as num? ?? 0).toDouble(),
        hari: (j['hari'] as num? ?? 30).toInt(),
        estimasiBiaya: (j['estimasiBiaya'] as num? ?? 0).round(),
        status: (j['status'] ?? 'diajukan').toString(),
        alasanTolak: j['alasanTolak']?.toString(),
      );
}

class DemandItem {
  final String id;
  final String buyerId;
  final String buyerNama;
  final String? buyerOrg;
  final String commodityId;
  final String commodityKode;
  final String commodityNama;
  final double qtyKg;
  final double terpenuhiKg;
  final double sisaKuotaKg;
  final double progressPct;
  final int hargaAcuan;
  final String dibutuhkanPada;
  final String kabupaten;
  final double? kadarAirMaksPct;
  final String? catatanMutu;
  final String status;
  final bool isDemo;

  const DemandItem({
    required this.id,
    required this.buyerId,
    required this.buyerNama,
    this.buyerOrg,
    required this.commodityId,
    required this.commodityKode,
    required this.commodityNama,
    required this.qtyKg,
    required this.terpenuhiKg,
    required this.sisaKuotaKg,
    required this.progressPct,
    required this.hargaAcuan,
    required this.dibutuhkanPada,
    required this.kabupaten,
    this.kadarAirMaksPct,
    this.catatanMutu,
    required this.status,
    required this.isDemo,
  });

  factory DemandItem.fromJson(Map<String, dynamic> j) {
    final mutu = (j['mutuMin'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DemandItem(
      id: (j['id'] ?? '').toString(),
      buyerId: (j['buyerId'] ?? '').toString(),
      buyerNama: (j['buyerNama'] ?? '').toString(),
      buyerOrg: j['buyerOrg']?.toString(),
      commodityId: (j['commodityId'] ?? '').toString(),
      commodityKode: (j['commodityKode'] ?? '').toString(),
      commodityNama: (j['commodityNama'] ?? '').toString(),
      qtyKg: (j['qtyKg'] as num? ?? 0).toDouble(),
      terpenuhiKg: (j['terpenuhiKg'] as num? ?? 0).toDouble(),
      sisaKuotaKg: (j['sisaKuotaKg'] as num? ?? 0).toDouble(),
      progressPct: (j['progressPct'] as num? ?? 0).toDouble(),
      hargaAcuan: (j['hargaAcuan'] as num? ?? 0).round(),
      dibutuhkanPada: (j['dibutuhkanPada'] ?? '').toString(),
      kabupaten: (j['kabupaten'] ?? '').toString(),
      kadarAirMaksPct: (mutu['kadar_air_maks_pct'] as num?)?.toDouble(),
      catatanMutu: mutu['catatan']?.toString(),
      status: (j['status'] ?? 'aktif').toString(),
      isDemo: j['isDemo'] == true,
    );
  }
}

class SaleItem {
  final String id;
  final String sellerId;
  final String sellerNama;
  final String demandId;
  final String buyerNama;
  final String? buyerNoWa;
  final String commodityKode;
  final String commodityNama;
  final int hargaAcuan;
  final double qtyKg;
  final int hargaTawar;
  final int totalNilaiRp;
  final String status;
  final String? alasanTolak;

  const SaleItem({
    required this.id,
    required this.sellerId,
    required this.sellerNama,
    required this.demandId,
    required this.buyerNama,
    this.buyerNoWa,
    required this.commodityKode,
    required this.commodityNama,
    required this.hargaAcuan,
    required this.qtyKg,
    required this.hargaTawar,
    required this.totalNilaiRp,
    required this.status,
    this.alasanTolak,
  });

  factory SaleItem.fromJson(Map<String, dynamic> j) => SaleItem(
        id: (j['id'] ?? '').toString(),
        sellerId: (j['sellerId'] ?? '').toString(),
        sellerNama: (j['sellerNama'] ?? '').toString(),
        demandId: (j['demandId'] ?? '').toString(),
        buyerNama: (j['buyerNama'] ?? '').toString(),
        buyerNoWa: j['buyerNoWa']?.toString(),
        commodityKode: (j['commodityKode'] ?? '').toString(),
        commodityNama: (j['commodityNama'] ?? '').toString(),
        hargaAcuan: (j['hargaAcuan'] as num? ?? 0).round(),
        qtyKg: (j['qtyKg'] as num? ?? 0).toDouble(),
        hargaTawar: (j['hargaTawar'] as num? ?? 0).round(),
        totalNilaiRp: (j['totalNilaiRp'] as num? ?? 0).round(),
        status: (j['status'] ?? 'diajukan').toString(),
        alasanTolak: j['alasanTolak']?.toString(),
      );
}
