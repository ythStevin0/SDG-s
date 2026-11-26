import { describe, expect, it } from 'vitest';
import {
  buildTemplateExplanation,
  regexExtractOffer,
  stripPii,
  validateAiExplanationNumbers,
} from '@/lib/ai/guard';
import { evaluateHoldVsSell } from '@/lib/engine/decision';
import { calculateDryingConversion } from '@/lib/engine/drying';
import { evaluatePanjarTandingan } from '@/lib/engine/panjar';
import { evaluateStorageReadiness } from '@/lib/engine/readiness';
import { scoreWarehouse } from '@/lib/engine/warehouse-score';
import { generatePriceForecast } from '@/lib/forecast/backtest';
import type { CommodityParams } from '@/db/schema';

const jagungParams: CommodityParams = {
  kadar_air_maks_pct: 15,
  kotoran_maks_pct: 3,
  rusak_maks_pct: 5,
  susut_per_bulan: 0.005,
  susut_rumah_per_bulan: 0.03,
  biaya_pengeringan_per_kg: 150,
  tarif_sewa_murah: 1,
  tarif_sewa_mahal: 8,
  fasilitas_wajib: ['ventilasi', 'lantai_palet_kering', 'kontrol_hama'],
};

describe('Drying & Decision Engine (Bagian 8.1 & Fixture 8.7)', () => {
  it('menghitung tepat sesuai fixture terkoreksi Bagian 8.7 (tanpa pembulatan tengah, Math.ceil titik impas)', () => {
    const res = evaluateHoldVsSell({
      qtyKg: 5000,
      kadarAirAktual: 14,
      kadarAirAmbang: 15,
      p0Dry: 5000,
      predictions: [{ horizonWeeks: 8, pricePoint: 5800, priceLow: 5250, priceHigh: 6350 }],
      tarifSewaPerKgHari: 3,
      biayaAngkutPerKg: 20,
      biayaTetap: 150000,
      susutPerBulan: 0.01,
      rasioPinjaman: 0.7,
      bungaTahunan: 0.12,
    });

    expect(res.perluPengeringan).toBe(false);
    expect(res.pendapatanJualSegera).toBe(25_000_000);
    expect(res.best.qtyEff).toBe(4907.07);
    expect(res.best.bungaPinjaman).toBe(322_192);
    expect(res.best.totalBiayaSimpan).toBe(1_412_192);
    expect(res.best.pendapatanTahan).toBe(27_048_822);
    expect(res.best.selisihRp).toBe(2_048_822);
    expect(res.best.titikImpasPerKg).toBe(5383);
    expect(res.recommendation).toBe('TAHAN_BERISIKO');
  });

  it('otomatis mengonversi susut bobot & biaya pengeringan saat kadar air melebihi ambang (GKP 24% -> GKG 14%)', () => {
    const dry = calculateDryingConversion({
      qtyKg: 5000,
      kadarAirAktual: 24,
      kadarAirAmbang: 14,
      biayaPengeringanPerKg: 150,
    });

    expect(dry.perluPengeringan).toBe(true);
    expect(dry.qtySiap).toBeCloseTo(4418.6, 2);
    expect(dry.biayaPengeringanRp).toBe(750_000);
  });

  it('mengeluarkan status TAHAN penuh jika batas bawah prediksi tetap untung dan JUAL jika rugi', () => {
    const safeHold = evaluateHoldVsSell({
      qtyKg: 5000,
      kadarAirAktual: 14,
      kadarAirAmbang: 15,
      p0Dry: 5000,
      predictions: [{ horizonWeeks: 8, pricePoint: 6200, priceLow: 5700, priceHigh: 6600 }],
      tarifSewaPerKgHari: 3,
      biayaAngkutPerKg: 20,
      biayaTetap: 150000,
      susutPerBulan: 0.005,
      rasioPinjaman: 0.7,
      bungaTahunan: 0.06,
    });
    expect(safeHold.recommendation).toBe('TAHAN');

    const sellNow = evaluateHoldVsSell({
      qtyKg: 5000,
      kadarAirAktual: 14,
      kadarAirAmbang: 15,
      p0Dry: 5000,
      predictions: [{ horizonWeeks: 4, pricePoint: 5050, priceLow: 4800, priceHigh: 5200 }],
      tarifSewaPerKgHari: 4,
      biayaAngkutPerKg: 20,
      biayaTetap: 150000,
      susutPerBulan: 0.01,
      rasioPinjaman: 0,
      bungaTahunan: 0.06,
    });
    expect(sellNow.recommendation).toBe('JUAL');
  });
});

