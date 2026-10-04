package sync

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/abdulrahemfaqih/shopeespot/internal/auth"
	"github.com/abdulrahemfaqih/shopeespot/internal/config"
	"github.com/abdulrahemfaqih/shopeespot/internal/db"
)

func TestSyncRepository_Integration(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test in short mode")
	}

	cfg, err := config.Load()
	if err != nil || cfg.DatabaseURL == "" {
		t.Skip("skipping integration test: DATABASE_URL not configured")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	pool, err := db.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		t.Skipf("skipping integration test: cannot connect to database: %v", err)
	}
	defer pool.Close()

	// 1. Create temporary test user
	testUserID := uuid.New()
	testEmail := "synctest_" + testUserID.String()[:8] + "@example.com"
	now := time.Now().UTC()

	_, err = pool.Exec(ctx,
		"INSERT INTO users (id, email, password_hash, created_at) VALUES ($1, $2, $3, $4)",
		testUserID, testEmail, "hash", now,
	)
	if err != nil {
		t.Fatalf("failed to insert test user: %v", err)
	}
	defer func() {
		_, _ = pool.Exec(context.Background(), "DELETE FROM users WHERE id = $1", testUserID)
	}()

	repo := NewRepository(pool)

	// 2. Test Push Spots and Orders
	spotID := uuid.New()
	orderID := uuid.New()

	pushSpots := []Spot{
		{
			ID:        spotID,
			Name:      "Spot Uji Integrasi",
			Category:  "shopeefood",
			Latitude:  -7.25,
			Longitude: 112.75,
			Notes:     "Catatan uji",
			PeakHours: []PeakHourRange{
				{Days: []int{1, 2, 3}, Start: 660, End: 780},
			},
			CreatedAt: now,
			UpdatedAt: now,
		},
	}

	pushOrders := []Order{
		{
			ID:        orderID,
			SpotID:    spotID,
			OrderedAt: now,
			LocalDow:  2,
			LocalHour: 11,
			CreatedAt: now,
			UpdatedAt: now,
		},
	}

	pulledSpots, pulledOrders, err := repo.SyncTx(ctx, testUserID, pushSpots, pushOrders, 0, 0, 500)
	if err != nil {
		t.Fatalf("SyncTx failed: %v", err)
	}

	if len(pulledSpots) != 1 || pulledSpots[0].Name != "Spot Uji Integrasi" {
		t.Fatalf("expected 1 pulled spot matching name, got: %+v", pulledSpots)
	}
	if len(pulledOrders) != 1 || pulledOrders[0].LocalHour != 11 {
		t.Fatalf("expected 1 pulled order matching hour, got: %+v", pulledOrders)
	}

	// 3. Test Newer updated_at Wins Over Older
	olderTime := now.Add(-10 * time.Minute)
	olderSpots := []Spot{
		{
			ID:        spotID,
			Name:      "Nama Usang",
			Category:  "shopeefood",
			Latitude:  -7.25,
			Longitude: 112.75,
			CreatedAt: olderTime,
			UpdatedAt: olderTime,
		},
	}
	pulledSpots, _, err = repo.SyncTx(ctx, testUserID, olderSpots, nil, 0, 0, 500)
	if err != nil {
		t.Fatalf("SyncTx older failed: %v", err)
	}
	if pulledSpots[0].Name != "Spot Uji Integrasi" {
		t.Fatalf("expected original name to persist, got: %s", pulledSpots[0].Name)
	}

	// 4. Test Newer updated_at Overwrites
	newerTime := now.Add(10 * time.Minute)
	newerSpots := []Spot{
		{
			ID:        spotID,
			Name:      "Nama Baru",
			Category:  "shopeefood",
			Latitude:  -7.25,
			Longitude: 112.75,
			CreatedAt: now,
			UpdatedAt: newerTime,
		},
	}
	pulledSpots, _, err = repo.SyncTx(ctx, testUserID, newerSpots, nil, 0, 0, 500)
	if err != nil {
		t.Fatalf("SyncTx newer failed: %v", err)
	}
	if pulledSpots[0].Name != "Nama Baru" {
		t.Fatalf("expected updated name 'Nama Baru', got: %s", pulledSpots[0].Name)
	}

	// 5. Test Soft Delete
	deleteTime := now.Add(15 * time.Minute)
	deletedSpots := []Spot{
		{
			ID:        spotID,
			Name:      "Nama Baru",
			Category:  "shopeefood",
			Latitude:  -7.25,
			Longitude: 112.75,
			CreatedAt: now,
			UpdatedAt: deleteTime,
			DeletedAt: &deleteTime,
		},
	}
	pulledSpots, _, err = repo.SyncTx(ctx, testUserID, deletedSpots, nil, 0, 0, 500)
	if err != nil {
		t.Fatalf("SyncTx soft delete failed: %v", err)
	}
	if pulledSpots[0].DeletedAt == nil {
		t.Fatalf("expected deleted_at to be populated")
	}
}

// Suppress unused imports
var _ = os.Getenv
var _ = auth.MinPasswordLength
