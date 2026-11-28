const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

export interface UserProfile {
  id: string;
  email: string;
  role: 'petani' | 'gudang' | 'pembeli' | 'admin';
  nama: string;
  kabupaten: string;
  namaOrg?: string;
  isDemo?: boolean;
}

export interface CommodityParams {
  kadar_air_maks_pct: number;
  kadar_kotoran_maks_pct?: number;
  kotoran_maks_pct?: number;
  rusak_maks_pct: number;
  susut_per_bulan: number;
  biaya_pengeringan_per_kg: number;
  tarif_sewa_murah: number;
  tarif_sewa_mahal: number;
  fasilitas_wajib: string[];
}

export interface Commodity {
  id: string;
  kode: string;
  nama: string;
  satuan: string;
  params: CommodityParams;
}

export interface HorizonEval {
  horizonWeeks: number;
  days: number;
  qtyEff: number;
  totalBiayaSimpan: number;
  pendapatanTahan: number;
  selisihRp: number;
  selisihPct: number;
  selisihLowRp: number;
  titikImpasPerKg: number;
}

export interface DecisionResult {
  recommendation: string;
  bestHorizonWeeks: number;
  pendapatanJualSegera: number;
  pinjamanAwal: number;
  qtySiap: number;
  perluPengeringan: boolean;
  susutPengeringanKg: number;
  best: HorizonEval;
  allHorizons: HorizonEval[];
  summarySentence: string;
}

export interface PanjarResult {
  hargaPanjarPerKg: number;
  pendapatanPanjarRp: number;
  pendapatanTahanRp: number;
  selisihTerhadapTahanRp: number;
  diskonTerhadapPasarPct: number;
  tunaiHariIniPanjarRp: number;
  tunaiHariIniSrgRp: number;
}

export interface AIExplanation {
  ringkasan: string;
  alasan: string[];
  langkah_berikut: string[];
  peringatan: string | null;
  fallback_used: boolean;
}

export interface SimResponse {
  latestPrice: number;
  decision: DecisionResult;
  panjar?: PanjarResult | null;
  forecast?: {
    selectedModel: string;
    mapePct: number;
    predictions: { horizonWeeks: number; pricePoint: number; priceLow: number; priceHigh: number }[];
  };
  readiness?: {
    status: string;
    reasons: string[];
    actions: string[];
  };
  offlineMode?: boolean;
}

export function getStoredToken(): string | null {
  return localStorage.getItem('simpanjual_jwt');
}

export function setStoredToken(tok: string | null) {
  if (tok) localStorage.setItem('simpanjual_jwt', tok);
  else localStorage.removeItem('simpanjual_jwt');
}

export function formatRp(n: number, plus = false): string {
  const r = Math.round(n);
  if (r < 0) return `-Rp${Math.abs(r).toLocaleString('id-ID')}`;
  return `${plus && r > 0 ? '+' : ''}Rp${r.toLocaleString('id-ID')}`;
}

export function formatKg(n: number): string {
  if (Number.isInteger(n)) return `${n.toLocaleString('id-ID')} kg`;
  return `${n.toLocaleString('id-ID', { maximumFractionDigits: 1 })} kg`;
}

