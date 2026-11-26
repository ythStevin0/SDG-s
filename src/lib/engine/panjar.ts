export interface PanjarInput {
  mode: 'per_kg' | 'borongan';
  hargaPanjarPerKg?: number;
  totalBoronganRp?: number;
  qtyKg: number;
  p0Actual: number;
  pendapatanTahanRp: number;
  pinjamanSrgRp: number;
}

export interface PanjarResult {
  hargaPanjarPerKg: number;
  pendapatanPanjarRp: number;
  pendapatanTahanRp: number;
  selisihTerhadapTahanRp: number;
  selisihTerhadapTahanPct: number;
  diskonTerhadapPasarPct: number;
  tunaiHariIniPanjarRp: number;
  tunaiHariIniSrgRp: number;
}

export function evaluatePanjarTandingan(input: PanjarInput): PanjarResult {
  if (input.qtyKg <= 0) throw new Error('qtyKg harus lebih besar dari 0');
  if (input.p0Actual <= 0) throw new Error('Harga pasar saat ini harus positif');

  let pendapatanPanjarRaw = 0;
  let hargaPanjarPerKgRaw = 0;

  if (input.mode === 'borongan') {
    const total = input.totalBoronganRp ?? 0;
    if (total <= 0) throw new Error('Total tawaran borongan harus positif');
    pendapatanPanjarRaw = total;
    hargaPanjarPerKgRaw = total / input.qtyKg;
  } else {
    const perKg = input.hargaPanjarPerKg ?? 0;
    if (perKg <= 0) throw new Error('Harga panjar per kg harus positif');
    hargaPanjarPerKgRaw = perKg;
    pendapatanPanjarRaw = perKg * input.qtyKg;
  }

  const selisihRp = input.pendapatanTahanRp - pendapatanPanjarRaw;
  const selisihPct =
    pendapatanPanjarRaw > 0 ? Number(((selisihRp / pendapatanPanjarRaw) * 100).toFixed(2)) : 0;
  const diskonPasarPct = Number(
    (((input.p0Actual - hargaPanjarPerKgRaw) / input.p0Actual) * 100).toFixed(2)
  );

  return {
    hargaPanjarPerKg: Math.round(hargaPanjarPerKgRaw),
    pendapatanPanjarRp: Math.round(pendapatanPanjarRaw),
    pendapatanTahanRp: Math.round(input.pendapatanTahanRp),
    selisihTerhadapTahanRp: Math.round(selisihRp),
    selisihTerhadapTahanPct: selisihPct,
    diskonTerhadapPasarPct: diskonPasarPct,
    tunaiHariIniPanjarRp: Math.round(pendapatanPanjarRaw),
    tunaiHariIniSrgRp: Math.round(input.pinjamanSrgRp),
  };
}
