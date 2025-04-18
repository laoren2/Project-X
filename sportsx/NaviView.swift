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
    case Default,Running = "跑步"
    
    var id: String { self.rawValue }
    
    var category: SportCategory {
        switch self {
        case .Default, .Bike, .Running:
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
        case .Default, .Running:
            return "figure.run"
        }
    }
    
    // 标记支持的运动
    var isSupported: Bool {
        switch self {
        case .Bike, .Running:
            return true
        default:
            return false
        }
    }
}

enum Tab: Int, CaseIterable {
    case home, shop, sportCenter, storeHouse, user

    var title: String {
        switch self {
        case .home: return "首页"
        case .shop: return "商店"
        case .sportCenter: return "运动中心"
        case .storeHouse: return "仓库"
        case .user: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .shop: return "storefront"
        case .sportCenter: return "sportscourt"
        case .storeHouse: return "message"
        case .user: return "person"
        }
    }
}

struct NaviView: View {
    var body: some View {
        RealNaviView()
            .overlay(
                CompetitionWidget()
                    .padding()
                    .offset(y: -50),
                alignment: .bottomTrailing // 右下角对齐
            )
    }
}

struct RealNaviView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var user = UserManager.shared
    @State private var isAppLaunching = true // 用于区分冷启动和后台恢复
    
    var body: some View {
        NavigationStack(path: $appState.navigationManager.path) {
            ZStack(alignment: .bottom) {
                TabView(selection: $appState.navigationManager.selectedTab) {
                    HomeView()
                        .tag(Tab.home)
                    
                    ShopView(title: "商店")
                        .tag(Tab.shop)
                    
                    SportCenterView()
                        .tag(Tab.sportCenter)
                    
                    MessageView(title: "仓库")
                        .tag(Tab.storeHouse)
                    
                    UserView(viewModel: UserViewModel(id: user.user?.userID ?? "未知", needBack: false))
                        .tag(Tab.user)
                }
                
                CustomTabBar()
            }
            .ignoresSafeArea(edges: .bottom)
            .fullScreenCover(isPresented: $user.showingLogin) {
                LoginView(showingLogin: $user.showingLogin)
            }
            .onChange(of: appState.competitionManager.isRecording) {
                if !appState.competitionManager.isRecording {
                    // 跳转比赛结果清算页面
                    appState.navigationManager.path.append(.competitionResultView)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // 应用从后台恢复时，加载之前的 Tab 状态
                let rawValue = UserDefaults.standard.integer(forKey: "SelectedTab")
                if let restoredTab = Tab(rawValue: rawValue) {
                    appState.navigationManager.selectedTab = restoredTab
                    print("后台恢复 Tab: ", restoredTab)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // 当应用进入后台时，保存当前选中的 Tab
                UserDefaults.standard.set(appState.navigationManager.selectedTab.rawValue, forKey: "SelectedTab")
                print("set key: SelectedTab value: ",appState.navigationManager.selectedTab)
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .competitionResultView:
                    CompetitionResultView()
                case .competitionCardSelectView:
                    CompetitionCardSelectView()
                case .competitionRealtimeView:
                    CompetitionRealtimeView()
                case .sensorBindView:
                    SensorBindView()
                case .skillView:
                    SportSkillView()
                case .activityView:
                    ActivityView()
                case .recordManagementView:
                    CompetitionRecordManagementView()
                case .teamManagementView:
                    TeamManagementView()
                case .userSetUpView:
                    UserSetUpView()
                case .instituteView:
                    InstituteView()
                case .userView(let id, let isNeedBack):
                    UserView(viewModel: UserViewModel(id: id, needBack: isNeedBack))
                }
            }
        }
    }
}

struct CustomTabBar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    

    var body: some View {
        HStack(alignment: .bottom) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Spacer()
                Button {
                    if shouldAllowSwitch(to: tab) {
                        appState.navigationManager.selectedTab = tab
                    }
                } label: {
                    VStack {
                        Image(systemName: tab == .home ? appState.sport.iconName : tab.icon)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(appState.navigationManager.selectedTab == tab ? .black : .gray)
                            .padding(.bottom, 1)
                        
                        Text(tab.title)
                            .font(.caption)
                            .foregroundColor(appState.navigationManager.selectedTab == tab ? .black : .gray)
                    }
                    .padding(.vertical, 8)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 20)
        .background(.white)
        .onAppear {
            // 从持久存储中读取登录状态/tab状态
            // 可以在这里添加持久化逻辑，例如 UserDefaults
            if !userManager.isLoggedIn {
                if let savedPhoneNumber = UserDefaults.standard.string(forKey: "savedPhoneNumber") {
                    //print("read UserDefaults success")
                    userManager.loginUser(phoneNumber: savedPhoneNumber)
                } else {
                    print("read UserDefaults unsuccess")
                    userManager.showingLogin = true
                }
            }
        }
        .onChange(of: userManager.isLoggedIn) {
            if userManager.isLoggedIn {
                // 模拟将登录状态保存到持久存储
                // 可以在这里添加你的持久化逻辑，例如 UserDefaults
                print("set Key: savedPhoneNumber Value: ",userManager.user?.phoneNumber ?? "nil")
                UserDefaults.standard.set(userManager.user?.phoneNumber, forKey: "savedPhoneNumber")
            }
        }
    }

    func shouldAllowSwitch(to tab: Tab) -> Bool {
        // 示例条件：如果切到“我的”，必须已登录
        if !userManager.isLoggedIn {
            print("未登录，禁止切换tab")
            // 可弹出登录弹窗
            userManager.showingLogin = true
            return false
        }
        return true
    }
}

struct MessageView: View {
    @EnvironmentObject var appState: AppState
    let title: String
    
    var body: some View {
        VStack{
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
        }
    }
}

struct ShopView: View {
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
    return NaviView()
        .environmentObject(appState)
}
