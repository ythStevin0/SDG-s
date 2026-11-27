# SimpanJual — Platform Keputusan Pascapanen "Tahan atau Jual"

**SEVENT X — Software Development (HMSE Telkom University Purwokerto)**  
- **Kategori Lomba:** **Mobile Application (Flutter & Dart)** + Pendamping Lintas-Platform (**React.js Web**)
- **Subtema SDG Tunggal:** **SDG 8 — Decent Work and Economic Growth** *(Co-benefits: SDG 2 & SDG 12)*

**SimpanJual** membantu petani kecil menghitung secara jujur apakah menahan hasil panen (termasuk konversi susut pengeringan kadar air GKP→GKG, ongkos gudang SRG, dan bunga subsidi S-SRG 6%) lebih menguntungkan dibanding menerima panjar/tebasan tengkulak, menghubungkan ke **Lot Kolektif Poktan** (`TANIJAYA`), peta kapasitas gudang kosong berskor anti-`NaN`, serta bursa pembeli siaga (*Janji Beli*).

---

## Arsitektur: Cross-Platform Modular Monolith

Repositori ini menggunakan pola **Modular Monolith** terpusat agar seluruh klien lintas-platform berbagi logika bisnis deterministik dan jaminan integritas database yang identik:

```text
sevent_x/
├── mobile/                 # Aplikasi Utama Kategori Mobile: Flutter (Dart) — Android APK, Web, & Desktop
├── web/                    # Aplikasi Pendamping Lintas-Platform: React.js 19 + TypeScript + Vite + Tailwind CSS
├── backend/                # Go (Golang) Modular Monolith API + SQL Migrations + Idempotent Seeder
│   ├── cmd/api/            # Entrypoint HTTP server (3-layer timeouts + graceful shutdown)
│   ├── cmd/dbtool/         # CLI migrasi terversi (up/down/reset) & database seeder idempoten
│   ├── migrations/         # Skema PostgreSQL 17 + B-Tree Indexes + tabel idempotency_keys
│   └── internal/
│       ├── platform/       # Config env, pgxpool, TTLCache, Rate Limiter, JWT+RBAC, Idempotency, CORS, JSON slog
│       └── modules/        # 8 Modul Terisolasi: engine, auth, catalog, stock, lot, warehouse, demand, impact, ai
├── compose.yaml            # Orkestrasi kontainer Podman (PostgreSQL 17 port 5435 + profil full API/Web)
├── scripts/                # Utilitas manajemen kontainer Podman lintas platform
└── docs/                   # PRD SimpanJual & Audit Spesifikasi Teknis
```

### Praktik Rekayasa Backend & Database pada `backend/` (Go + PostgreSQL 17)
1. **Proteksi & Keamanan:** Token-Bucket **Rate Limiting** per pengguna/IP (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `Retry-After`), **CORS Policy** terkonfigurasi, batas ukuran payload (`http.MaxBytesReader` 1 MB), **Stateless JWT (`HS256`) + RBAC Server-Side**, sensor nomor WhatsApp sebelum pengajuan disetujui, serta *zero hardcoded secrets* (seluruh kredensial melalui *environment variables*).
2. **Kebenaran Data & Konkurensi:** Transaksi PostgreSQL atomik memakai **`SELECT ... FOR UPDATE`** dengan urutan penguncian baris konsisten (*consistent lock ordering* untuk mencegah *deadlock* & *race condition*), dukungan header **`Idempotency-Key`** pada mutasi `POST` agar *retry* jaringan seluler di desa tidak memicu *double-booking*, serta *checked type assertions* & `sync.Mutex`/`sync.RWMutex` bebas *concurrent map writes*.
3. **Performa & Skema Database:** Query berparameter (`$1, $2` via `pgx/v5`) bebas *SQL Injection*, **Eager `JOIN` & Batch Query** untuk mencegah *N+1 Query Problem*, **In-Memory `TTLCache`** dengan *write-through invalidation* saat Admin memperbarui komoditas, *connection pooling* terukur (`pgxpool` + `defer rows.Close()`), **20+ B-Tree Indexes**, migrasi terversi (`up`/`down`), serta **Database Seeder Idempoten** (`ON CONFLICT`).
4. **Observabilitas & Ketahanan:** *Structured JSON Logging* (`log/slog`) dengan *Correlation ID* (`X-Request-ID`), pemisahan endpoint *liveness* (`/healthz`) dan *readiness* (`/readyz`, `/api/v1/health`), *3-layer HTTP & DB timeouts*, serta *exponential backoff + jitter* pada pemanggilan AI opsional dengan *fallback* deterministik instan.

---

## Cara Menjalankan Secara Lokal

### 1. Jalankan Database PostgreSQL (Podman) & Backend Go
```powershell
# 1. Salin konfigurasi environment
Copy-Item .env.example .env

# 2. Nyalakan kontainer Podman PostgreSQL 17 (port 5435)
npm run db:up

# 3. Jalankan migrasi SQL, seeder idempoten, & server Go Modular Monolith (port 8080)
cd backend
go test -v ./...
go run ./cmd/api
```
*(Cek kesehatan server di `http://localhost:8080/api/v1/health`)*

### 2. Jalankan Aplikasi Utama Mobile — Flutter (Dart)
Aplikasi Flutter mendukung **Android (APK / Emulator / Perangkat Fisik)**, **Web (Chrome/Edge)**, dan **Desktop**, serta dilengkapi **Mode Simulasi Mandiri (Offline)** otomatis apabila APK dibuka juri tanpa server lokal:
```powershell
cd mobile
flutter pub get
flutter test

# Jalankan di Android Emulator / HP terhubung:
flutter run

# Jalankan di Chrome untuk demo cepat lintas-platform:
flutter run -d chrome

# Bangun file APK Rilis untuk pengumpulan lomba:
flutter build apk --release
```

### 3. Jalankan Aplikasi Pendamping Web — React.js
```powershell
cd web
npm install
npm run dev
```
*(Buka `http://localhost:5173`)*

---

## Akun Demo (Tersedia 1-Click Demo Login di Flutter & React.js)
Kata sandi login manual seluruh akun demo: `demo12345`

| Peran | Email | Deskripsi Skenario |
|---|---|---|
| **Petani** | `petani@demo.id` | Pak Slamet — stok jagung 5 ton & gabah GKP basah 4 ton (KA 22%) |
| **Ketua Poktan** | `poktan@demo.id` | Bu Rini — Poktan Tani Jaya, kode gabung `TANIJAYA`, Lot Kolektif 6/10 ton |
| **Pengelola Gudang** | `gudang@demo.id` | Pak Joko — 4 gudang SRG & koperasi daerah |
| **Pembeli** | `pembeli@demo.id` | Koperasi & SPPG Mitra Banyumas (*Janji Beli*) |
| **Admin** | `admin@demo.id` | Konfigurasi parameter JSONB komoditas & monitor koneksi backend |

## Dokumentasi
- [PRD SimpanJual v2.2 (Mobile Flutter + Cross-Platform Modular Monolith)](docs/PRD_SimpanJual_v2.md)
- [Audit Kritis & Spesifikasi Teknis](docs/Audit_Kritik_dan_Spesifikasi_Teknis.md)
