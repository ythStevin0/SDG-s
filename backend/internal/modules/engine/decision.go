package engine

import (
	"errors"
	"fmt"
	"math"
	"strconv"
	"strings"
)

type RecommendationStatus string

const (
	RecTahan         RecommendationStatus = "TAHAN"
	RecTahanBerisiko RecommendationStatus = "TAHAN_BERISIKO"
	RecJual          RecommendationStatus = "JUAL"
)

type HorizonPrediction struct {
	HorizonWeeks int     `json:"horizonWeeks"`
	PricePoint   float64 `json:"pricePoint"`
	PriceLow     float64 `json:"priceLow"`
	PriceHigh    float64 `json:"priceHigh"`
}

type DecisionInput struct {
	QtyKg                 float64             `json:"qtyKg"`
	KadarAirAktual        float64             `json:"kadarAirAktual"`
	KadarAirAmbang        float64             `json:"kadarAirAmbang"`
	BiayaPengeringanPerKg *float64            `json:"biayaPengeringanPerKg,omitempty"`
	P0Dry                 float64             `json:"p0Dry"`
	P0Actual              *float64            `json:"p0Actual,omitempty"`
	Predictions           []HorizonPrediction `json:"predictions"`
	TarifSewaPerKgHari    float64             `json:"tarifSewaPerKgHari"`
	BiayaAngkutPerKg      float64             `json:"biayaAngkutPerKg"`
	BiayaTetap            float64             `json:"biayaTetap"`
	SusutPerBulan         float64             `json:"susutPerBulan"`
	RasioPinjaman         float64             `json:"rasioPinjaman"`
	BungaTahunan          float64             `json:"bungaTahunan"`
}

type HorizonEvaluation struct {
	HorizonWeeks     int     `json:"horizonWeeks"`
	Days             int     `json:"days"`
	SusutSimpanPct   float64 `json:"susutSimpanPct"`
	QtyEff           float64 `json:"qtyEff"`
	BiayaSewa        int     `json:"biayaSewa"`
	BiayaAngkut      int     `json:"biayaAngkut"`
	BiayaTetap       int     `json:"biayaTetap"`
	BiayaPengeringan int     `json:"biayaPengeringan"`
	BungaPinjaman    int     `json:"bungaPinjaman"`
	TotalBiayaSimpan int     `json:"totalBiayaSimpan"`
	PendapatanTahan  int     `json:"pendapatanTahan"`
	SelisihRp        int     `json:"selisihRp"`
	SelisihPct       float64 `json:"selisihPct"`
	SelisihLowRp     int     `json:"selisihLowRp"`
	TitikImpasPerKg  int     `json:"titikImpasPerKg"`
}

type DecisionResult struct {
	Recommendation       RecommendationStatus `json:"recommendation"`
	BestHorizonWeeks     int                  `json:"bestHorizonWeeks"`
	PendapatanJualSegera int                  `json:"pendapatanJualSegera"`
	PinjamanAwal         int                  `json:"pinjamanAwal"`
	QtySiap              float64              `json:"qtySiap"`
	PerluPengeringan     bool                 `json:"perluPengeringan"`
	SusutPengeringanKg   float64              `json:"susutPengeringanKg"`
	Best                 HorizonEvaluation    `json:"best"`
	AllHorizons          []HorizonEvaluation  `json:"allHorizons"`
	SummarySentence      string               `json:"summarySentence"`
}

func FormatIntID(n int) string {
	neg := n < 0
	if neg {
		n = -n
	}
	s := strconv.Itoa(n)
	var out []string
	for len(s) > 3 {
		out = append([]string{s[len(s)-3:]}, out...)
		s = s[:len(s)-3]
	}
	out = append([]string{s}, out...)
	joined := strings.Join(out, ".")
	if neg {
		return "-" + joined
	}
	return joined
}

