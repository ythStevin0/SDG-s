package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"simpanjual/backend/internal/platform/config"
	"simpanjual/backend/internal/platform/db"
	"simpanjual/backend/internal/platform/migrate"
	"simpanjual/backend/internal/seed"
)

func main() {
	cfg := config.Load()
	ctx := context.Background()

	pool, err := db.NewPool(ctx, cfg)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error koneksi database: %v\n", err)
		os.Exit(1)
	}
	defer pool.Close()

	migDir := "migrations"
	if _, err := os.Stat(migDir); err != nil {
		migDir = filepath.Join("backend", "migrations")
	}

	cmd := "setup"
	if len(os.Args) > 1 {
		cmd = os.Args[1]
	}

	switch cmd {
	case "up":
		applied, err := migrate.Up(ctx, pool, migDir)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Migrasi up gagal: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Migrasi up selesai (%d baru diterapkan: %v)\n", len(applied), applied)
	case "down":
		rev, err := migrate.Down(ctx, pool, migDir)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Migrasi down gagal: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Migrasi down selesai (%v)\n", rev)
	case "seed":
		if err := seed.Seed(ctx, pool); err != nil {
			fmt.Fprintf(os.Stderr, "Seed database gagal: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Seed idempoten database SimpanJual berhasil.")
	case "reset":
		_, _ = migrate.Down(ctx, pool, migDir)
		// Pastikan bersih bila sebelumnya tabel dibuat tanpa schema_migrations
		if b, err := os.ReadFile(filepath.Join(migDir, "001_init.down.sql")); err == nil {
			_, _ = pool.Exec(ctx, string(b))
		}
		_, _ = pool.Exec(ctx, `DELETE FROM schema_migrations`)
		if _, err := migrate.Up(ctx, pool, migDir); err != nil {
			fmt.Fprintf(os.Stderr, "Migrasi ulang gagal: %v\n", err)
			os.Exit(1)
		}
		if err := seed.Seed(ctx, pool); err != nil {
			fmt.Fprintf(os.Stderr, "Seed ulang gagal: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Reset + migrasi + seed idempoten selesai.")
	default: // setup
		if _, err := migrate.Up(ctx, pool, migDir); err != nil {
			fmt.Fprintf(os.Stderr, "Migrasi gagal: %v\n", err)
			os.Exit(1)
		}
		if err := seed.Seed(ctx, pool); err != nil {
			fmt.Fprintf(os.Stderr, "Seed gagal: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("Setup database (migrasi + seed idempoten) selesai.")
	}
}
