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
    
    @State private var dragOffset: CGFloat = 0       // 当前拖动偏移量
    @State private var disableScroll = false         // 是否禁用滚动(拖动时禁用)
    @GestureState private var drag = CGFloat.zero    // 手势状态
    
    // 是否是已登陆用户
    var isUserSelf: Bool {
        if let user = userManager.user {
            // 总tabview的"我的"页，防止未登录成功时id未设置成功
            if !viewModel.isNeedBack {
                viewModel.userID = user.userID
            }
            
            if viewModel.userID != user.userID {
                return false
            } else {
                return true
            }
        } else {
            return false
        }
    }
    
    
    var body: some View {
        // 无需返回场景支持右划弹出运动选择页
        // 返回场景支持左划弹出运动选择页,右划返回上一视图层级
        GeometryReader { geometry in
            // 主内容
            MainUserView(viewModel: viewModel, isDisableScroll: $disableScroll, dragOffset: $dragOffset, isUserSelf: isUserSelf)
                .offset(x: (viewModel.showSidebar ? (viewModel.isNeedBack ? -viewModel.sidebarWidth : viewModel.sidebarWidth) : 0) + dragOffset)
            
            // 侧边栏
            SportSelectionSidebar(viewModel: viewModel, isDisableScroll: $disableScroll, isUserSelf: isUserSelf)
                .frame(width: viewModel.sidebarWidth)
                .offset(x: (viewModel.showSidebar ? (viewModel.isNeedBack ? UIScreen.main.bounds.width - viewModel.sidebarWidth : 0) : (viewModel.isNeedBack ? UIScreen.main.bounds.width : -viewModel.sidebarWidth)) + dragOffset)
        }
        .gesture(
            DragGesture(minimumDistance: 10) // 设置最小拖动距离，防止误触
                .updating($drag) { value, state, _ in
                    // 获取水平滑动的偏移量
                    let translation = value.translation.width
                    
                    // 为拖动添加阻尼效果
                    if viewModel.isNeedBack {
                        if !viewModel.showSidebar && translation < 0 {
                            // 当隐藏侧边栏时向左拖动打开侧边栏
                            //dampenedTranslation = max(translation * 0.95, -viewModel.sidebarWidth) // 限制最大拖动距离
                            disableScroll = true
                            dragOffset = max(translation * 0.95, -viewModel.sidebarWidth) // 限制最大拖动距离
                        } else if !viewModel.showSidebar && translation > 0 {
                            disableScroll = true
                        } else if viewModel.showSidebar && translation > 0 {
                            // 当显示侧边栏时向右拖动收起侧边栏
                            //dampenedTranslation = min(translation * 0.95, viewModel.sidebarWidth) // 限制最大拖动距离
                            disableScroll = true
                            dragOffset = min(translation * 0.95, viewModel.sidebarWidth)
                        }
                    } else {
                        if !viewModel.showSidebar && translation > 0 {
                            // 当隐藏侧边栏时向右拖动打开侧边栏
                            //dampenedTranslation = min(translation * 0.95, viewModel.sidebarWidth) // 限制最大拖动距离
                            disableScroll = true
                            dragOffset = min(translation * 0.95, viewModel.sidebarWidth)
                        } else if viewModel.showSidebar && translation < 0 {
                            // 当显示侧边栏时向左拖动收起侧边栏
                            //dampenedTranslation = max(translation * 0.95, -viewModel.sidebarWidth) // 限制最大拖动距离
                            disableScroll = true
                            dragOffset = max(translation * 0.95, -viewModel.sidebarWidth)
                        }
                    }
                }
                .onEnded { value in
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
                    disableScroll = false
                }
        )
    }
}

