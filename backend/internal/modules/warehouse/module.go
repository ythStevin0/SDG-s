package warehouse

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"sort"
	"strconv"
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
	requireAuth := middleware.RequireAuth(m.cfg.JWTSecret)
	requireGudang := middleware.RequireAuth(m.cfg.JWTSecret, "gudang", "admin")
	requirePetani := middleware.RequireAuth(m.cfg.JWTSecret, "petani", "admin")

	mux.HandleFunc("GET /api/v1/warehouses", m.handleListWarehouses)
	mux.HandleFunc("POST /api/v1/warehouses", requireGudang(m.handleCreateWarehouse))
	mux.HandleFunc("PUT /api/v1/warehouses/{id}", requireGudang(m.handleUpdateWarehouse))

	mux.HandleFunc("GET /api/v1/rentals", requireAuth(m.handleListRentals))
	mux.HandleFunc("POST /api/v1/rentals", requirePetani(middleware.Idempotent(m.pool, m.handleSubmitRental)))
	mux.HandleFunc("POST /api/v1/rentals/{id}/respond", requireAuth(m.handleRespondRental))
}

type ScoredWarehouseDTO struct {
	ID                string                      `json:"id"`
	OwnerID           string                      `json:"ownerId"`
	Nama              string                      `json:"nama"`
	Kabupaten         string                      `json:"kabupaten"`
	Lat               float64                     `json:"lat"`
	Lng               float64                     `json:"lng"`
	KapasitasKg       float64                     `json:"kapasitasKg"`
	TersediaKg        float64                     `json:"tersediaKg"`
	TarifPerKgHari    float64                     `json:"tarifPerKgHari"`
	MinVolumeKg       float64                     `json:"minVolumeKg"`
	MinHari           int                         `json:"minHari"`
	IsSrg             bool                        `json:"isSrg"`
	KomoditasDiterima []string                    `json:"komoditasDiterima"`
	Checklist         engine.WarehouseChecklist   `json:"checklist"`
	KontakWa          *string                     `json:"kontakWa,omitempty"`
	IsDemo            bool                        `json:"isDemo"`
	Score             engine.WarehouseScoreResult `json:"score"`
	EstimasiSewa30Hr  int                         `json:"estimasiSewa30Hr"`
}

type RentalRequestDTO struct {
	ID            string    `json:"id"`
	RequesterID   string    `json:"requesterId"`
	RequesterNama string    `json:"requesterNama"`
	StockID       *string   `json:"stockId"`
	LotID         *string   `json:"lotId"`
	WarehouseID   string    `json:"warehouseId"`
	WarehouseNama string    `json:"warehouseNama"`
	Kabupaten     string    `json:"kabupaten"`
	KontakWa      *string   `json:"kontakWa,omitempty"`
	QtyKg         float64   `json:"qtyKg"`
	Hari          int       `json:"hari"`
	EstimasiBiaya int       `json:"estimasiBiaya"`
	Status        string    `json:"status"`
	AlasanTolak   *string   `json:"alasanTolak"`
	CreatedAt     time.Time `json:"createdAt"`
	UpdatedAt     time.Time `json:"updatedAt"`
}

