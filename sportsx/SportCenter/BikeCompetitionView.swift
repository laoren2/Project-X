//
//  BikeCompetitionView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/7.
//

import SwiftUI
import MapKit


struct BikeCompetitionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = BikeCompetitionViewModel()
    @ObservedObject var centerViewModel: CompetitionCenterViewModel
    @ObservedObject var locationManager = LocationManager.shared
    @ObservedObject var navigationManager = NavigationManager.shared
    let assetManager = AssetManager.shared
    
    @State private var selectedDetailEvent: BikeEvent? = nil
    @State private var chevronDirection: Bool = true
    @State private var chevronDirection2: Bool = true
    @State private var firstOnAppear = true
    
    @Binding var isDragging: Bool
    
    let globalConfig = GlobalConfig.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    // 赛事选择区域
                    HStack {
                        // 添加1个按钮管理我的队伍
                        VStack(spacing: 2) {
                            CommonIconButton(icon: "person.2") {
                                appState.navigationManager.append(.bikeTeamManagementView)
                            }
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("队伍")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondText)
                        }
                        Spacer()
                        if viewModel.events.isEmpty {
                            Text("当前区域暂无赛事")
                                .foregroundColor(.secondText)
                                .padding()
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.events) { event in
                                        VStack(alignment: .leading, spacing: 4) {
                                            CommonIconButton(icon: "info.circle") {
                                                selectedDetailEvent = event
                                            }
                                            .foregroundColor(Color.thirdText)
                                            Text(event.name)
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(viewModel.selectedEvent?.eventID == event.eventID ?
                                                      Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(viewModel.selectedEvent?.eventID == event.eventID ?
                                                        Color.blue : Color.clear, lineWidth: 2)
                                        )
                                        .exclusiveTouchTapGesture {
                                            // 防止频繁刷新
                                            if viewModel.selectedEvent?.eventID != event.eventID {
                                                //withAnimation {
                                                    viewModel.switchEvent(to: event)
                                                //}
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 2)
                            }
                        }
                        Spacer()
                        // 添加1个按钮管理我的赛事
                        VStack(spacing: 2) {
                            CommonIconButton(icon: "list.bullet.clipboard") {
                                appState.navigationManager.append(.bikeRecordManagementView)
                            }
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("记录")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    
                    // 使用安全检查显示地图
                    ScrollView {
                        if let track = viewModel.selectedTrack {
                            TrackMapView(
                                fromCoordinate: CoordinateConverter.parseCoordinate(coordinate: track.from),
                                toCoordinate: CoordinateConverter.parseCoordinate(coordinate: track.to)
                            )
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(radius: 2)
                            .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "map")
                                    .font(.system(size: 50))
                                    .foregroundColor(.thirdText)
                                    .opacity(0.5)
                                Text(AttributedString("无赛道数据\n1.请检查当前网络环境\n2.请切换位置区域重试"))
                                    .foregroundColor(.secondText)
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                        }
                    }
                    .frame(height: 200)
                    .disabled(true)
                    
                    HStack {
                        Spacer()
                        Image(systemName: chevronDirection2 ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .contentShape(Rectangle()) // 将整个 HStack 设为可点击区域
                    .exclusiveTouchTapGesture {
                        chevronDirection2.toggle()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation {
                                chevronDirection.toggle()
                            }
                        }
                    }
                    .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                    
                    // 赛道选择
                    if viewModel.tracks.isEmpty {
                        Text("当前赛事暂无可用赛道")
                            .foregroundColor(.secondText)
                            .padding()
                            .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(viewModel.tracks) { track in
                                    Text(track.name)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 20)
                                        .font(.system(size: 15))
                                        .foregroundStyle(viewModel.selectedTrack?.trackID == track.trackID ? .white : .thirdText)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(viewModel.selectedTrack?.trackID == track.trackID ?
                                                      Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(viewModel.selectedTrack?.trackID == track.trackID ?
                                                        Color.blue : Color.clear, lineWidth: 1)
                                        )
                                        .exclusiveTouchTapGesture {
                                            // 防止频繁刷新
                                            if viewModel.selectedTrack?.trackID != track.trackID {
                                                //withAnimation {
                                                    viewModel.switchTrack(to: track)
                                                //}
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 1)
                            .padding(.horizontal, 1)
                        }
                        .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                    }
                    
                    // 赛道信息
                    if let track = viewModel.selectedTrack {
                        VStack(alignment: .leading, spacing: 12) {
                            // 赛道信息卡片
                            VStack(alignment: .leading, spacing: 10) {
                                // 赛道标题
                                HStack {
                                    Text(track.name)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    // 参与人数信息
                                    HStack(spacing: 5) {
                                        Image(systemName: "person.2")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondText)
                                        //.frame(width: 24, height: 24, alignment: .center)
                                        Text("总参与人数: \(track.totalParticipants)")
                                            .font(.caption)
                                            .foregroundColor(.secondText)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Divider()
                                
                                // 赛道详细信息 - 使用LazyVGrid布局
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible(), spacing: 16)
                                ], alignment: .leading, spacing: 12) {
                                    // 海拔差
                                    InfoItemView(
                                        iconName: "arrow.up.arrow.down",
                                        iconColor: .blue,
                                        text: "海拔差: \(track.elevationDifference)"
                                    )
                                    // 奖金池
                                    InfoItemView(
                                        iconName: "dollarsign.circle",
                                        iconColor: .orange,
                                        text: "奖金池: \(track.prizePool)"
                                    )
                                    // 地理区域
                                    InfoItemView(
                                        iconName: "map",
                                        iconColor: .green,
                                        text: "覆盖区域: \(track.regionName)"
                                    )
                                    // 当前参与人数
                                    InfoItemView(
                                        iconName: "person.2",
                                        iconColor: .purple,
                                        text: "当前参与: \(track.currentParticipants)"
                                    )
                                    // 赛道积分
                                    InfoItemView(
                                        iconName: "staroflife.fill",
                                        iconColor: .red,
                                        text: "赛道积分: \(track.score)"
                                    )
                                }
                                .padding(.vertical, 6)
                                
                                Divider()
                                
                                // 按钮区
                                HStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                        Text("创建队伍")
                                    }
                                    .font(.system(size: 15))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .exclusiveTouchTapGesture {
                                        guard let competitionDate = track.endDate, competitionDate > Date() else {
                                            let toast = Toast(message: "比赛已结束")
                                            ToastManager.shared.show(toast: toast)
                                            return
                                        }
                                        navigationManager.append(.bikeTeamCreateView(trackID: track.trackID, competitionDate: competitionDate))
                                    }
                                    
                                    HStack {
                                        Image(systemName: "person.3")
                                        Text("加入队伍")
                                    }
                                    .font(.system(size: 15))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .exclusiveTouchTapGesture {
                                        guard let competitionDate = track.endDate, competitionDate > Date() else {
                                            let toast = Toast(message: "比赛已结束")
                                            ToastManager.shared.show(toast: toast)
                                            return
                                        }
                                        navigationManager.append(.bikeTeamJoinView(trackID: track.trackID))
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            
                            if let rankInfo = viewModel.selectedRankInfo {
                                VStack {
                                    HStack {
                                        Text("我的最好成绩")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                        Spacer()
                                        if let rank = rankInfo.rank {
                                            Text("No. \(rank)")
                                                .font(.headline)
                                        } else {
                                            Text("无数据")
                                                .font(.headline)
                                        }
                                        Spacer()
                                        Text("排行榜")
                                            .font(.subheadline)
                                            .padding(5)
                                            .background(Color.orange.opacity(0.5))
                                            .cornerRadius(8)
                                            .exclusiveTouchTapGesture {
                                                navigationManager.append(.bikeRankingListView(trackID: track.trackID, gender: UserManager.shared.user.gender ?? .male))
                                            }
                                    }
                                    .foregroundColor(.white)
                                    Divider()
                                    HStack(spacing: 0) {
                                        Text("用时: ")
                                        Text(TimeDisplay.formattedTime(rankInfo.duration, showFraction: true))
                                        Spacer()
                                        Text(rankInfo.recordID ?? "未知")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondText)
                                    Divider()
                                    HStack(spacing: 4) {
                                        Image(systemName: "staroflife.fill")
                                        Text("\(rankInfo.score ?? 0)")
                                        Spacer()
                                        Image(systemName: CCAssetType.voucher.iconName)
                                        Text("\(rankInfo.voucherAmount ?? 0)")
                                    }
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                            } else {
                                HStack {
                                    Text("我的最好成绩")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("登陆后查看")
                                            .font(.headline)
                                    Spacer()
                                    Text("排行榜")
                                        .font(.subheadline)
                                        .padding(5)
                                        .background(Color.orange.opacity(0.5))
                                        .cornerRadius(8)
                                        .exclusiveTouchTapGesture {
                                            navigationManager.append(.bikeRankingListView(trackID: track.trackID, gender: UserManager.shared.user.gender ?? .male))
                                        }
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                            }
                        }
                        .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 70)
                .padding(.top, 5)
                .onScrollDragChanged($isDragging)
            }
            
            // 报名按钮区域
            // todo: 解决切换赛道时因selectedTrack变化导致的闪烁问题
            if let track = viewModel.selectedTrack, !appState.competitionManager.isRecording {
                HStack(spacing: 0) {
                    Spacer()
                    Text("立即报名")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 25)
                    Spacer()
                    // 单人按钮
                    ZStack {
                        // 按钮容器
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.yellow.opacity(0.5))
                            .frame(width: 80, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.yellow.opacity(0.8), lineWidth: 1.5)
                            )
                            .shadow(color: Color.yellow.opacity(0.1), radius: 3, x: 0, y: 2)
                        
                        // 按钮文字
                        HStack(alignment: .center, spacing: 4) {
                            Image(systemName: "person")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                            
                            Text("单人")
                                .font(.subheadline)
                                .foregroundColor(.secondText)
                        }
                    }
                    .exclusiveTouchTapGesture {
                        guard let competitionDate = track.endDate, competitionDate > Date() else {
                            let toast = Toast(message: "比赛已结束")
                            ToastManager.shared.show(toast: toast)
                            return
                        }
                        singleRegister()
                    }
                    .disabled(appState.competitionManager.isRecording)
                    .alert(isPresented: $viewModel.showSingleRegisterAlert) {
                        Alert(
                            title: Text("报名成功"),
                            message: Text("单人模式"),
                            primaryButton: .default(Text("稍后开始")),
                            secondaryButton: .default(Text("立即开始")) {
                                if !appState.competitionManager.isRecording, let record = viewModel.currentRecord {
                                    appState.competitionManager.resetBikeRaceRecord(record: record)
                                    appState.navigationManager.append(.competitionCardSelectView)
                                    viewModel.currentRecord = nil
                                }
                            }
                        )
                    }
                    
                    Spacer()
                    
                    // 组队按钮
                    ZStack {
                        // 按钮容器
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.orange.opacity(0.5))
                            .frame(width: 80, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.8), lineWidth: 1.5)
                            )
                            .shadow(color: Color.orange.opacity(0.1), radius: 3, x: 0, y: 2)
                        
                        // 按钮文字
                        HStack(alignment: .center, spacing: 4) {
                            Image(systemName: "person.3")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                            
                            Text("组队")
                                .font(.subheadline)
                                .foregroundColor(.secondText)
                        }
                    }
                    .exclusiveTouchTapGesture {
                        navigationManager.showTeamRegisterSheet = true
                    }
                    .disabled(appState.competitionManager.isRecording)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.defaultBackground)
            }
        }
        .sheet(item: $selectedDetailEvent) { event in
            BikeEventDetailView(event: event)
        }
        .onValueChange(of: locationManager.region) {
            if let region = locationManager.region {
                viewModel.fetchEvents(with: region)
            }
        }
        .onValueChange(of: viewModel.selectedTrack) {
            if let track = viewModel.selectedTrack {
                viewModel.selectedRankInfo = track.rankInfo
                if track.rankInfo == nil {
                    viewModel.queryRankInfo(trackID: track.trackID)
                }
            }
        }
        .onStableAppear {
            if firstOnAppear || globalConfig.refreshCompetitionView {
                if let region = locationManager.region {
                    viewModel.fetchEvents(with: region)
                }
                globalConfig.refreshCompetitionView  = false
                globalConfig.refreshRankInfo  = false
            } else if globalConfig.refreshRankInfo, let trackID = viewModel.selectedTrack?.trackID {
                viewModel.queryRankInfo(trackID: trackID)
                globalConfig.refreshRankInfo  = false
            }
            firstOnAppear = false
        }
        .ignoresSafeArea(.keyboard)
    }
    
    // 单人报名
    func singleRegister() {
        guard let track = viewModel.selectedTrack else {
            let toast = Toast(message: "请选择一条赛道")
            ToastManager.shared.show(toast: toast)
            return
        }
        
        guard var components = URLComponents(string: "/competition/bike/single_register") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: track.trackID)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: BikeRegisterResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        assetManager.updateCPAsset(assetID: unwrappedData.asset_id, newBalance: unwrappedData.new_balance)
                        viewModel.currentRecord = BikeRaceRecord(from: unwrappedData.record)
                        viewModel.showSingleRegisterAlert = true
                    }
                }
            default: break
            }
        }
    }
}

