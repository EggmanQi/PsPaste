# P's Paste — 技术架构

> 本文档描述目标架构与关键决策。实现若偏离，须回写本文档。
> 相关决策记录见 `DECISIONS/`。

## 1. 技术栈

- Swift（项目当前 Swift 5；新代码可使用 Swift 6 严格并发特性，但不强制迁移）
- **SwiftUI 为主 + AppKit 承担平台能力**（NSPasteboard / NSPanel / 全局热键 / 模拟按键）
- **SwiftData + CloudKit 私有容器**做本地持久化与同步
- 最低系统：**macOS 14 Sonoma**（当前工程模板为 macOS 27.0，任务一中需下调）
- Bundle ID：`com.ebs.pspaste`（ebs = Egg Brain Studio；CloudKit 容器名为 `iCloud.com.ebs.pspaste`）
- 签名：M1 阶段用免费 Apple ID Personal Team（见 `DECISIONS/001-distribution.md`）；
  进入 M2（iCloud 同步）前升级付费 Apple Developer Program
- 分发：**Developer ID + 公证，沙盒外**（见 `DECISIONS/001-distribution.md`）
- **不开启 App Sandbox**（任何 sandbox entitlement 都不勾选——见下）
- 自动更新：Sparkle 2（MVP 后期接入，不阻塞核心闭环）

> 关于 Sandbox：ADR-001 决定沙盒外分发，因此 Signing & Capabilities 中
> **不要勾选任何 sandbox 相关 entitlement**（模板默认即不勾选，保持原样即可）。
> 未来若上架 App Store，需重新做沙盒适配并另写 ADR——届时典型配置会是
> `com.apple.security.app-sandbox` + `com.apple.security.files.user-selected.read-write`，
> 但全局热键与直接粘贴的实现在沙盒内会受限，这正是不在 MVP 开启沙盒的原因。

## 2. 模块划分

模块从第一天就按边界拆分（可用本地 Swift Package 或 Xcode group + 明确依赖方向），
UI 只做组合，不含业务逻辑：

```
PsPaste (app target)
├── ClipboardMonitor      # 捕获：NSPasteboard 轮询、UTI 解析、排除/敏感过滤
├── Storage               # SwiftData 模型、查询、清理策略、CloudKit 配置
├── HotKeyService         # 全局快捷键注册与回调（Carbon RegisterEventHotKey）
├── PanelController       # NSPanel 底部面板：唤出/收起、屏幕跟随、焦点策略
├── PasteService          # 写回剪贴板 + 辅助功能权限检测 + 模拟 ⌘V
└── UI (SwiftUI)          # HistoryPanelView / CardView / SettingsView / MenuBarView
                           # 视觉样式集中在 Theme/ 下（任务十一起：Theme 协议 +
                           # 双实现 + ThemeManager environment 注入，商业化时可整体替换）
```

依赖方向：`UI → {ClipboardMonitor, Storage, HotKeyService, PanelController, PasteService}`，
核心模块之间不互相依赖 UI，不 import SwiftUI。

## 3. 数据模型（SwiftData）

```swift
@Model ClipboardItem {
    var id: UUID
    var createdAt: Date
    var sourceAppBundleID: String?
    var sourceDevice: String        // 预留：本机标识，用于未来 iOS 端与去重
    var contentTypes: [String]      // 本次复制的全部 UTI，见 §4
    var text: String?               // 纯文本表示（可搜索）；富文本等原始数据见 payload
    var payloadPath: String?        // 大对象（图片/rtf/html）落盘后的相对路径
    var thumbnailPath: String?      // 图片缩略图路径
    var isPinned: Bool
    var contentHash: String         // 去重
}
```

- **大对象不进数据库**：图片、RTF、HTML 原始数据写入
  `~/Library/Application Support/PsPaste/Payloads/<uuid>/`，DB 只存路径与元数据。
- **CloudKit**：`ModelConfiguration(cloudKitDatabase: .private("iCloud.<bundle-id>"))`。
  SwiftData + CloudKit 约束：所有属性必须有默认值或可选，关系需可选——建模时遵守。
- **图片同步策略（MVP 简化）**：图片原始数据也随记录同步可接受（SwiftData 对
  二进制大字段支持有限，故 MVP 允许图片 payload 只保存在本地、其他设备显示
  “仅本机可用”占位；V2 再评估 CKAsset 方案）。文本/链接必须完整同步。
- **清理**：超过上限时删除最旧的 `isPinned == false` 项，同时删除其 payload 文件。

## 4. 剪贴板捕获（ClipboardMonitor）

