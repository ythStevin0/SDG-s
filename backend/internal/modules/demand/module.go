package demand

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"simpanjual/backend/internal/modules/engine"
	"simpanjual/backend/internal/platform/config"
	"simpanjual/backend/internal/platform/httpx"
	"simpanjual/backend/internal/platform/middleware"
)

type Module struct {
	pool *pgxpool.Pool
	cfg  config.Config
}

func NewModule(pool *pgxpool.Pool, cfg config.Config) *Module {
	return &Module{pool: pool, cfg: cfg}
}

func (m *Module) RegisterRoutes(mux *http.ServeMux) {
	requireAuth := middleware.RequireAuth(m.cfg.JWTSecret)
	requirePembeli := middleware.RequireAuth(m.cfg.JWTSecret, "pembeli", "admin")
	requirePetani := middleware.RequireAuth(m.cfg.JWTSecret, "petani", "admin")

	mux.HandleFunc("GET /api/v1/demands", m.handleListDemands)
	mux.HandleFunc("POST /api/v1/demands", requirePembeli(middleware.Idempotent(m.pool, m.handleCreateDemand)))

	mux.HandleFunc("GET /api/v1/sales", requireAuth(m.handleListSales))
	mux.HandleFunc("POST /api/v1/sales", requirePetani(middleware.Idempotent(m.pool, m.handleSubmitSale)))
	mux.HandleFunc("POST /api/v1/sales/{id}/respond", requireAuth(m.handleRespondSale))
}

type MutuMin struct {
	KadarAirMaksPct *float64 `json:"kadar_air_maks_pct,omitempty"`
	Catatan         *string  `json:"catatan,omitempty"`
}

type DemandDTO struct {
	ID             string    `json:"id"`
	BuyerID        string    `json:"buyerId"`
	BuyerNama      string    `json:"buyerNama"`
	BuyerOrg       *string   `json:"buyerOrg,omitempty"`
	TipePembeli    *string   `json:"tipePembeli,omitempty"`
	CommodityID    string    `json:"commodityId"`
	CommodityKode  string    `json:"commodityKode"`
	CommodityNama  string    `json:"commodityNama"`
	QtyKg          float64   `json:"qtyKg"`
	TerpenuhiKg    float64   `json:"terpenuhiKg"`
	SisaKuotaKg    float64   `json:"sisaKuotaKg"`
	ProgressPct    float64   `json:"progressPct"`
	HargaAcuan     int       `json:"hargaAcuan"`
	DibutuhkanPada string    `json:"dibutuhkanPada"`
	Kabupaten      string    `json:"kabupaten"`
	Lat            float64   `json:"lat"`
	Lng            float64   `json:"lng"`
	MutuMin        MutuMin   `json:"mutuMin"`
	Status         string    `json:"status"`
	IsDemo         bool      `json:"isDemo"`
	CreatedAt      time.Time `json:"createdAt"`
}

type SaleOfferDTO struct {
	ID            string    `json:"id"`
	SellerID      string    `json:"sellerId"`
	SellerNama    string    `json:"sellerNama"`
	StockID       *string   `json:"stockId"`
	LotID         *string   `json:"lotId"`
	DemandID      string    `json:"demandId"`
	BuyerNama     string    `json:"buyerNama"`
	BuyerNoWa     *string   `json:"buyerNoWa,omitempty"`
	CommodityKode string    `json:"commodityKode"`
	CommodityNama string    `json:"commodityNama"`
	HargaAcuan    int       `json:"hargaAcuan"`
	QtyKg         float64   `json:"qtyKg"`
	HargaTawar    int       `json:"hargaTawar"`
	TotalNilaiRp  int       `json:"totalNilaiRp"`
	Status        string    `json:"status"`
	AlasanTolak   *string   `json:"alasanTolak"`
	CreatedAt     time.Time `json:"createdAt"`
	UpdatedAt     time.Time `json:"updatedAt"`
}

func computeStockStatus(qty, reserved, sold float64) string {
	if sold >= qty {
		return "terjual"
	}
	free := qty - reserved - sold
	if free <= 0 {
		return "teralokasi_penuh"
	}
	if reserved > 0 || sold > 0 {
		return "teralokasi_sebagian"
	}
	return "tersedia"
}

