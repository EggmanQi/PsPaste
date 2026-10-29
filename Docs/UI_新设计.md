- 我无法直接写入文件到你的本地磁盘，以下是整理完成的完整 Markdown 文档源码，你可以全选复制后，在本地新建 `Paste-UI-Spec.md` 文件粘贴保存即可。

  ------

  # Particle 设计规范 · Paste macOS App 落地应用文档

  > 基于 particle.ai 官网设计语言，适配 macOS 原生平台，面向剪贴板效率工具的 UI 重构规范

  ## 一、全局设计 Token 体系

  重构第一步：统一全局设计常量，所有界面复用同一套 Token，杜绝零散硬编码样式。

  ### 1. 色彩系统（macOS 动态色）

  全部封装为动态色，自动适配浅色/深色模式，兼容系统强调色语义。

  | 分类     | Token 命名                       | 深色模式色值      | 浅色模式色值      | 应用场景                           |
  | -------- | -------------------------------- | ----------------- | ----------------- | ---------------------------------- |
  | 品牌主色 | `PasteColor.accent`              | `#3B82F6`         | `#2563EB`         | 选中态、主按钮、激活边框、收藏标识 |
  | 主色弱化 | `PasteColor.accentSoft`          | 主色 15% 不透明度 | 主色 10% 不透明度 | Hover 背景、标签弱填充             |
  | 一级背景 | `PasteColor.windowBackground`    | `#0B0F17`         | `#FFFFFF`         | 主窗口、面板底色                   |
  | 二级背景 | `PasteColor.secondaryBackground` | `#111827`         | `#F9FAFB`         | 侧边栏、底栏、卡片背景             |
  | 三级背景 | `PasteColor.tertiaryBackground`  | `#1F2937`         | `#F3F4F6`         | 输入框、代码块、分组背景           |
  | 一级文字 | `PasteColor.primaryText`         | `#F9FAFB`         | `#111827`         | 内容预览、标题                     |
  | 二级文字 | `PasteColor.secondaryText`       | `#9CA3AF`         | `#4B5563`         | 来源应用、时间说明                 |
  | 三级文字 | `PasteColor.tertiaryText`        | `#6B7280`         | `#9CA3AF`         | 占位符、禁用态、元数据             |
  | 边框分割 | `PasteColor.border`              | `#374151`         | `#E5E7EB`         | 控件边框、内容分割线               |
  | 成功语义 | `PasteColor.success`             | `#10B981`         | `#059669`         | 粘贴成功、同步正常                 |
  | 警告语义 | `PasteColor.warning`             | `#F59E0B`         | `#D97706`         | 容量预警                           |
  | 错误语义 | `PasteColor.danger`              | `#EF4444`         | `#DC2626`         | 删除确认、错误提示                 |

  ### 2. 排版系统

  基于 macOS 系统原生 SF Pro / SF Mono，适配剪贴板工具的高密度浏览场景。

  | Token 命名          | 字号/字重       | 字体    | 应用场景                 |
  | ------------------- | --------------- | ------- | ------------------------ |
  | `PasteFont.title`   | 17pt / Semibold | SF Pro  | 窗口标题、设置分组标题   |
  | `PasteFont.heading` | 15pt / Medium   | SF Pro  | 卡片标题、面板顶栏标题   |
  | `PasteFont.body`    | 13pt / Regular  | SF Pro  | 剪贴板内容预览、正文     |
  | `PasteFont.caption` | 11pt / Regular  | SF Pro  | 时间戳、来源应用、元数据 |
  | `PasteFont.code`    | 12pt / Regular  | SF Mono | 代码片段预览、原始数据   |

  ### 3. 基础通用规则

  - 基础网格：8px 基准，所有内边距、间距、尺寸均为 4/8 的倍数
  - 圆角：控件 6px，卡片/面板 8px，全局唤出浮窗 12px
  - 边框：统一 1px 细边框，无厚重外发光与投影
  - 材质：侧边栏、浮窗、下拉菜单使用 macOS 原生半透明材质

  ## 二、核心界面落地规范

  ### 1. 菜单栏快捷面板（最高频入口）

  核心目标：快找、快选、快粘贴。

  - 整体结构：顶部搜索框 → 分类标签栏 → 剪贴板列表 → 底部操作栏
  - 参考尺寸：宽度 380px，高度 520px
  - 规范落地细节：
    - **搜索框**：1px 细边框 + 圆角 6px，前置放大镜 SF 图标；激活态 2px 主色描边，无外发光
    - **分类标签**：次按钮样式，透明背景 + 细边框；选中态实心主色填充 + 白色文字；标签横向滚动，间距 8px
    - **列表项（核心组件）**：
      - 固定高度 44px，符合 macOS 点击热区规范
      - 布局：左侧类型图标（16px）+ 中间内容预览（最多 2 行截断）+ 右侧时间戳
      - 状态：Hover 填充 `accentSoft` 弱背景；选中态实心主色背景 + 白色文字
      - 操作按钮（收藏、删除）：默认隐藏，Hover 时显示在右侧
    - **底栏**：三级背景 + 1px 顶部分割线，放置「全部清除」「打开主窗口」文字按钮

  ### 2. 主应用窗口（完整管理界面）

  采用 macOS 标准三栏布局，适配全屏、分屏等原生特性。

  - **统一标题栏**：工具栏融入标题栏，放置全局搜索、视图切换、排序按钮，全部使用工具栏图标按钮样式，Hover 才显示背景
  - **左侧侧边栏**（默认 220px 宽，支持拖拽缩放）：
    - 背景：系统 `sidebarBackground` 半透明材质，右侧 1px 细分割线
    - 导航分组：收藏、历史记录、智能分类、应用来源
    - 选中态：主色填充背景 + 白色文字；Hover 填充浅灰背景；分组标题使用三级文字
  - **主内容区**：
    - 内边距 16px，卡片间距 12px，对齐 8px 网格
    - 列表视图：与菜单栏面板列表样式保持一致
    - 网格视图：纯色填充卡片 + 1px 细边框 + 圆角 8px，无阴影；Hover 轻微提亮背景
  - **右侧预览面板**（默认 280px 宽，可折叠）：
    - 背景：二级背景色，左侧 1px 分割线
    - 顶部：操作按钮组（复制、收藏、删除）
    - 中间：完整内容预览，代码片段自动切换等宽字体 + 三级背景
    - 底部：元数据区域，展示复制时间、来源应用、数据大小

  ### 3. 偏好设置窗口

  遵循 macOS 原生 Settings 交互范式。

  - 布局：左侧 Tab 导航（图标+文字），右侧分组式设置内容
  - 控件统一样式：
    - 开关：系统 Switch，主色 tint
    - 主按钮：实心主色填充 + 圆角 6px，用于「保存」「确认」
    - 次按钮：描边样式，用于「重置」「取消」
    - 输入框/下拉框：1px 细边框 + 圆角 6px，激活态主色描边
    - 快捷键录制框：复用输入框样式，聚焦态主色边框
  - 分组规则：组标题使用 `heading` 字级，组内项间距 8px，组间距 16px

  ### 4. 全局快捷唤出面板

  - 视觉：半透明毛玻璃 HUD 风格，圆角 12px，轻微系统阴影，无边框
  - 布局：顶部搜索框 + 下方垂直列表，列表样式与菜单栏面板 100% 复用
  - 动效：150ms 淡入淡出，键盘上下选择即时响应

  ### 5. 特殊内容类型适配

  - **纯文本**：默认正文字级，多行截断
  - **代码片段**：自动切换 SF Mono 等宽字体，三级背景色
  - **图片**：圆角 6px 缩略图，保持原始比例，无边框
  - **文件/链接**：左侧对应类型 SF 图标，右侧显示文件名/域名，辅助文字显示路径/来源

  ## 三、交互与动效规范

  遵循「克制、流畅、高效」原则，适配效率工具的跟手性要求：

  1. 所有状态切换（选中、Hover、面板展开）动效时长 150–200ms，使用系统原生缓动曲线
  2. 搜索实时过滤，列表更新使用淡入淡出，无生硬跳动
  3. 粘贴成功反馈：轻微缩放 + 成功色闪烁，不打断用户操作流
  4. 侧边栏折叠、预览面板收起：平滑位移 + 透明度过渡，无夸张弹跳动效
  5. 加载状态：细环形加载指示器，放置于搜索框右侧，不占用内容空间

  ## 四、代码层实现参考（SwiftUI）

  ### 1. 设计 Token 封装

  ```
  // 颜色扩展
  extension Color {
      enum Paste {
          static let accent = Color(light: .init(hex: "#2563EB"), dark: .init(hex: "#3B82F6"))
          static let accentSoft = accent.opacity(0.15)
          static let windowBackground = Color(light: .white, dark: .init(hex: "#0B0F17"))
          static let secondaryBackground = Color(light: .init(hex: "#F9FAFB"), dark: .init(hex: "#111827"))
          static let tertiaryBackground = Color(light: .init(hex: "#F3F4F6"), dark: .init(hex: "#1F2937"))
          
          static let primaryText = Color(light: .init(hex: "#111827"), dark: .init(hex: "#F9FAFB"))
          static let secondaryText = Color(light: .init(hex: "#4B5563"), dark: .init(hex: "#9CA3AF"))
          static let tertiaryText = Color(light: .init(hex: "#9CA3AF"), dark: .init(hex: "#6B7280"))
          
          static let border = Color(light: .init(hex: "#E5E7EB"), dark: .init(hex: "#374151"))
          static let success = Color(light: .init(hex: "#059669"), dark: .init(hex: "#10B981"))
          static let warning = Color(light: .init(hex: "#D97706"), dark: .init(hex: "#F59E0B"))
          static let danger = Color(light: .init(hex: "#DC2626"), dark: .init(hex: "#EF4444"))
      }
  }
  
  // 字体扩展
  extension Font {
      enum Paste {
          static let title = Font.system(size: 17, weight: .semibold)
          static let heading = Font.system(size: 15, weight: .medium)
          static let body = Font.system(size: 13, weight: .regular)
          static let caption = Font.system(size: 11, weight: .regular)
          static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
      }
  }
  ```

  ### 2. 通用组件样式

  ```
  // 主按钮样式
  struct PrimaryButtonStyle: ButtonStyle {
      func makeBody(configuration: Configuration) -> some View {
          configuration.label
              .font(.Paste.body)
              .foregroundColor(.white)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Color.Paste.accent)
              .cornerRadius(6)
              .opacity(configuration.isPressed ? 0.8 : 1)
      }
  }
  
  // 剪贴板列表项组件（全局复用）
  struct PasteboardListItem: View {
      let item: PasteboardItem
      let isSelected: Bool
      
      var body: some View {
          HStack(spacing: 8) {
              Image(systemName: item.type.iconName)
                  .frame(width: 16)
                  .foregroundColor(isSelected ? .white : .Paste.secondaryText)
              Text(item.preview)
                  .font(.Paste.body)
                  .foregroundColor(isSelected ? .white : .Paste.primaryText)
                  .lineLimit(2)
                  .frame(maxWidth: .infinity, alignment: .leading)
              Text(item.timeString)
                  .font(.Paste.caption)
                  .foregroundColor(isSelected ? .white.opacity(0.8) : .Paste.tertiaryText)
          }
          .padding(.horizontal, 10)
          .frame(height: 44)
          .background(isSelected ? Color.Paste.accent : Color.clear)
          .cornerRadius(6)
      }
  }
  ```

  ## 五、重构实施建议

  1. **原生体验优先**：所有自定义样式不破坏 macOS 原生键盘导航、VoiceOver、系统主题跟随能力，符合无障碍规范
  2. **性能优先**：剪贴板历史条目数量多，做好列表复用、异步渲染，视觉样式不能影响滚动流畅度
  3. **一致性原则**：所有界面复用同一套 Token，禁止在业务代码中出现硬编码色值、字号
  4. **渐进式重构**：先落地全局 Token → 逐个替换核心组件 → 最后调整整体布局，降低重构风险

  ------

  需要我补充 AppKit 版本的代码示例，或者再追加一份「重构优先级与里程碑」的执行清单吗？