describe('Panjar Tandingan & Readiness Engine', () => {
  it('menghitung konsisten antara mode per_kg dan borongan tebasan', () => {
    const perKg = evaluatePanjarTandingan({
      mode: 'per_kg',
      hargaPanjarPerKg: 3500,
      qtyKg: 5000,
      p0Actual: 5000,
      pendapatanTahanRp: 27_048_822,
      pinjamanSrgRp: 17_500_000,
    });
    const borongan = evaluatePanjarTandingan({
      mode: 'borongan',
      totalBoronganRp: 17_500_000,
      qtyKg: 5000,
      p0Actual: 5000,
      pendapatanTahanRp: 27_048_822,
      pinjamanSrgRp: 17_500_000,
    });

    expect(perKg.selisihTerhadapTahanRp).toBe(9_548_822);
    expect(perKg.diskonTerhadapPasarPct).toBe(30);
    expect(borongan.hargaPanjarPerKg).toBe(3500);
    expect(borongan.selisihTerhadapTahanRp).toBe(perKg.selisihTerhadapTahanRp);
  });

  it('menilai kesiapan mutu simpan secara akurat pada batas ambang', () => {
    expect(evaluateStorageReadiness({ kadarAir: 15, kotoranPct: 3, rusakPct: 5 }, jagungParams).status).toBe(
      'LAYAK'
    );
    expect(
      evaluateStorageReadiness({ kadarAir: 17, kotoranPct: 3, rusakPct: 5 }, jagungParams).status
    ).toBe('PERLU_PERBAIKAN');
    expect(
      evaluateStorageReadiness({ kadarAir: 24, kotoranPct: 3, rusakPct: 5 }, jagungParams).status
    ).toBe('BELUM_LAYAK');
  });
});

describe('Warehouse Score Anti-NaN', () => {
  it('menghasilkan skor valid 0-100 meski hanya ada 1 gudang dan saat lat/lng stok null', () => {
    const res = scoreWarehouse({
      warehouse: {
        id: 'w1',
        nama: 'Gudang SRG Banyumas',
        kabupaten: 'Banyumas',
        lat: -7.4314,
        lng: 109.2478,
        kapasitasKg: 100000,
        tersediaKg: 80000,
        tarifPerKgHari: 2.5,
        minVolumeKg: 5000,
        minHari: 30,
        isSrg: true,
        komoditasDiterima: ['jagung', 'gabah'],
        checklist: {
          atap_tidak_bocor: true,
          ventilasi: true,
          lantai_palet_kering: true,
          kontrol_hama: true,
          alat_ukur_ka: true,
          keamanan_suhu: true,
        },
      },
      commodityCode: 'jagung',
      commodityParams: jagungParams,
      qtyDibutuhkan: 5000,
      farmerLocation: { kabupaten: 'Banyumas', lat: null, lng: null },
    });

    expect(res.isEligible).toBe(true);
    expect(Number.isNaN(res.totalScore)).toBe(false);
    expect(res.totalScore).toBeGreaterThan(85);
    expect(res.totalScore).toBeLessThanOrEqual(100);
  });

  it('menandai ineligible jika komoditas tidak diterima atau kapasitas kurang', () => {
    const res = scoreWarehouse({
      warehouse: {
        id: 'w2',
        nama: 'Gudang Khusus Gabah',
        kabupaten: 'Banyumas',
        lat: -7.43,
        lng: 109.24,
        kapasitasKg: 10000,
        tersediaKg: 2000,
        tarifPerKgHari: 3,
        minVolumeKg: 1000,
        minHari: 14,
        isSrg: false,
        komoditasDiterima: ['gabah'],
        checklist: {
          atap_tidak_bocor: true,
          ventilasi: true,
          lantai_palet_kering: true,
          kontrol_hama: true,
          alat_ukur_ka: false,
          keamanan_suhu: false,
        },
      },
      commodityCode: 'jagung',
      commodityParams: jagungParams,
      qtyDibutuhkan: 5000,
      farmerLocation: { kabupaten: 'Banyumas' },
    });

    expect(res.isEligible).toBe(false);
    expect(res.totalScore).toBe(0);
  });
});

