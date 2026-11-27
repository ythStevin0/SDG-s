import { useEffect, useState } from 'react';
import {
  BarChart3,
  Building2,
  CheckCircle2,
  LogOut,
  RefreshCw,
  ShieldCheck,
  Sprout,
  Users,
  Volume2,
} from 'lucide-react';
import { apiFetch, formatRp, getStoredToken, setStoredToken } from './api';

interface User {
  id: string;
  email: string;
  role: 'petani' | 'gudang' | 'pembeli' | 'admin';
  nama: string;
  kabupaten: string;
}

interface Commodity {
  id: string;
  kode: string;
  nama: string;
  params: Record<string, unknown>;
}

interface Stock {
  id: string;
  commodityKode: string;
  commodityNama: string;
  qtyKg: number;
  reservedKg: number;
  freeKg: number;
  kadarAir: number;
  tglPanen: string;
  kabupaten: string;
  status: string;
}

interface Warehouse {
  id: string;
  nama: string;
  kabupaten: string;
  kapasitasKg: number;
  tersediaKg: number;
  tarifPerKgHari: number;
  minVolumeKg: number;
  minHari: number;
  isSrg: boolean;
  score: { isEligible: boolean; totalScore: number; distanceKm: number; ineligibleReason?: string };
}

interface Demand {
  id: string;
  buyerNama: string;
  commodityKode: string;
  commodityNama: string;
  qtyKg: number;
  terpenuhiKg: number;
  sisaKuotaKg: number;
  progressPct: number;
  hargaAcuan: number;
  dibutuhkanPada: string;
  kabupaten: string;
}

