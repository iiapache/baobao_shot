package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"github.com/baobao/notification-svc/internal/config"
	"github.com/baobao/notification-svc/internal/model"
	"github.com/baobao/notification-svc/internal/orchestrator"
)

// EventHandler dispatches parsed domain events to push orchestration.
type EventHandler interface {
	Dispatch(ctx context.Context, in orchestrator.DispatchInput) (orchestrator.DispatchResult, error)
}

// Consumer is a Kafka consumer stub for ai.events / feed.events / credit.events (T5.9).
type Consumer struct {
	cfg     *config.Config
	handler EventHandler
}

// NewConsumer creates a consumer bound to the push orchestrator.
func NewConsumer(cfg *config.Config, handler EventHandler) *Consumer {
	return &Consumer{cfg: cfg, handler: handler}
}

// Start blocks until ctx is cancelled. When Kafka is disabled this is a no-op stub.
func (c *Consumer) Start(ctx context.Context) error {
	if c == nil || c.cfg == nil || !c.cfg.KafkaEnabled() {
		slog.Info("kafka consumer disabled", "reason", "KAFKA_BROKERS not set")
		return nil
	}
	slog.Info("kafka consumer stub started",
		"brokers", c.cfg.KafkaBrokers,
		"topics", ConsumerTopics,
		"group", c.cfg.KafkaGroupID,
	)
	<-ctx.Done()
	slog.Info("kafka consumer stopped")
	return nil
}

// HandleMessage processes one Kafka message payload (used by tests and future real consumer).
func (c *Consumer) HandleMessage(ctx context.Context, topic string, payload []byte) error {
	if c == nil || c.handler == nil {
		return fmt.Errorf("consumer not initialized")
	}
	switch strings.TrimSpace(topic) {
	case TopicAIEvents:
		return c.handleAIEvent(ctx, payload)
	case TopicFeedEvents:
		return c.handleFeedEvent(ctx, payload)
	case TopicCreditEvents:
		return c.handleCreditEvent(ctx, payload)
	default:
		return fmt.Errorf("unsupported topic %q", topic)
	}
}

func (c *Consumer) handleAIEvent(ctx context.Context, payload []byte) error {
	var evt AIEvent
	if err := json.Unmarshal(payload, &evt); err != nil {
		return fmt.Errorf("decode ai event: %w", err)
	}
	if strings.TrimSpace(evt.UserID) == "" {
		return fmt.Errorf("userId required")
	}
	if strings.TrimSpace(evt.TaskID) == "" {
		return fmt.Errorf("taskId required")
	}

	body, custom, silent := aiCopy(evt)
	in := orchestrator.DispatchInput{
		UserID:     evt.UserID,
		Category:   model.CategoryAIDone,
		Title:      "AI 任务完成",
		Body:       body,
		Payload:    payload,
		CustomData: custom,
		SilentPush: silent,
	}
	switch evt.EventType {
	case EventAITaskSucceeded:
		_, err := c.handler.Dispatch(ctx, in)
		return err
	case EventAITaskFailed:
		in.Title = "AI 任务失败"
		in.Body = aiFailureBody(evt.Reason)
		in.SilentPush = false
		_, err := c.handler.Dispatch(ctx, in)
		return err
	case EventAITaskRejected:
		in.Title = "AI 任务未通过审核"
		in.Body = aiFailureBody(evt.Reason)
		in.SilentPush = false
		_, err := c.handler.Dispatch(ctx, in)
		return err
	default:
		return fmt.Errorf("unsupported event type %q", evt.EventType)
	}
}

