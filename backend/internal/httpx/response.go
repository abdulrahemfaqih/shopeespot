package httpx

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
)

// ErrorDetail contains machine-readable code and human-readable message.
type ErrorDetail struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// ErrorResponse represents standard error payload across all endpoints.
type ErrorResponse struct {
	Error ErrorDetail `json:"error"`
}

// AppError represents an application-level domain error with HTTP semantics.
type AppError struct {
	Status  int
	Code    string
	Message string
	Err     error
}

func (e *AppError) Error() string {
	if e.Err != nil {
		return e.Err.Error()
	}
	return e.Message
}

func (e *AppError) Unwrap() error {
	return e.Err
}

// NewAppError creates an AppError.
func NewAppError(status int, code, message string, err error) *AppError {
	return &AppError{
		Status:  status,
		Code:    code,
		Message: message,
		Err:     err,
	}
}

// WriteError sends a JSON error response matching ARCHITECTURE.md Section 10.
func WriteError(c *gin.Context, status int, code, message string) {
	c.AbortWithStatusJSON(status, ErrorResponse{
		Error: ErrorDetail{
			Code:    code,
			Message: message,
		},
	})
}

// WriteAppError handles an error by inspecting if it is an AppError or mapping it to internal.
func WriteAppError(c *gin.Context, err error) {
	var appErr *AppError
	if errors.As(err, &appErr) {
		WriteError(c, appErr.Status, appErr.Code, appErr.Message)
		return
	}

	WriteError(c, http.StatusInternalServerError, "internal", "Terjadi kesalahan internal server.")
}

// WriteJSON sends a successful JSON response.
func WriteJSON(c *gin.Context, status int, data any) {
	c.JSON(status, data)
}
