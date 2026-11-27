# Audit Kritis PRD v1.1 & Panduan Spesifikasi Teknis — SimpanJual (SEVENT X)

Dokumen ini merangkum seluruh temuan kritis dari evaluasi **PRD SimpanJual** terhadap **Ruleset SEVENT X (HMSE Telkom University Purwokerto)** untuk **Kategori Mobile Application (Flutter & Dart)** dengan arsitektur **Cross-Platform Modular Monolith (Flutter Mobile + React.js Web + Go Backend + Podman PostgreSQL 17)**, ilmu ekonomi pascapanen, keandalan logika AI, serta kesiapan menghadapi sesi Q&A dewan juri. Seluruh perbaikan arsitektur dan rumus dari audit ini telah diintegrasikan ke dalam `PRD_SimpanJual_v2.md` (v2.2).

---

## 1. Ringkasan Eksekutif Audit & Perubahan v1.1 → v2.1

| Aspek | Kondisi di PRD v1.1 | Masalah / Celah yang Ditemukan | Solusi Final di PRD v2.1 |
|---|---|---|---|
| **Kepatuhan Rulebook** | Mencantumkan 1 SDG utama + 2 SDG pendukung; lupa bobot Final 25% & prosedur portal | Rulebook Hal. 3 & 9 menekankan **salah satu subtema**; portal `sevent.zetech.id` punya verifikasi QRIS; Final memberi bobot 25% untuk sikap/waktu/Bahasa Indonesia | Kunci **SDG 8** sebagai subtema tunggal (SDG 2 & 12 sebagai *co-benefits*); tambah 1-Click Demo Login untuk juri; prioritaskan pembayaran & submit pagi hari (tiebreaker) |
| **Jadwal & Cakupan** | 18 rute halaman untuk 6 hari (25–30 Nov) | Malam 25 Nov workspace masih kosong; 18 rute berisiko UI setengah matang | Pemadatan menjadi **9 rute terpadu** memakai tab/modal/drawer tanpa membuang fitur pembeda |
| **Database & Deployment** | Bergantung penuh pada Supabase BaaS (Auth/RLS/RPC) | Terikat satu vendor & belum memanfaatkan kontainer lokal | **Podman PostgreSQL 17 (`compose.yaml`, port `5435`)** untuk dev lokal + **Drizzle ORM** + **JWT `httpOnly` (`jose`/`bcryptjs`)**; 100% portabel ke Vercel + Neon/Cloud Postgres lewat `DATABASE_URL` |
| **Ekonomi Pascapanen** | F6 (Kesiapan) terputus dari F4 (Keputusan); bunga `r = 12%` | Gabah panen basah (KA 22–25%) wajib dikeringkan ke KA 14% sehingga bobot menyusut ~11,6% + kena ongkos jemur; v1.1 memberi ilusi untung palsu | Integrasi rumus konversi bobot $Q_{\text{siap}}$ dan $C_{\text{dry}}$; tambah preset **S-SRG 6% (Subsidi Pemerintah)** + opsi Tebasan di F5 |
| **Matematika & Unit Test** | Pembulatan tengah pada contoh 8.7; skor gudang relatif | `H(8)` berbeda Rp158 antara hitungan manual v1.1 dan floating-point kode; skor relatif gudang menghasilkan **`NaN`** jika hasil filter = 1 gudang | Aturan IEEE-754 murni di tengah, `Math.ceil` khusus `P_be` (`5.383`); skor gudang deterministik berbasis patokan tarif komoditas |
| **Prediksi Harga** | Rata-rata bergerak & Holt Linear biasa | Holt Linear mengekstrapolasi garis lurus melewati puncak paceklik saat minggu ke-12 masuk panen raya | Gunakan **Holt Damped Trend ($\phi = 0,90$)** dan **Seasonal-Adjusted MA** untuk data $\ge 52$ minggu |
| **Transaksi & Keamanan** | Mutasi langsung klien & status tunggal pada `stocks` | Risiko *race condition*, *double-booking* stok, kapasitas gudang korup saat batal, dan kebocoran akses lintas peran | Kolom `reserved_kg` & `sold_kg`; `terpenuhi_kg` di `buyer_demands`; **4 transaksi Drizzle `db.transaction()` dengan `SELECT ... FOR UPDATE`** + validasi peran JWT server-side |
| **Guardrail AI (F14/F15)** | Validator cek semua angka ±1%; F15 tanpa tanggal | Angka nomor urut (`1.`) dan pembulatan `"Rp2,0 juta"` (selisih 2,38%) ditolak validator; `"besok"` di WA gagal terurai | Ekstraksi **angka berunit saja** (abaikan nomor urut), toleransi ±5% untuk istilah `juta/ribu`, injeksi `current_date` & konversi kuintal/karung |
| **Aksesibilitas (10%)** | Hanya menyebut kontras & label standar | Persona usia 48 tahun di sawah butuh dukungan baca/suara nyata | **Toolbar `Aa+ Mode Lapangan`** + tombol **🔊 Bacakan Rekomendasi** (*Web Speech API* `id-ID`) |

