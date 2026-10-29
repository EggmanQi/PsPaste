# 当前任务单

> 给开发协作者（Kimi Code）：先读本文件，再读 `../ARCHITECTURE.md`、`../UI.md`
> （§5.1 v4 选中规格、§5.2 主题系统，2026-10-29）。
> 完成后更新 `../ROADMAP.md`；实现若偏离文档，回写对应文档。

## 任务十：选中态 v4 + 静态时间 + 长文中段截断（已完成 2026-10-29）

### 背景（用户决策 2026-10-29）

v3 材质路线实测失效：面板底不透明，`.regularMaterial` 无可模糊内容，
选中/未选中都呈近白色，1.02 缩放不可辨。用户从三个候选中选定
**accent 2pt 描边 + 纯白卡 + 轻投影**（UI.md §5.1 v4）。同批交付：
meta 行活体相对时间改静态标签；长文摘要改中段截断。任务十的 v4 选中
规格是 Parchment 主题的默认选中样式（任务十一在此基础上做主题抽象）。

### 交付内容

- **A 选中态 v4**：选中卡 = 纯白实底（浅 #FFFFFF / 深 #E8E4DC 判断值）
  + 系统 accent 2pt 描边 + 轻投影（radius 8 / y 3 / 15%，判断值）；删除
  材质填充与 1.02 缩放（Theme.Selection 只留描边/投影三参数）。全部当帧
  切换，无动画。
- **B 静态时间**：`CardView.timeLabel(for:now:calendar:)` 纯函数——今天
  `HH:mm`，更早 `MM-dd HH:mm`；DateFormatter 不显式继承 calendar 时区
  的坑已修（显式 `formatter.timeZone = calendar.timeZone`）。meta 行不再
  用 `.relative` 活体标签，消除周期性无意义重渲染。
- **C 中段截断**：`ClipboardItem.middleTruncated(_:budget:)` 纯函数——
  ≤300 字全量，超过取前 70% + "…" + 后 30%（`summary` 从 HistoryListView
  的调试脚手架extension迁入 ClipboardItem.swift）；卡片行上限 6→8。
- **D 顺收**：HistoryPanelView 残留魔数（VStack spacing 0、hint 投影 4）
  收进 Theme（Panel.sectionSpacing / Hint.shadowRadius）。

### 验收记录

- A 类：xcodebuild test **55/55** 通过（新增 8：时间标签 3 + 截断 5）；
  编译 0 警告；视图层 grep 无样式魔数（HistoryListView 调试脚手架除外，
  不在范围）。
- B 类（人工，待用户验证）：① 选中卡纯白 + accent 描边 + 投影三重 cue
  一眼可辨（深浅色）；② meta 行静态时间格式正确、无定时刷新；③ 长文
  卡片头尾可读、中段省略；④ 行上限 8 行观感。

## 任务十一：双主题系统 + Particle 主题 + 面板主题切换（2026-10-29）

### 背景（用户决策）

- 用户提交 `Docs/UI_新设计.md`（particle.ai 设计语言），经 review 采纳：
  Token 体系 + accent 实底选中样式作为第二主题 **Particle**；其竖列表 HUD
  布局**不采纳**。修正：深色 accent 用 `#2563EB`（文档原值 `#3B82F6` 白字
  对比度仅 3.7:1，见 UI.md §5.2）。
- 面板顶栏增加主题切换按钮，菜单中列出主题列表选择使用。
- 规格源：UI.md §5.2（全部 Token 值、选中策略、公共不变量都在那里）。

### 子任务 A：Theme 架构升级（ARCH 影响，需回写）

- `Theme` 从静态 enum 升级为协议 + 实例：`ParchmentTheme`（现有全部值
  原样迁移，行为不变）+ `ParticleTheme`，经 `.environment` 注入视图；
  `ThemeManager` 用 `@AppStorage("selectedTheme")` 持久化当前主题 ID，
  切换即时生效。
- 迁移纪律：视图层只改取值方式（`theme.color.xxx` 取代
  `Theme.ColorToken.xxx(scheme)`），不碰布局/交互逻辑；迁移后行为应与
  迁移前逐像素一致（Parchment 下）。

### 子任务 B：Particle 主题落地（UI.md §5.2）

- Token 全部按 §5.2 表格实现（accent/三级背景/三级文字/边框/字号/圆角）。
- 选中态：accent 实底 + 白字白图标（meta 行同样转白）；图片卡内容不受影响。
  无描边无投影。深浅色都成立（accent 深浅同值 `#2563EB`）。
- 未选中卡：三级背景二级（`#F9FAFB` / `#111827`）实色 + 1pt border。

### 子任务 C：面板主题切换入口

- 顶栏（Pinboard/设置按钮左侧）新增主题按钮：`Image(systemName:
  "paintbrush")`，点击弹出 Menu 列出全部主题名，当前项 checkmark。
- 切换即生效（environment 更新），持久化到 UserDefaults，重启保持。

### 验收

- A 类：`xcodebuild -project PsPaste/PsPaste.xcodeproj -scheme PsPaste test`
  全过（新增 ThemeManager 切换/持久化用例）；Debug 0 error 0 警告；
  Parchment 主题下与迁移前观感一致；grep 视图层无魔数。
- B 类（人工，待用户验证）：Particle 主题下选中卡 accent 实底 + 白字
  一眼可辨（深浅色）；图片卡在选中态下正常；主题切换即时生效且重启
  保持；两主题下卡片布局/间距不变。
