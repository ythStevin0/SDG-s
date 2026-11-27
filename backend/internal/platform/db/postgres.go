package db

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"simpanjual/backend/internal/platform/config"
)

func NewPool(ctx context.Context, cfg config.Config) (*pgxpool.Pool, error) {
	poolCfg, err := pgxpool.ParseConfig(cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("gagal mem-parsing DATABASE_URL: %w", err)
	}

	poolCfg.MaxConns = cfg.DBMaxConns
	poolCfg.MinConns = cfg.DBMinConns
	poolCfg.MaxConnLifetime = 30 * time.Minute
	poolCfg.MaxConnIdleTime = 5 * time.Minute
	poolCfg.HealthCheckPeriod = 30 * time.Second
	poolCfg.ConnConfig.ConnectTimeout = cfg.DBConnectTimeout

	connectCtx, cancel := context.WithTimeout(ctx, cfg.DBConnectTimeout+2*time.Second)
	defer cancel()

	pool, err := pgxpool.NewWithConfig(connectCtx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("gagal membuka connection pool PostgreSQL: %w", err)
	}

	if err := pool.Ping(connectCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("gagal ping PostgreSQL: %w", err)
	}

	return pool, nil
}
