package lot

import (
	"crypto/rand"
	"errors"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
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
	requirePetani := middleware.RequireAuth(m.cfg.JWTSecret, "petani", "admin")

	mux.HandleFunc("GET /api/v1/groups", requirePetani(m.handleListMyGroups))
	mux.HandleFunc("POST /api/v1/groups", requirePetani(middleware.Idempotent(m.pool, m.handleCreateGroup)))
	mux.HandleFunc("POST /api/v1/groups/join", requirePetani(m.handleJoinGroup))
	mux.HandleFunc("GET /api/v1/lots", requirePetani(m.handleListLots))
	mux.HandleFunc("POST /api/v1/lots", requirePetani(middleware.Idempotent(m.pool, m.handleCreateLot)))
	mux.HandleFunc("POST /api/v1/lots/{id}/contribute", requirePetani(middleware.Idempotent(m.pool, m.handleContributeToLot)))
}

type GroupDTO struct {
	ID          string    `json:"id"`
	Nama        string    `json:"nama"`
	Kabupaten   string    `json:"kabupaten"`
	KetuaID     string    `json:"ketuaId"`
	KetuaNama   string    `json:"ketuaNama"`
	KodeGabung  string    `json:"kodeGabung"`
	IsKetua     bool      `json:"isKetua"`
	MemberCount int       `json:"memberCount"`
	CreatedAt   time.Time `json:"createdAt"`
}

type ContributionDTO struct {
	ID        string    `json:"id"`
	UserID    string    `json:"userId"`
	UserNama  string    `json:"userNama"`
	StockID   string    `json:"stockId"`
	QtyKg     float64   `json:"qtyKg"`
	SharePct  float64   `json:"sharePct"`
	CreatedAt time.Time `json:"createdAt"`
}

type LotDTO struct {
	ID            string            `json:"id"`
	GroupID       string            `json:"groupId"`
	GroupNama     string            `json:"groupNama"`
	KodeGabung    string            `json:"kodeGabung"`
	KetuaID       string            `json:"ketuaId"`
	IsKetua       bool              `json:"isKetua"`
	CommodityID   string            `json:"commodityId"`
	CommodityKode string            `json:"commodityKode"`
	CommodityNama string            `json:"commodityNama"`
	TargetKg      float64           `json:"targetKg"`
	TerkumpulKg   float64           `json:"terkumpulKg"`
	ProgressPct   float64           `json:"progressPct"`
	Status        string            `json:"status"`
	WarehouseID   *string           `json:"warehouseId"`
	WarehouseNama *string           `json:"warehouseNama"`
	Contributions []ContributionDTO `json:"contributions"`
	CreatedAt     time.Time         `json:"createdAt"`
}

func randomInviteCode() string {
	const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	for i := range b {
		b[i] = chars[int(b[i])%len(chars)]
	}
	return string(b)
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

func (m *Module) handleListMyGroups(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())

	rows, err := m.pool.Query(r.Context(), `
		SELECT fg.id::text, fg.nama, fg.kabupaten, fg.ketua_id::text, u.nama, fg.kode_gabung, fg.created_at,
		       (SELECT COUNT(*) FROM farmer_group_members m2 WHERE m2.group_id = fg.id)::int AS member_count
		FROM farmer_groups fg
		INNER JOIN farmer_group_members fgm ON fgm.group_id = fg.id
		INNER JOIN users u ON u.id = fg.ketua_id
		WHERE fgm.user_id = $1
		ORDER BY fg.created_at DESC
	`, u.UserID)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal memuat kelompok tani")
		return
	}
	defer rows.Close()

	groups := []GroupDTO{}
	for rows.Next() {
		var g GroupDTO
		if err := rows.Scan(&g.ID, &g.Nama, &g.Kabupaten, &g.KetuaID, &g.KetuaNama, &g.KodeGabung, &g.CreatedAt, &g.MemberCount); err != nil {
			httpx.Error(w, r, http.StatusInternalServerError, "SCAN_ERROR", "Gagal membaca kelompok tani")
			return
		}
		g.IsKetua = g.KetuaID == u.UserID
		groups = append(groups, g)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"groups": groups})
}

