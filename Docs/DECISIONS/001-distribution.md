# ADR-001：分发方式 — 先 Developer ID 沙盒外分发，暂不进 App Store

- 日期：2026-10-26
- 状态：已决定

## 背景

全局热键与模拟按键直接粘贴是本产品的核心交互。App Store 沙盒对这些能力限制严格
（Carbon 热键注册、CGEvent 模拟按键在沙盒内不可用或受限），而 Maccy 等同类
开源应用也采用沙盒外分发。

## 决定

1. **不开启 App Sandbox**（任何 sandbox entitlement 不勾选）——从第一天就按沙盒外实现。
   未来上架 App Store 需沙盒适配时另写 ADR，不回改本文档。
2. 签名节奏（2026-10-26 修订）：
   - M1–M2 阶段：免费 Apple ID **Personal Team** 本地开发签名（7 天重签，自用可接受）；
   - 进入 M2 的 iCloud/CloudKit 前升级付费 Apple Developer Program；
   - M3 公证分发时启用 Developer ID。
3. 使用 Carbon `RegisterEventHotKey` 实现全局热键；使用辅助功能 API + CGEvent 实现直接粘贴。

## 后果

- 正面：核心交互不受沙盒限制；核心代码在 M3 分发前无需改动，只需更换签名身份。
- 负面：Personal Team 期间 7 天需重签；无 App Store 分发红利；
  需自行处理付费账号、签名、公证与更新。
