package iap

import "strings"

// ProductCatalog maps IAP product identifiers to granted credits.
type ProductCatalog map[string]int64

// DefaultProductCatalog follows PRD §4.11.2 recharge tiers.
var DefaultProductCatalog = ProductCatalog{
	"credit_pack_60":    60,
	"credit_pack_330":   330,
	"credit_pack_800":   800,
	"credit_pack_2500":  2500,
	"com.baobao.credits.60":   60,
	"com.baobao.credits.100":  100,
	"com.baobao.credits.330":  330,
	"com.baobao.credits.800":  800,
	"com.baobao.credits.2500": 2500,
}

// CreditsForProduct returns granted credits for a product id.
func (c ProductCatalog) CreditsForProduct(productID string) (int64, bool) {
	if c == nil {
		return 0, false
	}
	productID = strings.TrimSpace(productID)
	if productID == "" {
		return 0, false
	}
	credits, ok := c[productID]
	return credits, ok
}
