# 后端微服务

> 各服务独立子目录，Go 为主、Python 为辅。详见 [design-backend.md §3](../docs/design-backend.md#3-服务划分)。

## 服务清单（V1.0）

| 目录 | 服务 | 端口 |
| --- | --- | --- |
| `auth-family-svc/` | 账号、家庭、宝宝 | 8001 |
| `feed-svc/` | 家庭圈 Feed | 8002 |
| `media-svc/` | 媒体上传 STS | 8003 |
| `ai-dispatch-svc/` | AI 任务调度 | 8004 |
| `audit-svc/` | 内容审核 | 8005 |
| `credit-sub-ad-svc/` | 积分 / 订阅 / 广告 | 8006 |
| `caption-svc/` | 智能文案（Python） | 8007 |
| `notification-svc/` | 推送通知 | 8008 |
| `config-svc/` | 灰度与运营配置 | 8009 |
| `iap-callback-svc/` | Apple IAP 回调 | 8010 |

## 脚手架

- `_template/`：Go / Python 服务模板，见任务 **T0.17**。
- 新服务：从 `_template/` fork，5 分钟内可本地启动。
