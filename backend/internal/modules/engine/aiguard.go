package engine

import (
	"fmt"
	"math"
	"regexp"
	"strconv"
	"strings"
)

var (
	phoneRegex      = regexp.MustCompile(`(?:\+62|62|0)8[1-9][0-9\-.\s]{6,13}`)
	emailRegex      = regexp.MustCompile(`[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`)
	unitNumberRegex = regexp.MustCompile(`(?i)(?:Rp\.?\s*([\d.,]+)\s*(juta|jt|ribu|rb)?)|(?:([\d.,]+)\s*(%|persen|kg|ton|kuintal|kw|minggu|hari|bulan)\b)`)
	thousandDotRe   = regexp.MustCompile(`^\d{1,3}(\.\d{3})+$`)
	priceExtractRe  = regexp.MustCompile(`(?i)Rp\.?\s*([\d.,]+)\s*(rb|ribu|jt|juta)?\s*(?:/\s*kg|per\s*kg)?`)
	qtyExtractRe    = regexp.MustCompile(`(?i)([\d.,]+)\s*(kg|ton|kuintal|kw|karung|sak)\b`)
	panjarWordRe    = regexp.MustCompile(`(?i)panjar|ijon|tebas`)
)

type ExtractedMetric struct {
	Raw           string
	Value         float64
	IsAbbreviated bool
}

type AIExplanation struct {
	Ringkasan      string   `json:"ringkasan"`
	Alasan         []string `json:"alasan"`
	LangkahBerikut []string `json:"langkah_berikut"`
	Peringatan     *string  `json:"peringatan"`
	FallbackUsed   bool     `json:"fallback_used"`
}

type ExtractedOffer struct {
	Jenis                string   `json:"jenis"`
	HargaPerKg           *int     `json:"harga_per_kg"`
	HargaTotalBorongan   *int     `json:"harga_total_borongan,omitempty"`
	JumlahKg             *int     `json:"jumlah_kg"`
	FieldTidakPasti      []string `json:"field_tidak_pasti"`
	Catatan              *string  `json:"catatan"`
	FallbackUsed         bool     `json:"fallback_used"`
}

func StripPII(text string) string {
	s := phoneRegex.ReplaceAllString(text, "[NOMOR_DIHAPUS]")
	return emailRegex.ReplaceAllString(s, "[EMAIL_DIHAPUS]")
}

func ParseIndonesianNumber(numStr string) float64 {
	cleaned := strings.TrimSpace(numStr)
	if strings.Contains(cleaned, ".") && strings.Contains(cleaned, ",") {
		cleaned = strings.ReplaceAll(cleaned, ".", "")
		cleaned = strings.ReplaceAll(cleaned, ",", ".")
		v, err := strconv.ParseFloat(cleaned, 64)
		if err != nil {
			return math.NaN()
		}
		return v
	}
	if strings.Contains(cleaned, ",") {
		cleaned = strings.ReplaceAll(cleaned, ",", ".")
		v, err := strconv.ParseFloat(cleaned, 64)
		if err != nil {
			return math.NaN()
		}
		return v
	}
	if thousandDotRe.MatchString(cleaned) {
		cleaned = strings.ReplaceAll(cleaned, ".", "")
		v, err := strconv.ParseFloat(cleaned, 64)
		if err != nil {
			return math.NaN()
		}
		return v
	}
	v, err := strconv.ParseFloat(cleaned, 64)
	if err != nil {
		return math.NaN()
	}
	return v
}

func ExtractUnitNumbers(text string) []ExtractedMetric {
	matches := unitNumberRegex.FindAllStringSubmatch(text, -1)
	var out []ExtractedMetric
	for _, m := range matches {
		if m[1] != "" {
			base := ParseIndonesianNumber(m[1])
			multUnit := strings.ToLower(m[2])
			mult := 1.0
			if multUnit == "juta" || multUnit == "jt" {
				mult = 1_000_000.0
			} else if multUnit == "ribu" || multUnit == "rb" {
				mult = 1_000.0
			}
			out = append(out, ExtractedMetric{
				Raw:           m[0],
				Value:         base * mult,
				IsAbbreviated: mult > 1.0,
			})
		} else if m[3] != "" {
			base := ParseIndonesianNumber(m[3])
			unit := strings.ToLower(m[4])
			mult := 1.0
			switch unit {
			case "ton":
				mult = 1000.0
			case "kuintal", "kw":
				mult = 100.0
			case "bulan":
				mult = 4.0
			}
			out = append(out, ExtractedMetric{
				Raw:           m[0],
				Value:         base * mult,
				IsAbbreviated: false,
			})
		}
	}
	return out
}