struct MainUserView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: UserViewModel
    @ObservedObject private var userManager = UserManager.shared
    
    @State private var selectedTab = 0
    @State private var toolbarTop: CGFloat = 0
    
    @Binding var isDisableScroll: Bool
    @Binding var dragOffset: CGFloat
    
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
                                            Text("1")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("好友")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .simultaneousGesture(
                                            TapGesture()
                                                .onEnded {
                                                    appState.navigationManager.append(.friendListView(selectedTab: 0))
                                                }
                                        )
                                        
                                        // 关注
                                        VStack(spacing: 2) {
                                            Text("2")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("关注")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .simultaneousGesture(
                                            TapGesture()
                                                .onEnded {
                                                    appState.navigationManager.append(.friendListView(selectedTab: 1))
                                                }
                                        )
                                        
                                        // 粉丝
                                        VStack(spacing: 2) {
                                            Text("5")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("粉丝")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .simultaneousGesture(
                                            TapGesture()
                                                .onEnded {
                                                    appState.navigationManager.append(.friendListView(selectedTab: 2))
                                                }
                                        )
                                        
                                        Spacer()
                                        
                                        if isUserSelf {
                                            Button(action: {
                                                appState.navigationManager.append(.userIntroEditView)
                                            }) {
                                                Text("编辑资料")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 20)
                                                    .background(.ultraThinMaterial)
                                                    .cornerRadius(8)
                                            }
                                        } else {
                                            Button(action: {
                                                // 关注
                                            }) {
                                                Text("关注")
                                                    .font(.system(size: 16))
                                                    .bold()
                                                    .foregroundColor(.white)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 30)
                                                    .background(.pink.opacity(0.8))
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .padding(.top, 25)
                                    .padding(.bottom, 10)
                                    .padding(.leading, 20)
                                    .padding(.trailing, 15)
                                    //.border(.purple)
                                    
                                    // 个人说明
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(isUserSelf ? (userManager.user?.introduction ?? "未知") : viewModel.currentUser.introduction)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                        
                                        HStack {
                                            if isUserSelf {
                                                if userManager.user?.isDisplayGender == true, let gender = userManager.user?.gender {
                                                    Text(gender)
                                                        .padding(.vertical, 4)
                                                        .padding(.horizontal, 8)
                                                        .background(.ultraThinMaterial)
                                                        .cornerRadius(6)
                                                }
                                                
                                                if userManager.user?.isDisplayAge == true, let age = AgeDisplay.calculateAge(from: userManager.user?.birthday ?? "xxxx-xx-xx") {
                                                    Text("\(age)岁")
                                                        .padding(.vertical, 4)
                                                        .padding(.horizontal, 8)
                                                        .background(.ultraThinMaterial)
                                                        .cornerRadius(6)
                                                }
                                                
                                                if userManager.user?.isDisplayLocation == true, let location = userManager.user?.location {
                                                    Text(location)
                                                        .padding(.vertical, 4)
                                                        .padding(.horizontal, 8)
                                                        .background(.ultraThinMaterial)
                                                        .cornerRadius(6)
                                                }
                                                
                                                if userManager.user?.isDisplayIdentity == true, let identity = userManager.user?.identityAuthName {
                                                    Text(identity)
                                                        .padding(.vertical, 4)
                                                        .padding(.horizontal, 8)
                                                        .background(.ultraThinMaterial)
                                                        .cornerRadius(6)
                                                }
                                            } else {
                                                if viewModel.currentUser.isDisplayGender == true, let gender = viewModel.currentUser.gender {
                                                    Text(gender)
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
                                            }
                                            
                                            Spacer()
                                        }
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .padding(.bottom, 12)
                            }
                            //.border(.orange)
                            
                            // 头像和用户名区域
                            VStack {
                                // 用户名
                                Text(isUserSelf ? (userManager.user?.nickname ?? "未知") : viewModel.currentUser.nickname)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
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
                            }
                            .padding(.top, 93)
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
                                .simultaneousGesture(
                                    TapGesture()
                                        .onEnded {
                                            appState.navigationManager.append(.sensorBindView)
                                        }
                                )
                                
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
                                .simultaneousGesture(
                                    TapGesture()
                                        .onEnded {
                                            appState.navigationManager.append(.instituteView)
                                        }
                                )
                                
                                // 预留三个空位，保证总共5个位置
                                ForEach(0..<3) { _ in
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
                                    .simultaneousGesture(
                                        TapGesture()
                                            .onEnded {
                                                withAnimation {
                                                    selectedTab = 0
                                                }
                                            }
                                    )
                                
                                Text("赛事")
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
                                    .simultaneousGesture(
                                        TapGesture()
                                            .onEnded {
                                                withAnimation {
                                                    selectedTab = 1
                                                }
                                            }
                                    )
                            }
                            
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { updateOffset(geo) }
                                    .onChange(of: geo.frame(in: .global).minY) {
                                        updateOffset(geo)
                                    }
                            }
                            .frame(height: 0) // 避免占空间
                        }
                        
                        Divider()
                        
                        if selectedTab == 0 {
                            CareerView(viewModel: viewModel)
                        } else {
                            GameSummaryView(viewModel: viewModel)
                        }
                    }
                    .padding(.bottom, 100)
                    //.border(.red)
                }
                //.border(.red)
                .disabled(isDisableScroll)
                
                // 顶部操作栏
                GeometryReader { geo in
                    let topSafeArea = geo.safeAreaInsets.top
                    VStack(spacing: 0) {
                        VStack {
                            Spacer()
                            
                            ZStack {
                                HStack(alignment: .center) {
                                    if viewModel.isNeedBack {
                                        Button(action: {
                                            appState.navigationManager.removeLast()
                                        }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                                .padding(10)
                                                .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                                .clipShape(Circle())
                                        }
                                    } else {
                                        HStack {
                                            Image(systemName: "list.dash")
                                            Image(systemName:viewModel.sport.iconName)
                                                .font(.system(size: 16))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                        .cornerRadius(18)
                                        .foregroundColor(.white)
                                        .simultaneousGesture(
                                            TapGesture()
                                                .onEnded {
                                                    withAnimation(.easeIn(duration: 0.3)) {
                                                        viewModel.showSidebar = true
                                                    }
                                                }
                                        )
                                    }
                                    
                                    Spacer()
                                    
                                    if viewModel.isNeedBack {
                                        HStack {
                                            Image(systemName:viewModel.sport.iconName)
                                                .font(.system(size: 16))
                                            Image(systemName: "list.dash")
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                        .cornerRadius(18)
                                        .foregroundColor(.white)
                                        .simultaneousGesture(
                                            TapGesture()
                                                .onEnded {
                                                    withAnimation(.easeIn(duration: 0.3)) {
                                                        viewModel.showSidebar = true
                                                    }
                                                }
                                        )
                                    }
                                    
                                    if isUserSelf {
                                        Button(action: {
                                            appState.navigationManager.append(.userSetUpView)
                                        }) {
                                            Image(systemName: "gearshape.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                                .padding(6)
                                                .background(.ultraThinMaterial.opacity(opacityFor(offset: toolbarTop)))
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                                //.border(.red)
                                
                                Text(isUserSelf ? (userManager.user?.nickname ?? "未知") : viewModel.currentUser.nickname)
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
                                    .simultaneousGesture(
                                        TapGesture()
                                            .onEnded {
                                                withAnimation {
                                                    selectedTab = 0
                                                }
                                            }
                                    )
                                
                                Text("赛事")
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
                                    .simultaneousGesture(
                                        TapGesture()
                                            .onEnded {
                                                withAnimation {
                                                    selectedTab = 1
                                                }
                                            }
                                    )
                            }
                            .background(isUserSelf ? userManager.backgroundColor : viewModel.backgroundColor)
                            //.border(.pink)
                            Divider()
                        }
                        Spacer()
                    }
                    //.border(.pink)
                    .ignoresSafeArea()
                }
            }
            //.border(.green)
            
            Color.gray
                .opacity(((viewModel.showSidebar ? viewModel.sidebarWidth : 0) + (viewModel.isNeedBack ? -dragOffset : dragOffset)) / (2 * viewModel.sidebarWidth))
                .ignoresSafeArea()
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            withAnimation(.easeIn(duration: 0.3)) {
                                viewModel.showSidebar = false
                            }
                        }
                )
        }
        .navigationBarHidden(true)
    }
    
    func updateOffset(_ geo: GeometryProxy) {
        DispatchQueue.main.async {
            toolbarTop = geo.frame(in: .global).minY
            //print("📐 仅用GeometryReader 距顶：", toolbarTop)
        }
    }
    
    func opacityFor(offset: CGFloat) -> Double {
        let visibleUntil: CGFloat = 110
        return max(0, min(1, offset / visibleUntil - 1))
    }
}

