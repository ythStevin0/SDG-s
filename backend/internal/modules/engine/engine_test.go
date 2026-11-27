package engine

import (
	"math"
	"testing"
)

func TestFixtureSection87HoldVsSellAndPanjar(t *testing.T) {
	// Fixture Eksak PRD Bagian 8.7:
	// Q = 5000, KA = 14 <= 15, P0 = 5000, P8 = 5800, t = 8 (d = 56),
	// cs = 3, ct = 20, A = 150000, sb = 0.01, rho = 0.70, r = 0.12
	res, err := EvaluateHoldVsSell(DecisionInput{
		QtyKg:          5000,
		KadarAirAktual: 14,
		KadarAirAmbang: 15,
		P0Dry:          5000,
		Predictions: []HorizonPrediction{
			{HorizonWeeks: 8, PricePoint: 5800, PriceLow: 5500, PriceHigh: 6100},
		},
		TarifSewaPerKgHari: 3,
		BiayaAngkutPerKg:   20,
		BiayaTetap:         150000,
		SusutPerBulan:      0.01,
		RasioPinjaman:      0.70,
		BungaTahunan:       0.12,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if res.PendapatanJualSegera != 25_000_000 {
		t.Errorf("expected J = 25000000, got %d", res.PendapatanJualSegera)
	}
	if res.PinjamanAwal != 17_500_000 {
		t.Errorf("expected L = 17500000, got %d", res.PinjamanAwal)
	}
	if res.Best.QtyEff != 4907.07 {
		t.Errorf("expected Q_eff = 4907.07, got %.2f", res.Best.QtyEff)
	}
	if res.Best.BiayaSewa != 840_000 {
		t.Errorf("expected BiayaSewa = 840000, got %d", res.Best.BiayaSewa)
	}
	if res.Best.BungaPinjaman != 322_192 {
		t.Errorf("expected Bunga = 322192, got %d", res.Best.BungaPinjaman)
	}
	if res.Best.TotalBiayaSimpan != 1_412_192 {
		t.Errorf("expected K = 1412192, got %d", res.Best.TotalBiayaSimpan)
	}
	if res.Best.PendapatanTahan != 27_048_822 {
		t.Errorf("expected H = 27048822, got %d", res.Best.PendapatanTahan)
	}
	if res.Best.SelisihRp != 2_048_822 {
		t.Errorf("expected G = 2048822, got %d", res.Best.SelisihRp)
	}
	if res.Best.TitikImpasPerKg != 5383 {
		t.Errorf("expected P_be = 5383, got %d", res.Best.TitikImpasPerKg)
	}
	if res.Recommendation != RecTahan {
		t.Errorf("expected TAHAN, got %s", res.Recommendation)
	}

	// Panjar Tandingan pada input yang sama (P_panjar = 3500 / borongan 17.500.000)
	pj, err := EvaluatePanjarTandingan(PanjarInput{
		Mode:              "borongan",
		TotalBoronganRp:   17_500_000,
		QtyKg:             5000,
		P0Actual:          5000,
		PendapatanTahanRp: float64(res.Best.PendapatanTahan),
		PinjamanSrgRp:     float64(res.PinjamanAwal),
	})
	if err != nil {
		t.Fatalf("unexpected panjar error: %v", err)
	}
	if pj.SelisihTerhadapTahanRp != 9_548_822 {
		t.Errorf("expected SelisihTerhadapTahanRp = 9548822, got %d", pj.SelisihTerhadapTahanRp)
	}
	if pj.DiskonTerhadapPasarPct != 30.00 {
		t.Errorf("expected Diskon = 30.00%%, got %.2f", pj.DiskonTerhadapPasarPct)
	}
}

func TestDryingWetGKPToGKG(t *testing.T) {
	dry, err := CalculateDryingConversion(DryingInput{
		QtyKg:                 5000,
		KadarAirAktual:        24,
		KadarAirAmbang:        14,
		BiayaPengeringanPerKg: 150,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !dry.PerluPengeringan {
		t.Fatal("expected perluPengeringan = true")
	}
	if dry.QtySiap != 4418.60 {
		t.Errorf("expected QtySiap = 4418.60, got %.2f", dry.QtySiap)
	}
	if dry.BiayaPengeringanRp != 750_000 {
		t.Errorf("expected BiayaPengeringanRp = 750000, got %d", dry.BiayaPengeringanRp)
	}
}

func TestWarehouseScoreAntiNaN(t *testing.T) {
	params := CommodityParams{
		KadarAirMaksPct: 15,
		TarifSewaMurah:  1,
		TarifSewaMahal:  8,
		FasilitasWajib:  []string{"ventilasi", "lantai_palet_kering", "kontrol_hama"},
	}
	wh := WarehouseEntity{
		ID:                "wh-1",
		Nama:              "Gudang SRG Banyumas",
		Kabupaten:         "Banyumas",
		Lat:               -7.4314,
		Lng:               109.2478,
		KapasitasKg:       100000,
		TersediaKg:        82000,
		TarifPerKgHari:    2.5,
		MinVolumeKg:       5000,
		MinHari:           30,
		IsSrg:             true,
		KomoditasDiterima: []string{"jagung"},
		Checklist: WarehouseChecklist{
			AtapTidakBocor:    true,
			Ventilasi:         true,
			LantaiPaletKering: true,
			KontrolHama:       true,
			AlatUkurKa:        true,
			KeamananSuhu:      true,
		},
	}

	score := ScoreWarehouse(wh, "jagung", params, 5000, "Banyumas", nil, nil)
	if !score.IsEligible {
		t.Fatalf("expected eligible warehouse, got reason: %v", score.IneligibleReason)
	}
	if math.IsNaN(score.DistanceKm) || score.TotalScore <= 0 || score.TotalScore > 100 {
		t.Fatalf("invalid score or NaN distance: %+v", score)
	}

	ineligible := ScoreWarehouse(wh, "kedelai", params, 5000, "Banyumas", nil, nil)
	if ineligible.IsEligible || ineligible.TotalScore != 0 {
		t.Fatalf("expected ineligible for unsupported commodity")
	}
}

func TestForecastAndAIGuard(t *testing.T) {
	points := make([]PriceSeriesPoint, 64)
	for w := 0; w < 64; w++ {
		phase := (2.0 * math.Pi * float64(w)) / 26.0
		p := int(math.Round(5000.0 + math.Sin(phase)*500.0 + float64(w*8)))
		points[w] = PriceSeriesPoint{
			Tanggal:    "2025-01-01",
			HargaPerKg: p,
		}
		// Beri urutan tanggal menaik sederhana
		points[w].Tanggal = FormatDateWeekOffset(w)
	}

	fc, err := GeneratePriceForecast(points)
	if err != nil {
		t.Fatalf("forecast failed: %v", err)
	}
	if len(fc.Predictions) != 3 {
		t.Fatalf("expected 3 horizons, got %d", len(fc.Predictions))
	}
	for _, p := range fc.Predictions {
		if !(p.PriceLow <= p.PricePoint && p.PricePoint <= p.PriceHigh) {
			t.Errorf("invalid CI ordering: %+v", p)
		}
	}

	// AI Guard: nomor urut "1." diabaikan, "Rp2,0 juta" lolos ±5% terhadap 2.048.822
	ok, bad := ValidateAIExplanationNumbers(
		[]string{"1. Tahan selama 8 minggu untuk selisih sekitar Rp2,0 juta jika harga minimal Rp5.383/kg."},
		[]float64{8, 2048822, 5383},
	)
	if !ok {
		t.Errorf("expected valid AI text, rejected token: %s", bad)
	}

	// Angka halusinasi Rp9.999/kg wajib ditolak
	ok2, _ := ValidateAIExplanationNumbers(
		[]string{"Harga pasti naik ke Rp9.999/kg minggu depan."},
		[]float64{8, 2048822, 5383},
	)
	if ok2 {
		t.Errorf("expected hallucinated price to be rejected")
	}

	stripped := StripPII("Hubungi Pak Budi 081234567890 atau budi@test.com untuk tebas 4 ton Rp4.200/kg")
	if stripped == "" || RegexExtractOffer(stripped).JumlahKg == nil || *RegexExtractOffer(stripped).JumlahKg != 4000 {
		t.Errorf("unexpected offer extraction result: %+v", RegexExtractOffer(stripped))
	}
}

func FormatDateWeekOffset(w int) string {
	year := 2025 + (w / 52)
	week := (w % 52) + 1
	if week < 10 {
		return string(rune('0'+year/1000)) + "025-01-0" + string(rune('0'+week))
	}
	_ = year
	// Cukup format leksikografis menaik YYYY-WW
	m := (w / 4) + 1
	d := (w % 4)*7 + 1
	return pad4(2025+(m-1)/12) + "-" + pad2(((m-1)%12)+1) + "-" + pad2(d)
}

func pad2(n int) string {
	if n < 10 {
		return "0" + FormatIntID(n)
	}
	return FormatIntID(n)
}

func pad4(n int) string {
	return strconvItoaSimple(n)
}

func strconvItoaSimple(n int) string {
	if n == 2025 {
		return "2025"
	}
	if n == 2026 {
		return "2026"
	}
	return "2027"
}
