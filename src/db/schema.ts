import {
  boolean,
  date,
  doublePrecision,
  integer,
  jsonb,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

export type UserRole = 'petani' | 'gudang' | 'pembeli' | 'admin';
export type StockStatus = 'tersedia' | 'teralokasi_sebagian' | 'teralokasi_penuh' | 'terjual';
export type LotStatus =
  | 'mengumpulkan'
  | 'siap_ajukan'
  | 'diajukan_sewa'
  | 'disimpan'
  | 'diajukan_jual'
  | 'selesai'
  | 'dibatalkan';
export type RequestStatus = 'diajukan' | 'diterima' | 'ditolak' | 'selesai' | 'dibatalkan';
export type DemandStatus = 'aktif' | 'terpenuhi' | 'ditutup';

export interface CommodityParams {
  kadar_air_maks_pct: number;
  kotoran_maks_pct: number;
  rusak_maks_pct: number;
  susut_per_bulan: number;
  susut_rumah_per_bulan: number;
  biaya_pengeringan_per_kg: number;
  tarif_sewa_murah: number;
  tarif_sewa_mahal: number;
  fasilitas_wajib: string[];
}

export interface WarehouseChecklist {
  atap_tidak_bocor: boolean;
  ventilasi: boolean;
  lantai_palet_kering: boolean;
  kontrol_hama: boolean;
  alat_ukur_ka: boolean;
  keamanan_suhu: boolean;
}

export const users = pgTable('users', {
  id: uuid('id').defaultRandom().primaryKey(),
  email: text('email').notNull().unique(),
  passwordHash: text('password_hash').notNull(),
  role: text('role').$type<UserRole>().notNull(),
  nama: text('nama').notNull(),
  noWa: text('no_wa'),
  kabupaten: text('kabupaten').notNull(),
  provinsi: text('provinsi').notNull().default('Jawa Tengah'),
  namaOrg: text('nama_org'),
  tipePembeli: text('tipe_pembeli'),
  isDemo: boolean('is_demo').notNull().default(false),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const farmerGroups = pgTable('farmer_groups', {
  id: uuid('id').defaultRandom().primaryKey(),
  nama: text('nama').notNull(),
  kabupaten: text('kabupaten').notNull(),
  ketuaId: uuid('ketua_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  kodeGabung: varchar('kode_gabung', { length: 8 }).notNull().unique(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const farmerGroupMembers = pgTable(
  'farmer_group_members',
  {
    groupId: uuid('group_id')
      .notNull()
      .references(() => farmerGroups.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    joinedAt: timestamp('joined_at').defaultNow().notNull(),
  },
  (t) => [primaryKey({ columns: [t.groupId, t.userId] })]
);

export const commodities = pgTable('commodities', {
  id: uuid('id').defaultRandom().primaryKey(),
  kode: text('kode').notNull().unique(),
  nama: text('nama').notNull(),
  satuan: text('satuan').notNull().default('kg'),
  params: jsonb('params').$type<CommodityParams>().notNull(),
});

export const pricePoints = pgTable('price_points', {
  id: uuid('id').defaultRandom().primaryKey(),
  commodityId: uuid('commodity_id')
    .notNull()
    .references(() => commodities.id, { onDelete: 'cascade' }),
  region: text('region').notNull(),
  tanggal: date('tanggal').notNull(),
  hargaPerKg: integer('harga_per_kg').notNull(),
  sumber: text('sumber').notNull(),
  isDemo: boolean('is_demo').notNull().default(true),
});

export const stocks = pgTable('stocks', {
  id: uuid('id').defaultRandom().primaryKey(),
  ownerId: uuid('owner_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  commodityId: uuid('commodity_id')
    .notNull()
    .references(() => commodities.id),
  qtyKg: doublePrecision('qty_kg').notNull(),
  reservedKg: doublePrecision('reserved_kg').notNull().default(0),
  soldKg: doublePrecision('sold_kg').notNull().default(0),
  kadarAir: doublePrecision('kadar_air').notNull(),
  kotoranPct: doublePrecision('kotoran_pct').notNull().default(2),
  rusakPct: doublePrecision('rusak_pct').notNull().default(3),
  tglPanen: date('tgl_panen').notNull(),
  kabupaten: text('kabupaten').notNull(),
  lat: doublePrecision('lat'),
  lng: doublePrecision('lng'),
  status: text('status').$type<StockStatus>().notNull().default('tersedia'),
  catatan: text('catatan'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const decisions = pgTable('decisions', {
  id: uuid('id').defaultRandom().primaryKey(),
  stockId: uuid('stock_id')
    .notNull()
    .references(() => stocks.id, { onDelete: 'cascade' }),
  inputs: jsonb('inputs').$type<Record<string, unknown>>().notNull(),
  outputs: jsonb('outputs').$type<Record<string, unknown>>().notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const warehouses = pgTable('warehouses', {
  id: uuid('id').defaultRandom().primaryKey(),
  ownerId: uuid('owner_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  nama: text('nama').notNull(),
  kabupaten: text('kabupaten').notNull(),
  lat: doublePrecision('lat').notNull(),
  lng: doublePrecision('lng').notNull(),
  kapasitasKg: doublePrecision('kapasitas_kg').notNull(),
  tersediaKg: doublePrecision('tersedia_kg').notNull(),
  tarifPerKgHari: doublePrecision('tarif_per_kg_hari').notNull(),
  minVolumeKg: doublePrecision('min_volume_kg').notNull(),
  minHari: integer('min_hari').notNull(),
  isSrg: boolean('is_srg').notNull().default(false),
  komoditasDiterima: text('komoditas_diterima').array().notNull(),
  checklist: jsonb('checklist').$type<WarehouseChecklist>().notNull(),
  kontakWa: text('kontak_wa'),
  isDemo: boolean('is_demo').notNull().default(true),
});

export const lots = pgTable('lots', {
  id: uuid('id').defaultRandom().primaryKey(),
  groupId: uuid('group_id')
    .notNull()
    .references(() => farmerGroups.id, { onDelete: 'cascade' }),
  commodityId: uuid('commodity_id')
    .notNull()
    .references(() => commodities.id),
  targetKg: doublePrecision('target_kg').notNull(),
  terkumpulKg: doublePrecision('terkumpul_kg').notNull().default(0),
  status: text('status').$type<LotStatus>().notNull().default('mengumpulkan'),
  warehouseId: uuid('warehouse_id').references(() => warehouses.id),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const lotContributions = pgTable('lot_contributions', {
  id: uuid('id').defaultRandom().primaryKey(),
  lotId: uuid('lot_id')
    .notNull()
    .references(() => lots.id, { onDelete: 'cascade' }),
  stockId: uuid('stock_id')
    .notNull()
    .references(() => stocks.id, { onDelete: 'cascade' }),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  qtyKg: doublePrecision('qty_kg').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const rentalRequests = pgTable('rental_requests', {
  id: uuid('id').defaultRandom().primaryKey(),
  requesterId: uuid('requester_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  stockId: uuid('stock_id').references(() => stocks.id, { onDelete: 'set null' }),
  lotId: uuid('lot_id').references(() => lots.id, { onDelete: 'set null' }),
  warehouseId: uuid('warehouse_id')
    .notNull()
    .references(() => warehouses.id, { onDelete: 'cascade' }),
  qtyKg: doublePrecision('qty_kg').notNull(),
  hari: integer('hari').notNull(),
  estimasiBiaya: integer('estimasi_biaya').notNull(),
  status: text('status').$type<RequestStatus>().notNull().default('diajukan'),
  alasanTolak: text('alasan_tolak'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const buyerDemands = pgTable('buyer_demands', {
  id: uuid('id').defaultRandom().primaryKey(),
  buyerId: uuid('buyer_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  commodityId: uuid('commodity_id')
    .notNull()
    .references(() => commodities.id),
  qtyKg: doublePrecision('qty_kg').notNull(),
  terpenuhiKg: doublePrecision('terpenuhi_kg').notNull().default(0),
  hargaAcuan: integer('harga_acuan').notNull(),
  dibutuhkanPada: date('dibutuhkan_pada').notNull(),
  kabupaten: text('kabupaten').notNull(),
  lat: doublePrecision('lat').notNull(),
  lng: doublePrecision('lng').notNull(),
  mutuMin: jsonb('mutu_min').$type<{ kadar_air_maks_pct?: number; catatan?: string }>().notNull(),
  status: text('status').$type<DemandStatus>().notNull().default('aktif'),
  isDemo: boolean('is_demo').notNull().default(true),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const saleOffers = pgTable('sale_offers', {
  id: uuid('id').defaultRandom().primaryKey(),
  sellerId: uuid('seller_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  stockId: uuid('stock_id').references(() => stocks.id, { onDelete: 'set null' }),
  lotId: uuid('lot_id').references(() => lots.id, { onDelete: 'set null' }),
  demandId: uuid('demand_id')
    .notNull()
    .references(() => buyerDemands.id, { onDelete: 'cascade' }),
  qtyKg: doublePrecision('qty_kg').notNull(),
  hargaTawar: integer('harga_tawar').notNull(),
  status: text('status').$type<RequestStatus>().notNull().default('diajukan'),
  alasanTolak: text('alasan_tolak'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});

export const impactEvents = pgTable('impact_events', {
  id: uuid('id').defaultRandom().primaryKey(),
  jenis: text('jenis').notNull(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  refId: uuid('ref_id'),
  nilai: doublePrecision('nilai').notNull(),
  meta: jsonb('meta').$type<Record<string, unknown>>(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const aiLogs = pgTable('ai_logs', {
  id: uuid('id').defaultRandom().primaryKey(),
  userId: uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  fitur: text('fitur').$type<'explain' | 'extract'>().notNull(),
  refId: uuid('ref_id'),
  ok: boolean('ok').notNull(),
  fallbackUsed: boolean('fallback_used').notNull().default(false),
  latencyMs: integer('latency_ms').notNull(),
  tokensIn: integer('tokens_in'),
  tokensOut: integer('tokens_out'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});
