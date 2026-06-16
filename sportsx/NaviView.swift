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

enum SportFeatureType: String {
    case race = "race"
    case freeTraining = "freeTraining"
    case routeTraining = "routeTraining"
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
            return "bike"
        case .Badminton:
            return "badminton"
        case .Default, .Running:
            return "running"
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

enum SportFeature: String, CaseIterable, Identifiable {
    
    // Bike
    case bikeRace
    case bikeFreeTraining
    case bikeRouteTraining
    
    // Running
    case runningRace
    case runningFreeTraining
    case runningRouteTraining
    
    var id: String { rawValue }
    
    var sportType: SportName {
        switch self {
        case .bikeRace, .bikeFreeTraining, .bikeRouteTraining:
            return .Bike
            
        case .runningRace, .runningFreeTraining, .runningRouteTraining:
            return .Running
        }
    }
    
    var featureType: SportFeatureType {
        switch self {
        case .bikeRace, .runningRace:
            return .race
        case .bikeFreeTraining, .runningFreeTraining:
            return .freeTraining
        case .bikeRouteTraining, .runningRouteTraining:
            return .routeTraining
        }
    }
    
    var icon: String {
        switch self {
        case .bikeRace: return "arena"
        case .bikeFreeTraining: return "free_training"
        case .bikeRouteTraining: return "route_training"
            
        case .runningRace: return "arena"
        case .runningFreeTraining: return "free_training"
        case .runningRouteTraining: return "route_training"
        }
    }
    
    var title: LocalizedStringKey {
        switch self {
        case .bikeRace: return "sport.feature.race"
        case .bikeFreeTraining: return "sport.feature.free_training"
        case .bikeRouteTraining: return "sport.feature.route_training"
            
        case .runningRace: return "sport.feature.race"
        case .runningFreeTraining: return "sport.feature.free_training"
        case .runningRouteTraining: return "sport.feature.route_training"
        }
    }
    