struct BikeEventDetailView: View {
    let event: BikeEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 背景图片
                    CachedAsyncImage(
                        urlString: event.image_url,
                        placeholder: Image("Ads"),
                        errorImage: Image(systemName: "photo.badge.exclamationmark")
                    )
                    .aspectRatio(contentMode: .fill)
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
                            Text("\(DateDisplay.formattedDate(event.startDate)) - \(DateDisplay.formattedDate(event.endDate))")
                                .foregroundColor(.secondary)
                        }
                        
                        // 比赛规则
                        VStack(alignment: .leading, spacing: 8) {
                            Text("比赛规则")
                                .font(.headline)
                            Text(event.description)
                                .font(.subheadline)
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

// 创建队伍页面
struct BikeTeamCreateView: View {
    @EnvironmentObject var appState: AppState
    let assetManager = AssetManager.shared
    let trackID: String
    let competitionDate: Date
    
    // 添加队伍字段
    @State var teamTitle: String = ""
    @State var teamDescription: String = ""
    @State var teamSize: Int = 5 // 默认值
    @State var teamCompetitionDate = Date().addingTimeInterval(86400 * 7) // 默认一周后
    @State var isPublic: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .exclusiveTouchTapGesture {
                            appState.navigationManager.removeLast()
                        }
                    Spacer()
                    Text("创建")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .exclusiveTouchTapGesture {
                            submitCreateTeamForm()
                        }
                }
                Text("创建队伍")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading) {
                    // 队伍名称
                    Text("基本信息")
                        .font(.title)
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    TextField(text: $teamTitle) {
                        Text("队伍名称")
                            .foregroundColor(.thirdText)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .onValueChange(of: teamTitle) {
                        DispatchQueue.main.async {
                            if teamTitle.count > 10 {
                                teamTitle = String(teamTitle.prefix(10)) // 限制为最多10个字符
                            }
                        }
                    }
                    
                    HStack {
                        Text("最多输入10个字符")
                            .font(.footnote)
                            .foregroundStyle(Color.thirdText)
                        
                        Spacer()
                        
                        Text("已输入\(teamTitle.count)/10字符")
                            .font(.footnote)
                            .foregroundStyle(Color.thirdText)
                    }
                    .padding(.bottom, 10)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $teamDescription)
                            .frame(maxHeight: 120)
                            .padding(16)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .onValueChange(of: teamDescription) {
                                DispatchQueue.main.async {
                                    if teamDescription.count > 50 {
                                        teamDescription = String(teamDescription.prefix(50)) // 限制为最多50个字符
                                    }
                                }
                            }
                        if teamDescription.isEmpty {
                            Text("队伍简介（50字以内）")
                                .foregroundColor(.thirdText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                        }
                    }
                    
                    HStack {
                        Text("最多输入50个字符")
                            .font(.footnote)
                            .foregroundStyle(Color.thirdText)
                        
                        Spacer()
                        
                        Text("已输入\(teamDescription.count)/50字符")
                            .font(.footnote)
                            .foregroundStyle(Color.thirdText)
                    }
                    
                    // 队伍设置
                    Text("队伍设置")
                        .font(.title)
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    Stepper("队伍人数: \(teamSize)人", value: $teamSize, in: 2...10)
                        .foregroundStyle(Color.secondText)
                    
                    DatePicker("比赛时间", selection: $teamCompetitionDate, in: Date()...competitionDate)
                        .foregroundStyle(Color.secondText)
                        .tint(Color.orange)
                    
                    // 添加一个开关允许用户选择是否公开队伍信息，开关直接控制viewModel.isPublic
                    Toggle("公开队伍信息", isOn: $isPublic)
                        .tint(.green)
                        .foregroundStyle(Color.secondText)
                }
                .padding(.horizontal)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
        .background(Color.defaultBackground)
        .hideKeyboardOnScroll()
        .environment(\.colorScheme, .dark)
    }
    
    func submitCreateTeamForm() {
        guard !teamTitle.isEmpty else {
            let toast = Toast(message: "请输入队伍名称")
            ToastManager.shared.show(toast: toast)
            return
        }
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        let body: [String: String] = [
            "track_id": trackID,
            "title": teamTitle,
            "description": teamDescription,
            "team_size": "\(teamSize)",
            "competition_date": ISO8601DateFormatter().string(from: teamCompetitionDate),
            "is_public": "\(isPublic)"
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        let request = APIRequest(path: "/competition/bike/create_team", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: TeamCreatedResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.assetManager.updateCPAsset(assetID: unwrappedData.asset_id, newBalance: unwrappedData.new_balance)
                        UIPasteboard.general.string = unwrappedData.team_code
                        self.appState.navigationManager.removeLast()
                    }
                }
            default: break
            }
        }
    }
}

