package auth

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
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
	mux.HandleFunc("POST /api/v1/auth/register", m.handleRegister)
	mux.HandleFunc("POST /api/v1/auth/login", m.handleLogin)
	mux.HandleFunc("POST /api/v1/auth/demo", m.handleDemoLogin)
	mux.HandleFunc("POST /api/v1/auth/logout", m.handleLogout)
	mux.HandleFunc("GET /api/v1/auth/me", requireAuth(m.handleMe))
	mux.HandleFunc("GET /api/v1/auth/demo-accounts", m.handleListDemoAccounts)
}

type UserProfile struct {
	ID          string  `json:"id"`
	Email       string  `json:"email"`
	Role        string  `json:"role"`
	Nama        string  `json:"nama"`
	NoWa        *string `json:"noWa,omitempty"`
	Kabupaten   string  `json:"kabupaten"`
	Provinsi    string  `json:"provinsi"`
	NamaOrg     *string `json:"namaOrg,omitempty"`
	TipePembeli *string `json:"tipePembeli,omitempty"`
	IsDemo      bool    `json:"isDemo"`
}

var demoPresetMap = map[string]string{
	"petani":  "petani@demo.id",
	"poktan":  "poktan@demo.id",
	"gudang":  "gudang@demo.id",
	"pembeli": "pembeli@demo.id",
	"admin":   "admin@demo.id",
}

func (m *Module) issueSession(w http.ResponseWriter, u UserProfile) {
	sess := middleware.SessionUser{
		UserID:    u.ID,
		Email:     u.Email,
		Role:      u.Role,
		Nama:      u.Nama,
		Kabupaten: u.Kabupaten,
	}
	tok, err := middleware.CreateJWT(m.cfg.JWTSecret, sess)
	if err != nil {
		httpx.Error(w, nil, http.StatusInternalServerError, "TOKEN_ERROR", "Gagal membuat sesi autentikasi")
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     middleware.SessionCookie,
		Value:    tok,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   7 * 24 * 3600,
	})

	httpx.JSON(w, http.StatusOK, map[string]any{
		"ok":    true,
		"token": tok,
		"user":  u,
	})
}

