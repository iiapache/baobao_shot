package model

import "time"

// HoldStatus is the saga lifecycle for a credit reservation.
type HoldStatus string

const (
	HoldStatusHeld      HoldStatus = "held"
	HoldStatusCommitted HoldStatus = "committed"
	HoldStatusReleased  HoldStatus = "released"
)

// Hold is a reserved credit amount for an AI task (design-backend §6.1).
type Hold struct {
	ID        string
	UserID    string
	AITaskID  string
	Amount    int64
	Status    HoldStatus
	CreatedAt time.Time
}
