package httpx

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
)

type ErrorEnvelope struct {
	Error   string `json:"error"`
	Code    string `json:"code,omitempty"`
	TraceID string `json:"traceId,omitempty"`
}

func JSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(data)
}

func Error(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	traceID := w.Header().Get("X-Request-ID")
	if traceID == "" && r != nil {
		traceID = r.Header.Get("X-Request-ID")
	}
	JSON(w, status, ErrorEnvelope{
		Error:   message,
		Code:    code,
		TraceID: traceID,
	})
}

// DecodeJSON membatasi ukuran payload (mencegah DoS payload besar) dan memvalidasi JSON secara ketat.
func DecodeJSON(w http.ResponseWriter, r *http.Request, maxBytes int64, dst any) error {
	if maxBytes <= 0 {
		maxBytes = 1 << 20 // 1 MB
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxBytes)
	defer r.Body.Close()

	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(dst); err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			return fmt.Errorf("ukuran payload melebihi batas maksimum (%d bytes)", maxBytes)
		}
		if errors.Is(err, io.EOF) {
			return errors.New("body JSON tidak boleh kosong")
		}
		return fmt.Errorf("format JSON tidak valid: %w", err)
	}
	// Pastikan hanya satu objek JSON
	if dec.More() {
		return errors.New("payload hanya boleh berisi satu objek JSON")
	}
	return nil
}

// ClassifyDomainError memetakan pesan error transaksi ke kode status HTTP yang tepat.
func ClassifyDomainError(err error) (int, string) {
	if err == nil {
		return http.StatusOK, ""
	}
	msg := err.Error()
	switch {
	case strings.HasPrefix(msg, "FORBIDDEN:"):
		return http.StatusForbidden, "FORBIDDEN"
	case strings.Contains(msg, "tidak ditemukan"):
		return http.StatusNotFound, "NOT_FOUND"
	case strings.Contains(msg, "tidak mencukupi"),
		strings.Contains(msg, "tidak cukup"),
		strings.Contains(msg, "di bawah batas"),
		strings.Contains(msg, "sisa kuota"),
		strings.Contains(msg, "Transisi status tidak valid"),
		strings.Contains(msg, "tidak dapat dibatalkan"),
		strings.Contains(msg, "harus"),
		strings.Contains(msg, "Pilih tepat satu"),
		strings.Contains(msg, "sudah terdaftar"):
		return http.StatusBadRequest, "VALIDATION_ERROR"
	default:
		return http.StatusBadRequest, "BAD_REQUEST"
	}
}
