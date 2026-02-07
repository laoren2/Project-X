//
//  RunningCompetitionView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/15.
//

import SwiftUI
import MapKit


struct RunningCompetitionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = RunningCompetitionViewModel()
    @ObservedObject var centerViewModel: CompetitionCenterViewModel
    @ObservedObject var locationManager = LocationManager.shared
    @ObservedObject var userManager = UserManager.shared
    let assetManager = AssetManager.shared
    
    @State private var chevronDirection: Bool = true
    @State private var chevronDirection2: Bool = true
    @State private var selectedTrackForFullMap: RunningTrack? = nil
    
    @Binding var isDragging: Bool
    
    let globalConfig = GlobalConfig.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    // 赛事选择区域
                    HStack(alignment: .center) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("competition.register.team.3")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.secondText)
                        }
                        .exclusiveTouchTapGesture {
                            appState.navigationManager.append(.runningTeamManagementView)
                        }
                        Spacer()
                        if viewModel.events.isEmpty {
                            Text("competition.event.error.no_events")
                                .foregroundColor(.secondText)
                                .padding()
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.events) { event in
                                        Text(event.name)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                            .frame(width: 100, height: 50)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(viewModel.selectedEvent?.eventID == event.eventID ?
                                                          Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(viewModel.selectedEvent?.eventID == event.eventID ?
                                                            Color.orange.opacity(0.6) : Color.clear, lineWidth: 2)
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
                        VStack(spacing: 4) {
                            Image("record")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30)
                            Text("competition.record")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.secondText)
                        }
                        .exclusiveTouchTapGesture {
                            appState.navigationManager.append(.runningRecordManagementView)
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    ScrollView {
                        if let event = viewModel.selectedEvent {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    Text("competition.event.info")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .foregroundColor(.white)
                                    Spacer()
                                    HStack {
                                        Text("action.detail")
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondText)
                                    .exclusiveTouchTapGesture {
                                        appState.navigationManager.append(.runningEventDetailView(eventID: event.eventID))
                                    }
                                }
                                
                                Divider()
                                
                                (Text("competition.begin_date") + Text(": ") + Text(LocalizedStringKey(DateDisplay.formattedDate(event.startDate))))
                                    .font(.subheadline)
                                    .foregroundColor(.secondText)
                                
                                (Text("competition.end_date") + Text(": ") + Text(LocalizedStringKey(DateDisplay.formattedDate(event.endDate))))
                                    .font(.subheadline)
                                    .foregroundColor(.secondText)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        }
                    }
                    
                    // 赛道选择
                    if viewModel.tracks.isEmpty {
                        Text("competition.track.error.no_tracks")
                            .foregroundColor(.secondText)
                            .padding()
                            .offset(y: chevronDirection ? 0 : -310) // 控制视图滑出/滑入
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
                                                      Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(viewModel.selectedTrack?.trackID == track.trackID ?
                                                        Color.orange : Color.clear, lineWidth: 1)
                                        )
                                        .exclusiveTouchTapGesture {
                                            // 防止频繁刷新
                                            if viewModel.selectedTrack?.trackID != track.trackID {
                                                viewModel.switchTrack(to: track)
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 1)
                            .padding(.horizontal, 1)
                        }
                    }
                    
                    // 赛道信息
                    if let track = viewModel.selectedTrack {
                        VStack(alignment: .leading, spacing: 12) {
                            ScrollView {
                                ZStack {
                                    TrackMapView(
                                        fromCoordinate: CoordinateConverter.parseCoordinate(coordinate: track.from),
                                        toCoordinate: CoordinateConverter.parseCoordinate(coordinate: track.to),
                                        startRadius: CLLocationDistance(track.fromRadius),
                                        endRadius: CLLocationDistance(track.toRadius)
                                    )
                                    .frame(height: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )
                                    .shadow(radius: 2)
                                    .disabled(true)

                                    Rectangle()
                                        .fill(Color.clear)
                                        .contentShape(Rectangle())
                                        .exclusiveTouchTapGesture {
                                            selectedTrackForFullMap = track
                                        }
                                }
                                .offset(y: chevronDirection ? 0 : -310)
                            }
                            
                            VStack(spacing: 12) {
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
                                
                                // 赛道信息卡片
                                VStack(alignment: .leading, spacing: 10) {
                                    // 赛道标题
                                    HStack {
                                        Text("competition.track.info")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .lineLimit(1)
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        // 参与人数信息
                                        Text("competition.track.total_number \(track.totalParticipants)")
                                            .font(.caption)
                                            .foregroundColor(.secondText)
                                            .lineLimit(1)
                                    }
                                    
                                    Divider()
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "calendar")
                                        Text("competition.begin_date") + Text(": ") + Text(LocalizedStringKey(DateDisplay.formattedDate(track.startDate)))
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondText)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "flag.checkered")
                                        Text("competition.end_date") + Text(": ") + Text(LocalizedStringKey(DateDisplay.formattedDate(track.endDate)))
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondText)
                                    
                                    Divider()
                                    
                                    // 赛道详细信息
                                    let infoItems: [(icon: String, text: String, value: String, unit: String?, isSysIcon: Bool)] = [
                                        ("terrain", "competition.track.terrain", track.terrainType.displayName, nil, false),
                                        (track.elevationDifference >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill", "competition.track.altitude", "\(track.elevationDifference)", "distance.m", true),
                                        ("total_distance", "competition.track.distance", "\(track.distance)", "distance.km", false),
                                        ("voucher", "competition.track.prize_pool", "\(track.prizePool)", nil, false),
                                        ("sub_region", "competition.track.sub_region", track.regionName, nil, false),
                                        ("season_score", "competition.track.score", "\(track.score)", nil, false)
                                    ]
                                    HStack(alignment: .top) {
                                        Spacer()
                                        VStack(alignment: .leading, spacing: 10) {
                                            ForEach(0..<infoItems.count, id: \.self) { index in
                                                if index <= (infoItems.count - 1) / 2 {
                                                    InfoItemView(
                                                        iconName: infoItems[index].icon,
                                                        text: infoItems[index].text,
                                                        param: infoItems[index].value,
                                                        unit: infoItems[index].unit,
                                                        isSysIcon: infoItems[index].isSysIcon
                                                    )
                                                }
                                            }
                                        }
                                        Spacer()
                                        VStack(alignment: .leading, spacing: 10) {
                                            ForEach(0..<infoItems.count, id: \.self) { index in
                                                if index > (infoItems.count - 1) / 2 {
                                                    InfoItemView(
                                                        iconName: infoItems[index].icon,
                                                        text: infoItems[index].text,
                                                        param: infoItems[index].value,
                                                        unit: infoItems[index].unit,
                                                        isSysIcon: infoItems[index].isSysIcon
                                                    )
                                                }
                                            }
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("competition.team.info")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .lineLimit(1)
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        HStack {
                                            Text("tab.my")
                                            Image(systemName: "chevron.right")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.secondText)
                                        .lineLimit(1)
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.runningTeamManagementView)
                                        }
                                    }
                                    Divider()
                                    HStack(spacing: 12) {
                                        Text("competition.team.create")
                                            .font(.system(size: 15))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.white.opacity(0.1))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.secondText, lineWidth: 2)
                                                    )
                                            )
                                            .exclusiveTouchTapGesture {
                                                guard let competitionDate = track.endDate, competitionDate > Date() else {
                                                    let toast = Toast(message: "competition.track.error.closed")
                                                    ToastManager.shared.show(toast: toast)
                                                    return
                                                }
                                                appState.navigationManager.append(.runningTeamCreateView(trackID: track.trackID, competitionDate: competitionDate))
                                            }
                                        
                                        Text("competition.team.join")
                                            .font(.system(size: 15))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.white.opacity(0.1))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.secondText, lineWidth: 2)
                                                    )
                                            )
                                            .exclusiveTouchTapGesture {
                                                guard let competitionDate = track.endDate, competitionDate > Date() else {
                                                    let toast = Toast(message: "competition.track.error.closed")
                                                    ToastManager.shared.show(toast: toast)
                                                    return
                                                }
                                                appState.navigationManager.append(.runningTeamJoinView(trackID: track.trackID))
                                            }
                                    }
                                    .foregroundStyle(Color.white)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                
                                if let rankInfo = viewModel.selectedRankInfo {
                                    VStack(spacing: 10) {
                                        HStack(alignment: .top) {
                                            Text("competition.track.my_score")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                            Spacer()
                                            HStack {
                                                Text("competition.track.leaderboard")
                                                Image(systemName: "chevron.right")
                                            }
                                            .font(.subheadline)
                                            .exclusiveTouchTapGesture {
                                                appState.navigationManager.append(.runningRankingListView(trackID: track.trackID, gender: UserManager.shared.user.gender ?? .male))
                                            }
                                        }
                                        .foregroundColor(.white)
                                        Divider()
                                        HStack {
                                            Text("competition.record.valid_time") + Text(": \(TimeDisplay.formattedTime(rankInfo.duration, showFraction: true))")
                                            Spacer()
                                            if let rank = rankInfo.rank {
                                                Text("competition.track.leaderboard.ranking") + Text(": \(rank)")
                                            } else {
                                                Text("competition.track.leaderboard.ranking") + Text(": ") + Text("error.no_data")
                                            }
                                            Spacer()
                                            Text("competition.track.leaderboard.score") + Text(": \(rankInfo.score ?? 0)")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.secondText)
                                        Divider()
                                        HStack(spacing: 4) {
                                            Text("competition.track.leaderboard.reference_reward") + Text(":")
                                            Image(CCAssetType.voucher.iconName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 15)
                                            Text("\(rankInfo.voucherAmount ?? 0)")
                                            Spacer()
                                            if let recordID = rankInfo.recordID {
                                                HStack(spacing: 4) {
                                                    Text("competition.record.detail")
                                                    Image(systemName: "chevron.right")
                                                }
                                                .exclusiveTouchTapGesture {
                                                    appState.navigationManager.append(.runningRecordDetailView(recordID: recordID))
                                                }
                                            } else {
                                                Text("competition.record.no_data")
                                            }
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.secondText)
                                        .padding(.vertical, 4)
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                                } else {
                                    HStack(alignment: .top) {
                                        Text("competition.track.my_score")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                        Spacer()
                                        Text("toast.no_login.2")
                                            .font(.headline)
                                        Spacer()
                                        HStack {
                                            Text("competition.track.leaderboard")
                                            Image(systemName: "chevron.right")
                                        }
                                        .font(.subheadline)
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.runningRankingListView(trackID: track.trackID, gender: UserManager.shared.user.gender ?? .male))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                                }
                            }
                            .offset(y: chevronDirection ? 0 : -310)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 180)
                .padding(.top, 8)
                .onScrollDragChanged($isDragging)
            }
            
            // 报名按钮区域
            // todo: 解决切换赛道时因selectedTrack变化导致的闪烁问题
            if let track = viewModel.selectedTrack, !appState.competitionManager.isRecording {
                HStack {
                    Spacer()
                    Text("competition.register.now")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Spacer()
                    // 单人按钮
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: "person")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                        Text("competition.register.single")
                            .font(.subheadline)
                            .foregroundColor(.secondText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        CachedAsyncImage(
                            urlString: track.singleRegisterCardUrl
                        )
                        .id(track.singleRegisterCardUrl)     // 强制重建视图
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .clipped()
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.yellow.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.yellow.opacity(0.8), lineWidth: 1.5)
                            )
                            .shadow(color: Color.yellow.opacity(0.1), radius: 3, x: 0, y: 2)
                    )
                    .exclusiveTouchTapGesture {
                        singleRegister()
                    }
                    .disabled(appState.competitionManager.isRecording)
                    
                    // 组队按钮
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: "person.3")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                        Text("competition.register.team")
                            .font(.subheadline)
                            .foregroundColor(.secondText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        CachedAsyncImage(
                            urlString: track.teamRegisterCardUrl
                        )
                        .id(track.teamRegisterCardUrl)     // 强制重建视图
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .clipped()
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.orange.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.8), lineWidth: 1.5)
                            )
                            .shadow(color: Color.orange.opacity(0.1), radius: 3, x: 0, y: 2)
                    )
                    .exclusiveTouchTapGesture {
                        PopupWindowManager.shared.presentPopup(
                            title: "competition.register.team.2",
                            bottomButtons: []
                        ) {
                            TeamRegisterView()
                        }
                    }
                    .disabled(appState.competitionManager.isRecording)
                }
                .padding(10)
                .background(Color.defaultBackground)
                .padding(.bottom, 85)
            }
        }
        .onValueChange(of: locationManager.regionID) {
            if let regionID = locationManager.regionID {
                viewModel.fetchEvents(with: regionID)
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
        .onValueChange(of: userManager.isLoggedIn) {
            if userManager.isLoggedIn {
                if let track = viewModel.selectedTrack {
                    viewModel.queryRankInfo(trackID: track.trackID)
                }
            }
        }
        .onStableAppear {
            if (!viewModel.didLoad) || globalConfig.refreshCompetitionView {
                if let regionID = locationManager.regionID {
                    viewModel.fetchEvents(with: regionID)
                }
                globalConfig.refreshCompetitionView  = false
                globalConfig.refreshRankInfo  = false
            } else if globalConfig.refreshRankInfo, let trackID = viewModel.selectedTrack?.trackID {
                viewModel.queryRankInfo(trackID: trackID)
                globalConfig.refreshRankInfo  = false
            }
            DispatchQueue.main.async {
                viewModel.didLoad = true
            }
        }
        .ignoresSafeArea(.keyboard)
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(item: $selectedTrackForFullMap) { track in
            FullScreenMapView(
                fromCoordinate: CoordinateConverter.parseCoordinate(coordinate: track.from),
                toCoordinate: CoordinateConverter.parseCoordinate(coordinate: track.to),
                startRadius: CLLocationDistance(track.fromRadius),
                endRadius: CLLocationDistance(track.toRadius)
            )
        }
    }
    
    // 单人报名
    func singleRegister() {
        guard let track = viewModel.selectedTrack else {
            let toast = Toast(message: "competition.register.result.failed.no_track")
            ToastManager.shared.show(toast: toast)
            return
        }
        
        guard var components = URLComponents(string: "/competition/running/single_register") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: track.trackID)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningRegisterResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        assetManager.updateCPAsset(assetID: unwrappedData.asset_id, newBalance: unwrappedData.new_balance)
                        viewModel.currentRecord = RunningRaceRecord(from: unwrappedData.record)
                        PopupWindowManager.shared.presentPopup(
                            title: "competition.register.result.success",
                            message: "competition.register.single.result.success",
                            bottomButtons: [
                                .cancel("competition.register.single.action.later"),
                                .confirm("competition.register.single.action.now") {
                                    if !appState.competitionManager.isRecording, let record = viewModel.currentRecord {
                                        appState.competitionManager.resetRunningRaceRecord(record: record)
                                        appState.navigationManager.append(.competitionCardSelectView)
                                        viewModel.currentRecord = nil
                                    }
                                }
                            ]
                        )
                    }
                }
            default: break
            }
        }
    }
}

