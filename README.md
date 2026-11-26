# SimpanJual — Platform Keputusan "Tahan atau Jual" Hasil Panen

**SEVENT X — Software Development (HMSE Telkom University Purwokerto)**  
Subtema SDG: **SDG 8 — Decent Work and Economic Growth**

SimpanJual membantu petani kecil menghitung secara jujur apakah menahan hasil panen (termasuk susut pengeringan kadar air, ongkos simpan gudang SRG, dan bunga S-SRG 6%) lebih menguntungkan dibanding menerima panjar/tebasan tengkulak, menghubungkan ke Lot Kolektif Poktan, peta kapasitas gudang kosong berskor, dan pembeli siaga (*Janji Beli*).

## Arsitektur & Teknologi
- **Frontend & API:** Next.js 15 (App Router), React 19, TypeScript (`strict`), Tailwind CSS
- **Database Lokal:** Podman PostgreSQL 17 (`compose.yaml`, port `5435:5432`)
- **Database Produksi:** Portabel ke Cloud PostgreSQL (Neon / Supabase Postgres) via `DATABASE_URL`
- **ORM & Transaksi:** Drizzle ORM + `postgres.js` + transaksi atomik `SELECT ... FOR UPDATE`
- **Autentikasi:** Session JWT `httpOnly` (`jose` + `bcryptjs`) + **1-Click Demo Login**
- **Testing & CI:** Vitest + GitHub Actions

## Menjalankan Secara Lokal (dengan Podman)

1. **Salin konfigurasi environment:**
   ```bash
   cp .env.example .env
   ```
2. **Instal dependensi:**
   ```bash
   npm install
   ```
3. **Jalankan kontainer Podman PostgreSQL, dorong skema, dan isi data demo:**
   ```bash
   npm run db:setup
   ```
4. **Jalankan pengujian unit & server pengembangan:**
   ```bash
   npm test
   npm run dev
   ```
5. Buka `http://localhost:3000` (endpoint healthcheck DB: `http://localhost:3000/api/health`).

## Akun Demo (Tersedia 1-Klik di Halaman `/masuk`)
Sandi untuk login manual seluruh akun demo: `demo12345`

| Peran | Email | Deskripsi |
|---|---|---|
| Petani | `petani@demo.id` | Pak Slamet (stok jagung 5 ton & gabah basah 4 ton) |
| Ketua Poktan | `poktan@demo.id` | Bu Rini (Poktan Tani Jaya, kode gabung `TANIJAYA`) |
| Pengelola Gudang | `gudang@demo.id` | Pak Joko (4 gudang daerah & SRG) |
| Pembeli | `pembeli@demo.id` | Koperasi & SPPG Mitra Banyumas |
| Admin | `admin@demo.id` | Konfigurasi parameter komoditas JSONB |

## Dokumentasi
- [PRD SimpanJual v2.1](docs/PRD_SimpanJual_v2.md)
- [Audit Kritis & Spesifikasi Teknis](docs/Audit_Kritik_dan_Spesifikasi_Teknis.md)
