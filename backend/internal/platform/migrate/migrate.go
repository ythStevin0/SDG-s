package migrate

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

func ensureMigrationTable(ctx context.Context, pool *pgxpool.Pool) error {
	_, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version TEXT PRIMARY KEY,
			applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		);
	`)
	return err
}

func Up(ctx context.Context, pool *pgxpool.Pool, migrationsDir string) ([]string, error) {
	if err := ensureMigrationTable(ctx, pool); err != nil {
		return nil, err
	}

	entries, err := os.ReadDir(migrationsDir)
	if err != nil {
		return nil, fmt.Errorf("gagal membaca direktori migrasi %s: %w", migrationsDir, err)
	}

	var upFiles []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".up.sql") {
			upFiles = append(upFiles, e.Name())
		}
	}
	sort.Strings(upFiles)

	var applied []string
	for _, fname := range upFiles {
		version := strings.TrimSuffix(fname, ".up.sql")
		var exists bool
		if err := pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)`, version).Scan(&exists); err != nil {
			return applied, err
		}
		// Jalankan selalu idempoten bila belum tercatat di schema_migrations
		if exists {
			continue
		}

		sqlBytes, err := os.ReadFile(filepath.Join(migrationsDir, fname))
		if err != nil {
			return applied, err
		}

		tx, err := pool.Begin(ctx)
		if err != nil {
			return applied, err
		}
		if _, err := tx.Exec(ctx, string(sqlBytes)); err != nil {
			_ = tx.Rollback(ctx)
			return applied, fmt.Errorf("migrasi %s gagal: %w", fname, err)
		}
		if _, err := tx.Exec(ctx, `INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT (version) DO NOTHING`, version); err != nil {
			_ = tx.Rollback(ctx)
			return applied, err
		}
		if err := tx.Commit(ctx); err != nil {
			return applied, err
		}
		applied = append(applied, version)
	}
	return applied, nil
}

func Down(ctx context.Context, pool *pgxpool.Pool, migrationsDir string) ([]string, error) {
	if err := ensureMigrationTable(ctx, pool); err != nil {
		return nil, err
	}

	rows, err := pool.Query(ctx, `SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1`)
	if err != nil {
		return nil, err
	}
	var versions []string
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			rows.Close()
			return nil, err
		}
		versions = append(versions, v)
	}
	rows.Close()

	var reverted []string
	for _, version := range versions {
		fname := version + ".down.sql"
		sqlBytes, err := os.ReadFile(filepath.Join(migrationsDir, fname))
		if err != nil {
			return reverted, err
		}
		tx, err := pool.Begin(ctx)
		if err != nil {
			return reverted, err
		}
		if _, err := tx.Exec(ctx, string(sqlBytes)); err != nil {
			_ = tx.Rollback(ctx)
			return reverted, fmt.Errorf("rollback %s gagal: %w", fname, err)
		}
		if _, err := tx.Exec(ctx, `DELETE FROM schema_migrations WHERE version = $1`, version); err != nil {
			_ = tx.Rollback(ctx)
			return reverted, err
		}
		if err := tx.Commit(ctx); err != nil {
			return reverted, err
		}
		reverted = append(reverted, version)
	}
	return reverted, nil
}
