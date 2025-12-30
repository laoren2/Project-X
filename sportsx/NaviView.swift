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

enum SportName: String, Identifiable, CaseIterable, Codable {
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
            return "sport.bike"
        case .Badminton:
            return "badminton"
        case .Default, .Running:
            return "sport.running"
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
    case home, shop, sportCenter, wareHouse, user

    var title: LocalizedStringKey {
        switch self {
        case .home: return "tab.home"
        case .shop: return "tab.shop"
        case .sportCenter: return "tab.sportCenter"
        case .wareHouse: return "tab.wareHouse"
        case .user: return "tab.my"
        }
    }

    var icon: String {
        switch self {
        case .home: return "single_app_icon"
        case .shop: return "storefront"
        case .sportCenter: return "sportscourt"
        case .wareHouse: return "wareHouse"
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
                    )
                
                // 自定义弹窗
                PopupContainerView()
                
                // 登录页
                LoginView()
                    .opacity(user.showingLogin ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: user.showingLogin)
                    .allowsHitTesting(user.showingLogin)
            }
        }
    }
}

struct RealNaviView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var navigationManager = NavigationManager.shared
    @ObservedObject var user = UserManager.shared
    @State private var isAppLaunching = true // 用于区分冷启动和后台恢复
    let sidebarWidth: CGFloat = 300
    
    var body: some View {
        NavigationStack(path: appState.navigationManager.binding) {
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .bottom) {
                    TabView(selection: $appState.navigationManager.selectedTab) {
                        HomeView()
                            .tag(Tab.home)
                        
                        ShopView()
                            .tag(Tab.shop)
                        
                        SportCenterView()
                            .tag(Tab.sportCenter)
                        
                        StoreHouseView()
                            .tag(Tab.wareHouse)
                        
                        LocalUserView()
                            .tag(Tab.user)
                    }
                    
                    // 防止穿透到TabView原生bar的暂时hack
                    Color.clear
                        .frame(height: 100) // 估算系统tabbar高度
                        .contentShape(Rectangle())
                    
                    CustomTabBar()
                }
                
                Color.gray
                    .opacity((navigationManager.showSideBar ? sidebarWidth : 0) / (2 * sidebarWidth))
                    .ignoresSafeArea()
                    .exclusiveTouchTapGesture {
                        withAnimation(.easeIn(duration: 0.25)) {
                            navigationManager.showSideBar = false
                        }
                    }
                
                // 运动选择侧边栏
                SportSelectionSidebar()
                    .frame(width: sidebarWidth)
                    .offset(x: (navigationManager.showSideBar ? 0 : -sidebarWidth))
            }
            .ignoresSafeArea(edges: .bottom)
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
                case .bikeRecordDetailView(let rid):
                    BikeRecordDetailView(recordID: rid)
                case .runningRecordDetailView(let rid):
                    RunningRecordDetailView(recordID: rid)
                case .competitionCardSelectView:
                    CompetitionCardSelectView()
                case .competitionRealtimeView:
                    CompetitionRealtimeView()
                case .sportTrainingView(let sport):
                    SportTrainingView(sport: sport)
                case .sensorBindView:
                    SensorBindView()
                case .skillView:
                    SportSkillView()
                case .activityView:
                    ActivityView()
                case .regionSelectedView:
                    RegionSelectedView()
                case .bikeRecordManagementView:
                    BikeRaceRecordManagementView()
                case .bikeTeamManagementView:
                    BikeTeamManagementView()
                case .userSetUpView:
                    UserSetUpView()
                case .instituteView:
                    InstituteView()
                case .userView(let id):
                    UserView(id: id)
                case .friendListView(let id, let selectedTab):
                    FriendListView(id: id, selectedTab: selectedTab)
                case .userIntroEditView:
                    UserIntroEditView()
                case .realNameAuthView:
                    RealNameAuthView()
                case .identityAuthView:
                    IdentityAuthView()
                case .userSetUpAccountView:
                    UserSetUpAccountView()
                case .phoneBindView:
                    PhoneBindView()
                case .appleBindView:
                    AppleBindView()
                case .bikeRankingListView(let id, let gender, let isHistory):
                    BikeRankingListView(trackID: id, gender: gender, isHistory: isHistory)
                case .bikeScoreRankingView(let name, let id, let gender):
                    BikeScoreRankingView(seasonName: name, seasonID: id, gender: gender)
                case .bikeTeamCreateView(let id, let date):
                    BikeTeamCreateView(trackID: id, competitionDate: date)
                case .bikeTeamJoinView(let id):
                    BikeTeamJoinView(trackID: id)
                case .bikeTeamManageView(let id):
                    BikeTeamManageView(teamID: id)
                case .bikeTeamDetailView(let id):
                    BikeTeamDetailView(teamID: id)
                case .runningRecordManagementView:
                    RunningRaceRecordManagementView()
                case .runningTeamManagementView:
                    RunningTeamManagementView()
                case .runningRankingListView(let id, let gender, let isHistory):
                    RunningRankingListView(trackID: id, gender: gender, isHistory: isHistory)
                case .runningScoreRankingView(let name, let id, let gender):
                    RunningScoreRankingView(seasonName: name, seasonID: id, gender: gender)
                case .runningTeamCreateView(let id, let date):
                    RunningTeamCreateView(trackID: id, competitionDate: date)
                case .runningTeamJoinView(let id):
                    RunningTeamJoinView(trackID: id)
                case .runningTeamManageView(let id):
                    RunningTeamManageView(teamID: id)
                case .runningTeamDetailView(let id):
                    RunningTeamDetailView(teamID: id)
                case .mailBoxView:
                    MailBoxView()
                case .mailBoxDetailView(let id):
                    MailBoxDetailView(mailID: id)
                case .subscriptionDetailView:
                    SubscriptionDetailView()
                case .iapHelpView:
                    IAPHelpView()
                case .iapCouponView:
                    IAPCouponView()
                case .feedbackView(let type, let reportUserID):
                    FeedbackView(mailType: type, reportUserID: reportUserID)
                case .aboutUsView:
                    AboutUsView()
                case .announcementView:
                    AnnouncementView()
                case .usageTipView:
                    UsageTipView()
                case .smsLoginView:
                    SmsLoginView()
                case .emailBindView:
                    EmailBindView()
