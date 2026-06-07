package model

import (
	"fmt"
	"time"
)

// AdRewardLedgerRefID builds the ledger ref_id for an ad reward grant.
func AdRewardLedgerRefID(network, signature string) string {
	return fmt.Sprintf("%s:%s", network, signature)
}

// AdReward records a granted incentivized ad reward.
type AdReward struct {
	ID             string
	UserID         string
	Network        string
	PlacementID    string
	Signature      string
	GrantedCredits int64
	CreatedAt      time.Time
}
