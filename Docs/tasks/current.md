# 当前任务单

> 给开发协作者（Kimi Code）：先读本文件，再读 `../ARCHITECTURE.md`、
> `../UI.md`（§3 菜单栏、§4 设置窗口——通用 Tab 补完）。
> 完成后更新 `../ROADMAP.md`；实现若偏离文档，回写对应文档。

## 任务十五：开机启动 + 快捷键修改（2026-10-30，通用 Tab 闭环）

### 背景（M2 收尾项）

- UI.md §4 通用 Tab 规格中"快捷键修改、开机启动"两项本期落地，完成后
  通用 Tab 规格闭环。
- 现状：全局热键写死 ⌘⇧`（kVK_ANSI_Grave）；无登录项；设置窗口
  （任务十四）已有通用/隐私/关于三 Tab 与 UserDefaults 设置模式
  （`Settings` 类），本期沿用该模式扩展。

### 子任务 A：开机启动

- 用 `SMAppService.mainApp`（macOS 13+，部署目标 14.0 满足）注册/
  注销登录项；通用 Tab 增加 "Launch at login" Toggle。
- **状态读取以 SMAppService 为唯一事实源**（`SMAppService.mainApp
  .status`），不写 UserDefaults 镜像，避免两处失同步。
- 注册失败（罕见，如 App 未进 /Applications）时 Toggle 回弹并显示
  一行错误说明。

### 子任务 B：快捷键修改

- 通用 Tab 增加快捷键录制器：
  - 显示当前绑定文本（如 `⌘⇧\``）；点击"Record"进入录制态，下一组
    按键即新绑定；Esc 取消录制。
  - **校验规则**：必须含 ≥1 修饰键（纯功能键/纯字母不可注册全局热键）；
    不接受纯修饰键组合；录制态捕获 keyCode + modifiers。
  - 冲突处理：试注册失败（Carbon 返回错误，复用任务四的失败状态/
    重试机制展示）→ 录制器内联显示 "Shortcut in use"，**保留旧绑定**。
  - 成功则持久化（UserDefaults 语义键，如 `hotkeyKeyCode` /
    `hotkeyModifiers`）并运行时重注册——**不重开 App 即生效**。
- HotKeyService 改造：启动时从 UserDefaults 读绑定（缺省 = 默认 ⌘⇧`），
  绑定变化时 cancel 旧注册 + 注册新键；任务四的失败可见性/30s 重试
  语义对自定义绑定同样适用。
- 校验/序列化抽纯函数（可测：modifier 集合判定、绑定持久化 round-trip、
  非法组合拒绝）。

### 验收

- A 类：全量测试通过（新增录制校验、持久化 round-trip、SMAppService
  状态读用的可测部分——SMAppService 本体不可测则注入协议包装）；
  Debug 0 error 0 警告；无魔数；设置键名集中定义不复用散字符串。
- B 类（人工，待用户验证）：登录项在系统设置中可见且开关一致；改键后
  新热键即刻唤出面板；冲突键显示占用提示且旧键仍可用；Esc 取消录制；
  重启 App 后自定义绑定保持；默认 ⌘⇧` 行为对老用户不变。
