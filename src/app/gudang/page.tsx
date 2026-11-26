import { redirect } from 'next/navigation';
import { eq } from 'drizzle-orm';
import { db } from '@/db';
import { warehouses } from '@/db/schema';
import { getSessionUser } from '@/lib/auth';

export default async function GudangDashboardPage() {
  const user = await getSessionUser();
  if (!user || user.role !== 'gudang') redirect('/masuk');

  const myWarehouses = await db
    .select()
    .from(warehouses)
    .where(eq(warehouses.ownerId, user.userId));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Dashboard Pengelola Gudang</h1>
        <p className="field-muted text-sm text-slate-600">
          Akun aktif: {user.nama} · Kapasitas tersedia otomatis terkelola via transaksi atomik.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {myWarehouses.map((wh) => (
          <div
            key={wh.id}
            className="field-card rounded-xl border border-slate-200 bg-white p-5 shadow-sm"
          >
            <div className="flex items-start justify-between gap-2">
              <h2 className="text-lg font-bold text-slate-900">{wh.nama}</h2>
              {wh.isSrg && (
                <span className="rounded-full bg-blue-100 px-2.5 py-1 text-xs font-bold text-blue-900">
                  Gudang SRG
                </span>
              )}
            </div>
            <p className="field-muted mt-1 text-sm text-slate-600">
              {wh.kabupaten} · Komoditas: {wh.komoditasDiterima.join(', ')}
            </p>
            <div className="mt-4 grid grid-cols-3 gap-2 rounded-lg bg-slate-50 p-3 text-sm">
              <div>
                <div className="text-xs text-slate-500">Kapasitas</div>
                <div className="font-bold">{wh.kapasitasKg.toLocaleString('id-ID')} kg</div>
              </div>
              <div>
                <div className="text-xs text-slate-500">Tersedia</div>
                <div className="font-bold text-emerald-700">
                  {wh.tersediaKg.toLocaleString('id-ID')} kg
                </div>
              </div>
              <div>
                <div className="text-xs text-slate-500">Tarif</div>
                <div className="font-bold">Rp{wh.tarifPerKgHari}/kg/hr</div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
