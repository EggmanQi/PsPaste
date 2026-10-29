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
- [x] 任务四：热键注册失败的可见提示与冲突处理（2026-10-27 完成，A 类已过；B 类人工验证待确认）
- [x] 任务五：面板点击外部自动收起（2026-10-27 完成，A 类已过；B 类人工验证待确认）
- [x] 任务六：面板选中响应速度与选中态视觉优化（2026-10-27 完成，A 类已过；B 类人工验证待确认）
- [x] 任务七：搜索默认按钮态 + Kami 默认主题落地（2026-10-29 完成，A 类已过；B 类人工验证待确认）
- [x] 任务八：HIG 化选中态与层次 + 缩略图损坏回退（2026-10-29 完成，A 类已过；B 类人工验证待确认）
- [x] 任务九：选中效果 v3——默认无选中 + 选中材质化（2026-10-29 完成，A 类已过；B 类人工验证待确认）
- [x] 任务十：选中态 v4 + 静态时间 + 长文中段截断（2026-10-29 完成，A 类已过；B 类人工验证待确认）
- [x] 任务十一：双主题系统 + Particle 主题 + 面板主题切换（2026-10-29 完成，A 类已过；B 类人工验证待确认）
- [x] 任务十二：LRU 淘汰 + 30 天周期移除（2026-10-29 完成，A 类已过；B 类人工验证待确认）
- [x] 任务十三：面板 v5——加高 + 选中上移 + 操作图标行（2026-10-29 完成，A 类已过；B 类人工验证待确认）

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
- 2026-10-27：任务四完成。HotKeyService 重构：注册结果经 `onRegistrationStateChange`
  （.registered/.failed）回调装配层（模块内不弹 UI，print 已全部移除）；失败每 30s
  自动重试（注入时钟 + 纯函数 `shouldRetry(lastFailureAt:now:interval:)`，Carbon 注册
  本身可注入脚本化序列便于测试）；SystemNotifier（UNUserNotificationCenter，授权
  请求仅一次，被拒降级为仅菜单栏警示，授权/投递均可注入）；菜单栏三级提示中的两级：
  图标换 exclamationmark.triangle.fill + 菜单顶部禁用项“Hotkey in use by another app”
  （menuNeedsUpdate 刷新）。加分项（点名冲突应用）跳过：Carbon 不暴露热键所有者，
  NSWorkspace 无法可靠推断注册方，不做猜测式提示。
- 2026-10-27：任务五完成。PanelController 可见期主动监听（非激活面板收不到
  resignKey/deactivate，按任务单机制判断实现）：show() 末尾安装、close()/
  closeImmediately() 成对幂等移除；NSEvent 全局鼠标按下（panel.frame.contains 判定，
  全局监听天然收不到发往本应用自身的事件，点菜单栏不收起）+
  NSWorkspace.didActivateApplicationNotification（覆盖 ⌘Tab/Dock 切换，本应用
  activate 不收起）；“是否收起”抽为纯函数 `shouldClose(for:panelFrame:selfBundleID:)`
  并单测（内/外点击、他应用/本应用激活）。两任务完成后 xcodebuild test 25/25 通过、
  Debug 0 error 0 警告。
- 2026-10-27：任务六完成（A→B→C）。根因排查：① 任何选中变化都触发
  withAnimation(scrollTo)（点击可见卡片也滚动）；② LazyHStack 滚动回收时 .task
  重跑重复读盘（选中切换本身不重解码）；③ 整卡 0.18s 隐式动画使描边/缩放慢半拍；
  ④（新发现）onTapGesture(1)+(2) 共存使单击延迟 ~0.3s 等双击判定。修复：滚动门控抽
  纯函数 shouldScrollToSelection（来源 × 可见性，点击可见不滚动、键盘导航保留平滑
  滚动）；ThumbnailCache（NSCache，payloadPath 为键，UI 层）；选中样式当帧切换仅缩放
  保留 0.1s；单击手势 + 手动双击判定。B：移除唤出自动聚焦（focusSignal 机制删除），
  搜索框 icon 态（放大镜 + 提示文字 + 胶囊底），可打印字符键面板级路由
  （searchAppendText 纯函数：聚焦 + 追加；⌘ 组合键/控制字符不追加）。C：按 UI.md §5.1
  三层配色（浅色暖纸 #F5F4ED/#FAF9F4/#1B365D，深色暖灰 #26221E/#37332D/#5B7DB1），
  选中 = 2pt 描边 + 8% 填充 + 1.02 缩放，色值全在 Theme 语义化命名，grep 自查视图
  无内联常量。xcodebuild test 32/32 通过、Debug 0 error 0 警告；浅色/深色截图待
  B 类人工验证。