#if DEBUG
                case .adminPanelView:
                    AdminPanelView()
                case .seasonBackendView:
                    SeasonBackendView()
                case .runningEventBackendView:
                    RunningEventBackendView()
                case .runningTrackBackendView:
                    RunningTrackBackendView()
                case .runningRecordBackendView:
                    RunningRecordBackendView()
                case .bikeEventBackendView:
                    BikeEventBackendView()
                case .bikeTrackBackendView:
                    BikeTrackBackendView()
                case .bikeRecordBackendView:
                    BikeRecordBackendView()
                case .cpAssetBackendView:
                    CPAssetBackendView()
                case .cpAssetPriceBackendView:
                    CPAssetPriceBackendView()
                case .mailboxBackendView:
                    MailboxBackendView()
                case .magicCardBackendView:
                    MagicCardBackendView()
                case .magicCardPriceBackendView:
                    MagicCardPriceBackendView()
                case .bikeMatchDebugView:
                    BikeMatchDebugView()
                case .feedbackMailBackendView:
                    FeedbackMailBackendView()
                case .homepageBackendView:
                    HomepageBackendView()
#endif
                }
            }
        }
    }
}

struct CustomTabBar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var navigationManager = NavigationManager.shared
    @ObservedObject private var userManager = UserManager.shared
    

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                //HStack {
                //Spacer()
                
                /*VStack(spacing: 4) {
                 if tab == .home || tab == .storeHouse {
                 Image(tab.icon)
                 .renderingMode(.template)
                 .resizable()
                 .scaledToFit()
                 .frame(width: 22, height: 22)
                 //.border(.red)
                 } else {
                 Image(systemName: tab.icon)
                 .font(.system(size: 22, weight: .regular))
                 .frame(height: 20)
                 //.border(.red)
                 }*/
                /*(tab == navigationManager.selectedTab && tab == .sportCenter) ? (navigationManager.isTrainingView ? "训练中心" : "竞技中心") : */
                Text(tab.title)
                    .font(.system(size: 18, weight: .semibold))
                //}
                    .foregroundColor(navigationManager.selectedTab == tab ? .white : .thirdText)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                //Spacer()
                //}
                    .contentShape(Rectangle())
                //.border(.red)
                    .exclusiveTouchTapGesture {
                        //if tab == navigationManager.selectedTab && tab == .sportCenter {
                        //    navigationManager.isTrainingView.toggle()
                        //}
                        if shouldAllowSwitch(to: tab) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            navigationManager.selectedTab = tab
                        }
                    }
            }
        }
        .padding(.bottom, 25)
        .frame(height: 85)
        .background(navigationManager.selectedTab == .user ? userManager.backgroundColor : .defaultBackground)
    }

    func shouldAllowSwitch(to tab: Tab) -> Bool {
        if tab == .home || tab == .sportCenter { return true }
        // 如果离开首页和竞技中心，必须登录
        if !userManager.isLoggedIn {
            //print("未登录，禁止切换tab")
            // 弹出登录页
            userManager.showingLogin = true
            return false
        }
        return true
    }
}

struct SportSelectionSidebar: View {
    @EnvironmentObject var appState: AppState
    @State var selectedSport: SportName = .Default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题区域
            VStack(alignment: .leading, spacing: 0) {
                Text("选择运动")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.top, 50)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 20)
                
                Text("查看最新的运动赛事")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                Divider()
                    .padding(.bottom, 10)
            }
            
            // 选项列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 15) {
                    ForEach(SportName.allCases.filter({ $0.isSupported })) { sport in
                        HStack {
                            Image(systemName: sport.iconName)
                            Text(LocalizedStringKey(sport.name))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(sport == selectedSport ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                        .foregroundStyle(sport == selectedSport ? Color.white : Color.secondText)
                        .cornerRadius(10)
                        .exclusiveTouchTapGesture {
                            selectedSport = sport
                            withAnimation(.easeIn(duration: 0.25)) {
                                appState.navigationManager.showSideBar = false
                                appState.sport = sport
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.defaultBackground)
        .onFirstAppear {
            selectedSport = appState.sport
        }
    }
}


#Preview{
    let appState = AppState.shared
    return NaviView()
        .environmentObject(appState)
        //.preferredColorScheme(.dark)
}
