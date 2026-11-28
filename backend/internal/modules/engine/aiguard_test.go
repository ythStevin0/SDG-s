package engine

import (
	"math"
	"strings"
	"testing"
)

func TestParseIndonesianNumber(t *testing.T) {
	cases := []struct {
		in   string
		want float64
	}{
		{"5.383", 5383},
		{"2,05", 2.05},
		{"1.412.192,5", 1412192.5},
	}
	for _, tc := range cases {
		got := ParseIndonesianNumber(tc.in)
		if got != tc.want {
			t.Errorf("ParseIndonesianNumber(%q) = %v, want %v", tc.in, got, tc.want)
		}
	}
}

func TestExtractUnitNumbers(t *testing.T) {
	text := "1. Siapkan stok 5 ton atau 3 kuintal selama 8 minggu, harga Rp2,05 juta dan kadar air 14%. 2. Jemur dulu."
	tokens := ExtractUnitNumbers(text)
	if len(tokens) != 5 {
		t.Fatalf("expected 5 unit tokens (numbered list prefixes ignored), got %d: %+v", len(tokens), tokens)
	}

	checks := []struct {
		val  float64
		abbr bool
	}{
		{5000, false},
		{300, false},
		{8, false},
		{2050000, true},
		{14, false},
	}
	for i, c := range checks {
		if math.Abs(tokens[i].Value-c.val) > 1e-6 || tokens[i].IsAbbreviated != c.abbr {
			t.Errorf("token[%d] = %+v, want Value=%v IsAbbreviated=%v", i, tokens[i], c.val, c.abbr)
		}
	}
}

func TestValidateAIExplanationNumbers(t *testing.T) {
	allowed := []float64{8, 2048822, 5383}

	ok, bad := ValidateAIExplanationNumbers(
		[]string{"1. Tahan 8 minggu untuk selisih sekitar Rp2,0 juta jika harga minimal Rp5.383/kg."},
		allowed,
	)
	if !ok {
		t.Errorf("expected abbreviated million within 5%% tolerance to pass, rejected %q", bad)
	}

	okExact, badExact := ValidateAIExplanationNumbers(
		[]string{"Titik impas tepat Rp5.400/kg dalam 8 minggu."},
		allowed,
	)
	if !okExact {
		t.Errorf("expected exact number within 1%% tolerance to pass, rejected %q", badExact)
	}

	okBad, tokBad := ValidateAIExplanationNumbers(
		[]string{"Harga akan melonjak ke Rp9.500/kg dalam waktu dekat."},
		allowed,
	)
	if okBad || tokBad == "" {
		t.Errorf("expected hallucinated price Rp9.500/kg to be rejected, got ok=%v tok=%q", okBad, tokBad)
	}
}

func TestBuildTemplateExplanation(t *testing.T) {
	statuses := []RecommendationStatus{RecJual, RecTahan, RecTahanBerisiko}
	for _, st := range statuses {
		exp := BuildTemplateExplanation(st, 8, 5383, 2048822, 1412192)
		if !exp.FallbackUsed {
			t.Errorf("%s: expected FallbackUsed=true", st)
		}
		if exp.Ringkasan == "" || len(exp.Alasan) == 0 || len(exp.LangkahBerikut) == 0 {
			t.Errorf("%s: expected populated explanation fields, got %+v", st, exp)
		}
		if st == RecTahanBerisiko && (exp.Peringatan == nil || *exp.Peringatan == "") {
			t.Errorf("expected non-empty peringatan for TAHAN_BERISIKO")
		}
		joined := exp.Ringkasan + " " + strings.Join(exp.Alasan, " ") + " " + strings.Join(exp.LangkahBerikut, " ")
		if strings.Contains(joined, "\u2014") {
			t.Errorf("%s: found forbidden em dash in explanation copy", st)
		}
	}
}

func TestStripPIIAndRegexExtractOffer(t *testing.T) {
	raw := "Hubungi +6281234567890 atau 0812-3456-7890 dan budi@tani.id untuk tebas Rp18 juta isi 80 karung."
	sanitized := StripPII(raw)
	if strings.Contains(sanitized, "0812") || strings.Contains(sanitized, "budi@tani.id") {
		t.Fatalf("PII not stripped properly: %q", sanitized)
	}
	if !strings.Contains(sanitized, "[NOMOR_DIHAPUS]") || !strings.Contains(sanitized, "[EMAIL_DIHAPUS]") {
		t.Fatalf("expected PII replacement markers in %q", sanitized)
	}

	ext := RegexExtractOffer(sanitized)
	if ext.Jenis != "panjar" {
		t.Errorf("expected jenis=panjar, got %q", ext.Jenis)
	}
	if ext.HargaTotalBorongan == nil || *ext.HargaTotalBorongan != 18000000 {
		t.Errorf("expected HargaTotalBorongan=18000000, got %v", ext.HargaTotalBorongan)
	}
	if ext.JumlahKg == nil || *ext.JumlahKg != 4000 {
		t.Errorf("expected 80 karung -> 4000 kg, got %v", ext.JumlahKg)
	}
	if len(ext.FieldTidakPasti) == 0 || ext.FieldTidakPasti[0] != "jumlah_kg" {
		t.Errorf("expected jumlah_kg in FieldTidakPasti, got %v", ext.FieldTidakPasti)
	}
}
