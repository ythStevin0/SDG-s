import React, { useEffect } from 'react';
import { formatKg, formatRp } from './api';
import { JATENG_COORDS, WarehouseItem } from './offlineData';

export function BarnScaleLogo({
  lightOnDark = true,
  compact = false,
}: {
  lightOnDark?: boolean;
  compact?: boolean;
}) {
  const fg = lightOnDark ? '#FFFFFF' : 'var(--sj-ink)';
  const sub = lightOnDark ? 'var(--sj-gold-text)' : 'var(--sj-ink-muted)';
  const size = compact ? 30 : 34;

  return (
    <span className="inline-flex items-center gap-2.5 select-none">
      <svg
        width={size}
        height={size}
        viewBox="0 0 64 64"
        fill="none"
        aria-hidden="true"
        className="shrink-0"
      >
        <path
          d="M7 27 L32 8 L57 27"
          stroke={fg}
          strokeWidth="5.4"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <line x1="13" y1="26" x2="13" y2="55" stroke={fg} strokeWidth="5.4" strokeLinecap="round" />
        <line x1="51" y1="26" x2="51" y2="55" stroke={fg} strokeWidth="5.4" strokeLinecap="round" />
        <line x1="9" y1="55" x2="55" y2="55" stroke={fg} strokeWidth="5.4" strokeLinecap="round" />
        <line x1="32" y1="17" x2="32" y2="34" stroke={fg} strokeWidth="4.2" strokeLinecap="round" />
        <line x1="20" y1="31" x2="44" y2="31" stroke={fg} strokeWidth="4.2" strokeLinecap="round" />
        <path
          d="M32 33 Q42 42 32 51 Q22 42 32 33 Z"
          fill="#E5AF42"
          stroke="#9A4206"
          strokeWidth="1.6"
        />
      </svg>
      <span className="flex flex-col leading-none">
        <span
          style={{ color: fg }}
          className={`font-black tracking-tight ${compact ? 'text-[13px]' : 'text-[14.5px]'}`}
        >
          Simpan
        </span>
        <span
          style={{ color: sub }}
          className={`font-extrabold tracking-tight mt-0.5 ${compact ? 'text-[13px]' : 'text-[14.5px]'}`}
        >
          Jual
        </span>
      </span>
    </span>
  );
}

export function SvgGlyph({
  name,
  className = 'w-5 h-5',
}: {
  name:
    | 'arrow-right'
    | 'arrow-down'
    | 'menu'
    | 'close'
    | 'sun'
    | 'moon'
    | 'speaker'
    | 'text-size'
    | 'refresh'
    | 'grain'
    | 'barn'
    | 'handshake'
    | 'collapse'
    | 'check'
    | 'warn';
  className?: string;
}) {
  switch (name) {
    case 'arrow-right':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.3" aria-hidden="true" className={className}>
          <path d="M5 12h14M13 6l6 6-6 6" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case 'arrow-down':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" aria-hidden="true" className={className}>
          <path d="M12 4v16M6 14l6 6 6-6" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case 'menu':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden="true" className={className}>
          <path d="M4 7h16M4 12h16M4 17h11" strokeLinecap="round" />
        </svg>
      );
    case 'close':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.3" aria-hidden="true" className={className}>
          <path d="M6 6l12 12M18 6L6 18" strokeLinecap="round" />
        </svg>
      );
    case 'sun':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true" className={className}>
          <circle cx="12" cy="12" r="4.2" />
          <path d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M18.7 5.3l-1.8 1.8M7.1 16.9l-1.8 1.8" strokeLinecap="round" />
        </svg>
      );
    case 'moon':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true" className={className}>
          <path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5Z" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case 'speaker':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true" className={className}>
          <path d="M11 5L6 9H3v6h3l5 4V5Z" strokeLinejoin="round" />
          <path d="M15.5 8.5a5 5 0 0 1 0 7M18.5 6a8.5 8.5 0 0 1 0 12" strokeLinecap="round" />
        </svg>
      );
    case 'text-size':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" aria-hidden="true" className={className}>
          <path d="M3 7V5h12v2M9 5v14M6.5 19h5M16 12h5M18.5 9.5v5" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case 'refresh':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" aria-hidden="true" className={className}>
          <path d="M20 11a8 8 0 1 0 2 5.3M20 4v7h-7" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case 'grain':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true" className={className}>
          <path d="M12 21V7M12 13c-3.5 0-6-2.5-6-6 3.5 0 6 2.5 6 6ZM12 16c3.5 0 6-2.5 6-6-3.5 0-6 2.5-6 6Z" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case 'barn':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true" className={className}>
          <path d="M3 10l9-6 9 6M5 9.5V20h14V9.5M9 20v-6h6v6" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case 'handshake':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true" className={className}>
          <path d="M8 11l4 4 7-7M3 13l5 5 3-3" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case 'collapse':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.1" aria-hidden="true" className={className}>
          <rect x="3" y="4" width="18" height="16" rx="2" />
          <path d="M9 4v16" />
        </svg>
      );
    case 'check':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" aria-hidden="true" className={className}>
          <path d="M5 13l4 4L19 7" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    case 'warn':
      return (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" aria-hidden="true" className={className}>
          <path d="M12 9v4m0 4h.01M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
  }
}

