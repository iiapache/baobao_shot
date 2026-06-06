package feature

import "strings"

// EvalContext carries request dimensions for feature evaluation.
type EvalContext struct {
	Region     string
	AppVersion string
	UserID     string
	UserIDHash int
}

// Definition is a raw feature flag rule from the config store.
type Definition struct {
	Key            string
	DefaultEnabled bool
	Regions        []string // empty = all regions
	RolloutPercent int      // 0-100; 100 = all users in matching region
	Variant        string
	MinAppVersion  string // optional; empty = no constraint
}

// Result is the evaluated flag for a single client.
type Result struct {
	Enabled bool   `json:"enabled"`
	Variant string `json:"variant,omitempty"`
}

// Evaluate resolves whether a feature is enabled for the given context.
func Evaluate(def Definition, ctx EvalContext) Result {
	if !regionAllowed(def.Regions, ctx.Region) {
		return Result{Enabled: false}
	}
	if def.MinAppVersion != "" && compareVersions(ctx.AppVersion, def.MinAppVersion) < 0 {
		return Result{Enabled: false}
	}

	hash := ctx.UserIDHash
	if ctx.UserID != "" {
		hash = UserIDHash(ctx.UserID)
	}

	enabled := def.DefaultEnabled
	if def.RolloutPercent < 100 {
		enabled = hash < def.RolloutPercent
	}

	return Result{
		Enabled: enabled,
		Variant: def.Variant,
	}
}

func regionAllowed(regions []string, region string) bool {
	if len(regions) == 0 {
		return true
	}
	region = strings.ToLower(strings.TrimSpace(region))
	for _, r := range regions {
		if strings.ToLower(strings.TrimSpace(r)) == region {
			return true
		}
	}
	return false
}

// compareVersions returns -1 if a < b, 0 if equal, 1 if a > b (semver-lite).
func compareVersions(a, b string) int {
	pa := strings.Split(a, ".")
	pb := strings.Split(b, ".")
	for i := 0; i < len(pa) || i < len(pb); i++ {
		var va, vb int
		if i < len(pa) {
			fmtAtoi(&va, pa[i])
		}
		if i < len(pb) {
			fmtAtoi(&vb, pb[i])
		}
		if va < vb {
			return -1
		}
		if va > vb {
			return 1
		}
	}
	return 0
}

func fmtAtoi(dst *int, s string) {
	n := 0
	for _, c := range s {
		if c < '0' || c > '9' {
			break
		}
		n = n*10 + int(c-'0')
	}
	*dst = n
}
