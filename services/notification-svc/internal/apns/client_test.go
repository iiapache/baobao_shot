package apns

import (
	"context"
	"testing"
)

func TestClientDualRegionPools(t *testing.T) {
	client, err := NewClient(Config{Sandbox: true})
	if err != nil {
		t.Fatal(err)
	}

	regions := client.Regions()
	if len(regions) != 2 {
		t.Fatalf("regions = %v", regions)
	}

	cnHost, err := client.PoolHost(RegionCN)
	if err != nil {
		t.Fatal(err)
	}
	if cnHost != HostSandbox {
		t.Fatalf("cn host = %q", cnHost)
	}

	osHost, err := client.PoolHost(RegionOS)
	if err != nil {
		t.Fatal(err)
	}
	if osHost != HostSandbox {
		t.Fatalf("os host = %q", osHost)
	}
}

func TestClientSendSuccess(t *testing.T) {
	mock := NewMockSender()
	client, err := NewClient(Config{Sender: mock})
	if err != nil {
		t.Fatal(err)
	}

	token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
	result, err := client.Send(context.Background(), RegionCN, PushPayload{
		DeviceToken: token,
		Title:       "hello",
		Body:        "world",
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.APNSID == "" {
		t.Fatal("expected apns id")
	}
	if mock.SendCount() != 1 {
		t.Fatalf("send count = %d", mock.SendCount())
	}
}

type stubCleaner struct {
	called bool
	token  string
}

func (s *stubCleaner) CleanupInvalidToken(_ context.Context, apnsToken string) (int64, error) {
	s.called = true
	s.token = apnsToken
	return 1, nil
}

func TestClientSendInvalidTokenTriggersCleanup(t *testing.T) {
	cleaner := &stubCleaner{}
	client, err := NewClient(Config{Cleaner: cleaner})
	if err != nil {
		t.Fatal(err)
	}

	token := invalidTokenPrefix + "0123456789abcdef0123456789abcdef"
	_, err = client.Send(context.Background(), RegionOS, PushPayload{DeviceToken: token})
	if err != ErrTokenInvalid {
		t.Fatalf("err = %v, want ErrTokenInvalid", err)
	}
	if !cleaner.called || cleaner.token != token {
		t.Fatalf("cleanup not invoked: %+v", cleaner)
	}
}

func TestClientUnsupportedRegion(t *testing.T) {
	client, err := NewClient(Config{})
	if err != nil {
		t.Fatal(err)
	}
	_, err = client.Send(context.Background(), Region("xx"), PushPayload{DeviceToken: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"})
	if err != ErrUnsupportedRegion {
		t.Fatalf("err = %v", err)
	}
}
