# OpenClaw Companion Phase 0.5 架构分析（iOS）

分析日期：2026-02-19  
源码基线：`openclaw/openclaw@d3dab089d70f4c98b914792fb43ca7d3ee1e4f4d`（`main`）

## 0. 执行范围与结果

本次按你的 Phase 0.5 目标完成了以下事项：

- [x] 拉取 OpenClaw 源码
- [x] 分析 iOS App 架构（目录结构、技术栈、Node 通信层）
- [x] 分析 Gateway 协议（WebSocket、OpenClawProtocol）
- [x] 分析现有功能（Canvas / Camera / Location / Voice）
- [x] 输出架构分析文档

---

## 1. 源码与工程结构

### 1.1 关键目录

- iOS App：`apps/ios/`
- iOS 共享协议/SDK：`apps/shared/OpenClawKit/`
- 协议模型（Swift 生成）：`apps/shared/OpenClawKit/Sources/OpenClawProtocol/`
- Share Extension：`apps/ios/ShareExtension/`
- Watch App：`apps/ios/WatchExtension/`

### 1.2 技术栈（iOS）

基于 `apps/ios/project.yml`：

- Swift 6 (`SWIFT_VERSION: 6.0`)
- iOS 18.0 目标版本
- XcodeGen 生成工程
- UI：SwiftUI + UIKit + WKWebView
- 实时通信：`URLSessionWebSocketTask`
- 协议层：`OpenClawProtocol`（生成模型）+ `OpenClawKit`
- 音频与语音：AVAudioEngine / Speech / SwabbleKit
- 设备能力：AVFoundation / ReplayKit / CoreLocation / EventKit / Contacts / Photos / CoreMotion

---

## 2. iOS App 架构分析

### 2.1 顶层运行结构

入口在 `apps/ios/Sources/OpenClawApp.swift`：

- `OpenClawApp` 启动时创建 `NodeAppModel` 与 `GatewayConnectionController`
- `RootCanvas` 作为主容器视图
- ScenePhase 改变时同时驱动：
  - `NodeAppModel.setScenePhase(...)`
  - `GatewayConnectionController.setScenePhase(...)`
- APNs token 通过 AppDelegate 回流到 `NodeAppModel`

### 2.2 核心职责分层

1. UI层

- `RootCanvas.swift`：主画布、Onboarding、Settings/Chat sheet、状态展示
- `ScreenWebView.swift`：WKWebView 容器与导航/消息桥接

2. 编排层（核心）

- `NodeAppModel.swift`：核心状态机（连接、能力路由、后台策略、推送唤醒、分享路由、语音协同）
- `GatewayConnectionController.swift`：发现网关、TLS 指纹确认、连接参数生成

3. 通信层

- `GatewayNodeSession.swift`：会话级封装（请求、事件订阅、node.invoke 请求处理）
- `GatewayChannel.swift`：WebSocket 帧收发、握手、重连、keepalive、tick watchdog
- `GatewayTLSPinning.swift`：TLS 指纹 pinning

4. 能力层

- `NodeCapabilityRouter.swift` + `NodeServiceProtocols.swift`
- 各能力服务：`CameraController`, `ScreenRecordService`, `LocationService`, `TalkModeManager`, `VoiceWakeManager` 等

### 2.3 Node 通信架构（重点）

iOS 端采用“双会话”设计（`apps/ios/Sources/Gateway/GatewayConnectConfig.swift`）：

- `role=node` 会话：设备能力与 `node.invoke.*`
- `role=operator` 会话：`chat.*` / `talk.*` / `config.*` / `voicewake.*`

`NodeAppModel` 内部明确分离：

- `nodeGateway`（能力通道）
- `operatorGateway`（交互通道）

优势：

- 避免 chat/talk 与 node.invoke 相互干扰
- 权限域更清晰（operator scopes 与 node commands/caps 分离）

代价：

- 连接状态同步复杂度上升（需同时处理两条 WS 的重连、暂停、后台恢复）

### 2.4 命令路由机制

`NodeAppModel.buildCapabilityRouter()` 中注册命令到处理器，当前覆盖：

- Canvas：`canvas.present/hide/navigate/eval/snapshot` + `canvas.a2ui.*`
- Camera：`camera.list/snap/clip`
- Screen：`screen.record`
- Location：`location.get`
- Talk：`talk.ptt.start/stop/cancel/once`
- 以及 device/watch/photos/contacts/calendar/reminders/motion/chat push/system notify

