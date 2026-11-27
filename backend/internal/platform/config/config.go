package config

import (
	"bufio"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port               string
	DatabaseURL        string
	JWTSecret          string
	AllowedOrigins     []string
	RateLimitPerMinute int
	MaxBodyBytes       int64
	RequestTimeout     time.Duration
	DBConnectTimeout   time.Duration
	DBMaxConns         int32
	DBMinConns         int32
	AIEnabled          bool
	GeminiAPIKey       string
	LLMModel           string
	AIRateLimitPerHour int
	AITimeout          time.Duration
}

// LoadDotEnv membaca file .env secara opsional tanpa menimpa environment variable yang sudah diset OS/kontainer.
func LoadDotEnv(paths ...string) {
	for _, p := range paths {
		clean := filepath.Clean(p)
		f, err := os.Open(clean)
		if err != nil {
			continue
		}
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			idx := strings.IndexByte(line, '=')
			if idx <= 0 {
				continue
			}
			key := strings.TrimSpace(line[:idx])
			val := strings.TrimSpace(line[idx+1:])
			val = strings.Trim(val, `"'`)
			if _, exists := os.LookupEnv(key); !exists {
				_ = os.Setenv(key, val)
			}
		}
		_ = f.Close()
	}
}

func Load() Config {
	LoadDotEnv(".env", "../.env")

	originsRaw := envOr("CORS_ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:5173,http://127.0.0.1:5173,http://localhost:8081,*")
	var origins []string
	for _, o := range strings.Split(originsRaw, ",") {
		if trimmed := strings.TrimSpace(o); trimmed != "" {
			origins = append(origins, trimmed)
		}
	}

	return Config{
		Port:               envOr("PORT", "8080"),
		DatabaseURL:        envOr("DATABASE_URL", "postgresql://simpanjual:simpanjual_dev@127.0.0.1:5435/simpanjual"),
		JWTSecret:          envOr("JWT_SECRET", "simpanjual-dev-secret-change-in-production-min-32-chars"),
		AllowedOrigins:     origins,
		RateLimitPerMinute: envIntOr("RATE_LIMIT_PER_MINUTE", 180),
		MaxBodyBytes:       int64(envIntOr("MAX_BODY_BYTES", 1048576)), // 1 MB payload limit
		RequestTimeout:     time.Duration(envIntOr("REQUEST_TIMEOUT_MS", 15000)) * time.Millisecond,
		DBConnectTimeout:   time.Duration(envIntOr("DB_CONNECT_TIMEOUT_MS", 5000)) * time.Millisecond,
		DBMaxConns:         int32(envIntOr("DB_MAX_CONNS", 20)),
		DBMinConns:         int32(envIntOr("DB_MIN_CONNS", 2)),
		AIEnabled:          strings.EqualFold(envOr("AI_ENABLED", "false"), "true"),
		GeminiAPIKey:       envOr("GOOGLE_GENERATIVE_AI_API_KEY", ""),
		LLMModel:           envOr("LLM_MODEL", "gemini-2.5-flash"),
		AIRateLimitPerHour: envIntOr("AI_RATE_LIMIT_PER_HOUR", 10),
		AITimeout:          time.Duration(envIntOr("AI_TIMEOUT_MS", 8000)) * time.Millisecond,
	}
}

func envOr(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func envIntOr(key string, fallback int) int {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil || n <= 0 {
		return fallback
	}
	return n
}
