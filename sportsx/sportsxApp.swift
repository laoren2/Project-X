//
//  sportsxApp.swift
//  sportsx
//
//  Created by 任杰 on 2024/7/17.
//
import Foundation
import SwiftUI
import Combine
import Network


enum AppLaunchState {
    case launching        // 启动中
    case ready             // 可以进入主界面
    //case forceUpgrade      // 需要强制升级
    case failed(String)    // 启动失败
}


@MainActor
final class BootstrapManager: ObservableObject {
    static let shared = BootstrapManager()

    @Published var state: AppLaunchState = .launching

    let isFreshInstall: Bool
    
    actor CompletionFlag {
        private var finished = false

        func tryFinish() -> Bool {
            if finished { return false }
            finished = true
            return true
        }
    }
    
    private init() {
        self.isFreshInstall = !UserDefaults.standard.bool(forKey: "hasInstalledApp")
    }

    // todo: 剩下的任务整理迁移进来
    func start() async {
        // 新安装时等待网络权限
        if isFreshInstall {
            print("Fresh install detected, waiting for network...")
            let networkReady = await waitForFullNetworkReady()
            if !networkReady {
                PopupWindowManager.shared.presentPopup(
                    title: "toast.network_error",
                    message: "error.network_error",
                    bottomButtons: [
                        .confirm()
                    ]
                )
                state = .ready
                return
            }
        }
        
        // 1. 用户系统（Token / UserInfo）
        await UserManager.shared.bootstrap()
        
        // 2. 设备 ID
        await KeychainHelper.standard.loadDeviceID()
        
        // 3. 检查版本
        let versionOK = await checkVersion()
        
        // 网络错误直接放进
        guard let checkResult = versionOK else {
            state = .ready
            return
        }
        
        if !checkResult {
            state = .failed("error.client_version")
            return
        }
        
        // 4. 用户信息（依赖 token）
#if DEBUG
        UserManager.shared.fetchMeRole()
#endif
        await UserManager.shared.fetchMeInfo()
        
        // 5. 资产系统（依赖 token）
        await AssetManager.shared.queryCCAssets()
        await AssetManager.shared.queryCPAssets(withLoadingToast: false)
        await AssetManager.shared.queryMagicCards(withLoadingToast: false)
        
        // 6. IAP（依赖 token）
        await IAPManager.shared.loadCouponProducts()
        await IAPManager.shared.loadSubscriptionProducts()
        
        // 7. 查询邮件未读状态（依赖 token）
        UserManager.shared.queryMailBox()
        
        // 8. 商店信息加载
        await ShopManager.shared.queryCPAssets(withLoadingToast: true)
        await ShopManager.shared.queryMagicCards(withLoadingToast: true)
        
        // 启动完成
        state = .ready
    }
    
#if DEBUG
    func prepareDebugEnv() {
        if UserDefaults.standard.bool(forKey: "debug.isDevEnv") {
            NetworkService.baseDomain = "https://dev.valbara.top"
        }
    }
#endif
    
