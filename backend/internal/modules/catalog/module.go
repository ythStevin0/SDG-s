package catalog

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"simpanjual/backend/internal/modules/engine"
	"simpanjual/backend/internal/platform/cache"
	"simpanjual/backend/internal/platform/config"
	"simpanjual/backend/internal/platform/httpx"
	"simpanjual/backend/internal/platform/middleware"
)

type Module struct {
	pool  *pgxpool.Pool
	cache *cache.TTLCache
	cfg   config.Config
}

func NewModule(pool *pgxpool.Pool, c *cache.TTLCache, cfg config.Config) *Module {
	return &Module{pool: pool, cache: c, cfg: cfg}
}

func (m *Module) RegisterRoutes(mux *http.ServeMux) {
	requireAdmin := middleware.RequireAuth(m.cfg.JWTSecret, "admin")

	mux.HandleFunc("GET /api/v1/commodities", m.handleListCommodities)
	mux.HandleFunc("GET /api/v1/regions", m.handleListRegions)
	mux.HandleFunc("GET /api/v1/prices", m.handleGetPricesAndForecast)
	mux.HandleFunc("POST /api/v1/simulator", m.handleQuickSimulator)
	mux.HandleFunc("POST /api/v1/admin/commodities", requireAdmin(m.handleAdminCreateCommodity))
	mux.HandleFunc("PUT /api/v1/admin/commodities/{id}", requireAdmin(m.handleAdminUpdateCommodity))
}

type CommodityDTO struct {
	ID     string                 `json:"id"`
	Kode   string                 `json:"kode"`
	Nama   string                 `json:"nama"`
	Satuan string                 `json:"satuan"`
	Params engine.CommodityParams `json:"params"`
}

