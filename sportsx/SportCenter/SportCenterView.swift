//
//  SportCenterView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/5.
//

import SwiftUI

struct SportCenterView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = SportCenterViewModel()
    @ObservedObject var currencyManager = CurrencyManager.shared
    
    @State private var showSportPicker = false
    @State private var selectedMode = 1
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    // 运动选择模块
                    HStack {
                        Image(systemName: viewModel.selectedSport.iconName)
                            .font(.title2)
                        Text(viewModel.selectedSport.rawValue)
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
                            SportPickerView(selectedSport: $viewModel.selectedSport)
                        }
                    }
                    .padding(.leading, 10)
                    
                    Spacer()
                    
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
                    if selectedMode == 1 {
                        Text("X1赛季")
                            .font(.headline)
                            .foregroundStyle(.red.opacity(0.8))
                    } else {
                        Image(systemName: "flag.2.crossed")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.green)
                    }
                }
            }
            
            if viewModel.selectedSport.category == .PVP {
                if selectedMode == 0 {
                    PVPTrainingView(viewModel: PVPTrainingViewModel())
                } else {
                    PVPCompetitionView(viewModel: PVPCompetitionViewModel())
                }
            } else if viewModel.selectedSport.category == .RVR {
                if selectedMode == 0 {
                    RVRTrainingView(viewModel: RVRTrainingViewModel())
                } else {
                    RVRCompetitionView(viewModel: RVRCompetitionViewModel(), centerViewModel: viewModel)
                }
            }
            //Spacer()
        }
        .toolbar(.hidden, for: .navigationBar) // 隐藏导航栏
    }
}

// 训练 View
struct PVPTrainingView: View {
    @StateObject var viewModel: PVPTrainingViewModel
    
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
    @StateObject var viewModel: RVRTrainingViewModel
    
    var body: some View {
        VStack {
            Spacer()
            Text("RVR训练页面")
                .font(.largeTitle)
                .fontWeight(.bold)
            // 添加更多的训练页面内容
            Spacer()
        }
    }
}

struct PVPCompetitionView: View {
    @StateObject var viewModel: PVPCompetitionViewModel
    
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
    let appState = AppState()
    return SportCenterView()
        .environmentObject(appState)
}
