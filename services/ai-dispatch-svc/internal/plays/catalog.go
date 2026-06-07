package plays

import (
	"context"
	"strings"

	"github.com/baobao/ai-dispatch-svc/internal/configclient"
)

// PlayItem is a region-filtered play exposed to clients.
type PlayItem struct {
	ID            string         `json:"id"`
	Name          string         `json:"name"`
	Description   string         `json:"description,omitempty"`
	Kind          string         `json:"kind"`
	CreditCost    int            `json:"creditCost,omitempty"`
	DurationTiers []DurationTier `json:"durationTiers,omitempty"`
	Available     bool           `json:"available"`
}

// CatalogResponse is returned by GET /v1/ai/plays.
type CatalogResponse struct {
	Version    string     `json:"version"`
	Region     string     `json:"region"`
	TTLSeconds int        `json:"ttlSeconds"`
	Plays      []PlayItem `json:"plays"`
}

// ListOptions carries request context for catalog filtering.
type ListOptions struct {
	Region     string
	AppVersion string
	UserID     string
}

// FilingChecker gates CN plays that require filed model adapters (T7.1).
type FilingChecker interface {
	PlayRoutableInCN(playID string) bool
}

// Catalog resolves the play list with region whitelist and config-svc gray rollout.
type Catalog struct {
	manifest Manifest
	flags    configclient.Client
	filings  FilingChecker
}

// NewCatalog builds a catalog from manifest and a config-svc client (stub or HTTP).
func NewCatalog(m Manifest, flags configclient.Client) *Catalog {
	return NewCatalogWithFilings(m, flags, nil)
}

// NewCatalogWithFilings adds CN algorithm filing gating for play list filtering.
func NewCatalogWithFilings(m Manifest, flags configclient.Client, filings FilingChecker) *Catalog {
	if flags == nil {
		flags = configclient.NewStub(nil)
	}
	return &Catalog{manifest: m, flags: flags, filings: filings}
}

// List returns plays available for the given region after gray filtering.
func (c *Catalog) List(ctx context.Context, opts ListOptions) (CatalogResponse, error) {
	region := strings.ToLower(strings.TrimSpace(opts.Region))
	if region == "" {
		region = "cn"
	}

	features, err := c.flags.Features(ctx, configclient.Request{
		Region:     region,
		AppVersion: opts.AppVersion,
		UserID:     opts.UserID,
	})
	if err != nil {
		return CatalogResponse{}, err
	}

	out := make([]PlayItem, 0, len(c.manifest.Plays))
	for _, play := range c.manifest.Plays {
		if !play.Enabled {
			continue
		}
		if !regionAllowed(play.Regions, region) {
			continue
		}
		if play.FeatureFlagKey != "" {
			result, ok := features[play.FeatureFlagKey]
			if ok && !result.Enabled {
				continue
			}
		}
		if region == "cn" && c.filings != nil && !c.filings.PlayRoutableInCN(play.ID) {
			continue
		}

		item := PlayItem{
			ID:          play.ID,
			Name:        play.Name,
			Description: play.Description,
			Kind:        play.Kind,
			CreditCost:  play.CreditCost,
			Available:   true,
		}
		if len(play.DurationTiers) > 0 {
			item.DurationTiers = append([]DurationTier(nil), play.DurationTiers...)
		}
		out = append(out, item)
	}

	return CatalogResponse{
		Version:    c.manifest.Version,
		Region:     region,
		TTLSeconds: c.manifest.TTLSeconds,
		Plays:      out,
	}, nil
}

func regionAllowed(regions []string, region string) bool {
	if len(regions) == 0 {
		return true
	}
	for _, r := range regions {
		if strings.ToLower(strings.TrimSpace(r)) == region {
			return true
		}
	}
	return false
}
