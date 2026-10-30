# P's Paste

轻量级 macOS 剪贴板管理器 —— Paste 式底部唤出历史面板 × Maccy 式轻量本地优先。

> **状态：自用 MVP 开发中（M2）**。功能与进度以 [Docs/ROADMAP.md](Docs/ROADMAP.md) 为准。

## 功能

已实现：

- **自动捕获**：复制文本 / 链接 / 文件 / 图片后约 1 秒内入库；自动跳过 `Concealed` / `Transient` 敏感标记内容；内容 hash 去重；可暂停捕获
- **本地持久化**：SwiftData 存元数据，大对象（图片等）落盘 `~/Library/Application Support/PsPaste/Payloads/`，重启不丢；容量上限（LRU）+ 保留时长自动清理，固定项豁免
- **全局热键唤出底部面板**（默认 ⌘⇧`，可在设置中修改）：出现在鼠标所在屏幕底部，不抢夺当前应用焦点；Esc、再按热键或点击外部收起
- **历史浏览**：横向卡片列表（最新在左），← / → 键盘导航，键入即搜索（正文 + 来源 App 名）；卡片操作：复制、固定、删除
- **粘贴**：Return / 双击直接粘贴到原应用光标处（需辅助功能权限）；未授权时写回剪贴板并提示手动 ⌘V
- **菜单栏入口与设置窗口**：历史上限、保留时长、主题、排除应用、清空历史、开机启动、快捷键录制

规划：Pinboard、iCloud 同步（见 ROADMAP M2–M4）。

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

构建运行后，在任何应用中按 **⌘⇧`**（默认，可在设置 ▸ 通用中修改）唤出底部历史面板，方向键选择、Return 粘贴。首次使用请在系统设置中授予辅助功能权限，以便直接粘贴。

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
