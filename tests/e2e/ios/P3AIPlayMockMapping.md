# P3 AI Play — Mock 场景 ↔ iOS 单元测试映射（T3.26）

> API E2E（`p3-e2e.sh`）覆盖后端契约；端侧弱网/切后台/失败态由 `BabyCameraAIPlay` 包内 mock 单测覆盖。

## 场景映射

| API E2E 场景 | Mock taskId / Header | iOS 测试文件 | 测试用例 |
| --- | --- | --- | --- |
| 图像 happy（WebSocket 推送） | `tsk_e2e_img_happy` | `AITaskCoordinatorTests.swift` | `testTrackAndReceiveWebSocketEvent` |
| 弱网（WS 断线 → 轮询） | `X-E2E-Network: slow` / `tsk_e2e_slow_net` | `AITaskCoordinatorTests.swift` | `testPollingFallbackAfterWebSocketDisconnectThreshold` |
| 切后台 + 静默推送补偿 | `X-E2E-Scenario: background` | `AITaskCoordinatorTests.swift` | `testBackgroundPushAndForegroundStillHasResult` |
| 回前台重连 WS | — | `AITaskCoordinatorTests.swift` | `testForegroundReconnectsWebSocketForActiveTasks` |
| ModelFailed UI | `tsk_e2e_model_failed` | `AITaskOutcomeMapperTests.swift` | `testModelFailedPresentation` |
| Rejected + 申诉入口 | `tsk_e2e_rejected` | `AITaskOutcomeMapperTests.swift` | `testRejectedPresentationWithAppealEntry` |
| 申诉已提交 | `appeal` 后 `appealed` | `AITaskOutcomeMapperTests.swift` | `testAppealedPresentation` |
| 积分退还提示 | failed + balanceAfter | `AITaskOutcomeMapperTests.swift` | `testRefundedCreditsDetectedOnTerminalFailure` |
| 结果下载入库 | succeeded + resultUrl | `AITaskResultDownloaderTests.swift` | 全文件 |
| 水印合成 | deepSynth 元数据 | `AITaskResultWatermarkProcessorTests.swift` | 全文件 |

## 运行 Swift 包测试

```bash
cd ios/Packages/BabyCameraAIPlay
swift test
```

## 说明

- P3 **未**新增独立 XCUITest harness（P2 模式 `-P3E2E`）；AI 玩法 UI 依赖主 App 集成，当前以 API E2E + 包内单测保证行为。
- 若后续需要真机 XCUITest，可参照 `ios/BabyCamera/Features/P2E2E/` 增加 `-P3E2E` harness 并订阅 mock `taskId`。

## 后端申诉契约

`services/ai-dispatch-svc` 申诉 handler 单测：

```bash
cd services/ai-dispatch-svc
go test ./internal/handler/rest/ -run Appeal -v
```

与 API mock `POST /v1/ai/tasks/tsk_e2e_rejected/appeal` 响应字段对齐：`taskId`、`state=appealed`、`appealId`。
