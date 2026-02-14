//
//  AppRootView.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/8.
//

import SwiftUI
import CoreLocation


struct UserView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    @StateObject var viewModel: UserViewModel
    
    //@State private var dragOffset: CGFloat = 0      // 当前拖动偏移量
    //@GestureState private var drag = CGFloat.zero   // 手势状态
    //@State private var isDragging: Bool = false     // 是否处于拖动中
    
    // 是否是已登陆用户
    var isUserSelf: Bool {
        if viewModel.userID != userManager.user.userID {
            return false
        } else {
            return true
        }
    }
    
    init(id: String) {
        _viewModel = StateObject(wrappedValue: UserViewModel(id: id))
    }
    
    var body: some View {
        // 无需返回场景支持右划弹出运动选择页
        // 返回场景支持左划弹出运动选择页,右划返回上一视图层级
        // 拖动手势暂不实现，因存在与ScrollView的手势冲突bug会引入空白区域填充
        GeometryReader { geometry in
            if let user = viewModel.currentUser {
                // 主内容
                ZStack {
                    MainUserView(viewModel: viewModel/*, dragOffset: $dragOffset*/, user: user, isUserSelf: isUserSelf)
                        .offset(x: (viewModel.showSidebar ? -viewModel.sidebarWidth : 0)/* + dragOffset*/)
                    // 放在MainUserView中偶现动画失效问题
                    Color.gray
                        .opacity(viewModel.showSidebar ? 0.5 : 0)
                        .ignoresSafeArea()
                        .allowsHitTesting(viewModel.showSidebar)
                        .exclusiveTouchTapGesture {
                            withAnimation(.easeIn(duration: 0.25)) {
                                viewModel.showSidebar = false
                            }
                        }
                }
                
                // 侧边栏
                UserSportSelectedBar(viewModel: viewModel, isUserSelf: isUserSelf)
                    .frame(width: viewModel.sidebarWidth)
                    .offset(x: (viewModel.showSidebar ? (UIScreen.main.bounds.width - viewModel.sidebarWidth) : UIScreen.main.bounds.width)/* + dragOffset*/)
            } else {
                VStack(spacing: 50) {
                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                                .frame(width: 20, height: 20)
                                .foregroundColor(.thirdText)
                                .padding(6)
                                .background(Color.gray.opacity(0.5))
                                .clipShape(Circle())
                                .exclusiveTouchTapGesture {
                                    appState.navigationManager.removeLast()
                                }
                            Rectangle()
                                .frame(height: 32)
                                .foregroundStyle(Color.gray.opacity(0.5))
                                .cornerRadius(16)
                        }
                        Rectangle()
                            .frame(height: 200)
                            .foregroundStyle(Color.gray.opacity(0.5))
                            .cornerRadius(20)
                    }
                    .padding(.horizontal)
                    Rectangle()
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
                .toolbar(.hidden, for: .navigationBar)
                .enableSwipeBackGesture()
                .ignoresSafeArea(edges: .bottom)
                .background(Color.defaultBackground)
            }
        }
        .onValueChange(of: viewModel.activeSport) {
            viewModel.queryHistoryCareers()
            viewModel.queryCurrentRecords()
        }
        .onValueChange(of: viewModel.selectedSeason) {
            viewModel.queryCareerData()
            viewModel.queryCareerRecords()
        }
        /*.allowsHitTesting(!isDragging)
        .disabled(isDragging)
        .gesture(
            DragGesture(minimumDistance: 10) // 设置最小拖动距离，防止误触
                .onChanged { _ in
                    isDragging = true
                }
                .updating($drag) { value, state, _ in
                    // 获取水平滑动的偏移量
                    let translation = value.translation.width
                    
                    // 为拖动添加阻尼效果
                    if viewModel.isNeedBack {
                        if !viewModel.showSidebar && translation < 0 {
                            // 当隐藏侧边栏时向左拖动打开侧边栏
                            dragOffset = max(translation * 0.95, -viewModel.sidebarWidth) // 限制最大拖动距离
                        } else if viewModel.showSidebar && translation > 0 {
                            // 当显示侧边栏时向右拖动收起侧边栏
                            dragOffset = min(translation * 0.95, viewModel.sidebarWidth)
                        }
                    } else {
                        if !viewModel.showSidebar && translation > 0 {
                            // 当隐藏侧边栏时向右拖动打开侧边栏
                            dragOffset = min(translation * 0.95, viewModel.sidebarWidth)
                        } else if viewModel.showSidebar && translation < 0 {
                            // 当显示侧边栏时向左拖动收起侧边栏
                            dragOffset = max(translation * 0.95, -viewModel.sidebarWidth)
                        }
                    }
                }
                .onEnded { value in
                    isDragging = false
                    // 计算拖动距离
                    let translation = value.translation.width
                    let distanceThreshold: CGFloat = 150  // 距离阈值，超过这个距离就触发动作
                    
                    // 速度阈值，单位是点/秒
                    let velocityThreshold: CGFloat = 200
                    let minThreshold: CGFloat = 20  // 最小距离阈值，即使速度很快也需要至少这么多距离
                    
                    // 根据距离或速度来判断是否切换侧边栏状态
                    if viewModel.isNeedBack {
                        if !viewModel.showSidebar && (translation < -distanceThreshold || (translation < -minThreshold && value.velocity.width < -velocityThreshold)) {
                            // 距离足够大或者速度足够快，打开侧边栏
                            withAnimation(.easeIn(duration: 0.3)) {
                                viewModel.showSidebar = true
                                dragOffset = 0
                            }
                        } else if !viewModel.showSidebar && (translation > distanceThreshold || (translation > minThreshold && value.velocity.width > velocityThreshold)) {
                            // 距离足够大或者速度足够快，返回导航上一页
                            appState.navigationManager.removeLast()
                        } else if viewModel.showSidebar && (translation > distanceThreshold || (translation > minThreshold && value.velocity.width > velocityThreshold)) {
                            // 距离足够大或者速度足够快，收起侧边栏
                            withAnimation(.easeIn(duration: 0.3)) {
                                viewModel.showSidebar = false
                                dragOffset = 0
                            }
                        } else {
                            // 不满足上述条件，回到原位
                            withAnimation(.easeIn(duration: 0.1)) {
                                dragOffset = 0
                            }
                        }
                    } else {
                        if !viewModel.showSidebar && (translation > distanceThreshold || (translation > minThreshold && value.velocity.width > velocityThreshold)) {
                            // 距离足够大或者速度足够快，打开侧边栏
                            withAnimation(.easeIn(duration: 0.3)) {
                                viewModel.showSidebar = true
                                dragOffset = 0
                            }
                        } else if viewModel.showSidebar && (translation < -distanceThreshold || (translation < -minThreshold && value.velocity.width < -velocityThreshold)) {
                            // 距离足够大或者速度足够快，收起侧边栏
                            withAnimation(.easeIn(duration: 0.3)) {
                                viewModel.showSidebar = false
                                dragOffset = 0
                            }
                        } else {
                            // 不满足上述条件，回到原位
                            withAnimation(.easeIn(duration: 0.1)) {
                                dragOffset = 0
                            }
                        }
                    }
                }
        )*/
    }
}

