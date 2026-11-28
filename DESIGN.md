# DESIGN.md: Arah Visual SimpanJual (Tema Rimbun Panen & Lumbung)

Dokumen ini menetapkan identitas visual, sistem warna teruji kontras WCAG AA, tipografi, motif arsitektural, dan tata letak lintas perangkat (`mobile/` Flutter & `web/` React.js) berdasarkan foto referensi visual dan keputusan aset pemilik produk.

Membaca antarmuka ini sebagai: panggung keputusan pascapanen dan ruang kerja koperasi bagi petani padi/jagung, kelompok tani, pengelola gudang SRG, serta pembeli siaga daerah, dalam bahasa visual editorial botani hijau-emas Nusantara, dial `ENERGY 3 / RHYTHM 3 / MOTION 1`.

Dial: `ENERGY 3 / RHYTHM 3 / MOTION 1`

## 1. Karakter Visual & Motif Identitas Utama
SimpanJual mengadaptasi tata panggung editorial botani hijau-emas ke dalam konteks pascapanen Nusantara (padi gabah, jagung pipil, dan lumbung SRG):

1. **Panggung Daun & Lengkungan Sudut Kiri Atas (*Asymmetric Top-Left Arch*)**: Bidang pameran hasil panen memakai panel hijau pucuk pucat (`#CEDFB5`) dan kartu hasil bumi berwarna emas panen (`#E5AF42`) dengan lengkungan khas hanya pada sudut kiri atas (`border-top-left-radius: 88px` pada hero desktop, `52px` pada hero ponsel, `36px` pada kartu panen bawah, dan `22px` pada kartu kerja), menciptakan siluet arsitektural yang langsung dikenali.
2. **Navigasi Pita Atas Berpenanda Emas + Blok Sudut Kanan**: Header panggung memakai penanda garis emas horizontal di tepi paling atas pada menu aktif, pemisah titik (`•`) antar menu yang benar-benar ada di halaman, kapsul aksi berwarna emas (`#E5AF42`), serta blok persegi hijau hutan (`#284D38`) di sudut kanan atas untuk laci navigasi cepat.
3. **Tombol Kapsul Belah Lingkaran Panah Emas (*Split Gold-Circle CTA*)**: Aksi utama ditampilkan sebagai kapsul berbingkai emas (`1.5px solid #E5AF42`) berisi teks putih di sisi kiri dan lingkaran emas penuh (`#E5AF42`) berisi panah hijau gelap (`#193226`) hanya pada CTA penggerak alur utama.
4. **Logo & Ikon Aplikasi "Atap Lumbung & Jarum Timbangan"**: Simbol siluet atap gudang yang menyatu dengan jarum timbangan koperasi dan bulir panen emas sebagai titik tumpu keseimbangan, disandingkan dengan susunan teks dua baris `Simpan` / `Jual`. Untuk ikon aplikasi (`ic_launcher.png` & `favicon.svg`), digunakan latar krem beras (`#FAF7F0`) dengan simbol hijau padi tua (`#163A2A`) dan bulir gabah matang (`#9A4206`).

## 2. Palet Warna Terbatas & Rasio Kontras Terukur (R-25, R-29)
Seluruh pasangan warna diuji menggunakan `.agents/skills/antislop-human/contrast-check.py` (minimal `4.5:1` teks normal, `3.0:1` teks besar dan batas komponen non-teks):

| Peran | Hex | Pasangan Teks / Latar | Rasio Terukur | Status WCAG AA |
|---|---|---|---|---|
| Hutan Gelap Dasar (`frameBg`) | `#193226` | Teks `#F3F7F0` di atas `#193226` | `12.70:1` | Lulus |
| Teks Sekunder Pita Bawah | `#C2D6C4` | Teks `#C2D6C4` di atas `#193226` | `8.99:1` | Lulus |
| Hutan Kiri Panggung (`stageLeft`) | `#183D31` | Judul `#FFFFFF` di atas `#183D31` | `12.00:1` | Lulus |
| Hutan Tengah Teks (`stageMid`) | `#265340` | Subjudul `#EAF4EC` di titik paling terang area teks | `7.79:1` | Lulus |
| Blok Menu Kanan Atas | `#284D38` | Ikon `#FFFFFF` di atas `#284D38` | `9.51:1` | Lulus |
| Emas Menu Aktif (`goldTextOnDark`) | `#F4C95D` | Teks `#F4C95D` di atas `#183D31` | `7.63:1` | Lulus |
| Aksen Emas Panen (`harvestGold`) | `#E5AF42` | Teks `#193226` di atas `#E5AF42` | `6.91:1` | Lulus |
| Lengkungan Pucuk Padi (`archSage`) | `#CEDFB5` | Titik/teks `#193226` di atas `#CEDFB5` | `9.73:1` | Lulus |
| Panel Aksi Daun (`sagePanel`) | `#84AE6B` | Kontrol `#193226` di atas `#84AE6B` | `5.41:1` | Lulus |
| Dasar Mode Terang (`bg`) | `#F3F7F0` | Tinta `#162A20` di atas `#F3F7F0` | `13.98:1` | Lulus |
| Teks Sekunder Kartu Terang | `#395244` | Teks `#395244` di atas `#FFFFFF` | `8.52:1` | Lulus |
| Garis Kartu Mode Terang | `#647D6D` | Garis `#647D6D` di atas `#F3F7F0` | `4.13:1` | Lulus (> 3:1 UI) |
| Dasar Mode Gelap (`darkBg`) | `#13261D` | Teks `#EDF5EE` di atas `#13261D` | `14.29:1` | Lulus |
| Permukaan Kartu Gelap (`darkCard`) | `#1B3529` | Teks `#B9CFC0` di atas `#1B3529` | `8.03:1` | Lulus |
| Garis Kartu Mode Gelap | `#6E917D` | Garis `#6E917D` di atas `#1B3529` | `3.78:1` | Lulus (> 3:1 UI) |
| Ikon Aplikasi Latar Krem | `#FAF7F0` | Simbol `#163A2A` (`11.73:1`) & bulir `#9A4206` (`6.22:1`) | `11.73:1` | Lulus |

