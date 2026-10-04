package sync

import (
	"errors"
	"fmt"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
)

var (
	// ErrTooManySpots is returned when push exceeds 200 spots.
	ErrTooManySpots = errors.New("maksimal 200 spot per request")
	// ErrTooManyOrders is returned when push exceeds 200 orders.
	ErrTooManyOrders = errors.New("maksimal 200 order per request")
)

// ValidateSyncRequest validates a sync request against all constraints in ARCHITECTURE.md Section 10.
func ValidateSyncRequest(req *SyncRequest, now time.Time) error {
	if len(req.Spots) > MaxPushLimit {
		return ErrTooManySpots
	}
	if len(req.Orders) > MaxPushLimit {
		return ErrTooManyOrders
	}

	maxFuture := now.Add(24 * time.Hour)

	for i := range req.Spots {
		if err := validateSpot(&req.Spots[i], maxFuture); err != nil {
			return fmt.Errorf("spot[%d]: %w", i, err)
		}
	}

	for i := range req.Orders {
		if err := validateOrder(&req.Orders[i], maxFuture); err != nil {
			return fmt.Errorf("order[%d]: %w", i, err)
		}
	}

	return nil
}

func validateSpot(s *Spot, maxFuture time.Time) error {
	if s.ID == uuid.Nil {
		return errors.New("id spot tidak valid")
	}

	nameLen := utf8.RuneCountInString(s.Name)
	if nameLen < 1 || nameLen > 80 {
		return errors.New("nama spot harus 1-80 karakter")
	}

	if s.Category != "shopeefood" && s.Category != "spx" {
		return errors.New("kategori harus shopeefood atau spx")
	}

	if s.Latitude < -90 || s.Latitude > 90 {
		return errors.New("latitude harus antara -90 dan 90")
	}

	if s.Longitude < -180 || s.Longitude > 180 {
		return errors.New("longitude harus antara -180 dan 180")
	}

	if utf8.RuneCountInString(s.Notes) > 500 {
		return errors.New("catatan maksimal 500 karakter")
	}

	if len(s.PeakHours) > 20 {
		return errors.New("maksimal 20 rentang jam ramai")
	}

	for _, ph := range s.PeakHours {
		if err := validatePeakHour(ph); err != nil {
			return err
		}
	}

	if s.UpdatedAt.After(maxFuture) {
		return errors.New("updated_at tidak boleh lebih dari 1 hari di masa depan")
	}

	return nil
}

func validatePeakHour(ph PeakHourRange) error {
	if len(ph.Days) == 0 {
		return errors.New("hari jam ramai tidak boleh kosong")
	}
	for _, day := range ph.Days {
		if day < 1 || day > 7 {
			return errors.New("hari jam ramai harus bernilai 1-7")
		}
	}
	if ph.Start < 0 || ph.Start > 1439 || ph.End < 0 || ph.End > 1439 {
		return errors.New("waktu mulai/selesai harus antara 0 dan 1439")
	}
	if ph.Start >= ph.End {
		return errors.New("waktu mulai harus lebih kecil dari waktu selesai")
	}
	return nil
}

func validateOrder(o *Order, maxFuture time.Time) error {
	if o.ID == uuid.Nil {
		return errors.New("id order tidak valid")
	}
	if o.SpotID == uuid.Nil {
		return errors.New("spot_id order tidak valid")
	}
	if o.LocalDow < 1 || o.LocalDow > 7 {
		return errors.New("local_dow harus antara 1 dan 7")
	}
	if o.LocalHour < 0 || o.LocalHour > 23 {
		return errors.New("local_hour harus antara 0 dan 23")
	}
	if o.UpdatedAt.After(maxFuture) {
		return errors.New("updated_at order tidak boleh lebih dari 1 hari di masa depan")
	}
	return nil
}
