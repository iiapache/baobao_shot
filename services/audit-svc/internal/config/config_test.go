package config

import (
	"testing"
)

func TestLoadDefaults(t *testing.T) {
	t.Setenv("HTTP_PORT", "")
	t.Setenv("GRPC_PORT", "")
	t.Setenv("STORAGE_BACKEND", "")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.HTTPPort != DefaultHTTPPort {
		t.Fatalf("HTTPPort = %d, want %d", cfg.HTTPPort, DefaultHTTPPort)
	}
	if cfg.GRPCPort != DefaultGRPCPort {
		t.Fatalf("GRPCPort = %d, want %d", cfg.GRPCPort, DefaultGRPCPort)
	}
	if cfg.ServiceName != "audit-svc" {
		t.Fatalf("ServiceName = %q, want audit-svc", cfg.ServiceName)
	}
	if cfg.KafkaTopic != "feed.events" {
		t.Fatalf("KafkaTopic = %q, want feed.events", cfg.KafkaTopic)
	}
	if cfg.KafkaEnabled() {
		t.Fatal("Kafka should be disabled by default")
	}
	if cfg.DeployRegion != "cn" {
		t.Fatalf("DeployRegion = %q, want cn", cfg.DeployRegion)
	}
}

func TestLoadDeployRegionOS(t *testing.T) {
	t.Setenv("DEPLOY_REGION", "os")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.DeployRegion != "os" {
		t.Fatalf("DeployRegion = %q, want os", cfg.DeployRegion)
	}
}

func TestLoadInvalidDeployRegion(t *testing.T) {
	t.Setenv("DEPLOY_REGION", "eu")
	if _, err := Load(); err == nil {
		t.Fatal("expected error for unsupported deploy region")
	}
}

func TestLoadInvalidBackend(t *testing.T) {
	t.Setenv("STORAGE_BACKEND", "redis")
	if _, err := Load(); err == nil {
		t.Fatal("expected error for unsupported backend")
	}
}

func TestKafkaEnabled(t *testing.T) {
	t.Setenv("KAFKA_BROKERS", "localhost:9092")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if !cfg.KafkaEnabled() {
		t.Fatal("expected kafka enabled")
	}
}

func TestAliyunGreenDefaults(t *testing.T) {
	t.Setenv("ALIYUN_GREEN_ACCESS_KEY_ID", "")
	t.Setenv("ALIYUN_GREEN_MOCK_MODE", "")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if !cfg.AliyunGreenMockMode {
		t.Fatal("expected mock mode by default without credentials")
	}
	if !cfg.AliyunGreenEnabled() {
		t.Fatal("expected aliyun green enabled in mock mode")
	}
	if cfg.AliyunGreenRegion != "cn-shanghai" {
		t.Fatalf("region = %q, want cn-shanghai", cfg.AliyunGreenRegion)
	}
}

func TestAliyunGreenLiveModeWithEndpoint(t *testing.T) {
	t.Setenv("ALIYUN_GREEN_ACCESS_KEY_ID", "")
	t.Setenv("ALIYUN_GREEN_ACCESS_KEY_SECRET", "")
	t.Setenv("ALIYUN_GREEN_MOCK_MODE", "false")
	t.Setenv("ALIYUN_GREEN_ENDPOINT", "http://mock-audit.example:8080")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.AliyunGreenMockMode {
		t.Fatal("expected live mode with endpoint")
	}
	if cfg.AliyunGreenEndpoint != "http://mock-audit.example:8080" {
		t.Fatalf("endpoint = %q", cfg.AliyunGreenEndpoint)
	}
}

func TestAliyunGreenLiveModeRequiresCredentialsOrEndpoint(t *testing.T) {
	t.Setenv("ALIYUN_GREEN_ACCESS_KEY_ID", "")
	t.Setenv("ALIYUN_GREEN_ACCESS_KEY_SECRET", "")
	t.Setenv("ALIYUN_GREEN_MOCK_MODE", "false")
	t.Setenv("ALIYUN_GREEN_ENDPOINT", "")
	if _, err := Load(); err == nil {
		t.Fatal("expected error when live mode without credentials or endpoint")
	}
}

func TestAliyunGreenLiveMode(t *testing.T) {
	t.Setenv("ALIYUN_GREEN_ENDPOINT", "")
	t.Setenv("ALIYUN_GREEN_ACCESS_KEY_ID", "ak_test")
	t.Setenv("ALIYUN_GREEN_ACCESS_KEY_SECRET", "sk_test")
	t.Setenv("ALIYUN_GREEN_MOCK_MODE", "false")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg.AliyunGreenMockMode {
		t.Fatal("expected live mode when mock disabled with credentials")
	}
	if !cfg.AliyunGreenEnabled() {
		t.Fatal("expected aliyun green enabled with credentials")
	}
}
