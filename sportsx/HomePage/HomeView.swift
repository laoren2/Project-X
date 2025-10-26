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
import UIKit


struct HomeView: View {
    @ObservedObject var userManager = UserManager.shared
    @StateObject private var viewModel = HomeViewModel()
    @State private var showSportPicker = false
    //@State private var isDragging: Bool = false     // 是否处于拖动中
    @State private var searchText: String = ""
    @State private var filteredPersonInfos: [PersonInfoCard] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .defaultBackground.softenColor(blendWithWhiteRatio: 0.2),
                            .defaultBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
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
                            .foregroundStyle(.white)
                            .font(.system(size: 15))
                            
                            if !searchText.isEmpty {
                                CommonIconButton(icon: "xmark.circle.fill") {
                                    withAnimation {
                                        searchText = ""
                                    }
                                    filteredPersonInfos.removeAll()
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
                    .padding(.trailing, 8)
                    
                    CommonTextButton(text: "搜索") {
                        filteredPersonInfos.removeAll()
                        searchAnyPersonInfoCard()
                    }
                    .foregroundStyle(.white)
                }
                .padding(.bottom, 10)
                .padding(.horizontal, 16)
                
                ZStack(alignment: .top) {
                    SquareView(viewModel: viewModel)
                    
                    if !searchText.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(filteredPersonInfos) { person in
                                    PersonInfoCardView(person: person)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                        }
                        .background(.ultraThinMaterial)
                    }
                }
                .hideKeyboardOnScroll()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.keyboard)
        .onValueChange(of: viewModel.reminderEnabled) {
            if viewModel.reminderEnabled {
                viewModel.enableReminder()
            } else {
                viewModel.disableReminder()
            }
        }
        .onValueChange(of: userManager.isLoggedIn) {
            if userManager.isLoggedIn {
                viewModel.fetchStatus()
            }
        }
    }
    
    func searchAnyPersonInfoCard() {
        guard var components = URLComponents(string: "/user/user_card/phone") else { return }
        components.queryItems = [
            URLQueryItem(name: "phone_number", value: searchText)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: PersonInfoDTO.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    filteredPersonInfos.append(
                        PersonInfoCard(
                            userID: unwrappedData.user_id,
                            avatarUrl: unwrappedData.avatar_image_url,
                            name: unwrappedData.nickname)
                    )
                }
            default: break
            }
        }
    }
}

/*struct TabButton: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            Button(action: action) {
                Text(title)
                    .fontWeight(isSelected ? .bold : .regular) // 选中状态下字体加粗
                    .foregroundColor(isSelected ? .white : .secondText)
            }
            
            if isSelected {
                Rectangle()
                    .frame(width: 20, height: 2) // 控制条状UI的宽度和高度
                    .foregroundColor(.white)
                    .matchedGeometryEffect(id: "underline", in: namespace)
            } else {
                Rectangle()
                    .frame(width: 20, height: 2)
                    .foregroundColor(.clear)
            }
        }
    }
}*/

/*struct RunningSquareView: View {
    var body: some View {
        VStack {
            Text("Running广场")
                .font(.largeTitle)
                .padding()
            Spacer()
        }
    }
}*/

// 示例功能页面
struct SportSkillView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.defaultBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Text("Sport Skill页面")
                    .font(.largeTitle)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        //.border(.red)
        .enableSwipeBackGesture()
    }
}

struct ActivityView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.defaultBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Text("Activity页面")
                    .font(.largeTitle)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        //.border(.red)
        .enableSwipeBackGesture()
    }
}

struct SquareView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: HomeViewModel
    @State private var adHeight: CGFloat = 200.0
    @State private var businessHeight: CGFloat = 150.0
    //@Binding var isDragging: Bool
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // 广告活动推荐区域
                AdsBannerView(width: UIScreen.main.bounds.width - 32, height: adHeight, ads: viewModel.ads)
                
                // 功能组件区域
                HStack(spacing: 0) {
                    ForEach(viewModel.features) { feature in
                        VStack {
                            Image(systemName: feature.iconName)
                                .resizable()
                                .frame(width: 40, height: 40)
                            Text(feature.title)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .exclusiveTouchTapGesture {
                            appState.navigationManager.append(feature.destination)
                        }
                    }
                    ForEach(0..<3) { _ in
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 20)
                
                // todo: 签到区域
                SignInSectionView(vm: viewModel)
                
                // 商业化区域
                //HStack() {
                //    Spacer()
                //    AdsBannerView(width: (UIScreen.main.bounds.width - 48) / 2, height: businessHeight, ads: viewModel.business)
                //}
                //.padding(.top, 20)
                
                Spacer()
            }
            .padding(.top, 10)
            .hideKeyboardOnScroll()
            //.onScrollDragChanged($isDragging)
        }
    }
}

struct SignInSectionView: View {
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var vm: HomeViewModel
    @State var showSheet: Bool = false
    @State var tempDate: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("每日签到")
                    .font(.headline)
                    .foregroundColor(.orange)
                Image(systemName: "gift")
                    .foregroundColor(.orange)
                    .font(.system(size: 15))
                
