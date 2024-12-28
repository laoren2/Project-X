//
//  RVRCompetitionView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/7.
//

import SwiftUI
import MapKit

struct RVRCompetitionView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: RVRCompetitionViewModel
    
    @State private var startLatitude: String = ""
    @State private var startLongitude: String = ""
    @State private var endLatitude: String = ""
    @State private var endLongitude: String = ""
    @State private var isActive = false
    @State private var showCardSelection = false
    
    
    var body: some View {
        VStack {
            // 地图视图显示赛道的出发点和终点
            Map() {
                Annotation("Start", coordinate: appState.competitionManager.startCoordinate) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.green)
                }
                Annotation("End", coordinate: appState.competitionManager.endCoordinate) {
                    Image(systemName: "flag.checkered")
                        .foregroundColor(.red)
                }
                // 添加出发点安全区域
                MapCircle(center: appState.competitionManager.startCoordinate, radius: appState.competitionManager.safetyRadius)
                    .foregroundStyle(.green.opacity(0.3))
                    .stroke(.mint, lineWidth: 2)
                
                // 添加终点安全区域
                MapCircle(center: appState.competitionManager.endCoordinate, radius: appState.competitionManager.safetyRadius)
                    .foregroundStyle(.red.opacity(0.3))
                    .stroke(.mint, lineWidth: 2)
                
                // 用户位置
                //UserAnnotation(anchor: .center, content: { UserLocation in
                
                //})
                //.annotationTitles(.automatic)
                
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .frame(height: 200)
            .padding()
            
            // 出发点/终点经纬度输入
            VStack {
                Text("出发点")
                    .font(.headline)
                HStack {
                    TextField("纬度", text: $startLatitude)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("完成") {
                                    hideKeyboard()
                                }
                            }
                        }
                    TextField("经度", text: $startLongitude)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
            }
            
            VStack {
                Text("终点")
                    .font(.headline)
                HStack {
                    TextField("纬度", text: $endLatitude)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("经度", text: $endLongitude)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
            }
            
            // 确认按钮
            Button(action: updateCoordinates) {
                Text("确认")
                    .frame(minWidth: 50)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
            
            Spacer()
            
            if !appState.competitionManager.isRecording && !appState.competitionManager.canStartCompetition {
                Text("您不在出发点，无法开始比赛")
                    .foregroundColor(Color.gray)
            }
            
            Button(action: {isActive = true}) {
                Text("我准备好了")
                    .frame(minWidth: 150)
                    .padding()
                    .background(appState.competitionManager.canStartCompetition ? Color.green : Color.gray)
                    .cornerRadius(10)
                    .foregroundColor(.white)
            }
            .disabled(!appState.competitionManager.canStartCompetition)
            //.onAppear() {
            //    print("我准备好了Btn onAppear")
            //}
            
            
            Spacer()
            
            // 显示已选择的模型名称（最多3个）
            if MagicCardManager.shared.selectedCards.isEmpty {
                Text("尚未选择卡片")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom)
            } else {
                /*VStack(alignment: .leading) {
                    Text("已选择的卡片：")
                        .font(.headline)
                    ForEach(MagicCardManager.shared.selectedCards.prefix(3)) { card in
                        Text(card.name)
                            .font(.subheadline)
                    }
                }
                .padding(.bottom)*/
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(MagicCardManager.shared.selectedCards) { card in
                            CardView(card: card)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Button(action: {
                showCardSelection = true
            }) {
                Text("选择卡片")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
            .sheet(isPresented: $showCardSelection) {
                CardSelectionView(isPresented: $showCardSelection)
            }
        }
        .onAppear() {
            print("CompetitionView onAppear")
            LocationManager.shared.saveCompetionSelectViewToLast()
            if !appState.competitionManager.isRecording {
                LocationManager.shared.enterCompetionSelectView()
            }
            appState.competitionManager.setupSelectedViewLocationSubscription()
        }
        .onDisappear() {
            print("CompetitionView onDisappear")
            appState.competitionManager.deleteSelectedViewLocationSubscription()
        }
        .navigationDestination(isPresented: $isActive) {
            CompetitionDetailView()
        }
    }
    
    // 更新坐标的逻辑
    func updateCoordinates() {
        if let startLat = Double(startLatitude),
           let startLon = Double(startLongitude),
           let endLat = Double(endLatitude),
           let endLon = Double(endLongitude) {
            appState.competitionManager.startCoordinate = CLLocationCoordinate2D(latitude: startLat, longitude: startLon)
            appState.competitionManager.endCoordinate = CLLocationCoordinate2D(latitude: endLat, longitude: endLon)
        }
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct CompetitionDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        // 显示比赛数据或其他内容
        VStack {
            // todo 添加时间显示
            Text("已进行时间: \(TimeDisplay.formattedTime(appState.competitionManager.elapsedTime))")
                .font(.subheadline)
            Spacer()
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
            Spacer()
        }
        //.navigationBarBackButtonHidden(true) // 隐藏默认返回按钮
        /*.toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if appState.competitionManager.isRecording {
                        appState.competitionManager.alertTitle = "暂时无法返回"
                        appState.competitionManager.alertMessage = "请先结束比赛再进行返回"
                        appState.competitionManager.showAlert = true
                    } else {
                        presentationMode.wrappedValue.dismiss() // 返回比赛页面
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }*/
        .alert(isPresented: $appState.competitionManager.showAlert) {
            Alert(
                title: Text(appState.competitionManager.alertTitle),
                message: Text(appState.competitionManager.alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .onAppear() {
            appState.competitionManager.isShowWidget = false
            appState.competitionManager.requestLocationAlwaysAuthorization()
        }
        .onDisappear() {
            appState.competitionManager.isShowWidget = true
        }
    }
}


#Preview {
    //PVPCompetitionView()
}
