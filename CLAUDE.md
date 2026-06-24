# CLAUDE.md

本文件为 Claude Code（及其他 AI 助手）提供在本仓库工作的指引。仓库为 **sportsx** —— 一个以骑行/跑步为核心的运动竞技平台 iOS App（含 watchOS 伴侣 App）。

> 维护约定：本文件描述的是「约定与边界」，不是 API 文档。改动架构（导航、网络层、启动流程、单例边界）时，请同步更新本文件。

---

## 1. 技术栈与构建

- **语言/UI**：纯 Swift + SwiftUI（无 Storyboard、无 UIKit 主体；仅在导航桥接等少数处用到 UIKit）。
- **最低系统**：iOS **16.0**（watchOS target 为 10.0）。
- **工程**：单一 `sportsx.xcodeproj`，**无 CocoaPods / 无 .xcworkspace**。
- **依赖管理**：Swift Package Manager。当前外部依赖：`ZIPFoundation`。
- **Targets**：
  - `sportsx` —— iOS 主 App（scheme：`sportsx`）
  - `sportsx_Watch Watch App` —— watchOS 伴侣 App
  - `sportsxTests` / `sportsxUITests` —— iOS 测试
- **本地化**： 所有支持的语言 `zh-Hans` / `zh-Hant` / `en` / `ja` / `ko` / `fr` /...，文案在各 `*.lproj/Localizable.strings`。

### 常用命令
```bash
# 构建（模拟器）
xcodebuild -project sportsx.xcodeproj -scheme sportsx \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# 运行测试
xcodebuild -project sportsx.xcodeproj -scheme sportsx \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```
> 日常开发以 Xcode GUI（Cmd+R / Cmd+U）为主，CI/批量验证用上面的 `xcodebuild`。

---

## 2. 整体架构

**Hybrid MVVM + Global Service Managers** 的 SwiftUI 应用。

```
sportsxApp (@main)
  └─ BootstrapManager   启动编排：网络就绪 → 用户/Token → 版本校验 → 资产/IAP/商店预加载
       └─ NaviView      根容器：自定义 TabBar + NavigationStack(绑定全局 path)
            └─ 各功能模块 View ←→ ViewModel(ObservableObject) ←→ 单例 Manager ←→ NetworkService
```

### 启动流程（关键，勿轻改顺序）
入口 [sportsxApp.swift](sportsx/sportsxApp.swift) 按 `BootstrapManager.state`（`.launching/.ready/.failed`）切换根视图：
1. `prepare()`：配置 URLCache、清理新装 token、注册卡牌类型、加载 ML 模型索引、激活 WCSession。
2. `start()`：等待网络 → `UserManager.bootstrap()`（Token/用户）→ 设备 ID → **版本校验** → 用户信息 → 资产系统 → IAP → 邮件 → 商店。多数步骤 `await` 串行，且**后续步骤依赖前面拿到的 token**。

### 状态分层
- `AppState.shared`：聚合当前运动（`SportFeature`/`SportName`）、`CompetitionManager`、`NavigationManager`、`GlobalConfig`，并把子 manager 的 `objectWillChange` 转发出来。通过 `.environmentObject(appState)` 注入。
- `GlobalConfig.shared`：全局开关与一批 `refreshXxxView` 布尔「刷新信号」标志位（页面在 `onAppear`/稳定回调里读取并自刷新）。

---

## 3. 核心模块（`sportsx/` 下）

| 目录 | 职责 |
|------|------|
| 根目录 | App 入口、导航（`NavigationManager`/`NaviView`）、登录、全局配置、资产/商店/IAP/版本/定位等单例 manager |
| `HomePage/` | 首页、Banner、使用提示 |
| `SportCenter/` | 运动中心：骑行/跑步的比赛、自由训练、路线训练、车队、记录管理、排行榜（每个含 `Model/`） |
| `CompetitionLink/` | 比赛运行时：实时页/结算页、选卡、魔法卡 UI；`CompetitionManager/` 内含比赛进程、数据融合、ML 预测、魔法卡系统 |
| `SensorManager/` | 传感器：手机传感器、Apple Watch（WCSession）、设备管理 |
| `UserCenter/` | 用户中心：资料、好友、生涯、实名认证、邮箱、绑定设备 |
| `Tools/` | 基础设施：`NetworkService`、`KeyChainHelper`、`CacheManager`、`ToastSystem`、`PopupWindowSystem`、`OSLog`、`MatchHelper` 等 |
| `Components/` | 复用 UI：按钮、缓存图片、地图、进度条 |
| `Extensions/` | `ViewModifier` 等扩展 |
| `AdminSevice/` | 后台运营面板（**仅 DEBUG 编译**，见第 5 节） |
| `DebugModule/` | 调试视图（仅 DEBUG） |