struct RunningEventDetailView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @State var event: RunningEvent?
    @State var backgroundColor: Color = .defaultBackground
    let eventID: String
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .exclusiveTouchTapGesture {
                        navigationManager.removeLast()
                    }
                
                Spacer()
                
                Text("competition.event.detail")
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
            if let event = event {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 背景图片
                        CachedAsyncImage(
                            urlString: event.image_url
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
                                .foregroundStyle(Color.white)
                            // 比赛时间
                            HStack {
                                Image(systemName: "calendar")
                                (Text(LocalizedStringKey(DateDisplay.formattedDate(event.startDate))) + Text("-") + Text(LocalizedStringKey(DateDisplay.formattedDate(event.endDate))))
                            }
                            .foregroundStyle(Color.secondText)
                            
                            // 赛事详情
                            VStack(alignment: .leading, spacing: 8) {
                                Text("competition.event.detail")
                                    .font(.headline)
                                    .foregroundStyle(Color.white)
                                Text(event.description)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondText)
                            }
                            
                            // 比赛规则
                            VStack(alignment: .leading, spacing: 8) {
                                Text("competition.event.precautions")
                                    .font(.headline)
                                    .foregroundStyle(Color.white)
                                Text("competition.event.running.precautions.content")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondText)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("error.no_data")
                        .foregroundStyle(Color.thirdText)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .background(backgroundColor)
        .onFirstAppear {
            queryEventDetail()
        }
    }
    
    func downloadImages(url: String) {
        NetworkService.downloadImage(from: url) { image in
            if let image = image {
                if let avg = ImageTool.averageColor(from: image) {
                    DispatchQueue.main.async {
                        self.backgroundColor = avg.bestSoftDarkReadableColor()
                    }
                }
            }
        }
    }
    
    func queryEventDetail() {
        guard var components = URLComponents(string: "/competition/running/query_event_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "event_id", value: eventID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: RunningEventInfoDTO.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        event = RunningEvent(from: unwrappedData)
                    }
                    downloadImages(url: unwrappedData.image_url)
                }
            default: break
            }
        }
    }
}

