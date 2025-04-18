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
    @StateObject var viewModel: UserViewModel
    @ObservedObject private var userManager = UserManager.shared
    
    @State private var selectedTab = 0
    @State private var toolbarTop: CGFloat = 0
    
    
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // 用户信息区
                    ZStack(alignment: .top) {
                        // 背景图片
                        AsyncImage(url: URL(string: viewModel.user.backgroundImageURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image("Ads") // 使用本地图片作为默认背景
                                .resizable()
                                .scaledToFill()
                        }
                        .frame(width: UIScreen.main.bounds.width, height: 230)
                        .clipped()
                        //.border(.green)
                        
                        // 头像和用户名区域
                        VStack {
                            Spacer()//.frame(height: 170)
                            
                            HStack(alignment: .center) {
                                // 头像
                                AsyncImage(url: URL(string: viewModel.user.avatarImageURL)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFill()
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 2)
                                .padding(.leading, 16)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    // 用户名
                                    Text(viewModel.user.nickname)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    // 用户ID
                                    Text("ID: \(viewModel.user.userID)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .padding(.leading, 15)
                                
                                Spacer()
                            }
                            //.frame(height: 90)
                            //.background(.clear)
                            .padding(.bottom, 15)
                        }
                    }
                    .frame(height: 230)
                    //.border(.red)
                    
                    // 资料展示区
                    VStack(spacing: 16) {
                        // 数据统计区域
                        HStack(spacing: 30) {
                            // 互关
                            VStack(spacing: 2) {
                                Text("1")
                                    .font(.system(size: 18, weight: .bold))
                                Text("好友")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            //.frame(maxWidth: .infinity)
                            
                            // 关注
                            VStack(spacing: 2) {
                                Text("2")
                                    .font(.system(size: 18, weight: .bold))
                                Text("关注")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            //.frame(maxWidth: .infinity)
                            
                            // 粉丝
                            VStack(spacing: 2) {
                                Text("5")
                                    .font(.system(size: 18, weight: .bold))
                                Text("粉丝")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            //.frame(maxWidth: .infinity)
                            
                            Spacer()
                            
                            if viewModel.isUserSelf {
                                Button(action: {
                                    // 编辑资料
                                }) {
                                    Text("编辑资料")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 20)
                                        .background(.gray.opacity(0.1))
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
                        .padding(.vertical, 12)
                        .padding(.leading, 20)
                        .padding(.trailing, 15)
                        //.border(.purple)
                        
                        // 个人说明
                        VStack(alignment: .leading, spacing: 12) {
                            Text("每一个追求无限可能的人，就是X玩家aaaa啊是谁 是谁谁谁谁 撒啊啊啊")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                            
                            HStack {
                                Text("上海")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 12)
                    
                    // 功能模块区
                    if viewModel.isUserSelf {
                        HStack(spacing: 0) {
                            // 设备绑定模块
                            Button(action: {
                                appState.navigationManager.path.append(.sensorBindView)
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "waveform.circle.fill")
                                        .font(.system(size: 24))
                                    Text("设备绑定")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                            }
                            .border(.orange)
                            
                            // 研究所模块
                            Button(action: {
                                appState.navigationManager.path.append(.instituteView)
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "flask.fill")
                                        .font(.system(size: 24))
                                    Text("研究所")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                            }
                            .border(.yellow)
                            
                            // 预留三个空位，保证总共5个位置
                            ForEach(0..<3) { _ in
                                Spacer()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 15)
                        .background(Color.white)
                        .opacity(opacityFor(offset: toolbarTop))
                        //.border(.pink)
                    }
                    
                    // 运动内容展示区
                    
                    // 选项卡栏
                    ZStack(alignment: .top) {
                        HStack(spacing: 0) {
                            Button(action: {
                                withAnimation {
                                    selectedTab = 0
                                }
                            }) {
                                Text("生涯")
                                    .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 0 ? .black : .gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .overlay(
                                Rectangle()
                                    .frame(width: 60, height: 2)
                                    .foregroundColor(selectedTab == 0 ? .black : .clear),
                                alignment: .bottom
                            )
                            
                            Button(action: {
                                withAnimation {
                                    selectedTab = 1
                                }
                            }) {
                                Text("赛事")
                                    .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                    .foregroundColor(selectedTab == 1 ? .black : .gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .overlay(
                                Rectangle()
                                    .frame(width: 60, height: 2)
                                    .foregroundColor(selectedTab == 1 ? .black : .clear),
                                alignment: .bottom
                            )
                        }
                        .background(.white)
                        
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
                        CareerView()
                    } else {
                        GameSummaryView()
                    }
                }
                .padding(.bottom, 100)
                //.border(.red)
            }
            .ignoresSafeArea(.all)
            //.border(.green)
            
            // 顶部操作栏
            VStack(spacing: 0) {
                ZStack {
                    HStack {
                        if viewModel.isNeedBack {
                            Button(action: {
                                appState.navigationManager.path.removeLast()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(Circle())
                            }
                        } else {
                            Button(action: {
                                // 选择运动按钮点击事件
                            }) {
                                Text("选择运动")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(18)
                            }
                        }
                        
                        Spacer()
                        
                        if viewModel.isNeedBack {
                            Button(action: {
                                // 选择运动按钮点击事件
                            }) {
                                Text("选择运动")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(18)
                            }
                        }
                        
                        if viewModel.isUserSelf {
                            Button(action: {
                                appState.navigationManager.path.append(.userSetUpView)
                            }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    
                    Text(viewModel.user.nickname)
                        .bold()
                        .opacity(1 - opacityFor(offset: toolbarTop))
                }
                .frame(height: 50)
                .padding(.horizontal, 16)
                .padding(.top, 60)
                //.border(.blue)
                .background(.white.opacity(1 - opacityFor(offset: toolbarTop)))
                
                if toolbarTop <= 110 {
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation {
                                selectedTab = 0
                            }
                        }) {
                            Text("生涯")
                                .font(.system(size: 16, weight: selectedTab == 0 ? .bold : .regular))
                                .foregroundColor(selectedTab == 0 ? .black : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .overlay(
                            Rectangle()
                                .frame(width: 60, height: 2)
                                .foregroundColor(selectedTab == 0 ? .black : .clear),
                            alignment: .bottom
                        )
                        
                        Button(action: {
                            withAnimation {
                                selectedTab = 1
                            }
                        }) {
                            Text("赛事")
                                .font(.system(size: 16, weight: selectedTab == 1 ? .bold : .regular))
                                .foregroundColor(selectedTab == 1 ? .black : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .overlay(
                            Rectangle()
                                .frame(width: 60, height: 2)
                                .foregroundColor(selectedTab == 1 ? .black : .clear),
                            alignment: .bottom
                        )
                    }
                    .background(.white)
                    //.border(.pink)
                    Divider()
                }
            }
            .ignoresSafeArea(.all)
            //.border(.green)
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.updateUserInfo()
        }
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



#Preview {
    let appState = AppState()
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
