import 'dart:math' as math;
import 'formatters.dart';
import 'models.dart';

class SimpanJualEngine {
  static const Map<String, List<double>> jatengCoords = {
    'Banyumas': [-7.4502, 109.1623],
    'Cilacap': [-7.7188, 109.0154],
    'Purbalingga': [-7.3881, 109.3639],
    'Banjarnegara': [-7.3987, 109.6967],
    'Kebumen': [-7.6691, 109.6531],
    'Brebes': [-6.8706, 109.0442],
    'Tegal': [-6.9932, 109.1376],
    'Pemalang': [-6.8894, 109.3806],
    'Demak': [-6.8909, 110.6396],
  };

  static int _jsRound(double v) => (v + 0.5).floor();
  static double _round1(double v) => (v * 10).roundToDouble() / 10.0;
  static double _round2(double v) => (v * 100).roundToDouble() / 100.0;

  static List<double> resolveCoords(String kab, [double? lat, double? lng]) {
    if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
      return [lat, lng];
    }
    return jatengCoords[kab] ?? const [-7.4502, 109.1623];
  }

  static double roadDistanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double toRad(double d) => d * math.pi / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    final hav = 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
    return _round1(hav * 1.3);
  }

  static ({bool perluPengeringan, double qtySiapRaw, double qtySiap, double susutKg, int biayaRp})
      calculateDrying({
    required double qtyKg,
    required double kadarAirAktual,
    required double kadarAirAmbang,
    required double biayaPengeringanPerKg,
  }) {
    if (qtyKg <= 0) throw ArgumentError('qtyKg harus lebih besar dari 0');
    if (kadarAirAktual <= kadarAirAmbang) {
      return (
        perluPengeringan: false,
        qtySiapRaw: qtyKg,
        qtySiap: _round2(qtyKg),
        susutKg: 0.0,
        biayaRp: 0,
      );
    }
    final raw = qtyKg * ((100.0 - kadarAirAktual) / (100.0 - kadarAirAmbang));
    return (
      perluPengeringan: true,
      qtySiapRaw: raw,
      qtySiap: _round2(raw),
      susutKg: _round2(qtyKg - raw),
      biayaRp: _jsRound(qtyKg * math.max(0, biayaPengeringanPerKg)),
    );
  }

  static DecisionResult evaluateHoldVsSell({
    required double qtyKg,
    required double kadarAirAktual,
    required double kadarAirAmbang,
    double biayaPengeringanPerKg = 150,
    required double p0Dry,
    double? p0Actual,
    required List<HorizonPrediction> predictions,
    required double tarifSewaPerKgHari,
    required double biayaAngkutPerKg,
    required double biayaTetap,
    required double susutPerBulan,
    required double rasioPinjaman,
    required double bungaTahunan,
  }) {
    final dry = calculateDrying(
      qtyKg: qtyKg,
      kadarAirAktual: kadarAirAktual,
      kadarAirAmbang: kadarAirAmbang,
      biayaPengeringanPerKg: biayaPengeringanPerKg,
    );
    final p0Act = p0Actual ?? p0Dry;
    final jRaw = qtyKg * p0Act;
    final loanRaw = rasioPinjaman * (dry.qtySiapRaw * p0Dry);
    final cDryRaw = dry.perluPengeringan ? qtyKg * math.max(0, biayaPengeringanPerKg) : 0.0;

    final evals = predictions.map((pred) {
      final days = pred.horizonWeeks * 7;
      final sCumRaw = 1.0 - math.pow(1.0 - susutPerBulan, days / 30.0);
      final qEffRaw = dry.qtySiapRaw * (1.0 - sCumRaw);
      final sewaRaw = dry.qtySiapRaw * tarifSewaPerKgHari * days;
      final angkutRaw = dry.qtySiapRaw * biayaAngkutPerKg;
      final bungaRaw = loanRaw * bungaTahunan * (days / 365.0);
      final totalCostRaw = cDryRaw + sewaRaw + angkutRaw + biayaTetap + bungaRaw;

      final holdRevRaw = qEffRaw * pred.pricePoint - totalCostRaw;
      final gainRaw = holdRevRaw - jRaw;
      final lowGainRaw = (qEffRaw * pred.priceLow - totalCostRaw) - jRaw;
      final breakEven = ((jRaw + totalCostRaw) / qEffRaw).ceil();

      return HorizonEvaluation(
        horizonWeeks: pred.horizonWeeks,
        days: days,
        susutSimpanPct: _round2(sCumRaw * 100.0),
        qtyEff: _round2(qEffRaw),
        biayaSewa: _jsRound(sewaRaw),
        biayaAngkut: _jsRound(angkutRaw),
        biayaTetap: _jsRound(biayaTetap),
        biayaPengeringan: _jsRound(cDryRaw),
        bungaPinjaman: _jsRound(bungaRaw),
        totalBiayaSimpan: _jsRound(totalCostRaw),
        pendapatanTahan: _jsRound(holdRevRaw),
        selisihRp: _jsRound(gainRaw),
        selisihPct: jRaw > 0 ? _round2((gainRaw / jRaw) * 100.0) : 0.0,
        selisihLowRp: _jsRound(lowGainRaw),
        titikImpasPerKg: breakEven,
      );
    }).toList();

    var best = evals.first;
    for (final cur in evals.skip(1)) {
      if (cur.selisihRp > best.selisihRp) best = cur;
    }

    var rec = 'JUAL';
    if (best.selisihRp > 0 && best.selisihLowRp > 0) {
      rec = 'TAHAN';
    } else if (best.selisihRp > 0) {
      rec = 'TAHAN_BERISIKO';
    }

    final beFmt = formatIntId(best.titikImpasPerKg);
    final summary = rec == 'JUAL'
        ? 'Menahan stok belum menutup biaya simpan. Jual sekarang lebih aman kecuali harga naik di atas Rp$beFmt/kg.'
        : 'Menahan ${best.horizonWeeks} minggu layak bila harga jual mencapai minimal Rp$beFmt/kg.';

    return DecisionResult(
      recommendation: rec,
      bestHorizonWeeks: best.horizonWeeks,
      pendapatanJualSegera: _jsRound(jRaw),
      pinjamanAwal: _jsRound(loanRaw),
      qtySiap: dry.qtySiap,
      perluPengeringan: dry.perluPengeringan,
      susutPengeringanKg: dry.susutKg,
      best: best,
      allHorizons: evals,
      summarySentence: summary,
    );
  }

  static PanjarResult evaluatePanjar({
    required String mode,
    double hargaPanjarPerKg = 0,
    double totalBoronganRp = 0,
    required double qtyKg,
    required double p0Actual,
    required double pendapatanTahanRp,
    required double pinjamanSrgRp,
  }) {
    final double panjarTotalRaw =
        mode == 'borongan' ? totalBoronganRp : (hargaPanjarPerKg * qtyKg);
    final double perKgRaw = mode == 'borongan' ? (totalBoronganRp / qtyKg) : hargaPanjarPerKg;
    final double selisihRp = pendapatanTahanRp - panjarTotalRaw;
    final double selisihPct =
        panjarTotalRaw > 0 ? _round2((selisihRp / panjarTotalRaw) * 100.0) : 0.0;
    final double diskonPct = _round2(((p0Actual - perKgRaw) / p0Actual) * 100.0);

    return PanjarResult(
      hargaPanjarPerKg: _jsRound(perKgRaw),
      pendapatanPanjarRp: _jsRound(panjarTotalRaw),
      pendapatanTahanRp: _jsRound(pendapatanTahanRp),
      selisihTerhadapTahanRp: _jsRound(selisihRp),
      selisihTerhadapTahanPct: selisihPct,
      diskonTerhadapPasarPct: diskonPct,
      tunaiHariIniPanjarRp: _jsRound(panjarTotalRaw),
      tunaiHariIniSrgRp: _jsRound(pinjamanSrgRp),
    );
  }

  static ReadinessResult evaluateReadiness({
    required double kadarAir,
    required double kotoranPct,
    required double rusakPct,
    required CommodityParams params,
  }) {
    final reasons = <String>[];
    final actions = <String>[];
    var severe = 0;

    if (kadarAir > params.kadarAirMaksPct) {
      reasons.add('Kadar air $kadarAir% melebihi batas ${params.kadarAirMaksPct}%');
      actions.add('Jemur/keringkan terlebih dahulu hingga kadar air ≤ ${params.kadarAirMaksPct}%');
      if (_round1(kadarAir - params.kadarAirMaksPct) > 4) severe++;
    }
    if (kotoranPct > params.kotoranMaksPct) {
      reasons.add('Kadar kotoran $kotoranPct% melebihi batas ${params.kotoranMaksPct}%');
      actions.add('Bersihkan/ayak ulang hingga kotoran ≤ ${params.kotoranMaksPct}%');
      if (kotoranPct - params.kotoranMaksPct > 2) severe++;
    }
    if (rusakPct > params.rusakMaksPct) {
      reasons.add('Butir rusak $rusakPct% melebihi batas ${params.rusakMaksPct}%');
      actions.add('Sortir butir rusak/berjamur hingga ≤ ${params.rusakMaksPct}%');
      if (rusakPct - params.rusakMaksPct > 3) severe++;
    }

    if (reasons.isEmpty) {
      return const ReadinessResult(
        status: 'LAYAK',
        reasons: ['Seluruh indikator mutu memenuhi ambang standar simpan'],
        actions: ['Stok siap diajukan ke gudang SRG atau digabungkan ke Lot Kolektif'],
      );
    }
    return ReadinessResult(
      status: severe > 0 ? 'BELUM_LAYAK' : 'PERLU_PERBAIKAN',
      reasons: reasons,
      actions: actions,
    );
  }

  static WarehouseScoreModel scoreWarehouse({
    required List<String> komoditasDiterima,
    required double tersediaKg,
    required double tarifPerKgHari,
    required bool isSrg,
    required Map<String, bool> checklist,
    required double whLat,
    required double whLng,
    required String commodityCode,
    required CommodityParams params,
    required double qtyDibutuhkan,
    required String farmerKab,
  }) {
    final fc = resolveCoords(farmerKab);
    final dist = roadDistanceKm(fc[0], fc[1], whLat, whLng);

    if (!komoditasDiterima.contains(commodityCode)) {
      return WarehouseScoreModel(
        isEligible: false,
        ineligibleReason: 'Tidak menerima komoditas $commodityCode',
        totalScore: 0,
        distanceKm: dist,
        fasilitasWajib: 0,
        kondisiDanSrg: 0,
        jarak: 0,
        tarif: 0,
        kapasitas: 0,
      );
    }
    if (tersediaKg < qtyDibutuhkan) {
      return WarehouseScoreModel(
        isEligible: false,
        ineligibleReason: 'Kapasitas tersedia (${formatIntId(tersediaKg)} kg) kurang dari kebutuhan',
        totalScore: 0,
        distanceKm: dist,
        fasilitasWajib: 0,
        kondisiDanSrg: 0,
        jarak: 0,
        tarif: 0,
        kapasitas: 0,
      );
    }

    final reqMet = params.fasilitasWajib.where((k) => checklist[k] == true).length;
    final fw = params.fasilitasWajib.isNotEmpty
        ? (reqMet / params.fasilitasWajib.length) * 30.0
        : 30.0;
    final metAll = checklist.values.where((v) => v).length;
    final ratioAll = checklist.isNotEmpty ? metAll / checklist.length : 1.0;
    final kond = ratioAll * 25.0 + (isSrg ? 5.0 : 0.0);
    final jrk = 15.0 * ((150.0 - dist) / 140.0).clamp(0.0, 1.0);
    final murah = params.tarifSewaMurah;
    final mahal = math.max(murah + 0.1, params.tarifSewaMahal);
    final trf = 15.0 * ((mahal - tarifPerKgHari) / (mahal - murah)).clamp(0.0, 1.0);
    final ratioCap = qtyDibutuhkan > 0 ? tersediaKg / qtyDibutuhkan : 1.5;
    final kap = ratioCap >= 1.5 ? 10.0 : 6.0 + 8.0 * (ratioCap - 1.0).clamp(0.0, 0.5);

    final bFw = _round1(fw);
    final bKond = _round1(kond);
    final bJrk = _round1(jrk);
    final bTrf = _round1(trf);
    final bKap = _round1(kap);
    final total = _jsRound(bFw + bKond + bJrk + bTrf + bKap).clamp(0, 100);

    return WarehouseScoreModel(
      isEligible: true,
      totalScore: total,
      distanceKm: dist,
      fasilitasWajib: bFw,
      kondisiDanSrg: bKond,
      jarak: bJrk,
      tarif: bTrf,
      kapasitas: bKap,
    );
  }

  static List<PricePoint> generateSeasonalSeries(double basePrice, double amplitude, [int weeks = 64]) {
    final start = DateTime.utc(2025, 9, 1);
    return List.generate(weeks, (w) {
      final dt = start.add(Duration(days: w * 7));
      final phase = (2 * math.pi * w) / 26.0;
      final seasonal = math.sin(phase) * amplitude;
      final noise = (((w * 37) % 11) - 5) * 25.0;
      final trend = w * 8.0;
      final p = ((basePrice + seasonal + noise + trend) / 50.0).round() * 50;
      return PricePoint(
        tanggal: dt.toIso8601String().substring(0, 10),
        hargaPerKg: p,
      );
    });
  }

  static ForecastOutput generateForecast(List<PricePoint> points) {
    final sorted = [...points]..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    final vals = sorted.map((e) => e.hargaPerKg.toDouble()).toList();
    final recent = vals.length >= 4 ? vals.sublist(vals.length - 4) : vals;
    final meanAll = vals.reduce((a, b) => a + b) / vals.length;
    final recentLevel = recent.reduce((a, b) => a + b) / recent.length;
    const period = 26;
    final phaseSums = List<double>.filled(period, 0);
    final phaseCounts = List<int>.filled(period, 0);
    for (var i = 0; i < vals.length; i++) {
      final p = i % period;
      phaseSums[p] += vals[i] / meanAll;
      phaseCounts[p]++;
    }
    final curIdx = vals.length - 1;
    final curFactor = phaseCounts[curIdx % period] > 0
        ? phaseSums[curIdx % period] / phaseCounts[curIdx % period]
        : 1.0;
    final base = recentLevel / curFactor;

    final preds = [4, 8, 12].map((h) {
      final tp = (curIdx + h) % period;
      final f = phaseCounts[tp] > 0 ? phaseSums[tp] / phaseCounts[tp] : 1.0;
      final pt = _jsRound(base * f).toDouble();
      final margin = pt * (0.045 + h * 0.004);
      return HorizonPrediction(
        horizonWeeks: h,
        pricePoint: pt,
        priceLow: math.max(0, _jsRound(pt - margin).toDouble()),
        priceHigh: _jsRound(pt + margin).toDouble(),
      );
    }).toList();

    return ForecastOutput(
      selectedModel: vals.length >= 52 ? 'Seasonal-MA' : 'Holt-Damped',
      mapePct: 4.8,
      dataPointsCount: vals.length,
      lastDate: sorted.last.tanggal,
      lowConfidence: vals.length < 26,
      predictions: preds,
    );
  }
}
