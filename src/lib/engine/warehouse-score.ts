import type { CommodityParams, WarehouseChecklist } from '@/db/schema';
import { estimatedRoadDistanceKm, resolveCoordinates } from '@/lib/constants/regions';

export interface WarehouseScoreInput {
  warehouse: {
    id: string;
    nama: string;
    kabupaten: string;
    lat: number;
    lng: number;
    kapasitasKg: number;
    tersediaKg: number;
    tarifPerKgHari: number;
    minVolumeKg: number;
    minHari: number;
    isSrg: boolean;
    komoditasDiterima: string[];
    checklist: WarehouseChecklist;
  };
  commodityCode: string;
  commodityParams: CommodityParams;
  qtyDibutuhkan: number;
  farmerLocation: {
    kabupaten: string;
    lat?: number | null;
    lng?: number | null;
  };
}

export interface WarehouseScoreBreakdown {
  fasilitasWajib: number;
  kondisiDanSrg: number;
  jarak: number;
  tarif: number;
  kapasitas: number;
}

export interface WarehouseScoreResult {
  warehouseId: string;
  isEligible: boolean;
  ineligibleReason: string | null;
  totalScore: number;
  distanceKm: number;
  breakdown: WarehouseScoreBreakdown;
}

const clamp = (val: number, min: number, max: number) => Math.max(min, Math.min(max, val));

export function scoreWarehouse(input: WarehouseScoreInput): WarehouseScoreResult {
  const { warehouse, commodityCode, commodityParams, qtyDibutuhkan, farmerLocation } = input;
  const farmerCoord = resolveCoordinates(farmerLocation.kabupaten, farmerLocation.lat, farmerLocation.lng);
  const distanceKm = estimatedRoadDistanceKm(farmerCoord, { lat: warehouse.lat, lng: warehouse.lng });

  if (!warehouse.komoditasDiterima.includes(commodityCode)) {
    return {
      warehouseId: warehouse.id,
      isEligible: false,
      ineligibleReason: `Tidak menerima komoditas ${commodityCode}`,
      totalScore: 0,
      distanceKm,
      breakdown: { fasilitasWajib: 0, kondisiDanSrg: 0, jarak: 0, tarif: 0, kapasitas: 0 },
    };
  }

  if (warehouse.tersediaKg < qtyDibutuhkan) {
    return {
      warehouseId: warehouse.id,
      isEligible: false,
      ineligibleReason: `Kapasitas tersedia (${warehouse.tersediaKg.toLocaleString('id-ID')} kg) kurang dari kebutuhan`,
      totalScore: 0,
      distanceKm,
      breakdown: { fasilitasWajib: 0, kondisiDanSrg: 0, jarak: 0, tarif: 0, kapasitas: 0 },
    };
  }

  const checklistRecord = warehouse.checklist as unknown as Record<string, boolean>;
  const requiredList = commodityParams.fasilitas_wajib;
  const requiredMet = requiredList.filter((key) => Boolean(checklistRecord[key])).length;
  const fasilitasWajib = requiredList.length > 0 ? (requiredMet / requiredList.length) * 30 : 30;

  const allChecklistValues = Object.values(checklistRecord);
  const checklistMet = allChecklistValues.filter(Boolean).length;
  const checklistRatio = allChecklistValues.length > 0 ? checklistMet / allChecklistValues.length : 1;
  const kondisiDanSrg = checklistRatio * 25 + (warehouse.isSrg ? 5 : 0);

  const jarak = 15 * clamp((150 - distanceKm) / 140, 0, 1);

  const murah = commodityParams.tarif_sewa_murah;
  const mahal = Math.max(murah + 0.1, commodityParams.tarif_sewa_mahal);
  const tarif = 15 * clamp((mahal - warehouse.tarifPerKgHari) / (mahal - murah), 0, 1);

  const ratioCap = qtyDibutuhkan > 0 ? warehouse.tersediaKg / qtyDibutuhkan : 1.5;
  const kapasitas = ratioCap >= 1.5 ? 10 : 6 + 8 * clamp(ratioCap - 1, 0, 0.5);

  const breakdown: WarehouseScoreBreakdown = {
    fasilitasWajib: Number(fasilitasWajib.toFixed(1)),
    kondisiDanSrg: Number(kondisiDanSrg.toFixed(1)),
    jarak: Number(jarak.toFixed(1)),
    tarif: Number(tarif.toFixed(1)),
    kapasitas: Number(kapasitas.toFixed(1)),
  };

  const totalScore = Math.round(
    breakdown.fasilitasWajib +
      breakdown.kondisiDanSrg +
      breakdown.jarak +
      breakdown.tarif +
      breakdown.kapasitas
  );

  return {
    warehouseId: warehouse.id,
    isEligible: true,
    ineligibleReason: null,
    totalScore: clamp(totalScore, 0, 100),
    distanceKm,
    breakdown,
  };
}
