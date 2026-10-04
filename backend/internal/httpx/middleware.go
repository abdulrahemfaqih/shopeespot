package httpx

import (
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"runtime/debug"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const (
	// HeaderRequestID is the standard HTTP header for tracing requests.
	HeaderRequestID = "X-Request-Id"

	// ContextKeyRequestID is the key stored in Gin context.
	ContextKeyRequestID = "request_id"

	// DefaultMaxBodyBytes is 1 MB per ARCHITECTURE.md Section 10.
	DefaultMaxBodyBytes = 1024 * 1024
)

// RequestID middleware ensures every request has a unique request ID.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		reqID := strings.TrimSpace(c.GetHeader(HeaderRequestID))
		if reqID == "" {
			reqID = uuid.New().String()
		}

		c.Set(ContextKeyRequestID, reqID)
		c.Header(HeaderRequestID, reqID)
		c.Next()
	}
}

// GetRequestID returns the request ID from Gin context or an empty string.
func GetRequestID(c *gin.Context) string {
	if val, ok := c.Get(ContextKeyRequestID); ok {
		if s, ok := val.(string); ok {
			return s
		}
	}
	return ""
}

// Logger middleware logs incoming HTTP requests using slog without logging sensitive data.
func Logger(logger *slog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		rawQuery := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()
		reqID := GetRequestID(c)

		if rawQuery != "" {
			path = path + "?" + rawQuery
		}

		attrs := []slog.Attr{
			slog.String("request_id", reqID),
			slog.String("method", c.Request.Method),
			slog.String("path", path),
			slog.Int("status", status),
			slog.Duration("latency", latency),
			slog.String("client_ip", c.ClientIP()),
		}

		msg := fmt.Sprintf("%s %s %d %s", c.Request.Method, path, status, latency)

		ctx := c.Request.Context()
		if status >= http.StatusInternalServerError {
			logger.LogAttrs(ctx, slog.LevelError, msg, attrs...)
		} else if status >= http.StatusBadRequest {
			logger.LogAttrs(ctx, slog.LevelWarn, msg, attrs...)
		} else {
			logger.LogAttrs(ctx, slog.LevelInfo, msg, attrs...)
		}
	}
}

// Recovery middleware recovers from panics and returns a generic 500 error response.
func Recovery(logger *slog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if r := recover(); r != nil {
				reqID := GetRequestID(c)
				stack := string(debug.Stack())

				logger.ErrorContext(
					c.Request.Context(),
					"panic recovered in HTTP handler",
					slog.String("request_id", reqID),
					slog.Any("error", r),
					slog.String("stack", stack),
				)

				WriteError(c, http.StatusInternalServerError, "internal", "Terjadi kesalahan internal server.")
			}
		}()
		c.Next()
	}
}

// BodyLimit middleware enforces a maximum request body size (default 1 MB).
func BodyLimit(maxBytes int64) gin.HandlerFunc {
	if maxBytes <= 0 {
		maxBytes = DefaultMaxBodyBytes
	}

	return func(c *gin.Context) {
		if c.Request.Body != nil {
			c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes)
		}
		c.Next()

		// If an error occurred reading the body due to MaxBytesReader
		for _, err := range c.Errors {
			var maxBytesErr *http.MaxBytesError
			if errors.As(err.Err, &maxBytesErr) {
				WriteError(c, http.StatusRequestEntityTooLarge, "payload_too_large", "Ukuran payload melebihi batas 1 MB.")
				return
			}
		}
	}
}
