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
    @State private var selectedTab = 0
    @State private var showSportPicker = false
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
                    RVRSquareView()
                        .tag(0)
                    RVRCompetitionInfoView()
                        .tag(1)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .toolbar(.hidden, for: .navigationBar) // 隐藏导航栏
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
                    .foregroundColor(.black)
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

struct RVRSquareView: View {
    var body: some View {
        Text("RVR广场")
            .font(.largeTitle)
            .padding()
        // 未来“广场”页面的内容会放在这里
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
    @StateObject private var viewModel = HomeViewModel()
    
    @State private var selectedPage = 0
    @State private var showingCitySelection = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isFloatingViewVisible = false
    @State private var adHeight: CGFloat = 200.0
    @State private var cancellable: AnyCancellable? = nil
    
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
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
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        AdsBannerView(width: UIScreen.main.bounds.width - 20, height: adHeight, ads: viewModel.ads)
                        
                        Map(interactionModes: []) {
                            Annotation("From", coordinate: viewModel.tracks[viewModel.selectedTrackIndex].from) {
                                Image(systemName: "location.fill")
                                    .padding(5)
                            }
                            Annotation("To", coordinate: viewModel.tracks[viewModel.selectedTrackIndex].to) {
                                Image(systemName: "location.fill")
                                    .padding(5)
                            }
                        }
                        .frame(height: 200)
                        .padding(10)
                        .shadow(radius: 2)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(viewModel.tracks) {track in
                                    Button(action: {
                                        withAnimation {
                                            viewModel.selectedTrackIndex = track.trackIndex
                                            viewModel.fetchLeaderboard(for: track.trackIndex, reset: true)
                                        }
                                    }) {
                                        Text(track.name)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 20)
                                            .background(viewModel.selectedTrackIndex == track.trackIndex ? Color.blue : Color.gray)
                                            .foregroundColor(.white)
                                            .cornerRadius(15)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        LeaderboardEntryView(entry: LeaderboardEntry(user_id: userManager.user?.userID ?? "null", nickname: userManager.user?.nickname ?? "未知", best_time: 55.55, avatarImageURL: userManager.user?.avatarImageURL ?? "Ads"))
                            .padding(.bottom, -6)
                            .padding(.top, 10)
                        
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
                    .background(GeometryReader { proxy -> Color in
                        DispatchQueue.main.async {
                            scrollOffset = -proxy.frame(in: .named("scroll")).origin.y
                            if scrollOffset > adHeight {
                                isFloatingViewVisible = true
                            } else {
                                isFloatingViewVisible = false
                            }
                        }
                        return Color.clear
                    })
                }
                .coordinateSpace(name: "scroll")
            }
            
            if isFloatingViewVisible {
                VStack(spacing: 0) {
                    Map(interactionModes: []) {
                        Annotation("From", coordinate: viewModel.tracks[viewModel.selectedTrackIndex].from) {
                            Image(systemName: "location.fill")
                                .padding(5)
                        }
                        Annotation("To", coordinate: viewModel.tracks[viewModel.selectedTrackIndex].to) {
                            Image(systemName: "location.fill")
                                .padding(5)
                        }
                    }
                    .frame(height: 200)
                    .padding(10)
                    .shadow(radius: 2)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(viewModel.tracks) { track in
                                Button(action: {
                                    withAnimation {
                                        viewModel.selectedTrackIndex = track.trackIndex
                                        viewModel.fetchLeaderboard(for: track.trackIndex, reset: true)
                                    }
                                }) {
                                    Text(track.name)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 20)
                                        .background(viewModel.selectedTrackIndex == track.trackIndex ? Color.blue : Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(15)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    LeaderboardEntryView(entry: LeaderboardEntry(user_id: userManager.user?.userID ?? "null", nickname: userManager.user?.nickname ?? "未知", best_time: 55.55, avatarImageURL: userManager.user?.avatarImageURL ?? "Ads"))
                        .padding(.top, 10)
                        .padding(.bottom, -8)
                }
                .background(Color.white)
                .transition(.opacity) // 透明度过渡动画
                .animation(.easeInOut, value: isFloatingViewVisible) // 动画效果
                .zIndex(1) // 保证悬浮视图在其他视图之上
                .offset(y: 40)
            }
        }
        .onAppear() {
            LocationManager.shared.saveHomeViewToLast()
            if !appState.competitionManager.isRecording {
                LocationManager.shared.enterHomeView()
            }
            viewModel.setupLocationSubscription()
        }
        .onDisappear() {
            viewModel.deleteLocationSubscription()
        }
    }
}

struct SportPickerView: View {
    @Binding var selectedSport: SportName
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List(SportName.allCases) { sport in
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

#Preview {
    let appState = AppState()
    return HomeView()
        .environmentObject(appState)
    //CompetitionResultView()
}
