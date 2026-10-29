# HIG Code Audit — 任务八（2026-10-29）

范围：`UI/HistoryPanelView.swift`、`UI/CardView.swift`、`UI/Theme/Theme.swift`，
以及缩略图链路涉及的 `ClipboardMonitor/ClipboardMonitor.swift`、
`Storage/ClipboardStore.swift`、`UI/ThumbnailCache.swift`。
准绳：Apple HIG（apple-design skill references，逐条引用文件 › 节）。

## Findings

### 1. 选中态用自定义墨蓝细环，而非 accent 高亮 — High

- **What**：`Theme.Selection.strokeLight/Dark`（墨蓝 `#1B365D` / 浅钢蓝 `#5B7DB1`）
  2pt 描边 + 8% 填充。用户实测反馈"选中态不起眼"。
- **Why**：`focus-and-selection.md › Best practices`："use a focus ring for a
  text or search field, but use a highlight in a list or collection"；macOS
  惯例是集合项用匹配 accent 色的背景高亮。`color.md › Desktop`：accent
  高亮属 `controlAccentColor`（用户在系统设置里选的强调色）管辖，
  "Avoid hard-coding system color values"，应用 API 取色。
- **Fix**：`Theme.Selection` 改 `Color.accentColor` 2pt 描边 + 15% 填充
  （v2 规格），删除自定义双色值；保留当帧切换 + 仅缩放 0.1s 动画。

### 2. 未选中卡与面板底只差一档明度，层次塌掉 — High

- **What**：浅色卡 `#FAF9F4` vs 面板 `#F5F4ED`（Δ 极小）；深色卡 `#37332D` vs
  `#26221E` 同样偏近。用户实测反馈"看起来和背景一致"。
- **Why**：`layout.md › Visual hierarchy`：用负空间/容器形状分组，层次要
  让人一眼理解；`collections.md › Best practices`："Use adequate padding
  around images to keep focus or hover effects easy to see"。参照
  `color.md › Platform considerations` 的 primary/secondary/tertiary
  背景台阶惯例，相邻层必须肉眼可辨。
- **Fix**（v2 规格值）：浅 面板 `#F0EEE6` / 卡 `#FFFFFF`；深 面板 `#1F1C19` /
  卡 `#332E29`；深描边按新卡色重配为 `#453E35`（原为旧卡色调的 `#4A443C`，
  新卡更暗，描边同步降一档，保持"描边比卡面亮一档"的关系；此值为判断项）。

### 3. 卡片内边距与固定高度不成比例：顶边贴字、下部死空白 — Medium

- **What**：`Theme.Card.padding` 10、卡高 256（320-40-24），内容顶对齐 +
  Spacer + meta 贴底。短文本卡中下部大片空白，视觉上"内容贴着顶边"。
- **Why**：`layout.md › Visual hierarchy`（对齐与分组传达结构）+ craft 判断。
  HIG 无具体数值，8pt 网格与 padding 10→12 / spacing 12→14 为工作室惯例
  （任务单指定）。
- **Fix**：padding 10→12、卡片间距 12→14（`Theme.Card`）；卡高公式
  24→28（上下各留 14，与新间距同网格）；结构不变。

### 4. 损坏图片 payload：捕获侧无校验，展示侧永久灰占位 — Critical（功能）

- **What**：库中真实案例 `Payloads/2CB816AF-.../0_public.png` 仅 4 字节
  （PNG 魔数）。`ClipboardMonitor.makeSnapshot` 原样落盘；
  `CardView` 解码失败后 thumbnail 永远 nil，且图片条目不显示已有文本，
  用户完全看不到内容。
- **Why**：健壮性 + `collections.md › Best practices`："Make it easy to
  choose an item"（看不到内容的卡片阻碍选择）。加载中/失败需区分
  （Lens 4 原则；具体规则 HIG 未单列，标注为判断项）。
- **Fix**：捕获侧图片 payload 落盘前校验（纯函数
  `ClipboardMonitor.isValidImagePayload`：字节数 ≥ 100 且
  `NSImage(data:)` 可解码），不通过则不存该类型、contentTypes 相应
  修正；展示侧区分加载中/失败，失败后 `item.text` 非空则回退文本卡布局
  （纯函数 `CardView.shouldFallbackToText` 可测）。

## 无变更项（audit 过但成立）

- **面板实色底不用毛玻璃**：`materials.md` 要求按语义选材质而非颜色观感，
  自定义色是 HIG 明示允许的（`color.md` 首段）；"半透明冲淡暖纸调"是
  任务七已验证的结论，维持。
- **系统字体**：`typography.md › Using system fonts` 支持；工具型面板
  系统无衬线是正确选择。
- **弱化文字暖灰对比度**（计算值，非估计）：浅 `#6E6759` on `#FFFFFF`
  ≈ 5.3:1；深 `#A8A091` on `#332E29` ≈ 5.2:1，均 ≥ 4.5:1
  （`accessibility.md` / `color.md › Inclusive color`）。
- **键盘导航/选中即焦**：面板是键盘优先的瞬态集合，选中项即焦点项，
  与 `focus-and-selection.md` 的"键盘离散移动时移动焦点"一致。
