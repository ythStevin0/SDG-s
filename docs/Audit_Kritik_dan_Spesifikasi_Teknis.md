# Audit Kritis & Panduan Spesifikasi Teknis: SimpanJual (SEVENT X)

Dokumen ini merangkum seluruh temuan kritis dari evaluasi **PRD SimpanJual** terhadap **Ruleset SEVENT X (HMSE Telkom University Purwokerto)** untuk **Kategori Mobile Application (Flutter & Dart)** dengan arsitektur **Cross-Platform Modular Monolith (Flutter Mobile + React.js Web + Go Backend + Podman PostgreSQL 17)**, ilmu ekonomi pascapanen, keandalan logika AI, serta kesiapan menghadapi sesi Q&A dewan juri.

---

## 1. Ringkasan Eksekutif Audit & Penyelarasan Arsitektur Final

| Aspek | Kondisi Awal (v1.1) | Masalah / Celah yang Ditemukan | Solusi Final di Kode & PRD v2.2 |
|---|---|---|---|
| **Kepatuhan Rulebook** | Mencantumkan 1 SDG utama + 2 SDG pendukung; belum menekankan kategori & bobot Final 25% | Rulebook menekankan **salah satu subtema** dan kategori **Mobile Application**; Final memberi bobot 25% untuk sikap/waktu/Bahasa Indonesia | Kunci **SDG 8** sebagai subtema tunggal (SDG 2 & 12 sebagai *co-benefits*); fokus klien utama **Flutter Android APK** + pendamping **React.js Web** + **1-Click Demo Login** |
| **Database & Skalabilitas** | Bergantung penuh pada layanan BaaS tunggal | Terikat satu vendor & belum memanfaatkan kontainer lokal serta caching terkelola | **Podman PostgreSQL 17 (`compose.yaml`, port `5435`)** + **Go `pgx/v5` (`pgxpool`)** + **`TTLCache` (write-through invalidation)** + **`SELECT ... FOR UPDATE`**; portabel ke Cloud Postgres via `DATABASE_URL` |
| **Ekonomi Pascapanen** | F6 (Kesiapan) terputus dari F4 (Keputusan); bunga `r = 12%` | Gabah panen basah (KA 22-25%) wajib dikeringkan ke KA 14% sehingga bobot menyusut ~11,6% + ongkos jemur; v1.1 memberi ilusi untung palsu | Integrasi rumus konversi bobot $Q_{\text{siap}}$ dan $C_{\text{dry}}$; preset **S-SRG 6%** + opsi **Tebasan Borongan** di F5 |
| **Matematika & Unit Test** | Pembulatan tengah pada contoh; skor gudang relatif | `H(8)` berbeda Rp158 antara hitungan manual dan kode; skor relatif menghasilkan **`NaN`** bila hasil filter hanya 1 gudang | IEEE-754 penuh di tengah, `Math.ceil` khusus `P_be` (`5.383`); skor gudang deterministik anti-`NaN` diuji serempak di Go & Dart |
| **Prediksi Harga** | Rata-rata bergerak & Holt Linear biasa | Holt Linear mengekstrapolasi garis lurus melewati puncak paceklik saat panen raya | **Holt Damped Trend ($\phi = 0,90$)** dan **Seasonal-Adjusted MA** untuk data $\ge 52$ minggu |
| **Transaksi, Konkurensi & Keamanan** | Risiko *race condition* dan *retry* jaringan desa | Dua petani dapat memesan sisa kapasitas yang sama bersamaan; sinyal seluler putus memicu *double-booking* | `reserved_kg` & `sold_kg`; `SELECT ... FOR UPDATE` dengan urutan kunci konsisten; **`Idempotency-Key`**; Token-Bucket Rate Limiter; **JWT `HS256` + RBAC** |
| **Guardrail AI (`aiguard.go`)** | Validator cek semua angka ±1% | Nomor urut (`1.`) ditolak dan pembulatan `"Rp2,0 juta"` gagal terhadap `2.048.822` | Ekstraksi **angka berunit saja** (`ExtractUnitNumbers`), toleransi ±5% untuk istilah `juta/ribu`, `StripPII` sensor HP/email, dan fallback deterministik |
| **Aksesibilitas & UI (`anti-slop`)** | Antarmuka seragam & belum ramah terik matahari sawah | Persona petani usia 48 tahun butuh teks besar, audio Bahasa Indonesia, kontras tinggi, & tema cerah/gelap | **Tema Rimbun Panen & Lumbung (`DESIGN.md`)**, kontras WCAG AA terverifikasi `contrast-check.py`, **Mode Terang/Gelap + `Aa+`**, suara `id-ID`, serta bebas em dash (`R-02`) |

---

## 2. Bedah Mendalam 4 Area Kritis

### 2.1 Kepatuhan Rulebook SEVENT X & Psikologi Juri
1. **Bukti Rekayasa Perangkat Lunak (Bobot 30%):** HMSE menilai implementasi kode & deployment: riwayat *commit* rapi, `.env.example`, GitHub Actions CI (Go Test + Flutter Analyze/Test/APK + React Build), `compose.yaml` + `render.yaml` + `vercel.json`, serta **1-Click Demo Login** (kata sandi manual akun demo: `demo12345`).
2. **Keunggulan *Tiebreaker* & Bobot Final 25%:** Selesaikan uji rilis `.apk` dan proposal lebih awal; latih presentasi dengan pengatur waktu ketat menggunakan Bahasa Indonesia baku dan terstruktur.

