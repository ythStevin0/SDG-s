package middleware

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"math"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"simpanjual/backend/internal/platform/httpx"
)

type ctxKey string

const (
	userCtxKey    ctxKey = "session_user"
	traceIDCtxKey ctxKey = "trace_id"
	SessionCookie        = "simpanjual_session"
)

type SessionUser struct {
	UserID    string `json:"userId"`
	Email     string `json:"email"`
	Role      string `json:"role"`
	Nama      string `json:"nama"`
	Kabupaten string `json:"kabupaten"`
}

func UserFromContext(ctx context.Context) (SessionUser, bool) {
	u, ok := ctx.Value(userCtxKey).(SessionUser)
	return u, ok
}

func TraceIDFromContext(ctx context.Context) string {
	id, ok := ctx.Value(traceIDCtxKey).(string)
	if !ok {
		return ""
	}
	return id
}

// CreateJWT membuat token JWT HS256 stateless berlaku 7 hari.
func CreateJWT(secret string, user SessionUser) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"userId":    user.UserID,
		"email":     user.Email,
		"role":      user.Role,
		"nama":      user.Nama,
		"kabupaten": user.Kabupaten,
		"iat":       now.Unix(),
		"exp":       now.Add(7 * 24 * time.Hour).Unix(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return tok.SignedString([]byte(secret))
}

// VerifyJWT memvalidasi signature HS256 dan memeriksa tipe klaim secara aman (tanpa unchecked type assertion).
func VerifyJWT(secret, tokenStr string) (SessionUser, error) {
	tok, err := jwt.Parse(tokenStr, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("algoritma JWT tidak didukung")
		}
		return []byte(secret), nil
	})
	if err != nil || !tok.Valid {
		return SessionUser{}, errors.New("token tidak valid atau kedaluwarsa")
	}
	claims, ok := tok.Claims.(jwt.MapClaims)
	if !ok {
		return SessionUser{}, errors.New("klaim JWT tidak valid")
	}

	userID, ok1 := claims["userId"].(string)
	email, ok2 := claims["email"].(string)
	role, ok3 := claims["role"].(string)
	nama, ok4 := claims["nama"].(string)
	if !ok1 || !ok2 || !ok3 || !ok4 || userID == "" {
		return SessionUser{}, errors.New("klaim identitas tidak lengkap")
	}
	kab, ok5 := claims["kabupaten"].(string)
	if !ok5 || kab == "" {
		kab = "Banyumas"
	}

	return SessionUser{
		UserID:    userID,
		Email:     email,
		Role:      role,
		Nama:      nama,
		Kabupaten: kab,
	}, nil
}

func extractToken(r *http.Request) string {
	authHeader := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(strings.ToLower(authHeader), "bearer ") {
		return strings.TrimSpace(authHeader[7:])
	}
	if c, err := r.Cookie(SessionCookie); err == nil && c.Value != "" {
		return c.Value
	}
	return ""
}

// OptionalAuth menyisipkan SessionUser ke context jika token valid, tanpa menolak akses publik.
func OptionalAuth(secret string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if tok := extractToken(r); tok != "" {
			if u, err := VerifyJWT(secret, tok); err == nil {
				ctx := context.WithValue(r.Context(), userCtxKey, u)
				r = r.WithContext(ctx)
			}
		}
		next.ServeHTTP(w, r)
	})
}

// RequireAuth mewajibkan autentikasi JWT dan opsional membatasi peran (RBAC server-side).
func RequireAuth(secret string, allowedRoles ...string) func(http.HandlerFunc) http.HandlerFunc {
	roleSet := make(map[string]struct{}, len(allowedRoles))
	for _, rl := range allowedRoles {
		roleSet[rl] = struct{}{}
	}

	return func(next http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			u, ok := UserFromContext(r.Context())
			if !ok {
				tok := extractToken(r)
				if tok == "" {
					httpx.Error(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Sesi tidak ditemukan. Silakan masuk terlebih dahulu.")
					return
				}
				parsed, err := VerifyJWT(secret, tok)
				if err != nil {
					httpx.Error(w, r, http.StatusUnauthorized, "INVALID_TOKEN", "Sesi tidak valid atau telah berakhir.")
					return
				}
				u = parsed
				r = r.WithContext(context.WithValue(r.Context(), userCtxKey, u))
			}

			if len(roleSet) > 0 {
				if _, allowed := roleSet[u.Role]; !allowed {
					httpx.Error(w, r, http.StatusForbidden, "FORBIDDEN", "Peran akun Anda tidak memiliki izin untuk aksi ini.")
					return
				}
			}
			next(w, r)
		}
	}
}

type statusRecorder struct {
	http.ResponseWriter
	status int
	buf    *bytes.Buffer
}

func (sr *statusRecorder) WriteHeader(code int) {
	sr.status = code
	sr.ResponseWriter.WriteHeader(code)
}

func (sr *statusRecorder) Write(b []byte) (int, error) {
	if sr.buf != nil {
		sr.buf.Write(b)
	}
	return sr.ResponseWriter.Write(b)
}

// CorrelationAndLog menambahkan X-Request-ID dan mencatat structured JSON log tanpa membocorkan token/password.
func CorrelationAndLog(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		traceID := strings.TrimSpace(r.Header.Get("X-Request-ID"))
		if traceID == "" {
			traceID = uuid.NewString()
		}
		w.Header().Set("X-Request-ID", traceID)
		ctx := context.WithValue(r.Context(), traceIDCtxKey, traceID)

		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r.WithContext(ctx))

		logger.Info("http_request",
			slog.String("trace_id", traceID),
			slog.String("method", r.Method),
			slog.String("path", r.URL.Path),
			slog.Int("status", rec.status),
			slog.Int64("latency_ms", time.Since(start).Milliseconds()),
			slog.String("remote_ip", clientIP(r)),
		)
	})
}

