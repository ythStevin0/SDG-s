import { redirect } from 'next/navigation';
import { db } from '@/db';
import { commodities } from '@/db/schema';
import { getSessionUser } from '@/lib/auth';

export default async function AdminDashboardPage() {
  const user = await getSessionUser();
  if (!user || user.role !== 'admin') redirect('/masuk');

  const allCommodities = await db.select().from(commodities);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Admin — Konfigurasi Komoditas (Scalability)</h1>
        <p className="field-muted text-sm text-slate-600">
          Seluruh aturan mutu, laju susut, dan patokan tarif disimpan dalam JSONB sehingga komoditas
          baru dapat ditambahkan tanpa mengubah logika mesin hitung.
        </p>
      </div>

      <div className="space-y-4">
        {allCommodities.map((c) => (
          <div
            key={c.id}
            className="field-card rounded-xl border border-slate-200 bg-white p-5 shadow-sm"
          >
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-slate-900">
                {c.nama} (<code className="font-mono text-sm">{c.kode}</code>)
              </h2>
              <span className="rounded bg-slate-100 px-2 py-1 text-xs font-semibold">
                Satuan: {c.satuan}
              </span>
            </div>
            <pre className="mt-3 overflow-x-auto rounded-lg bg-slate-900 p-3 text-xs text-emerald-300">
              {JSON.stringify(c.params, null, 2)}
            </pre>
          </div>
        ))}
      </div>
    </div>
  );
}
