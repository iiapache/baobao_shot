package sms

import (
	"context"
	"testing"

	dysmsapi "github.com/alibabacloud-go/dysmsapi-20170525/v4/client"
	"github.com/alibabacloud-go/tea/tea"

	"github.com/baobao/auth-family-svc/internal/config"
)

type stubDysms struct {
	lastPhone   string
	lastCode    string
	lastSign    string
	lastTpl     string
	lastTplParam string
	calls       int
}

func (s *stubDysms) SendSms(req *dysmsapi.SendSmsRequest) (*dysmsapi.SendSmsResponse, error) {
	s.calls++
	s.lastPhone = tea.StringValue(req.PhoneNumbers)
	s.lastSign = tea.StringValue(req.SignName)
	s.lastTpl = tea.StringValue(req.TemplateCode)
	s.lastTplParam = tea.StringValue(req.TemplateParam)
	return &dysmsapi.SendSmsResponse{
		Body: &dysmsapi.SendSmsResponseBody{
			Code:    tea.String("OK"),
			Message: tea.String("OK"),
			BizId:   tea.String("biz-1"),
		},
	}, nil
}

func TestAliyunSenderSkipsWhitelist(t *testing.T) {
	stub := &stubDysms{}
	sender := &AliyunSender{
		client:    stub,
		signName:  "抱抱相机",
		template:  "SMS_001",
		whitelist: map[string]string{"13800138001": "123456"},
	}

	if err := sender.Send(context.Background(), "13800138001", "123456"); err != nil {
		t.Fatal(err)
	}
	if stub.calls != 0 {
		t.Fatalf("whitelist send calls = %d, want 0", stub.calls)
	}
}

func TestAliyunSenderDispatchesRealPhone(t *testing.T) {
	stub := &stubDysms{}
	sender := &AliyunSender{
		client:    stub,
		signName:  "抱抱相机",
		template:  "SMS_001",
		whitelist: map[string]string{"13800138001": "123456"},
	}

	if err := sender.Send(context.Background(), "13900001111", "654321"); err != nil {
		t.Fatal(err)
	}
	if stub.calls != 1 {
		t.Fatalf("calls = %d, want 1", stub.calls)
	}
	if stub.lastPhone != "13900001111" {
		t.Fatalf("phone = %q", stub.lastPhone)
	}
	if stub.lastTplParam != `{"code":"654321"}` {
		t.Fatalf("template param = %q", stub.lastTplParam)
	}
}

func TestNewSenderMockDefault(t *testing.T) {
	sender, err := NewSender(&config.Config{SMSProvider: "mock"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := sender.(interface{ Send(context.Context, string, string) error }); !ok {
		t.Fatal("expected SMSSender")
	}
}

func TestNewAliyunSenderRequiresCredentials(t *testing.T) {
	_, err := newAliyunSender(&config.Config{SMSProvider: "aliyun"}, nil)
	if err == nil {
		t.Fatal("expected missing credential error")
	}
}

func TestNewSenderUnsupportedProvider(t *testing.T) {
	_, err := NewSender(&config.Config{SMSProvider: "twilio"}, nil)
	if err == nil {
		t.Fatal("expected unsupported provider error")
	}
}
