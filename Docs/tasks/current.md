# 当前任务单

> 给开发协作者（Kimi Code）：先读本文件，再读 `../ARCHITECTURE.md`、
> `../UI.md`（§2.3 交互、§3 菜单栏、§4 设置窗口、§5.2 主题系统）。
> 完成后更新 `../ROADMAP.md`；实现若偏离文档，回写对应文档。

## 任务十四：设置窗口 v1 + 排除应用管理 + 搜索增强（2026-10-30）

### 背景（M2 推进）

- 菜单栏已有 "Settings…" 禁用占位（UI.md §3），本期落地为真窗口。
- ARCH §4 跳过规则里已有"排除 App"，但排除列表此前无管理界面——本期
  把排除应用做成设置项（UserDefaults 持久化），并支持从运行中 App 选取。
- 搜索从"仅 text 字段 contains"增强为搜索完整版。

### 子任务 A：设置窗口 v1（UI.md §4，只做通用/隐私/关于）

- macOS 原生 `Settings` Scene（SwiftUI）或 NSWindowController + TabView，
  与现有 AppKit 委托结构协调（勿破坏 LSUIElement 关闭期的 Dock 可见
  开发与菜单栏入口；⌘, 接通）。
- **通用 Tab**：历史上限（默认 1000，数字输入，写回 store.historyLimit
  生效路径）；保留时长（30 天，与 Eviction.staleTTL 打通——做成可调则
  两值同源）；主题选择（复用 ThemeManager 全部主题，Radio/Picker）。
- **隐私 Tab**：排除应用列表（显示 App 名 + Bundle ID + 图标，添加/
  移除）；**从运行中 App 选取**（NSWorkspace 枚举前台可激活应用，面板
  选择后写入排除列表）；清空历史按钮（确认后清空 DB + payload 目录）。
- **关于 Tab**：版本号（从 Bundle 读）、辅助功能权限状态 + 授权入口
  （复用菜单栏已有逻辑）。
- 同步 Tab **不做**（iCloud 阻塞于付费账号，占位注明 Coming soon 即可，
  或直接不出现在 v1——实现时选后者，少一个死 Tab）。
- 所有设置读写 UserDefaults 语义键，默认值与现状一致（零迁移）。

### 子任务 B：排除应用生效链路

- ClipboardMonitor 的"排除 App"规则改为读 UserDefaults 列表（目前
  是写死或注入的——以 ARCH §4 现状为准改造），列表变化即时生效
  （排除列表变化时捕获线程下一次轮询即遵守，无需重启）。
- 面板显示不做处理（被排除 App 的复制静默跳过，符合预期）。

### 子任务 C：搜索增强（UI.md §2.3 完整版）

- 过滤字段从 text 扩展到：**text + 来源 App 名**（大小写不敏感 contains）。
- 实现从内存 filter 改为 SwiftData `#Predicate`（1000 条规模仍轻），
  保持 @Query 实时刷新语义。
- 现有搜索交互（输入即过滤、Esc、选中回落任务九逻辑）全部不变。

### 验收

- A 类：全量测试通过（新增：设置读写 round-trip、排除列表变化生效、
  predicate 搜索命中 text/来源 App）；Debug 0 error 0 警告；无魔数。
- B 类（人工，待用户验证）：⌘, 打开设置；改历史上限/保留时长生效；
  从运行中 App 选取排除后该 App 复制不入库；清空历史后面板为空；
  搜索来源 App 名可命中；三处设置重启后保持。
