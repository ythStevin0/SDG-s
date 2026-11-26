import { redirect } from 'next/navigation';
import { eq } from 'drizzle-orm';
import { db } from '@/db';
import { buyerDemands, commodities } from '@/db/schema';
import { getSessionUser } from '@/lib/auth';

export default async function PembeliDashboardPage() {
  const user = await getSessionUser();
  if (!user || user.role !== 'pembeli') redirect('/masuk');

  const myDemands = await db
    .select({
      id: buyerDemands.id,
      qtyKg: buyerDemands.qtyKg,
      terpenuhiKg: buyerDemands.terpenuhiKg,
      hargaAcuan: buyerDemands.hargaAcuan,
      dibutuhkanPada: buyerDemands.dibutuhkanPada,
      kabupaten: buyerDemands.kabupaten,
      status: buyerDemands.status,
      commodityNama: commodities.nama,
    })
    .from(buyerDemands)
    .innerJoin(commodities, eq(buyerDemands.commodityId, commodities.id))
    .where(eq(buyerDemands.buyerId, user.userId));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Dashboard Pembeli (Janji Beli)</h1>
        <p className="field-muted text-sm text-slate-600">
          Akun aktif: {user.nama} · Pantau target kebutuhan pasokan dan progres pemenuhan kuota.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {myDemands.map((d) => {
          const pct = Math.min(100, Math.round((d.terpenuhiKg / d.qtyKg) * 100));
          return (
            <div
              key={d.id}
              className="field-card rounded-xl border border-slate-200 bg-white p-5 shadow-sm"
            >
              <div className="flex items-start justify-between gap-2">
                <div>
                  <h2 className="text-lg font-bold text-slate-900">{d.commodityNama}</h2>
                  <p className="field-muted text-xs text-slate-600">
                    {d.kabupaten} · Dibutuhkan: {d.dibutuhkanPada}
                  </p>
                </div>
                <span className="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-bold text-amber-900">
                  Rp{d.hargaAcuan.toLocaleString('id-ID')}/kg
                </span>
              </div>

              <div className="mt-4">
                <div className="mb-1 flex justify-between text-xs font-semibold">
                  <span>
                    Terpenuhi: {d.terpenuhiKg.toLocaleString('id-ID')} /{' '}
                    {d.qtyKg.toLocaleString('id-ID')} kg
                  </span>
                  <span>{pct}%</span>
                </div>
                <div className="h-2.5 w-full overflow-hidden rounded-full bg-slate-200">
                  <div className="h-full bg-emerald-600" style={{ width: `${pct}%` }} />
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
