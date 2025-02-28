//
//  NaviView.swift
//  sportsx
//
//  Created by 任杰 on 2024/7/20.
//

import SwiftUI

enum SportCategory: String {
    case PVP = "PVP"
    case RVR = "RVR"
}

enum SportName: String, Identifiable, CaseIterable {
    case Bike = "自行车"
    case Badminton = "羽毛球"
    case Running = "跑步"
    
    var id: String { self.rawValue }
    
    var category: SportCategory {
        switch self {
        case .Bike, .Running:
            return .RVR
        case .Badminton:
            return .PVP
        }
    }
    
    var iconName: String {
        switch self {
        case .Bike:
            return "figure.outdoor.cycle"
        case .Badminton:
            return "figure.badminton"
        case .Running:
            return "figure.run"
        }
    }
}

struct NaviView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    @State private var selectedTab = 0
    @State private var showingLogin = false
    @State private var isAppLaunching = true // 用于区分冷启动和后台恢复

    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: appState.sport.iconName)
                        Text("首页")
                    }
                    .tag(0)
                
                PlaceholderView(title: "消息")
                    .tabItem {
                        Image(systemName: "message")
                        Text("消息")
                    }
                    .tag(1)
                
                SportCenterView()
                    .tabItem {
                        Image(systemName: "sportscourt")
                        Text("运动中心")
                    }
                    .tag(2)
                
                PlaceholderView(title: "钱包")
                    .tabItem {
                        Image(systemName: "storefront")
                        Text("商店")
                    }
                    .tag(3)
                
                UserView(showingLogin: $showingLogin)
                    .tabItem {
                        Image(systemName: "person")
                        Text("我的")
                    }
                    .tag(4)
            }
            .overlay(
                CompetitionWidget()
                    .padding(), alignment: .bottomTrailing // 右下角对齐
            )
            .fullScreenCover(isPresented: $showingLogin) {
                LoginView(showingLogin: $showingLogin)
            }
            .onAppear {
                // 从持久存储中读取登录状态/tab状态
                // 可以在这里添加持久化逻辑，例如 UserDefaults
                if !userManager.isLoggedIn {
                    if let savedPhoneNumber = UserDefaults.standard.string(forKey: "savedPhoneNumber") {
                        //print("read UserDefaults success")
                        userManager.loginUser(phoneNumber: savedPhoneNumber)
                    } else {
                        print("read UserDefaults unsuccess")
                        showingLogin = true
                    }
                }
                /*if isAppLaunching {
                 // 如果是冷启动，设置为默认首页
                 selectedTab = 0
                 isAppLaunching = false
                 print("冷启动")
                 } else {
                 // 如果是从后台恢复，读取上次选中的 tab
                 selectedTab = UserDefaults.standard.integer(forKey: "SelectedTab")
                 print("后台恢复")
                 }
                 print("onAppear tab: ",selectedTab)*/
            }
            .onChange(of: userManager.isLoggedIn) {
                if userManager.isLoggedIn {
                    // 模拟将登录状态保存到持久存储
                    // 可以在这里添加你的持久化逻辑，例如 UserDefaults
                    print("set Key: savedPhoneNumber Value: ",userManager.user?.phoneNumber ?? "nil")
                    UserDefaults.standard.set(userManager.user?.phoneNumber, forKey: "savedPhoneNumber")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // 应用从后台恢复时，加载之前的 Tab 状态
                selectedTab = UserDefaults.standard.integer(forKey: "SelectedTab")
                print("后台恢复 Tab: ",selectedTab)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // 当应用进入后台时，保存当前选中的 Tab
                UserDefaults.standard.set(selectedTab, forKey: "SelectedTab")
                print("set key: SelectedTab value: ",selectedTab)
            }
            .navigationDestination(isPresented: $appState.navigationManager.navigateToCompetition) {
                CompetitionDetailView()
            }
            .navigationDestination(isPresented: $appState.navigationManager.navigateToSensorBindView) {
                SensorBindView()
            }
        }
    }
}

struct PlaceholderView: View {
    @EnvironmentObject var appState: AppState
    let title: String
    var body: some View {
        Text(title)
            .font(.largeTitle)
            .fontWeight(.bold)
            .padding()
    }
}


#Preview{
    let appState = AppState()
    //appState.competitionManager.isShowWidget = true
    return NaviView()
        .environmentObject(appState)
}
