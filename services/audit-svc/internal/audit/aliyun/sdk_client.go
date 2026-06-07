package aliyun

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/aliyun/alibaba-cloud-sdk-go/services/green"
)

// SDKClient wraps the official Aliyun Green SDK for production CSP calls.
type SDKClient struct {
	client          *green.Client
	ObjectURLPrefix string
	ImageScenes     string
	TextScenes      string
}

// NewSDKClient creates a signed Green client for the given region and credentials.
func NewSDKClient(region, accessKeyID, accessKeySecret, objectURLPrefix, imageScenes, textScenes string) (*SDKClient, error) {
	if strings.TrimSpace(region) == "" {
		region = "cn-shanghai"
	}
	client, err := green.NewClientWithAccessKey(region, accessKeyID, accessKeySecret)
	if err != nil {
		return nil, fmt.Errorf("green sdk client: %w", err)
	}
	return &SDKClient{
		client:          client,
		ObjectURLPrefix: objectURLPrefix,
		ImageScenes:     imageScenes,
		TextScenes:      textScenes,
	}, nil
}

func (c *SDKClient) AuditText(ctx context.Context, text, scenes string) (bool, []string, error) {
	if err := ctx.Err(); err != nil {
		return false, nil, err
	}
	if scenes == "" {
		scenes = c.TextScenes
	}
	content, err := json.Marshal(map[string]any{
		"scenes": splitScenes(scenes),
		"tasks": []map[string]any{
			{"content": text},
		},
	})
	if err != nil {
		return false, nil, err
	}
	req := green.CreateTextScanRequest()
	req.SetContent(content)
	resp, err := c.client.TextScan(req)
	if err != nil {
		return false, nil, fmt.Errorf("green text scan: %w", err)
	}
	if resp.GetHttpStatus() != 200 {
		return false, nil, fmt.Errorf("green text scan status %d", resp.GetHttpStatus())
	}
	return parseScanResponse([]byte(resp.GetHttpContentString()))
}

func (c *SDKClient) AuditImage(ctx context.Context, objectKey, scenes string) (bool, []string, error) {
	if err := ctx.Err(); err != nil {
		return false, nil, err
	}
	if scenes == "" {
		scenes = c.ImageScenes
	}
	content, err := json.Marshal(map[string]any{
		"scenes": splitScenes(scenes),
		"tasks": []map[string]any{
			{"url": objectURL(c.ObjectURLPrefix, objectKey)},
		},
	})
	if err != nil {
		return false, nil, err
	}
	req := green.CreateImageSyncScanRequest()
	req.SetContent(content)
	resp, err := c.client.ImageSyncScan(req)
	if err != nil {
		return false, nil, fmt.Errorf("green image scan: %w", err)
	}
	if resp.GetHttpStatus() != 200 {
		return false, nil, fmt.Errorf("green image scan status %d", resp.GetHttpStatus())
	}
	return parseScanResponse([]byte(resp.GetHttpContentString()))
}

func (c *SDKClient) AuditVideo(ctx context.Context, objectKey, scenes string) (bool, []string, error) {
	if err := ctx.Err(); err != nil {
		return false, nil, err
	}
	if scenes == "" {
		scenes = c.ImageScenes
	}
	content, err := json.Marshal(map[string]any{
		"scenes": splitScenes(scenes),
		"tasks": []map[string]any{
			{"url": objectURL(c.ObjectURLPrefix, objectKey)},
		},
	})
	if err != nil {
		return false, nil, err
	}
	req := green.CreateVideoSyncScanRequest()
	req.SetContent(content)
	resp, err := c.client.VideoSyncScan(req)
	if err != nil {
		return false, nil, fmt.Errorf("green video scan: %w", err)
	}
	if resp.GetHttpStatus() != 200 {
		return false, nil, fmt.Errorf("green video scan status %d", resp.GetHttpStatus())
	}
	return parseScanResponse([]byte(resp.GetHttpContentString()))
}
