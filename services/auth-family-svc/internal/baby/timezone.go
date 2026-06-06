package baby

import (
	"strings"
	"time"
)

// placeTimezones maps common birth place labels to IANA time zones.
var placeTimezones = map[string]string{
	"北京":   "Asia/Shanghai",
	"上海":   "Asia/Shanghai",
	"广州":   "Asia/Shanghai",
	"深圳":   "Asia/Shanghai",
	"成都":   "Asia/Shanghai",
	"杭州":   "Asia/Shanghai",
	"香港":   "Asia/Hong_Kong",
	"台北":   "Asia/Taipei",
	"东京":   "Asia/Tokyo",
	"纽约":   "America/New_York",
	"洛杉矶":  "America/Los_Angeles",
	"伦敦":   "Europe/London",
	"悉尼":   "Australia/Sydney",
}

// ResolveTimezone picks the baby time zone from birth place or device time zone.
// Birth place takes precedence when it maps to a known zone or is a valid IANA name.
func ResolveTimezone(birthPlace *string, deviceTZ string) string {
	if birthPlace != nil {
		place := strings.TrimSpace(*birthPlace)
		if place != "" {
			if tz, ok := placeTimezones[place]; ok {
				return tz
			}
			if isIANATimezone(place) {
				return place
			}
		}
	}
	deviceTZ = strings.TrimSpace(deviceTZ)
	if deviceTZ != "" && isIANATimezone(deviceTZ) {
		return deviceTZ
	}
	return "UTC"
}

func isIANATimezone(name string) bool {
	if name == "" || strings.EqualFold(name, "UTC") {
		return name == "UTC"
	}
	_, err := time.LoadLocation(name)
	return err == nil
}
