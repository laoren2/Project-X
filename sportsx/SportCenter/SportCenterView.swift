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
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .defaultBackground.softenColor(blendWithWhiteRatio: 0.2),
                            .defaultBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ZStack {
                    HStack {
                        // 运动选择模块
                        HStack(spacing: 5) {
                            Image(systemName: "list.dash")
                                .bold()
                            
                            Text(viewModel.selectedSport.name)
                                .font(.headline)
                            
                            Image(systemName: viewModel.selectedSport.iconName)
                                .font(.system(size: 18))
                        }
                        .foregroundStyle(.white)
                        .onTapGesture {
                            withAnimation {
                                showSportPicker.toggle()
                            }
                        }
                        .sheet(isPresented: $showSportPicker) {
                            SportPickerView(selectedSport: $viewModel.selectedSport)
                        }
                        
                        Spacer()
                        
                        // 模式切换开关
                        Picker("", selection: $selectedMode) {
                            Text("训练").tag(0)
                            Text("竞赛").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 100, height: 40)
                    }
                    .padding(.horizontal, 10)
                    
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
            }
        }
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
    let appState = AppState.shared
    return SportCenterView()
        .environmentObject(appState)
        .preferredColorScheme(.dark)
}
