package sync

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/abdulrahemfaqih/shopeespot/internal/httpx"
)

// Service defines sync business logic.
type Service interface {
	Sync(ctx context.Context, userID uuid.UUID, req SyncRequest) (*SyncResponse, error)
}

type syncService struct {
	repo    Repository
	nowFunc func() time.Time
}

// NewService creates a new Sync service.
func NewService(repo Repository, nowFunc func() time.Time) Service {
	if nowFunc == nil {
		nowFunc = time.Now
	}
	return &syncService{
		repo:    repo,
		nowFunc: nowFunc,
	}
}

func (s *syncService) Sync(ctx context.Context, userID uuid.UUID, req SyncRequest) (*SyncResponse, error) {
	now := s.nowFunc().UTC()

	if err := ValidateSyncRequest(&req, now); err != nil {
		return nil, httpx.NewAppError(400, "validation_failed", err.Error(), err)
	}

	pulledSpots, pulledOrders, err := s.repo.SyncTx(
		ctx,
		userID,
		req.Spots,
		req.Orders,
		req.Cursors.Spots,
		req.Cursors.Orders,
		MaxPullLimit,
	)
	if err != nil {
		return nil, err
	}

	newSpotCursor := req.Cursors.Spots
	for _, spot := range pulledSpots {
		if spot.Seq > newSpotCursor {
			newSpotCursor = spot.Seq
		}
	}

	newOrderCursor := req.Cursors.Orders
	for _, order := range pulledOrders {
		if order.Seq > newOrderCursor {
			newOrderCursor = order.Seq
		}
	}

	hasMore := len(pulledSpots) >= MaxPullLimit || len(pulledOrders) >= MaxPullLimit

	if pulledSpots == nil {
		pulledSpots = []Spot{}
	}
	if pulledOrders == nil {
		pulledOrders = []Order{}
	}

	return &SyncResponse{
		Cursors: Cursors{
			Spots:  newSpotCursor,
			Orders: newOrderCursor,
		},
		Spots:      pulledSpots,
		Orders:     pulledOrders,
		HasMore:    hasMore,
		ServerTime: now,
	}, nil
}