func (m *Module) handleCreateGroup(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	var body struct {
		Nama       string `json:"nama"`
		Kabupaten  string `json:"kabupaten"`
		KodeGabung string `json:"kodeGabung"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	nama := strings.TrimSpace(body.Nama)
	if len(nama) < 3 {
		httpx.Error(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "Nama kelompok tani minimal 3 karakter")
		return
	}
	kab := strings.TrimSpace(body.Kabupaten)
	if kab == "" {
		kab = u.Kabupaten
	}
	kode := strings.ToUpper(strings.TrimSpace(body.KodeGabung))
	if kode == "" {
		kode = randomInviteCode()
	}
	if len(kode) > 8 {
		kode = kode[:8]
	}

	tx, err := m.pool.Begin(r.Context())
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "TX_ERROR", "Gagal memulai transaksi")
		return
	}
	defer tx.Rollback(r.Context())

	var g GroupDTO
	err = tx.QueryRow(r.Context(), `
		INSERT INTO farmer_groups (nama, kabupaten, ketua_id, kode_gabung)
		VALUES ($1, $2, $3, $4)
		RETURNING id::text, nama, kabupaten, ketua_id::text, kode_gabung, created_at
	`, nama, kab, u.UserID, kode).Scan(&g.ID, &g.Nama, &g.Kabupaten, &g.KetuaID, &g.KodeGabung, &g.CreatedAt)
	if err != nil {
		httpx.Error(w, r, http.StatusConflict, "CODE_EXISTS", "Kode gabung sudah digunakan kelompok lain")
		return
	}

	_, err = tx.Exec(r.Context(), `
		INSERT INTO farmer_group_members (group_id, user_id)
		VALUES ($1, $2)
		ON CONFLICT DO NOTHING
	`, g.ID, u.UserID)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal mendaftarkan ketua anggota")
		return
	}

	if err := tx.Commit(r.Context()); err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "COMMIT_ERROR", "Gagal menyimpan kelompok tani")
		return
	}
	g.KetuaNama = u.Nama
	g.IsKetua = true
	g.MemberCount = 1

	httpx.JSON(w, http.StatusCreated, map[string]any{"group": g})
}

func (m *Module) handleJoinGroup(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	var body struct {
		KodeGabung string `json:"kodeGabung"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	kode := strings.ToUpper(strings.TrimSpace(body.KodeGabung))
	if kode == "" {
		httpx.Error(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "Kode gabung wajib diisi (mis. TANIJAYA)")
		return
	}

	var groupID, groupNama string
	err := m.pool.QueryRow(r.Context(), `
		SELECT id::text, nama FROM farmer_groups WHERE UPPER(kode_gabung) = $1
	`, kode).Scan(&groupID, &groupNama)
	if err != nil {
		httpx.Error(w, r, http.StatusNotFound, "GROUP_NOT_FOUND", "Kode gabung poktan tidak ditemukan")
		return
	}

	_, err = m.pool.Exec(r.Context(), `
		INSERT INTO farmer_group_members (group_id, user_id)
		VALUES ($1, $2)
		ON CONFLICT (group_id, user_id) DO NOTHING
	`, groupID, u.UserID)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal bergabung ke poktan")
		return
	}

	httpx.JSON(w, http.StatusOK, map[string]any{
		"ok":      true,
		"groupId": groupID,
		"nama":    groupNama,
	})
}

