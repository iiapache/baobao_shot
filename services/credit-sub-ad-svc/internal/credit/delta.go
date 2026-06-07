package credit

// BalanceDelta returns the signed balance change for a movement type.
// grant/refund increase balance; charge/consume decrease; adjust uses signed amount.
func BalanceDelta(entryType EntryType, amount int64) (int64, error) {
	switch entryType {
	case EntryGrant, EntryRefund:
		if amount <= 0 {
			return 0, ErrInvalidAmount
		}
		return amount, nil
	case EntryCharge, EntryConsume:
		if amount <= 0 {
			return 0, ErrInvalidAmount
		}
		return -amount, nil
	case EntryAdjust:
		if amount == 0 {
			return 0, ErrInvalidAmount
		}
		return amount, nil
	default:
		return 0, ErrInvalidRequest
	}
}