// Timeout membatasi durasi eksekusi request agar tidak memicu cascading failure.
func Timeout(d time.Duration, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), d)
		defer cancel()
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// CORS menangani lintas-origin untuk aplikasi React.js Web & Flutter Web.
func CORS(allowedOrigins []string, next http.Handler) http.Handler {
	allowAll := false
	originMap := make(map[string]struct{}, len(allowedOrigins))
	for _, o := range allowedOrigins {
		if o == "*" {
			allowAll = true
		}
		originMap[o] = struct{}{}
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" {
			if _, ok := originMap[origin]; ok || allowAll {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Vary", "Origin")
				w.Header().Set("Access-Control-Allow-Credentials", "true")
			}
		} else if allowAll {
			w.Header().Set("Access-Control-Allow-Origin", "*")
		}

		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Request-ID, Idempotency-Key")
		w.Header().Set("Access-Control-Expose-Headers", "X-Request-ID, X-RateLimit-Limit, X-RateLimit-Remaining, Retry-After")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

type bucket struct {
	tokens   float64
	lastSync time.Time
}

// RateLimiter mengimplementasikan algoritma Token Bucket per IP/User secara thread-safe (sync.Mutex).
type RateLimiter struct {
	mu           sync.Mutex
	buckets      map[string]*bucket
	limitPerMin  int
	refillPerSec float64
}

func NewRateLimiter(limitPerMin int) *RateLimiter {
	if limitPerMin <= 0 {
		limitPerMin = 120
	}
	return &RateLimiter{
		buckets:      make(map[string]*bucket),
		limitPerMin:  limitPerMin,
		refillPerSec: float64(limitPerMin) / 60.0,
	}
}

func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/healthz" || r.URL.Path == "/readyz" {
			next.ServeHTTP(w, r)
			return
		}

		key := clientIP(r)
		if u, ok := UserFromContext(r.Context()); ok && u.UserID != "" {
			key = "usr:" + u.UserID
		}

		now := time.Now()
		rl.mu.Lock()
		b, exists := rl.buckets[key]
		if !exists {
			b = &bucket{tokens: float64(rl.limitPerMin), lastSync: now}
			rl.buckets[key] = b
		} else {
			elapsed := now.Sub(b.lastSync).Seconds()
			b.tokens = math.Min(float64(rl.limitPerMin), b.tokens+elapsed*rl.refillPerSec)
			b.lastSync = now
		}

		w.Header().Set("X-RateLimit-Limit", strconv.Itoa(rl.limitPerMin))
		if b.tokens < 1.0 {
			retrySec := int(math.Ceil((1.0 - b.tokens) / rl.refillPerSec))
			if retrySec < 1 {
				retrySec = 1
			}
			rl.mu.Unlock()
			w.Header().Set("X-RateLimit-Remaining", "0")
			w.Header().Set("Retry-After", strconv.Itoa(retrySec))
			httpx.Error(w, r, http.StatusTooManyRequests, "RATE_LIMITED", "Terlalu banyak permintaan. Mohon coba beberapa saat lagi.")
			return
		}

		b.tokens -= 1.0
		remaining := int(math.Floor(b.tokens))
		rl.mu.Unlock()

		w.Header().Set("X-RateLimit-Remaining", strconv.Itoa(remaining))
		next.ServeHTTP(w, r)
	})
}

// Idempotent membungkus endpoint POST mutasi agar aman dari retry jaringan (double-booking).
func Idempotent(pool *pgxpool.Pool, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		idemKey := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
		u, hasUser := UserFromContext(r.Context())
		if idemKey == "" || !hasUser || r.Method != http.MethodPost {
			next(w, r)
			return
		}
		if len(idemKey) > 128 {
			httpx.Error(w, r, http.StatusBadRequest, "INVALID_IDEMPOTENCY_KEY", "Idempotency-Key maksimal 128 karakter")
			return
		}

		var savedStatus int
		var savedBody []byte
		err := pool.QueryRow(r.Context(), `
			SELECT status_code, response_body
			FROM idempotency_keys
			WHERE key = $1 AND user_id = $2 AND expires_at > NOW()
		`, idemKey, u.UserID).Scan(&savedStatus, &savedBody)
		if err == nil {
			w.Header().Set("Content-Type", "application/json; charset=utf-8")
			w.Header().Set("X-Idempotent-Replay", "true")
			w.WriteHeader(savedStatus)
			_, _ = w.Write(savedBody)
			return
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			// Jika tabel belum ada/error minor, lanjutkan eksekusi normal
		}

		buf := &bytes.Buffer{}
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK, buf: buf}
		next(rec, r)

		if rec.status >= 200 && rec.status < 300 && json.Valid(buf.Bytes()) {
			_, _ = pool.Exec(r.Context(), `
				INSERT INTO idempotency_keys (key, user_id, method, path, status_code, response_body, expires_at)
				VALUES ($1, $2, $3, $4, $5, $6::jsonb, NOW() + INTERVAL '24 hours')
				ON CONFLICT (key, user_id) DO NOTHING
			`, idemKey, u.UserID, r.Method, r.URL.Path, rec.status, buf.String())
		}
	}
}

func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil && host != "" {
		return host
	}
	return r.RemoteAddr
}
