package rates

import (
	_ "embed"
	"encoding/json"
	"fmt"
)

//go:embed rates.manifest.json
var manifestJSON []byte

// DurationTier is a video play length option with its credit cost.
type DurationTier struct {
	DurationSeconds int `json:"durationSeconds"`
	CreditCost      int `json:"creditCost"`
}

// PlayRate is the credit cost for one AI play.
type PlayRate struct {
	PlayID        string         `json:"playId"`
	Kind          string         `json:"kind"`
	CreditCost    int            `json:"creditCost,omitempty"`
	DurationTiers []DurationTier `json:"durationTiers,omitempty"`
}

// RechargePack is an IAP credit pack tier (PRD §4.11.2).
type RechargePack struct {
	ProductID string `json:"productId"`
	Credits   int    `json:"credits"`
	PriceCNY  int    `json:"priceCny"`
}

// Catalog is the published credit pricing snapshot.
type Catalog struct {
	Version       string         `json:"version"`
	Plays         []PlayRate     `json:"plays"`
	RechargePacks []RechargePack `json:"rechargePacks"`
}

// LoadCatalog parses the embedded rates manifest.
func LoadCatalog() (Catalog, error) {
	var c Catalog
	if err := json.Unmarshal(manifestJSON, &c); err != nil {
		return Catalog{}, fmt.Errorf("parse rates manifest: %w", err)
	}
	if c.Version == "" {
		return Catalog{}, fmt.Errorf("rates manifest missing version")
	}
	return c, nil
}
