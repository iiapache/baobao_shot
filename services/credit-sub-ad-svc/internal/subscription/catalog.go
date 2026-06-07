package subscription

import (
	"strings"
	"time"
)

// Product describes a subscription SKU.
type Product struct {
	SKU      string
	Duration time.Duration
}

// ProductCatalog maps IAP product identifiers to subscription metadata.
type ProductCatalog map[string]Product

// DefaultProductCatalog follows PRD §4.11.4 subscription tiers.
var DefaultProductCatalog = ProductCatalog{
	"com.baobao.sub.monthly":    {SKU: "com.baobao.sub.monthly", Duration: 30 * 24 * time.Hour},
	"com.baobao.sub.quarterly":  {SKU: "com.baobao.sub.quarterly", Duration: 90 * 24 * time.Hour},
	"com.baobao.sub.yearly":     {SKU: "com.baobao.sub.yearly", Duration: 365 * 24 * time.Hour},
	"com.baobao.sub.lifetime":   {SKU: "com.baobao.sub.lifetime", Duration: 100 * 365 * 24 * time.Hour},
	"sub_monthly":               {SKU: "sub_monthly", Duration: 30 * 24 * time.Hour},
}

// ProductForID returns subscription metadata for a product id.
func (c ProductCatalog) ProductForID(productID string) (Product, bool) {
	if c == nil {
		return Product{}, false
	}
	productID = strings.TrimSpace(productID)
	if productID == "" {
		return Product{}, false
	}
	product, ok := c[productID]
	return product, ok
}