// handleListLots mengambil seluruh lot kelompok yang diikuti petani + batch query kontribusi (anti N+1).
func (m *Module) handleListLots(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())

	rows, err := m.pool.Query(r.Context(), `
		SELECT l.id::text, l.group_id::text, fg.nama, fg.kode_gabung, fg.ketua_id::text,
		       l.commodity_id::text, c.kode, c.nama,
		       l.target_kg, l.terkumpul_kg, l.status,
		       l.warehouse_id::text, wh.nama, l.created_at
		FROM lots l
		INNER JOIN farmer_groups fg ON fg.id = l.group_id
		INNER JOIN farmer_group_members fgm ON fgm.group_id = fg.id
		INNER JOIN commodities c ON c.id = l.commodity_id
		LEFT JOIN warehouses wh ON wh.id = l.warehouse_id
		WHERE fgm.user_id = $1
		ORDER BY l.created_at DESC
	`, u.UserID)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal memuat lot kolektif")
		return
	}
	defer rows.Close()

	var lots []LotDTO
	var lotIDs []string
	lotIndex := make(map[string]int)

	for rows.Next() {
		var lt LotDTO
		if err := rows.Scan(
			&lt.ID, &lt.GroupID, &lt.GroupNama, &lt.KodeGabung, &lt.KetuaID,
			&lt.CommodityID, &lt.CommodityKode, &lt.CommodityNama,
			&lt.TargetKg, &lt.TerkumpulKg, &lt.Status,
			&lt.WarehouseID, &lt.WarehouseNama, &lt.CreatedAt,
		); err != nil {
			httpx.Error(w, r, http.StatusInternalServerError, "SCAN_ERROR", "Gagal membaca data lot")
			return
		}
		lt.IsKetua = lt.KetuaID == u.UserID
		if lt.TargetKg > 0 {
			lt.ProgressPct = math.Min(100.0, math.Round((lt.TerkumpulKg/lt.TargetKg)*1000.0)/10.0)
		}
		lt.Contributions = []ContributionDTO{}
		lotIndex[lt.ID] = len(lots)
		lotIDs = append(lotIDs, lt.ID)
		lots = append(lots, lt)
	}

	// Batch query seluruh kontribusi dalam 1 query (bukan N+1 query di dalam loop)
	if len(lotIDs) > 0 {
		cRows, err := m.pool.Query(r.Context(), `
			SELECT lc.id::text, lc.lot_id::text, lc.user_id::text, u.nama, lc.stock_id::text, lc.qty_kg, lc.created_at
			FROM lot_contributions lc
			INNER JOIN users u ON u.id = lc.user_id
			WHERE lc.lot_id::text = ANY($1)
			ORDER BY lc.created_at ASC
		`, lotIDs)
		if err == nil {
			for cRows.Next() {
				var c ContributionDTO
				var lotID string
				if cRows.Scan(&c.ID, &lotID, &c.UserID, &c.UserNama, &c.StockID, &c.QtyKg, &c.CreatedAt) == nil {
					if idx, ok := lotIndex[lotID]; ok {
						denom := lots[idx].TerkumpulKg
						if denom > 0 {
							c.SharePct = math.Round((c.QtyKg/denom)*1000.0) / 10.0
						}
						lots[idx].Contributions = append(lots[idx].Contributions, c)
					}
				}
			}
			cRows.Close()
		}
	}

	if lots == nil {
		lots = []LotDTO{}
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"lots": lots})
}

