# PRD: SimpanJual (v2.2 Final Blueprint)

**Platform keputusan "tahan atau jual" hasil panen berbasis data, yang menghubungkan petani, gudang, dan pembeli**

| Item | Isi |
|---|---|
| Lomba | SEVENT X Software Development (HMSE Telkom University Purwokerto) |
| Tema lomba | *"Tech for Society: Building Smart, Scalable and Intuitive Solutions"* (Sub-tema SoftDev: *"Developing Sustainable Tech Solutions for Society"*) |
| Kategori | **Mobile Application (Flutter & Dart: Android APK, Web, & Desktop)** + Pendamping Lintas-Platform (**React.js Web**) |
| Subtema SDG Tunggal (sesuai Rulebook) | **SDG 8: Decent Work and Economic Growth** (peningkatan pendapatan & kepastian ekonomi petani) |
| Dampak Ikutan (*Co-benefits*) | SDG 2 (Zero Hunger: ketahanan pasokan pangan) & SDG 12 (Responsible Consumption and Production: reduksi susut pascapanen) |
| Batas submit | Senin, 30 November 2026 (Penilaian 1-4 Des, Pengumuman Finalis 5 Des, Final 10 Des, Daring) |
| Versi dokumen | **2.2 (28 November 2026)**: Arsitektur **Cross-Platform Modular Monolith: Flutter Dart Mobile + React.js Web + Go Backend + Podman PostgreSQL 17**, transaksi atomik `SELECT ... FOR UPDATE` dengan urutan kunci konsisten, `Idempotency-Key`, Token-Bucket Rate Limit, `TTLCache`, B-Tree Indexes, Mode Simulasi Offline Mandiri di APK & Web, serta suara TTS `id-ID` |
| Status | Siap Eksekusi & Verifikasi Akhir (25-30 November 2026) |

> **Catatan jujur tentang dokumen ini.** Angka parameter bawaan (susut, tarif sewa, biaya pengeringan, bunga, ambang kadar air) di Bagian 8 adalah **placeholder terkonfigurasi** untuk demonstrasi dan wajib diverifikasi ke sumber resmi (SNI/Bappebti/literatur pascapanen) sebelum finalisasi proposal. Seluruh data pasar/gudang/pembeli ilustratif diberi penanda eksplisit `is_demo = true`. Persentase kemiripan dengan solusi lain di Bagian 18 adalah perkiraan dari penelusuran terbatas, bukan audit hukum/orisinalitas formal.

---

## 1. Ringkasan Eksekutif & Penyelarasan Tema Lomba

Petani kecil di Indonesia sering terpaksa menjual hasil panen saat harga jatuh karena kebutuhan uang tunai mendesak dan ketiadaan akses penyimpanan. Pemerintah telah menyediakan Sistem Resi Gudang (SRG) untuk skema tunda jual, tetapi pemanfaatannya masih sangat rendah. Penyebab yang terdokumentasi bukanlah kurangnya informasi harga, melainkan kegagalan **koordinasi dan transparansi hitung-hitungan**: volume minimal tidak terpenuhi, gudang jauh atau tidak diketahui kapasitas kosongnya, syarat kadar air sulit dipenuhi, tidak ada pembeli siaga, serta jeratan panjar/ijon tengkulak.

**SimpanJual** adalah platform lintas-perangkat (aplikasi mobile Flutter sebagai klien utama dan aplikasi web pendamping React.js) yang menyatukan tiga aktor terpisah (petani/kelompok tani, pemilik gudang, dan pembeli institusi/UMKM) dalam satu alur keputusan terpadu di atas backend **Go Modular Monolith**:

1. **Pencatatan & Penawaran:** Petani mencatat stok panen (termasuk kadar air aktual) dan tawaran panjar/tebasan tengkulak bila ada.
2. **Keputusan Berbasis Risiko & Mutu:** Mesin hitung deterministik (`backend/internal/modules/engine` dan `mobile/lib/core/engine.dart`) mengonversi susut pengeringan mutu basah ke mutu siap simpan, memproyeksikan harga beserta pita ketidakpastian, lalu mengeluarkan **rekomendasi `TAHAN`, `TAHAN_BERISIKO`, atau `JUAL` lengkap dengan titik impas harga dan selisih rupiah terhadap panjar**.
3. **Jalur SIMPAN:** Cek kesiapan mutu -> gabung ke Lot Kolektif poktan via kode gabung -> cari gudang dengan kapasitas kosong, peta interaktif, jarak terhitung, dan skor kelayakan anti-`NaN` -> ajukan sewa secara atomik (transaksi PostgreSQL `SELECT ... FOR UPDATE`).
4. **Jalur JUAL:** Lihat kebutuhan pembeli aktif (*Janji Beli*) yang cocok dengan volume dan waktu panen -> ajukan penawaran jual yang tercatat statusnya secara atomik.
5. **Bantuan AI Terkendali (Opsional):** Penjelasan rekomendasi berbahasa petani (F14) dengan *guardrail* validator angka berbasis satuan (`aiguard.go`), serta ekstraksi teks tawaran WhatsApp (F15). Angka dan keputusan tetap 100% berasal dari modul `engine` Go/Dart yang teruji.

