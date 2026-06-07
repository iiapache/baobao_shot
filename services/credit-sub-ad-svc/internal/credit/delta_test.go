package credit

import (
	"errors"
	"testing"
)

func TestBalanceDelta(t *testing.T) {
	cases := []struct {
		typ    EntryType
		amount int64
		want   int64
		err    error
	}{
		{EntryGrant, 10, 10, nil},
		{EntryRefund, 5, 5, nil},
		{EntryCharge, 3, -3, nil},
		{EntryConsume, 8, -8, nil},
		{EntryAdjust, -2, -2, nil},
		{EntryGrant, 0, 0, ErrInvalidAmount},
		{EntryAdjust, 0, 0, ErrInvalidAmount},
		{EntryType("bad"), 1, 0, ErrInvalidRequest},
	}

	for _, tc := range cases {
		got, err := BalanceDelta(tc.typ, tc.amount)
		if !errors.Is(err, tc.err) {
			t.Fatalf("BalanceDelta(%s, %d) err = %v, want %v", tc.typ, tc.amount, err, tc.err)
		}
		if err == nil && got != tc.want {
			t.Fatalf("BalanceDelta(%s, %d) = %d, want %d", tc.typ, tc.amount, got, tc.want)
		}
	}
}
