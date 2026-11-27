package stock

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"simpanjual/backend/internal/modules/catalog"
	"simpanjual/backend/internal/modules/engine"
	"simpanjual/backend/internal/platform/config"
	"simpanjual/backend/internal/platform/httpx"
	"simpanjual/backend/internal/platform/middleware"
)

type Module struct {
	pool    *pgxpool.Pool
	catalog *catalog.Module
	cfg     config.Config
}

func NewModule(pool *pgxpool.Pool, cat *catalog.Module, cfg config.Config) *Module {
	return &Module{pool: pool, catalog: cat, cfg: cfg}
}

func (m *Module) RegisterRoutes(mux *http.ServeMux) {
	requirePetani := middleware.RequireAuth(m.cfg.JWTSecret, "petani", "admin")

	mux.HandleFunc("GET /api/v1/stocks", requirePetani(m.handleListStocks))
	mux.HandleFunc("POST /api/v1/stocks", requirePetani(middleware.Idempotent(m.pool, m.handleCreateStock)))
	mux.HandleFunc("DELETE /api/v1/stocks/{id}", requirePetani(m.handleDeleteStock))
	mux.HandleFunc("GET /api/v1/stocks/{id}/analysis", requirePetani(m.handleStockAnalysis))
	mux.HandleFunc("POST /api/v1/stocks/{id}/decide", requirePetani(m.handleEvaluateDecision))
}

type StockDTO struct {
	ID              string                 `json:"id"`
	OwnerID         string                 `json:"ownerId"`
	CommodityID     string                 `json:"commodityId"`
	CommodityKode   string                 `json:"commodityKode"`
	CommodityNama   string                 `json:"commodityNama"`
	CommodityParams engine.CommodityParams `json:"commodityParams"`
	QtyKg           float64                `json:"qtyKg"`
	ReservedKg      float64                `json:"reservedKg"`
	SoldKg          float64                `json:"soldKg"`
	FreeKg          float64                `json:"freeKg"`
	KadarAir        float64                `json:"kadarAir"`
	KotoranPct      float64                `json:"kotoranPct"`
	RusakPct        float64                `json:"rusakPct"`
	TglPanen        string                 `json:"tglPanen"`
	Kabupaten       string                 `json:"kabupaten"`
	Lat             *float64               `json:"lat"`
	Lng             *float64               `json:"lng"`
	Status          string                 `json:"status"`
	Catatan         *string                `json:"catatan"`
	CreatedAt       time.Time              `json:"createdAt"`
}

// handleListStocks menggunakan Eager JOIN ke tabel commodities untuk mencegah N+1 Query (#10).
func (m *Module) handleListStocks(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())

	rows, err := m.pool.Query(r.Context(), `
		SELECT s.id::text, s.owner_id::text, s.commodity_id::text,
		       c.kode, c.nama, c.params,
		       s.qty_kg, s.reserved_kg, s.sold_kg,
		       s.kadar_air, s.kotoran_pct, s.rusak_pct,
		       s.tgl_panen::text, s.kabupaten, s.lat, s.lng, s.status, s.catatan, s.created_at
		FROM stocks s
		INNER JOIN commodities c ON c.id = s.commodity_id
		WHERE s.owner_id = $1
		ORDER BY s.created_at DESC
	`, u.UserID)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal mengambil daftar stok")
		return
	}
	defer rows.Close()

	stocks := []StockDTO{}
	for rows.Next() {
		var st StockDTO
		var rawParams []byte
		if err := rows.Scan(
			&st.ID, &st.OwnerID, &st.CommodityID,
			&st.CommodityKode, &st.CommodityNama, &rawParams,
			&st.QtyKg, &st.ReservedKg, &st.SoldKg,
			&st.KadarAir, &st.KotoranPct, &st.RusakPct,
			&st.TglPanen, &st.Kabupaten, &st.Lat, &st.Lng, &st.Status, &st.Catatan, &st.CreatedAt,
		); err != nil {
			httpx.Error(w, r, http.StatusInternalServerError, "SCAN_ERROR", "Gagal membaca baris stok")
			return
		}
		_ = json.Unmarshal(rawParams, &st.CommodityParams)
		st.FreeKg = st.QtyKg - st.ReservedKg - st.SoldKg
		if st.FreeKg < 0 {
			st.FreeKg = 0
		}
		stocks = append(stocks, st)
	}

	httpx.JSON(w, http.StatusOK, map[string]any{"stocks": stocks})
}