### Penyelarasan Eksplisit Tema *"Smart, Scalable and Intuitive"* & SDG 8
- **Smart:** Menggabungkan prediksi deret waktu (*backtest* otomatis memilih model dengan MAPE terendah), kalkulasi biaya pascapanen lengkap (konversi kadar air, susut simpan, bunga S-SRG 6%), skor kelayakan gudang multi-kriteria, dan lapisan penjelas LLM berpagar validator.
- **Scalable:** Arsitektur berbasis konfigurasi komoditas JSONB di tabel `commodities`, transaksi database PostgreSQL murni lewat **`pgx/v5` (`pgxpool`) & migrasi SQL terversi** yang portabel dari kontainer **Podman** lokal ke **Cloud PostgreSQL (Render/Neon/Supabase Postgres)** hanya dengan mengganti `DATABASE_URL`. Menambah komoditas baru (misalnya Kedelai atau Beras) melalui panel Admin otomatis mengaktifkan grafik harga, aturan mutu, rumus konversi, dan skor gudang tanpa mengubah kode program.
- **Intuitive:** Alur layar terpadu per peran (disertai navigasi bawah ponsel, rel tablet, dan bilah samping desktop yang dapat diciutkan), satu keputusan utama per layar, bahasa petani dalam Rupiah nyata, **1-Click Demo Login** (JWT `HS256` & `httpOnly` cookie opsional) untuk juri, **Tema Terang/Gelap + `Aa+ Mode Lapangan`**, serta tombol **"Bacakan Rekomendasi"** berbahasa Indonesia via `flutter_tts` (`id-ID`) dan *Web Speech API*.
- **Fokus Subtema Tunggal (Rulebook Hal. 3 & Hal. 9):** Karya ini didedikasikan secara spesifik pada subtema **SDG 8: Decent Work and Economic Growth** (melindungi margin keuntungan petani kecil dan mencegah *distress sale* di bawah harga pasar). Kontribusi terhadap **SDG 2** dan **SDG 12** diposisikan sebagai dampak ikutan (*co-benefits*).

---

## 2. Latar Belakang dan Masalah

### 2.1 Bukti masalah (data sekunder)

Seluruh poin berikut dirangkum (parafrase) dari sumber di Bagian 22.

| # | Masalah yang terdokumentasi | Sumber |
|---|---|---|
| M1 | Pemanfaatan SRG oleh petani masih rendah. Bappebti menyebut sosialisasi belum optimal, pengelolaan gudang daerah belum maksimal, dan kondisi gudang timpang (ada yang penuh, ada yang kosong). | Bisnis.com (2023) |
| M2 | Petani sering menerima panjar sebelum panen dan menjual di sekitar separuh harga pasar. | Bisnis.com (2023) |
| M3 | Bappebti menyebut kesejahteraan petani pengguna SRG 1,6 kali dibanding non-pengguna. Artinya manfaatnya besar, tetapi tidak sampai ke banyak petani. | Bisnis.com (2023) |
| M4 | Syarat volume minimal (contoh Kuningan: 10 ton gabah) dan biaya SRG dirasa berat. Solusi yang disarankan adalah memakai peran poktan/gapoktan untuk menghimpun volume. | Kajian Bank Indonesia |
| M5 | Petani Bantul menyebut gudang jauh, hasil panen terbatas, minimal simpan tiga bulan, ada ongkos dan syarat kadar air. | Antara Jogja |
| M6 | Transaksi SRG di Bantul hanya sekitar 5% dari kapasitas gudang; di beberapa daerah operasional gudang berhenti. | Jurnal AGRARIS |
| M7 | Di beberapa daerah gudang yang sudah dibangun pemerintah tidak dimanfaatkan dengan baik. | Viva (Wamendag) |
| M8 | Kajian UGM menyarankan agar SRG punya pembeli siaga (*stand-by buyer*) untuk gabah petani SRG. | Repositori UGM |
| M9 | Pasokan lokal untuk MBG belum terpenuhi karena kendala harga, kuantitas, kualitas, dan kontinuitas. | Jurnal Jateng |
| M10 | BGN menyiapkan Loka MBG (marketplace pengadaan bahan baku MBG). Anggota DPR mengingatkan agar petani, koperasi, dan UMKM lokal tidak jadi penonton. | Katadata, RCTI+ |

### 2.2 Pernyataan masalah

> Petani kecil tidak punya cara praktis untuk **(a)** menghitung secara realistis apakah menahan stok (termasuk susut pengeringan dari mutu panen ke mutu simpan) benar-benar lebih untung daripada menerima panjar/tebasan atau menjual saat panen raya, **(b)** memenuhi syarat volume dan mutu penyimpanan, **(c)** menemukan ruang simpan terdekat yang tersedia dan layak, dan **(d)** memastikan ada pembeli siaga saat stok dilepas.

### 2.3 Konsekuensi bila tidak diselesaikan

- Petani menjual di bawah harga wajar, pendapatan rendah, modal musim tanam berikutnya tergerus utang panjar.
- Gudang SRG maupun gudang desa/koperasi yang sudah dibangun menganggur, investasi publik tidak optimal.
- Pembeli institusi (dapur MBG/SPPG, koperasi, penggiling) kesulitan mendapat pasokan lokal yang stabil dan memenuhi standar mutu.
- Risiko susut bobot dan *food loss* tinggi akibat penyimpanan seadanya di rumah dengan kadar air tidak terkontrol.

---

## 3. Tujuan dan Metrik Keberhasilan

### 3.1 Tujuan produk

- **G1.** Memberi petani rekomendasi tahan atau jual yang jujur secara ekonomi pascapanen (memperhitungkan konversi kadar air, susut simpan, biaya, dan ketidakpastian prediksi).
- **G2.** Menurunkan hambatan akses SRG/gudang lewat lot kolektif berbasis kode gabung, cek kesiapan mutu, dan pencarian kapasitas kosong.
- **G3.** Menghubungkan stok terverifikasi/kolektif dengan pembeli siaga lewat alur pengajuan atomik yang bebas *double-booking*.
- **G4.** Menunjukkan dampak ekonomi (tambahan pendapatan, stok terserap, estimasi susut dicegah) secara terukur dan transparan.

