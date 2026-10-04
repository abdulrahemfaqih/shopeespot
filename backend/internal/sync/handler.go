package sync

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/abdulrahemfaqih/shopeespot/internal/auth"
	"github.com/abdulrahemfaqih/shopeespot/internal/httpx"
)

// Handler handles HTTP requests for sync endpoints.
type Handler struct {
	service Service
}

// NewHandler creates a new sync Handler.
func NewHandler(service Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes mounts sync endpoints to the given router group.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/sync", h.Sync)
}

// Sync handles push and pull synchronization for spots and orders.
func (h *Handler) Sync(c *gin.Context) {
	userID, ok := auth.GetUserID(c)
	if !ok {
		httpx.WriteError(c, http.StatusUnauthorized, "unauthorized", "Autentikasi diperlukan.")
		return
	}

	var req SyncRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.WriteError(c, http.StatusBadRequest, "bad_request", "Format payload sinkronisasi tidak valid.")
		return
	}

	resp, err := h.service.Sync(c.Request.Context(), userID, req)
	if err != nil {
		httpx.WriteAppError(c, err)
		return
	}

	httpx.WriteJSON(c, http.StatusOK, resp)
}
