//
//  ContentView.swift
//  sportsx
//
//  Created by 任杰 on 2024/7/17.
//

import SwiftUI
import MapKit
import Combine
import SDWebImage
import SDWebImageSwiftUI


struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedTab = 0
    @State private var showSportPicker = false
    @State private var isMaleSelected = true // 添加性别选择状态，默认选择男性
    @Namespace private var animationNamespace

    var body: some View {
        VStack(spacing: 0) {
            // 自定义导航栏
            ZStack {
                // 运动选择部分
                HStack {
                    Image(systemName: appState.sport.iconName)
                        .font(.title2)
                    Text(appState.sport.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        withAnimation {
                            showSportPicker.toggle()
                        }
                    }) {
                        Image(systemName: "repeat")
                            .foregroundColor(.primary)
                            .font(.headline)
                    }
                    .sheet(isPresented: $showSportPicker) {
                        SportPickerView(selectedSport: $appState.sport)
                    }
                    
                    Spacer()
                    
                    // 性别选择toggle，仅在竞赛tab显示
                    if selectedTab == 1 {
                        Picker("", selection: $isMaleSelected) {
                            Image(systemName: "figure.stand")
                                .foregroundColor(.blue)
                                .tag(true)
                            Image(systemName: "figure.stand.dress")
                                .foregroundColor(.pink)
                                .tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 100, height: 20)
                        .padding(.trailing)
                        .onChange(of: isMaleSelected) {
                            // 当性别选择改变时，重新获取排行榜数据
                            viewModel.gender = isMaleSelected ? "male" : "female"
                            viewModel.fetchLeaderboard(for: viewModel.selectedTrackIndex, gender: isMaleSelected ? "male" : "female", reset: true)
                        }
                    }
                }
                .padding(.leading, 10)
                
                HStack(spacing: 20) {
                    TabButton(title: "广场", isSelected: selectedTab == 0, namespace: animationNamespace) {
                        withAnimation {
                            selectedTab = 0
                        }
                    }
                    
                    TabButton(title: "竞赛", isSelected: selectedTab == 1, namespace: animationNamespace) {
                        withAnimation {
                            selectedTab = 1
                        }
                    }
                }
            }
            
            // TabView 切换页面
            TabView(selection: $selectedTab) {
                if appState.sport.category == .PVP {
                    PVPSquareView()
                        .tag(0)
                    PVPCompetitionInfoView()
                        .tag(1)
                } else {
                    RVRSquareView(viewModel: viewModel)
                        .tag(0)
                    RVRCompetitionInfoView(viewModel: viewModel)
                        .tag(1)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .toolbar(.hidden, for: .navigationBar) // 隐藏导航栏
        .onAppear() {
            LocationManager.shared.saveLowToLast()
            if !appState.competitionManager.isRecording {
                LocationManager.shared.changeToLowUpdate()
            }
            viewModel.setupLocationSubscription()
            
            // 防止首次从运动中心切到首页时定位信息无法及时更新
            if let location = LocationManager.shared.getLocation() {
                viewModel.fetchCityName(from: location)
            }
        }
        .onDisappear() {
            viewModel.deleteLocationSubscription()
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            Button(action: action) {
                Text(title)
                    .fontWeight(isSelected ? .bold : .regular) // 选中状态下字体加粗
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            
            if isSelected {
                Rectangle()
                    .frame(width: 20, height: 2) // 控制条状UI的宽度和高度
                    .foregroundColor(.primary)
                    .matchedGeometryEffect(id: "underline", in: namespace)
            } else {
                Rectangle()
                    .frame(width: 20, height: 2)
                    .foregroundColor(.clear)
            }
        }
    }
}

struct PVPSquareView: View {
    var body: some View {
        Text("PVP广场")
            .font(.largeTitle)
            .padding()
        // 未来“广场”页面的内容会放在这里
    }
}

// 示例功能页面
struct SportSkillView: View {
    var body: some View {
        Text("Sport Skill页面")
    }
}

struct ActivityView: View {
    var body: some View {
        Text("活动页面")
    }
}

struct RVRSquareView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: HomeViewModel
    @State private var showingCitySelection = false
    @State private var adHeight: CGFloat = 200.0
    @State private var businessHeight: CGFloat = 150.0
    
    var body: some View {
        VStack(spacing: 0) {
            // 定位区域
            HStack {
                Image(systemName: "location.fill")
                Text(viewModel.cityName)
                Button(action: {
                    showingCitySelection.toggle()
                }) {
                    Text("选择城市")
                }
                .sheet(isPresented: $showingCitySelection) {
                    CitySelectionView(viewModel: viewModel, isPresented: $showingCitySelection)
                }
                Spacer()
                Button(action: {
                    viewModel.enableAutoLocation() // 启用自动定位
                }) {
                    Text("重新定位")
                }
                .padding(.leading, 10)
            }
            .frame(height: 40)
            .padding(.horizontal, 10)
            
            // 广告活动推荐区域
            AdsBannerView(width: UIScreen.main.bounds.width - 20, height: adHeight, ads: viewModel.ads)
            
            // 功能组件区域
            HStack(spacing: 38) {
                ForEach(viewModel.features) { feature in
                    Button(action: {
                        appState.navigationManager.path.append(feature.destination)
                    }) {
                        VStack {
                            Image(systemName: feature.iconName)
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.accentColor)
                            Text(feature.title)
                                .font(.caption)
                        }
                    }
                }
                Spacer() // 确保组件从左侧开始排列
            }
            .padding(.leading, 25)
            .padding(.top, 20)
            
            // 签到区域
            HStack() {
                // 左侧签到状态
                HStack(spacing: 10) {
                    ForEach(0..<7) { day in
                        Circle()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(viewModel.isSignedIn(day: day) ? .green : .gray)
                    }
                }
                .padding(.leading, 25)
                
                Spacer()
                
                // 右侧签到按钮
                Button(action: {
                    viewModel.signInToday()
                }) {
                    Text(viewModel.isTodaySigned ? "已签到" : "签到")
                        .padding(.vertical, 5)
                        .padding(.horizontal, 15)
                        .background(viewModel.isTodaySigned ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.trailing, 20)
                .disabled(viewModel.isTodaySigned)
            }
            .padding(.top, 20)
            .onAppear() {
                viewModel.fetchSignInStatus()
            }
            
            // 商业化区域
            HStack() {
                Spacer()
                AdsBannerView(width: (UIScreen.main.bounds.width - 30) / 2, height: businessHeight, ads: viewModel.business)
                    .padding(.trailing, 10)
            }
            .padding(.top, 20)

            Spacer() // 添加Spacer将内容推到顶部
        }
    }
}

struct PVPCompetitionInfoView: View {
    var body: some View {
        Text("PVP比赛信息页")
            .font(.largeTitle)
            .padding()
        // 未来“广场”页面的内容会放在这里
    }
}

struct RVRCompetitionInfoView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    @ObservedObject var viewModel: HomeViewModel
    
    @State private var selectedPage = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isFloatingViewVisible = false
    @State private var cancellable: AnyCancellable? = nil
    @State private var selectedEvent: Event? = nil
    
    // 安全获取当前选中的赛道
    private var currentTrack: Track? {
        guard !viewModel.tracks.isEmpty,
              viewModel.selectedTrackIndex >= 0,
              viewModel.selectedTrackIndex < viewModel.tracks.count else {
            return nil
        }
        return viewModel.tracks[viewModel.selectedTrackIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 赛事选择模块
            Spacer()
            
            HStack(spacing: 0) {
                Text("X1赛季")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.events) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(event.name)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.primary)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        selectedEvent = event
                                    }) {
                                        Image(systemName: "arrow.down.left.and.arrow.up.right.square")
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Text(event.description)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.selectedEventIndex == event.eventIndex ?
                                          Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(viewModel.selectedEventIndex == event.eventIndex ?
                                            Color.blue : Color.clear, lineWidth: 1)
                            )
                            .onTapGesture {
                                // 防止频繁刷新
                                if viewModel.selectedEventIndex != event.eventIndex {
                                    withAnimation {
                                        viewModel.switchEvent(to: event.eventIndex)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(width: 280)
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            
            // 使用安全检查显示地图
            if let track = currentTrack {
                Map(interactionModes: []) {
                    Annotation("From", coordinate: track.from) {
                        Image(systemName: "location.fill")
                            .padding(5)
                    }
                    Annotation("To", coordinate: track.to) {
                        Image(systemName: "location.fill")
                            .padding(5)
                    }
                }
                .frame(height: 200)
                .padding(10)
                .shadow(radius: 2)
            } else {
                // 当没有可用赛道时显示占位视图
                VStack {
                    Text("暂无赛道信息")
                        .foregroundColor(.secondary)
                    Image(systemName: "map")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .opacity(0.5)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .padding(10)
            }
            
            // 赛道选择
            if viewModel.tracks.isEmpty {
                Text("暂无可用赛道")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(viewModel.tracks) {track in
                            Text(track.name)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(viewModel.selectedTrackIndex == track.trackIndex ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .onTapGesture {
                                    // 防止频繁刷新
                                    if viewModel.selectedTrackIndex != track.trackIndex {
                                        withAnimation {
                                            viewModel.selectedTrackIndex = track.trackIndex
                                            viewModel.fetchLeaderboard(for: track.trackIndex, gender: viewModel.gender, reset: true)
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 用户排行信息
            LeaderboardEntryView(entry: LeaderboardEntry(user_id: userManager.user?.userID ?? "null", nickname: userManager.user?.nickname ?? "未知", best_time: 55.55, avatarImageURL: userManager.user?.avatarImageURL ?? "Ads"))
            //.padding(.bottom, 0)
                .padding(.top, 10)
            
            // 排行榜
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.leaderboardEntries.isEmpty && !viewModel.isLoadingMore {
                        Text("暂无排行榜数据")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        LazyVStack {
                            ForEach(viewModel.leaderboardEntries) { entry in
                                LeaderboardEntryView(entry: entry)
                                    .onAppear {
                                        if entry == viewModel.leaderboardEntries.last {
                                            viewModel.loadMoreEntries()
                                        }
                                    }
                            }
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
    }
}

struct SportPickerView: View {
    @Binding var selectedSport: SportName
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List(SportName.allCases.filter { $0.isSupported }) { sport in
                Button(action: {
                    selectedSport = sport
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: sport.iconName)
                            .foregroundColor(.blue)
                        Text(sport.rawValue)
                            .foregroundColor(.primary)
                        Spacer()
                        if sport == selectedSport {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("选择运动")
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct CitySelectionView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var selectedCity = ""
    @State private var showAlert = false
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            TextField("输入城市名称", text: $selectedCity)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            List {
                ForEach(viewModel.cities.filter { $0.contains(selectedCity) || selectedCity.isEmpty }, id: \.self) { city in
                    Text(city)
                        .onTapGesture {
                            selectedCity = city
                        }
                }
            }
            Button("确认选择") {
                if viewModel.cities.contains(selectedCity) {
                    // 这里根据服务端返回的数据确定城市和坐标
                    viewModel.selectCity(selectedCity)
                    isPresented = false
                } else {
                    showAlert = true
                }
            }
            .padding()
            .alert(isPresented: $showAlert) {
                Alert(title: Text("城市不支持"), message: Text("该城市暂不支持，请选择列表中的城市"), dismissButton: .default(Text("确定")))
            }
            Spacer()
        }
        .padding()
    }
}

struct EventDetailView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 背景图片
                    AsyncImage(url: URL(string: "https://example.com/event/\(event.name).jpg")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(height: 200)
                    .clipped()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // 比赛名称
                        Text(event.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        // 比赛时间
                        HStack {
                            Image(systemName: "calendar")
                            Text("2024年7月1日 - 2024年7月31日")
                                .foregroundColor(.secondary)
                        }
                        
                        // 比赛规则
                        VStack(alignment: .leading, spacing: 8) {
                            Text("比赛规则")
                                .font(.headline)
                            
                            Text("1. 参赛者需在指定时间内完成比赛\n2. 比赛过程中需遵守交通规则\n3. 成绩以完成时间计算\n4. 禁止使用任何交通工具\n5. 需全程开启运动记录")
                                .foregroundColor(.secondary)
                        }
                        
                        // 赛道信息
                        VStack(alignment: .leading, spacing: 8) {
                            Text("赛道信息")
                                .font(.headline)
                            
                            ForEach(event.tracks) { track in
                                HStack {
                                    Image(systemName: "figure.run")
                                    Text(track.name)
                                    Spacer()
                                    Text("\(track.from.latitude), \(track.from.longitude) → \(track.to.latitude), \(track.to.longitude)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let appState = AppState()
    return HomeView()
        .environmentObject(appState)
    //CompetitionResultView()
}
