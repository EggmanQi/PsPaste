# P's Paste

轻量级 macOS 剪贴板管理器 —— Paste 式底部唤出历史面板 × Maccy 式轻量本地优先。

> **状态：自用 MVP 开发中（M1 收尾）**。功能与进度以 [Docs/ROADMAP.md](Docs/ROADMAP.md) 为准。

## 功能

已实现：

- **自动捕获**：复制文本 / 链接 / 图片后约 1 秒内入库；自动跳过 `Concealed` / `Transient` 敏感标记内容；内容 hash 去重
- **本地持久化**：SwiftData 存元数据，大对象（图片等）落盘 `~/Library/Application Support/PsPaste/Payloads/`，重启不丢
- **⌘⇧V 全局唤出底部面板**：出现在鼠标所在屏幕底部，不抢夺当前应用焦点；Esc 或再按快捷键收起
- **历史浏览**：横向卡片列表（最新在左），来源 App 图标 + 相对时间，← / → 键盘导航，键入即搜索
- **粘贴**：选中后 Return / 双击写回系统剪贴板

进行中（[任务三](Docs/tasks/current.md)）：直接粘贴到原应用光标处（辅助功能权限 + 模拟 ⌘V）、菜单栏入口。

规划：Pinboard、排除应用列表、设置窗口、iCloud 同步（见 ROADMAP M2–M4）。

## 系统要求与构建

- macOS 14.0+，Xcode（Swift + SwiftUI / AppKit，无第三方依赖）
- Bundle ID：`com.ebs.pspaste`；**不启用 App Sandbox**（全局热键与直接粘贴所需，见 [ADR-001](Docs/DECISIONS/001-distribution.md)）

```bash
# 构建
xcodebuild -project PsPaste/PsPaste.xcodeproj -scheme PsPaste build

# 单元测试
xcodebuild -project PsPaste/PsPaste.xcodeproj -scheme PsPaste test
```

## 使用

构建运行后，在任何应用中按 **⌘⇧V** 唤出底部历史面板，方向键选择、Return 粘贴。

## 隐私

- 无遥测、无崩溃上报、无第三方服务器
- 数据仅存放在本机（未来同步仅经用户私有 iCloud 容器）

## 文档

| 文件 | 内容 |
|---|---|
| [Docs/PRD.md](Docs/PRD.md) | 产品需求（MVP 功能范围 F1–F12） |
| [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) | 技术架构与模块划分 |
| [Docs/ROADMAP.md](Docs/ROADMAP.md) | 里程碑与进度 |
| [Docs/UI.md](Docs/UI.md) | 界面规范 |
| [Docs/DECISIONS/](Docs/DECISIONS) | 架构决策记录（ADR） |

## License

[GPL-3.0](LICENSE) © Egg Brain Studio

注意：GPL-3.0 為 copyleft 授權，衍生作品需以相同授權開源。若未來調整商業化策略（如參考 Mole 的「核心開源 + 付費桌面版」雙軌模式），可在首次公開發布前更換授權。
