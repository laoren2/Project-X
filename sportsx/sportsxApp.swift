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
    
    func clearKeychainAfterInstall() {
        let defaults = UserDefaults.standard
        let installFlagKey = "hasInstalledApp"

        if !defaults.bool(forKey: installFlagKey) {
            print("Detected fresh install. Clearing keychain...")
            KeychainHelper.standard.delete(forKey: "access_token")
            defaults.set(true, forKey: installFlagKey)
        }
    }
    
    init() {
        clearKeychainAfterInstall()
        // 设置共享缓存，50MB内存 + 200MB磁盘
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "network_cache"
        )
        URLCache.shared = cache
        print("URLCache configured with memory: 50MB, disk: 200MB")
        // 查询地区
        if let countryCode = Locale.current.region?.identifier {
            print("region_language: \(countryCode)")
        } else {
            print("region_language: UNKNOWN")
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
}




