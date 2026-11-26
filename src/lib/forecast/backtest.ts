import type { HorizonPrediction } from '@/lib/engine/decision';

export type ForecastModelName = 'WMA-4' | 'Holt-Damped' | 'Seasonal-MA';

export interface PriceSeriesPoint {
  tanggal: string;
  hargaPerKg: number;
}

export interface ForecastOutput {
  selectedModel: ForecastModelName;
  mapePct: number;
  dataPointsCount: number;
  lastDate: string;
  lowConfidence: boolean;
  predictions: HorizonPrediction[];
}

function predictWma4(series: number[], horizon: number): number[] {
  const recent = series.slice(-4);
  const weights = [0.1, 0.2, 0.3, 0.4].slice(4 - recent.length);
  const wSum = weights.reduce((a, b) => a + b, 0);
  const level = recent.reduce((sum, val, idx) => sum + val * weights[idx], 0) / wSum;
  return Array.from({ length: horizon }, () => level);
}

function fitAndPredictHoltDamped(series: number[], horizon: number, phi = 0.9): number[] {
  if (series.length < 3) return predictWma4(series, horizon);

  const alphas = [0.2, 0.5, 0.8];
  const betas = [0.1, 0.3, 0.5];
  let bestErr = Number.POSITIVE_INFINITY;
  let bestLevel = series[series.length - 1];
  let bestTrend = 0;

  for (const alpha of alphas) {
    for (const beta of betas) {
      let level = series[0];
      let trend = series[1] - series[0];
      let sqErr = 0;

      for (let i = 1; i < series.length; i++) {
        const forecast1 = level + phi * trend;
        const err = series[i] - forecast1;
        sqErr += err * err;

        const nextLevel = alpha * series[i] + (1 - alpha) * (level + phi * trend);
        const nextTrend = beta * (nextLevel - level) + (1 - beta) * phi * trend;
        level = nextLevel;
        trend = nextTrend;
      }

      if (sqErr < bestErr) {
        bestErr = sqErr;
        bestLevel = level;
        bestTrend = trend;
      }
    }
  }

  const out: number[] = [];
  let phiSum = 0;
  for (let h = 1; h <= horizon; h++) {
    phiSum += Math.pow(phi, h);
    out.push(Math.max(0, bestLevel + phiSum * bestTrend));
  }
  return out;
}

function predictSeasonalMa(series: number[], horizon: number, period = 26): number[] {
  if (series.length < period + 4) {
    return predictWma4(series, horizon);
  }
  // Hitung rata-rata bergerak dasar dan rasio musiman per fase
  const meanAll = series.reduce((a, b) => a + b, 0) / series.length;
  const recentLevel = series.slice(-4).reduce((a, b) => a + b, 0) / 4;
  const currentIdx = series.length - 1;
  const currentPhase = currentIdx % period;

  const phaseSums = new Array<number>(period).fill(0);
  const phaseCounts = new Array<number>(period).fill(0);
  series.forEach((val, idx) => {
    const p = idx % period;
    phaseSums[p] += val / meanAll;
    phaseCounts[p] += 1;
  });

  const phaseIndex = phaseSums.map((s, p) => (phaseCounts[p] > 0 ? s / phaseCounts[p] : 1));
  const currentSeasonFactor = phaseIndex[currentPhase] || 1;
  const deseasonalizedLevel = recentLevel / currentSeasonFactor;

  return Array.from({ length: horizon }, (_, idx) => {
    const targetPhase = (currentIdx + idx + 1) % period;
    return Math.max(0, deseasonalizedLevel * (phaseIndex[targetPhase] || 1));
  });
}

function runModel(model: ForecastModelName, series: number[], horizon: number): number[] {
  if (model === 'WMA-4') return predictWma4(series, horizon);
  if (model === 'Holt-Damped') return fitAndPredictHoltDamped(series, horizon, 0.9);
  return predictSeasonalMa(series, horizon, 26);
}

export function generatePriceForecast(points: PriceSeriesPoint[]): ForecastOutput {
  if (points.length === 0) {
    throw new Error('Data harga kosong');
  }

  const sorted = [...points].sort((a, b) => a.tanggal.localeCompare(b.tanggal));
  const values = sorted.map((p) => p.hargaPerKg);
  const lastDate = sorted[sorted.length - 1].tanggal;
  const lowConfidence = values.length < 26;

  const candidates: ForecastModelName[] =
    values.length >= 52 ? ['WMA-4', 'Holt-Damped', 'Seasonal-MA'] : ['WMA-4', 'Holt-Damped'];

  const horizons: Array<4 | 8 | 12> = [4, 8, 12];
  const minTrain = Math.min(20, Math.max(6, Math.floor(values.length * 0.5)));
  const maxOrigin = values.length - 12;

  let selectedModel: ForecastModelName = candidates[0];
  let bestMape = Number.POSITIVE_INFINITY;
  let bestRmseByHorizon: Record<4 | 8 | 12, number> = { 4: 0, 8: 0, 12: 0 };

  if (maxOrigin > minTrain) {
    for (const model of candidates) {
      let totalAbsPct = 0;
      let countErr = 0;
      const sqErrs: Record<4 | 8 | 12, number[]> = { 4: [], 8: [], 12: [] };

      for (let origin = minTrain; origin <= maxOrigin; origin++) {
        const train = values.slice(0, origin);
        const preds = runModel(model, train, 12);
        for (const h of horizons) {
          const actual = values[origin + h - 1];
          const pred = preds[h - 1];
          if (actual > 0) {
            totalAbsPct += Math.abs(actual - pred) / actual;
            countErr++;
          }
          sqErrs[h].push((actual - pred) * (actual - pred));
        }
      }

      const mape = countErr > 0 ? (totalAbsPct / countErr) * 100 : 15;
      if (mape < bestMape) {
        bestMape = mape;
        selectedModel = model;
        bestRmseByHorizon = {
          4: Math.sqrt(sqErrs[4].reduce((a, b) => a + b, 0) / Math.max(1, sqErrs[4].length)),
          8: Math.sqrt(sqErrs[8].reduce((a, b) => a + b, 0) / Math.max(1, sqErrs[8].length)),
          12: Math.sqrt(sqErrs[12].reduce((a, b) => a + b, 0) / Math.max(1, sqErrs[12].length)),
        };
      }
    }
  } else {
    bestMape = 12;
    const latest = values[values.length - 1];
    bestRmseByHorizon = { 4: latest * 0.06, 8: latest * 0.09, 12: latest * 0.12 };
  }

  const finalPreds = runModel(selectedModel, values, 12);
  const z80 = 1.28;

  const predictions: HorizonPrediction[] = horizons.map((h) => {
    const point = Math.round(finalPreds[h - 1]);
    const margin = z80 * bestRmseByHorizon[h];
    return {
      horizonWeeks: h,
      pricePoint: point,
      priceLow: Math.max(0, Math.round(point - margin)),
      priceHigh: Math.round(point + margin),
    };
  });

  return {
    selectedModel,
    mapePct: Number(bestMape.toFixed(1)),
    dataPointsCount: values.length,
    lastDate,
    lowConfidence,
    predictions,
  };
}
