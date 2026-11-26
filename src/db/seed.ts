import 'dotenv/config';
import bcrypt from 'bcryptjs';
import { db, pgClient } from './index';
import {
  buyerDemands,
  commodities,
  farmerGroupMembers,
  farmerGroups,
  impactEvents,
  lotContributions,
  lots,
  pricePoints,
  stocks,
  users,
  warehouses,
} from './schema';

function generateSeasonalPrices(
  basePrice: number,
  amplitude: number,
  weeks = 64
): { tanggal: string; hargaPerKg: number }[] {
  const results: { tanggal: string; hargaPerKg: number }[] = [];
  const start = new Date('2025-09-01T00:00:00Z');
  for (let w = 0; w < weeks; w++) {
    const dt = new Date(start.getTime() + w * 7 * 24 * 60 * 60 * 1000);
    // Siklus musiman 26 minggu (2 musim panen per tahun) + tren inflasi ringan
    const phase = (2 * Math.PI * w) / 26;
    const seasonal = Math.sin(phase) * amplitude;
    const microNoise = ((w * 37) % 11 - 5) * 25;
    const trend = w * 8;
    const hargaPerKg = Math.round((basePrice + seasonal + microNoise + trend) / 50) * 50;
    results.push({
      tanggal: dt.toISOString().slice(0, 10),
      hargaPerKg,
    });
  }
  return results;
}