func maskPhone(wa *string, isDemo bool, approved bool) *string {
	if wa == nil || *wa == "" {
		return nil
	}
	if approved || isDemo {
		return wa
	}
	s := *wa
	if len(s) <= 6 {
		masked := "628***"
		return &masked
	}
	masked := s[:5] + "****" + s[len(s)-2:]
	return &masked
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

func (m *Module) handleListWarehouses(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	commodityKode := strings.TrimSpace(q.Get("commodity"))
	if commodityKode == "" {
		commodityKode = "jagung"
	}
	farmerKab := strings.TrimSpace(q.Get("kabupaten"))
	if farmerKab == "" {
		if u, ok := middleware.UserFromContext(r.Context()); ok && u.Kabupaten != "" {
			farmerKab = u.Kabupaten
		} else {
			farmerKab = "Banyumas"
		}
	}
	qtyNeeded := 5000.0
	if v, err := strconv.ParseFloat(q.Get("qtyKg"), 64); err == nil && v > 0 {
		qtyNeeded = v
	}
	onlySrg := strings.EqualFold(q.Get("onlySrg"), "true")
	ownerOnly := strings.EqualFold(q.Get("mine"), "true")

	// Ambil parameter komoditas untuk skor kelayakan gudang anti-NaN
	commodities, _ := m.catalog.ListCommodities(r.Context())
	params := engine.CommodityParams{
		KadarAirMaksPct: 15,
		TarifSewaMurah:  1,
		TarifSewaMahal:  8,
		FasilitasWajib:  []string{"ventilasi", "lantai_palet_kering", "kontrol_hama"},
	}
	for _, c := range commodities {
		if c.Kode == commodityKode {
			params = c.Params
			break
		}
	}

	var args []any
	where := "WHERE 1=1"
	if onlySrg {
		where += " AND is_srg = TRUE"
	}
	if ownerOnly {
		if u, ok := middleware.UserFromContext(r.Context()); ok {
			args = append(args, u.UserID)
			where += fmt.Sprintf(" AND owner_id = $%d", len(args))
		}
	}

	rows, err := m.pool.Query(r.Context(), `
		SELECT id::text, owner_id::text, nama, kabupaten, lat, lng,
		       kapasitas_kg, tersedia_kg, tarif_per_kg_hari, min_volume_kg, min_hari,
		       is_srg, komoditas_diterima, checklist, kontak_wa, is_demo
		FROM warehouses
	`+where+` ORDER BY is_srg DESC, tersedia_kg DESC`, args...)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal memuat daftar gudang")
		return
	}
	defer rows.Close()

	out := []ScoredWarehouseDTO{}
	for rows.Next() {
		var item ScoredWarehouseDTO
		var rawChecklist []byte
		var rawKontak *string
		if err := rows.Scan(
			&item.ID, &item.OwnerID, &item.Nama, &item.Kabupaten, &item.Lat, &item.Lng,
			&item.KapasitasKg, &item.TersediaKg, &item.TarifPerKgHari, &item.MinVolumeKg, &item.MinHari,
			&item.IsSrg, &item.KomoditasDiterima, &rawChecklist, &rawKontak, &item.IsDemo,
		); err != nil {
			httpx.Error(w, r, http.StatusInternalServerError, "SCAN_ERROR", "Gagal membaca gudang")
			return
		}
		_ = json.Unmarshal(rawChecklist, &item.Checklist)
		item.KontakWa = maskPhone(rawKontak, item.IsDemo, false)

		ent := engine.WarehouseEntity{
			ID:                item.ID,
			Nama:              item.Nama,
			Kabupaten:         item.Kabupaten,
			Lat:               item.Lat,
			Lng:               item.Lng,
			KapasitasKg:       item.KapasitasKg,
			TersediaKg:        item.TersediaKg,
			TarifPerKgHari:    item.TarifPerKgHari,
			MinVolumeKg:       item.MinVolumeKg,
			MinHari:           item.MinHari,
			IsSrg:             item.IsSrg,
			KomoditasDiterima: item.KomoditasDiterima,
			Checklist:         item.Checklist,
		}
		item.Score = engine.ScoreWarehouse(ent, commodityKode, params, qtyNeeded, farmerKab, nil, nil)
		item.EstimasiSewa30Hr = int(math.Round(qtyNeeded * item.TarifPerKgHari * 30.0))
		out = append(out, item)
	}

	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Score.IsEligible != out[j].Score.IsEligible {
			return out[i].Score.IsEligible
		}
		return out[i].Score.TotalScore > out[j].Score.TotalScore
	})

	httpx.JSON(w, http.StatusOK, map[string]any{"warehouses": out})
}

