-- 001_init.up.sql
-- Skema Database SimpanJual (Modular Monolith PostgreSQL 17)
-- Dilengkapi constraint integritas, tabel idempotency_keys, dan B-Tree Indexes anti full-table-scan

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('petani', 'gudang', 'pembeli', 'admin')),
  nama TEXT NOT NULL,
  no_wa TEXT,
  kabupaten TEXT NOT NULL,
  provinsi TEXT NOT NULL DEFAULT 'Jawa Tengah',
  nama_org TEXT,
  tipe_pembeli TEXT,
  is_demo BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS farmer_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama TEXT NOT NULL,
  kabupaten TEXT NOT NULL,
  ketua_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kode_gabung VARCHAR(8) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS farmer_group_members (
  group_id UUID NOT NULL REFERENCES farmer_groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);

CREATE TABLE IF NOT EXISTS commodities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kode TEXT NOT NULL UNIQUE,
  nama TEXT NOT NULL,
  satuan TEXT NOT NULL DEFAULT 'kg',
  params JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS price_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commodity_id UUID NOT NULL REFERENCES commodities(id) ON DELETE CASCADE,
  region TEXT NOT NULL,
  tanggal DATE NOT NULL,
  harga_per_kg INTEGER NOT NULL CHECK (harga_per_kg > 0),
  sumber TEXT NOT NULL,
  is_demo BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (commodity_id, region, tanggal)
);

