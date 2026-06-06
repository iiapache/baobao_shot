package middleware

import (
	"context"
	"log/slog"
	"net/http"

	"github.com/baobao/auth-family-svc/internal/config"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

// InitTracing configures OpenTelemetry. No-op when OTEL endpoint is empty.
func InitTracing(ctx context.Context, cfg *config.Config) (func(context.Context) error, error) {
	if cfg.OTelEndpoint == "" {
		slog.Info("tracing disabled", "reason", "OTEL_EXPORTER_OTLP_ENDPOINT not set")
		return func(context.Context) error { return nil }, nil
	}

	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(cfg.OTelEndpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		return nil, err
	}

	res, err := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceName(cfg.ServiceName),
			semconv.DeploymentEnvironment(cfg.Environment),
		),
	)
	if err != nil {
		return nil, err
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	slog.Info("tracing enabled", "endpoint", cfg.OTelEndpoint)
	return tp.Shutdown, nil
}

// Tracing wraps handlers with OpenTelemetry HTTP instrumentation.
func Tracing(next http.Handler) http.Handler {
	return otelhttp.NewHandler(next, "http")
}
