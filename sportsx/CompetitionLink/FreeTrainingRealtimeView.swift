//
//  FreeTrainingRealtimeView.swift
//  sportsx
//
//  Created by 任杰 on 2025/10/22.
//

import SwiftUI
import MapKit


struct FreeTrainingRealtimeView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var dataFusionManager = DataFusionManager.shared
    @ObservedObject var locationManager = LocationManager.shared
    @State var isReverse: Bool = false
    @State private var chevronDirection: Bool = true
    @State private var chevronDirection2: Bool = true
    @State private var assertInfo: Bool = false
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
                TrainingRealtimeMapView(
                    path: appState.competitionManager.basePathData,
                    isReverse: isReverse,
                    mapMode: $mapMode,
                    userLocation: $appState.competitionManager.userLocation
                )
                .ignoresSafeArea()
                
                VStack {
                    HStack(alignment: .top) {
                        Button(action: {
                            appState.navigationManager.removeLast()
                            if !appState.competitionManager.isRecording {
                                appState.competitionManager.resetCompetitionProperties()
                            }
                        }) {
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
                            Text("sport.feature.free_training")
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
                    ScrollView {
                        VStack(spacing: 20) {
                            HStack {
                                let isGray = locationManager.signalStrength.bars < 2
                                Spacer()
                                if appState.competitionManager.isRecording {
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
                                                        guard checkRecord() else {
                                                            PopupWindowManager.shared.presentPopup(
                                                                title: "无法保存",
                                                                message: "训练时间过短或距离过短，可能无法保存记录。",
                                                                bottomButtons: [
                                                                    .cancel(),
                                                                    .confirm("仍然结束") {
                                                                        appState.competitionManager.stopFreeTraining()
                                                                    }
                                                                ]
                                                            )
                                                            return
                                                        }
                                                        appState.competitionManager.stopFreeTraining()
                                                    }
                                                ]
                                            )
                                        }
                                } else {
                                    Text("competition.realtime.action.start")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 100, height: 100)
                                        .background(isGray ? Color.gray : Color.green)
                                        .clipShape(Circle())
                                        .exclusiveTouchTapGesture {
                                            startFreeTraining()
                                        }
                                }
                                Spacer()
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
            if !appState.competitionManager.isRecording {
                LocationManager.shared.changeToMediumUpdate()
                appState.competitionManager.setupTrainingLocationSubscription()
            }
            appState.competitionManager.isShowWidget = false
            appState.competitionManager.requestLocationAlwaysAuthorization()
        }
        .onStableDisappear() {
            appState.competitionManager.isShowWidget = appState.competitionManager.isRecording
            if !appState.competitionManager.isRecording {
                appState.competitionManager.deleteTrainingLocationSubscription()
            }
        }
    }
    
    func checkRecord() -> Bool {
        let data = appState.competitionManager.realtimeStatisticData
        return data.distance > 100 && dataFusionManager.elapsedTime > 30
    }
    
    private func startFreeTraining() {
        guard appState.competitionManager.sportFeature == .bikeFreeTraining || appState.competitionManager.sportFeature == .runningFreeTraining else {
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
            appState.competitionManager.startFreeTraining()
        }
    }
}