---

## 2. Bedah Mendalam 6 Area Kritis

### 2.1 Kepatuhan Rulebook SEVENT X & Psikologi Juri
1. **Ancaman Verifikasi Portal (`sevent.zetech.id`):** Pendaftaran mensyaratkan unggah KTM, Twibbon, IG Story, follow `@sevent.tup`, gabung Discord, Team Code, dan pembayaran QRIS **Rp80.000**. Jika verifikasi pembayaran oleh panitia memakan waktu 12–24 jam, mendaftar di tanggal 29–30 Nov bisa mengunci tombol *submit*. **Aksi wajib:** selesaikan pendaftaran dan pembayaran paling lambat 26 Nov pagi.
2. **Keunggulan *Tiebreaker* (Hal. 14 Rulebook):** Jika terjadi nilai seri pada tahap penyisihan, karya yang dikumpulkan lebih awal diprioritaskan. Jadwal tim wajib menargetkan *code freeze* Minggu 29 Nov pukul 14.00 WIB dan *submit* Senin 30 Nov pagi (≤ 10.00 WIB).
3. **Jebakan *Commit History* & Akses Demo:** Penyelenggara berasal dari HMSE (Rekayasa Perangkat Lunak) dengan bobot **30% pada Implementasi Kode & Deployment**. Repo GitHub harus menunjukkan progres *commit* bertahap sejak hari pertama, dilengkapi `.env.example`, GitHub Actions CI, `compose.yaml` (Podman), dan **tombol 1-Click Demo Login** di halaman `/masuk` agar juri bisa menguji seluruh peran dalam hitungan detik tanpa mengetik ulang kata sandi.
4. **Bobot Final 25% (Hal. 15 Rulebook):** 25% nilai final bukan soal kode, melainkan **kesopanan, ketepatan waktu, dan penggunaan Bahasa Indonesia yang baik dan benar**. Latih skrip presentasi dengan *stopwatch* ketat sebelum hari H.

### 2.2 Matematika & Fisika Pascapanen yang Akurat
Mengapa konversi kadar air menjadi pembeda kualitas teknis yang sangat kuat?
- Di lapangan, petani memanen Gabah Kering Panen (GKP) pada kadar air ~22%–25% (harga lebih rendah, tidak boleh masuk gudang SRG), sementara gudang SRG mensyaratkan Gabah Kering Giling (GKG) pada kadar air maksimal 14%.
- Rumus konservasi massa bahan kering:
  $$Q_{\text{siap}} = Q \times \frac{100 - KA_{\text{aktual}}}{100 - KA_{\text{ambang}}}$$
  Contoh: `5.000 kg` gabah berkadar air `24%` yang dikeringkan ke `14%` akan kehilangan `581,4 kg` massa air menjadi **`4.418,6 kg`** GKG, serta menanggung ongkos pengeringan (`Rp150/kg × 5.000 = Rp750.000`). Memasukkan realitas ini membuktikan aplikasi Anda benar-benar dirancang untuk dunia nyata, bukan sekadar kalkulator tugas kuliah.

### 2.3 Arsitektur Podman PostgreSQL, Race Condition & RBAC Server-Side
Dengan beralih ke **Podman (`postgres:17-alpine`) + Drizzle ORM + Session JWT (`jose`)**:
1. **Isolasi Akses Lintas-Peran di Server (`RBAC`):** Setiap API Route & Server Action memeriksa token JWT `httpOnly` (`getSessionUser()`). Petani tidak pernah bisa mengubah langsung kapasitas gudang (`warehouses.tersedia_kg`) dan Pembeli tidak bisa mengutak-atik stok bebas petani (`stocks`) secara sembarang. Semua perubahan lintas-entitas wajib melewati fungsi transaksi atomik di `src/db/transactions.ts`.
2. **Penguncian Baris `SELECT ... FOR UPDATE`:** Tanpa penguncian baris di level database PostgreSQL, dua petani bisa mengajukan sewa ke sisa kapasitas gudang yang sama secara bersamaan hingga kapasitas menjadi negatif. Dengan `.for('update')` di dalam `db.transaction()`, PostgreSQL menjamin antrean transaksi dieksekusi berurutan secara atomik, baik saat berjalan di **Podman lokal** maupun di **Cloud PostgreSQL** saat penjurian.
3. **Korupnya Kapasitas Gudang Saat Pembatalan:** Kapasitas gudang (`tersedia_kg`) hanya dikurangi saat pengelola gudang menekan **Terima**. Oleh karena itu, ketika petani membatalkan pengajuan yang masih berstatus `diajukan`, fungsi transaksi hanya melepas `reserved_kg` stok petani—**tanpa** menambah kembali `tersedia_kg` gudang.

