package store

import (
	"context"
	"encoding/base64"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

const (
	defaultLedgerPageSize = 20
	maxLedgerPageSize     = 50
)

// ErrInvalidCursor is returned when a pagination cursor cannot be decoded.
var ErrInvalidCursor = fmt.Errorf("invalid pagination cursor")

// ParseLedgerCursor decodes a ledger pagination cursor.
func ParseLedgerCursor(cursor string) (createdAt time.Time, entryID string, err error) {
	cursor = strings.TrimSpace(cursor)
	if cursor == "" {
		return time.Time{}, "", nil
	}
	raw, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, "", ErrInvalidCursor
	}
	parts := strings.SplitN(string(raw), "|", 2)
	if len(parts) != 2 || parts[1] == "" {
		return time.Time{}, "", ErrInvalidCursor
	}
	createdAt, err = time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return time.Time{}, "", ErrInvalidCursor
	}
	return createdAt.UTC(), parts[1], nil
}

// EncodeLedgerCursor builds an opaque cursor from a ledger entry.
func EncodeLedgerCursor(entry model.LedgerEntry) string {
	payload := entry.CreatedAt.UTC().Format(time.RFC3339Nano) + "|" + entry.ID
	return base64.RawURLEncoding.EncodeToString([]byte(payload))
}

// NormalizeLedgerLimit clamps page size to API bounds.
func NormalizeLedgerLimit(limit int) int {
	if limit <= 0 {
		return defaultLedgerPageSize
	}
	if limit > maxLedgerPageSize {
		return maxLedgerPageSize
	}
	return limit
}

func (s *MemoryStore) ListLedgerEntries(_ context.Context, in ListLedgerInput) (ListLedgerResult, error) {
	limit := NormalizeLedgerLimit(in.Limit)
	cursorTime, cursorID, err := ParseLedgerCursor(in.Cursor)
	if err != nil {
		return ListLedgerResult{}, err
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	var entries []*model.LedgerEntry
	for _, entry := range s.ledger {
		if entry.UserID != in.UserID {
			continue
		}
		entries = append(entries, cloneLedgerEntry(entry))
	}

	sort.Slice(entries, func(i, j int) bool {
		if entries[i].CreatedAt.Equal(entries[j].CreatedAt) {
			return entries[i].ID > entries[j].ID
		}
		return entries[i].CreatedAt.After(entries[j].CreatedAt)
	})

	if !cursorTime.IsZero() {
		filtered := entries[:0]
		for _, entry := range entries {
			if entry.CreatedAt.Before(cursorTime) {
				filtered = append(filtered, entry)
				continue
			}
			if entry.CreatedAt.Equal(cursorTime) && entry.ID < cursorID {
				filtered = append(filtered, entry)
			}
		}
		entries = filtered
	}

	result := ListLedgerResult{}
	if len(entries) > limit {
		page := entries[:limit]
		result.Items = cloneLedgerEntries(page)
		result.NextCursor = EncodeLedgerCursor(*entries[limit-1])
		return result, nil
	}

	result.Items = cloneLedgerEntries(entries)
	return result, nil
}

func cloneLedgerEntries(entries []*model.LedgerEntry) []model.LedgerEntry {
	out := make([]model.LedgerEntry, 0, len(entries))
	for _, entry := range entries {
		if entry == nil {
			continue
		}
		out = append(out, *entry)
	}
	return out
}

func (s *MemoryStore) HasSignedIn(_ context.Context, userID string, date time.Time) (bool, error) {
	key := signInKey(userID, date)
	s.mu.RLock()
	defer s.mu.RUnlock()
	_, ok := s.signIns[key]
	return ok, nil
}

func signInKey(userID string, date time.Time) string {
	return userID + "\x00" + date.UTC().Format("2006-01-02")
}
