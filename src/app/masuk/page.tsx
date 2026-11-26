'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { KeyRound, Sparkles, UserPlus } from 'lucide-react';
import { REGION_NAMES } from '@/lib/constants/regions';

const DEMO_ACCOUNTS = [
  {
    email: 'petani@demo.id',
    label: 'Pak Slamet (Petani)',
    desc: 'Punya stok jagung 5 ton & gabah basah 4 ton',
    badge: 'Petani',
  },
  {
    email: 'poktan@demo.id',
    label: 'Bu Rini (Ketua Poktan)',
    desc: 'Mengelola Poktan Tani Jaya (kode TANIJAYA)',
    badge: 'Poktan',
  },
  {
    email: 'gudang@demo.id',
    label: 'Pak Joko (Gudang SRG)',
    desc: 'Mengelola kapasitas 4 gudang & permintaan sewa',
    badge: 'Gudang',
  },
  {
    email: 'pembeli@demo.id',
    label: 'Koperasi & SPPG Mitra',
    desc: 'Memasang Janji Beli & memproses penawaran jual',
    badge: 'Pembeli',
  },
  {
    email: 'admin@demo.id',
    label: 'Admin Konfigurasi',
    desc: 'Kelola parameter JSONB komoditas (Scalability)',
    badge: 'Admin',
  },
] as const;

export default function MasukPage() {
  const router = useRouter();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [nama, setNama] = useState('');
  const [role, setRole] = useState<'petani' | 'gudang' | 'pembeli'>('petani');
  const [kabupaten, setKabupaten] = useState('Banyumas');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleDemoLogin = async (demoEmail: string) => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/auth/demo', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: demoEmail }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Gagal masuk demo');
      router.push(data.redirectTo);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Terjadi kesalahan');
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const endpoint = mode === 'login' ? '/api/auth/login' : '/api/auth/register';
      const payload =
        mode === 'login'
          ? { email, password }
          : { email, password, nama, role, kabupaten };
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Gagal autentikasi');
      router.push(data.redirectTo);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Terjadi kesalahan');
      setLoading(false);
    }
  };

  return (
    <div className="grid gap-6 lg:grid-cols-2">
      <section className="field-card rounded-2xl border border-emerald-200 bg-emerald-50/70 p-6">
        <div className="mb-4 flex items-center gap-2 text-emerald-900">
          <Sparkles className="h-5 w-5" />
          <h1 className="text-xl font-bold">Masuk Cepat Akun Demo (1-Klik)</h1>
        </div>
        <p className="field-muted mb-4 text-sm text-slate-700">
          Khusus penguji dan dewan juri: langsung masuk ke peran mana saja tanpa mengetik ulang
          kata sandi (sandi standar bila login manual: <code className="font-mono">demo12345</code>).
        </p>

        <div className="space-y-3">
          {DEMO_ACCOUNTS.map((acc) => (
            <button
              key={acc.email}
              type="button"
              disabled={loading}
              onClick={() => handleDemoLogin(acc.email)}
              className="field-card flex min-h-[56px] w-full items-center justify-between gap-3 rounded-xl border border-emerald-300 bg-white p-3.5 text-left transition hover:border-emerald-600 hover:bg-emerald-50 disabled:opacity-60"
            >
              <div>
                <div className="font-bold text-slate-900">{acc.label}</div>
                <div className="field-muted text-xs text-slate-600">{acc.desc}</div>
              </div>
              <span className="shrink-0 rounded-lg bg-emerald-700 px-3 py-1.5 text-xs font-bold text-white">
                Masuk {acc.badge}
              </span>
            </button>
          ))}
        </div>
      </section>

      <section className="field-card rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
        <div className="mb-4 flex gap-2 border-b border-slate-200 pb-3">
          <button
            type="button"
            onClick={() => setMode('login')}
            className={`inline-flex min-h-[44px] items-center gap-1.5 rounded-lg px-4 text-sm font-bold ${
              mode === 'login' ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-700'
            }`}
          >
            <KeyRound className="h-4 w-4" />
            <span>Masuk Akun</span>
          </button>
          <button
            type="button"
            onClick={() => setMode('register')}
            className={`inline-flex min-h-[44px] items-center gap-1.5 rounded-lg px-4 text-sm font-bold ${
              mode === 'register' ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-700'
            }`}
          >
            <UserPlus className="h-4 w-4" />
            <span>Daftar Baru</span>
          </button>
        </div>

        {error && (
          <div className="mb-4 rounded-lg border border-rose-300 bg-rose-50 p-3 text-sm font-medium text-rose-800">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          {mode === 'register' && (
            <>
              <label className="block text-sm font-medium">
                Nama Lengkap
                <input
                  required
                  value={nama}
                  onChange={(e) => setNama(e.target.value)}
                  className="mt-1 min-h-[44px] w-full rounded-lg border border-slate-300 px-3 py-2"
                />
              </label>
              <div className="grid gap-3 sm:grid-cols-2">
                <label className="block text-sm font-medium">
                  Peran
                  <select
                    value={role}
                    onChange={(e) => setRole(e.target.value as 'petani' | 'gudang' | 'pembeli')}
                    className="mt-1 min-h-[44px] w-full rounded-lg border border-slate-300 px-3 py-2"
                  >
                    <option value="petani">Petani / Poktan</option>
                    <option value="gudang">Pemilik Gudang</option>
                    <option value="pembeli">Pembeli / Koperasi / SPPG</option>
                  </select>
                </label>
                <label className="block text-sm font-medium">
                  Kabupaten
                  <select
                    value={kabupaten}
                    onChange={(e) => setKabupaten(e.target.value)}
                    className="mt-1 min-h-[44px] w-full rounded-lg border border-slate-300 px-3 py-2"
                  >
                    {REGION_NAMES.map((reg) => (
                      <option key={reg} value={reg}>
                        {reg}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
            </>
          )}

          <label className="block text-sm font-medium">
            Email
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="petani@demo.id"
              className="mt-1 min-h-[44px] w-full rounded-lg border border-slate-300 px-3 py-2"
            />
          </label>
          <label className="block text-sm font-medium">
            Kata Sandi
            <input
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Minimal 6 karakter"
              className="mt-1 min-h-[44px] w-full rounded-lg border border-slate-300 px-3 py-2"
            />
          </label>

          <button
            type="submit"
            disabled={loading}
            className="min-h-[48px] w-full rounded-xl bg-emerald-700 px-4 py-3 text-base font-bold text-white hover:bg-emerald-800 disabled:opacity-60"
          >
            {loading ? 'Memproses...' : mode === 'login' ? 'Masuk' : 'Daftar & Masuk'}
          </button>
        </form>
      </section>
    </div>
  );
}