export default function App() {
  const [user, setUser] = useState<User | null>(null);
  const [fieldMode, setFieldMode] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [impact, setImpact] = useState<Record<string, number> | null>(null);

  // Simulator state
  const [simKode, setSimKode] = useState('jagung');
  const [simQty, setSimQty] = useState(5000);
  const [simKa, setSimKa] = useState(18);
  const [simPanjar, setSimPanjar] = useState(3800);
  const [simResult, setSimResult] = useState<Record<string, any> | null>(null);

  // Role data
  const [stocks, setStocks] = useState<Stock[]>([]);
  const [selectedAnalysis, setSelectedAnalysis] = useState<Record<string, any> | null>(null);
  const [warehouses, setWarehouses] = useState<Warehouse[]>([]);
  const [demands, setDemands] = useState<Demand[]>([]);
  const [rentals, setRentals] = useState<Record<string, any>[]>([]);
  const [sales, setSales] = useState<Record<string, any>[]>([]);
  const [commodities, setCommodities] = useState<Commodity[]>([]);
  const [health, setHealth] = useState<Record<string, any> | null>(null);

  useEffect(() => {
    document.documentElement.classList.toggle('field-mode', fieldMode);
  }, [fieldMode]);

  useEffect(() => {
    apiFetch<{ tambahanPendapatanRp: number; stokTerserapKg: number; susutDicegahKg: number }>(
      '/api/v1/impact'
    )
      .then((d) => setImpact(d as unknown as Record<string, number>))
      .catch(() => {});

    if (getStoredToken()) {
      apiFetch<{ user: User }>('/api/v1/auth/me')
        .then((res) => setUser(res.user))
        .catch(() => setStoredToken(null));
    }
  }, []);

  useEffect(() => {
    if (user) void loadDashboard(user);
  }, [user]);

  async function runQuickSim() {
    try {
      const res = await apiFetch('/api/v1/simulator', {
        method: 'POST',
        body: JSON.stringify({
          commodityKode: simKode,
          qtyKg: simQty,
          kadarAirAktual: simKa,
          tarifSewaPerKgHari: 2.5,
          biayaAngkutPerKg: 20,
          biayaTetap: 100000,
          rasioPinjaman: 0.7,
          bungaTahunan: 0.06,
          hargaPanjarPerKg: simPanjar,
        }),
      });
      setSimResult(res);
    } catch (e: any) {
      setError(e.message);
    }
  }

  useEffect(() => {
    void runQuickSim();
  }, [simKode]);

  async function loginDemo(preset: string) {
    setError(null);
    try {
      const res = await apiFetch<{ token: string; user: User }>('/api/v1/auth/demo', {
        method: 'POST',
        body: JSON.stringify({ preset }),
      });
      setStoredToken(res.token);
      setUser(res.user);
      setSelectedAnalysis(null);
    } catch (e: any) {
      setError(e.message);
    }
  }

  async function loadDashboard(u: User) {
    setError(null);
    try {
      const comms = await apiFetch<{ commodities: Commodity[] }>('/api/v1/commodities');
      setCommodities(comms.commodities || []);

      if (u.role === 'petani') {
        const [st, wh, dm, rn, sl] = await Promise.all([
          apiFetch<{ stocks: Stock[] }>('/api/v1/stocks'),
          apiFetch<{ warehouses: Warehouse[] }>(`/api/v1/warehouses?commodity=jagung&kabupaten=${u.kabupaten}&qtyKg=5000`),
          apiFetch<{ demands: Demand[] }>('/api/v1/demands'),
          apiFetch<{ rentals: Record<string, any>[] }>('/api/v1/rentals'),
          apiFetch<{ sales: Record<string, any>[] }>('/api/v1/sales'),
        ]);
        setStocks(st.stocks || []);
        setWarehouses(wh.warehouses || []);
        setDemands(dm.demands || []);
        setRentals(rn.rentals || []);
        setSales(sl.sales || []);
      } else if (u.role === 'gudang') {
        const [wh, rn] = await Promise.all([
          apiFetch<{ warehouses: Warehouse[] }>('/api/v1/warehouses?mine=true'),
          apiFetch<{ rentals: Record<string, any>[] }>('/api/v1/rentals'),
        ]);
        setWarehouses(wh.warehouses || []);
        setRentals(rn.rentals || []);
      } else if (u.role === 'pembeli') {
        const [dm, sl] = await Promise.all([
          apiFetch<{ demands: Demand[] }>('/api/v1/demands?mine=true'),
          apiFetch<{ sales: Record<string, any>[] }>('/api/v1/sales'),
        ]);
        setDemands(dm.demands || []);
        setSales(sl.sales || []);
      } else if (u.role === 'admin') {
        const h = await apiFetch('/api/v1/health');
        setHealth(h);
      }
    } catch (e: any) {
      setError(e.message);
    }
  }

  function speakId(text: string) {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      const utt = new SpeechSynthesisUtterance(text);
      utt.lang = 'id-ID';
      window.speechSynthesis.speak(utt);
    }
  }

  async function inspectStock(stockId: string) {
    const res = await apiFetch(`/api/v1/stocks/${stockId}/analysis`);
    setSelectedAnalysis(res);
  }

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="sticky top-0 z-20 border-b border-slate-200 bg-white/95 backdrop-blur">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
          <div className="flex items-center gap-2">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-700 text-white">
              <Sprout className="h-5 w-5" />
            </div>
            <div>
              <div className="font-extrabold text-slate-900">SimpanJual Web</div>
              <div className="text-xs text-slate-500">
                Cross-Platform React.js + Flutter · Go Modular Monolith
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setFieldMode(!fieldMode)}
              className={`rounded-lg border px-3 py-1.5 text-xs font-bold ${
                fieldMode
                  ? 'border-amber-500 bg-amber-100 text-amber-950'
                  : 'border-slate-300 bg-white text-slate-700'
              }`}
            >
              Aa+ Mode Lapangan
            </button>

            {user && (
              <>
                <button
                  onClick={() => loadDashboard(user)}
                  className="rounded-lg border border-slate-300 p-2 text-slate-700 hover:bg-slate-100"
                  title="Muat Ulang"
                >
                  <RefreshCw className="h-4 w-4" />
                </button>
                <button
                  onClick={() => {
                    setStoredToken(null);
                    setUser(null);
                  }}
                  className="inline-flex items-center gap-1 rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-bold text-white"
                >
                  <LogOut className="h-3.5 w-3.5" />
                  <span>Ganti Peran ({user.nama})</span>
                </button>
              </>
            )}
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-6xl space-y-6 px-4 py-6">
        {error && (
          <div className="rounded-xl border border-rose-300 bg-rose-50 p-3 text-sm font-medium text-rose-900">
            {error}
          </div>
        )}

        {/* Quick 1-Click Role Switcher Always Accessible for Judges */}
        <section className="rounded-2xl border border-emerald-200 bg-emerald-50/70 p-4">
          <div className="mb-2 text-xs font-extrabold uppercase tracking-wider text-emerald-900">
            1-Click Demo Login Lintas Peran (Terhubung ke Go Modular Monolith + PostgreSQL Podman)
          </div>
          <div className="flex flex-wrap gap-2">
            {[
              { id: 'petani', label: 'Pak Slamet (Petani)' },
              { id: 'poktan', label: 'Bu Rini (Ketua Poktan)' },
              { id: 'gudang', label: 'Pak Joko (Gudang SRG)' },
              { id: 'pembeli', label: 'Koperasi & SPPG (Pembeli)' },
              { id: 'admin', label: 'Admin Scalability' },
            ].map((p) => (
              <button
                key={p.id}
                onClick={() => loginDemo(p.id)}
                className="rounded-xl border border-emerald-300 bg-white px-3.5 py-2 text-xs font-bold text-emerald-950 shadow-sm hover:bg-emerald-700 hover:text-white"
              >
                {p.label}
              </button>
            ))}
          </div>
        </section>

        {!user ? (
          <>
            <section className="rounded-2xl bg-gradient-to-br from-emerald-900 via-emerald-800 to-teal-900 p-6 text-white shadow-sm sm:p-8">
              <span className="inline-block rounded-full bg-white/15 px-3 py-1 text-xs font-bold">
                SEVENT X · SDG 8 — Decent Work & Economic Growth
              </span>
              <h1 className="mt-3 text-2xl font-extrabold sm:text-4xl">
                Jangan Jual Rugi Saat Panen Raya. Hitung Titik Impas, Simpan Kolektif, & Pastikan Pembeli.
              </h1>
              <p className="mt-2 max-w-3xl text-sm text-emerald-100 sm:text-base">
                Arsitektur <strong>Cross-Platform Modular Monolith</strong>: Aplikasi Mobile{' '}
                <strong>Flutter (Dart)</strong> untuk petani di lapangan dan aplikasi Web{' '}
                <strong>React.js</strong> yang berbagi satu backend <strong>Go + PostgreSQL 17 (Podman)</strong>.
              </p>
            </section>

            {impact && (
              <section className="grid gap-4 sm:grid-cols-3">
                <div className="rounded-xl border border-slate-200 bg-white p-4">
                  <div className="text-xs text-slate-500">Tambahan Pendapatan Petani</div>
                  <div className="text-xl font-black text-emerald-700">
                    {formatRp(impact.tambahanPendapatanRp || 0)}
                  </div>
                </div>
                <div className="rounded-xl border border-slate-200 bg-white p-4">
                  <div className="text-xs text-slate-500">Stok Terserap Pembeli Siaga</div>
                  <div className="text-xl font-black text-blue-700">
                    {(impact.stokTerserapKg || 0).toLocaleString('id-ID')} kg
                  </div>
                </div>
                <div className="rounded-xl border border-slate-200 bg-white p-4">
                  <div className="text-xs text-slate-500">Estimasi Susut Pascapanen Dicegah</div>
                  <div className="text-xl font-black text-amber-700">
                    {(impact.susutDicegahKg || 0).toLocaleString('id-ID')} kg
                  </div>
                </div>
              </section>
            )}

            <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {[
                { icon: BarChart3, title: 'Konversi Kadar Air & S-SRG 6%', desc: 'Hitung susut pengeringan GKP→GKG & titik impas Math.ceil.' },
                { icon: ShieldCheck, title: 'Panjar Tandingan', desc: 'Bandingkan tebasan tengkulak terhadap plafon pembiayaan resi gudang.' },
                { icon: Users, title: 'Lot Kolektif Poktan', desc: 'Gabung kode TANIJAYA agar stok kecil menembus syarat minimal SRG.' },
                { icon: Building2, title: 'Transaksi Atomik FOR UPDATE', desc: 'Bebas race-condition pada kapasitas gudang dan kuota Janji Beli.' },
              ].map((it) => {
                const Icon = it.icon;
                return (
                  <div key={it.title} className="rounded-xl border border-slate-200 bg-white p-4">
                    <Icon className="mb-2 h-6 w-6 text-emerald-700" />
                    <div className="font-bold">{it.title}</div>
                    <p className="mt-1 text-xs text-slate-600">{it.desc}</p>
                  </div>
                );
              })}
            </section>

            {/* Quick Simulator */}
            <section className="rounded-2xl border border-slate-200 bg-white p-6">
              <h2 className="text-lg font-extrabold">Simulator Cepat Tahan vs Panjar (Tanpa Login)</h2>
              <div className="mt-4 grid gap-4 sm:grid-cols-4">
                <label className="text-xs font-semibold">
                  Komoditas
                  <select
                    value={simKode}
                    onChange={(e) => setSimKode(e.target.value)}
                    className="mt-1 w-full rounded-lg border border-slate-300 p-2 text-sm"
                  >
                    <option value="jagung">Jagung Pipil</option>
                    <option value="gabah">Gabah GKG</option>
                  </select>
                </label>
                <label className="text-xs font-semibold">
                  Volume Panen (kg)
                  <input
                    type="number"
                    value={simQty}
                    onChange={(e) => setSimQty(Number(e.target.value))}
                    className="mt-1 w-full rounded-lg border border-slate-300 p-2 text-sm"
                  />
                </label>
                <label className="text-xs font-semibold">
                  Kadar Air Aktual (%)
                  <input
                    type="number"
                    value={simKa}
                    onChange={(e) => setSimKa(Number(e.target.value))}
                    className="mt-1 w-full rounded-lg border border-slate-300 p-2 text-sm"
                  />
                </label>
                <label className="text-xs font-semibold">
                  Panjar Tengkulak (Rp/kg)
                  <div className="mt-1 flex gap-2">
                    <input
                      type="number"
                      value={simPanjar}
                      onChange={(e) => setSimPanjar(Number(e.target.value))}
                      className="w-full rounded-lg border border-slate-300 p-2 text-sm"
                    />
                    <button
                      onClick={runQuickSim}
                      className="rounded-lg bg-emerald-700 px-4 py-2 text-xs font-bold text-white"
                    >
                      Hitung
                    </button>
                  </div>
                </label>
              </div>

              {simResult?.decision && (
                <div className="mt-4 rounded-xl border border-emerald-200 bg-emerald-50 p-4">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="text-base font-black text-emerald-950">
                      REKOMENDASI: {simResult.decision.recommendation} ({simResult.decision.bestHorizonWeeks} Minggu)
                    </div>
                    <button
                      onClick={() => speakId(simResult.decision.summarySentence)}
                      className="inline-flex items-center gap-1 rounded-lg bg-emerald-800 px-3 py-1.5 text-xs font-bold text-white"
                    >
                      <Volume2 className="h-3.5 w-3.5" /> Bacakan
                    </button>
                  </div>
                  <p className="mt-1 text-sm font-semibold text-emerald-900">
                    Selisih vs Jual Segera: {formatRp(simResult.decision.best.selisihRp, true)} · Titik Impas:{' '}
                    {formatRp(simResult.decision.best.titikImpasPerKg)}/kg
                  </p>
                  {simResult.panjar && (
                    <p className="mt-1 text-xs font-bold text-amber-900">
                      Panjar Tandingan: Menahan stok menyelamatkan{' '}
                      {formatRp(simResult.panjar.selisihTerhadapTahanRp, true)} dibanding tawaran panjar tengkulak!
                    </p>
                  )}
                </div>
              )}
            </section>
          </>
        ) : user.role === 'petani' ? (
          <div className="space-y-6">
            <section className="rounded-2xl border border-slate-200 bg-white p-5">
              <h2 className="text-lg font-extrabold">Stok Panen — {user.nama}</h2>
              <div className="mt-3 grid gap-4 sm:grid-cols-2">
                {stocks.map((s) => (
                  <div key={s.id} className="rounded-xl border border-slate-200 p-4">
                    <div className="flex justify-between">
                      <div className="font-bold">{s.commodityNama}</div>
                      <span className="rounded-full bg-emerald-100 px-2.5 py-0.5 text-xs font-bold text-emerald-900">
                        {s.status}
                      </span>
                    </div>
                    <div className="mt-1 text-xs text-slate-500">
                      Total {s.qtyKg.toLocaleString('id-ID')} kg · Bebas{' '}
                      <strong className="text-emerald-700">{s.freeKg.toLocaleString('id-ID')} kg</strong> · KA{' '}
                      {s.kadarAir}%
                    </div>
                    <button
                      onClick={() => inspectStock(s.id)}
                      className="mt-3 w-full rounded-lg bg-emerald-700 py-2 text-xs font-bold text-white"
                    >
                      Lihat Analisis Keputusan & Kesiapan Mutu
                    </button>
                  </div>
                ))}
              </div>

              {selectedAnalysis && (
                <div className="mt-4 rounded-xl border border-teal-300 bg-teal-50 p-4">
                  <div className="flex items-center justify-between">
                    <div className="font-black text-teal-950">
                      Hasil Mesin Keputusan ({selectedAnalysis.stock.commodityNama}):{' '}
                      {selectedAnalysis.decision.recommendation} ({selectedAnalysis.decision.bestHorizonWeeks} Minggu)
                    </div>
                    <button
                      onClick={() => speakId(selectedAnalysis.decision.summarySentence)}
                      className="inline-flex items-center gap-1 rounded-lg bg-teal-800 px-3 py-1 text-xs font-bold text-white"
                    >
                      <Volume2 className="h-3.5 w-3.5" /> Suara
                    </button>
                  </div>
                  <div className="mt-1 text-sm">
                    {selectedAnalysis.decision.summarySentence} · Bobot Kering Siap Simpan:{' '}
                    <strong>{selectedAnalysis.decision.qtySiap} kg</strong> · Kesiapan:{' '}
                    <strong>{selectedAnalysis.readiness.status}</strong> (MAPE {selectedAnalysis.forecast.mapePct}%)
                  </div>
                </div>
              )}
            </section>

            <section className="grid gap-6 lg:grid-cols-2">
              <div className="rounded-2xl border border-slate-200 bg-white p-5">
                <h3 className="font-extrabold">Gudang Berskor Anti-NaN (F8 & F9)</h3>
                <div className="mt-3 space-y-3">
                  {warehouses.map((w) => (
                    <div key={w.id} className="rounded-xl border border-slate-200 p-3">
                      <div className="flex justify-between">
                        <span className="font-bold text-sm">{w.nama}</span>
                        <span className="rounded bg-emerald-700 px-2 py-0.5 text-xs font-bold text-white">
                          Skor {w.score.totalScore}/100
                        </span>
                      </div>
                      <div className="mt-1 text-xs text-slate-600">
                        {w.kabupaten} (~{w.score.distanceKm} km) · Tersedia {w.tersediaKg.toLocaleString('id-ID')} kg ·
                        Rp{w.tarifPerKgHari}/kg/hr
                      </div>
                      {w.score.isEligible && stocks.some((s) => s.freeKg >= w.minVolumeKg) && (
                        <button
                          onClick={async () => {
                            const st = stocks.find((s) => s.freeKg >= w.minVolumeKg)!;
                            await apiFetch('/api/v1/rentals', {
                              method: 'POST',
                              idempotent: true,
                              body: JSON.stringify({
                                stockId: st.id,
                                warehouseId: w.id,
                                qtyKg: w.minVolumeKg,
                                hari: w.minHari,
                              }),
                            });
                            await loadDashboard(user);
                          }}
                          className="mt-2 rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-bold text-white"
                        >
                          Ajukan Sewa Atomik ({w.minVolumeKg.toLocaleString('id-ID')} kg)
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              <div className="rounded-2xl border border-slate-200 bg-white p-5">
                <h3 className="font-extrabold">Bursa Janji Beli Pembeli Siaga (F10 & F11)</h3>
                <div className="mt-3 space-y-3">
                  {demands.map((d) => (
                    <div key={d.id} className="rounded-xl border border-slate-200 p-3">
                      <div className="flex justify-between">
                        <span className="font-bold text-sm">
                          {d.commodityNama} — {d.buyerNama}
                        </span>
                        <span className="font-extrabold text-amber-800 text-xs">
                          {formatRp(d.hargaAcuan)}/kg
                        </span>
                      </div>
                      <div className="mt-1 text-xs text-slate-600">
                        Sisa kuota {d.sisaKuotaKg.toLocaleString('id-ID')} kg · Dibutuhkan {d.dibutuhkanPada}
                      </div>
                      {stocks.some((s) => s.freeKg > 0 && s.commodityKode === d.commodityKode) && (
                        <button
                          onClick={async () => {
                            const st = stocks.find((s) => s.freeKg > 0 && s.commodityKode === d.commodityKode)!;
                            await apiFetch('/api/v1/sales', {
                              method: 'POST',
                              idempotent: true,
                              body: JSON.stringify({
                                stockId: st.id,
                                demandId: d.id,
                                qtyKg: Math.min(st.freeKg, d.sisaKuotaKg),
                                hargaTawar: d.hargaAcuan,
                              }),
                            });
                            await loadDashboard(user);
                          }}
                          className="mt-2 rounded-lg bg-emerald-700 px-3 py-1.5 text-xs font-bold text-white"
                        >
                          Ajukan Jual Atomik
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </section>
          </div>
        ) : user.role === 'gudang' ? (
          <section className="rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
            <h2 className="text-lg font-extrabold">Dashboard Pengelola Gudang — Permintaan Sewa Masuk</h2>
            {rentals.length === 0 && <p className="text-sm text-slate-500">Belum ada permintaan sewa.</p>}
            {rentals.map((r) => (
              <div key={r.id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border p-3">
                <div className="text-sm">
                  <strong>{r.requesterNama}</strong> → {r.warehouseNama} ({r.qtyKg} kg · {r.hari} hr) · Status:{' '}
                  <strong>{r.status}</strong>
                </div>
                <div className="flex gap-2">
                  {r.status === 'diajukan' && (
                    <button
                      onClick={async () => {
                        await apiFetch(`/api/v1/rentals/${r.id}/respond`, {
                          method: 'POST',
                          body: JSON.stringify({ action: 'terima' }),
                        });
                        await loadDashboard(user);
                      }}
                      className="rounded-lg bg-emerald-700 px-3 py-1.5 text-xs font-bold text-white"
                    >
                      Terima Atomik
                    </button>
                  )}
                  {r.status === 'diterima' && (
                    <button
                      onClick={async () => {
                        await apiFetch(`/api/v1/rentals/${r.id}/respond`, {
                          method: 'POST',
                          body: JSON.stringify({ action: 'selesai' }),
                        });
                        await loadDashboard(user);
                      }}
                      className="rounded-lg bg-blue-700 px-3 py-1.5 text-xs font-bold text-white"
                    >
                      Selesai
                    </button>
                  )}
                </div>
              </div>
            ))}
          </section>
        ) : user.role === 'pembeli' ? (
          <section className="rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
            <h2 className="text-lg font-extrabold">Dashboard Pembeli — Penawaran Masuk</h2>
            {sales.length === 0 && <p className="text-sm text-slate-500">Belum ada penawaran jual masuk.</p>}
            {sales.map((s) => (
              <div key={s.id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl border p-3">
                <div className="text-sm">
                  <strong>{s.sellerNama}</strong> — {s.commodityNama} ({s.qtyKg} kg @ {formatRp(s.hargaTawar)}/kg) ·{' '}
                  <strong>{s.status}</strong>
                </div>
                <div className="flex gap-2">
                  {s.status === 'diajukan' && (
                    <button
                      onClick={async () => {
                        await apiFetch(`/api/v1/sales/${s.id}/respond`, {
                          method: 'POST',
                          body: JSON.stringify({ action: 'terima' }),
                        });
                        await loadDashboard(user);
                      }}
                      className="rounded-lg bg-emerald-700 px-3 py-1.5 text-xs font-bold text-white"
                    >
                      Terima Penawaran
                    </button>
                  )}
                  {s.status === 'diterima' && (
                    <button
                      onClick={async () => {
                        await apiFetch(`/api/v1/sales/${s.id}/respond`, {
                          method: 'POST',
                          body: JSON.stringify({ action: 'selesai' }),
                        });
                        await loadDashboard(user);
                      }}
                      className="rounded-lg bg-blue-700 px-3 py-1.5 text-xs font-bold text-white"
                    >
                      Tandai Selesai
                    </button>
                  )}
                </div>
              </div>
            ))}
          </section>
        ) : (
          <section className="rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
            <div className="flex items-center gap-2 text-emerald-800 font-bold">
              <CheckCircle2 className="h-5 w-5" />
              <span>Admin Observability & Konfigurasi Komoditas JSONB</span>
            </div>
            {health && (
              <pre className="overflow-x-auto rounded-xl bg-slate-900 p-4 text-xs text-emerald-300">
                {JSON.stringify(health, null, 2)}
              </pre>
            )}
            <div className="grid gap-4 sm:grid-cols-2">
              {commodities.map((c) => (
                <div key={c.id} className="rounded-xl border p-4">
                  <div className="font-bold">
                    {c.nama} ({c.kode})
                  </div>
                  <pre className="mt-2 overflow-x-auto rounded-lg bg-slate-950 p-3 text-xs text-teal-300">
                    {JSON.stringify(c.params, null, 2)}
                  </pre>
                </div>
              ))}
            </div>
          </section>
        )}
      </main>
    </div>
  );
}
