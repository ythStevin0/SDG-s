import type { CommodityParams } from '@/db/schema';

export type ReadinessStatus = 'LAYAK' | 'PERLU_PERBAIKAN' | 'BELUM_LAYAK';

export interface ReadinessResult {
  status: ReadinessStatus;
  reasons: string[];
  actions: string[];
}

export function evaluateStorageReadiness(
  metrics: { kadarAir: number; kotoranPct: number; rusakPct: number },
  params: CommodityParams
): ReadinessResult {
  const reasons: string[] = [];
  const actions: string[] = [];
  let severeCount = 0;

  if (metrics.kadarAir > params.kadar_air_maks_pct) {
    const diff = Number((metrics.kadarAir - params.kadar_air_maks_pct).toFixed(1));
    reasons.push(`Kadar air ${metrics.kadarAir}% melebihi batas ${params.kadar_air_maks_pct}%`);
    actions.push(`Jemur/keringkan terlebih dahulu hingga kadar air ≤ ${params.kadar_air_maks_pct}%`);
    if (diff > 4) severeCount++;
  }

  if (metrics.kotoranPct > params.kotoran_maks_pct) {
    reasons.push(`Kadar kotoran ${metrics.kotoranPct}% melebihi batas ${params.kotoran_maks_pct}%`);
    actions.push(`Lakukan pembersihan/ayak ulang hingga kotoran ≤ ${params.kotoran_maks_pct}%`);
    if (metrics.kotoranPct - params.kotoran_maks_pct > 2) severeCount++;
  }

  if (metrics.rusakPct > params.rusak_maks_pct) {
    reasons.push(`Butir rusak ${metrics.rusakPct}% melebihi batas ${params.rusak_maks_pct}%`);
    actions.push(`Sortir butir rusak/berjamur hingga ≤ ${params.rusak_maks_pct}%`);
    if (metrics.rusakPct - params.rusak_maks_pct > 3) severeCount++;
  }

  if (reasons.length === 0) {
    return {
      status: 'LAYAK',
      reasons: ['Seluruh indikator mutu memenuhi ambang standar simpan'],
      actions: ['Stok siap diajukan ke gudang SRG atau digabungkan ke Lot Kolektif'],
    };
  }

  return {
    status: severeCount > 0 ? 'BELUM_LAYAK' : 'PERLU_PERBAIKAN',
    reasons,
    actions,
  };
}
