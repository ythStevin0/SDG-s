# Panduan Finalisasi Proposal, Deployment Cloud, APK Rilis, & Video Demo SEVENT X

Dokumen ringkas ini menjadi panduan praktis tim untuk menyelesaikan berkas non-kode sebelum tenggat pengumpulan **SEVENT X Software Development**.

---

## 1. Kerangka Isi Proposal Karya (Mengikuti Template Resmi Panitia)

Gunakan template `.docx`/dokumen resmi dari panitia SEVENT X tanpa mengubah struktur babnya (maksimal 25 halaman di luar sampul, daftar pustaka, dan lampiran). Pastikan poin kunci berikut masuk ke dalam bab yang sesuai:

- **Latar Belakang & Urgensi (SDG 8):** Kutip data ketimpangan pemanfaatan SRG daerah (Bantul hanya ~5% kapasitas terpakai), kesejahteraan petani pengguna SRG 1,6x non-pengguna (Bappebti / Bisnis.com), serta hambatan volume minimal 10 ton dan jeratan panjar separuh harga pasar (Kajian Bank Indonesia & UGM). Fokuskan dampak pada **SDG 8 (Decent Work and Economic Growth)** dengan SDG 2 dan SDG 12 sebagai dampak ikutan.
- **Solusi & 5 Pembeda Utama:**
  1. Konversi massa kadar air panen basah ke mutu siap simpan ($Q_{\text{siap}}$) terintegrasi langsung ke titik impas harga (`Math.ceil`).
  2. Panjar Tandingan (mode Per-Kg & Tebasan Borongan) melawan plafon talangan S-SRG 6%.
  3. Lot Kolektif Kelompok Tani dengan kode gabung `TANIJAYA` agar petani kecil menembus syarat volume minimal 5-10 ton.
  4. Peta OpenStreetMap & Skor Kelayakan Gudang deterministik anti-`NaN` (0-100).
  5. Bantuan AI (`F14` & `F15`) terkendali *guardrail* satuan angka (`aiguard.go`) dengan *fallback* deterministik instan.
- **Arsitektur Teknis (Cross-Platform Modular Monolith):**
  - Aplikasi Utama Mobile: **Flutter 3.47 (Dart)** untuk Android APK, Web, & Desktop + Mode Offline Mandiri.
  - Aplikasi Pendamping Web: **React.js 19 + TypeScript + Vite + Tailwind CSS**.
  - Backend: **Go 1.26 Modular Monolith + PostgreSQL 17 (Podman lokal / Cloud Postgres)** dengan `SELECT ... FOR UPDATE`, `Idempotency-Key`, Token-Bucket Rate Limiter, `TTLCache`, dan JSONB komoditas dinamis.

---

## 2. Daftar Pustaka & Lisensi Open-Source (Lampiran Surat Pernyataan Orisinalitas)

Rulebook SEVENT X Hal. 9 mewajibkan pencantuman pustaka pihak ketiga beserta lisensinya. Tim dapat melampirkan tabel berikut:

| Komponen / Pustaka | Lapisan | Lisensi Resmi |
|---|---|---|
| Flutter SDK & Dart SDK (`material`, `cupertino_icons`) | Mobile Utama (`mobile/`) | BSD-3-Clause |
| `http`, `shared_preferences`, `url_launcher`, `flutter_tts` | Mobile Utama (`mobile/`) | BSD-3-Clause / MIT |
| `flutter_map` & `latlong2` + Peta OpenStreetMap (ODbL) | Mobile Utama (`mobile/`) | BSD-3-Clause / Apache-2.0 |
| Go Standard Library & `github.com/jackc/pgx/v5` | Backend (`backend/`) | BSD-3-Clause & MIT |
| `github.com/golang-jwt/jwt/v5`, `github.com/google/uuid`, `golang.org/x/crypto` | Backend (`backend/`) | MIT & BSD-3-Clause |
| PostgreSQL 17 (`postgres:17-alpine`) | Database | PostgreSQL License |
| React 19, Vite 6, Tailwind CSS 3, TypeScript 5 | Web Pendamping (`web/`) | MIT / Apache-2.0 |

