package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

const testJWTSecret = "simpanjual-unit-test-secret-key-32-chars"

func TestCreateAndVerifyJWT(t *testing.T) {
	in := SessionUser{
		UserID:    "u-123",
		Email:     "petani@demo.id",
		Role:      "petani",
		Nama:      "Pak Slamet",
		Kabupaten: "Banyumas",
	}
	tok, err := CreateJWT(testJWTSecret, in)
	if err != nil {
		t.Fatalf("CreateJWT failed: %v", err)
	}

	out, err := VerifyJWT(testJWTSecret, tok)
	if err != nil {
		t.Fatalf("VerifyJWT failed: %v", err)
	}
	if out.UserID != in.UserID || out.Role != in.Role || out.Kabupaten != in.Kabupaten {
		t.Errorf("claims mismatch: got %+v, want %+v", out, in)
	}

	if _, err := VerifyJWT("wrong-secret-key", tok); err == nil {
		t.Errorf("expected error for wrong secret")
	}
	if _, err := VerifyJWT(testJWTSecret, "not.a.valid.jwt"); err == nil {
		t.Errorf("expected error for malformed token")
	}
}

func TestRequireAuthAndRBAC(t *testing.T) {
	adminOnly := RequireAuth(testJWTSecret, "admin")(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	reqNoTok := httptest.NewRequest(http.MethodGet, "/api/v1/admin/commodities", nil)
	recNoTok := httptest.NewRecorder()
	adminOnly(recNoTok, reqNoTok)
	if recNoTok.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 without token, got %d", recNoTok.Code)
	}

	petaniTok, _ := CreateJWT(testJWTSecret, SessionUser{
		UserID: "u-petani", Email: "petani@demo.id", Role: "petani", Nama: "Pak Slamet",
	})
	reqPetani := httptest.NewRequest(http.MethodGet, "/api/v1/admin/commodities", nil)
	reqPetani.Header.Set("Authorization", "Bearer "+petaniTok)
	recPetani := httptest.NewRecorder()
	adminOnly(recPetani, reqPetani)
	if recPetani.Code != http.StatusForbidden {
		t.Errorf("expected 403 when petani hits admin route, got %d", recPetani.Code)
	}

	adminTok, _ := CreateJWT(testJWTSecret, SessionUser{
		UserID: "u-admin", Email: "admin@demo.id", Role: "admin", Nama: "Admin",
	})
	reqAdmin := httptest.NewRequest(http.MethodGet, "/api/v1/admin/commodities", nil)
	reqAdmin.Header.Set("Authorization", "Bearer "+adminTok)
	recAdmin := httptest.NewRecorder()
	adminOnly(recAdmin, reqAdmin)
	if recAdmin.Code != http.StatusOK {
		t.Errorf("expected 200 when admin hits admin route, got %d", recAdmin.Code)
	}
}

func TestRateLimiterAndHealthBypass(t *testing.T) {
	rl := NewRateLimiter(2)
	h := rl.Middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	for i := 0; i < 2; i++ {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/impact", nil)
		req.RemoteAddr = "127.0.0.1:9999"
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("request %d expected 200, got %d", i+1, rec.Code)
		}
		if rec.Header().Get("X-RateLimit-Limit") != "2" {
			t.Errorf("expected X-RateLimit-Limit=2, got %q", rec.Header().Get("X-RateLimit-Limit"))
		}
	}

	reqLimited := httptest.NewRequest(http.MethodGet, "/api/v1/impact", nil)
	reqLimited.RemoteAddr = "127.0.0.1:9999"
	recLimited := httptest.NewRecorder()
	h.ServeHTTP(recLimited, reqLimited)
	if recLimited.Code != http.StatusTooManyRequests {
		t.Errorf("expected 429 on 3rd request, got %d", recLimited.Code)
	}
	if recLimited.Header().Get("Retry-After") == "" {
		t.Errorf("expected Retry-After header on 429 response")
	}

	reqHealth := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	reqHealth.RemoteAddr = "127.0.0.1:9999"
	recHealth := httptest.NewRecorder()
	h.ServeHTTP(recHealth, reqHealth)
	if recHealth.Code != http.StatusOK {
		t.Errorf("expected /healthz to bypass rate limiter with 200, got %d", recHealth.Code)
	}
}

func TestCORSOptionsPreflight(t *testing.T) {
	handler := CORS([]string{"http://localhost:5173"}, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodOptions, "/api/v1/simulator", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("expected 204 for OPTIONS preflight, got %d", rec.Code)
	}
	if rec.Header().Get("Access-Control-Allow-Origin") != "http://localhost:5173" {
		t.Errorf("expected Access-Control-Allow-Origin header to match origin, got %q", rec.Header().Get("Access-Control-Allow-Origin"))
	}
}