- 2026-10-29：任务七完成。① 搜索默认按钮态：`PanelModel.searchExpanded`，
  `prepareForShow()` 每次唤起重置为 false；顶栏搜索位在折叠态只渲染放大镜
  按钮（无 TextField，根除了唤出即输入态的问题），点击/键入可打印字符/⌘F
  展开输入框并聚焦（`.onChange(of: searchExpanded)` 同步 FocusState）；
  两种状态同一胶囊槽位、同高不 reflow。② Kami 默认主题落地：面板底从
  “毛玻璃 + 暖色 tint（75%）”改为实色羊皮纸（浅 #F5F4ED / 深 #26221E），
  半透明透出桌面会冲淡暖纸调、层次塌掉；弱化文字/图标从系统 `.secondary`
  （冷灰）改为黄棕底调暖灰（浅 #6E6759 / 深 #A8A091）；卡片/选中描边色值
  本就是 Kami 值，未动。xcodebuild test 33/33 通过、Debug 0 error 0 警告；
  浅色/深色观感待 B 类人工验证。
- 2026-10-29：任务八完成（HIG 审查 skill 全流程，audit 清单落
  Docs/DECISIONS/hig-audit-task8.md）。A：选中态改系统 accent（
  `Theme.Selection` = `Color.accentColor` 2pt 描边 + 15% 填充，删墨蓝/钢蓝
  自定义色；HIG focus-and-selection：集合用高亮非细环，color.md：高亮属
  controlAccentColor 管辖），当帧切换 + 仅缩放 0.1s 的性能约束保留。B：层次
  拉开——浅 面板 #F0EEE6/卡 #FFFFFF，深 面板 #1F1C19/卡 #332E29，深描边
  重配 #453E35（描边恒比卡面亮一档）。C：卡片 padding 10→12、间距 12→14，
  卡高公式 -24→-28（上下各留 14，同网格）；顺带把顶栏/搜索胶囊/hint/空态/
  meta 行的残留间距与透明度魔数全部收进 Theme（grep 自查视图层仅剩
  HistoryListView——任务一调试窗口脚手架，不在范围内）。D：捕获侧
  `ClipboardMonitor.isValidPayload`（图片 ≥100B 且 NSImage 可解码才落盘，
  不通过则从 contentTypes/payloads 剔除，有文本自动降级为文本条目）；
  展示侧 CardView 区分加载中/加载失败（imageLoadFailed），失败且 item.text
  非空回退文本卡布局（纯函数 shouldFallbackToText 可测）。新增 7 个单测
  （捕获 3 + 回退 4），xcodebuild test 40/40 通过、Debug 0 error 0 警告。
  B 类待人工：深浅色选中态可辨性、间距观感、新复制不再产生损坏 payload、
  旧损坏条目显示文本回退。
- 2026-10-29：任务八 C 类修正——卡高公式 -28 此前未生效：ScrollView 被钉死为
  Card.height，卡片行贴上部分隔线、省下的 27pt 变成面板底部死空白。现 ScrollView
  填满顶栏以下空间、卡片行（252pt）垂直居中，上下各留 14pt（新增
  Theme.Card.verticalMargin，UI.md §5.1 已补"不得贴边"条款），新增 ThemeTests
  守护布局不变量。xcodebuild test 42/42 通过、编译 0 警告。
- 2026-10-29：任务九完成（选中效果 v3）。① 打开面板默认无选中：selectedID 的
  nil 语义从"跟随最新"改为"无选中"，effectiveSelection 不再有 first 回退，
  Return 在选中前不粘贴；搜索过滤时选中保留则不动、失效则落到第一条结果
  （updateSelectionAfterFilter，视图在 searchText 变化时调用），无选中时方向键
  落到最新一条。② 选中视觉：删除 accent 15% 填充 + 2pt 描边（Theme.Selection
  只留 scale 1.02 + 0.1s 动画）；未选中卡改半透明 tint（浅 白50% / 深 白10%），
  选中卡改标准材质 .regularMaterial（HIG materials.md：内容层层次用标准材质，
  Liquid Glass 只属功能层且需 macOS 26+）。UI.md §5.1 升 v3。新增 5 个单测，
  xcodebuild test 47/47 通过、编译 0 警告。B 类待人工：无选中唤出、材质选中
  态在深浅色下的可辨性。
- 2026-10-29：任务十完成（选中态 v4 + 静态时间 + 长文中段截断）。v3 材质路线
  实测失效（不透明面板底下无可模糊内容，选中/未选中同呈近白色、缩放不可辨），
  用户选定 §5.1 v4：选中卡 = 纯白实底（浅 #FFF / 深 #E8E4DC）+ accent 2pt
  描边 + 轻投影（r8/y3/15%），删材质与 1.02 缩放。meta 行 `.relative` 活体
  时间改静态标签（今天 HH:mm / 更早 MM-dd HH:mm，CardView.timeLabel 纯函数，
  修了 DateFormatter 不继承 calendar 时区的坑）；长文摘要改中段截断
  （≤300 字全量，超出前 70% … 后 30%，ClipboardItem.middleTruncated 纯函数，
  summary 迁入 ClipboardItem.swift），卡片行上限 6→8；顺带收掉
  HistoryPanelView 最后两个样式魔数。新增 8 个单测，xcodebuild test 55/55
  通过、编译 0 警告。B 类待人工：v4 选中三重 cue 观感、静态时间、长文
  头尾可读性。
