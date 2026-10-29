# 当前任务单

> 给开发协作者（Kimi Code）：先读本文件，再读 `../ARCHITECTURE.md`、`../UI.md`
> （§5.1 v3 是本任务的视觉规格源，2026-10-29 第三次修订，选中材质化）。
> 完成后更新 `../ROADMAP.md`；实现若偏离文档，回写对应文档。

## 任务九：选中效果 v3——默认无选中 + 选中材质化（已完成 2026-10-29）

### 背景（用户决策 2026-10-29）

1. 打开 panel 时默认没有选中。
2. 移除选中的 accent 底色变化与描边，改为：未选中 = 半透明背景，
   选中 = 毛玻璃质感。HIG 检索后用户选定**标准材质**路线（Liquid Glass
   只属功能层且 API 需 macOS 26+，内容层用 standard materials，见
   UI.md §5.1 v3 修订说明）。

### 交付内容

- **A 默认无选中**：`selectedID` 的 nil 语义从"跟随最新"改为"无选中"；
  `effectiveSelection(in:)` 删除 `items.first` 回退；Return 在选中前不
  粘贴。`updateSelectionAfterFilter(in:)`：过滤后选中仍有效则保留、失效
  落到第一条结果、空结果清空，视图在 `searchText` 变化时调用——保证
  输入后 Return 永远有目标。无选中时方向键落到最新一条（沿用原逻辑）。
- **B 选中材质化**：删 `Theme.Selection` 的 stroke/fill/strokeWidth/
  fillOpacity（只留 scale 1.02 + 0.1s 动画，任务六约束不变）；CardView
  选中卡填充改 `.regularMaterial`（当帧切换），描边两态统一 1pt 暖灰；
  未选中卡底改半透明 tint（浅 白 50% / 深 白 10%，判断值）。
- **C 文档**：UI.md §5.1 升 v3（选中规格、层次、对比度核算、禁用 Liquid
  Glass 条款）、§2.2 状态行、§2.3 默认选中行为行；ROADMAP 记录。

### 验收记录

- A/B 类：`xcodebuild test` **47/47** 通过（新增 5 个 PanelModel 选中
  语义用例）；编译 0 警告。
- C 类（人工，待用户验证）：① 唤出面板无任何选中高亮，Return 不粘贴；
  ② 方向键/点击选中后出现材质卡 + 轻微放大，无 accent 描边；
  ③ 深浅色下材质选中态一眼可辨；④ 输入过滤时选中保留/落第一条结果
  行为符合预期。