struct MainUserView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: UserViewModel
    @ObservedObject private var userManager = UserManager.shared
    
    @State private var selectedTab = 0
    @State private var toolbarTop: CGFloat = 0
    @State private var isDragging: Bool = false     // 是否处于拖动中
    @State private var showMoreSheet: Bool = false
    //@Binding var dragOffset: CGFloat
    let user: User
    let isUserSelf: Bool
    
    //@State private var tabHeights: [Int: CGFloat] = [:]
    //var currentTabHeight: CGFloat {
    //    return maxheight = max(tabHeights.values.max() ?? 0, 300)
    //}
    
    var userRegion: LocalizedStringKey? {
        for (_, cities) in regionTable_TW {
            if let index = cities.firstIndex(where: { $0.regionID == user.location }) {
                return LocalizedStringKey(cities[index].regionName)
            }
        }
        for (_, cities) in regionTable_HK {
            if let index = cities.firstIndex(where: { $0.regionID == user.location }) {
                return LocalizedStringKey(cities[index].regionName)
            }
        }
        for (_, cities) in regionTable_CN {
            if let index = cities.firstIndex(where: { $0.regionID == user.location }) {
                return LocalizedStringKey(cities[index].regionName)
            }
        }
        return nil
    }
    
    var body: some View {
        // 主内容视图
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            (isUserSelf ? userManager.backgroundColor : viewModel.backgroundColor).softenColor(blendWithWhiteRatio: 0.2),
                            isUserSelf ? userManager.backgroundColor : viewModel.backgroundColor
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 用户信息区
                        ZStack(alignment: .top) {
                            VStack(spacing: 0) {
                                // 背景图片
                                if let background = isUserSelf ? userManager.backgroundImage : viewModel.backgroundImage {
                                    Image(uiImage: background)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width - 32, height: 200)
                                        .cornerRadius(20)
                                } else {
                                    Image("placeholder")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width - 32, height: 200)
                                        .cornerRadius(20)
                                }
                                
                                // 资料展示区
                                VStack(spacing: 16) {
                                    // 数据统计区域
                                    HStack(spacing: 0) {
                                        // 互关
                                        VStack(spacing: 2) {
                                            Text(isUserSelf ? "\(userManager.friendCount)" : "\(viewModel.friendCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("user.page.friend")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: viewModel.userID, selectedTab: 0))
                                        }
                                        
                                        // 关注
                                        VStack(spacing: 2) {
                                            Text(isUserSelf ? "\(userManager.followedCount)" : "\(viewModel.followedCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("user.page.following")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .padding(.leading, 30)
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: viewModel.userID, selectedTab: 1))
                                        }
                                        
                                        // 粉丝
                                        VStack(spacing: 2) {
                                            Text(isUserSelf ? "\(userManager.followerCount)" : "\(viewModel.followerCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("user.page.follower")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .padding(.leading, 30)
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: viewModel.userID, selectedTab: 2))
                                        }
                                        
                                        Spacer()
                                        
                                        if isUserSelf {
                                            Text("user.page.edit")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 20)
                                                .background(.ultraThinMaterial)
                                                .cornerRadius(8)
                                                .exclusiveTouchTapGesture {
                                                    appState.navigationManager.append(.userIntroEditView)
                                                }
                                        } else {
                                            if viewModel.relationship == .follower || viewModel.relationship == .none {
                                                Text("user.page.follow")
                                                    .font(.system(size: 16))
                                                    .bold()
                                                    .foregroundColor(.white)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 20)
                                                    .background(.pink.opacity(0.8))
                                                    .cornerRadius(8)
                                                    .exclusiveTouchTapGesture {
                                                        viewModel.follow()
                                                    }
                                            } else {
                                                Text("user.page.cancel_follow")
                                                    .font(.system(size: 16))
                                                    .bold()
                                                    .foregroundColor(.white)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 20)
                                                    .background(.white.opacity(0.4))
                                                    .cornerRadius(8)
                                                    .exclusiveTouchTapGesture {
                                                        viewModel.cancelFollow()
                                                    }
                                            }
                                        }
                                    }
                                    .padding(.top, 30)
                                    .padding(.bottom, 10)
                                    .padding(.leading, 20)
                                    .padding(.trailing, 15)
                                    
                                    // 个人说明
                                    VStack(alignment: .leading, spacing: 12) {
                                        if isUserSelf {
                                            if let intro = userManager.user.introduction {
                                                Text(intro)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                            } else {
                                                HStack {
                                                    Text("user.page.introduce_placeholder")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(Color.secondText)
                                                    Image(systemName: "pencil.line")
                                                        .foregroundStyle(Color.secondText)
                                                }
                                                .exclusiveTouchTapGesture {
                                                    appState.navigationManager.append(.userIntroEditView)
                                                }
                                            }
                                        } else {
                                            if let intro = user.introduction {
                                                Text(intro)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        
                                        HStack {
                                            if user.isDisplayGender == true, let gender = user.gender {
                                                Text(gender.rawValue)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if user.isDisplayAge == true, let age = AgeDisplay.calculateAge(from: user.birthday ?? "xxxx-xx-xx") {
                                                Text("time.year_old \(age)")
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if user.isDisplayLocation == true, let region = userRegion {
                                                Text(region)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if user.isDisplayIdentity == true, let identity = user.identityAuthName {
                                                Text(identity)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            Spacer()
                                        }
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                    }
                                    .padding(.horizontal, 16)
                                    //.border(.red)
                                }
                                .padding(.top, 20)
                                .padding(.bottom, 12)
                                //.border(.red)
                            }
                            //.border(.orange)
                            
                            // 头像和用户名区域
                            VStack {
                                // 头像
                                if let avatar = isUserSelf ? userManager.avatarImage : viewModel.avatarImage {
                                    Image(uiImage: avatar)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                        .shadow(radius: 5, x: 0, y: 5)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .foregroundStyle(.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 5, x: 0, y: 5)
                                }
                                // 用户名
                                HStack {
                                    Text(isUserSelf ? userManager.user.nickname : user.nickname)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    if isUserSelf ? userManager.user.isVip : user.isVip {
                                        Image("vip_icon_on")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 20)
                                    }
                                    if (!isUserSelf) && viewModel.relationship != .none {
                                        Text(LocalizedStringKey(viewModel.relationship.displayName))
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 6)
                                            .background(Color.orange.opacity(0.6))
                                            .cornerRadius(5)
                                    }
                                }
                            }
                            .padding(.top, 120)
                            //.border(.green)
                        }
                        .padding(.top, 56)
                        //.border(.red)
                        
                        // 功能模块区
                        if isUserSelf {
                            HStack(spacing: 0) {
                                // 设备绑定模块
                                VStack(spacing: 6) {
                                    Image("device_bind")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28)
                                    Text("user.page.features.bind_device")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                //.border(.orange)
                                .opacity(opacityFor(offset: toolbarTop))
                                .exclusiveTouchTapGesture {
                                    appState.navigationManager.append(.sensorBindView)
                                }
                                
                                // 研究所模块
                                VStack(spacing: 6) {
                                    Image("institute")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28)
                                    Text("user.page.features.institute")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                //.border(.yellow)
                                .opacity(opacityFor(offset: toolbarTop))
                                .exclusiveTouchTapGesture {
                                    appState.navigationManager.append(.instituteView)
                                }
                                
                                // 邮箱模块
                                VStack(spacing: 6) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                        if userManager.mailboxUnreadCount != 0 {
                                            Image(systemName: "circle.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.red)
                                                .offset(x: 5, y: -5)
                                        }
                                    }
                                    Text("user.page.features.email_box")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .opacity(opacityFor(offset: toolbarTop))
                                .exclusiveTouchTapGesture {
                                    appState.navigationManager.append(.mailBoxView)
                                }
                                .onStableAppear {
                                    if GlobalConfig.shared.refreshMailStatus {
                                        userManager.queryMailBox()
                                        GlobalConfig.shared.refreshMailStatus = false
                                    }
                                }
                                
                                // 预留三个空位，保证总共5个位置
                                ForEach(0..<2) { _ in
                                    Spacer()
                                        .frame(maxWidth: .infinity)
                                    //.border(.red)
                                }
                            }
                            .padding(.vertical, 15)
                            //.border(.pink)
                        }
                        
                        // 选项卡栏
                        ZStack(alignment: .top) {
                            HStack(spacing: 0) {
                                Text("user.page.tab.career")
                                    .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundStyle(selectedTab == 0 ? Color.white : Color.clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 0
                                    }
                                
                                Text("user.page.tab.current_record")
                                    .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundStyle(selectedTab == 1 ? Color.white : Color.clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 1
                                    }
                            }
                            
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { updateOffset(geo) }
                                    .onValueChange(of: geo.frame(in: .global).minY) {
                                        updateOffset(geo)
                                    }
                            }
                            .frame(height: 0) // 避免占空间
                        }
                        
                        Divider()
                        
                        if user.status == .normal {
                            if selectedTab == 0 {
                                CareerView(viewModel: viewModel)
                            } else {
                                GameSummaryView(viewModel: viewModel)
                            }
                        } else if user.status == .banned {
                            Text("user.page.account_status.banned")
                                .foregroundStyle(Color.secondText)
                                .padding(.top, 100)
                        } else {
                            Text("user.page.account_status.deleted")
                                .foregroundStyle(Color.secondText)
                                .padding(.top, 100)
                        }
                    }
                    //.padding(.bottom, 100)
                    .onScrollDragChanged($isDragging)
                }
                
                // 顶部操作栏
                GeometryReader { geo in
                    let topSafeArea = geo.safeAreaInsets.top
                    VStack(spacing: 0) {
                        VStack {
                            Spacer()
                            
                            ZStack {
                                HStack(alignment: .center, spacing: 15) {
                                    Image(systemName: "chevron.left")
                                        .fontWeight(.semibold)
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                        .clipShape(Circle())
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.removeLast()
                                        }
                                    
                                    Spacer()
                                    
                                    if !isUserSelf {
                                        Image(systemName: "ellipsis")
                                            .fontWeight(.semibold)
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                            .clipShape(Circle())
                                            .exclusiveTouchTapGesture {
                                                showMoreSheet = true
                                            }
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Image(viewModel.sport.iconName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 20)
                                        Image("sport_selected_side_bar_button")
                                            .resizable()
                                            .scaledToFit()
                                            .scaleEffect(x: -1, y: 1)
                                            .frame(width: 20, height: 20)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                    .cornerRadius(18)
                                    .foregroundColor(.white)
                                    .exclusiveTouchTapGesture {
                                        if !isDragging {
                                            withAnimation(.easeIn(duration: 0.25)) {
                                                viewModel.showSidebar = true
                                            }
                                        }
                                    }
                                }
                                //.border(.red)
                                
                                Text(user.nickname)
                                    .bold()
                                    .foregroundStyle(.white)
                                    .opacity(1 - opacityFor(offset: toolbarTop))
                                //.border(.green)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 5)
                        .frame(height: 45 + topSafeArea)
                        .background((isUserSelf ? userManager.backgroundColor : viewModel.backgroundColor).opacity(1 - opacityFor(offset: toolbarTop)))
                        //.border(.blue)
                        
                        if toolbarTop <= 45 + topSafeArea {
                            HStack(spacing: 0) {
                                Text("user.page.tab.career")
                                    .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundStyle(selectedTab == 0 ? Color.white : Color.clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 0
                                    }
                                
                                Text("user.page.tab.current_record")
                                    .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundStyle(selectedTab == 1 ? Color.white : Color.clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 1
                                    }
                            }
                            .background(isUserSelf ? userManager.backgroundColor : viewModel.backgroundColor)
                            //.border(.pink)
                            Divider()
                        }
                        Spacer()
                    }
                    //.border(.green)
                    .ignoresSafeArea()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .sheet(isPresented: $showMoreSheet) {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                        .clipShape(Circle())
                        .exclusiveTouchTapGesture {
                            showMoreSheet = false
                        }
                }
                HStack(spacing: 5) {
                    if let avatar = viewModel.avatarImage {
                        Image(uiImage: avatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                    Text(user.nickname)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                Text("action.report")
                    .foregroundStyle(Color.white)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.6))
                    .cornerRadius(10)
                    .exclusiveTouchTapGesture {
                        showMoreSheet = false
                        appState.navigationManager.append(.feedbackView(mailType: .report, reportUserID: user.userID))
                    }
                Spacer()
            }
            .padding()
            .background(Color.defaultBackground)
            .presentationDetents([.fraction(0.3)])
        }
    }
    
    func updateOffset(_ geo: GeometryProxy) {
        DispatchQueue.main.async {
            toolbarTop = geo.frame(in: .global).minY
        }
    }
    
    func opacityFor(offset: CGFloat) -> Double {
        let visibleUntil: CGFloat = 110
        return max(0, min(1, offset / visibleUntil - 1))
    }
}

