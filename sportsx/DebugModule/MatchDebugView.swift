//
//  MatchDebugView.swift
//  sportsx
//
//  Created by 任杰 on 2025/11/24.
//
#if DEBUG
import SwiftUI

// 本地调试比赛链路和IMU数据
// todo: 改为统一复用 realtimeView & resultView 实现
struct BikeMatchDebugView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = BikeMatchDebugViewModel()
    @ObservedObject var dataFusionManager = DataFusionManager.shared
    @State var isRecording: Bool = false
    
    
    var body: some View {
        VStack {
            HStack {
                Button("begin"){
                    isRecording = true
                    appState.competitionManager.startRecordingSession_debug(with: .Bike)
                }
                Text("\(TimeDisplay.formattedTime(dataFusionManager.elapsedTime))")
                    .font(.largeTitle)
                Button("stop"){
                    appState.competitionManager.stopCompetition_debug()
                    viewModel.samplePath = BikePathPointTool.computeSamplePoints(pathData: appState.competitionManager.bikePathData_debug)
                    isRecording = false
                }
            }
            if !isRecording {
                TestBikePathDetailView(vm: viewModel)
            }
        }
    }
}

// 本地调试比赛路径数据展示
struct TestBikePathDetailView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: BikeMatchDebugViewModel
    @State private var progressIndex: Int = 0
    @State var isPedalDetail: Bool = false
    @State var isAltitudeDetail: Bool = false
    @State var isSpeedDetail: Bool = false
    let formHeight: CGFloat = 80
    
    
    var overallPedalCountRange: (min: Double, max: Double) {
        let pedals = vm.samplePath.compactMap { $0.pedal_count_avg }
        let minVal = pedals.min() ?? 0
        let maxVal = pedals.max() ?? 0
        return (minVal, maxVal)
    }
    
    var overallAltitudeRange: (min: Double, max: Double) {
        let altitudes = vm.samplePath.compactMap { $0.altitude_avg }
        let minVal = altitudes.min() ?? 0
        let maxVal = altitudes.max() ?? 0
        return (minVal, maxVal)
    }
    
    var overallSpeedRange: (min: Double, max: Double) {
        let altitudes = vm.samplePath.compactMap { $0.speed_avg }
        let minVal = altitudes.min() ?? 0
        let maxVal = altitudes.max() ?? 0
        return (minVal, maxVal)
    }
    
    var pedalCountAvg: Double {
        let steps = appState.competitionManager.bikePathData_debug.compactMap { $0.estimate_pedal_count }
        return steps.reduce(0, +) / Double(steps.count)
    }
    
    var speedAvg: Double {
        guard !appState.competitionManager.basePathData_debug.isEmpty else { return 0 }
        
        var totalDistance: Double = 0
        for i in 0..<(appState.competitionManager.basePathData_debug.count - 1) {
            let p1 = appState.competitionManager.basePathData_debug[i]
            let p2 = appState.competitionManager.basePathData_debug[i + 1]
            totalDistance += GeographyTool.haversineDistance(
                lat1: p1.lat, lon1: p1.lon,
                lat2: p2.lat, lon2: p2.lon
            )
        }
        let duration = max(appState.competitionManager.basePathData_debug.last!.timestamp - appState.competitionManager.basePathData_debug.first!.timestamp, 0.0001)
        return (totalDistance / duration) * 3.6
    }
    
    var altitudeAvg: Double {
        let altitudes = appState.competitionManager.basePathData_debug.map { $0.altitude }
        guard !altitudes.isEmpty else { return 0 }
        return altitudes.reduce(0, +) / Double(altitudes.count)
    }
    
    var spacingWidth: CGFloat { return ((UIScreen.main.bounds.width - 32) / (1 + CGFloat(vm.samplePath.count)) - 2) }
    
    var body: some View {
        if !vm.samplePath.isEmpty {
            ScrollView {
                ZStack(alignment: .bottom) {
                    GradientPathMapView(path: appState.competitionManager.basePathData_debug, highlightedIndex: progressIndex)
                        .frame(height: 280)
                        .cornerRadius(12)
                    if !vm.samplePath.isEmpty {
                        // 当前选中时间段
                        HStack {
                            Text(TimeDisplay.formattedTime(vm.samplePath[progressIndex].timestamp_min - vm.samplePath[0].timestamp_min))
                            Spacer()
                            Text(TimeDisplay.formattedTime(vm.samplePath[progressIndex].timestamp_max - vm.samplePath[0].timestamp_min))
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .foregroundStyle(Color.white)
                        .background(Color.black.opacity(0.2))
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(bottomLeadingRadius: 12, bottomTrailingRadius: 12))
                    }
                }
                .padding(.horizontal)
                
                Text("校验分数：\(appState.competitionManager.validationScore_debug)")
                
                VStack {
                    if isPedalDetail {
                        VStack {
                            ZStack(alignment: .center) {
                                HStack {
                                    Text("测试踏频")
                                    Spacer()
                                    Text(String(format: "%.0f - %.0f 次/分", overallPedalCountRange.min, overallPedalCountRange.max))
                                }
                                .foregroundStyle(Color.pink)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isPedalDetail.toggle()
                                }
                                Text(String(format: "%.0f 次/分", vm.samplePath[progressIndex].pedal_count_avg))
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.pink.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            ZStack {
                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                    ForEach(vm.samplePath.indices, id: \.self) { i in
                                        let overall = (overallPedalCountRange.max - overallPedalCountRange.min)
                                        let ratio = overall > 0 ? (vm.samplePath[i].pedal_count_avg - overallPedalCountRange.min) / overall : 1/2
                                        let height = max(formHeight * ratio, 0) + 4
                                        
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(i == progressIndex ? Color.pink : Color.gray.opacity(0.5))
                                            .frame(width: 2, height: height)
                                    }
                                }
                                GestureOverlayView(pointsCount: vm.samplePath.count, progressIndex: $progressIndex)
                            }
                            .frame(height: formHeight)
                            Rectangle()
                                .foregroundStyle(Color.gray)
                                .frame(height: 1)
                            HStack {
                                Text("00:00")
                                Spacer()
                                if let EndTime = appState.competitionManager.basePathData_debug.last?.timestamp, let startTime = appState.competitionManager.basePathData_debug.first?.timestamp {
                                    Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(Color.gray)
                        }
                    } else {
                        HStack {
                            Text("测试踏频")
                            Spacer()
                            Text(String(format: "平均 %.0f 次/分", pedalCountAvg))
                        }
                        .padding()
                        .foregroundStyle(Color.white)
                        .background(Color.pink.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            isPedalDetail.toggle()
                        }
                    }
                    if isAltitudeDetail {
                        VStack {
                            ZStack(alignment: .center) {
                                HStack {
                                    Text("海拔")
                                    Spacer()
                                    Text(String(format: "%.0f - %.0f 米", overallAltitudeRange.min, overallAltitudeRange.max))
                                }
                                .foregroundStyle(Color.green)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isAltitudeDetail.toggle()
                                }
                                Text(String(format: "%.0f 米", vm.samplePath[progressIndex].altitude_avg))
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.green.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            ZStack {
                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                    ForEach(vm.samplePath.indices, id: \.self) { i in
                                        let overall = (overallAltitudeRange.max - overallAltitudeRange.min)
                                        let ratio = overall > 0 ? (vm.samplePath[i].altitude_avg - overallAltitudeRange.min) / overall : 1/2
                                        let height = max(formHeight * ratio, 0) + 4
                                        
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(i == progressIndex ? Color.green : Color.gray.opacity(0.5))
                                            .frame(width: 2, height: height)
                                    }
                                }
                                GestureOverlayView(pointsCount: vm.samplePath.count, progressIndex: $progressIndex)
                            }
                            .frame(height: formHeight)
                            Rectangle()
                                .foregroundStyle(Color.gray)
                                .frame(height: 1)
                            HStack {
                                Text("00:00")
                                Spacer()
                                if let EndTime = appState.competitionManager.basePathData_debug.last?.timestamp, let startTime = appState.competitionManager.basePathData_debug.first?.timestamp {
                                    Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(Color.gray)
                        }
                    } else {
                        HStack {
                            Text("海拔")
                            Spacer()
                            Text(String(format: "平均 %.0f 米", altitudeAvg))
                        }
                        .padding()
                        .foregroundStyle(Color.white)
                        .background(Color.green.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            isAltitudeDetail.toggle()
                        }
                    }
                    if isSpeedDetail {
                        VStack {
                            ZStack(alignment: .center) {
                                HStack {
                                    Text("速度")
                                    Spacer()
                                    Text(String(format: "%.0f - %.0f 公里/小时", overallSpeedRange.min, overallSpeedRange.max))
                                }
                                .foregroundStyle(Color.orange)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isSpeedDetail.toggle()
                                }
                                Text(String(format: "%.0f 公里/小时", vm.samplePath[progressIndex].speed_avg))
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.orange.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            ZStack {
                                HStack(alignment: .bottom, spacing: spacingWidth) {
                                    ForEach(vm.samplePath.indices, id: \.self) { i in
                                        let overall = (overallSpeedRange.max - overallSpeedRange.min)
                                        let ratio = overall > 0 ? (vm.samplePath[i].speed_avg - overallSpeedRange.min) / overall : 1/2
                                        let height = max(formHeight * ratio, 0) + 4
                                        
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(i == progressIndex ? Color.orange : Color.gray.opacity(0.5))
                                            .frame(width: 2, height: height)
                                    }
                                }
                                GestureOverlayView(pointsCount: vm.samplePath.count, progressIndex: $progressIndex)
                            }
                            .frame(height: formHeight)
                            Rectangle()
                                .foregroundStyle(Color.gray)
                                .frame(height: 1)
                            HStack {
                                Text("00:00")
                                Spacer()
                                if let EndTime = appState.competitionManager.basePathData_debug.last?.timestamp, let startTime = appState.competitionManager.basePathData_debug.first?.timestamp {
                                    Text("\(TimeDisplay.formattedTime(EndTime - startTime))")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(Color.gray)
                        }
                    } else {
                        HStack {
                            Text("速度")
                            Spacer()
                            Text(String(format: "平均 %.0f 公里/小时", speedAvg))
                        }
                        .padding()
                        .foregroundStyle(Color.white)
                        .background(Color.orange.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            isSpeedDetail.toggle()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

class BikeMatchDebugViewModel: ObservableObject {
    @Published var samplePath: [BikeSamplePathPoint] = []
}
#endif