### 3.2 Metrik keberhasilan (untuk lomba)

| Metrik | Target MVP | Cara mengukur |
|---|---|---|
| Alur utama berjalan penuh lintas 5 akun demo tanpa *error* maupun pelanggaran hak akses | 100% pada skenario demo | Uji E2E manual + verifikasi status transaksi DB + Mode Offline APK |
| APK rilis Android & endpoint `/healthz` + `/api/v1/health` stabil | Siap uji 1-10 Des | APK `app-release.apk` + hosting Cloud API/Web aktif |
| Kinerja & ukuran bundel web serta keterbacaan lapangan | Responsif di 375px, 768px, 1280px; kontras WCAG AA | Pemeriksaan kontras `contrast-check.py` & uji build Vite |
| Unit test mesin hitung, guardrail AI, cache, & RBAC | 100% lulus di Go & Flutter | `go test ./...` + `flutter test` + GitHub Actions CI |
| Akurasi & kejujuran prediksi | MAPE *backtest* dan pita ketidakpastian 80% tampil di UI | *Rolling-origin backtest* |

### 3.3 Metrik dampak (ditampilkan di aplikasi, berbasis simulasi pada data demo)

- Tambahan pendapatan petani per keputusan (Rp) dan persentasenya.
- Volume stok yang tercatat terserap pembeli (kg).
- Jumlah petani yang tergabung dalam lot kolektif.
- Estimasi susut yang dicegah (kg), memakai selisih asumsi susut penyimpanan rumah tangga terhadap gudang layak (Bagian 8.6).

---

## 4. Persona dan Peran

| Peran | Siapa | Tujuan | Kebutuhan utama |
|---|---|---|---|
| **Petani / Pengurus Poktan** | Petani gabah/jagung skala kecil; pengurus poktan/gapoktan | Dapat harga lebih baik, terhindar dari jeratan panjar, gabungkan stok anggota | Hitungan sederhana dengan opsi konversi kadar air, bahasa awam, tombol besar `Aa+`, suara pembaca, akses HP lancar & mode offline |
| **Pemilik/Pengelola Gudang** | Pengelola gudang SRG daerah, koperasi, penggilingan, pemilik gudang swasta/desa | Mengisi kapasitas kosong yang menganggur | Daftar permintaan sewa masuk, kontrol kapasitas otomatis, checklist mutu 6 item jelas |
| **Pembeli** | Koperasi, penggiling, pabrik pakan/olahan, dapur MBG (SPPG), UMKM | Mendapat pasokan lokal stabil, sesuai volume & mutu | Memasang kebutuhan (*Janji Beli*) dengan sisa kuota otomatis, melihat stok/lot cocok |
| **Admin** | Tim pengembang / operator sistem | Menjaga konfigurasi komoditas, data harga, moderasi | Panel kelola parameter JSONB komoditas (bukti *scalability*) dan pantauan status API |

**Persona contoh (untuk proposal dan video demo)**
- *Pak Slamet*, 48 tahun, petani jagung 1 hektare. Ditawari panjar/tebasan tengkulak sebelum panen lewat pesan WhatsApp, belum paham hitungan kadar air dan resi gudang.
- *Bu Rini*, pengurus koperasi/poktan. Punya beberapa anggota dengan stok 1-2 ton yang masing-masing gagal memenuhi syarat minimal gudang 10 ton.
- *Pak Joko*, pengelola gudang SRG kabupaten yang baru terisi sebagian kapasitasnya.
- *Koperasi & SPPG Mitra Banyumas* yang membutuhkan pasokan rutin jagung pipil & gabah GKG setiap bulan.

---

## 5. Ruang Lingkup

### 5.1 Dalam lingkup (MVP)

- Dua komoditas awal: **jagung** (pipil kering) dan **gabah** (GKG/GKP), serta kemampuan menambah atau menyunting komoditas baru langsung melalui konfigurasi JSONB Admin.
- Satu wilayah fokus awal (Jawa Tengah: Banyumas, Cilacap, Purbalingga, Banjarnegara, Kebumen, Brebes, Tegal, Pemalang, Demak) dengan koordinat *centroid* kabupaten bawaan serta data gudang dan pembeli berlabel jelas `Data Ilustrasi`.
- Tiga peran utama + Admin, autentikasi JWT `HS256` (`golang-jwt/jwt/v5` + `bcrypt`), proteksi middleware RBAC server-side + transaksi atomik `pgx` (`SELECT ... FOR UPDATE`), **`Idempotency-Key`**, Token-Bucket Rate Limit, serta **1-Click Demo Login** untuk juri.
- Database lokal dijalankan di kontainer **Podman (`postgres:17-alpine`)** (`compose.yaml`, port `5435`), dan saat *deploy* online memakai **Cloud PostgreSQL (Render Postgres / Neon)** + **Vercel** melalui `DATABASE_URL` dan `VITE_API_BASE_URL`.
- Fitur inti F1-F13 di Flutter Mobile (`mobile/`) dan React.js Web Companion (`web/`) serta fitur AI terkendali F14-F15.

### 5.2 Di luar lingkup (pengembangan lanjutan)

- Pembayaran digital/escrow, verifikasi KYC perbankan, dan manajemen sengketa hukum.
- Pembiayaan resi gudang sungguhan dan integrasi API langsung ke Sistem Informasi Resi Gudang (IsReg) / Bappebti.
- Sensor IoT gudang, blockchain, serta integrasi API langsung ke Loka MBG.
- Model *deep learning* berat untuk prediksi harga. Prediksi menggunakan algoritma statistik transparan berbasis Go & Dart murni.

### 5.3 Asumsi