- 2026-10-29：任务十一完成（双主题系统 + Particle + 面板切换）。架构：
  静态 Theme enum 拆为 `Theme` 协议（色值/字号/圆角/选中策略）+ 共享
  `Metrics` enum（卡片网格/间距/面板几何，跨主题不变量）+ `ThemeManager`
  （@Observable，environment 注入，持久化键 selectedTheme——@AppStorage 仅
  View 上下文生效，直写同键 UserDefaults，UI.md §5.2 已注）。Parchment 全部
  值原样迁移（任务十 v4 选中规格即其默认选中样式）；Particle 按 §5.2 表格
  落地（深色 accent 修正 #2563EB，选中 = accent 实底 + 白字无描边无投影，
  未选中 = 背景二级实色 + 1pt border）。顶栏新增 paintbrush 主题菜单
  （Menu + checkmark 当前项），切换即时生效。ARCHITECTURE §2 已回写。
  新增 7 个单测，xcodebuild test 62/62 通过、编译 0 警告。B 类待人工：
  菜单浮层层级、Particle 深浅色选中观感、重启保持、两主题布局一致性。
- 2026-10-29：任务十、十一完成。十：选中 v4（纯白卡 + accent 2pt 描边 +
  轻投影，材质与缩放删除）、静态时间（CardView.timeLabel 纯函数，修复
  DateFormatter 不继承 calendar 时区的隐藏 bug）、长文中段截断
  （ClipboardItem.middleTruncated，≤300 全量 / 超出前 70% … 后 30%，行上限
  8），55/55 通过。十一：Theme 协议 + ParchmentTheme（值原样迁移）+
  ParticleTheme（UI.md §5.2 Token，深色 accent 修正 #2563EB，选中 = accent
  实底 + 白字）+ Metrics 跨主题不变量 + ThemeManager（UserDefaults 直写，
  已注文档），顶栏 paintbrush 菜单切换主题，ARCH §2 回写，62/62 通过。
  同日补漏：meta 行新增文本字数（charCountLabel 千分位，en_US 定 locale——
  POSIX locale 不分千分位，测试 caught），63/63 通过。B 类用户已验：UI/
  功能正常。
- 2026-10-29：任务十二完成（LRU 淘汰 + 30 天周期移除）。模型新增
  `lastUsedAt: Date?`（实现选型：可选 + `lastActivityAt` 回退 createdAt，
  因 SwiftData 迁移默认值只能给迁移时刻值、旧记录会被误判最近用过——
  ARCHITECTURE §3 已注）。容量淘汰改为按 lastActivityAt 升序删未固定项；
  周期淘汰 = 启动时 + 每 24h Timer 扫 30 天未动用的未固定项（判定纯函数
  ClipboardStore.shouldEvict，时钟经 evictStale(now:) 注入可测；ttl 与扫描
  间隔为 Eviction 语义常量）；confirm 粘贴时 store.markUsed touch（含跨
  context 重取，调用方可能持 @Query 实例）；删除统一走 store.delete（含
  payload 清理），为任务十三删除动作铺路。新增 4 个单测，xcodebuild test
  67/67 通过、编译 0 警告。B 类待人工：自用观察固定项豁免与 30 天清理。
- 2026-10-29：任务十三完成（面板 v5：加高 + 选中上移 + 操作图标行）。
  面板高 320→400（Metrics.Panel.height，为选中卡上移与操作行让位，卡片
  高度随公式重核算 332、verticalMargin 14 不变量守护仍成立）；选中卡
  上移 28pt（150ms 缓动），每卡预留等高的操作行槽位（22pt 图标热区、
  8pt 网格），选中变化网格零位移；操作行四图标：copy（写回剪贴板、
  markNextPasteboardWriteAsOwn 防回环、不粘贴不收起不写历史）/ delete
  （store.delete 含 payload 清理，选中回落邻卡——纯函数
  PanelModel.selectionAfterDelete 取后邻、无后邻取前邻）/ pin toggle
  （store.togglePin；未选中固定卡显示 pin 角标，选中态由操作行图标体现）/
  share（禁用占位，tooltip Coming soon）。动作经 PanelModel 回调装配，
  store.delete/togglePin 按 id 在自有 context 重取。字数统计由用户
  0760e1c 先行交付（charCountLabel，meta 行 千分位 "1,234 字"）。
  新增 6 个单测，xcodebuild test 73/73 通过、编译 0 警告（顺带清理两个
  既有测试告警）。B 类待人工：400pt 观感、上移+操作行、三图标行为、
  深浅色/两主题一致性、固定项豁免联动。