### 2.4 Guardrail AI (F14 & F15) Tanpa *False Positive*
Pada PRD v1.1, validator regex yang memeriksa *semua* angka dengan toleransi ±1% akan gagal pada kondisi paling umum:
- Kalimat `"1. Pastikan kadar air..."` mengekstrak angka `1` → ditolak karena `1` tidak ada di JSON input.
- Kalimat `"Selisih sekitar Rp2,0 juta"` memiliki selisih `2,38%` dari `2.048.822` → ditolak oleh batas `1%`.
Dengan membatasi ekstraksi pada **token angka berunit** (memiliki `Rp`, `%`, `kg`, `ton`, `minggu`, `hari`) dan membedakan toleransi ±1% (angka presisi) vs ±5% (pembulatan juta/ribu), tingkat kelolosan penjelasan AI yang valid meningkat drastis sambil tetap memblokir angka halusinasi.

---

## 3. Referensi Cepat Implementasi Transaksi Drizzle Atomik

Bagian ini menjadi acuan langsung untuk `src/db/transactions.ts` (100% portabel antara Podman PostgreSQL lokal dan Cloud PostgreSQL):

```ts
export async function respondRental(
  actorUserId: string,
  requestId: string,
  action: 'terima' | 'tolak' | 'selesai' | 'batal',
  reason?: string
) {
  return db.transaction(async (tx) => {
    const [req] = await tx
      .select()
      .from(rentalRequests)
      .where(eq(rentalRequests.id, requestId))
      .for('update');

    if (!req) throw new Error('Pengajuan sewa tidak ditemukan');

    const [wh] = await tx
      .select()
      .from(warehouses)
      .where(eq(warehouses.id, req.warehouseId))
      .for('update');

    if (!wh) throw new Error('Gudang tidak ditemukan');

    if (action === 'batal') {
      if (req.requesterId !== actorUserId) {
        throw new Error('FORBIDDEN: Hanya pengaju yang dapat membatalkan');
      }
      if (req.status !== 'diajukan' && req.status !== 'diterima') {
        throw new Error('Status pengajuan tidak dapat dibatalkan');
      }
      if (req.status === 'diterima') {
        await tx
          .update(warehouses)
          .set({ tersediaKg: Math.min(wh.kapasitasKg, wh.tersediaKg + req.qtyKg) })
          .where(eq(warehouses.id, wh.id));
      }
      if (req.stockId) {
        await releaseStockReserve(tx, req.stockId, req.qtyKg);
      } else if (req.lotId) {
        await tx.update(lots).set({ status: 'siap_ajukan' }).where(eq(lots.id, req.lotId));
      }
      await tx
        .update(rentalRequests)
        .set({ status: 'dibatalkan', alasanTolak: reason ?? null, updatedAt: new Date() })
        .where(eq(rentalRequests.id, req.id));
      return { ok: true, status: 'dibatalkan' };
    }

    if (wh.ownerId !== actorUserId) {
      throw new Error('FORBIDDEN: Hanya pemilik gudang yang berwenang');
    }

    if (action === 'terima' && req.status === 'diajukan') {
      if (wh.tersediaKg < req.qtyKg) {
        throw new Error('Kapasitas gudang tersedia tidak mencukupi');
      }
      await tx
        .update(warehouses)
        .set({ tersediaKg: wh.tersediaKg - req.qtyKg })
        .where(eq(warehouses.id, wh.id));
      await tx
        .update(rentalRequests)
        .set({ status: 'diterima', updatedAt: new Date() })
        .where(eq(rentalRequests.id, req.id));
      return { ok: true, status: 'diterima' };
    }

    if (action === 'tolak' && req.status === 'diajukan') {
      if (req.stockId) {
        await releaseStockReserve(tx, req.stockId, req.qtyKg);
      } else if (req.lotId) {
        await tx.update(lots).set({ status: 'siap_ajukan' }).where(eq(lots.id, req.lotId));
      }
      await tx
        .update(rentalRequests)
        .set({ status: 'ditolak', alasanTolak: reason ?? null, updatedAt: new Date() })
        .where(eq(rentalRequests.id, req.id));
      return { ok: true, status: 'ditolak' };
    }

    if (action === 'selesai' && req.status === 'diterima') {
      await tx
        .update(warehouses)
        .set({ tersediaKg: Math.min(wh.kapasitasKg, wh.tersediaKg + req.qtyKg) })
        .where(eq(warehouses.id, wh.id));
      if (req.stockId) {
        await releaseStockReserve(tx, req.stockId, req.qtyKg);
      } else if (req.lotId) {
        await tx.update(lots).set({ status: 'selesai' }).where(eq(lots.id, req.lotId));
      }
      await tx
        .update(rentalRequests)
        .set({ status: 'selesai', updatedAt: new Date() })
        .where(eq(rentalRequests.id, req.id));
      return { ok: true, status: 'selesai' };
    }

    throw new Error(`Transisi status tidak valid dari ${req.status} ke ${action}`);
  });
}
```

