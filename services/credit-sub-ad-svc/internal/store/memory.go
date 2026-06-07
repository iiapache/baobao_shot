package store

import (
	"context"
	"sync"

	"github.com/baobao/credit-sub-ad-svc/internal/model"
)

// MemoryStore is an in-memory Store for dev and unit tests.
type MemoryStore struct {
	mu                       sync.RWMutex
	balances                 map[string]memoryBalance
	ledger                   map[string]*model.LedgerEntry
	ledgerByRef              map[string]string
	holds                    map[string]*model.Hold
	holdsByTask              map[string]string
	iapReceipts              map[string]*model.IAPReceipt
	iapByTransactionID       map[string]string
	subscriptions            map[string]*model.Subscription
	subByOriginalTx          map[string]string
	subscriptionsByUser      map[string][]string
	signIns                  map[string]model.SignInRecord
	adRewards                map[string]*model.AdReward
	adByNetworkSig           map[string]string
	reconciliationRuns       map[string]*model.ReconciliationRun
}

// NewMemoryStore returns an empty in-memory store.
func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		balances:            make(map[string]memoryBalance),
		ledger:              make(map[string]*model.LedgerEntry),
		ledgerByRef:         make(map[string]string),
		holds:               make(map[string]*model.Hold),
		holdsByTask:         make(map[string]string),
		iapReceipts:         make(map[string]*model.IAPReceipt),
		iapByTransactionID:  make(map[string]string),
		subscriptions:       make(map[string]*model.Subscription),
		subByOriginalTx:     make(map[string]string),
		subscriptionsByUser: make(map[string][]string),
		signIns:             make(map[string]model.SignInRecord),
		adRewards:           make(map[string]*model.AdReward),
		adByNetworkSig:      make(map[string]string),
		reconciliationRuns:  make(map[string]*model.ReconciliationRun),
	}
}

func (s *MemoryStore) Ping(_ context.Context) error { return nil }