struct SportSelectionSidebar: View {
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var viewModel: UserViewModel
    @Binding var isDisableScroll: Bool
    
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
                
                Text("选择你要展示的运动项目")
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
                            PressableButton(icon: sport.iconName, title: sport.name, action: {
                                withAnimation(.easeIn(duration: 0.3)) {
                                    viewModel.showSidebar = false
                                    viewModel.sport = sport // 放在withAnimation中会导致拖影效果，但是拿出去会偶现主页opacity蒙层不更新问题
                                }
                            })
                            
                            Spacer()
                            
                            if sport.name == viewModel.sport.name {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(sport == viewModel.sport ? Color.gray.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                        //.border(.red)
                    }
                }
                .padding(.horizontal, 20)
            }
            .disabled(isDisableScroll)
        }
        .background(isUserSelf ? userManager.backgroundColor : viewModel.backgroundColor)
    }
}

struct PressableButton: View {
    var icon: String? = nil
    let title: String
    let action: () -> Void

    @GestureState private var isPressed = false

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(title)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange)
        .foregroundColor(.white)
        .cornerRadius(10)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .opacity(isPressed ? 0.85 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .contentShape(Rectangle()) // 确保整个区域可响应手势
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    action()
                }
        )
    }
}



#Preview {
    let appState = AppState.shared
    let userManager = UserManager.shared
    let vm = UserViewModel(id: userManager.user?.userID ?? "未知", needBack: false)
    
    UserView(viewModel: vm)
        .environmentObject(appState)
}