func maskPhone(wa *string, isDemo, approved bool) *string {
	if wa == nil || *wa == "" {
		return nil
	}
	if approved || isDemo {
		return wa
	}
	s := *wa
	if len(s) <= 6 {
		m := "628***"
		return &m
	}
	m := s[:5] + "****" + s[len(s)-2:]
	return &m
}

func (m *Module) handleListDemands(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	commodity := strings.TrimSpace(q.Get("commodity"))
	mine := strings.EqualFold(q.Get("mine"), "true")

	var args []any
	where := "WHERE 1=1"
	if commodity != "" {
		args = append(args, commodity)
		where += fmt.Sprintf(" AND (c.kode = $%d OR c.id::text = $%d)", len(args), len(args))
	}
	if mine {
		if u, ok := middleware.UserFromContext(r.Context()); ok {
			args = append(args, u.UserID)
			where += fmt.Sprintf(" AND bd.buyer_id = $%d", len(args))
		}
	} else {
		where += " AND bd.status = 'aktif'"
	}

	rows, err := m.pool.Query(r.Context(), `
		SELECT bd.id::text, bd.buyer_id::text, u.nama, u.nama_org, u.tipe_pembeli,
		       bd.commodity_id::text, c.kode, c.nama,
		       bd.qty_kg, bd.terpenuhi_kg, bd.harga_acuan, bd.dibutuhkan_pada::text,
		       bd.kabupaten, bd.lat, bd.lng, bd.mutu_min, bd.status, bd.is_demo, bd.created_at
		FROM buyer_demands bd
		INNER JOIN users u ON u.id = bd.buyer_id
		INNER JOIN commodities c ON c.id = bd.commodity_id
	`+where+` ORDER BY bd.harga_acuan DESC, bd.dibutuhkan_pada ASC`, args...)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal memuat kebutuhan pembeli")
		return
	}
	defer rows.Close()

	out := []DemandDTO{}
	for rows.Next() {
		var d DemandDTO
		var rawMutu []byte
		if err := rows.Scan(
			&d.ID, &d.BuyerID, &d.BuyerNama, &d.BuyerOrg, &d.TipePembeli,
			&d.CommodityID, &d.CommodityKode, &d.CommodityNama,
			&d.QtyKg, &d.TerpenuhiKg, &d.HargaAcuan, &d.DibutuhkanPada,
			&d.Kabupaten, &d.Lat, &d.Lng, &rawMutu, &d.Status, &d.IsDemo, &d.CreatedAt,
		); err != nil {
			httpx.Error(w, r, http.StatusInternalServerError, "SCAN_ERROR", "Gagal membaca kebutuhan pembeli")
			return
		}
		_ = json.Unmarshal(rawMutu, &d.MutuMin)
		d.SisaKuotaKg = math.Max(0, d.QtyKg-d.TerpenuhiKg)
		if d.QtyKg > 0 {
			d.ProgressPct = math.Min(100.0, math.Round((d.TerpenuhiKg/d.QtyKg)*1000.0)/10.0)
		}
		out = append(out, d)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"demands": out})
}