func (m *Module) handleCreateWarehouse(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	var body struct {
		Nama              string                    `json:"nama"`
		Kabupaten         string                    `json:"kabupaten"`
		Lat               *float64                  `json:"lat"`
		Lng               *float64                  `json:"lng"`
		KapasitasKg       float64                   `json:"kapasitasKg"`
		TersediaKg        float64                   `json:"tersediaKg"`
		TarifPerKgHari    float64                   `json:"tarifPerKgHari"`
		MinVolumeKg       float64                   `json:"minVolumeKg"`
		MinHari           int                       `json:"minHari"`
		IsSrg             bool                      `json:"isSrg"`
		KomoditasDiterima []string                  `json:"komoditasDiterima"`
		Checklist         engine.WarehouseChecklist `json:"checklist"`
		KontakWa          *string                   `json:"kontakWa"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if strings.TrimSpace(body.Nama) == "" || body.KapasitasKg <= 0 {
		httpx.Error(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "Nama gudang dan kapasitas > 0 wajib diisi")
		return
	}
	kab := strings.TrimSpace(body.Kabupaten)
	if kab == "" {
		kab = u.Kabupaten
	}
	lat, lng := engine.ResolveCoordinates(kab, body.Lat, body.Lng)
	if len(body.KomoditasDiterima) == 0 {
		body.KomoditasDiterima = []string{"jagung", "gabah"}
	}
	if body.MinHari <= 0 {
		body.MinHari = 14
	}
	checkBytes, _ := json.Marshal(body.Checklist)

	var whID string
	err := m.pool.QueryRow(r.Context(), `
		INSERT INTO warehouses (owner_id, nama, kabupaten, lat, lng, kapasitas_kg, tersedia_kg, tarif_per_kg_hari, min_volume_kg, min_hari, is_srg, komoditas_diterima, checklist, kontak_wa, is_demo)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13::jsonb, $14, FALSE)
		RETURNING id::text
	`, u.UserID, strings.TrimSpace(body.Nama), kab, lat, lng, body.KapasitasKg, body.TersediaKg, body.TarifPerKgHari, body.MinVolumeKg, body.MinHari, body.IsSrg, body.KomoditasDiterima, string(checkBytes), body.KontakWa).Scan(&whID)
	if err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "DB_ERROR", err.Error())
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]any{"ok": true, "warehouseId": whID})
}

func (m *Module) handleUpdateWarehouse(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	id := r.PathValue("id")

	var body struct {
		KapasitasKg       *float64                   `json:"kapasitasKg"`
		TersediaKg        *float64                   `json:"tersediaKg"`
		TarifPerKgHari    *float64                   `json:"tarifPerKgHari"`
		MinVolumeKg       *float64                   `json:"minVolumeKg"`
		MinHari           *int                       `json:"minHari"`
		KomoditasDiterima []string                   `json:"komoditasDiterima"`
		Checklist         *engine.WarehouseChecklist `json:"checklist"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}

	var checkJSON *string
	if body.Checklist != nil {
		b, _ := json.Marshal(body.Checklist)
		s := string(b)
		checkJSON = &s
	}

	cmd, err := m.pool.Exec(r.Context(), `
		UPDATE warehouses
		SET kapasitas_kg = COALESCE($3, kapasitas_kg),
		    tersedia_kg = COALESCE($4, tersedia_kg),
		    tarif_per_kg_hari = COALESCE($5, tarif_per_kg_hari),
		    min_volume_kg = COALESCE($6, min_volume_kg),
		    min_hari = COALESCE($7, min_hari),
		    komoditas_diterima = CASE WHEN $8::text[] IS NOT NULL AND array_length($8::text[], 1) > 0 THEN $8::text[] ELSE komoditas_diterima END,
		    checklist = COALESCE($9::jsonb, checklist)
		WHERE id = $1 AND ($2 = 'admin' OR owner_id::text = $10)
	`, id, u.Role, body.KapasitasKg, body.TersediaKg, body.TarifPerKgHari, body.MinVolumeKg, body.MinHari, body.KomoditasDiterima, checkJSON, u.UserID)
	if err != nil || cmd.RowsAffected() == 0 {
		httpx.Error(w, r, http.StatusForbidden, "FORBIDDEN", "Gudang tidak ditemukan atau bukan milik Anda")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"ok": true})
}

