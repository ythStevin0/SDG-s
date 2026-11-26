import Link from 'next/link';
import { ArrowRight, BarChart3, Building2, ShieldCheck, Users } from 'lucide-react';
import { QuickSimulator } from '@/components/QuickSimulator';

export default function HomePage() {
  return (
    <div className="space-y-8">
      <section className="field-card rounded-2xl border border-emerald-200 bg-gradient-to-br from-emerald-900 via-emerald-800 to-teal-900 p-6 text-white shadow-sm sm:p-8">
        <div className="max-w-3xl space-y-4">
          <div className="inline-flex items-center gap-2 rounded-full bg-white/15 px-3 py-1 text-xs font-semibold">
            <span>SEVENT X Software Development · Subtema SDG 8</span>
          </div>
          <h1 className="text-3xl font-extrabold leading-tight sm:text-4xl">
            Jangan Jual Rugi Saat Panen Raya. Hitung Titik Impas, Simpan Kolektif, dan Pastikan Pembeli.
          </h1>
          <p className="text-base text-emerald-100 sm:text-lg">
            <strong>SimpanJual</strong> menyatukan petani, pengelola gudang SRG, dan pembeli lokal
            agar petani kecil terhindar dari panjar tengkulak berpotongan hingga separuh harga pasar.
          </p>
          <div className="flex flex-wrap gap-3 pt-1">
            <Link
              href="/masuk"
              className="inline-flex min-h-[48px] items-center gap-2 rounded-xl bg-amber-400 px-5 py-3 text-base font-bold text-slate-950 hover:bg-amber-300"
            >
              <span>Coba Akun Demo 1-Klik</span>
              <ArrowRight className="h-5 w-5" />
            </Link>
            <Link
              href="#simulator"
              className="inline-flex min-h-[48px] items-center rounded-xl border border-white/40 px-5 py-3 text-base font-semibold text-white hover:bg-white/10"
            >
              Hitung Simulasi Tanpa Login
            </Link>
          </div>
        </div>
      </section>

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {[
          {
            icon: BarChart3,
            title: 'Keputusan Jujur + Kadar Air',
            desc: 'Menghitung susut pengeringan, ongkos gudang, bunga S-SRG 6%, dan titik impas Rp/kg.',
          },
          {
            icon: ShieldCheck,
            title: 'Panjar Tandingan',
            desc: 'Menunjukkan rupiah pasti yang hilang dari tawaran panjar maupun tebasan tengkulak.',
          },
          {
            icon: Users,
            title: 'Lot Kolektif Poktan',
            desc: 'Gabungkan stok kecil anggota via kode gabung untuk menembus batas volume gudang SRG.',
          },
          {
            icon: Building2,
            title: 'Gudang Kosong & Pembeli Siaga',
            desc: 'Peta skor gudang anti-NaN & bursa Janji Beli (koperasi, pabrik pakan, dapur SPPG).',
          },
        ].map((item) => {
          const Icon = item.icon;
          return (
            <div
              key={item.title}
              className="field-card rounded-xl border border-slate-200 bg-white p-4 shadow-sm"
            >
              <div className="mb-2 flex h-10 w-10 items-center justify-center rounded-lg bg-emerald-100 text-emerald-800">
                <Icon className="h-5 w-5" />
              </div>
              <h3 className="font-bold text-slate-900">{item.title}</h3>
              <p className="field-muted mt-1 text-sm text-slate-600">{item.desc}</p>
            </div>
          );
        })}
      </section>

      <div id="simulator">
        <QuickSimulator />
      </div>

      <footer className="field-card rounded-xl border border-slate-200 bg-white p-4 text-xs text-slate-600">
        <strong>Transparansi Data & Metodologi:</strong> Seluruh angka contoh gudang, pembeli, dan
        historis harga ilustratif pada MVP ditandai <em>Data Ilustrasi</em>. Prediksi harga memakai
        metode statistik transparan (WMA-4, Holt Damped, Seasonal-MA) dengan evaluasi backtest MAPE;
        bukan jaminan harga pasar masa depan.
      </footer>
    </div>
  );
}