## 3. Tipografi & Hierarki (R-06)
- **Rumpun Huruf Sistem Manusiawi (`Segoe UI`, `Plus Jakarta Sans`, `Roboto`, `system-ui`)**: Dipilih agar memuat instan tanpa pemblokiran jaringan di daerah pedesaan dengan keterbacaan angka dan huruf Latin Indonesia yang jernih.
- **Tajuk Panggung Utama (*Display Headline*)**: Huruf tebal padat (berat `900`, tinggi baris `0.95`) untuk komoditas/keputusan utama (`PANEN RAYA`, `PADI GABAH`, `LUMBUNG SRG`), didampingi keterangan konteks singkat tanpa kapsul hiasan di atas `h1`.
- **Angka & Rekap Hitungan**: Menggunakan `font-variant-numeric: tabular-nums` (`FontFeature.tabularFigures()`) pada seluruh angka Rupiah, kilogram, kadar air, dan skor gudang agar satuan sejajar lurus saat dibandingkan.

## 4. Reflow 3 Rentang Lebar Layar (R-03 & antislop-layoutmobile)
1. **Ponsel (`< 640px`)**: Tajuk panggung dengan ukuran huruf `clamp()` proporsional ditumpuk di atas panel lengkung `#CEDFB5`, diikuti pita rekap bawah satu kolom, target sentuh minimal `48x48 px` berjarak aman, dan bilah navigasi bawah dengan ruang gulir aman (`108px`).
2. **Tablet (`640px - 1023px`)**: Hero dua kolom seimbang, navigasi rel samping (`NavigationRail` / bilah ringkas), dan grid isi 2 kolom agar kartu tidak melebar berlebihan.
3. **Desktop / Web Lebar (`>= 1024px`)**: Panggung penuh dari tepi ke tepi (*full-bleed* tanpa margin/padding bingkai luar) dengan navigasi pita atas, komposisi hero asimetris (`55%` tipografi : `45%` lengkungan pucuk padi `#CEDFB5` + pemilih panggung vertikal di tepi kanan), pita bawah 4 bagian, serta bilah samping dasbor yang dapat diciutkan (`collapse`).

## 5. Alasan Tertulis Satu Baris per Keputusan Utama (R-31 & Purpose-Gate)
- **Gradasi daun terarah (`#183D31` -> `#265340` -> `#7BA866`, R-01)**: Memisahkan hierarki panggung utama dari lembar kerja kalkulator sembari menjaga kontras teks putih di sisi kiri minimal `7.79:1`.
- **Lengkungan asimetris sudut kiri atas (`#CEDFB5` & `#E5AF42`, R-11, R-20)**: Menjadi motif arsitektural berulang milik SimpanJual sesuai referensi visual pemilik, sementara input formulir tetap bersudut tegas `8px` agar mudah dikenali sebagai bidang ketik.
- **Aksen emas panen `#E5AF42` terbatas pada titik keputusan (R-29)**: Mengarahkan mata langsung ke CTA utama, penanda menu aktif, dan kapsul masuk akun demo tanpa membanjiri seluruh halaman.
- **Panah dalam lingkaran emas hanya pada tombol penggerak alur utama (`SplitGoldCtaButton`, R-08)**: Memberi isyarat perpindahan nyata menuju kalkulator atau ruang kerja akun, bukan hiasan di setiap tombol sekunder.
- **Lencana cap persegi asimetris (`StampBadge`, R-09)**: Menandai status fungsional nyata (`TAHAN`, `TAHAN BERISIKO`, `JUAL SEKARANG`, `SRG`, `LAYAK`) dengan teks + ikon tanpa efek pendar (`glow`).
- **Tanpa kaca buram, pendar, atau bayangan mengambang (`R-10, R-12, R-13`)**: Hirarki permukaan dibangun melalui batas garis tegas (`>= 3.78:1`) dan perbedaan bidang warna solid agar tetap tajam di layar ponsel kelas entri di bawah terik matahari.
- **Variasi hierarki peran pascapanen (`R-14, R-05`)**: Peran utama Petani Padi & Jagung ditampilkan sebagai panel unggulan lebar penuh dengan tombol coba langsung, sedangkan tiga peran pendukung ekosistem disusun dalam baris terpisah di bawahnya.
- **Gerak tenang sesuai `MOTION 1` (`R-19`)**: Hanya umpan balik `:hover`, `:active`, `:focus-visible`, dan gulir halus yang menghormati `prefers-reduced-motion: reduce`, tanpa animasi berulang tanpa henti.
- **Ilustrasi botani khusus hasil bumi Nusantara (`hero_harvest.jpg` & `crop_cluster.jpg`, R-22)**: Menampilkan rumpun jagung emas dan malai padi gabah yang langsung mencerminkan komoditas inti yang dihitung oleh mesin SimpanJual.
- **Ikon SVG fungsional buatan khusus (`R-04`)**: Menggunakan siluet atap lumbung-timbangan dan ikon garis fungsional spesifik konteks tanpa mengimpor paket ikon generik berseragam tipis atau emoji dekoratif.
- **Mode Kertas Daun Terang & Mode Rimbun Gelap + `Aa+` (`R-21, R-34`)**: Keduanya berfungsi penuh agar nyaman dibaca baik di bawah sinar matahari sawah maupun di dalam gudang penyimpanan yang teduh.
