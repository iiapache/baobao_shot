package worker

import (
	"github.com/baobao/ai-dispatch-svc/internal/creditclient"
)

// CreditClient settles credit holds after terminal task outcomes (T3.14 wires gRPC).
type CreditClient = creditclient.Client

// StubCreditClient records credit side effects for tests and local dev.
type StubCreditClient = creditclient.Stub

// NewStubCreditClient creates an in-memory credit client stub.
func NewStubCreditClient() *StubCreditClient {
	return creditclient.NewStub()
}

// SettleRequest re-exports credit settle payload for processor tests.
type SettleRequest = creditclient.SettleRequest

// Ref kinds for saga idempotency.
const (
	RefKindAITaskHold    = creditclient.RefKindAITaskHold
	RefKindAITaskCommit  = creditclient.RefKindAITaskCommit
	RefKindAITaskRelease = creditclient.RefKindAITaskRelease
)

// NormalizeCommit fills default idempotency keys for commit.
func NormalizeCommit(req SettleRequest) SettleRequest {
	return creditclient.NormalizeCommit(req)
}

// NormalizeRelease fills default idempotency keys for release.
func NormalizeRelease(req SettleRequest) SettleRequest {
	return creditclient.NormalizeRelease(req)
}
