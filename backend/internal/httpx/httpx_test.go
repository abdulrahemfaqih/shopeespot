package httpx

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func TestWriteErrorFormat(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)

	WriteError(c, http.StatusUnauthorized, "invalid_credentials", "Email atau kata sandi salah.")

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected status 401, got %d", w.Code)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode JSON response: %v", err)
	}

	if resp.Error.Code != "invalid_credentials" {
		t.Errorf("expected code invalid_credentials, got %s", resp.Error.Code)
	}
	if resp.Error.Message != "Email atau kata sandi salah." {
		t.Errorf("expected message Email atau kata sandi salah., got %s", resp.Error.Message)
	}
}

func TestRequestIDMiddleware(t *testing.T) {
	router := gin.New()
	router.Use(RequestID())
	router.GET("/test", func(c *gin.Context) {
		c.String(http.StatusOK, GetRequestID(c))
	})

	// Case 1: Without incoming X-Request-Id header -> generates UUID
	w1 := httptest.NewRecorder()
	req1, _ := http.NewRequest(http.MethodGet, "/test", nil)
	router.ServeHTTP(w1, req1)

	reqID1 := w1.Header().Get(HeaderRequestID)
	if reqID1 == "" {
		t.Fatal("expected X-Request-Id header in response")
	}
	if w1.Body.String() != reqID1 {
		t.Errorf("expected context request_id to match header, got %s vs %s", w1.Body.String(), reqID1)
	}

	// Case 2: With incoming X-Request-Id header -> preserves it
	w2 := httptest.NewRecorder()
	req2, _ := http.NewRequest(http.MethodGet, "/test", nil)
	req2.Header.Set(HeaderRequestID, "custom-trace-id-123")
	router.ServeHTTP(w2, req2)

	if w2.Header().Get(HeaderRequestID) != "custom-trace-id-123" {
		t.Errorf("expected preserved header custom-trace-id-123, got %s", w2.Header().Get(HeaderRequestID))
	}
}

func TestRecoveryMiddleware(t *testing.T) {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	router := gin.New()
	router.Use(RequestID(), Recovery(logger))
	router.GET("/panic", func(c *gin.Context) {
		panic("something went critically wrong!")
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest(http.MethodGet, "/panic", nil)
	router.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected status 500, got %d", w.Code)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode JSON response: %v", err)
	}

	if resp.Error.Code != "internal" {
		t.Errorf("expected error code internal, got %s", resp.Error.Code)
	}
}

func TestBodyLimitMiddleware(t *testing.T) {
	router := gin.New()
	router.Use(BodyLimit(10)) // Limit to 10 bytes for testing
	router.POST("/data", func(c *gin.Context) {
		body, err := io.ReadAll(c.Request.Body)
		if err != nil {
			_ = c.Error(err)
			return
		}
		c.String(http.StatusOK, string(body))
	})

	// Case 1: Body within limit
	w1 := httptest.NewRecorder()
	req1, _ := http.NewRequest(http.MethodPost, "/data", strings.NewReader("hello"))
	router.ServeHTTP(w1, req1)
	if w1.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w1.Code)
	}

	// Case 2: Body exceeds limit
	w2 := httptest.NewRecorder()
	req2, _ := http.NewRequest(http.MethodPost, "/data", bytes.NewReader([]byte("this payload is definitely too long!")))
	router.ServeHTTP(w2, req2)
	if w2.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("expected status 413, got %d", w2.Code)
	}
}