export function localSimulate(params: {
  commodityKode: string;
  qtyKg: number;
  kadarAirAktual: number;
  useSrgLoan: boolean;
  hargaPanjarPerKg: number;
  panjarMode?: 'per_kg' | 'borongan';
  totalBoronganRp?: number;
  tarifSewaPerKgHari?: number;
  biayaAngkutPerKg?: number;
  bungaTahunan?: number;
}): SimResponse {
  const isGabah = params.commodityKode === 'gabah';
  const ambang = isGabah ? 14 : 15;
  const latestPrice = isGabah ? 6850 : 5450;
  const predictions = isGabah
    ? [
        { horizonWeeks: 4, pricePoint: 7150, priceLow: 6800, priceHigh: 7500 },
        { horizonWeeks: 8, pricePoint: 7650, priceLow: 7200, priceHigh: 8100 },
        { horizonWeeks: 12, pricePoint: 7850, priceLow: 7300, priceHigh: 8400 },
      ]
    : [
        { horizonWeeks: 4, pricePoint: 5750, priceLow: 5450, priceHigh: 6050 },
        { horizonWeeks: 8, pricePoint: 6200, priceLow: 5850, priceHigh: 6550 },
        { horizonWeeks: 12, pricePoint: 6350, priceLow: 5900, priceHigh: 6800 },
      ];

  const qtyKg = Math.max(100, params.qtyKg || 5000);
  const ka = Math.max(10, Math.min(35, params.kadarAirAktual || ambang));
  const perluPengeringan = ka > ambang;
  const qtySiapRaw = perluPengeringan ? qtyKg * ((100 - ka) / (100 - ambang)) : qtyKg;
  const qtySiap = Math.round(qtySiapRaw * 100) / 100;
  const susutPengeringanKg = Math.round((qtyKg - qtySiapRaw) * 100) / 100;
  const biayaPengeringan = perluPengeringan ? Math.round(qtyKg * 150) : 0;

  const sewaRate = params.tarifSewaPerKgHari && params.tarifSewaPerKgHari > 0 ? params.tarifSewaPerKgHari : 2.5;
  const angkutRate = params.biayaAngkutPerKg !== undefined && params.biayaAngkutPerKg >= 0 ? params.biayaAngkutPerKg : 20;
  const bungaRate = params.bungaTahunan && params.bungaTahunan > 0 ? params.bungaTahunan : 0.06;

  const jRaw = qtyKg * latestPrice;
  const pinjamanAwal = params.useSrgLoan ? Math.round(0.7 * qtySiapRaw * latestPrice) : 0;

  const allHorizons: HorizonEval[] = predictions.map((pred) => {
    const days = pred.horizonWeeks * 7;
    const sCum = 1 - Math.pow(1 - 0.005, days / 30);
    const qEffRaw = qtySiapRaw * (1 - sCum);
    const sewa = qtySiapRaw * sewaRate * days;
    const angkut = qtySiapRaw * angkutRate;
    const bunga = pinjamanAwal * bungaRate * (days / 365);
    const totalCost = biayaPengeringan + sewa + angkut + 100000 + bunga;
    const holdRev = qEffRaw * pred.pricePoint - totalCost;
    const gain = holdRev - jRaw;
    const lowGain = qEffRaw * pred.priceLow - totalCost - jRaw;
    const breakEven = Math.ceil((jRaw + totalCost) / qEffRaw);

    return {
      horizonWeeks: pred.horizonWeeks,
      days,
      qtyEff: Math.round(qEffRaw * 100) / 100,
      totalBiayaSimpan: Math.round(totalCost),
      pendapatanTahan: Math.round(holdRev),
      selisihRp: Math.round(gain),
      selisihPct: Math.round((gain / jRaw) * 10000) / 100,
      selisihLowRp: Math.round(lowGain),
      titikImpasPerKg: breakEven,
    };
  });

  const best = allHorizons.reduce((acc, cur) => (cur.selisihRp > acc.selisihRp ? cur : acc), allHorizons[0]);
  let recommendation = 'JUAL';
  if (best.selisihRp > 0 && best.selisihLowRp > 0) recommendation = 'TAHAN';
  else if (best.selisihRp > 0) recommendation = 'TAHAN_BERISIKO';

  const summarySentence =
    recommendation === 'JUAL'
      ? `Menahan stok belum menutup biaya simpan. Jual sekarang lebih aman kecuali harga naik di atas ${formatRp(best.titikImpasPerKg)}/kg.`
      : `Menahan ${best.horizonWeeks} minggu layak bila harga jual mencapai minimal ${formatRp(best.titikImpasPerKg)}/kg.`;

  const isBorongan = params.panjarMode === 'borongan';
  const pendapatanPanjarRp = isBorongan
    ? Math.round(params.totalBoronganRp && params.totalBoronganRp > 0 ? params.totalBoronganRp : 19000000)
    : Math.round((params.hargaPanjarPerKg > 0 ? params.hargaPanjarPerKg : 3800) * qtyKg);
  const panjarPrice = isBorongan
    ? Math.round(pendapatanPanjarRp / qtyKg)
    : params.hargaPanjarPerKg > 0
      ? params.hargaPanjarPerKg
      : 3800;
  const selisihTerhadapTahanRp = best.pendapatanTahan - pendapatanPanjarRp;

  return {
    latestPrice,
    decision: {
      recommendation,
      bestHorizonWeeks: best.horizonWeeks,
      pendapatanJualSegera: Math.round(jRaw),
      pinjamanAwal,
      qtySiap,
      perluPengeringan,
      susutPengeringanKg,
      best,
      allHorizons,
      summarySentence,
    },
    panjar: {
      hargaPanjarPerKg: panjarPrice,
      pendapatanPanjarRp,
      pendapatanTahanRp: best.pendapatanTahan,
      selisihTerhadapTahanRp,
      diskonTerhadapPasarPct: Math.round(((latestPrice - panjarPrice) / latestPrice) * 1000) / 10,
      tunaiHariIniPanjarRp: pendapatanPanjarRp,
      tunaiHariIniSrgRp: pinjamanAwal,
    },
    forecast: {
      selectedModel: 'Seasonal-MA',
      mapePct: 4.8,
      predictions,
    },
    readiness: {
      status: perluPengeringan ? 'PERLU_PERBAIKAN' : 'LAYAK',
      reasons: perluPengeringan
        ? [`Kadar air ${ka}% melebihi ambang simpan ${ambang}%`]
        : ['Seluruh indikator mutu memenuhi standar simpan gudang'],
      actions: perluPengeringan
        ? [`Jemur terlebih dahulu hingga kadar air maksimal ${ambang}%`]
        : ['Stok siap diajukan ke gudang SRG atau Lot Kolektif Poktan'],
    },
    offlineMode: true,
  };
}