### 关键子系统
- **网络** [Tools/NetworkService.swift](sportsx/Tools/NetworkService.swift)：`APIRequest` → `NetworkService.sendRequest`/`sendAsyncRequest` → `APIResponse<T>` 信封（`code == 0` 为成功，否则 `APIError.businessError`）。鉴权用 `requiresAuth`，自动注入 Keychain 中的 Bearer token；内置 loading/success/error Toast 与登录态失效处理（401 与业务码 2005/2006/3002/3003 触发登出）。
- **导航** [NavigationManager.swift](sportsx/NavigationManager.swift)：全局 `path: [AppRoute]`，`AppRoute` 是带关联值的大 enum；`append/removeLast/backToHome` 控制栈；`NavigationStore`/`NavigationStoreManager` 用 **weak** 方式在路由间传递可观察 store。
- **魔法卡** `MagicCardFactory`：启动时按 `defID` 注册卡牌效果工厂（见 `BootstrapManager.registerAllCardTypes`）。
- **ML 预测** `CompetitionManager/ModelManagerML`/`PredictionModelML`：本地模型索引加载与同步、比赛中数据融合与预测。

---

## 4. 开发规范

- **命名**：模块化前缀 + 用途后缀。View 以 `...View`、ViewModel 以 `...ViewModel`、单例服务以 `...Manager`，运动相关类型以 `Bike`/`Running` 前缀成对出现。
- **MVVM 配对**：新页面建 `XxxView` + `XxxViewModel: ObservableObject`，业务/网络放 ViewModel，View 只负责展示与交互。
- **单例访问**：跨模块共享状态走 `XxxManager.shared`（`UserManager`、`AssetManager`、`ShopManager`、`IAPManager`、`LocationManager`、`ToastManager`、`PopupWindowManager`、`ModelManager`、`DeviceManager` 等）。
- **线程**：网络回调在后台线程，**所有 UI/`@Published` 改动必须切回主线程**（`DispatchQueue.main.async` 或 `await MainActor.run`）；启动/可重入逻辑标注 `@MainActor`。
- **文案**：用户可见字符串一律走本地化 key（`LocalizedStringKey`，如 `"toast.network_error"`），新增文案需补齐全部的 `Localizable.strings`，key的设计尽量遵循现有的结构。**不要硬编码中文/英文 UI 文案**（历史代码里 Toast 有少量硬编码中文，是待清理项，勿模仿）。
- **配色/样式**：使用 Asset 中的语义色（`Color.defaultBackground`、`Color.secondText` 等），需要大量复用的颜色可以在 extansion 中定义新的标准 Color，仅在特殊场景硬编码 RGB。
- **注释/文件头**：沿用现有中文注释风格与文件头格式。
- **错误处理**：网络层用 `Result<T?, APIError>`，按 `APIError` 分支处理；需要用户感知时通过 Toast/Popup，不要静默吞掉关键失败。
- **API 兼容与发布顺序**：发布顺序固定为**先服务端、后客户端**，因此客户端解码后端**新增的字段可直接用非可选类型**，无需为"旧服务端缺字段"做可选/默认兜底（那种场景不存在）。可选类型/默认值只在业务确有需要时使用，不要为兼容而加。
- **UI设计**： 整体采用极简风格设计，UI元素可以参考运动和游戏的活力风格进行设计，尽量使用SwiftUI，复杂的手势交互场景或SwiftUI无法满足要求时才考虑接入UIKit。

---

## 5. 不应违反的规则

