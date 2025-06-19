//
//  SportCenterView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/5.
//

import SwiftUI


struct SportCenterView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        ZStack {
            TrainingCenterView()
            CompetitionCenterView()
                .opacity(appState.navigationManager.isTrainingView ? 0 : 1)
        }
    }
}

struct CompetitionCenterView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = CompetitionCenterViewModel()
    @ObservedObject var currencyManager = CurrencyManager.shared
    @ObservedObject var locationManager = LocationManager.shared
    
    @State private var showSportPicker = false
    @State private var showingCitySelection = false
    
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
                            
                            Text(appState.sport.name)
                                .font(.headline)
                            
                            Image(systemName: appState.sport.iconName)
                                .font(.system(size: 18))
                        }
                        .foregroundStyle(.white)
                        .onTapGesture {
                            withAnimation {
                                showSportPicker.toggle()
                            }
                        }
                        .sheet(isPresented: $showSportPicker) {
                            SportPickerView()
                        }
                        
                        Spacer()
                        
                        // 定位
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.white)
                            Text(locationManager.region)
                                .foregroundColor(.white)
                        }
                        .onTapGesture {
                            appState.navigationManager.append(.regionSelectedView)
                        }
                    }
                    .padding(.horizontal, 10)
                    
                    // 居中图案
                    HStack {
                        Text(viewModel.seasonName)
                            .font(.headline)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .padding(.bottom, 10)
                
                if appState.sport == .Bike {
                    BikeCompetitionView(centerViewModel: viewModel)
                } else if appState.sport == .Running {
                    RunningCompetitionView(centerViewModel: viewModel)
                }
            }
        }
        .onFirstAppear {
            viewModel.fetchCurrentSeason()
            viewModel.setupLocationSubscription()
        }
        .onChange(of: appState.sport) {
            viewModel.fetchCurrentSeason()
        }
    }
}

struct TrainingCenterView: View {
    //@StateObject var viewModel: PVPCompetitionViewModel
    
    var body: some View {
        VStack {
            Text("Running比赛页面")
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