func (m *Module) handleCreateLot(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	var body struct {
		GroupID       string  `json:"groupId"`
		CommodityID   string  `json:"commodityId"`
		CommodityKode string  `json:"commodityKode"`
		TargetKg      float64 `json:"targetKg"`
		WarehouseID   *string `json:"warehouseId"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if body.TargetKg <= 0 || body.GroupID == "" {
		httpx.Error(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "Kelompok tani dan target volume (> 0 kg) wajib diisi")
		return
	}

	var ketuaID string
	if err := m.pool.QueryRow(r.Context(), `SELECT ketua_id::text FROM farmer_groups WHERE id = $1`, body.GroupID).Scan(&ketuaID); err != nil {
		httpx.Error(w, r, http.StatusNotFound, "GROUP_NOT_FOUND", "Kelompok tani tidak ditemukan")
		return
	}
	if ketuaID != u.UserID && u.Role != "admin" {
		httpx.Error(w, r, http.StatusForbidden, "FORBIDDEN", "Hanya ketua kelompok tani yang dapat membuat Lot Kolektif")
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

	var lotID string
	err := m.pool.QueryRow(r.Context(), `
		INSERT INTO lots (group_id, commodity_id, target_kg, terkumpul_kg, status, warehouse_id)
		VALUES ($1, $2, $3, 0, 'mengumpulkan', $4)
		RETURNING id::text
	`, body.GroupID, commID, body.TargetKg, body.WarehouseID).Scan(&lotID)
	if err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "DB_ERROR", "Gagal membuat lot kolektif")
		return
	}

	httpx.JSON(w, http.StatusCreated, map[string]any{"ok": true, "lotId": lotID})
}

// handleContributeToLot mengunci stok & lot dengan SELECT ... FOR UPDATE (urutan konsisten: stocks -> lots).
func (m *Module) handleContributeToLot(w http.ResponseWriter, r *http.Request) {
	u, _ := middleware.UserFromContext(r.Context())
	lotID := r.PathValue("id")

	var body struct {
		StockID string  `json:"stockId"`
		QtyKg   float64 `json:"qtyKg"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}
	if body.QtyKg <= 0 || body.StockID == "" {
		httpx.Error(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "Pilih stok dan jumlah kg > 0")
		return
	}

	tx, err := m.pool.Begin(r.Context())
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "TX_ERROR", "Gagal memulai transaksi")
		return
	}
	defer tx.Rollback(r.Context())

	// 1. Lock stocks terlebih dahulu (consistent lock ordering)
	var stOwner, stCommID string
	var qtyKg, reservedKg, soldKg float64
	err = tx.QueryRow(r.Context(), `
		SELECT owner_id::text, commodity_id::text, qty_kg, reserved_kg, sold_kg
		FROM stocks
		WHERE id = $1
		FOR UPDATE
	`, body.StockID).Scan(&stOwner, &stCommID, &qtyKg, &reservedKg, &soldKg)
	if err != nil {
		httpx.Error(w, r, http.StatusNotFound, "STOCK_NOT_FOUND", "Stok tidak ditemukan")
		return
	}
	if stOwner != u.UserID {
		httpx.Error(w, r, http.StatusForbidden, "FORBIDDEN", "FORBIDDEN: Bukan pemilik stok")
		return
	}
	freeKg := qtyKg - reservedKg - soldKg
	if freeKg < body.QtyKg {
		httpx.Error(w, r, http.StatusBadRequest, "INSUFFICIENT_STOCK", "Stok bebas tidak mencukupi")
		return
	}

	// 2. Lock lots
	var groupID, lotCommID, lotStatus string
	var targetKg, terkumpulKg float64
	err = tx.QueryRow(r.Context(), `
		SELECT group_id::text, commodity_id::text, target_kg, terkumpul_kg, status
		FROM lots
		WHERE id = $1
		FOR UPDATE
	`, lotID).Scan(&groupID, &lotCommID, &targetKg, &terkumpulKg, &lotStatus)
	if err != nil {
		httpx.Error(w, r, http.StatusNotFound, "LOT_NOT_FOUND", "Lot tidak ditemukan")
		return
	}
	if lotCommID != stCommID {
		httpx.Error(w, r, http.StatusBadRequest, "COMMODITY_MISMATCH", "Komoditas stok harus sama dengan komoditas Lot Kolektif")
		return
	}
	if lotStatus != "mengumpulkan" && lotStatus != "siap_ajukan" {
		httpx.Error(w, r, http.StatusBadRequest, "LOT_LOCKED", "Lot sudah dalam proses pengajuan/selesai")
		return
	}

	// Pastikan anggota kelompok tani
	var isMember bool
	_ = tx.QueryRow(r.Context(), `
		SELECT EXISTS(SELECT 1 FROM farmer_group_members WHERE group_id = $1 AND user_id = $2)
	`, groupID, u.UserID).Scan(&isMember)
	if !isMember {
		if err := errors.New("bukan anggota poktan"); err != nil {
			httpx.Error(w, r, http.StatusForbidden, "NOT_GROUP_MEMBER", "Gabung terlebih dahulu ke Poktan dengan kode gabung")
			return
		}
	}

	newReserved := reservedKg + body.QtyKg
	newStStatus := computeStockStatus(qtyKg, newReserved, soldKg)
	_, err = tx.Exec(r.Context(), `
		UPDATE stocks SET reserved_kg = $2, status = $3 WHERE id = $1
	`, body.StockID, newReserved, newStStatus)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal mengunci stok")
		return
	}

	newTerkumpul := terkumpulKg + body.QtyKg
	newLotStatus := lotStatus
	if newTerkumpul >= targetKg {
		newLotStatus = "siap_ajukan"
	}
	_, err = tx.Exec(r.Context(), `
		UPDATE lots SET terkumpul_kg = $2, status = $3 WHERE id = $1
	`, lotID, newTerkumpul, newLotStatus)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal memperbarui volume lot")
		return
	}

	var contribID string
	err = tx.QueryRow(r.Context(), `
		INSERT INTO lot_contributions (lot_id, stock_id, user_id, qty_kg)
		VALUES ($1, $2, $3, $4)
		RETURNING id::text
	`, lotID, body.StockID, u.UserID, body.QtyKg).Scan(&contribID)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal mencatat kontribusi lot")
		return
	}

	if err := tx.Commit(r.Context()); err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "COMMIT_ERROR", "Gagal menyimpan kontribusi lot")
		return
	}

	httpx.JSON(w, http.StatusCreated, map[string]any{
		"ok":            true,
		"contributionId": contribID,
		"terkumpulKg":   newTerkumpul,
		"lotStatus":     newLotStatus,
	})
}
