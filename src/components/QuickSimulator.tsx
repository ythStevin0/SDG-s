'use client';

import { useMemo, useState } from 'react';
import { evaluateHoldVsSell } from '@/lib/engine/decision';
import { evaluatePanjarTandingan } from '@/lib/engine/panjar';
import { SpeechButton } from '@/components/SpeechButton';

export function QuickSimulator() {
  const [qtyKg, setQtyKg] = useState(5000);
  const [kadarAir, setKadarAir] = useState(18);
  const [p0Dry, setP0Dry] = useState(5000);
  const [p8Pred, setP8Pred] = useState(5800);
  const [panjarPerKg, setPanjarPerKg] = useState(3500);
  const [pakaiSsrg, setPakaiSsrg] = useState(true);

  const result = useMemo(() => {
    const safeQty = Math.max(100, qtyKg);
    const safeP0 = Math.max(1000, p0Dry);
    const safeP8 = Math.max(1000, p8Pred);
    const decision = evaluateHoldVsSell({
      qtyKg: safeQty,
      kadarAirAktual: Math.min(40, Math.max(8, kadarAir)),
      kadarAirAmbang: 15,
      biayaPengeringanPerKg: 150,
      p0Dry: safeP0,
      predictions: [
        {
          horizonWeeks: 8,
          pricePoint: safeP8,
          priceLow: Math.round(safeP8 * 0.91),
          priceHigh: Math.round(safeP8 * 1.09),
        },
      ],
      tarifSewaPerKgHari: 3,
      biayaAngkutPerKg: 20,
      biayaTetap: 150000,
      susutPerBulan: 0.005,
      rasioPinjaman: pakaiSsrg ? 0.7 : 0,
      bungaTahunan: 0.06,
    });

    const panjar = evaluatePanjarTandingan({
      mode: 'per_kg',
      hargaPanjarPerKg: Math.max(500, panjarPerKg),
      qtyKg: safeQty,
      p0Actual: safeP0,
      pendapatanTahanRp: decision.best.pendapatanTahan,
      pinjamanSrgRp: decision.pinjamanAwal,
    });

    return { decision, panjar };
  }, [qtyKg, kadarAir, p0Dry, p8Pred, panjarPerKg, pakaiSsrg]);

  const { decision, panjar } = result;
  const badgeStyle =
    decision.recommendation === 'TAHAN'
      ? 'bg-emerald-100 text-emerald-900 border-emerald-400'
      : decision.recommendation === 'TAHAN_BERISIKO'
        ? 'bg-amber-100 text-amber-900 border-amber-400'
        : 'bg-rose-100 text-rose-900 border-rose-400';

  const speechText = `Rekomendasi SimpanJual: ${decision.recommendation.replace('_', ' ')}. ${decision.summarySentence} Jika menerima panjar Rp${panjar.hargaPanjarPerKg.toLocaleString('id-ID')} per kilogram, potensi kehilangan hasil sekitar Rp${panjar.selisihTerhadapTahanRp.toLocaleString('id-ID')}.`;

  return (
    <section className="field-card rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-slate-900">
            Simulator Keputusan Cepat (Jagung Pipil)
          </h2>
          <p className="field-muted text-sm text-slate-600">
            Coba ubah berat panen, kadar air, atau tawaran panjar tengkulak di bawah ini.
          </p>
        </div>
        <SpeechButton text={speechText} />
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <label className="block text-sm font-medium text-slate-800">
          Jumlah Panen (kg)
          <input
            type="number"
            inputMode="numeric"
            value={qtyKg}
            onChange={(e) => setQtyKg(Number(e.target.value) || 0)}
            className="mt-1 min-h-[44px] w-full rounded-lg border border-slate-300 px-3 py-2 text-base font-semibold"
          />
        </label>
        <label className="block text-sm font-medium text-slate-800">
          Kadar Air Aktual (%) — Ambang 15%
          <input
            type="number"
            inputMode="decimal"
            step="0.5"
            value={kadarAir}
            onChange={(e) => setKadarAir(Number(e.target.value) || 0)}
            className="mt-1 min-h-[44px] w-full rounded-lg border border-slate-300 px-3 py-2 text-base font-semibold"
          />
        </label>
        <label className="block text-sm font-medium text-slate-800">
          Harga Pasar Hari Ini (Rp/kg)
          <input
            type="number"
            inputMode="numeric"
            value={p0Dry}
            onChange={(e) => setP0Dry(Number(e.target.value) || 0)}
            className="mt-1 min-h-[44px] w-full rounded-lg border border-slate-300 px-3 py-2 text-base font-semibold"
          />
        </label>
        <label className="block text-sm font-medium text-slate-800">
          Perkiraan Harga 8 Minggu (Rp/kg)
          <input
            type="number"
            inputMode="numeric"
            value={p8Pred}
            onChange={(e) => setP8Pred(Number(e.target.value) || 0)}
            className="mt-1 min-h-[44px] w-full rounded-lg border border-slate-300 px-3 py-2 text-base font-semibold"
          />
        </label>
        <label className="block text-sm font-medium text-slate-800">
          Tawaran Panjar Tengkulak (Rp/kg)
          <input
            type="number"
            inputMode="numeric"
            value={panjarPerKg}
            onChange={(e) => setPanjarPerKg(Number(e.target.value) || 0)}
            className="mt-1 min-h-[44px] w-full rounded-lg border border-slate-300 px-3 py-2 text-base font-semibold"
          />
        </label>
        <label className="flex min-h-[44px] cursor-pointer items-center gap-2.5 self-end rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm font-medium text-slate-800">
          <input
            type="checkbox"
            checked={pakaiSsrg}
            onChange={(e) => setPakaiSsrg(e.target.checked)}
            className="h-5 w-5 accent-emerald-700"
          />
          <span>Pakai Skema Bunga S-SRG (6%/thn)</span>
        </label>
      </div>

      <div className={`mt-5 rounded-xl border p-4 ${badgeStyle}`}>
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="text-lg font-extrabold">
            REKOMENDASI: {decision.recommendation.replace('_', ' ')} ({decision.bestHorizonWeeks} Minggu)
          </span>
          <span className="text-base font-bold">
            Titik Impas: Rp{decision.best.titikImpasPerKg.toLocaleString('id-ID')}/kg
          </span>
        </div>
        <p className="mt-1 text-sm font-medium">{decision.summarySentence}</p>
        <div className="mt-3 grid gap-2 text-sm sm:grid-cols-3">
          <div className="rounded-lg bg-white/80 p-2.5">
            <div className="text-xs text-slate-600">Bobot Siap Simpan</div>
            <div className="font-bold">
              {decision.qtySiap.toLocaleString('id-ID')} kg
              {decision.perluPengeringan
                ? ` (susut jemur ${decision.susutPengeringanKg.toLocaleString('id-ID')} kg)`
                : ' (siap masuk gudang)'}
            </div>
          </div>
          <div className="rounded-lg bg-white/80 p-2.5">
            <div className="text-xs text-slate-600">Selisih Bersih vs Jual Hari Ini</div>
            <div className="font-bold">
              {decision.best.selisihRp >= 0 ? '+' : ''}Rp
              {decision.best.selisihRp.toLocaleString('id-ID')} ({decision.best.selisihPct}%)
            </div>
          </div>
          <div className="rounded-lg bg-white/80 p-2.5">
            <div className="text-xs text-slate-600">Panjar Tandingan</div>
            <div className="font-bold text-rose-800">
              Potensi rugi Rp{panjar.selisihTerhadapTahanRp.toLocaleString('id-ID')} (diskon{' '}
              {panjar.diskonTerhadapPasarPct}%)
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
