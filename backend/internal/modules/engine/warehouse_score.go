package engine

import (
	"fmt"
	"math"
)

type WarehouseChecklist struct {
	AtapTidakBocor    bool `json:"atap_tidak_bocor"`
	Ventilasi         bool `json:"ventilasi"`
	LantaiPaletKering bool `json:"lantai_palet_kering"`
	KontrolHama       bool `json:"kontrol_hama"`
	AlatUkurKa        bool `json:"alat_ukur_ka"`
	KeamananSuhu      bool `json:"keamanan_suhu"`
}

func (wc WarehouseChecklist) Map() map[string]bool {
	return map[string]bool{
		"atap_tidak_bocor":    wc.AtapTidakBocor,
		"ventilasi":           wc.Ventilasi,
		"lantai_palet_kering": wc.LantaiPaletKering,
		"kontrol_hama":        wc.KontrolHama,
		"alat_ukur_ka":        wc.AlatUkurKa,
		"keamanan_suhu":       wc.KeamananSuhu,
	}
}

type WarehouseEntity struct {
	ID                string             `json:"id"`
	Nama              string             `json:"nama"`
	Kabupaten         string             `json:"kabupaten"`
	Lat               float64            `json:"lat"`
	Lng               float64            `json:"lng"`
	KapasitasKg       float64            `json:"kapasitasKg"`
	TersediaKg        float64            `json:"tersediaKg"`
	TarifPerKgHari    float64            `json:"tarifPerKgHari"`
	MinVolumeKg       float64            `json:"minVolumeKg"`
	MinHari           int                `json:"minHari"`
	IsSrg             bool               `json:"isSrg"`
	KomoditasDiterima []string           `json:"komoditasDiterima"`
	Checklist         WarehouseChecklist `json:"checklist"`
}

type WarehouseScoreBreakdown struct {
	FasilitasWajib float64 `json:"fasilitasWajib"`
	KondisiDanSrg  float64 `json:"kondisiDanSrg"`
	Jarak          float64 `json:"jarak"`
	Tarif          float64 `json:"tarif"`
	Kapasitas      float64 `json:"kapasitas"`
}

type WarehouseScoreResult struct {
	WarehouseID      string                  `json:"warehouseId"`
	IsEligible       bool                    `json:"isEligible"`
	IneligibleReason *string                 `json:"ineligibleReason"`
	TotalScore       int                     `json:"totalScore"`
	DistanceKm       float64                 `json:"distanceKm"`
	Breakdown        WarehouseScoreBreakdown `json:"breakdown"`
}

// ScoreWarehouse menghasilkan skor kelayakan gudang deterministik 0-100 yang dijamin bebas NaN.
func ScoreWarehouse(wh WarehouseEntity, commodityCode string, params CommodityParams, qtyDibutuhkan float64, farmerKab string, farmerLat, farmerLng *float64) WarehouseScoreResult {
	fLat, fLng := ResolveCoordinates(farmerKab, farmerLat, farmerLng)
	distanceKm := EstimatedRoadDistanceKm(fLat, fLng, wh.Lat, wh.Lng)

	supportsCommodity := false
	for _, c := range wh.KomoditasDiterima {
		if c == commodityCode {
			supportsCommodity = true
			break
		}
	}
	if !supportsCommodity {
		reason := fmt.Sprintf("Tidak menerima komoditas %s", commodityCode)
		return WarehouseScoreResult{
			WarehouseID:      wh.ID,
			IsEligible:       false,
			IneligibleReason: &reason,
			TotalScore:       0,
			DistanceKm:       distanceKm,
		}
	}

	if wh.TersediaKg < qtyDibutuhkan {
		reason := fmt.Sprintf("Kapasitas tersedia (%s kg) kurang dari kebutuhan", FormatIntID(int(math.Round(wh.TersediaKg))))
		return WarehouseScoreResult{
			WarehouseID:      wh.ID,
			IsEligible:       false,
			IneligibleReason: &reason,
			TotalScore:       0,
			DistanceKm:       distanceKm,
		}
	}

	checkMap := wh.Checklist.Map()
	reqMet := 0
	for _, k := range params.FasilitasWajib {
		if checkMap[k] {
			reqMet++
		}
	}
	fasilitasWajib := 30.0
	if len(params.FasilitasWajib) > 0 {
		fasilitasWajib = (float64(reqMet) / float64(len(params.FasilitasWajib))) * 30.0
	}

	totalChecks := len(checkMap)
	metChecks := 0
	for _, v := range checkMap {
		if v {
			metChecks++
		}
	}
	checklistRatio := 1.0
	if totalChecks > 0 {
		checklistRatio = float64(metChecks) / float64(totalChecks)
	}
	srgBonus := 0.0
	if wh.IsSrg {
		srgBonus = 5.0
	}
	kondisiDanSrg := checklistRatio*25.0 + srgBonus

	jarak := 15.0 * clamp((150.0-distanceKm)/140.0, 0.0, 1.0)

	murah := params.TarifSewaMurah
	mahal := math.Max(murah+0.1, params.TarifSewaMahal)
	tarif := 15.0 * clamp((mahal-wh.TarifPerKgHari)/(mahal-murah), 0.0, 1.0)

	ratioCap := 1.5
	if qtyDibutuhkan > 0 {
		ratioCap = wh.TersediaKg / qtyDibutuhkan
	}
	kapasitas := 10.0
	if ratioCap < 1.5 {
		kapasitas = 6.0 + 8.0*clamp(ratioCap-1.0, 0.0, 0.5)
	}

	bd := WarehouseScoreBreakdown{
		FasilitasWajib: round1(fasilitasWajib),
		KondisiDanSrg:  round1(kondisiDanSrg),
		Jarak:          round1(jarak),
		Tarif:          round1(tarif),
		Kapasitas:      round1(kapasitas),
	}

	rawTotal := bd.FasilitasWajib + bd.KondisiDanSrg + bd.Jarak + bd.Tarif + bd.Kapasitas
	total := int(clamp(float64(jsRound(rawTotal)), 0, 100))

	return WarehouseScoreResult{
		WarehouseID:      wh.ID,
		IsEligible:       true,
		IneligibleReason: nil,
		TotalScore:       total,
		DistanceKm:       distanceKm,
		Breakdown:        bd,
	}
}