这意味着“命令面”与“实现面”已做解耦，后续 Phase 1 扩展可继续按 router 增量接入。

---

## 3. Gateway 协议分析（WebSocket + OpenClawProtocol）

### 3.1 协议模型来源

- `apps/shared/OpenClawKit/Sources/OpenClawProtocol/GatewayModels.swift`
- `GATEWAY_PROTOCOL_VERSION = 3`
- 帧类型：`req` / `res` / `event`

`ConnectParams` 关键字段包括：

- `minProtocol/maxProtocol`
- `client`
- `role/scopes`
- `caps/commands/permissions`
- `auth`
- `device`（设备身份签名）

### 3.2 握手路径（实际实现）

`GatewayChannelActor.sendConnect()` 流程：

1. 建立 WebSocket
2. 等待可选 `connect.challenge`（含 nonce）
3. 发送 `connect` 请求（带 role/scopes/caps/commands/permissions/auth/device）
4. 收到 `hello-ok`
5. 更新 tick 策略、缓存 device token（如返回）

该实现与 `docs/gateway/protocol.md` 一致。

### 3.3 可靠性机制

`GatewayChannelActor` 内建：

- 16MB 最大消息
- 请求级 timeout（pending map）
- keepalive（周期性 `health`）
- tick watchdog（心跳丢失触发重连）
- 指数退避重连
- 事件 seq gap 检测

`GatewayNodeSession` 还增加了：

- snapshot 到达前的连接就绪等待
- `node.invoke.request` -> 本地 handler -> `node.invoke.result`
- invoke 超时保护（默认 30s）

### 3.4 安全模型（iOS侧）

1. TLS 指纹信任链

- 首次连接可提示用户确认 fingerprint
- 存储于 `GatewayTLSStore`（按 stableID 维度）

2. 设备身份与 token

- 支持 device identity 签名连接
- 可持久化 device token，后续优先使用

3. Operator 会话安全策略

- `includeDeviceIdentity=false`（防止重复 pairing 流程）
- 使用 shared gateway auth（token/password）

---

## 4. 现有功能分析

## 4.1 Canvas

实现主线：

- 命令执行在 `NodeAppModel.handleCanvasInvoke(...)`
- UI承载在 `ScreenController` + `ScreenWebView`
- 默认 scaffold 来自 `OpenClawKit` 资源
- 连接后会尝试自动切到 A2UI host（`showA2UIOnConnectIfNeeded`）

关键点：

- 支持 `eval` 与 `snapshot`（JPEG/PNG）
- A2UI action 仅接受可信来源：
  - 本地 scaffold 文件
  - 局域网/本地网络 URL
- 后台限制：`canvas.*` 被禁止（返回 `NODE_BACKGROUND_UNAVAILABLE`）

## 4.2 Camera

实现主线：`CameraController`（actor）

- `camera.list`：枚举可用摄像头
- `camera.snap`：拍照后转码，默认 `maxWidth=1600`
- `camera.clip`：录制短视频并转码 MP4，时长限制 250ms~60s

关键点：

- 显式处理相机/麦克风权限
- 加入 warm-up 延迟，降低首帧空白概率
- 支持 includeAudio 控制
- 后台限制：`camera.*` 被禁止

## 4.3 Location

实现主线：`LocationService` + `SignificantLocationMonitor`

- `location.get`：支持 `coarse/balanced/precise` 精度与 timeout/maxAge
- 模式：`off / whileUsing / always`
- significant change 事件会通过 `location.update` 发回 gateway（仅 always 且授权）

关键点：

- 背景下只有 `always` 模式可用
- 权限不足时返回结构化错误（如 `LOCATION_PERMISSION_REQUIRED`）

## 4.4 Voice（Voice Wake + Talk）

Voice Wake（`VoiceWakeManager`）：

- AVAudioEngine + SFSpeechRecognizer 持续监听触发词
- 支持与 Talk 模式的麦克风互斥（suspend/resume）

Talk（`TalkModeManager`）：

- 连续听写 + PTT（`talk.ptt.*`）
- 通过 operator 会话调用 `chat.send`，订阅事件流获取 assistant 输出
- 支持语音播放与打断

