package adapter

import (
	"context"

	"github.com/baobao/ai-dispatch-svc/internal/model"
)

// StubAdapter is a test/double implementation of ModelAdapter.
type StubAdapter struct {
	AdapterName string
	AdapterRegion model.Region
	Capabilities  []model.Capability
	UnitCost      int
	InvokeFn      func(ctx context.Context, req InvokeRequest) (InvokeOutput, error)
}

func (s *StubAdapter) Name() string { return s.AdapterName }

func (s *StubAdapter) Region() model.Region { return s.AdapterRegion }

func (s *StubAdapter) Supports(capability model.Capability) bool {
	for _, c := range s.Capabilities {
		if c == capability {
			return true
		}
	}
	return false
}

func (s *StubAdapter) Cost(_ InvokeRequest) int {
	if s.UnitCost > 0 {
		return s.UnitCost
	}
	return 1
}

func (s *StubAdapter) Invoke(ctx context.Context, req InvokeRequest) (InvokeOutput, error) {
	if s.InvokeFn != nil {
		return s.InvokeFn(ctx, req)
	}
	return InvokeOutput{ObjectKey: "stub/" + req.Input.ObjectKey}, nil
}
