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
    @ObservedObject var viewModel: HomeViewModel
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
                                Text("home.search_text")
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
                    
                    Button("action.search") {
                        searchAnyPersonInfoCard(reset: true)
                    }
                    .foregroundStyle(.white)
                    .disabled(searchText.isEmpty)
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
                                        .onAppear {
                                            if person == filteredPersonInfos.last && viewModel.hasMoreUsers {
                                                searchAnyPersonInfoCard(reset: false)
                                            }
                                        }
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
    
    func searchAnyPersonInfoCard(reset: Bool) {
        if reset {
            filteredPersonInfos.removeAll()
            viewModel.page = 1
        }
        guard var components = URLComponents(string: "/user/user_card/nick_name") else { return }
        components.queryItems = [
            URLQueryItem(name: "nick_name", value: searchText),
            URLQueryItem(name: "page", value: "\(viewModel.page)"),
            URLQueryItem(name: "size", value: "\(viewModel.size)")
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
        NetworkService.sendRequest(with: request, decodingType: PersonInfoResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    if let unwrappedData = data {
                        for user in unwrappedData.users {
                            filteredPersonInfos.append(
                                PersonInfoCard(
                                    userID: user.user_id,
                                    avatarUrl: user.avatar_image_url,
                                    name: user.nickname)
                            )
                        }
                        if unwrappedData.users.count < viewModel.size {
                            viewModel.hasMoreUsers = false
                        } else {
                            viewModel.hasMoreUsers = true
                            viewModel.page += 1
                        }
                        if reset && unwrappedData.users.isEmpty {
                            ToastManager.shared.show(toast: Toast(message: "home.search.toast"))
                        }
                    }
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
                if !viewModel.ads.isEmpty {
                    AdsBannerView(width: UIScreen.main.bounds.width - 32, height: adHeight, ads: viewModel.ads)
                } else {
                    Rectangle()
                        .frame(width: UIScreen.main.bounds.width - 32, height: adHeight)
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .cornerRadius(20)
                }
                
                // 功能组件区域
                HStack(alignment: .bottom, spacing: 0) {
                    let spacings = 5 - viewModel.features.count
                    ForEach(viewModel.features) { feature in
                        VStack(spacing: 5) {
                            if feature.isSysIcon {
                                Image(systemName: feature.iconName)
                                    .font(.system(size: 28))
                            } else {
                                Image(feature.iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                            }
                            Text(feature.title)
                                .font(.system(size: 13))
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .exclusiveTouchTapGesture {
                            appState.navigationManager.append(feature.destination)
                        }
                    }
                    ForEach(Array(0..<spacings), id: \.self) { _ in
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 20)
                
                // 公告区域
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "speaker.wave.2")
                        .frame(width: 20)
                        .foregroundStyle(Color.yellow)
                    Divider()
                    if !viewModel.announcements.isEmpty {
                        TextBannerView(
                            height: 40,
                            texts: viewModel.announcements
                        )
                    } else {
                        Spacer()
                        Text("home.announcament.no_contents")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .exclusiveTouchTapGesture {
                    appState.navigationManager.append(.announcementView)
                }
                
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
            .padding(.bottom, 100)
            .hideKeyboardOnScroll()
            //.onScrollDragChanged($isDragging)
        }
    }
}

struct SignInSectionView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
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
            HStack(alignment: .bottom) {
                Text("home.sign_in.tile")
                    .font(.headline)
                    .foregroundColor(.white)
                Image("vip_benefit_gift")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28)
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
                if !userManager.user.isVip {
                    Text("home.sign_in.vip_tile")
                        .font(.caption)
                        .foregroundColor(.secondText)
                    
                    HStack(spacing: 4) {
                        Image("vip_icon_on")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 18)
                        Image(systemName: "capslock.fill")
                            .foregroundStyle(Color.white)
                            .font(.system(size: 12))
                    }
                    .fontWeight(.semibold)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 5)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
                    .exclusiveTouchTapGesture {
                        guard userManager.isLoggedIn else {
                            UserManager.shared.showingLogin = true
                            return
                        }
                        navigationManager.append(.subscriptionDetailView)
                    }
                } else {
                    Text("home.sign_in.subtile")
                        .font(.caption)
                        .foregroundColor(.secondText)
                }
                Spacer()
                if vm.reminderEnabled {
                    HStack {
                        Text("home.sign_in.reminder_time \(vm.reminderTimeString)")
                        Button("action.change") {
                            showSheet = true
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondText)
                }
            }
            if userManager.isLoggedIn {
                if !vm.items.isEmpty {
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
                        Text("toast.network_error")
                            .foregroundStyle(Color.secondText)
                        Spacer()
                    }
                    .padding(.vertical)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                }
            } else {
                HStack {
                    Spacer()
                    Text("toast.no_login")
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
                    Button("action.cancel") {
                        showSheet = false
                    }
                    .foregroundStyle(Color.thirdText)
                    Spacer()
                    Button("action.save") {
                        vm.updateReminderTime(tempDate)
                        showSheet = false
                    }
                    .foregroundStyle(Color.white)
                }
                DatePicker("home.sign_in.reminder_time", selection: $tempDate, displayedComponents: .hourAndMinute)
                    .tint(Color.orange)
                Spacer()
            }
            .padding()
            .background(Color.defaultBackground)
            .presentationDetents([.fraction(0.2)])
            .interactiveDismissDisabled() // 防止点击过快导致弹窗高度错误
            .onStableAppear {
                tempDate = vm.reminderTime
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct SignInDayView: View {
    @ObservedObject var vm: HomeViewModel
    let day: SignInDay

    private var dayLabel: LocalizedStringKey {
        if Calendar.current.isDateInToday(day.date) {
            return "time.today"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MM/dd"
            return LocalizedStringKey(df.string(from: day.date))
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
                        Image(day.ccassetType.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15)
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
                    vm.signInToday(day: day)
                }
            }
            ZStack {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .frame(width: 60, height: 30)
                        .foregroundStyle(VipBackgroundColor)
                    Image("vip_icon_on")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 18)
                        .offset(x: -6, y: -5)
                }
                if day.state_vip == .claimed {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white)
                } else {
                    HStack(spacing: 2) {
                        Image(day.ccassetTypeVip.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15)
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
                if day.state_vip == .available && Calendar.current.isDateInToday(day.date) {
                    vm.signInTodayVip(day: day)
                }
            }
            Text(dayLabel)
                .font(.caption2)
                .foregroundColor(day.state == .future ? Color.secondText : Color.white)
        }
        .padding(10)
        .background(backgroundView)
        .cornerRadius(10)
        //.opacity(day.state == .future ? 0.8 : 1.0)
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
            return Color.orange.opacity(0.4)
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
                    .foregroundStyle(Color.white.opacity(0.1))
            )
        }
    }
}

struct AnnouncementView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @State var announcements: [AnnouncementInfo] = []
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
                Text("home.announcament.title")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.clear)
                }
            }
            .padding(.horizontal)
            ScrollView {
                VStack(spacing: 40) {
                    ForEach(announcements) { info in
                        VStack {
                            Text(LocalizedStringKey(DateDisplay.formattedDate(info.date)))
                                .foregroundStyle(Color.secondText)
                            Divider()
                            HStack {
                                Text(info.content)
                                    .foregroundStyle(Color.white)
                                    .font(.headline)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onFirstAppear {
            fetchAnnouncements()
        }
    }
    
    func fetchAnnouncements() {
        let request = APIRequest(path: "/homepage/query_announcements", method: .get)
        NetworkService.sendRequest(with: request, decodingType: AnnouncementResponse.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else { return }
                    for announcement in unwrappedData.announcements {
                        self.announcements.append(AnnouncementInfo(from: announcement))
                    }
                default:
                    break
                }
            }
        }
    }
}

/*#Preview {
    let appState = AppState.shared
    return HomeView()
        .environmentObject(appState)
        .preferredColorScheme(.dark)
}*/