describe('Price Forecast & Backtest', () => {
  it('memilih model terendah MAPE dan menjaga interval priceLow <= pricePoint <= priceHigh', () => {
    const series = Array.from({ length: 64 }, (_, i) => ({
      tanggal: new Date(Date.UTC(2025, 0, 1 + i * 7)).toISOString().slice(0, 10),
      hargaPerKg: Math.round(5000 + Math.sin((2 * Math.PI * i) / 26) * 450),
    }));

    const out = generatePriceForecast(series);
    expect(out.lowConfidence).toBe(false);
    expect(out.mapePct).toBeGreaterThanOrEqual(0);
    expect(out.predictions).toHaveLength(3);
    for (const p of out.predictions) {
      expect(p.priceLow).toBeLessThanOrEqual(p.pricePoint);
      expect(p.pricePoint).toBeLessThanOrEqual(p.priceHigh);
    }
  });
});

describe('AI Guardrail & Fallback (F14 & F15)', () => {
  const allowed = [8, 2_048_822, 8.2, 5383, 5000, 1_412_192];

  it('mengabaikan angka urutan kalimat & menerima pembulatan jutaan dalam toleransi 5%', () => {
    const ok = validateAiExplanationNumbers(
      [
        '1. Menahan selama 8 minggu berpotensi memberi tambahan sekitar Rp2,0 juta.',
        '2. Pastikan harga jual di atas titik impas Rp5.383/kg.',
      ],
      allowed
    );
    expect(ok.valid).toBe(true);
  });

  it('menolak angka halusinasi di luar data input', () => {
    const bad = validateAiExplanationNumbers(
      ['Keuntungan dijamin naik menjadi Rp8,5 juta dalam 8 minggu.'],
      allowed
    );
    expect(bad.valid).toBe(false);
    expect(bad.offendingToken).toContain('8,5 juta');
  });

  it('menghapus PII nomor HP/email dan mengonversi ton/kuintal di regex fallback', () => {
    const sanitized = stripPii('Hubungi 0812-3456-7890 atau tani@mail.com');
    expect(sanitized).not.toContain('0812-3456-7890');
    expect(sanitized).not.toContain('tani@mail.com');

    const extracted = regexExtractOffer('Saya panjar 3,5 ton jagung harga Rp3.500/kg, WA 08123456789');
    expect(extracted.jenis).toBe('panjar');
    expect(extracted.jumlah_kg).toBe(3500);
    expect(extracted.harga_per_kg).toBe(3500);

    const tpl = buildTemplateExplanation({
      recommendation: 'TAHAN_BERISIKO',
      horizonWeeks: 8,
      titikImpasPerKg: 5383,
      selisihRp: 2_048_822,
      totalBiayaSimpan: 1_412_192,
    });
    expect(tpl.ringkasan).toContain('8 minggu');
    expect(tpl.alasan[0]).toContain('5.383');
  });
});