func (m *Module) handleRegister(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email       string  `json:"email"`
		Password    string  `json:"password"`
		Role        string  `json:"role"`
		Nama        string  `json:"nama"`
		NoWa        *string `json:"noWa"`
		Kabupaten   string  `json:"kabupaten"`
		NamaOrg     *string `json:"namaOrg"`
		TipePembeli *string `json:"tipePembeli"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}

	email := strings.ToLower(strings.TrimSpace(body.Email))
	nama := strings.TrimSpace(body.Nama)
	kabupaten := strings.TrimSpace(body.Kabupaten)
	if kabupaten == "" {
		kabupaten = "Banyumas"
	}
	role := strings.TrimSpace(body.Role)
	if role != "petani" && role != "gudang" && role != "pembeli" {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_ROLE", "Peran registrasi harus petani, gudang, atau pembeli")
		return
	}
	if !strings.Contains(email, "@") || len(body.Password) < 6 || len(nama) < 2 {
		httpx.Error(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "Email valid, nama, dan kata sandi minimal 6 karakter wajib diisi")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(body.Password), 10)
	if err != nil {
		httpx.Error(w, r, http.StatusInternalServerError, "HASH_ERROR", "Gagal mengenkripsi kata sandi")
		return
	}

	var created UserProfile
	err = m.pool.QueryRow(r.Context(), `
		INSERT INTO users (email, password_hash, role, nama, no_wa, kabupaten, provinsi, nama_org, tipe_pembeli, is_demo)
		VALUES ($1, $2, $3, $4, $5, $6, 'Jawa Tengah', $7, $8, FALSE)
		RETURNING id::text, email, role, nama, no_wa, kabupaten, provinsi, nama_org, tipe_pembeli, is_demo
	`, email, string(hash), role, nama, body.NoWa, kabupaten, body.NamaOrg, body.TipePembeli).Scan(
		&created.ID, &created.Email, &created.Role, &created.Nama, &created.NoWa,
		&created.Kabupaten, &created.Provinsi, &created.NamaOrg, &created.TipePembeli, &created.IsDemo,
	)
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") {
			httpx.Error(w, r, http.StatusConflict, "EMAIL_EXISTS", "Email sudah terdaftar. Silakan masuk.")
			return
		}
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal mendaftarkan pengguna")
		return
	}

	m.issueSession(w, created)
}

func (m *Module) handleLogin(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}

	email := strings.ToLower(strings.TrimSpace(body.Email))
	var u UserProfile
	var passwordHash string
	err := m.pool.QueryRow(r.Context(), `
		SELECT id::text, email, password_hash, role, nama, no_wa, kabupaten, provinsi, nama_org, tipe_pembeli, is_demo
		FROM users
		WHERE email = $1
	`, email).Scan(
		&u.ID, &u.Email, &passwordHash, &u.Role, &u.Nama, &u.NoWa,
		&u.Kabupaten, &u.Provinsi, &u.NamaOrg, &u.TipePembeli, &u.IsDemo,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			httpx.Error(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Email atau kata sandi salah")
			return
		}
		httpx.Error(w, r, http.StatusInternalServerError, "DB_ERROR", "Gagal memeriksa kredensial")
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(body.Password)); err != nil {
		httpx.Error(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Email atau kata sandi salah")
		return
	}

	m.issueSession(w, u)
}

func (m *Module) handleDemoLogin(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Preset string `json:"preset"` // petani | poktan | gudang | pembeli | admin | email
		Email  string `json:"email"`
	}
	if err := httpx.DecodeJSON(w, r, m.cfg.MaxBodyBytes, &body); err != nil {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_JSON", err.Error())
		return
	}

	targetEmail := strings.ToLower(strings.TrimSpace(body.Email))
	if mapped, ok := demoPresetMap[strings.ToLower(strings.TrimSpace(body.Preset))]; ok {
		targetEmail = mapped
	} else if strings.Contains(body.Preset, "@") {
		targetEmail = strings.ToLower(strings.TrimSpace(body.Preset))
	}
	if targetEmail == "" {
		httpx.Error(w, r, http.StatusBadRequest, "INVALID_PRESET", "Pilih akun demo: petani, poktan, gudang, pembeli, atau admin")
		return
	}

	var u UserProfile
	err := m.pool.QueryRow(r.Context(), `
		SELECT id::text, email, role, nama, no_wa, kabupaten, provinsi, nama_org, tipe_pembeli, is_demo
		FROM users
		WHERE email = $1 AND is_demo = TRUE
	`, targetEmail).Scan(
		&u.ID, &u.Email, &u.Role, &u.Nama, &u.NoWa,
		&u.Kabupaten, &u.Provinsi, &u.NamaOrg, &u.TipePembeli, &u.IsDemo,
	)
	if err != nil {
		httpx.Error(w, r, http.StatusNotFound, "DEMO_USER_NOT_FOUND", "Akun demo belum tersedia. Pastikan seeder database telah dijalankan.")
		return
	}

	m.issueSession(w, u)
}

func (m *Module) handleLogout(w http.ResponseWriter, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     middleware.SessionCookie,
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		Expires:  time.Unix(0, 0),
		MaxAge:   -1,
	})
	httpx.JSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (m *Module) handleMe(w http.ResponseWriter, r *http.Request) {
	sess, _ := middleware.UserFromContext(r.Context())
	var u UserProfile
	err := m.pool.QueryRow(r.Context(), `
		SELECT id::text, email, role, nama, no_wa, kabupaten, provinsi, nama_org, tipe_pembeli, is_demo
		FROM users
		WHERE id = $1
	`, sess.UserID).Scan(
		&u.ID, &u.Email, &u.Role, &u.Nama, &u.NoWa,
		&u.Kabupaten, &u.Provinsi, &u.NamaOrg, &u.TipePembeli, &u.IsDemo,
	)
	if err != nil {
		httpx.Error(w, r, http.StatusNotFound, "USER_NOT_FOUND", "Pengguna tidak ditemukan")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"user": u})
}

func (m *Module) handleListDemoAccounts(w http.ResponseWriter, r *http.Request) {
	httpx.JSON(w, http.StatusOK, map[string]any{
		"accounts": []map[string]string{
			{"preset": "petani", "email": "petani@demo.id", "role": "petani", "nama": "Pak Slamet", "desc": "Petani jagung 5 ton & gabah GKP basah 4 ton"},
			{"preset": "poktan", "email": "poktan@demo.id", "role": "petani", "nama": "Bu Rini (Ketua Poktan)", "desc": "Ketua Poktan Tani Jaya · Kode gabung TANIJAYA"},
			{"preset": "gudang", "email": "gudang@demo.id", "role": "gudang", "nama": "Pak Joko (Pengelola SRG)", "desc": "Pengelola 4 gudang SRG & koperasi daerah"},
			{"preset": "pembeli", "email": "pembeli@demo.id", "role": "pembeli", "nama": "Koperasi & SPPG Mitra", "desc": "Pembeli siaga Janji Beli jagung & GKG"},
			{"preset": "admin", "email": "admin@demo.id", "role": "admin", "nama": "Admin SimpanJual", "desc": "Konfigurasi parameter JSONB komoditas"},
		},
	})
}