// 创建队伍页面
struct RunningTeamCreateView: View {
    @EnvironmentObject var appState: AppState
    let assetManager = AssetManager.shared
    let trackID: String
    let competitionDate: Date
    
    // 添加队伍字段
    @State var teamTitle: String = ""
    @State var teamDescription: String = ""
    @State var teamSize: Int = 5 // 默认值
    @State var teamCompetitionDate = Date().addingTimeInterval(3600 * 2)
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
                    Text("action.create")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .exclusiveTouchTapGesture {
                            submitCreateTeamForm()
                        }
                }
                (Text("action.create") + Text("competition.register.team.3"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading) {
                    // 队伍名称
                    Text("competition.team.basic_info")
                        .font(.title)
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    TextField(text: $teamTitle) {
                        Text("competition.team.name")
                            .foregroundColor(.thirdText)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .onValueChange(of: teamTitle) {
                        DispatchQueue.main.async {
                            if teamTitle.count > 15 {
                                teamTitle = String(teamTitle.prefix(15)) // 限制为最多10个字符
                            }
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Text("user.intro.words_entered \(teamTitle.count) \(15)")
                            .font(.footnote)
                            .foregroundStyle(Color.thirdText)
                    }
                    .padding(.bottom, 10)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $teamDescription)
                            .frame(minHeight: 120)
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
                            Text("competition.team.intro")
                                .foregroundColor(.thirdText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Text("user.intro.words_entered \(teamDescription.count) \(50)")
                            .font(.footnote)
                            .foregroundStyle(Color.thirdText)
                    }
                    
                    // 队伍设置
                    Text("competition.team.setup")
                        .font(.title)
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    Stepper("competition.team.member.count \(teamSize)", value: $teamSize, in: 2...10)
                        .foregroundStyle(Color.secondText)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Text("competition.match_date")
                            Image(systemName: "info.circle")
                                .font(.subheadline)
                                .exclusiveTouchTapGesture {
                                    PopupWindowManager.shared.presentPopup(
                                        title: "competition.team.manage.start_date.popup.title",
                                        message: "competition.team.create.start_date.popup.content",
                                        bottomButtons: [
                                            .confirm()
                                        ]
                                    )
                                }
                        }
                        Spacer()
                        DatePicker("", selection: $teamCompetitionDate, in: Date()...competitionDate)
                            .tint(Color.orange)
                    }
                    .foregroundStyle(Color.secondText)
                    HStack {
                        HStack(spacing: 4) {
                            Text("competition.team.public")
                            Image(systemName: "info.circle")
                                .font(.subheadline)
                                .exclusiveTouchTapGesture {
                                    PopupWindowManager.shared.presentPopup(
                                        title: "competition.team.manage.public.popup.title",
                                        message: "competition.team.manage.public.popup.content",
                                        bottomButtons: [
                                            .confirm()
                                        ]
                                    )
                                }
                        }
                        Spacer()
                        Toggle("", isOn: $isPublic)
                            .tint(.green)
                    }
                    .foregroundStyle(Color.secondText)
                }
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .background(Color.defaultBackground)
        .hideKeyboardOnScroll()
        .ignoresSafeArea(.keyboard)
        .environment(\.colorScheme, .dark)
    }
    
    func submitCreateTeamForm() {
        guard !teamTitle.isEmpty else {
            let toast = Toast(message: "competition.team.toast.no_name")
            ToastManager.shared.show(toast: toast)
            return
        }
        if teamCompetitionDate < Date() || teamCompetitionDate > competitionDate {
            ToastManager.shared.show(toast: Toast(message: "competition.team.toast.invalid_time"))
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
        let request = APIRequest(path: "/competition/running/create_team", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: TeamCreatedResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.assetManager.updateCPAsset(assetID: unwrappedData.asset_id, newBalance: unwrappedData.new_balance)
                        UIPasteboard.general.string = unwrappedData.team_code
                        self.appState.navigationManager.removeLast()
                        ToastManager.shared.show(toast: Toast(message: "competition.team.create.toast.success"))
                    }
                }
            default: break
            }
        }
    }
}

