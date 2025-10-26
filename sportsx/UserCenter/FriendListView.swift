//
//  FriendListView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/22.
//

import SwiftUI

struct FriendListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: FriendListViewModel
    
    // 当前选择的Tab
    @State var selectedTab: Int
    
    @State private var searchFriendText: String = ""
    @State private var searchIdolText: String = ""
    @State private var searchFanText: String = ""
    
    init(id: String, selectedTab: Int) {
        _viewModel = StateObject(wrappedValue: FriendListViewModel(id: id))
        self.selectedTab = selectedTab
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack(alignment: .top) {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                
                Spacer()
                
                // 选项卡
                HStack(spacing: 20) {
                    ForEach(["好友", "关注", "粉丝"].indices, id: \.self) { index in
                        VStack(spacing: 10) {
                            Text(["好友", "关注", "粉丝"][index])
                                .font(.system(size: 16, weight: selectedTab == index ? .semibold : .regular))
                                .foregroundColor(selectedTab == index ? Color.white : Color.thirdText)
                            
                            // 选中指示器
                            Rectangle()
                                .fill(selectedTab == index ? Color.white : Color.clear)
                                .frame(width: 40, height: 2)
                        }
                        .onTapGesture {
                            selectedTab = index
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
            .padding(.horizontal, 16)
            
            Divider()
            
            // 列表区域
            TabView(selection: $selectedTab) {
                VStack(spacing: 0) {
                    // 搜索框
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.gray.opacity(0.1))
                                .frame(height: 30)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 12)
                                
                                TextField(text: $searchFriendText) {
                                    Text("搜索好友")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 15))
                                }
                                .foregroundStyle(.white)
                                .font(.system(size: 15))
                                
                                if !searchFriendText.isEmpty {
                                    CommonIconButton(icon: "xmark.circle.fill") {
                                        searchFriendText = ""
                                        viewModel.myFilteredFriends.removeAll()
                                    }
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 12)
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
                        .padding(.vertical, 16)
                        .padding(.trailing, 8)
                        
                        CommonTextButton(text: "搜索") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            viewModel.myFilteredFriends.removeAll()
                            if !searchFriendText.isEmpty {
                                viewModel.searchFriendsCursorDatetime = nil
                                viewModel.searchFriendsCursorID = nil
                                viewModel.fetchFriends(withNicname: searchFriendText)
                            }
                        }
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    // 好友列表
                    ZStack(alignment: .top) {
                        if viewModel.myFriends.isEmpty {
                            VStack(spacing: 10) {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text("您当前还没有好友")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                HStack {
                                    Spacer()
                                    Text("去组队运动，寻找一名好友吧")
                                        .font(.subheadline)
                                        .foregroundColor(Color.secondText)
                                        .multilineTextAlignment(.center)
                                        //.padding(.horizontal, 40)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .background(Color.defaultBackground)
                            .hideKeyboardOnTap()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 15) {
                                    ForEach(viewModel.myFriends) { person in
                                        PersonInfoCardView(person: person)
                                            .onAppear {
                                                if person == viewModel.myFriends.last && viewModel.hasMoreFriends {
                                                    viewModel.fetchFriends()
                                                }
                                            }
                                    }
                                    if viewModel.isFriendsLoading {
                                        ProgressView()
                                            .padding()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top)
                            }
                            .hideKeyboardOnScroll()
                        }
                        if !searchFriendText.isEmpty {
                            ScrollView {
                                LazyVStack(spacing: 15) {
                                    ForEach(viewModel.myFilteredFriends) { person in
                                        PersonInfoCardView(person: person)
                                            .onAppear {
                                                if person == viewModel.myFilteredFriends.last && viewModel.hasMoreSearchFriends {
                                                    viewModel.fetchFriends(withNicname: searchFriendText)
                                                }
                                            }
                                    }
                                    if viewModel.isSearchFriendsLoading {
                                        ProgressView()
                                            .padding()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top)
                            }
                            .background(.ultraThinMaterial)
                            .hideKeyboardOnScroll()
                        }
                    }
                }
                .tag(0)
                
                VStack(spacing: 0) {
                    // 搜索框
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.gray.opacity(0.1))
                                .frame(height: 30)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 12)
                                
                                TextField(text: $searchIdolText) {
                                    Text("搜索关注")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 15))
                                }
                                .foregroundStyle(.white)
                                .font(.system(size: 15))
                                
                                if !searchIdolText.isEmpty {
                                    CommonIconButton(icon: "xmark.circle.fill") {
                                        searchIdolText = ""
                                        viewModel.myFilteredIdols.removeAll()
                                    }
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 12)
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
                        .padding(.vertical, 16)
                        .padding(.trailing, 8)
                        
                        CommonTextButton(text: "搜索") {
                            viewModel.myFilteredIdols.removeAll()
                            if !searchIdolText.isEmpty {
                                viewModel.searchIdolsCursorDatetime = nil
                                viewModel.searchIdolsCursorID = nil
                                viewModel.fetchIdols(withNicname: searchIdolText)
                            }
                        }
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    // 关注列表
                    ZStack(alignment: .top) {
                        if viewModel.myIdols.isEmpty {
                            VStack(spacing: 10) {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text("您当前还没有关注的人")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                HStack {
                                    Spacer()
                                    Text("快去排行榜逛一逛，关注一位运动达人吧")
                                        .font(.subheadline)
                                        .foregroundColor(Color.secondText)
                                        .multilineTextAlignment(.center)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .background(Color.defaultBackground)
                            .hideKeyboardOnTap()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 15) {
                                    ForEach(viewModel.myIdols) { person in
                                        PersonInfoCardView(person: person)
                                            .onAppear {
                                                if person == viewModel.myIdols.last && viewModel.hasMoreIdols {
                                                    viewModel.fetchIdols()
                                                }
                                            }
                                    }
                                    if viewModel.isIdolsLoading {
                                        ProgressView()
                                            .padding()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top)
                            }
                            .hideKeyboardOnScroll()
                        }
                        if !searchIdolText.isEmpty {
                            ScrollView {
                                LazyVStack(spacing: 15) {
                                    ForEach(viewModel.myFilteredIdols) { person in
                                        PersonInfoCardView(person: person)
                                            .onAppear {
                                                if person == viewModel.myFilteredIdols.last && viewModel.hasMoreSearchIdols {
                                                    viewModel.fetchIdols(withNicname: searchIdolText)
                                                }
                                            }
                                    }
                                    if viewModel.isSearchIdolsLoading {
                                        ProgressView()
                                            .padding()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top)
                            }
                            .background(.ultraThinMaterial)
                            .hideKeyboardOnScroll()
                        }
                    }
                }
                .tag(1)
                
                VStack(spacing: 0) {
                    // 搜索框
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.gray.opacity(0.1))
                                .frame(height: 30)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 12)
                                
                                TextField(text: $searchFanText) {
                                    Text("搜索粉丝")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 15))
                                }
                                .foregroundStyle(.white)
                                .font(.system(size: 15))
                                
                                if !searchFanText.isEmpty {
                                    CommonIconButton(icon: "xmark.circle.fill") {
                                        searchFanText = ""
                                        viewModel.myFilteredFans.removeAll()
                                    }
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 12)
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
                        .padding(.vertical, 16)
                        .padding(.trailing, 8)
                        
                        
                        CommonTextButton(text: "搜索") {
                            viewModel.myFilteredFans.removeAll()
                            if !searchFanText.isEmpty {
                                viewModel.searchFansCursorDatetime = nil
                                viewModel.searchFansCursorID = nil
                                viewModel.fetchFans(withNicname: searchFanText)
                            }
                        }
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    // 粉丝列表
                    ZStack(alignment: .top) {
                        if viewModel.myFans.isEmpty {
                            VStack(spacing: 10) {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text("您当前还没有粉丝")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                HStack {
                                    Spacer()
                                    Text("快去比赛中挑战自己，吸引更多粉丝吧")
                                        .font(.subheadline)
                                        .foregroundColor(Color.secondText)
                                        .multilineTextAlignment(.center)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .background(Color.defaultBackground)
                            .hideKeyboardOnTap()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 15) {
                                    ForEach(viewModel.myFans) { person in
                                        PersonInfoCardView(person: person)
                                            .onAppear {
                                                if person == viewModel.myFans.last && viewModel.hasMoreFans {
                                                    viewModel.fetchFans()
                                                }
                                            }
                                    }
                                    if viewModel.isFansLoading {
                                        ProgressView()
                                            .padding()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top)
                            }
                            .hideKeyboardOnScroll()
                        }
                        if !searchFanText.isEmpty {
                            ScrollView {
                                LazyVStack(spacing: 15) {
                                    ForEach(viewModel.myFilteredFans) { person in
                                        PersonInfoCardView(person: person)
                                            .onAppear {
                                                if person == viewModel.myFilteredFans.last && viewModel.hasMoreSearchFans {
                                                    viewModel.fetchFans(withNicname: searchFanText)
                                                }
                                            }
                                    }
                                    if viewModel.isSearchFansLoading {
                                        ProgressView()
                                            .padding()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top)
                            }
                            .background(.ultraThinMaterial)
                            .hideKeyboardOnScroll()
                        }
                    }
                }
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.defaultBackground)
    }
}

struct PersonInfoCardView: View {
    @EnvironmentObject var appState: AppState
    let person: PersonInfoCard
    
    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                CachedAsyncImage(
                    urlString: person.avatarUrl,
                    placeholder: Image(systemName: "person"),
                    errorImage: Image(systemName: "photo.badge.exclamationmark")
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                Text(person.name)
                    .foregroundStyle(.white)
                    .font(.system(size: 15))
                    .bold()
            }
            .exclusiveTouchTapGesture {
                appState.navigationManager.append(.userView(id: person.userID))
            }
            
            Spacer()
            
            Image(systemName: "ellipsis")
                .foregroundStyle(.white)
                .font(.system(size: 18))
                .padding(.vertical,10)
        }
    }
}


#Preview {
    let appState = AppState.shared
    //return PersonInfoCardView(avatarUrl: "123", name: "哈qweasd我的")
    //return FriendListView()
    //    .environmentObject(appState)
}