// handleListRentals menyertakan hak baca bagi anggota penyumbang Lot Kolektif (PRD Bagian 9.4) dengan Eager JOIN.
func (m *Module) handleListRentals(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())

	rows, err := m.pool.Query(r.Context(), `
		SELECT rr.id::text, rr.requester_id::text, u.nama,
		       rr.stock_id::text, rr.lot_id::text,
		       rr.warehouse_id::text, wh.nama, wh.kabupaten, wh.kontak_wa, wh.is_demo,
		       rr.qty_kg, rr.hari, rr.estimasi_biaya, rr.status, rr.alasan_tolak, rr.created_at, rr.updated_at
		FROM rental_requests rr
		INNER JOIN warehouses wh ON wh.id = rr.warehouse_id
		INNER JOIN users u ON u.id = rr.requester_id
		WHERE $1 = 'admin'
		   OR rr.requester_id = $2
		   OR wh.owner_id = $2
		   OR (rr.lot_id IS NOT NULL AND EXISTS (
		        SELECT 1 FROM lot_contributions lc WHERE lc.lot_id = rr.lot_id AND lc.user_id = $2
		      ))
		ORDER BY rr.created_at DESC
	`, u.Role, u.UserID)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal memuat riwayat pengajuan sewa")
		return
	}
	defer rows.Close()

	out := []RentalRequestDTO{}
	for rows.Next() {
		var item RentalRequestDTO
		var rawWa *string
		var isDemo bool
		if err := rows.Scan(
			&item.ID, &item.RequesterID, &item.RequesterNama,
			&item.StockID, &item.LotID,
			&item.WarehouseID, &item.WarehouseNama, &item.Kabupaten, &rawWa, &isDemo,
			&item.QtyKg, &item.Hari, &item.EstimasiBiaya, &item.Status, &item.AlasanTolak, &item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			httpx.Error(w, r, http.StatusInternalServerError, "SCAN_ERROR", "Gagal membaca pengajuan sewa")
			return
		}
		approved := item.Status == "diterima" || item.Status == "selesai"
		item.KontakWa = maskPhone(rawWa, isDemo, approved)
		out = append(out, item)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"rentals": out})
}

