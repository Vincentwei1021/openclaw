# OpenClaw iOS Phase 2（社交功能）自动验收

日期：2026-02-20  
范围：按你定义的 Phase 2 四个子项执行“可自动化验收”的部分，手动项跳过。

## 1) 自动验收结论

- [x] Phase 2 代码已落地（NFC 名片交换 / 同 WiFi 发现 / Agent Profile / 授权体系）
- [x] `xcodebuild test` 通过：`19 tests in 5 suites passed`
- [x] `xcodebuild build` 通过：`BUILD SUCCEEDED`
- [x] 产物校验通过（主 app + share/widget/watch 均存在）

## 2) 本轮新增能力（代码层）

### 2.1 NFC agent 名片交换

- Agent 名片 payload 编解码（含 deep link 兼容）：
  - `Sources/Social/AgentProfile.swift`
- NFC 可用性检测：
  - `Sources/Social/NFCAgentCardService.swift`
- 设置页支持名片导出（code/deep link）与导入：
  - `Sources/Social/SocialSettingsView.swift`

### 2.2 同 WiFi agent 发现

- Bonjour 广播 + 发现服务（`_openclaw-peer._tcp`）：
  - `Sources/Social/SocialPeerDiscoveryService.swift`
- TXT 记录编解码：
  - `Sources/Social/SocialPeerTXTRecordCodec.swift`
- Local Network/Bonjour 声明扩展：
  - `Sources/Info.plist`
  - `project.yml`

### 2.3 Agent profile 系统

- Profile 模型与规范化逻辑：
  - `Sources/Social/AgentProfile.swift`
- Profile/策略本地持久化：
  - `Sources/Social/SocialProfileStore.swift`
- Profile 设置 UI：
  - `Sources/Social/SocialSettingsView.swift`

### 2.4 授权体系

- 授权策略与判定器：
  - `Sources/Social/SocialAuthorization.swift`
- Trusted/Blocked 列表管理：
  - `Sources/Social/SocialHub.swift`
- 设置页策略切换与授权操作：
  - `Sources/Social/SocialSettingsView.swift`

## 3) 自动化测试结果

执行命令（节选）：

```bash
xcodebuild -project apps/ios/OpenClaw.xcodeproj -scheme OpenClaw \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -only-testing:OpenClawTests/AgentCardCodecTests \
  -only-testing:OpenClawTests/SocialAuthorizationEvaluatorTests \
  -only-testing:OpenClawTests/SocialPeerTXTRecordCodecTests \
  -only-testing:OpenClawTests/SocialProfileStoreTests \
  -only-testing:OpenClawTests/SwiftUIRenderSmokeTests \
  test
```

结果：

- `19 tests in 5 suites passed`
- 新增 suite 全通过：
  - `AgentCardCodecTests`
  - `SocialAuthorizationEvaluatorTests`
  - `SocialPeerTXTRecordCodecTests`
  - `SocialProfileStoreTests`
  - `SwiftUIRenderSmokeTests`（包含 `socialSettingsViewBuildsAViewHierarchy`）

## 4) 构建验收结果

执行命令（节选）：

```bash
xcodebuild -project apps/ios/OpenClaw.xcodeproj -scheme OpenClaw \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
```

结果：

- `BUILD SUCCEEDED`
- `OpenClaw.app` 中校验到：
  - `PlugIns/OpenClawShareExtension.appex`
  - `PlugIns/OpenClawWidgetExtension.appex`
  - `Watch/OpenClawWatchApp.app`

## 5) 手动项（本轮按要求跳过）

- [-] NFC 真机贴卡读写交互（需要真机硬件）
- [-] 同 WiFi 多设备互发现（需要两台设备同网）
- [-] 真机本地网络授权弹窗链路
- [-] 授权策略下跨设备端到端请求流转
