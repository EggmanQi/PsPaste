# 当前任务单

> 给开发协作者（Kimi Code）：先读本文件，再读 `../ARCHITECTURE.md`、`../UI.md`
> （§5.1 选中态与配色 v2 是本任务的视觉规格源，2026-10-29 修订，已转向
> Apple HIG 准绳，Kami 方案废弃）。
> 完成后更新 `../ROADMAP.md`；实现若偏离文档，回写对应文档。

## 任务八：HIG 化选中态与层次 + 缩略图损坏回退（已完成 2026-10-29）

### 背景（用户实测反馈 + 负责人诊断）

1. 用户截图（2026-10-29）实测：选中态不起眼；未选中卡片与面板背景"看起来
   一致"；卡片内文字顶边贴、下部死空白。
2. 负责人已从磁盘定位一个 bug：库中 Xcode 截图条目 payload 文件
   `Payloads/2CB816AF-.../0_public.png` 只有 4 字节（仅 PNG 魔数），
   `NSImage(data:)` 解码失败 → 卡片永远显示灰色占位图，且图片条目不显示
   已有的文本。
3. 视觉方向调整：§5.1 v2（HIG 准绳版）——选中用系统 accent 高亮、
   面板/卡片层次拉开、间距按 8pt 网格。Kami 视觉规则归档勿实现。

### 交付内容

- **前置**：apple-design skill 全流程；对 HistoryPanelView / CardView /
  Theme（及缩略图链路 ClipboardMonitor / ClipboardStore / ThumbnailCache）
  的 code audit 清单落 `Docs/DECISIONS/hig-audit-task8.md`（4 条 findings：
  选中态 High、层次 High、间距 Medium、损坏 payload Critical）。
- **A 选中态 accent 化**：`Theme.Selection` = `Color.accentColor` 2pt +
  15% 填充 + ≤1.02 缩放；删 `strokeLight/strokeDark`；当帧切换、仅缩放
  0.1s 动画保留（任务六性能约束）。
- **B 层次**：浅 面板 `#F0EEE6` / 卡 `#FFFFFF`；深 面板 `#1F1C19` /
  卡 `#332E29`；深描边重配 `#453E35`（比卡面亮一档，与浅色模式同关系）。
  旧值（#F5F4ED/#FAF9F4/#26221E/#37332D/#4A443C）全部删除。
- **C 间距**：`Theme.Card.padding` 10→12、`spacing` 12→14；卡高公式
  -24→-28（上下各留 14）；顶栏/搜索胶囊/hint/空态/meta 行残留魔数
  全部收进 Theme（新增 SearchSlot / Hint / EmptyState / Control tokens）。
- **D 缩略图健壮性**：
  - 捕获侧 `ClipboardMonitor.isValidPayload`：图片 payload 落盘前校验
    ≥100B 且 NSImage 可解码；不通过则不存 payload、contentTypes 相应
    修正（有文本 → 文本条目；无任何可用表示 → 不入库）。
  - 展示侧 CardView：`imageLoadFailed` 区分加载中/失败；失败且
    `item.text` 非空 → 回退文本卡布局（host + summary）；纯函数
    `CardView.shouldFallbackToText` 可测。旧损坏条目同样走回退路径。

### 验收记录

- A 类：`xcodebuild test` **40/40** 通过（新增 7：捕获侧 3 个
  corrupt/valid image 用例 + 展示侧 4 个 shouldFallbackToText 用例）；
  Debug 0 error 0 警告；grep 自查视图层无色值/间距魔数（残留仅
  HistoryListView——任务一调试脚手架，不在范围）；audit 清单已落档。
- B 类（人工，待用户验证）：① 浅色/深色截图选中态一眼可辨且为系统
  accent 色；② 未选中卡与面板底可辨；③ 间距匀称（顶边贴字/底部死空白
  消失）；④ 新复制 Xcode 截图不再产生 4 字节 payload；⑤ 旧损坏条目
  （2CB816AF-...）显示文本回退而非灰占位。