func EvaluateHoldVsSell(in DecisionInput) (DecisionResult, error) {
	if in.QtyKg <= 0 {
		return DecisionResult{}, errors.New("qtyKg harus lebih besar dari 0")
	}
	if in.P0Dry <= 0 {
		return DecisionResult{}, errors.New("harga pasar saat ini harus positif")
	}
	if len(in.Predictions) == 0 {
		return DecisionResult{}, errors.New("minimal satu horizon prediksi diperlukan")
	}

	cDryPerKg := 150.0
	if in.BiayaPengeringanPerKg != nil {
		cDryPerKg = *in.BiayaPengeringanPerKg
	}

	drying, err := CalculateDryingConversion(DryingInput{
		QtyKg:                 in.QtyKg,
		KadarAirAktual:        in.KadarAirAktual,
		KadarAirAmbang:        in.KadarAirAmbang,
		BiayaPengeringanPerKg: cDryPerKg,
	})
	if err != nil {
		return DecisionResult{}, err
	}

	p0Actual := in.P0Dry
	if in.P0Actual != nil && *in.P0Actual > 0 {
		p0Actual = *in.P0Actual
	}

	jRaw := in.QtyKg * p0Actual
	loanRaw := in.RasioPinjaman * (drying.QtySiapRaw * in.P0Dry)
	cDryRaw := 0.0
	if drying.PerluPengeringan {
		cDryRaw = in.QtyKg * math.Max(0, cDryPerKg)
	}

	evaluations := make([]HorizonEvaluation, 0, len(in.Predictions))
	for _, pred := range in.Predictions {
		days := pred.HorizonWeeks * 7
		sCumRaw := 1.0 - math.Pow(1.0-in.SusutPerBulan, float64(days)/30.0)
		qEffRaw := drying.QtySiapRaw * (1.0 - sCumRaw)

		sewaRaw := drying.QtySiapRaw * in.TarifSewaPerKgHari * float64(days)
		angkutRaw := drying.QtySiapRaw * in.BiayaAngkutPerKg
		bungaRaw := loanRaw * in.BungaTahunan * (float64(days) / 365.0)
		totalCostRaw := cDryRaw + sewaRaw + angkutRaw + in.BiayaTetap + bungaRaw

		holdRevRaw := qEffRaw*pred.PricePoint - totalCostRaw
		gainRaw := holdRevRaw - jRaw
		lowRevRaw := qEffRaw*pred.PriceLow - totalCostRaw
		lowGainRaw := lowRevRaw - jRaw

		// Pembulatan hanya di output akhir; titik impas memakai Math.Ceil agar G >= 0 terjamin
		breakEven := int(math.Ceil((jRaw + totalCostRaw) / qEffRaw))

		selisihPct := 0.0
		if jRaw > 0 {
			selisihPct = round2((gainRaw / jRaw) * 100.0)
		}

		evaluations = append(evaluations, HorizonEvaluation{
			HorizonWeeks:     pred.HorizonWeeks,
			Days:             days,
			SusutSimpanPct:   round2(sCumRaw * 100.0),
			QtyEff:           round2(qEffRaw),
			BiayaSewa:        jsRound(sewaRaw),
			BiayaAngkut:      jsRound(angkutRaw),
			BiayaTetap:       jsRound(in.BiayaTetap),
			BiayaPengeringan: jsRound(cDryRaw),
			BungaPinjaman:    jsRound(bungaRaw),
			TotalBiayaSimpan: jsRound(totalCostRaw),
			PendapatanTahan:  jsRound(holdRevRaw),
			SelisihRp:        jsRound(gainRaw),
			SelisihPct:       selisihPct,
			SelisihLowRp:     jsRound(lowGainRaw),
			TitikImpasPerKg:  breakEven,
		})
	}

	best := evaluations[0]
	for _, cur := range evaluations[1:] {
		if cur.SelisihRp > best.SelisihRp {
			best = cur
		}
	}

	rec := RecJual
	if best.SelisihRp > 0 && best.SelisihLowRp > 0 {
		rec = RecTahan
	} else if best.SelisihRp > 0 {
		rec = RecTahanBerisiko
	}

	formattedBe := FormatIntID(best.TitikImpasPerKg)
	var summary string
	if rec == RecJual {
		summary = fmt.Sprintf("Menahan stok belum menutup biaya simpan. Jual sekarang lebih aman kecuali harga naik di atas Rp%s/kg.", formattedBe)
	} else {
		summary = fmt.Sprintf("Menahan %d minggu layak bila harga jual mencapai minimal Rp%s/kg.", best.HorizonWeeks, formattedBe)
	}

	return DecisionResult{
		Recommendation:       rec,
		BestHorizonWeeks:     best.HorizonWeeks,
		PendapatanJualSegera: jsRound(jRaw),
		PinjamanAwal:         jsRound(loanRaw),
		QtySiap:              drying.QtySiap,
		PerluPengeringan:     drying.PerluPengeringan,
		SusutPengeringanKg:   drying.SusutPengeringanKg,
		Best:                 best,
		AllHorizons:          evaluations,
		SummarySentence:      summary,
	}, nil
}
