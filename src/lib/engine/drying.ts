export interface DryingInput {
  qtyKg: number;
  kadarAirAktual: number;
  kadarAirAmbang: number;
  biayaPengeringanPerKg: number;
}

export interface DryingResult {
  perluPengeringan: boolean;
  qtySiapRaw: number;
  qtySiap: number;
  susutPengeringanKg: number;
  biayaPengeringanRp: number;
}

/**
 * Menghitung konversi bobot dan ongkos pengeringan dari kadar air aktual (mis. GKP 24%)
 * menuju kadar air standar simpan gudang (mis. GKG 14%) memakai kesetimbangan bahan kering.
 */
export function calculateDryingConversion(input: DryingInput): DryingResult {
  const { qtyKg, kadarAirAktual, kadarAirAmbang, biayaPengeringanPerKg } = input;
  if (qtyKg <= 0) throw new Error('Jumlah stok (qtyKg) harus lebih dari 0');
  if (kadarAirAktual < 0 || kadarAirAktual >= 100) {
    throw new Error('Kadar air aktual harus antara 0 dan < 100%');
  }
  if (kadarAirAmbang <= 0 || kadarAirAmbang >= 100) {
    throw new Error('Ambang kadar air tidak valid');
  }

  if (kadarAirAktual <= kadarAirAmbang) {
    return {
      perluPengeringan: false,
      qtySiapRaw: qtyKg,
      qtySiap: Number(qtyKg.toFixed(2)),
      susutPengeringanKg: 0,
      biayaPengeringanRp: 0,
    };
  }

  const qtySiapRaw = qtyKg * ((100 - kadarAirAktual) / (100 - kadarAirAmbang));
  const biayaPengeringanRp = Math.round(qtyKg * Math.max(0, biayaPengeringanPerKg));
  return {
    perluPengeringan: true,
    qtySiapRaw,
    qtySiap: Number(qtySiapRaw.toFixed(2)),
    susutPengeringanKg: Number((qtyKg - qtySiapRaw).toFixed(2)),
    biayaPengeringanRp,
  };
}