---

## 3. Langkah Deploy Cloud Online 24 Jam (Sekitar 10 Menit)

Agar juri dapat membuka Web Pendamping sekaligus menghubungkan APK Android ke server hidup selama penjurian:

### A. Deploy Backend Go & PostgreSQL ke Render (menggunakan `render.yaml`)
1. Push branch repositori ke GitHub.
2. Masuk ke dashboard **Render** -> **New +** -> **Blueprint**, lalu hubungkan repositori GitHub ini. Render otomatis membaca berkas [render.yaml](file:///d:/sevent_x/render.yaml).
3. Setelah database PostgreSQL (`simpanjual-db`) dan web service (`simpanjual-api`) aktif, jalankan satu kali migrasi & seeder dari terminal lokal menggunakan URL eksternal database Render:
   ```powershell
   $env:DATABASE_URL="postgresql://USER:PASSWORD@HOST/simpanjual?sslmode=require"
   cd backend
   go run ./cmd/dbtool up
   go run ./cmd/dbtool seed
   ```
4. Pastikan endpoint publik `https://<nama-service>.onrender.com/api/v1/health` mengembalikan `200 OK`.

### B. Deploy Web Pendamping React.js ke Vercel (menggunakan `web/vercel.json`)
1. Masuk ke **Vercel** -> **Add New Project**, pilih repositori GitHub dengan **Root Directory = `web`**.
2. Tambahkan Environment Variable:
   - `VITE_API_BASE_URL` = `https://<nama-service>.onrender.com`
3. Klik **Deploy**.

### C. Bangun APK Rilis Mengarah ke Server Publik
Saat merakit APK final sebelum diunggah ke GitHub Releases / formulir pengumpulan:
```powershell
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://<nama-service>.onrender.com
```
*(Catatan: Tanpa `--dart-define`, APK tetap berjalan mulus di HP mana pun berkat Mode Simulasi Offline Mandiri bawaan atau pengaturan URL server di menu Pengaturan Server.)*

---

## 4. Susunan Adegan Video Demo YouTube (Maksimal 5 Menit)

Format judul YouTube: `Nama Tim | SoftDev - SEVENT X National Competition`

1. **0:00 - 0:40 (Masalah Nyata & Solusi SDG 8):** Ceritakan dilema Pak Slamet menghadapi tawaran panjar separuh harga pasar saat gabah basah KA 22% dan gudang SRG daerah kosong.
2. **0:40 - 1:45 (Demo Aplikasi Mobile Flutter APK):** Tampilkan beranda botani *Panen Raya*, uji kalkulator instan, pindah ke **5 Akun Demo** sebagai *Pak Slamet*, tunjukkan `Aa+ Mode Lapangan`, Mode Rimbun Gelap, grafik titik impas, **Panjar Tandingan** (ekstrak teks WA), dan klik **Bacakan Suara (`id-ID`)**.
3. **1:45 - 3:05 (Jalur SIMPAN: Lot Kolektif & Gudang SRG Atomik):** Masuk **Peta OpenStreetMap & Skor Gudang (0-100)**, gabung Lot Kolektif kode `TANIJAYA`, ajukan sewa, lalu pindah 1-klik ke akun **Pak Joko (Gudang SRG)** untuk menerima pengajuan (kapasitas otomatis berkurang secara atomik).
4. **3:05 - 4:10 (Jalur JUAL, Skalabilitas JSONB, & Web Companion React):** Ajukan jual ke **Koperasi/SPPG Mitra**, selesaikan transaksi sebagai pembeli hingga Kartu Dampak naik, tunjukkan panel **Admin** menambah/mengedit komoditas JSONB, serta tampilkan keselarasan Web Pendamping React.js.
5. **4:10 - 4:50 (Bukti Rekayasa & Penutup):** Perlihatkan `go test ./...`, `flutter test`, GitHub Actions CI hijau, dan kejujuran pelabelan data simulasi ilustratif.
