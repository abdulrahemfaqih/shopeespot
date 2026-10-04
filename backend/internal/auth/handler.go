package auth

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/abdulrahemfaqih/shopeespot/internal/httpx"
)

const (
	// ContextKeyUserID is the key used to store authenticated user UUID in gin.Context.
	ContextKeyUserID = "user_id"
)

// Handler handles HTTP requests for auth endpoints.
type Handler struct {
	service Service
}

// NewHandler creates a new Handler.
func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers the auth routes onto the given Gin router group.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/register", h.Register)
	rg.POST("/login", h.Login)
	rg.POST("/refresh", h.Refresh)
	rg.POST("/logout", h.Logout)
}

// Register handles user registration.
func (h *Handler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteError(c, http.StatusBadRequest, "bad_request", "Format email atau kata sandi tidak valid.")
		return
	}

	resp, err := h.service.Register(c.Request.Context(), req)
	if err != nil {
		httpx.WriteAppError(c, err)
		return
	}

	httpx.WriteJSON(c, http.StatusOK, resp)
}

// Login handles user authentication with email and password.
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteError(c, http.StatusBadRequest, "bad_request", "Format email atau kata sandi tidak valid.")
		return
	}

	resp, err := h.service.Login(c.Request.Context(), req)
	if err != nil {
		httpx.WriteAppError(c, err)
		return
	}

	httpx.WriteJSON(c, http.StatusOK, resp)
}

// Refresh handles token rotation.
func (h *Handler) Refresh(c *gin.Context) {
	var req RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteError(c, http.StatusBadRequest, "bad_request", "Token penyegar diperlukan.")
		return
	}

	resp, err := h.service.Refresh(c.Request.Context(), req)
	if err != nil {
		httpx.WriteAppError(c, err)
		return
	}

	httpx.WriteJSON(c, http.StatusOK, resp)
}

// Logout revokes the token family.
func (h *Handler) Logout(c *gin.Context) {
	var req LogoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteError(c, http.StatusBadRequest, "bad_request", "Token penyegar diperlukan.")
		return
	}

	_ = h.service.Logout(c.Request.Context(), req)
	c.Status(http.StatusNoContent)
}

// AuthMiddleware creates a Gin middleware that verifies Bearer JWT tokens.
func (h *Handler) AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			httpx.WriteError(c, http.StatusUnauthorized, "unauthorized", "Token akses diperlukan.")
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			httpx.WriteError(c, http.StatusUnauthorized, "unauthorized", "Format header otorisasi harus Bearer <token>.")
			return
		}

		tokenStr := strings.TrimSpace(parts[1])
		userID, err := h.service.ValidateToken(tokenStr)
		if err != nil {
			if errors.Is(err, ErrExpiredToken) {
				httpx.WriteError(c, http.StatusUnauthorized, "token_expired", "Token akses telah kedaluwarsa.")
				return
			}
			httpx.WriteError(c, http.StatusUnauthorized, "invalid_token", "Token akses tidak valid.")
			return
		}

		c.Set(ContextKeyUserID, userID)
		c.Next()
	}
}

// GetUserID retrieves the authenticated user's UUID from the Gin context.
func GetUserID(c *gin.Context) (uuid.UUID, bool) {
	val, exists := c.Get(ContextKeyUserID)
	if !exists {
		return uuid.Nil, false
	}
	userID, ok := val.(uuid.UUID)
	return userID, ok
}
