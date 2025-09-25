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
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State var isReverse: Bool = false

    let startCoordinate: CLLocationCoordinate2D = {
        let coordinate = AppState.shared.competitionManager.startCoordinate
        return CoordinateConverter.parseCoordinate(coordinate: coordinate)
    }()
    
    let reverseCoordinate: CLLocationCoordinate2D = {
        let coordinate = AppState.shared.competitionManager.startCoordinate
        return CoordinateConverter.reverseParseCoordinate(coordinate: coordinate)
    }()
    
    var body: some View {
        // 显示比赛数据或其他内容
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    adjustNavigationPath()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                Spacer()
                Text("realtime")
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
            
            ZStack(alignment: .bottomTrailing) {
                Map(position: $cameraPosition) {
                    Annotation("From", coordinate: isReverse ? reverseCoordinate : startCoordinate) {
                        Image(systemName: "location.fill")
                            .padding(5)
                    }
                    // 添加出发点安全区域
                    MapCircle(center: isReverse ? reverseCoordinate : startCoordinate, radius: appState.competitionManager.safetyRadius)
                        .foregroundStyle(.green.opacity(0.3))
                        .stroke(.mint, lineWidth: 2)
                }
                .frame(height: 200)
                .shadow(radius: 2)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                
                // 重新居中按钮
                CommonIconButton(icon: "location.north.line.fill") {
                    withAnimation(.easeInOut(duration: 2)) {
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: isReverse ? reverseCoordinate : startCoordinate,
                                latitudinalMeters: appState.competitionManager.safetyRadius * 3,
                                longitudinalMeters: appState.competitionManager.safetyRadius * 3
                            )
                        )
                    }
                }
                .font(.title3)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(radius: 2)
                .padding(.trailing, 15)
                .padding(.bottom, 15) // 贴到右下角
            }
            .padding()
            
            HStack {
                Text("如遇到显示区域错误，请手动切换坐标系")
                Spacer()
                Text("切换")
                    .onTapGesture {
                        isReverse.toggle()
                    }
            }
            .padding(.horizontal)
            .foregroundStyle(Color.secondText)
            
            Spacer()
            
            // 组队模式显示区域
            if appState.competitionManager.isTeam && (!appState.competitionManager.isRecording) {
                VStack {
                    if appState.competitionManager.isTeamJoinWindowExpired {
                        Text("队伍有效窗口时间已过，无法加入比赛")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        Text("剩余加入时间: \(appState.competitionManager.teamJoinRemainingTime)秒")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding()
                    }
                }
                .padding(.bottom, 20)
                
                Spacer()
            }
            
            // todo 添加时间显示
            Text("已进行时间: \(TimeDisplay.formattedTime(dataFusionManager.elapsedTime))")
                .font(.subheadline)
                .foregroundColor(.white)
            //Spacer()
            //Text("Xpose: \(appState.competitionManager.predictResultCnt)")
            //    .font(.headline)
            //    .foregroundColor(.white)
            //    .padding(.top, 20)
            
            Spacer()
            
            if !appState.competitionManager.isRecording && !appState.competitionManager.isInValidArea {
                Text("您不在出发点，无法开始比赛")
                    .foregroundColor(Color.secondText)
            }
            
            ZStack {
                let isDisabledInTeamMode = appState.competitionManager.isTeam && appState.competitionManager.isTeamJoinWindowExpired
                let isGray = (!appState.competitionManager.isInValidArea) || isDisabledInTeamMode || (!appState.competitionManager.isEffectsFinishPrepare)
                
                Text(appState.competitionManager.isRecording ? "进行中" : "开始")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .background(appState.competitionManager.isRecording ? Color.orange : (isGray ? Color.gray : Color.green))
                    .clipShape(Circle())
                    .exclusiveTouchTapGesture {
                        startCompetition()
                    }
                    .disabled(appState.competitionManager.isRecording) // 比赛进行中时禁用按钮
                
                if appState.competitionManager.isRecording {
                    HStack {
                        Spacer()
                        Text("结束比赛")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 50)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .padding(.trailing, 25)
                            .exclusiveTouchTapGesture {
                                appState.competitionManager.stopCompetition()
                            }
                    }
                }
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture() {
            adjustNavigationPath()
        }
        .alert(isPresented: $appState.competitionManager.showAlert) {
            Alert(
                title: Text(appState.competitionManager.alertTitle),
                message: Text(appState.competitionManager.alertMessage),
                dismissButton: .default(Text("确定"))
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
    
    private func startCompetition() {
        if appState.competitionManager.sport == .Bike {
            guard let record = appState.competitionManager.currentBikeRecord else {
                let toast = Toast(message: "报名数据错误,请重试")
                ToastManager.shared.show(toast: toast)
                return
            }
            if record.isTeam, appState.competitionManager.isTeamJoinWindowExpired {
                let toast = Toast(message: "您不在队伍比赛窗口期内")
                ToastManager.shared.show(toast: toast)
                return
            }
        } else if appState.competitionManager.sport == .Running {
            guard let record = appState.competitionManager.currentRunningRecord else {
                let toast = Toast(message: "报名数据错误,请重试")
                ToastManager.shared.show(toast: toast)
                return
            }
            if record.isTeam, appState.competitionManager.isTeamJoinWindowExpired {
                let toast = Toast(message: "您不在队伍比赛窗口期内")
                ToastManager.shared.show(toast: toast)
                return
            }
        } else {
            let toast = Toast(message: "暂不支持当前运动")
            ToastManager.shared.show(toast: toast)
            return
        }
        
        guard appState.competitionManager.isInValidArea else {
            let toast = Toast(message: "您不在出发点范围内")
            ToastManager.shared.show(toast: toast)
            return
        }
        guard appState.competitionManager.isEffectsFinishPrepare else {
            let toast = Toast(message: "资源加载中...")
            ToastManager.shared.show(toast: toast)
            return
        }
        for (pos, dev) in DeviceManager.shared.deviceMap {
            if let device = dev, (appState.competitionManager.sensorRequest & (1 << (pos.rawValue + 1))) != 0 {
                if !device.connect() {
                    let toast = Toast(message: "传感器设备已断开连接,请重试")
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
