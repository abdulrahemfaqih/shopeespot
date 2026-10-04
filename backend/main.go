package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/abdulrahemfaqih/shopeespot/internal/auth"
	"github.com/abdulrahemfaqih/shopeespot/internal/config"
	"github.com/abdulrahemfaqih/shopeespot/internal/db"
	"github.com/abdulrahemfaqih/shopeespot/internal/httpx"
	"github.com/abdulrahemfaqih/shopeespot/internal/sync"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to load configuration: %v\n", err)
		os.Exit(1)
	}

	// Setup structured logger with slog
	var handler slog.Handler
	if cfg.AppEnv == "production" {
		handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})
	} else {
		handler = slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelDebug})
	}
	logger := slog.New(handler)
	slog.SetDefault(logger)

	logger.Info("starting SpotShopee backend",
		slog.String("env", cfg.AppEnv),
		slog.String("port", cfg.Port),
	)

	// Initialize database pool if database URL is provided
	var pool *pgxpool.Pool
	var poolClose func()
	if cfg.DatabaseURL != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var err error
		pool, err = db.NewPool(ctx, cfg.DatabaseURL)
		if err != nil {
			logger.Warn("could not connect to database pool on startup", slog.String("error", err.Error()))
		} else {
			logger.Info("database pool connected successfully")
			poolClose = pool.Close
		}
	}

	// Configure Gin
	if cfg.AppEnv == "production" {
		gin.SetMode(gin.ReleaseMode)
	} else {
		gin.SetMode(gin.DebugMode)
	}

	var authHandler *auth.Handler
	var syncHandler *sync.Handler
	if pool != nil {
		authRepo := auth.NewRepository(pool)
		authSvc := auth.NewService(authRepo, auth.ServiceConfig{
			JWTSecret:           cfg.JWTSecret,
			AccessTokenTTL:      cfg.AccessTokenTTL,
			RefreshTokenTTL:     cfg.RefreshTokenTTL,
			RefreshGrace:        cfg.RefreshGrace,
			BcryptCost:          cfg.BcryptCost,
			RegistrationEnabled: cfg.RegistrationEnabled,
		})
		authHandler = auth.NewHandler(authSvc)

		syncRepo := sync.NewRepository(pool)
		syncSvc := sync.NewService(syncRepo, nil)
		syncHandler = sync.NewHandler(syncSvc)
	}

	router := setupRouter(logger, authHandler, syncHandler)

	// Create and start HTTP server
	addr := ":" + cfg.Port
	srv := &http.Server{
		Addr:         addr,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown channel
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		logger.Info("server listening", slog.String("addr", addr))
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server error", slog.String("error", err.Error()))
			os.Exit(1)
		}
	}()

	<-stop
	logger.Info("shutting down server gracefully...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("server shutdown forced", slog.String("error", err.Error()))
	}

	if poolClose != nil {
		poolClose()
		logger.Info("database pool closed")
	}

	logger.Info("server exited cleanly")
}

// setupRouter configures middleware and registered endpoints.
func setupRouter(logger *slog.Logger, authHandler *auth.Handler, syncHandler *sync.Handler) *gin.Engine {
	router := gin.New()

	router.Use(
		httpx.RequestID(),
		httpx.Logger(logger),
		httpx.Recovery(logger),
		httpx.BodyLimit(httpx.DefaultMaxBodyBytes),
	)

	// Health check endpoint per ARCHITECTURE.md Section 10
	router.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "ok",
		})
	})

	if authHandler != nil {
		v1 := router.Group("/v1")
		authGroup := v1.Group("/auth")
		authHandler.RegisterRoutes(authGroup)

		if syncHandler != nil {
			v1Sync := v1.Group("")
			v1Sync.Use(authHandler.AuthMiddleware())
			syncHandler.RegisterRoutes(v1Sync)
		}
	}

	return router
}
