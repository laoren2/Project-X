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
    @State var isReverse: Bool = false
    @State private var chevronDirection: Bool = true
    @State private var chevronDirection2: Bool = true
    @State private var assertInfo: Bool = false
    @State private var assertInfo2: Bool = false
    @State private var mapMode: MapViewMode = .followUser
    
    @GestureState private var isPressing = false
    @State private var pressProgress: CGFloat = 0.0
    
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
        temp.append(("competition.realtime.avgspeed", String(format: "%.1f ", data.avgSpeed), "speed.km/h", Color.yellow))
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
        return temp
    }
    
    var body: some View {
        // 显示实时比赛数据
        ZStack(alignment: .bottom) {
            ZStack {
                RealtimeMapView(
                    fromCoordinate: appState.competitionManager.startCoordinate,
                    toCoordinate: appState.competitionManager.endCoordinate,
                    startRadius: appState.competitionManager.startRadius,
                    endRadius: appState.competitionManager.endRadius,
                    path: appState.competitionManager.basePathData,
                    isReverse: isReverse,
                    mapMode: $mapMode,
                    userLocation: $appState.competitionManager.userLocation
                )
                .ignoresSafeArea()
                
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
                        Button(action: {
                            assertInfo2.toggle()
                            withAnimation(.easeIn(duration: 0.2)) {
                                assertInfo.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "info")
                                    .font(.system(size: 20))
                                    .bold()
                                    .foregroundColor(.white)
                                if assertInfo {
                                    Text("competition.realtime.switch_info")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.secondText)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Text("competition.realtime.switch")
                                        .foregroundStyle(Color.white)
                                        .onTapGesture {
                                            isReverse.toggle()
                                        }
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                    .padding(.bottom, 40)
                    HStack {
                        Spacer()
                        Button {
                            mapMode = .overview
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                Image("location2")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25, height: 25)
                            }
                            .contentShape(Circle())
                        }
                    }
                    HStack {
                        Spacer()
                        Button {
                            mapMode = .followUser
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                Image("location")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }
                            .contentShape(Circle())
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            VStack {
                HStack {
                    HStack(spacing: 2) {
                        Image(appState.competitionManager.sport.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                        Text(appState.competitionManager.isTeam ? "competition.register.team" : "competition.register.single")
                    }
                    .foregroundStyle(Color.white)
                    .padding(6)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
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
                    Spacer()
                    HStack(spacing: 2) {
                        Image(appState.competitionManager.sport.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                        Text(appState.competitionManager.isTeam ? "competition.register.team" : "competition.register.single")
                    }
                    .padding(6)
                    .hidden()
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
                                if appState.competitionManager.isRecording {
                                    Spacer()
                                    VStack {
                                        (Text("user.page.tab.current_record") + Text(":"))
                                            .font(.subheadline)
                                            .foregroundColor(.secondText)
                                        Text("\(TimeDisplay.formattedTime(dataFusionManager.elapsedTime))")
                                            .font(.largeTitle)
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 120)
                                    Spacer()
                                    // 背景按钮
                                    Text("competition.realtime.action.finish")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 100, height: 50)
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
                                        //.gesture(longPress)
                                    
                                    // 长按时的进度环
                                    //if isPressing {
                                        //CapsuleProgressShape(progress: pressProgress)
                                        //.stroke(Color.white, lineWidth: 4)
                                        //    .frame(width: 100, height: 50)
                                        //.animation(.linear(duration: 2), value: pressProgress)
                                    //}
                                    Spacer()
                                } else {
                                    Text("competition.realtime.action.start")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 100, height: 100)
                                        .background(isGray ? Color.gray : Color.green)
                                        .clipShape(Circle())
                                        .exclusiveTouchTapGesture {
                                            startCompetition()
                                        }
                                }
                            }
                            if appState.competitionManager.isRecording {
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
                                                        (Text("competition.realtime.card.time") + Text(TimeDisplay.formattedTime( appState.competitionManager.matchContext.bonusEachCards[index].bonus_time, showFraction: true)))
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
                    .frame(height: 550)
                }
                .background(Color.defaultBackground.opacity(0.8))
                .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
            }
            .offset(y: chevronDirection ? 350 : 0)
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
        .onStableAppear() {
            appState.competitionManager.isShowWidget = false
            appState.competitionManager.requestLocationAlwaysAuthorization()
            if !appState.competitionManager.isRecording {
                LocationManager.shared.changeToMediumUpdate()
                appState.competitionManager.setupRealtimeViewLocationSubscription()
            }
        }
        .onStableDisappear() {
            appState.competitionManager.isShowWidget = appState.competitionManager.isRecording
            appState.competitionManager.deleteRealtimeViewLocationSubscription()
        }
    }
    
    var longPress: some Gesture {
        LongPressGesture(minimumDuration: 2)
            .updating($isPressing) { currentState, gestureState, _ in
                gestureState = currentState
            }
            .onChanged { _ in
                pressProgress = 0.0
                withAnimation(.linear(duration: 2)) {
                    pressProgress = 1.0
                }
            }
            .onEnded { finished in
                if finished {
                    appState.competitionManager.stopCompetition()
                }
                // 重置状态
                pressProgress = 0.0
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
        
        guard appState.competitionManager.isInValidArea else {
            let toast = Toast(message: "competition.realtime.start.out_of_area")
            ToastManager.shared.show(toast: toast)
            return
        }
        //guard appState.competitionManager.isEffectsFinishPrepare else {
        //    let toast = Toast(message: "competition.realtime.start.toast.card_loading")
        //    ToastManager.shared.show(toast: toast)
        //    return
        //}
        for (pos, dev) in DeviceManager.shared.deviceMap {
            if let device = dev, (appState.competitionManager.sensorRequest & (1 << (pos.rawValue + 1))) != 0 {
                if !device.connect() {
                    let toast = Toast(message: "competition.realtime.start.toast.sensor_unbind")
                    ToastManager.shared.show(toast: toast)
                    return
                }
            }
        }
        guard locationManager.signalStrength.bars > 1 else {
            let toast = Toast(message: "competition.realtime.start.toast.gps")
            ToastManager.shared.show(toast: toast)
            return
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