// 生涯内容
/*VStack(alignment: .center, spacing: 16) {
    Image(systemName: "figure.run")
        .font(.system(size: 60))
        .foregroundColor(.gray.opacity(0.5))
        .padding(.top, 40)
    
    Text("还没有运动记录")
        .font(.system(size: 16))
        .foregroundColor(.gray)
    
    Text("去运动一下，记录你的生涯")
        .font(.system(size: 14))
        .foregroundColor(.gray.opacity(0.7))
        .padding(.bottom, 40)
}
.frame(maxWidth: .infinity)
.padding(.vertical, 20)
.tag(0)

// 赛事内容
VStack(alignment: .center, spacing: 16) {
    Image(systemName: "trophy")
        .font(.system(size: 60))
        .foregroundColor(.gray.opacity(0.5))
        .padding(.top, 40)
    
    Text("还没有参加过赛事")
        .font(.system(size: 16))
        .foregroundColor(.gray)
    
    Text("去参加一次赛事，展示你的实力")
        .font(.system(size: 14))
        .foregroundColor(.gray.opacity(0.7))
        .padding(.bottom, 40)
}
.frame(maxWidth: .infinity)
.padding(.vertical, 20)
.tag(1)*/

// 选项卡内容
/*TabView(selection: $selectedTab) {
    ScrollView(showsIndicators: false) {
        LazyVStack(spacing: 15) {
            ForEach(appState.competitionManager.userTab1) { competition in
                CompetitionRecordCard(competition: competition, onStart:  {
                    print("onStart")
                })
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .border(.blue)
    }
    .tag(0)
    
    ScrollView(showsIndicators: false) {
        LazyVStack(spacing: 15) {
            ForEach(appState.competitionManager.userTab2) { competition in
                CompetitionRecordCard(competition: competition, onStart:  {
                    print("onStart")
                })
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .border(.blue)
    }
    .tag(1)
}
.frame(height: 720)
.tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))*/