func (m *Module) ListCommodities(ctx context.Context) ([]CommodityDTO, error) {
	const cacheKey = "catalog:commodities"
	if cached, ok := m.cache.Get(cacheKey); ok {
		if items, ok2 := cached.([]CommodityDTO); ok2 {
			return items, nil
		}
	}

	rows, err := m.pool.Query(ctx, `
		SELECT id::text, kode, nama, satuan, params
		FROM commodities
		ORDER BY kode ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []CommodityDTO
	for rows.Next() {
		var c CommodityDTO
		var rawParams []byte
		if err := rows.Scan(&c.ID, &c.Kode, &c.Nama, &c.Satuan, &rawParams); err != nil {
			return nil, err
		}
		_ = json.Unmarshal(rawParams, &c.Params)
		out = append(out, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	m.cache.Set(cacheKey, out, 2*time.Minute)
	return out, nil
}

func (m *Module) GetPriceSeriesAndForecast(ctx context.Context, commodityKodeOrID, region string) ([]engine.PriceSeriesPoint, engine.ForecastOutput, CommodityDTO, error) {
	if region == "" {
		region = "Jawa Tengah"
	}
	cacheKey := fmt.Sprintf("forecast:%s:%s", strings.ToLower(commodityKodeOrID), strings.ToLower(region))

	type cachedBundle struct {
		Series    []engine.PriceSeriesPoint
		Forecast  engine.ForecastOutput
		Commodity CommodityDTO
	}
	if v, ok := m.cache.Get(cacheKey); ok {
		if b, ok2 := v.(cachedBundle); ok2 {
			return b.Series, b.Forecast, b.Commodity, nil
		}
	}

	var comm CommodityDTO
	var rawParams []byte
	err := m.pool.QueryRow(ctx, `
		SELECT id::text, kode, nama, satuan, params
		FROM commodities
		WHERE kode = $1 OR id::text = $1
		LIMIT 1
	`, commodityKodeOrID).Scan(&comm.ID, &comm.Kode, &comm.Nama, &comm.Satuan, &rawParams)
	if err != nil {
		return nil, engine.ForecastOutput{}, CommodityDTO{}, fmt.Errorf("komoditas %s tidak ditemukan", commodityKodeOrID)
	}
	_ = json.Unmarshal(rawParams, &comm.Params)

	rows, err := m.pool.Query(ctx, `
		SELECT tanggal::text, harga_per_kg
		FROM price_points
		WHERE commodity_id = $1 AND region = $2
		ORDER BY tanggal ASC
	`, comm.ID, region)
	if err != nil {
		return nil, engine.ForecastOutput{}, comm, err
	}
	defer rows.Close()

	var series []engine.PriceSeriesPoint
	for rows.Next() {
		var pt engine.PriceSeriesPoint
		if err := rows.Scan(&pt.Tanggal, &pt.HargaPerKg); err != nil {
			return nil, engine.ForecastOutput{}, comm, err
		}
		series = append(series, pt)
	}

	if len(series) == 0 {
		// Fallback ke wilayah mana pun untuk komoditas tersebut
		rows2, err2 := m.pool.Query(ctx, `
			SELECT tanggal::text, harga_per_kg
			FROM price_points
			WHERE commodity_id = $1
			ORDER BY tanggal ASC
		`, comm.ID)
		if err2 == nil {
			for rows2.Next() {
				var pt engine.PriceSeriesPoint
				if rows2.Scan(&pt.Tanggal, &pt.HargaPerKg) == nil {
					series = append(series, pt)
				}
			}
			rows2.Close()
		}
	}

	fc, err := engine.GeneratePriceForecast(series)
	if err != nil {
		return series, engine.ForecastOutput{}, comm, err
	}

	m.cache.Set(cacheKey, cachedBundle{Series: series, Forecast: fc, Commodity: comm}, 2*time.Minute)
	return series, fc, comm, nil
}

func (m *Module) handleListCommodities(w http.ResponseWriter, r *http.Request) {
	items, err := m.ListCommodities(r.Context())
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal memuat daftar komoditas")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"commodities": items})
}

func (m *Module) handleListRegions(w http.ResponseWriter, r *http.Request) {
	regions := make([]engine.RegionCoord, 0, len(engine.JatengRegions))
	for _, rc := range engine.JatengRegions {
		regions = append(regions, rc)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"regions": regions})
}

func (m *Module) handleGetPricesAndForecast(w http.ResponseWriter, r *http.Request) {
	kode := strings.TrimSpace(r.URL.Query().Get("commodity"))
	if kode == "" {
		kode = "jagung"
	}
	region := strings.TrimSpace(r.URL.Query().Get("region"))
	if region == "" {
		region = "Jawa Tengah"
	}

	series, fc, comm, err := m.GetPriceSeriesAndForecast(r.Context(), kode, region)
	if err != nil {
		status, code := httpx.ClassifyDomainError(err)
		httpx.Error(w, r, status, code, err.Error())
		return
	}

	latestPrice := 0
	if len(series) > 0 {
		latestPrice = series[len(series)-1].HargaPerKg
	}

	httpx.JSON(w, http.StatusOK, map[string]any{
		"commodity":   comm,
		"region":      region,
		"latestPrice": latestPrice,
		"series":      series,
		"forecast":    fc,
		"disclaimer":  "Prediksi bersifat perkiraan statistik (WMA-4, Holt-Damped, Seasonal-MA), bukan jaminan harga.",
	})
}

func (m *Module) handleQuickSimulator(w http.ResponseWriter, r *http.Request) {
	var body struct {
		CommodityKode      string   `json:"commodityKode"`
		QtyKg              float64  `json:"qtyKg"`
		KadarAirAktual     float64  `json:"kadarAirAktual"`
		TarifSewaPerKgHari float64  `json:"tarifSewaPerKgHari"`
		BiayaAngkutPerKg   float64  `json:"biayaAngkutPerKg"`
		BiayaTetap         float64  `json:"biayaTetap"`
		RasioPinjaman      float64  `json:"rasioPinjaman"`
		BungaTahunan       float64  `json:"bungaTahunan"`
		HargaPanjarPerKg   *float64 `json:"hargaPanjarPerKg"`
		TotalBoronganRp    *float64 `json:"totalBoronganRp"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if body.CommodityKode == "" {
		body.CommodityKode = "jagung"
	}
	if body.TarifSewaPerKgHari <= 0 {
		body.TarifSewaPerKgHari = 2.5
	}
	if body.BiayaAngkutPerKg < 0 {
		body.BiayaAngkutPerKg = 20
	}
	if body.BungaTahunan <= 0 {
		body.BungaTahunan = 0.06
	}

	series, fc, comm, err := m.GetPriceSeriesAndForecast(r.Context(), body.CommodityKode, "Jawa Tengah")
	if err != nil || len(series) == 0 {
		httpx.Error(w, r, http.StatusBadRequest, "PRICE_UNAVAILABLE", "Data harga komoditas belum tersedia")
		return
	}
	p0 := float64(series[len(series)-1].HargaPerKg)
	cDry := comm.Params.BiayaPengeringanPerKg

	dec, err := engine.EvaluateHoldVsSell(engine.DecisionInput{
		QtyKg:                 body.QtyKg,
		KadarAirAktual:        body.KadarAirAktual,
		KadarAirAmbang:        comm.Params.KadarAirMaksPct,
		BiayaPengeringanPerKg: &cDry,
		P0Dry:                 p0,
		Predictions:           fc.Predictions,
		TarifSewaPerKgHari:    body.TarifSewaPerKgHari,
		BiayaAngkutPerKg:      body.BiayaAngkutPerKg,
		BiayaTetap:            body.BiayaTetap,
		SusutPerBulan:         comm.Params.SusutPerBulan,
		RasioPinjaman:         body.RasioPinjaman,
		BungaTahunan:          body.BungaTahunan,
	})
	if err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "ENGINE_ERROR", err.Error())
		return
	}

	var panjarRes *engine.PanjarResult
	if body.TotalBoronganRp != nil && *body.TotalBoronganRp > 0 {
		pr, err := engine.EvaluatePanjarTandingan(engine.PanjarInput{
			Mode:              "borongan",
			TotalBoronganRp:   *body.TotalBoronganRp,
			QtyKg:             body.QtyKg,
			P0Actual:          p0,
			PendapatanTahanRp: float64(dec.Best.PendapatanTahan),
			PinjamanSrgRp:     float64(dec.PinjamanAwal),
		})
		if err == nil {
			panjarRes = &pr
		}
	} else if body.HargaPanjarPerKg != nil && *body.HargaPanjarPerKg > 0 {
		pr, err := engine.EvaluatePanjarTandingan(engine.PanjarInput{
			Mode:              "per_kg",
			HargaPanjarPerKg:  *body.HargaPanjarPerKg,
			QtyKg:             body.QtyKg,
			P0Actual:          p0,
			PendapatanTahanRp: float64(dec.Best.PendapatanTahan),
			PinjamanSrgRp:     float64(dec.PinjamanAwal),
		})
		if err == nil {
			panjarRes = &pr
		}
	}

	readiness := engine.EvaluateStorageReadiness(body.KadarAirAktual, 2.0, 3.0, comm.Params)

	httpx.JSON(w, http.StatusOK, map[string]any{
		"commodity":   comm,
		"latestPrice": int(p0),
		"forecast":    fc,
		"decision":    dec,
		"panjar":      panjarRes,
		"readiness":   readiness,
	})
}

