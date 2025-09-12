//
//  sportsxApp.swift
//  sportsx
//
//  Created by 任杰 on 2024/7/17.
//
import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var sport: SportName = .Bike // 默认运动
    @Published var competitionManager = CompetitionManager.shared // 管理比赛进程
    @Published var navigationManager = NavigationManager.shared // 管理一级导航
    
    let config = GlobalConfig.shared    // 全局配置
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 当 competitionManager 有变化时，让 AppState 也发出变化通知
        competitionManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
        
        navigationManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
    }
}

class AppStateTest: ObservableObject {
    @Published var testbool: Bool = false
    @Published var showWidget: Bool = false
}


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct sportsxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    //@StateObject var appStateTest = AppStateTest()
    //@StateObject private var navigationManager = NManager()
    //@StateObject var nm = NManager()
    
    init() {
        // 验证版本号
        checkVersion()
        clearKeychainAfterInstall()
        // 设置共享缓存，50MB内存 + 200MB磁盘
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "network_cache"
        )
        URLCache.shared = cache
        print("URLCache configured with memory: 50MB, disk: 200MB")
        // 查询语言地区
        if let countryCode = Locale.current.region?.identifier {
            print("region_language: \(countryCode)")
        } else {
            print("region_language: UNKNOWN")
        }
        // 注册和更新卡牌
        registerAllCardTypes()
        ModelManager.shared.loadIndex()
        ModelManager.shared.syncModels()
        // 激活WCSession
        DeviceManager.shared.activateWCSession()
        // 请求用户资产
        AssetManager.shared.queryCCAssets()
        Task {
            await AssetManager.shared.queryCPAssets(withLoadingToast: false)
            await AssetManager.shared.queryMagicCards(withLoadingToast: false)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            NaviView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
            //TestView()
            //    .environmentObject(appState)
            //CompetitionView()
        }
    }
    
    func clearKeychainAfterInstall() {
        let defaults = UserDefaults.standard
        let installFlagKey = "hasInstalledApp"

        if !defaults.bool(forKey: installFlagKey) {
            print("Detected fresh install. Clearing keychain...")
            KeychainHelper.standard.delete(forKey: "access_token")
            defaults.set(true, forKey: installFlagKey)
        }
    }
    
    func registerAllCardTypes() {
        MagicCardFactory.register(type: "avg_pedal_rpm_1") { cardID, level, params in
            return PedalRPMEffect(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(type: "heart_rate_test_1") { cardID, level, params in
            return HeartRateBoostEffect(cardID: cardID, level: level, with: params)
        }
        MagicCardFactory.register(type: "xpose_test_1") { cardID, level, params in
            return XposeTestEffect(cardID: cardID, level: level, with: params)
        }
    }
    
    func checkVersion() {
        // 从服务端拉取最低支持版本
        let request = APIRequest(path: "/common/query_min_version", method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: String.self) { result in
            switch result {
            case .success(let data):
                if let minVersionString = data {
                    let minVersion = AppVersion(minVersionString)
                    if !AppVersionManager.shared.checkMinimumVersion(minVersion) {
                        print("version invalid")
                    } else {
                        print("version valid")
                    }
                    print("local version: \(AppVersionManager.shared.currentVersion.toString())")
                    print("server version: \(minVersionString)")
                }
            default: break
            }
        }
    }
}