- **A1.** Data harga historis mingguan publik tersedia untuk komoditas terpilih; bila sumber eksternal tidak stabil saat demo, sistem menggunakan data historis sintetis bermusim berlabel `"Data ilustrasi"`.
- **A2.** Pengajuan sewa/jual di MVP merupakan komitmen pencatatan dan pemesanan kapasitas/kuota yang berstatus, bukan transaksi finansial/pembayaran.
- **A3.** Pengguna mengisi data stok dan kondisi gudang secara jujur; verifikasi fisik di lapangan menjadi kewenangan pengelola gudang.
- **A4.** Parameter biaya dan mutu default dapat diubah langsung per pengguna di panel *"Ubah Asumsi"* maupun secara global oleh Admin.

---

## 6. Alur Pengguna (*User Journey*)

### 6.1 Alur inti petani & lot kolektif

```text
Masuk (atau 1-Click Demo Login) -> Catat stok (komoditas, kg, KA aktual %, tanggal panen, kabupaten)
      -> (opsional) tempel pesan WA tawaran tengkulak (F15) atau isi manual
      -> Lihat tren harga + prediksi + pita 80% + MAPE
      -> Mesin keputusan: konversi KA (jika basah) -> TAHAN / TAHAN_BERISIKO / JUAL + titik impas + Panjar Tandingan
         |-- Jika TAHAN / TAHAN_BERISIKO:
         |     Cek Kesiapan Simpan -> (stok kecil?) Gabung / buat Lot Kolektif via Kode Gabung
         |     -> Cari gudang (peta, skor anti-NaN 0-100, jarak, tarif, kapasitas kosong)
         |     -> Ajukan sewa (transaksi atomik mengunci stok bebas) -> pantau status
         |-- Jika JUAL:
               Lihat kebutuhan pembeli cocok (Janji Beli, sisa kuota) -> Ajukan jual (transaksi atomik) -> pantau status
      -> Ringkasan dampak & audio penjelas ramah lapangan (id-ID)
```

### 6.2 Alur pemilik gudang

```text
Masuk -> Kelola profil gudang (kapasitas total, tersedia, tarif, minimal volume/hari, checklist 6 item, komoditas)
      -> Tinjau permintaan sewa masuk (status: diajukan)
      -> Terima (cek kapasitas ulang & potong tersedia_kg atomik) / Tolak (alasan; stok petani dilepas)
      -> Tandai selesai (pulihkan tersedia_kg & catat dampak)
```

### 6.3 Alur pembeli

```text
Masuk -> Pasang kebutuhan (komoditas, volume, harga acuan, tanggal butuh, kabupaten, mutu min)
      -> Tinjau penawaran jual masuk yang cocok -> Terima (tambah terpenuhi_kg atomik) / Tolak (stok petani dilepas)
      -> Tandai selesai (konversi reserved_kg ke sold_kg & catat dampak)
```

### 6.4 Diagram status pengajuan (Sewa & Jual)

```text
diajukan --(terima atomik)--> diterima --(selesai atomik)--> selesai
   |                             |
   |--(tolak atomik)--> ditolak  --(batal oleh pengaju: pulihkan kapasitas/kuota & stok)--> dibatalkan
   --(batal oleh pengaju: pulihkan stok saja)--> dibatalkan
```

---

## 7. Kebutuhan Fungsional

Prioritas MoSCoW: **M** = Must, **S** = Should, **C** = Could.

### F1: Autentikasi, Peran, dan *1-Click Demo Login* (M)
- **Cerita pengguna:** Sebagai pengguna (atau juri lomba), saya dapat mendaftar atau langsung mencoba tiap peran dengan cepat tanpa hambatan login.
- **Kriteria penerimaan:**
  - Registrasi dengan email, kata sandi (di-*hash* `bcrypt`), nama, kabupaten, dan peran (`petani`, `gudang`, `pembeli`); peran `admin` dibuat lewat *seed*.
  - Sesi memakai JWT `HS256` (dikirim via `Authorization: Bearer` oleh Flutter/Web dan cookie `httpOnly` `simpanjual_session`), divalidasi oleh `middleware.RequireAuth` di setiap endpoint terproteksi.
  - Layar masuk di Flutter dan modal akun di React menyediakan tombol **Masuk Cepat Akun Demo (1-Klik)** untuk 5 profil demo (*Pak Slamet*, *Bu Rini*, *Pak Joko*, *Koperasi & SPPG Mitra*, dan *Admin*), beserta tab daftar akun baru dan login email (`demo12345`).
  - Endpoint peran lain dilindungi RBAC server-side (`403 FORBIDDEN`).

### F2: Manajemen Stok Petani dengan Pelacakan Alokasi Parsial (M)
- **Cerita pengguna:** Sebagai petani, saya mencatat hasil panen beserta kadar air aktual dan dapat mengalokasikan sebagian atau seluruh stok ke lot/pengajuan tanpa bentrok.
- **Kriteria penerimaan:**
  - Form: komoditas, jumlah `qty_kg > 0`, kadar air aktual `0-100%`, kotoran `%`, butir rusak `%`, tanggal panen, kabupaten (wajib, otomatis mengisi *centroid* koordinat bila titik peta tidak dipilih), catatan mutu.
  - Pelacakan stok menggunakan `qty_kg`, `reserved_kg`, dan `sold_kg` sehingga `stok_bebas = qty_kg - reserved_kg - sold_kg`.
  - Status terhitung: `tersedia`, `teralokasi_sebagian`, `teralokasi_penuh`, `terjual`.
  - Hapus hanya diizinkan oleh pemilik stok (`owner_id = sess.UserID`) jika `reserved_kg = 0` dan `sold_kg = 0`.

