package sync

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/abdulrahemfaqih/shopeespot/internal/auth"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func setupTestSyncRouter() (*gin.Engine, uuid.UUID) {
	repo := newMockSyncRepository()
	now := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	svc := NewService(repo, func() time.Time { return now })
	handler := NewHandler(svc)

	testUserID := uuid.New()

	r := gin.New()
	v1 := r.Group("/v1")

	// Middleware setting authenticated user
	v1.Use(func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "Bearer valid-token" {
			c.Set(auth.ContextKeyUserID, testUserID)
		}
		c.Next()
	})

	handler.RegisterRoutes(v1)
	return r, testUserID
}

func TestHandler_Sync_Success(t *testing.T) {
	router, _ := setupTestSyncRouter()

	reqBody, _ := json.Marshal(SyncRequest{
		Cursors: Cursors{Spots: 0, Orders: 0},
		Spots:   []Spot{},
		Orders:  []Order{},
	})

	req := httptest.NewRequest(http.MethodPost, "/v1/sync", bytes.NewBuffer(reqBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer valid-token")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 OK on sync, got %d: %s", w.Code, w.Body.String())
	}

	var resp SyncResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.HasMore {
		t.Fatal("expected has_more to be false")
	}
}

func TestHandler_Sync_Unauthorized(t *testing.T) {
	router, _ := setupTestSyncRouter()

	reqBody, _ := json.Marshal(SyncRequest{})
	req := httptest.NewRequest(http.MethodPost, "/v1/sync", bytes.NewBuffer(reqBody))
	req.Header.Set("Content-Type", "application/json")
	// Missing Authorization header
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 Unauthorized, got %d", w.Code)
	}
}