// 加入队伍页面
struct BikeTeamJoinView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: BikeTeamJoinViewModel
    @ObservedObject var navigationManager = NavigationManager.shared
    
    
    init(trackID: String) {
        _viewModel = StateObject(wrappedValue: BikeTeamJoinViewModel(trackID: trackID))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .exclusiveTouchTapGesture {
                        navigationManager.removeLast()
                    }
                
                Spacer()
                
                Text("加入队伍")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            // 队伍码输入区域
            HStack(spacing: 20) {
                TextField(text: $viewModel.teamCode) {
                    Text("输入8位队伍码直接加入")
                        .foregroundStyle(Color.thirdText)
                }
                .padding(8)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .keyboardType(.asciiCapable)
                
                Text("一键加入")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(8)
                    .onTapGesture {
                        guard viewModel.teamCode.count == 8 else {
                            let toast = Toast(message: "请输入合法的8位队伍码")
                            ToastManager.shared.show(toast: toast)
                            return
                        }
                        viewModel.joinTeam()
                    }
            }
            .padding()
            .background(.blue.opacity(0.2))
            
            ScrollView {
                if viewModel.publicTeams.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 10)
                        
                        Text("暂无可加入的队伍")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("当前赛道还没有可加入的队伍，您可以创建一个新队伍")
                            .font(.subheadline)
                            .foregroundColor(.thirdText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 200)
                } else {
                    LazyVStack(spacing: 15) {
                        ForEach(viewModel.publicTeams) { team in
                            BikeTeamPublicCard(team: team, viewModel: viewModel)
                                .onAppear {
                                    if team == viewModel.publicTeams.last && viewModel.hasMore{
                                        Task {
                                            await viewModel.queryPublicTeams(withLoadingToast: false, reset: false)
                                        }
                                    }
                                }
                        }
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
            }
            .refreshable {
                await viewModel.queryPublicTeams(withLoadingToast: false, reset: true)
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
        .sheet(isPresented: $viewModel.showDetailSheet) {
            TeamDescriptionView(showDetailSheet: $viewModel.showDetailSheet, selectedDescription: $viewModel.selectedDescription)
                .presentationDetents([.fraction(0.4)])
                .interactiveDismissDisabled()
        }
        .bottomSheet(isPresented: $viewModel.showIntroSheet, size: .medium) {
            BikeTeamAppliedView(viewModel: viewModel)
        }
        .onFirstAppear {
            Task {
                await viewModel.queryPublicTeams(withLoadingToast: true, reset: true)
            }
        }
    }
}