### 2.2 Matematika & Fisika Pascapanen yang Akurat
Di lapangan, Gabah Kering Panen (GKP) dipanen pada kadar air ~22-25%, sedangkan gudang SRG mensyaratkan Gabah Kering Giling (GKG) pada kadar air maksimal 14%.
$$Q_{\text{siap}} = Q \times \frac{100 - KA_{\text{aktual}}}{100 - KA_{\text{ambang}}}$$
Contoh nyata: `5.000 kg` gabah berkadar air `24%` yang dikeringkan ke `14%` kehilangan `581,4 kg` massa air menjadi **`4.418,6 kg`** GKG, serta menanggung ongkos pengeringan (`Rp150/kg x 5.000 = Rp750.000`) sebelum menghitung titik impas.

### 2.3 Arsitektur Go Modular Monolith, Podman PostgreSQL 17, & RBAC Server-Side
1. **Isolasi Akses Lintas-Peran (`middleware.RequireAuth`):** Petani tidak pernah bisa memodifikasi kapasitas gudang secara langsung dan Pembeli tidak bisa mengubah stok petani secara sewenang-wenang.
2. **Penguncian Baris `SELECT ... FOR UPDATE` (`Consistent Lock Ordering`):** Seluruh mutasi di `warehouse/module.go` dan `demand/module.go` mengunci `stocks`/`lots` terlebih dahulu baru `warehouses` atau `buyer_demands`, mencegah *race condition* sekaligus mencegah *deadlock*.
3. **Pemulihan Kapasitas Akurat Saat Pembatalan:** Jika petani membatalkan pengajuan berstatus `diajukan`, fungsi transaksi hanya melepas `stocks.reserved_kg`; kapasitas `warehouses.tersedia_kg` hanya dipulihkan bila pengajuan sudah berstatus `diterima`.

### 2.4 Guardrail AI (`aiguard.go`) Tanpa *False Positive*
Dengan `ExtractUnitNumbers` di `backend/internal/modules/engine/aiguard.go`:
- Nomor urut kalimat (`1.`, `2.`) tidak memiliki satuan sehingga otomatis diabaikan.
- Angka yang memiliki satuan (`Rp`, `%`, `kg`, `ton`, `kuintal`, `minggu`, `hari`) dinormalisasi lalu dicocokkan ke himpunan angka masukan (`±1%` nilai eksak, `±5%` singkatan `juta`/`ribu`).

---

## 3. Referensi Implementasi Transaksi Atomik Go (`backend/internal/modules/warehouse/module.go`)

Cuplikan berikut menunjukkan pola transaksi `pgx` (`SELECT ... FOR UPDATE`) aktual di backend Go SimpanJual:

```go
tx, err := m.pool.Begin(ctx)
if err != nil {
    return nil, err
}
defer tx.Rollback(ctx)

// 1. Kunci baris rental_requests lebih dulu
err = tx.QueryRow(ctx, `
    SELECT requester_id::text, stock_id::text, lot_id::text, warehouse_id::text, qty_kg, hari, status
    FROM rental_requests WHERE id = $1 FOR UPDATE
`, requestID).Scan(&requesterID, &stockID, &lotID, &warehouseID, &qtyKg, &hari, &curStatus)

// 2. Kunci baris gudang untuk validasi kepemilikan & kapasitas atomik
err = tx.QueryRow(ctx, `
    SELECT owner_id::text, kapasitas_kg, tersedia_kg FROM warehouses WHERE id = $1 FOR UPDATE
`, warehouseID).Scan(&whOwnerID, &kapasitasKg, &tersediaKg)

// 3. Saat action == "terima" && curStatus == "diajukan":
if tersediaKg < qtyKg {
    return nil, fmt.Errorf("Kapasitas gudang tersisa %.0f kg, tidak mencukupi", tersediaKg)
}
_, err = tx.Exec(ctx, `UPDATE warehouses SET tersedia_kg = $2 WHERE id = $1`, warehouseID, tersediaKg-qtyKg)
_, err = tx.Exec(ctx, `UPDATE rental_requests SET status = 'diterima', updated_at = NOW() WHERE id = $1`, requestID)
return tx.Commit(ctx)
```

---

## 4. Bank Pertanyaan & Jawaban Teknis Q&A Final (10 Pertanyaan Juri)

1. **Juri:** *"Jika petani panen gabah basah kadar air 24%, bukankah menahan stok di gudang SRG tidak bisa langsung dilakukan karena bobotnya pasti menyusut saat dikeringkan?"*
   - **Jawaban:** "Betul sekali, Pak/Bu. Karena itulah Cek Kesiapan Simpan (F6) terhubung langsung ke mesin hitung (F4). Jika petani menginput kadar air aktual 24% sedangkan ambang simpan gabah 14%, sistem otomatis menyusutkan bobot kering ($Q_{\text{siap}}$) sekitar 11,6% dan menambahkan biaya penjemuran sebelum menghitung titik impas."