### F3: Tren Harga dan Prediksi Statistik (M)
- **Cerita pengguna:** Sebagai petani, saya melihat pergerakan harga dan proyeksi beberapa minggu ke depan beserta tingkat keyakinannya.
- **Kriteria penerimaan:**
  - Grafik garis harga historis mingguan (`CustomPainter` di Flutter & SVG terukur di React Web) per komoditas dan wilayah.
  - Proyeksi horizon 4, 8, dan 12 minggu dengan pita ketidakpastian 80% (`P_low` hingga `P_high`) serta garis referensi titik impas.
  - Pemilihan otomatis model terbaik (WMA-4, Holt Damped Trend, atau Seasonal-Adjusted MA) melalui *rolling-origin backtest*.
  - Tampil **MAPE backtest**, jumlah titik data, tanggal data terakhir, dan label wajib: *"Prediksi bersifat perkiraan statistik, bukan jaminan harga"*.
  - Bila data < 26 titik mingguan, tampil peringatan `lowConfidence`.

### F4: Mesin Keputusan Tahan atau Jual dengan Konversi Kadar Air (M)
- **Cerita pengguna:** Sebagai petani, saya mendapat rekomendasi tahan atau jual yang memperhitungkan penyusutan bobot pengeringan dari kondisi panen ke standar simpan.
- **Kriteria penerimaan:**
  - Input otomatis dari stok dan prediksi; seluruh parameter asumsi (biaya sewa, angkut, biaya pengeringan, susut, rasio pinjaman, bunga **default S-SRG 6% atau komersial 12%**) dapat disesuaikan pengguna di panel *"Ubah Asumsi"*.
  - Jika kadar air stok melebihi ambang simpan komoditas, sistem otomatis menghitung bobot siap simpan ($Q_{\text{siap}}$) dan biaya pengeringan ($C_{\text{dry}}$) serta menampilkan keduanya secara transparan.
  - Output: rekomendasi (`TAHAN`, `TAHAN_BERISIKO`, `JUAL`), horizon optimal $t^*$, estimasi selisih pendapatan (Rp dan %), **titik impas harga (`P_be`, dibulatkan ke atas `Math.ceil`)**, dan rincian komponen biaya.
  - Tersedia tombol **"Bacakan Rekomendasi"** (`flutter_tts` & *Web Speech API* `id-ID`).
  - Setiap keputusan tersimpan ke tabel `decisions`.

### F5: Panjar Tandingan (Mode Per-Kg & Tebasan Borongan) (M)
- **Cerita pengguna:** Sebagai petani yang ditawari uang panjar atau sistem borongan oleh tengkulak, saya ingin melihat perbandingan rupiah bersihnya.
- **Kriteria penerimaan:**
  - Mendukung 2 mode input: **Harga per Kg (`Rp/kg`)** atau **Total Tebasan/Borongan (`Rp` total)** yang otomatis dikonversi ke Rp/kg berdasarkan `qty_kg` stok.
  - Output menampilkan perbandingan 2 baris arus kas: *Uang Tunai Hari Ini* (panjar vs estimasi plafon pembiayaan SRG jika memakai pinjaman) dan *Hasil Bersih Akhir* (terima panjar vs tahan stok).
  - Menampilkan selisih Rp, selisih %, dan persentase diskon panjar terhadap harga pasar saat ini (`P0`).

### F6: Cek Kesiapan Simpan (S)
- Evaluasi kadar air (%), kotoran (%), dan butir rusak (%) terhadap parameter JSONB komoditas (Bagian 8.3).
- Output: `LAYAK`, `PERLU_PERBAIKAN`, atau `BELUM_LAYAK` beserta daftar tindakan konkret.

### F7: Lot Kolektif Poktan Berbasis Kode Gabung (S)
- Pengurus membuat `farmer_groups` (`kode_gabung` unik 8 karakter, mis. `TANIJAYA`); petani lain cukup memasukkan kode tersebut untuk bergabung.
- Pengurus membuat Lot (`target_kg`, komoditas); anggota menyumbangkan sebagian/seluruh `stok_bebas` ke lot (`lot_contributions`) dengan perhitungan porsi % otomatis.
- Setelah mencapai target, ketua poktan dapat mengajukan sewa/jual atas nama lot; anggota penyumbang dapat memantau status pengajuan lot tersebut.

### F8: Pencarian Gudang dengan Kapasitas Kosong & Skor Kelayakan Anti-`NaN` (M)
- Tampilan peta interaktif (`flutter_map` OpenStreetMap di Flutter; peta koordinat regional + tautan OpenStreetMap di React Web) dan daftar kartu gudang berskor.
- Gudang yang tidak mendukung komoditas atau `tersedia_kg < qty_dibutuhkan` ditandai tidak memenuhi syarat (*ineligible*) dan diletakkan di bawah dengan alasan jelas.
- Gudang memenuhi syarat menampilkan **skor kelayakan deterministik 0-100** (Bagian 8.2) beserta 5 sub-skornya, jarak estimasi, tarif, dan estimasi total biaya sewa.

### F9: Pengajuan Sewa Atomik (M)
- Eksekusi server melalui transaksi Go `pgx` `submitRentalTx` & `respondRentalTx` (`SELECT ... FOR UPDATE`, `Idempotency-Key` pada `POST /api/v1/rentals`).
- Saat `diterima`, `warehouses.tersedia_kg` dipotong atomik; saat `ditolak`/`dibatalkan`, `reserved_kg` dan `tersedia_kg` dipulihkan sesuai status sebelumnya; saat `selesai`, kapasitas dikembalikan dan `impact_events` dicatat.
- Tombol **"Hubungi via WhatsApp"** (`wa.me`) muncul setelah pengajuan berstatus `diterima` atau `selesai`.

