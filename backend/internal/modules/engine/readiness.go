package engine

import "fmt"

type CommodityParams struct {
	KadarAirMaksPct       float64  `json:"kadar_air_maks_pct"`
	KotoranMaksPct        float64  `json:"kotoran_maks_pct"`
	RusakMaksPct          float64  `json:"rusak_maks_pct"`
	SusutPerBulan         float64  `json:"susut_per_bulan"`
	SusutRumahPerBulan    float64  `json:"susut_rumah_per_bulan"`
	BiayaPengeringanPerKg float64  `json:"biaya_pengeringan_per_kg"`
	TarifSewaMurah        float64  `json:"tarif_sewa_murah"`
	TarifSewaMahal        float64  `json:"tarif_sewa_mahal"`
	FasilitasWajib        []string `json:"fasilitas_wajib"`
}

type ReadinessResult struct {
	Status  string   `json:"status"` // LAYAK | PERLU_PERBAIKAN | BELUM_LAYAK
	Reasons []string `json:"reasons"`
	Actions []string `json:"actions"`
}

func EvaluateStorageReadiness(kadarAir, kotoranPct, rusakPct float64, params CommodityParams) ReadinessResult {
	var reasons []string
	var actions []string
	severeCount := 0

	if kadarAir > params.KadarAirMaksPct {
		diff := round1(kadarAir - params.KadarAirMaksPct)
		reasons = append(reasons, fmt.Sprintf("Kadar air %.1f%% melebihi batas %.1f%%", kadarAir, params.KadarAirMaksPct))
		actions = append(actions, fmt.Sprintf("Jemur/keringkan terlebih dahulu hingga kadar air ≤ %.1f%%", params.KadarAirMaksPct))
		if diff > 4.0 {
			severeCount++
		}
	}

	if kotoranPct > params.KotoranMaksPct {
		reasons = append(reasons, fmt.Sprintf("Kadar kotoran %.1f%% melebihi batas %.1f%%", kotoranPct, params.KotoranMaksPct))
		actions = append(actions, fmt.Sprintf("Lakukan pembersihan/ayak ulang hingga kotoran ≤ %.1f%%", params.KotoranMaksPct))
		if kotoranPct-params.KotoranMaksPct > 2.0 {
			severeCount++
		}
	}

	if rusakPct > params.RusakMaksPct {
		reasons = append(reasons, fmt.Sprintf("Butir rusak %.1f%% melebihi batas %.1f%%", rusakPct, params.RusakMaksPct))
		actions = append(actions, fmt.Sprintf("Sortir butir rusak/berjamur hingga ≤ %.1f%%", params.RusakMaksPct))
		if rusakPct-params.RusakMaksPct > 3.0 {
			severeCount++
		}
	}

	if len(reasons) == 0 {
		return ReadinessResult{
			Status:  "LAYAK",
			Reasons: []string{"Seluruh indikator mutu memenuhi ambang standar simpan"},
			Actions: []string{"Stok siap diajukan ke gudang SRG atau digabungkan ke Lot Kolektif"},
		}
	}

	status := "PERLU_PERBAIKAN"
	if severeCount > 0 {
		status = "BELUM_LAYAK"
	}
	return ReadinessResult{
		Status:  status,
		Reasons: reasons,
		Actions: actions,
	}
}
