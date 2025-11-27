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
            // 主内容
            ZStack {
                MainUserView(viewModel: viewModel/*, dragOffset: $dragOffset*/, isUserSelf: isUserSelf)
                    .offset(x: (viewModel.showSidebar ? -viewModel.sidebarWidth : 0)/* + dragOffset*/)
                // 放在MainUserView中偶现动画失效问题
                Color.gray
                    .opacity(viewModel.showSidebar ? 0.5 : 0)
                    .ignoresSafeArea()
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
        }
        .onValueChange(of: viewModel.sport) {
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
    
    //@Binding var dragOffset: CGFloat
    
    let isUserSelf: Bool
    
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
                                    Image("Ads")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width - 32, height: 200)
                                        .cornerRadius(20)
                                    
                                }
                                
                                // 资料展示区
                                VStack(spacing: 16) {
                                    // 数据统计区域
                                    HStack(spacing: 30) {
                                        // 互关
                                        VStack(spacing: 2) {
                                            Text("\(viewModel.friendCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("好友")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: viewModel.userID, selectedTab: 0))
                                        }
                                        
                                        // 关注
                                        VStack(spacing: 2) {
                                            Text("\(viewModel.followedCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("关注")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: viewModel.userID, selectedTab: 1))
                                        }
                                        
                                        // 粉丝
                                        VStack(spacing: 2) {
                                            Text("\(viewModel.followerCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("粉丝")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: viewModel.userID, selectedTab: 2))
                                        }
                                        
                                        Spacer()
                                        
                                        if isUserSelf {
                                            Text("编辑资料")
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
                                                Text("关注")
                                                .font(.system(size: 16))
                                                .bold()
                                                .foregroundColor(.white)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 30)
                                                .background(.pink.opacity(0.8))
                                                .cornerRadius(8)
                                                .exclusiveTouchTapGesture {
                                                    viewModel.follow()
                                                }
                                            } else {
                                                Text("取消关注")
                                                    .font(.system(size: 16))
                                                    .bold()
                                                    .foregroundColor(.white)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 30)
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
                                    //.border(.purple)
                                    
                                    // 个人说明
                                    VStack(alignment: .leading, spacing: 12) {
                                        if isUserSelf {
                                            if let intro = userManager.user.introduction {
                                                Text(intro)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                            } else {
                                                HStack {
                                                    Text("介绍一下自己吧")
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
                                            if let intro = viewModel.currentUser.introduction {
                                                Text(intro)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        
                                        HStack {
                                            if viewModel.currentUser.isDisplayGender == true, let gender = viewModel.currentUser.gender {
                                                Text(gender.rawValue)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if viewModel.currentUser.isDisplayAge == true, let age = AgeDisplay.calculateAge(from: viewModel.currentUser.birthday ?? "xxxx-xx-xx") {
                                                Text("\(age)岁")
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if viewModel.currentUser.isDisplayLocation == true, let location = viewModel.currentUser.location {
                                                Text(location)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if viewModel.currentUser.isDisplayIdentity == true, let identity = viewModel.currentUser.identityAuthName {
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
                                    Text(isUserSelf ? userManager.user.nickname : viewModel.currentUser.nickname)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    if isUserSelf ? userManager.user.isVip : viewModel.currentUser.isVip {
                                        Image(systemName: "v.circle.fill")
                                            .font(.system(size: 15))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.red)
                                    }
                                    if (!isUserSelf) && viewModel.relationship != .none {
                                        Text(viewModel.relationship.displayName)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 6)
                                            .background(viewModel.relationship.backgroundColor.opacity(0.6))
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
                                    Image(systemName: "waveform.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    Text("设备绑定")
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
                                    Image(systemName: "flask.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    Text("研究所")
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
                                    Text("邮箱")
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
                                Text("生涯")
                                    .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundColor(selectedTab == 0 ? .white : .clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 0
                                    }
                                
                                Text("进行中")
                                    .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundColor(selectedTab == 1 ? .white : .clear),
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
                        
                        if viewModel.currentUser.status == .normal {
                            if selectedTab == 0 {
                                CareerView(viewModel: viewModel)
                            } else {
                                GameSummaryView(viewModel: viewModel)
                            }
                        } else if viewModel.currentUser.status == .banned {
                            Text("账号已封禁")
                                .foregroundStyle(Color.secondText)
                                .padding(.top, 100)
                        } else {
                            Text("账号已注销")
                                .foregroundStyle(Color.secondText)
                                .padding(.top, 100)
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
                            
                            ZStack {
                                HStack(alignment: .center) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                        .clipShape(Circle())
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.removeLast()
                                        }
                                    
                                    Spacer()
                                    
                                    HStack {
                                        Image(systemName: viewModel.sport.iconName)
                                            .font(.system(size: 16))
                                        Image(systemName: "list.dash")
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
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
                                
                                Text(isUserSelf ? (userManager.user.nickname) : viewModel.currentUser.nickname)
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
                                Text("生涯")
                                    .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundColor(selectedTab == 0 ? .white : .clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 0
                                    }
                                
                                Text("进行中")
                                    .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundColor(selectedTab == 1 ? .white : .clear),
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
    @StateObject var viewModel = LocalUserViewModel()
    
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
        .onValueChange(of: viewModel.sport) {
            viewModel.queryHistoryCareers()
            viewModel.queryCurrentRecords()
            DailyTaskManager.shared.queryDailyTask(sport: viewModel.sport)
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
                        if viewModel.sport == userManager.user.defaultSport {
                            viewModel.queryHistoryCareers()
                            viewModel.queryCurrentRecords()
                            DailyTaskManager.shared.queryDailyTask(sport: viewModel.sport)
                        } else {
                            viewModel.sport = userManager.user.defaultSport
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
                                    Image("Ads")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width - 32, height: 200)
                                        .cornerRadius(20)
                                    
                                }
                                
                                // 资料展示区
                                VStack(spacing: 16) {
                                    // 数据统计区域
                                    HStack(spacing: 30) {
                                        // 互关
                                        VStack(spacing: 2) {
                                            Text("\(userManager.friendCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("好友")
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
                                            Text("关注")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: userManager.user.userID, selectedTab: 1))
                                        }
                                        
                                        // 粉丝
                                        VStack(spacing: 2) {
                                            Text("\(userManager.followerCount)")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("粉丝")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.friendListView(id: userManager.user.userID, selectedTab: 2))
                                        }
                                        
                                        Spacer()
                                        
                                        Text("编辑资料")
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
                                                Text("介绍一下自己吧")
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
                                                Text("\(age)岁")
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(6)
                                            }
                                            
                                            if userManager.user.isDisplayLocation == true, let location = userManager.user.location {
                                                Text(location)
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
                                    if userManager.user.isVip {
                                        Image(systemName: "v.circle.fill")
                                            .font(.system(size: 15))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.red)
                                    } else {
                                        Image(systemName: "v.circle.fill")
                                            .font(.system(size: 15))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.thirdText)
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
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                Text("设备绑定")
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
                                Image(systemName: "flask.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                Text("研究所")
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
                                Text("邮箱")
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
                                        Text("每日运动任务")
                                        Spacer()
                                        /*Text("去训练>")
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 6)
                                            .font(.subheadline)
                                            .background(Color.orange.opacity(0.6))
                                            .cornerRadius(12)
                                            .exclusiveTouchTapGesture {
                                                appState.navigationManager.append(.sportTrainingView(sport: viewModel.sport))
                                            }*/
                                    }
                                    .padding(.horizontal, 10)
                                    
                                    HStack {
                                        if task.taskType == .distance {
                                            Text(String(format: "在竞技中累计运动距离 %.1f/%.0f \(task.taskType.disPlayName)", task.progress, task.totalProgress))
                                                .font(.subheadline)
                                        } else {
                                            Text(String(format: "在竞技中累计运动时间 %.0f/%.0f \(task.taskType.disPlayName)", task.progress / 60, task.totalProgress / 60))
                                                .font(.subheadline)
                                        }
                                        Spacer()
                                        Text("去竞技>")
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                            .font(.subheadline)
                                            .background(Color.orange.opacity(0.8))
                                            .cornerRadius(12)
                                            .exclusiveTouchTapGesture {
                                                appState.sport = viewModel.sport
                                                appState.navigationManager.selectedTab = .sportCenter
                                            }
                                    }
                                    .padding(.top, 20)
                                    .padding(.horizontal, 10)
                                    
                                    ZStack {
                                        // 进度条
                                        ZStack(alignment: .leading) {
                                            // 背景
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white.opacity(0.25))
                                                .frame(width: 300, height: 10)
                                            // 前景
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: (task.progress / task.totalProgress) * 300, height: 10)
                                        }
                                        
                                        // 3个可领取奖励的圆形节点
                                        HStack(spacing: 47) {
                                            Circle()
                                                .foregroundStyle(Color.orange.opacity(0.8))
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Image(systemName: viewModel.sport.iconName)
                                                        .font(.system(size: 18))
                                                )
                                            ZStack {
                                                HStack(alignment: .center, spacing: 2) {
                                                    Image(systemName: task.reward_stage1_type.iconName)
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
                                                    dailyTaskManager.claimReward(stage: 1, sport: viewModel.sport)
                                                }
                                            }
                                            ZStack {
                                                HStack(alignment: .center, spacing: 2) {
                                                    Image(systemName: task.reward_stage2_type.iconName)
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
                                                    dailyTaskManager.claimReward(stage: 2, sport: viewModel.sport)
                                                }
                                            }
                                            ZStack {
                                                CachedAsyncImage(
                                                    urlString: task.reward_stage3_url,
                                                    placeholder: Image("Ads"),
                                                    errorImage: Image(systemName: "photo.badge.exclamationmark")
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
                                                    dailyTaskManager.claimReward(stage: 3, sport: viewModel.sport)
                                                }
                                            }
                                        }
                                        .frame(width: 300)
                                    }
                                    .padding(.top, 10)
                                }
                                .foregroundStyle(Color.secondText)
                                .padding(.top, 10)
                                .padding(.bottom, 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.orange.opacity(0.8), lineWidth: 3)
                                        .background(Color.white.opacity(0.2))
                                )
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        
                        // 选项卡栏
                        ZStack(alignment: .top) {
                            HStack(spacing: 0) {
                                Text("生涯")
                                    .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundColor(selectedTab == 0 ? .white : .clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 0
                                    }
                                
                                Text("进行中")
                                    .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundColor(selectedTab == 1 ? .white : .clear),
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
                            
                            ZStack {
                                HStack(alignment: .center) {
                                    HStack {
                                        Image(systemName: "list.dash")
                                        Image(systemName: viewModel.sport.iconName)
                                            .font(.system(size: 16))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
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
                                
                                Text(userManager.user.nickname)
                                    .bold()
                                    .foregroundStyle(.white)
                                    .opacity(1 - opacityFor(offset: toolbarTop))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 5)
                        .frame(height: 45 + topSafeArea)
                        .background(userManager.backgroundColor.opacity(1 - opacityFor(offset: toolbarTop)))
                        
                        if toolbarTop <= 45 + topSafeArea {
                            HStack(spacing: 0) {
                                Text("生涯")
                                    .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundColor(selectedTab == 0 ? .white : .clear),
                                        alignment: .bottom
                                    )
                                    .exclusiveTouchTapGesture {
                                        selectedTab = 0
                                    }
                                
                                Text("进行中")
                                    .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        Rectangle()
                                            .frame(width: 60, height: 2)
                                            .foregroundColor(selectedTab == 1 ? .white : .clear),
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
                Text("选择运动")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.top, 50)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 20)
                
                if isUserSelf {
                    HStack {
                        if !isEditMode {
                            Text("个人主页默认展示运动: \(userManager.user.defaultSport.name)")
                        }
                        Spacer()
                        Text(isEditMode ? "取消编辑" : "编辑")
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
                            PressableButton(icon: sport.iconName, title: sport.name, isEditMode: isEditMode, action: {
                                if isEditMode {
                                    updateUserDefaultSport(with: sport)
                                } else {
                                    withAnimation(.easeIn(duration: 0.25)) {
                                        viewModel.showSidebar = false
                                        viewModel.sport = sport // 放在withAnimation中会导致拖影效果，但是拿出去会偶现主页opacity蒙层不更新问题
                                    }
                                }
                            })
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background((sport == viewModel.sport && (!isEditMode)) ? Color.gray.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
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
                Text("选择运动")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.top, 50)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 20)
                
                HStack {
                    if !isEditMode {
                        Text("个人主页默认展示运动: \(userManager.user.defaultSport.name)")
                    }
                    Spacer()
                    Text(isEditMode ? "取消编辑" : "编辑")
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
                            PressableButton(icon: sport.iconName, title: sport.name, isEditMode: isEditMode, action: {
                                if isEditMode {
                                    updateUserDefaultSport(with: sport)
                                } else {
                                    withAnimation(.easeIn(duration: 0.25)) {
                                        viewModel.showSidebar = false
                                        viewModel.sport = sport // 放在withAnimation中会导致拖影效果，但是拿出去会偶现主页opacity蒙层不更新问题
                                    }
                                }
                            })
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background((sport == viewModel.sport && (!isEditMode)) ? Color.gray.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
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

struct PressableButton: View {
    let icon: String
    let title: String
    let isEditMode: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            if isEditMode {
                Image(systemName: "circle.dotted")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange)
        .foregroundColor(.secondText)
        .cornerRadius(10)
        .exclusiveTouchTapGesture {
            action()
        }
    }
}


#Preview {
    let appState = AppState.shared
    let userManager = UserManager.shared
    let vm = LocalUserViewModel()
    
    LocalUserView(viewModel: vm)
        .environmentObject(appState)
}
