package aliyun

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"
)

const vendorName = "aliyun-green"

// Request is the normalized vendor audit payload.
type Request struct {
	Kind      string
	TargetRef string
	Region    string
	MediaType string
	ObjectKey string
	Text      string
}

// Config holds Aliyun Content Security (Green) adapter settings.
type Config struct {
	MockMode        bool
	AccessKeyID     string
	AccessKeySecret string
	Region          string
	ImageScenes     string
	TextScenes      string
	MockDelay       time.Duration
}

// ContentSecurityAdapter audits image/text/video content via Aliyun Green CSP.
type ContentSecurityAdapter struct {
	cfg    Config
	client Client
}

// NewContentSecurityAdapter creates the CN vendor adapter.
func NewContentSecurityAdapter(cfg Config) *ContentSecurityAdapter {
	if cfg.Region == "" {
		cfg.Region = "cn-shanghai"
	}
	if cfg.ImageScenes == "" {
		cfg.ImageScenes = "porn,terrorism,ad,qrcode,live"
	}
	if cfg.TextScenes == "" {
		cfg.TextScenes = "antispam"
	}
	client := cfg.client()
	return &ContentSecurityAdapter{cfg: cfg, client: client}
}

func (c Config) client() Client {
	if c.MockMode {
		return nil
	}
	return &HTTPClient{
		AccessKeyID:     c.AccessKeyID,
		AccessKeySecret: c.AccessKeySecret,
		Region:          c.Region,
		ImageScenes:     c.ImageScenes,
		TextScenes:      c.TextScenes,
	}
}

// Name returns the persisted vendor identifier.
func (a *ContentSecurityAdapter) Name() string {
	return vendorName
}

// Audit routes the request to image/text/video handlers with context deadline support.
func (a *ContentSecurityAdapter) Audit(ctx context.Context, req Request) (bool, []string, error) {
	if err := ctx.Err(); err != nil {
		return false, nil, err
	}
	if strings.ToLower(req.Region) != "cn" {
		return true, nil, nil
	}

	if a.cfg.MockMode {
		return a.mockAudit(ctx, req)
	}
	if a.client == nil {
		return false, nil, errors.New("aliyun green client not configured")
	}

	switch normalizeMediaType(req) {
	case "text":
		return a.client.AuditText(ctx, req.Text, a.cfg.TextScenes)
	case "image":
		return a.client.AuditImage(ctx, req.ObjectKey, a.cfg.ImageScenes)
	case "video":
		return a.client.AuditVideo(ctx, req.ObjectKey, a.cfg.ImageScenes)
	default:
		if strings.TrimSpace(req.Text) != "" {
			return a.client.AuditText(ctx, req.Text, a.cfg.TextScenes)
		}
		if strings.TrimSpace(req.ObjectKey) != "" {
			return a.client.AuditImage(ctx, req.ObjectKey, a.cfg.ImageScenes)
		}
		return true, nil, nil
	}
}

func (a *ContentSecurityAdapter) mockAudit(ctx context.Context, req Request) (bool, []string, error) {
	if a.cfg.MockDelay > 0 {
		timer := time.NewTimer(a.cfg.MockDelay)
		defer timer.Stop()
		select {
		case <-ctx.Done():
			return false, nil, ctx.Err()
		case <-timer.C:
		}
	}

	mediaType := normalizeMediaType(req)
	if reasons := mockRejectReasons(req, mediaType); len(reasons) > 0 {
		return false, reasons, nil
	}
	return true, nil, nil
}

func normalizeMediaType(req Request) string {
	mediaType := strings.ToLower(strings.TrimSpace(req.MediaType))
	if mediaType != "" {
		return mediaType
	}
	if strings.TrimSpace(req.Text) != "" {
		return "text"
	}
	if strings.TrimSpace(req.ObjectKey) != "" {
		return "image"
	}
	return ""
}

func mockRejectReasons(req Request, mediaType string) []string {
	markers := []string{
		strings.ToLower(req.Text),
		strings.ToLower(req.ObjectKey),
		strings.ToLower(req.TargetRef),
	}
	for _, marker := range markers {
		if marker == "" {
			continue
		}
		if strings.Contains(marker, "reject_porn") || strings.Contains(marker, "违规色情") {
			return []string{"porn"}
		}
		if strings.Contains(marker, "reject_terror") || strings.Contains(marker, "违规暴恐") {
			return []string{"terrorism"}
		}
		if strings.Contains(marker, "reject_spam") || strings.Contains(marker, "违规文字") {
			return []string{"antispam"}
		}
		if strings.Contains(marker, "reject") {
			switch mediaType {
			case "text":
				return []string{"antispam", "abuse"}
			case "video":
				return []string{"porn", "terrorism"}
			default:
				return []string{"porn"}
			}
		}
	}
	return nil
}

// VendorName is the pipeline vendor label for Aliyun Green.
const VendorName = vendorName

// KindLabel maps audit kind to a short log label.
func KindLabel(kind string) string {
	switch kind {
	case "input":
		return "input"
	case "output":
		return "output"
	case "ugc":
		return "ugc"
	default:
		return fmt.Sprintf("unknown(%s)", kind)
	}
}
