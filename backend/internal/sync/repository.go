package sync

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository defines data access for sync operations.
type Repository interface {
	SyncTx(
		ctx context.Context,
		userID uuid.UUID,
		pushSpots []Spot,
		pushOrders []Order,
		spotCursor int64,
		orderCursor int64,
		pullLimit int,
	) ([]Spot, []Order, error)
}

type pgxRepository struct {
	pool *pgxpool.Pool
}

// NewRepository creates a PostgreSQL sync repository.
func NewRepository(pool *pgxpool.Pool) Repository {
	return &pgxRepository{pool: pool}
}

func (r *pgxRepository) SyncTx(
	ctx context.Context,
	userID uuid.UUID,
	pushSpots []Spot,
	pushOrders []Order,
	spotCursor int64,
	orderCursor int64,
	pullLimit int,
) ([]Spot, []Order, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("begin sync tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if len(pushSpots) > 0 {
		if err := upsertSpotsTx(ctx, tx, userID, pushSpots); err != nil {
			return nil, nil, fmt.Errorf("upsert spots: %w", err)
		}
	}

	if len(pushOrders) > 0 {
		if err := upsertOrdersTx(ctx, tx, userID, pushOrders); err != nil {
			return nil, nil, fmt.Errorf("upsert orders: %w", err)
		}
	}

	pulledSpots, err := pullSpotsTx(ctx, tx, userID, spotCursor, pullLimit)
	if err != nil {
		return nil, nil, fmt.Errorf("pull spots: %w", err)
	}

	pulledOrders, err := pullOrdersTx(ctx, tx, userID, orderCursor, pullLimit)
	if err != nil {
		return nil, nil, fmt.Errorf("pull orders: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, nil, fmt.Errorf("commit sync tx: %w", err)
	}

	return pulledSpots, pulledOrders, nil
}

func upsertSpotsTx(ctx context.Context, tx pgx.Tx, userID uuid.UUID, spots []Spot) error {
	ids := make([]uuid.UUID, len(spots))
	names := make([]string, len(spots))
	categories := make([]string, len(spots))
	lats := make([]float64, len(spots))
	lngs := make([]float64, len(spots))
	notes := make([]string, len(spots))
	peakHoursJSON := make([]string, len(spots))
	lastVerifiedAts := make([]*time.Time, len(spots))
	createdAts := make([]time.Time, len(spots))
	updatedAts := make([]time.Time, len(spots))
	deletedAts := make([]*time.Time, len(spots))

	for i, s := range spots {
		ids[i] = s.ID
		names[i] = s.Name
		categories[i] = s.Category
		lats[i] = s.Latitude
		lngs[i] = s.Longitude
		notes[i] = s.Notes
		ph, _ := json.Marshal(s.PeakHours)
		peakHoursJSON[i] = string(ph)
		lastVerifiedAts[i] = s.LastVerifiedAt
		createdAts[i] = s.CreatedAt
		updatedAts[i] = s.UpdatedAt
		deletedAts[i] = s.DeletedAt
	}

	query := `
		INSERT INTO spots (user_id, id, name, category, latitude, longitude, notes, peak_hours, last_verified_at, created_at, updated_at, deleted_at)
		SELECT $1, u.id, u.name, u.category, u.latitude, u.longitude, u.notes, u.peak_hours::jsonb, u.last_verified_at, u.created_at, u.updated_at, u.deleted_at
		FROM unnest(
			$2::uuid[],
			$3::text[],
			$4::text[],
			$5::double precision[],
			$6::double precision[],
			$7::text[],
			$8::text[],
			$9::timestamptz[],
			$10::timestamptz[],
			$11::timestamptz[],
			$12::timestamptz[]
		) AS u(id, name, category, latitude, longitude, notes, peak_hours, last_verified_at, created_at, updated_at, deleted_at)
		ON CONFLICT (user_id, id) DO UPDATE
		SET name = EXCLUDED.name,
			category = EXCLUDED.category,
			latitude = EXCLUDED.latitude,
			longitude = EXCLUDED.longitude,
			notes = EXCLUDED.notes,
			peak_hours = EXCLUDED.peak_hours,
			last_verified_at = EXCLUDED.last_verified_at,
			updated_at = EXCLUDED.updated_at,
			deleted_at = EXCLUDED.deleted_at,
			seq = nextval('sync_seq')
		WHERE spots.updated_at < EXCLUDED.updated_at;
	`
	_, err := tx.Exec(ctx, query, userID, ids, names, categories, lats, lngs, notes, peakHoursJSON, lastVerifiedAts, createdAts, updatedAts, deletedAts)
	return err
}

func upsertOrdersTx(ctx context.Context, tx pgx.Tx, userID uuid.UUID, orders []Order) error {
	ids := make([]uuid.UUID, len(orders))
	spotIDs := make([]uuid.UUID, len(orders))
	orderedAts := make([]time.Time, len(orders))
	localDows := make([]int16, len(orders))
	localHours := make([]int16, len(orders))
	createdAts := make([]time.Time, len(orders))
	updatedAts := make([]time.Time, len(orders))
	deletedAts := make([]*time.Time, len(orders))

	for i, o := range orders {
		ids[i] = o.ID
		spotIDs[i] = o.SpotID
		orderedAts[i] = o.OrderedAt
		localDows[i] = o.LocalDow
		localHours[i] = o.LocalHour
		createdAts[i] = o.CreatedAt
		updatedAts[i] = o.UpdatedAt
		deletedAts[i] = o.DeletedAt
	}

	query := `
		INSERT INTO orders (user_id, id, spot_id, ordered_at, local_dow, local_hour, created_at, updated_at, deleted_at)
		SELECT $1, * FROM unnest(
			$2::uuid[],
			$3::uuid[],
			$4::timestamptz[],
			$5::smallint[],
			$6::smallint[],
			$7::timestamptz[],
			$8::timestamptz[],
			$9::timestamptz[]
		)
		ON CONFLICT (user_id, id) DO UPDATE
		SET spot_id = EXCLUDED.spot_id,
			ordered_at = EXCLUDED.ordered_at,
			local_dow = EXCLUDED.local_dow,
			local_hour = EXCLUDED.local_hour,
			updated_at = EXCLUDED.updated_at,
			deleted_at = EXCLUDED.deleted_at,
			seq = nextval('sync_seq')
		WHERE orders.updated_at < EXCLUDED.updated_at;
	`
	_, err := tx.Exec(ctx, query, userID, ids, spotIDs, orderedAts, localDows, localHours, createdAts, updatedAts, deletedAts)
	return err
}

func pullSpotsTx(ctx context.Context, tx pgx.Tx, userID uuid.UUID, cursor int64, limit int) ([]Spot, error) {
	query := `
		SELECT id, name, category, latitude, longitude, notes, peak_hours, last_verified_at, created_at, updated_at, deleted_at, seq
		FROM spots
		WHERE user_id = $1 AND seq > $2
		ORDER BY seq ASC
		LIMIT $3
	`
	rows, err := tx.Query(ctx, query, userID, cursor, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var spots []Spot
	for rows.Next() {
		var s Spot
		var rawPeakHours []byte
		if err := rows.Scan(
			&s.ID, &s.Name, &s.Category, &s.Latitude, &s.Longitude,
			&s.Notes, &rawPeakHours, &s.LastVerifiedAt, &s.CreatedAt,
			&s.UpdatedAt, &s.DeletedAt, &s.Seq,
		); err != nil {
			return nil, err
		}
		if len(rawPeakHours) > 0 {
			_ = json.Unmarshal(rawPeakHours, &s.PeakHours)
		}
		if s.PeakHours == nil {
			s.PeakHours = []PeakHourRange{}
		}
		spots = append(spots, s)
	}
	return spots, rows.Err()
}

func pullOrdersTx(ctx context.Context, tx pgx.Tx, userID uuid.UUID, cursor int64, limit int) ([]Order, error) {
	query := `
		SELECT id, spot_id, ordered_at, local_dow, local_hour, created_at, updated_at, deleted_at, seq
		FROM orders
		WHERE user_id = $1 AND seq > $2
		ORDER BY seq ASC
		LIMIT $3
	`
	rows, err := tx.Query(ctx, query, userID, cursor, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var orders []Order
	for rows.Next() {
		var o Order
		if err := rows.Scan(
			&o.ID, &o.SpotID, &o.OrderedAt, &o.LocalDow, &o.LocalHour,
			&o.CreatedAt, &o.UpdatedAt, &o.DeletedAt, &o.Seq,
		); err != nil {
			return nil, err
		}
		orders = append(orders, o)
	}
	return orders, rows.Err()
}