### F10: Dashboard Pembeli & *Janji Beli* dengan Pelacakan Sisa Kuota (M)
- Pembeli membuat kebutuhan (`komoditas`, `qty_kg`, `harga_acuan`, `dibutuhkan_pada`, `kabupaten`, `mutu_min`).
- Sistem melacak `terpenuhi_kg` dan menampilkan **sisa kuota (`qty_kg - terpenuhi_kg`)** secara *real-time*.

### F11: Pengajuan Jual Atomik (M)
- Eksekusi transaksi `submitSaleTx` & `respondSaleTx` (`SELECT ... FOR UPDATE`, `Idempotency-Key` pada `POST /api/v1/sales`).
- Menambah `terpenuhi_kg` saat `terima` dan memindahkan `reserved_kg` ke `sold_kg` saat `selesai` sambil mencatat `impact_events`.

### F12: Ringkasan Dampak (C)
- Kartu dampak menampilkan: akumulasi tambahan pendapatan (Rp), total stok terserap pembeli (kg), jumlah anggota poktan dalam lot kolektif, dan estimasi susut dicegah (kg), terhitung dari `impact_events`.

### F13: Admin, Data Awal, & Konfigurasi Skalabilitas (M)
- *Seed* idempoten (`backend/cmd/dbtool` & `internal/seed/seeder.go`) mengisi 2 komoditas awal, 64 minggu histori harga, 4 gudang SRG/koperasi/swasta, 4 kebutuhan pembeli, serta 5 akun demo.
- Endpoint `POST /api/v1/admin/commodities` dan `PUT /api/v1/admin/commodities/{id}` memperbarui parameter JSONB dan meng-invalidate `TTLCache`.

### F14: Penjelas Rekomendasi Berbasis AI dengan *Guardrail* Satuan (C)
- Endpoint `POST /api/v1/ai/explain` mengirim angka *pre-formatted* ke Gemini REST API (bila `AI_ENABLED=true`).
- **Validator angka berbasis satuan (`aiguard.go`):** mengekstrak angka dengan satuan (`Rp`, `%`, `kg`, `ton`, `kuintal`, `minggu`, `hari`), mengabaikan angka urutan daftar (`1.`, `2.`), serta memeriksa kecocokan toleransi `±1%` (nilai eksak) dan `±5%` (singkatan `"juta"`/`"ribu"`). Jika gagal, *timeout* (> 8 detik), atau `AI_ENABLED=false`, sistem otomatis menyajikan `BuildTemplateExplanation`.

### F15: Ekstrak Tawaran WhatsApp Berbasis AI dengan Konteks Tanggal & Satuan Lokal (C)
- Endpoint `POST /api/v1/ai/extract` menyensor nomor HP (`StripPII`) dan email sebelum diteruskan ke LLM atau `RegexExtractOffer`.
- Mengonversi `1 ton = 1.000 kg`, `1 kuintal = 100 kg`, `1 karung ≈ 50 kg` (`jumlah_kg` masuk `field_tidak_pasti`), serta mendeteksi `harga_per_kg` atau `harga_total_borongan`.

### Ringkasan prioritas

| Prioritas | Fitur |
|---|---|
| **Must (M)** | F1, F2, F3, F4, F5, F8, F9, F10, F11, F13 |
| **Should (S)** | F6, F7 |
| **Could (C)** | F12, F14, F15 |

---

## 8. Logika Bisnis dan Rumus Eksak

### 8.1 Mesin keputusan pascapanen (F4 & F6 terpadu)

Seluruh harga pasar $P_0$ dan prediksi $P(t)$ mengacu pada **mutu standar siap simpan** (Gabah GKG KA <= 14%, Jagung Pipil Kering KA <= 15%).

$$Q_{\text{siap}} = \begin{cases} Q \times \dfrac{100 - KA_{\text{aktual}}}{100 - KA_{\text{ambang}}} & \text{jika } KA_{\text{aktual}} > KA_{\text{ambang}} \\ Q & \text{jika } KA_{\text{aktual}} \le KA_{\text{ambang}} \end{cases}$$

$$C_{\text{dry}} = \begin{cases} Q \times c_{\text{dry}} & \text{jika } KA_{\text{aktual}} > KA_{\text{ambang}} \\ 0 & \text{selain itu} \end{cases}$$

$$\text{Susut kumulatif } s(d) = 1 - (1 - s_b)^{d/30}, \qquad Q_{\text{eff}}(t) = Q_{\text{siap}} \times (1 - s(d))$$

$$J = Q \times P_{0,\text{aktual}}, \qquad L = \rho \times (Q_{\text{siap}} \times P_0), \qquad B(t) = L \times r \times \frac{d}{365}$$

$$K(t) = C_{\text{dry}} + (Q_{\text{siap}} \times c_s \times d) + (Q_{\text{siap}} \times c_t) + A + B(t)$$

$$H(t) = Q_{\text{eff}}(t) \times P(t) - K(t), \qquad G(t) = H(t) - J, \qquad P_{\text{be}}(t) = \left\lceil \frac{J + K(t)}{Q_{\text{eff}}(t)} \right\rceil$$

**Aturan Pembulatan Ketat (`engine/decision.go` & `engine.dart`):**
- Langkah antara berjalan dalam `float64` / `double` IEEE-754 penuh tanpa pembulatan di tengah.
- `math.Round` (`jsRound`) untuk total Rupiah, 2 desimal untuk persentase dan berat, serta **`math.Ceil` khusus untuk titik impas $P_{\text{be}}$**.
- Klasifikasi: `TAHAN` jika $G_{\text{low}}(t^*) > 0$, `TAHAN_BERISIKO` jika $G(t^*) > 0$ tetapi $G_{\text{low}}(t^*) \le 0$, dan `JUAL` jika $G(t^*) \le 0$.

