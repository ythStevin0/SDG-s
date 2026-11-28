import { Commodity, localSimulate, SimResponse, UserProfile } from './api';

export interface StockItem {
  id: string;
  commodityKode: string;
  commodityNama: string;
  qtyKg: number;
  reservedKg: number;
  soldKg: number;
  freeKg: number;
  kadarAir: number;
  tglPanen: string;
  kabupaten: string;
  status: string;
  catatan?: string;
}

export interface WarehouseItem {
  id: string;
  nama: string;
  kabupaten: string;
  lat: number;
  lng: number;
  kapasitasKg: number;
  tersediaKg: number;
  tarifPerKgHari: number;
  minVolumeKg: number;
  minHari: number;
  isSrg: boolean;
  checklist: Record<string, boolean>;
  kontakWa?: string;
  score: {
    isEligible: boolean;
    totalScore: number;
    distanceKm: number;
    ineligibleReason?: string;
  };
}

export interface LotItem {
  id: string;
  groupId: string;
  groupNama: string;
  kodeGabung: string;
  commodityKode: string;
  commodityNama: string;
  targetKg: number;
  terkumpulKg: number;
  progressPct: number;
  status: string;
  warehouseNama?: string;
}

export interface DemandItem {
  id: string;
  buyerNama: string;
  buyerOrg?: string;
  commodityKode: string;
  commodityNama: string;
  qtyKg: number;
  terpenuhiKg: number;
  sisaKuotaKg: number;
  progressPct: number;
  hargaAcuan: number;
  dibutuhkanPada: string;
  kabupaten: string;
  catatanMutu?: string;
}

export interface RentalItem {
  id: string;
  requesterNama: string;
  warehouseNama: string;
  qtyKg: number;
  hari: number;
  estimasiBiaya?: number;
  kontakWa?: string;
  status: string;
  alasanTolak?: string;
}

export interface SaleItem {
  id: string;
  sellerNama: string;
  buyerNama?: string;
  buyerNoWa?: string;
  commodityNama: string;
  qtyKg: number;
  hargaTawar: number;
  status: string;
  alasanTolak?: string;
}

export const JATENG_COORDS: Record<string, [number, number]> = {
  Banyumas: [-7.4502, 109.1623],
  Cilacap: [-7.7188, 109.0154],
  Purbalingga: [-7.3881, 109.3639],
  Banjarnegara: [-7.3987, 109.6967],
  Kebumen: [-7.6691, 109.6531],
  Brebes: [-6.8706, 109.0442],
  Demak: [-6.8909, 110.6396],
};

export const DEMO_USERS: Record<string, UserProfile> = {
  petani: {
    id: 'u-petani',
    email: 'petani@demo.id',
    role: 'petani',
    nama: 'Pak Slamet',
    kabupaten: 'Banyumas',
    isDemo: true,
  },
  poktan: {
    id: 'u-poktan',
    email: 'poktan@demo.id',
    role: 'petani',
    nama: 'Bu Rini (Ketua Poktan)',
    kabupaten: 'Banyumas',
    namaOrg: 'Poktan Tani Jaya',
    isDemo: true,
  },
  gudang: {
    id: 'u-gudang',
    email: 'gudang@demo.id',
    role: 'gudang',
    nama: 'Pak Joko (Pengelola SRG)',
    kabupaten: 'Banyumas',
    namaOrg: 'Gudang SRG Banyumas',
    isDemo: true,
  },
  pembeli: {
    id: 'u-pembeli',
    email: 'pembeli@demo.id',
    role: 'pembeli',
    nama: 'Koperasi & SPPG Mitra Banyumas',
    kabupaten: 'Banyumas',
    namaOrg: 'Koperasi Pangan Banyumas',
    isDemo: true,
  },
  admin: {
    id: 'u-admin',
    email: 'admin@demo.id',
    role: 'admin',
    nama: 'Admin SimpanJual',
    kabupaten: 'Banyumas',
    isDemo: true,
  },
};

export const OFFLINE_COMMODITIES: Commodity[] = [
  {
    id: 'c-jagung',
    kode: 'jagung',
    nama: 'Jagung Pipil',
    satuan: 'kg',
    params: {
      kadar_air_maks_pct: 15,
      kotoran_maks_pct: 3,
      rusak_maks_pct: 5,
      susut_per_bulan: 0.005,
      biaya_pengeringan_per_kg: 150,
      tarif_sewa_murah: 1,
      tarif_sewa_mahal: 8,
      fasilitas_wajib: ['ventilasi', 'lantai_palet_kering', 'kontrol_hama'],
    },
  },
  {
    id: 'c-gabah',
    kode: 'gabah',
    nama: 'Gabah Kering Giling (GKG)',
    satuan: 'kg',
    params: {
      kadar_air_maks_pct: 14,
      kotoran_maks_pct: 3,
      rusak_maks_pct: 5,
      susut_per_bulan: 0.005,
      biaya_pengeringan_per_kg: 150,
      tarif_sewa_murah: 1,
      tarif_sewa_mahal: 8,
      fasilitas_wajib: ['ventilasi', 'lantai_palet_kering', 'kontrol_hama'],
    },
  },
];