---

## 4. Bank Pertanyaan & Jawaban Teknis Q&A Final (10 Pertanyaan Jebakan Juri)

Persiapkan seluruh anggota tim agar mampu menjawab 10 pertanyaan kritis berikut dengan data dan argumen teknis yang tenang:

1. **Juri:** *"Jika petani panen gabah basah kadar air 24%, bukankah menahan stok di gudang SRG tidak bisa langsung dilakukan karena bobotnya pasti menyusut saat dikeringkan?"*
   - **Jawaban:** "Betul sekali, Pak/Bu. Karena itulah di SimpanJual fitur Cek Kesiapan Simpan (F6) terhubung langsung ke mesin hitung (F4). Jika petani menginput kadar air aktual 24% sedangkan ambang simpan gabah 14%, sistem otomatis menyusutkan estimasi bobot kering ($Q_{\text{siap}}$) sekitar 11,6% dan menambahkan biaya penjemuran sebelum menghitung titik impas. Jadi tidak ada ilusi keuntungan palsu."

2. **Juri:** *"Sudah ada portal Loka MBG dari Badan Gizi Nasional dan sistem SRG resmi dari Bappebti. Mengapa aplikasi ini tidak sekadar menduplikasi mereka?"*
   - **Jawaban:** "Kami memosisikan SimpanJual sebagai lapisan koordinasi *pre-SRG* dan *upstream* sebelum masuk ke marketplace seperti Loka MBG. Masalah di lapangan berdasarkan kajian BI dan Bappebti adalah petani kecil terhalang volume minimal 10 ton, terikat panjar tengkulak, dan tidak tahu gudang mana yang kosong. SimpanJual menyelesaikan hambatan hulu tersebut lewat Panjar Tandingan, Lot Kolektif poktan, dan pencocokan kapasitas gudang."

3. **Juri:** *"Mengapa tidak memakai model Machine Learning atau LLM langsung untuk memprediksi harga dan menghitung keuntungan agar lebih canggih?"*
   - **Jawaban:** "Untuk keputusan finansial petani kecil, akuntabilitas dan transparansi jauh lebih penting daripada *black-box*. Prediksi kami memakai tiga model deret waktu statistik (*WMA-4*, *Holt Damped Trend*, dan *Seasonal-Adjusted MA*) yang dipilih otomatis per komoditas berdasarkan MAPE *rolling-origin backtest* terendah serta menampilkan pita ketidakpastian 80%. Sementara LLM sengaja kami batasi hanya untuk menerjemahkan angka mesin hitung ke bahasa awam (F14) dan mengekstrak teks tawaran (F15), dilengkapi validator angka di sisi server sehingga AI mustahil mengarang angka keuntungan."

4. **Juri:** *"Bagaimana jika model prediksi harga Anda salah karena tiba-tiba masuk musim panen raya?"*
   - **Jawaban:** "Pertama, kami menghindari Holt linear murni dan memakai *Damped Trend* ($\phi=0,90$) serta komponen indeks musiman untuk data $\ge 52$ minggu agar proyeksi minggu ke-12 tidak menanjak tak wajar. Kedua, aturan rekomendasi kami sangat konservatif: status `TAHAN` penuh hanya keluar jika pada batas bawah pita 80% ($P_{\text{low}}$) petani masih untung; jika hanya untung di titik tengah tetapi rugi di batas bawah, sistem memberi peringatan `TAHAN_BERISIKO`."