struct BikeTeamAppliedView: View {
    @State var introduction: String = ""
    @ObservedObject var viewModel: BikeTeamJoinViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Button(action: {
                    viewModel.showIntroSheet = false
                }) {
                    Text("取消")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondText)
                }
                
                Spacer()
                
                Text("编辑申请信息")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action:{
                    //UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    appliedJoinTeam()
                }) {
                    Text("申请")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.orange)
                }
            }
            //.padding()
            
            VStack {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $introduction)
                        .frame(maxHeight: 120)
                        .padding(16)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .onValueChange(of: introduction) {
                            DispatchQueue.main.async {
                                if introduction.count > 50 {
                                    introduction = String(introduction.prefix(50)) // 限制为最多50个字符
                                }
                            }
                        }
                    if introduction.isEmpty {
                        Text("申请信息（50字以内）")
                            .foregroundColor(.thirdText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                    }
                }
                
                HStack {
                    Text("最多输入50个字符")
                        .font(.footnote)
                        .foregroundStyle(Color.thirdText)
                    
                    Spacer()
                    
                    Text("已输入\(introduction.count)/50字符")
                        .font(.footnote)
                        .foregroundStyle(Color.thirdText)
                }
                Spacer()
            }
            //.padding()
        }
        .padding()
        .background(Color.defaultBackground)
        //.hideKeyboardOnScroll()
        .onValueChange(of: viewModel.showIntroSheet) {
            if !viewModel.showIntroSheet {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            } else {
                introduction = ""
            }
        }
    }
    
    func appliedJoinTeam() {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        var body: [String: String] = [
            "team_id": viewModel.selectedTeamID
        ]
        if !introduction.isEmpty {
            body["introduction"] = introduction
        }
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        let request = APIRequest(path: "/competition/bike/applied_join_team", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    viewModel.showIntroSheet = false
                }
            default: break
            }
        }
    }
}

