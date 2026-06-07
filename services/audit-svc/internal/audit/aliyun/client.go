package aliyun

import (
	"context"
	"errors"
)

// Client performs Aliyun Green content moderation RPCs.
type Client interface {
	AuditText(ctx context.Context, text, scenes string) (bool, []string, error)
	AuditImage(ctx context.Context, objectKey, scenes string) (bool, []string, error)
	AuditVideo(ctx context.Context, objectKey, scenes string) (bool, []string, error)
}

// HTTPClient is a stub for live Aliyun Green API integration (T3.4 skeleton).
type HTTPClient struct {
	AccessKeyID     string
	AccessKeySecret string
	Region          string
	ImageScenes     string
	TextScenes      string
}

var errLiveClientStub = errors.New("aliyun green live client not implemented")

// AuditText calls Aliyun text antispam API (stub).
func (c *HTTPClient) AuditText(ctx context.Context, text, scenes string) (bool, []string, error) {
	_ = ctx
	_ = text
	_ = scenes
	return false, nil, errLiveClientStub
}

// AuditImage calls Aliyun image sync scan API (stub).
func (c *HTTPClient) AuditImage(ctx context.Context, objectKey, scenes string) (bool, []string, error) {
	_ = ctx
	_ = objectKey
	_ = scenes
	return false, nil, errLiveClientStub
}

// AuditVideo calls Aliyun video frame sampling API (stub).
func (c *HTTPClient) AuditVideo(ctx context.Context, objectKey, scenes string) (bool, []string, error) {
	_ = ctx
	_ = objectKey
	_ = scenes
	return false, nil, errLiveClientStub
}
