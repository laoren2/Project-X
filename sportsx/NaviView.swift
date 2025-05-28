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
    case Bike = "bike"
    case Badminton = "badminton"
    case Running = "running"
    case Default = "default"
    
    var id: String {
        return self.rawValue
    }
    
    var name: String {
        switch self {
        case .Bike:
            return "自行车"
        case .Badminton:
            return "羽毛球"
        case .Default, .Running:
            return "跑步"
        }
    }
    
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
    @ObservedObject var user = UserManager.shared
    var body: some View {
        ToastContainerView() {
            ZStack {
                RealNaviView()
                    .overlay(
                        CompetitionWidget()
                            .padding()
                            .offset(y: -50),
                        alignment: .bottomTrailing // 右下角对齐
                    )
                LoginView()
                    .opacity(user.showingLogin ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: user.showingLogin)
                    .allowsHitTesting(user.showingLogin)
            }
        }
    }
}

struct RealNaviView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var user = UserManager.shared
    @State private var isAppLaunching = true // 用于区分冷启动和后台恢复
    
    var body: some View {
        NavigationStack(path: appState.navigationManager.binding) {
            ZStack(alignment: .bottom) {
                TabView(selection: $appState.navigationManager.selectedTab) {
                    HomeView()
                        .tag(Tab.home)
                    
                    ShopView(title: "商店")
                        .tag(Tab.shop)
                    
                    SportCenterView()
                        .tag(Tab.sportCenter)
                    
                    StoreHouseView(title: "仓库")
                        .tag(Tab.storeHouse)
                    
                    UserView(viewModel: UserViewModel(id: user.user.userID, needBack: false))
                        .tag(Tab.user)
                }
                
                // 防止穿透到TabView原生bar的暂时hack
                Color.clear
                    .frame(height: 100) // 估算系统tabbar高度
                    .contentShape(Rectangle())
                    //.border(.blue)
                
                CustomTabBar()
            }
            .ignoresSafeArea(edges: .bottom)
            .onChange(of: appState.competitionManager.isRecording) {
                if !appState.competitionManager.isRecording {
                    // 跳转比赛结果清算页面
                    appState.navigationManager.append(.competitionResultView)
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
                case .friendListView(let id, let selectedTab):
                    FriendListView(viewModel:FriendListViewModel(id: id), selectedTab: selectedTab)
                case .userIntroEditView:
                    UserIntroEditView()
                case .realNameAuthView:
                    RealNameAuthView()
                case .identityAuthView:
                    IdentityAuthView()
                case .userSetUpAccountView:
                    UserSetUpAccountView()
                }
            }
        }
    }
}

struct CustomTabBar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Spacer()
                
                VStack {
                    Image(systemName: tab == .home ? appState.sport.iconName : tab.icon)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(appState.navigationManager.selectedTab == tab ? .white : .thirdText)
                        .padding(.bottom, 1)
                    
                    Text(tab.title)
                        .font(.caption)
                        .foregroundColor(appState.navigationManager.selectedTab == tab ? .white : .thirdText)
                }
                .padding(.vertical, 8)
                .onTapGesture {
                    if shouldAllowSwitch(to: tab) {
                        appState.navigationManager.selectedTab = tab
                    }
                }
                //.border(.red)
                
                Spacer()
            }
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 25)
        .frame(height: 85)
        .background(appState.navigationManager.selectedTab == .user ? userManager.backgroundColor : .defaultBackground)
        .background(appState.navigationManager.selectedTab == .user ? .ultraThickMaterial : .ultraThinMaterial)
    }

    func shouldAllowSwitch(to tab: Tab) -> Bool {
        if tab == .home { return true }
        // 如果离开首页，必须登录
        if !userManager.isLoggedIn {
            print("未登录，禁止切换tab")
            // 弹出登录页
            userManager.showingLogin = true
            return false
        }
        return true
    }
}

struct StoreHouseView: View {
    @EnvironmentObject var appState: AppState
    let title: String
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .defaultBackground.softenColor(blendWithWhiteRatio: 0.2),
                            .defaultBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            VStack{
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
    }
}

struct ShopView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    
    let title: String
    @State private var filteredPersonInfos: [PersonInfoCard] = []
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .defaultBackground.softenColor(blendWithWhiteRatio: 0.2),
                            .defaultBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    // 搜索框
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.gray.opacity(0.1))
                            .frame(height: 30)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.leading, 12)
                            
                            TextField(text: $searchText) {
                                Text("搜索用户")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 15))
                            }
                            .foregroundStyle(.white)
                            .font(.system(size: 15))
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    withAnimation {
                                        searchText = ""
                                    }
                                    filteredPersonInfos.removeAll()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 12)
                                }
                                .transition(.opacity)
                            } else {
                                // 占位，保持布局一致
                                Spacer().frame(width: 12)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.trailing, 8)
                    
                    Button("搜索"){
                        filteredPersonInfos.removeAll()
                        searchAnyPersonInfoCard()
                    }
                    .foregroundStyle(.white)
                }
                
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(filteredPersonInfos) { person in
                            PersonInfoCardView(person: person)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding()
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .ignoresSafeArea(.keyboard)
        .hideKeyboardOnTap()
    }
    
    func searchAnyPersonInfoCard() {
        guard var components = URLComponents(string: "/user/anyone_card") else { return }
        components.queryItems = [
            URLQueryItem(name: "phone_number", value: searchText)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: false, isInternal: true)
        NetworkService.sendRequest(with: request, decodingType: PersonInfoDTO.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    filteredPersonInfos.append(
                        PersonInfoCard(
                            userID: unwrappedData.user_id,
                            avatarUrl: unwrappedData.avatar_image_url,
                            name: unwrappedData.nickname)
                    )
                }
            default: break
            }
        }
    }
}


#Preview{
    let appState = AppState.shared
    return ShopView(title: "商店")
        //.environmentObject(appState)
        //.preferredColorScheme(.dark)
}