func (m *Module) handleCreateDemand(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	var body struct {
		CommodityID     string   `json:"commodityId"`
		CommodityKode   string   `json:"commodityKode"`
		QtyKg           float64  `json:"qtyKg"`
		HargaAcuan      int      `json:"hargaAcuan"`
		DibutuhkanPada  string   `json:"dibutuhkanPada"`
		Kabupaten       string   `json:"kabupaten"`
		KadarAirMaksPct *float64 `json:"kadarAirMaksPct"`
		Catatan         *string  `json:"catatan"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if body.QtyKg <= 0 || body.HargaAcuan <= 0 {
		httpx.Error(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "Volume dan harga acuan harus > 0")
		return
	}

	commRef := strings.TrimSpace(body.CommodityID)
	if commRef == "" {
		commRef = strings.TrimSpace(body.CommodityKode)
	}
	var commID string
	if err := m.pool.QueryRow(r.Context(), `SELECT id::text FROM commodities WHERE id::text = $1 OR kode = $1 LIMIT 1`, commRef).Scan(&commID); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_COMMODITY", "Komoditas tidak ditemukan")
		return
	}

	kab := strings.TrimSpace(body.Kabupaten)
	if kab == "" {
		kab = u.Kabupaten
	}
	lat, lng := engine.ResolveCoordinates(kab, nil, nil)
	dibutuhkan := strings.TrimSpace(body.DibutuhkanPada)
	if dibutuhkan == "" {
		dibutuhkan = time.Now().AddDate(0, 1, 0).Format("2006-01-02")
	}

	mutuBytes, _ := json.Marshal(MutuMin{KadarAirMaksPct: body.KadarAirMaksPct, Catatan: body.Catatan})
	var demandID string
	err := m.pool.QueryRow(r.Context(), `
		INSERT INTO buyer_demands (buyer_id, commodity_id, qty_kg, terpenuhi_kg, harga_acuan, dibutuhkan_pada, kabupaten, lat, lng, mutu_min, status, is_demo)
		VALUES ($1, $2, $3, 0, $4, $5::date, $6, $7, $8, $9::jsonb, 'aktif', FALSE)
		RETURNING id::text
	`, u.UserID, commID, body.QtyKg, body.HargaAcuan, dibutuhkan, kab, lat, lng, string(mutuBytes)).Scan(&demandID)
	if err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "DB_ERROR", err.Error())
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]any{"ok": true, "demandId": demandID})
}

func (m *Module) handleListSales(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())

	rows, err := m.pool.Query(r.Context(), `
		SELECT so.id::text, so.seller_id::text, us.nama,
		       so.stock_id::text, so.lot_id::text,
		       so.demand_id::text, ub.nama, ub.no_wa, bd.is_demo,
		       c.kode, c.nama, bd.harga_acuan,
		       so.qty_kg, so.harga_tawar, so.status, so.alasan_tolak, so.created_at, so.updated_at
		FROM sale_offers so
		INNER JOIN buyer_demands bd ON bd.id = so.demand_id
		INNER JOIN users us ON us.id = so.seller_id
		INNER JOIN users ub ON ub.id = bd.buyer_id
		INNER JOIN commodities c ON c.id = bd.commodity_id
		WHERE $1 = 'admin'
		   OR so.seller_id = $2
		   OR bd.buyer_id = $2
		   OR (so.lot_id IS NOT NULL AND EXISTS (
		        SELECT 1 FROM lot_contributions lc WHERE lc.lot_id = so.lot_id AND lc.user_id = $2
		      ))
		ORDER BY so.created_at DESC
	`, u.Role, u.UserID)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal memuat daftar penawaran jual")
		return
	}
	defer rows.Close()

	out := []SaleOfferDTO{}
	for rows.Next() {
		var s SaleOfferDTO
		var rawWa *string
		var isDemo bool
		if err := rows.Scan(
			&s.ID, &s.SellerID, &s.SellerNama,
			&s.StockID, &s.LotID,
			&s.DemandID, &s.BuyerNama, &rawWa, &isDemo,
			&s.CommodityKode, &s.CommodityNama, &s.HargaAcuan,
			&s.QtyKg, &s.HargaTawar, &s.Status, &s.AlasanTolak, &s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			httpx.Error(w, r, http.StatusInternalServerError, "SCAN_ERROR", "Gagal membaca penawaran jual")
			return
		}
		approved := s.Status == "diterima" || s.Status == "selesai"
		s.BuyerNoWa = maskPhone(rawWa, isDemo, approved)
		s.TotalNilaiRp = int(math.Round(s.QtyKg * float64(s.HargaTawar)))
		out = append(out, s)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"sales": out})
}

func (m *Module) handleSubmitSale(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	var body struct {
		StockID    *string `json:"stockId"`
		LotID      *string `json:"lotId"`
		DemandID   string  `json:"demandId"`
		QtyKg      float64 `json:"qtyKg"`
		HargaTawar int     `json:"hargaTawar"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}

	created, err := m.submitSaleTx(r.Context(), u.UserID, body.StockID, body.LotID, body.DemandID, body.QtyKg, body.HargaTawar)
	if err != nil {
		status, code := httpx.ClassifyDomainError(err)
		httpx.Error(w, r, status, code, err.Error())
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]any{"sale": created})
}