func (m *Module) handleSubmitRental(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	var body struct {
		StockID     *string `json:"stockId"`
		LotID       *string `json:"lotId"`
		WarehouseID string  `json:"warehouseId"`
		QtyKg       float64 `json:"qtyKg"`
		Hari        int     `json:"hari"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}

	created, err := m.submitRentalTx(r.Context(), u.UserID, body.StockID, body.LotID, body.WarehouseID, body.QtyKg, body.Hari)
	if err != nil {
		status, code := httpx.ClassifyDomainError(err)
		httpx.Error(w, r, status, code, err.Error())
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]any{"rental": created})
}

func (m *Module) submitRentalTx(ctx context.Context, userID string, stockID, lotID *string, warehouseID string, qtyKg float64, hari int) (map[string]any, error) {
	hasStock := stockID != nil && strings.TrimSpace(*stockID) != ""
	hasLot := lotID != nil && strings.TrimSpace(*lotID) != ""
	if hasStock == hasLot {
		return nil, errors.New("Pilih tepat satu sumber: stok mandiri atau lot kolektif")
	}
	if qtyKg <= 0 || hari <= 0 {
		return nil, errors.New("Jumlah dan lama simpan harus lebih besar dari nol")
	}

	tx, err := m.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	// Consistent lock ordering (#12 & #26): lock stocks/lots -> warehouses
	if hasStock {
		var ownerID string
		var totalKg, reservedKg, soldKg float64
		err := tx.QueryRow(ctx, `
			SELECT owner_id::text, qty_kg, reserved_kg, sold_kg
			FROM stocks WHERE id = $1 FOR UPDATE
		`, *stockID).Scan(&ownerID, &totalKg, &reservedKg, &soldKg)
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
		var groupID, lotStatus string
		err := tx.QueryRow(ctx, `
			SELECT group_id::text, status FROM lots WHERE id = $1 FOR UPDATE
		`, *lotID).Scan(&groupID, &lotStatus)
		if err != nil {
			return nil, errors.New("Lot tidak ditemukan")
		}
		var ketuaID string
		_ = tx.QueryRow(ctx, `SELECT ketua_id::text FROM farmer_groups WHERE id = $1`, groupID).Scan(&ketuaID)
		if ketuaID != userID {
			return nil, errors.New("FORBIDDEN: Hanya ketua kelompok tani yang dapat mengajukan sewa lot")
		}
		if lotStatus != "siap_ajukan" && lotStatus != "mengumpulkan" {
			return nil, errors.New("Status lot belum/tidak siap diajukan")
		}
		_, err = tx.Exec(ctx, `UPDATE lots SET status = 'diajukan_sewa', warehouse_id = $2 WHERE id = $1`, *lotID, warehouseID)
		if err != nil {
			return nil, err
		}
	}

	var tersediaKg, minVolKg, tarif float64
	var minHari int
	err = tx.QueryRow(ctx, `
		SELECT tersedia_kg, min_volume_kg, min_hari, tarif_per_kg_hari
		FROM warehouses WHERE id = $1 FOR UPDATE
	`, warehouseID).Scan(&tersediaKg, &minVolKg, &minHari, &tarif)
	if err != nil {
		return nil, errors.New("Gudang tidak ditemukan")
	}
	if tersediaKg < qtyKg {
		return nil, fmt.Errorf("Kapasitas gudang tidak cukup (tersisa %.0f kg)", tersediaKg)
	}
	if qtyKg < minVolKg {
		return nil, fmt.Errorf("Volume di bawah batas minimum gudang (%.0f kg)", minVolKg)
	}
	if hari < minHari {
		return nil, fmt.Errorf("Lama simpan di bawah batas minimum gudang (%d hari)", minHari)
	}

	estimasi := int(math.Round(qtyKg * tarif * float64(hari)))
	var reqID string
	err = tx.QueryRow(ctx, `
		INSERT INTO rental_requests (requester_id, stock_id, lot_id, warehouse_id, qty_kg, hari, estimasi_biaya, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, 'diajukan')
		RETURNING id::text
	`, userID, stockID, lotID, warehouseID, qtyKg, hari, estimasi).Scan(&reqID)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return map[string]any{
		"id":            reqID,
		"warehouseId":   warehouseID,
		"qtyKg":         qtyKg,
		"hari":          hari,
		"estimasiBiaya": estimasi,
		"status":        "diajukan",
	}, nil
}

func (m *Module) handleRespondRental(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	reqID := r.PathValue("id")

	var body struct {
		Action string  `json:"action"` // terima | tolak | selesai | batal
		Reason *string `json:"reason"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}

	res, err := m.respondRentalTx(r.Context(), u.UserID, reqID, strings.ToLower(strings.TrimSpace(body.Action)), body.Reason)
	if err != nil {
		status, code := httpx.ClassifyDomainError(err)
		httpx.Error(w, r, status, code, err.Error())
		return
	}
	httpx.JSON(w, http.StatusOK, res)
}

