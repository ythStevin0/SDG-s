package seed

import (
	"context"
	"encoding/json"
	"math"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
	"simpanjual/backend/internal/modules/engine"
)

func generateSeasonalPrices(basePrice, amplitude float64, weeks int) []engine.PriceSeriesPoint {
	out := make([]engine.PriceSeriesPoint, 0, weeks)
	start := time.Date(2025, 9, 1, 0, 0, 0, 0, time.UTC)
	for w := 0; w < weeks; w++ {
		dt := start.AddDate(0, 0, w*7).Format("2006-01-02")
		phase := (2.0 * math.Pi * float64(w)) / 26.0
		seasonal := math.Sin(phase) * amplitude
		noise := float64(((w*37)%11)-5) * 25.0
		trend := float64(w * 8)
		price := int(math.Round((basePrice+seasonal+noise+trend)/50.0)) * 50
		out = append(out, engine.PriceSeriesPoint{
			Tanggal:    dt,
			HargaPerKg: price,
		})
	}
	return out
}

// Seed mengisi data demo secara IDEMPOTEN (#49): aman dijalankan berulang kali tanpa duplikasi.
func Seed(ctx context.Context, pool *pgxpool.Pool) error {
	hashBytes, err := bcrypt.GenerateFromPassword([]byte("demo12345"), 10)
	if err != nil {
		return err
	}
	demoHash := string(hashBytes)

	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// 1. Upsert 5 Akun Demo
	upsertUser := func(email, role, nama, noWa, kab string, namaOrg, tipe *string) (string, error) {
		var id string
		err := tx.QueryRow(ctx, `
			INSERT INTO users (email, password_hash, role, nama, no_wa, kabupaten, provinsi, nama_org, tipe_pembeli, is_demo)
			VALUES ($1, $2, $3, $4, $5, $6, 'Jawa Tengah', $7, $8, TRUE)
			ON CONFLICT (email) DO UPDATE
			SET password_hash = EXCLUDED.password_hash,
			    role = EXCLUDED.role,
			    nama = EXCLUDED.nama,
			    no_wa = EXCLUDED.no_wa,
			    kabupaten = EXCLUDED.kabupaten,
			    nama_org = EXCLUDED.nama_org,
			    tipe_pembeli = EXCLUDED.tipe_pembeli,
			    is_demo = TRUE
			RETURNING id::text
		`, email, demoHash, role, nama, noWa, kab, namaOrg, tipe).Scan(&id)
		return id, err
	}

	strPtr := func(s string) *string { return &s }

	petaniID, err := upsertUser("petani@demo.id", "petani", "Pak Slamet", "6281234567801", "Banyumas", nil, nil)
	if err != nil {
		return err
	}
	poktanUserID, err := upsertUser("poktan@demo.id", "petani", "Bu Rini (Ketua Poktan)", "6281234567802", "Banyumas", strPtr("Poktan Tani Jaya"), nil)
	if err != nil {
		return err
	}
	gudangUserID, err := upsertUser("gudang@demo.id", "gudang", "Pak Joko (Pengelola SRG)", "6281234567803", "Banyumas", strPtr("Gudang SRG Banyumas"), nil)
	if err != nil {
		return err
	}
	pembeliUserID, err := upsertUser("pembeli@demo.id", "pembeli", "Koperasi & SPPG Mitra Banyumas", "6281234567804", "Banyumas", strPtr("Koperasi Pangan Banyumas (Mitra SPPG)"), strPtr("sppg"))
	if err != nil {
		return err
	}
	if _, err := upsertUser("admin@demo.id", "admin", "Admin SimpanJual", "6281234567805", "Banyumas", nil, nil); err != nil {
		return err
	}

	// 2. Upsert 2 Komoditas Utama
	upsertComm := func(kode, nama string, params engine.CommodityParams) (string, error) {
		b, _ := json.Marshal(params)
		var id string
		err := tx.QueryRow(ctx, `
			INSERT INTO commodities (kode, nama, satuan, params)
			VALUES ($1, $2, 'kg', $3::jsonb)
			ON CONFLICT (kode) DO UPDATE SET nama = EXCLUDED.nama, params = EXCLUDED.params
			RETURNING id::text
		`, kode, nama, string(b)).Scan(&id)
		return id, err
	}

	jagungID, err := upsertComm("jagung", "Jagung Pipil", engine.CommodityParams{
		KadarAirMaksPct:       15,
		KotoranMaksPct:        3,
		RusakMaksPct:          5,
		SusutPerBulan:         0.005,
		SusutRumahPerBulan:    0.03,
		BiayaPengeringanPerKg: 150,
		TarifSewaMurah:        1,
		TarifSewaMahal:        8,
		FasilitasWajib:        []string{"ventilasi", "lantai_palet_kering", "kontrol_hama"},
	})
	if err != nil {
		return err
	}

	gabahID, err := upsertComm("gabah", "Gabah Kering Giling (GKG)", engine.CommodityParams{
		KadarAirMaksPct:       14,
		KotoranMaksPct:        3,
		RusakMaksPct:          5,
		SusutPerBulan:         0.005,
		SusutRumahPerBulan:    0.025,
		BiayaPengeringanPerKg: 150,
		TarifSewaMurah:        1,
		TarifSewaMahal:        8,
		FasilitasWajib:        []string{"ventilasi", "lantai_palet_kering", "kontrol_hama"},
	})
	if err != nil {
		return err
	}

	// 3. Upsert 64 Minggu Harga Historis Bermusim
	for _, pt := range generateSeasonalPrices(4950, 550, 64) {
		_, _ = tx.Exec(ctx, `
			INSERT INTO price_points (commodity_id, region, tanggal, harga_per_kg, sumber, is_demo)
			VALUES ($1, 'Jawa Tengah', $2::date, $3, 'Data Ilustrasi Bermusim (Referensi Pasar Jateng)', TRUE)
			ON CONFLICT (commodity_id, region, tanggal) DO UPDATE SET harga_per_kg = EXCLUDED.harga_per_kg
		`, jagungID, pt.Tanggal, pt.HargaPerKg)
	}
	for _, pt := range generateSeasonalPrices(6400, 650, 64) {
		_, _ = tx.Exec(ctx, `
			INSERT INTO price_points (commodity_id, region, tanggal, harga_per_kg, sumber, is_demo)
			VALUES ($1, 'Jawa Tengah', $2::date, $3, 'Data Ilustrasi Bermusim (Referensi Pasar Jateng)', TRUE)
			ON CONFLICT (commodity_id, region, tanggal) DO UPDATE SET harga_per_kg = EXCLUDED.harga_per_kg
		`, gabahID, pt.Tanggal, pt.HargaPerKg)
	}

	// 4. Kelompok Tani TANIJAYA
	var poktanID string
	err = tx.QueryRow(ctx, `
		INSERT INTO farmer_groups (nama, kabupaten, ketua_id, kode_gabung)
		VALUES ('Poktan Tani Jaya Banyumas', 'Banyumas', $1, 'TANIJAYA')
		ON CONFLICT (kode_gabung) DO UPDATE SET ketua_id = EXCLUDED.ketua_id
		RETURNING id::text
	`, poktanUserID).Scan(&poktanID)
	if err != nil {
		return err
	}
	_, _ = tx.Exec(ctx, `INSERT INTO farmer_group_members (group_id, user_id) VALUES ($1, $2), ($1, $3) ON CONFLICT DO NOTHING`,
		poktanID, poktanUserID, petaniID)

	// Hanya isi stok/gudang/lot/kebutuhan awal bila tabel warehouses demo masih kosong agar idempoten tanpa menduplikasi data transaksi
	var whCount int
	_ = tx.QueryRow(ctx, `SELECT COUNT(*)::int FROM warehouses WHERE is_demo = TRUE`).Scan(&whCount)
	if whCount == 0 {
		fullCheck, _ := json.Marshal(engine.WarehouseChecklist{
			AtapTidakBocor: true, Ventilasi: true, LantaiPaletKering: true,
			KontrolHama: true, AlatUkurKa: true, KeamananSuhu: true,
		})
		coopCheck, _ := json.Marshal(engine.WarehouseChecklist{
			AtapTidakBocor: true, Ventilasi: true, LantaiPaletKering: true,
			KontrolHama: true, AlatUkurKa: false, KeamananSuhu: false,
		})
		millCheck, _ := json.Marshal(engine.WarehouseChecklist{
			AtapTidakBocor: true, Ventilasi: true, LantaiPaletKering: true,
			KontrolHama: false, AlatUkurKa: true, KeamananSuhu: false,
		})

		var whSrgID string
		err = tx.QueryRow(ctx, `
			INSERT INTO warehouses (owner_id, nama, kabupaten, lat, lng, kapasitas_kg, tersedia_kg, tarif_per_kg_hari, min_volume_kg, min_hari, is_srg, komoditas_diterima, checklist, kontak_wa, is_demo)
			VALUES ($1, 'Gudang SRG Banyumas (Data Ilustrasi)', 'Banyumas', -7.4314, 109.2478, 100000, 82000, 2.5, 5000, 30, TRUE, ARRAY['jagung','gabah'], $2::jsonb, '6281234567803', TRUE)
			RETURNING id::text
		`, gudangUserID, string(fullCheck)).Scan(&whSrgID)
		if err != nil {
			return err
		}

		_, _ = tx.Exec(ctx, `
			INSERT INTO warehouses (owner_id, nama, kabupaten, lat, lng, kapasitas_kg, tersedia_kg, tarif_per_kg_hari, min_volume_kg, min_hari, is_srg, komoditas_diterima, checklist, kontak_wa, is_demo)
			VALUES
			($1, 'Gudang Koperasi Tani Makmur Cilacap (Data Ilustrasi)', 'Cilacap', -7.7188, 109.0154, 60000, 45000, 3.0, 2000, 14, FALSE, ARRAY['jagung','gabah'], $2::jsonb, '6281234567803', TRUE),
			($1, 'Penggilingan & Lumbung Purbalingga (Data Ilustrasi)', 'Purbalingga', -7.3881, 109.3639, 40000, 28000, 3.5, 1000, 14, FALSE, ARRAY['gabah'], $3::jsonb, '6281234567803', TRUE),
			($1, 'Gudang Agribisnis Brebes (Data Ilustrasi)', 'Brebes', -6.8706, 109.0442, 80000, 60000, 4.0, 3000, 30, TRUE, ARRAY['jagung','gabah'], $2::jsonb, '6281234567803', TRUE)
		`, gudangUserID, string(coopCheck), string(millCheck))

		// Stok awal Pak Slamet & Bu Rini
		_, _ = tx.Exec(ctx, `
			INSERT INTO stocks (owner_id, commodity_id, qty_kg, reserved_kg, sold_kg, kadar_air, kotoran_pct, rusak_pct, tgl_panen, kabupaten, lat, lng, status, catatan)
			VALUES
			($1, $2, 5000, 0, 0, 14.5, 2.0, 3.0, '2026-11-20', 'Banyumas', -7.4502, 109.1623, 'tersedia', 'Panen blok sawah Sokaraja, jagung pipil kuning'),
			($1, $3, 4000, 0, 0, 22.0, 2.5, 3.5, '2026-11-22', 'Banyumas', -7.4502, 109.1623, 'tersedia', 'Gabah Kering Panen (GKP) baru panen, perlu dijemur sebelum masuk SRG')
		`, petaniID, jagungID, gabahID)

		var stokRiniID string
		err = tx.QueryRow(ctx, `
			INSERT INTO stocks (owner_id, commodity_id, qty_kg, reserved_kg, sold_kg, kadar_air, kotoran_pct, rusak_pct, tgl_panen, kabupaten, lat, lng, status, catatan)
			VALUES ($1, $2, 6000, 6000, 0, 14.0, 2.0, 2.5, '2026-11-18', 'Banyumas', -7.4311, 109.2478, 'teralokasi_penuh', 'Stok himpunan anggota Poktan Tani Jaya untuk Lot Kolektif')
			RETURNING id::text
		`, poktanUserID, jagungID).Scan(&stokRiniID)
		if err == nil {
			var lotID string
			if tx.QueryRow(ctx, `
				INSERT INTO lots (group_id, commodity_id, target_kg, terkumpul_kg, status, warehouse_id)
				VALUES ($1, $2, 10000, 6000, 'mengumpulkan', $3)
				RETURNING id::text
			`, poktanID, jagungID, whSrgID).Scan(&lotID) == nil {
				_, _ = tx.Exec(ctx, `
					INSERT INTO lot_contributions (lot_id, stock_id, user_id, qty_kg)
					VALUES ($1, $2, $3, 6000)
				`, lotID, stokRiniID, poktanUserID)
			}
		}

		// Kebutuhan Pembeli (Janji Beli)
		_, _ = tx.Exec(ctx, `
			INSERT INTO buyer_demands (buyer_id, commodity_id, qty_kg, terpenuhi_kg, harga_acuan, dibutuhkan_pada, kabupaten, lat, lng, mutu_min, status, is_demo)
			VALUES
			($1, $2, 15000, 3000, 5850, '2027-01-15', 'Banyumas', -7.4243, 109.2302, '{"kadar_air_maks_pct":15,"catatan":"Jagung pipil kering bersih bebas jamur"}'::jsonb, 'aktif', TRUE),
			($1, $3, 20000, 5000, 7200, '2027-01-20', 'Banyumas', -7.4243, 109.2302, '{"kadar_air_maks_pct":14,"catatan":"Gabah Kering Giling (GKG) standar RMU/SPPG"}'::jsonb, 'aktif', TRUE),
			($1, $2, 8000, 0, 5650, '2026-12-28', 'Cilacap', -7.7188, 109.0154, '{"kadar_air_maks_pct":15,"catatan":"Pasokan pakan ternak koperasi"}'::jsonb, 'aktif', TRUE),
			($1, $3, 12000, 2000, 7050, '2027-01-10', 'Purbalingga', -7.3881, 109.3639, '{"kadar_air_maks_pct":14,"catatan":"Kebutuhan beras dapur SPPG regional"}'::jsonb, 'aktif', TRUE)
		`, pembeliUserID, jagungID, gabahID)

		// Metrik dampak awal ilustratif
		_, _ = tx.Exec(ctx, `
			INSERT INTO impact_events (jenis, user_id, nilai, meta)
			VALUES
			('tambahan_pendapatan', $1, 4250000, '{"is_demo":true}'::jsonb),
			('stok_terserap', $1, 10000, '{"is_demo":true}'::jsonb),
			('susut_dicegah', $1, 240, '{"is_demo":true}'::jsonb)
		`, petaniID)
	}

	return tx.Commit(ctx)
}