    func prepare() {
#if DEBUG
        prepareDebugEnv()
#endif
        // 新安装时清理 token
        clearTokenAfterInstall()
        // 设置共享缓存，50MB内存 + 200MB磁盘
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "network_cache"
        )
        URLCache.shared = cache
        print("URLCache configured with memory: 50MB, disk: 200MB")
        // 查询语言地区
        //if let countryCode = Locale.current.region?.identifier {
        //    print("region_language: \(countryCode)")
        //} else {
        //    print("region_language: UNKNOWN")
        //}
        // 注册和更新卡牌
        registerAllCardTypes()
        ModelManager.shared.loadIndex()
        ModelManager.shared.syncModels()
        // 激活WCSession
        DeviceManager.shared.activateWCSession()
    }
    
    func checkVersion() async -> Bool? {
        // 从服务端拉取最低支持版本
        let request = APIRequest(path: "/common/query_min_version", method: .get)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: String.self)
        switch result {
        case .success(let data):
            if let minVersionString = data {
                let minVersion = AppVersion(minVersionString)
                if !AppVersionManager.shared.checkMinimumVersion(minVersion) {
                    print("version invalid")
                    return false
                } else {
                    print("version valid")
                    return true
                }
                //print("local version: \(AppVersionManager.shared.currentVersion.toString())")
                //print("server version: \(minVersionString)")
            }
        case .failure(let error):
            switch error {
            case .networkError:
                return nil
            default:
                return true
            }
        }
        return true
    }
    
    func clearTokenAfterInstall() {
        let defaults = UserDefaults.standard
        let installFlagKey = "hasInstalledApp"

        if !defaults.bool(forKey: installFlagKey) {
            print("Detected fresh install. Clearing keychain...")
            KeychainHelper.standard.delete(forKey: "access_token")
            defaults.set(true, forKey: installFlagKey)
        }
    }
    
    func registerAllCardTypes() {
        // running
        MagicCardFactory.register(defID: "equipcard_running_00000001") { cardID, level, params in
            return HeartRateEffect_C_00000001(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(defID: "equipcard_running_00000002") { cardID, level, params in
            return HeartRateEffect_B_00000001(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(defID: "equipcard_running_00000003") { cardID, level, params in
            return AltitudeEffect_C_00000001(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(defID: "equipcard_running_00000004") { cardID, level, params in
            return AltitudeEffect_B_00000001(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(defID: "equipcard_running_00000005") { cardID, level, params in
            return SpeedEffect_B_00000001(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(defID: "equipcard_running_00000006") { cardID, level, params in
            return SpeedEffect_A_00000001(cardID: cardID, level: level, with: params)
        }
        // bike
        MagicCardFactory.register(defID: "equipcard_bike_00000001") { cardID, level, params in
            return HeartRateEffect_C_00000001(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(defID: "equipcard_bike_00000002") { cardID, level, params in
            return HeartRateEffect_B_00000001(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(defID: "equipcard_bike_00000003") { cardID, level, params in
            return AltitudeEffect_C_00000001(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(defID: "equipcard_bike_00000004") { cardID, level, params in
            return AltitudeEffect_B_00000001(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(defID: "equipcard_bike_00000005") { cardID, level, params in
            return SpeedEffect_B_00000002(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(defID: "equipcard_bike_00000006") { cardID, level, params in
            return SpeedEffect_A_00000002(cardID: cardID, level: level, with: params)
        }
        // test
        //MagicCardFactory.register(defID: "equipcard_bike_00000000") { cardID, level, params in
        //    return SpeedEffect_A_00000000(cardID: cardID, level: level, with: params)
        //}
    }
    
    func waitForFullNetworkReady(timeout: TimeInterval = 20) async -> Bool {
        // 1. 等外网
        let internetOK = await waitForNetworkIfNeeded(timeout: timeout)
        //print("internetOK: \(internetOK)")
        if !internetOK { return false }

        // 2. 如果是局域网后端，再等本地网络权限
#if DEBUG
        let localinternetOK = await waitForLocalNetworkReady(timeout: timeout)
        //print("localinternetOK: \(localinternetOK)")
        return localinternetOK
#endif
        return true
    }
    
    func waitForNetworkIfNeeded(timeout: TimeInterval = 15) async -> Bool {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        let flag = CompletionFlag()

        return await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                Task {
                    if path.status == .satisfied {
                        let shouldFinish = await flag.tryFinish()
                        if shouldFinish {
                            monitor.cancel()
                            continuation.resume(returning: true)
                        }
                    }
                }
            }

            monitor.start(queue: queue)

            // 超时兜底
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                let shouldFinish = await flag.tryFinish()
                if shouldFinish {
                    monitor.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func waitForLocalNetworkReady(
        timeout: TimeInterval,
        retryInterval: TimeInterval = 1.0
    ) async -> Bool {
        let start = Date()
        while true {
            // 尝试一次 ping
            let ok = await NetworkService.pingLocalServer()
            if ok {
                return true
            }
            // 是否超时
            if Date().timeIntervalSince(start) > timeout {
                return false
            }
            // 等待一会再试（让系统弹权限框）
            try? await Task.sleep(
                nanoseconds: UInt64(retryInterval * 1_000_000_000)
            )
        }
    }
}

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var sport: SportName = .Bike // 默认运动
    @Published var competitionManager = CompetitionManager.shared // 管理比赛进程
    @Published var navigationManager = NavigationManager.shared // 管理一级导航
    
    let config = GlobalConfig.shared    // 全局配置
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 当 competitionManager 有变化时，让 AppState 也发出变化通知
        competitionManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        navigationManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

class AppStateTest: ObservableObject {
    @Published var testbool: Bool = false
    @Published var showWidget: Bool = false
}


/*class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}*/

struct TestLaunchView: View {
    var body: some View {
        VStack(spacing: 50) {
            Spacer()
            Image("single_app_icon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 100)
                .foregroundStyle(Color.orange.opacity(0.8))
            Text("app.slogan")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(Color.secondText)
                .frame(maxWidth: .infinity)
            Spacer()
        }
        .ignoresSafeArea(.all)
        .background(Color.defaultBackground)
    }
}

struct TestErrorView: View {
    let message: String
    
    var body: some View {
        VStack {
            Spacer()
            Text(LocalizedStringKey(message))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
            Spacer()
        }
        .ignoresSafeArea(.all)
        .background(Color.defaultBackground)
    }
}

@main
struct sportsxApp: App {
    //@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var bootstrap = BootstrapManager.shared
    @StateObject private var appState = AppState.shared
    //@StateObject var appStateTest = AppStateTest()
    
    init() {
        UITabBar.appearance().isHidden = true
    }
    
    var body: some Scene {
        WindowGroup {
            switch bootstrap.state {
            case .launching:
                TestLaunchView()
                    .task {
                        bootstrap.prepare()
                        await bootstrap.start()
                    }
            case .ready:
                NaviView()
                    .environmentObject(appState)
                    .preferredColorScheme(.light)
                //TestView()
            case .failed(let msg):
                TestErrorView(message: msg)
            }
        }
    }
    
    
    
    /*func queryIPCountry() {
        // 查询 ip 对应的国家地区
        let request = APIRequest(path: "/common/query_ip_country", method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: String.self) { result in
            switch result {
            case .success(let data):
                if let country = data {
                    DispatchQueue.main.async {
                        GlobalConfig.shared.ipCountryCode = country
                    }
                    print("ip-country: \(country)")
                }
            default: break
            }
        }
    }*/
}
