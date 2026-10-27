# P's Paste — 路线图与进度

> 每完成一个任务/里程碑就更新本文档。日期格式 YYYY-MM-DD。

## 里程碑

### M1 — 最小闭环（自用可跑）
目标：⌘⇧V → 底部面板 → 选择 → 粘贴回插，全链路可用。
- [x] 任务一：工程调整 + 模块骨架 + 剪贴板监听 + SwiftData 本地存储（`tasks/current.md`，2026-10-26 完成）
  - 备注：任务单 A 类中“单元测试”当时未交付（工程无测试 target，实际为手动/sqlite 直验）；
    已在任务二前置项补做完成（PsPasteTests target，12 个用例，见下条）。
- [x] 任务二：底部 NSPanel + 卡片历史列表 + 键盘导航（2026-10-26 完成，A 类已过；B 类人工验证待确认）
  - 前置项：新建 PsPasteTests 单元测试 target（pasteboard 抽象为协议注入 mock），
    覆盖去重闭包、Concealed/Transient 跳过、暂停/恢复、自身写回防回环、
    历史上限清理（固定项保留 + payload 清理）、payload 仅存路径。
- [x] 任务三：PasteService（写回 + 辅助功能 + 模拟 ⌘V）+ 菜单栏入口（2026-10-27 完成，A 类已过；B 类人工验证待确认）

### M2 — MVP 完整（对齐 PRD 全部 F1–F12）
- [ ] 搜索过滤、Pinboard（单收藏夹）
- [ ] 排除应用列表、敏感内容跳过、暂停捕获
- [ ] 设置窗口、历史清理策略
- [ ] iCloud（CloudKit 私有容器）同步 + 同步状态展示
- [ ] 按 PRD §6 用户故事逐条验收

### M3 — 打磨（自用体验）
- [ ] 性能：千条历史滚动、缩略图后台解码、分页加载
- [ ] 面板高度拖拽调节、图片预览、Sparkle 自动更新
- [ ] Developer ID 签名 + 公证，产出可分发的 dmg

### M4 — 差异化探索（自用三个月后启动，届时单独调研立项）
候选方向（不承诺全做）：端侧语义搜索、开发者片段模板、买断制 + 隐私叙事、
纯文本粘贴/多选粘贴/Paste Stack 等效率补全、全新视觉设计（替换 MVP 临时皮肤）。
- 前提：视觉皮肤与核心交互已解耦（见 `UI.md`）。

## 当前状态

- 2026-10-26：需求与架构文档建立；Xcode 模板工程已创建（待按 ARCHITECTURE §10 调整）。
- 2026-10-26：任务一完成。部署目标降至 macOS 14.0，移除全部 sandbox 配置（Bundle ID `com.ebs.pspaste`、
  免费 Personal Team 签名保持模板原值）；按 ARCHITECTURE §2 建立 ClipboardMonitor / Storage / UI 骨架；
  捕获链路（轮询 → UTI 读取 → Concealed/Transient 跳过 → hash 去重 → payload 落盘 → SwiftData 入库 +
  上限清理）已跑通，验收项全部通过（含强杀重启持久化、图片原图存于 Payloads 目录）。
  实现未偏离架构文档。iCloud/CloudKit 能力仍未开启，留待 M2。
- 2026-10-26：任务二完成（含前置测试补做）。HotKeyService（Carbon RegisterEventHotKey，⌘⇧V，
  失败时控制台报错并暴露 lastError）；PanelController（.nonactivatingPanel + .borderless，level=.floating，
  collectionBehavior 支持全屏 Space，鼠标所在屏幕底部定位、宽=屏宽、高 320，上下滑动 + 淡入淡出 <200ms，
  全程不激活本 App）；HistoryPanelView + CardView（横向 LazyHStack 最新在左、文本多行截断/链接域名、
  图片缩略图异步解码 + 占位、来源 App 图标 + 相对时间、选中描边 + 缩放，样式常量在 UI/Theme/Theme.swift）；
  键盘交互（←/→ 移动并自动滚动、Return/双击经 monitor 防回环标记后写回剪贴板、Esc 先清搜索再收起、
  键入即过滤 text 字段）；WindowGroup 调试窗口保留。实现未偏离架构/UI 文档。
- 2026-10-27：任务三完成，M1 闭环收口。PasteService 扩展（AXIsProcessTrustedWithOptions 查询式权限检查、
  纯函数分支 action(isAccessibilityTrusted:)（已单测）、有权限时 closeImmediately + 50ms 后 CGEvent post ⌘V、
  无权限时提示条“Copied — press ⌘V to paste”短暂显示后收起）；MenuBarController（NSStatusItem，
  菜单：Open/暂停·恢复/授权入口/调试窗口/设置占位/退出，暂停时图标换 pause.circle + 灰化）；
  应用形态改为 LSUIElement（显式 PsPaste-Info.plist，GENERATE_INFOPLIST_FILE 关闭；注意
  INFOPLIST_KEY_LSUIElement 构建设置实际不生效）、SwiftUI App 改为 AppKit 委托（最小主菜单保证
  搜索框 Copy/Paste 快捷键）、调试窗口改为 AppKit NSWindowController 仅经菜单打开。
  实现未偏离架构/UI 文档。
- 2026-10-27（下午）：任务三后实测发现严重 bug 并已修复：纯 AppKit 委托缺少显式
  `static func main()`，NSApplicationMain 未关联 delegate → 应用进程活着但完全无响应
  （无监听/无热键/无图标）。已加显式入口并验证热键唤出面板生效。同轮改动：
  默认热键 ⌘⇧V → ⌘⇧`（与 Paste.app 登录项热键冲突）；自定义图标（Resources/icon.png →
  icon.icns 作 App 图标 + png 作菜单栏图标，非模板渲染）；开发期关闭 LSUIElement
  （Dock 可见，M3 再评估）；12→15 测试外新增插桩已清理，编译零警告。
  实测确认：Dock 图标可见、⌘⇧` 唤出面板、状态栏图标存在。
