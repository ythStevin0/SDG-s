import 'package:flutter_test/flutter_test.dart';
import 'package:simpanjual_mobile/core/engine.dart';
import 'package:simpanjual_mobile/core/models.dart';

void main() {
  test('Fixture PRD 8.7: Hold vs Sell & Panjar Tandingan akurat di Dart Engine', () {
    final dec = SimpanJualEngine.evaluateHoldVsSell(
      qtyKg: 5000,
      kadarAirAktual: 14,
      kadarAirAmbang: 15,
      p0Dry: 5000,
      predictions: const [
        HorizonPrediction(
          horizonWeeks: 8,
          pricePoint: 5800,
          priceLow: 5500,
          priceHigh: 6100,
        ),
      ],
      tarifSewaPerKgHari: 3,
      biayaAngkutPerKg: 20,
      biayaTetap: 150000,
      susutPerBulan: 0.01,
      rasioPinjaman: 0.70,
      bungaTahunan: 0.12,
    );

    expect(dec.pendapatanJualSegera, 25000000);
    expect(dec.pinjamanAwal, 17500000);
    expect(dec.best.qtyEff, 4907.07);
    expect(dec.best.totalBiayaSimpan, 1412192);
    expect(dec.best.pendapatanTahan, 27048822);
    expect(dec.best.selisihRp, 2048822);
    expect(dec.best.titikImpasPerKg, 5383);
    expect(dec.recommendation, 'TAHAN');

    final pj = SimpanJualEngine.evaluatePanjar(
      mode: 'borongan',
      totalBoronganRp: 17500000,
      qtyKg: 5000,
      p0Actual: 5000,
      pendapatanTahanRp: dec.best.pendapatanTahan.toDouble(),
      pinjamanSrgRp: dec.pinjamanAwal.toDouble(),
    );
    expect(pj.selisihTerhadapTahanRp, 9548822);
    expect(pj.diskonTerhadapPasarPct, 30.0);
  });

  test('Konversi Gabah Basah GKP 24% ke GKG 14% & Skor Gudang Anti-NaN', () {
    final dry = SimpanJualEngine.calculateDrying(
      qtyKg: 5000,
      kadarAirAktual: 24,
      kadarAirAmbang: 14,
      biayaPengeringanPerKg: 150,
    );
    expect(dry.perluPengeringan, isTrue);
    expect(dry.qtySiap, 4418.60);
    expect(dry.biayaRp, 750000);

    const params = CommodityParams(
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
    final score = SimpanJualEngine.scoreWarehouse(
      komoditasDiterima: const ['jagung'],
      tersediaKg: 82000,
      tarifPerKgHari: 2.5,
      isSrg: true,
      checklist: const {
        'atap_tidak_bocor': true,
        'ventilasi': true,
        'lantai_palet_kering': true,
        'kontrol_hama': true,
        'alat_ukur_ka': true,
        'keamanan_suhu': true,
      },
      whLat: -7.4314,
      whLng: 109.2478,
      commodityCode: 'jagung',
      params: params,
      qtyDibutuhkan: 5000,
      farmerKab: 'Banyumas',
    );
    expect(score.isEligible, isTrue);
    expect(score.totalScore, greaterThan(80));
    expect(score.distanceKm.isNaN, isFalse);
  });
}
