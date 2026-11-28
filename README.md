# SimpanJual: Platform Keputusan Pascapanen "Tahan atau Jual"

**SEVENT X Software Development (HMSE Telkom University Purwokerto)**  
- **Kategori Lomba:** **Mobile Application (Flutter & Dart)** + Pendamping Lintas-Platform (**React.js Web**)
- **Subtema SDG Tunggal:** **SDG 8: Decent Work and Economic Growth** *(Co-benefits: SDG 2 & SDG 12)*

**SimpanJual** membantu petani kecil menghitung secara jujur apakah menahan hasil panen (termasuk konversi susut pengeringan kadar air GKP->GKG, ongkos gudang SRG, dan bunga subsidi S-SRG 6%) lebih menguntungkan dibanding menerima panjar/tebasan tengkulak, menghubungkan ke **Lot Kolektif Poktan** (`TANIJAYA`), peta kapasitas gudang kosong berskor anti-`NaN`, serta bursa pembeli siaga (*Janji Beli*).

![Ilustrasi Panggung Panen SimpanJual](mobile/assets/images/hero_harvest.jpg)

---

## Arsitektur: Cross-Platform Modular Monolith

Repositori ini menggunakan pola **Modular Monolith** terpusat agar klien Flutter maupun React.js berbagi logika bisnis deterministik dan jaminan integritas database yang identik, dengan arah antarmuka **Tema Rimbun Panen & Lumbung** yang diatur di [DESIGN.md](DESIGN.md) dan aturan kualitas [AGENTS.md](AGENTS.md).

```text
sevent_x/
├── mobile/                 # Aplikasi Utama Kategori Mobile: Flutter (Dart) Android APK, Web, & Desktop
├── web/                    # Aplikasi Pendamping Lintas-Platform: React.js 19 + TypeScript + Vite + Tailwind CSS
├── backend/                # Go Modular Monolith API + SQL Migrations + Idempotent Seeder
│   ├── cmd/api/            # Entrypoint HTTP server (timeouts 3-lapis + graceful shutdown)
│   ├── cmd/dbtool/         # CLI migrasi terversi (up/down/reset) & database seeder idempoten
│   ├── migrations/         # Skema PostgreSQL 17 + B-Tree Indexes + tabel idempotency_keys
│   └── internal/
│       ├── platform/       # Config env, pgxpool, TTLCache (+test), Rate Limiter (+test), JWT+RBAC, Idempotency, JSON slog
│       └── modules/        # 8 Modul: engine (+engine_test & aiguard_test), auth, catalog, stock, lot, warehouse, demand, impact, ai
├── compose.yaml            # Orkestrasi kontainer Podman (PostgreSQL 17 port 5435 + profil full API/Web)
├── render.yaml             # Blueprint deploy Cloud Go API + PostgreSQL
├── scripts/                # Utilitas manajemen kontainer Podman lintas platform
└── docs/                   # PRD v2.2, Audit Spesifikasi Teknis, & Panduan Proposal/Deploy/Video
```

### Praktik Rekayasa Backend & Database pada `backend/` (Go + PostgreSQL 17)
1. **Proteksi & Keamanan:** Token-Bucket **Rate Limiting** (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `Retry-After`), **CORS Policy**, batas payload (`http.MaxBytesReader` 1 MB), **Stateless JWT (`HS256`) + RBAC Server-Side**, sensor nomor WhatsApp sebelum pengajuan disetujui, serta kredensial penuh lewat *environment variables* (lihat [.env.example](.env.example)).
2. **Kebenaran Data & Konkurensi:** Transaksi PostgreSQL atomik memakai **`SELECT ... FOR UPDATE`** dengan urutan penguncian baris konsisten (*consistent lock ordering*), dukungan header **`Idempotency-Key`** pada mutasi `POST`, serta bebas *concurrent map writes* via `sync.Mutex`/`sync.RWMutex`.
3. **Performa & Guardrail AI:** Query berparameter (`pgx/v5`), **Eager `JOIN`**, **In-Memory `TTLCache`** dengan *write-through invalidation*, **20+ B-Tree Indexes**, **Database Seeder Idempoten**, serta *guardrail* satuan angka AI (`aiguard.go`) dengan *fallback* template/regex instan.

---

## Cara Menjalankan Secara Lokal

### 1. Jalankan Database PostgreSQL (Podman) & Backend Go
```powershell
Copy-Item .env.example .env
npm run db:up

cd backend
go test -v ./...
go run ./cmd/api
```
*(Cek kesehatan server di `http://localhost:8080/api/v1/health`)*

### 2. Jalankan Aplikasi Utama Mobile: Flutter (Dart)
Aplikasi Flutter mendukung **Android APK**, **Web**, dan **Desktop**, serta memiliki **Mode Simulasi Mandiri (Offline)** otomatis apabila APK dibuka tanpa koneksi server lokal:
```powershell
cd mobile
flutter pub get
flutter test

# Jalankan di Android Emulator / HP terhubung:
flutter run

# Jalankan di Chrome untuk demo cepat lintas-platform:
flutter run -d chrome

# Bangun APK Rilis untuk pengumpulan lomba (mengarah ke localhost/emulator atau API publik):
flutter build apk --release
# Atau dengan URL server cloud publik:
flutter build apk --release --dart-define=API_BASE_URL=https://simpanjual-api.onrender.com
```
File output APK rilis berada di: `mobile/build/app/outputs/flutter-apk/app-release.apk`.

### 3. Jalankan Aplikasi Pendamping Web: React.js
```powershell
cd web
npm install
npm run dev
```
*(Buka `http://localhost:5173`)*

---

## Akun Demo (Tersedia 1-Click Demo Login di Flutter & React.js)
Kata sandi login manual seluruh akun demo: **`demo12345`**

| Peran | Email | Deskripsi Skenario |
|---|---|---|
| **Petani** | `petani@demo.id` | Pak Slamet: stok jagung 5 ton & gabah GKP basah 4 ton (KA 22%) |
| **Ketua Poktan** | `poktan@demo.id` | Bu Rini: Poktan Tani Jaya, kode gabung `TANIJAYA`, Lot Kolektif 6/10 ton |
| **Pengelola Gudang** | `gudang@demo.id` | Pak Joko: pengelola gudang SRG & koperasi daerah |
| **Pembeli** | `pembeli@demo.id` | Koperasi & SPPG Mitra Banyumas (*Janji Beli*) |
| **Admin** | `admin@demo.id` | Konfigurasi parameter JSONB komoditas & monitor koneksi backend |

## Dokumentasi & Deployment
- [Arah Desain & Pemeriksaan Kontras (DESIGN.md)](DESIGN.md)
- [PRD SimpanJual v2.2 (Cross-Platform Modular Monolith)](docs/PRD_SimpanJual_v2.md)
- [Audit Kritis & Spesifikasi Teknis](docs/Audit_Kritik_dan_Spesifikasi_Teknis.md)
- [Panduan Proposal, Deploy Cloud (Render + Vercel), & Video Demo SEVENT X](docs/Panduan_Proposal_Deploy_dan_Video_SEVENT_X.md)
