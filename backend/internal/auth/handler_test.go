package auth

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func setupTestRouter() (*gin.Engine, *Handler, Service) {
	repo := newMockRepository()
	baseTime := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	svc, _ := setupTestService(repo, baseTime)
	handler := NewHandler(svc)

	r := gin.New()
	v1 := r.Group("/v1/auth")
	handler.RegisterRoutes(v1)

	// Protected test route
	protected := r.Group("/v1/protected")
	protected.Use(handler.AuthMiddleware())
	protected.GET("/me", func(c *gin.Context) {
		userID, ok := GetUserID(c)
		if !ok {
			c.Status(http.StatusUnauthorized)
			return
		}
		c.JSON(http.StatusOK, gin.H{"user_id": userID.String()})
	})

	return r, handler, svc
}

func TestHandler_RegisterAndLogin(t *testing.T) {
	router, _, _ := setupTestRouter()

	// 1. Register
	regBody, _ := json.Marshal(RegisterRequest{
		Email:    "driver@example.com",
		Password: "password123",
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/register", bytes.NewBuffer(regBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 on register, got %d: %s", w.Code, w.Body.String())
	}

	var authResp AuthResponse
	if err := json.Unmarshal(w.Body.Bytes(), &authResp); err != nil {
		t.Fatalf("failed to decode auth response: %v", err)
	}

	if authResp.AccessToken == "" || authResp.RefreshToken == "" {
		t.Fatal("expected access and refresh tokens")
	}

	// 2. Login
	loginBody, _ := json.Marshal(LoginRequest{
		Email:    "driver@example.com",
		Password: "password123",
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/auth/login", bytes.NewBuffer(loginBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 on login, got %d: %s", w.Code, w.Body.String())
	}

	// 3. Login with wrong password -> 401 invalid_credentials
	wrongLoginBody, _ := json.Marshal(LoginRequest{
		Email:    "driver@example.com",
		Password: "wrongPassword!",
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/auth/login", bytes.NewBuffer(wrongLoginBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 on wrong password, got %d", w.Code)
	}
}

func TestHandler_RefreshAndLogout(t *testing.T) {
	router, _, svc := setupTestRouter()

	// Register user
	regResp, err := svc.Register(t.Context(), RegisterRequest{
		Email:    "driver@example.com",
		Password: "password123",
	})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	// 1. Refresh
	refreshBody, _ := json.Marshal(RefreshRequest{
		RefreshToken: regResp.RefreshToken,
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/auth/refresh", bytes.NewBuffer(refreshBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 on refresh, got %d: %s", w.Code, w.Body.String())
	}

	// 2. Logout
	logoutBody, _ := json.Marshal(LogoutRequest{
		RefreshToken: regResp.RefreshToken,
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/auth/logout", bytes.NewBuffer(logoutBody))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("expected 204 on logout, got %d", w.Code)
	}
}

func TestHandler_AuthMiddleware(t *testing.T) {
	router, _, svc := setupTestRouter()

	regResp, err := svc.Register(t.Context(), RegisterRequest{
		Email:    "driver@example.com",
		Password: "password123",
	})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	// 1. Request without auth header -> 401 unauthorized
	req := httptest.NewRequest(http.MethodGet, "/v1/protected/me", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 without auth header, got %d", w.Code)
	}

	// 2. Request with valid bearer token -> 200 OK
	req = httptest.NewRequest(http.MethodGet, "/v1/protected/me", nil)
	req.Header.Set("Authorization", "Bearer "+regResp.AccessToken)
	w = httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 with valid bearer token, got %d: %s", w.Code, w.Body.String())
	}

	// 3. Request with expired token -> 401 token_expired
	secret := []byte("secret-key-must-be-at-least-32-bytes!")
	expiredToken, _, _ := GenerateAccessToken(uuid.New(), secret, 1*time.Minute, time.Now().Add(-10*time.Minute))
	req = httptest.NewRequest(http.MethodGet, "/v1/protected/me", nil)
	req.Header.Set("Authorization", "Bearer "+expiredToken)
	w = httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for expired token, got %d", w.Code)
	}
	if !bytes.Contains(w.Body.Bytes(), []byte("token_expired")) {
		t.Fatalf("expected token_expired error code, got: %s", w.Body.String())
	}
}