5. **Juri:** *"Bagaimana Anda menjamin keamanan data lintas-peran, ketahanan sinyal seluler di desa, dan mencegah bentrok kapasitas gudang saat dua petani mengajukan sewa bersamaan?"*
   - **Jawaban:** "Kami menggunakan arsitektur **Go Modular Monolith + PostgreSQL 17 (Podman)**. Seluruh endpoint dijaga oleh JWT `HS256` stateless, RBAC server-side, dan Token-Bucket Rate Limiter. Untuk mencegah *race condition* dan *deadlock*, mutasi lintas-peran (`submitRental`, `respondRental`, `submitSale`, `respondSale`) memakai transaksi PostgreSQL `SELECT ... FOR UPDATE` dengan urutan penguncian baris konsisten (*consistent lock ordering*). Selain itu, aplikasi Flutter mengirim header `Idempotency-Key` pada mutasi `POST` sehingga *retry* sinyal 4G yang putus-nyambung di desa tidak pernah memicu *double-booking*."

6. **Juri:** *"Bagaimana jika petani salah menginput atau sengaja menggelembungkan stok/mutu pada data?"*
   - **Jawaban:** "Di ruang lingkup MVP, kami menetapkan asumsi verifikasi fisik akhir tetap dilakukan oleh pengelola gudang atau lembaga penilai mutu saat serah terima, dan itu dicantumkan eksplisit pada disclaimer aplikasi. Namun secara arsitektur, sistem mencegah *double-booking* stok secara matematis melalui pelacakan `reserved_kg` dan `sold_kg`."

7. **Juri:** *"Apa bukti konkret bahwa arsitektur kalian 'Scalable' sesuai tema SEVENT X, bukan hanya untuk jagung dan gabah?"*
   - **Jawaban:** "Seluruh aturan mutu, rasio susut bulanan, biaya pengeringan, patokan tarif, dan kebutuhan fasilitas wajib disimpan dalam kolom JSONB pada tabel `commodities`. Saat admin menambahkan komoditas baru seperti Kedelai di halaman `/admin` dan mengunggah histori harganya, grafik proyeksi, cek kesiapan, skor gudang, dan kalkulator titik impas langsung bekerja otomatis tanpa perubahan kode aplikasi. Infrastruktur databasenya juga portabel lewat satu variabel `DATABASE_URL` dari Podman lokal ke Cloud PostgreSQL."

8. **Juri:** *"Apa yang terjadi jika kuota API AI habis atau server AI lambat saat aplikasi dipakai petani di desa?"*
   - **Jawaban:** "Kami memasang *timeout* 8 detik dengan *fallback* deterministik otomatis. Untuk F14, jika AI gagal atau diblokir validator angka, pengguna tetap menerima ringkasan berbasis template yang akurat. Untuk F15, sistem jatuh ke parser regex lokal atau input manual. Seluruh alur inti aplikasi tetap berjalan 100% bahkan ketika `AI_ENABLED=false`."

9. **Juri:** *"Bagaimana petani usia lanjut yang kurang akrab dengan istilah teknis dan akses di bawah terik matahari menggunakan aplikasi ini?"*
   - **Jawaban:** "Pada aplikasi **Flutter (Dart)** maupun pendamping **React.js Web**, kami merancang satu keputusan besar per layar dengan angka Rupiah langsung, menyertakan tombol `Aa+ Mode Lapangan` (`TextScaler` 114% & kontras tinggi untuk layar HP di bawah terik matahari), tombol `Bacakan Rekomendasi` berbasis *Text-to-Speech* Bahasa Indonesia (`flutter_tts` `id-ID`), serta **Mode Simulasi Offline Mandiri** otomatis apabila juri atau petani membuka APK saat tidak terjangkau server."

10. **Juri:** *"Apa model bisnis berkelanjutan SimpanJual setelah lomba ini selesai?"*
    - **Jawaban:** "Layanan dasar kalkulasi keputusan dan panjar tandingan gratis untuk petani kecil. Monetisasi berkelanjutan (B2B/B2G) berasal dari *subscription* manajemen kapasitas untuk pengelola gudang swasta/koperasi serta biaya koordinasi pasokan (*sourcing fee* kecil per transaksi selesai) bagi pembeli institusi atau pabrik yang membutuhkan pasokan lokal terkurasi dan stabil."