1. **DEBUG 隔离**：`AdminSevice/`、`DebugModule/`、`AppRoute` 中的后台/调试路由、`BootstrapManager.prepareDebugEnv()`、`UserManager.fetchMeRole()` 等均被 `#if DEBUG` 包裹。**任何后台/调试/Mock 代码必须 `#if DEBUG` 守卫**，绝不可进入 Release。
2. **服务环境**：生产域名为 `https://app.valbara.top`。**不要把 dev/local 域名或调试 IP 写成默认值或带进 Release**；环境切换只能走 DEBUG 下的 `debug.serverEnv` 机制。
3. **Token/密钥**：access token 只存 `KeychainHelper`，**不要落到 `UserDefaults`、日志或网络明文**。现有 `print("save token...")` 属于应清理的调试输出，勿照抄、勿新增打印密钥。
4. **导航副作用**：如 [NavigationManager.swift](sportsx/NavigationManager.swift) 头注释所述，全局 `path` 变更会触发 SwiftUI 重建。**关键业务逻辑不要依赖 `onAppear`/`onDisappear`**，改用项目里的 Stable 版本回调。
5. **启动顺序**：`BootstrapManager.start()` 的步骤有依赖关系（先 token 后用户/资产/IAP）。新增启动任务要放对位置并维护 `advanceProgress` 权重，勿打乱串行依赖。
6. **单例生命周期**：`*.shared` 为全局唯一，`init` 私有。不要在别处重复实例化这些 manager，也不要在 `NavigationStoreManager` 里强引用 store（用 `WeakBox`，避免内存泄漏）。
7. **本地化完整性**：新增/修改文案必须同步全部的本地化语言，避免缺 key 露出原始字符串，同时避免同一个语言文件内key的重复。
---

## 6. 常见工作流

### 新增一个页面
1. 在对应模块目录建 `XxxView.swift`（+ 需要时 `XxxViewModel.swift`）。
2. 在 `AppRoute` 中加 case（如需传参用关联值），并在其 `string` 计算属性补映射。
3. 在 [NaviView.swift](sportsx/NaviView.swift) 的 `navigationDestination` 中注册该路由 → View。
4. 用 `NavigationManager.shared.append(.xxx)` 跳转。
5. UI 文案加进 5 份 `Localizable.strings`。

### 新增一个后端接口调用
1. 在 ViewModel/Manager 里构造 `APIRequest(path:method:requiresAuth:...)`。
2. 调 `NetworkService.sendRequest`/`sendAsyncRequest`，`decodingType` 传对应 `Codable` 响应模型（命名 `XxxResponse`，字段对齐后端 snake_case）。
3. 在 `.success`/`.failure` 分支处理；UI 更新切主线程；需要提示时设 `showLoadingToast`/`showErrorToast` 或自定义 `customErrorToast`。

### 新增一个全局服务/单例
- 新建 `XxxManager: ObservableObject`，`static let shared`、`private init`；若要被根视图观察，参考 `AppState` 把其 `objectWillChange` 转发或直接 `.environmentObject` 注入。

### 新增 watchOS 侧能力
- 手机/手表通过 `DeviceManager` 的 WCSession 通信；改动消息协议时两端（`sportsx` 与 `sportsx_Watch Watch App`）需同步。

### 调试环境切换（仅 DEBUG）
- 通过 `UserDefaults` 的 `debug.serverEnv`（`prod`/`dev`/`local`）与 `debug.localServerIP` 控制 `NetworkService.baseDomain`，详见 `BootstrapManager.prepareDebugEnv()`。

---

## 7. 已知技术债（改动时留意，勿扩散）

- `NetworkService` 仍以 completion-handler 为主，`sendAsyncRequest` 只是 `withCheckedContinuation` 包装；代码注释已标注「待迁移到现代 async URLSession」。新代码优先用 async 版本。
- 部分 View 直接调用 `NetworkService`（约 30 处），未严格收敛到 ViewModel。新代码尽量保持 View 纯展示。
- 个别 Toast 文案硬编码中文、个别 `print` 输出敏感信息，属待清理项，**不要作为范式复制**。
- 根目录存在 `test.swift` 等试验文件，非正式模块。
