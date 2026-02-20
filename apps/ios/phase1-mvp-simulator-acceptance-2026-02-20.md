# OpenClaw iOS Phase 1 MVP 模拟器验收清单

日期：2026-02-20  
目标：按 Phase 1 五个子项执行可复现的功能验收（优先 simulator）

## 0. 本轮执行结论（自动验收）

- [x] 已完成自动验收（构建 + 测试 + 构建产物检查）
- [x] 按你的要求，手动项已跳过（不阻塞当前结论）

自动验收结果：

- `xcodebuild ... test`：`33 tests in 9 suites passed`
- `xcodebuild ... build`：`BUILD SUCCEEDED`
- `.app` 产物中确认存在：
  - `PlugIns/OpenClawShareExtension.appex`
  - `PlugIns/OpenClawWidgetExtension.appex`
  - `Watch/OpenClawWatchApp.app`

## 1. 已完成的自动化验收

### 1.1 Phase 1 相关测试套件

已执行命令：

```bash
xcodebuild -project apps/ios/OpenClaw.xcodeproj -scheme OpenClaw \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -only-testing:OpenClawTests/AgentAvatarExpressionTests \
  -only-testing:OpenClawTests/TalkModeManagerDedupTests \
  -only-testing:OpenClawTests/ShareDraftBuilderTests \
  -only-testing:OpenClawTests/OpenClawWidgetSnapshotStoreTests \
  -only-testing:OpenClawTests/LocationSceneModeTests \
  -only-testing:OpenClawTests/StatusActivityBuilderSceneTests \
  test
```

结果（本轮更新）：

- `33 tests in 9 suites passed`
- 覆盖：
  - Agent 头像表情映射
  - Voice/Talk 去重与 VoiceWake 状态机
  - Share 草稿构建
  - Widget 快照存储
  - Scene Mode 分类与状态栏 Scene 展示
  - SwiftUI 渲染冒烟（含 Settings/Status/Voice/RootTabs）

### 1.2 单项补充验证

已单独验证：

- `LocationSceneModeTests`：3/3 passed
- `StatusActivityBuilderSceneTests`：1/1 passed

## 2. 手动验收清单（Simulator）

状态定义：

- `[x]` 已在自动化中覆盖
- `[ ]` 需要你手动点验 UI/交互

### 2.1 Agent 化身 UI（表情系统）

- [x] 表情状态映射逻辑（测试）
- [-] 打开 App 主界面，确认状态变化时头像表情会变化（本轮按要求跳过手动）
- [-] 连接 gateway 后，观察头像与状态条是否一致（本轮按要求跳过手动）

### 2.2 Voice wake + 连续对话优化

- [x] Talk 去重与关键逻辑（测试）
- [-] 在 Settings 打开 `Voice Wake` 和 `Talk Mode`（本轮按要求跳过手动）
- [-] 进行连续语音输入，确认没有明显重复触发/重复消息（本轮按要求跳过手动）
- [-] 切后台再回前台，确认 Voice/Talk 状态可恢复（本轮按要求跳过手动）

### 2.3 Share Extension 增强

- [x] Share draft 组装逻辑（测试）
- [-] 在 simulator 中从 Safari/Photos 触发分享到 OpenClaw（本轮按要求跳过手动）
- [-] 确认默认 instruction 被附加，且重复 URL/样板文本被清理（本轮按要求跳过手动）
- [-] 确认分享后在会话里可见预期文本（本轮按要求跳过手动）

### 2.4 锁屏/桌面 Widget + Dynamic Island

- [x] Widget snapshot 存储逻辑（测试）
- [-] 在 Home Screen 添加 OpenClaw Widget，确认状态可见（本轮按要求跳过手动）
- [-] 锁屏添加 Widget（若模拟器支持），确认展示一致（本轮按要求跳过手动）
- [-] 触发 Live Activity，确认 Dynamic Island/锁屏展示无崩溃（本轮按要求跳过手动）

### 2.5 位置感知 + 场景模式

- [x] Scene classifier（测试）
- [x] 状态活动展示 Scene（测试）
- [-] Settings > Features 中切换 `Scene Mode`（Off/Auto/Focus/Commute）（本轮按要求跳过手动）
- [-] 选择 `Auto` 后，模拟不同定位速度（或通过调试入口），确认 Scene 在 Focus/Commute 切换（本轮按要求跳过手动）
- [-] 观察顶部状态 activity 文案是否同步更新（本轮按要求跳过手动）

## 3. 当前结论

- Phase 1 的自动化可验证部分已通过。
- 手动项在本轮按你的要求全部跳过，未影响自动验收通过结论。

## 4. 建议执行顺序（你现在就可以按这个走）

1. 先验 `2.1 + 2.5`（App 内即可完成）
2. 再验 `2.2`（语音链路）
3. 再验 `2.3`（跨应用分享链路）
4. 最后验 `2.4`（Widget/Live Activity）
