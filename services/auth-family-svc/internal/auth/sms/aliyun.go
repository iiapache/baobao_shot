package sms

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	openapi "github.com/alibabacloud-go/darabonba-openapi/v2/client"
	dysmsapi "github.com/alibabacloud-go/dysmsapi-20170525/v4/client"
	"github.com/alibabacloud-go/tea/tea"

	"github.com/baobao/auth-family-svc/internal/config"
)

type dysmsAPI interface {
	SendSms(request *dysmsapi.SendSmsRequest) (*dysmsapi.SendSmsResponse, error)
}

// AliyunSender delivers verification codes via Aliyun SMS (dysmsapi).
// Whitelisted test phones skip the vendor call; codes still persist for login.
type AliyunSender struct {
	client    dysmsAPI
	signName  string
	template  string
	whitelist map[string]string
}

func newAliyunSender(cfg *config.Config, whitelist map[string]string) (*AliyunSender, error) {
	if strings.TrimSpace(cfg.AliyunSMSAccessKeyID) == "" ||
		strings.TrimSpace(cfg.AliyunSMSAccessKeySecret) == "" ||
		strings.TrimSpace(cfg.AliyunSMSSignName) == "" ||
		strings.TrimSpace(cfg.AliyunSMSTemplateCodeLogin) == "" {
		return nil, fmt.Errorf("aliyun SMS: ALIYUN_SMS_ACCESS_KEY_ID, ALIYUN_SMS_ACCESS_KEY_SECRET, ALIYUN_SMS_SIGN_NAME, ALIYUN_SMS_TEMPLATE_CODE_LOGIN are required when SMS_PROVIDER=aliyun")
	}

	region := strings.TrimSpace(cfg.AliyunSMSRegion)
	if region == "" {
		region = "cn-hangzhou"
	}

	client, err := dysmsapi.NewClient(&openapi.Config{
		AccessKeyId:     tea.String(cfg.AliyunSMSAccessKeyID),
		AccessKeySecret: tea.String(cfg.AliyunSMSAccessKeySecret),
		RegionId:        tea.String(region),
		Endpoint:        tea.String("dysmsapi.aliyuncs.com"),
	})
	if err != nil {
		return nil, fmt.Errorf("aliyun SMS client: %w", err)
	}

	return &AliyunSender{
		client:    client,
		signName:  cfg.AliyunSMSSignName,
		template:  cfg.AliyunSMSTemplateCodeLogin,
		whitelist: cloneWhitelist(whitelist),
	}, nil
}

// Send dispatches SMS or skips vendor call for whitelisted QA numbers.
func (s *AliyunSender) Send(ctx context.Context, phone, code string) error {
	if s == nil {
		return fmt.Errorf("aliyun SMS sender is nil")
	}
	if _, ok := s.whitelist[phone]; ok {
		slog.InfoContext(ctx, "aliyun sms skipped for test phone", "phone", maskPhone(phone))
		return nil
	}

	templateParam, err := json.Marshal(map[string]string{"code": code})
	if err != nil {
		return fmt.Errorf("aliyun SMS template param: %w", err)
	}

	resp, err := s.client.SendSms(&dysmsapi.SendSmsRequest{
		PhoneNumbers:  tea.String(phone),
		SignName:        tea.String(s.signName),
		TemplateCode:    tea.String(s.template),
		TemplateParam:   tea.String(string(templateParam)),
	})
	if err != nil {
		return fmt.Errorf("aliyun SendSms: %w", err)
	}
	if resp == nil || resp.Body == nil {
		return fmt.Errorf("aliyun SendSms: empty response")
	}
	if codeVal := tea.StringValue(resp.Body.Code); codeVal != "OK" {
		return fmt.Errorf("aliyun SendSms: code=%s message=%s", codeVal, tea.StringValue(resp.Body.Message))
	}
	slog.InfoContext(ctx, "aliyun sms sent", "phone", maskPhone(phone), "bizId", tea.StringValue(resp.Body.BizId))
	return nil
}

func cloneWhitelist(in map[string]string) map[string]string {
	if len(in) == 0 {
		return map[string]string{}
	}
	out := make(map[string]string, len(in))
	for phone, code := range in {
		out[phone] = code
	}
	return out
}

func maskPhone(phone string) string {
	if len(phone) < 7 {
		return phone
	}
	return phone[:3] + "****" + phone[len(phone)-4:]
}
