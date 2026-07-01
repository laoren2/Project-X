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
    //@State var isReverse: Bool = false
    @State private var chevronDirection: Bool = true
    @State private var chevronDirection2: Bool = true
    //@State private var assertInfo: Bool = false
    @State private var mapMode: MapViewMode = .followUser
    @State var showGrids: Bool = false
    // 网格指引开关：独立于 showGrids 瓦片，控制最近 3 个 buff 网格的实时指引
    @State private var showGridGuide: Bool = false
    // “已暂停”提示的呼吸脉动开关（持续轻微缩放，提示运动处于暂停态）
    @State private var pausedPulse: Bool = false
    
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
        return temp
    }
    
    var body: some View {
        // 显示实时比赛数据
        ZStack(alignment: .bottom) {
            ZStack(alignment: .topLeading) {
                if appState.competitionManager.sportFeature == .bikeFreeTraining {
                    BikeTrainingRealtimeMapView(
                        path: appState.competitionManager.basePathData,
                        mapMode: $mapMode,
                        userLocation: $appState.competitionManager.userLocation,
                        isShowSheet: !chevronDirection,
                        showGrids: showGrids,
                        nearbyGrids: appState.competitionManager.nearbyGrids,
                        showGridGuide: showGridGuide
                    )
                    .ignoresSafeArea()
                } else if appState.competitionManager.sportFeature == .runningFreeTraining {
                    RunningTrainingRealtimeMapView(
                        path: appState.competitionManager.basePathData,
                        mapMode: $mapMode,
                        userLocation: $appState.competitionManager.userLocation,
                        isShowSheet: !chevronDirection,
                        showGrids: showGrids,
                        nearbyGrids: appState.competitionManager.nearbyGrids,
                        showGridGuide: showGridGuide
                    )
                    .ignoresSafeArea()
                }
                
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
                        .padding()
                }
            }
            
            VStack {
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
                
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(showGrids ? Color.defaultBackground : Color.black.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(showGrids ? Color.orange : Color.clear, lineWidth: 2)
                            )
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 20))
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    }
                    .contentShape(Circle())
                    .exclusiveTouchTapGesture {
                        showGrids.toggle()
                    }
                }
                .padding(.horizontal)

                // 网格指引按钮：附近 buff 网格在运动开始后才查询，故仅录制中显示
                if appState.competitionManager.isRecording {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(showGridGuide ? Color.defaultBackground : Color.black.opacity(0.6))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(showGridGuide ? Color.orange : Color.clear, lineWidth: 2)
                                )
                            Image("grid_guide")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                        .contentShape(Circle())
                        .exclusiveTouchTapGesture {
                            showGridGuide.toggle()
                        }
                    }
                    .padding(.horizontal)
                }

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
                        if let feature = appState.competitionManager.sportFeature {
                            Image(feature.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 20)
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
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
                
                VStack(spacing: 0) {
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
                            // ZStack 让开始按钮与录制控件各自独立定位：切换时开始按钮原地居中缩小，
                            // 不会被录制态的整行布局（计时器撑满）瞬间推到左侧
                            ZStack {
                                let isGray = locationManager.signalStrength.bars < 2
                                if appState.competitionManager.isRecording {
                                    HStack {
                                        Text("\(TimeDisplay.formattedTime(dataFusionManager.elapsedTime))")
                                            .font(.system(size: 35, weight: .heavy, design: .rounded))
                                            .frame(maxWidth: .infinity)
                                        HStack(spacing: 16) {
                                            // 暂停 / 继续按钮
                                            Button(action: {
                                                if appState.competitionManager.isPaused {
                                                    appState.competitionManager.resumeFreeTraining()
                                                } else {
                                                    appState.competitionManager.pauseFreeTraining()
                                                }
                                            }) {
                                                Image(systemName: appState.competitionManager.isPaused ? "arrowtriangle.right.fill" : "pause.fill")
                                                    .font(.system(size: 25))
                                                    .frame(width: 50, height: 50)
                                                    .foregroundStyle(appState.competitionManager.isPaused ? Color.green : Color.orange)
                                                    .background(Color.white.opacity(0.3))
                                                    .clipShape(Circle())
                                            }
                                            // 结束按钮
                                            Button(action: {
                                                PopupWindowManager.shared.presentPopup(
                                                    title: "training.realtime.action.finish",
                                                    message: "training.realtime.popup.finish",
                                                    bottomButtons: [
                                                        .cancel(),
                                                        .confirm() {
                                                            guard checkRecord() else {
                                                                PopupWindowManager.shared.presentPopup(
                                                                    title: "training.realtime.popup.cannot_save",
                                                                    message: "training.realtime.popup.cannot_save.content",
                                                                    bottomButtons: [
                                                                        .cancel(),
                                                                        .confirm("training.realtime.popup.cannot_save.button") {
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
                                            }) {
                                                Image(systemName: "stop.fill")
                                                    .font(.system(size: 25))
                                                    .frame(width: 50, height: 50)
                                                    .foregroundStyle(Color.red)
                                                    .background(Color.white.opacity(0.3))
                                                    .clipShape(Circle())
                                            }
                                        }
                                    }
                                    // 录制态控件整体从中心缩放跳入，与开始按钮的缩小消失衔接
                                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                                } else {
                                    Text("competition.realtime.action.start")
                                        .font(.system(size: 30))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(width: 100, height: 100)
                                        .background(isGray ? Color.gray : Color.green)
                                        .clipShape(Circle())
                                        .exclusiveTouchTapGesture {
                                            startFreeTraining()
                                        }
                                        // 点击开始后缩小再消失的弹性动画
                                        .transition(.scale(scale: 0.1).combined(with: .opacity))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal)

                            // “已暂停”提示：弹性跳出 + 呼吸脉动，挤占下方统计数据的位置
                            if appState.competitionManager.isPaused {
                                HStack(spacing: 8) {
                                    Image(systemName: "pause.fill")
                                    Text("training.realtime.status.paused")
                                        .font(.system(size: 25, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(Color.secondText)
                                .padding(.vertical, 10)
                                .scaleEffect(pausedPulse ? 1.06 : 0.94)
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                                .onAppear {
                                    pausedPulse = false
                                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                                        pausedPulse = true
                                    }
                                }
                            }

                            // 网格指引开启时，展示附近最近 3 个 buff 网格信息（布局参考 GridBuffCardView）
                            if appState.competitionManager.isRecording && showGridGuide && !appState.competitionManager.nearbyGrids.isEmpty {
                                VStack(spacing: 10) {
                                    ForEach(appState.competitionManager.nearbyGrids) { grid in
                                        NearbyGridGuideCardView(grid: grid, sport: appState.competitionManager.sport)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .transition(.opacity)
                            }

                            if appState.competitionManager.isRecording {
                                // 非懒加载两列网格：卡片始终常驻，避免被挤出 ScrollView 视口后回收重建，
                                // 导致 StatCardView 的入场动画（onAppear）重复触发而出现“瞬移”
                                VStack(spacing: 16) {
                                    ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { row in
                                        HStack(spacing: 16) {
                                            let left = items[row]
                                            StatCardView(title: left.0, value: left.1, unit: left.2, color: left.3, index: row)
                                            if row + 1 < items.count {
                                                let right = items[row + 1]
                                                StatCardView(title: right.0, value: right.1, unit: right.2, color: right.3, index: row + 1)
                                            } else {
                                                // 奇数张时占位，保持最后一张为半宽，与两列对齐
                                                Color.clear.frame(maxWidth: .infinity)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                        // 统一驱动开始/录制/暂停态切换的弹性动画
                        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: appState.competitionManager.isRecording)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appState.competitionManager.isPaused)
                        .animation(.easeInOut(duration: 0.25), value: showGridGuide)
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
        .onStableAppear() {
            if !appState.competitionManager.isRecording {
                LocationManager.shared.changeToMediumUpdate()
                appState.competitionManager.setupFreeTrainingLocationSubscription()
            }
            DispatchQueue.main.async {
                appState.competitionManager.isShowWidget = false
            }
            appState.competitionManager.requestLocationAlwaysAuthorization()
        }
        .onStableDisappear() {
            DispatchQueue.main.async {
                appState.competitionManager.isShowWidget = appState.competitionManager.isRecording
            }
            if !appState.competitionManager.isRecording {
                appState.competitionManager.deleteFreeTrainingLocationSubscription()
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

// 单个实时统计卡片：首次出现时按索引错峰做弹性跳出动画
private struct StatCardView: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let index: Int

    @State private var appeared: Bool = false

    var body: some View {
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
        .scaleEffect(appeared ? 1 : 0.3)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            // 按索引错峰，营造逐个跳出的层次感
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(Double(index) * 0.06)) {
                appeared = true
            }
        }
    }
}

#Preview {
    let appState = AppState.shared
    appState.competitionManager.isRecording = true
    return FreeTrainingRealtimeView()
        .environmentObject(appState)
}

// 附近 buff 网格指引卡片：reward 图标 + 条件角标 + 富文本描述 + 实时距离。
// 布局参考 BikeGridBuffCardView，附加与用户的实时距离（随定位刷新）。
private struct NearbyGridGuideCardView: View {
    let grid: NearbyGrid
    let sport: SportName?

    @ObservedObject private var locationManager = LocationManager.shared

    // condition_type 字符串 → 右上角角标图标，按运动解码到各自的条件枚举
    private var conditionBadgeName: String? {
        switch sport {
        case .Bike:
            return BikeGridConditionType(rawValue: grid.conditionType)?.badgeImageName
        case .Running, .Default:
            return RunningGridConditionType(rawValue: grid.conditionType)?.badgeImageName
        default:
            return nil
        }
    }

    private var distanceText: String? {
        guard let loc = locationManager.getLocation() else { return nil }
        let d = loc.distance(from: CLLocation(latitude: grid.lat, longitude: grid.lon))
        return d >= 1000 ? String(format: "%.1f km", d / 1000) : String(format: "%.0f m", d)
    }

    var body: some View {
        HStack(spacing: 12) {
            // grid icon + 条件角标
            ZStack(alignment: .topTrailing) {
                Image(grid.reward.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                if let badge = conditionBadgeName {
                    Image(badge)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15)
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: 35, height: 35)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.orange.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.orange.opacity(0.8), lineWidth: 1.5)
            )
            .fixedSize()

            // description
            RichTextLabel(
                templateKey: grid.description,
                items:
                    [
                        ("reward", .image(grid.reward.iconName, width: 20)),
                        ("reward", .text(" * \(grid.count)"))
                    ],
                font: .systemFont(ofSize: 15)
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            // 与用户的实时距离
            if let distanceText {
                HStack(spacing: 4) {
                    Image("location")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                    Text(distanceText)
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.secondText)
                .fixedSize()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.3))
        )
    }
}