export function SplitGoldCtaButton({
  label,
  onClick,
  href,
}: {
  label: string;
  onClick?: () => void;
  href?: string;
}) {
  if (href) {
    return (
      <a href={href} onClick={onClick} className="sj-split-cta">
        <span>{label}</span>
        <span className="sj-split-cta-circle">
          <SvgGlyph name="arrow-right" className="w-4 h-4" />
        </span>
      </a>
    );
  }
  return (
    <button type="button" onClick={onClick} className="sj-split-cta">
      <span>{label}</span>
      <span className="sj-split-cta-circle">
        <SvgGlyph name="arrow-right" className="w-4 h-4" />
      </span>
    </button>
  );
}

export function StampBadge({
  label,
  tone = 'neutral',
}: {
  label: string;
  tone?: 'ok' | 'warn' | 'danger' | 'neutral';
}) {
  const styles: Record<string, React.CSSProperties> = {
    ok: {
      backgroundColor: 'var(--sj-ok-bg)',
      color: 'var(--sj-ok-ink)',
      borderColor: 'var(--sj-ok-ink)',
    },
    warn: {
      backgroundColor: 'var(--sj-warn-bg)',
      color: 'var(--sj-warn-ink)',
      borderColor: 'var(--sj-warn-ink)',
    },
    danger: {
      backgroundColor: 'var(--sj-danger-bg)',
      color: 'var(--sj-danger-ink)',
      borderColor: 'var(--sj-danger-ink)',
    },
    neutral: {
      backgroundColor: 'var(--sj-surface-alt)',
      color: 'var(--sj-ink)',
      borderColor: 'var(--sj-border)',
    },
  };

  return (
    <span
      style={styles[tone]}
      className="sj-stamp inline-flex items-center gap-1.5 border px-2.5 py-1 text-xs font-extrabold tracking-wide"
    >
      <SvgGlyph name={tone === 'ok' || tone === 'neutral' ? 'check' : 'warn'} className="w-3.5 h-3.5" />
      <span>{label}</span>
    </span>
  );
}

export function LedgerRow({
  label,
  value,
  emphasize = false,
  tone,
}: {
  label: string;
  value: string;
  emphasize?: boolean;
  tone?: 'ok' | 'danger';
}) {
  const valColor =
    tone === 'ok'
      ? 'var(--sj-ok-ink)'
      : tone === 'danger'
        ? 'var(--sj-danger-ink)'
        : 'var(--sj-ink)';

  return (
    <div className="flex items-baseline justify-between gap-3 py-1.5">
      <span
        style={{ color: emphasize ? 'var(--sj-ink)' : 'var(--sj-ink-muted)' }}
        className={emphasize ? 'text-sm font-extrabold' : 'text-[13px] font-medium'}
      >
        {label}
      </span>
      <span
        style={{ color: valColor }}
        className={`tabular-nums text-right ${emphasize ? 'text-[15.5px] font-black' : 'text-[13.5px] font-bold'}`}
      >
        {value}
      </span>
    </div>
  );
}

