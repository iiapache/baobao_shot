package audit

import (
	"context"
	"errors"
	"strings"

	"github.com/baobao/audit-svc/internal/model"
)

var errOSWrongRegion = errors.New("os vendor called with non-os region")

const (
	rekognitionRejectMarker = "audit-reject-rekognition"
	cloudflareRejectMarker  = "audit-reject-cloudflare"
	openaiRejectMarker      = "audit-reject-openai"
)

// OSStubSet groups the three OS moderation stub adapters.
type OSStubSet struct {
	Rekognition *RekognitionAdapter
	Cloudflare  *CloudflareGuardAdapter
	OpenAI      *OpenAIModerationAdapter
}

// DefaultOSStubs returns pass-by-default OS vendor stubs.
func DefaultOSStubs() OSStubSet {
	return OSStubSet{
		Rekognition: NewRekognitionAdapter(false),
		Cloudflare:  NewCloudflareGuardAdapter(false),
		OpenAI:      NewOpenAIModerationAdapter(false),
	}
}

// OSVendorAdapter composes AWS Rekognition, Cloudflare Images Guard, and OpenAI Moderation stubs.
type OSVendorAdapter struct {
	rekognition *RekognitionAdapter
	cloudflare  *CloudflareGuardAdapter
	openai      *OpenAIModerationAdapter
}

// NewOSVendorAdapter wires the three OS stub adapters.
func NewOSVendorAdapter(stubs OSStubSet) *OSVendorAdapter {
	if stubs.Rekognition == nil {
		stubs.Rekognition = NewRekognitionAdapter(false)
	}
	if stubs.Cloudflare == nil {
		stubs.Cloudflare = NewCloudflareGuardAdapter(false)
	}
	if stubs.OpenAI == nil {
		stubs.OpenAI = NewOpenAIModerationAdapter(false)
	}
	return &OSVendorAdapter{
		rekognition: stubs.Rekognition,
		cloudflare:  stubs.Cloudflare,
		openai:      stubs.OpenAI,
	}
}

// Audit routes OS requests to the appropriate stub adapter(s).
func (a *OSVendorAdapter) Audit(ctx context.Context, req VendorRequest) (bool, []string, error) {
	if normalizeRegion(req.Region) != RegionOS {
		return false, nil, errOSWrongRegion
	}

	switch inferOSMediaType(req) {
	case "text":
		return a.openai.Audit(ctx, req)
	case "video":
		return a.rekognition.Audit(ctx, req)
	case "image":
		passed, reasons, err := a.rekognition.Audit(ctx, req)
		if err != nil {
			return false, nil, err
		}
		if !passed {
			return false, reasons, nil
		}
		return a.cloudflare.Audit(ctx, req)
	default:
		if strings.TrimSpace(req.Text) != "" {
			return a.openai.Audit(ctx, req)
		}
		if req.ObjectKey != "" {
			req.MediaType = "image"
			return a.Audit(ctx, req)
		}
		return true, nil, nil
	}
}

// RekognitionAdapter stubs AWS Rekognition / Rekognition Video moderation (T3.5).
type RekognitionAdapter struct {
	mockReject bool
}

// NewRekognitionAdapter creates a Rekognition stub adapter.
func NewRekognitionAdapter(mockReject bool) *RekognitionAdapter {
	return &RekognitionAdapter{mockReject: mockReject}
}

// Audit moderates image/video content for the OS region.
func (a *RekognitionAdapter) Audit(_ context.Context, req VendorRequest) (bool, []string, error) {
	if normalizeRegion(req.Region) != RegionOS {
		return false, nil, errOSWrongRegion
	}
	if a.mockReject || containsOSRejectMarker(req, rekognitionRejectMarker) {
		return false, []string{"aws_rekognition:moderation_failed"}, nil
	}
	return true, nil, nil
}

// CloudflareGuardAdapter stubs Cloudflare Images Guard moderation (T3.5).
type CloudflareGuardAdapter struct {
	mockReject bool
}

// NewCloudflareGuardAdapter creates a Cloudflare Images Guard stub adapter.
func NewCloudflareGuardAdapter(mockReject bool) *CloudflareGuardAdapter {
	return &CloudflareGuardAdapter{mockReject: mockReject}
}

// Audit moderates image content for the OS region.
func (a *CloudflareGuardAdapter) Audit(_ context.Context, req VendorRequest) (bool, []string, error) {
	if normalizeRegion(req.Region) != RegionOS {
		return false, nil, errOSWrongRegion
	}
	if a.mockReject || containsOSRejectMarker(req, cloudflareRejectMarker) {
		return false, []string{"cloudflare_guard:unsafe_content"}, nil
	}
	return true, nil, nil
}

// OpenAIModerationAdapter stubs OpenAI Moderation API (T3.5).
type OpenAIModerationAdapter struct {
	mockReject bool
}

// NewOpenAIModerationAdapter creates an OpenAI Moderation stub adapter.
func NewOpenAIModerationAdapter(mockReject bool) *OpenAIModerationAdapter {
	return &OpenAIModerationAdapter{mockReject: mockReject}
}

// Audit moderates text content for the OS region.
func (a *OpenAIModerationAdapter) Audit(_ context.Context, req VendorRequest) (bool, []string, error) {
	if normalizeRegion(req.Region) != RegionOS {
		return false, nil, errOSWrongRegion
	}
	if a.mockReject || containsOSRejectMarker(req, openaiRejectMarker) {
		return false, []string{"openai_moderation:flagged"}, nil
	}
	return true, nil, nil
}

func containsOSRejectMarker(req VendorRequest, marker string) bool {
	marker = strings.ToLower(marker)
	return strings.Contains(strings.ToLower(req.Text), marker) ||
		strings.Contains(strings.ToLower(req.ObjectKey), marker) ||
		strings.Contains(strings.ToLower(req.TargetRef), marker)
}

func inferOSMediaType(req VendorRequest) string {
	mediaType := strings.ToLower(strings.TrimSpace(req.MediaType))
	if mediaType != "" {
		return mediaType
	}
	if req.ObjectKey != "" {
		key := strings.ToLower(req.ObjectKey)
		if strings.HasSuffix(key, ".mp4") || strings.HasSuffix(key, ".mov") || strings.HasSuffix(key, ".webm") {
			return "video"
		}
		return "image"
	}
	if strings.TrimSpace(req.Text) != "" {
		return "text"
	}
	if req.Kind == model.AuditKindInput || req.Kind == model.AuditKindOutput {
		return "image"
	}
	return ""
}
