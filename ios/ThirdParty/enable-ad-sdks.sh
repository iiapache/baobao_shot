#!/usr/bin/env bash
# INT-04：链接穿山甲 / 优量汇 / AdMob 真实 SDK 时执行。
# 当前仓库默认使用 Staging Bridge，无需本脚本即可 Staging 联调。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "==> BabyCamera 广告 SDK 启用指引"
echo ""
echo "1. 在 Xcode Target → Build Settings 添加 Swift Active Compilation Conditions: BABYCAMERA_AD_SDK_LIVE"
echo "2. 按区域添加 SDK 依赖（SPM / CocoaPods / 手动 framework）："
echo "   - CN: 穿山甲 BUAdSDK、优量汇 GDTMobSDK"
echo "   - OS: Google Mobile Ads SDK"
echo "3. 在 Packages/BabyCameraCredit/Sources/.../LiveAdSDKClients.swift 实现 Pangle/GDT/AdMob 客户端"
echo "4. 将生产 AppID / 广告位写入 Ads.xcconfig 或 CI Variables"
echo ""
echo "Staging 测试位已配置于: ${ROOT}/BabyCamera/Resources/Config/Ads.xcconfig"
echo "联调文档: ${ROOT}/docs/AD_STAGING_TESTING.md"