    static func features(for sport: SportName) -> [SportFeature] {
        Self.allCases.filter { $0.sportType == sport }
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
    @Environment(\.scenePhase) private var scenePhase
    
    // iOS16 可能会重复构建 @StateObject，所以暂时提出来统一放到 TabView 外层
    @StateObject var homeVM = HomeViewModel()
    @StateObject var sportCenterVM = CompetitionCenterViewModel()
    @StateObject var LocalUserVM = LocalUserViewModel()
    
    @ObservedObject var navigationManager = NavigationManager.shared    // 直接观察 NavigationManager 避免 appState 中转偶现的不更新问题
    @State private var isAppLaunching = true    // 用于区分冷启动和后台恢复

    var body: some View {
        NavigationStack(path: navigationManager.binding) {
            // 侧边栏抽屉容器：把高频变化的拖动状态隔离到 SidebarDrawer 内部，
            // 避免拖动每帧重算 RealNaviView.body（NavigationStack/TabView/navigationDestination 整棵树）
            SidebarDrawer {
                ZStack(alignment: .bottom) {
                    TabView(selection: $navigationManager.selectedTab) {
                        HomeView(viewModel: homeVM)
                            .tag(Tab.home)

                        ShopView()
                            .tag(Tab.shop)

                        SportCenterView(viewModel: sportCenterVM)
                            .tag(Tab.sportCenter)

                        StoreHouseView()
                            .tag(Tab.wareHouse)

                        LocalUserView(viewModel: LocalUserVM)
                            .tag(Tab.user)
                    }
                    .toolbar(.hidden, for: .navigationBar)

                    CustomTabBar()
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .onValueChange(of: scenePhase) { oldPhase, newPhase  in
                switch (oldPhase, newPhase) {
                case (_, .active):
                    if isAppLaunching {
                        isAppLaunching = false
                        UserDefaults.standard.set(Tab.home.rawValue, forKey: "SelectedTab")
                        return
                    }
                    
                    let rawValue = UserDefaults.standard.integer(forKey: "SelectedTab")
                    if let restoredTab = Tab(rawValue: rawValue) {
                        navigationManager.selectedTab = restoredTab
                        //print("后台恢复 Tab:", restoredTab)
                    }
                    
                    appState.competitionManager.syncWidgetVisibility()
                case (.active, _):
                    UserDefaults.standard.set(navigationManager.selectedTab.rawValue, forKey: "SelectedTab")
                    //print("设置后台 Tab:", navigationManager.selectedTab)
                default:
                    break
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .bikeRaceRecordDetailView(let rid):
                    BikeRaceRecordDetailView(recordID: rid)
                case .runningRaceRecordDetailView(let rid):
                    RunningRaceRecordDetailView(recordID: rid)
                case .bikeEventDetailView(let eid):
                    BikeEventDetailView(eventID: eid)
                case .runningEventDetailView(let eid):
                    RunningEventDetailView(eventID: eid)
                case .competitionCardSelectView:
                    CompetitionCardSelectView()
                case .competitionRealtimeView:
                    CompetitionRealtimeView()
                case .freeTrainingRealtimeView:
                    FreeTrainingRealtimeView()
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
                //case .realNameAuthView:
                //    RealNameAuthView()
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
                case .userCardDetailView(let cardID):
                    UserCardDetailView(cardID: cardID)
                case .shopCardDetailView(let defID):
                    ShopCardDetailView(defID: defID)
                case .privacyPanelView:
                    PrivacyPanelView()
                case .bikeTrainingRecordHistoryView:
                    BikeTrainingRecordHistoryView()
                case .runningTrainingRecordHistoryView:
                    RunningTrainingRecordHistoryView()
                case .bikeFreeTrainingRecordDetailView(let rid):
                    BikeFreeTrainingRecordDetailView(recordID: rid)
                case .runningFreeTrainingRecordDetailView(let rid):
                    RunningFreeTrainingRecordDetailView(recordID: rid)
                case .bikeTrainingMapView(let centerLat, let centerLng, let spanLat, let spanLng):
                    BikeTrainingMapView(centerLat: centerLat, centerLng: centerLng, spanLat: spanLat, spanLng: spanLng)
                case .runningTrainingMapView(let centerLat, let centerLng, let spanLat, let spanLng):
                    RunningTrainingMapView(centerLat: centerLat, centerLng: centerLng, spanLat: spanLat, spanLng: spanLng)
                case .bikeRouteCreateView:
                    BikeRouteCreateView()
                case .runningRouteCreateView:
                    RunningRouteCreateView()
                case .bikeRouteEditView(let route):
                    BikeRouteEditView(route: route)
                case .runningRouteEditView(let route):
                    RunningRouteEditView(route: route)
                case .routeEditorView(let id):
                    if let store = NavigationStoreManager.shared.resolve(id, as: RouteEditorStore.self) {
                        RouteEditorView()
                            .environmentObject(store)
                    } else {
                        EmptyView()
                    }
                case .bikeRouteManageView:
                    BikeRouteManageView()
                case .runningRouteManageView:
                    RunningRouteManageView()
                case .routeTrainingRealtimeView:
                    RouteTrainingRealtimeView()
                case .bikeRouteTrainingRecordDetailView(let rid):
                    BikeRouteTrainingRecordDetailView(recordID: rid)
                case .runningRouteTrainingRecordDetailView(let rid):
                    RunningRouteTrainingRecordDetailView(recordID: rid)
                case .bikeRouteRankListView(let id, let isPremium):
                    BikeRouteRankListView(routeID: id, isPremium: isPremium)
                case .runningRouteRankListView(let id, let isPremium):
                    RunningRouteRankListView(routeID: id, isPremium: isPremium)
                case .pendingUploadListView(let category, let sport):
                    PendingUploadListView(category: category, sport: sport)
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
                case .routeApplicationBackendView:
                    RouteApplicationBackendView()
                case .localDebugView:
                    LocalDebugPanelView()
#endif
                }
            }
        }
    }
}

/// 运动选择侧边栏抽屉容器。
///
/// 关键作用：把高频变化的拖动状态（`dragOffset`/`isDragging`）封装在本视图内部，
/// 使得拖动期间只重算 `SidebarDrawer.body`，而 `content`（整棵 TabView）由父视图构建一次后稳定复用，
/// 不再每帧重建 NavigationStack/TabView/navigationDestination，从根上消除拖动掉帧。
struct SidebarDrawer<Content: View>: View {
    @ObservedObject private var navigationManager = NavigationManager.shared
    @ObservedObject private var user = UserManager.shared

    @State private var dragOffset: CGFloat = 0     // 拖动进行中的实时水平位移
    @State private var isDragging = false          // 是否处于拖动中（拖动期间禁止内容/侧边栏交互）

    private let sidebarWidth: CGFloat = 300
    private let animation: Animation = .interactiveSpring(response: 0.3, dampingFraction: 0.85)
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    private let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // 主内容实际水平位移（0…sidebarWidth）
    private var contentOffset: CGFloat {
        let base = navigationManager.showSideBar ? sidebarWidth : 0
        return min(max(base + dragOffset, 0), sidebarWidth)
    }

    // 揭示进度 0…1，统一驱动视差与遮罩
    private var progress: CGFloat { contentOffset / sidebarWidth }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 底层：运动选择侧边栏（常驻被揭示，随进度做轻微视差）
            SportSelectionSidebar()
                .frame(width: sidebarWidth)
                .offset(x: -sidebarWidth * 0.25 * (1 - progress))
                .allowsHitTesting(navigationManager.showSideBar && !isDragging)

            // 上层：主内容整体右移以揭示下层侧边栏
            content
                .allowsHitTesting(!isDragging)
                .overlay(
                    // 遮罩：随揭示进度加深；展开时拦截点击以收起侧边栏。
                    // 必须放在 .offset 之前，使其随主内容一起右移，否则会盖住被揭示的侧边栏
                    Color.black
                        .opacity(0.5 * progress)
                        .ignoresSafeArea()
                        .allowsHitTesting(navigationManager.showSideBar && !isDragging)
                        .exclusiveTouchTapGesture {
                            withAnimation(animation) {
                                navigationManager.showSideBar = false
                            }
                        }
                )
                .offset(x: contentOffset)
                .shadow(color: .black.opacity(0.2 * progress), radius: 8, x: -4)
        }
        .overlay(
            // 全屏唤出/收起手势（自动让位给 ScrollView，仅运动中心根层生效）
            SidebarPanGesture(
                enabled: navigationManager.selectedTab == .sportCenter
                    && navigationManager.path.isEmpty
                    && !user.showingLogin,
                isOpen: navigationManager.showSideBar,
                onChanged: { translation in
                    if !isDragging { isDragging = true }
                    dragOffset = navigationManager.showSideBar ? min(0, translation) : max(0, translation)
                },
                onEnded: { translation, velocity in
                    isDragging = false
                    commit(translation: translation, velocity: velocity)
                }
            )
            .allowsHitTesting(false)
        )
        // 展开/收回（无论拖动、按钮、点遮罩、选 feature）统一给一次轻微震动
        .onValueChange(of: navigationManager.showSideBar) { _, _ in
            impactFeedback.impactOccurred()
        }
    }

    // 拖动结束后按位移/速度阈值吸附到展开或收起
    private func commit(translation: CGFloat, velocity: CGFloat) {
        let distanceThreshold: CGFloat = 150
        let velocityThreshold: CGFloat = 200
        let minThreshold: CGFloat = 20
        let openByDrag = !navigationManager.showSideBar
            && (translation > distanceThreshold
                || (translation > minThreshold && velocity > velocityThreshold))
        let closeByDrag = navigationManager.showSideBar
            && (translation < -distanceThreshold
                || (translation < -minThreshold && velocity < -velocityThreshold))
        withAnimation(animation) {
            if openByDrag { navigationManager.showSideBar = true }
            if closeByDrag { navigationManager.showSideBar = false }
            dragOffset = 0
        }
    }
}

struct CustomTabBar: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @ObservedObject private var userManager = UserManager.shared

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                /*(tab == navigationManager.selectedTab && tab == .sportCenter) ? (navigationManager.isTrainingView ? "训练中心" : "竞技中心") : */
                Text(tab.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(navigationManager.selectedTab == tab ? .white : .thirdText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
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
        //.border(.green)
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
    //@State var selectedSport: SportName = .Default
    @State var selectedFeature: SportFeature = .bikeRace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题区域
            VStack(alignment: .leading, spacing: 0) {
                Text("competition.slidebar.title")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.top, 50)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 20)
                
                Text("competition.slidebar.subtitle")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                //Rectangle()
                //    .foregroundStyle(Color.thirdText)
                //    .frame(height: 1)
            }
            