func (c *Consumer) handleFeedEvent(ctx context.Context, payload []byte) error {
	var evt FeedEvent
	if err := json.Unmarshal(payload, &evt); err != nil {
		return fmt.Errorf("decode feed event: %w", err)
	}
	if strings.TrimSpace(evt.UserID) == "" {
		return fmt.Errorf("userId required")
	}

	switch evt.EventType {
	case EventFeedPostCreated:
		actor := defaultName(evt.ActorName, "家人")
		_, err := c.handler.Dispatch(ctx, orchestrator.DispatchInput{
			UserID:   evt.UserID,
			Category: model.CategoryFamilyActivity,
			Title:    "家庭圈有新动态",
			Body:     fmt.Sprintf("%s 发布了新作品", actor),
			Payload:  payload,
		})
		return err
	case EventFeedPostLiked:
		actor := defaultName(evt.ActorName, "家人")
		_, err := c.handler.Dispatch(ctx, orchestrator.DispatchInput{
			UserID:   evt.UserID,
			Category: model.CategoryFamilyActivity,
			Title:    "收到新的点赞",
			Body:     fmt.Sprintf("%s 赞了你的作品", actor),
			Payload:  payload,
		})
		return err
	case EventFeedPostCommented:
		actor := defaultName(evt.ActorName, "家人")
		body := fmt.Sprintf("%s 评论了你的作品", actor)
		if preview := strings.TrimSpace(evt.CommentPreview); preview != "" {
			body = fmt.Sprintf("%s：%s", body, preview)
		}
		_, err := c.handler.Dispatch(ctx, orchestrator.DispatchInput{
			UserID:   evt.UserID,
			Category: model.CategoryFamilyActivity,
			Title:    "收到新的评论",
			Body:     body,
			Payload:  payload,
		})
		return err
	case EventFeedMilestoneReminder:
		title := strings.TrimSpace(evt.Title)
		if title == "" {
			title = "里程碑提醒"
		}
		body := strings.TrimSpace(evt.Body)
		if body == "" {
			body = "宝宝的重要成长时刻到了，快去记录吧"
		}
		_, err := c.handler.Dispatch(ctx, orchestrator.DispatchInput{
			UserID:   evt.UserID,
			Category: model.CategoryMilestone,
			Title:    title,
			Body:     body,
			Payload:  payload,
		})
		return err
	case EventSystemAnnouncement:
		title := strings.TrimSpace(evt.Title)
		if title == "" {
			title = "系统通知"
		}
		body := strings.TrimSpace(evt.Body)
		if body == "" {
			return fmt.Errorf("body required for %s", evt.EventType)
		}
		_, err := c.handler.Dispatch(ctx, orchestrator.DispatchInput{
			UserID:   evt.UserID,
			Category: model.CategorySystem,
			Title:    title,
			Body:     body,
			Payload:  payload,
		})
		return err
	default:
		return fmt.Errorf("unsupported event type %q", evt.EventType)
	}
}

func (c *Consumer) handleCreditEvent(ctx context.Context, payload []byte) error {
	var evt CreditEvent
	if err := json.Unmarshal(payload, &evt); err != nil {
		return fmt.Errorf("decode credit event: %w", err)
	}
	if strings.TrimSpace(evt.UserID) == "" {
		return fmt.Errorf("userId required")
	}

	switch evt.EventType {
	case EventCreditGranted:
		reason := strings.TrimSpace(evt.Reason)
		if reason == "" {
			reason = "积分到账"
		}
		_, err := c.handler.Dispatch(ctx, orchestrator.DispatchInput{
			UserID:   evt.UserID,
			Category: model.CategoryCredit,
			Title:    "积分到账",
			Body:     fmt.Sprintf("%s +%d", reason, evt.Amount),
			Payload:  payload,
		})
		return err
	case EventCreditRefunded:
		reason := strings.TrimSpace(evt.Reason)
		if reason == "" {
			reason = "积分退还"
		}
		body := fmt.Sprintf("%s +%d", reason, evt.Amount)
		if taskID := strings.TrimSpace(evt.TaskID); taskID != "" {
			body = fmt.Sprintf("%s（任务 %s）", body, taskID)
		}
		_, err := c.handler.Dispatch(ctx, orchestrator.DispatchInput{
			UserID:   evt.UserID,
			Category: model.CategoryCredit,
			Title:    "积分退还",
			Body:     body,
			Payload:  payload,
		})
		return err
	default:
		return fmt.Errorf("unsupported event type %q", evt.EventType)
	}
}

func aiCopy(evt AIEvent) (body string, custom map[string]string, silent bool) {
	state := strings.TrimSpace(evt.State)
	if state == "" {
		state = "succeeded"
	}
	custom = map[string]string{
		"taskId": evt.TaskID,
		"state":  state,
	}
	if url := strings.TrimSpace(evt.ResultURL); url != "" {
		custom["resultUrl"] = url
	}
	if url := strings.TrimSpace(evt.ThumbnailURL); url != "" {
		custom["thumbnailUrl"] = url
	}
	body = "你的 AI 作品已生成，点击查看"
	silent = true
	return body, custom, silent
}

func aiFailureBody(reason string) string {
	reason = strings.TrimSpace(reason)
	if reason == "" {
		return "请稍后重试或联系客服"
	}
	return reason
}

func defaultName(name, fallback string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return fallback
	}
	return name
}
