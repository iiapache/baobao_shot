package subscription

import "strings"

// ListedProduct is a subscription SKU exposed to clients.
type ListedProduct struct {
	ProductID    string   `json:"productId"`
	Name         string   `json:"name"`
	Period       string   `json:"period"`
	PriceCNY     int      `json:"priceCny,omitempty"`
	BonusCredits int      `json:"bonusCredits,omitempty"`
	Regions      []string `json:"regions"`
}

var defaultListedProducts = []ListedProduct{
	{
		ProductID: "com.baobao.sub.monthly",
		Name:      "月会员",
		Period:    "monthly",
		PriceCNY:  18,
		Regions:   []string{"cn", "os"},
	},
	{
		ProductID: "com.baobao.sub.quarterly",
		Name:      "季会员",
		Period:    "quarterly",
		PriceCNY:  45,
		Regions:   []string{"cn", "os"},
	},
	{
		ProductID: "com.baobao.sub.yearly",
		Name:      "年会员",
		Period:    "yearly",
		PriceCNY:  128,
		BonusCredits: 200,
		Regions:   []string{"cn", "os"},
	},
	{
		ProductID: "com.baobao.sub.lifetime",
		Name:      "终身会员",
		Period:    "lifetime",
		PriceCNY:  498,
		BonusCredits: 500,
		Regions:   []string{"cn"},
	},
}

// ListProducts returns subscription SKUs for the given region.
func ListProducts(region string) []ListedProduct {
	region = strings.ToLower(strings.TrimSpace(region))
	if region == "" {
		region = "cn"
	}
	out := make([]ListedProduct, 0, len(defaultListedProducts))
	for _, product := range defaultListedProducts {
		if !containsRegion(product.Regions, region) {
			continue
		}
		item := product
		if region == "os" {
			item.PriceCNY = 0
		}
		out = append(out, item)
	}
	return out
}

func containsRegion(regions []string, region string) bool {
	for _, r := range regions {
		if strings.EqualFold(r, region) {
			return true
		}
	}
	return false
}
