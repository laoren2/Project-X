//
//  SportCenterView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/5.
//

import SwiftUI

struct SportCenterView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSport: SportName = .Bike // 默认运动
    @State private var showSportPicker = false
    @State private var selectedMode = 1
    
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    // 运动选择模块
                    HStack {
                        Image(systemName: selectedSport.iconName)
                            .font(.title2)
                        Text(selectedSport.rawValue)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Button(action: {
                            withAnimation {
                                showSportPicker.toggle()
                            }
                        }) {
                            Image(systemName: "repeat")
                                .foregroundColor(.primary)
                                .font(.headline)
                        }
                        .sheet(isPresented: $showSportPicker) {
                            SportPickerView(selectedSport: $selectedSport)
                        }
                        Spacer()
                    }
                    .padding(.leading, 10)
                    
                    // 模式切换开关
                    Picker("", selection: $selectedMode) {
                        Text("训练").tag(0)
                        Text("竞赛").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 120, height: 40)
                    .padding(.trailing)
                }
                // 居中图案
                HStack {
                    Image(systemName: selectedMode == 1 ? "flag.checkered.2.crossed" : "flag.2.crossed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor((selectedMode == 1) ? .red : .green)
                        .animation(.easeInOut, value: selectedMode) // 切换时的动画
                }
            }
            
            Spacer()

            if selectedSport.category == .PVP {
                if selectedMode == 0 {
                    PVPTrainingView(viewModel: PVPTrainingViewModel(sport: selectedSport))
                } else {
                    PVPCompetitionView(viewModel: PVPCompetitionViewModel(sport: selectedSport))
                }
            } else if selectedSport.category == .RVR {
                if selectedMode == 0 {
                    RVRTrainingView(viewModel: RVRTrainingViewModel(sport: selectedSport))
                } else {
                    RVRCompetitionView(viewModel: RVRCompetitionViewModel(sport: selectedSport))
                }
            }
            
            Spacer()
        }
        .toolbar(.hidden, for: .navigationBar) // 隐藏导航栏
        .navigationDestination(isPresented: $appState.competitionManager.navigateToCompetition) {
            CompetitionDetailView()
        }
    }
}

// 训练 View
struct PVPTrainingView: View {
    @ObservedObject var viewModel: PVPTrainingViewModel
    
    var body: some View {
        VStack {
            Text("PVP训练页面")
                .font(.largeTitle)
                .fontWeight(.bold)
            // 添加更多的训练页面内容
        }
    }
}

struct RVRTrainingView: View {
    @ObservedObject var viewModel: RVRTrainingViewModel
    
    var body: some View {
        VStack {
            Text("RVR训练页面")
                .font(.largeTitle)
                .fontWeight(.bold)
            // 添加更多的训练页面内容
        }
    }
}

struct PVPCompetitionView: View {
    @ObservedObject var viewModel: PVPCompetitionViewModel
    
    var body: some View {
        VStack {
            Text("PVP比赛页面")
                .font(.largeTitle)
                .fontWeight(.bold)
            // 添加更多的训练页面内容
        }
    }
}

#Preview {
    SportCenterView()
}