async function seed() {
  console.log('Memulai seed database SimpanJual...');

  const demoPasswordHash = await bcrypt.hash('demo12345', 10);

  // Bersihkan data demo lama secara aman dalam urutan relasi
  await db.delete(impactEvents);
  await db.delete(lotContributions);
  await db.delete(lots);
  await db.delete(stocks);
  await db.delete(buyerDemands);
  await db.delete(warehouses);
  await db.delete(pricePoints);
  await db.delete(farmerGroupMembers);
  await db.delete(farmerGroups);
  await db.delete(commodities);
  await db.delete(users);

  // 1. Insert 5 Akun Demo
  const [petaniUser, poktanUser, gudangUser, pembeliUser, adminUser] = await db
    .insert(users)
    .values([
      {
        email: 'petani@demo.id',
        passwordHash: demoPasswordHash,
        role: 'petani',
        nama: 'Pak Slamet',
        noWa: '6281234567801',
        kabupaten: 'Banyumas',
        provinsi: 'Jawa Tengah',
        isDemo: true,
      },
      {
        email: 'poktan@demo.id',
        passwordHash: demoPasswordHash,
        role: 'petani',
        nama: 'Bu Rini (Ketua Poktan)',
        noWa: '6281234567802',
        kabupaten: 'Banyumas',
        provinsi: 'Jawa Tengah',
        namaOrg: 'Poktan Tani Jaya',
        isDemo: true,
      },
      {
        email: 'gudang@demo.id',
        passwordHash: demoPasswordHash,
        role: 'gudang',
        nama: 'Pak Joko (Pengelola SRG)',
        noWa: '6281234567803',
        kabupaten: 'Banyumas',
        provinsi: 'Jawa Tengah',
        namaOrg: 'Gudang SRG Banyumas',
        isDemo: true,
      },
      {
        email: 'pembeli@demo.id',
        passwordHash: demoPasswordHash,
        role: 'pembeli',
        nama: 'Koperasi & SPPG Mitra Banyumas',
        noWa: '6281234567804',
        kabupaten: 'Banyumas',
        provinsi: 'Jawa Tengah',
        namaOrg: 'Koperasi Pangan Banyumas (Mitra SPPG)',
        tipePembeli: 'sppg',
        isDemo: true,
      },
      {
        email: 'admin@demo.id',
        passwordHash: demoPasswordHash,
        role: 'admin',
        nama: 'Admin SimpanJual',
        noWa: '6281234567805',
        kabupaten: 'Banyumas',
        provinsi: 'Jawa Tengah',
        isDemo: true,
      },
    ])
    .returning();

  // 2. Insert 2 Komoditas Utama
  const [jagung, gabah] = await db
    .insert(commodities)
    .values([
      {
        kode: 'jagung',
        nama: 'Jagung Pipil',
        satuan: 'kg',
        params: {
          kadar_air_maks_pct: 15,
          kotoran_maks_pct: 3,
          rusak_maks_pct: 5,
          susut_per_bulan: 0.005,
          susut_rumah_per_bulan: 0.03,
          biaya_pengeringan_per_kg: 150,
          tarif_sewa_murah: 1,
          tarif_sewa_mahal: 8,
          fasilitas_wajib: ['ventilasi', 'lantai_palet_kering', 'kontrol_hama'],
        },
      },
      {
        kode: 'gabah',
        nama: 'Gabah Kering Giling (GKG)',
        satuan: 'kg',
        params: {
          kadar_air_maks_pct: 14,
          kotoran_maks_pct: 3,
          rusak_maks_pct: 5,
          susut_per_bulan: 0.005,
          susut_rumah_per_bulan: 0.025,
          biaya_pengeringan_per_kg: 150,
          tarif_sewa_murah: 1,
          tarif_sewa_mahal: 8,
          fasilitas_wajib: ['ventilasi', 'lantai_palet_kering', 'kontrol_hama'],
        },
      },
    ])
    .returning();

  // 3. Insert 64 Minggu Harga Historis (cukup untuk Seasonal-MA & rolling backtest)
  const jagungPrices = generateSeasonalPrices(4950, 550, 64).map((p) => ({
    commodityId: jagung.id,
    region: 'Jawa Tengah',
    tanggal: p.tanggal,
    hargaPerKg: p.hargaPerKg,
    sumber: 'Data Ilustrasi Bermusim (Referensi Pasar Jateng)',
    isDemo: true,
  }));
  const gabahPrices = generateSeasonalPrices(6400, 650, 64).map((p) => ({
    commodityId: gabah.id,
    region: 'Jawa Tengah',
    tanggal: p.tanggal,
    hargaPerKg: p.hargaPerKg,
    sumber: 'Data Ilustrasi Bermusim (Referensi Pasar Jateng)',
    isDemo: true,
  }));
  await db.insert(pricePoints).values([...jagungPrices, ...gabahPrices]);

  // 4. Kelompok Tani & Anggota
  const [poktan] = await db
    .insert(farmerGroups)
    .values({
      nama: 'Poktan Tani Jaya Banyumas',
      kabupaten: 'Banyumas',
      ketuaId: poktanUser.id,
      kodeGabung: 'TANIJAYA',
    })
    .returning();

  await db.insert(farmerGroupMembers).values([
    { groupId: poktan.id, userId: poktanUser.id },
    { groupId: poktan.id, userId: petaniUser.id },
  ]);

  // 5. Stok Awal Petani & Poktan
  const [stokSlamet, stokGabahSlamet, stokRini] = await db
    .insert(stocks)
    .values([
      {
        ownerId: petaniUser.id,
        commodityId: jagung.id,
        qtyKg: 5000,
        reservedKg: 0,
        soldKg: 0,
        kadarAir: 14.5,
        kotoranPct: 2.0,
        rusakPct: 3.0,
        tglPanen: '2026-11-20',
        kabupaten: 'Banyumas',
        lat: -7.4502,
        lng: 109.1623,
        status: 'tersedia',
        catatan: 'Panen blok sawah Sokaraja, jagung pipil kuning',
      },
      {
        ownerId: petaniUser.id,
        commodityId: gabah.id,
        qtyKg: 4000,
        reservedKg: 0,
        soldKg: 0,
        kadarAir: 22.0,
        kotoranPct: 2.5,
        rusakPct: 3.5,
        tglPanen: '2026-11-22',
        kabupaten: 'Banyumas',
        lat: -7.4502,
        lng: 109.1623,
        status: 'tersedia',
        catatan: 'Gabah Kering Panen (GKP) baru panen, perlu dijemur sebelum masuk SRG',
      },
      {
        ownerId: poktanUser.id,
        commodityId: jagung.id,
        qtyKg: 6000,
        reservedKg: 6000,
        soldKg: 0,
        kadarAir: 14.0,
        kotoranPct: 2.0,
        rusakPct: 2.5,
        tglPanen: '2026-11-18',
        kabupaten: 'Banyumas',
        lat: -7.4311,
        lng: 109.2478,
        status: 'teralokasi_penuh',
        catatan: 'Stok himpunan anggota Poktan Tani Jaya untuk Lot Kolektif',
      },
    ])
    .returning();

  // 6. Empat Gudang Contoh
  const [whSrg] = await db
    .insert(warehouses)
    .values([
      {
        ownerId: gudangUser.id,
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
          atap_tidak_bocor: true,
          ventilasi: true,
          lantai_palet_kering: true,
          kontrol_hama: true,
          alat_ukur_ka: true,
          keamanan_suhu: true,
        },
        kontakWa: '6281234567803',
        isDemo: true,
      },
      {
        ownerId: gudangUser.id,
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
          atap_tidak_bocor: true,
          ventilasi: true,
          lantai_palet_kering: true,
          kontrol_hama: true,
          alat_ukur_ka: false,
          keamanan_suhu: false,
        },
        kontakWa: '6281234567803',
        isDemo: true,
      },
      {
        ownerId: gudangUser.id,
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
          atap_tidak_bocor: true,
          ventilasi: true,
          lantai_palet_kering: true,
          kontrol_hama: false,
          alat_ukur_ka: true,
          keamanan_suhu: false,
        },
        kontakWa: '6281234567803',
        isDemo: true,
      },
      {
        ownerId: gudangUser.id,
        nama: 'Gudang Agribisnis Brebes (Data Ilustrasi)',
        kabupaten: 'Brebes',
        lat: -6.8706,
        lng: 109.0442,
        kapasitasKg: 80000,
        tersediaKg: 60000,
        tarifPerKgHari: 4.0,
        minVolumeKg: 3000,
        minHari: 30,
        isSrg: true,
        komoditasDiterima: ['jagung', 'gabah'],
        checklist: {
          atap_tidak_bocor: true,
          ventilasi: true,
          lantai_palet_kering: true,
          kontrol_hama: true,
          alat_ukur_ka: true,
          keamanan_suhu: false,
        },
        kontakWa: '6281234567803',
        isDemo: true,
      },
    ])
    .returning();

  // 7. Lot Kolektif Awal
  const [lotAwal] = await db
    .insert(lots)
    .values({
      groupId: poktan.id,
      commodityId: jagung.id,
      targetKg: 10000,
      terkumpulKg: 6000,
      status: 'mengumpulkan',
      warehouseId: whSrg.id,
    })
    .returning();

  await db.insert(lotContributions).values({
    lotId: lotAwal.id,
    stockId: stokRini.id,
    userId: poktanUser.id,
    qtyKg: 6000,
  });

  // 8. Empat Kebutuhan Pembeli (Janji Beli)
  await db.insert(buyerDemands).values([
    {
      buyerId: pembeliUser.id,
      commodityId: jagung.id,
      qtyKg: 15000,
      terpenuhiKg: 3000,
      hargaAcuan: 5850,
      dibutuhkanPada: '2027-01-15',
      kabupaten: 'Banyumas',
      lat: -7.4243,
      lng: 109.2302,
      mutuMin: { kadar_air_maks_pct: 15, catatan: 'Jagung pipil kering bersih bebas jamur' },
      status: 'aktif',
      isDemo: true,
    },
    {
      buyerId: pembeliUser.id,
      commodityId: gabah.id,
      qtyKg: 20000,
      terpenuhiKg: 5000,
      hargaAcuan: 7200,
      dibutuhkanPada: '2027-01-20',
      kabupaten: 'Banyumas',
      lat: -7.4243,
      lng: 109.2302,
      mutuMin: { kadar_air_maks_pct: 14, catatan: 'Gabah Kering Giling (GKG) standar RMU/SPPG' },
      status: 'aktif',
      isDemo: true,
    },
    {
      buyerId: pembeliUser.id,
      commodityId: jagung.id,
      qtyKg: 25000,
      terpenuhiKg: 0,
      hargaAcuan: 5700,
      dibutuhkanPada: '2026-12-30',
      kabupaten: 'Cilacap',
      lat: -7.7188,
      lng: 109.0154,
      mutuMin: { kadar_air_maks_pct: 15, catatan: 'Bahan baku pabrik pakan ternak' },
      status: 'aktif',
      isDemo: true,
    },
    {
      buyerId: pembeliUser.id,
      commodityId: gabah.id,
      qtyKg: 12000,
      terpenuhiKg: 2000,
      hargaAcuan: 6950,
      dibutuhkanPada: '2026-12-25',
      kabupaten: 'Purbalingga',
      lat: -7.3881,
      lng: 109.3639,
      mutuMin: { kadar_air_maks_pct: 14.5, catatan: 'Koperasi Penggilingan Padi Daerah' },
      status: 'aktif',
      isDemo: true,
    },
  ]);

  // 9. Data Dampak Awal (Simulasi Berlabel)
  await db.insert(impactEvents).values([
    {
      jenis: 'tambahan_pendapatan',
      userId: petaniUser.id,
      refId: stokSlamet.id,
      nilai: 2048822,
      meta: { isDemo: true, label: 'Simulasi keputusan tahan jagung 8 minggu' },
    },
    {
      jenis: 'stok_terserap',
      userId: pembeliUser.id,
      refId: stokGabahSlamet.id,
      nilai: 10000,
      meta: { isDemo: true, label: 'Simulasi serapan awal koperasi & SPPG' },
    },
  ]);

  console.log(
    `Seed selesai: 5 akun demo (${adminUser.email}..${petaniUser.email}), 2 komoditas, 128 titik harga, 4 gudang, 4 kebutuhan pembeli.`
  );
  await pgClient.end();
}

seed().catch(async (err) => {
  console.error('Seed gagal:', err);
  await pgClient.end();
  process.exit(1);
});
