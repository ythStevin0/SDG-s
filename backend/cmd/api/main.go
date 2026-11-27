package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"simpanjual/backend/internal/modules/ai"
	"simpanjual/backend/internal/modules/auth"
	"simpanjual/backend/internal/modules/catalog"
	"simpanjual/backend/internal/modules/demand"
	"simpanjual/backend/internal/modules/impact"
	"simpanjual/backend/internal/modules/lot"
	"simpanjual/backend/internal/modules/stock"
	"simpanjual/backend/internal/modules/warehouse"
	"simpanjual/backend/internal/platform/cache"
	"simpanjual/backend/internal/platform/config"
	"simpanjual/backend/internal/platform/db"
	"simpanjual/backend/internal/platform/middleware"
	"simpanjual/backend/internal/platform/migrate"
	"simpanjual/backend/internal/seed"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	cfg := config.Load()

	ctx := context.Background()
	pool, err := db.NewPool(ctx, cfg)
	if err != nil {
		logger.Error("gagal menginisialisasi koneksi PostgreSQL", slog.String("error", err.Error()))
		os.Exit(1)
	}
	defer pool.Close()

	// Jalankan migrasi & seed idempoten otomatis agar environment siap pakai
	migDir := "migrations"
	if _, err := os.Stat(migDir); err != nil {
		migDir = filepath.Join("backend", "migrations")
	}
	if _, err := migrate.Up(ctx, pool, migDir); err != nil {
		logger.Warn("peringatan migrasi otomatis", slog.String("error", err.Error()))
	}
	if err := seed.Seed(ctx, pool); err != nil {
		logger.Warn("peringatan seeder otomatis", slog.String("error", err.Error()))
	}

	appCache := cache.NewTTLCache()
	mux := http.NewServeMux()

	// Registrasi seluruh modul dalam arsitektur Modular Monolith
	authMod := auth.NewModule(pool, cfg)
	catalogMod := catalog.NewModule(pool, appCache, cfg)
	stockMod := stock.NewModule(pool, catalogMod, cfg)
	lotMod := lot.NewModule(pool, cfg)
	warehouseMod := warehouse.NewModule(pool, catalogMod, cfg)
	demandMod := demand.NewModule(pool, cfg)
	impactMod := impact.NewModule(pool, appCache)
	aiMod := ai.NewModule(pool, appCache, cfg)

	authMod.RegisterRoutes(mux)
	catalogMod.RegisterRoutes(mux)
	stockMod.RegisterRoutes(mux)
	lotMod.RegisterRoutes(mux)
	warehouseMod.RegisterRoutes(mux)
	demandMod.RegisterRoutes(mux)
	impactMod.RegisterRoutes(mux)
	aiMod.RegisterRoutes(mux)

	// Rantai Middleware: Correlation+JSONLog -> CORS -> OptionalAuth -> RateLimiter -> RequestTimeout -> Router
	limiter := middleware.NewRateLimiter(cfg.RateLimitPerMinute)
	var handler http.Handler = mux
	handler = middleware.Timeout(cfg.RequestTimeout, handler)
	handler = limiter.Middleware(handler)
	handler = middleware.OptionalAuth(cfg.JWTSecret, handler)
	handler = middleware.CORS(cfg.AllowedOrigins, handler)
	handler = middleware.CorrelationAndLog(logger, handler)

	// HTTP Server dengan 3-layer timeout (#13)
	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      20 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		logger.Info("SimpanJual Go Modular Monolith API aktif",
			slog.String("port", cfg.Port),
			slog.Int("rate_limit_per_min", cfg.RateLimitPerMinute),
		)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server berhenti dengan error", slog.String("error", err.Error()))
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
	logger.Info("server dimatikan dengan aman (graceful shutdown)")
}