            // 选项列表
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(SportName.allCases.filter({ $0.isSupported })) { sport in
                        VStack {
                            HStack(spacing: 5) {
                                Image(sport.iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 20)
                                Text(LocalizedStringKey(sport.name))
                                    .font(.system(size: 15))
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.white)
                            }
                            .padding(.vertical, 10)
                            
                            let columns = Array(
                                repeating: GridItem(.flexible(), spacing: 10),
                                count: 3
                            )
                            
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(SportFeature.features(for: sport)) { feature in
                                    VStack(spacing: 10) {
                                        Image(feature.icon)
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 30)
                                        Text(feature.title)
                                            .font(.system(size: 18))
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.7)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 80)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(feature == selectedFeature ? Color.white : Color.thirdText)
                                    .background(feature == selectedFeature ? Color.white.opacity(0.4) : Color.clear)
                                    .cornerRadius(10)
                                    .contentShape(Rectangle())
                                    .exclusiveTouchTapGesture {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        selectedFeature = feature
                                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.85)) {
                                            appState.navigationManager.showSideBar = false
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            appState.sportFeature = feature
                                        }
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(10)
            }
        }
        .background(Color.defaultBackground)
        .onFirstAppear {
            selectedFeature = appState.sportFeature
        }
        .onValueChange(of: appState.sportFeature) { _, newState in
            selectedFeature = newState
        }
    }
}



#Preview {
    TestLaunchView()
}