                Spacer()
                
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundColor(vm.reminderEnabled ? .orange : .secondText)
                    Toggle("", isOn: $vm.reminderEnabled)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                        .scaleEffect(0.8)
                }
            }
            HStack(spacing: 4) {
                //Text("已连续签到 \(vm.continuousDays) 天")
                //    .font(.caption)
                //    .foregroundColor(.secondText)
                Image(systemName: "v.circle.fill")
                    .font(.system(size: 12))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.red)
                Text("订阅领取更多签到奖励")
                    .font(.caption)
                    .foregroundColor(.secondText)
                Spacer()
                if vm.reminderEnabled {
                    HStack {
                        Text("提醒时间: \(vm.reminderTimeString)")
                        Button("修改") {
                            showSheet = true
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondText)
                }
            }
            if userManager.isLoggedIn {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.items) { day in
                            SignInDayView(vm: vm, day: day)
                        }
                    }
                    .padding(.vertical, 6)
                }
            } else {
                HStack {
                    Spacer()
                    Text("请先登录")
                        .foregroundStyle(Color.secondText)
                    Spacer()
                }
                .padding(.vertical)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
            }
        }
        .padding()
        .sheet(isPresented: $showSheet) {
            VStack(spacing: 20) {
                HStack {
                    Button("取消") {
                        showSheet = false
                    }
                    Spacer()
                    Button("保存") {
                        vm.updateReminderTime(tempDate)
                        showSheet = false
                    }
                }
                DatePicker("提醒时间", selection: $tempDate, displayedComponents: .hourAndMinute)
                Spacer()
            }
            .padding()
            .presentationDetents([.fraction(0.2)])
            .interactiveDismissDisabled() // 防止点击过快导致弹窗高度错误
            .onStableAppear {
                tempDate = vm.reminderTime
            }
        }
    }
}

struct SignInDayView: View {
    @ObservedObject var vm: HomeViewModel
    let day: SignInDay

    private var dayLabel: String {
        if Calendar.current.isDateInToday(day.date) {
            return "今天"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MM/dd"
            return df.string(from: day.date)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .frame(width: 60, height: 30)
                    .foregroundStyle(BackgroundColor)
                
                if day.state == .claimed {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white)
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: day.ccassetType.iconName)
                        Text("+\(day.ccassetReward)")
                    }
                    .font(.system(size: 12))
                    .fontWeight(.semibold)
                    .foregroundStyle(day.state == .future ? Color.secondText : Color.white)
                }
                if vm.isLoading {
                    ProgressView()
                }
            }
            .onTapGesture {
                if (!vm.isLoading) && day.state == .available && Calendar.current.isDateInToday(day.date) {
                    vm.signInToday()
                }
            }
            ZStack {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .frame(width: 60, height: 30)
                        .foregroundStyle(VipBackgroundColor)
                    Image(systemName: "v.circle.fill")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.red)
                        .offset(x: -5, y: -5)
                }
                if day.state_vip == .claimed {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white)
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: day.ccassetTypeVip.iconName)
                        Text("+\(day.ccassetRewardVip)")
                    }
                    .font(.system(size: 12))
                    .fontWeight(.semibold)
                    .foregroundStyle(day.state == .future ? Color.secondText : Color.white)
                }
                if vm.isLoadingVip {
                    ProgressView()
                }
            }
            .onTapGesture {
                if day.state == .available && Calendar.current.isDateInToday(day.date) {
                    vm.signInTodayVip()
                }
            }
            Text(dayLabel)
                .font(.caption2)
                .foregroundColor(day.state == .future ? Color.secondText : Color.white)
        }
        .padding(10)
        .background(backgroundView)
        .cornerRadius(10)
        .opacity(day.state == .future ? 0.8 : 1.0)
    }
    
    private var BackgroundColor: Color {
        switch day.state {
        case .claimed:
            return Color.green.opacity(0.4)
        case .available:
            return Color.orange.opacity(0.4)
        case .future:
            return Color.gray.opacity(0.2)
        }
    }
    
    private var VipBackgroundColor: Color {
        switch day.state_vip {
        case .claimed:
            return Color.green.opacity(0.4)
        case .available:
            return Color.red.opacity(0.4)
        case .future:
            return Color.gray.opacity(0.2)
        }
    }

    private var backgroundView: some View {
        switch day.state {
        case .claimed:
            return AnyView(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.6), lineWidth: 3)
            )
        case .available:
            return AnyView(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.6), lineWidth: 3)
            )
        case .future:
            return AnyView(
                RoundedRectangle(cornerRadius: 10)
                    .foregroundStyle(Color.gray.opacity(0.1))
            )
        }
    }
}

#Preview {
    let appState = AppState.shared
    return HomeView()
        .environmentObject(appState)
        .preferredColorScheme(.dark)
}