- `Timer`（~0.5s）轮询 `NSPasteboard.general.changeCount`，变化才读取。
- 一次复制包含多个 UTI representation：保留全部常见类型
  （`public.utf8-plain-text`、`public.rtf`、`public.html`、`public.png`、`public.tiff`、`public.url`、`public.file-url`），
  存 `contentTypes` 以便粘贴时无损还原。
- 跳过规则（按顺序）：
  1. 含 `org.nspasteboard.ConcealedType` 或 `TransientType` → 不记录；
  2. 来源 App 在排除列表 → 不记录；
  3. 内容 hash 与最新一条相同 → 不重复记录；
  4. 来源是自身（PasteService 写回时打 `org.nspasteboard.TransientType` 或内部标记）→ 不回环记录。
- 捕获暂停时停止读取（继续轮询 changeCount 但直接跳过）。

## 5. 面板与焦点（PanelController）

- `NSPanel`（`.nonactivatingPanel` + `.borderless`），`level = .floating`，
  `collectionBehavior` 支持全屏 Space 与多显示器。
- 唤出时定位到**当前鼠标所在屏幕**底部，宽度 = 屏幕宽，高度默认约 320pt，可拖拽上边缘调节（V2 可延后）。
- **不激活本 App**：唤出/收起全程不改变前台应用，这是“直接粘贴到原应用”的前提。
- 快捷键再次按下或 Esc 收起；点击面板外区域收起（V2 可选）。

## 6. 全局热键（HotKeyService）

- 沙盒外分发，使用 **Carbon `RegisterEventHotKey`**（当前默认 ⌘⇧`，因 ⌘⇧V 被 Paste.app 占用；M2 设置窗口可配置）。
- 与系统/常见 App 冲突时在设置中提示并允许修改。

## 7. 粘贴（PasteService）

1. 把选中条目的全部 representation 写回 `NSPasteboard.general`。
2. 检查辅助功能权限（`AXIsProcessTrustedWithOptions`，不强制弹窗，设置里提供授权入口）。
3. 有权限：收起面板 → 向之前的前台应用发送 `CGEvent` 模拟 ⌘V。
   无权限：仅写回剪贴板，面板顶部显示“已复制，按 ⌘V 粘贴”。
4. 写回时做内部标记，避免 ClipboardMonitor 回环（见 §4）。

## 8. iCloud 同步注意

- 同步失败/未登录 iCloud：本地功能完全不受影响，设置页显示同步状态。
- **通用剪贴板回环**：iPhone 复制 → Universal Clipboard → Mac changeCount 变化是正常捕获；
  但自身写回 + 同步可能产生重复，靠 `contentHash + sourceDevice` 去重。
- 不在 MVP 实现 iOS 端，但模型字段不得假设“只有一台设备”。

## 9. 性能

- 历史列表懒加载（SwiftData 分页查询，如每页 50 条）。
- 图片缩略图生成在后台线程，列表只加载缩略图；原图按需解码。
- 搜索走内存索引或 SwiftData predicate，1000 条规模无需引入 FTS。

## 10. 当前工程待调整项（任务一处理）

- `MACOSX_DEPLOYMENT_TARGET` 27.0 → **14.0**
- Bundle ID 占位符 → 固定值 `com.ebs.pspaste`（CloudKit 容器名 `iCloud.com.ebs.pspaste`）
- **不开启 App Sandbox**——Capabilities 中不勾选任何 sandbox entitlement（ADR-001）；
  M1 阶段签名用免费 Apple ID Personal Team（7 天重签可接受）；M2 前升级付费开发者账号以启用 CloudKit
- M2 时在 Signing & Capabilities 中添加 **iCloud → CloudKit**（私有容器）

## 11. 应用入口与形态（2026-10-27 修订）

- **入口**：纯 AppKit 委托必须有显式 `static func main()` 来连接
  `NSApplication.shared.delegate`——无 Main storyboard 时 `NSApplicationMain`
  不会自动关联委托，应用会“进程活着但什么都不做”（静默无监听、无热键、无图标）。
  此 bug 曾于任务三后发生，已修复，**未来重构入口时必须保留显式 main()**。
- **形态**：当前开发期**关闭 LSUIElement**（Dock 图标可见，便于确认应用在跑、
  便于调试）；M3 打磨时重新评估是否恢复菜单栏纯驻留（届时写 ADR）。
- **图标**：`Resources/icon.png`（1024×1024，彩色艺术图）→ 转 `icon.icns`
  作 App 图标（`CFBundleIconFile = icon`），原 png 同时进 bundle 作菜单栏图标
  （20×20，**非模板渲染**，彩色图用模板会变黑色剪影）；暂停态仍用 SF Symbol。