func ValidateAIExplanationNumbers(aiTexts []string, allowedValues []float64) (bool, string) {
	fullText := strings.Join(aiTexts, " ")
	tokens := ExtractUnitNumbers(fullText)
	for _, tok := range tokens {
		if math.IsNaN(tok.Value) || math.IsInf(tok.Value, 0) {
			return false, tok.Raw
		}
		tol := 0.01
		if tok.IsAbbreviated {
			tol = 0.05
		}
		matched := false
		for _, ref := range allowedValues {
			if ref == 0 {
				if math.Abs(tok.Value) < 1.0 {
					matched = true
					break
				}
			} else if math.Abs(tok.Value-ref)/math.Abs(ref) <= tol {
				matched = true
				break
			}
		}
		if !matched {
			return false, tok.Raw
		}
	}
	return true, ""
}

func BuildTemplateExplanation(rec RecommendationStatus, horizonWeeks, titikImpasPerKg, selisihRp, totalBiayaSimpan int) AIExplanation {
	beStr := fmt.Sprintf("Rp%s/kg", FormatIntID(titikImpasPerKg))
	absSelisih := selisihRp
	if absSelisih < 0 {
		absSelisih = -absSelisih
	}
	selisihStr := fmt.Sprintf("Rp%s", FormatIntID(absSelisih))
	biayaStr := fmt.Sprintf("Rp%s", FormatIntID(totalBiayaSimpan))

	var ringkasan string
	var langkah []string
	if rec == RecJual {
		ringkasan = fmt.Sprintf("Sebaiknya jual sekarang karena perkiraan kenaikan harga belum menutup biaya simpan (%s).", biayaStr)
		langkah = []string{
			"Buka daftar kebutuhan pembeli di menu Jual.",
			"Bandingkan harga tawar dengan harga pasar hari ini.",
		}
	} else {
		ringkasan = fmt.Sprintf("Disarankan menahan selama %d minggu dengan perkiraan tambahan hasil %s jika harga minimal %s.", horizonWeeks, selisihStr, beStr)
		langkah = []string{
			"Periksa kesiapan kadar air stok Anda.",
			"Cari gudang terdekat atau gabung Lot Kolektif poktan.",
		}
	}

	var peringatan *string
	if rec == RecTahanBerisiko {
		p := "Prediksi masih memiliki risiko turun di batas bawah. Pantau harga mingguan secara berkala."
		peringatan = &p
	}

	return AIExplanation{
		Ringkasan: ringkasan,
		Alasan: []string{
			fmt.Sprintf("Titik impas harga jual setelah simpan adalah %s.", beStr),
			fmt.Sprintf("Total biaya simpan, angkut, susut, dan bunga tercatat sebesar %s.", biayaStr),
		},
		LangkahBerikut: langkah,
		Peringatan:     peringatan,
		FallbackUsed:   true,
	}
}

func RegexExtractOffer(rawText string) ExtractedOffer {
	cleaned := StripPII(rawText)
	var hargaPerKg *int
	var hargaBorongan *int
	var jumlahKg *int
	uncertain := []string{}

	if pm := priceExtractRe.FindStringSubmatch(cleaned); len(pm) >= 3 {
		val := ParseIndonesianNumber(pm[1])
		unit := strings.ToLower(pm[2])
		mult := 1.0
		if unit == "rb" || unit == "ribu" {
			mult = 1000.0
		} else if unit == "jt" || unit == "juta" {
			mult = 1_000_000.0
		}
		cand := jsRound(val * mult)
		if cand >= 100 && cand <= 200_000 {
			hargaPerKg = &cand
		} else if cand > 200_000 {
			hargaBorongan = &cand
		}
	}

	if qm := qtyExtractRe.FindStringSubmatch(cleaned); len(qm) >= 3 {
		val := ParseIndonesianNumber(qm[1])
		unit := strings.ToLower(qm[2])
		var kg int
		switch unit {
		case "ton":
			kg = jsRound(val * 1000.0)
		case "kuintal", "kw":
			kg = jsRound(val * 100.0)
		case "karung", "sak":
			kg = jsRound(val * 50.0)
			uncertain = append(uncertain, "jumlah_kg")
		default:
			kg = jsRound(val)
		}
		if kg > 0 {
			jumlahKg = &kg
		}
	}

	jenis := "pembelian"
	if panjarWordRe.MatchString(cleaned) {
		jenis = "panjar"
	}

	var catatan *string
	for _, u := range uncertain {
		if u == "jumlah_kg" {
			c := "Satuan karung diasumsikan 50 kg per karung; mohon sesuaikan berat riil."
			catatan = &c
		}
	}

	return ExtractedOffer{
		Jenis:              jenis,
		HargaPerKg:         hargaPerKg,
		HargaTotalBorongan: hargaBorongan,
		JumlahKg:           jumlahKg,
		FieldTidakPasti:    uncertain,
		Catatan:            catatan,
		FallbackUsed:       true,
	}
}