func (m *Module) submitSaleTx(ctx context.Context, userID string, stockID, lotID *string, demandID string, qtyKg float64, hargaTawar int) (map[string]any, error) {
	hasStock := stockID != nil && strings.TrimSpace(*stockID) != ""
	hasLot := lotID != nil && strings.TrimSpace(*lotID) != ""
	if hasStock == hasLot {
		return nil, errors.New("Pilih tepat satu sumber: stok mandiri atau lot kolektif")
	}
	if qtyKg <= 0 || hargaTawar <= 0 {
		return nil, errors.New("Volume dan harga tawar harus positif")
	}

	tx, err := m.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	// Consistent lock ordering: lock stocks/lots -> buyer_demands
	var sourceCommID string
	if hasStock {
		var ownerID string
		var totalKg, reservedKg, soldKg float64
		err := tx.QueryRow(ctx, `
			SELECT owner_id::text, commodity_id::text, qty_kg, reserved_kg, sold_kg
			FROM stocks WHERE id = $1 FOR UPDATE
		`, *stockID).Scan(&ownerID, &sourceCommID, &totalKg, &reservedKg, &soldKg)
		if err != nil {
			return nil, errors.New("Stok tidak ditemukan")
		}
		if ownerID != userID {
			return nil, errors.New("FORBIDDEN: Bukan pemilik stok")
		}
		freeKg := totalKg - reservedKg - soldKg
		if freeKg < qtyKg {
			return nil, fmt.Errorf("Stok bebas tidak mencukupi (tersisa %.0f kg)", freeKg)
		}
		newRes := reservedKg + qtyKg
		_, err = tx.Exec(ctx, `UPDATE stocks SET reserved_kg = $2, status = $3 WHERE id = $1`,
			*stockID, newRes, computeStockStatus(totalKg, newRes, soldKg))
		if err != nil {
			return nil, err
		}
	} else {
		var groupID string
		err := tx.QueryRow(ctx, `
			SELECT group_id::text, commodity_id::text FROM lots WHERE id = $1 FOR UPDATE
		`, *lotID).Scan(&groupID, &sourceCommID)
		if err != nil {
			return nil, errors.New("Lot tidak ditemukan")
		}
		var ketuaID string
		_ = tx.QueryRow(ctx, `SELECT ketua_id::text FROM farmer_groups WHERE id = $1`, groupID).Scan(&ketuaID)
		if ketuaID != userID {
			return nil, errors.New("FORBIDDEN: Hanya ketua poktan yang berhak menjual lot")
		}
		_, err = tx.Exec(ctx, `UPDATE lots SET status = 'diajukan_jual' WHERE id = $1`, *lotID)
		if err != nil {
			return nil, err
		}
	}

	var demandCommID, demandStatus string
	var demandQty, terpenuhiKg float64
	err = tx.QueryRow(ctx, `
		SELECT commodity_id::text, qty_kg, terpenuhi_kg, status
		FROM buyer_demands WHERE id = $1 FOR UPDATE
	`, demandID).Scan(&demandCommID, &demandQty, &terpenuhiKg, &demandStatus)
	if err != nil || demandStatus != "aktif" {
		return nil, errors.New("Kebutuhan pembeli tidak ditemukan atau sudah ditutup")
	}
	if demandCommID != sourceCommID {
		return nil, errors.New("Komoditas stok harus sesuai dengan kebutuhan pembeli")
	}
	remaining := demandQty - terpenuhiKg
	if remaining < qtyKg {
		return nil, fmt.Errorf("Sisa kuota pembeli tinggal %.0f kg", remaining)
	}

	var offerID string
	err = tx.QueryRow(ctx, `
		INSERT INTO sale_offers (seller_id, stock_id, lot_id, demand_id, qty_kg, harga_tawar, status)
		VALUES ($1, $2, $3, $4, $5, $6, 'diajukan')
		RETURNING id::text
	`, userID, stockID, lotID, demandID, qtyKg, hargaTawar).Scan(&offerID)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return map[string]any{
		"id":         offerID,
		"demandId":   demandID,
		"qtyKg":      qtyKg,
		"hargaTawar": hargaTawar,
		"status":     "diajukan",
	}, nil
}