struct LocalUserView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var viewModel: LocalUserViewModel
    
    var body: some View {
        GeometryReader { geometry in
            // 主内容
            ZStack {
                LocalMainUserView(viewModel: viewModel)
                    .offset(x: (viewModel.showSidebar ? viewModel.sidebarWidth : 0))
                // 放在MainUserView中偶现动画失效问题
                Color.gray
                    .opacity(viewModel.showSidebar ? 0.5 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(viewModel.showSidebar)
                    .exclusiveTouchTapGesture {
                        withAnimation(.easeIn(duration: 0.25)) {
                            viewModel.showSidebar = false
                        }
                    }
            }
            
            // 侧边栏
            LocalUserSportSelectedBar(viewModel: viewModel)
                .frame(width: viewModel.sidebarWidth)
                .offset(x: (viewModel.showSidebar ? 0 : -viewModel.sidebarWidth))
        }
        .onValueChange(of: viewModel.activeSport) {
            viewModel.queryHistoryCareers()
            viewModel.queryCurrentRecords()
            DailyTaskManager.shared.queryDailyTask(sport: viewModel.activeSport)
        }
        .onValueChange(of: viewModel.selectedSeason) {
            viewModel.queryCareerData()
            viewModel.queryCareerRecords()
        }
        .onValueChange(of: userManager.isLoggedIn) {
            if userManager.isLoggedIn {
                Task {
                    await userManager.fetchMeInfo()
                    await MainActor.run {
                        userManager.queryMailBox()
                        if viewModel.activeSport == userManager.user.defaultSport {
                            viewModel.queryHistoryCareers()
                            viewModel.queryCurrentRecords()
                            DailyTaskManager.shared.queryDailyTask(sport: viewModel.activeSport)
                        } else {
                            viewModel.sport = userManager.user.defaultSport
                            viewModel.activeSport = viewModel.sport
                        }
                    }
                }
            }
        }
    }
}

