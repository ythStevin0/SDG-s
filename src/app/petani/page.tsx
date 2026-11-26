import { redirect } from 'next/navigation';
import { eq } from 'drizzle-orm';
import { db } from '@/db';
import { commodities, stocks } from '@/db/schema';
import { getSessionUser } from '@/lib/auth';

export default async function PetaniDashboardPage() {
  const user = await getSessionUser();
  if (!user || user.role !== 'petani') redirect('/masuk');

  const myStocks = await db
    .select({
      id: stocks.id,
      qtyKg: stocks.qtyKg,
      reservedKg: stocks.reservedKg,
      soldKg: stocks.soldKg,
      kadarAir: stocks.kadarAir,
      tglPanen: stocks.tglPanen,
      kabupaten: stocks.kabupaten,
      status: stocks.status,
      commodityNama: commodities.nama,
      kaAmbang: commodities.params,
    })
    .from(stocks)
    .innerJoin(commodities, eq(stocks.commodityId, commodities.id))
    .where(eq(stocks.ownerId, user.userId));

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Dashboard Petani — {user.nama}</h1>
          <p className="field-muted text-sm text-slate-600">
            Wilayah: {user.kabupaten} · Kelola stok panen & pantau ketersediaan bebas untuk simpan/jual.
          </p>
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {myStocks.map((st) => {
          const bebas = st.qtyKg - st.reservedKg - st.soldKg;
          const perluJemur = st.kadarAir > st.kaAmbang.kadar_air_maks_pct;
          return (
            <div
              key={st.id}
              className="field-card rounded-xl border border-slate-200 bg-white p-5 shadow-sm"
            >
              <div className="flex items-start justify-between gap-2">
                <div>
                  <h2 className="text-lg font-bold text-slate-900">{st.commodityNama}</h2>
                  <p className="field-muted text-xs text-slate-600">
                    Panen {st.tglPanen} · {st.kabupaten}
                  </p>
                </div>
                <span className="rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-bold text-emerald-900">
                  {st.status.replace('_', ' ')}
                </span>
              </div>

              <div className="mt-4 grid grid-cols-3 gap-2 rounded-lg bg-slate-50 p-3 text-sm">
                <div>
                  <div className="text-xs text-slate-500">Total</div>
                  <div className="font-bold">{st.qtyKg.toLocaleString('id-ID')} kg</div>
                </div>
                <div>
                  <div className="text-xs text-slate-500">Terkunci</div>
                  <div className="font-bold">{st.reservedKg.toLocaleString('id-ID')} kg</div>
                </div>
                <div>
                  <div className="text-xs text-slate-500">Bebas</div>
                  <div className="font-bold text-emerald-700">{bebas.toLocaleString('id-ID')} kg</div>
                </div>
              </div>

              <div className="mt-3 text-sm">
                Kadar air aktual: <strong>{st.kadarAir}%</strong>{' '}
                {perluJemur ? (
                  <span className="font-semibold text-amber-700">
                    (Perlu pengeringan ke ≤ {st.kaAmbang.kadar_air_maks_pct}%)
                  </span>
                ) : (
                  <span className="font-semibold text-emerald-700">(Layak simpan ✓)</span>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
