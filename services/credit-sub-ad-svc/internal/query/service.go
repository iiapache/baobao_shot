package query

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/baobao/credit-sub-ad-svc/internal/credit"
	"github.com/baobao/credit-sub-ad-svc/internal/model"
	"github.com/baobao/credit-sub-ad-svc/internal/rates"
	"github.com/baobao/credit-sub-ad-svc/internal/store"
	"github.com/baobao/credit-sub-ad-svc/internal/subscription"
)

var (
	// ErrInvalidRequest is returned when required query fields are missing.
	ErrInvalidRequest = errors.New("invalid query request")
	// ErrInvalidCursor is returned when pagination cursor is malformed.
	ErrInvalidCursor = store.ErrInvalidCursor
)

// Service serves read-only credit and subscription queries.
type Service struct {
	ledger   *credit.Service
	signIns  store.SignInStore
	rates    rates.Catalog
	now      func() time.Time
}

// NewService creates a query service.
func NewService(st store.Store, ledger *credit.Service, catalog rates.Catalog) *Service {
	return &Service{
		ledger:  ledger,
		signIns: st,
		rates:   catalog,
		now:     time.Now,
	}
}

// BalanceData is GET /v1/credits/balance payload.
type BalanceData struct {
	Balance          int64 `json:"balance"`
	SignInAvailable  bool  `json:"signInAvailable"`
}

// TransactionItem is one ledger row in GET /v1/credits/transactions.
type TransactionItem struct {
	ID           string `json:"id"`
	Type         string `json:"type"`
	Amount       int64  `json:"amount"`
	RefKind      string `json:"refKind,omitempty"`
	RefID        string `json:"refId,omitempty"`
	BalanceAfter int64  `json:"balanceAfter"`
	CreatedAt    string `json:"createdAt"`
}

// TransactionsData is a paginated ledger page.
type TransactionsData struct {
	Items      []TransactionItem `json:"items"`
	NextCursor *string           `json:"nextCursor,omitempty"`
}

// ListTransactionsInput carries pagination options.
type ListTransactionsInput struct {
	UserID string
	Cursor string
	Limit  int
}

// GetBalance returns the current balance and sign-in availability.
func (s *Service) GetBalance(ctx context.Context, userID string) (BalanceData, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return BalanceData{}, ErrInvalidRequest
	}

	bal, err := s.ledger.GetBalance(ctx, userID)
	if err != nil {
		return BalanceData{}, err
	}

	signInAvailable := true
	if s.signIns != nil {
		signedIn, checkErr := s.signIns.HasSignedIn(ctx, userID, s.now().UTC())
		if checkErr != nil {
			return BalanceData{}, checkErr
		}
		signInAvailable = !signedIn
	}

	return BalanceData{
		Balance:         bal.Balance,
		SignInAvailable: signInAvailable,
	}, nil
}

// ListTransactions returns paginated ledger entries for a user.
func (s *Service) ListTransactions(ctx context.Context, in ListTransactionsInput) (TransactionsData, error) {
	in.UserID = strings.TrimSpace(in.UserID)
	if in.UserID == "" {
		return TransactionsData{}, ErrInvalidRequest
	}

	page, err := s.ledger.ListTransactions(ctx, in.UserID, in.Cursor, in.Limit)
	if err != nil {
		return TransactionsData{}, err
	}

	items := make([]TransactionItem, 0, len(page.Items))
	for _, entry := range page.Items {
		items = append(items, toTransactionItem(entry))
	}

	data := TransactionsData{Items: items}
	if page.NextCursor != "" {
		cursor := page.NextCursor
		data.NextCursor = &cursor
	}
	return data, nil
}

// GetRates returns the published credit pricing catalog.
func (s *Service) GetRates(_ context.Context) rates.Catalog {
	return s.rates
}

// ProductsData is GET /v1/subscriptions/products payload.
type ProductsData struct {
	Region   string                    `json:"region"`
	Products []subscription.ListedProduct `json:"products"`
}

// ListSubscriptionProducts returns SKUs for a region.
func (s *Service) ListSubscriptionProducts(region string) ProductsData {
	region = strings.ToLower(strings.TrimSpace(region))
	if region == "" {
		region = "cn"
	}
	return ProductsData{
		Region:   region,
		Products: subscription.ListProducts(region),
	}
}

func toTransactionItem(entry model.LedgerEntry) TransactionItem {
	amount := entry.Amount
	switch entry.Type {
	case model.EntryCharge, model.EntryConsume:
		amount = -entry.Amount
	case model.EntryAdjust:
		// amount already signed in ledger for adjust entries
	}

	return TransactionItem{
		ID:           entry.ID,
		Type:         string(entry.Type),
		Amount:       amount,
		RefKind:      entry.RefKind,
		RefID:        entry.RefID,
		BalanceAfter: entry.BalanceAfter,
		CreatedAt:    entry.CreatedAt.UTC().Format(time.RFC3339),
	}
}
