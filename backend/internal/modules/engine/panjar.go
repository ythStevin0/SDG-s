package engine

import "errors"

type PanjarInput struct {
	Mode              string  `json:"mode"` // "per_kg" | "borongan"
	HargaPanjarPerKg  float64 `json:"hargaPanjarPerKg"`
	TotalBoronganRp   float64 `json:"totalBoronganRp"`
	QtyKg             float64 `json:"qtyKg"`
	P0Actual          float64 `json:"p0Actual"`
	PendapatanTahanRp float64 `json:"pendapatanTahanRp"`
	PinjamanSrgRp     float64 `json:"pinjamanSrgRp"`
}

type PanjarResult struct {
	HargaPanjarPerKg        int     `json:"hargaPanjarPerKg"`
	PendapatanPanjarRp      int     `json:"pendapatanPanjarRp"`
	PendapatanTahanRp       int     `json:"pendapatanTahanRp"`
	SelisihTerhadapTahanRp  int     `json:"selisihTerhadapTahanRp"`
	SelisihTerhadapTahanPct float64 `json:"selisihTerhadapTahanPct"`
	DiskonTerhadapPasarPct  float64 `json:"diskonTerhadapPasarPct"`
	TunaiHariIniPanjarRp    int     `json:"tunaiHariIniPanjarRp"`
	TunaiHariIniSrgRp       int     `json:"tunaiHariIniSrgRp"`
}

func EvaluatePanjarTandingan(in PanjarInput) (PanjarResult, error) {
	if in.QtyKg <= 0 {
		return PanjarResult{}, errors.New("qtyKg harus lebih besar dari 0")
	}
	if in.P0Actual <= 0 {
		return PanjarResult{}, errors.New("harga pasar saat ini harus positif")
	}

	var pendapatanPanjarRaw, hargaPanjarPerKgRaw float64
	if in.Mode == "borongan" {
		if in.TotalBoronganRp <= 0 {
			return PanjarResult{}, errors.New("total tawaran borongan harus positif")
		}
		pendapatanPanjarRaw = in.TotalBoronganRp
		hargaPanjarPerKgRaw = in.TotalBoronganRp / in.QtyKg
	} else {
		if in.HargaPanjarPerKg <= 0 {
			return PanjarResult{}, errors.New("harga panjar per kg harus positif")
		}
		hargaPanjarPerKgRaw = in.HargaPanjarPerKg
		pendapatanPanjarRaw = in.HargaPanjarPerKg * in.QtyKg
	}

	selisihRp := in.PendapatanTahanRp - pendapatanPanjarRaw
	selisihPct := 0.0
	if pendapatanPanjarRaw > 0 {
		selisihPct = round2((selisihRp / pendapatanPanjarRaw) * 100.0)
	}
	diskonPct := round2(((in.P0Actual - hargaPanjarPerKgRaw) / in.P0Actual) * 100.0)

	return PanjarResult{
		HargaPanjarPerKg:        jsRound(hargaPanjarPerKgRaw),
		PendapatanPanjarRp:      jsRound(pendapatanPanjarRaw),
		PendapatanTahanRp:       jsRound(in.PendapatanTahanRp),
		SelisihTerhadapTahanRp:  jsRound(selisihRp),
		SelisihTerhadapTahanPct: selisihPct,
		DiskonTerhadapPasarPct:  diskonPct,
		TunaiHariIniPanjarRp:    jsRound(pendapatanPanjarRaw),
		TunaiHariIniSrgRp:       jsRound(in.PinjamanSrgRp),
	}, nil
}