// 加入队伍页面
struct RunningTeamJoinView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: RunningTeamJoinViewModel
    @ObservedObject var navigationManager = NavigationManager.shared
    
    
    init(trackID: String) {
        _viewModel = StateObject(wrappedValue: RunningTeamJoinViewModel(trackID: trackID))
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
                
                Text("competition.team.join")
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
                    Text("competition.team.join.placeholder")
                        .foregroundStyle(Color.thirdText)
                }
                .padding(8)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .keyboardType(.asciiCapable)
                
                Text("competition.team.join.action")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(8)
                    .onTapGesture {
                        guard viewModel.teamCode.count == 8 else {
                            let toast = Toast(message: "competition.team.join.toast.invalid_teamcode")
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
                        Text("competition.team.join.no_team")
                            .font(.headline)
                            .foregroundColor(.secondText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 200)
                } else {
                    LazyVStack(spacing: 15) {
                        ForEach(viewModel.publicTeams) { team in
                            RunningTeamPublicCard(team: team, viewModel: viewModel)
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
        .enableSwipeBackGesture()
        .hideKeyboardOnScroll()
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $viewModel.showDetailSheet) {
            TeamDescriptionView(showDetailSheet: $viewModel.showDetailSheet, selectedDescription: $viewModel.selectedDescription)
                .presentationDetents([.fraction(0.4)])
                .interactiveDismissDisabled()
        }
        .bottomSheet(isPresented: $viewModel.showIntroSheet, size: .medium) {
            RunningTeamAppliedView(viewModel: viewModel)
        }
        .onFirstAppear {
            Task {
                await viewModel.queryPublicTeams(withLoadingToast: true, reset: true)
            }
        }
    }
}

struct RunningTeamAppliedView: View {
    @State var introduction: String = ""
    @ObservedObject var viewModel: RunningTeamJoinViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Button(action: {
                    viewModel.showIntroSheet = false
                }) {
                    Text("action.cancel")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondText)
                }
                
                Spacer()
                
                (Text("action.edit") + Text("competition.team.applied.info"))
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action:{
                    //UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    appliedJoinTeam()
                }) {
                    Text("competition.team.action.applied")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.orange)
                }
            }
            //.padding()
            
            VStack {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $introduction)
                        .frame(minHeight: 100)
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
                        Text("competition.team.applied.info")
                            .foregroundColor(.thirdText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                    }
                }
                
                HStack {
                    Spacer()
                    Text("user.intro.words_entered \(introduction.count) \(50)")
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
        
        let request = APIRequest(path: "/competition/running/applied_join_team", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    viewModel.showIntroSheet = false
                    ToastManager.shared.show(toast: Toast(message: "competition.team.applied.toast.success"))
                }
            default: break
            }
        }
    }
}