export function StatePanel({
  kind,
  title,
  message,
  actionLabel,
  onAction,
}: {
  kind: 'loading' | 'empty' | 'error';
  title: string;
  message: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  const isError = kind === 'error';
  return (
    <div
      role={isError ? 'alert' : 'status'}
      style={{
        backgroundColor: isError ? 'var(--sj-danger-bg)' : 'var(--sj-surface)',
        borderColor: isError ? 'var(--sj-danger-ink)' : 'var(--sj-border)',
        color: isError ? 'var(--sj-danger-ink)' : 'var(--sj-ink)',
      }}
      className="sj-card p-5"
    >
      <div className="flex items-center gap-2.5">
        <SvgGlyph name={isError ? 'warn' : 'grain'} className="w-5 h-5 shrink-0" />
        <strong className="text-[15px] font-extrabold">{title}</strong>
      </div>
      <p
        style={{ color: isError ? 'var(--sj-danger-ink)' : 'var(--sj-ink-muted)' }}
        className="mt-1.5 text-sm leading-relaxed"
      >
        {message}
      </p>
      {actionLabel && onAction && (
        <div className="mt-3.5">
          <button type="button" onClick={onAction} className="sj-btn-primary">
            {actionLabel}
          </button>
        </div>
      )}
    </div>
  );
}

// Grafik menjawab satu pertanyaan keputusan nyata petani, bukan dekorasi garis kosong (antislop-ui)
export function ForecastBreakEvenChart({
  latestPrice,
  breakEvenPerKg,
  predictions,
}: {
  latestPrice: number;
  breakEvenPerKg: number;
  predictions: { horizonWeeks: number; pricePoint: number; priceLow: number; priceHigh: number }[];
}) {
  const pts = [
    { label: 'Hari ini', price: latestPrice, low: latestPrice, high: latestPrice },
    ...predictions.map((p) => ({
      label: `+${p.horizonWeeks} mgg`,
      price: p.pricePoint,
      low: p.priceLow,
      high: p.priceHigh,
    })),
  ];

  const allVals = pts.flatMap((p) => [p.low, p.high]).concat([breakEvenPerKg]);
  const minVal = Math.min(...allVals) * 0.94;
  const maxVal = Math.max(...allVals) * 1.04;
  const span = Math.max(200, maxVal - minVal);

  const w = 520;
  const h = 190;
  const padL = 62;
  const padR = 20;
  const padT = 18;
  const padB = 32;
  const plotW = w - padL - padR;
  const plotH = h - padT - padB;

  const xAt = (idx: number) => padL + (idx / Math.max(1, pts.length - 1)) * plotW;
  const yAt = (val: number) => padT + plotH - ((val - minVal) / span) * plotH;

  const polyPoints = pts.map((p, i) => `${xAt(i)},${yAt(p.price)}`).join(' ');
  const yBreakEven = yAt(breakEvenPerKg);

  return (
    <div className="sj-card p-4 mt-4">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <strong className="text-sm font-extrabold" style={{ color: 'var(--sj-ink)' }}>
          Apakah proyeksi harga 4 sampai 12 minggu melewati titik impas simpan?
        </strong>
        <span className="tabular-nums text-xs font-bold" style={{ color: 'var(--sj-ink-muted)' }}>
          Garis impas: {formatRp(breakEvenPerKg)}/kg
        </span>
      </div>
      <svg
        viewBox={`0 0 ${w} ${h}`}
        role="img"
        aria-label={`Grafik perbandingan proyeksi harga terhadap titik impas ${formatRp(breakEvenPerKg)} per kilogram`}
        className="mt-3 w-full h-auto"
      >
        <line
          x1={padL}
          y1={yBreakEven}
          x2={w - padR}
          y2={yBreakEven}
          stroke="#C2410C"
          strokeWidth="2"
          strokeDasharray="6 4"
        />
        <text x={padL - 6} y={yBreakEven + 4} textAnchor="end" fontSize="11" fontWeight="700" fill="#C2410C">
          Impas
        </text>
        <polyline
          fill="none"
          stroke="#2E7D4F"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
          points={polyPoints}
        />
        {pts.map((p, i) => (
          <g key={p.label}>
            <circle cx={xAt(i)} cy={yAt(p.price)} r="4.5" fill="#E5AF42" stroke="#193226" strokeWidth="2" />
            <text
              x={xAt(i)}
              y={yAt(p.price) - 10}
              textAnchor="middle"
              fontSize="11"
              fontWeight="800"
              fill="currentColor"
            >
              {formatRp(p.price)}
            </text>
            <text
              x={xAt(i)}
              y={h - 8}
              textAnchor="middle"
              fontSize="11"
              fontWeight="600"
              fill="currentColor"
            >
              {p.label}
            </text>
          </g>
        ))}
      </svg>
    </div>
  );
}

// Peta koordinat regional interaktif untuk memvisualisasikan posisi petani terhadap gudang SRG & koperasi
export function WarehouseMapPanel({
  farmerKabupaten,
  warehouses,
  selectedId,
  onSelect,
}: {
  farmerKabupaten: string;
  warehouses: WarehouseItem[];
  selectedId?: string;
  onSelect: (wh: WarehouseItem) => void;
}) {
  const farmerCoord = JATENG_COORDS[farmerKabupaten] ?? JATENG_COORDS.Banyumas;
  const allLats = [farmerCoord[0], ...warehouses.map((w) => w.lat)];
  const allLngs = [farmerCoord[1], ...warehouses.map((w) => w.lng)];
  const minLat = Math.min(...allLats) - 0.14;
  const maxLat = Math.max(...allLats) + 0.14;
  const minLng = Math.min(...allLngs) - 0.18;
  const maxLng = Math.max(...allLngs) + 0.18;
  const latSpan = Math.max(0.25, maxLat - minLat);
  const lngSpan = Math.max(0.25, maxLng - minLng);

  const toPos = (lat: number, lng: number) => ({
    leftPct: Math.min(88, Math.max(12, ((lng - minLng) / lngSpan) * 100)),
    topPct: Math.min(82, Math.max(18, (1 - (lat - minLat) / latSpan) * 100)),
  });

  const farmerPos = toPos(farmerCoord[0], farmerCoord[1]);
  const activeWh = warehouses.find((w) => w.id === selectedId) || warehouses[0];

  return (
    <section
      role="region"
      aria-label="Peta sebaran gudang Jawa Tengah"
      className="sj-card p-4 space-y-3"
    >
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <strong className="text-sm font-extrabold">Peta Sebaran Gudang &amp; Skor Kelayakan (F8)</strong>
          <p className="text-xs" style={{ color: 'var(--sj-ink-muted)' }}>
            Pilih pin gudang untuk melihat koordinat, jarak estimasi, dan membuka peta OpenStreetMap.
          </p>
        </div>
        {activeWh && (
          <a
            href={`https://www.openstreetmap.org/?mlat=${activeWh.lat}&mlon=${activeWh.lng}#map=13/${activeWh.lat}/${activeWh.lng}`}
            target="_blank"
            rel="noreferrer"
            className="sj-btn-outline text-xs px-3 py-1.5 min-h-[44px]"
          >
            <span>Buka di OpenStreetMap</span>
            <SvgGlyph name="arrow-right" className="w-3.5 h-3.5" />
          </a>
        )}
      </div>

      <div
        style={{ backgroundColor: '#DDECD3', borderColor: 'var(--sj-border)' }}
        className="relative h-60 w-full rounded-xl border overflow-hidden"
      >
        <div
          style={{
            left: `${farmerPos.leftPct}%`,
            top: `${farmerPos.topPct}%`,
            transform: 'translate(-50%, -50%)',
          }}
          className="absolute z-10 pointer-events-none"
        >
          <span className="inline-flex items-center gap-1 rounded bg-[#1C1917] px-2 py-1 text-[11px] font-extrabold text-white">
            Lokasi ({farmerKabupaten})
          </span>
        </div>

        {warehouses.map((w) => {
          const pos = toPos(w.lat, w.lng);
          const isSelected = activeWh?.id === w.id;
          const pinBg = !w.score.isEligible ? '#57534E' : w.isSrg ? '#163A2A' : '#9A4206';
          return (
            <button
              key={w.id}
              type="button"
              aria-pressed={isSelected}
              onClick={() => onSelect(w)}
              style={{
                left: `${pos.leftPct}%`,
                top: `${pos.topPct}%`,
                transform: 'translate(-50%, -50%)',
                backgroundColor: pinBg,
                borderColor: isSelected ? '#E5AF42' : '#FFFFFF',
              }}
              className={`absolute z-20 inline-flex min-h-[44px] items-center gap-1.5 rounded-lg border-2 px-2.5 py-1 text-[11px] font-extrabold text-white ${
                isSelected ? 'z-30' : 'opacity-95 hover:opacity-100'
              }`}
            >
              <SvgGlyph name="barn" className="w-3.5 h-3.5 shrink-0" />
              <span className="whitespace-nowrap">
                {w.isSrg ? 'SRG' : 'Koperasi'} · Skor {w.score.totalScore}
              </span>
            </button>
          );
        })}
      </div>

      {activeWh && (
        <div className="sj-card-alt px-3.5 py-2.5 flex flex-wrap items-center justify-between gap-2 text-xs">
          <span className="font-bold">
            Terpilih: {activeWh.nama} ({activeWh.kabupaten}) · Jarak {activeWh.score.distanceKm} km · Kosong{' '}
            {formatKg(activeWh.tersediaKg)}
          </span>
          <StampBadge label={activeWh.isSrg ? 'STANDAR SRG' : 'GUDANG MITRA'} tone="ok" />
        </div>
      )}
    </section>
  );
}

export function QuickAuthModal({
  open,
  onClose,
  onDemoSelect,
  onManualLogin,
  onRegister,
  busy,
  authError,
}: {
  open: boolean;
  onClose: () => void;
  onDemoSelect: (preset: string) => void;
  onManualLogin: (email: string, password: string) => void;
  onRegister: (payload: {
    nama: string;
    email: string;
    password: string;
    role: 'petani' | 'gudang' | 'pembeli';
    kabupaten: string;
  }) => void;
  busy: boolean;
  authError: string | null;
}) {
  const [formMode, setFormMode] = React.useState<'login' | 'register'>('login');
  const [nama, setNama] = React.useState('');
  const [email, setEmail] = React.useState('');
  const [password, setPassword] = React.useState('');
  const [role, setRole] = React.useState<'petani' | 'gudang' | 'pembeli'>('petani');
  const [kabupaten, setKabupaten] = React.useState('Banyumas');
  const [localValidation, setLocalValidation] = React.useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose();
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;

  const presets = [
    { id: 'petani', title: 'Pak Slamet · Petani Padi & Jagung', sub: 'Banyumas · Stok 5 ton jagung & 4 ton gabah' },
    { id: 'poktan', title: 'Bu Rini · Ketua Poktan Tani Jaya', sub: 'Kode gabung TANIJAYA · Lot kolektif 10 ton' },
    { id: 'gudang', title: 'Pak Joko · Pengelola Gudang SRG', sub: 'Kapasitas 82 ton · Persetujuan sewa atomik' },
    { id: 'pembeli', title: 'Koperasi & SPPG Mitra Banyumas', sub: 'Pembeli siaga · Janji Beli jagung & gabah' },
    { id: 'admin', title: 'Admin SimpanJual', sub: 'Kesehatan sistem & parameter komoditas JSONB' },
  ];

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ backgroundColor: 'rgba(14, 30, 22, 0.78)' }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="judul-dialog-akun"
        className="sj-card w-full max-w-xl max-h-[90dvh] overflow-y-auto p-6"
      >
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 id="judul-dialog-akun" className="text-lg font-black" style={{ color: 'var(--sj-ink)' }}>
              Masuk, Daftar, atau Pilih 5 Akun Demo
            </h2>
            <p className="text-xs mt-0.5" style={{ color: 'var(--sj-ink-muted)' }}>
              Tekan tombol Escape kapan saja untuk menutup jendela ini.
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Tutup dialog akun"
            className="sj-btn-outline px-3 py-2"
          >
            <SvgGlyph name="close" className="w-4 h-4" />
            <span>Tutup</span>
          </button>
        </div>

        {(authError || localValidation) && (
          <div
            role="alert"
            style={{
              backgroundColor: 'var(--sj-danger-bg)',
              color: 'var(--sj-danger-ink)',
              borderColor: 'var(--sj-danger-ink)',
            }}
            className="mt-4 rounded-lg border p-3 text-sm font-semibold"
          >
            {localValidation || authError}
          </div>
        )}

        <div className="mt-4 space-y-2">
          <div className="text-xs font-extrabold uppercase tracking-wide" style={{ color: 'var(--sj-ink-muted)' }}>
            1-Klik Akun Demo Siap Uji
          </div>
          {presets.map((p) => (
            <button
              key={p.id}
              type="button"
              disabled={busy}
              onClick={() => onDemoSelect(p.id)}
              className="sj-btn-outline w-full justify-between text-left px-4 py-3"
            >
              <span>
                <span className="block text-sm font-extrabold" style={{ color: 'var(--sj-ink)' }}>
                  {p.title}
                </span>
                <span className="block text-xs font-medium mt-0.5" style={{ color: 'var(--sj-ink-muted)' }}>
                  {p.sub}
                </span>
              </span>
              <SvgGlyph name="arrow-right" className="w-4 h-4 shrink-0" />
            </button>
          ))}
        </div>

        <div className="mt-6 pt-5 border-t" style={{ borderColor: 'var(--sj-border-subtle)' }}>
          <div className="grid grid-cols-2 gap-2 mb-4">
            <button
              type="button"
              aria-pressed={formMode === 'login'}
              onClick={() => {
                setFormMode('login');
                setLocalValidation(null);
              }}
              className={formMode === 'login' ? 'sj-btn-primary' : 'sj-btn-outline'}
            >
              Masuk Akun
            </button>
            <button
              type="button"
              aria-pressed={formMode === 'register'}
              onClick={() => {
                setFormMode('register');
                setLocalValidation(null);
              }}
              className={formMode === 'register' ? 'sj-btn-primary' : 'sj-btn-outline'}
            >
              Daftar Akun Baru
            </button>
          </div>

          <form
            className="space-y-3"
            onSubmit={(e) => {
              e.preventDefault();
              if (!email.trim() || !email.includes('@')) {
                setLocalValidation('Masukkan alamat email yang valid terlebih dahulu.');
                return;
              }
              if (formMode === 'register') {
                if (nama.trim().length < 2) {
                  setLocalValidation('Masukkan nama lengkap minimal 2 huruf.');
                  return;
                }
                if (password.length < 6) {
                  setLocalValidation('Kata sandi pendaftaran minimal 6 karakter.');
                  return;
                }
                setLocalValidation(null);
                onRegister({ nama: nama.trim(), email: email.trim(), password, role, kabupaten });
                return;
              }
              if (password.length < 4) {
                setLocalValidation('Kata sandi minimal terdiri dari 4 karakter.');
                return;
              }
              setLocalValidation(null);
              onManualLogin(email.trim(), password);
            }}
          >
            {formMode === 'register' && (
              <>
                <div>
                  <label htmlFor="reg-nama" className="block text-xs font-bold mb-1">
                    Nama Lengkap
                  </label>
                  <input
                    id="reg-nama"
                    type="text"
                    value={nama}
                    onChange={(e) => setNama(e.target.value)}
                    placeholder="Contoh: Pak Darto"
                    className="sj-input"
                  />
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label htmlFor="reg-role" className="block text-xs font-bold mb-1">
                      Peran Akun
                    </label>
                    <select
                      id="reg-role"
                      value={role}
                      onChange={(e) => setRole(e.target.value as 'petani' | 'gudang' | 'pembeli')}
                      className="sj-input"
                    >
                      <option value="petani">Petani / Pengurus Poktan</option>
                      <option value="gudang">Pengelola Gudang SRG</option>
                      <option value="pembeli">Pembeli Siaga (Koperasi/SPPG)</option>
                    </select>
                  </div>
                  <div>
                    <label htmlFor="reg-kab" className="block text-xs font-bold mb-1">
                      Kabupaten / Kota
                    </label>
                    <select
                      id="reg-kab"
                      value={kabupaten}
                      onChange={(e) => setKabupaten(e.target.value)}
                      className="sj-input"
                    >
                      {Object.keys(JATENG_COORDS).map((k) => (
                        <option key={k} value={k}>
                          {k}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              </>
            )}

            <div>
              <label htmlFor="login-email" className="block text-xs font-bold mb-1">
                Alamat Email
              </label>
              <input
                id="login-email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Contoh: petani@demo.id"
                className="sj-input"
              />
            </div>
            <div>
              <label htmlFor="login-password" className="block text-xs font-bold mb-1">
                Kata Sandi
              </label>
              <input
                id="login-password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder={
                  formMode === 'register'
                    ? 'Minimal 6 karakter'
                    : 'Masukkan kata sandi akun (demo12345)'
                }
                className="sj-input"
              />
            </div>
            <button type="submit" disabled={busy} className="sj-btn-primary w-full">
              {busy
                ? 'Memproses akun...'
                : formMode === 'register'
                  ? 'Buat Akun & Masuk'
                  : 'Masuk ke Ruang Kerja'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
