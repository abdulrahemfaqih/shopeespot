package sync

import (
	"time"

	"github.com/google/uuid"
)

const (
	// MaxPushLimit is the maximum items allowed per table in a push sync.
	MaxPushLimit = 200
	// MaxPullLimit is the maximum items pulled per table in a pull sync.
	MaxPullLimit = 500
)

// Cursors holds per-table sync sequence positions.
type Cursors struct {
	Spots  int64 `json:"spots"`
	Orders int64 `json:"orders"`
}

// PeakHourRange defines a single recurring peak window.
type PeakHourRange struct {
	Days  []int `json:"days"`
	Start int   `json:"start"`
	End   int   `json:"end"`
}

// Spot represents a seller or hub location.
type Spot struct {
	ID             uuid.UUID       `json:"id"`
	UserID         uuid.UUID       `json:"-"`
	Name           string          `json:"name"`
	Category       string          `json:"category"`
	Latitude       float64         `json:"latitude"`
	Longitude      float64         `json:"longitude"`
	Notes          string          `json:"notes"`
	PeakHours      []PeakHourRange `json:"peak_hours"`
	LastVerifiedAt *time.Time      `json:"last_verified_at"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
	DeletedAt      *time.Time      `json:"deleted_at"`
	Seq            int64           `json:"seq,omitempty"`
}

// Order represents an order logged by the driver at a spot.
type Order struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"-"`
	SpotID    uuid.UUID  `json:"spot_id"`
	OrderedAt time.Time  `json:"ordered_at"`
	LocalDow  int16      `json:"local_dow"`  // 1=Monday ... 7=Sunday
	LocalHour int16      `json:"local_hour"` // 0-23
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	DeletedAt *time.Time `json:"deleted_at"`
	Seq       int64      `json:"seq,omitempty"`
}

// SyncRequest is the payload sent by the mobile client to POST /v1/sync.
type SyncRequest struct {
	Cursors Cursors `json:"cursors"`
	Spots   []Spot  `json:"spots"`
	Orders  []Order `json:"orders"`
}

// SyncResponse is the payload returned by POST /v1/sync.
type SyncResponse struct {
	Cursors    Cursors   `json:"cursors"`
	Spots      []Spot    `json:"spots"`
	Orders     []Order   `json:"orders"`
	HasMore    bool      `json:"has_more"`
	ServerTime time.Time `json:"server_time"`
}
