package engine

import (
	"errors"
	"math"
	"sort"
)

type PriceSeriesPoint struct {
	Tanggal    string `json:"tanggal"`
	HargaPerKg int    `json:"hargaPerKg"`
}

type ForecastOutput struct {
	SelectedModel   string              `json:"selectedModel"`
	MapePct         float64             `json:"mapePct"`
	DataPointsCount int                 `json:"dataPointsCount"`
	LastDate        string              `json:"lastDate"`
	LowConfidence   bool                `json:"lowConfidence"`
	Predictions     []HorizonPrediction `json:"predictions"`
}

func predictWma4(series []float64, horizon int) []float64 {
	start := 0
	if len(series) > 4 {
		start = len(series) - 4
	}
	recent := series[start:]
	allWeights := []float64{0.1, 0.2, 0.3, 0.4}
	weights := allWeights[4-len(recent):]
	wSum := 0.0
	weighted := 0.0
	for i, val := range recent {
		wSum += weights[i]
		weighted += val * weights[i]
	}
	level := weighted / wSum
	out := make([]float64, horizon)
	for i := range out {
		out[i] = level
	}
	return out
}

func fitAndPredictHoltDamped(series []float64, horizon int, phi float64) []float64 {
	if len(series) < 3 {
		return predictWma4(series, horizon)
	}
	alphas := []float64{0.2, 0.5, 0.8}
	betas := []float64{0.1, 0.3, 0.5}
	bestErr := math.Inf(1)
	bestLevel := series[len(series)-1]
	bestTrend := 0.0

	for _, alpha := range alphas {
		for _, beta := range betas {
			level := series[0]
			trend := series[1] - series[0]
			sqErr := 0.0

			for i := 1; i < len(series); i++ {
				forecast1 := level + phi*trend
				err := series[i] - forecast1
				sqErr += err * err

				nextLevel := alpha*series[i] + (1.0-alpha)*(level+phi*trend)
				nextTrend := beta*(nextLevel-level) + (1.0-beta)*phi*trend
				level = nextLevel
				trend = nextTrend
			}

			if sqErr < bestErr {
				bestErr = sqErr
				bestLevel = level
				bestTrend = trend
			}
		}
	}

	out := make([]float64, 0, horizon)
	phiSum := 0.0
	for h := 1; h <= horizon; h++ {
		phiSum += math.Pow(phi, float64(h))
		out = append(out, math.Max(0, bestLevel+phiSum*bestTrend))
	}
	return out
}

func predictSeasonalMa(series []float64, horizon int, period int) []float64 {
	if len(series) < period+4 {
		return predictWma4(series, horizon)
	}
	sumAll := 0.0
	for _, v := range series {
		sumAll += v
	}
	meanAll := sumAll / float64(len(series))

	recentSum := 0.0
	for _, v := range series[len(series)-4:] {
		recentSum += v
	}
	recentLevel := recentSum / 4.0

	currentIdx := len(series) - 1
	currentPhase := currentIdx % period

	phaseSums := make([]float64, period)
	phaseCounts := make([]int, period)
	for idx, val := range series {
		p := idx % period
		phaseSums[p] += val / meanAll
		phaseCounts[p]++
	}

	phaseIndex := make([]float64, period)
	for p := 0; p < period; p++ {
		if phaseCounts[p] > 0 {
			phaseIndex[p] = phaseSums[p] / float64(phaseCounts[p])
		} else {
			phaseIndex[p] = 1.0
		}
	}

	currentFactor := phaseIndex[currentPhase]
	if currentFactor == 0 {
		currentFactor = 1.0
	}
	deseasonalized := recentLevel / currentFactor

	out := make([]float64, horizon)
	for i := 0; i < horizon; i++ {
		targetPhase := (currentIdx + i + 1) % period
		factor := phaseIndex[targetPhase]
		if factor == 0 {
			factor = 1.0
		}
		out[i] = math.Max(0, deseasonalized*factor)
	}
	return out
}

func runModel(model string, series []float64, horizon int) []float64 {
	switch model {
	case "WMA-4":
		return predictWma4(series, horizon)
	case "Holt-Damped":
		return fitAndPredictHoltDamped(series, horizon, 0.9)
	default:
		return predictSeasonalMa(series, horizon, 26)
	}
}

func GeneratePriceForecast(points []PriceSeriesPoint) (ForecastOutput, error) {
	if len(points) == 0 {
		return ForecastOutput{}, errors.New("data harga kosong")
	}

	sorted := make([]PriceSeriesPoint, len(points))
	copy(sorted, points)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Tanggal < sorted[j].Tanggal
	})

	values := make([]float64, len(sorted))
	for i, p := range sorted {
		values[i] = float64(p.HargaPerKg)
	}
	lastDate := sorted[len(sorted)-1].Tanggal
	lowConfidence := len(values) < 26

	candidates := []string{"WMA-4", "Holt-Damped"}
	if len(values) >= 52 {
		candidates = append(candidates, "Seasonal-MA")
	}

	horizons := []int{4, 8, 12}
	half := len(values) / 2
	if half < 6 {
		half = 6
	}
	minTrain := half
	if minTrain > 20 {
		minTrain = 20
	}
	maxOrigin := len(values) - 12

	selectedModel := candidates[0]
	bestMape := math.Inf(1)
	bestRmse := map[int]float64{4: 0, 8: 0, 12: 0}

	if maxOrigin > minTrain {
		for _, model := range candidates {
			totalAbsPct := 0.0
			countErr := 0
			sqErrs := map[int][]float64{4: nil, 8: nil, 12: nil}

			for origin := minTrain; origin <= maxOrigin; origin++ {
				train := values[:origin]
				preds := runModel(model, train, 12)
				for _, h := range horizons {
					actual := values[origin+h-1]
					pred := preds[h-1]
					if actual > 0 {
						totalAbsPct += math.Abs(actual-pred) / actual
						countErr++
					}
					diff := actual - pred
					sqErrs[h] = append(sqErrs[h], diff*diff)
				}
			}

			mape := 15.0
			if countErr > 0 {
				mape = (totalAbsPct / float64(countErr)) * 100.0
			}
			if mape < bestMape {
				bestMape = mape
				selectedModel = model
				for _, h := range horizons {
					sumSq := 0.0
					for _, sq := range sqErrs[h] {
						sumSq += sq
					}
					denom := len(sqErrs[h])
					if denom < 1 {
						denom = 1
					}
					bestRmse[h] = math.Sqrt(sumSq / float64(denom))
				}
			}
		}
	} else {
		bestMape = 12.0
		latest := values[len(values)-1]
		bestRmse[4] = latest * 0.06
		bestRmse[8] = latest * 0.09
		bestRmse[12] = latest * 0.12
	}

	finalPreds := runModel(selectedModel, values, 12)
	const z80 = 1.28

	predictions := make([]HorizonPrediction, 0, len(horizons))
	for _, h := range horizons {
		point := float64(jsRound(finalPreds[h-1]))
		margin := z80 * bestRmse[h]
		low := math.Max(0, float64(jsRound(point-margin)))
		high := float64(jsRound(point + margin))
		predictions = append(predictions, HorizonPrediction{
			HorizonWeeks: h,
			PricePoint:   point,
			PriceLow:     low,
			PriceHigh:    high,
		})
	}

	return ForecastOutput{
		SelectedModel:   selectedModel,
		MapePct:         round1(bestMape),
		DataPointsCount: len(values),
		LastDate:        lastDate,
		LowConfidence:   lowConfidence,
		Predictions:     predictions,
	}, nil
}
