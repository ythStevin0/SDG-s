import { calculateDryingConversion } from './drying';

export type RecommendationStatus = 'TAHAN' | 'TAHAN_BERISIKO' | 'JUAL';

export interface HorizonPrediction {
  horizonWeeks: 4 | 8 | 12;
  pricePoint: number;
  priceLow: number;
  priceHigh: number;
}

export interface DecisionInput {
  qtyKg: number;
  kadarAirAktual: number;
  kadarAirAmbang: number;
  biayaPengeringanPerKg?: number;
  p0Dry: number; // Harga pasar saat ini mutu standar simpan (Rp/kg)
  p0Actual?: number; // Harga jual segera aktual (default = p0Dry bila sudah kering)
  predictions: HorizonPrediction[];
  tarifSewaPerKgHari: number; // c_s
  biayaAngkutPerKg: number; // c_t
  biayaTetap: number; // A
  susutPerBulan: number; // s_b (pecahan, mis. 0.005 atau 0.01)
  rasioPinjaman: number; // rho (0 jika tanpa pinjaman, 0.70 S-SRG)
  bungaTahunan: number; // r (0.06 S-SRG, 0.12 komersial)
}

export interface HorizonEvaluation {
  horizonWeeks: 4 | 8 | 12;
  days: number;
  susutSimpanPct: number;
  qtyEff: number;
  biayaSewa: number;
  biayaAngkut: number;
  biayaTetap: number;
  biayaPengeringan: number;
  bungaPinjaman: number;
  totalBiayaSimpan: number;
  pendapatanTahan: number;
  selisihRp: number;
  selisihPct: number;
  selisihLowRp: number;
  titikImpasPerKg: number;
}

export interface DecisionResult {
  recommendation: RecommendationStatus;
  bestHorizonWeeks: 4 | 8 | 12;
  pendapatanJualSegera: number;
  pinjamanAwal: number;
  qtySiap: number;
  perluPengeringan: boolean;
  susutPengeringanKg: number;
  best: HorizonEvaluation;
  allHorizons: HorizonEvaluation[];
  summarySentence: string;
}

export function evaluateHoldVsSell(input: DecisionInput): DecisionResult {
  if (input.qtyKg <= 0) throw new Error('qtyKg harus lebih besar dari 0');
  if (input.p0Dry <= 0) throw new Error('Harga pasar saat ini harus positif');
  if (!input.predictions.length) throw new Error('Minimal satu horizon prediksi diperlukan');

  const drying = calculateDryingConversion({
    qtyKg: input.qtyKg,
    kadarAirAktual: input.kadarAirAktual,
    kadarAirAmbang: input.kadarAirAmbang,
    biayaPengeringanPerKg: input.biayaPengeringanPerKg ?? 150,
  });

  const p0Actual = input.p0Actual ?? input.p0Dry;
  const jRaw = input.qtyKg * p0Actual;
  const loanRaw = input.rasioPinjaman * (drying.qtySiapRaw * input.p0Dry);
  const cDryRaw = drying.perluPengeringan
    ? input.qtyKg * Math.max(0, input.biayaPengeringanPerKg ?? 150)
    : 0;

  const evaluations: HorizonEvaluation[] = input.predictions.map((pred) => {
    const days = pred.horizonWeeks * 7;
    const sCumRaw = 1 - Math.pow(1 - input.susutPerBulan, days / 30);
    const qEffRaw = drying.qtySiapRaw * (1 - sCumRaw);

    const sewaRaw = drying.qtySiapRaw * input.tarifSewaPerKgHari * days;
    const angkutRaw = drying.qtySiapRaw * input.biayaAngkutPerKg;
    const bungaRaw = loanRaw * input.bungaTahunan * (days / 365);
    const totalCostRaw = cDryRaw + sewaRaw + angkutRaw + input.biayaTetap + bungaRaw;

    const holdRevRaw = qEffRaw * pred.pricePoint - totalCostRaw;
    const gainRaw = holdRevRaw - jRaw;
    const lowRevRaw = qEffRaw * pred.priceLow - totalCostRaw;
    const lowGainRaw = lowRevRaw - jRaw;

    // Pembulatan hanya di output akhir; titik impas memakai Math.ceil agar G >= 0 terjamin
    const breakEven = Math.ceil((jRaw + totalCostRaw) / qEffRaw);

    return {
      horizonWeeks: pred.horizonWeeks,
      days,
      susutSimpanPct: Number((sCumRaw * 100).toFixed(2)),
      qtyEff: Number(qEffRaw.toFixed(2)),
      biayaSewa: Math.round(sewaRaw),
      biayaAngkut: Math.round(angkutRaw),
      biayaTetap: Math.round(input.biayaTetap),
      biayaPengeringan: Math.round(cDryRaw),
      bungaPinjaman: Math.round(bungaRaw),
      totalBiayaSimpan: Math.round(totalCostRaw),
      pendapatanTahan: Math.round(holdRevRaw),
      selisihRp: Math.round(gainRaw),
      selisihPct: jRaw > 0 ? Number(((gainRaw / jRaw) * 100).toFixed(2)) : 0,
      selisihLowRp: Math.round(lowGainRaw),
      titikImpasPerKg: breakEven,
    };
  });

  // Pilih horizon dengan selisih keuntungan terbesar
  const best = evaluations.reduce((acc, cur) => (cur.selisihRp > acc.selisihRp ? cur : acc));

  let recommendation: RecommendationStatus = 'JUAL';
  if (best.selisihRp > 0 && best.selisihLowRp > 0) {
    recommendation = 'TAHAN';
  } else if (best.selisihRp > 0) {
    recommendation = 'TAHAN_BERISIKO';
  }

  const formattedBe = best.titikImpasPerKg.toLocaleString('id-ID');
  const summarySentence =
    recommendation === 'JUAL'
      ? `Menahan stok belum menutup biaya simpan. Jual sekarang lebih aman kecuali harga naik di atas Rp${formattedBe}/kg.`
      : `Menahan ${best.horizonWeeks} minggu layak bila harga jual mencapai minimal Rp${formattedBe}/kg.`;

  return {
    recommendation,
    bestHorizonWeeks: best.horizonWeeks,
    pendapatanJualSegera: Math.round(jRaw),
    pinjamanAwal: Math.round(loanRaw),
    qtySiap: drying.qtySiap,
    perluPengeringan: drying.perluPengeringan,
    susutPengeringanKg: drying.susutPengeringanKg,
    best,
    allHorizons: evaluations,
    summarySentence,
  };
}