export function localExplainAI(decision: DecisionResult): AIExplanation {
  const beStr = `${formatRp(decision.best.titikImpasPerKg)}/kg`;
  const biayaStr = formatRp(decision.best.totalBiayaSimpan);
  const absSelisihStr = formatRp(Math.abs(decision.best.selisihRp));

  const ringkasan =
    decision.recommendation === 'JUAL'
      ? `Sebaiknya jual sekarang karena perkiraan kenaikan harga belum menutup biaya simpan (${biayaStr}).`
      : `Disarankan menahan selama ${decision.bestHorizonWeeks} minggu dengan perkiraan tambahan hasil ${absSelisihStr} jika harga minimal ${beStr}.`;

  const langkah_berikut =
    decision.recommendation === 'JUAL'
      ? ['Buka daftar kebutuhan pembeli di tab Janji Beli.', 'Bandingkan harga tawar dengan harga pasar hari ini.']
      : ['Periksa kesiapan kadar air stok Anda.', 'Cari gudang terdekat atau gabung Lot Kolektif poktan.'];

  const peringatan =
    decision.recommendation === 'TAHAN_BERISIKO'
      ? 'Prediksi masih memiliki risiko turun di batas bawah. Pantau harga mingguan secara berkala.'
      : null;

  return {
    ringkasan,
    alasan: [
      `Titik impas harga jual setelah simpan adalah ${beStr}.`,
      `Total biaya simpan, angkut, susut, dan bunga tercatat sebesar ${biayaStr}.`,
    ],
    langkah_berikut,
    peringatan,
    fallback_used: true,
  };
}

let backendMarkedDownUntil = 0;

export function resetBackendCircuit() {
  backendMarkedDownUntil = 0;
}

export async function apiFetch<T = Record<string, any>>(
  path: string,
  options: RequestInit & { idempotent?: boolean } = {}
): Promise<T> {
  if (Date.now() < backendMarkedDownUntil) {
    throw new Error('Server Go lokal sedang tidak aktif (Mode Simulasi Mandiri)');
  }

  const headers = new Headers(options.headers);
  headers.set('Content-Type', 'application/json');
  const tok = getStoredToken();
  if (tok && !tok.startsWith('offline-')) {
    headers.set('Authorization', `Bearer ${tok}`);
  }
  if (options.idempotent) {
    headers.set('Idempotency-Key', `web-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`);
  }

  const controller = new AbortController();
  const timer = window.setTimeout(() => controller.abort(), 5000);
  try {
    const res = await fetch(`${API_BASE}${path}`, {
      ...options,
      headers,
      signal: controller.signal,
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data?.error || `Permintaan gagal (${res.status})`);
    }
    backendMarkedDownUntil = 0;
    return data as T;
  } catch (err) {
    if (err instanceof TypeError || (err instanceof DOMException && err.name === 'AbortError')) {
      backendMarkedDownUntil = Date.now() + 15000;
    }
    throw err;
  } finally {
    window.clearTimeout(timer);
  }
}