func (m *Module) handleAdminCreateCommodity(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Kode          string                 `json:"kode"`
		Nama          string                 `json:"nama"`
		Satuan        string                 `json:"satuan"`
		HargaAwalKg   int                    `json:"hargaAwalKg"`
		Params        engine.CommodityParams `json:"params"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}

	kode := strings.ToLower(strings.TrimSpace(body.Kode))
	nama := strings.TrimSpace(body.Nama)
	if kode == "" || nama == "" {
		httpx.Error(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "Kode dan nama komoditas wajib diisi")
		return
	}
	if body.Satuan == "" {
		body.Satuan = "kg"
	}
	if body.Params.KadarAirMaksPct <= 0 {
		body.Params.KadarAirMaksPct = 14
	}
	if body.Params.KotoranMaksPct <= 0 {
		body.Params.KotoranMaksPct = 3
	}
	if body.Params.RusakMaksPct <= 0 {
		body.Params.RusakMaksPct = 5
	}
	if body.Params.SusutPerBulan <= 0 {
		body.Params.SusutPerBulan = 0.005
	}
	if body.Params.SusutRumahPerBulan <= 0 {
		body.Params.SusutRumahPerBulan = 0.025
	}
	if body.Params.BiayaPengeringanPerKg <= 0 {
		body.Params.BiayaPengeringanPerKg = 150
	}
	if body.Params.TarifSewaMurah <= 0 {
		body.Params.TarifSewaMurah = 1
	}
	if body.Params.TarifSewaMahal <= body.Params.TarifSewaMurah {
		body.Params.TarifSewaMahal = 8
	}
	if len(body.Params.FasilitasWajib) == 0 {
		body.Params.FasilitasWajib = []string{"ventilasi", "lantai_palet_kering", "kontrol_hama"}
	}

	paramsBytes, _ := json.Marshal(body.Params)

	tx, err := m.pool.Begin(r.Context())
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "TX_ERROR", "Gagal memulai transaksi")
		return
	}
	defer tx.Rollback(r.Context())

	var created CommodityDTO
	err = tx.QueryRow(r.Context(), `
		INSERT INTO commodities (kode, nama, satuan, params)
		VALUES ($1, $2, $3, $4::jsonb)
		ON CONFLICT (kode) DO UPDATE SET nama = EXCLUDED.nama, satuan = EXCLUDED.satuan, params = EXCLUDED.params
		RETURNING id::text, kode, nama, satuan
	`, kode, nama, body.Satuan, string(paramsBytes)).Scan(&created.ID, &created.Kode, &created.Nama, &created.Satuan)
	if err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "DB_ERROR", err.Error())
		return
	}
	created.Params = body.Params

	// Isi 64 minggu histori harga ilustratif secara otomatis agar grafik & backtest langsung aktif
	basePrice := body.HargaAwalKg
	if basePrice <= 0 {
		basePrice = 8500
	}
	start := time.Date(2025, 9, 1, 0, 0, 0, 0, time.UTC)
	for wIdx := 0; wIdx < 64; wIdx++ {
		dt := start.AddDate(0, 0, wIdx*7).Format("2006-01-02")
		phase := (2.0 * math.Pi * float64(wIdx)) / 26.0
		seasonal := math.Sin(phase) * float64(basePrice) * 0.09
		noise := float64(((wIdx*37)%11)-5) * 25.0
		trend := float64(wIdx * 8)
		p := int(math.Round((float64(basePrice)+seasonal+noise+trend)/50.0)) * 50
		_, _ = tx.Exec(r.Context(), `
			INSERT INTO price_points (commodity_id, region, tanggal, harga_per_kg, sumber, is_demo)
			VALUES ($1, 'Jawa Tengah', $2::date, $3, 'Data Ilustrasi Bermusim (Komoditas Baru)', TRUE)
			ON CONFLICT (commodity_id, region, tanggal) DO NOTHING
		`, created.ID, dt, p)
	}

	if err := tx.Commit(r.Context()); err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "COMMIT_ERROR", "Gagal menyimpan komoditas")
		return
	}

	// Write-through cache invalidation agar tidak ada stale cache (#40)
	m.cache.InvalidatePrefix("catalog:")
	m.cache.InvalidatePrefix("forecast:")

	httpx.JSON(w, http.StatusCreated, map[string]any{"commodity": created})
}

func (m *Module) handleAdminUpdateCommodity(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	var body struct {
		Nama   string                 `json:"nama"`
		Params engine.CommodityParams `json:"params"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	paramsBytes, _ := json.Marshal(body.Params)

	var updated CommodityDTO
	err := m.pool.QueryRow(r.Context(), `
		UPDATE commodities
		SET nama = COALESCE(NULLIF($2, ''), nama),
		    params = $3::jsonb
		WHERE id = $1
		RETURNING id::text, kode, nama, satuan
	`, id, strings.TrimSpace(body.Nama), string(paramsBytes)).Scan(&updated.ID, &updated.Kode, &updated.Nama, &updated.Satuan)
	if err != nil {
		httpx.Error(w, r, http.StatusNotFound, "NOT_FOUND", "Komoditas tidak ditemukan")
		return
	}
	updated.Params = body.Params

	m.cache.InvalidatePrefix("catalog:")
	m.cache.InvalidatePrefix("forecast:")

	httpx.JSON(w, http.StatusOK, map[string]any{"commodity": updated})
}