2. **Juri:** *"Sudah ada portal Loka MBG dari Badan Gizi Nasional dan sistem SRG resmi dari Bappebti. Mengapa aplikasi ini tidak sekadar menduplikasi mereka?"*
   - **Jawaban:** "Kami memosisikan SimpanJual sebagai lapisan koordinasi *pre-SRG* dan *upstream* sebelum masuk ke marketplace seperti Loka MBG. Masalah di lapangan berdasarkan kajian BI dan Bappebti adalah petani kecil terhalang volume minimal 10 ton, terikat panjar tengkulak, dan tidak tahu gudang mana yang kosong. SimpanJual menyelesaikan hambatan hulu tersebut."

3. **Juri:** *"Mengapa tidak memakai Machine Learning / LLM langsung untuk memprediksi harga dan menghitung keuntungan?"*
   - **Jawaban:** "Untuk keputusan finansial petani kecil, akuntabilitas dan transparansi jauh lebih penting daripada *black-box*. Prediksi memakai model deret waktu statistik (*WMA-4*, *Holt Damped Trend*, *Seasonal-MA*) berdasar MAPE *backtest* terendah beserta pita 80%. LLM dibatasi pada penjelasan bahasa awam (F14) dan ekstrak WA (F15) dengan validator angka `aiguard.go`."

4. **Juri:** *"Bagaimana jika model prediksi harga salah karena masuk musim panen raya?"*
   - **Jawaban:** "Kami memakai *Holt Damped Trend* ($\phi=0,90$) dan komponen indeks musiman agar proyeksi tidak menanjak tak wajar. Kedua, status `TAHAN` penuh hanya muncul bila di batas bawah pita 80% ($P_{\text{low}}$) petani tetap untung; jika hanya untung di titik tengah, statusnya `TAHAN_BERISIKO`."

5. **Juri:** *"Bagaimana menjamin keamanan data, ketahanan sinyal seluler desa, dan mencegah bentrok kapasitas gudang?"*
   - **Jawaban:** "Backend memakai **Go Modular Monolith + PostgreSQL 17 (Podman)**. Seluruh endpoint dijaga JWT `HS256`, RBAC server-side, dan Token-Bucket Rate Limiter. Mutasi lintas-peran memakai transaksi PostgreSQL `SELECT ... FOR UPDATE` dengan urutan kunci konsisten, serta header `Idempotency-Key` pada permintaan `POST` sehingga *retry* sinyal 4G tidak memicu *double-booking*."

6. **Juri:** *"Bagaimana jika petani salah menginput atau menggelembungkan stok/mutu pada data?"*
   - **Jawaban:** "Verifikasi fisik akhir tetap dilakukan oleh pengelola gudang saat serah terima sesuai disclaimer aplikasi. Di dalam sistem, pelacakan `reserved_kg` dan `sold_kg` memastikan stok yang sudah dialokasikan tidak bisa dijual atau disewakan ganda."

7. **Juri:** *"Apa bukti konkret arsitektur ini 'Scalable' bukan hanya untuk jagung dan gabah?"*
   - **Jawaban:** "Seluruh aturan mutu, rasio susut, tarif patokan, dan fasilitas wajib disimpan pada kolom JSONB tabel `commodities`. Admin dapat menambah atau memperbarui komoditas baru seperti Kedelai langsung dari UI (`POST/PUT /api/v1/admin/commodities`), yang meng-invalidate `TTLCache` serta langsung mengaktifkan perhitungan di seluruh aplikasi."

8. **Juri:** *"Apa yang terjadi jika kuota API AI habis atau server tidak terjangkau saat demo di desa?"*
   - **Jawaban:** "Server AI memiliki batas tunggu 8 detik dengan fallback template/regex deterministik instan (`AI_ENABLED=false` pun tetap 100% jalan). Di sisi klien Flutter & React, tersedia **Mode Simulasi Offline Mandiri** otomatis sehingga kalkulator dan simulasi peran tetap berfungsi walau internet putus."

9. **Juri:** *"Bagaimana petani usia lanjut dan pengguna di bawah terik matahari memakai aplikasi ini?"*
   - **Jawaban:** "Kami menerapkan desain **Rimbun Panen & Lumbung (`DESIGN.md`)** teruji kontras WCAG AA, tombol pengalih Mode Terang/Gelap + `Aa+ Mode Lapangan` (`TextScaler` 114% & `112.5%`), serta tombol pembaca suara Bahasa Indonesia (`flutter_tts` & *Web Speech API* `id-ID`)."

10. **Juri:** *"Apa model bisnis berkelanjutan SimpanJual setelah lomba?"*
    - **Jawaban:** "Akses dasar petani gratis. Pendapatan berkelanjutan (B2B/B2G) berasal dari langganan manajemen kapasitas gudang koperasi/swasta serta biaya fasilitasi pasokan terverifikasi (*sourcing fee* kecil per transaksi selesai) bagi pembeli institusi atau pabrik."