### 8.2 Skor kelayakan gudang anti-`NaN` (F8, skala 0-100)

1. **Gatekeeper Mutlak:** Jika komoditas tidak diterima ATAU `tersedia_kg < qty_dibutuhkan` -> `is_eligible = false`, `skor = 0`.
2. **Penilaian 5 Komponen (total maksimal 100 poin):** Fasilitas wajib (`30`), Kondisi fisik & SRG (`30`), Jarak jalan estimasi $1,3 \times \text{Haversine}$ (`15`), Efisiensi tarif terhadap patokan komoditas (`15`), dan Keleluasaan kapasitas (`10`).

### 8.3 Parameter komoditas JSONB (konfigurasi, **placeholder: wajib verifikasi SNI/SRG**)

Default `gabah`: KA maks `14%`, kotoran `3%`, rusak `5%`, susut gudang `0.005`/bln, susut rumah `0.025`/bln, pengeringan `Rp150/kg`, patokan sewa `1-8 Rp/kg/hr`. Default `jagung`: KA maks `15%`, parameter lain serupa.

### 8.4 Panjar Tandingan (F5) & 8.5 Prediksi Harga (`WMA-4`, `Holt Damped`, `Seasonal-MA`)
- Mendukung mode `per_kg` maupun `borongan`.
- Backtest *rolling-origin* memilih model dengan MAPE terendah dan interval keyakinan ~80% ($\hat{y}_{t+h} \pm 1,28 \times \text{RMSE}_h$).

### 8.6 Fixture Unit Test Terkoreksi (`engine_test.go` & `widget_test.dart`)

Kasus uji stok kering (`Q = 5000`, `P0 = 5000`, `P8 = 5800`, `t = 8` (`d = 56`), `cs = 3`, `ct = 20`, `A = 150000`, `sb = 0.01`, `rho = 0.70`, `r = 0.12`):
- `J = 25.000.000`, `L = 17.500.000`, `Q_eff = 4907.07 kg`, `K = 1.412.192`, `H = 27.048.822`, `G = 2.048.822`, **`P_be = 5.383`**.
- Panjar borongan `17.500.000` (`3.500/kg`): `Selisih_Rp = 9.548.822`, `Diskon_terhadap_pasar = 30.00%`.

---

## 9. Model Data, Infrastruktur Podman & Transaksi Atomik

### 9.1 Infrastruktur Database Portabel (Podman Lokal + Cloud Postgres)
- **Pengembangan Lokal:** Kontainer **Podman (`postgres:17-alpine`)** bernama `simpanjual-postgres` via `compose.yaml` pada port `5435:5432` dengan volume persisten `simpanjual_pgdata`.
- **Produksi Penjurian:** Cloud PostgreSQL (`Render Postgres` / `Neon`) + Go API Docker (`render.yaml`) + Web SPA (`web/vercel.json`) lewat `DATABASE_URL` dan `VITE_API_BASE_URL`.

### 9.2 Skema SQL Terversi (`backend/migrations/001_init.up.sql`)

Mencakup 16 tabel terindeks B-Tree: `users`, `farmer_groups`, `farmer_group_members`, `commodities` (JSONB), `price_points`, `stocks` (`reserved_kg`, `sold_kg`), `decisions`, `warehouses`, `lots`, `lot_contributions`, `rental_requests`, `buyer_demands` (`terpenuhi_kg`), `sale_offers`, `impact_events`, `ai_logs`, dan `idempotency_keys`.

### 9.3 Matriks Transaksi Atomik Go (`SELECT ... FOR UPDATE`)

1. **`submitRentalTx`** (`warehouse/module.go`): Mengunci `stocks`/`lots` terlebih dahulu lalu `warehouses` (`consistent lock ordering`), menambah `stocks.reserved_kg`, dan membuat `rental_requests`.
2. **`respondRentalTx`** (`warehouse/module.go`): Mengunci `rental_requests`, `stocks`, dan `warehouses` untuk aksi `terima`, `tolak`, `selesai`, dan `batal` sesuai status sebelumnya.
3. **`submitSaleTx`** (`demand/module.go`): Mengunci `stocks`/`lots` lalu `buyer_demands`, menambah `stocks.reserved_kg`, dan membuat `sale_offers`.
4. **`respondSaleTx`** (`demand/module.go`): Memvalidasi pemilik `demand`/`seller`, memperbarui `terpenuhi_kg`, memindahkan `reserved_kg` ke `sold_kg` saat `selesai`, dan mencatat `impact_events`.

### 9.4 Keamanan Akses Server-Side (RBAC & Privasi)
- Setiap endpoint privat dilindungi `middleware.RequireAuth(secret, allowedRoles...)`.
- Nomor WhatsApp (`no_wa` / `kontak_wa`) disensor oleh `maskPhone()` hingga pengajuan berstatus `diterima` atau `selesai`.

---

## 10. Arsitektur dan Tumpukan Teknologi (Cross-Platform Modular Monolith)

