'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { LogOut, Sprout, Sun, UserCheck } from 'lucide-react';
import type { SessionUser } from '@/lib/auth';

const ROLE_LABEL: Record<SessionUser['role'], string> = {
  petani: 'Petani / Poktan',
  gudang: 'Pengelola Gudang',
  pembeli: 'Pembeli',
  admin: 'Admin',
};

export function Navbar({ user }: { user: SessionUser | null }) {
  const router = useRouter();
  const [fieldMode, setFieldMode] = useState(false);

  useEffect(() => {
    const saved = window.localStorage.getItem('simpanjual_field_mode') === '1';
    setFieldMode(saved);
    document.documentElement.classList.toggle('field-mode', saved);
  }, []);

  const toggleFieldMode = () => {
    const next = !fieldMode;
    setFieldMode(next);
    window.localStorage.setItem('simpanjual_field_mode', next ? '1' : '0');
    document.documentElement.classList.toggle('field-mode', next);
  };

  const handleLogout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' });
    router.push('/masuk');
    router.refresh();
  };

  return (
    <header className="sticky top-0 z-40 border-b border-slate-200 bg-white/95 backdrop-blur">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3 sm:px-6">
        <div className="flex items-center gap-3">
          <Link href="/" className="flex items-center gap-2 font-bold text-emerald-800">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-700 text-white">
              <Sprout className="h-5 w-5" />
            </span>
            <span className="text-lg tracking-tight">SimpanJual</span>
          </Link>
          <span className="hidden rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-semibold text-emerald-800 sm:inline-block">
            SDG 8
          </span>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={toggleFieldMode}
            aria-pressed={fieldMode}
            className={`inline-flex min-h-[44px] items-center gap-1.5 rounded-lg border px-3 text-sm font-semibold transition ${
              fieldMode
                ? 'border-slate-900 bg-amber-300 text-slate-950'
                : 'border-slate-300 bg-slate-50 text-slate-800 hover:bg-slate-100'
            }`}
            title="Perbesar teks & pertajam kontras untuk penggunaan di lapangan"
          >
            <Sun className="h-4 w-4" />
            <span>Aa+ Mode Lapangan</span>
          </button>

          {user ? (
            <>
              <Link
                href={`/${user.role}`}
                className="inline-flex min-h-[44px] items-center gap-1.5 rounded-lg bg-emerald-50 px-3 text-sm font-medium text-emerald-900 hover:bg-emerald-100"
              >
                <UserCheck className="h-4 w-4" />
                <span>
                  {user.nama} ({ROLE_LABEL[user.role]})
                </span>
              </Link>
              <button
                type="button"
                onClick={handleLogout}
                className="inline-flex min-h-[44px] items-center gap-1.5 rounded-lg border border-slate-300 px-3 text-sm font-medium text-slate-700 hover:bg-slate-100"
              >
                <LogOut className="h-4 w-4" />
                <span>Keluar</span>
              </button>
            </>
          ) : (
            <Link
              href="/masuk"
              className="inline-flex min-h-[44px] items-center rounded-lg bg-emerald-700 px-4 text-sm font-semibold text-white hover:bg-emerald-800"
            >
              Masuk / Demo 1-Klik
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}
