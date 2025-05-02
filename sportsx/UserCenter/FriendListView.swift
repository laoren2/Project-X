//
//  FriendListView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/22.
//

import SwiftUI

struct FriendListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = FriendListViewModel()
    
    // 当前选择的Tab
    @State var selectedTab = 0
    
    @State private var searchText: String = ""
    
    // 过滤后的好友
    var filteredFriends: [PersonInfoCard] {
        if searchText.isEmpty {
            return viewModel.myFriends
        } else {
            return viewModel.myFriends.filter { person in
                person.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    // 过滤后的关注
    var filteredIdols: [PersonInfoCard] {
        if searchText.isEmpty {
            return viewModel.myIdols
        } else {
            return viewModel.myIdols.filter { person in
                person.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    // 过滤后的粉丝
    var filteredFans: [PersonInfoCard] {
        if searchText.isEmpty {
            return viewModel.myFans
        } else {
            return viewModel.myFans.filter { person in
                person.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack(alignment: .top) {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // 选项卡
                HStack(spacing: 20) {
                    ForEach(["好友", "关注", "粉丝"].indices, id: \.self) { index in
                        Button(action: {
                            withAnimation {
                                selectedTab = index
                            }
                        }) {
                            VStack(spacing: 10) {
                                Text(["好友", "关注", "粉丝"][index])
                                    .font(.system(size: 16, weight: selectedTab == index ? .semibold : .regular))
                                    .foregroundColor(selectedTab == index ? .black : .gray)
                                
                                // 选中指示器
                                Rectangle()
                                    .fill(selectedTab == index ? Color.black : Color.clear)
                                    .frame(width: 40, height: 2)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
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
                    .foregroundStyle(.black)
                    .font(.system(size: 15))
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            withAnimation {
                                searchText = ""
                            }
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
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)            )
            .padding()
            
            // 列表区域
            TabView(selection: $selectedTab) {
                // 好友列表
                if viewModel.myFriends.isEmpty {
                    VStack(spacing: 10) {
                        Text("您当前还没有好友")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("去组队运动，寻找一名好友吧")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .tag(0)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(filteredFriends) { person in
                                PersonInfoCardView(person: person)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .tag(0)
                }
                
                // 关注列表
                if viewModel.myIdols.isEmpty {
                    VStack(spacing: 10) {
                        Text("您当前还没有关注的人")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("快去排行榜逛一逛，关注一位大神吧")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .tag(1)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(filteredIdols) { person in
                                PersonInfoCardView(person: person)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .tag(1)
                }
                
                // 粉丝列表
                if viewModel.myFans.isEmpty {
                    VStack(spacing: 10) {
                        Text("您当前还没有粉丝")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("快去比赛中挑战自己，吸引更多粉丝吧")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .tag(2)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(filteredFans) { person in
                                PersonInfoCardView(person: person)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .tag(2)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(.white)
    }
}

struct PersonInfoCardView: View {
    @EnvironmentObject var appState: AppState
    let person: PersonInfoCard
    
    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                if let url = URL(string: person.avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle()) // 使图片变为圆形
                    } placeholder: {
                        Image("Ads")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    }
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 60, height: 60)
                        .padding(.leading, 5)
                }
                
                Text(person.name)
                    .foregroundStyle(.black)
                    .font(.system(size: 15))
                    .bold()
            }
            .onTapGesture {
                appState.navigationManager.append(.userView(id: person.userID, needBack: true))
            }
            
            Spacer()
            
            Image(systemName: "ellipsis")
                .foregroundStyle(.black)
                .font(.system(size: 18))
                .padding(.vertical,10)
        }
    }
}


#Preview {
    let appState = AppState.shared
    //return PersonInfoCardView(avatarUrl: "123", name: "哈qweasd我的")
    return FriendListView()
        .environmentObject(appState)
}