| Lapisan | Pilihan | Alasan |
|---|---|---|
| Aplikasi Utama (Kategori Mobile) | **Flutter 3.47 (Dart 3.13) Material 3** | Satu kode untuk Android APK, Flutter Web, dan Desktop; disertai Mode Offline Mandiri & `--dart-define=API_BASE_URL` |
| Aplikasi Pendamping Web | **React.js 19 + TypeScript + Vite + Tailwind CSS** | Klien web ringan berpenampilan botani hijau-emas identik dengan versi Flutter |
| Backend Modular Monolith | **Go 1.26 + `net/http` + `log/slog`** | Terbagi ke 8 modul terisolasi (`auth`, `catalog`, `stock`, `lot`, `warehouse`, `demand`, `impact`, `ai`) dalam satu biner cepat |
| Database & Kontainer | **Podman PostgreSQL 17 (`compose.yaml`, port `5435`) + `pgx/v5`** | Query berparameter, `SELECT ... FOR UPDATE`, 20+ B-Tree Indexes, dan migrasi `up`/`down` |
| Keamanan, Cache & Ketahanan | **JWT `HS256` + RBAC + Token-Bucket Rate Limit + `Idempotency-Key` + `TTLCache`** | Bebas *double-booking* saat jaringan seluler desa putus-nyambung dan *write-through invalidation* |
| Peta, Grafik & Suara | **`flutter_map` (OpenStreetMap) + `CustomPainter` / SVG + `flutter_tts` (`id-ID`)** | Gratis tanpa API berbayar, aksesibel dengan `Aa+ Mode Lapangan` |
| AI Opsional Terkendali | **Gemini REST API (`8s timeout` + retry jitter) + `aiguard.go`** | Aman di server Go, bebas halusinasi angka berunit, jatuh mulus ke template |
| CI & Distribusi | **GitHub Actions (Go Test + Flutter Analyze/Test/APK + React Build)** | Pengujian dan artefak `.apk` terotomatisasi di ketiga lapisan |

### 10.1 Struktur folder monorepo

```text
sevent_x/
├── compose.yaml                  # Kontainer Podman postgres:17-alpine (port 5435) + profil API/Web
├── render.yaml                   # Blueprint deploy Cloud Backend Go + PostgreSQL
├── DESIGN.md                     # Spesifikasi palet, tipografi, & rasio kontras WCAG AA
├── AGENTS.md                     # Aturan antislop & Delivery Gate
├── backend/                      # Go Modular Monolith Backend
│   ├── cmd/api/main.go           # HTTP server (timeouts 3-lapis + graceful shutdown)
│   ├── cmd/dbtool/main.go        # Migrasi SQL up/down/reset & database seeder idempoten
│   ├── migrations/               # 001_init.up.sql & 001_init.down.sql (16 tabel + B-Tree Indexes)
│   └── internal/
│       ├── platform/             # config, db (pgxpool), cache (+test), httpx, middleware (+test), migrate
│       ├── modules/              # engine (+test & aiguard_test), auth, catalog, stock, lot, warehouse, demand, impact, ai
│       └── seed/seeder.go        # Seeder idempoten (5 akun demo, 64 minggu harga, gudang SRG, lot, Janji Beli)
├── mobile/                       # Aplikasi Utama Kategori Mobile (Flutter & Dart)
│   ├── lib/core/                 # engine.dart, models.dart, api_client.dart, app_state.dart, theme.dart
│   ├── lib/widgets/              # price_forecast_chart.dart, warehouse_map_card.dart, server_config_dialog.dart
│   ├── lib/screens/              # landing, auth, petani_shell, stock_decision, role_dashboards
│   └── test/widget_test.dart     # Pengujian unit fixture PRD 8.7 & skor gudang anti-NaN
├── web/                          # Aplikasi Pendamping Lintas-Platform (React.js + Vite + Tailwind + vercel.json)
└── docs/                         # PRD, Audit Spesifikasi, & Panduan Proposal/Deploy/Video
```

---

## 11-17. Ringkasan Aksesibilitas, Pengujian, & Kriteria Penilaian Lomba

1. **Aksesibilitas (`DESIGN.md` & `AGENTS.md`):** Target sentuh minimal `44x44 px`, kontras WCAG AA terukur (`>= 4.5:1` teks normal), dukungan penuh papan ketik (`Tab`, `Enter`, `Escape`), Mode Terang/Gelap + `Aa+`, serta baca suara `id-ID`.
2. **Pengujian Kualitas:** Mencakup `engine_test.go`, `aiguard_test.go`, `ttlcache_test.go`, `middleware_test.go` (Go), `widget_test.dart` & `flutter analyze` (Flutter), serta `tsc --noEmit && vite build` (React Web).
3. **Berkas Pengumpulan Kategori Mobile SEVENT X:**
   - File instalasi `app-release.apk` (`flutter build apk --release`).
   - Link repositori GitHub monorepo dan URL web demo pendamping (`vercel.json` + `render.yaml`).
   - Proposal karya (template resmi SEVENT X <= 25 halaman), Surat Orisinalitas (menyertakan pustaka & lisensi di `docs/Panduan_Proposal_Deploy_dan_Video_SEVENT_X.md`), dan Video YouTube (<= 5 menit).

---

## 18-22. Orisinalitas, Risiko, & Referensi

Pembeda SimpanJual terletak pada integrasi lima komponen hulu pra-SRG: (1) Konversi kadar air GKP->GKG masuk ke titik impas, (2) Panjar Tandingan (per-kg & borongan), (3) Lot Kolektif kode gabung `TANIJAYA`, (4) Skor kelayakan gudang deterministik anti-`NaN` + peta, serta (5) AI berpagar `aiguard.go`.

### Referensi Utama
- Bisnis.com (2023), *"Resi Gudang Minim Dimanfaatkan Petani, Bappebti Ungkap Sebabnya"*
- Bank Indonesia, *Kajian Peningkatan Pemanfaatan Sistem Resi Gudang (Kuningan dan Konawe Selatan)*
- Repositori UGM, *Disertasi Pemanfaatan SRG Gabah*
- Antara Jogja (Bantul), *AGRARIS Journal*, Viva (Wamendag), Pertanian.go.id (SRG Jagung)
- Katadata, Avinews, RCTI+, & Jurnal Jawa Tengah terkait pengadaan bahan baku lokal MBG/SPPG
- SEVENT X Software Development Ruleset (HMSE Telkom University Purwokerto)