struct LocalMainUserView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: LocalUserViewModel
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject private var dailyTaskManager = DailyTaskManager.shared
    
    @State private var selectedTab = 0
    @State private var toolbarTop: CGFloat = 0
    @State private var isDragging: Bool = false     // 是否处于拖动中
    
    
    var body: some View {
        // 主内容视图
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            userManager.backgroundColor.softenColor(blendWithWhiteRatio: 0.2),
                            userManager.backgroundColor
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 用户信息区
                        ZStack(alignment: .top) {
                            VStack(spacing: 0) {
                                // 背景图片
                                if let background = userManager.backgroundImage {
                                    Image(uiImage: background)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width - 32, height: 200)
                                        .cornerRadius(20)
                                } else {
                                    Image("placeholder")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width - 32, height: 200)
                                        .cornerRadius(20)
                                }
                                
                                // 资料展示区
                                VStack(spacing: 16) {
                                    // 数据统计区域
                                    HStack(spacing: 0) {
                                        // 互关
                                        VStack(spacing: 2) {
                                            Text("\(userManager.friendCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("user.page.friend")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: userManager.user.userID, selectedTab: 0))
                                        }
                                        
                                        // 关注
                                        VStack(spacing: 2) {
                                            Text("\(userManager.followedCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("user.page.following")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .padding(.leading, 30)
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: userManager.user.userID, selectedTab: 1))
                                        }
                                        
                                        // 粉丝
                                        VStack(spacing: 2) {
                                            Text("\(userManager.followerCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("user.page.follower")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .padding(.leading, 30)
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: userManager.user.userID, selectedTab: 2))
                                        }
                                        
                                        Spacer()
                                        
                                        Text("user.page.edit")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 20)
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(8)
                                            .exclusiveTouchTapGesture {
                                                appState.navigationManager.append(.userIntroEditView)
                                            }
                                    }
                                    .padding(.top, 30)
                                    .padding(.bottom, 10)
                                    .padding(.leading, 20)
                                    .padding(.trailing, 15)
                                    
                                    // 个人说明
                                    VStack(alignment: .leading, spacing: 12) {
                                        if let intro = userManager.user.introduction {
                                            Text(intro)
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                        } else {
                                            HStack {
                                                Text("user.page.introduce_placeholder")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color.secondText)
                                                Image(systemName: "pencil.line")
                                                    .foregroundStyle(Color.secondText)
                                            }
                                            .exclusiveTouchTapGesture {
                                                appState.navigationManager.append(.userIntroEditView)
                                            }
                                        }
                                        
                                        HStack {
                                            if userManager.user.isDisplayGender == true, let gender = userManager.user.gender {
                                                Text(gender.rawValue)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if userManager.user.isDisplayAge == true, let age = AgeDisplay.calculateAge(from: userManager.user.birthday ?? "xxxx-xx-xx") {
                                                Text(LocalizedStringKey("time.year_old \(age)"))
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if userManager.user.isDisplayLocation == true, let region = userManager.userRegion {
                                                Text(region)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if userManager.user.isDisplayIdentity == true, let identity = userManager.user.identityAuthName {
                                                Text(identity)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            Spacer()
                                        }
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .padding(.top, 20)
                                .padding(.bottom, 12)
                            }
                            
                            // 头像和用户名区域
                            VStack {
                                // 头像
                                if let avatar = userManager.avatarImage {
                                    Image(uiImage: avatar)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                        .shadow(radius: 5, x: 0, y: 5)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .foregroundStyle(.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 5, x: 0, y: 5)
                                }
                                // 用户名
                                HStack {
                                    Text(userManager.user.nickname)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Image(userManager.user.isVip ? "vip_icon_on" : "vip_icon_off")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 20)
                                        .exclusiveTouchTapGesture {
                                            guard UserManager.shared.isLoggedIn else {
                                                UserManager.shared.showingLogin = true
                                                return
                                            }
                                            appState.navigationManager.append(.subscriptionDetailView)
                                        }
                                }
                            }
                            .padding(.top, 120)
                        }
                        .padding(.top, 56)
                        
                        // 功能模块区
                        HStack(alignment: .bottom, spacing: 0) {
                            // 设备绑定模块
                            VStack(spacing: 6) {
                                Image("device_bind")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28)
                                Text("user.page.features.bind_device")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .opacity(opacityFor(offset: toolbarTop))
                            .exclusiveTouchTapGesture {
                                appState.navigationManager.append(.sensorBindView)
                            }
                            
                            // 研究所模块
                            VStack(spacing: 6) {
                                Image("institute")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28)
                                Text("user.page.features.institute")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .opacity(opacityFor(offset: toolbarTop))
                            .exclusiveTouchTapGesture {
                                appState.navigationManager.append(.instituteView)
                            }
                            
                            // 邮箱模块
                            VStack(spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    if userManager.mailboxUnreadCount != 0 {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.red)
                                            .offset(x: 5, y: -5)
                                    }
                                }
                                Text("user.page.features.email_box")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .opacity(opacityFor(offset: toolbarTop))
                            .exclusiveTouchTapGesture {
                                appState.navigationManager.append(.mailBoxView)
                            }
                            .onStableAppear {
                                if GlobalConfig.shared.refreshMailStatus {
                                    userManager.queryMailBox()
                                    GlobalConfig.shared.refreshMailStatus = false
                                }
                            }
                            
                            // 预留三个空位，保证总共5个位置
                            ForEach(0..<2) { _ in
                                Spacer()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 15)
                        
                        // 每日任务
                        if let task = dailyTaskManager.task {
                            VStack {
                                VStack(spacing: 0) {
                                    HStack {
                                        Spacer()
                                        Text("user.page.dailytask")
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    
                                    HStack(spacing: 0) {
                                        if task.taskType == .distance {
                                            Text("user.page.dailytask.distance")
                                        } else {
                                            Text("user.page.dailytask.time")
                                        }
                                        Spacer()
                                        if task.taskType == .distance {
                                            Text("distance.km.a/b \(task.progress) \(task.totalProgress)") + Text(LocalizedStringKey(task.taskType.disPlayName))
                                        } else {
                                            Text("time.minute.a/b \(task.progress / 60) \(task.totalProgress / 60)") + Text(LocalizedStringKey(task.taskType.disPlayName))
                                        }
                                    }
                                    .font(.subheadline)
                                    .padding(.top, 20)
                                    .padding(.horizontal, 10)
                                    
                                    ZStack {
                                        // 进度条
                                        ZStack(alignment: .leading) {
                                            // 背景
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white.opacity(0.25))
                                                .frame(width: 280, height: 10)
                                            // 前景
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: min(280, max(0, (task.progress / task.totalProgress)) * 280), height: 10)
                                        }
                                        
                                        // 3个可领取奖励的圆形节点
                                        HStack {
                                            Circle()
                                                .foregroundStyle(Color.orange.opacity(0.8))
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Image(viewModel.activeSport.iconName)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(height: 25)
                                                )
                                            Spacer()
                                            ZStack {
                                                HStack(alignment: .center, spacing: 2) {
                                                    Image(task.reward_stage1_type.iconName)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 20)
                                                    Text("+\(task.reward_stage1)")
                                                }
                                                .font(.subheadline)
                                                .frame(width: 60)
                                                .offset(y: 40)
                                                Circle()
                                                    .foregroundStyle(
                                                        task.reward_stage1_status.color
                                                    )
                                                    .frame(width: 40, height: 40)
                                                    .overlay(
                                                        task.reward_stage1_status.icon
                                                            .fontWeight(.semibold)
                                                    )
                                            }
                                            .onTapGesture {
                                                if (!dailyTaskManager.reward1Loading) && task.reward_stage1_status == .available {
                                                    dailyTaskManager.claimReward(stage: 1, sport: viewModel.activeSport, rewardImage: task.reward_stage1_type.iconName, rewardCount: task.reward_stage1)
                                                }
                                            }
                                            Spacer()
                                            ZStack {
                                                HStack(alignment: .center, spacing: 2) {
                                                    Image(task.reward_stage2_type.iconName)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 20)
                                                    Text("+\(task.reward_stage2)")
                                                }
                                                .font(.subheadline)
                                                .frame(width: 60)
                                                .offset(y: 40)
                                                Circle()
                                                    .foregroundStyle(
                                                        task.reward_stage2_status.color
                                                    )
                                                    .frame(width: 40, height: 40)
                                                    .overlay(
                                                        task.reward_stage2_status.icon
                                                            .fontWeight(.semibold)
                                                    )
                                            }
                                            .onTapGesture {
                                                if (!dailyTaskManager.reward2Loading) && task.reward_stage2_status == .available {
                                                    dailyTaskManager.claimReward(stage: 2, sport: viewModel.activeSport, rewardImage: task.reward_stage2_type.iconName, rewardCount: task.reward_stage2)
                                                }
                                            }
                                            Spacer()
                                            ZStack {
                                                CachedAsyncImage(
                                                    urlString: task.reward_stage3_url
                                                )
                                                .id(task.reward_stage3_url)     // 强制重建视图
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 30, height: 30)
                                                .clipped()
                                                .offset(y: 40)
                                                Circle()
                                                    .foregroundStyle(
                                                        task.reward_stage3_status.color
                                                    )
                                                    .frame(width: 40, height: 40)
                                                    .overlay(
                                                        task.reward_stage3_status.icon
                                                            .fontWeight(.semibold)
                                                    )
                                            }
                                            .onTapGesture {
                                                if (!dailyTaskManager.reward3Loading) && task.reward_stage3_status == .available {
                                                    dailyTaskManager.claimReward(stage: 3, sport: viewModel.activeSport, rewardCount: 1, rewardURL: task.reward_stage3_url)
                                                }
                                            }
                                        }
                                        .frame(width: 320)
                                    }
                                    .padding(.top, 10)
                                    
                                    HStack(spacing: 4) {
                                        Text("user.page.dailytask.go_complete")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline)
                                    .offset(y: 40)
                                    .exclusiveTouchTapGesture {
                                        appState.sport = viewModel.activeSport
                                        appState.navigationManager.selectedTab = .sportCenter
                                    }
                                }
                                .foregroundStyle(Color.secondText)
                                .padding(.top, 10)
                                .padding(.bottom, 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.orange.opacity(0.8), lineWidth: 3)
                                        .background(Color.white.opacity(0.2))
                                )
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        }
                        
                        // 选项卡栏
                        ZStack(alignment: .top) {
                            HStack(spacing: 0) {
                                Text("user.page.tab.career")
                                    .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundStyle(selectedTab == 0 ? Color.white : Color.clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 0
                                    }
                                
                                Text("user.page.tab.current_record")
                                    .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundStyle(selectedTab == 1 ? Color.white : Color.clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 1
                                    }
                            }
                            
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { updateOffset(geo) }
                                    .onValueChange(of: geo.frame(in: .global).minY) {
                                        updateOffset(geo)
                                    }
                            }
                            .frame(height: 0) // 避免占空间
                        }
                        
                        Divider()
                        
                        if selectedTab == 0 {
                            LocalCareerView(viewModel: viewModel)
                        } else {
                            LocalGameSummaryView(viewModel: viewModel)
                        }
                    }
                    .padding(.bottom, 100)
                    .onScrollDragChanged($isDragging)
                }
                
                // 顶部操作栏
                GeometryReader { geo in
                    let topSafeArea = geo.safeAreaInsets.top
                    VStack(spacing: 0) {
                        VStack {
                            Spacer()
                            
                            //ZStack {
                                HStack(alignment: .center, spacing: 15) {
                                    HStack(spacing: 4) {
                                        Image("sport_selected_side_bar_button")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                        Image(viewModel.sport.iconName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 20)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                    .cornerRadius(18)
                                    .foregroundColor(.white)
                                    .exclusiveTouchTapGesture {
                                        if !isDragging {
                                            withAnimation(.easeIn(duration: 0.25)) {
                                                viewModel.showSidebar = true
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if !userManager.user.isRealnameAuth {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.circle")
                                                .foregroundStyle(Color.pink)
                                                .frame(width: 20, height: 20)
                                            Text("user.setup.realname_auth.undone.2")
                                                .font(.system(size: 18))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                        .cornerRadius(18)
                                        .foregroundColor(.white)
                                        .exclusiveTouchTapGesture {
                                            PopupWindowManager.shared.presentPopup(
                                                title: "user.setup.realname_auth.undone",
                                                message: "user.setup.realname_auth.popup.no_auth",
                                                bottomButtons: [
                                                    .confirm("user.intro.go_auth") {
                                                        appState.navigationManager.append(.realNameAuthView)
                                                    }
                                                ]
                                            )
                                        }
                                    }
                                    
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                        .clipShape(Circle())
                                        .exclusiveTouchTapGesture {
                                            //if !isDragging {
                                            appState.navigationManager.append(.userSetUpView)
                                            //}
                                        }
                                }
                                
                                //Text(userManager.user.nickname)
                                //    .bold()
                                //    .foregroundStyle(.white)
                                //    .opacity(1 - opacityFor(offset: toolbarTop))
                            //}
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 5)
                        .frame(height: 45 + topSafeArea)
                        .background(userManager.backgroundColor.opacity(1 - opacityFor(offset: toolbarTop)))
                        
                        if toolbarTop <= 45 + topSafeArea {
                            HStack(spacing: 0) {
                                Text("user.page.tab.career")
                                    .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundStyle(selectedTab == 0 ? Color.white : Color.clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 0
                                    }
                                
                                Text("user.page.tab.current_record")
                                    .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundStyle(selectedTab == 1 ? Color.white : Color.clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 1
                                    }
                            }
                            .background(userManager.backgroundColor)
                            Divider()
                        }
                        Spacer()
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }
    
    func updateOffset(_ geo: GeometryProxy) {
        DispatchQueue.main.async {
            toolbarTop = geo.frame(in: .global).minY
        }
    }
    
    func opacityFor(offset: CGFloat) -> Double {
        let visibleUntil: CGFloat = 110
        return max(0, min(1, offset / visibleUntil - 1))
    }
}

struct UserSportSelectedBar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var viewModel: UserViewModel
    @State var isEditMode: Bool = false
    let isUserSelf: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题区域
            VStack(alignment: .leading, spacing: 0) {
                Text("user.sidebar.select_sport")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.top, 50)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 20)
                
                if isUserSelf {
                    HStack(spacing: 0) {
                        if !isEditMode {
                            Text("user.sidebar.default_sport")
                            Text(LocalizedStringKey(userManager.user.defaultSport.name))
                        }
                        Spacer()
                        Text(isEditMode ? "action.cencal_edit" : "action.edit")
                            .exclusiveTouchTapGesture {
                                isEditMode.toggle()
                            }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondText)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                
                Divider()
                    .padding(.bottom, 10)
            }
            
            // 选项列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 15) {
                    ForEach(SportName.allCases.filter({ $0.isSupported })) { sport in
                        HStack {
                            Image(sport.iconName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 30)
                            Text(LocalizedStringKey(sport.name))
                            if isEditMode {
                                Image(systemName: "circle.dotted")
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background((sport == viewModel.sport && (!isEditMode)) ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                        .foregroundStyle((sport == viewModel.sport && (!isEditMode)) ? Color.white : Color.thirdText)
                        .cornerRadius(10)
                        .exclusiveTouchTapGesture {
                            if isEditMode {
                                updateUserDefaultSport(with: sport)
                            } else {
                                viewModel.sport = sport
                                withAnimation(.easeIn(duration: 0.25)) {
                                    viewModel.showSidebar = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    viewModel.activeSport = sport
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .background(viewModel.backgroundColor)
        .onValueChange(of: viewModel.showSidebar) {
            if !viewModel.showSidebar {
                isEditMode = false
            }
        }
    }
    
    func updateUserDefaultSport(with sport: SportName) {
        guard var components = URLComponents(string: "/user/update_user_default_sport") else { return }
        components.queryItems = [
            URLQueryItem(name: "sport", value: sport.rawValue)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: SportName.self, showErrorToast: true) {result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        userManager.user.defaultSport = unwrappedData
                        UserDefaults.standard.set(sport.rawValue, forKey: "user.defaultSport")
                        isEditMode = false
                    }
                }
            default: break
            }
        }
    }
}

struct LocalUserSportSelectedBar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var viewModel: LocalUserViewModel
    @State var isEditMode: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题区域
            VStack(alignment: .leading, spacing: 0) {
                Text("user.sidebar.select_sport")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.top, 50)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 20)
                
                HStack {
                    if !isEditMode {
                        Text("user.sidebar.default_sport")
                        Text(LocalizedStringKey(userManager.user.defaultSport.name))
                    }
                    Spacer()
                    Text(isEditMode ? "action.cancel_edit" : "action.edit")
                        .exclusiveTouchTapGesture {
                            isEditMode.toggle()
                        }
                }
                .font(.subheadline)
                .foregroundColor(.secondText)
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
                            Image(sport.iconName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 30)
                            Text(LocalizedStringKey(sport.name))
                            if isEditMode {
                                Image(systemName: "circle.dotted")
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background((sport == viewModel.sport && (!isEditMode)) ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                        .foregroundStyle((sport == viewModel.sport && (!isEditMode)) ? Color.white : Color.thirdText)
                        .cornerRadius(10)
                        .exclusiveTouchTapGesture {
                            if isEditMode {
                                updateUserDefaultSport(with: sport)
                            } else {
                                viewModel.sport = sport
                                withAnimation(.easeIn(duration: 0.25)) {
                                    viewModel.showSidebar = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    viewModel.activeSport = sport
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(userManager.backgroundColor)
        .onValueChange(of: viewModel.showSidebar) {
            if !viewModel.showSidebar {
                isEditMode = false
            }
        }
    }
    
    func updateUserDefaultSport(with sport: SportName) {
        guard var components = URLComponents(string: "/user/update_user_default_sport") else { return }
        components.queryItems = [
            URLQueryItem(name: "sport", value: sport.rawValue)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: SportName.self, showErrorToast: true) {result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        userManager.user.defaultSport = unwrappedData
                        UserDefaults.standard.set(sport.rawValue, forKey: "user.defaultSport")
                        isEditMode = false
                    }
                }
            default: break
            }
        }
    }
}

/*struct TabContentHeightKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: max)
    }
}

extension View {
    func measureHeight(for index: Int) -> some View {
        self.background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: TabContentHeightKey.self, value: [index: proxy.size.height])
            }
        )
    }
}*/

#Preview {
    let appState = AppState.shared
    let userManager = UserManager.shared
    let vm = LocalUserViewModel()
    
    LocalUserView(viewModel: vm)
        .environmentObject(appState)
}
