package engine

import (
	"errors"
	"math"
)

type DryingInput struct {
	QtyKg                 float64 `json:"qtyKg"`
	KadarAirAktual        float64 `json:"kadarAirAktual"`
	KadarAirAmbang        float64 `json:"kadarAirAmbang"`
	BiayaPengeringanPerKg float64 `json:"biayaPengeringanPerKg"`
}

type DryingResult struct {
	PerluPengeringan   bool    `json:"perluPengeringan"`
	QtySiapRaw         float64 `json:"-"`
	QtySiap            float64 `json:"qtySiap"`
	SusutPengeringanKg float64 `json:"susutPengeringanKg"`
	BiayaPengeringanRp int     `json:"biayaPengeringanRp"`
}

// CalculateDryingConversion menghitung konversi bobot dan ongkos pengeringan dari kadar air aktual (mis. GKP 24%)
// menuju kadar air standar simpan gudang (mis. GKG 14%) memakai konservasi massa bahan kering.
func CalculateDryingConversion(in DryingInput) (DryingResult, error) {
	if in.QtyKg <= 0 {
		return DryingResult{}, errors.New("jumlah stok (qtyKg) harus lebih dari 0")
	}
	if in.KadarAirAktual < 0 || in.KadarAirAktual >= 100 {
		return DryingResult{}, errors.New("kadar air aktual harus antara 0 dan < 100%")
	}
	if in.KadarAirAmbang <= 0 || in.KadarAirAmbang >= 100 {
		return DryingResult{}, errors.New("ambang kadar air tidak valid")
	}

	if in.KadarAirAktual <= in.KadarAirAmbang {
		return DryingResult{
			PerluPengeringan:   false,
			QtySiapRaw:         in.QtyKg,
			QtySiap:            round2(in.QtyKg),
			SusutPengeringanKg: 0,
			BiayaPengeringanRp: 0,
		}, nil
	}

	qtySiapRaw := in.QtyKg * ((100.0 - in.KadarAirAktual) / (100.0 - in.KadarAirAmbang))
	biayaRp := jsRound(in.QtyKg * math.Max(0, in.BiayaPengeringanPerKg))

	return DryingResult{
		PerluPengeringan:   true,
		QtySiapRaw:         qtySiapRaw,
		QtySiap:            round2(qtySiapRaw),
		SusutPengeringanKg: round2(in.QtyKg - qtySiapRaw),
		BiayaPengeringanRp: biayaRp,
	}, nil
}
