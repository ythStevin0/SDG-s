package impact

import (
	"context"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"simpanjual/backend/internal/platform/cache"
	"simpanjual/backend/internal/platform/httpx"
)

type Module struct {
	pool      *pgxpool.Pool
	cache     *cache.TTLCache
	startedAt time.Time
}

func NewModule(pool *pgxpool.Pool, c *cache.TTLCache) *Module {
	return &Module{pool: pool, cache: c, startedAt: time.Now()}
}

func (m *Module) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /healthz", m.handleLiveness)
	mux.HandleFunc("GET /readyz", m.handleReadiness)
	mux.HandleFunc("GET /api/v1/health", m.handleReadiness)
	mux.HandleFunc("GET /api/v1/impact", m.handleImpactSummary)
}

// handleLiveness ringan tanpa kueri berat agar orchestrator tahu proses hidup (#20).
func (m *Module) handleLiveness(w http.ResponseWriter, r *http.Request) {
	httpx.JSON(w, http.StatusOK, map[string]any{
		"status":    "alive",
		"uptimeSec": int(time.Since(m.startedAt).Seconds()),
	})
}

// handleReadiness mengecek kesiapan pool PostgreSQL & ringkasan jumlah entitas.
func (m *Module) handleReadiness(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()

	var usersCount, commoditiesCount, warehousesCount, demandsCount int
	err := m.pool.QueryRow(ctx, `
		SELECT
			(SELECT COUNT(*) FROM users)::int,
			(SELECT COUNT(*) FROM commodities)::int,
			(SELECT COUNT(*) FROM warehouses)::int,
			(SELECT COUNT(*) FROM buyer_demands)::int
	`).Scan(&usersCount, &commoditiesCount, &warehousesCount, &demandsCount)
	if err != nil {
		httpx.Error(w, r, http.StatusServiceUnavailable, "DB_UNREADY", "Database PostgreSQL belum siap: "+err.Error())
		return
	}

	stat := m.pool.Stat()
	httpx.JSON(w, http.StatusOK, map[string]any{
		"status":       "ready",
		"architecture": "Go Modular Monolith + PostgreSQL 17 (Podman)",
		"uptimeSec":    int(time.Since(m.startedAt).Seconds()),
		"counts": map[string]int{
			"users":       usersCount,
			"commodities": commoditiesCount,
			"warehouses":  warehousesCount,
			"demands":     demandsCount,
		},
		"pool": map[string]int32{
			"totalConns":    stat.TotalConns(),
			"acquiredConns": stat.AcquiredConns(),
			"idleConns":     stat.IdleConns(),
			"maxConns":      stat.MaxConns(),
		},
		"cacheActiveEntries": m.cache.Stats(),
	})
}

func (m *Module) handleImpactSummary(w http.ResponseWriter, r *http.Request) {
	var tambahanPendapatan, stokTerserap, susutDicegah float64
	var anggotaPoktan, lotAktif int

	err := m.pool.QueryRow(r.Context(), `
		SELECT
			COALESCE((SELECT SUM(nilai) FROM impact_events WHERE jenis = 'tambahan_pendapatan'), 0),
			COALESCE((SELECT SUM(nilai) FROM impact_events WHERE jenis = 'stok_terserap'), 0),
			COALESCE((SELECT SUM(nilai) FROM impact_events WHERE jenis = 'susut_dicegah'), 0),
			COALESCE((SELECT COUNT(DISTINCT user_id) FROM farmer_group_members), 0)::int,
			COALESCE((SELECT COUNT(*) FROM lots), 0)::int
	`).Scan(&tambahanPendapatan, &stokTerserap, &susutDicegah, &anggotaPoktan, &lotAktif)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal merangkum metrik dampak")
		return
	}

	httpx.JSON(w, http.StatusOK, map[string]any{
		"sdgFocus":             "SDG 8: Pekerjaan Layak dan Pertumbuhan Ekonomi",
		"coBenefits":           []string{"SDG 2: Tanpa Kelaparan", "SDG 12: Konsumsi dan Produksi Bertanggung Jawab"},
		"tambahanPendapatanRp": int(tambahanPendapatan),
		"stokTerserapKg":       stokTerserap,
		"susutDicegahKg":       susutDicegah,
		"petaniTergabung":      anggotaPoktan,
		"lotKolektifCount":     lotAktif,
		"methodology": map[string]string{
			"tambahanPendapatan": "Akumulasi selisih pendapatan bersih tunda-jual/transaksi terhadap patokan jual tertekan (panjar).",
			"stokTerserap":       "Total volume (kg) penawaran jual yang telah terverifikasi selesai oleh pembeli siaga.",
			"susutDicegah":       "Estimasi selisih susut simpan rumah tangga (~2,5-3%/bln) terhadap gudang standar SRG (~0,5%/bln).",
		},
	})
}