struct BikeTeamPublicCard: View {
    @EnvironmentObject var appState: AppState
    let team: BikeTeamAppliedCard
    @ObservedObject var viewModel: BikeTeamJoinViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和人数
            HStack {
                Text(team.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(team.member_count)/\(team.max_member_size) 人")
                    .font(.subheadline)
                    .foregroundColor(.secondText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            
            // 队长信息
            HStack(spacing: 8) {
                Text("队长")
                    .font(.subheadline)
                    .foregroundColor(.secondText)
                CachedAsyncImage(
                    urlString: team.leader_avatar_url,
                    placeholder: Image(systemName: "person"),
                    errorImage: Image(systemName: "photo.badge.exclamationmark")
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .exclusiveTouchTapGesture {
                    appState.navigationManager.append(.userView(id: team.leader_id, needBack: true))
                }
                
                Text("\(team.leader_name)")
                    .font(.subheadline)
                    .foregroundColor(.secondText)
            }
            
            // 分隔线
            Divider()
            
            // 底部信息
            HStack {
                Text("比赛时间: \(DateDisplay.formattedDate(team.competition_date))")
                    .font(.caption)
                    .foregroundColor(Color.thirdText)
                Spacer()
                // 详情按钮
                CommonTextButton(text: "详情") {
                    viewModel.selectedDescription = team.description
                    viewModel.showDetailSheet = true
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .cornerRadius(8)
                
                // 申请加入按钮
                CommonTextButton(text: "申请加入") {
                    viewModel.selectedTeamID = team.team_id
                    viewModel.showIntroSheet = true
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.gray)
        .cornerRadius(12)
    }
}