func (m *Module) handleRespondSale(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	offerID := r.PathValue("id")

	var body struct {
		Action string  `json:"action"` // terima | tolak | selesai | batal
		Reason *string `json:"reason"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}

	res, err := m.respondSaleTx(r.Context(), u.UserID, offerID, strings.ToLower(strings.TrimSpace(body.Action)), body.Reason)
	if err != nil {
		status, code := httpx.ClassifyDomainError(err)
		httpx.Error(w, r, status, code, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, res)
}

func (m *Module) respondSaleTx(ctx context.Context, actorID, offerID, action string, reason *string) (map[string]any, error) {
	tx, err := m.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var sellerID, demandID, curStatus string
	var stockID, lotID *string
	var qtyKg float64
	var hargaTawar int
	err = tx.QueryRow(ctx, `
		SELECT seller_id::text, stock_id::text, lot_id::text, demand_id::text, qty_kg, harga_tawar, status
		FROM sale_offers WHERE id = $1 FOR UPDATE
	`, offerID).Scan(&sellerID, &stockID, &lotID, &demandID, &qtyKg, &hargaTawar, &curStatus)
	if err != nil {
		return nil, errors.New("Penawaran jual tidak ditemukan")
	}

	releaseStock := func() error {
		if stockID == nil {
			return nil
		}
		var tKg, rKg, sKg float64
		if err := tx.QueryRow(ctx, `SELECT qty_kg, reserved_kg, sold_kg FROM stocks WHERE id = $1 FOR UPDATE`, *stockID).Scan(&tKg, &rKg, &sKg); err != nil {
			return nil
		}
		nextRes := math.Max(0, rKg-qtyKg)
		_, err := tx.Exec(ctx, `UPDATE stocks SET reserved_kg = $2, status = $3 WHERE id = $1`,
			*stockID, nextRes, computeStockStatus(tKg, nextRes, sKg))
		return err
	}

	finalizeStock := func() error {
		if stockID == nil {
			return nil
		}
		var tKg, rKg, sKg float64
		if err := tx.QueryRow(ctx, `SELECT qty_kg, reserved_kg, sold_kg FROM stocks WHERE id = $1 FOR UPDATE`, *stockID).Scan(&tKg, &rKg, &sKg); err != nil {
			return nil
		}
		nextRes := math.Max(0, rKg-qtyKg)
		nextSold := math.Min(tKg, sKg+qtyKg)
		_, err := tx.Exec(ctx, `UPDATE stocks SET reserved_kg = $2, sold_kg = $3, status = $4 WHERE id = $1`,
			*stockID, nextRes, nextSold, computeStockStatus(tKg, nextRes, nextSold))
		return err
	}

	var buyerID string
	var demandQty, terpenuhiKg float64
	err = tx.QueryRow(ctx, `
		SELECT buyer_id::text, qty_kg, terpenuhi_kg FROM buyer_demands WHERE id = $1 FOR UPDATE
	`, demandID).Scan(&buyerID, &demandQty, &terpenuhiKg)
	if err != nil {
		return nil, errors.New("Kebutuhan pembeli tidak ditemukan")
	}

	if action == "batal" {
		if sellerID != actorID {
			return nil, errors.New("FORBIDDEN: Hanya penjual yang dapat membatalkan")
		}
		if curStatus != "diajukan" && curStatus != "diterima" {
			return nil, errors.New("Status penawaran tidak dapat dibatalkan")
		}
		if curStatus == "diterima" {
			nextFul := math.Max(0, terpenuhiKg-qtyKg)
			dStatus := "aktif"
			if nextFul >= demandQty {
				dStatus = "terpenuhi"
			}
			_, _ = tx.Exec(ctx, `UPDATE buyer_demands SET terpenuhi_kg = $2, status = $3 WHERE id = $1`, demandID, nextFul, dStatus)
		}
		if err := releaseStock(); err != nil {
			return nil, err
		}
		if lotID != nil {
			_, _ = tx.Exec(ctx, `UPDATE lots SET status = 'siap_ajukan' WHERE id = $1`, *lotID)
		}
		_, err = tx.Exec(ctx, `UPDATE sale_offers SET status = 'dibatalkan', alasan_tolak = $2, updated_at = NOW() WHERE id = $1`, offerID, reason)
		if err != nil {
			return nil, err
		}
		if err := tx.Commit(ctx); err != nil {
			return nil, err
		}
		return map[string]any{"ok": true, "status": "dibatalkan"}, nil
	}

	if buyerID != actorID {
		return nil, errors.New("FORBIDDEN: Hanya pembeli pemilik kebutuhan yang berwenang")
	}

	switch {
	case action == "terima" && curStatus == "diajukan":
		rem := demandQty - terpenuhiKg
		if rem < qtyKg {
			return nil, fmt.Errorf("Sisa kebutuhan tinggal %.0f kg", rem)
		}
		nextFul := terpenuhiKg + qtyKg
		dStatus := "aktif"
		if nextFul >= demandQty {
			dStatus = "terpenuhi"
		}
		_, err = tx.Exec(ctx, `UPDATE buyer_demands SET terpenuhi_kg = $2, status = $3 WHERE id = $1`, demandID, nextFul, dStatus)
		if err != nil {
			return nil, err
		}
		_, err = tx.Exec(ctx, `UPDATE sale_offers SET status = 'diterima', updated_at = NOW() WHERE id = $1`, offerID)
		if err != nil {
			return nil, err
		}
		if err := tx.Commit(ctx); err != nil {
			return nil, err
		}
		return map[string]any{"ok": true, "status": "diterima"}, nil

	case action == "tolak" && curStatus == "diajukan":
		if err := releaseStock(); err != nil {
			return nil, err
		}
		if lotID != nil {
			_, _ = tx.Exec(ctx, `UPDATE lots SET status = 'siap_ajukan' WHERE id = $1`, *lotID)
		}
		_, err = tx.Exec(ctx, `UPDATE sale_offers SET status = 'ditolak', alasan_tolak = $2, updated_at = NOW() WHERE id = $1`, offerID, reason)
		if err != nil {
			return nil, err
		}
		if err := tx.Commit(ctx); err != nil {
			return nil, err
		}
		return map[string]any{"ok": true, "status": "ditolak"}, nil

	case action == "selesai" && curStatus == "diterima":
		if err := finalizeStock(); err != nil {
			return nil, err
		}
		if lotID != nil {
			_, _ = tx.Exec(ctx, `UPDATE lots SET status = 'selesai' WHERE id = $1`, *lotID)
		}
		metaBytes, _ := json.Marshal(map[string]any{"demandId": demandID, "hargaTawar": hargaTawar})
		_, _ = tx.Exec(ctx, `
			INSERT INTO impact_events (jenis, user_id, ref_id, nilai, meta)
			VALUES ('stok_terserap', $1, $2, $3, $4::jsonb)
		`, sellerID, offerID, qtyKg, string(metaBytes))

		// Estimasi tambahan pendapatan dibanding panjar diskon pasar (~15% margin dilindungi)
		estGain := math.Round(qtyKg * float64(hargaTawar) * 0.12)
		_, _ = tx.Exec(ctx, `
			INSERT INTO impact_events (jenis, user_id, ref_id, nilai, meta)
			VALUES ('tambahan_pendapatan', $1, $2, $3, $4::jsonb)
		`, sellerID, offerID, estGain, string(metaBytes))

		_, err = tx.Exec(ctx, `UPDATE sale_offers SET status = 'selesai', updated_at = NOW() WHERE id = $1`, offerID)
		if err != nil {
			return nil, err
		}
		if err := tx.Commit(ctx); err != nil {
			return nil, err
		}
		return map[string]any{"ok": true, "status": "selesai"}, nil

	default:
		return nil, fmt.Errorf("Transisi status tidak valid dari %s ke %s", curStatus, action)
	}
}