关键点：

- `NodeAppModel` 内有显式协同逻辑，避免 VoiceWake 与 Talk 抢占麦克风
- 后台策略细致：可配置是否保持 talk 活跃；否则切后台后暂停并在回前台恢复

## 4.5 Share Extension（额外观察）

`ShareViewController` 已实现“分享 -> 网关 -> agent.request”闭环：

- 读取共享内容/附件
- 使用共享配置建立临时 GatewayNodeSession
- 发送 `node.event`（`agent.request`）

这意味着你计划中的 “Share Extension 增强” 是在现有能力上升级，而非从零做。

---

## 5. 对 Phase 1 的工程含义

### 5.1 可直接复用（利好）

- 双会话连接框架已完成
- 节点能力路由已可扩展
- Share、Voice、Location、Canvas 基础能力齐全
- Gateway TLS/鉴权/重连机制可直接沿用

### 5.2 主要技术风险

1. 单文件复杂度偏高

- `NodeAppModel.swift`、`TalkModeManager.swift` 体量大，后续功能继续堆叠会提高回归风险

2. 前后台切换复杂

- iOS 对 socket 与音频会话限制严格，语音/连接恢复需持续压测

3. 双会话一致性

- node/operator 状态不同步时，UI 体验可能出现“半连接”状态

4. 权限组合复杂

- Camera/Location/Speech/Notifications/Background modes 的组合路径较多

---

## 6. 建议的 Phase 1 落地切入顺序

结合当前代码基础，建议以下顺序最稳：

1. Agent 化身 UI（纯 UI 层）

- 首先在 `RootCanvas`/`Status` 层做，不动连接栈

2. Voice/Talk 交互优化（小步）

- 优先做状态可视化与用户反馈，再动识别/流式逻辑

3. Share Extension 增强

- 以现有 `agent.request` 链路为基础，补充富文本/附件策略与失败重试

4. Widget / Dynamic Island

- 与 `NodeAppModel` 状态做只读同步，避免直接操控网络层

5. 位置感知场景模式

- 基于已有 `location.update` 与模式控制扩展，不改底层权限模型

---

## 7. Phase 0.5 验收结论

结论：Phase 0.5 已可判定完成。  
现有 iOS 代码不是“原型空壳”，而是具备可演进的 node/operator 双会话与完整能力路由体系。  
你的 Phase 1 更适合采用“在现有框架上分层增量开发”，而不是重写通信与协议基础层。

---

## 8. 补充验证：iOS 模拟器冒烟（2026-02-20）

为补齐“先跑现有版本再进入开发”的验证路径，补做了 iOS 模拟器冒烟。

### 8.1 验证环境

- macOS 15.7（24G222）
- Xcode 26.2（17C52）
- iOS Simulator：`iPhone 17 Pro`（iOS 26.2）

### 8.2 执行内容

1. 功能定向测试（Canvas / Camera / Location / Voice 相关套件）：

- 结果：`50 tests / 10 suites` 全通过（`TEST SUCCEEDED`）
- 证据日志：`/tmp/openclaw-ios-feature-smoke.log`

2. 运行态冒烟（安装、拉起、deep link 注入）：

- `openclaw://gateway?...` 与 `openclaw://agent?...` 调用返回码均为 `0`
- App 进程保持存活（`UIKitApplication:ai.openclaw.ios.local`）
- 截图产物：`/tmp/openclaw-ios-smoke/openclaw-smoke.png`

### 8.3 四项能力结论

| 能力     | 结论       | 说明                                                     |
| -------- | ---------- | -------------------------------------------------------- |
| Canvas   | 通过       | 相关测试通过，`canvas.present/navigate/eval` 路径可执行  |
| Camera   | 部分通过   | 逻辑链路通过；模拟器不等价真实相机硬件行为               |
| Location | 部分通过   | 命令能力与路由通过；定位精度/后台行为需真机复核          |
| Voice    | 模拟器受限 | `VoiceWake` 在模拟器是受限路径；语音识别权限注入存在限制 |

### 8.4 限制与建议

- 本次结果可作为“代码路径正确 + 基础集成可运行”的证据。
- 与麦克风、语音识别、定位后台策略强相关的行为，仍需真机再做一轮验收（后续如果真机识别恢复，建议优先补测 Voice/Location）。