CREATE TABLE IF NOT EXISTS stocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  commodity_id UUID NOT NULL REFERENCES commodities(id),
  qty_kg DOUBLE PRECISION NOT NULL CHECK (qty_kg > 0),
  reserved_kg DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (reserved_kg >= 0),
  sold_kg DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (sold_kg >= 0),
  kadar_air DOUBLE PRECISION NOT NULL CHECK (kadar_air >= 0 AND kadar_air < 100),
  kotoran_pct DOUBLE PRECISION NOT NULL DEFAULT 2 CHECK (kotoran_pct >= 0 AND kotoran_pct <= 100),
  rusak_pct DOUBLE PRECISION NOT NULL DEFAULT 3 CHECK (rusak_pct >= 0 AND rusak_pct <= 100),
  tgl_panen DATE NOT NULL,
  kabupaten TEXT NOT NULL,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  status TEXT NOT NULL DEFAULT 'tersedia',
  catatan TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_id UUID NOT NULL REFERENCES stocks(id) ON DELETE CASCADE,
  inputs JSONB NOT NULL,
  outputs JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  nama TEXT NOT NULL,
  kabupaten TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  kapasitas_kg DOUBLE PRECISION NOT NULL CHECK (kapasitas_kg > 0),
  tersedia_kg DOUBLE PRECISION NOT NULL CHECK (tersedia_kg >= 0),
  tarif_per_kg_hari DOUBLE PRECISION NOT NULL CHECK (tarif_per_kg_hari >= 0),
  min_volume_kg DOUBLE PRECISION NOT NULL DEFAULT 0,
  min_hari INTEGER NOT NULL DEFAULT 1,
  is_srg BOOLEAN NOT NULL DEFAULT FALSE,
  komoditas_diterima TEXT[] NOT NULL,
  checklist JSONB NOT NULL,
  kontak_wa TEXT,
  is_demo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS lots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES farmer_groups(id) ON DELETE CASCADE,
  commodity_id UUID NOT NULL REFERENCES commodities(id),
  target_kg DOUBLE PRECISION NOT NULL CHECK (target_kg > 0),
  terkumpul_kg DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (terkumpul_kg >= 0),
  status TEXT NOT NULL DEFAULT 'mengumpulkan',
  warehouse_id UUID REFERENCES warehouses(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lot_contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id UUID NOT NULL REFERENCES lots(id) ON DELETE CASCADE,
  stock_id UUID NOT NULL REFERENCES stocks(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  qty_kg DOUBLE PRECISION NOT NULL CHECK (qty_kg > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rental_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stock_id UUID REFERENCES stocks(id) ON DELETE SET NULL,
  lot_id UUID REFERENCES lots(id) ON DELETE SET NULL,
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  qty_kg DOUBLE PRECISION NOT NULL CHECK (qty_kg > 0),
  hari INTEGER NOT NULL CHECK (hari > 0),
  estimasi_biaya INTEGER NOT NULL CHECK (estimasi_biaya >= 0),
  status TEXT NOT NULL DEFAULT 'diajukan',
  alasan_tolak TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS buyer_demands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  commodity_id UUID NOT NULL REFERENCES commodities(id),
  qty_kg DOUBLE PRECISION NOT NULL CHECK (qty_kg > 0),
  terpenuhi_kg DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (terpenuhi_kg >= 0),
  harga_acuan INTEGER NOT NULL CHECK (harga_acuan > 0),
  dibutuhkan_pada DATE NOT NULL,
  kabupaten TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  mutu_min JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'aktif',
  is_demo BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sale_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stock_id UUID REFERENCES stocks(id) ON DELETE SET NULL,
  lot_id UUID REFERENCES lots(id) ON DELETE SET NULL,
  demand_id UUID NOT NULL REFERENCES buyer_demands(id) ON DELETE CASCADE,
  qty_kg DOUBLE PRECISION NOT NULL CHECK (qty_kg > 0),
  harga_tawar INTEGER NOT NULL CHECK (harga_tawar > 0),
  status TEXT NOT NULL DEFAULT 'diajukan',
  alasan_tolak TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS impact_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  jenis TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  ref_id UUID,
  nilai DOUBLE PRECISION NOT NULL,
  meta JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fitur TEXT NOT NULL CHECK (fitur IN ('explain', 'extract')),
  ref_id UUID,
  ok BOOLEAN NOT NULL,
  fallback_used BOOLEAN NOT NULL DEFAULT FALSE,
  latency_ms INTEGER NOT NULL,
  tokens_in INTEGER,
  tokens_out INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS idempotency_keys (
  key TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  method TEXT NOT NULL,
  path TEXT NOT NULL,
  status_code INTEGER NOT NULL,
  response_body JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (key, user_id)
);

-- B-Tree Indexes untuk mencegah Full Table Scan & mempercepat JOIN / ORDER BY
CREATE INDEX IF NOT EXISTS idx_price_points_comm_region_date ON price_points (commodity_id, region, tanggal);
CREATE INDEX IF NOT EXISTS idx_stocks_owner_status ON stocks (owner_id, status);
CREATE INDEX IF NOT EXISTS idx_stocks_commodity ON stocks (commodity_id);
CREATE INDEX IF NOT EXISTS idx_decisions_stock_created ON decisions (stock_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_warehouses_owner ON warehouses (owner_id);
CREATE INDEX IF NOT EXISTS idx_warehouses_kabupaten_srg ON warehouses (kabupaten, is_srg);
CREATE INDEX IF NOT EXISTS idx_farmer_groups_ketua ON farmer_groups (ketua_id);
CREATE INDEX IF NOT EXISTS idx_lots_group_status ON lots (group_id, status);
CREATE INDEX IF NOT EXISTS idx_lot_contrib_lot ON lot_contributions (lot_id);
CREATE INDEX IF NOT EXISTS idx_lot_contrib_user ON lot_contributions (user_id);
CREATE INDEX IF NOT EXISTS idx_rental_req_warehouse_status ON rental_requests (warehouse_id, status);
CREATE INDEX IF NOT EXISTS idx_rental_req_requester ON rental_requests (requester_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rental_req_lot ON rental_requests (lot_id);
CREATE INDEX IF NOT EXISTS idx_buyer_demands_buyer_status ON buyer_demands (buyer_id, status);
CREATE INDEX IF NOT EXISTS idx_buyer_demands_comm_status ON buyer_demands (commodity_id, status);
CREATE INDEX IF NOT EXISTS idx_sale_offers_demand_status ON sale_offers (demand_id, status);
CREATE INDEX IF NOT EXISTS idx_sale_offers_seller ON sale_offers (seller_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sale_offers_lot ON sale_offers (lot_id);
CREATE INDEX IF NOT EXISTS idx_impact_events_jenis ON impact_events (jenis);
CREATE INDEX IF NOT EXISTS idx_ai_logs_user_created ON ai_logs (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_idempotency_expires ON idempotency_keys (expires_at);