struct RunningTeamPublicCard: View {
    @EnvironmentObject var appState: AppState
    let team: RunningTeamAppliedCard
    @ObservedObject var viewModel: RunningTeamJoinViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和人数
            HStack {
                Text(team.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("common.member.a/b \(team.member_count) \(team.max_member_size)")
                    .font(.subheadline)
                    .foregroundColor(.secondText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.thirdText, lineWidth: 1)
                    )
            }
            
            // 队长信息
            HStack(spacing: 8) {
                Text("competition.team.leader")
                    .font(.subheadline)
                    .foregroundColor(.secondText)
                CachedAsyncImage(
                    urlString: team.leader_avatar_url
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .exclusiveTouchTapGesture {
                    appState.navigationManager.append(.userView(id: team.leader_id))
                }
                
                Text("\(team.leader_name)")
                    .font(.subheadline)
                    .foregroundColor(.secondText)
            }
            
            // 分隔线
            Divider()
            
            // 底部信息
            HStack {
                (Text("competition.match_date") + Text(": ") + Text(LocalizedStringKey(DateDisplay.formattedDate(team.competition_date))))
                    .font(.caption)
                    .foregroundColor(Color.thirdText)
                Spacer()
                // 详情按钮
                CommonTextButton(text: "action.detail") {
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
                CommonTextButton(text: "competition.team.action.applied") {
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
