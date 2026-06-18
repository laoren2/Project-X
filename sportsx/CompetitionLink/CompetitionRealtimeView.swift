//
//  CompetitionRealtimeView.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/15.
//

import SwiftUI
import MapKit

struct CompetitionRealtimeView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var dataFusionManager = DataFusionManager.shared
    @ObservedObject var locationManager = LocationManager.shared
    //@State var isReverse: Bool = false
    @State private var chevronDirection: Bool = true
    @State private var chevronDirection2: Bool = true
    //@State private var assertInfo: Bool = false
    @State private var mapMode: MapViewMode = .followUser
    
    
    // 定义两列布局
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // 动态构建 items 数组
    var items: [(String, String, String, Color)] {
        var temp: [(String, String, String, Color)] = []
        let data = appState.competitionManager.realtimeStatisticData
        
        // 距离
        temp.append(("competition.realtime.distance", String(format: "%.2f ", data.distance / 1000), "distance.km", Color.orange))
        // 均速
        temp.append(("competition.realtime.avgspeed", appState.competitionManager.sport == .Bike ? String(format: "%.1f ", data.avgSpeed) : SpeedHelper.paceString(from: data.avgSpeed), appState.competitionManager.sport == .Bike ? "speed.km/h" : "/km", Color.yellow))
        // 累计爬升
        temp.append(("competition.realtime.elev_gain", String(format: "%.1f ", data.elevationGain), "distance.m", Color.purple))
        // 心率
        if let heartRate = data.heartRate {
            temp.append(("competition.realtime.heartrate", "\(Int(heartRate)) ", "heartrate.unit", Color.red))
        }
        // 能耗
        if let energy = data.totalEnergy {
            temp.append(("competition.realtime.energy", "\(Int(energy)) ", "energy.unit", Color.blue))
        }
        // 功率
        if let power = data.power {
            temp.append(("competition.realtime.power", "\(Int(power)) ", "power.unit", Color.green))
        }
        // 步频
        if let stepCadence = data.stepCadence {
            temp.append(("competition.result.stepcadence", "\(Int(stepCadence)) ", "stepCadence.unit", Color.pink))
        }
        // 踏频
        if let pedalCadence = data.pedalCadence {
            temp.append(("competition.result.stepcadence", "\(Int(pedalCadence)) ", "pedalCadence.unit", Color.pink))
        }
        return temp
    }

    // 当前比赛赛道的实时路线（多检查点）
    private var currentRaceRouteData: (routePoints: [RoutePointRealtime], routeType: RouteType)? {
        switch appState.competitionManager.sportFeature {
        case .bikeRace:
            guard let record = appState.competitionManager.currentBikeRecord else { return nil }
            return (record.routePoints, record.routeType)
        case .runningRace:
            guard let record = appState.competitionManager.currentRunningRecord else { return nil }
            return (record.routePoints, record.routeType)
        default:
            return nil
        }
    }

    var body: some View {
        //let _ = Self._printChanges()
        // 显示实时比赛数据
        ZStack(alignment: .bottom) {
            ZStack {
                if let route = currentRaceRouteData {
                    RouteRealtimeMapView(
                        routePoints: route.routePoints,
                        routeType: route.routeType,
                        path: appState.competitionManager.basePathData,
                        nextRoutePointIndex: appState.competitionManager.nextCheckPointIndex,
                        mapMode: $mapMode,
                        userLocation: appState.competitionManager.userLocation,
                        isShowSheet: !chevronDirection
                    )
                    .ignoresSafeArea()
                }
                
                VStack {
                    HStack(alignment: .top) {
                        Button(action: { adjustNavigationPath() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    Spacer()
                }
            }
            VStack {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(mapMode == .overview ? Color.defaultBackground : Color.black.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(mapMode == .overview ? Color.orange : Color.clear, lineWidth: 2)
                            )
                        Image("location2")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                    }
                    .contentShape(Circle())
                    .exclusiveTouchTapGesture {
                        mapMode = .overview
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(mapMode == .followUser ? Color.defaultBackground : Color.black.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(mapMode == .followUser ? Color.orange : Color.clear, lineWidth: 2)
                            )
                        Image("location")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    .contentShape(Circle())
                    .exclusiveTouchTapGesture {
                        mapMode = .followUser
                    }
                }
                .padding(.horizontal)
                
                ZStack {
                    HStack {
                        if let sport = appState.competitionManager.sport {
                            Image(sport.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 20)
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Spacer()
                        HStack(spacing: 2) {
                            if let feature = appState.competitionManager.sportFeature {
                                Image(feature.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 20)
                            }
                            Text(appState.competitionManager.isTeam ? "competition.register.team" : "competition.register.single")
                        }
                        .foregroundStyle(Color.white)
                        .padding(6)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    HStack(alignment: .top, spacing: 5) {
                        Text("GPS")
                            .foregroundStyle(Color.white)
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<4) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(index < locationManager.signalStrength.bars ? locationManager.signalStrength.color : Color.white.opacity(0.3))
                                    .frame(width: 6, height: CGFloat(6 + index * 4))
                            }
                        }
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal)
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: chevronDirection2 ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.white)
                            .bold()
                            .padding(.vertical, 10)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .exclusiveTouchTapGesture {
                        chevronDirection2.toggle()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeIn(duration: 0.2)) {
                                chevronDirection.toggle()
                            }
                        }
                    }
                    if let route = currentRaceRouteData, route.routeType == .multiPoints, appState.competitionManager.isRecording {
                        let checkPoints = route.routePoints.filter {
                            if case .checkpoint = $0 { return true }
                            return false
                        }.count - 2
                        let checkedPoints = min(max(route.routePoints.filter {
                            if case .checkpoint(let cp) = $0 {
                                return cp.isCheck
                            }
                            return false
                        }.count - 1, 0), checkPoints)
                        ZStack {
                            ProgressBar(progress: Double(checkedPoints) / Double(checkPoints))
                                .frame(height: 20)
                            Text("checked \(checkedPoints) / \(checkPoints)")
                                .foregroundStyle(Color.white)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                    ScrollView {
                        VStack(spacing: 20) {
                            // 组队模式显示区域
                            if appState.competitionManager.isTeam && (!appState.competitionManager.isRecording) {
                                if appState.competitionManager.isTeamJoinWindowExpired {
                                    Text("competition.realtime.out_window")
                                        .foregroundColor(.red)
                                } else {
                                    Text("competition.realtime.remaining_time \(appState.competitionManager.teamJoinRemainingTime)")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                }
                            }
                            if !appState.competitionManager.isRecording && !appState.competitionManager.isInValidArea {
                                Text("competition.realtime.start.out_of_area")
                                    .foregroundColor(Color.thirdText)
                            }
                            HStack {
                                let isDisabledInTeamMode = appState.competitionManager.isTeam && appState.competitionManager.isTeamJoinWindowExpired
                                let isGray = (!appState.competitionManager.isInValidArea) || isDisabledInTeamMode || locationManager.signalStrength.bars < 2
                                Spacer()
                                if appState.competitionManager.isRecording {
                                    Text("\(TimeDisplay.formattedTime(dataFusionManager.elapsedTime))")
                                        .font(.system(size: 35, weight: .heavy, design: .rounded))
                                    Spacer()
                                    // 背景按钮
                                    Text("competition.realtime.action.finish")
                                        .font(.system(size: 20))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 20)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                        .exclusiveTouchTapGesture {
                                            PopupWindowManager.shared.presentPopup(
                                                title: "competition.realtime.action.finish",
                                                message: "competition.realtime.popup.finish",
                                                bottomButtons: [
                                                    .cancel(),
                                                    .confirm() {
                                                        appState.competitionManager.stopCompetition()
                                                    }
                                                ]
                                            )
                                        }
                                } else {
                                    Text("competition.realtime.action.start")
                                        .font(.system(size: 30))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(width: 100, height: 100)
                                        .background(isGray ? Color.gray : Color.green)
                                        .clipShape(Circle())
                                        .exclusiveTouchTapGesture {
                                            startCompetition()
                                        }
                                }
                                Spacer()
                            }
                            .foregroundStyle(Color.white)
                            
                            if appState.competitionManager.isRecording {
                                HStack(spacing: 16) {
                                    let bonusTime = appState.competitionManager.matchContext.bonusEachCards.reduce(0) { result, item in
                                        guard item.bonus_time > 0 else {
                                            return result
                                        }
                                        return result + item.bonus_time
                                    }
                                    VStack(spacing: 4) {
                                        Text("competition.realtime.card.time")
                                            .font(.headline)
                                        Text("- \(Int(bonusTime))s")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                    .background(Color.green.opacity(0.8))
                                    .clipShape(Capsule())
                                    
                                    if let route = currentRaceRouteData, route.routeType == .multiPoints {
                                        let penaltyTime: Int = {
                                            guard let lastCheckedIndex = route.routePoints.lastIndex(where: {
                                                if case .checkpoint(let cp) = $0 {
                                                    return cp.isCheck
                                                }
                                                return false
                                            }) else { return 0 }
                                            return route.routePoints[0..<lastCheckedIndex].reduce(0) { result, point in
                                                guard case .checkpoint(let cp) = point,
                                                      !cp.isCheck else {
                                                    return result
                                                }
                                                return result + (cp.penalty ?? 0)
                                            }
                                        }()
                                        VStack(spacing: 4) {
                                            Text("training.route.create.penalty_time")
                                                .font(.headline)
                                            Text("+ \(penaltyTime)s")
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                        }
                                        .foregroundStyle(Color.white)
                                        .frame(maxWidth: .infinity, minHeight: 60)
                                        .background(Color.red.opacity(0.8))
                                        .clipShape(Capsule())
                                    } else {
                                        VStack(spacing: 4) {
                                            Text("training.route.create.penalty_time")
                                                .font(.headline)
                                            Text("+ 0s")
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                        }
                                        .foregroundStyle(Color.white)
                                        .frame(maxWidth: .infinity, minHeight: 60)
                                        .background(Color.red.opacity(0.8))
                                        .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                RealtimePaceCompareView()
                                
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(items, id: \.0) { title, value, unit, color in
                                        VStack {
                                            Text(LocalizedStringKey(title))
                                                .font(.headline)
                                            (Text(value) + Text(LocalizedStringKey(unit)))
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, minHeight: 80)
                                        .background(color.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("competition.realtime.card.benefit")
                                            .font(.title2)
                                            .bold()
                                            .foregroundStyle(Color.secondText)
                                            .padding(.horizontal)
                                        Spacer()
                                    }
                                    if !appState.competitionManager.selectedCards.isEmpty {
                                        ForEach(appState.competitionManager.selectedCards) { card in
                                            HStack(spacing: 16) {
                                                MagicCardView(card: card)
                                                    .frame(width: 60)
                                                VStack(alignment: .leading) {
                                                    Spacer()
                                                    Text(card.name)
                                                        .font(.headline)
                                                        .bold()
                                                        .foregroundStyle(Color.secondText)
                                                    Spacer()
                                                    if let index = appState.competitionManager.matchContext.bonusEachCards.firstIndex(where: { $0.card_id == card.cardID }) {
                                                        (Text("competition.realtime.card.time") + Text(": ") + Text(TimeDisplay.formattedTime( appState.competitionManager.matchContext.bonusEachCards[index].bonus_time, showFraction: true)))
                                                            .font(.subheadline)
                                                            .foregroundStyle(Color.white)
                                                        Spacer()
                                                    } else {
                                                        (Text("competition.realtime.card.time") + Text(": 00.00"))
                                                            .font(.subheadline)
                                                            .foregroundStyle(Color.secondText)
                                                        Spacer()
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .padding()
                                            .cornerRadius(12)
                                            .padding(.horizontal)
                                        }
                                    } else {
                                        Text("competition.realtime.card.no_cards")
                                            .foregroundStyle(Color.secondText)
                                            .padding(.top, 50)
                                    }
                                }
                                .padding(.bottom, 50)
                            }
                        }
                    }
                    .frame(height: 450)
                }
                .background(Color.defaultBackground)
                .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
            }
            .offset(y: chevronDirection ? 300 : 0)
        }
        .ignoresSafeArea(edges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture(false)
        .alert(isPresented: $appState.competitionManager.showAlert) {
            Alert(
                title: Text(LocalizedStringKey(appState.competitionManager.alertTitle)),
                message: Text(LocalizedStringKey(appState.competitionManager.alertMessage)),
                dismissButton: .default(Text("action.confirm"))
            )
        }
        .onFirstAppear {
            if !appState.competitionManager.isRecording {
                PopupWindowManager.shared.presentPopup(
                    title: "competition.event.precautions",
                    message: "competition.realtime.popup.familiar_route",
                    doNotShowAgainKey: "CompetitionRealtimeView.familiar_route",
                    bottomButtons: [
                        .confirm()
                    ]
                )
            }
        }
        .onStableAppear() {
            DispatchQueue.main.async {
                appState.competitionManager.isShowWidget = false
            }
            appState.competitionManager.requestLocationAlwaysAuthorization()
            if !appState.competitionManager.isRecording {
                LocationManager.shared.changeToMediumUpdate()
                appState.competitionManager.setupCompetitionLocationSubscription()
            }
        }
        .onStableDisappear() {
            DispatchQueue.main.async {
                appState.competitionManager.isShowWidget = appState.competitionManager.isRecording
            }
            if !appState.competitionManager.isRecording {
                appState.competitionManager.deleteCompetitionLocationSubscription()
            }
        }
    }
    
    private func startCompetition() {
        if appState.competitionManager.sport == .Bike {
            guard let record = appState.competitionManager.currentBikeRecord else {
                let toast = Toast(message: "competition.realtime.start.toast.record_error")
                ToastManager.shared.show(toast: toast)
                return
            }
            if record.isTeam, appState.competitionManager.isTeamJoinWindowExpired {
                let toast = Toast(message: "competition.realtime.start.toast.out_window")
                ToastManager.shared.show(toast: toast)
                return
            }
        } else if appState.competitionManager.sport == .Running {
            guard let record = appState.competitionManager.currentRunningRecord else {
                let toast = Toast(message: "competition.realtime.start.toast.record_error")
                ToastManager.shared.show(toast: toast)
                return
            }
            if record.isTeam, appState.competitionManager.isTeamJoinWindowExpired {
                let toast = Toast(message: "competition.realtime.start.toast.out_window")
                ToastManager.shared.show(toast: toast)
                return
            }
        } else {
            let toast = Toast(message: "competition.realtime.start.toast.sport_not_support")
            ToastManager.shared.show(toast: toast)
            return
        }
        
        // 检查精确位置权限
        guard locationManager.checkPreciseLocation() else {
            DispatchQueue.main.async {
                PopupWindowManager.shared.presentPopup(
                    title: "competition.realtime.precise_location.popup.title",
                    message: "competition.realtime.precise_location.popup.content",
                    bottomButtons: [.confirm()]
                )
            }
            return
        }
        
        // 检查是否在出发区域内
        guard appState.competitionManager.isInValidArea else {
            let toast = Toast(message: "competition.realtime.start.out_of_area")
            ToastManager.shared.show(toast: toast)
            return
        }
        
        for (pos, dev) in DeviceManager.shared.deviceMap {
            if let device = dev, (appState.competitionManager.sensorRequest & (1 << (pos.rawValue + 1))) != 0 {
                if !device.connect() {
                    let toast = Toast(message: "competition.realtime.start.toast.sensor_unbind")
                    ToastManager.shared.show(toast: toast)
                    return
                }
            }
        }
        
        if !appState.competitionManager.isRecording {
            appState.competitionManager.startCompetition()
        }
    }
    
    private func adjustNavigationPath() {
        if !appState.competitionManager.isRecording {
            appState.navigationManager.removeLast()
        } else {
            var indexToLast = 1
            if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
                indexToLast = appState.navigationManager.path.count - index
            }
            let lastToRemove = max(1, indexToLast)
            appState.navigationManager.removeLast(lastToRemove)
        }
    }
}

#Preview {
    let appState = AppState.shared
    return CompetitionRealtimeView()
        .environmentObject(appState)
}
