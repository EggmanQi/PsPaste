# 当前任务单

> 给开发协作者（Kimi Code）：先读本文件，再读 `../ARCHITECTURE.md`
> （§3 清理策略 2026-10-29 已改 LRU）、`../UI.md`（§2.1 面板高度 v5、
> §2.2 操作图标行、§5.1 v4、§5.2）。
> 完成后更新 `../ROADMAP.md`；实现若偏离文档，回写对应文档。

## 任务十二：LRU 淘汰 + 30 天周期移除（2026-10-29，用户决策）

### 背景

- 淘汰依据从"最早创建"改为"最近使用"（LRU）；新增 30 天未使用移除。
- 固定项（isPinned）豁免两条规则——固定动作在任务十三提供，本期固定
  项价值 = 豁免淘汰。Pinboard 展示区延后，与标签/分类文件夹/私密文件夹
  作为组织体系一并规划（已记录，勿提前实现）。
- 规格源：ARCHITECTURE §3 清理（修订版全文在那里）。

### 子任务 A：模型迁移

- `ClipboardItem` 新增 `lastUsedAt: Date`（默认 createdAt，需自定义
  初始化保证；轻量迁移，保持全属性默认值/可选纪律兼容 M2 CloudKit）。
- 迁移后旧数据行为：旧条目 lastUsedAt 回退为 createdAt（语义合理：
  从未"被使用过"，创建即最后活跃）。

### 子任务 B：touch 与淘汰逻辑

- PasteService confirm（用户粘贴了该条目）时更新 `lastUsedAt = now`。
- 容量淘汰：超上限（1000）时按 `lastUsedAt` 升序删未固定项（取代原
  createdAt 排序）。
- 周期淘汰：启动时 + 每 24h Timer 扫一遍，`lastUsedAt` 早于 30 天前
  的未固定项删除。周期/判定抽纯函数（`shouldEvict(lastUsedAt:now:ttl:)`
  等），Timer 依赖注入可测；ttl（30 天）与扫描间隔进 ClipboardStore
  语义常量。
- 两条规则删除时照旧清理 payload 文件。

### 验收

- A 类：xcodebuild test **67/67** 通过（新增 4：LRU 容量淘汰序、
  shouldEvict 边界、周期扫描保留固定/新鲜/touched、markUsed touch）；
  编译 0 警告。
- 实现选型记录：`lastUsedAt` 为 `Date?` + `lastActivityAt` 回退
  createdAt（非可选 + 默认值做不到"旧条目 = 创建即最后活跃"——
  SwiftData 迁移默认值只能是迁移时刻值）；ARCHITECTURE §3 已回写。
  markUsed 在 store 自有 context 重取（调用方可能持 @Query 实例）。
- B 类（人工，待用户验证）：自用观察——固定项不被容量/周期淘汰；
  30 天前的旧未固定项在启动扫描时被移除；常用条目粘贴后不被误删。

## 任务十三：面板 v5——加高 + 居中 + 选中上移 + 操作图标行（2026-10-29）

### 背景（用户重设计，取代原右键菜单方案）

- 面板加高（320 → 400，判断值）；卡片行在内容区 **centerY 居中**。
- 选中卡**上移**，卡下浮现操作图标行：**复制**（写回剪贴板、不写历史）
  / **删除** / **固定·取消固定** / **分享**（禁用占位 Coming soon）。
- 规格源：UI.md §2.1（高度）、§2.2（操作图标行）。

### 子任务 A：几何调整

- `Theme/Metrics` 面板高 320 → 400（或按内容推导的合理值，理由写进
  ROADMAP）；卡片高度逻辑随内容区重新核算（卡片行居中后上下边距对称，
  保留 verticalMargin 不变量守护）。
- 卡片行无选中时 centerY 居中；选中卡上移量进 Metrics 语义常量。

### 子任务 B：选中上移 + 操作图标行

- 选中卡上移（建议 ~28pt，判断值），切换 150ms 内系统缓动；未选中卡
  保持居中。
- 操作图标行只挂在选中卡下方（同卡片宽度居中，图标 22pt 热区，间距
  8pt 网格）：copy / delete / pin(unpin 状态切换) / share（disabled，
  tooltip "Coming soon"）。
- 行为：copy = PasteService 写回剪贴板（复用 markNextPasteboardWriteAsOwn
  防回环，不写历史不粘贴）；delete = 删条目 + payload，选中回落邻卡；
  pin = toggle isPinned；share 禁用。
- 键盘导航时图标行跟随选中卡移动；Return 语义不变（直接粘贴）。
- 面板外点击收起逻辑不变。

### 子任务 C：固定项可视反馈

- 未选中卡上固定项显示小 pin 角标（SF pin 图标，meta 行或卡角，判断
  值，保持克制）——否则用户无法感知固定状态。

### 验收

- A 类：xcodebuild test **73/73** 通过（新增 6：selectionAfterDelete 四例 +
  deleteItem 选中回落/未选中保持两例；字数统计为主人 0760e1c 已交付）；
  编译 0 警告（顺带清了 HotKeyServiceTests/PasteServiceTests 两个既有
  测试告警）；grep 视图层无样式魔数。
- 实现记录：操作行动作经 PanelModel 回调装配（UI 只做组合）；store.delete
  /togglePin 均按 id 在自有 context 重取（调用方持 @Query 实例）；每卡
  预留等高原操作行槽位，选中变化时网格零位移。
- B 类（人工，待用户验证）：① 面板加高 400pt、未选中卡片行 centerY
  居中；② 选中卡上移 ~28pt（150ms 缓动）+ 卡下浮现操作图标行；③
  复制/删除/固定三图标行为正确（复制写回剪贴板不收起面板、删除后选中
  回落邻卡、固定角标即时出现）；share 禁用 + Coming soon 提示；④ 深浅色/
  两主题下观感一致；⑤ 键盘导航时图标行跟随；⑥ 与任务十二联动：固定
  项豁免淘汰。
