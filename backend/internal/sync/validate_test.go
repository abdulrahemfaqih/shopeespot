package sync

import (
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestValidateSyncRequest_Valid(t *testing.T) {
	now := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	spotID := uuid.New()

	req := SyncRequest{
		Cursors: Cursors{Spots: 0, Orders: 0},
		Spots: []Spot{
			{
				ID:        spotID,
				Name:      "Ayam Geprek Sambal Korek",
				Category:  "shopeefood",
				Latitude:  -7.2575,
				Longitude: 112.7521,
				Notes:     "Dekat parkir timur",
				PeakHours: []PeakHourRange{
					{Days: []int{1, 2, 3, 4, 5}, Start: 660, End: 780}, // 11:00 - 13:00
				},
				CreatedAt: now,
				UpdatedAt: now,
			},
		},
		Orders: []Order{
			{
				ID:        uuid.New(),
				SpotID:    spotID,
				OrderedAt: now,
				LocalDow:  1,
				LocalHour: 11,
				CreatedAt: now,
				UpdatedAt: now,
			},
		},
	}

	err := ValidateSyncRequest(&req, now)
	if err != nil {
		t.Fatalf("expected valid sync request, got error: %v", err)
	}
}

func TestValidateSyncRequest_TooManySpots(t *testing.T) {
	now := time.Now()
	spots := make([]Spot, 201)
	for i := 0; i < 201; i++ {
		spots[i] = Spot{
			ID:        uuid.New(),
			Name:      "Spot",
			Category:  "shopeefood",
			Latitude:  0,
			Longitude: 0,
			CreatedAt: now,
			UpdatedAt: now,
		}
	}
	req := SyncRequest{Spots: spots}
	err := ValidateSyncRequest(&req, now)
	if err == nil || !strings.Contains(err.Error(), "maksimal 200 spot") {
		t.Fatalf("expected too many spots error, got: %v", err)
	}
}

func TestValidateSyncRequest_TooManyOrders(t *testing.T) {
	now := time.Now()
	orders := make([]Order, 201)
	for i := 0; i < 201; i++ {
		orders[i] = Order{
			ID:        uuid.New(),
			SpotID:    uuid.New(),
			OrderedAt: now,
			LocalDow:  1,
			LocalHour: 12,
			CreatedAt: now,
			UpdatedAt: now,
		}
	}
	req := SyncRequest{Orders: orders}
	err := ValidateSyncRequest(&req, now)
	if err == nil || !strings.Contains(err.Error(), "maksimal 200 order") {
		t.Fatalf("expected too many orders error, got: %v", err)
	}
}

func TestValidateSyncRequest_InvalidSpotFields(t *testing.T) {
	now := time.Now()
	testCases := []struct {
		name string
		spot Spot
	}{
		{
			name: "empty id",
			spot: Spot{ID: uuid.Nil, Name: "A", Category: "shopeefood", CreatedAt: now, UpdatedAt: now},
		},
		{
			name: "empty name",
			spot: Spot{ID: uuid.New(), Name: "", Category: "shopeefood", CreatedAt: now, UpdatedAt: now},
		},
		{
			name: "name too long",
			spot: Spot{ID: uuid.New(), Name: strings.Repeat("A", 81), Category: "shopeefood", CreatedAt: now, UpdatedAt: now},
		},
		{
			name: "invalid category",
			spot: Spot{ID: uuid.New(), Name: "A", Category: "grabfood", CreatedAt: now, UpdatedAt: now},
		},
		{
			name: "lat out of bounds",
			spot: Spot{ID: uuid.New(), Name: "A", Category: "shopeefood", Latitude: 95.0, CreatedAt: now, UpdatedAt: now},
		},
		{
			name: "lng out of bounds",
			spot: Spot{ID: uuid.New(), Name: "A", Category: "shopeefood", Longitude: -185.0, CreatedAt: now, UpdatedAt: now},
		},
		{
			name: "notes too long",
			spot: Spot{ID: uuid.New(), Name: "A", Category: "shopeefood", Notes: strings.Repeat("X", 501), CreatedAt: now, UpdatedAt: now},
		},
		{
			name: "invalid peak hour day",
			spot: Spot{
				ID: uuid.New(), Name: "A", Category: "shopeefood", CreatedAt: now, UpdatedAt: now,
				PeakHours: []PeakHourRange{{Days: []int{8}, Start: 100, End: 200}},
			},
		},
		{
			name: "invalid peak hour range",
			spot: Spot{
				ID: uuid.New(), Name: "A", Category: "shopeefood", CreatedAt: now, UpdatedAt: now,
				PeakHours: []PeakHourRange{{Days: []int{1}, Start: 300, End: 200}},
			},
		},
		{
			name: "updated_at too far future",
			spot: Spot{
				ID: uuid.New(), Name: "A", Category: "shopeefood", CreatedAt: now,
				UpdatedAt: now.Add(25 * time.Hour),
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			req := SyncRequest{Spots: []Spot{tc.spot}}
			if err := ValidateSyncRequest(&req, now); err == nil {
				t.Fatalf("expected validation error for %s, got nil", tc.name)
			}
		})
	}
}

func TestValidateSyncRequest_InvalidOrderFields(t *testing.T) {
	now := time.Now()
	testCases := []struct {
		name  string
		order Order
	}{
		{
			name:  "empty id",
			order: Order{ID: uuid.Nil, SpotID: uuid.New(), LocalDow: 1, LocalHour: 10, CreatedAt: now, UpdatedAt: now},
		},
		{
			name:  "empty spot id",
			order: Order{ID: uuid.New(), SpotID: uuid.Nil, LocalDow: 1, LocalHour: 10, CreatedAt: now, UpdatedAt: now},
		},
		{
			name:  "invalid dow",
			order: Order{ID: uuid.New(), SpotID: uuid.New(), LocalDow: 0, LocalHour: 10, CreatedAt: now, UpdatedAt: now},
		},
		{
			name:  "invalid hour",
			order: Order{ID: uuid.New(), SpotID: uuid.New(), LocalDow: 1, LocalHour: 24, CreatedAt: now, UpdatedAt: now},
		},
		{
			name:  "future updated_at",
			order: Order{ID: uuid.New(), SpotID: uuid.New(), LocalDow: 1, LocalHour: 10, CreatedAt: now, UpdatedAt: now.Add(25 * time.Hour)},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			req := SyncRequest{Orders: []Order{tc.order}}
			if err := ValidateSyncRequest(&req, now); err == nil {
				t.Fatalf("expected validation error for %s, got nil", tc.name)
			}
		})
	}
}