func (m *Module) respondRentalTx(ctx context.Context, actorID, requestID, action string, reason *string) (map[string]any, error) {
	tx, err := m.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var requesterID, warehouseID, curStatus string
	var stockID, lotID *string
	var qtyKg float64
	var hari int
	err = tx.QueryRow(ctx, `
		SELECT requester_id::text, stock_id::text, lot_id::text, warehouse_id::text, qty_kg, hari, status
		FROM rental_requests WHERE id = $1 FOR UPDATE
	`, requestID).Scan(&requesterID, &stockID, &lotID, &warehouseID, &qtyKg, &hari, &curStatus)
	if err != nil {
		return nil, errors.New("Pengajuan sewa tidak ditemukan")
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

	var whOwnerID string
	var kapasitasKg, tersediaKg float64
	err = tx.QueryRow(ctx, `
		SELECT owner_id::text, kapasitas_kg, tersedia_kg FROM warehouses WHERE id = $1 FOR UPDATE
	`, warehouseID).Scan(&whOwnerID, &kapasitasKg, &tersediaKg)
	if err != nil {
		return nil, errors.New("Gudang tidak ditemukan")
	}

	if action == "batal" {
		if requesterID != actorID {
			return nil, errors.New("FORBIDDEN: Hanya pengaju yang dapat membatalkan")
		}
		if curStatus != "diajukan" && curStatus != "diterima" {
			return nil, errors.New("Pengajuan tidak dapat dibatalkan pada status ini")
		}
		if curStatus == "diterima" {
			_, _ = tx.Exec(ctx, `UPDATE warehouses SET tersedia_kg = $2 WHERE id = $1`,
				warehouseID, math.Min(kapasitasKg, tersediaKg+qtyKg))
		}
		if err := releaseStock(); err != nil {
			return nil, err
		}
		if lotID != nil {
			_, _ = tx.Exec(ctx, `UPDATE lots SET status = 'siap_ajukan' WHERE id = $1`, *lotID)
		}
		_, err = tx.Exec(ctx, `UPDATE rental_requests SET status = 'dibatalkan', alasan_tolak = $2, updated_at = NOW() WHERE id = $1`, requestID, reason)
		if err != nil {
			return nil, err
		}
		if err := tx.Commit(ctx); err != nil {
			return nil, err
		}
		return map[string]any{"ok": true, "status": "dibatalkan"}, nil
	}

	if whOwnerID != actorID {
		return nil, errors.New("FORBIDDEN: Hanya pemilik gudang yang dapat memproses permintaan ini")
	}

	switch {
	case action == "terima" && curStatus == "diajukan":
		if tersediaKg < qtyKg {
			return nil, fmt.Errorf("Kapasitas gudang tersisa %.0f kg, tidak mencukupi", tersediaKg)
		}
		_, err = tx.Exec(ctx, `UPDATE warehouses SET tersedia_kg = $2 WHERE id = $1`, warehouseID, tersediaKg-qtyKg)
		if err != nil {
			return nil, err
		}
		if lotID != nil {
			_, _ = tx.Exec(ctx, `UPDATE lots SET status = 'disimpan' WHERE id = $1`, *lotID)
		}
		_, err = tx.Exec(ctx, `UPDATE rental_requests SET status = 'diterima', updated_at = NOW() WHERE id = $1`, requestID)
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
		_, err = tx.Exec(ctx, `UPDATE rental_requests SET status = 'ditolak', alasan_tolak = $2, updated_at = NOW() WHERE id = $1`, requestID, reason)
		if err != nil {
			return nil, err
		}
		if err := tx.Commit(ctx); err != nil {
			return nil, err
		}
		return map[string]any{"ok": true, "status": "ditolak"}, nil

	case action == "selesai" && curStatus == "diterima":
		_, _ = tx.Exec(ctx, `UPDATE warehouses SET tersedia_kg = $2 WHERE id = $1`,
			warehouseID, math.Min(kapasitasKg, tersediaKg+qtyKg))
		if err := releaseStock(); err != nil {
			return nil, err
		}
		if lotID != nil {
			_, _ = tx.Exec(ctx, `UPDATE lots SET status = 'selesai' WHERE id = $1`, *lotID)
		}
		susutDicegah := math.Round(qtyKg * 0.02 * (float64(hari) / 30.0))
		metaBytes, _ := json.Marshal(map[string]any{"warehouseId": warehouseID, "qtyKg": qtyKg, "hari": hari})
		_, _ = tx.Exec(ctx, `
			INSERT INTO impact_events (jenis, user_id, ref_id, nilai, meta)
			VALUES ('susut_dicegah', $1, $2, $3, $4::jsonb)
		`, requesterID, requestID, susutDicegah, string(metaBytes))

		_, err = tx.Exec(ctx, `UPDATE rental_requests SET status = 'selesai', updated_at = NOW() WHERE id = $1`, requestID)
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