export const INITIAL_OFFLINE_STOCKS: StockItem[] = [
  {
    id: 'st-1',
    commodityKode: 'jagung',
    commodityNama: 'Jagung Pipil',
    qtyKg: 5000,
    reservedKg: 0,
    soldKg: 0,
    freeKg: 5000,
    kadarAir: 14.5,
    tglPanen: '2026-11-20',
    kabupaten: 'Banyumas',
    status: 'tersedia',
    catatan: 'Panen blok sawah Sokaraja, jagung pipil kuning',
  },
  {
    id: 'st-2',
    commodityKode: 'gabah',
    commodityNama: 'Gabah Kering Giling (GKG)',
    qtyKg: 4000,
    reservedKg: 0,
    soldKg: 0,
    freeKg: 4000,
    kadarAir: 21.5,
    tglPanen: '2026-11-22',
    kabupaten: 'Banyumas',
    status: 'tersedia',
    catatan: 'Gabah panen basah, perlu dijemur ke standar 14%',
  },
];

export const INITIAL_OFFLINE_WAREHOUSES: WarehouseItem[] = [
  {
    id: 'wh-1',
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
    kontakWa: '6281234567803',
    checklist: {
      atap_tidak_bocor: true,
      ventilasi: true,
      lantai_palet_kering: true,
      kontrol_hama: true,
      alat_ukur_ka: true,
      keamanan_suhu: true,
    },
    score: { isEligible: true, totalScore: 95, distanceKm: 11.4 },
  },
  {
    id: 'wh-2',
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
    kontakWa: '6281234567803',
    checklist: {
      atap_tidak_bocor: true,
      ventilasi: true,
      lantai_palet_kering: true,
      kontrol_hama: true,
      alat_ukur_ka: false,
      keamanan_suhu: false,
    },
    score: { isEligible: true, totalScore: 81, distanceKm: 38.2 },
  },
  {
    id: 'wh-3',
    nama: 'Lumbung & Penggilingan Purbalingga (Data Ilustrasi)',
    kabupaten: 'Purbalingga',
    lat: -7.3881,
    lng: 109.3639,
    kapasitasKg: 40000,
    tersediaKg: 28000,
    tarifPerKgHari: 3.5,
    minVolumeKg: 1000,
    minHari: 14,
    isSrg: false,
    kontakWa: '6281234567803',
    checklist: {
      atap_tidak_bocor: true,
      ventilasi: true,
      lantai_palet_kering: true,
      kontrol_hama: false,
      alat_ukur_ka: true,
      keamanan_suhu: false,
    },
    score: { isEligible: true, totalScore: 76, distanceKm: 24.8 },
  },
];

export const INITIAL_OFFLINE_LOTS: LotItem[] = [
  {
    id: 'lot-1',
    groupId: 'grp-1',
    groupNama: 'Poktan Tani Jaya Banyumas',
    kodeGabung: 'TANIJAYA',
    commodityKode: 'jagung',
    commodityNama: 'Jagung Pipil',
    targetKg: 10000,
    terkumpulKg: 6000,
    progressPct: 60,
    status: 'mengumpulkan',
    warehouseNama: 'Gudang SRG Banyumas (Data Ilustrasi)',
  },
];

export const INITIAL_OFFLINE_DEMANDS: DemandItem[] = [
  {
    id: 'dem-1',
    buyerNama: 'Koperasi & SPPG Mitra Banyumas',
    buyerOrg: 'Koperasi Pangan Banyumas',
    commodityKode: 'jagung',
    commodityNama: 'Jagung Pipil',
    qtyKg: 15000,
    terpenuhiKg: 3000,
    sisaKuotaKg: 12000,
    progressPct: 20,
    hargaAcuan: 5850,
    dibutuhkanPada: '2027-01-15',
    kabupaten: 'Banyumas',
    catatanMutu: 'Jagung pipil kering bersih bebas jamur (KA <= 15%)',
  },
  {
    id: 'dem-2',
    buyerNama: 'Koperasi & SPPG Mitra Banyumas',
    buyerOrg: 'Koperasi Pangan Banyumas',
    commodityKode: 'gabah',
    commodityNama: 'Gabah Kering Giling (GKG)',
    qtyKg: 20000,
    terpenuhiKg: 5000,
    sisaKuotaKg: 15000,
    progressPct: 25,
    hargaAcuan: 7200,
    dibutuhkanPada: '2027-01-20',
    kabupaten: 'Banyumas',
    catatanMutu: 'Gabah Kering Giling standar RMU/SPPG (KA <= 14%)',
  },
];

export function buildOfflineStockAnalysis(stock: StockItem): SimResponse & { stock: StockItem } {
  const sim = localSimulate({
    commodityKode: stock.commodityKode,
    qtyKg: stock.qtyKg,
    kadarAirAktual: stock.kadarAir,
    useSrgLoan: true,
    hargaPanjarPerKg: stock.commodityKode === 'gabah' ? 5100 : 3800,
  });
  return { ...sim, stock };
}
