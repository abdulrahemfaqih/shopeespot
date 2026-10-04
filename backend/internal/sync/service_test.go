package sync

import (
	"context"
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

type mockSyncRepository struct {
	mu         sync.Mutex
	spots      map[string]Spot  // key: userID:spotID
	orders     map[string]Order // key: userID:orderID
	nextSeqVal int64
}

func newMockSyncRepository() *mockSyncRepository {
	return &mockSyncRepository{
		spots:      make(map[string]Spot),
		orders:     make(map[string]Order),
		nextSeqVal: 1,
	}
}

func (m *mockSyncRepository) SyncTx(
	ctx context.Context,
	userID uuid.UUID,
	pushSpots []Spot,
	pushOrders []Order,
	spotCursor int64,
	orderCursor int64,
	pullLimit int,
) ([]Spot, []Order, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// 1. Process spots push
	for _, s := range pushSpots {
		key := userID.String() + ":" + s.ID.String()
		existing, found := m.spots[key]
		if !found || s.UpdatedAt.After(existing.UpdatedAt) {
			s.UserID = userID
			s.Seq = m.nextSeqVal
			m.nextSeqVal++
			m.spots[key] = s
		}
	}

	// 2. Process orders push
	for _, o := range pushOrders {
		key := userID.String() + ":" + o.ID.String()
		existing, found := m.orders[key]
		if !found || o.UpdatedAt.After(existing.UpdatedAt) {
			o.UserID = userID
			o.Seq = m.nextSeqVal
			m.nextSeqVal++
			m.orders[key] = o
		}
	}

	// 3. Pull spots where seq > spotCursor
	var pulledSpots []Spot
	for _, s := range m.spots {
		if s.UserID == userID && s.Seq > spotCursor {
			pulledSpots = append(pulledSpots, s)
		}
	}
	sort.Slice(pulledSpots, func(i, j int) bool {
		return pulledSpots[i].Seq < pulledSpots[j].Seq
	})
	if len(pulledSpots) > pullLimit {
		pulledSpots = pulledSpots[:pullLimit]
	}

	// 4. Pull orders where seq > orderCursor
	var pulledOrders []Order
	for _, o := range m.orders {
		if o.UserID == userID && o.Seq > orderCursor {
			pulledOrders = append(pulledOrders, o)
		}
	}
	sort.Slice(pulledOrders, func(i, j int) bool {
		return pulledOrders[i].Seq < pulledOrders[j].Seq
	})
	if len(pulledOrders) > pullLimit {
		pulledOrders = pulledOrders[:pullLimit]
	}

	return pulledSpots, pulledOrders, nil
}

func TestSyncService_NewerWins(t *testing.T) {
	repo := newMockSyncRepository()
	now := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	svc := NewService(repo, func() time.Time { return now })
	userID := uuid.New()
	spotID := uuid.New()

	// Client 1 pushes spot version 1
	req1 := SyncRequest{
		Spots: []Spot{
			{
				ID:        spotID,
				Name:      "Warung Awal",
				Category:  "shopeefood",
				Latitude:  -7.1,
				Longitude: 112.5,
				CreatedAt: now,
				UpdatedAt: now,
			},
		},
	}
	resp1, err := svc.Sync(context.Background(), userID, req1)
	if err != nil {
		t.Fatalf("first sync failed: %v", err)
	}
	if len(resp1.Spots) != 1 || resp1.Spots[0].Name != "Warung Awal" {
		t.Fatalf("expected 1 spot with name 'Warung Awal'")
	}

	// Client 2 attempts to push an older version (updated_at earlier) -> should not overwrite
	olderTime := now.Add(-10 * time.Minute)
	reqOlder := SyncRequest{
		Spots: []Spot{
			{
				ID:        spotID,
				Name:      "Warung Usang",
				Category:  "shopeefood",
				Latitude:  -7.1,
				Longitude: 112.5,
				CreatedAt: olderTime,
				UpdatedAt: olderTime,
			},
		},
	}
	respOlder, err := svc.Sync(context.Background(), userID, reqOlder)
	if err != nil {
		t.Fatalf("sync older failed: %v", err)
	}
	// Pulled spots should still have "Warung Awal"
	if len(respOlder.Spots) != 1 || respOlder.Spots[0].Name != "Warung Awal" {
		t.Fatalf("older update should not win, got name: %s", respOlder.Spots[0].Name)
	}

	// Client 1 pushes a newer version -> should overwrite
	newerTime := now.Add(10 * time.Minute)
	reqNewer := SyncRequest{
		Spots: []Spot{
			{
				ID:        spotID,
				Name:      "Warung Baru",
				Category:  "shopeefood",
				Latitude:  -7.1,
				Longitude: 112.5,
				CreatedAt: now,
				UpdatedAt: newerTime,
			},
		},
	}
	respNewer, err := svc.Sync(context.Background(), userID, reqNewer)
	if err != nil {
		t.Fatalf("sync newer failed: %v", err)
	}
	if len(respNewer.Spots) != 1 || respNewer.Spots[0].Name != "Warung Baru" {
		t.Fatalf("expected newer version 'Warung Baru', got: %s", respNewer.Spots[0].Name)
	}
}

func TestSyncService_SoftDeletePropagation(t *testing.T) {
	repo := newMockSyncRepository()
	now := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	svc := NewService(repo, func() time.Time { return now })
	userID := uuid.New()
	spotID := uuid.New()

	// 1. Create spot
	_, _ = svc.Sync(context.Background(), userID, SyncRequest{
		Spots: []Spot{
			{ID: spotID, Name: "Warung", Category: "shopeefood", Latitude: -7.0, Longitude: 112.0, CreatedAt: now, UpdatedAt: now},
		},
	})

	// 2. Soft delete spot
	deleteTime := now.Add(5 * time.Minute)
	delResp, err := svc.Sync(context.Background(), userID, SyncRequest{
		Spots: []Spot{
			{
				ID:        spotID,
				Name:      "Warung",
				Category:  "shopeefood",
				Latitude:  -7.0,
				Longitude: 112.0,
				CreatedAt: now,
				UpdatedAt: deleteTime,
				DeletedAt: &deleteTime,
			},
		},
	})
	if err != nil {
		t.Fatalf("sync soft delete failed: %v", err)
	}

	if len(delResp.Spots) != 1 || delResp.Spots[0].DeletedAt == nil {
		t.Fatalf("expected pulled spot to have deleted_at set")
	}
}

func TestSyncService_HasMoreFlag(t *testing.T) {
	repo := newMockSyncRepository()
	now := time.Date(2026, 10, 4, 12, 0, 0, 0, time.UTC)
	svc := NewService(repo, func() time.Time { return now })
	userID := uuid.New()

	// Seed 500 spots directly in repo
	repo.mu.Lock()
	for i := 0; i < 500; i++ {
		sID := uuid.New()
		key := userID.String() + ":" + sID.String()
		repo.spots[key] = Spot{
			ID:        sID,
			UserID:    userID,
			Name:      "Spot",
			Category:  "shopeefood",
			CreatedAt: now,
			UpdatedAt: now,
			Seq:       int64(i + 1),
		}
	}
	repo.mu.Unlock()

	// Pull from cursor 0
	resp, err := svc.Sync(context.Background(), userID, SyncRequest{Cursors: Cursors{Spots: 0, Orders: 0}})
	if err != nil {
		t.Fatalf("sync failed: %v", err)
	}

	if len(resp.Spots) != 500 {
		t.Fatalf("expected 500 pulled spots, got %d", len(resp.Spots))
	}
	if !resp.HasMore {
		t.Fatal("expected has_more to be true when 500 items pulled")
	}
}
