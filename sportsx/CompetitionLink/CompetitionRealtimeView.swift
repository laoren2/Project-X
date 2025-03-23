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
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        // 显示比赛数据或其他内容
        VStack {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $cameraPosition) {
                    Annotation("From", coordinate: appState.competitionManager.startCoordinate) {
                        Image(systemName: "location.fill")
                            .padding(5)
                    }
                    // 添加出发点安全区域
                    MapCircle(center: appState.competitionManager.startCoordinate, radius: appState.competitionManager.safetyRadius)
                        .foregroundStyle(.green.opacity(0.3))
                        .stroke(.mint, lineWidth: 2)
                }
                .frame(height: 200)
                .padding(10)
                .shadow(radius: 2)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                
                // 重新居中按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 2)) {
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: appState.competitionManager.startCoordinate,
                                latitudinalMeters: appState.competitionManager.safetyRadius * 3,
                                longitudinalMeters: appState.competitionManager.safetyRadius * 3
                            )
                        )
                    }
                }) {
                    Image(systemName: "location.north.line.fill") // 自定义图标
                        .font(.title3)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding(.trailing, 15)
                .padding(.bottom, 15) // 贴到右下角
            }
            
            Spacer()
            
            // todo 添加时间显示
            Text("已进行时间: \(TimeDisplay.formattedTime(appState.competitionManager.elapsedTime))")
                .font(.subheadline)
            //Spacer()
            Text("Xpose: \(appState.competitionManager.predictResultCnt)")
                .font(.headline)
                .padding(.top, 20)
            
            Spacer()
            
            if !appState.competitionManager.isRecording && !appState.competitionManager.canStartCompetition {
                Text("您不在出发点，无法开始比赛")
                    .foregroundColor(Color.gray)
            }
            
            ZStack {
                Button(action: {
                    if !appState.competitionManager.isRecording {
                        appState.competitionManager.startCompetition()
                    }
                }) {
                    Text(appState.competitionManager.isRecording ? "进行中" : "开始")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 100, height: 100)
                        .background(appState.competitionManager.isRecording ? Color.orange : (appState.competitionManager.canStartCompetition ? Color.green : Color.gray))
                        .clipShape(Circle())
                }
                .disabled(appState.competitionManager.isRecording || !appState.competitionManager.canStartCompetition) // 比赛进行中时禁用按钮
                
                if appState.competitionManager.isRecording {
                    HStack {
                        Spacer()
                        Button(action: {
                            appState.competitionManager.stopCompetition()
                        }) {
                            Text("结束比赛")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 80, height: 50)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                        .padding(.trailing, 25)
                    }
                }
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .navigationBarBackButtonHidden(true)  // 隐藏默认返回按钮
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: adjustNavigationPath) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
            }
        }
        .alert(isPresented: $appState.competitionManager.showAlert) {
            Alert(
                title: Text(appState.competitionManager.alertTitle),
                message: Text(appState.competitionManager.alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear() {
            appState.competitionManager.isShowWidget = false
            appState.competitionManager.requestLocationAlwaysAuthorization()
        }
        .onAppear() {
            if !appState.competitionManager.isRecording {
                LocationManager.shared.saveCompetionSelectViewToLast()
                if !appState.competitionManager.isRecording {
                    LocationManager.shared.enterCompetionSelectView()
                }
                appState.competitionManager.setupSelectedViewLocationSubscription()
            }
        }
        .onDisappear() {
            appState.competitionManager.isShowWidget = appState.competitionManager.isRecording
        }
        .onDisappear() {
            //if !appState.competitionManager.isRecording {
                appState.competitionManager.deleteSelectedViewLocationSubscription()
            //}
        }
    }
    
    private func adjustNavigationPath() {
        if !appState.competitionManager.isRecording {
            appState.navigationManager.path.removeLast()
        } else {
            let lastToRemove = max(1, appState.navigationManager.findIndex(des: "competitionCardSelectView"))
            appState.navigationManager.path.removeLast(lastToRemove)
        }
    }
}


#Preview {
    let appState = AppState()
    return CompetitionRealtimeView()
        .environmentObject(appState)
}