func (m *Module) handleCreateStock(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())

	var body struct {
		CommodityID string   `json:"commodityId"`
		Commodity   string   `json:"commodityKode"`
		QtyKg       float64  `json:"qtyKg"`
		KadarAir    float64  `json:"kadarAir"`
		KotoranPct  *float64 `json:"kotoranPct"`
		RusakPct    *float64 `json:"rusakPct"`
		TglPanen    string   `json:"tglPanen"`
		Kabupaten   string   `json:"kabupaten"`
		Lat         *float64 `json:"lat"`
		Lng         *float64 `json:"lng"`
		Catatan     *string  `json:"catatan"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if body.QtyKg <= 0 || body.KadarAir < 0 || body.KadarAir >= 100 {
		httpx.Error(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "Jumlah stok harus > 0 kg dan kadar air antara 0% hingga < 100%")
		return
	}

	commRef := strings.TrimSpace(body.CommodityID)
	if commRef == "" {
		commRef = strings.TrimSpace(body.Commodity)
	}
	var commID, commKode, commNama string
	var rawParams []byte
	err := m.pool.QueryRow(r.Context(), `
		SELECT id::text, kode, nama, params
		FROM commodities
		WHERE id::text = $1 OR kode = $1
		LIMIT 1
	`, commRef).Scan(&commID, &commKode, &commNama, &rawParams)
	if err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_COMMODITY", "Komoditas tidak ditemukan")
		return
	}

	kab := strings.TrimSpace(body.Kabupaten)
	if kab == "" {
		kab = u.Kabupaten
	}
	lat, lng := engine.ResolveCoordinates(kab, body.Lat, body.Lng)
	kotoran := 2.0
	if body.KotoranPct != nil {
		kotoran = *body.KotoranPct
	}
	rusak := 3.0
	if body.RusakPct != nil {
		rusak = *body.RusakPct
	}
	tglPanen := strings.TrimSpace(body.TglPanen)
	if tglPanen == "" {
		tglPanen = time.Now().Format("2006-01-02")
	}

	var st StockDTO
	err = m.pool.QueryRow(r.Context(), `
		INSERT INTO stocks (owner_id, commodity_id, qty_kg, reserved_kg, sold_kg, kadar_air, kotoran_pct, rusak_pct, tgl_panen, kabupaten, lat, lng, status, catatan)
		VALUES ($1, $2, $3, 0, 0, $4, $5, $6, $7::date, $8, $9, $10, 'tersedia', $11)
		RETURNING id::text, owner_id::text, commodity_id::text, qty_kg, reserved_kg, sold_kg, kadar_air, kotoran_pct, rusak_pct, tgl_panen::text, kabupaten, lat, lng, status, catatan, created_at
	`, u.UserID, commID, body.QtyKg, body.KadarAir, kotoran, rusak, tglPanen, kab, lat, lng, body.Catatan).Scan(
		&st.ID, &st.OwnerID, &st.CommodityID, &st.QtyKg, &st.ReservedKg, &st.SoldKg,
		&st.KadarAir, &st.KotoranPct, &st.RusakPct, &st.TglPanen, &st.Kabupaten, &st.Lat, &st.Lng, &st.Status, &st.Catatan, &st.CreatedAt,
	)
	if err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "DB_ERROR", "Gagal mencatat stok: "+err.Error())
		return
	}
	st.CommodityKode = commKode
	st.CommodityNama = commNama
	_ = json.Unmarshal(rawParams, &st.CommodityParams)
	st.FreeKg = st.QtyKg

	httpx.JSON(w, http.StatusCreated, map[string]any{"stock": st})
}

func (m *Module) handleDeleteStock(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	id := r.PathValue("id")

	cmd, err := m.pool.Exec(r.Context(), `
		DELETE FROM stocks
		WHERE id = $1 AND owner_id = $2 AND reserved_kg = 0 AND sold_kg = 0
	`, id, u.UserID)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal menghapus stok")
		return
	}
	if cmd.RowsAffected() == 0 {
		httpx.Error(w, r, http.StatusBadRequest, "CANNOT_DELETE", "Stok tidak ditemukan, bukan milik Anda, atau sedang teralokasi pada lot/pengajuan")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (m *Module) loadStockForUser(r *http.Request, stockID, userID, role string) (StockDTO, error) {
	var st StockDTO
	var rawParams []byte
	err := m.pool.QueryRow(r.Context(), `
		SELECT s.id::text, s.owner_id::text, s.commodity_id::text,
		       c.kode, c.nama, c.params,
		       s.qty_kg, s.reserved_kg, s.sold_kg,
		       s.kadar_air, s.kotoran_pct, s.rusak_pct,
		       s.tgl_panen::text, s.kabupaten, s.lat, s.lng, s.status, s.catatan, s.created_at
		FROM stocks s
		INNER JOIN commodities c ON c.id = s.commodity_id
		WHERE s.id = $1 AND ($2 = 'admin' OR s.owner_id = $3)
	`, stockID, role, userID).Scan(
		&st.ID, &st.OwnerID, &st.CommodityID,
		&st.CommodityKode, &st.CommodityNama, &rawParams,
		&st.QtyKg, &st.ReservedKg, &st.SoldKg,
		&st.KadarAir, &st.KotoranPct, &st.RusakPct,
		&st.TglPanen, &st.Kabupaten, &st.Lat, &st.Lng, &st.Status, &st.Catatan, &st.CreatedAt,
	)
	if err != nil {
		return StockDTO{}, err
	}
	_ = json.Unmarshal(rawParams, &st.CommodityParams)
	st.FreeKg = st.QtyKg - st.ReservedKg - st.SoldKg
	if st.FreeKg < 0 {
		st.FreeKg = 0
	}
	return st, nil
}

// handleStockAnalysis menyajikan analisis terpadu Layar Bintang (F3 + F4 + F5 default + F6).
func (m *Module) handleStockAnalysis(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	id := r.PathValue("id")

	st, err := m.loadStockForUser(r, id, u.UserID, u.Role)
	if err != nil {
		httpx.Error(w, r, http.StatusNotFound, "STOCK_NOT_FOUND", "Stok tidak ditemukan atau bukan milik Anda")
		return
	}

	series, fc, _, err := m.catalog.GetPriceSeriesAndForecast(r.Context(), st.CommodityKode, "Jawa Tengah")
	if err != nil || len(series) == 0 {
		httpx.Error(w, r, http.StatusBadRequest, "PRICE_UNAVAILABLE", "Data harga historis belum tersedia")
		return
	}
	p0 := float64(series[len(series)-1].HargaPerKg)
	cDry := st.CommodityParams.BiayaPengeringanPerKg

	dec, err := engine.EvaluateHoldVsSell(engine.DecisionInput{
		QtyKg:                 st.QtyKg,
		KadarAirAktual:        st.KadarAir,
		KadarAirAmbang:        st.CommodityParams.KadarAirMaksPct,
		BiayaPengeringanPerKg: &cDry,
		P0Dry:                 p0,
		Predictions:           fc.Predictions,
		TarifSewaPerKgHari:    2.5,
		BiayaAngkutPerKg:      20,
		BiayaTetap:            100000,
		SusutPerBulan:         st.CommodityParams.SusutPerBulan,
		RasioPinjaman:         0.70,
		BungaTahunan:          0.06, // Default S-SRG 6%
	})
	if err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "ENGINE_ERROR", err.Error())
		return
	}

	readiness := engine.EvaluateStorageReadiness(st.KadarAir, st.KotoranPct, st.RusakPct, st.CommodityParams)

	httpx.JSON(w, http.StatusOK, map[string]any{
		"stock":       st,
		"latestPrice": int(p0),
		"series":      series,
		"forecast":    fc,
		"decision":    dec,
		"readiness":   readiness,
	})
}

// handleEvaluateDecision mengevaluasi dengan asumsi kustom petani + Panjar Tandingan + menyimpan ke tabel decisions.
func (m *Module) handleEvaluateDecision(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	id := r.PathValue("id")

	st, err := m.loadStockForUser(r, id, u.UserID, u.Role)
	if err != nil {
		httpx.Error(w, r, http.StatusNotFound, "STOCK_NOT_FOUND", "Stok tidak ditemukan atau bukan milik Anda")
		return
	}

	var body struct {
		TarifSewaPerKgHari    *float64 `json:"tarifSewaPerKgHari"`
		BiayaAngkutPerKg      *float64 `json:"biayaAngkutPerKg"`
		BiayaTetap            *float64 `json:"biayaTetap"`
		BiayaPengeringanPerKg *float64 `json:"biayaPengeringanPerKg"`
		SusutPerBulan         *float64 `json:"susutPerBulan"`
		RasioPinjaman         *float64 `json:"rasioPinjaman"`
		BungaTahunan          *float64 `json:"bungaTahunan"`
		P0Actual              *float64 `json:"p0Actual"`
		PanjarMode            string   `json:"panjarMode"`
		HargaPanjarPerKg      *float64 `json:"hargaPanjarPerKg"`
		TotalBoronganRp       *float64 `json:"totalBoronganRp"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}

	series, fc, _, err := m.catalog.GetPriceSeriesAndForecast(r.Context(), st.CommodityKode, "Jawa Tengah")
	if err != nil || len(series) == 0 {
		httpx.Error(w, r, http.StatusBadRequest, "PRICE_UNAVAILABLE", "Data harga historis belum tersedia")
		return
	}
	p0 := float64(series[len(series)-1].HargaPerKg)

	valOr := func(ptr *float64, def float64) float64 {
		if ptr != nil {
			return *ptr
		}
		return def
	}

	cDry := valOr(body.BiayaPengeringanPerKg, st.CommodityParams.BiayaPengeringanPerKg)
	in := engine.DecisionInput{
		QtyKg:                 st.QtyKg,
		KadarAirAktual:        st.KadarAir,
		KadarAirAmbang:        st.CommodityParams.KadarAirMaksPct,
		BiayaPengeringanPerKg: &cDry,
		P0Dry:                 p0,
		P0Actual:              body.P0Actual,
		Predictions:           fc.Predictions,
		TarifSewaPerKgHari:    valOr(body.TarifSewaPerKgHari, 2.5),
		BiayaAngkutPerKg:      valOr(body.BiayaAngkutPerKg, 20),
		BiayaTetap:            valOr(body.BiayaTetap, 100000),
		SusutPerBulan:         valOr(body.SusutPerBulan, st.CommodityParams.SusutPerBulan),
		RasioPinjaman:         valOr(body.RasioPinjaman, 0.70),
		BungaTahunan:          valOr(body.BungaTahunan, 0.06),
	}

	dec, err := engine.EvaluateHoldVsSell(in)
	if err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "ENGINE_ERROR", err.Error())
		return
	}

	p0Act := p0
	if body.P0Actual != nil && *body.P0Actual > 0 {
		p0Act = *body.P0Actual
	}

	var panjarRes *engine.PanjarResult
	if body.PanjarMode == "borongan" && body.TotalBoronganRp != nil && *body.TotalBoronganRp > 0 {
		pr, err := engine.EvaluatePanjarTandingan(engine.PanjarInput{
			Mode:              "borongan",
			TotalBoronganRp:   *body.TotalBoronganRp,
			QtyKg:             st.QtyKg,
			P0Actual:          p0Act,
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
			QtyKg:             st.QtyKg,
			P0Actual:          p0Act,
			PendapatanTahanRp: float64(dec.Best.PendapatanTahan),
			PinjamanSrgRp:     float64(dec.PinjamanAwal),
		})
		if err == nil {
			panjarRes = &pr
		}
	}

	inJSON, _ := json.Marshal(in)
	outJSON, _ := json.Marshal(map[string]any{"decision": dec, "panjar": panjarRes})

	var decisionID string
	_ = m.pool.QueryRow(r.Context(), `
		INSERT INTO decisions (stock_id, inputs, outputs)
		VALUES ($1, $2::jsonb, $3::jsonb)
		RETURNING id::text
	`, st.ID, string(inJSON), string(outJSON)).Scan(&decisionID)

	readiness := engine.EvaluateStorageReadiness(st.KadarAir, st.KotoranPct, st.RusakPct, st.CommodityParams)

	httpx.JSON(w, http.StatusOK, map[string]any{
		"decisionId":  decisionID,
		"latestPrice": int(p0),
		"forecast":    fc,
		"decision":    dec,
		"panjar":      panjarRes,
		"readiness":   readiness,
	})
}
